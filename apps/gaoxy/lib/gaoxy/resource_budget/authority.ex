defmodule Gaoxy.ResourceBudget.Authority do
  @moduledoc false
  use GenServer
  require Logger
  alias Gaoxy.ResourceBudget.{Ledger, Supervisor}

  def start_link(options),
    do:
      GenServer.start_link(__MODULE__, options,
        name: Supervisor.name(__MODULE__, Keyword.fetch!(options, :identity))
      )

  @impl true
  def init(options) do
    identity = Keyword.fetch!(options, :identity)

    state = %{
      server: Supervisor.name(__MODULE__, identity),
      ledger: Supervisor.name(Ledger, identity),
      sampler: Supervisor.name(Gaoxy.ResourceBudget.Sampler, identity),
      ledger_monitor: nil,
      generation: nil,
      monitors: %{},
      recovering: true
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case connect(state) do
      {:ok, state} ->
        {:noreply, state, {:continue, {:recover, :start}}}

      :error ->
        Process.send_after(self(), :connect, 10)
        {:noreply, state}
    end
  end

  def handle_continue({:recover, cursor}, state) do
    {owners, next} = GenServer.call(state.ledger, {:page, state.generation, cursor})
    state = Enum.reduce(owners, state, fn {pid, count}, state -> monitor(state, pid, count) end)

    case next do
      :done ->
        {_, effects} = write(state, :ready, self())
        {:noreply, effects(state, effects), {:continue, :recovered}}

      next ->
        {:noreply, state, {:continue, {:recover, next}}}
    end
  end

  def handle_continue(:recovered, state), do: {:noreply, %{state | recovering: false}}

  @impl true
  def handle_call(:sampler, _, %{generation: nil} = state) do
    case connect(state) do
      {:ok, state} -> {:reply, {:ok, state.sampler}, state, {:continue, {:recover, :start}}}
      :error -> {:reply, {:error, :budget_unavailable}, state}
    end
  end

  def handle_call(:sampler, _, state), do: {:reply, {:ok, state.sampler}, state}

  def handle_call(request, {actor, _}, state) do
    if state.generation do
      {result, changes} = write(state, request, actor)

      result =
        case {request, result} do
          {{:register_gate, _, _, _}, {:ok, client}} ->
            {:ok, Map.put(client, :server, state.server)}

          _ ->
            result
        end

      {:reply, result, effects(state, changes)}
    else
      {:reply, {:error, :budget_unavailable}, state}
    end
  end

  @impl true
  def handle_info(:connect, %{generation: nil} = state),
    do: {:noreply, state, {:continue, :connect}}

  def handle_info(:connect, state), do: {:noreply, state}

  def handle_info({:DOWN, ref, :process, _, _}, %{ledger_monitor: ref} = state) do
    Process.send_after(self(), :connect, 10)
    Enum.each(state.monitors, fn {_, {monitor, _}} -> Process.demonitor(monitor, [:flush]) end)
    {:noreply, %{state | generation: nil, ledger_monitor: nil, monitors: %{}, recovering: true}}
  end

  def handle_info({:DOWN, ref, :process, pid, _}, state) do
    case state.monitors[pid] do
      {^ref, count} ->
        {_, changes} = write(state, {:down, pid}, self())
        # Keep the canonical count so later release can reconcile an orphan.
        {:noreply,
         effects(%{state | monitors: Map.put(state.monitors, pid, {nil, count})}, changes)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:transition_page, old_detection, cursor}, state) do
    {result, changes} = write(state, {:transition_page, old_detection, cursor}, self())

    case result do
      {:ok, :done} -> :ok
      {:ok, next} -> send(self(), {:transition_page, old_detection, next})
      _ -> :ok
    end

    {:noreply, effects(state, changes)}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp connect(state) do
    case GenServer.whereis(state.ledger) do
      nil ->
        :error

      pid ->
        case GenServer.call(pid, :claim) do
          {:ok, _epoch, generation, _fenced} ->
            {:ok, %{state | generation: generation, ledger_monitor: Process.monitor(pid)}}

          _ ->
            :error
        end
    end
  catch
    :exit, _ -> :error
  end

  defp write(state, request, actor) do
    GenServer.call(state.ledger, {:write, state.generation, request, actor}, 4500)
  catch
    :exit, _ -> {{:error, :budget_unavailable}, []}
  end

  defp effects(state, changes) do
    Enum.reduce(changes, state, fn
      {:refresh_transitions, old_detection}, state ->
        send(self(), {:transition_page, old_detection, :start})
        state

      {:monitor, pid, delta}, state ->
        monitor(state, pid, delta)

      {:event, event, measurement, metadata}, state ->
        Gaoxy.Telemetry.emit(event, measurement, metadata)
        state

      {:warning, measurement, metadata}, state ->
        Logger.warning("resource budget warning", Map.to_list(Map.merge(measurement, metadata)))
        state
    end)
  end

  defp monitor(state, pid, delta) do
    {ref, count} = Map.get(state.monitors, pid, {nil, 0})
    next = count + delta

    monitors =
      cond do
        next <= 0 ->
          if ref, do: Process.demonitor(ref, [:flush])
          Map.delete(state.monitors, pid)

        count == 0 ->
          Map.put(state.monitors, pid, {Process.monitor(pid), next})

        true ->
          Map.put(state.monitors, pid, {ref, next})
      end

    %{state | monitors: monitors}
  end
end
