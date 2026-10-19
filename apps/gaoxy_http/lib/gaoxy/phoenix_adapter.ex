defmodule Gaoxy.PhoenixAdapter do
  @moduledoc """
  Phoenix Endpoint server adapter. One Endpoint child owns a Gaoxy instance and
  its configured HTTP and HTTPS services. An externally mounted Endpoint sets
  `server: false` so its supervisor does not create another listener.
  """

  @http_options [
    :ip,
    :port,
    :limits,
    :http_limits,
    :protocols,
    :h2c,
    :h2_limits,
    :extended_connect
  ]
  @https_options @http_options ++ [:certfile, :keyfile, :versions, :alpn]

  def child_specs(endpoint, config) when is_atom(endpoint) and is_list(config) do
    if Keyword.get(config, :server) == false do
      []
    else
      services =
        [:http, :https]
        |> Enum.flat_map(fn scheme ->
          case Keyword.get(config, scheme) do
            nil -> []
            false -> []
            options -> [service!(endpoint, scheme, options, config)]
          end
        end)

      if services == [] do
        []
      else
        options = [name: instance_name(endpoint), services: services]
        [%{Gaoxy.child_spec(options) | id: {__MODULE__, endpoint}}]
      end
    end
  end

  def server_info(endpoint, scheme) when scheme in [:http, :https] do
    case Process.whereis(instance_name(endpoint)) do
      nil ->
        {:error, :not_running}

      pid ->
        case Gaoxy.info(pid, service_id(endpoint, scheme)) do
          %{local: local} -> local
          error -> error
        end
    end
  end

  def server_info(_, _), do: {:error, :invalid_scheme}

  defp service!(endpoint, scheme, options, config)
       when is_list(options) do
    allowed = if scheme == :https, do: @https_options, else: @http_options

    if not Keyword.keyword?(options) or
         Enum.any?(Keyword.keys(options), &(&1 not in allowed)) do
      raise ArgumentError, "invalid #{scheme} listener options for #{inspect(endpoint)}"
    end

    port = port!(Keyword.get(options, :port, if(scheme == :http, do: 4000, else: 4040)))

    {plug_module, plug_options} =
      if Keyword.get(config, :code_reloader, false),
        do: {Phoenix.Endpoint.SyncCodeReloadPlug, {endpoint, []}},
        else: {endpoint, []}

    target = if plug_module == endpoint, do: endpoint, else: {plug_module, plug_options}
    paths = Keyword.get(config, :websocket_paths, [])

    args = [
      id: service_id(endpoint, scheme),
      ip: Keyword.get(options, :ip, {127, 0, 0, 1}),
      port: port,
      transport: if(scheme == :http, do: :tcp, else: :tls),
      endpoint:
        {Gaoxy.HTTP.PlugEndpoint, {Gaoxy.PhoenixWebSocket, {target, paths}, :endpoint_managed}},
      limits: Keyword.get(options, :limits, %{}),
      http_limits: Keyword.get(options, :http_limits, %{}),
      h2c: Keyword.get(options, :h2c, :disabled),
      extended_connect: Keyword.get(options, :extended_connect, false),
      h2_limits: Keyword.get(options, :h2_limits, %{})
    ]

    args = args ++ Keyword.take(options, [:protocols])

    args =
      if scheme == :https do
        tls =
          options
          |> Keyword.take([:certfile, :keyfile, :versions, :alpn])
          |> Map.new()

        Keyword.put(args, :tls, tls)
      else
        args
      end

    case Gaoxy.HTTP.service_spec(args) do
      {:ok, service} ->
        service

      {:error, reason} ->
        raise ArgumentError,
              "invalid #{scheme} listener for #{inspect(endpoint)}: #{inspect(reason)}"
    end
  end

  defp service!(endpoint, scheme, _options, _config),
    do: raise(ArgumentError, "invalid #{scheme} listener options for #{inspect(endpoint)}")

  defp port!(port) when is_integer(port) and port in 0..65_535, do: port

  defp port!(port) when is_binary(port) do
    case Integer.parse(port) do
      {value, ""} when value in 0..65_535 -> value
      _ -> raise ArgumentError, "invalid Phoenix listener port"
    end
  end

  defp port!(_), do: raise(ArgumentError, "invalid Phoenix listener port")

  defp instance_name(endpoint), do: Module.concat(endpoint, GaoxyInstance)

  defp service_id(endpoint, scheme),
    do: Module.concat(endpoint, if(scheme == :http, do: HTTP, else: HTTPS))
end
