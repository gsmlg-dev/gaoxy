defmodule Gaoxy.Server.Supervisor do
  @moduledoc "Supervises standalone configuration generations before their dependent listeners."
  use Supervisor
  alias Gaoxy.HTTP.{Generation, Router}

  def start_link(options) do
    with {:ok, config} <- Gaoxy.Config.validate(options),
         do: Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  def route_store(id), do: {:via, Registry, {Gaoxy.Server.RouteStores, id}}

  @impl true
  def init(%{services: services}) do
    stores =
      for %{handler: Gaoxy.HTTP.Connection, handler_options: %{endpoint: {Router, router}}} = spec <-
            services do
        profile = Map.take(spec.handler_options, [:protocols, :http_limits])
        name = {:via, Registry, {Gaoxy.Server.RouteStores, spec.id, profile}}

        Supervisor.child_spec({Generation, router: router, name: name},
          id: {:routes, spec.id}
        )
      end

    services = Enum.map(services, &generation_service/1)

    children =
      [{Registry, keys: :unique, name: Gaoxy.Server.RouteStores}] ++
        stores ++ [{Gaoxy, name: Gaoxy.Server.Runtime, services: services}]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp generation_service(
         %{handler: Gaoxy.HTTP.Connection, handler_options: %{endpoint: {Router, _}} = options} =
           spec
       ) do
    %{
      spec
      | handler_options: %{
          options
          | endpoint: {Generation, route_store(spec.id)},
            initialized: false
        }
    }
  end

  defp generation_service(spec), do: spec
end
