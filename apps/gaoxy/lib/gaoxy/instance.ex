defmodule Gaoxy.Instance do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Activation, Lifecycle, RegistryPolicy}

  def start_link(plan) do
    case GenServer.start(
           __MODULE__,
           {plan, self()},
           if(plan.name, do: [name: plan.name], else: [])
         ) do
      {:ok, pid} = result ->
        Process.link(pid)
        result

      error ->
        error
    end
  rescue
    error in ArgumentError ->
      if match?({:via, Registry, {Gaoxy.Registry, _}}, plan.name) or
           match?({:via, Registry, {Gaoxy.Registry, _, _}}, plan.name),
         do: {:error, :registry_unavailable},
         else: reraise(error, __STACKTRACE__)
  end

  def drain_timeout(services),
    do: Enum.max(Enum.map(services, & &1.limits.drain_timeout), fn -> 5_000 end)

  @impl true
  def init({plan, parent}) do
    Process.flag(:trap_exit, true)

    case RegistryPolicy.watch_name(plan.name) do
      {:ok, registry_monitor} -> init_services(plan, parent, registry_monitor)
      {:error, reason} -> {:stop, reason}
    end
  end

  defp init_services(plan, parent, registry_monitor) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    state = %{
      table: :ets.new(__MODULE__, [:set, :public]),
      live: :ets.new(__MODULE__, [:set, :public]),
      supervisor: supervisor,
      scope: make_ref(),
      parent: parent,
      parent_monitor: Process.monitor(parent),
      registry_monitor: registry_monitor,
      drain_timeout: drain_timeout(plan.services),
      participants: %{},
      operations: %{},
      activation_mode: Map.get(plan, :activation, :immediate),
      planned_services: plan.services,
      activation_control: :ets.new(Activation, [:set, :public]),
      activation: nil,
      activation_receipt: nil,
      stopping: nil
    }

    # Retain the complete plan and budgets while preparing instance-bound state.
    services =
      if state.activation_mode == :deferred or Map.get(plan, :defer_services, false),
        do: [],
        else: plan.services

    case Enum.reduce_while(services, :ok, fn spec, _ ->
           case start_service(spec, state) do
             {:ok, _} -> {:cont, :ok}
             {:error, reason} -> {:halt, {:error, reason}}
           end
         end) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        terminate(reason, state)
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:services, _, state),
    do: {:reply, Enum.map(:ets.tab2list(state.table), &elem(&1, 0)), state}

  def handle_call({:lookup, id}, _, state), do: {:reply, lookup(state, id), state}

  def handle_call({:activation_status, operation}, _, state) do
    receipt = activation_record(state, operation)

    result =
      if receipt,
        do: {:ok, Map.take(receipt, [:operation_id, :status, :result, :cleanup])},
        else: {:error, :unknown_operation}

    {:reply, result, state}
  end

  def handle_call({:activate, _, _, _}, _, %{stopping: stopping} = state)
      when not is_nil(stopping),
      do: {:reply, {:error, :stopping}, state}

  def handle_call({:activate, services, operation, deadline}, from, state) do
    current = activation_record(state, operation)

    cond do
      current && current.operation_id == operation && current.services != services ->
        {:reply, {:error, :operation_conflict}, state}

      current && current.operation_id == operation ->
        result = current.result || {:error, {:activation_pending, operation}}
        {:reply, result, state}

      state.activation ->
        {:reply, {:error, :activation_in_progress}, state}

      state.activation_mode == :cleanup_pending ->
        {:reply, {:error, :cleanup_pending}, state}

      state.activation_mode != :deferred ->
        {:reply, {:error, :already_activated}, state}

      true ->
        owner = self()
        caller = elem(from, 0)
        context = activation_context(state)
        :ets.insert(state.activation_control, {operation, :pending})

        {pid, monitor} =
          :erlang.spawn_opt(
            fn ->
              Activation.run(
                owner,
                caller,
                operation,
                deadline,
                services,
                state.planned_services,
                context,
                &start_service(&1, state)
              )
            end,
            [:link, :monitor]
          )

        activation = %{
          operation_id: operation,
          services: services,
          status: :pending,
          result: nil,
          cleanup: :pending,
          pid: pid,
          monitor: monitor,
          caller: caller,
          caller_monitor: Process.monitor(caller),
          from: from,
          deadline: deadline,
          timer:
            Process.send_after(
              owner,
              {:activation_deadline, operation, pid},
              Lifecycle.remaining(deadline)
            )
        }

        {:noreply, %{state | activation: activation}}
    end
  end

  def handle_call({:register_lifecycle_participant, _}, _, %{stopping: stopping} = state)
      when not is_nil(stopping),
      do: {:reply, {:error, :stopping}, state}

  def handle_call({:register_lifecycle_participant, deadline}, {pid, _}, state) do
    cond do
      Lifecycle.remaining(deadline) == 0 ->
        {:reply, {:error, {:deadline_exceeded, :cleanup_pending}}, state}

      Enum.any?(state.participants, fn {_, participant} -> participant.pid == pid end) ->
        {:reply, {:error, :already_registered}, state}

      map_size(state.participants) >= 64 ->
        {:reply, {:error, :participant_limit}, state}

      true ->
        registration = make_ref()
        participant = %{pid: pid, monitor: Process.monitor(pid), outcome: nil}
        {:reply, {:ok, registration}, put_in(state.participants[registration], participant)}
    end
  end

  def handle_call({:add, _}, _, %{stopping: stopping} = state) when not is_nil(stopping),
    do: {:reply, {:error, :stopping}, state}

  def handle_call({:add, _}, _, %{activation_mode: :deferred} = state),
    do: {:reply, {:error, :activation_required}, state}

  def handle_call({:add, _}, _, %{activation_mode: :cleanup_pending} = state),
    do: {:reply, {:error, :cleanup_pending}, state}

  def handle_call({:add, input}, _, state) do
    result =
      with {:ok, plan} <-
             Gaoxy.Config.validate(
               services: [input | Enum.map(:ets.tab2list(state.table), &elem(&1, 1))]
             ),
           true <-
             hd(plan.services).limits.drain_timeout <= state.drain_timeout ||
               {:error, :shutdown_budget_exceeded} do
        start_service(hd(plan.services), state)
      end

    {:reply, result, state}
  end

  def handle_call({:remove, _id, _deadline}, _, %{stopping: stopping} = state)
      when not is_nil(stopping),
      do: {:reply, {:error, :stopping}, state}

  def handle_call({:remove, _, _}, _, %{activation: activation} = state)
      when not is_nil(activation),
      do: {:reply, {:error, :activation_in_progress}, state}

  def handle_call({:remove, id, deadline}, from, state) do
    key = if is_map(id), do: id.id, else: id

    with false <- Map.has_key?(state.operations, key),
         {:ok, pid, generation} <- lookup(state, id) do
      operation = operation([{key, pid, generation}], deadline, from, key)
      {:noreply, put_in(state.operations[key], operation)}
    else
      true -> {:reply, {:error, :already_draining}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:stop, _}, _, %{stopping: stopping} = state) when not is_nil(stopping),
    do: {:reply, {:error, :stopping}, state}

  def handle_call({:stop, deadline}, from, state) do
    state = cancel_activation(state, :stopping)

    operation =
      operation(live_services(state), deadline, from, :instance, state.participants, state)

    {:noreply, %{state | stopping: operation}}
  end

  @impl true
  def handle_info(
        {:activation_ready, operation, worker, handles},
        %{activation: %{operation_id: operation, pid: worker} = activation} = state
      ) do
    cond do
      state.stopping != nil ->
        {:noreply, cancel_activation(state, :stopping)}

      Lifecycle.remaining(activation.deadline) == 0 ->
        {:noreply, cancel_activation(state, :deadline_exceeded)}

      not Process.alive?(activation.caller) ->
        {:noreply, cancel_activation(state, :caller_down)}

      :ets.lookup(state.activation_control, operation) != [{operation, :pending}] ->
        {:noreply, state}

      true ->
        send(worker, {:activation_commit, operation})
        {:noreply, finish_activation(state, {:ok, handles}, :committed, :complete)}
    end
  end

  def handle_info(
        {:activation_done, operation, worker, result, cleanup},
        %{activation: %{operation_id: operation, pid: worker}} = state
      ) do
    {:noreply, finish_activation(state, result, :rejected, cleanup)}
  end

  def handle_info(
        {:activation_deadline, operation, worker},
        %{activation: %{operation_id: operation, pid: worker}} = state
      ),
      do: {:noreply, cancel_activation(state, :deadline_exceeded)}

  def handle_info({:operation_done, token, result}, state) do
    cond do
      state.stopping && state.stopping.token == token ->
        Process.demonitor(state.stopping.monitor, [:flush])

        {:stop, :normal,
         %{state | stopping: Map.merge(state.stopping, %{result: result, completed: true})}}

      true ->
        case Enum.find(state.operations, fn {_, op} -> op.token == token end) do
          {id, op} ->
            Process.demonitor(op.monitor, [:flush])

            result =
              case result do
                {:error, {:services, [{^id, error}]}} -> error
                other -> other
              end

            GenServer.reply(op.from, result)
            {:noreply, %{state | operations: Map.delete(state.operations, id)}}

          nil ->
            {:noreply, state}
        end
    end
  end

  def handle_info({:DOWN, ref, :process, _, reason}, %{parent_monitor: ref} = state),
    do: {:stop, reason, state}

  def handle_info({:DOWN, ref, :process, _, _}, %{registry_monitor: ref} = state),
    do: {:stop, :normal, %{state | drain_timeout: min(state.drain_timeout, 1_000)}}

  def handle_info({:DOWN, ref, :process, _, _}, %{activation: %{caller_monitor: ref}} = state),
    do: {:noreply, cancel_activation(state, :caller_down)}

  def handle_info(
        {:DOWN, ref, :process, _, reason},
        %{activation: %{monitor: ref} = activation} = state
      ) do
    state = cancel_activation(state, {:activation_worker_exit, reason})
    owner = self()
    context = activation_context(state)

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          cleanup = Activation.rollback(context)

          send(
            owner,
            {:activation_done, activation.operation_id, self(),
             {:error, {:activation_worker_exit, reason}}, cleanup}
          )
        end,
        [:link, :monitor]
      )

    {:noreply, %{state | activation: %{state.activation | pid: pid, monitor: monitor}}}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, state) do
    case Enum.find(state.operations, fn {_, op} -> op.monitor == ref end) do
      {id, op} ->
        GenServer.reply(op.from, {:error, {:cleanup_failed, {:coordinator_exit, reason}}})
        {:noreply, %{state | operations: Map.delete(state.operations, id)}}

      nil ->
        if state.stopping && state.stopping.monitor == ref do
          {:stop, :normal,
           %{
             state
             | stopping:
                 Map.put(
                   state.stopping,
                   :result,
                   {:error, {:cleanup_failed, {:coordinator_exit, reason}}}
                 )
           }}
        else
          participants =
            Map.new(state.participants, fn
              {registration, %{monitor: ^ref} = participant} ->
                {registration, %{participant | outcome: {:error, :cleanup_unconfirmed}}}

              entry ->
                entry
            end)

          {:noreply, %{state | participants: participants}}
        end
    end
  end

  def handle_info({:EXIT, pid, reason}, %{supervisor: pid} = state), do: {:stop, reason, state}
  def handle_info({:EXIT, pid, reason}, %{parent: pid} = state), do: {:stop, reason, state}
  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    state = cancel_activation(state, :stopping)

    deadline =
      if state.stopping,
        do: state.stopping.deadline,
        else: Lifecycle.deadline(state.drain_timeout)

    # Children still run their normal callback loops while the instance is in
    # terminate/2. No service needs a call to this instance to complete cleanup.
    unless state.stopping && Map.get(state.stopping, :completed, false) do
      Lifecycle.drain_all(live_services(state), state.participants, deadline)
    end

    cleanup_deadline = deadline + Lifecycle.cleanup_headroom()

    result =
      Lifecycle.protect(fn ->
        Supervisor.stop(state.supervisor, :normal, Lifecycle.remaining(cleanup_deadline))
      end)

    if result != :ok do
      resources = Lifecycle.resources(state.supervisor, self())
      Lifecycle.terminate_resources(resources, deadline + 2 * Lifecycle.cleanup_headroom())
    end

    Enum.each(state.operations, fn {_, op} -> Process.exit(op.pid, :kill) end)

    if state.stopping do
      Process.exit(state.stopping.pid, :kill)

      GenServer.reply(
        state.stopping.from,
        Map.get(state.stopping, :result, {:error, {:deadline_exceeded, :cleanup_pending}})
      )
    end
  end

  defp lookup(state, handle) do
    {id, expected} =
      case handle do
        %{id: id, generation: generation} -> {id, generation}
        id -> {id, nil}
      end

    case :ets.lookup(state.live, id) do
      [{^id, pid, generation}] ->
        cond do
          expected != nil and expected != generation ->
            {:error, :stale_generation}

          not Process.alive?(pid) ->
            {:error, :not_running}

          true ->
            case RegistryPolicy.lookup({state.scope, id}) do
              {:ok, [{^pid, ^generation}]} -> {:ok, pid, generation}
              _ -> {:error, :registry_unavailable}
            end
        end

      [] ->
        case RegistryPolicy.lookup({state.scope, id}) do
          {:error, :registry_unavailable} -> {:error, :registry_unavailable}
          _ -> {:error, :not_running}
        end
    end
  end

  defp live_services(state),
    do:
      for(
        {id, pid, generation} <- :ets.tab2list(state.live),
        Process.alive?(pid),
        do: {id, pid, generation}
      )

  defp operation(services, deadline, from, id, participants \\ %{}, state \\ nil) do
    owner = self()
    token = make_ref()

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          result =
            if state && state.activation do
              result = Lifecycle.drain_services(services, deadline)
              # A pending start can still create a dependent listener. Retain
              # cleanup participants until its owned rollback has completed.
              Activation.wait(state.activation_control, state.activation.operation_id)
              late_result = Lifecycle.drain_all(live_services(state), participants, deadline)
              if result == :ok, do: late_result, else: result
            else
              Lifecycle.drain_all(services, participants, deadline)
            end

          send(owner, {:operation_done, token, result})
        end,
        [:link, :monitor]
      )

    %{pid: pid, monitor: monitor, token: token, from: from, id: id, deadline: deadline}
  end

  defp activation_context(state),
    do: %{
      supervisor: state.supervisor,
      table: state.table,
      live: state.live,
      control: state.activation_control
    }

  defp activation_record(state, operation),
    do:
      Enum.find([state.activation, state.activation_receipt], fn record ->
        record && record.operation_id == operation
      end)

  defp cancel_activation(%{activation: nil} = state, _), do: state

  defp cancel_activation(state, reason) do
    activation = state.activation

    case :ets.lookup(state.activation_control, activation.operation_id) do
      [{_, :pending}] ->
        :ets.insert(state.activation_control, {activation.operation_id, {:cancelled, reason}})
        send(activation.pid, {:activation_cancel, activation.operation_id, reason})

      _ ->
        :ok
    end

    state
  end

  defp finish_activation(state, result, status, cleanup) do
    activation = state.activation
    Process.cancel_timer(activation.timer)
    Process.demonitor(activation.monitor, [:flush])
    Process.demonitor(activation.caller_monitor, [:flush])
    GenServer.reply(activation.from, result)

    if state.activation_receipt,
      do: :ets.delete(state.activation_control, state.activation_receipt.operation_id)

    :ets.insert(
      state.activation_control,
      {activation.operation_id, if(status == :committed, do: :committed, else: :complete)}
    )

    receipt = Map.merge(activation, %{status: status, result: result, cleanup: cleanup})

    %{
      state
      | activation: nil,
        activation_receipt: receipt,
        activation_mode:
          cond do
            status == :committed -> :immediate
            cleanup == :pending -> :cleanup_pending
            true -> state.activation_mode
          end
    }
  end

  defp start_service(spec, state) do
    :ets.insert(state.table, {spec.id, spec})

    case DynamicSupervisor.start_child(
           state.supervisor,
           {Gaoxy.Service, {state.table, state.live, spec.id, state.scope}}
         ) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, {:request, nil, :handle})}

      {:error, reason} ->
        :ets.delete(state.table, spec.id)
        {:error, reason}
    end
  end
end
