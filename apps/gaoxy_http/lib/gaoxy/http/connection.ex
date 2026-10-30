defmodule Gaoxy.HTTP.Connection do
  @moduledoc false
  use Hell.Handler
  @behaviour Gaoxy.NativeStreamHandler
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Options, ProtocolDetector, WebSocket}
  alias Gaoxy.HTTP.HTTP1.Parser

  @impl Gaoxy.NativeStreamHandler
  def validate_options(options), do: Options.normalize(options)

  @impl true
  def handle_connection(socket, %{spec: spec} = context) do
    case protocol(socket, spec.handler_options) do
      :http2 ->
        start_http2(socket, context)

      :detecting ->
        start_detecting(socket, context)

      :http1 ->
        start_http1(socket, context)

      {:error, reason} ->
        {:error, reason, context}
    end
  end

  defp protocol(socket, options) do
    if Hell.Socket.secure?(socket) do
      case Hell.Socket.negotiated_protocol(socket) do
        {:ok, "h2"} ->
          if :http2 in options.protocols, do: :http2, else: {:error, :unsupported_protocol}

        {:ok, "http/1.1"} ->
          if :http1 in options.protocols, do: :http1, else: {:error, :unsupported_protocol}

        {:error, :protocol_not_negotiated} ->
          if :http1 in options.protocols, do: :http1, else: {:error, :unsupported_protocol}

        _ ->
          {:error, :unsupported_protocol}
      end
    else
      case {options.h2c, options.protocols} do
        {:prior_knowledge, [:http2]} -> :http2
        {:prior_knowledge, [:http2, :http1]} -> :detecting
        _ -> :http1
      end
    end
  end

  defp start_http2(socket, context) do
    with {:ok, peer} <- Hell.Socket.peername(socket),
         {:ok, local} <- Hell.Socket.sockname(socket) do
      ssl = socket_information(Hell.Socket.connection_information(socket))
      cert = socket_information(Hell.Socket.peercert(socket))

      Gaoxy.HTTP.HTTP2.Connection.start(
        socket,
        Map.merge(context, %{
          owner: self(),
          peer: peer,
          local: local,
          secure: Hell.Socket.secure?(socket),
          ssl: ssl,
          peer_cert: cert
        })
      )
    else
      {:error, reason} when reason in [:closed, :einval, :enotconn] -> {:close, context}
      {:error, reason} -> {:error, reason, context}
    end
  end

  defp socket_information({:ok, value}), do: value
  defp socket_information(_), do: nil

  defp start_detecting(socket, %{spec: spec} = context) do
    with :ok <-
           Hell.Socket.setopts(socket,
             recbuf: Gaoxy.HTTP.HTTP2.Limits.receive_buffer(),
             buffer: Gaoxy.HTTP.HTTP2.Limits.receive_buffer(),
             send_timeout: spec.handler_options.http_limits.write_timeout,
             send_timeout_close: true
           ),
         {:ok, lease, connection_member} <- acquire_connection(context) do
      {:continue,
       Map.merge(context, %{
         phase: :detecting,
         lease: lease,
         connection_member: connection_member,
         buffer: "",
         first_input: nil,
         detector_deadline: nil,
         detector_timer: nil,
         detector_token: nil,
         closing: false
       })}
    else
      {:error, reason} -> {:error, reason, context}
    end
  end

  defp owner_lease(%{lease: lease} = context),
    do: {:ok, lease, Map.get(context, :connection_member, lease)}

  defp owner_lease(context), do: acquire_connection(context)

  defp acquire_connection(context) do
    member = make_ref()

    case Admission.acquire(context.gate, 0,
           kind: :connection,
           memberships: %{connection: member},
           drain_notify: true
         ) do
      {:ok, lease} -> {:ok, lease, member}
      error -> error
    end
  end

  defp update(state, bytes, deadline) do
    deadline = if is_integer(deadline), do: deadline, else: Lifecycle.deadline(50)
    Admission.update_until(state.gate, state.lease, bytes, make_ref(), deadline)
  catch
    :exit, _ -> {:error, :closed}
  end

  defp start_http1(socket, %{spec: spec} = context) do
    limits = spec.handler_options.http_limits

    with :ok <-
           Hell.Socket.setopts(socket,
             recbuf: limits.max_buffer_bytes,
             buffer: limits.max_buffer_bytes,
             send_timeout: limits.write_timeout,
             send_timeout_close: true
           ),
         {:ok, lease, connection_member} <- owner_lease(context) do
      {:continue,
       Map.merge(context, %{
         lease: lease,
         connection_member: connection_member,
         first_input: Map.get(context, :first_input),
         buffer: "",
         phase: :idle,
         deadline: nil,
         header_timer: nil,
         header_token: nil,
         websocket: nil,
         closing: false,
         limits: limits
       })}
    else
      {:error, reason} -> {:error, reason, context}
    end
  end

  @impl true
  def handle_data("", _socket, %{phase: :detecting} = state), do: {:continue, state}

  def handle_data(bytes, socket, %{phase: :detecting} = state) do
    state = detection_started(state)

    if Lifecycle.remaining(state.detector_deadline) == 0 do
      {:close, cancel_detection(state)}
    else
      case ProtocolDetector.classify(state.buffer, bytes) do
        {:more, carry} ->
          case update(state, byte_size(carry), state.detector_deadline) do
            :ok -> {:continue, %{state | buffer: carry}}
            {:error, _} -> {:close, cancel_detection(state)}
          end

        {protocol, replay} ->
          select_protocol(protocol, replay, socket, cancel_detection(state))
      end
    end
  end

  def handle_data(bytes, socket, %{phase: :http2} = state),
    do: Gaoxy.HTTP.HTTP2.Connection.data(bytes, socket, state)

  def handle_data(bytes, socket, %{phase: :websocket} = state) do
    websocket_result(WebSocket.data(bytes, socket, state.websocket), state)
  end

  def handle_data(bytes, socket, state) do
    if byte_size(state.buffer) + byte_size(bytes) > state.spec.limits.max_bytes do
      {:close, state}
    else
      state = %{state | buffer: state.buffer <> bytes}

      process(socket, state)
    end
  end

  defp detection_started(%{first_input: nil} = state) do
    options = state.spec.handler_options

    timeout =
      min(
        options.http_limits.header_timeout,
        min(options.http_limits.request_timeout, options.h2_limits.frame_timeout)
      )

    first = Lifecycle.now()
    token = make_ref()
    timer = Process.send_after(self(), {:gaoxy_http_detect_timeout, token}, timeout)

    %{
      state
      | first_input: first,
        detector_deadline: first + timeout,
        detector_timer: timer,
        detector_token: token
    }
  end

  defp detection_started(state), do: state

  defp cancel_detection(state) do
    if state.detector_timer, do: Process.cancel_timer(state.detector_timer)
    %{state | detector_timer: nil, detector_token: nil}
  end

  defp select_protocol(protocol, replay, socket, state) do
    limit =
      if protocol == :http2,
        do: state.spec.handler_options.http_limits.max_buffer_bytes,
        else: state.spec.limits.max_bytes

    if IO.iodata_length(replay) > limit do
      {:close, state}
    else
      initialized =
        if protocol == :http2, do: start_http2(socket, state), else: start_http1(socket, state)

      case initialized do
        {:continue, selected} -> handle_data(IO.iodata_to_binary(replay), socket, selected)
        result -> result
      end
    end
  end

  defp process(socket, %{phase: :idle} = state) do
    first = state.first_input || Lifecycle.now()

    deadline =
      if state.limits.request_timeout == :infinity,
        do: :infinity,
        else: first + state.limits.request_timeout

    header_deadline = first + state.limits.header_timeout
    state = %{state | first_input: nil}
    token = make_ref()

    if Lifecycle.remaining(header_deadline) == 0 do
      {:close, state}
    else
      case Admission.begin_request(state.gate, state.lease, byte_size(state.buffer), deadline) do
        :ok ->
          timeout = min(Lifecycle.remaining(header_deadline), Lifecycle.remaining(deadline))
          timer = Process.send_after(self(), {:gaoxy_http_header_timeout, token}, timeout)

          process(socket, %{
            state
            | phase: :header,
              deadline: deadline,
              header_timer: timer,
              header_token: token
          })

        {:error, _} ->
          overload(socket, %{state | deadline: deadline})
      end
    end
  end

  defp process(socket, state) do
    case update(state, byte_size(state.buffer), state.deadline) do
      :ok -> parse(socket, state)
      {:error, _} -> {:close, state}
    end
  end

  defp parse(socket, state) do
    case Parser.parse_head(state.buffer, state.limits) do
      :more ->
        if byte_size(state.buffer) <= state.limits.max_buffer_bytes and
             Lifecycle.remaining(state.deadline) > 0 do
          {:continue, state}
        else
          {:close, state}
        end

      {:error, code, _reason} ->
        _ = write_error(socket, state, code)
        {:close, state}

      {:ok, request, rest} ->
        Process.cancel_timer(state.header_timer)
        scheme = if Hell.Socket.secure?(socket), do: :https, else: :http

        {endpoint, endpoint_options} = state.spec.handler_options.endpoint

        allowed_absolute =
          request.target_form == :absolute and
            if(function_exported?(endpoint, :absolute_form_scheme?, 2),
              do: endpoint.absolute_form_scheme?(request.scheme, endpoint_options),
              else:
                function_exported?(endpoint, :absolute_form_scheme?, 1) and
                  endpoint.absolute_form_scheme?(request.scheme)
            )

        if request.scheme != nil and request.scheme != scheme and not allowed_absolute do
          _ = write_error(socket, state, 400)
          {:close, state}
        else
          case Exchange.new(
                 request,
                 socket,
                 state.gate,
                 state.lease,
                 state.deadline,
                 Map.put(
                   state.limits,
                   :max_write_chunk,
                   min(state.spec.limits.max_output, state.limits.max_read_chunk)
                 ),
                 rest
               ) do
            %Exchange{} = exchange ->
              exchange = %{
                exchange
                | service: Map.get(state, :service),
                  instance: Map.get(state, :instance)
              }

              exchange =
                if is_pid(Map.get(state, :instance)),
                  do: %{
                    exchange
                    | protocol_bytes:
                        4 * state.limits.max_buffer_bytes +
                          exchange.limits.max_write_chunk
                  },
                  else: exchange

              exchange =
                if exchange.protocol_bytes > 0 do
                  Exchange.fund(
                    exchange,
                    Exchange.retained_bytes(exchange),
                    exchange.protocol_bytes,
                    %{connection: state.connection_member, request: state.lease}
                  )
                else
                  exchange
                end

              accounting = request_accounting(state, exchange)

              state = %{state | buffer: ""}

              case update(state, accounting, state.deadline) do
                :ok ->
                  respond(socket, state, exchange)

                _ ->
                  _ = write_error(socket, state, 503)
                  {:close, state}
              end

            {:error, reason} when reason in [:closed, :einval, :enotconn] ->
              {:close, state}

            {:error, reason} ->
              {:error, reason, state}
          end
        end
    end
  end

  defp respond(socket, state, exchange) do
    {module, options} = state.spec.handler_options.endpoint

    result = call_endpoint(module, options, exchange)
    committed = flush_sent()

    exchange =
      case result do
        {:ok, exchange} -> exchange
        {:error, _, exchange} -> exchange
      end

    exchange =
      if committed and exchange.response == :unset,
        do: %{exchange | response: :sent, close: true},
        else: exchange

    exchange =
      if match?({:error, _, _}, result) and exchange.response != :unset,
        do: %{exchange | close: true},
        else: finish_response(exchange)

    cond do
      match?({:websocket, _, _, _, _}, exchange.response) ->
        case release_request_credit(state, exchange) do
          {:ok, exchange} -> websocket_result(WebSocket.start(exchange, state.spec.limits), state)
          {:error, _} -> {:close, state}
        end

      exchange.response == :unset ->
        _ = write_error(socket, state, 500)
        {:close, state}

      exchange.close or exchange.body.phase != :done ->
        {:close, state}

      true ->
        case Admission.end_request(
               state.gate,
               state.lease,
               idle_accounting(state, byte_size(exchange.buffer)),
               Lifecycle.deadline(50)
             ) do
          :ok ->
            next = %{
              state
              | buffer: exchange.buffer,
                phase: :idle,
                deadline: nil,
                header_timer: nil,
                header_token: nil
            }

            if next.buffer == "", do: {:continue, next}, else: process(socket, next)

          {:error, _} ->
            {:close, state}
        end
    end
  end

  defp call_endpoint(module, options, exchange) do
    module.call(exchange, options)
  catch
    kind, reason -> {:error, {kind, reason}, exchange}
  end

  defp request_accounting(_state, exchange) do
    bytes = Exchange.retained_bytes(exchange)

    if exchange.protocol_bytes > 0 do
      Exchange.accounting(exchange, bytes)
    else
      bytes
    end
  end

  defp idle_accounting(state, bytes) do
    if is_pid(Map.get(state, :instance)),
      do: %{
        retained_bytes: bytes,
        temporary_bytes: 0,
        transport_bytes: bytes,
        websocket_bytes: 0,
        memberships: %{connection: state.connection_member},
        pending_processes: 0
      },
      else: bytes
  end

  defp release_request_credit(_state, %{protocol_bytes: 0} = exchange), do: {:ok, exchange}

  defp release_request_credit(state, exchange) do
    exchange = %{exchange | protocol_bytes: 0, funding: nil}
    accounting = idle_accounting(state, Exchange.retained_bytes(exchange))

    accounting = %{
      accounting
      | memberships: %{
          connection: state.connection_member,
          request: state.lease
        }
    }

    case update(state, accounting, state.deadline) do
      :ok ->
        {:ok, Exchange.fund(exchange, accounting.retained_bytes, 0, accounting.memberships)}

      error ->
        error
    end
  end

  defp flush_sent do
    receive do
      {:plug_conn, :sent} ->
        flush_sent()
        true
    after
      0 -> false
    end
  end

  defp finish_response(%{response: response} = exchange)
       when response in [:unset, :tunnel] or
              (is_tuple(response) and elem(response, 0) == :websocket),
       do: exchange

  defp finish_response(exchange) do
    case Gaoxy.HTTP.HTTP1.Response.finish(exchange) do
      {:ok, exchange} -> exchange
      {:error, _} -> %{exchange | close: true}
    end
  end

  defp write_error(socket, state, code) do
    reason = Plug.Conn.Status.reason_phrase(code)
    bytes = "HTTP/1.1 #{code} #{reason}\r\ncontent-length: 0\r\nconnection: close\r\n\r\n"

    Exchange.send_bytes(
      %Exchange{
        socket: socket,
        gate: state.gate,
        lease: state.lease,
        buffer: state.buffer,
        limits: state.limits,
        deadline: state.deadline || Lifecycle.deadline(50)
      },
      bytes
    )
  end

  defp overload(socket, state) do
    # A complete first request head permits a bounded HTTP overload response.
    # Partial or ambiguous input closes without adding another framing promise.
    if match?({:ok, _, _}, Parser.parse_head(state.buffer, state.limits)),
      do: write_error(socket, state, 503)

    {:close, state}
  end

  @impl true
  def handle_call(message, from, {socket, %{phase: :http2} = state}),
    do: Gaoxy.HTTP.HTTP2.Connection.call(message, from, socket, state)

  @impl true
  def handle_info(
        {:gaoxy_http_detect_timeout, token},
        {socket, %{phase: :detecting, detector_token: token} = state}
      )
      when is_reference(token) do
    {:stop, :normal, {socket, cancel_detection(state)}}
  end

  # A canceled timer may already be queued. Consume these before H2 delegation.
  def handle_info({:gaoxy_http_detect_timeout, _}, {socket, state}),
    do: {:noreply, {socket, state}}

  def handle_info(message, {socket, %{phase: :http2} = state}),
    do: Gaoxy.HTTP.HTTP2.Connection.info(message, socket, state)

  def handle_info(
        {:gaoxy_drain, gate, lease, deadline},
        {socket, %{phase: :websocket, gate: gate, lease: lease} = state}
      ) do
    websocket_info_result(WebSocket.drain(state.websocket, deadline), socket, state)
  end

  def handle_info(
        {:gaoxy_http_header_timeout, token},
        {socket, %{phase: :header, header_token: token} = state}
      ) do
    {:stop, :normal, {socket, state}}
  end

  def handle_info({:gaoxy_http_header_timeout, _}, {socket, state}) do
    {:noreply, {socket, state}}
  end

  def handle_info(
        {:gaoxy_drain, gate, lease, _deadline},
        {socket, %{phase: :detecting, gate: gate, lease: lease} = state}
      ) do
    {:stop, :normal, {socket, %{cancel_detection(state) | closing: true}}}
  end

  def handle_info(
        {:gaoxy_drain, gate, lease, _deadline},
        {socket, %{gate: gate, lease: lease} = state}
      ) do
    {:stop, :normal, {socket, %{state | closing: true}}}
  end

  def handle_info(message, {socket, %{phase: :websocket} = state}) do
    websocket_info_result(WebSocket.info(message, state.websocket), socket, state)
  end

  def handle_info(_, {socket, state}), do: {:noreply, {socket, state}}

  defp websocket_result({action, websocket}, state) do
    state = %{state | phase: :websocket, websocket: websocket, buffer: "", header_token: nil}

    case action do
      :continue -> {:continue, state, {:persistent, websocket.limits.timeout}}
      :close -> {:close, state}
    end
  end

  defp websocket_info_result({action, websocket}, socket, state) do
    state = %{state | websocket: websocket}

    case action do
      :continue -> {:noreply, {socket, state}}
      :close -> {:stop, {:shutdown, :local_closed}, {socket, state}}
    end
  end

  @impl true
  def handle_close(_, %{phase: :detecting} = state) do
    _ = cancel_detection(state)
    :ok
  end

  def handle_close(_, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)
  def handle_close(_, %{phase: :websocket, websocket: ws}), do: WebSocket.terminate(ws, :remote)
  def handle_close(_, _), do: :ok

  @impl true
  def handle_error(_, _, %{phase: :detecting} = state) do
    _ = cancel_detection(state)
    :ok
  end

  def handle_error(_, _, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)

  def handle_error(reason, _, %{phase: :websocket, websocket: ws}),
    do: WebSocket.terminate(ws, {:error, reason})

  def handle_error(_, _, _), do: :ok

  @impl true
  def handle_shutdown(_, %{phase: :detecting} = state) do
    _ = cancel_detection(state)
    :ok
  end

  def handle_shutdown(_, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)

  def handle_shutdown(_, %{phase: :websocket, websocket: ws}),
    do: WebSocket.terminate(ws, :shutdown)

  def handle_shutdown(_, _), do: :ok

  @impl true
  def handle_timeout(_, %{phase: :detecting} = state) do
    _ = cancel_detection(state)
    :ok
  end

  def handle_timeout(_, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)
  def handle_timeout(_, %{phase: :websocket, websocket: ws}), do: WebSocket.timeout(ws)
  def handle_timeout(_, _), do: :ok
end
