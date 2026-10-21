defmodule Gaoxy.StagedActivationTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Lifecycle

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
    def handle_datagram(packet, _), do: {:reply, packet.data}
  end

  defmodule PreparedDispatcher do
    use GenServer

    def validate_options(options), do: {:ok, options}
    def validate_service(options, _), do: {:ok, options}

    def prepare_service(%{owner: owner} = options, _) do
      send(owner, {:preparing_service, self()})

      receive do
        :release -> {:ok, options}
      end
    end

    def start_link(_, %{owner: owner}) do
      {:ok, pid} = GenServer.start_link(__MODULE__, nil)
      send(owner, {:dispatcher_started, pid})
      {:ok, pid}
    end

    def init(nil), do: {:ok, nil}
    def offer(pid, _), do: {:ok, pid}
    def control(_, _, _), do: :ok
    def drain(_, _), do: :ok
  end

  defp spec(extra \\ %{}),
    do: Map.merge(%{id: "echo", transport: :tcp, handler: Echo}, extra)

  defp dispatcher do
    spec(%{
      id: "late",
      transport: :udp,
      port: free_port(:udp),
      handler_mode: :datagram_dispatcher,
      handler: PreparedDispatcher,
      handler_options: %{owner: self()}
    })
  end

  defp instance(services) do
    pid = start_supervised!({Gaoxy, services: services, activation: :deferred})
    on_exit(fn -> if Process.alive?(pid), do: Gaoxy.stop(pid, 1_000) end)
    pid
  end

  test "activation option is strict and immediate remains the default" do
    assert {:ok, %{activation: :immediate}} = Gaoxy.Config.validate(services: [spec()])

    assert {:ok, %{activation: :deferred}} =
             Gaoxy.Config.validate(services: [spec()], activation: :deferred)

    assert {:error, :invalid_activation} =
             Gaoxy.Config.validate(services: [spec()], activation: :paused)
  end

  test "deferred startup preserves budgets above five seconds without binding" do
    service = spec(%{port: free_port(:tcp), limits: %{drain_timeout: 7_000}})
    instance = instance([service])
    assert [] = Gaoxy.services(instance)
    assert {:error, :not_running} = Gaoxy.info(instance, "echo")
    assert_available(:tcp, service.port)
    assert Gaoxy.child_spec(services: [service], activation: :deferred).shutdown == 9_000
    assert {:error, :activation_required} = Gaoxy.add(instance, service)
    assert {:ok, [%{id: "echo", generation: generation}]} = Gaoxy.activate(instance, [service])
    assert is_reference(generation)
    assert ["echo"] = Gaoxy.services(instance)
    %{local: {:ok, {ip, port}}, mode: :ready} = Gaoxy.info(instance, "echo")
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(client, "active")
    assert {:ok, "active"} = :gen_tcp.recv(client, 0, 1_000)
    :gen_tcp.close(client)
    assert :ok = Gaoxy.stop(instance, 1_000)
    refute Process.alive?(instance)
    assert_available(:tcp, service.port)
  end

  test "complete final-set validation precedes binding and preserves planned ceilings" do
    first = spec(%{port: free_port(:tcp)})
    second = spec(%{id: "other", port: free_port(:tcp)})
    instance = instance([first, second])

    assert {:error, {:duplicate_service, "echo"}} = Gaoxy.activate(instance, [first, first])
    assert [] = Gaoxy.services(instance)
    assert_available(:tcp, first.port)

    assert {:error, {:binding_conflict, "other", "echo"}} =
             Gaoxy.activate(instance, [first, %{second | port: first.port}])

    assert {:error, {:planned_services_mismatch, _}} = Gaoxy.activate(instance, [first])

    assert {:error, {:planned_service_changed, "echo"}} =
             Gaoxy.activate(instance, [%{first | port: 0}, second])

    assert {:error, {:planned_service_ceiling, "echo"}} =
             Gaoxy.activate(instance, [Map.put(first, :limits, %{max_bytes: 2_097_152}), second])

    assert [] = Gaoxy.services(instance)
    assert {:ok, [_, _]} = Gaoxy.activate(instance, [first, second])
  end

  test "OS bind failure rolls back every service created by the batch" do
    {:ok, occupied} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    on_exit(fn -> :gen_tcp.close(occupied) end)
    {:ok, {_, occupied_port}} = :inet.sockname(occupied)
    first = spec(%{port: free_port(:tcp)})
    second = spec(%{id: "occupied", port: occupied_port})
    instance = instance([first, second])
    operation = make_ref()
    assert {:error, _} = Gaoxy.activate(instance, [first, second], operation_id: operation)
    assert [] = Gaoxy.services(instance)
    assert_available(:tcp, first.port)

    assert {:ok, %{status: :rejected, cleanup: :complete}} =
             Gaoxy.activation_status(instance, operation)
  end

  test "TCP and UDP may share one numeric port" do
    port = free_port(:tcp)
    tcp = spec(%{port: port})
    udp = spec(%{id: "udp", transport: :udp, port: port})
    instance = instance([tcp, udp])
    assert {:ok, [_, _]} = Gaoxy.activate(instance, [tcp, udp])
    assert %{local: {:ok, {{127, 0, 0, 1}, ^port}}} = Gaoxy.info(instance, "echo")
    assert %{local: {{127, 0, 0, 1}, ^port}} = Gaoxy.info(instance, "udp")
  end

  test "activation operation is reconcilable and conflicting identity reuse is rejected" do
    service = spec()
    instance = instance([service])
    operation = make_ref()
    assert {:ok, handles} = Gaoxy.activate(instance, [service], operation_id: operation)

    assert {:ok, %{status: :committed, result: {:ok, ^handles}, cleanup: :complete}} =
             Gaoxy.activation_status(instance, operation)

    assert {:ok, ^handles} = Gaoxy.activate(instance, [service], operation_id: operation)

    assert {:error, :operation_conflict} =
             Gaoxy.activate(instance, [spec(%{id: "changed"})], operation_id: operation)

    assert {:error, :already_activated} = Gaoxy.activate(instance, [service])
    assert {:error, :unknown_operation} = Gaoxy.activation_status(instance, make_ref())
  end

  test "deadline while service startup is blocked retains late completion and rollback" do
    service = dispatcher()
    instance = instance([service])
    owner = self()
    operation = make_ref()

    caller =
      spawn(fn ->
        send(
          owner,
          {:activation_result,
           Gaoxy.activate(instance, [service], timeout: 30, operation_id: operation)}
        )

        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> Process.exit(caller, :kill) end)

    assert_receive {:preparing_service, preparation}, 1_000
    assert_receive {:activation_result, {:error, {:activation_pending, ^operation}}}, 1_000

    assert {:ok, %{status: :pending, cleanup: :pending}} =
             Gaoxy.activation_status(instance, operation)

    send(preparation, :release)
    assert_receive {:dispatcher_started, dispatcher}, 1_000

    eventually(fn ->
      match?(
        {:ok, %{status: :rejected, cleanup: :complete}},
        Gaoxy.activation_status(instance, operation)
      )
    end)

    assert {:ok, %{result: {:error, :deadline_exceeded}}} =
             Gaoxy.activation_status(instance, operation)

    refute Process.alive?(dispatcher)
    assert [] = Gaoxy.services(instance)
    assert_available(:udp, service.port)
    send(caller, :finish)
  end

  test "caller death cancels pending activation but does not abandon late listener cleanup" do
    service = dispatcher()
    instance = instance([service])
    operation = make_ref()

    caller =
      spawn(fn ->
        Gaoxy.activate(instance, [service], timeout: 2_000, operation_id: operation)
      end)

    assert_receive {:preparing_service, preparation}, 1_000
    Process.exit(caller, :kill)
    send(preparation, :release)
    assert_receive {:dispatcher_started, dispatcher}, 1_000

    eventually(fn ->
      match?(
        {:ok, %{status: :rejected, cleanup: :complete}},
        Gaoxy.activation_status(instance, operation)
      )
    end)

    assert {:ok, %{result: {:error, :caller_down}}} =
             Gaoxy.activation_status(instance, operation)

    refute Process.alive?(dispatcher)
    assert [] = Gaoxy.services(instance)
    assert_available(:udp, service.port)
  end

  test "stop cancels an in-flight batch and waits for its late startup rollback" do
    service = dispatcher()
    instance = instance([service])
    owner = self()
    operation = make_ref()

    spawn(fn ->
      send(
        owner,
        {:activation_result, Gaoxy.activate(instance, [service], operation_id: operation)}
      )
    end)

    assert_receive {:preparing_service, preparation}, 1_000
    spawn(fn -> send(owner, {:stop_result, Gaoxy.stop(instance, 1_000)}) end)

    eventually(fn ->
      {:error, :stopping} == Gaoxy.activate(instance, [service], operation_id: make_ref())
    end)

    refute_receive {:stop_result, :ok}, 20
    send(preparation, :release)
    assert_receive {:dispatcher_started, dispatcher}, 1_000
    assert_receive {:activation_result, {:error, :stopping}}, 1_000
    assert_receive {:stop_result, :ok}, 1_000
    refute Process.alive?(instance)
    refute Process.alive?(dispatcher)
    assert_available(:udp, service.port)
  end

  test "an expired absolute deadline cannot bind even with a fresh relative budget" do
    service = spec(%{port: free_port(:tcp)})
    instance = instance([service])
    operation = make_ref()

    result =
      Gaoxy.activate(instance, [service],
        timeout: 1_000,
        deadline: Lifecycle.now() - 1,
        operation_id: operation
      )

    assert match?({:error, _}, result)

    eventually(fn ->
      match?({:ok, %{status: :rejected}}, Gaoxy.activation_status(instance, operation))
    end)

    assert [] = Gaoxy.services(instance)
    assert_available(:tcp, service.port)
  end

  test "stop keeps cleanup participants available until pending startup rollback completes" do
    service = dispatcher()
    instance = instance([service])
    owner = self()

    participant =
      spawn(fn ->
        {:ok, registration} = Gaoxy.register_lifecycle_participant(instance, 1_000)
        send(owner, {:participant_registered, self()})

        receive do
          {:gaoxy_lifecycle_drain, ^registration, operation, coordinator, _} ->
            send(owner, {:participant_drain, self()})
            send(coordinator, {:gaoxy_lifecycle_result, registration, operation, self(), :ok})
        end
      end)

    on_exit(fn -> Process.exit(participant, :kill) end)
    assert_receive {:participant_registered, ^participant}, 1_000
    spawn(fn -> Gaoxy.activate(instance, [service], timeout: 2_000) end)
    assert_receive {:preparing_service, preparation}, 1_000
    spawn(fn -> send(owner, {:stop_result, Gaoxy.stop(instance, 1_000)}) end)
    eventually(fn -> {:error, :stopping} == Gaoxy.activate(instance, [service]) end)
    refute_receive {:participant_drain, ^participant}, 20
    assert Process.alive?(participant)
    send(preparation, :release)
    assert_receive {:dispatcher_started, dispatcher}, 1_000
    assert_receive {:participant_drain, ^participant}, 1_000
    refute Process.alive?(dispatcher)
    assert_receive {:stop_result, :ok}, 1_000
    refute Process.alive?(instance)
  end

  test "activation accepts only finite options" do
    instance = instance([spec()])

    assert {:error, :invalid_activation_options} =
             Gaoxy.activate(instance, [spec()], timeout: :infinity)

    assert {:error, :invalid_activation_options} =
             Gaoxy.activate(instance, [spec()], deadline: :infinity)

    assert {:error, :invalid_activation_options} =
             Gaoxy.activate(instance, [spec()], unknown: true)
  end

  defp free_port(:tcp) do
    {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {_, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    port
  end

  defp free_port(:udp) do
    {:ok, socket} = :gen_udp.open(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, {_, port}} = :inet.sockname(socket)
    :gen_udp.close(socket)
    port
  end

  defp assert_available(:tcp, port) do
    assert {:ok, socket} = :gen_tcp.listen(port, ip: {127, 0, 0, 1}, active: false)
    :gen_tcp.close(socket)
  end

  defp assert_available(:udp, port) do
    assert {:ok, socket} = :gen_udp.open(port, ip: {127, 0, 0, 1}, active: false)
    :gen_udp.close(socket)
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(2_000)

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0, "condition did not settle"

      receive do
      after
        2 -> eventually(fun, deadline)
      end
    end
  end
end
