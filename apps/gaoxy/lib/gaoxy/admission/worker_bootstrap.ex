defmodule Gaoxy.Admission.WorkerBootstrap do
  @moduledoc false
  alias Gaoxy.Lifecycle

  def run(gate, owner, activation, deadline, {module, function, args}) do
    Process.link(owner)
    owner_monitor = Process.monitor(owner)
    gate_monitor = Process.monitor(gate)

    receive do
      {:gaoxy_admitted_worker_activate, ^activation, lease} when is_reference(lease) ->
        if Process.alive?(owner) and Process.alive?(gate) and Lifecycle.remaining(deadline) > 0 do
          Process.demonitor(owner_monitor, [:flush])
          Process.demonitor(gate_monitor, [:flush])
          apply(module, function, [lease | args])
        end

      {:DOWN, ^owner_monitor, :process, ^owner, _} ->
        :ok

      {:DOWN, ^gate_monitor, :process, ^gate, _} ->
        :ok
    after
      Lifecycle.remaining(deadline) -> :ok
    end
  end
end
