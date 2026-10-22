defmodule Gaoxy.BackendOptionsRuntimeTest do
  use ExUnit.Case, async: true

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

  defp spec(extra),
    do: Map.merge(%{id: :echo, transport: :tcp, handler: Echo}, extra)

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
end
