defmodule Gaoxy.PhoenixAdapter do
  @moduledoc """
  Phoenix Endpoint server adapter. One Endpoint child owns a ListenerSet and
  one Gaoxy instance for its configured HTTP, HTTPS and optional HTTP/3 roles.
  An externally mounted Endpoint sets `server: false`.

  Enable H3 explicitly with `http3: [ip: ..., port: ..., certfile: ..., keyfile: ...]`
  and include `gaoxy_http3` in the host dependencies. `listeners/1` reports actual
  transport addresses; Phoenix's `url` remains the configured public origin.
  """
  alias Gaoxy.HTTP.ListenerSet

  @http_options [
    :ip,
    :port,
    :limits,
    :hell_options,
    :http_limits,
    :protocols,
    :h2c,
    :h2_limits,
    :extended_connect
  ]
  @https_options @http_options ++
                   [
                     :certfile,
                     :keyfile,
                     :versions,
                     :alpn,
                     :verify,
                     :cacertfile,
                     :fail_if_no_peer_cert
                   ]
  @h3_options [
    :ip,
    :port,
    :certfile,
    :keyfile,
    :limits,
    :http_limits,
    :h3_limits,
    :abyss_options,
    :extended_connect
  ]

  def child_specs(endpoint, config) when is_atom(endpoint) and is_list(config) do
    if Keyword.get(config, :server) == false do
      []
    else
      listeners =
        Enum.flat_map([:http, :https, :http3], fn role ->
          case Keyword.get(config, role) do
            disabled when disabled in [nil, false] -> []
            options -> [{role, options!(endpoint, role, options)}]
          end
        end)

      if listeners == [] do
        []
      else
        target =
          if Keyword.get(config, :code_reloader, false),
            do: {Phoenix.Endpoint.SyncCodeReloadPlug, {endpoint, []}},
            else: endpoint

        paths = Keyword.get(config, :websocket_paths, [])

        options = [
          id: endpoint,
          endpoint:
            {Gaoxy.HTTP.PlugEndpoint,
             {Gaoxy.PhoenixWebSocket, {target, paths}, :endpoint_managed}},
          listeners: listeners,
          service_ids: Map.new(listeners, fn {role, _} -> {role, service_id(endpoint, role)} end),
          discovery: Keyword.get(config, :http3_discovery, false)
        ]

        case ListenerSet.plan(options) do
          {:ok, plan} ->
            child =
              ListenerSet.child_spec(
                plan: plan,
                name: owner_name(endpoint),
                instance_name: instance_name(endpoint)
              )

            [%{child | id: {__MODULE__, endpoint}}]

          {:error, reason} ->
            raise ArgumentError, "invalid listeners for #{inspect(endpoint)}: #{inspect(reason)}"
        end
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

  @doc "Returns the current logical phase and physical listener metadata, including UDP H3."
  def listeners(endpoint) do
    case Process.whereis(owner_name(endpoint)) do
      nil -> {:error, :not_running}
      owner -> ListenerSet.info(owner)
    end
  end

  defp options!(endpoint, role, options) when is_list(options) do
    allowed =
      case role do
        :http -> @http_options
        :https -> @https_options
        :http3 -> @h3_options
      end

    if not Keyword.keyword?(options) or length(options) != map_size(Map.new(options)) or
         Enum.any?(Keyword.keys(options), &(&1 not in allowed)) do
      raise ArgumentError, "invalid #{role} listener options for #{inspect(endpoint)}"
    end

    if role == :http3 and
         not Enum.all?([:ip, :port, :certfile, :keyfile], &Keyword.has_key?(options, &1)),
       do: raise(ArgumentError, "http3 requires explicit ip, port, certfile and keyfile")

    default = if role == :http, do: 4000, else: 4040
    Keyword.put(options, :port, port!(Keyword.get(options, :port, default)))
  end

  defp options!(endpoint, role, _),
    do: raise(ArgumentError, "invalid #{role} listener options for #{inspect(endpoint)}")

  defp port!(port) when is_integer(port) and port in 0..65_535, do: port

  defp port!(port) when is_binary(port) do
    case Integer.parse(port) do
      {value, ""} when value in 0..65_535 -> value
      _ -> raise ArgumentError, "invalid Phoenix listener port"
    end
  end

  defp port!(_), do: raise(ArgumentError, "invalid Phoenix listener port")
  defp instance_name(endpoint), do: Module.concat(endpoint, GaoxyInstance)
  defp owner_name(endpoint), do: Module.concat(endpoint, GaoxyListenerSet)

  defp service_id(endpoint, role),
    do:
      Module.concat(
        endpoint,
        case role do
          :http -> HTTP
          :https -> HTTPS
          :http3 -> HTTP3
        end
      )
end
