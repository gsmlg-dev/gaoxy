defmodule Gaoxy.Server.RouteConfig do
  @moduledoc """
  Version 1 data-only route files for a stable `Gaoxy.HTTP.Generation` listener.
  Registered targets are `static`, `reverse_proxy`, `websocket` and
  `upstream_group`; input creates no atoms
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
         do: activate(store, expected, prepared, deadline)
  end

  def reload(_, _, _, _), do: {:error, :invalid_reload_timeout}

  defp activate(store, expected, prepared, deadline) do
    if Process.whereis(Gaoxy.Server.RouteResources) do
      Gaoxy.Server.RouteResources.activate(store, expected, prepared, deadline)
    else
      if Enum.any?(prepared.routes, &match?(%{target: {Gaoxy.Server.UpstreamEndpoint, _}}, &1)),
        do: {:error, :upstream_runtime_unavailable},
        else: Generation.activate(store, expected, prepared, Gaoxy.Lifecycle.remaining(deadline))
    end
  end

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
    if data["upstream_protocol"] in ["http2", "h2c"] or Map.get(data, "managed", false) != false do
      Gaoxy.Server.UpstreamEndpoint.fixed(data)
    else
      dedicated_proxy(Map.delete(data, "managed"))
    end
  end

  defp target(%{"type" => "websocket"} = data) do
    allowed =
      ~w(upstream cacertfile max_message_bytes max_fragments opening_timeout idle_timeout write_timeout close_timeout max_lifetime)a

    with {:ok, options} <- endpoint_options(data, allowed),
         {:ok, options} <- Gaoxy.Proxy.WebSocket.init(options),
         do: {:ok, {Gaoxy.Proxy.WebSocket, options}}
  end

  defp target(%{"type" => "upstream_group"} = data), do: Gaoxy.Server.UpstreamEndpoint.group(data)
  defp target(_), do: {:error, :unregistered_route_target}

  defp dedicated_proxy(data) do
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

  defp endpoint_options(data, allowed) do
    names = Map.new(allowed, &{Atom.to_string(&1), &1})

    with :ok <- keys(data, ["type" | Map.keys(names)]),
         do: {:ok, Map.new(Map.delete(data, "type"), fn {key, value} -> {names[key], value} end)}
  end

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
