defmodule Gaoxy.Proxy.Gateway.Control do
  @moduledoc false
  use GenServer
  alias Gaoxy.HTTP.Generation
  alias Gaoxy.Lifecycle

  def start_link(context), do: GenServer.start_link(__MODULE__, context, name: context.control)
  def context(control), do: GenServer.call(control, :context)
  def context(control, deadline), do: Lifecycle.call(control, :bounded_context, deadline)
  def phase(control), do: GenServer.call(control, :phase, 50)
  def recovering(control, epoch), do: recovering(control, epoch, Lifecycle.deadline(5_000))

  def recovering(control, epoch, deadline),
    do: Lifecycle.call(control, {:recovering, epoch, deadline}, deadline)

  def ready(control, epoch), do: ready(control, epoch, Lifecycle.deadline(5_000))

  def ready(control, epoch, deadline),
    do: Lifecycle.call(control, {:ready, epoch, deadline}, deadline)

  def drain(control, deadline), do: Lifecycle.call(control, {:drain, deadline}, deadline)
  def info(control), do: GenServer.call(control, :info)

  @impl true
  def init(context), do: {:ok, %{context: context, phase: :starting, epoch: nil}}
  @impl true
  def handle_call(:context, _, state), do: {:reply, state.context, state}
  def handle_call(:bounded_context, _, state), do: {:reply, {:ok, state.context}, state}
  def handle_call(:phase, _, state), do: {:reply, state.phase, state}

  def handle_call({:recovering, _, _}, _, %{phase: :draining} = state),
    do: {:reply, {:error, :gateway_draining}, state}

  def handle_call({:recovering, epoch, deadline}, _, state) do
    if Lifecycle.remaining(deadline) > 0,
      do: {:reply, :ok, %{state | phase: :recovering, epoch: epoch}},
      else: {:reply, {:error, :startup_timeout}, state}
  end

  def handle_call({:ready, epoch, deadline}, _, %{epoch: epoch, phase: phase} = state)
      when phase != :draining do
    if Lifecycle.remaining(deadline) > 0,
      do: {:reply, :ok, %{state | phase: :ready}},
      else: {:reply, {:error, :startup_timeout}, state}
  end

  def handle_call({:ready, _, _}, _, state), do: {:reply, {:error, :gateway_draining}, state}

  def handle_call({:drain, deadline}, _, state) do
    # This stable process precedes the runtime subtree. Each Store serializes
    # its own barrier against the authoritative route commit.
    result =
      Enum.reduce_while(state.context.stores, :ok, fn {_, store}, :ok ->
        case Generation.drain(store, deadline) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    {:reply, result, %{state | phase: :draining}}
  end

  def handle_call(:info, _, state) do
    context = state.context
    instance = GenServer.whereis(context.instance)
    listeners = if instance, do: Enum.map(context.planned, &listener_info(instance, &1)), else: []

    sets =
      Map.new(context.stores, fn {id, store} ->
        {id,
         case Generation.accepted(store, 100) do
           {:ok, accepted} -> accepted
           error -> %{state: :unavailable, error: error}
         end}
      end)

    phase =
      if state.phase == :ready and Enum.any?(listeners, &(&1.state != :ready)),
        do: :degraded,
        else: state.phase

    preparations = preparation_status(context.coordinator)

    cleanup =
      if state.phase == :draining or preparations != %{preparation_pins: 0},
        do: :pending,
        else:
          if(Enum.any?(sets, fn {_, s} -> s[:cleanup_pending] end),
            do: :pending,
            else: :confirmed
          )

    info = %{
      phase: phase,
      instance: instance,
      runtime_epoch: state.epoch,
      listener_sets: sets,
      listeners: listeners,
      cleanup: cleanup,
      preparations: preparations,
      coordinator: GenServer.whereis(context.coordinator),
      upstream_owners: GenServer.whereis(context.owners)
    }

    {:reply, info, state}
  end

  defp preparation_status(coordinator) do
    case GenServer.call(coordinator, :cleanup_status, 50) do
      %{preparation_pins: count} = status when is_integer(count) and count >= 0 -> status
      _ -> %{preparation_pins: :unknown}
    end
  catch
    :exit, _ -> %{preparation_pins: :unknown}
  end

  defp listener_info(instance, spec) do
    case Gaoxy.info(instance, spec.id) do
      %{mode: mode} = info -> Map.merge(info, %{id: spec.id, state: mode})
      error -> %{id: spec.id, state: :recovering, error: error}
    end
  end
end
