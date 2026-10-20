defmodule Gaoxy.Proxy.ManagedPin do
  @moduledoc false
  alias Gaoxy.Lifecycle

  def release(%{provider: provider, owner: owner} = pin, deadline)
      when provider in [Gaoxy.Proxy.UpstreamTransports, Gaoxy.Proxy.UpstreamGroups] do
    case Lifecycle.call(owner, {:release, pin}, deadline) do
      {:error, :not_running} = error -> obsolete(pin, error, deadline)
      result -> result
    end
  end

  defp obsolete(%{owner: owner, owner_epoch: epoch, ref: ref, kind: kind}, error, deadline)
       when node(owner) == node() and is_reference(epoch) and is_reference(ref) and
              kind in [:baseline, :preparation, :request] do
    monitor = Process.monitor(owner)

    # These providers hold pin metadata only in this PID/epoch. Transport
    # custodians survive owner death and independently join scope retirement;
    # group/probe/guardian holder monitors retain nested transport cleanup.
    result =
      receive do
        {:DOWN, ^monitor, :process, ^owner, _} -> :ok
      after
        Lifecycle.remaining(deadline) -> error
      end

    Process.demonitor(monitor, [:flush])
    result
  end

  defp obsolete(_, error, _deadline), do: error
end
