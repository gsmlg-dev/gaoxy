defmodule Gaoxy.HTTP.Exchange do
  @moduledoc "One request's socket, admission lease, framing and response state."
  alias Gaoxy.HTTP.HTTP1.Body
  alias Hell.Socket
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
    discovery: nil,
    stream_timeout: nil,
    response: :unset,
    response_trailers: [],
    close: false,
    route_bytes: 0,
    resource_pins: [],
    protocol_bytes: 0,
    adapter_body_bytes: 0,
    poll_buffer_bytes: 0,
    transport: nil,
    transport_state: nil,
    secure: nil,
    ssl: nil,
    peer_cert: nil,
    expect_sent: false
  ]

  @type t :: %__MODULE__{}

  @doc "Selects a streaming response lifetime before response start; request reads remain finite."
  def put_stream_timeout(%{response: :unset} = exchange, timeout)
      when timeout in [:request, :infinity] or (is_integer(timeout) and timeout > 0),
      do: %{exchange | stream_timeout: timeout}

  def put_stream_timeout(_, _),
    do:
      raise(
        ArgumentError,
        "stream timeout requires an unsent response and :request, :infinity or positive milliseconds"
      )

  @doc false
  def begin_stream(exchange) do
    timeout = exchange.stream_timeout || Map.get(exchange.limits, :stream_timeout, :request)

    cond do
      timeout == :request ->
        {:ok, exchange}

      exchange.response != :unset ->
        {:error, :invalid_response_state}

      exchange.transport not in [nil, Gaoxy.HTTP.HTTP2.Transport] ->
        {:error, :unsupported_stream_timeout}

      not body_complete?(exchange) ->
        {:error, :unconsumed_request_body}

      Gaoxy.Lifecycle.remaining(exchange.deadline) == 0 ->
        {:error, :timeout}

      true ->
        deadline = if timeout == :infinity, do: :infinity, else: Gaoxy.Lifecycle.deadline(timeout)

        with :ok <-
               Admission.begin_stream(
                 exchange.gate,
                 exchange.lease,
                 retained_bytes(exchange),
                 deadline,
                 min(Gaoxy.Lifecycle.remaining(exchange.deadline), 5_000)
               ),
             :ok <- begin_transport_stream(exchange, deadline),
             do: {:ok, %{exchange | deadline: deadline}}
    end
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, _ -> {:error, :closed}
  end

  defp begin_transport_stream(%{transport: nil}, _deadline), do: :ok

  defp begin_transport_stream(exchange, deadline),
    do: Gaoxy.HTTP.HTTP2.Transport.operation(exchange, {:begin_stream, deadline})

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
    Code.ensure_loaded!(Gaoxy.PlugAdapter)

    request = exchange.request
    scheme = if secure?(exchange), do: "https", else: "http"

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
  def read_body_step(%{request: %{body: :tunnel}} = exchange, _, _),
    do: {:error, :unsupported_tunnel_body, exchange}

  def read_body_step(%{body: :tunnel} = exchange, _, _),
    do: {:error, :unsupported_tunnel_body, exchange}

  def read_body_step(%{transport: module} = exchange, credit, wait_ms) when not is_nil(module),
    do: module.read_body_step(exchange, credit, wait_ms)

  def read_body_step(exchange, credit, wait_ms),
    do: read_body_step(exchange, credit, wait_ms, :bounded_step)

  @doc false
  def read_body_step(%{request: %{body: :tunnel}} = exchange, credit, wait_ms, _),
    do: read_body_step(exchange, credit, wait_ms)

  def read_body_step(%{body: :tunnel} = exchange, credit, wait_ms, _),
    do: read_body_step(exchange, credit, wait_ms)

  def read_body_step(%{transport: module} = exchange, credit, wait_ms, :per_socket_read)
      when not is_nil(module),
      do: read_body_step(exchange, credit, wait_ms)

  def read_body_step(exchange, credit, wait_ms, timing) do
    cond do
      not is_integer(credit) or credit <= 0 ->
        {:error, :invalid_read_length, exchange}

      not is_integer(wait_ms) or wait_ms < 0 ->
        {:error, :invalid_read_timeout, exchange}

      Gaoxy.Lifecycle.remaining(exchange.deadline) <= 0 ->
        {:error, :timeout, exchange}

      true ->
        read_deadline =
          if timing == :per_socket_read,
            do: {exchange.deadline, wait_ms},
            else: min(exchange.deadline, Gaoxy.Lifecycle.deadline(wait_ms))

        case maybe_continue(exchange) do
          {:ok, exchange} ->
            do_read_body(exchange, min(credit, exchange.limits.max_read_chunk), read_deadline)

          {:error, reason, exchange} ->
            {:error, reason, exchange}
        end
    end
  end

  @doc "Polls one socket byte for peer closure, retaining input for the next request or body read."
  def poll_connection(%{transport: module} = exchange, wait_ms) when not is_nil(module),
    do: module.poll_connection(exchange, wait_ms)

  def poll_connection(exchange, wait_ms) do
    cond do
      not is_integer(wait_ms) or wait_ms < 0 ->
        {:error, :invalid_read_timeout, exchange}

      Gaoxy.Lifecycle.remaining(exchange.deadline) <= 0 ->
        {:error, :timeout, exchange}

      byte_size(exchange.buffer) > exchange.limits.max_buffer_bytes ->
        {:error, :buffer_limit, exchange}

      true ->
        # The old buffer, received byte and concatenation can coexist. Keep the
        # complete peak charged across idle polls until the request is released.
        next = %{
          exchange
          | poll_buffer_bytes: max(exchange.poll_buffer_bytes, 2 * byte_size(exchange.buffer) + 2)
        }

        case Admission.update(next.gate, next.lease, retained_bytes(next)) do
          :ok -> recv_connection(next, wait_ms)
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
      {:ok, _byte} when byte_size(exchange.buffer) == exchange.limits.max_buffer_bytes ->
        # A full buffer is valid. Only an observed excess byte rejects it; do not
        # concatenate that byte or retain more than the configured input limit.
        {:error, :buffer_limit, exchange}

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

    case send_continue(exchange) do
      :ok -> {:ok, exchange}
      {:error, reason} -> {:error, reason, exchange}
    end
  end

  defp maybe_continue(exchange), do: {:ok, exchange}

  defp send_continue(exchange), do: send_continue(exchange, "HTTP/1.1 100 Continue\r\n\r\n")
  defp send_continue(_, ""), do: :ok

  defp send_continue(exchange, pending) do
    size = min(byte_size(pending), Map.get(exchange.limits, :max_write_chunk, 16_384))
    <<bytes::binary-size(^size), rest::binary>> = pending
    operation = make_ref()
    deadline = min(exchange.deadline, Gaoxy.Lifecycle.deadline(exchange.limits.write_timeout))

    result =
      with :ok <- update_body_retention(exchange, retained_bytes(exchange) + byte_size(bytes)),
           :ok <-
             Admission.start_send_until(
               exchange.gate,
               exchange.lease,
               byte_size(bytes),
               operation,
               deadline
             ) do
        {result, outcome} = send_continue_window(exchange, bytes)
        _ = Admission.finish_send_async(exchange.gate, exchange.lease, operation, outcome)
        result
      end

    result =
      case update_body_retention(exchange, retained_bytes(exchange)) do
        :ok ->
          result

        error ->
          defer_body_retention(exchange, retained_bytes(exchange))
          if result == :ok, do: error, else: result
      end

    case result do
      :ok -> send_continue(exchange, rest)
      error -> error
    end
  end

  defp send_continue_window(exchange, bytes) do
    case Gaoxy.Lifecycle.remaining(exchange.deadline) do
      0 ->
        {{:error, :timeout}, {:error, :not_submitted}}

      remaining ->
        timeout = min(exchange.limits.write_timeout, remaining)

        case Socket.setopts(exchange.socket, send_timeout: timeout, send_timeout_close: true) do
          :ok ->
            result = Socket.send(exchange.socket, bytes)
            {result, result}

          error ->
            {error, {:error, :not_submitted}}
        end
    end
  end

  defp do_read_body(exchange, credit, read_deadline) do
    # Decoding can retain the input while producing a body piece and copied tail.
    case update_body_retention(
           exchange,
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
    <<input::binary-size(^count), tail::binary>> = exchange.buffer

    case Body.read(exchange.body, input, credit) do
      {kind, bytes, body, rest} ->
        progressed = body != exchange.body or byte_size(rest) < count
        exchange = %{exchange | body: body, buffer: rest <> tail}

        case update_body_retention(exchange, retained_bytes(exchange)) do
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
        _ = update_body_retention(exchange, retained_bytes(exchange))
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
    timeout = read_remaining(read_deadline)
    size = read_size(exchange.body.phase, credit, exchange.limits.max_read_chunk)

    cond do
      timeout <= 0 ->
        wait_expired(exchange)

      byte_size(exchange.buffer) + size > exchange.limits.max_buffer_bytes ->
        {:error, :buffer_limit, exchange}

      true ->
        case update_body_retention(exchange, retained_bytes(exchange) + size) do
          :ok -> recv_body(exchange, size, credit, read_deadline)
          {:error, reason} -> {:error, reason, exchange}
        end
    end
  end

  defp recv_body(exchange, size, credit, read_deadline) do
    case recv_body_chunk(exchange.socket, size, read_deadline) do
      {:ok, chunk} ->
        exchange = %{exchange | buffer: exchange.buffer <> chunk}

        case update_body_retention(exchange, retained_bytes(exchange)) do
          :ok ->
            if byte_size(exchange.buffer) <= exchange.limits.max_buffer_bytes,
              do: do_read_body(exchange, credit, read_deadline),
              else: {:error, :buffer_limit, exchange}

          {:error, reason} ->
            {:error, reason, exchange}
        end

      {:error, reason} ->
        _ = update_body_retention(exchange, retained_bytes(exchange))

        if reason == :timeout,
          do: wait_expired(exchange),
          else: {:error, reason, exchange}
    end
  end

  defp recv_body_chunk(socket, size, read_deadline) do
    timeout = read_remaining(read_deadline)

    cond do
      timeout <= 0 ->
        {:error, :timeout}

      size == 1 ->
        Socket.recv(socket, 1, timeout)

      true ->
        # Exact-length reads must not hold an available producer prefix until
        # more DATA arrives. Probe smaller bounded pieces before waiting.
        case Socket.recv(socket, size, 0) do
          {:error, :timeout} -> recv_body_chunk(socket, div(size, 2), read_deadline)
          result -> result
        end
    end
  end

  defp read_remaining({deadline, wait}), do: min(wait, Gaoxy.Lifecycle.remaining(deadline))
  defp read_remaining(deadline), do: Gaoxy.Lifecycle.remaining(deadline)

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

  defp send_window(%{deadline: deadline} = exchange, chunk)
       when is_integer(deadline) or deadline == :infinity do
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
  def update_body_retention(exchange, bytes) do
    case Gaoxy.Lifecycle.remaining(exchange.deadline) do
      0 -> {:error, :timeout}
      remaining -> Admission.update(exchange.gate, exchange.lease, bytes, min(remaining, 5_000))
    end
  catch
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, _ -> {:error, :closed}
  end

  @doc false
  def defer_body_retention(exchange, bytes) do
    request = :gen_server.send_request(exchange.gate, {:update, exchange.lease, bytes})
    _ = :gen_server.receive_response(request, 0)
    :ok
  catch
    :exit, _ -> :ok
  end

  @doc false
  def retained_bytes(exchange) do
    headers = if exchange.request, do: 2 * exchange.request.head_bytes, else: 0

    trailers =
      case exchange.body do
        %{trailer_bytes: bytes} -> 2 * bytes
        _ -> 0
      end

    response_trailers = 2 * Enum.reduce(exchange.response_trailers, 0, &(byte_size(&1) + &2))

    max(byte_size(exchange.buffer), exchange.poll_buffer_bytes) + headers + trailers +
      response_trailers + exchange.route_bytes + exchange.protocol_bytes +
      exchange.adapter_body_bytes
  end

  def body_complete?(%{request: %{body: :tunnel}}), do: false
  def body_complete?(%{body: :tunnel}), do: false
  def body_complete?(%{transport: nil, body: %{phase: :done}}), do: true
  def body_complete?(%{transport: nil}), do: false
  def body_complete?(%{transport: module} = exchange), do: module.body_complete?(exchange)

  def request_trailers(%{body: %{trailers: trailers}}), do: trailers
  def request_trailers(_), do: []

  def secure?(%{secure: secure}) when is_boolean(secure), do: secure
  def secure?(exchange), do: Socket.secure?(exchange.socket)

  def peer_data(exchange) do
    {address, port} = exchange.peer

    certificate =
      if exchange.transport == nil do
        case Socket.peercert(exchange.socket) do
          {:ok, cert} -> cert
          _ -> nil
        end
      else
        exchange.peer_cert
      end

    %{address: address, port: port, ssl_cert: certificate}
  end

  def sock_data(exchange) do
    {address, port} = exchange.local
    %{address: address, port: port}
  end

  def ssl_data(%{transport: Gaoxy.HTTP.HTTP2.Transport} = exchange) do
    case Gaoxy.HTTP.HTTP2.Transport.operation(exchange, :ssl_data) do
      {:ok, data} -> data
      {:error, _} -> nil
    end
  end

  def ssl_data(%{transport: module, ssl: ssl}) when not is_nil(module), do: ssl

  def ssl_data(exchange) do
    if secure?(exchange) do
      case Socket.connection_information(exchange.socket) do
        {:ok, data} -> data
        _ -> nil
      end
    end
  end

  def abort(%{transport: module} = exchange, reason) when not is_nil(module),
    do: module.abort(exchange, reason)

  def abort(exchange, _reason) do
    Socket.close(exchange.socket)
    {:ok, %{exchange | close: true}}
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
    <<chunk::binary-size(^count), tail::binary>> = bytes
    next = if tail == "", do: rest, else: [tail | rest]
    take_chunk(next, limit, [chunk | acc], size + count)
  end
end
