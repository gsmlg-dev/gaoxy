defmodule Gaoxy.HTTP.HTTP3.BackendOptionsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{HTTP3, ListenerSet}

  defmodule Endpoint do
    def init(options) do
      if options[:observer], do: send(options[:observer], :h3_backend_initialized)
      {:ok, options}
    end

    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "backend-options")
  end

  defmodule PhoenixEndpoint do
    def init(options), do: options
    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "backend-options")
  end

  test "HTTP3 normalizes host polling before target initialization and keeps defaults" do
    options = [endpoint: {Endpoint, [observer: self()]}, tls: %{certfile: "cert", keyfile: "key"}]
    assert {:ok, default} = HTTP3.service_spec(options)
    assert default.abyss_options == []
    assert default.quic == %{alpn: ["h3"], poll_interval: 10}
    assert_receive :h3_backend_initialized
    assert {:ok, ^default} = HTTP3.service_spec(options ++ [abyss_options: []])
    assert_receive :h3_backend_initialized

    assert {:ok, tuned} =
             HTTP3.service_spec(options ++ [abyss_options: [event_batch: 1, poll_interval: 1]])

    assert tuned.abyss_options == [event_batch: 1]
    assert tuned.quic == %{alpn: ["h3"], poll_interval: 1}
    assert_receive :h3_backend_initialized
    assert {:ok, ^tuned} = Gaoxy.Config.service(tuned)
    refute_received :h3_backend_initialized

    for invalid <- [
          [handler: Endpoint],
          [tls: %{certfile: "other"}],
          [quic_options: []],
          [udp_buffer_size: 4096],
          [transport_options: [recbuf: 4096]],
          [event_batch: 0],
          [event_batch: 129],
          [event_batch: 1, event_batch: 2],
          [poll_interval: 0],
          [poll_interval: 1_001]
        ] do
      assert {:error, _} = HTTP3.service_spec(options ++ [abyss_options: invalid])
      refute_received :h3_backend_initialized
    end

    assert {:error, :invalid_http3_options} = HTTP3.service_spec(options ++ [hell_options: []])
    refute_received :h3_backend_initialized
  end

  @tag :tmp_dir
  test "direct HTTP3 applies host options and serves an independent QUIC peer", %{tmp_dir: dir} do
    certificates(dir)

    assert {:ok, instance} =
             HTTP3.start_link(
               endpoint: {Endpoint, []},
               tls: tls(dir),
               abyss_options: [event_batch: 1, poll_interval: 1]
             )

    Process.unlink(instance)
    on_exit(fn -> if Process.alive?(instance), do: Gaoxy.stop(instance, 1_000) end)
    listener = assert_host(instance, :http3, dir)
    stop_and_rebind(instance, fn -> Gaoxy.stop(instance, 2_000) end, listener)
  end

  @tag :tmp_dir
  test "ListenerSet carries HTTP3 host options through real activation", %{tmp_dir: dir} do
    certificates(dir)

    assert {:ok, owner} =
             ListenerSet.start_link(
               id: :tuned_h3,
               endpoint: {Endpoint, []},
               listeners: [
                 http3: secure(dir) ++ [abyss_options: [event_batch: 1, poll_interval: 1]]
               ]
             )

    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)
    %{instance: instance} = ListenerSet.info(owner)
    listener = assert_host(instance, "tuned_h3:http3", dir)
    stop_and_rebind(instance, fn -> GenServer.stop(owner, :normal, 3_000) end, listener)
  end

  @tag :tmp_dir
  test "Phoenix carries HTTP3 host options and shuts down its owned runtime", %{tmp_dir: dir} do
    certificates(dir)

    [child] =
      Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint,
        http3: secure(dir) ++ [abyss_options: [event_batch: 1, poll_interval: 1]]
      )

    {module, function, arguments} = child.start
    assert {:ok, owner} = apply(module, function, arguments)
    Process.unlink(owner)
    on_exit(fn -> if Process.alive?(owner), do: GenServer.stop(owner) end)
    %{phase: :ready, instance: instance} = Gaoxy.PhoenixAdapter.listeners(PhoenixEndpoint)
    listener = assert_host(instance, Module.concat(PhoenixEndpoint, :HTTP3), dir)
    stop_and_rebind(instance, fn -> GenServer.stop(owner, :normal, 3_000) end, listener)
    assert {:error, :not_running} = Gaoxy.PhoenixAdapter.listeners(PhoenixEndpoint)
  end

  @tag :tmp_dir
  test "invalid host options fail before a ListenerSet sibling binds", %{tmp_dir: dir} do
    certificates(dir)
    {:ok, tcp} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {ip, port}} = :inet.sockname(tcp)
    :gen_tcp.close(tcp)

    assert {:error, {:unsupported_backend_option, :abyss_options, :max_connections}} =
             ListenerSet.start_link(
               id: :invalid_h3_options,
               endpoint: {Endpoint, []},
               listeners: [
                 http: [port: port],
                 http3: secure(dir) ++ [abyss_options: [max_connections: 1000]]
               ],
               name: __MODULE__.InvalidOwner,
               instance_name: __MODULE__.InvalidCore
             )

    assert Process.whereis(__MODULE__.InvalidOwner) == nil
    assert Process.whereis(__MODULE__.InvalidCore) == nil
    assert {:ok, available} = :gen_tcp.listen(port, ip: ip, active: false)
    :gen_tcp.close(available)
  end

  defp assert_host(instance, id, dir) do
    assert {:ok, service, _} = GenServer.call(instance, {:lookup, id})
    backend = :sys.get_state(service).backend
    # Observe the running dependency host, rather than only the normalized declaration.
    assert %{event_batch: 1, poll_interval: 1, max_connections: 64} = :sys.get_state(backend)
    assert %{local: {:ok, {ip, port}}} = Gaoxy.info(instance, id)
    assert port > 0
    root = Path.expand("../../..", __DIR__)
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")

    peer = """
    import asyncio, sys
    from types import SimpleNamespace
    sys.path.insert(0, 'integration/http3')
    from peer import opened
    async def run():
        async with opened(SimpleNamespace(port=int(sys.argv[1]), ca=sys.argv[2], mode='startup')) as client:
            await client.response(client.request(), body=b'backend-options')
        print('BACKEND_OPTIONS_QUIC_PASS')
    asyncio.run(run())
    """

    {output, code} =
      System.cmd(python, ["-c", peer, to_string(port), Path.join(dir, "ca.pem")],
        cd: root,
        stderr_to_stdout: true
      )

    assert code == 0, output
    assert output =~ "BACKEND_OPTIONS_QUIC_PASS"
    await_idle(instance, id, Gaoxy.Lifecycle.deadline(2_000))
    {backend, ip, port}
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

  defp stop_and_rebind(instance, stop, {backend, ip, port}) do
    runtime_monitor = Process.monitor(instance)
    backend_monitor = Process.monitor(backend)
    deadline = Gaoxy.Lifecycle.deadline(3_000)
    assert :ok = stop.()
    assert_receive {:DOWN, ^runtime_monitor, :process, ^instance, :normal}, 1_000
    assert_receive {:DOWN, ^backend_monitor, :process, ^backend, _}, 1_000
    assert Gaoxy.Lifecycle.remaining(deadline) > 0
    assert {:ok, socket} = :gen_udp.open(port, [:binary, active: false, ip: ip])
    assert :ok = :gen_udp.close(socket)
  end

  defp tls(dir), do: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}

  defp secure(dir),
    do: [ip: {127, 0, 0, 1}, port: 0, certfile: tls(dir).certfile, keyfile: tls(dir).keyfile]

  defp certificates(dir) do
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )
  end
end
