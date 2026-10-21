defmodule Gaoxy.HTTP.ListenerSet.Owner do
  @moduledoc false
  use GenServer
  alias Gaoxy.HTTP.ListenerSet
  alias Gaoxy.Lifecycle

  @impl true
  def init({plan, options, parent}) do
    parent_monitor = Process.monitor(parent)
    Process.flag(:trap_exit, true)
    deadline = Lifecycle.deadline(plan.startup_timeout)
    operation = make_ref()

    result =
      with :ok <- ListenerSet.preflight(plan),
           {:ok, planned} <- ListenerSet.planned_services(plan),
           {:ok, instance} <-
             Gaoxy.start_link(
               services: planned,
               activation: :deferred,
               name: options[:instance_name]
             ) do
        prepared =
          Lifecycle.bounded(
            fn ->
              ListenerSet.prepare(plan, instance: instance, activation_id: operation)
            end,
            Lifecycle.remaining(deadline)
          )

        result =
          with {:ok, services} <- prepared,
               {:ok, _} <-
                 Gaoxy.activate(instance, services,
                   deadline: deadline,
                   timeout: Lifecycle.remaining(deadline),
                   operation_id: operation
                 ),
               {:ok, listeners} <-
                 Lifecycle.bounded(
                   fn -> {:ok, ListenerSet.inspect_listeners(instance, plan)} end,
                   Lifecycle.remaining(deadline)
                 ),
               true <- Lifecycle.remaining(deadline) > 0 || {:error, :startup_timeout},
               true <-
                 Enum.all?(listeners, &(&1.state == :ready)) || {:error, :listeners_not_ready},
               do:
                 {:ok,
                  %{
                    plan: plan,
                    instance: instance,
                    deadline: deadline,
                    parent: parent,
                    parent_monitor: parent_monitor
                  }}

        case result do
          {:ok, state} ->
            {:ok, state}

          error ->
            cleanup = Gaoxy.stop(instance, max(1, Lifecycle.remaining(deadline)))

            if cleanup == :ok,
              do: error,
              else: {:error, {:startup_failed, error, :cleanup_pending, instance}}
        end
      end

    case result do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
      other -> {:stop, {:preparation_failed, other}}
    end
  end

  @impl true
  def handle_call(:info, _, state) do
    listeners = ListenerSet.inspect_listeners(state.instance, state.plan)
    phase = if Enum.all?(listeners, &(&1.state == :ready)), do: :ready, else: :degraded

    {:reply, %{id: state.plan.id, phase: phase, instance: state.instance, listeners: listeners},
     state}
  end

  @impl true
  def handle_info({:EXIT, parent, reason}, %{parent: parent} = state),
    do: {:stop, reason, state}

  def handle_info({:DOWN, monitor, :process, _, _}, %{parent_monitor: monitor} = state),
    do: {:stop, :normal, state}

  def handle_info({:EXIT, instance, reason}, %{instance: instance} = state),
    do: {:stop, reason, state}

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_, state) do
    if Process.alive?(state.instance) do
      drain =
        Enum.map(state.plan.listeners, fn {_, options} ->
          Map.get(Keyword.get(options, :limits, %{}), :drain_timeout, 5_000)
        end)

      Gaoxy.stop(state.instance, Enum.max(drain, fn -> 5_000 end) + 1_000)
    end

    :ok
  end
end
