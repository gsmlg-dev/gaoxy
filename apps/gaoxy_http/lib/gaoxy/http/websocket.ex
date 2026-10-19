defmodule Gaoxy.HTTP.WebSocket do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.WebSocket.{ExtendedHandshake, Frame, Handshake, Message}
  alias ThousandIsland.Socket

  defstruct [
    :exchange,
    :handler,
    :app_state,
    :limits,
    :message,
    :deadline,
    :lifetime_timer,
    :close_timer,
    :close_token,
    :reason,
    buffer: "",
    input_credit: 0,
    closing: false,
    initialized: false
  ]

  @defaults %{
    timeout: 60_000,
    callback_timeout: 5_000,
    close_timeout: 1_000,
    max_lifetime: 86_400_000,
    max_frame_size: 262_144,
    max_message_size: 262_144,
    max_fragments: 128,
    max_mailbox: 128,
    max_push_frames: 32
  }
  # Phoenix passes its complete transport configuration after applying these
  # policies. They belong to the application handshake, not the wire engine.
  @application_options [
    :path,
    :serializer,
    :error_handler,
    :transport_log,
    :check_origin,
    :connect_info,
    :check_csrf,
    :subprotocols,
    :auth_token
  ]

  def prepare(exchange, {module, initial, options}) when is_atom(module) and is_list(options) do
    with true <-
           Code.ensure_loaded?(module) and function_exported?(module, :init, 1) and
             function_exported?(module, :handle_in, 2) and
             function_exported?(module, :handle_info, 2),
         {:ok, limits} <- options(options),
         {:ok, _headers} <- handshake(exchange.request, []) do
      {:ok, %{exchange | response: {:websocket, module, initial, limits, []}}}
    else
      _ -> {:error, :invalid_websocket_upgrade}
    end
  end

  def prepare(_, _), do: {:error, :invalid_websocket_upgrade}

  defp handshake(%{protocol: "websocket", body: :tunnel} = request, headers),
    do: ExtendedHandshake.headers(request, headers)

  defp handshake(request, headers), do: Handshake.headers(request, headers)

  def response_headers(%{response: {:websocket, module, initial, limits, _}} = exchange, headers),
    do: %{exchange | response: {:websocket, module, initial, limits, headers}}

  defp options(options) do
    allowed =
      Map.keys(@defaults) ++
        @application_options ++ [:compress, :validate_utf8, :early_validate_upgrade]

    limits = Map.merge(@defaults, Map.new(Keyword.take(options, Map.keys(@defaults))))

    if Keyword.keyword?(options) and Enum.all?(Keyword.keys(options), &(&1 in allowed)) and
         Enum.all?(limits, fn {_, value} -> is_integer(value) and value > 0 end) and
         Keyword.get(options, :compress, false) == false and
         Keyword.get(options, :validate_utf8, true) == true do
      {:ok, limits}
    else
      {:error, :invalid_websocket_options}
    end
  end

  def start(exchange, service_limits) do
    {:websocket, module, initial, limits, response_headers} = exchange.response

    limits =
      limits
      |> Map.put(:max_state, service_limits.max_state)
      |> Map.update!(:max_frame_size, &min(&1, div(service_limits.max_bytes, 4)))
      |> Map.update!(:max_message_size, &min(&1, div(service_limits.max_bytes, 4)))

    deadline = Lifecycle.deadline(limits.max_lifetime)

    next_exchange =
      if exchange.transport do
        %{exchange | buffer: "", response: :upgraded, deadline: deadline}
      else
        %{exchange | buffer: "", response: :upgraded, request: nil, body: nil}
      end

    ws = %__MODULE__{
      exchange: next_exchange,
      handler: module,
      app_state: initial,
      limits: limits,
      deadline: deadline,
      buffer: exchange.buffer,
      message:
        Message.new(
          max_message_bytes: limits.max_message_size,
          max_fragments: limits.max_fragments
        )
    }

    with {:ok, headers} <- handshake(exchange.request, response_headers),
         # Upgrade is a single transition from the completed H1 request to a new
         # admitted protocol lifetime. Later callbacks cannot renew this deadline.
         :ok <- Admission.upgrade(exchange.gate, exchange.lease, retained(ws), deadline),
         :ok <-
           Admission.begin_callback(
             exchange.gate,
             exchange.lease,
             retained(ws),
             if(exchange.transport, do: deadline, else: exchange.deadline)
           ),
         {:ok, ws} <- send_handshake(ws, headers) do
      timer =
        Process.send_after(
          self(),
          {:gaoxy_websocket_lifetime, exchange.lease},
          if(exchange.transport, do: Lifecycle.remaining(deadline), else: limits.max_lifetime)
        )

      ws = %{ws | lifetime_timer: timer, initialized: true}

      case callback(ws, :init, [initial]) do
        {:continue, ws} -> parse(ws)
        other -> other
      end
    else
      {:error, reason} -> {:close, %{ws | reason: {:error, reason}}}
    end
  end

  defp send_handshake(%{exchange: %{transport: module} = exchange} = ws, headers)
       when not is_nil(module) do
    case module.websocket_open(exchange, headers, ws.deadline) do
      {:ok, exchange} -> {:ok, %{ws | exchange: %{exchange | request: nil, body: nil}}}
      error -> error
    end
  end

  defp send_handshake(ws, headers) do
    head = [
      "HTTP/1.1 101 Switching Protocols\r\n",
      Enum.map(headers, fn {key, value} -> [key, ": ", value, "\r\n"] end),
      "\r\n"
    ]

    size = IO.iodata_length(head)

    with true <- size <= ws.exchange.limits.max_header_bytes || {:error, :response_header_limit},
         :ok <- account(ws, retained(ws) + size),
         :ok <- send_wire(ws, IO.iodata_to_binary(head)) do
      {:ok, ws}
    end
  end

  def data(bytes, socket, ws) do
    ws = %{ws | exchange: %{ws.exchange | socket: socket}}
    data(bytes, ws)
  end

  def data(bytes, ws) do
    ws = %{ws | input_credit: 0}
    size = byte_size(ws.buffer) + byte_size(bytes)

    with true <- size <= ws.limits.max_frame_size + 14 + ws.exchange.limits.max_read_chunk,
         :ok <- account(ws, retained(%{ws | buffer: ""}) + 2 * size) do
      parse(%{ws | buffer: ws.buffer <> bytes})
    else
      _ -> close(ws, 1009, {:error, :buffer_limit})
    end
  end

  @doc false
  def reserve_input(ws, credit) do
    ws = %{ws | input_credit: credit}

    case account(ws, retained(ws)) do
      :ok -> {:ok, ws}
      error -> error
    end
  end

  defp parse(ws) do
    with :ok <- account(ws, retained(ws)),
         {:message_queue_len, count} when count <= ws.limits.max_mailbox <-
           Process.info(self(), :message_queue_len) do
      case Frame.decode(ws.buffer, ws.limits.max_frame_size) do
        :more -> idle(ws)
        {:error, code, reason} -> close(%{ws | buffer: ""}, code, {:error, reason})
        {:ok, frame, rest} -> dispatch(%{ws | buffer: rest}, frame)
      end
    else
      _ -> close(%{ws | buffer: ""}, 1009, {:error, :resource_limit})
    end
  end

  defp dispatch(%{closing: true} = ws, %{opcode: :close}), do: {:close, ws}
  defp dispatch(%{closing: true} = ws, _), do: parse(ws)

  defp dispatch(ws, %{opcode: :close, payload: payload}) do
    result =
      if function_exported?(ws.handler, :gaoxy_close, 2) do
        detail =
          case payload do
            "" -> {nil, ""}
            <<code::16, reason::binary>> -> {code, reason}
          end

        callback(ws, :gaoxy_close, [detail, ws.app_state], byte_size(payload))
      else
        {:continue, ws}
      end

    case result do
      {:continue, ws} ->
        _ = send_frame(ws, :close, payload)
        {:close, %{ws | reason: :remote}}

      other ->
        other
    end
  end

  defp dispatch(ws, frame) do
    case Message.push(ws.message, frame) do
      {:error, code, reason} ->
        close(ws, code, {:error, reason})

      {:ok, nil, message} ->
        parse(%{ws | message: message})

      {:ok, {:data, opcode, payload}, message} ->
        next = %{ws | message: message}

        proceed(
          callback(
            next,
            :handle_in,
            [{payload, [opcode: opcode]}, ws.app_state],
            byte_size(payload)
          )
        )

      {:ok, {:control, opcode, payload}, message} ->
        next = %{ws | message: message}
        result = if opcode == :ping, do: send_frame(next, :pong, payload), else: :ok

        if result == :ok do
          if function_exported?(ws.handler, :handle_control, 2),
            do:
              proceed(
                callback(
                  next,
                  :handle_control,
                  [{payload, [opcode: opcode]}, ws.app_state],
                  byte_size(payload)
                )
              ),
            else: parse(next)
        else
          {:close, %{ws | reason: {:error, result}}}
        end
    end
  end

  defp proceed({:continue, ws}), do: parse(ws)
  defp proceed(other), do: other

  def info({:gaoxy_websocket_lifetime, lease}, %{exchange: %{lease: lease}} = ws),
    do: close(ws, 1001, :timeout)

  def info({:gaoxy_websocket_close, token}, %{close_token: token} = ws), do: {:close, ws}

  def info({kind, _}, ws) when kind in [:gaoxy_websocket_close, :gaoxy_websocket_lifetime],
    do: idle(ws)

  def info(_, %{closing: true} = ws), do: idle(ws)

  def info(message, ws) do
    case Process.info(self(), :message_queue_len) do
      {:message_queue_len, count} when count <= ws.limits.max_mailbox ->
        callback(ws, :handle_info, [message, ws.app_state])

      _ ->
        close(ws, 1009, {:error, :mailbox_limit})
    end
  end

  def drain(ws, deadline) do
    ws = %{ws | deadline: min(ws.deadline, deadline)}

    ws =
      if ws.exchange.transport,
        do: %{ws | exchange: %{ws.exchange | deadline: ws.deadline}},
        else: ws

    close(ws, 1001, :shutdown)
  end

  defp callback(ws, function, args, bytes \\ 0) do
    deadline = min(ws.deadline, Lifecycle.deadline(ws.limits.callback_timeout))

    with :ok <-
           Admission.begin_callback(
             ws.exchange.gate,
             ws.exchange.lease,
             retained(ws) + bytes,
             deadline
           ) do
      result(ws, apply(ws.handler, function, args))
    else
      {:error, reason} -> {:close, %{ws | reason: {:error, reason}}}
    end
  catch
    kind, reason -> close(ws, 1011, {:error, {kind, reason}})
  end

  defp result(ws, {:ok, state}), do: idle(%{ws | app_state: state})
  defp result(ws, {:reply, _, messages, state}), do: result(ws, {:push, messages, state})

  defp result(ws, {:push, messages, state}) do
    ws = %{ws | app_state: state}

    case push(ws, messages) do
      :ok -> idle(ws)
      {:error, reason} -> close(ws, 1011, {:error, reason})
    end
  end

  defp result(ws, {:gaoxy_push, messages, {recipient, reference}, state})
       when is_pid(recipient) and is_reference(reference) do
    ws = %{ws | app_state: state}
    result = push(ws, messages)
    send(recipient, {:gaoxy_websocket_written, reference, result})

    case result do
      :ok -> idle(ws)
      {:error, reason} -> close(ws, 1011, {:error, reason})
    end
  end

  defp result(ws, {:stop, reason, state}) do
    code =
      case reason do
        :normal -> 1000
        {:shutdown, :restart} -> 1012
        _ -> 1011
      end

    result(ws, {:stop, reason, code, state})
  end

  defp result(ws, {:stop, reason, detail, state}),
    do: result(ws, {:stop, reason, detail, [], state})

  defp result(ws, {:stop, reason, detail, messages, state}) do
    ws = %{ws | app_state: state}
    _ = push(ws, messages)

    reason =
      case reason do
        :normal -> :normal
        {:shutdown, :restart} -> :shutdown
        other -> {:error, other}
      end

    close(ws, detail, reason)
  end

  defp result(ws, _), do: close(ws, 1011, {:error, :invalid_callback_result})

  defp push(ws, messages) do
    messages = if is_tuple(messages), do: [messages], else: messages

    with {:ok, _} <-
           Enum.reduce_while(messages, {:ok, {0, 0}}, fn
             {opcode, payload}, {:ok, {count, bytes}}
             when opcode in [:text, :binary, :ping, :pong] ->
               bytes = bytes + IO.iodata_length(payload || "")

               if count < ws.limits.max_push_frames and bytes <= ws.limits.max_message_size,
                 do: {:cont, {:ok, {count + 1, bytes}}},
                 else: {:halt, {:error, :output_limit}}

             _, _ ->
               {:halt, {:error, :invalid_output}}
           end) do
      Enum.reduce_while(messages, :ok, fn {opcode, payload}, :ok ->
        case send_frame(ws, opcode, payload || "") do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp send_frame(ws, opcode, payload) do
    size = IO.iodata_length(payload)

    with :ok <- account(ws, retained(ws) + 2 * size + 14),
         {:ok, wire} <- Frame.encode(opcode, payload),
         :ok <- send_wire(ws, wire),
         :ok <- account(ws, retained(ws)) do
      :ok
    else
      {:error, _, reason} -> {:error, reason}
      error -> error
    end
  end

  defp send_wire(_, ""), do: :ok

  defp send_wire(ws, wire) do
    size = min(byte_size(wire), ws.exchange.limits.max_write_chunk)
    <<chunk::binary-size(size), rest::binary>> = wire

    with {:ok, operation} <- Admission.start_send(ws.exchange.gate, ws.exchange.lease, size) do
      result =
        if ws.exchange.transport,
          do: ws.exchange.transport.websocket_send(ws.exchange, chunk),
          else: Socket.send(ws.exchange.socket, chunk)

      :ok = Admission.finish_send(ws.exchange.gate, ws.exchange.lease, operation, result)

      case result do
        :ok -> send_wire(ws, rest)
        error -> error
      end
    end
  end

  defp close(%{closing: true} = ws, _, _), do: idle(ws)

  defp close(ws, detail, reason) do
    payload =
      case detail do
        {nil, ""} -> ""
        code when is_integer(code) -> <<code::16>>
        {code, text} -> <<code::16>> <> IO.iodata_to_binary(text || "")
      end

    case send_frame(ws, :close, payload) do
      :ok ->
        token = make_ref()
        timeout = min(ws.limits.close_timeout, Lifecycle.remaining(ws.deadline))
        timer = Process.send_after(self(), {:gaoxy_websocket_close, token}, timeout)

        idle(%{
          ws
          | closing: true,
            close_timer: timer,
            close_token: token,
            reason: reason,
            buffer: "",
            message: Message.new()
        })

      _ ->
        {:close, %{ws | reason: reason}}
    end
  end

  defp idle(ws) do
    if :erlang.external_size(ws.app_state) <= ws.limits.max_state do
      case Admission.retain(ws.exchange.gate, ws.exchange.lease, retained(ws)) do
        :ok -> {:continue, ws}
        _ -> {:close, %{ws | reason: {:error, :byte_limit}}}
      end
    else
      {:close, %{ws | reason: {:error, :state_limit}}}
    end
  end

  def terminate(ws, fallback) do
    if ws.lifetime_timer, do: Process.cancel_timer(ws.lifetime_timer)
    if ws.close_timer, do: Process.cancel_timer(ws.close_timer)
    reason = ws.reason || fallback

    if ws.initialized and function_exported?(ws.handler, :terminate, 2) do
      deadline = min(ws.deadline, Lifecycle.deadline(ws.limits.callback_timeout))

      if Admission.begin_callback(ws.exchange.gate, ws.exchange.lease, retained(ws), deadline) ==
           :ok,
         do: ws.handler.terminate(reason, ws.app_state)
    end

    :ok
  catch
    _, _ -> :ok
  end

  def timeout(ws) do
    _ = send_frame(ws, :close, <<1001::16>>)
    terminate(ws, :timeout)
  end

  defp retained(ws) do
    exchange_bytes =
      if ws.exchange.transport, do: Gaoxy.HTTP.Exchange.retained_bytes(ws.exchange), else: 0

    exchange_bytes + 2 * byte_size(ws.buffer) + 2 * ws.message.bytes +
      2 * ws.input_credit + :erlang.external_size(ws.app_state)
  end

  defp account(ws, bytes), do: Admission.update(ws.exchange.gate, ws.exchange.lease, bytes)
end
