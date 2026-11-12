defmodule Gaoxy.RegistrySupervisor do
  @moduledoc false
  use Supervisor

  @registry Gaoxy.Registry
  # Bounded wait for a previous Registry generation's processes to exit.
  @stale_timeout 5_000

  def start_link(options \\ []), do: Supervisor.start_link(__MODULE__, options)

  def child_spec(options),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}, type: :supervisor}

  # A dedicated supervisor absorbs Registry restarts, so a Registry failure
  # costs the application supervisor (and the resource-budget ledger, which
  # fences for the VM lifetime once lost) at most one restart.
  @impl true
  def init(_options) do
    Supervisor.init(
      [
        %{
          id: @registry,
          start: {__MODULE__, :start_registry, [[keys: :unique, name: @registry]]},
          type: :supervisor
        }
      ],
      strategy: :one_for_one
    )
  end

  # Registry partitions trap exits and terminate asynchronously after an abrupt
  # supervisor death. Wait for that previous generation instead of failing the
  # restart with `already_started` and exhausting restart intensity.
  @doc false
  def start_registry(options),
    do: start_registry(options, Gaoxy.Lifecycle.deadline(@stale_timeout))

  defp start_registry(options, deadline) do
    case Registry.start_link(options) do
      {:error, reason} = error ->
        with pid when is_pid(pid) <- stale(reason),
             true <- await_exit(pid, deadline) do
          start_registry(options, deadline)
        else
          _ -> error
        end

      started ->
        started
    end
  end

  defp stale({:already_started, pid}) when is_pid(pid), do: pid

  defp stale({:shutdown, {:failed_to_start_child, _, {:already_started, pid}}})
       when is_pid(pid),
       do: pid

  defp stale(_), do: nil

  defp await_exit(pid, deadline) do
    monitor = Process.monitor(pid)

    receive do
      {:DOWN, ^monitor, :process, ^pid, _} -> true
    after
      Gaoxy.Lifecycle.remaining(deadline) ->
        Process.demonitor(monitor, [:flush])
        false
    end
  end
end
