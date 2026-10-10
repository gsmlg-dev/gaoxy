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
    :service,
    :instance,
    response: :unset,
    response_trailers: [],
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
    if is_integer(read_timeout) and read_timeout > 0 do
      case read_body_step(exchange, credit, read_timeout) do
        {:pending, _exchange} ->
          {:error, :timeout}

        {:error, {:request_error, status, reason}, _exchange} ->
          raise Gaoxy.HTTP.RequestError, message: inspect(reason), plug_status: status

        {:error, reason, _exchange} ->
          {:error, reason}

        result ->
          result
      end
    else
      reason =
        if is_integer(credit) and credit > 0,
          do: :invalid_read_timeout,
          else: :invalid_read_length

      {:error, reason}
    end
  end

  @doc "Reads at most one credited body piece, retaining state when the finite wait expires."
  def read_body_step(exchange, credit, wait_ms) do
    cond do
      not is_integer(credit) or credit <= 0 ->
        {:error, :invalid_read_length, exchange}

      not is_integer(wait_ms) or wait_ms < 0 ->
        {:error, :invalid_read_timeout, exchange}

      Gaoxy.Lifecycle.remaining(exchange.deadline) <= 0 ->
        {:error, :timeout, exchange}

      true ->
        read_deadline = min(exchange.deadline, Gaoxy.Lifecycle.deadline(wait_ms))

        case maybe_continue(exchange) do
          {:ok, exchange} ->
            do_read_body(exchange, min(credit, exchange.limits.max_read_chunk), read_deadline)

          {:error, reason, exchange} ->
            {:error, reason, exchange}
        end
    end
  end

  @doc "Polls one socket byte for peer closure, retaining input for the next request or body read."
  def poll_connection(exchange, wait_ms) do
    cond do
      not is_integer(wait_ms) or wait_ms < 0 ->
        {:error, :invalid_read_timeout, exchange}

      Gaoxy.Lifecycle.remaining(exchange.deadline) <= 0 ->
        {:error, :timeout, exchange}

      byte_size(exchange.buffer) >= exchange.limits.max_buffer_bytes ->
        {:error, :buffer_limit, exchange}

      true ->
        case Admission.update(
               exchange.gate,
               exchange.lease,
               retained_bytes(exchange) + byte_size(exchange.buffer) + 1
             ) do
          :ok -> recv_connection(exchange, wait_ms)
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  defp recv_connection(exchange, wait_ms) do
    remaining = Gaoxy.Lifecycle.remaining(exchange.deadline)

    result =
      if remaining <= 0,
        do: {:error, :timeout},
        else: Socket.recv(exchange.socket, 1, min(wait_ms, remaining))

    case result do
      {:ok, byte} ->
        exchange = %{exchange | buffer: exchange.buffer <> byte}

        case Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange)) do
          :ok -> {:more, exchange}
          {:error, reason} -> {:error, reason, exchange}
        end

      {:error, reason} ->
        _ = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))
        if reason == :timeout, do: wait_expired(exchange), else: {:error, reason, exchange}
    end
  end

  defp maybe_continue(%{request: %{expect_continue: true}, expect_sent: false} = exchange) do
    # A failed write may have sent a prefix; never replay the informational head.
    exchange = %{exchange | expect_sent: true}

    case send_bytes(exchange, "HTTP/1.1 100 Continue\r\n\r\n") do
      :ok -> {:ok, exchange}
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  defp maybe_continue(exchange), do: {:ok, exchange}

  defp do_read_body(exchange, credit, read_deadline) do
    # Decoding can retain the input while producing a body piece and copied tail.
    case Admission.update(
           exchange.gate,
           exchange.lease,
           retained_bytes(exchange) + byte_size(exchange.buffer)
         ) do
      :ok -> decode_body(exchange, credit, read_deadline)
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  defp decode_body(exchange, credit, read_deadline) do
    # Install each framing transition before the next one can fail. Body.read/3
    # intentionally returns no decoder on malformed input.
    count = decode_size(exchange.body.phase, exchange.buffer, credit)
    <<input::binary-size(count), tail::binary>> = exchange.buffer

    case Body.read(exchange.body, input, credit) do
      {kind, bytes, body, rest} ->
        progressed = body != exchange.body or byte_size(rest) < count
        exchange = %{exchange | body: body, buffer: rest <> tail}

        case Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange)) do
          :ok ->
            cond do
              kind != :more or bytes != "" -> {kind, bytes, exchange}
              progressed -> do_read_body(exchange, credit, read_deadline)
              true -> await_body(exchange, credit, read_deadline)
            end

          {:error, reason} ->
            {:error, reason, exchange}
        end

      {:error, status, reason} ->
        _ = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))
        {:error, {:request_error, status, reason}, exchange}
    end
  end

  defp decode_size(phase, buffer, _credit) when phase in [:chunk_size, :trailers] do
    case :binary.match(buffer, "\r\n") do
      {size, 2} -> size + 2
      :nomatch -> byte_size(buffer)
    end
  end

  defp decode_size(:chunk_crlf, buffer, _credit), do: min(2, byte_size(buffer))

  defp decode_size({kind, remaining}, buffer, credit) when kind in [:length, :chunk_data],
    do: min(byte_size(buffer), min(remaining, credit))

  defp decode_size(_, buffer, _credit), do: byte_size(buffer)

  defp await_body(exchange, credit, read_deadline) do
    timeout = Gaoxy.Lifecycle.remaining(read_deadline)
    size = read_size(exchange.body.phase, credit, exchange.limits.max_read_chunk)

    cond do
      timeout <= 0 ->
        wait_expired(exchange)

      byte_size(exchange.buffer) + size > exchange.limits.max_buffer_bytes ->
        {:error, :buffer_limit, exchange}

      true ->
        case Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange) + size) do
          :ok -> recv_body(exchange, size, timeout, credit, read_deadline)
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  defp recv_body(exchange, size, timeout, credit, read_deadline) do
    case Socket.recv(exchange.socket, size, timeout) do
      {:ok, chunk} ->
        exchange = %{exchange | buffer: exchange.buffer <> chunk}

        case Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange)) do
          :ok ->
            if byte_size(exchange.buffer) <= exchange.limits.max_buffer_bytes,
              do: do_read_body(exchange, credit, read_deadline),
              else: {:error, :buffer_limit, exchange}

          {:error, reason} ->
            {:error, reason, exchange}
        end

      {:error, reason} ->
        _ = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))

        if reason == :timeout,
          do: wait_expired(exchange),
          else: {:error, reason, exchange}
    end
  end

  defp wait_expired(exchange) do
    if Gaoxy.Lifecycle.remaining(exchange.deadline) <= 0,
      do: {:error, :timeout, exchange},
      else: {:pending, exchange}
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
      result = if size == 0, do: :ok, else: send_window(exchange, chunk)
      :ok = Admission.finish_send(exchange.gate, exchange.lease, operation, result)
      :ok = Admission.update(exchange.gate, exchange.lease, retained_bytes(exchange))

      case result do
        :ok -> send_chunks(exchange, rest, limit)
        error -> error
      end
    end
  end

  defp send_window(%{deadline: deadline} = exchange, chunk) when is_integer(deadline) do
    case Gaoxy.Lifecycle.remaining(deadline) do
      0 ->
        {:error, :timeout}

      remaining ->
        timeout = min(Map.get(exchange.limits, :write_timeout, 5_000), remaining)

        with :ok <-
               Socket.setopts(exchange.socket, send_timeout: timeout, send_timeout_close: true),
             do: Socket.send(exchange.socket, chunk)
    end
  end

  defp send_window(exchange, chunk), do: Socket.send(exchange.socket, chunk)

  @doc false
  def retained_bytes(exchange) do
    headers = if exchange.request, do: 2 * exchange.request.head_bytes, else: 0
    trailers = if exchange.body, do: 2 * exchange.body.trailer_bytes, else: 0
    response_trailers = 2 * Enum.reduce(exchange.response_trailers, 0, &(byte_size(&1) + &2))
    byte_size(exchange.buffer) + headers + trailers + response_trailers
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
