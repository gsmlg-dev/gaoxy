defmodule Gaoxy.Server do
  @moduledoc "Local operations for the standalone runtime; route reload leaves listener settings intact."

  def reload_routes(service_id, path, timeout \\ 5_000) do
    with true <-
           Process.whereis(Gaoxy.Server.RouteStores) != nil || {:error, :unknown_http_service},
         [{store, profile}] <- Registry.lookup(Gaoxy.Server.RouteStores, service_id) do
      deadline = Gaoxy.Lifecycle.deadline(timeout)

      loader = fn ->
        with {:ok, routes} <- Gaoxy.Server.RouteConfig.load(path),
             :ok <- Gaoxy.Server.RouteConfig.validate_routes(routes, profile),
             do: {:ok, routes}
      end

      with {:ok, prepared} <-
             Gaoxy.HTTP.Generation.prepare_with(
               store,
               loader,
               Gaoxy.Lifecycle.remaining(deadline)
             ),
           routes = Enum.map(prepared.routes, &Gaoxy.Proxy.Gateway.Declaration.route_input/1),
           {:ok, accepted} <-
             Gaoxy.HTTP.Generation.accepted(store, max(1, Gaoxy.Lifecycle.remaining(deadline))),
           true <- Gaoxy.Lifecycle.remaining(deadline) > 0 || {:error, :reload_timeout},
           {:ok, %{generation: generation}} <-
             Gaoxy.Proxy.Gateway.reload_routes(Gaoxy.Server.Supervisor, service_id, routes,
               expected_revision: accepted.revision,
               deadline: deadline,
               timeout: Gaoxy.Lifecycle.remaining(deadline)
             ) do
        {:ok, generation}
      end
    else
      [] -> {:error, :unknown_http_service}
      {:error, _} = error -> error
    end
  rescue
    ArgumentError -> {:error, :unknown_http_service}
  catch
    :exit, _ -> {:error, :unknown_http_service}
  end
end
