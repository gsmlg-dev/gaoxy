defmodule Gaoxy.HTTP.BackendOptionsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.ListenerSet

  defmodule Endpoint do
    def init(options) do
      if options[:observer], do: send(options[:observer], :backend_endpoint_initialized)
      {:ok, options}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "backend-options")
  end

  defmodule PhoenixEndpoint do
    def init(options), do: options
    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "backend-options")
  end

  test "default remains compatible and invalid backend options fail before target initialization" do
    options = [endpoint: {Endpoint, [observer: self()]}]
    assert {:ok, default} = Gaoxy.HTTP.service_spec(options)
    assert_receive :backend_endpoint_initialized
    assert {:ok, ^default} = Gaoxy.HTTP.service_spec(options ++ [hell_options: []])
    assert_receive :backend_endpoint_initialized

    for invalid <- [
          [handler_module: Endpoint],
          [num_acceptors: 65],
          [num_acceptors: 1, num_acceptors: 2],
          [transport_options: [ip: {0, 0, 0, 0}]],
          [transport_options: [active: true]],
          [transport_options: [nodelay: :yes]]
        ] do
      assert {:error, _} = Gaoxy.HTTP.service_spec(options ++ [hell_options: invalid])
      refute_received :backend_endpoint_initialized
    end

    assert {:error, :invalid_http_options} =
             Gaoxy.HTTP.service_spec(options ++ [abyss_options: []])

    assert {:error, :invalid_http_options} =
             Gaoxy.HTTP.service_spec(options ++ [hell_options: [], hell_options: tuning(2)])

    for transport <- [:tcp, :tls], key <- [:recbuf, :buffer] do
      assert {:error, {:unsupported_http_backend_option, ^key}} =
               Gaoxy.HTTP.service_spec(
                 options ++
                   [transport: transport, hell_options: [transport_options: [{key, 4096}]]]
               )

      refute_received :backend_endpoint_initialized
    end

    refute_received :backend_endpoint_initialized
  end

  test "listener roles reject the other backend and preflight rejects reserved options" do
    for {role, key} <- [http: :abyss_options, https: :abyss_options, http3: :hell_options] do
      assert {:error, {:field, [:listeners, ^role, ^key], :unknown_option}} =
               ListenerSet.plan(
                 id: :wrong_backend,
                 endpoint: {Endpoint, []},
                 listeners: [{role, [{key, []}]}]
               )

      assert_raise ArgumentError, fn ->
        Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint, [{role, [{key, []}]}])
      end
    end

    assert {:ok, plan} =
             ListenerSet.plan(
               id: :invalid_backend,
               endpoint: {Endpoint, []},
               listeners: [http: [hell_options: [port: 9000]]]
             )

    assert {:error, {:unsupported_backend_option, :hell_options, :port}} =
             ListenerSet.preflight(plan)

    for role <- [:http, :https], key <- [:recbuf, :buffer] do
      listeners = [{role, [hell_options: [transport_options: [{key, 4096}]]]}]

      assert {:ok, plan} =
               ListenerSet.plan(
                 id: :owned_buffers,
                 endpoint: {Endpoint, []},
                 listeners: listeners
               )

      assert {:error, {:unsupported_http_backend_option, ^key}} = ListenerSet.preflight(plan)
      [child] = Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint, listeners)
      {module, function, arguments} = child.start

      assert {:error, {:unsupported_http_backend_option, ^key}} =
               apply(module, function, arguments)
    end
  end

  @tag :tmp_dir
  test "direct HTTP and HTTPS start requested acceptors and apply socket tuning", %{tmp_dir: dir} do
    certificates(dir)

    for transport <- [:tcp, :tls] do
      tls = if transport == :tls, do: secure(dir) |> Keyword.drop([:port]) |> Map.new(), else: %{}

      assert {:ok, instance} =
               Gaoxy.HTTP.start_link(
                 endpoint: {Endpoint, []},
                 transport: transport,
                 tls: tls,
                 protocols: [:http1],
                 hell_options: tuning(3)
               )

      Process.unlink(instance)
      on_exit(fn -> if Process.alive?(instance), do: Gaoxy.stop(instance, 1_000) end)
      listener = assert_backend(instance, :http, transport, 3)
      stop_and_rebind(instance, fn -> Gaoxy.stop(instance, 2_000) end, [listener])
    end
  end

  @tag :tmp_dir
  test "ListenerSet carries separate HTTP and HTTPS tuning to real backends", %{tmp_dir: dir} do
    certificates(dir)

    assert {:ok, owner} =
             ListenerSet.start_link(
               id: :tuned_listeners,
               endpoint: {Endpoint, []},
               listeners: [
                 http: [hell_options: tuning(2)],
                 https: secure(dir) ++ [protocols: [:http1], hell_options: tuning(3)]
               ]
             )

    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)
    %{instance: instance} = ListenerSet.info(owner)

    listeners = [
      assert_backend(instance, "tuned_listeners:http", :tcp, 2),
      assert_backend(instance, "tuned_listeners:https", :tls, 3)
    ]

    stop_and_rebind(instance, fn -> GenServer.stop(owner, :normal, 3_000) end, listeners)
  end

  @tag :tmp_dir
  test "Phoenix starts tuned HTTP and HTTPS services and cleans up its owned runtime", %{
    tmp_dir: dir
  } do
    certificates(dir)

    [child] =
      Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint,
        http: [port: 0, hell_options: tuning(2)],
        https: secure(dir) ++ [protocols: [:http1], hell_options: tuning(3)]
      )

    {module, function, arguments} = child.start
    assert {:ok, owner} = apply(module, function, arguments)
    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)
    %{phase: :ready, instance: instance} = Gaoxy.PhoenixAdapter.listeners(PhoenixEndpoint)

    listeners = [
      assert_backend(instance, Module.concat(PhoenixEndpoint, HTTP), :tcp, 2),
      assert_backend(instance, Module.concat(PhoenixEndpoint, HTTPS), :tls, 3)
    ]

    stop_and_rebind(instance, fn -> GenServer.stop(owner, :normal, 3_000) end, listeners)
    assert {:error, :not_running} = Gaoxy.PhoenixAdapter.listeners(PhoenixEndpoint)
  end

  defp tuning(count),
    do: [
      num_acceptors: count,
      transport_options: [backlog: 32, nodelay: false, keepalive: true, sndbuf: 32_768]
    ]

  defp assert_backend(instance, id, transport, count) do
    assert {:ok, service, _} = GenServer.call(instance, {:lookup, id})
    backend = :sys.get_state(service).backend
    pool = Hell.Server.acceptor_pool_supervisor_pid(backend)
    assert length(Supervisor.which_children(pool)) == count
    listener = Hell.Server.listener_pid(backend)
    [{1, socket}] = :sys.get_state(listener).listener_sockets
    getter = if transport == :tls, do: :ssl, else: :inet
    assert {:ok, values} = apply(getter, :getopts, [socket, [:nodelay, :keepalive, :sndbuf]])
    assert values[:nodelay] == false
    assert values[:keepalive] == true
    assert values[:sndbuf] >= 32_768
    assert %{local: {:ok, {ip, port}}} = Gaoxy.info(instance, id)
    assert port > 0
    client = if transport == :tls, do: :ssl, else: :gen_tcp

    options =
      [:binary, active: false] ++ if(transport == :tls, do: [verify: :verify_none], else: [])

    assert {:ok, connection} = apply(client, :connect, [ip, port, options, 1_000])

    assert :ok =
             apply(client, :send, [
               connection,
               "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
             ])

    response = receive_response(client, connection, Gaoxy.Lifecycle.deadline(1_000), "")
    assert response =~ "HTTP/1.1 200"
    assert response =~ "backend-options"
    apply(client, :close, [connection])
    await_idle(instance, id, Gaoxy.Lifecycle.deadline(1_000))
    {backend, ip, port}
  end

  defp receive_response(client, connection, deadline, response) do
    remaining = Gaoxy.Lifecycle.remaining(deadline)
    assert remaining > 0, "HTTP response deadline expired"

    case apply(client, :recv, [connection, 0, remaining]) do
      {:ok, bytes} -> receive_response(client, connection, deadline, response <> bytes)
      {:error, :closed} -> response
      error -> flunk("HTTP response failed: #{inspect(error)}")
    end
  end

  defp await_idle(instance, id, deadline) do
    case Gaoxy.status(instance, id) do
      %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)
        Process.sleep(5)
        await_idle(instance, id, deadline)
    end
  end

  defp stop_and_rebind(instance, stop, listeners) do
    monitor = Process.monitor(instance)
    monitors = for {backend, _, _} <- listeners, do: {Process.monitor(backend), backend}
    deadline = Gaoxy.Lifecycle.deadline(3_000)
    assert :ok = stop.()
    assert_receive {:DOWN, ^monitor, :process, ^instance, :normal}, 1_000

    for {reference, backend} <- monitors do
      assert_receive {:DOWN, ^reference, :process, ^backend, _}, 1_000
    end

    assert Gaoxy.Lifecycle.remaining(deadline) > 0

    for {_, ip, port} <- listeners do
      assert {:ok, socket} = :gen_tcp.listen(port, ip: ip, active: false, reuseaddr: true)
      :gen_tcp.close(socket)
    end
  end

  defp secure(dir),
    do: [port: 0, certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")]

  defp certificates(dir) do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )
  end
end
