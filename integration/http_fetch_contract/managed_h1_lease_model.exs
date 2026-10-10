defmodule Gaoxy.Qualification.ManagedH1LeaseModel do
  @moduledoc """
  Fixture-only symbolic ownership model. Its events are modeled premises,
  and its fixed credits do not certify retained bytes or real cleanup.
  """

  @max_time 9_223_372_036_854_775_807
  @deadline_window 86_400_000
  @generation_roles [:policy_source, :policy_prepared, :custodian, :scope, :shared_controls]
  @attempt_roles [
    :source,
    :prepared,
    :upstream,
    :helpers,
    :parser_batch,
    :terminal,
    :upload_source,
    :response_consumer
  ]
  @generation_operations [:open, :retire, :abort]
  @attempt_operations [:initial_wait, :abort_wait]
  @directions [:upload, :response]
  @results [:ok, :failed, :cleanup_pending, :cleanup_unconfirmed]

  defmodule State do
    defstruct now: 0, generations: {nil, nil, nil, nil}
  end

  defmodule Generation do
    defstruct token: nil,
              phase: :preparing,
              opening_deadline: nil,
              retirement_deadline: nil,
              opening_outcome: :pending,
              retirement_outcome: :not_started,
              scope_evidence: :not_started,
              lost_proof: false,
              roots: %{
                policy_source: nil,
                policy_prepared: nil,
                custodian: nil,
                scope: nil,
                shared_controls: nil
              },
              controls: %{open: :unused, retire: :unused, abort: :unused},
              attempts:
                {nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
                 nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
  end

  defmodule Attempt do
    defstruct token: nil,
              phase: :reserved,
              deadline: nil,
              outcome: :pending,
              launched: false,
              completion: :none,
              lost_proof: false,
              roots: %{
                source: nil,
                prepared: nil,
                upstream: nil,
                helpers: nil,
                parser_batch: nil,
                terminal: nil,
                upload_source: nil,
                response_consumer: nil
              },
              chunks: %{upload: nil, response: nil},
              finished: %{upload: false, response: false},
              controls: %{initial_wait: :unused, abort_wait: :unused}
  end

  defmodule Chunk do
    defstruct [:token, phase: :held]
  end

  defmodule Control do
    defstruct [:token, result: :pending, helper_released: false, frontier_released: false]
  end

  def new(now) do
    if valid_time?(now), do: {:ok, %State{now: now}}, else: {:error, :invalid_time}
  end

  def step(%State{} = state, event), do: transition(state, event)
  def step(state, _event), do: {:error, :invalid_event, state}

  def snapshot(%State{} = state) do
    generations = state.generations |> Tuple.to_list() |> Enum.reject(&is_nil/1)
    attempts = Enum.flat_map(generations, &occupied_attempts/1)
    owners = generations ++ attempts

    %{
      qualification: :unqualified,
      generation_slots: 4,
      occupied_generations: length(generations),
      attempt_slots_per_generation: 32,
      occupied_attempts:
        state.generations
        |> Tuple.to_list()
        |> Enum.map(fn
          nil -> 0
          generation -> length(occupied_attempts(generation))
        end)
        |> List.to_tuple(),
      held_roots: Enum.reduce(owners, 0, &(present_count(&1.roots) + &2)),
      held_chunks: Enum.reduce(attempts, 0, &(present_count(&1.chunks) + &2)),
      issued_controls:
        Enum.reduce(owners, 0, fn owner, count ->
          count + Enum.count(Map.values(owner.controls), &(&1 != :unused))
        end),
      outstanding_controls:
        Enum.reduce(owners, 0, fn owner, count ->
          count + Enum.count(Map.values(owner.controls), &outstanding?/1)
        end)
    }
  end

  def invariants(%State{} = state) do
    if exact_fields?(state, [:now, :generations]) and valid_time?(state.now) and
         is_tuple(state.generations) and tuple_size(state.generations) == 4 and
         Enum.all?(0..3, &valid_generation?(elem(state.generations, &1), &1, state.now)) do
      counts = snapshot(state)

      if counts.occupied_generations <= 4 and
           Enum.all?(Tuple.to_list(counts.occupied_attempts), &(&1 <= 32)) and
           counts.held_roots <= 1044 and counts.held_chunks <= 256 and
           counts.issued_controls <= 268 and counts.outstanding_controls <= 268,
         do: :ok,
         else: {:error, :ownership_pending}
    else
      {:error, :invalid_event}
    end
  end

  def invariants(_state), do: {:error, :invalid_event}

  defp transition(state, {:advance, now}) do
    if valid_time?(now) and now >= state.now do
      generations =
        state.generations
        |> Tuple.to_list()
        |> Enum.map(&expire_generation(&1, now))
        |> List.to_tuple()

      {:ok, %{state | now: now, generations: generations}, :applied}
    else
      error(state, :invalid_time)
    end
  end

  defp transition(state, {:reserve_generation, deadline}) do
    cond do
      not valid_deadline?(state.now, deadline) ->
        error(state, :invalid_deadline)

      true ->
        case empty_slot(state.generations) do
          nil ->
            {:ok, state, :busy}

          slot ->
            token = {:generation, slot, make_ref()}
            owner = %Generation{token: token, opening_deadline: deadline}
            {:ok, put_owner(state, token, owner), token}
        end
    end
  end

  defp transition(state, {:scope_opened, token}) do
    on_generation(state, token, fn owner ->
      cond do
        owner.scope_evidence in [:opened, :retired] ->
          same(owner, :duplicate)

        is_nil(owner.roots.custodian) or is_nil(owner.roots.scope) ->
          {:error, :ownership_pending}

        not control_ok?(owner.controls.open) or owner.opening_outcome == :failed ->
          {:error, :invalid_phase}

        true ->
          outcome =
            if owner.opening_outcome == :pending and state.now < owner.opening_deadline,
              do: :ready,
              else: owner.opening_outcome

          phase =
            if owner.phase == :preparing and outcome == :ready, do: :ready, else: owner.phase

          evidence = if owner.lost_proof, do: owner.scope_evidence, else: :opened

          changed(owner, %{
            owner
            | opening_outcome: outcome,
              phase: phase,
              scope_evidence: evidence
          })
      end
    end)
  end

  defp transition(state, {:generation_failed, token, :not_opened}) do
    on_generation(state, token, fn owner ->
      cond do
        owner.scope_evidence == :not_opened ->
          same(owner, :duplicate)

        not is_nil(owner.roots.scope) ->
          {:error, :ownership_pending}

        owner.opening_outcome == :ready or owner.scope_evidence in [:opened, :retired] or
            control_ok?(owner.controls.open) ->
          {:error, :invalid_phase}

        true ->
          outcome = if owner.opening_outcome == :pending, do: :failed, else: owner.opening_outcome
          evidence = if owner.lost_proof, do: owner.scope_evidence, else: :not_opened

          changed(owner, %{
            owner
            | opening_outcome: outcome,
              scope_evidence: evidence,
              phase: :cleanup_hold
          })
      end
    end)
  end

  defp transition(state, {:retire_generation, token, deadline}) do
    on_generation(state, token, fn owner ->
      cond do
        not valid_time?(deadline) ->
          {:error, :invalid_deadline}

        not is_nil(owner.retirement_deadline) ->
          same(owner, :cached)

        not valid_deadline?(state.now, deadline) ->
          {:error, :invalid_deadline}

        true ->
          phase = if owner.phase == :cleanup_hold, do: :cleanup_hold, else: :retiring

          same(%{
            owner
            | retirement_deadline: deadline,
              retirement_outcome: :pending,
              phase: phase
          })
      end
    end)
  end

  defp transition(state, {:scope_retired, token}) do
    on_generation(state, token, fn owner ->
      opened =
        owner.scope_evidence in [:opened, :retired] or
          (owner.scope_evidence == :unconfirmed and control_ok?(owner.controls.open))

      cond do
        is_nil(owner.retirement_deadline) or not opened or
            not (control_ok?(owner.controls.retire) or control_ok?(owner.controls.abort)) ->
          {:error, :invalid_phase}

        owner.scope_evidence == :retired or owner.retirement_outcome == :ok ->
          same(owner, :duplicate)

        true ->
          outcome =
            if owner.retirement_outcome == :pending and state.now < owner.retirement_deadline,
              do: :ok,
              else: owner.retirement_outcome

          evidence = if owner.lost_proof, do: owner.scope_evidence, else: :retired
          changed(owner, %{owner | retirement_outcome: outcome, scope_evidence: evidence})
      end
    end)
  end

  defp transition(state, {:generation_unconfirmed, token}) do
    on_generation(state, token, &uncertain/1)
  end

  defp transition(state, {:release_generation, token}) do
    on_generation(state, token, fn owner ->
      cond do
        owner.lost_proof ->
          {:error, :lost_proof}

        occupied_attempts(owner) != [] or ownership_pending?(owner) ->
          {:error, :ownership_pending}

        owner.scope_evidence == :retired or
            (owner.scope_evidence == :not_opened and
               owner.opening_outcome in [:failed, :timed_out] and
               not control_ok?(owner.controls.open)) ->
          {:remove, :applied}

        true ->
          {:error, :invalid_phase}
      end
    end)
  end

  defp transition(state, {:acquire_attempt, token, deadline}) do
    on_generation(state, token, fn owner ->
      cond do
        not valid_deadline?(state.now, deadline) ->
          {:error, :invalid_deadline}

        not admitting?(owner) ->
          {:error, :invalid_phase}

        true ->
          case empty_slot(owner.attempts) do
            nil ->
              same(owner, :busy)

            slot ->
              attempt = {:attempt, token, slot, make_ref()}
              record = %Attempt{token: attempt, deadline: deadline}
              same(%{owner | attempts: put_elem(owner.attempts, slot, record)}, attempt)
          end
      end
    end)
  end

  defp transition(state, {:prepare_attempt, token}) do
    on_attempt(state, token, fn owner ->
      cond do
        owner.phase == :preparing -> same(owner, :duplicate)
        owner.phase != :reserved -> {:error, :invalid_phase}
        is_nil(owner.roots.source) -> {:error, :ownership_pending}
        true -> same(%{owner | phase: :preparing})
      end
    end)
  end

  defp transition(state, {:launch_attempt, token}) do
    on_attempt(state, token, fn owner ->
      {:attempt, generation, _, _} = token

      cond do
        owner.launched ->
          same(owner, :duplicate)

        owner.phase != :preparing or owner.outcome != :pending or state.now >= owner.deadline or
            not admitting?(fetch_owner(state, generation)) ->
          {:error, :invalid_phase}

        true ->
          same(%{owner | launched: true, phase: :launched})
      end
    end)
  end

  defp transition(state, {:reject_attempt, token}) do
    on_attempt(state, token, fn owner ->
      cond do
        owner.outcome == :rejected ->
          same(owner, :duplicate)

        owner.launched or owner.phase not in [:reserved, :preparing] or owner.outcome != :pending ->
          {:error, :invalid_phase}

        true ->
          same(%{owner | outcome: :rejected, completion: :not_launched, phase: :releasing})
      end
    end)
  end

  defp transition(state, {:attempt_result, token, result}) when result in [:ok, :failed] do
    on_attempt(state, token, fn owner ->
      cond do
        not owner.launched ->
          {:error, :invalid_phase}

        owner.outcome == result ->
          same(owner, :duplicate)

        owner.outcome != :pending or state.now >= owner.deadline ->
          {:error, :conflicting_result}

        result == :ok and not owner.finished.response ->
          {:error, :invalid_phase}

        true ->
          phase = if owner.lost_proof, do: :cleanup_hold, else: :releasing
          same(%{owner | outcome: result, phase: phase})
      end
    end)
  end

  defp transition(state, {:request_completed, token}) do
    on_attempt(state, token, fn owner ->
      cond do
        not owner.launched -> {:error, :invalid_phase}
        owner.completion == :confirmed -> same(owner, :duplicate)
        owner.completion == :unconfirmed -> same(owner)
        true -> same(%{owner | completion: :confirmed})
      end
    end)
  end

  defp transition(state, {:attempt_unconfirmed, token}) do
    on_attempt(state, token, &uncertain/1)
  end

  defp transition(state, {:owner_down, token}) do
    on_owner(state, token, fn
      %{lost_proof: true} = owner ->
        same(owner, :duplicate)

      %Attempt{} = owner ->
        outcome = if owner.outcome == :pending, do: :failed, else: owner.outcome
        same(%{owner | lost_proof: true, phase: :cleanup_hold, outcome: outcome})

      %Generation{} = owner ->
        same(%{owner | lost_proof: true, phase: :cleanup_hold})
    end)
  end

  defp transition(state, {:retain_root, token, role}) do
    on_owner(state, token, fn owner ->
      cond do
        role not in roles(owner) ->
          {:error, :invalid_role}

        match?(%Attempt{phase: :reserved}, owner) and role not in [:source, :helpers] ->
          {:error, :invalid_phase}

        not is_nil(Map.fetch!(owner.roots, role)) ->
          same(owner, Map.fetch!(owner.roots, role))

        true ->
          root = {:root, token, role, make_ref()}
          same(%{owner | roots: Map.put(owner.roots, role, root)}, root)
      end
    end)
  end

  defp transition(state, {:release_root, {:root, owner, role, ref} = root}) do
    if valid_owner_token?(owner) and is_reference(ref) and role in token_roles(owner) do
      on_owner(state, owner, fn record ->
        if Map.fetch!(record.roots, role) == root,
          do: same(%{record | roots: Map.put(record.roots, role, nil)}),
          else: same(record, :stale)
      end)
    else
      error(state, :invalid_token)
    end
  end

  defp transition(state, {:release_root, _root}), do: error(state, :invalid_token)

  defp transition(state, {:offer_chunk, token, direction}) when direction in @directions do
    on_attempt(state, token, fn owner ->
      role = if direction == :upload, do: :upload_source, else: :response_consumer

      cond do
        not owner.launched or owner.outcome != :pending or state.now >= owner.deadline or
            Map.fetch!(owner.finished, direction) ->
          {:error, :invalid_phase}

        not is_nil(Map.fetch!(owner.chunks, direction)) or is_nil(Map.fetch!(owner.roots, role)) ->
          {:error, :ownership_pending}

        true ->
          chunk = {:chunk, token, direction, make_ref()}
          same(%{owner | chunks: Map.put(owner.chunks, direction, %Chunk{token: chunk})}, chunk)
      end
    end)
  end

  defp transition(state, {:release_chunk, token}) do
    on_chunk(state, token, fn owner, direction, chunk ->
      if chunk.phase == :released do
        same(owner, :duplicate)
      else
        same(%{owner | chunks: Map.put(owner.chunks, direction, %{chunk | phase: :released})})
      end
    end)
  end

  defp transition(state, {:ack_chunk, token}) do
    on_chunk(state, token, fn owner, direction, chunk ->
      if chunk.phase == :held,
        do: {:error, :ownership_pending},
        else: same(%{owner | chunks: Map.put(owner.chunks, direction, nil)})
    end)
  end

  defp transition(state, {:finish_stream, token, direction}) when direction in @directions do
    on_attempt(state, token, fn owner ->
      cond do
        not owner.launched ->
          {:error, :invalid_phase}

        Map.fetch!(owner.finished, direction) ->
          same(owner, :duplicate)

        not is_nil(Map.fetch!(owner.chunks, direction)) or is_nil(owner.roots.terminal) ->
          {:error, :ownership_pending}

        true ->
          same(%{owner | finished: Map.put(owner.finished, direction, true)})
      end
    end)
  end

  defp transition(state, {:begin_control, token, operation}) do
    on_owner(state, token, fn owner ->
      cond do
        operation not in operations(owner) ->
          {:error, :invalid_operation}

        Map.fetch!(owner.controls, operation) != :unused ->
          control = Map.fetch!(owner.controls, operation)
          same(owner, if(control.result == :pending, do: control.token, else: :cached))

        not control_allowed?(owner, operation) ->
          {:error, :invalid_phase}

        true ->
          control = {:control, token, operation, make_ref()}

          same(
            %{owner | controls: Map.put(owner.controls, operation, %Control{token: control})},
            control
          )
      end
    end)
  end

  defp transition(state, {:control_result, token, result}) when result in @results do
    on_control(state, token, fn owner, operation, control ->
      cond do
        control.result == result ->
          same(owner, :duplicate)

        control.result != :pending ->
          {:error, :conflicting_result}

        true ->
          owner = %{
            owner
            | controls: Map.put(owner.controls, operation, %{control | result: result})
          }

          if result == :cleanup_unconfirmed do
            {:ok, owner, _receipt} = uncertain(owner)
            same(owner)
          else
            same(owner)
          end
      end
    end)
  end

  defp transition(state, {:control_helper_released, token}),
    do: release_control_flag(state, token, :helper_released)

  defp transition(state, {:control_frontier_released, token}),
    do: release_control_flag(state, token, :frontier_released)

  defp transition(state, {:release_attempt, token}) do
    on_attempt(state, token, fn owner ->
      cond do
        owner.lost_proof ->
          {:error, :lost_proof}

        ownership_pending?(owner) or present_count(owner.chunks) > 0 ->
          {:error, :ownership_pending}

        owner.outcome == :pending or
          (owner.launched and owner.completion != :confirmed) or
            (not owner.launched and owner.completion != :not_launched) ->
          {:error, :invalid_phase}

        true ->
          {:remove, :applied}
      end
    end)
  end

  defp transition(state, _event), do: error(state, :invalid_event)

  defp same(owner, receipt \\ :applied), do: {:ok, owner, receipt}
  defp changed(owner, owner), do: same(owner, :duplicate)
  defp changed(_previous, owner), do: same(owner)
  defp error(state, reason), do: {:error, reason, state}

  defp on_generation(state, token, function) do
    if generation_token?(token),
      do: on_owner(state, token, function),
      else: error(state, :invalid_token)
  end

  defp on_attempt(state, token, function) do
    if attempt_token?(token),
      do: on_owner(state, token, function),
      else: error(state, :invalid_token)
  end

  defp on_owner(state, token, function) do
    cond do
      not valid_owner_token?(token) ->
        error(state, :invalid_token)

      true ->
        case fetch_owner(state, token) do
          nil ->
            {:ok, state, :stale}

          owner ->
            case function.(owner) do
              {:ok, owner, receipt} -> {:ok, put_owner(state, token, owner), receipt}
              {:remove, receipt} -> {:ok, put_owner(state, token, nil), receipt}
              {:error, reason} -> error(state, reason)
            end
        end
    end
  end

  defp on_chunk(state, {:chunk, owner, direction, ref} = token, function)
       when direction in @directions and is_reference(ref) do
    on_attempt(state, owner, fn record ->
      case Map.fetch!(record.chunks, direction) do
        %Chunk{token: ^token} = chunk -> function.(record, direction, chunk)
        _other -> same(record, :stale)
      end
    end)
  end

  defp on_chunk(state, _token, _function), do: error(state, :invalid_token)

  defp on_control(state, {:control, owner, operation, ref} = token, function) do
    if valid_owner_token?(owner) and is_reference(ref) and operation in token_operations(owner) do
      on_owner(state, owner, fn record ->
        case Map.fetch!(record.controls, operation) do
          %Control{token: ^token} = control -> function.(record, operation, control)
          _other -> same(record, :stale)
        end
      end)
    else
      error(state, :invalid_token)
    end
  end

  defp on_control(state, _token, _function), do: error(state, :invalid_token)

  defp release_control_flag(state, token, flag) do
    on_control(state, token, fn owner, operation, control ->
      if Map.fetch!(control, flag) do
        same(owner, :duplicate)
      else
        control = Map.put(control, flag, true)
        same(%{owner | controls: Map.put(owner.controls, operation, control)})
      end
    end)
  end

  defp fetch_owner(state, {:generation, slot, _} = token) do
    case elem(state.generations, slot) do
      %Generation{token: ^token} = owner -> owner
      _other -> nil
    end
  end

  defp fetch_owner(state, {:attempt, generation, slot, _} = token) do
    case fetch_owner(state, generation) do
      nil ->
        nil

      owner ->
        case elem(owner.attempts, slot) do
          %Attempt{token: ^token} = attempt -> attempt
          _other -> nil
        end
    end
  end

  defp put_owner(state, {:generation, slot, _}, owner),
    do: %{state | generations: put_elem(state.generations, slot, owner)}

  defp put_owner(state, {:attempt, generation, slot, _}, owner) do
    record = fetch_owner(state, generation)
    put_owner(state, generation, %{record | attempts: put_elem(record.attempts, slot, owner)})
  end

  defp uncertain(%Generation{lost_proof: true, scope_evidence: :unconfirmed} = owner),
    do: same(owner, :duplicate)

  defp uncertain(%Generation{} = owner),
    do: same(%{owner | lost_proof: true, scope_evidence: :unconfirmed, phase: :cleanup_hold})

  defp uncertain(%Attempt{lost_proof: true, completion: :unconfirmed} = owner),
    do: same(owner, :duplicate)

  defp uncertain(%Attempt{} = owner),
    do: same(%{owner | lost_proof: true, completion: :unconfirmed, phase: :cleanup_hold})

  defp expire_generation(nil, _now), do: nil

  defp expire_generation(owner, now) do
    opening = owner.opening_outcome == :pending and now >= owner.opening_deadline
    retirement = owner.retirement_outcome == :pending and now >= owner.retirement_deadline

    attempts =
      owner.attempts |> Tuple.to_list() |> Enum.map(&expire_attempt(&1, now)) |> List.to_tuple()

    %{
      owner
      | opening_outcome: if(opening, do: :timed_out, else: owner.opening_outcome),
        retirement_outcome: if(retirement, do: :timed_out, else: owner.retirement_outcome),
        phase: if(opening or retirement, do: :cleanup_hold, else: owner.phase),
        attempts: attempts
    }
  end

  defp expire_attempt(%Attempt{outcome: :pending} = owner, now) when now >= owner.deadline,
    do: %{owner | outcome: :timed_out, phase: :cleanup_hold}

  defp expire_attempt(owner, _now), do: owner

  defp valid_time?(now), do: is_integer(now) and now >= 0 and now <= @max_time

  defp valid_deadline?(now, deadline),
    do: valid_time?(deadline) and deadline > now and deadline - now <= @deadline_window

  defp generation_token?({:generation, slot, ref}),
    do: is_integer(slot) and slot >= 0 and slot < 4 and is_reference(ref)

  defp generation_token?(_token), do: false

  defp attempt_token?({:attempt, generation, slot, ref}),
    do:
      generation_token?(generation) and is_integer(slot) and slot >= 0 and slot < 32 and
        is_reference(ref)

  defp attempt_token?(_token), do: false
  defp valid_owner_token?(token), do: generation_token?(token) or attempt_token?(token)
  defp token_roles({:generation, _, _}), do: @generation_roles
  defp token_roles({:attempt, _, _, _}), do: @attempt_roles
  defp token_operations({:generation, _, _}), do: @generation_operations
  defp token_operations({:attempt, _, _, _}), do: @attempt_operations
  defp roles(%Generation{}), do: @generation_roles
  defp roles(%Attempt{}), do: @attempt_roles
  defp operations(%Generation{}), do: @generation_operations
  defp operations(%Attempt{}), do: @attempt_operations
  defp control_allowed?(%Generation{phase: :preparing}, :open), do: true

  defp control_allowed?(%Generation{retirement_deadline: deadline}, operation)
       when operation in [:retire, :abort],
       do: not is_nil(deadline)

  defp control_allowed?(%Attempt{launched: true}, operation)
       when operation in @attempt_operations,
       do: true

  defp control_allowed?(_owner, _operation), do: false
  defp control_ok?(%Control{result: :ok}), do: true
  defp control_ok?(_control), do: false
  defp outstanding?(:unused), do: false

  defp outstanding?(%Control{} = control),
    do: control.result == :pending or not control.helper_released or not control.frontier_released

  defp ownership_pending?(owner),
    do: present_count(owner.roots) > 0 or Enum.any?(Map.values(owner.controls), &outstanding?/1)

  defp present_count(credits), do: Enum.count(Map.values(credits), &(not is_nil(&1)))
  defp occupied_attempts(owner), do: owner.attempts |> Tuple.to_list() |> Enum.reject(&is_nil/1)
  defp empty_slot(slots), do: Enum.find(0..(tuple_size(slots) - 1), &is_nil(elem(slots, &1)))

  defp admitting?(owner),
    do:
      owner.phase == :ready and owner.opening_outcome == :ready and
        is_nil(owner.retirement_deadline) and not owner.lost_proof

  defp exact_fields?(record, fields),
    do: Enum.sort(Map.keys(Map.delete(record, :__struct__))) == Enum.sort(fields)

  defp valid_generation?(nil, _slot, _now), do: true

  defp valid_generation?(%Generation{} = owner, slot, now) do
    exact_fields?(owner, [
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
    ]) and
      generation_token?(owner.token) and elem(owner.token, 1) == slot and
      valid_stored_deadline?(owner.opening_deadline) and
      owner.opening_outcome in [:pending, :ready, :failed, :timed_out] and
      (owner.opening_outcome != :pending or owner.opening_deadline > now) and
      valid_retirement?(owner, now) and is_boolean(owner.lost_proof) and
      valid_roots?(owner.roots, owner.token, @generation_roles) and
      valid_controls?(owner.controls, owner, @generation_operations) and
      valid_generation_phase?(owner) and valid_scope_evidence?(owner) and
      is_tuple(owner.attempts) and tuple_size(owner.attempts) == 32 and
      Enum.all?(0..31, &valid_attempt?(elem(owner.attempts, &1), owner.token, &1, now))
  end

  defp valid_generation?(_owner, _slot, _now), do: false

  defp valid_retirement?(%Generation{retirement_deadline: nil} = owner, _now),
    do: owner.retirement_outcome == :not_started

  defp valid_retirement?(owner, now),
    do:
      valid_stored_deadline?(owner.retirement_deadline) and
        owner.retirement_outcome in [:pending, :ok, :timed_out, :unconfirmed] and
        (owner.retirement_outcome != :pending or owner.retirement_deadline > now) and
        (owner.retirement_outcome != :unconfirmed or owner.lost_proof)

  defp valid_generation_phase?(%Generation{lost_proof: true} = owner),
    do: owner.phase == :cleanup_hold

  defp valid_generation_phase?(%Generation{phase: :preparing} = owner),
    do: owner.opening_outcome == :pending and is_nil(owner.retirement_deadline)

  defp valid_generation_phase?(%Generation{phase: :ready} = owner),
    do:
      owner.opening_outcome == :ready and owner.scope_evidence == :opened and
        is_nil(owner.retirement_deadline)

  defp valid_generation_phase?(%Generation{phase: :retiring} = owner),
    do: not is_nil(owner.retirement_deadline) and owner.retirement_outcome in [:pending, :ok]

  defp valid_generation_phase?(%Generation{phase: :cleanup_hold} = owner),
    do:
      owner.opening_outcome in [:failed, :timed_out] or
        owner.retirement_outcome in [:timed_out, :unconfirmed]

  defp valid_generation_phase?(_owner), do: false

  defp valid_scope_evidence?(%Generation{scope_evidence: :not_started} = owner),
    do: owner.opening_outcome in [:pending, :timed_out] or owner.lost_proof

  defp valid_scope_evidence?(%Generation{scope_evidence: :not_opened} = owner),
    do: owner.opening_outcome in [:failed, :timed_out]

  defp valid_scope_evidence?(%Generation{scope_evidence: :opened} = owner),
    do: owner.opening_outcome in [:ready, :timed_out] and control_ok?(owner.controls.open)

  defp valid_scope_evidence?(%Generation{scope_evidence: :retired} = owner),
    do:
      not is_nil(owner.retirement_deadline) and owner.retirement_outcome in [:ok, :timed_out] and
        owner.opening_outcome in [:ready, :timed_out] and control_ok?(owner.controls.open) and
        (control_ok?(owner.controls.retire) or control_ok?(owner.controls.abort))

  defp valid_scope_evidence?(%Generation{scope_evidence: :unconfirmed} = owner),
    do: owner.lost_proof

  defp valid_scope_evidence?(_owner), do: false

  defp valid_attempt?(nil, _generation, _slot, _now), do: true

  defp valid_attempt?(%Attempt{} = owner, generation, slot, now) do
    exact_fields?(owner, [
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
    ]) and
      attempt_token?(owner.token) and elem(owner.token, 1) == generation and
      elem(owner.token, 2) == slot and
      valid_stored_deadline?(owner.deadline) and
      owner.outcome in [:pending, :ok, :rejected, :failed, :timed_out] and
      (owner.outcome != :pending or owner.deadline > now) and
      is_boolean(owner.launched) and is_boolean(owner.lost_proof) and
      valid_attempt_phase?(owner) and valid_completion?(owner) and
      valid_roots?(owner.roots, owner.token, @attempt_roles) and
      valid_controls?(owner.controls, owner, @attempt_operations) and
      is_map(owner.chunks) and Enum.sort(Map.keys(owner.chunks)) == Enum.sort(@directions) and
      Enum.all?(@directions, &valid_chunk?(Map.fetch!(owner.chunks, &1), owner.token, &1)) and
      is_map(owner.finished) and Enum.sort(Map.keys(owner.finished)) == Enum.sort(@directions) and
      Enum.all?(Map.values(owner.finished), &is_boolean/1) and
      (owner.outcome != :ok or owner.finished.response) and
      (owner.launched or not Enum.any?(Map.values(owner.finished)))
  end

  defp valid_attempt?(_owner, _generation, _slot, _now), do: false

  defp valid_attempt_phase?(%Attempt{lost_proof: true} = owner), do: owner.phase == :cleanup_hold

  defp valid_attempt_phase?(%Attempt{phase: phase} = owner) when phase in [:reserved, :preparing],
    do: not owner.launched and owner.outcome == :pending and owner.completion == :none

  defp valid_attempt_phase?(%Attempt{phase: :launched} = owner),
    do: owner.launched and owner.outcome == :pending

  defp valid_attempt_phase?(%Attempt{phase: :releasing} = owner),
    do:
      (owner.launched and owner.outcome in [:ok, :failed]) or
        (not owner.launched and owner.outcome == :rejected)

  defp valid_attempt_phase?(%Attempt{phase: :cleanup_hold} = owner),
    do: owner.outcome == :timed_out

  defp valid_attempt_phase?(_owner), do: false

  defp valid_completion?(%Attempt{completion: :none}), do: true
  defp valid_completion?(%Attempt{completion: :confirmed} = owner), do: owner.launched

  defp valid_completion?(%Attempt{completion: :not_launched} = owner),
    do: not owner.launched and owner.outcome == :rejected

  defp valid_completion?(%Attempt{completion: :unconfirmed} = owner), do: owner.lost_proof
  defp valid_completion?(_owner), do: false

  defp valid_roots?(roots, owner, roles) do
    is_map(roots) and Enum.sort(Map.keys(roots)) == Enum.sort(roles) and
      Enum.all?(roles, fn role ->
        case Map.fetch!(roots, role) do
          nil -> true
          {:root, ^owner, ^role, ref} -> is_reference(ref)
          _root -> false
        end
      end)
  end

  defp valid_controls?(controls, owner, operations) do
    is_map(controls) and Enum.sort(Map.keys(controls)) == Enum.sort(operations) and
      Enum.all?(operations, fn operation ->
        case Map.fetch!(controls, operation) do
          :unused ->
            true

          %Control{token: {:control, token, ^operation, ref}} = control ->
            token == owner.token and is_reference(ref) and
              exact_fields?(control, [:token, :result, :helper_released, :frontier_released]) and
              control.result in [:pending | @results] and
              is_boolean(control.helper_released) and is_boolean(control.frontier_released) and
              (control.result != :cleanup_unconfirmed or owner.lost_proof) and
              (match?(%Generation{}, owner) or owner.launched)

          _control ->
            false
        end
      end)
  end

  defp valid_chunk?(nil, _owner, _direction), do: true

  defp valid_chunk?(%Chunk{token: {:chunk, owner, direction, ref}} = chunk, owner, direction),
    do:
      is_reference(ref) and chunk.phase in [:held, :released] and
        exact_fields?(chunk, [:token, :phase])

  defp valid_chunk?(_chunk, _owner, _direction), do: false
  defp valid_stored_deadline?(deadline), do: valid_time?(deadline) and deadline > 0
end
