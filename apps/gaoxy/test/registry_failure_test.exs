defmodule Gaoxy.RegistryFailureTest do
  use ExUnit.Case, async: false
  @moduletag :loopback

  defmodule Stream do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  defmodule Datagram do
    def handle_datagram(packet, _), do: {:reply, packet.data}
  end

  defmodule WaitingDatagram do
    def handle_datagram(packet, owner) do
      send(owner, {:waiting, self(), packet.data})

      receive do
        :release -> {:reply, packet.data}
      end
    end
  end

  setup do
    {:ok, _} = Application.ensure_all_started(:gaoxy)
    supervisor = application_supervisor()

    on_exit(fn ->
      if Process.alive?(supervisor) do
        case Supervisor.restart_child(supervisor, Gaoxy.Registry) do
          {:ok, _} -> :ok
          {:error, :running} -> :ok
        end
      else
        Application.ensure_all_started(:gaoxy)
      end
    end)

    {:ok, application_supervisor: supervisor}
  end

  test "partition loss restores TCP/UDP management and telemetry with the same generation" do
    a = runtime()
    b = runtime()
    tcp = Gaoxy.handle(a, "tcp")
    udp = Gaoxy.handle(a, "udp")
    other = Gaoxy.handle(b, "udp")
    {:ok, service, _} = GenServer.call(a, {:lookup, "udp"})
    backend = :sys.get_state(service).backend
    before_tcp = Gaoxy.info(a, tcp).local
    before_udp = Gaoxy.info(a, udp).local
    exchange_tcp(before_tcp)
    exchange_udp(before_udp)

    [{_, partition, _, _}] = Supervisor.which_children(Gaoxy.Registry)
    monitor = Process.monitor(partition)
    Process.exit(partition, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^partition, :killed}, 1_000
    exchange_tcp(before_tcp)
    exchange_udp(before_udp)

    eventually(fn -> Gaoxy.handle(a, "udp") == udp end)
    assert tcp == Gaoxy.handle(a, "tcp")
    assert other == Gaoxy.handle(b, "udp")
    assert before_tcp == Gaoxy.info(a, tcp).local
    assert before_udp == Gaoxy.info(a, udp).local
    exchange_tcp(before_tcp)
    exchange_udp(before_udp)

    assert [{^service, %{generation: generation}}] =
             Registry.lookup(Gaoxy.Registry, {Gaoxy.Telemetry, backend})

    assert generation == udp.generation
    assert_backend_scope(before_udp, generation, other.generation)
    assert :ok = Gaoxy.pause(a, udp)
    assert %{state: :paused} = Gaoxy.status(a, udp)
    assert :ok = Gaoxy.resume(a, udp)
    assert :ok = Gaoxy.remove(a, udp, 1_000)
    assert {:error, :not_running} = Gaoxy.info(a, udp)
    assert %{state: :ready} = Gaoxy.status(b, other)
  end

  test "whole Registry replacement restores paused management without replacing listeners", %{
    application_supervisor: supervisor
  } do
    instance = runtime()
    handle = Gaoxy.handle(instance, "udp")
    local = Gaoxy.info(instance, handle).local
    exchange_udp(local)
    assert :ok = Gaoxy.pause(instance, handle)
    old = Process.whereis(Gaoxy.Registry)
    monitor = Process.monitor(old)
    assert :ok = Supervisor.terminate_child(supervisor, Gaoxy.Registry)
    assert_receive {:DOWN, ^monitor, :process, ^old, :shutdown}, 1_000
    assert {:ok, _} = Supervisor.restart_child(supervisor, Gaoxy.Registry)
    eventually(fn -> Process.whereis(Gaoxy.Registry) not in [nil, old] end)
    assert Process.alive?(supervisor)
    eventually(fn -> Gaoxy.handle(instance, "udp") == handle end)
    assert local == Gaoxy.info(instance, handle).local
    assert %{state: :paused} = Gaoxy.status(instance, handle)
    assert :ok = Gaoxy.resume(instance, handle)
    exchange_udp(local)
    assert :ok = Gaoxy.remove(instance, handle, 1_000)
  end

  test "abrupt whole Registry death restores each listener or confirms it closed" do
    instance = runtime()

    services =
      for id <- ["tcp", "udp"] do
        handle = Gaoxy.handle(instance, id)
        {:ok, service, _} = GenServer.call(instance, {:lookup, handle})
        %{backend: backend, gate: gate} = :sys.get_state(service)
        {handle, service, backend, gate, Gaoxy.info(instance, handle).local}
      end

    [{_, _, _, _, tcp}, {_, _, _, _, udp}] = services
    exchange_tcp(tcp)
    exchange_udp(udp)
    registry = Process.whereis(Gaoxy.Registry)
    monitor = Process.monitor(registry)
    Process.exit(registry, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^registry, :killed}, 1_000

    for {handle, service, backend, gate, local} <- services do
      eventually(fn ->
        Gaoxy.handle(instance, handle.id) == handle or
          Enum.all?([service, backend, gate], &(not Process.alive?(&1)))
      end)

      if Process.alive?(service) do
        assert local == Gaoxy.info(instance, handle).local
        assert :ok = Gaoxy.remove(instance, handle, 1_000)
      else
        refute Process.alive?(backend)
        refute Process.alive?(gate)

        case local do
          {:ok, {ip, port}} ->
            assert {:error, :econnrefused} =
                     :gen_tcp.connect(ip, port, [:binary, active: false], 100)

          {ip, port} ->
            assert {:ok, socket} = :gen_udp.open(port, ip: ip, active: false)
            :gen_udp.close(socket)
        end
      end
    end
  end

  test "unavailable Registry returns bounded errors and closes resources without restart storms",
       %{
         application_supervisor: supervisor
       } do
    instance = runtime()
    {:ok, service, _} = GenServer.call(instance, {:lookup, "udp"})
    %{backend: backend, gate: gate} = :sys.get_state(service)
    monitors = for pid <- [service, backend, gate], do: {pid, Process.monitor(pid)}
    {ip, port} = Gaoxy.info(instance, "udp").local
    tcp_local = Gaoxy.info(instance, "tcp").local
    exchange_udp({ip, port})
    assert :ok = Supervisor.terminate_child(supervisor, Gaoxy.Registry)

    started = System.monotonic_time(:millisecond)
    assert {:error, :registry_unavailable} = Gaoxy.info(instance, "udp")
    assert {:error, :registry_unavailable} = Gaoxy.pause(instance, "udp")
    assert {:error, :registry_unavailable} = Gaoxy.remove(instance, "udp", 100)

    assert {:error, :registry_unavailable} =
             Gaoxy.add(instance, %{id: "new", transport: :udp, handler: Datagram})

    assert System.monotonic_time(:millisecond) - started < 1_000

    eventually(fn ->
      case :sys.get_state(service).registry_policy.recovery do
        nil -> false
        _ -> true
      end
    end)

    assert {:message_queue_len, count} = Process.info(service, :message_queue_len)
    assert count < 10

    for {pid, monitor} <- monitors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, _}, 3_000
    end

    assert Process.alive?(instance)
    assert {:ok, socket} = :gen_udp.open(port, ip: ip, active: false)
    :gen_udp.close(socket)
    assert {:ok, {tcp_ip, tcp_port}} = tcp_local

    assert {:error, :econnrefused} =
             :gen_tcp.connect(tcp_ip, tcp_port, [:binary, active: false], 100)

    assert {:ok, _} = Supervisor.restart_child(supervisor, Gaoxy.Registry)
    assert {:error, :not_running} = Gaoxy.info(instance, "udp")
    assert {:error, :not_running} = Gaoxy.info(instance, "tcp")
  end

  test "Registry startup failure returns an error without opening a listener", %{
    application_supervisor: supervisor
  } do
    assert :ok = Supervisor.terminate_child(supervisor, Gaoxy.Registry)

    assert {:error, :registry_unavailable} =
             Gaoxy.start_link(services: [%{id: "udp", transport: :udp, handler: Datagram}])

    assert {:ok, _} = Supervisor.restart_child(supervisor, Gaoxy.Registry)
  end

  test "Registry via-name startup failure returns the documented bounded error", %{
    application_supervisor: supervisor
  } do
    assert :ok = Supervisor.terminate_child(supervisor, Gaoxy.Registry)

    for registry_name <- [
          {Gaoxy.Registry, {__MODULE__, make_ref()}},
          {Gaoxy.Registry, {__MODULE__, make_ref()}, :instance_value}
        ] do
      assert {:error, :registry_unavailable} =
               Gaoxy.start_link(
                 name: {:via, Registry, registry_name},
                 services: [%{id: "udp", transport: :udp, handler: Datagram}]
               )
    end

    assert {:ok, _} = Supervisor.restart_child(supervisor, Gaoxy.Registry)
  end

  for value <- [nil, :instance_value] do
    @tag registry_value: value
    test "Registry via-named instance with value #{inspect(value)} closes normally when its management name is lost",
         %{registry_value: value} do
      key = {__MODULE__, make_ref()}

      registry_name =
        if value == nil, do: {Gaoxy.Registry, key}, else: {Gaoxy.Registry, key, value}

      name = {:via, Registry, registry_name}

      instance =
        start_supervised!(
          {Gaoxy,
           name: name,
           services: [
             %{id: "tcp", transport: :tcp, handler: Stream},
             %{id: "udp", transport: :udp, handler: Datagram, limits: %{drain_timeout: 500}}
           ]}
        )

      assert [{^instance, ^value}] = Registry.lookup(Gaoxy.Registry, key)

      services =
        for id <- ["tcp", "udp"] do
          {:ok, pid, _} = GenServer.call(instance, {:lookup, id})
          state = :sys.get_state(pid)
          {pid, state.backend, state.gate, Gaoxy.info(instance, id).local}
        end

      [{_, _, _, tcp}, {_, _, _, udp}] = services
      exchange_tcp(tcp)
      exchange_udp(udp)
      monitor = Process.monitor(instance)
      [{_, partition, _, _}] = Supervisor.which_children(Gaoxy.Registry)
      Process.exit(partition, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^instance, :normal}, 2_500
      assert [] = Registry.lookup(Gaoxy.Registry, key)

      for {pid, backend, gate, local} <- services do
        refute Enum.any?([pid, backend, gate], &Process.alive?/1)

        case local do
          {:ok, {ip, port}} ->
            assert {:error, :econnrefused} =
                     :gen_tcp.connect(ip, port, [:binary, active: false], 100)

          {ip, port} ->
            assert {:ok, socket} = :gen_udp.open(port, ip: ip, active: false)
            :gen_udp.close(socket)
        end
      end
    end
  end

  test "loss between primary and telemetry registration returns a bounded startup error", %{
    application_supervisor: supervisor
  } do
    Process.flag(:trap_exit, true)
    scope = %{instance: make_ref(), service: "starting", generation: make_ref()}
    assert {:ok, policy} = Gaoxy.RegistryPolicy.register(scope)
    assert :ok = Supervisor.terminate_child(supervisor, Gaoxy.Registry)
    assert {:error, :registry_unavailable} = Gaoxy.RegistryPolicy.bind(policy, self())

    assert {:error, :registry_unavailable} =
             Gaoxy.RegistryPolicy.lookup({scope.instance, scope.service})

    assert {:ok, _} = Supervisor.restart_child(supervisor, Gaoxy.Registry)
    assert {:ok, []} = Gaoxy.RegistryPolicy.lookup({scope.instance, scope.service})
  end

  test "late reconciliation cannot overwrite another process registration" do
    Process.flag(:trap_exit, true)
    scope = %{instance: make_ref(), service: "generation", generation: make_ref()}
    assert {:ok, policy} = Gaoxy.RegistryPolicy.register(scope)
    owner = self()

    spawn_monitor(fn ->
      Process.flag(:trap_exit, true)
      send(owner, {:conflicting_registration, Gaoxy.RegistryPolicy.register(scope)})
    end)

    assert_receive {:conflicting_registration, {:error, :registry_unavailable}}, 1_000

    assert {:ok, [{^owner, generation}]} =
             Gaoxy.RegistryPolicy.lookup({scope.instance, scope.service})

    assert generation == scope.generation
    Gaoxy.RegistryPolicy.cancel(policy)
  end

  test "partial reconciliation does not advertise ready before telemetry is rebound" do
    instance = runtime()
    handle = Gaoxy.handle(instance, "udp")
    {:ok, service, _} = GenServer.call(instance, {:lookup, handle})
    token = make_ref()

    state =
      :sys.replace_state(service, fn state ->
        Gaoxy.RegistryPolicy.cancel(state.registry_policy)
        Registry.unregister(Gaoxy.Registry, {state.scope.instance, state.scope.service})
        Registry.unregister(Gaoxy.Registry, {Gaoxy.Telemetry, state.backend})
        {:ok, policy} = Gaoxy.RegistryPolicy.register(state.scope)
        timer = Process.send_after(self(), {:registry_recover, token}, 1_000)

        recovery = %{
          token: token,
          deadline: System.monotonic_time(:millisecond) + 2_000,
          timer: timer
        }

        %{state | registry_policy: %{policy | backend: state.backend, recovery: recovery}}
      end)

    assert [] = Registry.lookup(Gaoxy.Registry, {Gaoxy.Telemetry, state.backend})
    assert {:error, :registry_unavailable} = Gaoxy.info(instance, handle)
    assert {:error, :registry_unavailable} = Gaoxy.pause(instance, handle)
    send(service, {:registry_recover, token})
    eventually(fn -> Gaoxy.handle(instance, "udp") == handle end)
    assert %{state: :ready} = Gaoxy.status(instance, handle)

    assert [{^service, %{generation: generation}}] =
             Registry.lookup(Gaoxy.Registry, {Gaoxy.Telemetry, state.backend})

    assert generation == handle.generation
    assert :ok = Gaoxy.remove(instance, handle, 1_000)
  end

  test "Registry recovery during removal preserves draining work and never resurrects the generation",
       %{
         application_supervisor: supervisor
       } do
    spec = %{id: "udp", transport: :udp, handler: WaitingDatagram, handler_options: self()}
    instance = start_supervised!({Gaoxy, services: [spec]})
    old = Gaoxy.handle(instance, "udp")
    {:ok, service, _} = GenServer.call(instance, {:lookup, old})
    {ip, port} = Gaoxy.info(instance, old).local
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    on_exit(fn -> :gen_udp.close(socket) end)
    :ok = :gen_udp.send(socket, ip, port, "hold")
    assert_receive {:waiting, worker, "hold"}, 1_000
    owner = self()
    spawn(fn -> send(owner, {:removed, Gaoxy.remove(instance, old, 2_000)}) end)
    eventually(fn -> Gaoxy.status(instance, old).state == :draining end)
    assert :ok = Supervisor.terminate_child(supervisor, Gaoxy.Registry)
    assert {:ok, _} = Supervisor.restart_child(supervisor, Gaoxy.Registry)
    eventually(fn -> Gaoxy.handle(instance, "udp") == old end)
    assert %{state: :draining} = Gaoxy.status(instance, old)
    policy = :sys.get_state(service).registry_policy
    send(worker, :release)
    assert {:ok, {^ip, ^port, "hold"}} = :gen_udp.recv(socket, 0, 1_000)
    assert_receive {:removed, :ok}, 1_000
    assert {:ok, current} = Gaoxy.add(instance, %{id: "udp", transport: :udp, handler: Datagram})
    assert current.generation != old.generation
    {:ok, replacement, _} = GenServer.call(instance, {:lookup, current})

    for {monitor, pid} <- policy.owners,
        do: send(replacement, {:DOWN, monitor, :process, pid, :killed})

    send(replacement, {:registry_recover, make_ref()})
    assert current == Gaoxy.handle(instance, "udp")
    assert {:error, :stale_generation} = Gaoxy.info(instance, old)
    assert :ok = Gaoxy.remove(instance, current, 1_000)
  end

  defp assert_backend_scope({ip, port}, generation, other_generation) do
    reference = make_ref()
    owner = self()

    :ok =
      :telemetry.attach(
        reference,
        [:gaoxy, :admission_rejected],
        fn _, _, scope, _ ->
          send(owner, {reference, scope})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)

    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    :ok = :gen_udp.send(socket, ip, port, "large")
    :gen_udp.close(socket)

    assert_receive {^reference, %{generation: ^generation, service: "udp", source: :backend}},
                   1_000

    refute_receive {^reference, _}, 50
    refute_receive {^reference, %{generation: ^other_generation}}, 0
  end

  defp runtime do
    start_supervised!(
      {Gaoxy,
       services: [
         %{id: "tcp", transport: :tcp, handler: Stream},
         %{id: "udp", transport: :udp, handler: Datagram, limits: %{max_packet: 4}}
       ]}
    )
  end

  defp application_supervisor do
    partitions = Enum.map(Supervisor.which_children(Gaoxy.Registry), &elem(&1, 1))
    {:links, links} = Process.info(Process.whereis(Gaoxy.Registry), :links)
    [supervisor] = links -- partitions
    supervisor
  end

  defp exchange_tcp({:ok, {ip, port}}) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(socket, "echo")
    assert {:ok, "echo"} = :gen_tcp.recv(socket, 4, 1_000)
    :gen_tcp.close(socket)
  end

  defp exchange_udp({ip, port}) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    :ok = :gen_udp.send(socket, ip, port, "echo")
    assert {:ok, {^ip, ^port, "echo"}} = :gen_udp.recv(socket, 0, 1_000)
    :gen_udp.close(socket)
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || System.monotonic_time(:millisecond) + 2_000

    result =
      try do
        predicate.()
      catch
        :exit, _ -> false
      end

    unless result do
      assert System.monotonic_time(:millisecond) < deadline, "Registry recovery timed out"

      receive do
      after
        5 -> eventually(predicate, deadline)
      end
    end
  end
end
