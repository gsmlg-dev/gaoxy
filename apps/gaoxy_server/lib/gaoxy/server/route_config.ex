defmodule Gaoxy.Server.RouteConfig do
  @moduledoc """
  Version 1 data-only route files for a stable `Gaoxy.HTTP.Generation` listener.
  Registered targets are `static` and `reverse_proxy`; input creates no atoms
  or modules. Reload prepares a complete candidate before atomic activation.
  Listener transport/address/TLS changes require an explicit restart.
  """
  alias Gaoxy.HTTP.{Generation, Router}
  @max_routes 1024

  def load(path) do
    with {:ok, bytes} <- Gaoxy.Server.Config.read_file(path),
         {:ok, data} <- JSON.decode(bytes),
         do: decode(data)
  end

  def reload(store, path, timeout \\ 5_000, profile \\ nil)

  def reload(store, path, timeout, profile) when is_integer(timeout) and timeout > 0 do
    deadline = Gaoxy.Lifecycle.deadline(timeout)

    loader = fn ->
      with {:ok, routes} <- load(path),
           :ok <- validate_routes(routes, profile),
           do: {:ok, routes}
    end

    with {:ok, expected, _} <- Generation.snapshot(store, Gaoxy.Lifecycle.remaining(deadline)),
         {:ok, prepared} <-
           Generation.prepare_with(store, loader, Gaoxy.Lifecycle.remaining(deadline)),
         do: Generation.activate(store, expected, prepared, Gaoxy.Lifecycle.remaining(deadline))
  end

  def reload(_, _, _, _), do: {:error, :invalid_reload_timeout}

  @doc false
  def validate_routes(%Router{routes: routes}, profile), do: validate_routes(routes, profile)
  def validate_routes(_routes, nil), do: :ok

  def validate_routes(routes, profile) do
    Enum.reduce_while(routes, :ok, fn
      %{target: {Gaoxy.Server.StaticEndpoint, options}}, :ok ->
        case Gaoxy.Server.StaticEndpoint.validate_limits(options, profile) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      _route, :ok ->
        {:cont, :ok}
    end)
  end

  def decode(%{"version" => 1, "routes" => routes} = data) when is_list(routes) do
    with :ok <- keys(data, ["version", "routes"]),
         true <- length(routes) <= @max_routes || {:error, :route_limit},
         {:ok, routes} <- traverse(routes, &route/1),
         {:ok, _} <- Router.compile(routes),
         do: {:ok, routes}
  end

  def decode(_), do: {:error, :invalid_route_configuration}

  defp route(data) when is_map(data) do
    with :ok <- keys(data, ["host", "path", "prefix", "methods", "target"]),
         true <-
           not (Map.has_key?(data, "path") and Map.has_key?(data, "prefix")) ||
             {:error, :ambiguous_route_path},
         {:ok, target} <- target(data["target"]) do
      route = %{target: target}
      route = if Map.has_key?(data, "host"), do: Map.put(route, :host, data["host"]), else: route

      route =
        if Map.has_key?(data, "methods"),
          do: Map.put(route, :methods, data["methods"]),
          else: route

      route = if Map.has_key?(data, "path"), do: Map.put(route, :path, data["path"]), else: route

      route =
        if Map.has_key?(data, "prefix"),
          do: Map.put(route, :path, {:prefix, data["prefix"]}),
          else: route

      {:ok, route}
    end
  end

  defp route(_), do: {:error, :invalid_route_configuration}

  defp target(%{"type" => "static"} = data) do
    with :ok <- keys(data, ["type", "status", "body", "headers"]),
         {:ok, headers} <- headers(Map.get(data, "headers", [])),
         {:ok, options} <-
           Gaoxy.Server.StaticEndpoint.init(%{
             status: Map.get(data, "status", 200),
             body: Map.get(data, "body", ""),
             headers: headers
           }),
         do: {:ok, {Gaoxy.Server.StaticEndpoint, options}}
  end

  defp target(%{"type" => "reverse_proxy"} = data) do
    with :ok <- keys(data, ["type", "upstream", "cacertfile", "upstream_protocol"]),
         {:ok, protocol} <- upstream_protocol(Map.get(data, "upstream_protocol", "http1")),
         options = %{upstream: data["upstream"], upstream_protocol: protocol},
         options =
           if(Map.has_key?(data, "cacertfile"),
             do: Map.put(options, :cacertfile, data["cacertfile"]),
             else: options
           ),
         {:ok, options} <- Gaoxy.Proxy.HTTP.init(options),
         do: {:ok, {Gaoxy.Proxy.HTTP, options}}
  end

  defp target(_), do: {:error, :unregistered_route_target}

  defp upstream_protocol("http1"), do: {:ok, :http1}
  defp upstream_protocol("http3"), do: {:ok, :http3}
  defp upstream_protocol(_), do: {:error, :invalid_upstream_protocol}

  defp headers(headers) when is_list(headers) and length(headers) <= 100 do
    traverse(headers, fn
      [name, value] when is_binary(name) and is_binary(value) ->
        if Regex.match?(~r/\A[!#$%&'*+.^_`|~0-9a-z-]+\z/, name) and
             not String.contains?(value, ["\r", "\n", <<0>>]),
           do: {:ok, {name, value}},
           else: {:error, :invalid_static_headers}

      _ ->
        {:error, :invalid_static_headers}
    end)
  end

  defp headers(_), do: {:error, :invalid_static_headers}

  defp keys(data, allowed) do
    if Map.keys(data) -- allowed == [],
      do: :ok,
      else: {:error, :invalid_route_configuration}
  end

  defp traverse(values, fun) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
