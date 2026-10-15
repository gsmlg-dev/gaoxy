defmodule Gaoxy.Application do
  @moduledoc false
  use Application
  @impl true
  def start(_, _) do
    with {:ok, supervisor} <-
           Supervisor.start_link(
             [{Registry, keys: :unique, name: Gaoxy.Registry}],
             strategy: :one_for_one
           ) do
      :ok = Gaoxy.Telemetry.attach_backend()
      {:ok, supervisor}
    end
  end

  @impl true
  def stop(_), do: :telemetry.detach(Gaoxy.Telemetry)
end
