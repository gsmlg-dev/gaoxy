defmodule Gaoxy.BackendOptionsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{BackendOptions, Config}

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
    def handle_datagram(packet, _), do: {:reply, packet.data}
  end

  defmodule Native do
    use Hell.Handler
    def validate_options(owner) when is_pid(owner), do: {:ok, owner}

    def handle_connection(socket, %{spec: spec, gate: gate} = state) do
      {:ok, lease} = Gaoxy.Admission.acquire(gate, 0, drain_notify: true)
      {:ok, options} = Hell.Socket.getopts(socket, [:nodelay, :keepalive, :sndbuf, :recbuf])
      send(spec.handler_options, {:socket_options, self(), options})
      {:continue, Map.put(state, :lease, lease)}
    end

    def handle_data(bytes, socket, state) do
      :ok = Hell.Socket.send(socket, bytes)
      {:continue, state}
    end

    def handle_info({:gaoxy_drain, _, _, _}, {socket, state}),
      do: {:stop, :normal, {socket, state}}
  end

  defp spec(extra \\ %{}),
    do: Map.merge(%{id: :echo, transport: :tcp, handler: Echo}, extra)

  test "empty backend options preserve existing defaults and normalize idempotently" do
    assert {:ok, defaults} = Config.service(spec())
    assert defaults.hell_options == []
    assert defaults.abyss_options == []
    assert defaults.limits.max_active == 64
    assert {:ok, ^defaults} = Config.service(spec(%{hell_options: [], abyss_options: []}))
    assert {:ok, ^defaults} = Config.service(defaults)
  end

  test "strict backend and nested option lists reject duplicates, malformed and unknown entries" do
    for options <- [%{}, nil, [:binary], [num_acceptors: 1, num_acceptors: 2]] do
      assert {:error, {:invalid_backend_options, :hell_options}} =
               Config.service(spec(%{hell_options: options}))
    end

    for options <- [%{}, [:inet], [backlog: 1, backlog: 2]] do
      assert {:error, {:invalid_backend_options, {:hell_options, :transport_options}}} =
               Config.service(spec(%{hell_options: [transport_options: options]}))
    end

    assert {:error, {:unsupported_backend_option, :hell_options, :typo}} =
             Config.service(spec(%{hell_options: [typo: 1]}))
  end

  test "handler, binding, resource and lifecycle ownership cannot be overridden" do
    for key <- [
          :handler_module,
          :handler_options,
          :transport_module,
          :port,
          :ip,
          :genserver_options,
          :supervisor_options,
          :num_connections,
          :num_listen_sockets,
          :read_timeout,
          :handshake_timeout,
          :shutdown_timeout,
          :max_connections_retry_count,
          :max_connections_retry_wait,
          :silent_terminate_on_error
        ] do
      assert {:error, {:unsupported_backend_option, :hell_options, ^key}} =
               Config.service(spec(%{hell_options: [{key, 1}]}))
    end

    for key <- [
          :active,
          :mode,
          :packet,
          :ip,
          :port,
          :ifaddr,
          :fd,
          :raw,
          :inet_backend,
          :reuseaddr,
          :reuseport,
          :send_timeout,
          :send_timeout_close,
          :certfile,
          :keyfile,
          :alpn_preferred_protocols
        ] do
      assert {:error, {:unsupported_backend_option, :hell_options, {:transport_options, ^key}}} =
               Config.service(spec(%{hell_options: [transport_options: [{key, 1}]]}))
    end

    for key <- [
          :num_connections,
          :num_listeners,
          :dynamic_listeners,
          :datagram_handler,
          :datagram_dispatcher,
          :runtime_options,
          :read_timeout,
          :shutdown_timeout
        ] do
      assert {:error, {:unsupported_backend_option, :abyss_options, ^key}} =
               Config.service(spec(%{transport: :udp, abyss_options: [{key, 1}]}))
    end

    for key <- [:recbuf, :sndbuf, :buffer, :active, :mode, :ip, :reuseport] do
      assert {:error, {:unsupported_backend_option, :abyss_options, {:transport_options, ^key}}} =
               Config.service(
                 spec(%{transport: :udp, abyss_options: [transport_options: [{key, 1}]]})
               )
    end
  end

  test "backend-specific options and finite socket ranges fail before startup" do
    assert {:error, {:inapplicable_backend_options, :abyss_options}} =
             Config.service(spec(%{abyss_options: [udp_buffer_size: 1000]}))

    assert {:error, {:inapplicable_backend_options, :hell_options}} =
             Config.service(spec(%{transport: :udp, hell_options: [num_acceptors: 1]}))

    for value <- [0, -1, :infinity, 65, 1.5] do
      assert {:error, {:invalid_backend_option, :hell_options, :num_acceptors}} =
               Config.service(spec(%{hell_options: [num_acceptors: value]}))
    end

    for {key, value} <- [
          backlog: 0,
          recbuf: -1,
          sndbuf: :infinity,
          buffer: 2_147_483_648,
          nodelay: 1,
          keepalive: nil,
          tos: 256
        ] do
      assert {:error, {:invalid_backend_option, :hell_options, {:transport_options, ^key}}} =
               Config.service(spec(%{hell_options: [transport_options: [{key, value}]]}))
    end

    assert {:error, {:invalid_backend_option, :abyss_options, :udp_buffer_size}} =
             Config.service(spec(%{transport: :udp, abyss_options: [udp_buffer_size: 0]}))

    for key <- [:tos, :ttl] do
      assert {:error, {:invalid_backend_option, :abyss_options, {:transport_options, ^key}}} =
               Config.service(
                 spec(%{
                   transport: :udp,
                   ip: {0, 0, 0, 0, 0, 0, 0, 1},
                   abyss_options: [transport_options: [{key, 1}]]
                 })
               )
    end
  end

  test "QUIC polling aliases normalize before defaults and reject explicit conflicts" do
    raw = %{
      transport: :quic,
      quic: %{alpn: ["h3"]},
      abyss_options: [event_batch: 7, poll_interval: 3]
    }

    assert {:ok, normalized} = BackendOptions.normalize(raw)
    assert normalized.quic.poll_interval == 3
    assert normalized.abyss_options == [event_batch: 7]
    assert {:ok, ^normalized} = BackendOptions.normalize(normalized)

    assert {:ok, ^normalized} =
             BackendOptions.normalize(%{raw | quic: %{alpn: ["h3"], poll_interval: 3}})

    assert {:error, {:backend_option_conflict, :poll_interval}} =
             BackendOptions.normalize(%{raw | quic: %{poll_interval: 4}})

    for {key, value} <- [event_batch: 0, event_batch: 129, poll_interval: 0, poll_interval: 1001] do
      assert {:error, {:invalid_backend_option, :abyss_options, ^key}} =
               BackendOptions.normalize(%{transport: :quic, abyss_options: [{key, value}]})
    end

    for key <- [
          :quic_options,
          :transport_options,
          :udp_buffer_size,
          :handler,
          :alpn,
          :tls,
          :max_connections,
          :name,
          :init_timeout,
          :callback_timeout,
          :shutdown_timeout,
          :writer_timeout,
          :writer_max_queue,
          :writer_max_bytes,
          :_backend
        ] do
      assert {:error, {:unsupported_backend_option, :abyss_options, ^key}} =
               BackendOptions.normalize(%{transport: :quic, abyss_options: [{key, 1}]})
    end
  end

  @tag :loopback
  test "TCP options reach accepted sockets and acceptor quotas preserve the global ceiling" do
    runtime = start_supervised!({Gaoxy, services: [native(:tcp)]})
    {backend, gate} = owners(runtime)
    pool = child(backend, :acceptor_pool_supervisor)
    acceptors = Supervisor.which_children(pool)
    assert length(acceptors) == 2

    ceilings =
      Enum.map(acceptors, fn {_, supervisor, _, _} ->
        supervisor |> child(:connection_sup) |> :sys.get_state() |> Map.fetch!(:max_children)
      end)

    assert ceilings == [2, 2]
    assert Enum.sum(ceilings) <= 5

    %{local: {:ok, {ip, port}}} = Gaoxy.info(runtime, :echo)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(client) end)
    assert_socket_options()
    assert :ok = :gen_tcp.send(client, "tcp")
    assert {:ok, "tcp"} = :gen_tcp.recv(client, 0, 1000)
    assert %{active: 1} = Gaoxy.status(runtime, :echo)
    assert :ok = Gaoxy.remove(runtime, :echo, 1000)
    refute Process.alive?(backend)
    refute Process.alive?(gate)
    assert {:error, :closed} = :gen_tcp.recv(client, 0, 1000)
  end

  @tag :loopback
  @tag :tmp_dir
  test "TLS options reach real negotiated sockets", %{tmp_dir: dir} do
    root = Path.expand("../../..", __DIR__)
    assert {_, 0} = System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir])

    service =
      Map.put(native(:tls), :tls, %{
        certfile: Path.join(dir, "cert.pem"),
        keyfile: Path.join(dir, "key.pem")
      })

    runtime = start_supervised!({Gaoxy, services: [service]})
    {backend, gate} = owners(runtime)
    %{local: {:ok, {ip, port}}} = Gaoxy.info(runtime, :echo)
    {:ok, client} = :ssl.connect(ip, port, [:binary, active: false, verify: :verify_none], 1000)
    on_exit(fn -> :ssl.close(client) end)
    assert_socket_options()
    assert :ok = :ssl.send(client, "tls")
    assert {:ok, "tls"} = :ssl.recv(client, 0, 1000)
    assert %{active: 1} = Gaoxy.status(runtime, :echo)
    assert :ok = Gaoxy.remove(runtime, :echo, 1000)
    refute Process.alive?(backend)
    refute Process.alive?(gate)
    assert {:error, :closed} = :ssl.recv(client, 0, 1000)
  end

  @tag :loopback
  test "UDP buffer sizing and socket tuning are effective and cleanup closes the endpoint" do
    runtime =
      start_supervised!(
        {Gaoxy,
         services: [
           spec(%{
             transport: :udp,
             abyss_options: [udp_buffer_size: 131_072, transport_options: [tos: 16, ttl: 42]]
           })
         ]}
      )

    {backend, gate} = owners(runtime)
    [listener] = Abyss.Listener.for_server(backend)
    {socket, _span} = Abyss.Listener.socket_info(listener)
    assert {:ok, options} = :inet.getopts(socket, [:sndbuf, :recbuf, :buffer, :tos, :ttl])
    assert options[:sndbuf] >= 131_072
    assert options[:recbuf] >= 131_072
    assert options[:buffer] == 65_536
    assert options[:tos] == 16
    assert options[:ttl] == 42
    %{local: {ip, port}} = Gaoxy.info(runtime, :echo)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false])
    on_exit(fn -> :gen_udp.close(client) end)
    assert :ok = :gen_udp.send(client, ip, port, "udp")
    assert {:ok, {^ip, ^port, "udp"}} = :gen_udp.recv(client, 0, 1000)
    assert :ok = Gaoxy.remove(runtime, :echo, 1000)
    refute Process.alive?(backend)
    refute Process.alive?(gate)
    refute Process.alive?(listener)
    assert {:error, :einval} = :inet.getopts(socket, [:sndbuf])
  end

  test "deferred activation cannot alter planned backend settings" do
    planned = spec(%{hell_options: [num_acceptors: 2], limits: %{max_active: 5}})
    runtime = start_supervised!({Gaoxy, services: [planned], activation: :deferred})

    assert {:error, {:planned_service_changed, :echo}} =
             Gaoxy.activate(runtime, [%{planned | hell_options: [num_acceptors: 1]}])

    assert [] == Gaoxy.services(runtime)
    assert {:ok, [_]} = Gaoxy.activate(runtime, [planned])
    assert :ok = Gaoxy.remove(runtime, :echo, 1000)
  end

  defp native(transport) do
    spec(%{
      transport: transport,
      handler_mode: :native,
      handler: Native,
      handler_options: self(),
      limits: %{max_active: 5},
      hell_options: [
        num_acceptors: 2,
        transport_options: [
          backlog: 37,
          nodelay: false,
          keepalive: true,
          sndbuf: 65_536,
          recbuf: 65_536,
          buffer: 32_768
        ]
      ]
    })
  end

  defp assert_socket_options do
    assert_receive {:socket_options, _, options}, 1000
    assert options[:nodelay] == false
    assert options[:keepalive] == true
    assert options[:sndbuf] >= 65_536
    assert options[:recbuf] >= 65_536
  end

  defp owners(runtime) do
    {:ok, service, _} = GenServer.call(runtime, {:lookup, :echo})
    %{backend: backend, gate: gate} = :sys.get_state(service)
    {backend, gate}
  end

  defp child(supervisor, id) do
    {^id, pid, _, _} = Enum.find(Supervisor.which_children(supervisor), &(elem(&1, 0) == id))
    pid
  end
end
