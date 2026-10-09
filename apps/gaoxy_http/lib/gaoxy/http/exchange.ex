defmodule Gaoxy.HTTP.Exchange do
  @moduledoc "One request's socket, admission lease, framing and response state."
  alias Gaoxy.HTTP.HTTP1.Body
  alias ThousandIsland.Socket
  alias Gaoxy.Admission

  defstruct [
    :request,
    :socket,
    :gate,
    :lease,
    :deadline,
    :limits,
    :body,
    :buffer,
    :peer,
    :local,
    response: :unset,
    close: false,
    expect_sent: false
  ]

  @type t :: %__MODULE__{}

  def new(request, socket, gate, lease, deadline, limits, buffer) do
    {:ok, peer} = Socket.peername(socket)
    {:ok, local} = Socket.sockname(socket)

    %__MODULE__{
      request: request,
      socket: socket,
      gate: gate,
      lease: lease,
      deadline: deadline,
      limits: limits,
      body: Body.new(request.body, limits),
      buffer: buffer,
      peer: peer,
      local: local,
      close: not request.keep_alive
    }
  end

  def plug_conn(exchange) do
    request = exchange.request
    scheme = if Socket.secure?(exchange.socket), do: "https", else: "http"

    uri = %URI{
      scheme: scheme,
      host: request.host || "localhost",
      port: request.port || if(scheme == "https", do: 443, else: 80),
      path: request.path,
      query: request.query_string
    }

    Plug.Conn.Adapter.conn(
      {Gaoxy.PlugAdapter, exchange},
      request.method,
      uri,
      elem(exchange.peer, 0),
      request.headers
    )
    |> Map.put(:private, %{gaoxy_http_version: request.version})
  end

  def read_body(exchange, credit, read_timeout) do
    with true <- (is_integer(credit) and credit > 0) || {:error, :invalid_read_length},
         true <-
           (is_integer(read_timeout) and read_timeout > 0) || {:error, :invalid_read_timeout},
         :ok <- maybe_continue(exchange) do
      read_deadline = min(exchange.deadline, Gaoxy.Lifecycle.deadline(read_timeout))
      do_read_body(exchange, min(credit, exchange.limits.max_read_chunk), read_deadline)
    end
  end

  defp maybe_continue(%{request: %{expect_continue: true}, expect_sent: false} = exchange) do
    send_bytes(exchange, "HTTP/1.1 100 Continue\r\n\r\n")
  end

  defp maybe_continue(_), do: :ok

  defp do_read_body(exchange, credit, read_deadline) do
    # Decoding can retain the input while producing a body piece and copied tail.
    :ok =
      Admission.update(
        exchange.gate,
        exchange.lease,
        retained_bytes(exchange) + byte_size(exchange.buffer)
      )

    case Body.read(exchange.body, exchange.buffer, credit) do
      {kind, bytes, body, rest} ->
        exchange = %{exchange | body: body, buffer: rest, expect_sent: true}
        :ok = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))

        if kind == :more and bytes == "" do
          timeout = Gaoxy.Lifecycle.remaining(read_deadline)
          size = read_size(body.phase, credit, exchange.limits.max_read_chunk)

          cond do
            timeout <= 0 ->
              {:error, :timeout}

            byte_size(rest) + size > exchange.limits.max_buffer_bytes ->
              {:error, :buffer_limit}

            true ->
              case Admission.update(
                     exchange.gate,
                     exchange.lease,
                     retained_bytes(exchange) + size
                   ) do
                :ok -> recv_body(exchange, rest, size, timeout, credit, read_deadline)
                error -> error
              end
          end
        else
          {kind, bytes, exchange}
        end

      {:error, status, reason} ->
        raise Gaoxy.HTTP.RequestError, message: inspect(reason), plug_status: status
    end
  end

  defp recv_body(exchange, rest, size, timeout, credit, read_deadline) do
    case Socket.recv(exchange.socket, size, timeout) do
      {:ok, chunk}
      when byte_size(rest) + byte_size(chunk) <= exchange.limits.max_buffer_bytes ->
        buffer = rest <> chunk

        :ok =
          Admission.update(
            exchange.gate,
            exchange.lease,
            retained_bytes(exchange) + byte_size(chunk)
          )

        do_read_body(%{exchange | buffer: buffer}, credit, read_deadline)

      {:ok, _} ->
        {:error, :buffer_limit}

      {:error, reason} ->
        :ok = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))
        {:error, reason}
    end
  end

  defp read_size({kind, remaining}, credit, limit) when kind in [:length, :chunk_data],
    do: max(1, min(remaining, min(credit, limit)))

  defp read_size(_, _, _), do: 1

  def send_bytes(exchange, bytes) do
    send_chunks(exchange, [bytes], Map.get(exchange.limits || %{}, :max_write_chunk, 16_384))
  end

  defp send_chunks(_, [], _), do: :ok

  defp send_chunks(exchange, pending, limit) do
    {chunk, size, rest} = take_chunk(pending, limit, [], 0)

    with :ok <-
           Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange) + size),
         {:ok, operation} <- Admission.start_send(exchange.gate, exchange.lease, size) do
      result = if size == 0, do: :ok, else: Socket.send(exchange.socket, chunk)
      :ok = Admission.finish_send(exchange.gate, exchange.lease, operation, result)
      :ok = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))

      case result do
        :ok -> send_chunks(exchange, rest, limit)
        error -> error
      end
    end
  end

  @doc false
  def retained_bytes(exchange) do
    headers = if exchange.request, do: 2 * exchange.request.head_bytes, else: 0
    trailers = if exchange.body, do: 2 * exchange.body.trailer_bytes, else: 0
    byte_size(exchange.buffer) + headers + trailers
  end

  # Traverse application-owned iodata lazily. Never flatten an entire response
  # merely to split it again; only one admitted output window reaches the socket.
  defp take_chunk(rest, limit, acc, limit), do: {Enum.reverse(acc), limit, rest}
  defp take_chunk([], _, acc, size), do: {Enum.reverse(acc), size, []}
  defp take_chunk([[] | rest], limit, acc, size), do: take_chunk(rest, limit, acc, size)

  defp take_chunk([[head | tail] | rest], limit, acc, size),
    do: take_chunk([head, tail | rest], limit, acc, size)

  defp take_chunk([byte | rest], limit, acc, size) when is_integer(byte) and byte in 0..255,
    do: take_chunk(rest, limit, [byte | acc], size + 1)

  defp take_chunk([bytes | rest], limit, acc, size) when is_binary(bytes) do
    count = min(byte_size(bytes), limit - size)
    <<chunk::binary-size(count), tail::binary>> = bytes
    next = if tail == "", do: rest, else: [tail | rest]
    take_chunk(next, limit, [chunk | acc], size + count)
  end
end
