defmodule Gaoxy.PlugAdapter do
  @behaviour Plug.Conn.Adapter
  alias Gaoxy.HTTP.{Exchange, Response}

  def send_resp(exchange, status, headers, body) do
    case Response.send_resp(exchange, status, headers, body) do
      {:ok, exchange} ->
        send(self(), Plug.Conn.Adapter.already_sent())
        {:ok, nil, exchange}

      {:error, reason} ->
        raise Plug.Conn.NotSentError, message: inspect(reason)
    end
  end

  def send_file(exchange, status, headers, file, offset, length) do
    case Response.send_file(exchange, status, headers, file, offset, length) do
      {:ok, exchange} ->
        send(self(), Plug.Conn.Adapter.already_sent())
        {:ok, nil, exchange}

      {:error, reason} ->
        raise Plug.Conn.NotSentError, message: inspect(reason)
    end
  end

  def send_chunked(exchange, status, headers) do
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
    credit = Keyword.get(options, :length, exchange.limits.max_read_chunk)
    timeout = Keyword.get(options, :read_timeout, exchange.limits.read_timeout)
    Exchange.read_body(exchange, credit, timeout)
  end

  def inform(exchange, status, headers), do: Response.inform(exchange, status, headers)

  def upgrade(%{request: %{version: :"HTTP/2"}}, _, _), do: {:error, :not_supported}

  def upgrade(exchange, :websocket, arguments) do
    case Gaoxy.HTTP.WebSocket.prepare(exchange, arguments) do
      {:ok, exchange} -> {:ok, exchange}
      {:error, reason} -> raise ArgumentError, "invalid WebSocket upgrade: #{inspect(reason)}"
    end
  end

  def upgrade(_, _, _), do: {:error, :not_supported}
  def push(_, _, _), do: {:error, :not_supported}

  def get_peer_data(exchange), do: Exchange.peer_data(exchange)
  def get_sock_data(exchange), do: Exchange.sock_data(exchange)
  def get_ssl_data(exchange), do: Exchange.ssl_data(exchange)

  def get_http_protocol(%{request: %{version: version}}), do: version
end
