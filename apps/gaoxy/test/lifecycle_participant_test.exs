defmodule Gaoxy.LifecycleParticipantTest do
  use ExUnit.Case, async: true

  defmodule Service do
    use GenServer
    def start_link(owner), do: GenServer.start_link(__MODULE__, owner)
    def init(owner), do: {:ok, %{owner: owner, from: nil}}

    def handle_call({:drain, _, deadline}, from, state) do
      send(state.owner, {:service_drain, self(), deadline})
      {:noreply, %{state | from: from}}
    end

    def handle_info({:settle, result}, state) do
      GenServer.reply(state.from, result)
      {:stop, :normal, state}
    end
  end

  test "registration authenticates the caller and rejects duplicate ownership" do
    instance = instance()
    {pid, registration} = participant(instance)
    send(pid, {:register, instance, :duplicate})
    assert_receive {:duplicate, {:error, :already_registered}}, 1_000
    stop_async(instance)
    assert_receive {:drain, ^pid, ^registration, operation, coordinator, _}, 1_000
    assert is_reference(operation)
    send(pid, {:settle, :ok})
    assert_receive {:stopped, :ok}, 1_000
    refute Process.alive?(instance)
    refute Process.alive?(coordinator)
  end

  test "registrations are isolated between instances" do
    left = instance()
    right = instance()
    {pid, first} = participant(left)
    send(pid, {:register, right, :other_instance})
    assert_receive {:other_instance, {:ok, second}}, 1_000
    refute first == second
    stop_async(left)
    assert_receive {:drain, ^pid, ^first, _, _, _}, 1_000
    send(pid, {:settle, :ok})
    assert_receive {:stopped, :ok}, 1_000
    assert Process.alive?(right)
    stop_async(right)
    assert_receive {:drain, ^pid, ^second, _, _, _}, 1_000
    send(pid, {:settle, :ok})
    assert_receive {:stopped, :ok}, 1_000
  end

  test "64 registrations include failed entries and the 65th has no allocation" do
    instance = instance()
    participants = for _ <- 1..64, do: participant(instance)
    {dead, registration} = hd(participants)
    monitor = Process.monitor(dead)
    send(dead, :die)
    assert_receive {:DOWN, ^monitor, :process, ^dead, :normal}, 1_000
    eventually(fn -> :sys.get_state(instance).participants[registration].outcome != nil end)
    rejected = start_participant(instance)
    assert_receive {:registered, ^rejected, {:error, :participant_limit}}, 1_000
    refute_receive {:allocated, ^rejected}, 20
    stop_async(instance)

    for {pid, _} <- tl(participants) do
      assert_receive {:drain, ^pid, _, _, _, _}, 1_000
      send(pid, {:settle, :ok})
    end

    assert_receive {:stopped, {:error, {:shutdown, [], errors}}}, 1_000
    assert [{^registration, {:error, :cleanup_unconfirmed}}] = errors
  end

  test "registration timeout cannot allocate or become a late registration" do
    instance = instance()
    :ok = :sys.suspend(instance)
    pid = start_participant(instance, 10)
    assert_receive {:registered, ^pid, {:error, {:deadline_exceeded, :cleanup_pending}}}, 1_000
    refute_receive {:allocated, ^pid}, 20
    :ok = :sys.resume(instance)
    assert map_size(:sys.get_state(instance).participants) == 0
    assert :ok = Gaoxy.stop(instance, 1_000)
  end

  test "registration closes while stop is held and Instance remains responsive" do
    instance = instance()
    {pid, registration} = participant(instance)
    stop_async(instance)
    assert_receive {:drain, ^pid, ^registration, _, _, _}, 1_000
    assert [] = Gaoxy.services(instance)
    other = start_participant(instance)
    assert_receive {:registered, ^other, {:error, :stopping}}, 1_000
    refute_receive {:allocated, ^other}, 20
    refute_receive {:stopped, _}, 20
    send(pid, {:settle, :ok})
    assert_receive {:stopped, :ok}, 1_000
  end

  test "services and every participant receive one D before either barrier settles" do
    instance = instance()
    service = start_supervised!({Service, self()})
    :ets.insert(:sys.get_state(instance).live, {"fixture", service, make_ref()})
    {first, _} = participant(instance)
    {second, _} = participant(instance)
    stop_async(instance)
    assert_receive {:service_drain, ^service, deadline}, 1_000
    assert_receive {:drain, ^first, _, first_operation, _, ^deadline}, 1_000
    assert_receive {:drain, ^second, _, second_operation, _, ^deadline}, 1_000
    refute first_operation == second_operation
    assert :sys.get_state(instance).stopping.deadline == deadline
    assert [] = Gaoxy.services(instance)
    send(first, {:settle, :ok})
    send(second, {:settle, :ok})
    refute_receive {:stopped, _}, 20
    send(service, {:settle, :ok})
    assert_receive {:stopped, :ok}, 1_000
  end

  test "wrong registration, PID, operation and shared coordinator token cannot settle" do
    instance = instance()
    {pid, registration} = participant(instance)
    stop_async(instance)
    assert_receive {:drain, ^pid, ^registration, operation, coordinator, _}, 1_000
    token = :sys.get_state(instance).stopping.token
    refute token == operation

    for {reg, op, sender} <- [
          {make_ref(), operation, pid},
          {registration, make_ref(), pid},
          {registration, token, pid},
          {registration, operation, self()}
        ] do
      send(coordinator, {:gaoxy_lifecycle_result, reg, op, sender, :ok})
    end

    refute_receive {:stopped, _}, 30
    send(pid, {:settle, :ok})
    assert_receive {:stopped, :ok}, 1_000
  end

  test "known failure is resource tagged and survives termination without a new drain" do
    instance = instance()
    {pid, registration} = participant(instance)
    stop_async(instance)
    assert_receive {:drain, ^pid, ^registration, _, _, _}, 1_000
    send(pid, {:settle, {:error, :injected}})

    assert_receive {:stopped, {:error, {:shutdown, [], [{^registration, {:error, :injected}}]}}},
                   1_000

    refute_receive {:drain, ^pid, _, _, _, _}, 20
  end

  test "oversized participant failure has bounded retained metadata" do
    instance = instance()
    {pid, registration} = participant(instance)
    stop_async(instance)
    assert_receive {:drain, ^pid, ^registration, _, _, _}, 1_000
    send(pid, {:settle, {:error, String.duplicate("private", 100_000)}})
    assert_receive {:stopped, {:error, {:shutdown, [], [{^registration, error}]}}}, 1_000
    assert error == {:error, :cleanup_unconfirmed}
  end

  test "pending at D is cleanup pending and cleanup headroom is not success budget" do
    instance = instance()
    {pid, registration} = participant(instance)
    monitor = Process.monitor(instance)
    stop_async(instance, 100)
    assert_receive {:drain, ^pid, ^registration, _, _, deadline}, 1_000
    assert_receive {:stopped, {:error, {:deadline_exceeded, :cleanup_pending}}}, 500
    assert Gaoxy.Lifecycle.remaining(deadline) == 0
    send(pid, {:settle, :ok})
    assert_receive {:DOWN, ^monitor, :process, ^instance, :normal}, 1_000
  end

  test "participant death without a receipt cannot confirm cleanup" do
    instance = instance()
    {pid, registration} = participant(instance)
    monitor = Process.monitor(instance)
    stop_async(instance, 150)
    assert_receive {:drain, ^pid, ^registration, _, _, _}, 1_000
    send(pid, :die)
    assert_receive {:stopped, {:error, result}}, 500

    assert result in [
             {:deadline_exceeded, :cleanup_pending},
             {:shutdown, [], [{registration, {:error, :cleanup_unconfirmed}}]}
           ]

    assert_receive {:DOWN, ^monitor, :process, ^instance, :normal}, 1_000
  end

  for order <- [:result_first, :down_first] do
    @tag order: order
    test "authenticated success survives #{order} monitor delivery", %{order: order} do
      instance = instance()
      {pid, registration} = participant(instance)
      stop_async(instance)
      assert_receive {:drain, ^pid, ^registration, operation, coordinator, _}, 1_000
      :erlang.suspend_process(coordinator)
      monitor = Process.monitor(pid)

      if order == :result_first do
        send(pid, {:settle_and_exit, :ok})
      else
        send(pid, :die)
      end

      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 1_000

      eventually(fn ->
        {:messages, messages} = Process.info(coordinator, :messages)
        Enum.any?(messages, &match?({:DOWN, _, :process, ^pid, _}, &1))
      end)

      if order == :down_first do
        send(coordinator, {:gaoxy_lifecycle_result, registration, operation, pid, :ok})
      end

      :erlang.resume_process(coordinator)
      assert_receive {:stopped, :ok}, 1_000
    end
  end

  test "duplicate receipt cannot replace an accepted failure" do
    instance = instance()
    {pid, registration} = participant(instance)
    {held, _} = participant(instance)
    stop_async(instance)
    assert_receive {:drain, ^pid, ^registration, operation, coordinator, _}, 1_000
    assert_receive {:drain, ^held, _, _, _, _}, 1_000

    send(
      coordinator,
      {:gaoxy_lifecycle_result, registration, operation, pid, {:error, :injected}}
    )

    send(coordinator, {:gaoxy_lifecycle_result, registration, operation, pid, :ok})
    send(held, {:settle, :ok})

    assert_receive {:stopped, {:error, {:shutdown, [], [{^registration, {:error, :injected}}]}}},
                   1_000
  end

  test "coordinator death cannot be converted to success during termination" do
    instance = instance()
    {pid, _} = participant(instance)
    stop_async(instance, 300)
    assert_receive {:drain, ^pid, _, _, coordinator, deadline}, 1_000
    Process.exit(coordinator, :kill)
    assert_receive {:drain, ^pid, _, _, replacement, ^deadline}, 1_000
    refute replacement == coordinator
    send(pid, {:settle, :ok})
    assert_receive {:stopped, {:error, {:cleanup_failed, {:coordinator_exit, :killed}}}}, 1_000
  end

  test "supervisor termination uses the combined participant barrier" do
    parent =
      start_supervised!(%{
        id: make_ref(),
        start: {Supervisor, :start_link, [[{Gaoxy, []}], [strategy: :one_for_one]]},
        type: :supervisor
      })

    [{_, instance, _, _}] = Supervisor.which_children(parent)
    {pid, registration} = participant(instance)
    owner = self()
    spawn(fn -> send(owner, {:supervisor_stopped, Supervisor.stop(parent)}) end)
    assert_receive {:drain, ^pid, ^registration, _, _, deadline}, 1_000
    assert Gaoxy.Lifecycle.remaining(deadline) > 0
    refute_receive {:supervisor_stopped, _}, 20
    send(pid, {:settle, :ok})
    assert_receive {:supervisor_stopped, :ok}, 1_000
    refute Process.alive?(instance)
  end

  defp instance, do: start_supervised!({Gaoxy, []}, id: make_ref())

  defp participant(instance) do
    pid = start_participant(instance)
    assert_receive {:registered, ^pid, {:ok, registration}}, 1_000
    assert_receive {:allocated, ^pid}, 1_000
    {pid, registration}
  end

  defp start_participant(instance, timeout \\ 1_000) do
    owner = self()

    pid =
      spawn(fn ->
        result = Gaoxy.register_lifecycle_participant(instance, timeout)
        send(owner, {:registered, self(), result})
        if match?({:ok, _}, result), do: send(owner, {:allocated, self()})
        participant_loop(owner, nil)
      end)

    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    pid
  end

  defp participant_loop(owner, drain) do
    receive do
      {:gaoxy_lifecycle_drain, registration, operation, coordinator, deadline} ->
        send(owner, {:drain, self(), registration, operation, coordinator, deadline})
        participant_loop(owner, {registration, operation, coordinator})

      {:register, instance, tag} ->
        send(owner, {tag, Gaoxy.register_lifecycle_participant(instance, 1_000)})
        participant_loop(owner, drain)

      {:settle, result} ->
        receipt(drain, result)
        participant_loop(owner, drain)

      {:settle_and_exit, result} ->
        receipt(drain, result)

      :die ->
        :ok
    end
  end

  defp receipt({registration, operation, coordinator}, result),
    do: send(coordinator, {:gaoxy_lifecycle_result, registration, operation, self(), result})

  defp stop_async(instance, timeout \\ 1_000) do
    owner = self()
    spawn(fn -> send(owner, {:stopped, Gaoxy.stop(instance, timeout)}) end)
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)

    unless predicate.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> eventually(predicate, deadline)
      end
    end
  end
end
