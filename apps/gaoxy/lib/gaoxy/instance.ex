defmodule Gaoxy.Instance do
  @moduledoc false
  use GenServer

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
  end

  @impl true
  def init({plan, parent}) do
    Process.flag(:trap_exit, true)
    table = :ets.new(__MODULE__, [:set, :public])
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    state = %{
      table: table,
      supervisor: supervisor,
      scope: make_ref(),
      parent: parent,
      parent_monitor: Process.monitor(parent)
    }

    case Enum.reduce_while(plan.services, :ok, fn spec, _ ->
           case start_service(spec, state) do
             {:ok, _} -> {:cont, :ok}
             {:error, reason} -> {:halt, {:error, reason}}
           end
         end) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Supervisor.stop(supervisor)
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:services, _, state),
    do: {:reply, Enum.map(:ets.tab2list(state.table), &elem(&1, 0)), state}

  def handle_call({:lookup, id}, _, state) do
    {id, expected} =
      case id do
        %{id: id, generation: generation} -> {id, generation}
        id -> {id, nil}
      end

    result =
      case Registry.lookup(Gaoxy.Registry, {state.scope, id}) do
        [{pid, generation}] when is_nil(expected) or expected == generation ->
          {:ok, pid, generation}

        [_] ->
          {:error, :stale_generation}

        [] ->
          {:error, :not_running}
      end

    {:reply, result, state}
  end

  def handle_call({:add, input}, _, state) do
    result =
      with {:ok, plan} <-
             Gaoxy.Config.validate(
               services: [input | Enum.map(:ets.tab2list(state.table), &elem(&1, 1))]
             ) do
        start_service(hd(plan.services), state)
      end

    {:reply, result, state}
  end

  def handle_call({:remove, id, pid}, _, state) do
    id = if is_map(id), do: id.id, else: id

    case Registry.lookup(Gaoxy.Registry, {state.scope, id}) do
      [{^pid, _}] ->
        :ok = DynamicSupervisor.terminate_child(state.supervisor, pid)
        :ets.delete(state.table, id)
        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :stale_generation}, state}
    end
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{supervisor: pid} = state), do: {:stop, reason, state}
  def handle_info({:EXIT, pid, reason}, %{parent: pid} = state), do: {:stop, reason, state}

  def handle_info({:DOWN, ref, :process, _, reason}, %{parent_monitor: ref} = state),
    do: {:stop, reason, state}

  def handle_info(_, state), do: {:noreply, state}
  @impl true
  def terminate(_, state),
    do: if(Process.alive?(state.supervisor), do: Supervisor.stop(state.supervisor))

  defp start_service(spec, state) do
    :ets.insert(state.table, {spec.id, spec})

    case DynamicSupervisor.start_child(
           state.supervisor,
           {Gaoxy.Service, {state.table, spec.id, state.scope}}
         ) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, {:request, nil, :handle})}

      {:error, reason} ->
        :ets.delete(state.table, spec.id)
        {:error, reason}
    end
  end
end
