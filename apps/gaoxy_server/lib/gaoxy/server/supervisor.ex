defmodule Gaoxy.Server.Supervisor do
  @moduledoc "Standalone registration adapter for the reusable Proxy Gateway."
  def child_spec(options),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}, type: :supervisor}

  def start_link(options) do
    Gaoxy.Proxy.Gateway.start_link(
      options ++
        [
          host: [
            name: __MODULE__,
            runtime_name: Gaoxy.Server.Runtime,
            owner_name: Gaoxy.Server.UpstreamOwners,
            coordinator_name: Gaoxy.Server.RouteResources,
            coordinator_id: Gaoxy.Server.RouteResources,
            store_registry: Gaoxy.Server.RouteStores,
            runtime_group_id: Gaoxy.Server.UpstreamSupervisor
          ]
        ]
    )
  end

  def route_store(id), do: {:via, Registry, {Gaoxy.Server.RouteStores, id}}
end
