defmodule Gaoxy.ResourceBudget.Ledger do
  @moduledoc false
  use GenServer
  alias Gaoxy.ResourceBudget.{Policy, Safety}
  alias Gaoxy.ResourceBudget.Supervisor, as: BudgetSupervisor
  @maximum 9_223_372_036_854_775_807
  @receipt_limit 64
  @kinds [:connection, :request, :h2_stream, :h3_stream, :writer, :transport, :guardian]

  def start_link(options),
    do:
      GenServer.start_link(__MODULE__, options,
        name: BudgetSupervisor.name(__MODULE__, Keyword.fetch!(options, :identity))
      )

  @impl true
  def init(options) do
    identity = Keyword.fetch!(options, :identity)
    marker = {__MODULE__, identity}
    previous = :persistent_term.get(marker, nil)
    epoch = previous || make_ref()
    if is_nil(previous), do: :persistent_term.put(marker, epoch)

    {:ok,
     %{
       epoch: epoch,
       authority_name: BudgetSupervisor.name(Gaoxy.ResourceBudget.Authority, identity),
       lease_limit: Keyword.get(options, :lease_limit, 1_000_000),
       fenced: previous != nil,
       ready: false,
       authority: nil,
       auth_gen: 0,
       instances: %{},
       instance_keys: %{},
       services: %{},
       service_keys: %{},
       gates: %{},
       gate_keys: %{},
       allocations: %{},
       totals: %{vm: zero()},
       members: %{},
       owners: %{},
       dead: MapSet.new(),
       rejections: %{},
       detection: nil,
       safety: nil,
       probe: nil,
       effects: [],
       warning_at: %{},
       retired: %{},
       retired_order: :queue.new(),
       now: Keyword.get(options, :now, fn -> System.monotonic_time(:millisecond) end),
       processes:
         Keyword.get(options, :processes, fn ->
           %{
             count: :erlang.system_info(:process_count),
             limit: :erlang.system_info(:process_limit)
           }
         end)
     }}
  end

  @impl true
  def handle_call(:claim, {authority, _}, state) do
    if GenServer.whereis(state.authority_name) == authority do
      generation = state.auth_gen + 1
      state = %{state | authority: authority, auth_gen: generation, ready: false}
      {:reply, {:ok, state.epoch, generation, state.fenced}, state}
    else
      {:reply, {:error, :unauthorized_authority}, state}
    end
  end

  def handle_call(
        {:page, generation, iterator},
        {pid, _},
        %{authority: pid, auth_gen: generation} = state
      ) do
    iterator = if iterator == :start, do: :maps.iterator(state.owners), else: iterator
    {entries, next} = page(iterator, 64, [])
    {:reply, {entries, next}, state}
  end

  def handle_call(
        {:write, generation, request, actor},
        {pid, _},
        %{authority: pid, auth_gen: generation} = state
      ) do
    {result, state} = dispatch(request, actor, %{state | effects: []})
    {:reply, {result, Enum.reverse(state.effects)}, %{state | effects: []}}
  end

  def handle_call(_, _, state), do: {:reply, {{:error, :stale_authority}, []}, state}

  defp page(_, 0, acc), do: {Enum.reverse(acc), :more}

  defp page(iterator, n, acc) do
    case :maps.next(iterator) do
      :none -> {Enum.reverse(acc), :done}
      {pid, count, next} when n == 1 -> {Enum.reverse([{pid, count} | acc]), next}
      {pid, count, next} -> page(next, n - 1, [{pid, count} | acc])
    end
  end

  defp dispatch(:probe_context, _, state), do: {%{active?: map_size(state.instances) > 0}, state}

  defp dispatch({:begin_sample, id}, _, state) do
    {:ok, %{state | probe: %{id: id, baseline: state.totals.vm.retained_bytes}}}
  end

  defp dispatch(:ready, _, state), do: {:ok, %{state | ready: not state.fenced}}

  defp dispatch({:down, pid}, _, state) do
    dead = if Map.has_key?(state.owners, pid), do: MapSet.put(state.dead, pid), else: state.dead
    {:ok, %{state | dead: dead}}
  end

  defp dispatch({:install, detection, safety, probe_id}, _, state) do
    if state.fenced do
      {:ok, state}
    else
      old = state
      detection = detection || state.detection
      baseline = if state.probe && state.probe.id == probe_id, do: state.probe.baseline, else: 0

      safety =
        case safety do
          {:ok, data} when is_map(data) -> Map.put(data, :retained_baseline, baseline)
          _ -> nil
        end

      state = %{state | detection: detection, safety: safety, probe: nil}
      state = transitions(old, state, [], nil)

      effects = [
        {:refresh_transitions, old.detection},
        {:event, :resource_budget_snapshot,
         measurements(state.totals.vm, Policy.limits(detection), detection),
         %{instance: :vm, service: nil, detection: detection}}
      ]

      effects =
        if old.detection == detection,
          do: Enum.reject(effects, &match?({:refresh_transitions, _}, &1)),
          else: effects

      effects =
        if detection && Map.get(detection, :fallback?, false),
          do: [
            {:event, :resource_budget_fallback, %{count: 1},
             %{instance: :vm, detection: detection}}
            | effects
          ],
          else: effects

      {:ok, %{state | effects: effects ++ state.effects}}
    end
  end

  defp dispatch({:transition_page, old_detection, cursor}, _, state) do
    iterator = if cursor == :start, do: :maps.iterator(state.instances), else: cursor
    {entries, next} = page(iterator, 64, [])
    refs = for {ref, _} <- entries, Map.has_key?(state.instances, ref), do: ref
    old = %{state | detection: old_detection}
    {{:ok, next}, transitions(old, state, refs, nil)}
  end

  defp dispatch({:allocations, client, cursor}, actor, state) do
    result =
      with :ok <- available(state),
           {:ok, gate} <- gate(state, client),
           true <- authorized?(state, gate, actor) || {:error, :unauthorized_owner},
           true <-
             (cursor == :start or (is_integer(cursor) and cursor >= 0)) ||
               {:error, :invalid_cursor} do
        start = if cursor == :start, do: 0, else: cursor

        {tokens, next} =
          allocation_page(:gb_trees.iterator_from(start + 1, gate.tokens), 64, [], start)

        rows =
          Enum.map(tokens, fn token ->
            Map.take(state.allocations[token], [:token, :revision, :owner, :kind, :accounting])
          end)

        {:ok,
         %{
           allocations: rows,
           cursor: next,
           watermark: gate.watermark,
           next_operation: gate.watermark + 1
         }}
      end

    {result, state}
  end

  defp dispatch({:snapshot, instance}, _, state) do
    result = inspection(state, instance)

    effects =
      if is_map(result) and result[:availability] != :fenced do
        [
          {:event, :resource_budget_snapshot,
           measurements(
             state.totals[{:instance, instance}],
             effective(state.instances[instance].policy, state.detection),
             state.detection
           ), %{instance: instance, service: nil, availability: result.availability}}
          | state.effects
        ]
      else
        state.effects
      end

    {result, %{state | effects: effects}}
  end

  defp dispatch({:operation_status, client, sequence}, _, state) do
    result =
      with {:ok, gate} <- gate(state, client) do
        case gate.receipts[sequence] do
          nil ->
            {:error,
             if(is_integer(sequence) and sequence <= gate.watermark,
               do: :operation_expired,
               else: :unknown_operation
             )}

          %{result: result} ->
            result
        end
      end

    {result, state}
  end

  defp dispatch({:register_instance, pid, policy, deadline}, _actor, state) do
    with :ok <- available(state),
         true <- (is_pid(pid) and Process.alive?(pid)) || {:error, :invalid_owner},
         {:ok, policy} <- instance_policy(policy) do
      case state.instance_keys[pid] do
        nil ->
          with :ok <- timely(state, deadline) do
            original = state
            ref = make_ref()
            row = Map.merge(control(), %{owner: pid, policy: policy, mode: :ready, services: 0})

            state = %{
              state
              | instances: Map.put(state.instances, ref, row),
                instance_keys: Map.put(state.instance_keys, pid, ref),
                totals: Map.put(state.totals, {:instance, ref}, zero())
            }

            finalize(original, deadline, {{:ok, ref}, owner(state, pid, 1)})
          else
            error -> {error, state}
          end

        ref ->
          result =
            if state.instances[ref].policy == policy,
              do: {:ok, ref},
              else: {:error, :operation_conflict}

          {result, state}
      end
    else
      error -> {error, state}
    end
  end

  defp dispatch({:register_service, instance, scope, policy, deadline}, actor, state) do
    with :ok <- available(state),
         {:ok, parent} <- fetch(state.instances, instance, :unknown_instance),
         true <-
           (is_map(scope) and is_pid(scope[:owner]) and scope[:generation] != nil and
              scope[:id] != nil) || {:error, :invalid_scope},
         true <- actor in [parent.owner, scope.owner] || {:error, :unauthorized_owner},
         true <- (parent.mode == :ready and Process.alive?(parent.owner)) || {:error, :orphaned},
         {:ok, policy} <- service_policy(policy) do
      key = {instance, scope.id, scope.generation}

      case state.service_keys[key] do
        nil ->
          with :ok <- timely(state, deadline) do
            original = state
            ref = make_ref()

            row =
              Map.merge(control(), %{
                instance: instance,
                owner: scope.owner,
                scope: scope,
                policy: policy,
                mode: :ready,
                gates: 0
              })

            state = %{
              state
              | services: Map.put(state.services, ref, row),
                service_keys: Map.put(state.service_keys, key, ref),
                totals: Map.put(state.totals, {:service, ref}, zero())
            }

            state = update_in(state.instances[instance].services, &(&1 + 1))
            finalize(original, deadline, {{:ok, ref}, owner(state, scope.owner, 1)})
          else
            error -> {error, state}
          end

        ref ->
          row = state.services[ref]

          result =
            if row.policy == policy and row.scope == scope,
              do: {:ok, ref},
              else: {:error, :operation_conflict}

          {result, state}
      end
    else
      error -> {error, state}
    end
  end

  defp dispatch({:register_gate, service, pid, deadline}, actor, state) do
    with :ok <- available(state),
         {:ok, parent} <- fetch(state.services, service, :unknown_service),
         true <- (is_pid(pid) and Process.alive?(pid)) || {:error, :invalid_owner},
         true <-
           actor in [pid, parent.owner, state.instances[parent.instance].owner] ||
             {:error, :unauthorized_owner},
         true <-
           (parent.mode == :ready and state.instances[parent.instance].mode == :ready) ||
             {:error, :draining} do
      key = {service, pid}

      case state.gate_keys[key] do
        nil ->
          with :ok <- timely(state, deadline) do
            original = state
            ref = make_ref()

            row = %{
              service: service,
              owner: pid,
              watermark: 0,
              receipts: %{},
              order: :queue.new(),
              mode: :ready,
              allocations: 0,
              tokens: :gb_trees.empty()
            }

            state = %{
              state
              | gates: Map.put(state.gates, ref, row),
                gate_keys: Map.put(state.gate_keys, key, ref)
            }

            state = update_in(state.services[service].gates, &(&1 + 1))

            finalize(
              original,
              deadline,
              {{:ok, client(state, service, ref)}, owner(state, pid, 1)}
            )
          else
            error -> {error, state}
          end

        ref ->
          {{:ok, client(state, service, ref)}, state}
      end
    else
      error -> {error, state}
    end
  end

  defp dispatch({:registration_mutation, scope, sequence, deadline, action, digest}, actor, state) do
    fingerprint = {digest, actor}

    with :ok <- retired_retry(state, scope, sequence, fingerprint),
         {:ok, row} <- registration(state, scope),
         true <- actor in registration_owners(state, scope, row) || {:error, :unauthorized_owner},
         true <- (is_integer(sequence) and sequence > 0) || {:error, :invalid_operation} do
      case row.receipts[sequence] do
        %{fingerprint: ^fingerprint, result: result} ->
          {result, state}

        %{} ->
          {{:error, :operation_conflict}, state}

        nil when sequence <= row.watermark ->
          {{:error, :operation_expired}, state}

        nil ->
          result =
            with :ok <- available(state),
                 :ok <- timely(state, deadline),
                 do: registration_action(state, scope, row, action)

          {outcome, changed} =
            case result do
              {:ok, changed} ->
                finalize(
                  state,
                  deadline,
                  {{:ok, %{scope: scope, operation: sequence, status: :committed}}, changed}
                )

              {:error, reason} ->
                {{:error, reason}, state}
            end

          updated = put_control_receipt(row, sequence, fingerprint, outcome)

          case registration(changed, scope) do
            {:ok, current} ->
              {kind, ref} = scope
              table = if kind == :instance, do: :instances, else: :services

              changed =
                control_receipt_delta(
                  changed,
                  scope,
                  map_size(updated.receipts) - map_size(row.receipts)
                )

              changed =
                put_in(
                  changed,
                  [table, ref],
                  Map.merge(current, Map.take(updated, [:watermark, :receipts, :order]))
                )

              {outcome, changed}

            _ ->
              {outcome, remember_retired(changed, scope, updated)}
          end
      end
    else
      {:cached, result} -> {result, state}
      error -> {error, state}
    end
  end

  defp dispatch({:mutate, client, sequence, deadline, action, digest}, actor, state) do
    with :ok <- retired_retry(state, {:gate, client[:generation]}, sequence, {digest, actor}),
         {:ok, gate} <- gate(state, client),
         true <- (is_integer(sequence) and sequence > 0) || {:error, :invalid_operation} do
      fingerprint = {digest, actor}

      case gate.receipts[sequence] do
        %{fingerprint: ^fingerprint, result: result} ->
          {result, state}

        %{} ->
          {{:error, :operation_conflict}, state}

        nil when sequence <= gate.watermark ->
          {{:error, :operation_expired}, state}

        nil ->
          result =
            with :ok <- available(state),
                 :ok <- timely(state, deadline),
                 do: execute(state, client, gate, action, actor, sequence)

          {outcome, changed} =
            case result do
              {{:ok, _}, _} = candidate -> finalize(state, deadline, candidate)
              {:error, _} = error -> {error, state}
            end

          changed =
            case outcome do
              {:error, reason} -> rejection(state, client, reason)
              {:ok, _} -> changed
            end

          # Retirement deliberately invalidates its generation. Other operations
          # retain a fixed recent ring and a canonical monotonic watermark.
          changed =
            if Map.has_key?(changed.gates, client.generation),
              do: receipt(changed, client.generation, sequence, fingerprint, outcome),
              else:
                remember_retired(
                  changed,
                  {:gate, client.generation},
                  put_control_receipt(gate, sequence, fingerprint, outcome)
                )

          {outcome, changed}
      end
    else
      {:cached, result} -> {result, state}
      error -> {error, state}
    end
  end

  defp execute(state, client, gate, {:set_mode, target}, actor, sequence) do
    {kind, mode} =
      case target do
        {kind, mode} -> {kind, mode}
        mode -> {:gate, mode}
      end

    service = state.services[gate.service]

    scope =
      case kind do
        :gate -> {:gate, client.generation}
        :service -> {:service, gate.service}
        :instance -> {:instance, service.instance}
        _ -> nil
      end

    with true <- not is_nil(scope) || {:error, :invalid_mode},
         :ok <- mode_authorization(state, scope, gate, actor),
         {:ok, changed} <- change_mode(state, scope, mode) do
      {{:ok, %{operation: sequence, status: :committed}}, changed}
    end
  end

  defp execute(state, client, gate, {:retire, proof}, actor, sequence) do
    scope = if is_map(proof), do: Map.get(proof, :scope, :gate)
    service = state.services[gate.service]
    instance = state.instances[service.instance]

    cond do
      not authorized?(state, gate, actor) ->
        {:error, :unauthorized_owner}

      not is_map(proof) or proof[:terminal] != :confirmed ->
        {:error, :invalid_terminal_receipt}

      scope not in [:gate, :service, :instance] ->
        {:error, :invalid_terminal_receipt}

      gate.allocations != 0 ->
        {:error, :cleanup_pending}

      scope in [:service, :instance] and
          (service.gates != 1 or state.totals[{:service, gate.service}].leases != 0) ->
        {:error, :cleanup_pending}

      scope == :instance and
          (instance.services != 1 or state.totals[{:instance, service.instance}].leases != 0) ->
        {:error, :cleanup_pending}

      scope == :gate and gate.mode != :draining and Process.alive?(gate.owner) ->
        {:error, :not_draining}

      scope == :service and service.mode != :draining and gate.mode != :draining and
          Process.alive?(service.owner) ->
        {:error, :not_draining}

      scope == :instance and instance.mode != :draining and Process.alive?(instance.owner) ->
        {:error, :not_draining}

      true ->
        state = receipt_delta(state, gate.service, -map_size(gate.receipts))

        state = %{
          state
          | gates: Map.delete(state.gates, client.generation),
            gate_keys: Map.delete(state.gate_keys, {gate.service, gate.owner})
        }

        state = owner(state, gate.owner, -1)
        state = update_in(state.services[gate.service].gates, &(&1 - 1))

        state =
          if scope in [:service, :instance],
            do: remove_registration(state, {:service, gate.service}),
            else: state

        state =
          if scope == :instance,
            do: remove_registration(state, {:instance, service.instance}),
            else: state

        {{:ok, %{operation: sequence, status: :committed}}, state}
    end
  end

  defp execute(state, client, gate, {:reserve, pid, kind, input}, actor, sequence) do
    with true <-
           (is_pid(pid) and Process.alive?(pid) and kind in @kinds) || {:error, :invalid_owner},
         true <-
           (actor == pid or authorized?(state, gate, actor)) || {:error, :unauthorized_owner},
         {:ok, accounting} <- Gaoxy.ResourceBudget.normalize_accounting(input),
         :ok <- membership_kind(kind, accounting.memberships) do
      token = {state.epoch, client.generation, sequence}

      row = %{
        token: token,
        revision: 1,
        gate: client.generation,
        service: gate.service,
        instance: state.services[gate.service].instance,
        owner: pid,
        kind: kind,
        accounting: accounting
      }

      commit(state, client, gate, nil, row, true, sequence)
    end
  end

  defp execute(state, client, gate, action, actor, sequence)
       when elem(action, 0) in [:replace, :transfer, :release, :activate, :retain_stream] do
    token = elem(action, 1)
    revision = elem(action, 2)

    with {:ok, row} <- fetch(state.allocations, token, :closed_allocation),
         true <- row.gate == client.generation || {:error, :unknown_generation},
         true <- row.revision == revision || {:error, :stale_revision},
         true <-
           (actor == row.owner or authorized?(state, gate, actor)) ||
             {:error, :unauthorized_owner} do
      case action do
        {:replace, _, _, input} ->
          with {:ok, accounting} <- Gaoxy.ResourceBudget.normalize_accounting(input) do
            updated = %{row | accounting: accounting, revision: revision + 1}
            growth = growth?(row.accounting, accounting)
            commit(state, client, gate, row, updated, growth, sequence)
          end

        {:activate, _, _, pid} ->
          if authorized?(state, gate, actor) and is_pid(pid) and Process.alive?(pid) do
            accounting = %{row.accounting | pending_processes: 0}

            commit(
              state,
              client,
              gate,
              row,
              %{row | owner: pid, accounting: accounting, revision: revision + 1},
              false,
              sequence
            )
          else
            {:error, :invalid_owner}
          end

        {:retain_stream, _, _, pid, proof} ->
          cond do
            not authorized?(state, gate, actor) ->
              {:error, :unauthorized_owner}

            row.kind not in [:h2_stream, :h3_stream] ->
              {:error, :invalid_operation}

            not is_pid(pid) or not Process.alive?(pid) ->
              {:error, :invalid_owner}

            not is_map(proof) or proof[:terminal] != :confirmed or proof[:owner] != row.owner or
                proof[:revision] != revision ->
              {:error, :invalid_terminal_receipt}

            true ->
              accounting = %{
                row.accounting
                | memberships: Map.delete(row.accounting.memberships, :request),
                  pending_processes: 0
              }

              commit(
                state,
                client,
                gate,
                row,
                %{
                  row
                  | kind: :stream_retention,
                    owner: pid,
                    accounting: accounting,
                    revision: revision + 1
                },
                false,
                sequence
              )
          end

        {:transfer, _, _, pid} ->
          if is_pid(pid) and Process.alive?(pid),
            do:
              commit(
                state,
                client,
                gate,
                row,
                %{row | owner: pid, revision: revision + 1},
                false,
                sequence
              ),
            else: {:error, :invalid_owner}

        {:release, _, _, proof} ->
          if is_map(proof) and proof[:terminal] == :confirmed and proof[:owner] == row.owner and
               proof[:revision] == revision,
             do: commit(state, client, gate, row, nil, false, sequence),
             else: {:error, :invalid_terminal_receipt}
      end
    end
  end

  defp execute(_, _, _, _, _, _), do: {:error, :invalid_operation}

  defp membership_kind(kind, members) when kind in [:h2_stream, :h3_stream] do
    if Map.has_key?(members, :request) and Map.has_key?(members, kind),
      do: :ok,
      else: {:error, :invalid_membership}
  end

  defp membership_kind(kind, members) when kind in [:writer, :guardian, :transport] do
    if members == %{}, do: :ok, else: {:error, :invalid_membership}
  end

  defp membership_kind(_, _), do: :ok

  defp growth?(old, new),
    do:
      total(new) > total(old) or new.temporary_bytes > old.temporary_bytes or
        new.pending_processes > old.pending_processes or
        Enum.any?(new.memberships, fn {kind, id} -> old.memberships[kind] != id end)

  defp commit(state, _client, gate, old, new, growth, sequence) do
    changed = change_row(state, old, new)

    with :ok <- transport_category_check(state, changed, gate),
         :ok <- if(growth, do: growth_checks(state, changed, gate), else: :ok) do
      changed = transitions(state, changed, [state.services[gate.service].instance], gate.service)
      row = new || old

      receipt = %{
        token: row.token,
        revision: if(new, do: new.revision, else: old.revision + 1),
        operation: sequence,
        status: :committed
      }

      {{:ok, receipt}, changed}
    end
  end

  defp transport_category_check(state, projected, gate) do
    limit = state.services[gate.service].policy.max_bytes
    current = state.totals[{:service, gate.service}].transport_bytes
    after_transport = projected.totals[{:service, gate.service}].transport_bytes

    if is_integer(limit) and after_transport > current and after_transport > limit,
      do: {:error, :byte_limit},
      else: :ok
  end

  defp growth_checks(old, projected, gate) do
    service = old.services[gate.service]
    instance = old.instances[service.instance]
    current = old.totals
    after_totals = projected.totals
    service_usage = after_totals[{:service, gate.service}]
    instance_limits = effective(instance.policy, old.detection)
    vm_limits = Policy.limits(old.detection)

    cond do
      not old.ready or is_nil(old.detection) ->
        {:error, :budget_unavailable}

      not Process.alive?(gate.owner) or not Process.alive?(service.owner) or
          not Process.alive?(instance.owner) ->
        {:error, :orphaned}

      gate.mode != :ready ->
        {:error, gate.mode}

      service.mode != :ready ->
        {:error, service.mode}

      instance.mode != :ready ->
        {:error, instance.mode}

      total(after_totals.vm) > vm_limits.hard_limit or
          total(after_totals[{:instance, service.instance}]) > instance_limits.hard_limit ->
        {:error, :memory_hard_limit}

      service_usage.leases > old.lease_limit ->
        {:error, :lease_capacity}

      is_integer(service.policy.max_active) and
          service_usage.legacy_leases > service.policy.max_active ->
        {:error, :active_limit}

      is_integer(service.policy.max_bytes) and
          service_usage.transport_bytes > service.policy.max_bytes ->
        {:error, :byte_limit}

      service_usage.connections > service.policy.max_connections ->
        {:error, :connection_limit}

      service_usage.requests > service.policy.max_requests ->
        {:error, :request_limit}

      service_usage.h2_streams + service_usage.h3_streams > service.policy.max_streams ->
        {:error, :stream_limit}

      true ->
        # No new obligation: existing completion credits remain usable even if
        # an unrelated process made a safety observation stale or pressured.
        if total(after_totals.vm) > total(current.vm) or
             after_totals.vm.temporary_bytes > current.vm.temporary_bytes or
             after_totals.vm.pending_processes > current.vm.pending_processes do
          Safety.check(
            after_totals.vm,
            old.safety,
            capacity(old.detection),
            old.now.(),
            old.processes.()
          )
        else
          :ok
        end
    end
  end

  defp change_row(state, old, new) do
    state = if old, do: account(state, old, -1), else: state
    state = if new, do: account(state, new, 1), else: state
    token = if new, do: new.token, else: old.token

    allocations =
      if new,
        do: Map.put(state.allocations, token, new),
        else: Map.delete(state.allocations, token)

    old_retained = if old, do: old.accounting.retained_bytes, else: 0
    new_retained = if new, do: new.accounting.retained_bytes, else: 0

    probe =
      if state.probe do
        %{
          state.probe
          | baseline: max(0, state.probe.baseline + min(0, new_retained - old_retained))
        }
      end

    %{state | allocations: allocations, probe: probe}
  end

  defp account(state, row, sign) do
    scopes = [:vm, {:instance, row.instance}, {:service, row.service}]

    state =
      Enum.reduce(scopes, state, fn scope, state ->
        totals = state.totals[scope]

        totals =
          Enum.reduce(
            [
              :retained_bytes,
              :temporary_bytes,
              :transport_bytes,
              :websocket_bytes,
              :pending_processes
            ],
            totals,
            fn key, totals -> Map.update!(totals, key, &(&1 + sign * row.accounting[key])) end
          )

        legacy_delta = if row.kind in [:guardian, :stream_retention], do: 0, else: sign

        state =
          put_in(state.totals[scope], %{
            totals
            | leases: totals.leases + sign,
              legacy_leases: totals.legacy_leases + legacy_delta
          })

        Enum.reduce(row.accounting.memberships, state, fn {kind, id}, state ->
          key = {scope, row.service, kind, id}
          before = Map.get(state.members, key, 0)
          after_count = before + sign

          members =
            if after_count == 0,
              do: Map.delete(state.members, key),
              else: Map.put(state.members, key, after_count)

          delta =
            cond do
              before == 0 -> 1
              after_count == 0 -> -1
              true -> 0
            end

          counter =
            %{
              connection: :connections,
              request: :requests,
              h2_stream: :h2_streams,
              h3_stream: :h3_streams
            }[kind]

          state = %{state | members: members}
          update_in(state.totals[scope][counter], &(&1 + delta))
        end)
      end)

    state = update_in(state.gates[row.gate].allocations, &(&1 + sign))
    index = elem(row.token, 2)
    tree = state.gates[row.gate].tokens

    tree =
      if sign == 1,
        do: :gb_trees.enter(index, row.token, tree),
        else: :gb_trees.delete_any(index, tree)

    state = put_in(state.gates[row.gate].tokens, tree)
    owner(state, row.owner, sign)
  end

  defp owner(state, pid, sign) do
    count = Map.get(state.owners, pid, 0) + sign

    owners =
      if count == 0, do: Map.delete(state.owners, pid), else: Map.put(state.owners, pid, count)

    dead = if count == 0, do: MapSet.delete(state.dead, pid), else: state.dead
    %{state | owners: owners, dead: dead, effects: [{:monitor, pid, sign} | state.effects]}
  end

  defp receipt(state, ref, sequence, fingerprint, result) do
    gate = state.gates[ref]
    receipts = Map.put(gate.receipts, sequence, %{fingerprint: fingerprint, result: result})
    order = :queue.in(sequence, gate.order)

    {receipts, order} =
      if map_size(receipts) > @receipt_limit do
        {{:value, expired}, order} = :queue.out(order)
        {Map.delete(receipts, expired), order}
      else
        {receipts, order}
      end

    state = receipt_delta(state, gate.service, map_size(receipts) - map_size(gate.receipts))
    put_in(state.gates[ref], %{gate | watermark: sequence, receipts: receipts, order: order})
  end

  defp receipt_delta(state, service, delta) do
    instance = state.services[service].instance

    Enum.reduce([:vm, {:instance, instance}, {:service, service}], state, fn scope, state ->
      update_in(state.totals[scope].receipt_count, &(&1 + delta))
    end)
  end

  defp rejection(state, client, reason) do
    service = state.services[client.service]
    scope = %{instance: service.instance, service: service.scope.id, reason: reason}

    state =
      Enum.reduce([:vm, {:instance, service.instance}, {:service, client.service}], state, fn key,
                                                                                              state ->
        update_in(
          state.rejections,
          &Map.update(&1, key, %{reason => 1}, fn counts ->
            Map.update(counts, reason, 1, fn n -> n + 1 end)
          end)
        )
      end)

    %{state | effects: [{:event, :resource_budget_rejected, %{count: 1}, scope} | state.effects]}
  end

  defp transitions(old, state, instances, service) do
    Enum.reduce([:vm | Enum.map(instances, &{:instance, &1})], state, fn scope, state ->
      limits = scope_limits(state, scope)
      previous_limits = scope_limits(old, scope)
      usage = total(state.totals[scope])
      status = Policy.state(usage, limits.soft_limit, limits.hard_limit)

      previous =
        Policy.state(
          total(old.totals[scope]),
          previous_limits.soft_limit,
          previous_limits.hard_limit
        )

      instance =
        case scope do
          :vm -> :vm
          {:instance, ref} -> ref
        end

      meta = %{
        instance: instance,
        service: if(service, do: state.services[service].scope.id),
        state: status,
        reason: :memory_policy
      }

      measurement = Map.merge(limits, %{usage: usage})

      state =
        if previous != status,
          do: %{
            state
            | effects: [{:event, :resource_budget_state, measurement, meta} | state.effects]
          },
          else: state

      now = state.now.()
      # One shared timestamp plus one per registered instance. Shared pressure
      # must warn even when every instance remains individually below soft.
      last = state.warning_at[scope]
      vm_limits = Policy.limits(state.detection)

      vm_warning? =
        Policy.state(total(state.totals.vm), vm_limits.soft_limit, vm_limits.hard_limit) ==
          :warning

      warn? = status == :warning and (scope == :vm or not vm_warning?)

      log_meta =
        if scope == :vm and service do
          Map.merge(meta, %{instance: state.services[service].instance, budget_scope: :vm})
        else
          Map.put(meta, :budget_scope, scope)
        end

      if warn? and (is_nil(last) or now - last >= 30_000) do
        %{
          state
          | warning_at: Map.put(state.warning_at, scope, now),
            effects: [{:warning, measurement, log_meta} | state.effects]
        }
      else
        state
      end
    end)
  end

  defp inspection(%{fenced: true}, _),
    do: %{availability: :fenced, usage: :unknown, state: :unavailable}

  defp inspection(state, instance) do
    case state.instances[instance] do
      nil ->
        {:error, :unknown_instance}

      row ->
        counters = state.totals[{:instance, instance}]
        limits = effective(row.policy, state.detection)
        vm_limits = Policy.limits(state.detection)

        Map.merge(
          counters,
          Map.merge(limits, %{
            usage: total(counters),
            active_connections: counters.connections,
            active_requests: counters.requests,
            active_h2_streams: counters.h2_streams,
            active_h3_streams: counters.h3_streams,
            availability:
              cond do
                not state.ready or is_nil(state.detection) -> :recovering
                not Safety.fresh?(state.safety, state.now.()) -> :safety_sample_unavailable
                true -> :ready
              end,
            state: Policy.state(total(counters), limits.soft_limit, limits.hard_limit),
            detection: state.detection,
            capacity: if(state.detection, do: state.detection[:capacity]),
            safety: state.safety,
            policy: row.policy,
            mode: row.mode,
            orphaned?: not Process.alive?(row.owner),
            rejections: Map.get(state.rejections, {:instance, instance}, %{}),
            receipt_count: counters.receipt_count,
            vm:
              Map.merge(
                state.totals.vm,
                Map.merge(vm_limits, %{
                  usage: total(state.totals.vm),
                  state:
                    Policy.state(
                      total(state.totals.vm),
                      vm_limits.soft_limit,
                      vm_limits.hard_limit
                    )
                })
              )
          })
        )
    end
  end

  defp allocation_page(iterator, remaining, acc, last) do
    case :gb_trees.next(iterator) do
      :none -> {Enum.reverse(acc), :done}
      _ when remaining == 0 -> {Enum.reverse(acc), last}
      {index, token, next} -> allocation_page(next, remaining - 1, [token | acc], index)
    end
  end

  defp measurements(totals, limits, detection) do
    Map.merge(
      Map.take(totals, [
        :retained_bytes,
        :temporary_bytes,
        :transport_bytes,
        :websocket_bytes,
        :pending_processes
      ]),
      Map.merge(limits, %{
        capacity: capacity(detection),
        usage: total(totals),
        active_connections: totals.connections,
        active_requests: totals.requests,
        active_h2_streams: totals.h2_streams,
        active_h3_streams: totals.h3_streams
      })
    )
  end

  defp registration_action(state, scope, _, {:mode, mode}), do: change_mode(state, scope, mode)

  defp registration_action(state, {kind, ref} = scope, row, {:retire, proof}) do
    count = if kind == :instance, do: row.services, else: row.gates

    cond do
      not is_map(proof) or proof[:terminal] != :confirmed -> {:error, :invalid_terminal_receipt}
      row.mode != :draining and Process.alive?(row.owner) -> {:error, :not_draining}
      count != 0 or state.totals[{kind, ref}].leases != 0 -> {:error, :cleanup_pending}
      true -> {:ok, remove_registration(state, scope)}
    end
  end

  defp registration_action(_, _, _, _), do: {:error, :invalid_operation}
  defp control_receipt_delta(state, {:service, ref}, delta), do: receipt_delta(state, ref, delta)

  defp control_receipt_delta(state, {:instance, ref}, delta) do
    state = update_in(state.totals.vm.receipt_count, &(&1 + delta))
    update_in(state.totals[{:instance, ref}].receipt_count, &(&1 + delta))
  end

  defp control, do: %{watermark: 0, receipts: %{}, order: :queue.new()}
  defp registration(state, {:instance, ref}), do: fetch(state.instances, ref, :unknown_instance)
  defp registration(state, {:service, ref}), do: fetch(state.services, ref, :unknown_service)
  defp registration(_, _), do: {:error, :invalid_scope}
  defp registration_owners(_state, {:instance, _}, row), do: [row.owner]

  defp registration_owners(state, {:service, _}, row),
    do: [row.owner, state.instances[row.instance].owner]

  defp mode_authorization(state, {:gate, _}, gate, actor),
    do: if(authorized?(state, gate, actor), do: :ok, else: {:error, :unauthorized_owner})

  defp mode_authorization(state, scope, _, actor) do
    with {:ok, row} <- registration(state, scope),
         true <- actor in registration_owners(state, scope, row) || {:error, :unauthorized_owner},
         do: :ok
  end

  defp change_mode(state, {kind, ref}, mode) when kind in [:instance, :service, :gate] do
    table = %{instance: :instances, service: :services, gate: :gates}[kind]
    row = state[table][ref]

    cond do
      mode not in [:ready, :paused, :draining] -> {:error, :invalid_mode}
      row.mode == :draining and mode != :draining -> {:error, :draining}
      true -> {:ok, put_in(state, [table, ref, :mode], mode)}
    end
  end

  defp remove_registration(state, {:service, ref}) do
    row = state.services[ref]
    state = receipt_delta(state, ref, -map_size(row.receipts))

    state = %{
      state
      | services: Map.delete(state.services, ref),
        service_keys:
          Map.delete(state.service_keys, {row.instance, row.scope.id, row.scope.generation}),
        totals: Map.delete(state.totals, {:service, ref}),
        rejections: Map.delete(state.rejections, {:service, ref})
    }

    state = update_in(state.instances[row.instance].services, &(&1 - 1))
    owner(state, row.owner, -1)
  end

  defp remove_registration(state, {:instance, ref}) do
    row = state.instances[ref]
    state = update_in(state.totals.vm.receipt_count, &(&1 - map_size(row.receipts)))

    state = %{
      state
      | instances: Map.delete(state.instances, ref),
        instance_keys: Map.delete(state.instance_keys, row.owner),
        totals: Map.delete(state.totals, {:instance, ref}),
        rejections: Map.delete(state.rejections, {:instance, ref}),
        warning_at: Map.delete(state.warning_at, {:instance, ref})
    }

    owner(state, row.owner, -1)
  end

  defp put_control_receipt(row, sequence, fingerprint, result) do
    receipts = Map.put(row.receipts, sequence, %{fingerprint: fingerprint, result: result})
    order = :queue.in(sequence, row.order)

    {receipts, order} =
      if map_size(receipts) > @receipt_limit do
        {{:value, expired}, order} = :queue.out(order)
        {Map.delete(receipts, expired), order}
      else
        {receipts, order}
      end

    %{row | watermark: sequence, receipts: receipts, order: order}
  end

  defp remember_retired(state, scope, row) do
    retired = Map.put(state.retired, scope, Map.take(row, [:receipts, :watermark, :order]))
    order = :queue.in(scope, state.retired_order)

    {retired, order} =
      if map_size(retired) > 64 do
        {{:value, expired}, order} = :queue.out(order)
        {Map.delete(retired, expired), order}
      else
        {retired, order}
      end

    %{state | retired: retired, retired_order: order}
  end

  defp retired_retry(state, scope, sequence, fingerprint) do
    case state.retired[scope] do
      nil ->
        :ok

      row ->
        case row.receipts[sequence] do
          %{fingerprint: ^fingerprint, result: result} -> {:cached, result}
          %{} -> {:error, :operation_conflict}
          nil -> {:error, :unknown_generation}
        end
    end
  end

  defp instance_policy(input) when is_map(input) do
    policy = Map.merge(%{soft_limit: nil, hard_limit: nil, provenance: %{}}, input)

    valid =
      (is_nil(policy.soft_limit) and is_nil(policy.hard_limit)) or
        (is_integer(policy.soft_limit) and policy.soft_limit > 0 and is_integer(policy.hard_limit) and
           policy.hard_limit >= policy.soft_limit and policy.hard_limit <= @maximum)

    if valid and is_map(policy.provenance) and
         Map.keys(input) -- [:soft_limit, :hard_limit, :provenance] == [],
       do: {:ok, policy},
       else: {:error, :invalid_policy}
  end

  defp instance_policy(_), do: {:error, :invalid_policy}

  defp service_policy(input) when is_map(input) do
    policy =
      Map.merge(
        %{
          max_active: nil,
          max_bytes: nil,
          max_connections: 1_000_000,
          max_requests: 1_000_000,
          max_streams: 1_000_000,
          provenance: %{}
        },
        input
      )

    valid =
      Enum.all?([:max_active, :max_bytes], fn key ->
        is_nil(policy[key]) or
          (is_integer(policy[key]) and policy[key] > 0 and policy[key] <= @maximum)
      end) and
        Enum.all?([:max_connections, :max_requests, :max_streams], fn key ->
          is_integer(policy[key]) and policy[key] > 0 and policy[key] <= @maximum
        end)

    if valid and is_map(policy.provenance) and
         Map.keys(input) --
           [:max_active, :max_bytes, :max_connections, :max_requests, :max_streams, :provenance] ==
           [],
       do: {:ok, policy},
       else: {:error, :invalid_policy}
  end

  defp service_policy(_), do: {:error, :invalid_policy}
  defp effective(%{soft_limit: nil, hard_limit: nil}, detection), do: Policy.limits(detection)
  defp effective(policy, _), do: Map.take(policy, [:soft_limit, :hard_limit])
  defp scope_limits(state, :vm), do: Policy.limits(state.detection)

  defp scope_limits(state, {:instance, ref}),
    do: effective(state.instances[ref].policy, state.detection)

  defp capacity(detection),
    do:
      if(detection && is_integer(detection[:capacity]), do: detection.capacity, else: 536_870_912)

  # Candidate rows, counters and monitoring effects are still immutable data.
  # Expiry discards them together, before acknowledgments or terminal receipts.
  defp finalize(original, deadline, candidate) do
    case timely(original, deadline) do
      :ok -> candidate
      {:error, _} = error -> {error, original}
    end
  end

  defp timely(state, deadline),
    do:
      if(is_integer(deadline) and deadline > state.now.(),
        do: :ok,
        else: {:error, :deadline_exceeded}
      )

  defp available(%{fenced: true}), do: {:error, :ledger_fenced}
  defp available(%{ready: false}), do: {:error, :budget_unavailable}
  defp available(%{detection: nil}), do: {:error, :budget_unavailable}
  defp available(_), do: :ok

  defp gate(state, client) do
    cond do
      state.fenced ->
        {:error, :ledger_fenced}

      not is_map(client) or client[:epoch] != state.epoch ->
        {:error, :unknown_generation}

      true ->
        case state.gates[client[:generation]] do
          %{service: service} = gate when service == client.service -> {:ok, gate}
          _ -> {:error, :unknown_generation}
        end
    end
  end

  defp client(state, service, generation),
    do: %{epoch: state.epoch, service: service, generation: generation}

  defp authorized?(state, gate, actor) do
    service = state.services[gate.service]
    actor in [gate.owner, service.owner, state.instances[service.instance].owner]
  end

  defp fetch(map, key, error) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, error}
    end
  end

  defp total(row), do: row.retained_bytes + row.temporary_bytes

  defp zero,
    do: %{
      retained_bytes: 0,
      temporary_bytes: 0,
      transport_bytes: 0,
      websocket_bytes: 0,
      pending_processes: 0,
      receipt_count: 0,
      leases: 0,
      legacy_leases: 0,
      connections: 0,
      requests: 0,
      h2_streams: 0,
      h3_streams: 0
    }
end
