defmodule Gaoxy.Proxy.ForwardHTTP do
  @moduledoc """
  Explicit authenticated HTTP forward proxy and HTTP/1.1 CONNECT endpoint.

  A nonempty destination policy is required at initialization. Every new
  request authenticates, authorizes and validates all DNS answers before dialing
  one approved numeric address. HTTP requests preserve the target authority;
  HTTPS uses CONNECT. Proxy credentials never enter upstream HTTP requests.
  CONNECT retains the original request deadline and transfers buffered bytes
  once through the bounded native relay. HTTP/2 CONNECT is not supported.
  """
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.{Lifecycle, Proxy.DestinationPolicy, Proxy.StreamRelay}
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.Proxy.HTTP, as: HTTPProxy
  alias Gaoxy.Proxy.StreamRelay.Upstream

  @defaults %{
    opening_timeout: 5_000,
    idle_timeout: 30_000,
    write_timeout: 5_000,
    max_lifetime: 30_000,
    max_chunk_bytes: 16_384
  }
  defstruct [:policy, :limits]

  @impl true
  def init(%{policy: policy} = options) do
    limits = Map.merge(@defaults, Map.take(options, Map.keys(@defaults)))

    with true <- Map.keys(options) -- [:policy | Map.keys(@defaults)] == [],
         {:ok, policy} <- DestinationPolicy.init(policy),
         {:ok, _} <- HTTPProxy.init(Map.put(limits, :upstream, "http://forward.invalid")),
         true <- limits.max_chunk_bytes <= 16_384 do
      {:ok, %__MODULE__{policy: policy, limits: limits}}
    else
      _ -> {:error, :invalid_forward_proxy_options}
    end
  end

  def init(_), do: {:error, :invalid_forward_proxy_options}

  @impl true
  def absolute_form_scheme?(scheme), do: scheme == :http

  @impl true
  def call(exchange, config) do
    deadline = min(exchange.deadline, Lifecycle.deadline(config.limits.max_lifetime))

    with {:ok, principal} <-
           DestinationPolicy.authenticate(config.policy, exchange.request.headers),
         {:ok, target} <- target(exchange),
         {:ok, authorization} <- DestinationPolicy.authorize(config.policy, principal, target),
         {:ok, address} <-
           DestinationPolicy.resolve(
             authorization,
             min(deadline, Lifecycle.deadline(config.limits.opening_timeout))
           ) do
      dispatch(%{exchange | deadline: deadline}, config, target, address)
    else
      {:error, :authentication_required} ->
        reject(exchange, 407, [{"proxy-authenticate", "Bearer"}])

      {:error, :destination_denied} ->
        reject(exchange, 403)

      {:error, :invalid_forward_target} ->
        reject(exchange, 400)

      _ ->
        reject(exchange, 502)
    end
  end

  defp target(%{request: %{method: "CONNECT"} = request, transport: nil}) do
    if request.target_form == :authority and request.version == :"HTTP/1.1" and
         request.body == :none and
         not Enum.any?(request.headers, fn {name, _} ->
           name in ["content-length", "transfer-encoding", "expect", "trailer"]
         end) do
      {:ok,
       %{host: request.host, port: request.port, operation: :connect, method: request.method}}
    else
      {:error, :invalid_forward_target}
    end
  end

  defp target(%{request: %{target_form: :absolute, scheme: :http} = request}) do
    uri = URI.parse(request.target)

    if uri.scheme == "http" and uri.userinfo == nil and uri.fragment == nil,
      do:
        {:ok,
         %{host: request.host, port: request.port, operation: :forward, method: request.method}},
      else: {:error, :invalid_forward_target}
  end

  defp target(_), do: {:error, :invalid_forward_target}

  defp dispatch(exchange, config, %{operation: :forward} = target, address) do
    upstream = URI.to_string(%URI{scheme: "http", host: target.host, port: target.port})
    options = Map.merge(config.limits, %{upstream: upstream, connect_address: address})

    with {:ok, proxy} <- HTTPProxy.init(options), do: HTTPProxy.call(exchange, proxy)
  end

  defp dispatch(exchange, config, %{operation: :connect} = target, address) do
    options = %{
      upstream: {address, target.port},
      mode: if(Exchange.secure?(exchange), do: :tls_termination, else: :tcp),
      max_chunk_bytes: config.limits.max_chunk_bytes,
      connect_timeout: config.limits.opening_timeout,
      idle_timeout: config.limits.idle_timeout,
      write_timeout: config.limits.write_timeout,
      max_lifetime: config.limits.max_lifetime
    }

    case StreamRelay.connect(options, exchange.deadline) do
      {:ok, upstream} ->
        try do
          tunnel(exchange, upstream, options)
        after
          Upstream.close(upstream)
        end

      {:error, _} ->
        reject(exchange, 502)
    end
  end

  defp tunnel(exchange, upstream, options) do
    case Exchange.send_bytes(exchange, "HTTP/1.1 200 Connection Established\r\n\r\n") do
      :ok ->
        final = %{exchange | response: :tunnel, close: true, buffer: ""}

        context = %{
          gate: exchange.gate,
          scope: %{service: exchange.service, instance: exchange.instance}
        }

        case StreamRelay.bridge(
               exchange.socket,
               upstream,
               context,
               options,
               exchange.lease,
               exchange.deadline,
               exchange.buffer
             ) do
          {:close, _} -> {:ok, final}
          {:error, reason, _} -> {:error, reason, final}
        end

      {:error, reason} ->
        Upstream.abort(upstream)
        {:error, reason, %{exchange | response: :tunnel, close: true}}
    end
  end

  defp reject(exchange, status, headers \\ []) do
    Response.send_resp(%{exchange | close: true}, status, headers, "")
  end
end
