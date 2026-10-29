defmodule Gaoxy.ResourceBudget.Sampler do
  @moduledoc false
  use GenServer
  alias Gaoxy.ResourceBudget.{Authority, Safety, SystemMemory, Supervisor}

  def start_link(options),
    do:
      GenServer.start_link(__MODULE__, options,
        name: Supervisor.name(__MODULE__, Keyword.fetch!(options, :identity))
      )

  def refresh(server) do
    GenServer.call(server, :refresh, 4500)
  catch
    :exit, _ -> {:error, :budget_unavailable}
  end

  @impl true
  def init(options) do
    Process.flag(:trap_exit, true)
    identity = Keyword.fetch!(options, :identity)

    state = %{
      authority: Supervisor.name(Authority, identity),
      worker: nil,
      waiters: [],
      refresh_pending: false,
      detection: nil,
      capacity_at: nil,
      capacity_probe: Keyword.get(options, :capacity_probe, &SystemMemory.detect/0),
      safety_probe: Keyword.get(options, :safety_probe, &Safety.detect/1),
      now: Keyword.get(options, :now, fn -> System.monotonic_time(:millisecond) end)
    }

    Process.send_after(self(), :tick, 1000)
    {:ok, launch(state, true)}
  end

  @impl true
  def handle_call(:refresh, from, state) do
    cond do
      length(state.waiters) >= 64 ->
        {:reply, {:error, :refresh_busy}, state}

      state.worker ->
        {:noreply,
         %{
           state
           | waiters: [from | state.waiters],
             refresh_pending: state.refresh_pending or not state.worker.capacity?
         }}

      true ->
        {:noreply, launch(%{state | waiters: [from]}, true)}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, 1000)
    due = is_nil(state.capacity_at) or state.now.() - state.capacity_at >= 60_000

    active =
      case safe_call(state.authority, :probe_context) do
        %{active?: active} -> active
        _ -> false
      end

    if is_nil(state.worker) and (due or active),
      do: {:noreply, launch(state, due)},
      else: {:noreply, state}
  end

  def handle_info(
        {:probe_result, pid, detection, safety},
        %{worker: %{pid: pid} = worker} = state
      ),
      do: {:noreply, %{state | worker: %{worker | result: {detection, safety}}}}

  def handle_info({:probe_timeout, pid}, %{worker: %{pid: pid}} = state) do
    Process.exit(pid, :kill)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{worker: %{monitor: ref} = worker} = state) do
    Process.cancel_timer(worker.timer)

    {detection, safety} =
      worker.result ||
        {state.detection || SystemMemory.select(nil, []), {:error, :safety_sample_unavailable}}

    result = safe_call(state.authority, {:install, detection, safety, worker.probe_id})

    state = %{
      state
      | worker: nil,
        detection: detection,
        capacity_at: if(worker.capacity?, do: state.now.(), else: state.capacity_at)
    }

    if state.refresh_pending do
      {:noreply, launch(%{state | refresh_pending: false}, true)}
    else
      Enum.each(state.waiters, &GenServer.reply(&1, result))
      {:noreply, %{state | waiters: []}}
    end
  end

  def handle_info(_, state), do: {:noreply, state}
  @impl true
  def terminate(_, %{worker: nil}), do: :ok

  def terminate(_, %{worker: worker}) do
    Process.exit(worker.pid, :kill)

    receive do
      {:DOWN, ref, :process, _, _} when ref == worker.monitor -> :ok
    after
      1000 -> :ok
    end
  end

  defp launch(state, capacity?) do
    probe_id = make_ref()

    case safe_call(state.authority, {:begin_sample, probe_id}) do
      :ok ->
        start_probe(state, capacity?, probe_id)

      error ->
        Enum.each(state.waiters, &GenServer.reply(&1, error))
        %{state | waiters: [], refresh_pending: false}
    end
  end

  defp start_probe(state, capacity?, probe_id) do
    parent = self()

    {pid, ref} =
      :erlang.spawn_opt(
        fn ->
          detection =
            if capacity?, do: validated_detection(state.capacity_probe.()), else: state.detection

          safety = state.safety_probe.(detection)
          send(parent, {:probe_result, self(), detection, safety})
        end,
        [:link, :monitor]
      )

    timer = Process.send_after(self(), {:probe_timeout, pid}, 2500)

    %{
      state
      | worker: %{
          pid: pid,
          monitor: ref,
          timer: timer,
          result: nil,
          capacity?: capacity?,
          probe_id: probe_id
        }
    }
  end

  defp validated_detection(%{capacity: n} = detection)
       when is_integer(n) and n in 2..9_223_372_036_854_775_807,
       do: detection

  defp validated_detection(%{capacity: nil, fallback?: true} = detection), do: detection

  defp validated_detection(_),
    do: SystemMemory.select(nil, [], %{reasons: [:invalid_capacity_snapshot]})

  defp safe_call(server, request) do
    GenServer.call(server, request, 4000)
  catch
    :exit, _ -> {:error, :budget_unavailable}
  end
end
