defmodule Gaoxy.AdmittedSpawnTest do
  use ExUnit.Case, async: false
  alias Gaoxy.{Admission, Lifecycle}

  @wait 2_000
  @parent_bytes 11
  @worker_bytes 100_000

  # This callback is entered by the real generic bootstrap through
  # apply(module, function, [lease | six_scalar_args]). It deliberately does
  # not handle owner/gate DOWN while blocked and does not alter lifecycle flags.
  def probe(lease, observer, id, token, gate, bytes, deadline) do
    status = Admission.status(gate)
    owned_update = Admission.update(gate, lease, bytes)
    send(observer, {:entered, self(), lease, id, token, deadline, status, owned_update})
    probe_loop(lease, observer, gate, bytes)
  end

  defp probe_loop(lease, observer, gate, bytes) do
    receive do
      :finish ->
        :ok

      {:crash, reason} ->
        exit(reason)

      {:grow, delta} ->
        result = Admission.update(gate, lease, bytes + delta)
        send(observer, {:grew, self(), result, bytes + delta})
        probe_loop(lease, observer, gate, bytes + delta)
    end
  end

  # The authenticated owner deliberately stops before dispatch. The admitted
  # callback cannot poll owner DOWN, so normal owner death needs Gate custody.
  def dispatch_probe(lease, observer, owner, token, gate, bytes, deadline) do
    :ok = Admission.update(gate, lease, bytes)
    send(observer, {:dispatch_waiting, self(), lease, owner, token, deadline})

    receive do
      {:dispatch, ^owner, ^token} ->
        send(observer, {:dispatch_entered, self(), token})
    after
      Lifecycle.remaining(deadline) -> exit(:fixture_dispatch_deadline)
    end
  end

  @tag :native_worker_constructor
  test "additive async admitted-spawn API has the settled arities without spawning" do
    assert_api!()
  end

  @tag :native_worker_constructor
  test "signed absolute deadline ETF widths are not unsigned byte-count widths" do
    assert :erlang.external_size(-1) == 6
    assert :erlang.external_size(0) == 3
    assert :erlang.external_size(-2_147_483_648) == 6
    assert :erlang.external_size(-2_147_483_649) == 8
    assert :erlang.external_size(2_147_483_647) == 6
    assert :erlang.external_size(2_147_483_648) == 8
  end

  test "W minus one refuses before any real child spawn; exact W gets one slot and owned lease" do
    assert_api!()
    {gate, _parent} = gate(max_bytes: @parent_bytes + @worker_bytes - 1)
    {owner, _lease, deadline} = owner(gate)
    trace_spawns(gate)
    token = make_ref()
    request(owner, token, @worker_bytes, deadline)
    assert_reply(owner, token, {:error, :byte_limit})
    assert_status(gate, 1, @parent_bytes)
    assert_no_spawn(gate)

    {exact, _parent} = gate(max_bytes: @parent_bytes + @worker_bytes, max_active: 2)
    {accepted_owner, parent_lease, accepted_deadline} = owner(exact)
    ref = committed_barrier(exact, accepted_owner)
    accepted_token = make_ref()
    request(accepted_owner, accepted_token, @worker_bytes, accepted_deadline)
    {worker, child_lease, state} = await_committed(ref, exact)
    own(worker)
    assert state.bytes == @parent_bytes + @worker_bytes
    assert map_size(state.leases) == 2
    assert state.leases[parent_lease].pid == accepted_owner

    assert %{
             pid: ^worker,
             bytes: @worker_bytes,
             request_active: true,
             drain_notify: true,
             deadline: ^accepted_deadline
           } = state.leases[child_lease]

    assert parent_lease != child_lease
    refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
    release_barrier(exact, ref)
    assert_reply(accepted_owner, accepted_token, {:ok, worker, child_lease})

    assert_entered(
      worker,
      child_lease,
      accepted_token,
      accepted_deadline,
      2,
      @parent_bytes + @worker_bytes
    )

    finish(worker)
    await_status(exact, 1, @parent_bytes)
  end

  test "existing active limit refuses without spawn or extra slot" do
    assert_api!()
    {gate, _} = gate(max_active: 1)
    {owner, _, deadline} = owner(gate)
    trace_spawns(gate)
    token = make_ref()
    request(owner, token, @worker_bytes, deadline)
    assert_reply(owner, token, {:error, :active_limit})
    assert_status(gate, 1, @parent_bytes)
    assert_no_spawn(gate)
  end

  test "a different live caller cannot use another parent's real lease" do
    assert_api!()
    {gate, _} = gate()
    {_owner, parent_lease, deadline} = owner(gate)
    trace_spawns(gate)
    token = make_ref()

    request_id =
      apply(Admission, :spawn_request, [
        gate,
        parent_lease,
        token,
        @worker_bytes,
        deadline,
        mfa(self(), token, gate, deadline)
      ])

    assert {:reply, {:error, :stale_generation}} =
             :gen_server.receive_response(request_id, @wait)

    assert_status(gate, 1, @parent_bytes)
    assert_no_spawn(gate)
  end

  for mode <- [:paused, :draining, :failed] do
    @mode mode
    test "mode #{@mode} refuses before spawn" do
      assert_api!()
      {gate, _} = gate()
      {owner, _, deadline} = owner(gate)
      assert :ok = Admission.mode(gate, @mode)
      trace_spawns(gate)
      token = make_ref()
      request(owner, token, @worker_bytes, deadline)
      assert_reply(owner, token, {:error, @mode})
      assert_status(gate, 1, @parent_bytes)
      assert_no_spawn(gate)
    end
  end

  test "expired absolute deadline refuses before spawn" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, _} = owner(gate)
    trace_spawns(gate)
    token = make_ref()
    request(owner, token, @worker_bytes, Lifecycle.now() - 1)
    assert_reply(owner, token, {:error, :deadline_exceeded})
    assert_status(gate, 1, @parent_bytes)
    assert_no_spawn(gate)
  end

  test "qualified live negative monotonic absolute deadline is accepted intact" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)

    assert deadline < 0,
           "qualification requires live negative monotonic D; do not change the API to D > 0"

    assert Lifecycle.remaining(deadline) > 0
    token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    assert :sys.get_state(gate, @wait).leases[lease].deadline == deadline
    finish(worker)
    await_status(gate, 1, @parent_bytes)
  end

  test "wrong activation ref cannot invoke callback before committed gate activation" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    ref = committed_barrier(gate, owner)
    token = make_ref()
    request(owner, token, @worker_bytes, deadline)
    {worker, lease, _state} = await_committed(ref, gate)
    own(worker)
    assert 1 == :erlang.trace(gate, true, [:send, {:tracer, self()}])
    wrong = {:gaoxy_admitted_worker_activate, make_ref(), lease}
    send(worker, wrong)
    # Secret is never supplied to owner. This unmatched message cannot substitute
    # for the real gate send. Entry after release must still occur exactly once.
    refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
    release_barrier(gate, ref)
    assert_reply(owner, token, {:ok, worker, lease})
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    trace_flush(gate)
    activations = drain_activations(gate, worker, [])
    assert [{:gaoxy_admitted_worker_activate, secret, ^lease}] = activations
    assert is_reference(secret)
    refute secret == elem(wrong, 1)
    send(worker, wrong)
    finish(worker)
    await_status(gate, 1, @parent_bytes)
    refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
  end

  for reason <- [:normal, :owner_failed] do
    @reason reason
    test "queued requester death #{@reason} before Gate callback cannot spawn" do
      assert_api!()
      {gate, _} = gate()
      {owner, _, deadline} = owner(gate)
      trace_spawns(gate)
      assert :ok = :sys.suspend(gate, @wait)

      try do
        request(owner, make_ref(), @worker_bytes, deadline)
        die_owner(owner, @reason)
      after
        assert :ok = :sys.resume(gate, @wait)
      end

      await_status(gate, 0, 0)
      assert_no_spawn(gate)
    end

    test "owner death #{@reason} after spawn before PID receipt cannot enter callback" do
      assert_api!()
      {gate, _} = gate()
      {owner, _, deadline} = owner(gate)
      ref = committed_barrier(gate, owner)
      token = make_ref()
      request(owner, token, @worker_bytes, deadline)
      {worker, _lease, state} = await_committed(ref, gate)
      own(worker)
      assert state.bytes == @parent_bytes + @worker_bytes
      worker_monitor = Process.monitor(worker)
      die_owner(owner, @reason)
      release_barrier(gate, ref)
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, @wait
      await_status(gate, 0, 0)
      refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
    end

    test "owner death #{@reason} kills an endpoint-blocked child without worker polling" do
      assert_api!()
      {gate, _} = gate()
      {owner, _, deadline} = owner(gate)
      token = make_ref()
      {worker, lease} = start_worker(owner, gate, token, deadline)
      assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
      monitor = Process.monitor(worker)
      die_owner(owner, @reason)
      assert_receive {:DOWN, ^monitor, :process, ^worker, _}, @wait
      await_status(gate, 0, 0)
      assert Process.alive?(gate)
    end
  end

  for reason <- [:normal, :gate_parent_failed] do
    @reason reason
    test "actual OTP start_link parent exit #{@reason} stops Gate and blocked child" do
      assert_api!()
      {gate, actual_parent} = gate()
      {owner, _, deadline} = owner(gate)
      token = make_ref()
      {worker, lease} = start_worker(owner, gate, token, deadline)
      assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
      gate_monitor = Process.monitor(gate)
      worker_monitor = Process.monitor(worker)
      parent_monitor = Process.monitor(actual_parent)
      send(actual_parent, {:die, @reason})
      assert_receive {:DOWN, ^parent_monitor, :process, ^actual_parent, @reason}, @wait
      assert_receive {:DOWN, ^gate_monitor, :process, ^gate, @reason}, @wait
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, @wait
    end
  end

  for reason <- [:normal, :pending_parent_failed] do
    @reason reason
    test "actual OTP parent exit #{@reason} kills tracked pre-activation child" do
      assert_api!()
      {gate, actual_parent} = gate()
      {owner, _, deadline} = owner(gate)
      ref = committed_barrier(gate, owner, hold_activation: true)
      token = make_ref()
      request(owner, token, @worker_bytes, deadline)
      {worker, _, _} = await_committed(ref, gate)
      own(worker)
      gate_monitor = Process.monitor(gate)
      worker_monitor = Process.monitor(worker)
      die_owner(actual_parent, @reason)
      # Actual parent EXIT is now queued while Gate is held after commit.
      release_barrier(gate, ref)
      assert_receive {:DOWN, ^gate_monitor, :process, ^gate, @reason}, @wait
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, @wait
      refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
    end
  end

  test "original finite watchdog kills endpoint-blocked worker without refund before pair" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, _} = owner(gate)
    deadline = Lifecycle.deadline(1_000)
    token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    assert :sys.get_state(gate, @wait).leases[lease].deadline == deadline
    monitor = Process.monitor(worker)
    # Await the real timer and direct :kill. There is no timer-envelope injection
    # and no sleep used to guess when a deadline passed.
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
    await_status(gate, 0, 0)
    assert Process.alive?(gate)
  end

  test "Gate kill bypasses terminate yet atomically linked endpoint-blocked child dies" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    assert {:links, links} = Process.info(worker, :links)
    assert gate in links
    assert {:trap_exit, false} = Process.info(worker, :trap_exit)
    gate_monitor = Process.monitor(gate)
    worker_monitor = Process.monitor(worker)
    Process.exit(gate, :kill)
    assert_receive {:DOWN, ^gate_monitor, :process, ^gate, :killed}, @wait
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, @wait
  end

  test "normal Gate stop explicitly kills pending child before activation" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    ref = committed_barrier(gate, owner, hold_activation: true)
    token = make_ref()
    request(owner, token, @worker_bytes, deadline)
    {worker, _, _} = await_committed(ref, gate)
    own(worker)
    worker_monitor = Process.monitor(worker)
    # A system terminate is queued before release. The real child is already
    # tracked; endpoint entry is forbidden by holding the private activation.
    observer = self()

    stopper =
      own(spawn(fn -> send(observer, {:normal_stop, GenServer.stop(gate, :normal, @wait)}) end))

    wait_system_request(gate)
    release_barrier(gate, ref)
    assert_receive {:normal_stop, :ok}, @wait
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, @wait
    join(stopper)
    refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
  end

  test "normal Gate stop kills an already endpoint-blocked child" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    monitor = Process.monitor(worker)
    assert :ok = GenServer.stop(gate, :normal, @wait)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
  end

  test "one child crash leaves Gate and another owner/sibling lease alive" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    # Use distinct owners: legacy native owner link deliberately makes a stream
    # crash kill its own native connection; shared Gate/sibling must be isolated.
    {sibling_owner, _, sibling_deadline} = owner(gate)
    token = make_ref()
    sibling_token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 3, 2 * @parent_bytes + @worker_bytes)
    {sibling, sibling_lease} = start_worker(sibling_owner, gate, sibling_token, sibling_deadline)

    assert_entered(
      sibling,
      sibling_lease,
      sibling_token,
      sibling_deadline,
      4,
      2 * @parent_bytes + 2 * @worker_bytes
    )

    monitor = Process.monitor(worker)
    send(worker, {:crash, :endpoint_failed})
    assert_receive {:DOWN, ^monitor, :process, ^worker, :endpoint_failed}, @wait
    await_status(gate, 2, @parent_bytes + @worker_bytes)
    assert Process.alive?(gate)
    assert Process.alive?(sibling_owner)
    assert Process.alive?(sibling)
    finish(sibling)
    await_status(gate, 1, @parent_bytes)
  end

  for first <- [:exit, :down] do
    @first first
    test "real terminal #{@first} first retains current W plus B until pair; refunds once" do
      assert_api!()
      {gate, _} = gate()
      {owner, _, deadline} = owner(gate)
      token = make_ref()
      {worker, lease} = start_worker(owner, gate, token, deadline)
      assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
      extra = 37_001
      send(worker, {:grow, extra})
      assert_receive {:grew, ^worker, :ok, grown}, @wait
      assert grown == @worker_bytes + extra
      assert_status(gate, 2, @parent_bytes + grown)
      ref = terminal_pair_barrier(gate, worker, lease)
      observer = self()
      reader = own(spawn(fn -> send(observer, {:status_trigger, Admission.status(gate)}) end))
      assert_receive {:terminal_waiting, ^ref}, @wait
      monitor = Process.monitor(worker)
      send(worker, :finish)
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @wait
      assert_receive {:terminal_captured, ^ref, actual_exit, actual_down}, @wait
      send(gate, {:terminal_first, ref, @first})
      assert_receive {:terminal_first_applied, ^ref, state}, @wait
      assert %{bytes: ^grown, pid: ^worker} = state.leases[lease]
      assert state.bytes == @parent_bytes + grown
      assert map_size(state.leases) == 2
      send(gate, {:terminal_rest, ref})
      assert_receive {:status_trigger, _}, @wait
      join(reader)
      await_status(gate, 1, @parent_bytes)
      # Duplicate real normal terminal envelopes cannot subtract again.
      send(gate, actual_exit)
      send(gate, actual_down)
      assert_status(gate, 1, @parent_bytes)
      assert Process.alive?(gate)
    end
  end

  test "same-sender cancel queued after spawn request wins before activation" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    trace_spawns(gate)
    assert :ok = :sys.suspend(gate, @wait)
    token = make_ref()

    try do
      request(owner, token, @worker_bytes, deadline)
      cancel(owner, token)
    after
      assert :ok = :sys.resume(gate, @wait)
    end

    assert_reply(owner, {:cancel, token}, :ok)
    assert_reply(owner, token, {:error, :cancelled})
    await_status(gate, 1, @parent_bytes)
    trace_flush(gate)

    for child <- spawned_children(gate, []) do
      own(child)
      assert not Process.alive?(child)
      refute_receive {:entered, ^child, _, _, _, _, _, _}, 0
    end
  end

  test "retiring original alias is local only; later authenticated cancel still joins worker" do
    assert_api!()
    {gate, _} = gate()
    # The real native connection traps exits through Hell.Handler;
    # it must survive the cancelled worker's linked :killed signal to read reply.
    {owner, _, deadline} = owner(gate, trap_exit: true)
    assert {:trap_exit, true} = Process.info(owner, :trap_exit)
    ref = committed_barrier(gate, owner)
    token = make_ref()
    original_id = request(owner, token, @worker_bytes, deadline)
    {worker, _lease, _} = await_committed(ref, gate)
    own(worker)
    worker_monitor = Process.monitor(worker)
    send(owner, {:retire, token})
    assert_receive {:retired, ^owner, ^token, :timeout}, @wait
    assert Process.alive?(worker)
    cancel(owner, token)
    release_barrier(gate, ref)
    assert_reply(owner, {:cancel, token}, :ok)
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, @wait
    await_status(gate, 1, @parent_bytes)
    assert not Process.alive?(worker)
    assert Process.alive?(owner)
    refute_receive {:reply, ^owner, ^token, _, _}, 0
    refute_receive {:owner_unmatched, ^owner, {[:alias | ^original_id], _}}, 0
  end

  test "non-scalar MFA config is rejected before spawn with a live authentic parent" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    trace_spawns(gate)
    token = make_ref()
    invalid_mfa = {__MODULE__, :probe, [self(), 1, token, gate, %{config: :not_scalar}, deadline]}
    send(owner, {:raw_request, token, @worker_bytes, deadline, invalid_mfa})
    assert_receive {:queued, ^owner, ^token, _}, @wait
    assert_reply(owner, token, {:error, :invalid_spawn_request})
    assert_status(gate, 1, @parent_bytes)
    assert_no_spawn(gate)
  end

  for reason <- [:normal, :owner_failed] do
    @reason reason
    test "authenticated success before dispatch retains child custody on owner #{@reason}" do
      assert_api!()
      {gate, _} = gate()
      {sibling, _, _} = owner(gate)
      {owner, parent_lease, deadline} = dispatch_owner(gate)
      token = make_ref()
      request_id = request(owner, token, @worker_bytes, deadline)

      assert_receive {:authenticated_before_dispatch, ^owner, ^request_id, raw, worker, lease},
                     @wait

      assert {[:alias | ^request_id], {:ok, ^worker, ^lease}} = raw
      own(worker)
      monitor = Process.monitor(worker)
      assert_receive {:dispatch_waiting, ^worker, ^lease, ^owner, ^token, ^deadline}, @wait
      state = :sys.get_state(gate, @wait)
      assert %{phase: :running, worker: ^worker, lease: ^lease} = state.spawns[token]
      assert state.leases[parent_lease].pid == owner
      assert state.leases[lease].pid == worker
      assert state.leases[lease].bytes == @worker_bytes
      assert_status(gate, 3, 2 * @parent_bytes + @worker_bytes)
      die_owner(owner, @reason)

      if @reason == :normal do
        assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
      else
        assert_receive {:DOWN, ^monitor, :process, ^worker, child_reason}, @wait
        assert child_reason in [@reason, :killed]
      end

      await_status(gate, 1, @parent_bytes)
      assert Process.alive?(sibling) and Process.alive?(gate)
      refute_receive {:dispatch_entered, ^worker, ^token}, 0
      die_owner(sibling, :normal)
      await_status(gate, 0, 0)
    end
  end

  for transition <- [:pause, :drain] do
    @transition transition
    test "committed child is refused when #{@transition} precedes its real activation" do
      assert_api!()
      {gate, _} = gate()
      {owner, _, deadline} = owner(gate, trap_exit: true)
      ref = committed_barrier(gate, owner, hold_activation: true, report_activation: true)
      token = make_ref()
      request(owner, token, @worker_bytes, deadline)
      {worker, lease, state} = await_committed(ref, gate)
      own(worker)
      monitor = Process.monitor(worker)
      assert_receive {:held_activation, ^ref, {:activate_spawn, ^token} = continuation}, @wait
      assert state.leases[lease].bytes == @worker_bytes
      assert state.bytes == @parent_bytes + @worker_bytes
      observer = self()
      command = if @transition == :pause, do: {:mode, :paused}, else: {:drain, deadline}

      {controller, controller_monitor} =
        spawn_monitor(fn ->
          result =
            if @transition == :pause,
              do: Admission.mode(gate, :paused),
              else: Admission.drain(gate, deadline)

          send(observer, {:transition_result, self(), result})
        end)

      own(controller)

      try do
        wait_gate_call(gate, command)
        # Queue the captured real continuation after the observed public call.
        send(gate, continuation)
      after
        release_barrier(gate, ref)
      end

      assert_receive {:transition_result, ^controller, :ok}, @wait
      assert_receive {:DOWN, ^controller_monitor, :process, ^controller, :normal}, @wait
      expected = if @transition == :pause, do: :paused, else: :draining
      assert_reply(owner, token, {:error, expected})
      assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
      await_status(gate, 1, @parent_bytes)
      refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
      assert Process.alive?(owner)
      die_owner(owner, :normal)
      await_status(gate, 0, 0)
    end
  end

  test "original deadline expires with a committed child before activation" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, _} = owner(gate, trap_exit: true)
    ref = committed_barrier(gate, owner)
    token = make_ref()
    deadline = Lifecycle.deadline(750)
    assert 1 == :erlang.trace(gate, true, [:send, {:tracer, self()}])
    request(owner, token, @worker_bytes, deadline)
    {worker, lease, state} = await_committed(ref, gate)
    own(worker)
    monitor = Process.monitor(worker)

    try do
      assert state.spawns[token].phase == :pending_activation
      assert state.leases[lease].deadline == deadline
      assert state.bytes == @parent_bytes + @worker_bytes
      # The genuine bootstrap timeout proves D passed while Gate still holds
      # the original activation ahead of its unconsumed terminal pair.
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @wait
      assert Lifecycle.remaining(deadline) == 0
    after
      release_barrier(gate, ref)
    end

    assert_reply(owner, token, {:error, :deadline_exceeded})
    await_status(gate, 1, @parent_bytes)
    trace_flush(gate)
    assert drain_activations(gate, worker, []) == []
    refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
    die_owner(owner, :normal)
    await_status(gate, 0, 0)
  end

  test "a different caller cannot cancel a live authentic owner's child" do
    assert_api!()
    {gate, _} = gate()
    {owner, parent_lease, deadline} = owner(gate)
    token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    request_id = apply(Admission, :cancel_spawn, [gate, parent_lease, token])

    assert {:reply, {:error, :stale_generation}} =
             :gen_server.receive_response(request_id, @wait)

    assert_status(gate, 2, @parent_bytes + @worker_bytes)
    assert Process.alive?(worker)
    finish(worker)
    await_status(gate, 1, @parent_bytes)
  end

  test "unknown non-parent normal link exit is ignored; abnormal link exit stops Gate" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    token = make_ref()
    {worker, lease} = start_worker(owner, gate, token, deadline)
    assert_entered(worker, lease, token, deadline, 2, @parent_bytes + @worker_bytes)
    normal_peer = linked_peer(gate)
    die_owner(normal_peer, :normal)
    assert_status(gate, 2, @parent_bytes + @worker_bytes)
    assert Process.alive?(worker)
    abnormal_peer = linked_peer(gate)
    gate_monitor = Process.monitor(gate)
    child_monitor = Process.monitor(worker)
    die_owner(abnormal_peer, :non_parent_link_failed)
    assert_receive {:DOWN, ^gate_monitor, :process, ^gate, :non_parent_link_failed}, @wait
    assert_receive {:DOWN, ^child_monitor, :process, ^worker, _}, @wait
  end

  test "Gate kill also kills the known pending child before first activation" do
    assert_api!()
    {gate, _} = gate()
    {owner, _, deadline} = owner(gate)
    ref = committed_barrier(gate, owner)
    token = make_ref()
    request(owner, token, @worker_bytes, deadline)
    {worker, _, state} = await_committed(ref, gate)
    own(worker)
    assert state.bytes == @parent_bytes + @worker_bytes
    monitor = Process.monitor(worker)
    Process.exit(gate, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
    refute_receive {:entered, ^worker, _, _, _, _, _, _}, 0
  end

  # All remaining functions are test fixture code. No production hooks required.
  defp assert_api! do
    assert Code.ensure_loaded?(Admission)
    assert function_exported?(Admission, :spawn_request, 6), "missing Admission.spawn_request/6"
    assert function_exported?(Admission, :cancel_spawn, 3), "missing Admission.cancel_spawn/3"
  end

  defp gate(options \\ []) do
    observer = self()
    ref = make_ref()

    limits = %{
      max_active: Keyword.get(options, :max_active, 16),
      max_bytes: Keyword.get(options, :max_bytes, 10_000_000),
      max_state: 65_536,
      callback_timeout: 10_000
    }

    parent =
      own(
        spawn(fn ->
          # Deliberately different from the genuine start_link parent.
          scope = %{
            service: "admitted-spawn",
            instance: observer,
            generation: make_ref(),
            service_pid: observer
          }

          {:ok, gate} = Admission.start_link({limits, scope})
          send(observer, {:fixture_gate, ref, self(), gate})

          receive do
            {:die, reason} -> exit(reason)
          after
            15_000 -> exit(:fixture_parent_deadline)
          end
        end)
      )

    assert_receive {:fixture_gate, ^ref, ^parent, gate}, @wait
    own(gate)
    {gate, parent}
  end

  defp owner(gate, options \\ []) do
    observer = self()

    owner =
      own(
        spawn(fn ->
          Process.flag(:trap_exit, Keyword.get(options, :trap_exit, false))
          {:ok, lease} = Admission.acquire(gate, @parent_bytes, drain_notify: true)
          deadline = Lifecycle.deadline(10_000)
          :ok = Admission.begin_request(gate, lease, @parent_bytes, deadline)
          send(observer, {:fixture_owner, self(), lease, deadline})
          owner_loop(observer, gate, lease, %{})
        end)
      )

    assert_receive {:fixture_owner, ^owner, lease, deadline}, @wait
    {owner, lease, deadline}
  end

  defp dispatch_owner(gate) do
    observer = self()

    owner =
      own(
        spawn(fn ->
          {:ok, lease} = Admission.acquire(gate, @parent_bytes, drain_notify: true)
          deadline = Lifecycle.deadline(10_000)
          :ok = Admission.begin_request(gate, lease, @parent_bytes, deadline)
          send(observer, {:fixture_owner, self(), lease, deadline})

          receive do
            {:request, token, bytes, ^deadline} ->
              request =
                Admission.spawn_request(
                  gate,
                  lease,
                  token,
                  bytes,
                  deadline,
                  {__MODULE__, :dispatch_probe, [observer, self(), token, gate, bytes, deadline]}
                )

              send(observer, {:queued, self(), token, request})

              receive do
                {[:alias | ^request], {:ok, worker, child_lease}} = message ->
                  {:reply, {:ok, ^worker, ^child_lease}} =
                    :gen_server.check_response(message, request)

                  send(
                    observer,
                    {:authenticated_before_dispatch, self(), request, message, worker,
                     child_lease}
                  )

                  receive do
                    {:die, reason} -> exit(reason)
                  after
                    @wait -> exit(:fixture_owner_dispatch_barrier_deadline)
                  end
              after
                @wait -> exit(:fixture_owner_success_deadline)
              end
          after
            @wait -> exit(:fixture_owner_request_deadline)
          end
        end)
      )

    assert_receive {:fixture_owner, ^owner, lease, deadline}, @wait
    {owner, lease, deadline}
  end

  defp owner_loop(observer, gate, lease, pending) do
    receive do
      {:request, token, bytes, deadline} ->
        reqid =
          apply(Admission, :spawn_request, [
            gate,
            lease,
            token,
            bytes,
            deadline,
            mfa(observer, token, gate, deadline, bytes)
          ])

        send(observer, {:queued, self(), token, reqid})
        owner_loop(observer, gate, lease, Map.put(pending, token, reqid))

      {:raw_request, token, bytes, deadline, callback_mfa} ->
        reqid =
          apply(Admission, :spawn_request, [gate, lease, token, bytes, deadline, callback_mfa])

        send(observer, {:queued, self(), token, reqid})
        owner_loop(observer, gate, lease, Map.put(pending, token, reqid))

      {:cancel, token} ->
        reqid = apply(Admission, :cancel_spawn, [gate, lease, token])
        send(observer, {:queued, self(), {:cancel, token}, reqid})
        owner_loop(observer, gate, lease, Map.put(pending, {:cancel, token}, reqid))

      {:retire, token} ->
        {reqid, pending} = Map.pop!(pending, token)
        result = :gen_server.receive_response(reqid, 0)
        send(observer, {:retired, self(), token, result})
        owner_loop(observer, gate, lease, pending)

      {:die, reason} ->
        exit(reason)

      message ->
        {matched, pending} =
          Enum.reduce(pending, {false, pending}, fn {key, reqid}, acc ->
            case :gen_server.check_response(message, reqid) do
              :no_reply ->
                acc

              result ->
                send(observer, {:reply, self(), key, message, result})
                {true, Map.delete(elem(acc, 1), key)}
            end
          end)

        if not matched, do: send(observer, {:owner_unmatched, self(), message})
        owner_loop(observer, gate, lease, pending)
    end
  end

  defp mfa(observer, token, gate, deadline, bytes \\ @worker_bytes),
    do: {__MODULE__, :probe, [observer, 1, token, gate, bytes, deadline]}

  defp request(owner, token, bytes, deadline) do
    send(owner, {:request, token, bytes, deadline})
    assert_receive {:queued, ^owner, ^token, reqid}, @wait
    assert is_reference(reqid)
    reqid
  end

  defp cancel(owner, token) do
    send(owner, {:cancel, token})
    assert_receive {:queued, ^owner, {:cancel, ^token}, reqid}, @wait
    reqid
  end

  defp assert_reply(owner, key, payload) do
    assert_receive {:reply, ^owner, ^key, raw, {:reply, ^payload}}, @wait
    assert {[:alias | request_id], ^payload} = raw
    assert is_reference(request_id)
    payload
  end

  defp start_worker(owner, gate, token, deadline) do
    request(owner, token, @worker_bytes, deadline)
    assert_receive {:reply, ^owner, ^token, raw, {:reply, {:ok, worker, lease}}}, @wait
    assert {[:alias | request_id], {:ok, ^worker, ^lease}} = raw
    assert is_reference(request_id)
    assert is_pid(worker) and is_reference(lease)
    own(worker)
    state = :sys.get_state(gate, @wait)
    assert state.leases[lease].pid == worker
    {worker, lease}
  end

  defp assert_entered(worker, lease, token, deadline, active, bytes) do
    assert_receive {:entered, ^worker, ^lease, 1, ^token, ^deadline, status, :ok}, @wait
    assert status.active == active
    assert status.retained_bytes == bytes
  end

  defp committed_barrier(gate, owner, options \\ []) do
    observer = self()
    ref = make_ref()

    debug = fn
      :armed, {:noreply, state}, _ ->
        case Enum.find(state.leases, fn {_, row} -> row.pid != owner end) do
          {lease, %{pid: worker}} ->
            if Keyword.get(options, :hold_activation, false) do
              # Hold the actual already-enqueued self-continuation so a real
              # system normal-stop request can be first when this hook returns.
              # Only used by the pending-normal-stop test; never fabricated.
              receive do
                {:activate_spawn, _} = continuation ->
                  if Keyword.get(options, :report_activation, false),
                    do: send(observer, {:held_activation, ref, continuation})
              after
                @wait -> exit(:test_real_activation_continuation_deadline)
              end
            end

            send(observer, {:committed, ref, self(), worker, lease, state})

            receive do
              {:release_barrier, ^ref} -> :done
            after
              @wait -> exit(:test_committed_barrier_deadline)
            end

          nil ->
            :armed
        end

      phase, _, _ ->
        phase
    end

    assert :ok = :sys.install(gate, {ref, debug, :armed}, @wait)
    ref
  end

  defp await_committed(ref, gate) do
    assert_receive {:committed, ^ref, ^gate, worker, lease, state}, @wait
    {worker, lease, state}
  end

  defp release_barrier(gate, ref), do: send(gate, {:release_barrier, ref})

  defp terminal_pair_barrier(gate, worker, lease) do
    observer = self()
    ref = make_ref()
    monitor = :sys.get_state(gate, @wait).leases[lease].monitor

    debug = fn
      :armed, {:in, {:"$gen_call", _, :status}}, _ ->
        send(observer, {:terminal_waiting, ref})

        exit_message =
          receive do
            {:EXIT, ^worker, _} = message -> message
          after
            @wait -> exit(:test_real_exit_deadline)
          end

        down_message =
          receive do
            {:DOWN, ^monitor, :process, ^worker, _} = message -> message
          after
            @wait -> exit(:test_real_down_deadline)
          end

        send(observer, {:terminal_captured, ref, exit_message, down_message})

        receive do
          {:terminal_first, ^ref, kind} when kind in [:exit, :down] ->
            {first, second} =
              if kind == :exit,
                do: {exit_message, down_message},
                else: {down_message, exit_message}

            send(self(), first)
            {:first_queued, first, second}
        after
          @wait -> exit(:test_terminal_order_deadline)
        end

      {:first_queued, first, second}, {:in, message}, _ when message == first ->
        {:first_running, second}

      {:first_running, second}, {:noreply, state}, _ ->
        send(observer, {:terminal_first_applied, ref, state})

        receive do
          {:terminal_rest, ^ref} -> send(self(), second)
        after
          @wait -> exit(:test_terminal_rest_deadline)
        end

        :done

      phase, _, _ ->
        phase
    end

    assert :ok = :sys.install(gate, {ref, debug, :armed}, @wait)
    ref
  end

  defp trace_spawns(gate) do
    assert 1 == :erlang.trace(gate, true, [:procs, {:tracer, self()}])
    # Trace flags are scoped to this test tracer and disappear with it.
  end

  defp trace_flush(pid) do
    ref = :erlang.trace_delivered(pid)
    assert_receive {:trace_delivered, ^pid, ^ref}, @wait
  end

  defp assert_no_spawn(gate) do
    trace_flush(gate)
    refute_receive {:trace, ^gate, :spawn, _, _}, 0
  end

  defp spawned_children(gate, acc) do
    receive do
      {:trace, ^gate, :spawn, child, _} -> spawned_children(gate, [child | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp drain_activations(gate, worker, acc) do
    receive do
      {:trace, ^gate, :send, {:gaoxy_admitted_worker_activate, _, _} = activation, ^worker} ->
        drain_activations(gate, worker, [activation | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp assert_status(gate, active, bytes) do
    assert %{active: ^active, retained_bytes: ^bytes} = Admission.status(gate)
  end

  defp await_status(gate, active, bytes, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)

    case Admission.status(gate) do
      %{active: ^active, retained_bytes: ^bytes} ->
        :ok

      _ ->
        assert Lifecycle.remaining(deadline) > 0,
               "real Gate did not reach the required terminal accounting barrier"

        await_status(gate, active, bytes, deadline)
    end
  end

  defp wait_system_request(gate, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    {:messages, messages} = Process.info(gate, :messages)

    if Enum.any?(messages, &match?({:system, _, _}, &1)) do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0
      wait_system_request(gate, deadline)
    end
  end

  defp wait_gate_call(gate, command, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    {:messages, messages} = Process.info(gate, :messages)

    unless Enum.any?(messages, &match?({:"$gen_call", _, ^command}, &1)) do
      assert Lifecycle.remaining(deadline) > 0, "public transition was not queued at Gate"
      wait_gate_call(gate, command, deadline)
    end
  end

  defp finish(worker) do
    ref = Process.monitor(worker)
    send(worker, :finish)
    assert_receive {:DOWN, ^ref, :process, ^worker, :normal}, @wait
  end

  defp die_owner(owner, reason) do
    ref = Process.monitor(owner)
    send(owner, {:die, reason})
    assert_receive {:DOWN, ^ref, :process, ^owner, ^reason}, @wait
  end

  defp linked_peer(gate) do
    observer = self()

    peer =
      own(
        spawn(fn ->
          Process.link(gate)
          send(observer, {:linked_peer, self()})

          receive do
            {:die, reason} -> exit(reason)
          after
            10_000 -> exit(:fixture_peer_deadline)
          end
        end)
      )

    assert_receive {:linked_peer, ^peer}, @wait
    peer
  end

  defp join(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, reason} when reason in [:normal, :noproc], @wait
  end

  defp own(pid) do
    on_exit(fn ->
      if Process.alive?(pid) do
        ref = Process.monitor(pid)
        # A prior failed assertion may leave a test-only sys debugger waiting;
        # forced fixture cleanup is not reported as successful product cleanup.
        Process.exit(pid, :kill)
        assert_receive {:DOWN, ^ref, :process, ^pid, _}, @wait
      end
    end)

    pid
  end
end
