defmodule Gaoxy.HTTP.HTTP3.ListenerSetNetworkTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.ListenerSet

  defmodule UnifiedPlug do
    def init(options), do: options

    def call(conn, options) do
      conn = Plug.Conn.put_resp_header(conn, "alt-svc", "h3=\":1\"")

      case conn.request_path do
        "/stream" ->
          conn = Plug.Conn.send_chunked(conn, 200)
          {:ok, conn} = Plug.Conn.chunk(conn, "listener-stream")
          conn

        "/file" ->
          Plug.Conn.send_file(conn, 200, options[:file])

        _ ->
          Plug.Conn.send_resp(conn, 200, Atom.to_string(conn.private.gaoxy_http_version))
      end
    end
  end

  defmodule Native do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "native")
  end

  @tag :tmp_dir
  test "H3 preflight reserves a generation snapshot for every admitted stream", %{tmp_dir: dir} do
    certificates(dir)
    provider = Gaoxy.HTTP.HTTP3.ListenerProvider

    target = %Gaoxy.HTTP.ListenerSet.PreparedTarget{
      endpoint: {Gaoxy.HTTP.Generation, %{snapshot_bytes: 4_096}}
    }

    options = Keyword.put(secure(dir), :id, :budget)
    assert {:ok, base} = provider.materialize(:http3, options, :planned)
    reserves = Gaoxy.HTTP.HTTP3.Options.reservation(base.handler_options)
    streams = base.handler_options.h3_limits.max_streams
    required = reserves.connection + streams * (reserves.request + 4_096) + reserves.writer

    assert {:error, :generation_byte_budget} =
             provider.materialize(
               :http3,
               Keyword.put(options, :limits, %{max_bytes: required - 1}),
               target
             )

    assert {:ok, _} =
             provider.materialize(
               :http3,
               Keyword.put(options, :limits, %{max_bytes: required}),
               target
             )
  end

  @tag :tmp_dir
  test "one target serves negotiated TLS H1/H2 and H3, with opt-in discovery for all final response paths",
       %{tmp_dir: dir} do
    certificates(dir)
    file = Path.join(dir, "response.txt")
    File.write!(file, "listener-file")

    {:ok, owner} =
      ListenerSet.start_link(
        id: :unified,
        plug: {UnifiedPlug, [file: file]},
        listeners: [https: secure(dir), http3: secure(dir)],
        discovery: [port: :bound]
      )

    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)
    assert %{phase: :ready, listeners: [https, h3]} = ListenerSet.info(owner)
    assert %{role: :https, transport: :tls, local: {:ok, {_, tls_port}}} = https

    assert %{
             role: :http3,
             transport: :quic,
             local: {:ok, {_, h3_port}},
             pause: :unsupported,
             drain: :local_host_cleanup
           } = h3

    assert tls_port > 0 and h3_port > 0
    root = Path.expand("../../..", __DIR__)
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")

    {output, code} =
      System.cmd(
        python,
        [
          Path.join(root, "apps/gaoxy_http/test/support/listener_set_peer.py"),
          to_string(tls_port),
          to_string(h3_port),
          Path.join(dir, "ca.pem")
        ],
        cd: root,
        stderr_to_stdout: true
      )

    assert code == 0, output
    assert output =~ ~s("result": "PASS")
  end

  @tag :tmp_dir
  test "TCP HTTPS and UDP H3 share an explicit nonzero numeric port", %{tmp_dir: dir} do
    certificates(dir)
    {:ok, probe} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(probe)
    :gen_udp.close(probe)
    opts = Keyword.put(secure(dir), :port, port)

    {:ok, owner} =
      ListenerSet.start_link(
        id: :same_port,
        endpoint: {Native, []},
        listeners: [https: opts, http3: opts]
      )

    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)

    assert %{listeners: [%{local: {:ok, {ip, ^port}}}, %{local: {:ok, {ip, ^port}}}]} =
             ListenerSet.info(owner)
  end

  @tag :tmp_dir
  test "occupied UDP rolls back the started TCP sibling", %{tmp_dir: dir} do
    certificates(dir)
    {:ok, occupied} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_udp.close(occupied) end)
    {:ok, {ip, port}} = :inet.sockname(occupied)
    opts = Keyword.put(secure(dir), :port, port)

    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        result =
          ListenerSet.start_link(
            id: :rollback,
            endpoint: {Native, []},
            listeners: [https: opts, http3: opts]
          )

        send(parent, {:startup_result, self(), result})

        receive do
          :finish -> :ok
        after
          1_000 -> exit(:finish_timeout)
        end
      end)

    assert_receive {:startup_result, ^caller, {:error, _}}, 5_000
    send(caller, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 1_000

    assert {:ok, tcp} = :gen_tcp.listen(port, [:binary, ip: ip, reuseaddr: true])
    :gen_tcp.close(tcp)
  end

  @tag :tmp_dir
  test "discovery observes current listener readiness and port instead of a stale incarnation",
       %{tmp_dir: dir} do
    {instance, services, exchange} = discovery_fixture(dir)
    headers = [{"alt-svc", "upstream"}, {"x-test", "kept"}]
    h3 = Enum.find(services, &(&1.id == "discovery:http3"))
    assert %{local: {:ok, {_, first}}} = Gaoxy.info(instance, h3.id)

    assert [{"alt-svc", public}, {"x-test", "kept"}] =
             Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, 200, headers)

    assert public == "h3=\":9443\"; ma=120"
    context = %{exchange.discovery | policy: %{port: :bound, max_age: 60}}
    exchange = %{exchange | discovery: context}

    assert [{"alt-svc", current} | _] =
             Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, 200, headers)

    assert current == "h3=\":#{first}\"; ma=60"
    assert :ok = Gaoxy.remove(instance, h3.id)

    assert [{"x-test", "kept"}] =
             Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, 200, headers)

    # Occupy the old UDP port so the replacement incarnation must bind another.
    {:ok, occupied} = :gen_udp.open(first, [:binary, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_udp.close(occupied) end)
    assert {:ok, _} = Gaoxy.add(instance, h3)
    assert %{local: {:ok, {_, replacement}}} = Gaoxy.info(instance, h3.id)
    assert replacement != first

    assert [{"alt-svc", rebound} | _] =
             Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, 200, headers)

    assert rebound == "h3=\":#{replacement}\"; ma=60"
    assert :ok = Gaoxy.pause(instance, "discovery:https")

    assert [{"x-test", "kept"}] =
             Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, 200, headers)
  end

  @tag :tmp_dir
  test "discovery stays disabled on excluded responses and is charged to renderer header limits",
       %{tmp_dir: dir} do
    {_instance, _services, exchange} = discovery_fixture(dir)
    headers = [{"x-test", "one"}]
    disabled = %{exchange | discovery: nil}
    assert Gaoxy.HTTP.ListenerSet.Discovery.headers(disabled, 200, headers) == headers

    for excluded <- [
          %{exchange | secure: false},
          %{exchange | request: %{exchange.request | version: :"HTTP/3"}},
          %{exchange | request: %{exchange.request | method: "CONNECT", protocol: "websocket"}}
        ] do
      assert Gaoxy.HTTP.ListenerSet.Discovery.headers(excluded, 200, headers) == headers
    end

    assert Gaoxy.HTTP.ListenerSet.Discovery.headers(exchange, 103, headers) == headers
    limited = %{exchange | limits: %{max_headers: 1, max_header_bytes: 8_192}}

    assert {:error, :response_header_limit} =
             Gaoxy.HTTP.HTTP1.Response.send_resp(limited, 200, headers, "")

    assert {:error, :response_header_limit} =
             Gaoxy.HTTP.HTTP1.Response.send_chunked(limited, 200, headers)

    assert {:error, :invalid_response_headers} =
             Gaoxy.HTTP.FramedResponse.send_resp(limited, 200, headers, "")

    assert {:error, :invalid_response_headers} =
             Gaoxy.HTTP.FramedResponse.send_chunked(limited, 200, headers)
  end

  defp discovery_fixture(dir) do
    certificates(dir)

    {:ok, plan} =
      ListenerSet.plan(
        id: :discovery,
        endpoint: {Native, []},
        listeners: [https: secure(dir), http3: secure(dir)],
        discovery: [port: 9443, max_age: 120]
      )

    {:ok, planned} = ListenerSet.planned_services(plan)
    {:ok, instance} = Gaoxy.start_link(services: planned, activation: :deferred)
    Process.unlink(instance)
    on_exit(fn -> if Process.alive?(instance), do: Gaoxy.stop(instance) end)
    operation = make_ref()
    {:ok, services} = ListenerSet.prepare(plan, instance: instance, activation_id: operation)
    {:ok, _} = Gaoxy.activate(instance, services, operation_id: operation)
    {_, target} = hd(services).handler_options.endpoint

    exchange = %Gaoxy.HTTP.Exchange{
      discovery: target.discovery,
      deadline: Gaoxy.Lifecycle.deadline(5_000),
      secure: true,
      request: %{version: :"HTTP/2", method: "GET", protocol: nil}
    }

    {instance, services, exchange}
  end

  @tag :tmp_dir
  test "invalid H3 credentials fail before its HTTPS sibling binds and leave no owned runtime",
       %{tmp_dir: dir} do
    certificates(dir)
    invalid = Path.join(dir, "invalid.pem")
    File.write!(invalid, "not a certificate")
    {ip, tls_port, quic_port} = available_ports()

    assert {:error, {:field, [:listeners, :http3, :tls], :invalid_credentials}} =
             ListenerSet.start_link(
               id: :invalid_credentials,
               endpoint: {Native, []},
               listeners: [
                 https: Keyword.put(secure(dir), :port, tls_port),
                 http3:
                   secure(dir) |> Keyword.put(:port, quic_port) |> Keyword.put(:certfile, invalid)
               ],
               name: __MODULE__.InvalidOwner,
               instance_name: __MODULE__.InvalidCore
             )

    assert Process.whereis(__MODULE__.InvalidOwner) == nil
    assert Process.whereis(__MODULE__.InvalidCore) == nil
    assert_ports_available(ip, tls_port, quic_port)
  end

  @tag :tmp_dir
  test "unsupported H3 wildcard bind fails before its HTTPS sibling starts", %{tmp_dir: dir} do
    certificates(dir)
    {ip, tls_port, quic_port} = available_ports()

    assert {:error, :wildcard_bind_unsupported} =
             ListenerSet.start_link(
               id: :unsupported_binding,
               endpoint: {Native, []},
               listeners: [
                 https: Keyword.put(secure(dir), :port, tls_port),
                 http3:
                   secure(dir) |> Keyword.put(:port, quic_port) |> Keyword.put(:ip, {0, 0, 0, 0})
               ],
               name: __MODULE__.UnsupportedOwner,
               instance_name: __MODULE__.UnsupportedCore
             )

    assert Process.whereis(__MODULE__.UnsupportedOwner) == nil
    assert Process.whereis(__MODULE__.UnsupportedCore) == nil
    assert_ports_available(ip, tls_port, quic_port)
  end

  defp available_ports do
    ip = {127, 0, 0, 1}
    {:ok, tcp} = :gen_tcp.listen(0, ip: ip, active: false)
    {:ok, udp} = :gen_udp.open(0, ip: ip, active: false)
    {:ok, {^ip, tls_port}} = :inet.sockname(tcp)
    {:ok, {^ip, quic_port}} = :inet.sockname(udp)
    :gen_tcp.close(tcp)
    :gen_udp.close(udp)
    {ip, tls_port, quic_port}
  end

  defp assert_ports_available(ip, tls_port, quic_port) do
    assert {:ok, tcp} = :gen_tcp.listen(tls_port, ip: ip, active: false)
    assert {:ok, udp} = :gen_udp.open(quic_port, ip: ip, active: false)
    :gen_tcp.close(tcp)
    :gen_udp.close(udp)
  end

  defp secure(dir),
    do: [
      ip: {127, 0, 0, 1},
      port: 0,
      certfile: Path.join(dir, "cert.pem"),
      keyfile: Path.join(dir, "key.pem")
    ]

  defp certificates(dir) do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )
  end
end
