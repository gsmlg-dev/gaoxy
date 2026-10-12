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
      for %{handler: handler, handler_options: %{endpoint: {Router, router}}} = spec <- services,
          handler in [Gaoxy.HTTP.Connection, Gaoxy.HTTP.HTTP3.Connection] do
        profile = Map.take(spec.handler_options, [:protocols, :http_limits])

        profile =
          if handler == Gaoxy.HTTP.HTTP3.Connection,
            do: Map.put(profile, :protocols, [:http3]),
            else: profile

        name = {:via, Registry, {Gaoxy.Server.RouteStores, spec.id, profile}}

        Supervisor.child_spec({Generation, router: router, name: name},
          id: {:routes, spec.id}
        )
      end

    services = Enum.map(services, &generation_service/1)
    runtime_options = [name: Gaoxy.Server.Runtime, services: services]
    runtime = Supervisor.child_spec({Gaoxy, runtime_options}, [])
    runtime = %{runtime | start: {__MODULE__, :start_runtime, [runtime_options]}}

    children =
      [{Registry, keys: :unique, name: Gaoxy.Server.RouteStores}] ++
        stores ++ [runtime]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc false
  def start_runtime(options) do
    Enum.reduce_while(options[:services], {:ok, []}, fn spec, {:ok, services} ->
      case initialize_generation(spec) do
        {:ok, spec} -> {:cont, {:ok, [spec | services]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, services} -> Gaoxy.start_link(Keyword.put(options, :services, Enum.reverse(services)))
      error -> error
    end
  end

  defp initialize_generation(
         %{
           handler: Gaoxy.HTTP.HTTP3.Connection,
           handler_options: %{endpoint: {Generation, store}} = options
         } = spec
       ) do
    with {:ok, initialized} <- Generation.init(store),
         do:
           {:ok,
            %{
              spec
              | handler_options: %{
                  options
                  | endpoint: {Generation, initialized},
                    initialized: true
                }
            }}
  end

  defp initialize_generation(spec), do: {:ok, spec}

  defp generation_service(
         %{handler: handler, handler_options: %{endpoint: {Router, _}} = options} =
           spec
       )
       when handler in [Gaoxy.HTTP.Connection, Gaoxy.HTTP.HTTP3.Connection] do
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
