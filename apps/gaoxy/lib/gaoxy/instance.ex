defmodule Gaoxy.Instance do
  @moduledoc false
  use GenServer
  alias Gaoxy.{Lifecycle, RegistryPolicy}

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
      stopping: nil
    }

    # Standalone prepares instance-bound resources before opening listeners.
    # Its internal plan retains the complete service list for the shutdown cap.
    services = if Map.get(plan, :defer_services, false), do: [], else: plan.services

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
    operation = operation(live_services(state), deadline, from, :instance, state.participants)
    {:noreply, %{state | stopping: operation}}
  end

  @impl true
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

  defp operation(services, deadline, from, id, participants \\ %{}) do
    owner = self()
    token = make_ref()

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          result = Lifecycle.drain_all(services, participants, deadline)
          send(owner, {:operation_done, token, result})
        end,
        [:link, :monitor]
      )

    %{pid: pid, monitor: monitor, token: token, from: from, id: id, deadline: deadline}
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
