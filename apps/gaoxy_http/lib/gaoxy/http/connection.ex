defmodule Gaoxy.HTTP.Connection do
  @moduledoc false
  use ThousandIsland.Handler
  @behaviour Gaoxy.NativeStreamHandler
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Options, WebSocket}
  alias Gaoxy.HTTP.HTTP1.Parser

  @impl Gaoxy.NativeStreamHandler
  def validate_options(options), do: Options.normalize(options)

  @impl true
  def handle_connection(socket, %{spec: spec} = context) do
    case protocol(socket, spec.handler_options) do
      :http2 ->
        {:ok, peer} = ThousandIsland.Socket.peername(socket)
        {:ok, local} = ThousandIsland.Socket.sockname(socket)

        ssl =
          case ThousandIsland.Socket.connection_information(socket) do
            {:ok, value} -> value
            _ -> nil
          end

        cert =
          case ThousandIsland.Socket.peercert(socket) do
            {:ok, value} -> value
            _ -> nil
          end

        Gaoxy.HTTP.HTTP2.Connection.start(
          socket,
          Map.merge(context, %{
            owner: self(),
            peer: peer,
            local: local,
            secure: ThousandIsland.Socket.secure?(socket),
            ssl: ssl,
            peer_cert: cert
          })
        )

      :http1 ->
        start_http1(socket, context)

      {:error, reason} ->
        {:error, reason, context}
    end
  end

  defp protocol(socket, options) do
    if ThousandIsland.Socket.secure?(socket) do
      case ThousandIsland.Socket.negotiated_protocol(socket) do
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
      if options.h2c == :prior_knowledge and options.protocols == [:http2],
        do: :http2,
        else: :http1
    end
  end

  defp start_http1(socket, %{spec: spec, gate: gate} = context) do
    limits = spec.handler_options.http_limits

    with :ok <-
           ThousandIsland.Socket.setopts(socket,
             recbuf: limits.max_read_chunk,
             buffer: limits.max_read_chunk,
             send_timeout: limits.write_timeout,
             send_timeout_close: true
           ),
         {:ok, lease} <- Admission.acquire(gate, 0, drain_notify: true) do
      {:continue,
       Map.merge(context, %{
         lease: lease,
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
  def handle_data(bytes, socket, %{phase: :http2} = state),
    do: Gaoxy.HTTP.HTTP2.Connection.data(bytes, socket, state)

  def handle_data(bytes, socket, %{phase: :websocket} = state) do
    websocket_result(WebSocket.data(bytes, socket, state.websocket), state)
  end

  def handle_data(bytes, socket, state) do
    buffer = state.buffer <> bytes

    if byte_size(buffer) > state.spec.limits.max_bytes do
      {:close, state}
    else
      state = %{state | buffer: buffer}

      process(socket, state)
    end
  end

  defp process(socket, %{phase: :idle} = state) do
    deadline = Lifecycle.deadline(state.limits.request_timeout)
    token = make_ref()

    case Admission.begin_request(state.gate, state.lease, byte_size(state.buffer), deadline) do
      :ok ->
        timeout = min(state.limits.header_timeout, Lifecycle.remaining(deadline))
        timer = Process.send_after(self(), {:gaoxy_http_header_timeout, token}, timeout)

        process(socket, %{
          state
          | phase: :header,
            deadline: deadline,
            header_timer: timer,
            header_token: token
        })

      {:error, _} ->
        {:close, state}
    end
  end

  defp process(socket, state) do
    case Admission.update(state.gate, state.lease, byte_size(state.buffer)) do
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
        scheme = if ThousandIsland.Socket.secure?(socket), do: :https, else: :http

        {endpoint, _options} = state.spec.handler_options.endpoint

        allowed_absolute =
          request.target_form == :absolute and
            function_exported?(endpoint, :absolute_form_scheme?, 1) and
            endpoint.absolute_form_scheme?(request.scheme)

        if request.scheme != nil and request.scheme != scheme and not allowed_absolute do
          _ = write_error(socket, state, 400)
          {:close, state}
        else
          exchange = %{
            Exchange.new(
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
            )
            | service: Map.get(state, :service),
              instance: Map.get(state, :instance)
          }

          state = %{state | buffer: ""}

          case Admission.update(state.gate, state.lease, Exchange.retained_bytes(exchange)) do
            :ok -> respond(socket, state, exchange)
            _ -> {:close, state}
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
        websocket_result(WebSocket.start(exchange, state.spec.limits), state)

      exchange.response == :unset ->
        _ = write_error(socket, state, 500)
        {:close, state}

      exchange.close or exchange.body.phase != :done ->
        {:close, state}

      true ->
        :ok = Admission.retain(state.gate, state.lease, byte_size(exchange.buffer))

        next = %{
          state
          | buffer: exchange.buffer,
            phase: :idle,
            deadline: nil,
            header_timer: nil,
            header_token: nil
        }

        if next.buffer == "", do: {:continue, next}, else: process(socket, next)
    end
  end

  defp call_endpoint(module, options, exchange) do
    module.call(exchange, options)
  catch
    kind, reason -> {:error, {kind, reason}, exchange}
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
      %Exchange{socket: socket, gate: state.gate, lease: state.lease, buffer: state.buffer},
      bytes
    )
  end

  @impl true
  def handle_call(message, from, {socket, %{phase: :http2} = state}),
    do: Gaoxy.HTTP.HTTP2.Connection.call(message, from, socket, state)

  @impl true
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
  def handle_close(_, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)
  def handle_close(_, %{phase: :websocket, websocket: ws}), do: WebSocket.terminate(ws, :remote)
  def handle_close(_, _), do: :ok

  @impl true
  def handle_error(_, _, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)

  def handle_error(reason, _, %{phase: :websocket, websocket: ws}),
    do: WebSocket.terminate(ws, {:error, reason})

  def handle_error(_, _, _), do: :ok

  @impl true
  def handle_shutdown(_, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)

  def handle_shutdown(_, %{phase: :websocket, websocket: ws}),
    do: WebSocket.terminate(ws, :shutdown)

  def handle_shutdown(_, _), do: :ok

  @impl true
  def handle_timeout(_, %{phase: :http2} = state), do: Gaoxy.HTTP.HTTP2.Connection.close(state)
  def handle_timeout(_, %{phase: :websocket, websocket: ws}), do: WebSocket.timeout(ws)
  def handle_timeout(_, _), do: :ok
end
