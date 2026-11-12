defmodule Gaoxy.Proxy.Quarantine do
  @moduledoc false
  # Reports an upstream resource entering a fail-closed state that only a reload
  # or restart clears. Metadata is limited to atoms and opaque identifiers.
  require Logger

  def report(component, reason, metadata \\ %{}) do
    metadata = Map.merge(metadata, %{component: component, reason: reason})
    Gaoxy.Telemetry.emit(:upstream_quarantined, %{count: 1}, %{}, metadata)
    Logger.warning("upstream #{component} quarantined: #{inspect(reason)}")
  end
end
