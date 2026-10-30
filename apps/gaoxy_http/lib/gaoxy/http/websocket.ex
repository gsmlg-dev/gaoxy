defmodule Gaoxy.HTTP.WebSocket do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.WebSocket.{ExtendedHandshake, Frame, Handshake, Message}
  alias Hell.Socket

  defstruct [
    :exchange,
    :handler,
    :app_state,
    :limits,
    :message,
    :decoder,
    :deadline,
    :lifetime_timer,
    :close_timer,
    :close_token,
    :reason,
    buffer: "",
    input_credit: 0,
    pending_output: [],
    input_events: [],
    completion_credit: 0,
    funded_floor: nil,
    funded_websocket_bytes: 0,
    memberships: nil,
    closing: false,
    initialized: false
  ]

  @defaults %{
    timeout: :infinity,
    callback_timeout: 5_000,
    close_timeout: 1_000,
    max_lifetime: :infinity,
    max_frame_size: :infinity,
    max_message_size: :infinity,
    max_fragments: :infinity,
    max_mailbox: :infinity,
    max_push_frames: :infinity
  }
  # Phoenix passes its complete transport configuration after applying these
  # policies. They belong to the application handshake, not the wire engine.
  @application_options [
    :path,
    :serializer,
    :error_handler,
    :log,
    :code_reloader,
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

    configured = Map.new(Keyword.take(options, Map.keys(@defaults)))

    # Phoenix exposes max_frame_size, so an omitted message ceiling follows it.
    # A direct WebSock user's explicit message ceiling remains authoritative.
    limits =
      @defaults
      |> Map.put(
        :max_message_size,
        Map.get(configured, :max_frame_size, @defaults.max_frame_size)
      )
      |> Map.merge(configured)

    if Keyword.keyword?(options) and Enum.all?(Keyword.keys(options), &(&1 in allowed)) and
         Enum.all?(limits, fn {key, value} ->
           (value == :infinity and key not in [:callback_timeout, :close_timeout]) or
             (is_integer(value) and value > 0)
         end) and
         Keyword.get(options, :compress, false) == false and
         Keyword.get(options, :validate_utf8, true) == true do
      {:ok, limits}
    else
      {:error, :invalid_websocket_options}
    end
  end

  def start(exchange, _service_limits) do
    {:websocket, module, initial, limits, response_headers} = exchange.response

    deadline = Lifecycle.deadline(limits.max_lifetime)

    next_exchange =
      if exchange.transport do
        %{exchange | buffer: "", response: :upgraded, deadline: deadline}
      else
        %{exchange | buffer: "", response: :upgraded, request: nil, body: nil, deadline: deadline}
      end

    ws = %__MODULE__{
      exchange: next_exchange,
      handler: module,
      app_state: initial,
      limits: limits,
      deadline: deadline,
      buffer: exchange.buffer,
      # A server control frame is at most 125 payload bytes plus two header
      # bytes. Its encoder/output copies remain funded through graceful close.
      completion_credit: if(exchange.funding, do: 2 * 127, else: 0),
      memberships: if(exchange.funding, do: Map.delete(exchange.funding.memberships, :request)),
      decoder: Frame.decoder(max_frame_size: limits.max_frame_size),
      message:
        Message.new(
          max_message_bytes: limits.max_message_size,
          max_fragments: limits.max_fragments
        )
    }

    ws = fund_completion(ws)

    with {:ok, headers} <- handshake(exchange.request, response_headers),
         # Upgrade is a single transition from the completed H1 request to a new
         # admitted protocol lifetime. Later callbacks cannot renew this deadline.
         :ok <- Admission.upgrade(exchange.gate, exchange.lease, retained(ws), deadline),
         {:ok, ws} <- send_handshake(ws, headers) do
      timer =
        if deadline != :infinity do
          Process.send_after(
            self(),
            {:gaoxy_websocket_lifetime, exchange.lease},
            Lifecycle.remaining(deadline)
          )
        end

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
         :ok <- account(ws, size),
         :ok <- send_wire(ws, IO.iodata_to_binary(head)) do
      {:ok, ws}
    end
  end

  def data(bytes, socket, ws) do
    ws = %{ws | exchange: %{ws.exchange | socket: socket}}
    data(bytes, ws)
  end

  def data(bytes, ws) do
    ws = %{ws | input_credit: 0, buffer: bytes}
    parse(ws)
  end

  @doc false
  def reserve_input(ws, credit) do
    previous = ws
    ws = fund_completion(%{ws | input_credit: credit})

    case account(ws, 0, previous) do
      :ok -> {:ok, ws}
      error -> error
    end
  end

  defp parse(ws) do
    with :ok <- account(ws),
         true <- within?(mailbox_count(), ws.limits.max_mailbox),
         {:ok, events, decoder} <- Frame.consume(ws.decoder, ws.buffer) do
      events(%{ws | buffer: "", decoder: decoder, input_events: events})
    else
      {:error, code, reason} -> close(%{ws | buffer: ""}, code, {:error, reason})
      _ -> close(%{ws | buffer: ""}, 1009, {:error, :resource_limit})
    end
  end

  defp events(%{input_events: []} = ws), do: idle(ws)
  defp events(%{closing: true, input_events: [{:control, :close, _} | _]} = ws), do: {:close, ws}

  defp events(%{closing: true, input_events: [_ | rest]} = ws),
    do: events(%{ws | input_events: rest})

  defp events(%{input_events: [event | rest]} = ws) do
    case Message.consume(ws.message, event) do
      {:error, code, reason} ->
        close(ws, code, {:error, reason})

      {:ok, result, message} ->
        next = %{ws | message: message, input_events: rest}

        case dispatch(next, result) do
          {:continue, next} -> events(next)
          other -> other
        end
    end
  end

  defp dispatch(ws, nil), do: {:continue, ws}

  defp dispatch(ws, {:control, :close, payload}) do
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

  defp dispatch(ws, {:data, opcode, payload}),
    do:
      callback(
        ws,
        :handle_in,
        [{payload, [opcode: opcode]}, ws.app_state],
        2 * byte_size(payload)
      )

  defp dispatch(ws, {:control, opcode, payload}) do
    result = if opcode == :ping, do: send_frame(ws, :pong, payload), else: :ok

    if result == :ok do
      if function_exported?(ws.handler, :handle_control, 2),
        do:
          callback(
            ws,
            :handle_control,
            [{payload, [opcode: opcode]}, ws.app_state],
            byte_size(payload)
          ),
        else: {:continue, ws}
    else
      {:close, %{ws | reason: {:error, result}}}
    end
  end

  def info({:gaoxy_websocket_lifetime, lease}, %{exchange: %{lease: lease}} = ws),
    do: close(ws, 1001, :timeout)

  def info({:gaoxy_websocket_close, token}, %{close_token: token} = ws), do: {:close, ws}

  def info({kind, _}, ws) when kind in [:gaoxy_websocket_close, :gaoxy_websocket_lifetime],
    do: idle(ws)

  def info(_, %{closing: true} = ws), do: idle(ws)

  def info(message, ws) do
    if within?(mailbox_count(), ws.limits.max_mailbox),
      do: callback(ws, :handle_info, [message, ws.app_state]),
      else: close(ws, 1009, {:error, :mailbox_limit})
  end

  def drain(ws, deadline) do
    ws = %{ws | deadline: Lifecycle.earlier(ws.deadline, deadline)}

    ws =
      if ws.exchange.transport,
        do: %{ws | exchange: %{ws.exchange | deadline: ws.deadline}},
        else: ws

    close(ws, 1001, :shutdown)
  end

  defp callback(ws, function, args, bytes \\ 0) do
    deadline = Lifecycle.earlier(ws.deadline, Lifecycle.deadline(ws.limits.callback_timeout))

    with :ok <-
           Admission.begin_callback(
             ws.exchange.gate,
             ws.exchange.lease,
             retained(ws, 0, bytes),
             deadline
           ) do
      ws =
        if ws.memberships do
          paid = retained(ws, 0, bytes)
          %{ws | funded_floor: paid.transport_bytes, funded_websocket_bytes: paid.websocket_bytes}
        else
          ws
        end

      result(ws, apply(ws.handler, function, args))
    else
      {:error, reason} -> {:close, %{ws | reason: {:error, reason}}}
    end
  catch
    kind, reason ->
      case complete(ws, ws.app_state, []) do
        {:continue, ws} -> close(ws, 1011, {:error, {kind, reason}})
        other -> other
      end
  end

  defp result(ws, {:ok, state}), do: complete(ws, state, [])
  defp result(ws, {:reply, _, messages, state}), do: result(ws, {:push, messages, state})

  defp result(ws, {:push, messages, state}) do
    with {:continue, ws} <- complete(ws, state, messages), {:ok, ws} <- push(ws), do: idle(ws)
  end

  defp result(ws, {:gaoxy_push, messages, {recipient, reference}, state})
       when is_pid(recipient) and is_reference(reference) do
    result = result(ws, {:push, messages, state})

    receipt =
      case result do
        {_, %{reason: {:error, reason}}} -> {:error, reason}
        {:continue, %{closing: false}} -> :ok
        _ -> {:error, :closed}
      end

    send(recipient, {:gaoxy_websocket_written, reference, receipt})
    result
  end

  defp result(ws, {:stop, reason, state}) do
    code =
      case reason do
        :normal -> 1000
        {:shutdown, :disconnected} -> 1000
        {:shutdown, :restart} -> 1012
        _ -> 1011
      end

    result(ws, {:stop, reason, code, state})
  end

  defp result(ws, {:stop, reason, detail, state}),
    do: result(ws, {:stop, reason, detail, [], state})

  defp result(ws, {:stop, reason, detail, messages, state}) do
    with {:continue, ws} <- complete(ws, state, messages),
         {:ok, ws} <- push(ws) do
      reason =
        case reason do
          :normal -> :normal
          {:shutdown, :disconnected} -> :normal
          {:shutdown, :restart} -> :shutdown
          other -> {:error, other}
        end

      close(ws, detail, reason)
    end
  end

  defp result(ws, _) do
    case complete(ws, ws.app_state, []) do
      {:continue, ws} -> close(ws, 1011, {:error, :invalid_callback_result})
      other -> other
    end
  end

  # The callback watchdog owns computation only. Install its complete retained
  # result and invalidate that watchdog before any synchronous transport call.
  defp complete(ws, state, messages) do
    messages = if is_tuple(messages), do: [messages], else: messages
    previous = ws
    ws = fund_completion(%{ws | app_state: state, pending_output: messages})

    result =
      with :ok <- if(ws.memberships, do: account(ws, 0, previous), else: :ok),
           do: Admission.end_websocket_callback(ws.exchange.gate, ws.exchange.lease, retained(ws))

    case result do
      :ok -> {:continue, ws}
      {:error, reason} -> {:close, %{ws | reason: {:error, reason}}}
    end
  end

  defp push(ws) do
    with true <- is_list(ws.pending_output),
         true <- within?(length(ws.pending_output), ws.limits.max_push_frames),
         true <-
           Enum.all?(ws.pending_output, fn
             {opcode, payload} when opcode in [:text, :binary, :ping, :pong] ->
               within?(IO.iodata_length(payload || ""), ws.limits.max_message_size) and
                 within?(IO.iodata_length(payload || ""), ws.limits.max_frame_size)

             _ ->
               false
           end) do
      push_next(ws)
    else
      _ -> close(ws, 1011, {:error, :output_limit})
    end
  end

  defp push_next(%{pending_output: []} = ws), do: {:ok, ws}

  defp push_next(%{pending_output: [{opcode, payload} | rest]} = ws) do
    case send_frame(ws, opcode, payload || "") do
      :ok ->
        next = fund_completion(%{ws | pending_output: rest})

        case account(next, 0, ws) do
          :ok -> push_next(next)
          {:error, reason} -> {:close, %{next | reason: {:error, reason}}}
        end

      {:error, reason} ->
        close(ws, 1011, {:error, reason})
    end
  end

  defp send_frame(ws, opcode, payload) do
    with {:ok, cursor} <- Frame.encoder(opcode, payload) do
      send_cursor(ws, cursor)
    else
      {:error, _, reason} -> {:error, reason}
    end
  end

  defp send_cursor(ws, cursor) do
    case Frame.next_chunk(cursor, ws.exchange.limits.max_write_chunk) do
      :done ->
        :ok

      {:ok, chunk, next} ->
        with :ok <- send_chunk(ws, chunk), do: send_cursor(ws, next)
    end
  end

  defp send_wire(_, ""), do: :ok

  defp send_wire(ws, wire) do
    size = min(byte_size(wire), ws.exchange.limits.max_write_chunk)
    <<chunk::binary-size(size), rest::binary>> = wire
    with :ok <- send_chunk(ws, chunk), do: send_wire(ws, rest)
  end

  defp send_chunk(ws, chunk) do
    size = byte_size(chunk)

    deadline =
      Lifecycle.earlier(ws.deadline, Lifecycle.deadline(ws.exchange.limits.write_timeout))

    operation = make_ref()

    with :ok <- account(ws, 2 * size),
         :ok <-
           Admission.start_send_until(
             ws.exchange.gate,
             ws.exchange.lease,
             size,
             operation,
             deadline
           ) do
      result =
        if ws.exchange.transport,
          do: ws.exchange.transport.websocket_send(ws.exchange, chunk),
          else: Socket.send(ws.exchange.socket, chunk)

      :ok = Admission.finish_send(ws.exchange.gate, ws.exchange.lease, operation, result)
      :ok = account(ws)
      result
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
        timeout = Lifecycle.earlier(ws.limits.close_timeout, Lifecycle.remaining(ws.deadline))
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
    ws = fund_completion(ws)

    case Admission.retain(ws.exchange.gate, ws.exchange.lease, retained(ws)) do
      :ok -> {:continue, ws}
      {:error, reason} -> {:close, %{ws | reason: {:error, reason}}}
    end
  end

  def terminate(ws, fallback) do
    if ws.lifetime_timer, do: Process.cancel_timer(ws.lifetime_timer)
    if ws.close_timer, do: Process.cancel_timer(ws.close_timer)
    reason = ws.reason || fallback

    if ws.initialized and function_exported?(ws.handler, :terminate, 2) do
      deadline = Lifecycle.earlier(ws.deadline, Lifecycle.deadline(ws.limits.callback_timeout))

      if Admission.begin_callback(ws.exchange.gate, ws.exchange.lease, retained(ws), deadline) ==
           :ok do
        try do
          ws.handler.terminate(reason, ws.app_state)
        after
          Admission.end_websocket_callback(ws.exchange.gate, ws.exchange.lease, retained(ws))
        end
      end
    end

    :ok
  catch
    _, _ -> :ok
  end

  def timeout(ws) do
    _ = send_frame(ws, :close, <<1001::16>>)
    terminate(ws, :timeout)
  end

  defp retained(ws, staging \\ 0, callback_bytes \\ 0) do
    exchange_bytes =
      if ws.exchange.transport, do: Gaoxy.HTTP.Exchange.retained_bytes(ws.exchange), else: 0

    categories = %{
      transport_bytes:
        exchange_bytes + 2 * byte_size(ws.buffer) + 2 * ws.input_credit +
          :erlang.external_size(ws.decoder) + staging,
      websocket_bytes:
        2 * ws.message.bytes + :erlang.external_size(ws.app_state) +
          :erlang.external_size(ws.pending_output) + :erlang.external_size(ws.input_events) +
          callback_bytes
    }

    if ws.memberships do
      transport = categories.transport_bytes
      temporary = max((ws.funded_floor || transport + ws.completion_credit) - transport, 0)

      %{
        retained_bytes: categories.transport_bytes + categories.websocket_bytes,
        temporary_bytes: temporary,
        transport_bytes: categories.transport_bytes + temporary,
        websocket_bytes: categories.websocket_bytes,
        memberships: ws.memberships,
        pending_processes: 0
      }
    else
      categories
    end
  end

  defp fund_completion(%{memberships: nil} = ws), do: ws

  defp fund_completion(ws) do
    # Keep a fixed funded total across send staging and its release. Adding a
    # fresh temporary reserve to every new retained value would require growth
    # even for an already-funded close frame during drain.
    accounting = retained(ws)
    transport = accounting.transport_bytes - accounting.temporary_bytes

    %{
      ws
      | funded_floor: transport + ws.completion_credit,
        funded_websocket_bytes: accounting.websocket_bytes
    }
  end

  defp account(ws, staging \\ 0, previous \\ nil) do
    accounting = retained(ws, staging)

    if ws.memberships do
      deadline = Lifecycle.earlier(ws.deadline, Lifecycle.deadline(50))
      paid = previous || ws
      total = accounting.retained_bytes + accounting.temporary_bytes
      funded = paid.funded_floor + paid.funded_websocket_bytes
      mutation = if total <= funded, do: :repartition_until, else: :update_until

      apply(Admission, mutation, [
        ws.exchange.gate,
        ws.exchange.lease,
        accounting,
        make_ref(),
        deadline
      ])
    else
      Admission.update(ws.exchange.gate, ws.exchange.lease, accounting)
    end
  end

  defp within?(_, :infinity), do: true
  defp within?(value, limit), do: value <= limit

  defp mailbox_count do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)
    count
  end
end
