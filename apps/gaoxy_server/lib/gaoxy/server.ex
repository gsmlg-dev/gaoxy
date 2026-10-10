defmodule Gaoxy.Server do
  @moduledoc "Local operations for the standalone runtime; route reload leaves listener settings intact."

  def reload_routes(service_id, path, timeout \\ 5_000) do
    with true <-
           Process.whereis(Gaoxy.Server.RouteStores) != nil || {:error, :unknown_http_service},
         [{store, profile}] <- Registry.lookup(Gaoxy.Server.RouteStores, service_id) do
      Gaoxy.Server.RouteConfig.reload(store, path, timeout, profile)
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
