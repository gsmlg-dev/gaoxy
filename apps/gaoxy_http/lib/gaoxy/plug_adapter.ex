defmodule Gaoxy.PlugAdapter do
  @behaviour Plug.Conn.Adapter
  alias Gaoxy.HTTP.{Exchange, Response}

  @connection_response_fields ~w(connection keep-alive proxy-connection transfer-encoding upgrade te)

  def send_resp(exchange, status, headers, body) do
    headers = response_headers(exchange, headers)

    case Response.send_resp(exchange, status, headers, body) do
      {:ok, exchange} ->
        send(self(), Plug.Conn.Adapter.already_sent())
        {:ok, nil, exchange}

      {:error, reason} ->
        raise Plug.Conn.NotSentError, message: inspect(reason)
    end
  end

  def send_file(exchange, status, headers, file, offset, length) do
    headers = response_headers(exchange, headers)

    case Response.send_file(exchange, status, headers, file, offset, length) do
      {:ok, exchange} ->
        send(self(), Plug.Conn.Adapter.already_sent())
        {:ok, nil, exchange}

      {:error, reason} ->
        raise Plug.Conn.NotSentError, message: inspect(reason)
    end
  end

  def send_chunked(exchange, status, headers) do
    headers = response_headers(exchange, headers)

    case Response.send_chunked(exchange, status, headers) do
      {:ok, exchange} ->
        send(self(), Plug.Conn.Adapter.already_sent())
        {:ok, nil, exchange}

      {:error, reason} ->
        raise Plug.Conn.NotSentError, message: inspect(reason)
    end
  end

  def chunk(exchange, data) do
    case Response.chunk(exchange, data) do
      :ok -> :ok
      {:ok, next} -> {:ok, nil, next}
      {:error, reason} -> {:error, reason}
    end
  end

  def read_req_body(exchange, options) do
    length = Keyword.get(options, :length, 8_000_000)
    read_length = Keyword.get(options, :read_length, 1_000_000)
    timeout = Keyword.get(options, :read_timeout, 15_000)

    cond do
      not is_integer(length) or length <= 0 or not is_integer(read_length) or read_length <= 0 ->
        {:error, :invalid_read_length}

      not is_integer(timeout) or timeout <= 0 ->
        {:error, :invalid_read_timeout}

      true ->
        read_body(
          exchange,
          length,
          read_length,
          min(timeout, exchange.limits.read_timeout),
          [],
          0
        )
    end
  end

  defp read_body(exchange, 0, _read_length, _timeout, chunks, size),
    do: finish_body(:more, exchange, chunks, size)

  defp read_body(exchange, remaining, read_length, timeout, chunks, size) do
    demand = min(remaining, min(read_length, exchange.limits.max_read_chunk))

    # A native result may still reference its input buffer. Reserve that backing,
    # the emitted window and a detached copy before retaining the next piece.
    bytes = size + byte_size(exchange.buffer) + 2 * demand

    cond do
      Gaoxy.Lifecycle.remaining(exchange.deadline) == 0 ->
        body_error(exchange, :timeout)

      true ->
        case reserve_body(exchange, bytes) do
          {:ok, reserved} ->
            case Exchange.read_body_step(reserved, demand, timeout, :per_socket_read) do
              {:more, "", next} ->
                body_error(next, :no_body_progress)

              {kind, piece, next} when kind in [:ok, :more] ->
                piece = :binary.copy(piece)
                chunks = [piece | chunks]
                size = size + byte_size(piece)

                if kind == :ok,
                  do: finish_body(:ok, next, chunks, size),
                  else:
                    read_body(
                      next,
                      remaining - byte_size(piece),
                      read_length,
                      timeout,
                      chunks,
                      size
                    )

              {:pending, next} ->
                body_error(next, :timeout)

              {:error, reason, next} ->
                body_error(next, reason)
            end

          {:error, reason} ->
            body_error(exchange, reason)
        end
    end
  end

  defp finish_body(kind, exchange, chunks, size) do
    # Both detached chunks and the flattened binary coexist until ownership is
    # transferred to Plug/application code. Native request retention stays charged.
    case reserve_body(exchange, 2 * size) do
      {:ok, exchange} ->
        body = chunks |> Enum.reverse() |> IO.iodata_to_binary()

        case release_body(exchange) do
          {:ok, exchange} -> {kind, body, exchange}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        body_error(exchange, reason)
    end
  end

  defp reserve_body(exchange, bytes) do
    next = %{exchange | adapter_body_bytes: bytes}

    case update_body(next) do
      :ok -> {:ok, next}
      error -> error
    end
  end

  defp release_body(exchange) do
    next = %{exchange | adapter_body_bytes: 0}

    case update_body(next) do
      :ok ->
        {:ok, next}

      {:error, reason} ->
        # A timed-out update can still be queued at the gate. Order its cleanup
        # after that update without extending the request's absolute deadline.
        defer_body_release(next)
        {:error, reason}
    end
  end

  defp update_body(exchange),
    do: Exchange.update_body_retention(exchange, Exchange.retained_bytes(exchange))

  defp defer_body_release(exchange),
    do: Exchange.defer_body_retention(exchange, Exchange.retained_bytes(exchange))

  defp body_error(exchange, reason) do
    _ = release_body(exchange)

    case reason do
      {:request_error, status, reason} ->
        raise Gaoxy.HTTP.RequestError, message: inspect(reason), plug_status: status

      reason ->
        {:error, reason}
    end
  end

  def inform(exchange, status, headers),
    do: Response.inform(exchange, status, response_headers(exchange, headers))

  # Plug middleware may use H1 connection fields without knowing the negotiated
  # protocol. Remove those fields only here; native framed responses remain strict.
  defp response_headers(%{request: %{version: version}, limits: limits}, headers)
       when version in [:"HTTP/2", :"HTTP/3"] do
    # Bound the original collection before splitting Connection nominations.
    # Invalid collections pass unchanged to the existing response validator.
    if Gaoxy.HTTP.RendererBounds.fields(headers, limits.max_headers, limits.max_header_bytes) ==
         :ok do
      nominated =
        for {name, value} <- headers,
            String.downcase(name, :ascii) == "connection",
            token <- String.split(value, ","),
            do: token |> String.trim() |> String.downcase(:ascii)

      removed = MapSet.new(@connection_response_fields ++ nominated)

      Enum.reject(headers, fn {name, _} ->
        MapSet.member?(removed, String.downcase(name, :ascii))
      end)
    else
      headers
    end
  end

  defp response_headers(_, headers), do: headers

  def upgrade(%{request: %{version: version}} = exchange, :websocket, arguments)
      when version in [:"HTTP/2", :"HTTP/3"] do
    if websocket_request?(exchange) do
      prepare_websocket(exchange, arguments)
    else
      {:error, :not_supported}
    end
  end

  def upgrade(exchange, :websocket, arguments) do
    prepare_websocket(exchange, arguments)
  end

  def upgrade(_, _, _), do: {:error, :not_supported}

  @doc false
  def websocket_request?(%{
        request:
          %{method: "CONNECT", protocol: "websocket", body: :tunnel, version: version} = request,
        limits: %{extended_connect: true},
        transport: transport,
        transport_state: state
      })
      when version in [:"HTTP/2", :"HTTP/3"] and not is_nil(transport) and not is_nil(state),
      do: Gaoxy.HTTP.WebSocket.ExtendedHandshake.headers(request, []) == {:ok, []}

  def websocket_request?(_), do: false

  defp prepare_websocket(exchange, arguments) do
    case Gaoxy.HTTP.WebSocket.prepare(exchange, arguments) do
      {:ok, exchange} -> {:ok, exchange}
      {:error, reason} -> raise ArgumentError, "invalid WebSocket upgrade: #{inspect(reason)}"
    end
  end

  def push(_, _, _), do: {:error, :not_supported}

  def get_peer_data(exchange), do: Exchange.peer_data(exchange)
  def get_sock_data(exchange), do: Exchange.sock_data(exchange)
  def get_ssl_data(exchange), do: Exchange.ssl_data(exchange)

  def get_http_protocol(%{request: %{version: version}}), do: version
end
