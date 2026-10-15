defmodule Gaoxy.HTTP.Router do
  @moduledoc """
  Immutable first-match HTTP routes. Hosts are case-insensitive; methods and raw
  paths are exact. Prefixes match complete path segments, never `/apiary` for
  `/api`. No percent decoding, forwarding-header trust, or header mutation occurs
  during routing. Target endpoints own their explicit header policy.
  """
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.HTTP1.Parser
  alias Gaoxy.HTTP.Response
  defstruct [:generation, routes: [], resources: []]

  @impl true
  def init(%__MODULE__{} = router), do: {:ok, router}
  def init(routes), do: compile(routes)

  def compile(routes) when is_list(routes) do
    Enum.reduce_while(routes, {:ok, []}, fn input, {:ok, acc} ->
      case compile_route(input) do
        {:ok, route} -> {:cont, {:ok, [route | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, routes} ->
        with {:ok, resources} <- collect_resources(routes),
             do:
               {:ok,
                %__MODULE__{
                  generation: make_ref(),
                  routes: Enum.reverse(routes),
                  resources: resources
                }}

      error ->
        error
    end
  end

  def compile(_), do: {:error, :invalid_routes}

  @doc false
  def validate_resource_sidecar(%__MODULE__{routes: routes, resources: resources})
      when is_list(routes) do
    with {:ok, supplied} <- Gaoxy.HTTP.Resources.validate(resources),
         {:ok, expected} <- collect_resources(routes, :compiled),
         true <- MapSet.equal?(MapSet.new(supplied), MapSet.new(expected)) do
      :ok
    else
      _ -> {:error, :invalid_endpoint_resources}
    end
  end

  def validate_resource_sidecar(_), do: {:error, :invalid_endpoint_resources}

  defp collect_resources(routes, mode \\ :compile) do
    Enum.reduce_while(routes, {:ok, []}, fn %{target: {module, options}}, {:ok, acc} ->
      handles =
        if mode == :compiled,
          do: compiled_resources(module, options),
          else:
            if(function_exported?(module, :resources, 1), do: module.resources(options), else: [])

      with {:ok, handles} <- Gaoxy.HTTP.Resources.validate(handles),
           {:ok, union} <- Gaoxy.HTTP.Resources.validate(Enum.uniq(acc ++ handles)) do
        {:cont, {:ok, union}}
      else
        error -> {:halt, error}
      end
    end)
  rescue
    _ -> {:error, :invalid_endpoint_resources}
  catch
    _, _ -> {:error, :invalid_endpoint_resources}
  end

  defp compiled_resources(__MODULE__, router) do
    with :ok <- validate_resource_sidecar(router), do: resources(router)
  end

  defp compiled_resources(module, options) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :resources, 1),
      do: module.resources(options),
      else: []
  end

  @impl true
  def resources(router), do: router.resources

  def match(%__MODULE__{routes: routes}, request) do
    case Enum.find(routes, &matches?(&1, request)) do
      nil -> :not_found
      route -> {:ok, route.target}
    end
  end

  @impl true
  def call(exchange, router) do
    case match(router, exchange.request) do
      {:ok, {module, options}} ->
        module.call(exchange, options)

      :not_found ->
        case Response.send_resp(exchange, 404, [], "Not Found") do
          {:ok, exchange} -> {:ok, exchange}
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  defp compile_route(%{target: {module, options}} = input) when is_atom(module) do
    with true <-
           Map.keys(input) -- [:host, :path, :methods, :target] == [] ||
             {:error, :unknown_route_options},
         {:ok, host} <- host(Map.get(input, :host, :any)),
         {:ok, path} <- path(Map.get(input, :path, :any)),
         {:ok, methods} <- methods(Map.get(input, :methods, :any)),
         true <-
           (Code.ensure_loaded?(module) and function_exported?(module, :init, 1) and
              function_exported?(module, :call, 2)) || {:error, :invalid_endpoint},
         {:ok, options} <- module.init(options) do
      {:ok, %{host: host, path: path, methods: methods, target: {module, options}}}
    end
  end

  defp compile_route(_), do: {:error, :invalid_route}

  defp host(:any), do: {:ok, :any}

  defp host(value) when is_binary(value) do
    case Parser.parse_authority(value) do
      {:ok, host, nil} -> {:ok, host}
      _ -> {:error, :invalid_route_host}
    end
  end

  defp host(_), do: {:error, :invalid_route_host}

  defp path(:any), do: {:ok, :any}
  defp path({:prefix, "/"}), do: {:ok, {:prefix, "/"}}

  defp path({:prefix, value}) when is_binary(value) do
    if valid_path?(value) and not String.ends_with?(value, "/"),
      do: {:ok, {:prefix, value}},
      else: {:error, :invalid_route_path}
  end

  defp path(value) when is_binary(value) do
    if valid_path?(value), do: {:ok, {:exact, value}}, else: {:error, :invalid_route_path}
  end

  defp path(_), do: {:error, :invalid_route_path}

  defp valid_path?("/" <> _ = value) do
    Enum.all?(:binary.bin_to_list(value), &(&1 in 33..126 and &1 not in [??, ?#, ?\\])) and
      not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, value)
  end

  defp valid_path?(_), do: false

  defp methods(:any), do: {:ok, :any}

  defp methods(values) when is_list(values) and values != [] do
    if Enum.all?(
         values,
         &(is_binary(&1) and Regex.match?(~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/, &1))
       ),
       do: {:ok, MapSet.new(values)},
       else: {:error, :invalid_route_methods}
  end

  defp methods(_), do: {:error, :invalid_route_methods}

  defp matches?(route, request) do
    (route.host == :any or route.host == request.host) and
      (route.methods == :any or MapSet.member?(route.methods, request.method)) and
      path_match?(route.path, request.path)
  end

  defp path_match?(:any, _), do: true
  defp path_match?({:exact, path}, request), do: path == request
  defp path_match?({:prefix, "/"}, request), do: String.starts_with?(request, "/")

  defp path_match?({:prefix, path}, request),
    do: request == path or String.starts_with?(request, path <> "/")
end
