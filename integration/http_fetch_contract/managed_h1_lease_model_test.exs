ExUnit.start(autorun: false)
ExUnit.configure(seed: 21_112_026, max_cases: 1)
Code.require_file("managed_h1_lease_model.exs", __DIR__)

defmodule Gaoxy.Qualification.ManagedH1LeaseModelTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Qualification.ManagedH1LeaseModel, as: Model

  @max_time 9_223_372_036_854_775_807
  @generation_roots [:policy_source, :policy_prepared, :custodian, :scope, :shared_controls]
  @attempt_roots [
    :source,
    :prepared,
    :upstream,
    :helpers,
    :parser_batch,
    :terminal,
    :upload_source,
    :response_consumer
  ]
  @snapshot_keys [
    :qualification,
    :generation_slots,
    :occupied_generations,
    :attempt_slots_per_generation,
    :occupied_attempts,
    :held_roots,
    :held_chunks,
    :issued_controls,
    :outstanding_controls
  ]

  test "generation reservation precedes roots" do
    state = fresh()
    ghost = {:generation, 0, make_ref()}
    unchanged(state, {:retain_root, ghost, :policy_source}, :stale)
    unchanged(state, {:begin_control, ghost, :open}, :stale)
    {state, generation} = apply_event(state, {:reserve_generation, 100})
    {state, root} = apply_event(state, {:retain_root, generation, :policy_source})
    rejected(state, {:release_generation, generation}, :ownership_pending)
    state = applied(state, {:generation_failed, generation, :not_opened})
    unchanged(state, {:generation_failed, generation, :not_opened}, :duplicate)
    rejected(state, {:release_generation, generation}, :ownership_pending)
    state = applied(state, {:release_root, root})
    unchanged(state, {:release_root, root}, :stale)
    state = applied(state, {:release_generation, generation})
    assert Model.snapshot(state).occupied_generations == 0
  end

  test "four generation phases reject fifth" do
    state = fresh()
    {state, preparing} = apply_event(state, {:reserve_generation, 100})
    {state, ready} = ready_generation(state)
    {state, retiring} = ready_generation(state)
    state = applied(state, {:retire_generation, retiring, 200})
    {state, uncertain} = apply_event(state, {:reserve_generation, 100})
    state = applied(state, {:generation_unconfirmed, uncertain})
    assert generation(state, preparing).phase == :preparing
    assert generation(state, ready).phase == :ready
    assert generation(state, retiring).phase == :retiring
    assert generation(state, uncertain).phase == :cleanup_hold
    unchanged(state, {:reserve_generation, 100}, :busy)
    assert Model.snapshot(state).occupied_generations == 4
  end

  test "thirty two leases precede preparation" do
    {state, generation} = ready_generation(fresh())
    ghost = {:attempt, generation, 0, make_ref()}
    unchanged(state, {:prepare_attempt, ghost}, :stale)
    unchanged(state, {:retain_root, ghost, :source}, :stale)

    state =
      Enum.reduce(0..31, state, fn index, state ->
        {state, attempt} = apply_event(state, {:acquire_attempt, generation, 100})
        assert elem(attempt, 2) == index
        rejected(state, {:prepare_attempt, attempt}, :ownership_pending)

        if rem(index, 2) == 0 do
          {state, _root} = apply_event(state, {:retain_root, attempt, :source})
          applied(state, {:prepare_attempt, attempt})
        else
          state
        end
      end)

    unchanged(state, {:acquire_attempt, generation, 100}, :busy)
    assert Model.snapshot(state).occupied_attempts == {32, 0, 0, 0}
    assert Model.snapshot(state).held_roots == 18
    assert Model.snapshot(state).issued_controls == 1
  end

  test "prelaunch rejection keeps captured roots charged" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = apply_event(state, {:acquire_attempt, generation, 100})
    {state, source} = apply_event(state, {:retain_root, attempt, :source})
    {state, helpers} = apply_event(state, {:retain_root, attempt, :helpers})
    state = applied(state, {:prepare_attempt, attempt})
    {state, prepared} = apply_event(state, {:retain_root, attempt, :prepared})
    state = applied(state, {:reject_attempt, attempt})
    unchanged(state, {:reject_attempt, attempt}, :duplicate)
    assert attempt(state, attempt).outcome == :rejected
    assert attempt(state, attempt).completion == :not_launched
    rejected(state, {:release_attempt, attempt}, :ownership_pending)

    state =
      Enum.reduce([source, helpers, prepared], state, fn root, state ->
        applied(state, {:release_root, root})
      end)

    state = applied(state, {:release_attempt, attempt})
    assert Model.snapshot(state).occupied_attempts == {0, 0, 0, 0}

    for phase <- [:reserved, :preparing] do
      {state, generation} = ready_generation(fresh())
      {state, old} = apply_event(state, {:acquire_attempt, generation, 10})
      {state, source} = apply_event(state, {:retain_root, old, :source})
      {state, helpers} = apply_event(state, {:retain_root, old, :helpers})

      state =
        if phase == :preparing do
          state = applied(state, {:prepare_attempt, old})
          {state, _prepared} = apply_event(state, {:retain_root, old, :prepared})
          state
        else
          state
        end

      original = attempt(state, old)
      state = applied(state, {:advance, 9})
      assert attempt(state, old) == original
      state = applied(state, {:advance, 10})
      expired = %{original | outcome: :timed_out, phase: :cleanup_hold}
      assert attempt(state, old) == expired
      rejected(state, {:release_attempt, old}, :ownership_pending)
      rejected(state, {:request_completed, old}, :invalid_phase)
      rejected(state, {:begin_control, old, :initial_wait}, :invalid_phase)
      without_roots = clear_roots(state, old)
      rejected(without_roots, {:release_attempt, old}, :invalid_phase)
      assert attempt(without_roots, old).completion == :none

      counts = Model.snapshot(state)
      state = applied(state, {:reject_attempt, old})
      terminal = %{expired | completion: :not_launched, phase: :releasing}
      assert attempt(state, old) == terminal
      assert Model.snapshot(state) == counts
      assert terminal.controls == %{initial_wait: :unused, abort_wait: :unused}
      unchanged(state, {:reject_attempt, old}, :duplicate)
      rejected(state, {:release_attempt, old}, :ownership_pending)

      held = applied(state, {:owner_down, old})
      assert :ok = Model.invariants(held)
      assert attempt(held, old) == %{terminal | lost_proof: true, phase: :cleanup_hold}
      assert Model.snapshot(held) == counts
      unchanged(held, {:owner_down, old}, :duplicate)
      unchanged(held, {:reject_attempt, old}, :duplicate)
      rejected(held, {:release_attempt, old}, :lost_proof)
      held = clear_roots(held, old)
      assert Enum.all?(Map.values(attempt(held, old).roots), &is_nil/1)
      assert attempt(held, old).completion == :not_launched
      assert attempt(held, old).outcome == :timed_out
      assert attempt(held, old).deadline == 10
      assert attempt(held, old).chunks == terminal.chunks
      assert attempt(held, old).controls == terminal.controls
      rejected(held, {:release_attempt, old}, :lost_proof)
      assert Model.snapshot(held).occupied_attempts == counts.occupied_attempts

      state = applied(state, {:advance, 11})
      assert attempt(state, old) == terminal
      state = applied(state, {:release_root, source})
      rejected(state, {:release_attempt, old}, :ownership_pending)
      state = clear_roots(state, old)
      assert attempt(state, old).outcome == :timed_out
      assert attempt(state, old).deadline == 10
      state = applied(state, {:release_attempt, old})
      assert Model.snapshot(state).occupied_attempts == {0, 0, 0, 0}
      {state, current} = apply_event(state, {:acquire_attempt, generation, 20})
      {state, current_source} = apply_event(state, {:retain_root, current, :source})
      assert elem(current, 2) == elem(old, 2)
      refute elem(current, 3) == elem(old, 3)
      assert attempt(state, current).roots.source == current_source

      for event <- [
            {:attempt_result, old, :ok},
            {:request_completed, old},
            {:release_root, source},
            {:release_root, helpers},
            {:reject_attempt, old},
            {:release_attempt, old}
          ] do
        unchanged(state, event, :stale)
      end

      assert Model.snapshot(state).occupied_attempts == {1, 0, 0, 0}
    end

    for issued_control <- [false, true] do
      {state, generation} = ready_generation(fresh())
      {state, launched} = launched_attempt(state, generation, 10)

      state =
        if issued_control do
          {state, _control} = apply_event(state, {:begin_control, launched, :initial_wait})
          state
        else
          state
        end

      state = applied(state, {:advance, 10})
      rejected(state, {:reject_attempt, launched}, :invalid_phase)
      assert attempt(state, launched).completion == :none
      state = clear_roots(state, launched)

      if issued_control do
        state = applied(state, {:request_completed, launched})
        rejected(state, {:reject_attempt, launched}, :invalid_phase)
        rejected(state, {:release_attempt, launched}, :ownership_pending)
        assert attempt(state, launched).controls.initial_wait.result == :pending
        refute attempt(state, launched).controls.initial_wait.helper_released
        refute attempt(state, launched).controls.initial_wait.frontier_released
      else
        rejected(state, {:release_attempt, launched}, :invalid_phase)
      end
    end

    for {lost_at, event, completion, outcome} <- [
          {:before_expiry, :attempt_unconfirmed, :unconfirmed, :timed_out},
          {:after_expiry, :attempt_unconfirmed, :unconfirmed, :timed_out},
          {:before_expiry, :owner_down, :none, :failed},
          {:after_expiry, :owner_down, :none, :timed_out}
        ] do
      {state, generation} = ready_generation(fresh())
      {state, uncertain} = preparing_attempt(state, generation, 10)

      state =
        if lost_at == :before_expiry,
          do: applied(state, {event, uncertain}),
          else: state

      state = applied(state, {:advance, 10})

      state =
        if lost_at == :after_expiry,
          do: applied(state, {event, uncertain}),
          else: state

      rejected(state, {:reject_attempt, uncertain}, :invalid_phase)
      assert attempt(state, uncertain).completion == completion
      assert attempt(state, uncertain).outcome == outcome
      assert attempt(state, uncertain).deadline == 10
      assert attempt(state, uncertain).lost_proof
      assert attempt(state, uncertain).phase == :cleanup_hold
      state = clear_roots(state, uncertain)
      rejected(state, {:release_attempt, uncertain}, :lost_proof)
      assert Model.snapshot(state).occupied_attempts == {1, 0, 0, 0}
    end
  end

  test "closed generation denies acquisition and launch" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = preparing_attempt(state, generation)
    state = applied(state, {:retire_generation, generation, 200})
    rejected(state, {:acquire_attempt, generation, 100}, :invalid_phase)
    rejected(state, {:launch_attempt, attempt}, :invalid_phase)
    assert Model.snapshot(state).occupied_attempts == {1, 0, 0, 0}
    assert attempt(state, attempt).launched == false
  end

  test "stale generation cannot release replacement" do
    {state, old} = apply_event(fresh(), {:reserve_generation, 100})
    state = applied(state, {:generation_failed, old, :not_opened})
    state = applied(state, {:release_generation, old})
    {state, current} = apply_event(state, {:reserve_generation, 100})
    assert elem(old, 1) == elem(current, 1)
    refute old == current

    for event <- [
          {:scope_opened, old},
          {:scope_retired, old},
          {:generation_failed, old, :not_opened},
          {:retire_generation, old, 200},
          {:release_generation, old}
        ] do
      unchanged(state, event, :stale)
    end
  end

  test "stale attempt cannot release replacement" do
    {state, generation} = ready_generation(fresh())
    {state, old} = launched_attempt(state, generation)
    state = complete_attempt(state, old)
    state = clear_roots(state, old)
    state = applied(state, {:release_attempt, old})
    {state, current} = apply_event(state, {:acquire_attempt, generation, 100})
    assert elem(old, 2) == elem(current, 2)
    refute old == current

    for event <- [{:attempt_result, old, :ok}, {:request_completed, old}, {:release_attempt, old}] do
      unchanged(state, event, :stale)
    end

    assert Model.snapshot(state).occupied_attempts == {1, 0, 0, 0}
  end

  test "root release matches allocation identity" do
    {state, generation} = apply_event(fresh(), {:reserve_generation, 100})
    {state, old} = apply_event(state, {:retain_root, generation, :policy_source})
    unchanged(state, {:retain_root, generation, :policy_source}, old)
    state = applied(state, {:release_root, old})
    {state, current} = apply_event(state, {:retain_root, generation, :policy_source})
    refute old == current
    unchanged(state, {:release_root, old}, :stale)
    assert Model.snapshot(state).held_roots == 1
    state = applied(state, {:release_root, current})
    assert Model.snapshot(state).held_roots == 0
  end

  test "upload credit requires release before ack" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = launched_attempt(state, generation)
    {state, source} = apply_event(state, {:retain_root, attempt, :upload_source})
    {state, chunk} = apply_event(state, {:offer_chunk, attempt, :upload})
    rejected(state, {:offer_chunk, attempt, :upload}, :ownership_pending)
    rejected(state, {:ack_chunk, chunk}, :ownership_pending)
    state = applied(state, {:release_chunk, chunk})
    unchanged(state, {:release_chunk, chunk}, :duplicate)
    rejected(state, {:offer_chunk, attempt, :upload}, :ownership_pending)
    assert Model.snapshot(state).held_chunks == 1
    state = applied(state, {:ack_chunk, chunk})
    unchanged(state, {:ack_chunk, chunk}, :stale)
    assert Model.snapshot(state).held_chunks == 0
    assert attempt(state, attempt).roots.upload_source == source
    state = applied(state, {:release_root, source})
    rejected(state, {:offer_chunk, attempt, :upload}, :ownership_pending)
  end

  test "response credit rejects stale ack" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = launched_attempt(state, generation)
    {state, consumer} = apply_event(state, {:retain_root, attempt, :response_consumer})
    {state, old} = apply_event(state, {:offer_chunk, attempt, :response})
    state = applied(state, {:release_chunk, old})
    state = applied(state, {:ack_chunk, old})
    {state, current} = apply_event(state, {:offer_chunk, attempt, :response})
    refute old == current
    unchanged(state, {:release_chunk, old}, :stale)
    unchanged(state, {:ack_chunk, old}, :stale)
    rejected(state, {:finish_stream, attempt, :response}, :ownership_pending)
    assert Model.snapshot(state).held_chunks == 1
    assert attempt(state, attempt).roots.response_consumer == consumer
  end

  test "terminal root blocks request refund" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = launched_attempt(state, generation)
    rejected(state, {:attempt_result, attempt, :ok}, :invalid_phase)
    rejected(state, {:finish_stream, attempt, :response}, :ownership_pending)
    {state, _terminal} = apply_event(state, {:retain_root, attempt, :terminal})
    {state, _parser} = apply_event(state, {:retain_root, attempt, :parser_batch})
    {state, _consumer} = apply_event(state, {:retain_root, attempt, :response_consumer})
    state = applied(state, {:finish_stream, attempt, :response})
    unchanged(state, {:finish_stream, attempt, :response}, :duplicate)
    rejected(state, {:offer_chunk, attempt, :response}, :invalid_phase)
    state = applied(state, {:attempt_result, attempt, :ok})
    unchanged(state, {:attempt_result, attempt, :ok}, :duplicate)
    rejected(state, {:attempt_result, attempt, :failed}, :conflicting_result)
    state = applied(state, {:request_completed, attempt})
    unchanged(state, {:request_completed, attempt}, :duplicate)
    rejected(state, {:release_attempt, attempt}, :ownership_pending)
    assert Model.snapshot(state).held_roots == 6
    state = clear_roots(state, attempt)
    state = applied(state, {:release_attempt, attempt})
    assert Model.snapshot(state).occupied_attempts == {0, 0, 0, 0}
  end

  test "public completion is not local cleanup" do
    # Every ordering of the four independent release premises must retain
    # the attempt until the final premise, including completion-first.
    for order <- permutations([:completion, :roots, :helper, :frontier]) do
      {state, generation} = ready_generation(fresh())
      {state, attempt} = launched_attempt(state, generation)
      {state, _helper_root} = apply_event(state, {:retain_root, attempt, :helpers})
      {state, control} = apply_event(state, {:begin_control, attempt, :initial_wait})
      state = applied(state, {:control_result, control, :ok})
      state = applied(state, {:attempt_result, attempt, :failed})

      state =
        Enum.reduce(Enum.with_index(order), state, fn {premise, index}, state ->
          state =
            case premise do
              :completion -> applied(state, {:request_completed, attempt})
              :roots -> clear_roots(state, attempt)
              :helper -> applied(state, {:control_helper_released, control})
              :frontier -> applied(state, {:control_frontier_released, control})
            end

          if index < 3 do
            reason =
              if index == 2 and List.last(order) == :completion,
                do: :invalid_phase,
                else: :ownership_pending

            rejected(state, {:release_attempt, attempt}, reason)
          end

          state
        end)

      state = applied(state, {:release_attempt, attempt})
      assert Model.snapshot(state).occupied_attempts == {0, 0, 0, 0}
    end
  end

  test "control retries join one operation" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = launched_attempt(state, generation)
    {state, control} = apply_event(state, {:begin_control, attempt, :initial_wait})

    for _ <- 1..32 do
      unchanged(state, {:begin_control, attempt, :initial_wait}, control)
    end

    state = applied(state, {:control_result, control, :cleanup_pending})
    unchanged(state, {:control_result, control, :cleanup_pending}, :duplicate)
    unchanged(state, {:begin_control, attempt, :initial_wait}, :cached)
    state = applied(state, {:control_helper_released, control})
    unchanged(state, {:begin_control, attempt, :initial_wait}, :cached)
    rejected(state, {:control_result, control, :ok}, :conflicting_result)
    assert Model.snapshot(state).issued_controls == 2
    assert Model.snapshot(state).outstanding_controls == 1
  end

  test "control reply is not release frontier" do
    for order <- [[:helper, :frontier], [:frontier, :helper]] do
      {state, generation} = ready_generation(fresh())
      {state, attempt} = launched_attempt(state, generation)
      {state, control} = apply_event(state, {:begin_control, attempt, :abort_wait})
      state = applied(state, {:control_result, control, :ok})
      state = applied(state, {:attempt_result, attempt, :failed})
      state = applied(state, {:request_completed, attempt})
      state = clear_roots(state, attempt)
      rejected(state, {:release_attempt, attempt}, :ownership_pending)
      assert Model.snapshot(state).outstanding_controls == 1
      [first, last] = order
      state = applied(state, control_release(first, control))
      unchanged(state, control_release(first, control), :duplicate)
      rejected(state, {:release_attempt, attempt}, :ownership_pending)
      assert Model.snapshot(state).outstanding_controls == 1
      state = applied(state, control_release(last, control))
      assert Model.snapshot(state).outstanding_controls == 0
      state = applied(state, {:release_attempt, attempt})
      assert Model.snapshot(state).issued_controls == 1
    end
  end

  test "stale control cannot affect reused owner" do
    {state, generation} = ready_generation(fresh())
    old_open = generation(state, generation).controls.open.token
    {state, old_attempt} = launched_attempt(state, generation)
    {state, old_control} = apply_event(state, {:begin_control, old_attempt, :initial_wait})
    state = finish_control(state, old_control)
    state = complete_attempt(state, old_attempt)
    state = clear_roots(state, old_attempt)
    state = applied(state, {:release_attempt, old_attempt})
    {state, current} = launched_attempt(state, generation)
    {state, _new_control} = apply_event(state, {:begin_control, current, :initial_wait})
    stale_control_events(state, old_control)
    state = complete_attempt(state, current)
    state = clear_roots(state, current)
    current_control = attempt(state, current).controls.initial_wait.token
    state = finish_control(state, current_control)
    state = applied(state, {:release_attempt, current})
    state = retire_and_clear(state, generation)
    state = applied(state, {:release_generation, generation})
    {state, replacement} = ready_generation(state)
    refute generation == replacement
    stale_control_events(state, old_open)
    stale_control_events(state, old_control)
    assert Model.snapshot(state).occupied_generations == 1
  end

  test "request timeout preserves original result" do
    {state, generation} = ready_generation(fresh())
    {state, attempt} = launched_attempt(state, generation, 10)
    {state, _consumer} = apply_event(state, {:retain_root, attempt, :response_consumer})
    {state, _terminal} = apply_event(state, {:retain_root, attempt, :terminal})
    {state, chunk} = apply_event(state, {:offer_chunk, attempt, :response})
    state = applied(state, {:advance, 9})
    assert attempt(state, attempt).outcome == :pending
    state = applied(state, {:advance, 10})
    assert attempt(state, attempt).outcome == :timed_out
    rejected(state, {:attempt_result, attempt, :ok}, :conflicting_result)
    rejected(state, {:attempt_result, attempt, :failed}, :conflicting_result)
    rejected(state, {:release_attempt, attempt}, :ownership_pending)
    state = applied(state, {:request_completed, attempt})
    state = applied(state, {:release_chunk, chunk})
    state = applied(state, {:ack_chunk, chunk})
    state = clear_roots(state, attempt)
    assert attempt(state, attempt).outcome == :timed_out
    assert attempt(state, attempt).deadline == 10
    state = applied(state, {:release_attempt, attempt})
    assert Model.snapshot(state).occupied_attempts == {0, 0, 0, 0}
  end

  test "opening timeout does not reopen admission" do
    {state, generation} = opening_generation(fresh(), 10)
    state = applied(state, {:advance, 10})
    open = generation(state, generation).controls.open.token
    state = applied(state, {:control_result, open, :ok})
    state = applied(state, {:scope_opened, generation})
    assert generation(state, generation).opening_outcome == :timed_out
    assert generation(state, generation).scope_evidence == :opened
    rejected(state, {:acquire_attempt, generation, 100}, :invalid_phase)

    {state, generation} = apply_event(fresh(), {:reserve_generation, 10})
    state = applied(state, {:advance, 1})
    state = applied(state, {:retire_generation, generation, 20})
    state = applied(state, {:advance, 10})
    state = applied(state, {:generation_failed, generation, :not_opened})
    record = generation(state, generation)
    assert record.opening_outcome == :timed_out
    assert record.retirement_outcome == :pending
    assert record.retirement_deadline == 20
    assert record.scope_evidence == :not_opened
    rejected(state, {:acquire_attempt, generation, 100}, :invalid_phase)

    {state, generation} = opening_generation(fresh(), 10)
    state = applied(state, {:retire_generation, generation, 20})
    open = generation(state, generation).controls.open.token
    state = applied(state, {:control_result, open, :ok})
    state = applied(state, {:scope_opened, generation})
    assert generation(state, generation).opening_outcome == :ready
    assert generation(state, generation).phase == :retiring
    state = applied(state, {:advance, 10})
    assert generation(state, generation).opening_outcome == :ready
    rejected(state, {:acquire_attempt, generation, 100}, :invalid_phase)
  end

  test "retirement deadline never restarts" do
    {state, generation} = ready_generation(fresh())
    state = applied(state, {:retire_generation, generation, 10})
    unchanged(state, {:retire_generation, generation, 20}, :cached)
    {state, control} = apply_event(state, {:begin_control, generation, :retire})
    state = applied(state, {:advance, 10})
    state = applied(state, {:control_result, control, :ok})
    state = applied(state, {:scope_retired, generation})
    assert generation(state, generation).retirement_deadline == 10
    assert generation(state, generation).retirement_outcome == :timed_out
    assert generation(state, generation).scope_evidence == :retired

    for {opening_deadline, retirement_deadline} <- [{10, 20}, {20, 10}, {10, 10}] do
      {state, generation} = opening_generation(fresh(), opening_deadline)
      state = applied(state, {:retire_generation, generation, retirement_deadline})
      {state, _control} = apply_event(state, {:begin_control, generation, :retire})
      before = generation(state, generation)
      earlier = min(opening_deadline, retirement_deadline)
      later = max(opening_deadline, retirement_deadline)
      state = applied(state, {:advance, earlier})
      middle = generation(state, generation)

      assert middle.opening_outcome ==
               if(opening_deadline == earlier, do: :timed_out, else: :pending)

      assert middle.retirement_outcome ==
               if(retirement_deadline == earlier, do: :timed_out, else: :pending)

      state = applied(state, {:advance, later})
      after_deadlines = generation(state, generation)
      assert after_deadlines.opening_outcome == :timed_out
      assert after_deadlines.retirement_outcome == :timed_out
      assert after_deadlines.phase == :cleanup_hold

      assert Map.drop(after_deadlines, [:phase, :opening_outcome, :retirement_outcome]) ==
               Map.drop(before, [:phase, :opening_outcome, :retirement_outcome])

      assert Model.snapshot(state).occupied_generations == 1
      rejected(state, {:acquire_attempt, generation, later + 100}, :invalid_phase)
    end
  end

  test "owner death and unconfirmed stay charged" do
    for event <- [:owner_down, :attempt_unconfirmed, :control_unconfirmed] do
      {state, generation} = ready_generation(fresh())
      {state, attempt} = launched_attempt(state, generation)
      {state, control} = apply_event(state, {:begin_control, attempt, :abort_wait})

      state =
        if event == :control_unconfirmed do
          applied(state, {:control_result, control, :cleanup_unconfirmed})
        else
          state = applied(state, {:control_result, control, :ok})
          applied(state, {event, attempt})
        end

      state = applied(state, {:request_completed, attempt})
      state = clear_roots(state, attempt)
      state = release_control(state, control)

      unchanged(
        state,
        {if(event == :owner_down, do: :owner_down, else: :attempt_unconfirmed), attempt},
        :duplicate
      )

      rejected(state, {:release_attempt, attempt}, :lost_proof)
      assert Model.snapshot(state).occupied_attempts == {1, 0, 0, 0}
      assert attempt(state, attempt).lost_proof
    end

    for event <- [:owner_down, :generation_unconfirmed, :control_unconfirmed] do
      {state, generation} = ready_generation(fresh())
      state = applied(state, {:retire_generation, generation, 100})
      {state, control} = apply_event(state, {:begin_control, generation, :abort})

      state =
        if event == :control_unconfirmed do
          state = applied(state, {:control_result, control, :cleanup_unconfirmed})
          {state, retirement} = apply_event(state, {:begin_control, generation, :retire})
          finish_control(state, retirement)
        else
          state = applied(state, {:control_result, control, :ok})
          applied(state, {event, generation})
        end

      state = applied(state, {:scope_retired, generation})
      state = clear_roots(state, generation)
      state = release_control(state, control)
      rejected(state, {:release_generation, generation}, :lost_proof)
      assert generation(state, generation).lost_proof
      assert Model.snapshot(state).occupied_generations == 1
    end
  end

  test "request release is not generation release" do
    {state, generation} = ready_generation(fresh())
    {state, _shared} = apply_event(state, {:retain_root, generation, :shared_controls})
    {state, attempt} = launched_attempt(state, generation)
    state = complete_attempt(state, attempt)
    state = clear_roots(state, attempt)
    state = applied(state, {:release_attempt, attempt})
    assert Model.snapshot(state).occupied_generations == 1
    assert Model.snapshot(state).held_roots == 3
    rejected(state, {:release_generation, generation}, :ownership_pending)
    state = clear_roots(state, generation)
    rejected(state, {:release_generation, generation}, :invalid_phase)

    # A separate trace keeps the scope roots until public retirement.
    {state, generation} = ready_generation(fresh())
    state = retire_and_clear(state, generation)
    state = applied(state, {:release_generation, generation})
    assert Model.snapshot(state).occupied_generations == 0

    # Generation release has the same four independent release premises.
    for order <- permutations([:completion, :roots, :helper, :frontier]) do
      {state, generation} = ready_generation(fresh())
      state = applied(state, {:retire_generation, generation, 100})
      {state, control} = apply_event(state, {:begin_control, generation, :retire})
      state = applied(state, {:control_result, control, :ok})

      state =
        Enum.reduce(Enum.with_index(order), state, fn {premise, index}, state ->
          state =
            case premise do
              :completion -> applied(state, {:scope_retired, generation})
              :roots -> clear_roots(state, generation)
              :helper -> applied(state, {:control_helper_released, control})
              :frontier -> applied(state, {:control_frontier_released, control})
            end

          if index < 3 do
            reason =
              if index == 2 and List.last(order) == :completion,
                do: :invalid_phase,
                else: :ownership_pending

            rejected(state, {:release_generation, generation}, reason)
          end

          state
        end)

      state = applied(state, {:release_generation, generation})
      assert Model.snapshot(state).occupied_generations == 0
    end
  end

  test "invalid events preserve bounded state" do
    for time <- [-1, @max_time + 1, 1.0, :now, "0", nil] do
      assert Model.new(time) == {:error, :invalid_time}
    end

    state = fresh()

    for event <- [
          %{payload: "retained"},
          [payload: "retained"],
          "retained",
          fn -> :payload end,
          self(),
          {:unknown},
          {:advance, 0, "payload"}
        ] do
      rejected(state, event, :invalid_event)
    end

    for time <- [-1, @max_time + 1, 0.0, nil] do
      rejected(state, {:advance, time}, :invalid_time)
    end

    state = applied(state, {:advance, 1})
    rejected(state, {:advance, 0}, :invalid_time)

    for deadline <- [1, 0, 86_400_002, @max_time + 1, 2.0, nil] do
      rejected(state, {:reserve_generation, deadline}, :invalid_deadline)
    end

    {state, generation} = apply_event(state, {:reserve_generation, 86_400_001})
    rejected(state, {:retain_root, generation, :payload}, :invalid_role)
    rejected(state, {:begin_control, generation, :wait_forever}, :invalid_operation)

    for token <- [
          {:generation, 4, make_ref()},
          {:generation, 0, 1},
          {:attempt, generation, 32, make_ref()},
          {:root, generation, :policy_source, 1}
        ] do
      rejected(state, {:owner_down, token}, :invalid_token)
    end

    rejected(state, {:retain_root, generation, :scope, "payload"}, :invalid_event)
    {state, control} = apply_event(state, {:begin_control, generation, :open})
    rejected(state, {:control_result, control, :unknown}, :invalid_event)
    state = applied(state, {:control_result, control, :failed})
    rejected(state, {:control_result, control, :ok}, :conflicting_result)
    rejected(state, {:scope_opened, generation}, :ownership_pending)
    assert Enum.sort(Map.keys(Model.snapshot(state))) == Enum.sort(@snapshot_keys)
    {state, generation} = ready_generation(fresh())
    {state, attempt} = launched_attempt(state, generation)
    rejected(state, {:offer_chunk, attempt, :sideways}, :invalid_event)
    rejected(state, {:finish_stream, attempt, :sideways}, :invalid_event)
    rejected(state, {:attempt_result, attempt, :unknown}, :invalid_event)
    rejected(state, {:begin_control, attempt, :open}, :invalid_operation)
    rejected(state, {:offer_chunk, attempt, :upload, "payload"}, :invalid_event)
    state = fresh(@max_time - 1)
    {state, _generation} = apply_event(state, {:reserve_generation, @max_time})
    rejected(state, {:reserve_generation, @max_time + 1}, :invalid_deadline)
  end

  test "long turnover retains only current slots" do
    {state, generation} = ready_generation(fresh())
    {state, sibling} = preparing_attempt(state, generation)
    baseline_nodes = bounded_shape(state)

    state =
      Enum.reduce(1..2048, state, fn index, state ->
        {state, attempt} = launched_attempt(state, generation)
        assert elem(attempt, 2) == 1
        {state, source} = apply_event(state, {:retain_root, attempt, :upload_source})
        state = applied(state, {:release_root, source})
        {state, _new_source} = apply_event(state, {:retain_root, attempt, :upload_source})
        unchanged(state, {:release_root, source}, :stale)
        {state, consumer} = apply_event(state, {:retain_root, attempt, :response_consumer})
        {state, upload} = apply_event(state, {:offer_chunk, attempt, :upload})
        state = applied(state, {:release_chunk, upload})
        state = applied(state, {:ack_chunk, upload})
        {state, response} = apply_event(state, {:offer_chunk, attempt, :response})
        state = applied(state, {:release_chunk, response})
        state = applied(state, {:ack_chunk, response})
        {state, _next_response} = apply_event(state, {:offer_chunk, attempt, :response})
        unchanged(state, {:ack_chunk, response}, :stale)
        state = clear_chunks(state, attempt)
        {state, control} = apply_event(state, {:begin_control, attempt, :initial_wait})
        state = finish_control(state, control)
        state = complete_attempt(state, attempt)
        state = clear_roots(state, attempt)
        state = applied(state, {:release_attempt, attempt})

        if rem(index, 128) == 0 do
          assert bounded_shape(state) == baseline_nodes
          refute contains?(state, attempt)
          refute contains?(state, source)
          refute contains?(state, consumer)
          refute contains?(state, response)
          refute contains?(state, control)
          assert contains?(state, sibling)
          assert Model.snapshot(state).occupied_attempts == {1, 0, 0, 0}
        end

        state
      end)

    rejected(state, {:release_attempt, sibling}, :ownership_pending)
    assert attempt(state, sibling).phase == :preparing

    state =
      Enum.reduce(1..31, state, fn _, state ->
        {state, _attempt} = apply_event(state, {:acquire_attempt, generation, 100})
        state
      end)

    unchanged(state, {:acquire_attempt, generation, 100}, :busy)
  end

  defp fresh(now \\ 0) do
    assert {:ok, state} = Model.new(now)
    assert :ok = Model.invariants(state)
    assert Model.snapshot(state).qualification == :unqualified
    state
  end

  defp apply_event(state, event) do
    assert :ok = Model.invariants(state)
    assert {:ok, next, receipt} = Model.step(state, event)
    assert :ok = Model.invariants(next)
    {next, receipt}
  end

  defp applied(state, event) do
    {state, receipt} = apply_event(state, event)
    assert receipt == :applied
    state
  end

  defp unchanged(state, event, receipt) do
    assert :ok = Model.invariants(state)
    assert {:ok, ^state, ^receipt} = Model.step(state, event)
    assert :ok = Model.invariants(state)
    state
  end

  defp rejected(state, event, reason) do
    assert :ok = Model.invariants(state)
    assert {:error, ^reason, ^state} = Model.step(state, event)
    assert :ok = Model.invariants(state)
    state
  end

  defp opening_generation(state, deadline) do
    {state, generation} = apply_event(state, {:reserve_generation, deadline})
    {state, _custodian} = apply_event(state, {:retain_root, generation, :custodian})
    {state, _scope} = apply_event(state, {:retain_root, generation, :scope})
    {state, _open} = apply_event(state, {:begin_control, generation, :open})
    {state, generation}
  end

  defp ready_generation(state) do
    {state, generation} = opening_generation(state, state.now + 100)
    open = generation(state, generation).controls.open.token
    state = finish_control(state, open)
    state = applied(state, {:scope_opened, generation})
    {state, generation}
  end

  defp preparing_attempt(state, generation, deadline \\ 100) do
    {state, attempt} = apply_event(state, {:acquire_attempt, generation, deadline})
    {state, _source} = apply_event(state, {:retain_root, attempt, :source})
    state = applied(state, {:prepare_attempt, attempt})
    {state, attempt}
  end

  defp launched_attempt(state, generation, deadline \\ 100) do
    {state, attempt} = preparing_attempt(state, generation, deadline)
    state = applied(state, {:launch_attempt, attempt})
    {state, attempt}
  end

  defp complete_attempt(state, attempt) do
    {state, _terminal} = apply_event(state, {:retain_root, attempt, :terminal})
    state = applied(state, {:finish_stream, attempt, :response})
    state = applied(state, {:attempt_result, attempt, :ok})
    applied(state, {:request_completed, attempt})
  end

  defp finish_control(state, control) do
    state = applied(state, {:control_result, control, :ok})
    release_control(state, control)
  end

  defp release_control(state, control) do
    state = applied(state, {:control_helper_released, control})
    applied(state, {:control_frontier_released, control})
  end

  defp retire_and_clear(state, generation) do
    state = applied(state, {:retire_generation, generation, state.now + 100})
    {state, control} = apply_event(state, {:begin_control, generation, :retire})
    state = finish_control(state, control)
    state = applied(state, {:scope_retired, generation})
    clear_roots(state, generation)
  end

  defp clear_roots(state, owner) do
    roots =
      case owner do
        {:generation, _, _} -> generation(state, owner).roots
        {:attempt, _, _, _} -> attempt(state, owner).roots
      end

    Enum.reduce(Map.values(roots), state, fn
      nil, state -> state
      root, state -> applied(state, {:release_root, root})
    end)
  end

  defp clear_chunks(state, owner) do
    Enum.reduce(Map.values(attempt(state, owner).chunks), state, fn
      nil, state ->
        state

      %{token: token, phase: :held}, state ->
        state = applied(state, {:release_chunk, token})
        applied(state, {:ack_chunk, token})

      %{token: token, phase: :released}, state ->
        applied(state, {:ack_chunk, token})
    end)
  end

  defp generation(state, {:generation, slot, _}), do: elem(state.generations, slot)

  defp attempt(state, {:attempt, owner, slot, _}),
    do: elem(generation(state, owner).attempts, slot)

  defp control_release(:helper, control), do: {:control_helper_released, control}
  defp control_release(:frontier, control), do: {:control_frontier_released, control}

  defp stale_control_events(state, control) do
    for event <- [
          {:control_result, control, :ok},
          {:control_helper_released, control},
          {:control_frontier_released, control}
        ] do
      unchanged(state, event, :stale)
    end
  end

  defp permutations([]), do: [[]]

  defp permutations(items) do
    for item <- items, rest <- permutations(List.delete(items, item)), do: [item | rest]
  end

  defp bounded_shape(state) do
    assert Enum.sort(Map.keys(Map.delete(state, :__struct__))) == [:generations, :now]
    assert tuple_size(state.generations) == 4

    for generation <- Tuple.to_list(state.generations), generation != nil do
      assert Enum.sort(Map.keys(Map.delete(generation, :__struct__))) ==
               Enum.sort([
                 :token,
                 :phase,
                 :opening_deadline,
                 :retirement_deadline,
                 :opening_outcome,
                 :retirement_outcome,
                 :scope_evidence,
                 :lost_proof,
                 :roots,
                 :controls,
                 :attempts
               ])

      assert tuple_size(generation.attempts) == 32
      assert Enum.sort(Map.keys(generation.roots)) == Enum.sort(@generation_roots)
      assert Enum.sort(Map.keys(generation.controls)) == [:abort, :open, :retire]

      for attempt <- Tuple.to_list(generation.attempts), attempt != nil do
        assert Enum.sort(Map.keys(Map.delete(attempt, :__struct__))) ==
                 Enum.sort([
                   :token,
                   :phase,
                   :deadline,
                   :outcome,
                   :launched,
                   :completion,
                   :lost_proof,
                   :roots,
                   :chunks,
                   :finished,
                   :controls
                 ])

        assert Enum.sort(Map.keys(attempt.roots)) == Enum.sort(@attempt_roots)
        assert Enum.sort(Map.keys(attempt.chunks)) == [:response, :upload]
        assert Enum.sort(Map.keys(attempt.finished)) == [:response, :upload]
        assert Enum.sort(Map.keys(attempt.controls)) == [:abort_wait, :initial_wait]
      end
    end

    scalar_nodes(state)
  end

  defp scalar_nodes(value) when is_map(value) do
    assert map_size(value) <= 12

    1 +
      Enum.reduce(Map.to_list(value), 0, fn {key, child}, count ->
        assert is_atom(key)
        count + scalar_nodes(child)
      end)
  end

  defp scalar_nodes(value) when is_tuple(value) do
    assert tuple_size(value) <= 32
    1 + Enum.reduce(Tuple.to_list(value), 0, &(scalar_nodes(&1) + &2))
  end

  defp scalar_nodes(value) do
    assert is_atom(value) or is_boolean(value) or is_reference(value) or
             (is_integer(value) and value >= 0 and value <= @max_time)

    1
  end

  defp contains?(value, token) when value == token, do: true

  defp contains?(value, token) when is_map(value),
    do: Enum.any?(Map.values(value), &contains?(&1, token))

  defp contains?(value, token) when is_tuple(value),
    do: Enum.any?(Tuple.to_list(value), &contains?(&1, token))

  defp contains?(_value, _token), do: false
end

summary = ExUnit.run()
IO.inspect(summary, label: "H1_MODEL_EXUNIT_SUMMARY")

if summary.total == 22 and summary.total > 0 and summary.failures == 0 and
     summary.skipped == 0 and summary.excluded == 0 do
  System.halt(0)
else
  System.halt(1)
end
