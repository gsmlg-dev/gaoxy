defmodule Gaoxy.Proxy.ManagedH2FixedReleaseOrderTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  @moduletag :capture_log
  @timeout 5_000

  for protocol <- [:http2, :h2c] do
    @protocol protocol

    test "#{protocol} authentic Promise task DOWN leaves an unread body and original holds pending" do
      f = F.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = F.hold(f)
      :ok = :sys.suspend(guardian)
      on_exit(fn -> safe_resume(guardian) end)
      state = :sys.get_state(guardian)
      task = state.original_request.promise.task
      task_monitor = Process.monitor(task.pid)
      guardian_monitor = Process.monitor(guardian)
      {service, gate} = service(f)
      observe_calls(f.owner, guardian, state.transport_selection, service, state.token)
      suspend_pump_poll(gate, state.owner, state.token)
      retained = assert_pending_holds(f, guardian, completion)

      F.command(f.peer, seen, "respond", %{
        "fields" => [["content-length", "4"]],
        "ended" => false
      })

      assert_receive {:DOWN, ^task_monitor, :process, task_pid, :normal}, @timeout
      assert task_pid == task.pid
      task_ref = task.ref

      F.eventually(fn ->
        {:messages, messages} = Process.info(guardian, :messages)

        match?({^task_ref, %HTTP.Response{}}, List.keyfind(messages, task_ref, 0)) and
          {:DOWN, task_ref, :process, task_pid, :normal} in messages
      end)

      {:messages, messages} = Process.info(guardian, :messages)
      assert {^task_ref, %HTTP.Response{stream: stream}} = List.keyfind(messages, task_ref, 0)
      assert is_pid(stream)
      assert {:DOWN, task_ref, :process, task_pid, :normal} in messages

      # Only the published Task PID was monitored. System suspension prevents
      # a poll from consuming its real result before the guardian mailbox check.
      assert assert_pending_holds(f, guardian, completion) == retained
      refute_receive {:h2_release_call, :finish, _}, 0
      refute_receive {:h2_release_call, :receipt, _}, 0
      safe_resume_pump(state.owner)
      :ok = :sys.resume(guardian)
      assert F.h1_head(socket) =~ "200 OK"
      Session.cancel(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close_aborted(f, 1)
    end

    test "#{protocol} repeated integrated cancellation keeps one actual poll and finishes each hold once" do
      f = F.fixture(@protocol)
      {socket, seen, guardian, completion} = F.hold(f)
      {service, gate} = service(f)
      guardian_monitor = Process.monitor(guardian)
      :ok = :sys.suspend(guardian)
      on_exit(fn -> safe_resume(guardian) end)
      state = :sys.get_state(guardian)
      assert is_reference(state.poll_timer)
      {_, transport_token} = state.transport_selection
      observe_calls(f.owner, guardian, state.transport_selection, service, state.token)
      suspend_pump_poll(gate, state.owner, state.token)
      retained = assert_pending_holds(f, guardian, completion)
      for _ <- 1..16, do: Session.cancel(guardian)

      F.eventually(fn ->
        {:messages, messages} = Process.info(guardian, :messages)
        Process.read_timer(state.poll_timer) == false and :poll in messages
      end)

      {:messages, messages} = Process.info(guardian, :messages)
      assert Enum.count(messages, &(&1 == :poll)) == 1
      assert Enum.count(messages, &(&1 == {:"$gen_cast", :cancel})) == 16
      assert assert_pending_holds(f, guardian, completion) == retained
      refute_receive {:h2_release_call, :finish, _}, 0
      refute_receive {:h2_release_call, :receipt, _}, 0
      safe_resume_pump(state.owner)
      :ok = :sys.resume(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      # System replies follow this actor's observer messages and establish a
      # finite collection boundary; no sleep establishes the call counts.
      :sys.get_state(f.owner)
      :sys.get_state(service)
      assert collect_calls(:finish) == [transport_token]
      assert collect_calls(:receipt) == [state.token]
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      assert :ok = HTTP.RequestCompletion.abort_and_await(completion, 0)
      assert %{status: 200, body: "/sibling"} = F.request(f, "GET", "/sibling")
      sibling = F.event(f.peer, "request")
      assert sibling["connection"] == seen["connection"]
      F.close_aborted(f, 2)
    end

    test "#{protocol} normal release orders original completion token pin receipt and guardian DOWN" do
      f = F.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = F.hold(f)
      state = :sys.get_state(guardian)
      {service, gate} = service(f)
      [pin] = state.transport_pins
      initial_pins = :sys.get_state(f.owner).pins

      [pump_pin] =
        for {_, hold} <- initial_pins,
            hold.public.kind == :request and hold.public.holder == state.owner,
            do: hold.public

      baseline_pins = Map.drop(initial_pins, [pin.ref, pump_pin.ref])
      assert map_size(baseline_pins) == 1
      guardian_monitor = Process.monitor(guardian)
      owner_barrier = release_order_barrier(f.owner, guardian, state.transport_selection, pin)
      service_barrier = receipt_barrier(service, guardian, state.token)
      assert_pending_holds(f, guardian, completion)

      F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = F.response(f, socket)
      assert_receive {:h2_release_finish_held, owner}, @timeout
      assert owner == f.owner
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      refute_receive {:h2_release_pin_held, _, _}, 0
      refute_receive {:h2_release_receipt_held, _}, 0
      send(f.owner, {:h2_release_continue, owner_barrier})

      assert_receive {:h2_release_finish_confirmed, ^owner, 0, true}, @timeout
      assert_receive {:h2_release_pin_held, ^owner, ^pin}, @timeout
      assert %{cleanup_pending: 1, retained_bytes: bytes} = Gaoxy.status(f.instance, :http)
      assert bytes >= 9_444_956
      refute_receive {:h2_release_receipt_held, _}, 0
      send(f.owner, {:h2_release_continue, owner_barrier})

      assert_receive {:h2_release_pin_confirmed, ^owner, 0, false}, @timeout
      assert_receive {:h2_release_receipt_held, ^service}, @timeout
      assert {:ok, %{request_tokens: 0, pins: 2, helpers: 0}} = Transports.status(f.owner)
      receipt_pins = :sys.get_state(f.owner).pins
      refute Map.has_key?(receipt_pins, pin.ref)
      assert receipt_pins[pump_pin.ref].public == pump_pin
      assert Map.delete(receipt_pins, pump_pin.ref) == baseline_pins
      # Service is held before accepting the receipt. Its Gaoxy Admission
      # ledger remains callable and still owns the cleanup reserve.
      assert %{retained_bytes: bytes} = GenServer.call(gate, :status, @timeout)
      assert bytes >= 9_444_956
      refute_receive {:DOWN, ^guardian_monitor, :process, ^guardian, _}, 0
      send(service, {:h2_release_continue, service_barrier})
      assert_receive {:h2_release_receipt_confirmed, ^service, :ok, true}, @timeout
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert :sys.get_state(f.owner).pins == baseline_pins
      assert {:ok, %{request_tokens: 0, pins: 1, helpers: 0}} = Transports.status(f.owner)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      F.close(f)
    end
  end

  test "published response Stream death retains original uncertainty and a missing Service receipt" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, guardian, completion} = F.hold(f)
    {service, _gate} = service(f)
    state = :sys.get_state(guardian)
    observe_calls(f.owner, guardian, state.transport_selection, service, state.token)
    assert :sys.get_state(service).cleanups[state.token].receipt == false
    barrier = missing_receipt_barrier(service, guardian, state.token)
    guardian_monitor = Process.monitor(guardian)
    custodians = own_custodians(f.owner)
    actor_monitors = monitor_all([f.owner | custodians])
    on_exit(fn -> stop_failed_actors(f.owner, custodians) end)
    assert_pending_holds(f, guardian, completion)
    F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "4"]], "ended" => false})
    assert F.h1_head(socket) =~ "200 OK"
    stream = :sys.get_state(guardian).request.stream
    assert is_pid(stream)
    stream_monitor = Process.monitor(stream)
    # This is the public Response stream PID, never a private connection or
    # delivery process discovered by inspecting the dependency.
    Process.exit(stream, :kill)
    assert_receive {:DOWN, ^stream_monitor, :process, ^stream, :killed}, @timeout
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    Session.cancel(guardian)

    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian,
                    {:cleanup_failed, :cleanup_unconfirmed}},
                   @timeout

    assert_receive {:h2_release_down_held, ^service, ^guardian,
                    {:cleanup_failed, :cleanup_unconfirmed}},
                   @timeout

    F.eventually(fn ->
      match?({:ok, %{request_tokens: 1, pins: 1, helpers: 0}}, Transports.status(f.owner))
    end)

    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert hold.completion == completion
    assert hold.guardian_down
    assert hold.abort_helper == nil
    refute_receive {:h2_release_call, :finish, _}, 0
    refute_receive {:h2_release_call, :receipt, _}, 0
    :ok = :gen_tcp.close(socket)
    stop_uncertain_fixture(f, service, barrier, completion, custodians, actor_monitors)
  end

  test "instance death confirms the original request but cannot manufacture a Service receipt" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, _seen, guardian, completion} = F.hold(f)
    state = :sys.get_state(guardian)
    {service, _gate} = service(f)
    observe_calls(f.owner, guardian, state.transport_selection, service, state.token)
    {_, transport_token} = state.transport_selection
    owner_state = :sys.get_state(f.owner)
    [entry] = Map.values(owner_state.records)
    custodian = entry.custodian
    capability = entry.capability
    on_exit(fn -> stop_failed_actors(f.owner, [custodian]) end)

    custodian_barrier =
      install_barrier(custodian, fn
        false, {:in, {:retire, ^capability, :graceful, _}} ->
          {{:h2_release_custodian_retire_held, custodian}, true}

        held, _ ->
          {nil, held}
      end)

    owner_barrier = down_barrier(f.owner, f.instance, owner_state.instance_monitor)
    monitors = monitor_all([f.instance, service, f.owner, guardian, custodian])
    assert_pending_holds(f, guardian, completion)
    :ok = :sys.suspend(guardian)
    on_exit(fn -> safe_resume(guardian) end)
    owner = f.owner
    instance = f.instance
    Process.exit(instance, :kill)
    assert_down(monitors, instance, :killed)
    assert_receive {:h2_release_down_held, ^owner, ^instance, :killed}, @timeout
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    assert owner_state.tokens[transport_token].completion == completion
    assert_down(monitors, service, :shutdown)
    refute_receive {:h2_release_call, :receipt, _}, 0
    send(owner, {:h2_release_continue, owner_barrier})
    assert_receive {:h2_release_custodian_retire_held, ^custodian}, @timeout

    # Original abort joins while the real scope creator remains alive. Scope
    # retirement cannot make the transport owner disappear before Service fails.
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

    F.eventually(fn ->
      match?({:ok, %{request_tokens: 0, pins: 0, helpers: 0}}, Transports.status(owner))
    end)

    assert :sys.get_state(guardian).original_request.completion == completion
    :ok = :sys.resume(guardian)

    assert_down(monitors, guardian, {:cleanup_failed, {:service_cleanup_failed, :unavailable}})
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    :sys.get_state(owner)
    assert collect_calls(:finish) == [transport_token]
    refute_receive {:h2_release_call, :receipt, _}, 0
    send(custodian, {:h2_release_continue, custodian_barrier})
    assert_down(monitors, custodian, :normal)
    assert_down(monitors, owner, :normal)
    assert :ok = HTTP.RequestCompletion.await(completion, 0)
    refute_receive {:h2_release_call, :receipt, _}, 0
    :ok = :gen_tcp.close(socket)
    stop_embedding(f, {:error, :not_running})
    F.physical_termination(f.peer)
    stop_peer(f.peer, 1)
  end

  test "published Stream death before instance collapse preserves original uncertainty and no Service receipt" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    {socket, seen, guardian, completion} = F.hold(f)
    state = :sys.get_state(guardian)
    {service, _gate} = service(f)
    observe_calls(f.owner, guardian, state.transport_selection, service, state.token)
    owner_state = :sys.get_state(f.owner)
    custodians = own_custodians(f.owner)
    on_exit(fn -> stop_failed_actors(f.owner, custodians) end)

    owner_barrier = down_barrier(f.owner, f.instance, owner_state.instance_monitor)
    monitors = monitor_all([f.instance, service, f.owner, guardian | custodians])
    owner = f.owner
    instance = f.instance
    assert_pending_holds(f, guardian, completion)
    F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "4"]], "ended" => false})
    assert F.h1_head(socket) =~ "200 OK"
    :ok = :sys.suspend(guardian)
    on_exit(fn -> safe_resume(guardian) end)
    stream = :sys.get_state(guardian).request.stream
    assert is_pid(stream)
    assert :sys.get_state(guardian).original_request.completion == completion
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    stream_monitor = Process.monitor(stream)
    # Kill only the published Response Stream. Its genuine original completion
    # is already uncertain before instance death introduces further cleanup.
    Process.exit(stream, :kill)
    assert_receive {:DOWN, ^stream_monitor, :process, ^stream, :killed}, @timeout
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    Process.exit(f.instance, :kill)
    assert_down(monitors, f.instance, :killed)
    assert_receive {:h2_release_down_held, ^owner, ^instance, :killed}, @timeout
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    assert Map.values(owner_state.tokens) |> Enum.map(& &1.completion) == [completion]
    # The real Service has terminated while its Gaoxy guardian is suspended.
    # No late receipt can turn original uncertainty into successful cleanup.
    assert_down(monitors, service, :shutdown)
    refute_receive {:h2_release_call, :receipt, _}, 0
    send(f.owner, {:h2_release_continue, owner_barrier})
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    :ok = :sys.resume(guardian)
    assert_down(monitors, guardian, {:cleanup_failed, :cleanup_unconfirmed})

    F.eventually(fn ->
      match?({:ok, %{request_tokens: 1, pins: 0, helpers: 0}}, Transports.status(f.owner))
    end)

    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert hold.completion == completion
    assert hold.guardian == guardian
    assert hold.guardian_down
    assert hold.abort_helper == nil
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    refute_receive {:h2_release_call, :finish, _}, 0
    refute_receive {:h2_release_call, :receipt, _}, 0
    :ok = :gen_tcp.close(socket)
    stop_embedding(f, {:error, :not_running})

    # Published Stream cleanup remains unconfirmed with the original token held.
    # Joining failed test-owned Gaoxy actors below is explicit disposal only.
    stop_failed_actors(f.owner, custodians)
    assert_down(monitors, f.owner, :normal)

    for {pid, _} <- monitors,
        pid not in [f.instance, service, f.owner, guardian],
        do: assert_down(monitors, pid, :normal)

    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    refute_receive {:h2_release_call, :receipt, _}, 0
    F.physical_termination(f.peer)
    stop_peer(f.peer, 1)
  end

  defp service(f) do
    assert {:ok, pid, _} = GenServer.call(f.instance, {:lookup, :http}, @timeout)
    {pid, :sys.get_state(pid).gate}
  end

  defp assert_pending_holds(f, guardian, completion) do
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    assert {:ok, %{request_tokens: 1, pins: 3, helpers: 0}} = Transports.status(f.owner)
    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert hold.guardian == guardian
    assert hold.completion == completion
    pins = :sys.get_state(f.owner).pins |> Map.values() |> Enum.map(& &1.public)
    assert Enum.count(pins, &(&1.holder == guardian and &1.kind == :request)) == 1

    assert %{cleanup_pending: 1, retained_bytes: bytes, cleanup_failed: nil} =
             Gaoxy.status(f.instance, :http)

    assert bytes >= 9_444_956
    bytes
  end

  defp suspend_pump_poll(gate, pump, token) do
    caller = self()
    lease = :sys.get_state(gate).cleanups[token].lease
    debug_id = make_ref()

    debug = fn held, event, _ ->
      case {held, event} do
        {false, {:in, {:"$gen_call", {^pump, _}, {:update, ^lease, bytes}}}} ->
          send(caller, {:h2_release_pump_poll_held, pump, lease, bytes})
          await_release(debug_id)
          true

        _ ->
          held
      end
    end

    on_exit(fn ->
      send(gate, {:h2_release_continue, debug_id})
      safe_resume_pump(pump)
    end)

    bytes =
      try do
        :ok = :sys.install(gate, {debug_id, debug, false}, @timeout)
        assert_receive {:h2_release_pump_poll_held, ^pump, ^lease, bytes}, @timeout
        # The test suspends its Gaoxy H1 pump while the synchronous update is
        # blocked. Releasing the gate settles that real charge before status.
        assert :erlang.suspend_process(pump)
        bytes
      after
        send(gate, {:h2_release_continue, debug_id})

        try do
          :sys.remove(gate, debug_id, @timeout)
        catch
          :exit, _ -> :ok
        end
      end

    state = :sys.get_state(gate, @timeout)
    assert [^lease] = Map.keys(state.leases)
    assert [^token] = Map.keys(state.cleanups)
    assert state.leases[lease].pid == pump
    assert state.leases[lease].bytes == bytes
    assert state.cleanups[token].bytes == 9_444_956
    assert state.cleanups[token].receipt == false
    assert state.bytes == bytes + state.cleanups[token].bytes
  end

  defp safe_resume_pump(pump) do
    :erlang.resume_process(pump)
  catch
    :error, :badarg -> :ok
  end

  defp down_barrier(pid, target, monitor) do
    install_barrier(pid, fn
      false, {:in, {:DOWN, ref, :process, ^target, reason}}
      when monitor == nil or ref == monitor ->
        {{:h2_release_down_held, pid, target, reason}, true}

      held, _ ->
        {nil, held}
    end)
  end

  defp install_barrier(pid, match) do
    caller = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      {message, next} = match.(held, event)

      if message do
        send(caller, message)
        await_release(barrier)
      end

      next
    end

    :ok = :sys.install(pid, {make_ref(), debug, false})
    on_exit(fn -> send(pid, {:h2_release_continue, barrier}) end)
    barrier
  end

  defp missing_receipt_barrier(service, guardian, token) do
    caller = self()
    barrier = make_ref()

    debug = fn phase, event, _ ->
      case {phase, event} do
        {:start, {:in, {:DOWN, _, :process, ^guardian, reason}}} ->
          send(caller, {:h2_release_down_held, service, guardian, reason})
          await_release(barrier)
          :handling

        {:handling, {:noreply, app_state}} ->
          send(
            caller,
            {:h2_release_missing_receipt, service, app_state.cleanup_failed,
             Map.has_key?(app_state.cleanups, token), app_state.drain.outcome}
          )

          await_release(barrier)
          :done

        _ ->
          phase
      end
    end

    :ok = :sys.install(service, {make_ref(), debug, :start})

    on_exit(fn ->
      send(service, {:h2_release_continue, barrier})
      send(service, {:h2_release_continue, barrier})
    end)

    barrier
  end

  defp release_order_barrier(owner, guardian, {handle, token}, pin) do
    caller = self()
    barrier = make_ref()

    debug = fn phase, event, _ ->
      case {phase, event} do
        {:start, {:in, {:"$gen_call", {^guardian, _}, {:finish, ^handle, ^token}}}} ->
          send(caller, {:h2_release_finish_held, owner})
          await_release(barrier)
          :finishing

        {:finishing, {:out, :ok, _, app_state}} ->
          send(
            caller,
            {:h2_release_finish_confirmed, owner, map_size(app_state.tokens),
             Map.has_key?(app_state.pins, pin.ref)}
          )

          :releasing

        {:releasing, {:in, {:"$gen_call", {^guardian, _}, {:release, ^pin}}}} ->
          send(caller, {:h2_release_pin_held, owner, pin})
          await_release(barrier)
          :released

        {:released, {:out, :ok, _, app_state}} ->
          send(
            caller,
            {:h2_release_pin_confirmed, owner, map_size(app_state.tokens),
             Map.has_key?(app_state.pins, pin.ref)}
          )

          :done

        _ ->
          phase
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, :start})

    on_exit(fn ->
      send(owner, {:h2_release_continue, barrier})
      send(owner, {:h2_release_continue, barrier})
    end)

    barrier
  end

  defp receipt_barrier(service, guardian, token) do
    caller = self()
    barrier = make_ref()

    debug = fn phase, event, _ ->
      case {phase, event} do
        {:start, {:in, {:"$gen_call", {^guardian, _}, {:complete_cleanup, ^token}}}} ->
          send(caller, {:h2_release_receipt_held, service})
          await_release(barrier)
          :receiving

        {:receiving, {:out, result, _, app_state}} ->
          send(
            caller,
            {:h2_release_receipt_confirmed, service, result, app_state.cleanups[token].receipt}
          )

          :done

        _ ->
          phase
      end
    end

    :ok = :sys.install(service, {make_ref(), debug, :start})
    on_exit(fn -> send(service, {:h2_release_continue, barrier}) end)
    barrier
  end

  defp observe_calls(owner, guardian, {handle, transport_token}, service, service_token) do
    caller = self()

    for {pid, message, kind, token} <- [
          {owner, {:finish, handle, transport_token}, :finish, transport_token},
          {service, {:complete_cleanup, service_token}, :receipt, service_token}
        ] do
      debug = fn state, event, _ ->
        case event do
          {:in, {:"$gen_call", {^guardian, _}, ^message}} ->
            send(caller, {:h2_release_call, kind, token})

          _ ->
            :ok
        end

        state
      end

      :ok = :sys.install(pid, {make_ref(), debug, nil})
    end
  end

  defp collect_calls(kind) do
    receive do
      {:h2_release_call, ^kind, token} -> [token | collect_calls(kind)]
    after
      0 -> []
    end
  end

  defp await_release(barrier) do
    receive do
      {:h2_release_continue, ^barrier} -> :ok
    after
      @timeout -> raise "fixed H2 release-order barrier expired"
    end
  end

  defp own_custodians(owner),
    do: :sys.get_state(owner).records |> Map.values() |> Enum.map(& &1.custodian)

  defp monitor_all(pids), do: Enum.map(pids, &{&1, Process.monitor(&1)})

  defp assert_down(monitors, pid, reason) do
    {^pid, monitor} = List.keyfind(monitors, pid, 0)
    assert_receive {:DOWN, ^monitor, :process, ^pid, ^reason}, @timeout
  end

  defp safe_resume(pid) do
    if Process.alive?(pid), do: :sys.resume(pid, @timeout)
  catch
    :exit, _ -> :ok
  end

  defp stop_uncertain_fixture(f, service, barrier, completion, custodians, monitors) do
    embedding_monitor = Process.monitor(f.embedding)
    instance_monitor = Process.monitor(f.instance)
    send(f.embedding, {:stop, self()})

    F.eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)

    send(service, {:h2_release_continue, barrier})

    assert_receive {:h2_release_missing_receipt, ^service, :cleanup_receipt_missing, false,
                    {:cleanup_failed, :cleanup_receipt_missing}},
                   @timeout

    refute_receive {:h2_release_call, :receipt, _}, 0
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert hold.completion == completion
    send(service, {:h2_release_continue, barrier})

    assert_receive {:fixed_h2_embedding_stopped, embedding,
                    {:error, {:deadline_exceeded, :cleanup_pending}}},
                   2 * @timeout

    assert embedding == f.embedding
    assert_receive {:DOWN, ^embedding_monitor, :process, ^embedding, :normal}, @timeout
    assert_receive {:DOWN, ^instance_monitor, :process, instance, :normal}, @timeout
    assert instance == f.instance
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    assert {:ok, retirement} = Transports.retire(f.owner, F.deadline())

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.await_retirement(retirement, F.deadline())

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.await_retirement(retirement, F.deadline())

    F.eventually(fn ->
      match?(
        {:ok,
         %{
           resources: 1,
           reserved_connections: 0,
           failed_resources: 0,
           request_tokens: 1,
           helpers: 0,
           pins: 0
         }},
        Transports.status(f.owner)
      )
    end)

    [entry] = :sys.get_state(f.owner).records |> Map.values()
    assert entry.transport_confirmed
    assert entry.custodian_down
    assert map_size(entry.helpers) == 0
    [hold] = :sys.get_state(f.owner).tokens |> Map.values()
    assert hold.completion == completion
    assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
    refute_receive {:h2_release_call, :receipt, _}, 0
    # Gaoxy's physical transport receipt and custodian join are confirmed,
    # while its owner still retains the unconfirmed original request token.
    # The negative receipts and retained ledger were proved above. Stopping
    # failed test-owned Gaoxy actors is teardown, never successful retirement.
    stop_failed_actors(f.owner, custodians)
    for {pid, _} <- monitors, do: assert_down(monitors, pid, :normal)
    F.physical_termination(f.peer)
    stop_peer(f.peer, 1)
  end

  defp stop_failed_actors(owner, custodians) do
    for pid <- custodians ++ [owner] do
      if Process.alive?(pid), do: GenServer.stop(pid, :normal, @timeout)
    end
  end

  defp stop_embedding(f, expected) do
    monitor = Process.monitor(f.embedding)
    send(f.embedding, {:stop, self()})
    assert_receive {:fixed_h2_embedding_stopped, embedding, ^expected}, 2 * @timeout
    assert embedding == f.embedding
    assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
  end

  defp stop_peer(peer, requests) do
    monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})

    assert %{"forced" => 0, "live" => 0, "failed" => false, "requests" => ^requests} =
             F.event(peer, "joined")

    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
  end
end
