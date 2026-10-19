defmodule Gaoxy.Proxy.WebSocket do
  @moduledoc """
  Native HTTP endpoint for message-level WebSocket reverse proxying to one
  configured `ws` or verified `wss` authority. The incoming raw path/query and
  offered subprotocols are preserved. Ping/pong are handled on each hop.

  Options are a map with `:upstream`, optional `:cacertfile`, and finite limits
  below. Compression, redirects and automatic replay are disabled. This endpoint
  handles WebSocket upgrades; use `Gaoxy.Proxy.HTTP` for HTTP body proxying.

  Each session reserves 4 MiB plus eight message windows and its request fields
  before opening upstream. The fixed allowance covers the pinned client's raw
  receive queue, opening headers and transient copies. Set service `max_bytes`
  accordingly; native retained bytes are charged separately. This payload ledger
  does not measure total BEAM memory or kernel/OTP socket buffers.
  """
  @behaviour Gaoxy.HTTP.Endpoint
  alias Gaoxy.HTTP.{WebSocket, WebSocket.Handshake, HTTP1.Response}
  alias Gaoxy.Proxy.WebSocket.{Handler, Session}

  @defaults %{
    max_message_bytes: 65_536,
    max_fragments: 128,
    opening_timeout: 5_000,
    idle_timeout: 60_000,
    write_timeout: 5_000,
    close_timeout: 1_000,
    max_lifetime: 86_400_000
  }
  @hop ~w(connection proxy-connection keep-alive proxy-authenticate proxy-authorization te trailer
    transfer-encoding upgrade host content-length sec-websocket-key sec-websocket-accept
    sec-websocket-version sec-websocket-protocol sec-websocket-extensions)

  defstruct [:uri, :cacertfile, :limits]

  @impl true
  def init(%__MODULE__{} = options), do: {:ok, options}

  def init(%{upstream: upstream} = options) when is_binary(upstream) do
    uri = URI.parse(upstream)
    limits = Map.merge(@defaults, Map.take(options, Map.keys(@defaults)))

    with true <- Map.keys(options) -- [:upstream, :cacertfile | Map.keys(@defaults)] == [],
         true <- uri.scheme in ["ws", "wss"] and is_binary(uri.host) and uri.host != "",
         true <- is_integer(uri.port) and uri.port in 1..65_535,
         true <-
           uri.userinfo == nil and uri.path in [nil, "", "/"] and uri.query == nil and
             uri.fragment == nil,
         true <- Enum.all?(limits, fn {_, v} -> is_integer(v) and v > 0 end),
         true <-
           is_nil(options[:cacertfile]) or
             (is_binary(options[:cacertfile]) and File.regular?(options[:cacertfile])) do
      {:ok,
       %__MODULE__{uri: %{uri | path: nil}, cacertfile: options[:cacertfile], limits: limits}}
    else
      _ -> {:error, :invalid_websocket_proxy_options}
    end
  rescue
    ArgumentError -> {:error, :invalid_websocket_proxy_options}
  end

  def init(_), do: {:error, :invalid_websocket_proxy_options}

  @impl true
  def call(exchange, config) do
    with {:ok, _} <- Handshake.headers(exchange.request, []),
         true <- is_pid(exchange.service) and is_pid(exchange.instance),
         {:ok, session} <- start_session(exchange, config) do
      open(exchange, session, config)
    else
      {:error, :invalid_websocket_handshake} -> error_response(exchange, 400)
      _ -> error_response(exchange, 503)
    end
  end

  defp start_session(exchange, config) do
    request = exchange.request

    query = if String.contains?(request.target, "?"), do: request.query_string, else: nil
    url = URI.to_string(%{config.uri | path: request.path, query: query})

    headers = upstream_headers(exchange)
    protocols = tokens(request.headers, "sec-websocket-protocol")

    reserve =
      4_194_304 + 8 * max(config.limits.max_message_bytes, 125) +
        2 * :erlang.external_size({headers, url, protocols})

    args = %{
      owner: self(),
      service: exchange.service,
      instance: exchange.instance,
      gate: exchange.gate,
      deadline: exchange.deadline,
      config: config,
      url: url,
      protocols: protocols,
      headers: headers
    }

    with {:ok, session} <-
           DynamicSupervisor.start_child(Gaoxy.Proxy.SessionSupervisor, {Session, args}) do
      case Gaoxy.Service.attach_cleanup(
             exchange.service,
             exchange.gate,
             exchange.lease,
             session,
             reserve,
             exchange.deadline
           ) do
        {:ok, token} ->
          {:ok, {session, token}}

        error ->
          Session.cancel(session)
          error
      end
    end
  end

  defp open(exchange, {session, token}, config) do
    case Session.await_open(session, exchange.deadline) do
      {:ok, protocol} ->
        initial = %{session: session, token: token, write_timeout: config.limits.write_timeout}
        limits = config.limits

        options = [
          max_message_size: limits.max_message_bytes,
          max_frame_size: limits.max_message_bytes,
          max_fragments: limits.max_fragments,
          timeout: limits.idle_timeout,
          callback_timeout: limits.write_timeout + 1_000,
          close_timeout: limits.close_timeout,
          max_lifetime: limits.max_lifetime
        ]

        case WebSocket.prepare(exchange, {Handler, initial, options}) do
          {:ok, exchange} ->
            headers = if protocol == "", do: [], else: [{"sec-websocket-protocol", protocol}]
            {:ok, WebSocket.response_headers(exchange, headers)}

          {:error, reason} ->
            Session.cancel(session)
            {:error, reason, exchange}
        end

      {:error, reason} ->
        Session.cancel(session)
        error_response(exchange, if(reason == :timeout, do: 504, else: 502))
    end
  end

  defp error_response(exchange, code) do
    case Response.send_resp(%{exchange | close: true}, code, [], "") do
      {:ok, exchange} -> {:ok, exchange}
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  defp upstream_headers(exchange) do
    request = exchange.request
    nominated = tokens(request.headers, "connection") |> Enum.map(&String.downcase/1)

    headers =
      Enum.reject(request.headers, fn {name, _} ->
        name in @hop or name in nominated or name in ["forwarded", "x-real-ip"] or
          String.starts_with?(name, "x-forwarded-")
      end)

    {address, _port} = exchange.peer
    host = Enum.find_value(request.headers, request.host, fn {k, v} -> if k == "host", do: v end)
    scheme = if Hell.Socket.secure?(exchange.socket), do: "https", else: "http"

    headers ++
      [
        {"x-forwarded-for", address |> :inet.ntoa() |> to_string()},
        {"x-forwarded-host", host},
        {"x-forwarded-proto", scheme}
      ]
  end

  defp tokens(headers, name),
    do: for({^name, value} <- headers, token <- String.split(value, ","), do: String.trim(token))
end
