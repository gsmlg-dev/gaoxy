defmodule Gaoxy.HTTP do
  @moduledoc "Native HTTP service with H2-first HTTPS and explicit prior-knowledge h2c."

  @keys [
    :id,
    :ip,
    :port,
    :transport,
    :tls,
    :limits,
    :http_limits,
    :plug,
    :endpoint,
    :protocols,
    :extended_connect,
    :h2c,
    :h2_limits
  ]

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

    service = %{
      id: Keyword.get(options, :id, :http),
      ip: Keyword.get(options, :ip, {127, 0, 0, 1}),
      port: Keyword.get(options, :port, 0),
      transport: transport,
      tls: tls,
      limits: Keyword.get(options, :limits, %{}),
      handler_mode: :native,
      handler: Gaoxy.HTTP.Connection,
      handler_options: %{
        endpoint: endpoint,
        http_limits: Keyword.get(options, :http_limits, %{}),
        protocols:
          Keyword.get(
            options,
            :protocols,
            if(transport == :tls, do: [:http2, :http1], else: [:http1])
          ),
        h2c: Keyword.get(options, :h2c, :disabled),
        extended_connect: Keyword.get(options, :extended_connect, false),
        h2_limits: Keyword.get(options, :h2_limits, %{})
      }
    }

    with {:ok, normalized} <- Gaoxy.HTTP.Options.normalize(service.handler_options),
         limits =
           if(:http2 in normalized.protocols and is_map(service.limits),
             do: Map.put_new(service.limits, :max_bytes, 268_435_456),
             else: service.limits
           ),
         tls = alpn(transport, tls, normalized.protocols),
         :ok <- protocol_transport(transport, tls, normalized),
         {:ok, spec} <-
           Gaoxy.Config.service(%{
             service
             | handler_options: normalized,
               tls: tls,
               limits: limits
           }),
         :ok <- budget(spec) do
      {:ok, spec}
    end
  end

  defp alpn(:tls, tls, protocols) when is_map(tls) do
    Map.put_new(
      tls,
      :alpn,
      Enum.map(protocols, fn
        :http1 -> "http/1.1"
        :http2 -> "h2"
      end)
    )
  end

  defp alpn(_, tls, _), do: tls

  defp protocol_transport(:tcp, _, %{protocols: [:http1], h2c: :disabled}), do: :ok
  defp protocol_transport(:tcp, _, %{protocols: [:http2], h2c: :prior_knowledge}), do: :ok

  defp protocol_transport(:tls, tls, %{h2c: :disabled, protocols: protocols}) when is_map(tls) do
    allowed =
      Enum.map(protocols, fn
        :http1 -> "http/1.1"
        :http2 -> "h2"
      end)

    if Map.get(tls, :alpn, []) == allowed or (protocols == [:http1] and tls.alpn == []),
      do: :ok,
      else: {:error, :unsupported_http_alpn}
  end

  defp protocol_transport(:tls, tls, _) when not is_map(tls), do: {:error, :invalid_options}
  defp protocol_transport(_, _, _), do: {:error, :invalid_http_protocols}

  defp budget(%{handler_options: %{protocols: protocols} = options} = spec) do
    if :http2 in protocols do
      with :ok <- Gaoxy.HTTP.HTTP2.Limits.validate_host(spec.transport) do
        Gaoxy.HTTP.HTTP2.Limits.validate_budget(
          options.http_limits,
          options.h2_limits,
          spec.limits
        )
      end
    else
      :ok
    end
  end
end
