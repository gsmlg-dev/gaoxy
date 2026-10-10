defmodule Gaoxy.HTTP do
  @moduledoc "Native HTTP/1 service backed by a Gaoxy TCP or TLS listener."

  @keys [:id, :ip, :port, :transport, :tls, :limits, :http_limits, :plug, :endpoint]

  def start_link(options) do
    with {:ok, spec} <- service_spec(options), do: Gaoxy.start_link(services: [spec])
  end

  def child_spec(options) do
    %{
      id: {__MODULE__, Keyword.get(options, :id, :http)},
      start: {__MODULE__, :start_link, [options]},
      restart: :transient
    }
  end

  def service_spec(options) when is_list(options) do
    if Keyword.keyword?(options) and Enum.all?(Keyword.keys(options), &(&1 in @keys)) do
      {endpoint, plug} = {Keyword.get(options, :endpoint), Keyword.get(options, :plug)}

      case {endpoint, plug} do
        {nil, {module, opts}} when is_atom(module) ->
          spec(options, {Gaoxy.HTTP.PlugEndpoint, {module, opts}})

        {{module, opts}, nil} when is_atom(module) ->
          spec(options, {module, opts})

        _ ->
          {:error, :invalid_endpoint}
      end
    else
      {:error, :invalid_http_options}
    end
  end

  def service_spec(_), do: {:error, :invalid_http_options}

  defp spec(options, endpoint) do
    transport = Keyword.get(options, :transport, :tcp)
    tls = Keyword.get(options, :tls, %{})

    tls =
      if transport == :tls and is_map(tls), do: Map.put_new(tls, :alpn, ["http/1.1"]), else: tls

    service = %{
      id: Keyword.get(options, :id, :http),
      ip: Keyword.get(options, :ip, {127, 0, 0, 1}),
      port: Keyword.get(options, :port, 0),
      transport: transport,
      tls: tls,
      limits: Keyword.get(options, :limits, %{}),
      handler_mode: :native,
      handler: Gaoxy.HTTP.Connection,
      handler_options: %{endpoint: endpoint, http_limits: Keyword.get(options, :http_limits, %{})}
    }

    if transport == :tls and is_map(tls) and tls.alpn not in [[], ["http/1.1"]],
      do: {:error, :unsupported_http_alpn},
      else: Gaoxy.Config.service(service)
  end
end
