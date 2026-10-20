defmodule Gaoxy.HTTP.HTTP2.Connection do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, HTTP2.Frame, HTTP2.Headers, HTTP2.Limits, HTTP2.Settings}
  alias Gaoxy.HTTP.RendererBounds
  alias Gaoxy.HTTP.HTTP2.{Stream, Writer, Transport, WorkerAccounting}
  alias Hell.Socket
  @preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
  @max_window 2_147_483_647

  def start(socket, context) do
    options = context.spec.handler_options
    h2 = options.h2_limits
    reserves = Limits.reservation(options.http_limits, h2)

    with :ok <- Limits.validate_budget(options.http_limits, h2, context.spec.limits),
         :ok <- Limits.validate_host(if(Socket.secure?(socket), do: :tls, else: :tcp)),
         :ok <- tls_policy(socket),
         :ok <-
           Socket.setopts(socket,
             recbuf: Limits.receive_buffer(),
             buffer: Limits.receive_buffer()
           ),
         {:ok, lease} <- Admission.acquire(context.gate, reserves.connection, drain_notify: true),
         {:ok, writer} <-
           Task.Supervisor.start_child(Gaoxy.HTTP.Tasks, fn ->
             Writer.run(
               context.owner,
               socket,
               context.gate,
               reserves.writer,
               options.http_limits.write_timeout
             )
           end) do
      token = make_ref()
      timer = Process.send_after(self(), {:h2_start_timeout, token}, h2.frame_timeout)

      {:continue,
       Map.merge(context, %{
         phase: :http2,
         lease: lease,
         limits:
           Map.merge(options.http_limits, %{
             extended_connect: options.extended_connect,
             websocket_limits: Map.take(context.spec.limits, [:max_bytes, :max_state])
           }),
         h2: h2,
         reserves: reserves,
         decode_reservation: 0,
         buffer: "",
         preface: false,
         first: true,
         decoder: HPAX.new(h2.table_size),
         settings: Settings.defaults(),
         streams: %{},
         highest: 0,
         accepted: 0,
         starting: nil,
         writer: writer,
         writer_monitor: Process.monitor(writer),
         writer_ready: false,
         inflight: nil,
         inflight_write: nil,
         inflight_started: false,
         outgoing_block: nil,
         outgoing_started: false,
         output: :queue.new(),
         send_window: 65_535,
         recv_window: 65_535,
         pending_credit: 0,
         continuation: nil,
         closing: false,
         draining: false,
         close_after_write: false,
         start_token: token,
         start_timer: timer,
         settings_ack: false,
         rate_start: Lifecycle.now(),
         rate: 0,
         last_sent: 0,
         partial_timer: nil,
         partial_token: nil
       })}
    else
      {:error, reason} -> {:error, reason, context}
    end
  end

  defp tls_policy(socket) do
    if Socket.secure?(socket) do
      case Socket.connection_information(socket) do
        {:ok, info} ->
          case {info[:protocol], info[:selected_cipher_suite]} do
            {:"tlsv1.3", _} ->
              :ok

            {:"tlsv1.2", %{key_exchange: exchange, cipher: cipher}}
            when exchange in [:ecdhe_rsa, :ecdhe_ecdsa, :dhe_rsa] and
                   cipher in [:aes_128_gcm, :aes_256_gcm, :chacha20_poly1305] ->
              :ok

            _ ->
              {:error, :inadequate_security}
          end

        _ ->
          {:error, :inadequate_security}
      end
    else
      :ok
    end
  end

  def data(bytes, _socket, state) do
    if byte_size(state.buffer) + byte_size(bytes) > state.limits.max_buffer_bytes do
      {:close, state}
    else
      state = %{state | buffer: state.buffer <> bytes}
      state = parse(state, state.h2.control_turn)
      {:continue, schedule(partial_timer(state))}
    end
  end

  defp parse(%{closing: true} = state, _), do: state

  defp parse(state, 0) do
    send(self(), :h2_parse)
    state
  end

  defp parse(%{preface: false} = state, left) do
    size = min(byte_size(state.buffer), byte_size(@preface))

    if binary_part(state.buffer, 0, size) == binary_part(@preface, 0, size) do
      if size == byte_size(@preface) do
        <<_::binary-size(size), rest::binary>> = state.buffer

        initial =
          <<1::16, state.h2.table_size::32, 3::16, state.h2.max_streams::32, 4::16,
            state.h2.receive_window::32, 5::16, state.h2.max_frame::32, 6::16,
            state.limits.max_header_bytes::32>>

        initial =
          if state.limits.extended_connect,
            do: initial <> <<8::16, 1::32>>,
            else: initial

        state =
          enqueue(%{state | preface: true, buffer: rest}, Frame.encode(4, 0, 0, initial), nil)

        parse(state, left)
      else
        state
      end
    else
      failure(state, :protocol_error)
    end
  end

  defp parse(state, left) do
    case Frame.decode(state.buffer, state.h2.max_frame) do
      :more ->
        state

      {:error, reason} ->
        failure(state, reason)

      {:ok, frame, rest} ->
        state = %{state | buffer: rest}
        state = rate(state, frame)

        state =
          cond do
            state.closing ->
              state

            state.first and (frame.type != 4 or Frame.flag?(frame.flags, 1) or frame.id != 0) ->
              failure(state, :protocol_error)

            state.continuation != nil and (frame.type != 9 or frame.id != state.continuation.id) ->
              failure(state, :protocol_error)

            true ->
              receive_frame(%{state | first: false}, frame)
          end

        parse(state, left - 1)
    end
  end

  defp rate(state, %{type: type}) when type in [2, 3, 4, 6, 7, 8] do
    state =
      if Lifecycle.now() - state.rate_start >= 1_000,
        do: %{state | rate: 0, rate_start: Lifecycle.now()},
        else: state

    state = %{state | rate: state.rate + 1}
    if state.rate > state.h2.control_rate, do: failure(state, :enhance_your_calm), else: state
  end

  defp rate(state, _), do: state

  defp receive_frame(state, %{type: 4, id: 0, flags: flags, payload: payload}) do
    cond do
      Frame.flag?(flags, 1) and payload != "" ->
        failure(state, :frame_size_error)

      Frame.flag?(flags, 1) and state.settings_ack ->
        state

      Frame.flag?(flags, 1) ->
        Process.cancel_timer(state.start_timer)
        delta = state.h2.receive_window - 65_535

        streams =
          Map.new(state.streams, fn {id, stream} ->
            {id, %{stream | recv_window: stream.recv_window + delta}}
          end)

        %{state | settings_ack: true, streams: streams}

      true ->
        case Settings.apply(state.settings, payload) do
          {:ok, settings, delta} ->
            if Enum.any?(state.streams, fn {_, stream} ->
                 stream.send_window + delta > @max_window
               end) do
              failure(state, :flow_control_error)
            else
              streams =
                Map.new(state.streams, fn {id, stream} ->
                  {id, %{stream | send_window: stream.send_window + delta}}
                end)

              enqueue(
                %{
                  state
                  | settings: settings,
                    streams: streams
                },
                Frame.encode(4, 1, 0, ""),
                nil
              )
            end

          {:error, reason} ->
            failure(state, reason)
        end
    end
  end

  defp receive_frame(state, %{type: 4}), do: failure(state, :protocol_error)

  defp receive_frame(state, %{type: 6, id: 0, flags: flags, payload: payload})
       when byte_size(payload) == 8 do
    if Frame.flag?(flags, 1), do: state, else: enqueue(state, Frame.encode(6, 1, 0, payload), nil)
  end

  defp receive_frame(state, %{type: 6, id: 0}), do: failure(state, :frame_size_error)
  defp receive_frame(state, %{type: 6}), do: failure(state, :protocol_error)

  defp receive_frame(state, %{type: 8, id: id, payload: <<_::1, increment::31>>}) do
    cond do
      id > state.highest ->
        failure(state, :protocol_error)

      increment == 0 and id == 0 ->
        failure(state, :protocol_error)

      increment == 0 ->
        reset(state, id, :protocol_error)

      id == 0 and state.send_window + increment > @max_window ->
        failure(state, :flow_control_error)

      id == 0 ->
        %{state | send_window: state.send_window + increment}

      Map.has_key?(state.streams, id) ->
        stream = state.streams[id]

        if stream.send_window + increment > @max_window,
          do: reset(state, id, :flow_control_error),
          else: put_in(state.streams[id].send_window, stream.send_window + increment)

      true ->
        state
    end
  end

  defp receive_frame(state, %{type: 8}), do: failure(state, :frame_size_error)

  defp receive_frame(state, %{type: 3, id: id, payload: <<_::32>>}) when id > 0 do
    if id > state.highest, do: failure(state, :protocol_error), else: discard(state, id)
  end

  defp receive_frame(state, %{type: 3, id: 0}), do: failure(state, :protocol_error)
  defp receive_frame(state, %{type: 3}), do: failure(state, :frame_size_error)

  defp receive_frame(state, %{type: 2, id: id, payload: <<_::1, dependency::31, _weight>>})
       when id > 0 do
    if dependency == id, do: reset(state, id, :protocol_error), else: state
  end

  defp receive_frame(state, %{type: 2, id: 0}), do: failure(state, :protocol_error)
  defp receive_frame(state, %{type: 2, id: id}), do: reset(state, id, :frame_size_error)

  defp receive_frame(state, %{type: 7, id: 0, payload: <<_::1, _last::31, _code::32, _::binary>>}),
    do: %{state | draining: true}

  defp receive_frame(state, %{type: 7, id: 0}), do: failure(state, :frame_size_error)
  defp receive_frame(state, %{type: 7}), do: failure(state, :protocol_error)
  defp receive_frame(state, %{type: 5}), do: failure(state, :protocol_error)

  defp receive_frame(state, %{type: 1, id: id} = frame) when id > 0 do
    cond do
      rem(id, 2) == 0 ->
        failure(state, :protocol_error)

      true ->
        with {:ok, payload} <- unpad(frame),
             {:ok, block, stream_error} <- priority(payload, frame.flags, id) do
          ended = Frame.flag?(frame.flags, 1)

          cond do
            byte_size(block) > state.h2.max_header_block ->
              failure(state, :enhance_your_calm)

            Frame.flag?(frame.flags, 4) ->
              decode_headers(state, id, block, ended, stream_error)

            true ->
              %{state | continuation: %{id: id, block: block, ended: ended, error: stream_error}}
          end
        else
          {:error, reason} -> failure(state, reason)
        end
    end
  end

  defp receive_frame(state, %{type: 1}), do: failure(state, :protocol_error)

  defp receive_frame(%{continuation: nil} = state, %{type: 9}),
    do: failure(state, :protocol_error)

  defp receive_frame(state, %{type: 9, payload: payload, flags: flags}) do
    cont = state.continuation

    if byte_size(cont.block) + byte_size(payload) > state.h2.max_header_block do
      failure(state, :enhance_your_calm)
    else
      block = cont.block <> payload

      if Frame.flag?(flags, 4),
        do: decode_headers(%{state | continuation: nil}, cont.id, block, cont.ended, cont.error),
        else: %{state | continuation: %{cont | block: block}}
    end
  end

  defp receive_frame(state, %{type: 0, id: 0}), do: failure(state, :protocol_error)

  defp receive_frame(state, %{type: 0, id: id} = frame) do
    size = byte_size(frame.payload)

    cond do
      size > state.recv_window ->
        failure(state, :flow_control_error)

      id > state.highest ->
        failure(state, :protocol_error)

      not Map.has_key?(state.streams, id) ->
        credit_connection(
          reset(%{state | recv_window: state.recv_window - size}, id, :stream_closed),
          size
        )

      state.streams[id].eof ->
        credit_connection(
          reset(%{state | recv_window: state.recv_window - size}, id, :stream_closed),
          size
        )

      size > 0 and size > state.streams[id].recv_window ->
        credit_connection(
          reset(%{state | recv_window: state.recv_window - size}, id, :flow_control_error),
          size
        )

      true ->
        case unpad(frame) do
          {:ok, bytes} ->
            stream = state.streams[id]
            # A tunnel has no cumulative HTTP body length. Its receive windows
            # still bound all buffered and delivered bytes until acknowledged.
            received =
              if stream.request.body == :tunnel, do: 0, else: stream.received + byte_size(bytes)

            ended = Frame.flag?(frame.flags, 1)
            state = %{state | recv_window: state.recv_window - size}

            cond do
              received > state.limits.max_body_bytes ->
                credit_connection(reset(state, id, :cancel), size)

              match?({:length, _}, stream.request.body) and
                  (received > elem(stream.request.body, 1) or
                     (ended and received != elem(stream.request.body, 1))) ->
                credit_connection(reset(state, id, :protocol_error), size)

              true ->
                stream = %{
                  stream
                  | recv_window: stream.recv_window - size,
                    received: received,
                    input: stream.input <> bytes,
                    queued_wire: stream.queued_wire + size,
                    eof: ended
                }

                deliver(put_in(state.streams[id], stream), id)
            end

          {:error, reason} ->
            failure(state, reason)
        end
    end
  end

  defp receive_frame(state, _), do: state

  defp unpad(%{payload: <<padding, rest::binary>>, flags: flags})
       when Bitwise.band(flags, 8) != 0 do
    if padding <= byte_size(rest),
      do: {:ok, binary_part(rest, 0, byte_size(rest) - padding)},
      else: {:error, :protocol_error}
  end

  defp unpad(%{payload: "", flags: flags}) when Bitwise.band(flags, 8) != 0,
    do: {:error, :protocol_error}

  defp unpad(%{payload: bytes}), do: {:ok, bytes}

  defp priority(<<_::1, dep::31, _weight, rest::binary>>, flags, id)
       when Bitwise.band(flags, 32) != 0,
       do: {:ok, rest, if(dep == id, do: :protocol_error, else: nil)}

  defp priority(_, flags, _) when Bitwise.band(flags, 32) != 0, do: {:error, :frame_size_error}
  defp priority(bytes, _, _), do: {:ok, bytes, nil}

  defp decode_headers(state, id, block, ended, stream_error) do
    if byte_size(block) > state.h2.max_header_block do
      failure(state, :enhance_your_calm)
    else
      case reserve_decode(state, byte_size(block)) do
        {:ok, state} -> decode_reserved_headers(state, id, block, ended, stream_error)
        {:error, _} -> failure(state, :enhance_your_calm)
      end
    end
  end

  defp reserve_decode(state, block_bytes) do
    bytes = Limits.decode_reservation(state.h2, block_bytes)

    if bytes <= state.decode_reservation do
      {:ok, state}
    else
      # HPAX materializes the entire field list before header validation. Grow
      # before decoding, and retain the high-water charge through connection exit.
      case Admission.update(state.gate, state.lease, state.reserves.connection + bytes) do
        :ok -> {:ok, %{state | decode_reservation: bytes}}
        error -> error
      end
    end
  end

  defp decode_reserved_headers(state, id, block, ended, stream_error) do
    case HPAX.decode(block, state.decoder) do
      {:ok, fields, decoder} ->
        state = %{state | decoder: decoder}

        cond do
          stream_error != nil ->
            reset(%{state | highest: max(state.highest, id)}, id, stream_error)

          Map.has_key?(state.streams, id) ->
            trailers(state, id, fields, ended)

          id <= state.highest ->
            reset(state, id, :stream_closed)

          true ->
            admit(state, id, fields, ended)
        end

      {:error, _} ->
        failure(state, :compression_error)
    end
  end

  defp trailers(state, id, fields, ended) do
    stream = state.streams[id]

    valid_length =
      not match?({:length, _}, stream.request.body) or
        stream.received == elem(stream.request.body, 1)

    if stream.request.body != :tunnel and ended and not stream.eof and valid_length and
         Headers.trailers(fields, state.limits) == :ok do
      deliver(put_in(state.streams[id], %{stream | eof: true, trailers: fields}), id)
    else
      reset(state, id, :protocol_error)
    end
  end

  defp admit(state, id, fields, ended) do
    previous = state.highest
    state = %{state | highest: max(id, state.highest)}

    cond do
      id <= previous ->
        failure(state, :protocol_error)

      state.draining or map_size(state.streams) >= state.h2.max_streams ->
        reset(state, id, :refused_stream)

      true ->
        case Headers.request(fields, state.secure, state.limits, state.limits.extended_connect) do
          {:ok, request} ->
            request =
              if ended and request.body == :chunked,
                do: %{request | body: :none},
                else: request

            if ended and match?({:length, length} when length != 0, request.body) do
              reset(state, id, :protocol_error)
            else
              stream = %{
                id: id,
                token: make_ref(),
                worker: nil,
                monitor: nil,
                lease: nil,
                startup: nil,
                request: request,
                deadline: Lifecycle.deadline(state.limits.request_timeout),
                input: "",
                queued_wire: 0,
                delivered_wire: 0,
                received: 0,
                eof: ended,
                initial_eof: ended,
                trailers: [],
                recv_window: if(state.settings_ack, do: state.h2.receive_window, else: 65_535),
                pending_credit: 0,
                send_window: state.settings.initial_window,
                read: nil,
                poll: nil,
                write: nil,
                write_failed: false,
                websocket: false,
                demand: nil,
                delivery_ref: nil,
                last_demand: nil,
                renderer_blocks: 0,
                renderer_projection_bytes: 0,
                committed: false,
                local_closed: false
              }

              start_next(put_in(state.streams[id], stream))
            end

          {:error, _, _} ->
            reset(state, id, :protocol_error)
        end
    end
  end

  defp start_next(%{starting: nil} = state) do
    case Enum.find(Enum.sort(state.streams), fn {_, stream} -> stream.worker == nil end) do
      nil ->
        state

      {id, stream} ->
        case WorkerAccounting.reservation(state, stream) do
          {:ok, {:native_http2_worker_v1, protocol_bytes, bytes}} ->
            request =
              Admission.spawn_request(
                state.gate,
                state.lease,
                stream.token,
                bytes,
                stream.deadline,
                {Stream, :run,
                 [self(), id, stream.token, state.gate, protocol_bytes, stream.deadline]}
              )

            timer =
              Process.send_after(
                self(),
                {:h2_worker_start_timeout, id, stream.token},
                Lifecycle.remaining(stream.deadline)
              )

            startup = %{
              request: request,
              timer: timer,
              token: stream.token,
              parent_lease: state.lease,
              protocol_bytes: protocol_bytes,
              bytes: bytes,
              deadline: stream.deadline
            }

            put_in(%{state | starting: id}.streams[id], %{stream | startup: startup})

          {:error, :worker_capacity} ->
            reset(state, id, :refused_stream)
        end
    end
  end

  defp start_next(state), do: state

  def call({:h2_operation, id, token, operation}, {pid, _} = from, socket, state) do
    case state.streams[id] do
      %{token: ^token, worker: ^pid} = stream ->
        state = operation(state, stream, operation, from)
        {:noreply, {socket, schedule(state)}}

      _ ->
        {:reply, {:error, :closed}, {socket, state}}
    end
  end

  defp operation(state, stream, :ssl_data, from) do
    if Lifecycle.remaining(stream.deadline) == 0 do
      reply_error(state, from, :timeout)
    else
      GenServer.reply(from, {:ok, state.ssl})
      state
    end
  end

  defp operation(state, _stream, {:poll, 0}, from) do
    GenServer.reply(from, :ok)
    state
  end

  defp operation(state, stream, {:poll, wait}, from) when is_integer(wait) and wait > 0 do
    if stream.poll == nil do
      token = make_ref()
      timer = Process.send_after(self(), {:h2_poll_timeout, stream.id, token}, wait)
      put_in(state.streams[stream.id].poll, %{from: from, token: token, timer: timer})
    else
      reply_error(state, from, :pending_poll)
    end
  end

  defp operation(state, stream, {:abort, _}, from) do
    GenServer.reply(from, :ok)
    reset(state, stream.id, :cancel)
  end

  defp operation(state, stream, {:websocket_open, headers, lifetime, write_deadline}, from)
       when is_integer(lifetime) and is_integer(write_deadline) do
    valid =
      state.limits.extended_connect and not stream.websocket and
        not stream.committed and not stream.eof and stream.read == nil and stream.poll == nil and
        Lifecycle.remaining(stream.deadline) > 0 and Lifecycle.remaining(lifetime) > 0 and
        Gaoxy.HTTP.WebSocket.ExtendedHandshake.headers(stream.request, headers) == {:ok, headers}

    if valid do
      stream = %{stream | websocket: true, deadline: lifetime}
      state = put_in(state.streams[stream.id], stream)
      operation(state, stream, {:write, write_deadline, {:head, 200, headers, false}}, from)
    else
      reply_error(state, from, :invalid_websocket_upgrade)
    end
  end

  defp operation(state, %{websocket: true} = stream, {:websocket_demand, credit, ref}, from)
       when is_integer(credit) and credit in 0..16_384 and is_reference(ref) do
    cond do
      Lifecycle.remaining(stream.deadline) == 0 ->
        reply_error(state, from, :timeout)

      stream.demand != nil or stream.read != nil ->
        reply_error(state, from, :pending_read)

      credit == 0 and stream.delivery_ref != ref ->
        reply_error(state, from, :stale_demand)

      credit > 0 and stream.last_demand == ref ->
        reply_error(state, from, :stale_demand)

      true ->
        state = return_credit(state, stream.id)

        stream = %{
          state.streams[stream.id]
          | delivery_ref: nil,
            demand: if(credit > 0, do: %{credit: credit, ref: ref}, else: nil),
            last_demand: ref
        }

        GenServer.reply(from, :ok)
        deliver(put_in(state.streams[stream.id], stream), stream.id)
    end
  end

  defp operation(state, %{websocket: true} = stream, :websocket_closing, from) do
    state = return_credit(state, stream.id)
    stream = %{state.streams[stream.id] | demand: nil, delivery_ref: nil}
    GenServer.reply(from, :ok)
    put_in(state.streams[stream.id], stream)
  end

  defp operation(state, stream, {:read, credit, wait}, from)
       when is_integer(credit) and credit in 1..16_384 and is_integer(wait) and wait >= 0 do
    if stream.read != nil do
      GenServer.reply(from, {:error, :pending_read})
      state
    else
      state = return_credit(state, stream.id)
      token = make_ref()
      timer = Process.send_after(self(), {:h2_read_timeout, stream.id, token}, wait)

      state =
        put_in(state.streams[stream.id].read, %{
          from: from,
          credit: credit,
          token: token,
          timer: timer
        })

      deliver(state, stream.id)
    end
  end

  defp operation(state, stream, {:write, deadline, operation}, from)
       when is_integer(deadline) and
              deadline in -9_223_372_036_854_775_808..9_223_372_036_854_775_807 do
    deadline = min(deadline, stream.deadline)

    cond do
      stream.write_failed ->
        reply_error(state, from, :timeout)

      Lifecycle.remaining(deadline) == 0 ->
        state = put_in(state.streams[stream.id].write_failed, true)
        reply_error(state, from, :timeout)

      true ->
        write_operation(state, stream, operation, from, deadline)
    end
  end

  defp operation(state, _, _, from), do: reply_error(state, from, :invalid_operation)

  defp write_operation(state, stream, {:head, status, fields, ended}, from, deadline) do
    cond do
      stream.write != nil or stream.local_closed or stream.committed ->
        reply_error(state, from, :invalid_response_state)

      not (is_integer(status) and status in 100..599 and status != 101 and is_boolean(ended)) ->
        reply_error(state, from, :invalid_status)

      RendererBounds.response_fields(
        fields,
        state.limits.max_headers - 1,
        state.limits.max_header_bytes - Headers.bytes([{":status", Integer.to_string(status)}])
      ) != :ok ->
        reply_error(state, from, :invalid_response_headers)

      true ->
        encode_headers(
          state,
          stream.id,
          [{":status", Integer.to_string(status)} | fields],
          ended,
          from,
          status >= 200,
          deadline
        )
    end
  end

  defp write_operation(state, stream, {:trailers, fields}, from, deadline) do
    if stream.write == nil and stream.committed and not stream.local_closed and
         RendererBounds.trailer_fields(
           fields,
           state.limits.max_trailers,
           state.limits.max_trailer_bytes
         ) == :ok do
      encode_headers(state, stream.id, fields, true, from, true, deadline)
    else
      reply_error(state, from, :invalid_response_state)
    end
  end

  defp write_operation(state, stream, {:data, bytes, ended}, from, deadline)
       when is_binary(bytes) and byte_size(bytes) <= 16_384 and is_boolean(ended) do
    if stream.write == nil and stream.committed and not stream.local_closed do
      write =
        Map.merge(pending_write(stream.id, from, deadline, :data), %{bytes: bytes, ended: ended})

      put_in(state.streams[stream.id].write, write)
    else
      reply_error(state, from, :invalid_response_state)
    end
  end

  defp write_operation(state, _, _, from, _), do: reply_error(state, from, :invalid_operation)

  defp pending_write(id, from, deadline, kind) do
    token = make_ref()

    timer =
      Process.send_after(self(), {:h2_write_timeout, id, token}, Lifecycle.remaining(deadline))

    %{kind: kind, from: from, deadline: deadline, token: token, timer: timer}
  end

  defp reply_error(state, from, reason) do
    GenServer.reply(from, {:error, reason})
    state
  end

  defp deliver(state, id) do
    stream = state.streams[id]

    cond do
      stream.demand != nil and (stream.input != "" or stream.eof) ->
        demand = stream.demand
        count = min(demand.credit, byte_size(stream.input))
        <<bytes::binary-size(count), rest::binary>> = stream.input
        ended = rest == "" and stream.eof
        wire = if rest == "", do: stream.queued_wire, else: count
        send(stream.worker, {:gaoxy_websocket_data, stream.token, demand.ref, bytes, ended})

        put_in(state.streams[id], %{
          stream
          | input: rest,
            demand: nil,
            queued_wire: stream.queued_wire - wire,
            delivered_wire: wire,
            delivery_ref: demand.ref
        })

      stream.read != nil and (stream.input != "" or stream.eof) ->
        read = stream.read
        Process.cancel_timer(read.timer)
        count = min(read.credit, byte_size(stream.input))
        <<bytes::binary-size(count), rest::binary>> = stream.input
        ended = rest == "" and stream.eof
        # Payload credit follows the next consumer call; padding travels with the final piece.
        wire = if rest == "", do: stream.queued_wire, else: count

        GenServer.reply(
          read.from,
          {if(ended, do: :ok, else: :more), bytes, ended, stream.trailers}
        )

        put_in(state.streams[id], %{
          stream
          | input: rest,
            read: nil,
            queued_wire: stream.queued_wire - wire,
            delivered_wire: wire
        })

      true ->
        state
    end
  end

  defp return_credit(state, id) do
    stream = state.streams[id]
    size = stream.delivered_wire
    pending = stream.pending_credit + size
    state = put_in(state.streams[id], %{stream | delivered_wire: 0, pending_credit: pending})
    state = credit_connection(state, size)

    if pending >= min(16_384, state.h2.receive_window) do
      state =
        put_in(state.streams[id], %{
          state.streams[id]
          | pending_credit: 0,
            recv_window: stream.recv_window + pending
        })

      enqueue(state, Frame.encode(8, 0, id, <<pending::32>>), nil)
    else
      state
    end
  end

  defp credit_connection(state, 0), do: state

  defp credit_connection(state, size) do
    pending = state.pending_credit + size

    if pending >= 16_384 do
      enqueue(
        %{state | recv_window: state.recv_window + pending, pending_credit: 0},
        Frame.encode(8, 0, 0, <<pending::32>>),
        nil
      )
    else
      %{state | pending_credit: pending}
    end
  end

  defp encode_headers(state, id, fields, ended, from, committed, deadline) do
    # Every block declares an empty dynamic table. A canceled unsent block can
    # then be removed without losing a SETTINGS resize required by a later block.
    stream = state.streams[id]

    with true <- stream.renderer_blocks < 2,
         {block, _encoder} <- encode_field_blocks(fields, HPAX.resize(HPAX.new(0), 0)),
         {:ok, _} <- RendererBounds.iodata(block, 131_072),
         bytes = IO.iodata_to_binary(block),
         {:ok, entries} <- RendererBounds.header_frames(bytes, id, ended, from, deadline) do
      # No flags or response commitment change before the complete bounded
      # projection is accepted. The write slot prevents a second concurrent
      # block; final completion releases occupancy before trailers can start.
      stream = %{
        stream
        | committed: stream.committed or committed,
          local_closed: ended,
          write: pending_write(id, from, deadline, :headers),
          renderer_blocks: stream.renderer_blocks + 1,
          renderer_projection_bytes: :erlang.external_size({:queue.from_list(entries), id})
      }

      state = put_in(state.streams[id], stream)

      Enum.reduce(entries, state, fn {frame, callback, deadline}, acc ->
        enqueue(acc, frame, callback, deadline)
      end)
    else
      _ -> reply_error(state, from, :response_header_limit)
    end
  catch
    _, _ -> reply_error(state, from, :response_header_limit)
  end

  defp encode_field_blocks([], encoder) do
    {block, encoder} = HPAX.encode(:never_store, [], encoder)
    {[block], encoder}
  end

  defp encode_field_blocks([field | fields], encoder) do
    {block, encoder} = HPAX.encode(:never_store, [field], encoder)
    {blocks, encoder} = encode_field_blocks(fields, encoder)
    {[block | blocks], encoder}
  end

  defp enqueue(state, bytes, callback, deadline \\ nil) do
    if :queue.len(state.output) >= state.h2.control_rate + state.h2.max_streams * 8 do
      %{state | closing: true, close_after_write: true}
    else
      %{state | output: :queue.in({bytes, callback, deadline}, state.output)}
    end
  end

  defp schedule(%{writer_ready: false} = state), do: state
  defp schedule(%{inflight: inflight} = state) when inflight != nil, do: state

  defp schedule(state) do
    case :queue.out(state.output) do
      {{:value, {bytes, callback, deadline}}, queue} ->
        if deadline != nil and Lifecycle.remaining(deadline) == 0 and callback != nil do
          state = expire_write(%{state | output: queue}, callback_id(callback))
          if state.closing, do: state, else: schedule(state)
        else
          send_frame(
            %{state | output: queue},
            bytes,
            callback,
            deadline || Lifecycle.deadline(state.limits.write_timeout)
          )
        end

      {:empty, _} ->
        cond do
          state.close_after_write or (state.draining and map_size(state.streams) == 0) ->
            send(self(), :h2_close)
            state

          true ->
            schedule_data(state)
        end
    end
  end

  defp schedule_data(state) do
    state =
      Enum.reduce(state.streams, state, fn
        {id, %{write: %{deadline: deadline}}}, acc ->
          if Lifecycle.remaining(deadline) == 0, do: expire_write(acc, id), else: acc

        _, acc ->
          acc
      end)

    ready =
      Enum.filter(Enum.sort(state.streams), fn {_, stream} ->
        match?(%{kind: :data}, stream.write) and
          (stream.write.bytes == "" or (state.send_window > 0 and stream.send_window > 0))
      end)

    case Enum.find(ready, fn {id, _} -> id > state.last_sent end) || List.first(ready) do
      nil ->
        state

      {id, stream} ->
        write = stream.write

        size =
          min(byte_size(write.bytes), min(16_384, min(state.send_window, stream.send_window)))
          |> max(0)

        <<bytes::binary-size(size), rest::binary>> = write.bytes
        ended = write.ended and rest == ""

        stream = %{
          stream
          | send_window: stream.send_window - size,
            local_closed: ended,
            write: %{write | bytes: rest}
        }

        state =
          put_in(
            %{state | send_window: state.send_window - size, last_sent: id}.streams[id],
            stream
          )

        send_frame(
          state,
          Frame.encode(0, if(ended, do: 1, else: 0), id, bytes),
          {:data, id, rest == "", write.from},
          write.deadline
        )
    end
  end

  defp send_frame(state, bytes, callback, deadline) do
    token = make_ref()
    send(state.writer, {:h2_write, self(), token, bytes, deadline})

    outgoing_block =
      case callback do
        {:headers, id, _} -> id
        {:header_fragment, id} -> id
        _ -> state.outgoing_block
      end

    write =
      if callback != nil do
        id = callback_id(callback)
        operation = state.streams[id] && state.streams[id].write
        credit = if match?({:data, _, _, _}, callback), do: IO.iodata_length(bytes) - 9, else: 0
        %{id: id, token: operation && operation.token, deadline: deadline, credit: credit}
      end

    %{
      state
      | inflight: {token, callback},
        inflight_write: write,
        inflight_started: false,
        outgoing_block: outgoing_block
    }
  end

  defp callback_id({:headers, id, _}), do: id
  defp callback_id({:header_fragment, id}), do: id
  defp callback_id({:data, id, _, _}), do: id

  def info(message, socket, state) do
    case message(state, message) do
      :close -> {:stop, {:shutdown, :local_closed}, {socket, state}}
      next -> {:noreply, {socket, schedule(next)}}
    end
  end

  defp message(state, {:h2_writer_ready, writer}) when writer == state.writer,
    do: %{state | writer_ready: true}

  defp message(_state, {:h2_writer_failed, _}), do: :close

  defp message(state, {:h2_write_started, writer, token}) when writer == state.writer do
    case state.inflight do
      {^token, callback} ->
        headers = match?({:headers, _, _}, callback) or match?({:header_fragment, _}, callback)

        state = %{
          state
          | inflight_started: true,
            outgoing_started: state.outgoing_started or headers
        }

        if headers and state.inflight_write != nil and
             Lifecycle.remaining(state.inflight_write.deadline) == 0 do
          _ = expire_write(state, state.inflight_write.id)
          :close
        else
          state
        end

      _ ->
        state
    end
  end

  defp message(state, {:h2_written, writer, token, :ok}) when writer == state.writer do
    case state.inflight do
      # A stale success for an expired, unsent mailbox frame cannot release the
      # writer slot. Its actual :expired receipt releases the slot safely.
      {^token, callback} when state.inflight_started ->
        write = state.inflight_write
        state = %{state | inflight: nil, inflight_write: nil, inflight_started: false}

        if write != nil and Lifecycle.remaining(write.deadline) == 0 do
          state = expire_write(state, write.id)
          if state.closing, do: :close, else: clear_finished_block(state, callback)
        else
          written(state, callback, write)
        end

      _ ->
        state
    end
  end

  defp message(state, {:h2_written, writer, token, :expired}) when writer == state.writer do
    case state.inflight do
      {^token, callback} ->
        write = state.inflight_write
        state = %{state | inflight: nil, inflight_write: nil, inflight_started: false}

        if write == nil do
          :close
        else
          state = restore_unsent_credit(state, write)
          state = expire_write(state, write.id)
          state = clear_finished_block(state, callback)
          if state.closing, do: :close, else: state
        end

      _ ->
        state
    end
  end

  defp message(state, {:h2_written, writer, token, {:error, _}}) when writer == state.writer do
    case state.inflight do
      {^token, _} -> :close
      _ -> state
    end
  end

  # Only the original public async Admission response can grant worker custody.
  # Old worker-supplied ready/failure envelopes carry no such authority.
  defp message(state, {:h2_stream_ready, _, _, _, _}), do: state
  defp message(state, {:h2_stream_failed, _, _, _, _}), do: state

  defp message(state, {:h2_stream_done, worker, id, token, {:error, :endpoint_failed}}) do
    case state.streams[id] do
      %{worker: ^worker, token: ^token} -> reset(state, id, :cancel)
      _ -> state
    end
  end

  defp message(state, {:h2_stream_done, worker, id, token, _outcome}) do
    case state.streams[id] do
      %{worker: ^worker, token: ^token, write_failed: true} ->
        reset(state, id, :cancel)

      %{worker: ^worker, token: ^token, local_closed: true, eof: true} ->
        discard(state, id, false)

      %{worker: ^worker, token: ^token, local_closed: true} ->
        reset(state, id, :cancel)

      %{worker: ^worker, token: ^token} ->
        reset(state, id, :internal_error)

      _ ->
        state
    end
  end

  defp message(state, {:DOWN, monitor, :process, _, _} = message) do
    if monitor == state.writer_monitor do
      :close
    else
      case Enum.find(state.streams, fn {_, stream} -> stream.monitor == monitor end) do
        {id, _} ->
          start_next(
            reset(
              %{state | starting: if(state.starting == id, do: nil, else: state.starting)},
              id,
              :internal_error
            )
          )

        nil ->
          startup_response(state, message)
      end
    end
  end

  defp message(state, {:h2_read_timeout, id, token}) do
    case state.streams[id] do
      %{read: %{token: ^token, from: from}} ->
        GenServer.reply(from, :pending)
        put_in(state.streams[id].read, nil)

      _ ->
        state
    end
  end

  defp message(state, {:h2_write_timeout, id, token}) do
    case state.streams[id] do
      %{write: %{token: ^token}} -> expire_write(state, id)
      _ -> state
    end
  end

  defp message(state, {:h2_poll_timeout, id, token}) do
    case state.streams[id] do
      %{poll: %{token: ^token, from: from}} ->
        GenServer.reply(from, :ok)
        put_in(state.streams[id].poll, nil)

      _ ->
        state
    end
  end

  defp message(state, {:h2_worker_start_timeout, id, token}) do
    case state.streams[id] do
      %{token: ^token, startup: startup} when not is_nil(startup) ->
        reset(state, id, :refused_stream)

      _ ->
        state
    end
  end

  defp message(state, {:h2_start_timeout, token}) do
    if token == state.start_token and not state.settings_ack,
      do: failure(state, :settings_timeout),
      else: state
  end

  defp message(state, {:h2_partial_timeout, token}) do
    if token == state.partial_token, do: failure(state, :protocol_error), else: state
  end

  defp message(state, :h2_parse), do: partial_timer(parse(state, state.h2.control_turn))

  defp message(state, {:gaoxy_drain, gate, lease, deadline})
       when gate == state.gate and lease == state.lease do
    Process.send_after(self(), :h2_close, Lifecycle.remaining(deadline))

    enqueue(
      %{state | draining: true},
      Frame.encode(7, 0, 0, <<state.accepted::32, 0::32>>),
      nil,
      deadline
    )
  end

  defp message(_state, :h2_close), do: :close
  defp message(state, message), do: startup_response(state, message)

  defp startup_response(state, message) do
    case state.streams[state.starting] do
      %{startup: %{request: request} = startup} = stream ->
        case :gen_server.check_response(message, request) do
          {:reply, {:ok, worker, lease}} when is_pid(worker) and is_reference(lease) ->
            if startup.token == stream.token and startup.parent_lease == state.lease and
                 startup.deadline == stream.deadline and node(worker) == node() and
                 Process.alive?(worker) and Lifecycle.remaining(stream.deadline) > 0 do
              Process.cancel_timer(startup.timer)
              dispatch(state, stream, worker, lease, startup.protocol_bytes)
            else
              reset(state, stream.id, :refused_stream)
            end

          :no_reply ->
            state

          _ ->
            reset(state, stream.id, :refused_stream)
        end

      _ ->
        state
    end
  end

  defp dispatch(state, stream, worker, lease, protocol_bytes) do
    id = stream.id
    token = stream.token

    limits =
      if stream.request.protocol == "websocket",
        do: state.limits,
        else: Map.drop(state.limits, [:extended_connect, :websocket_limits])

    exchange = %Exchange{
      request: stream.request,
      gate: state.gate,
      lease: lease,
      deadline: stream.deadline,
      limits: Map.put(limits, :max_write_chunk, 16_384),
      body: %{
        phase: if(stream.initial_eof, do: :done, else: :data),
        total: 0,
        trailers: [],
        trailer_bytes: 0
      },
      buffer: "",
      transport: Transport,
      transport_state: {self(), id, token},
      peer: state.peer,
      local: state.local,
      secure: state.secure,
      ssl: nil,
      peer_cert: state.peer_cert,
      service: Map.get(state, :service),
      instance: Map.get(state, :instance),
      protocol_bytes: protocol_bytes
    }

    send(worker, {:h2_dispatch, self(), exchange, state.spec.handler_options.endpoint})

    start_next(
      put_in(
        %{state | starting: nil, accepted: max(state.accepted, id)}.streams[id],
        %{stream | worker: worker, monitor: Process.monitor(worker), lease: lease, startup: nil}
      )
    )
  end

  defp cancel_start(state, %{startup: startup}) when not is_nil(startup) do
    # Retiring an alias is local only. Gate still owns the known child and its
    # charge until actual DOWN plus EXIT, even when this connection drops its row.
    cancel = Admission.cancel_spawn(state.gate, startup.parent_lease, startup.token)
    Process.cancel_timer(startup.timer)
    :gen_server.receive_response(startup.request, 0)
    :gen_server.receive_response(cancel, 0)
    :ok
  end

  defp cancel_start(_, _), do: :ok

  defp written(state, nil, _), do: state
  defp written(state, {:header_fragment, _id}, _), do: state

  defp written(state, {:headers, id, from} = callback, write) do
    state = complete_write(state, id, from, write)
    clear_finished_block(state, callback)
  end

  defp written(state, {:data, id, true, from}, write) do
    complete_write(state, id, from, write)
  end

  defp written(state, {:data, _, false, _}, _), do: state

  defp complete_write(state, id, from, %{token: token}) do
    case state.streams[id] do
      %{write_failed: false, write: %{token: ^token, from: ^from} = write} = stream ->
        Process.cancel_timer(write.timer)
        GenServer.reply(from, :ok)

        put_in(state.streams[id], %{
          stream
          | write: nil,
            renderer_blocks: 0,
            renderer_projection_bytes: 0
        })

      _ ->
        state
    end
  end

  defp clear_finished_block(state, {:headers, _, _}),
    do: %{state | outgoing_block: nil, outgoing_started: false}

  defp clear_finished_block(state, _), do: state

  defp expire_write(state, id) do
    state =
      case state.streams[id] do
        %{write: write} = stream when is_map(write) ->
          Process.cancel_timer(write.timer)
          GenServer.reply(write.from, {:error, :timeout})
          # Keep the endpoint worker admitted while its upstream guardian joins
          # cleanup; later writes, including fallback responses, stay rejected.
          put_in(state.streams[id], %{
            stream
            | write: nil,
              write_failed: true,
              renderer_blocks: 0,
              renderer_projection_bytes: 0
          })

        _ ->
          state
      end

    if state.outgoing_block == id and state.outgoing_started do
      # Expiry cannot drop a started block's CONTINUATION frames and preserve
      # framing. Ordinary peer reset still uses discard/3's END_HEADERS drain.
      send(self(), :h2_close)
      %{state | closing: true, close_after_write: true}
    else
      output =
        :queue.filter(
          fn {_, callback, _} -> callback == nil or callback_id(callback) != id end,
          state.output
        )

      %{
        state
        | output: output,
          outgoing_block: if(state.outgoing_block == id, do: nil, else: state.outgoing_block)
      }
    end
  end

  defp restore_unsent_credit(state, %{id: id, credit: credit}) do
    state = %{state | send_window: state.send_window + credit}

    case state.streams[id] do
      nil -> state
      stream -> put_in(state.streams[id].send_window, stream.send_window + credit)
    end
  end

  defp reset(state, id, reason) do
    state = enqueue(discard(state, id), Frame.encode(3, 0, id, <<Frame.code(reason)::32>>), nil)
    if state.closing, do: state, else: start_next(state)
  end

  defp discard(state, id, kill \\ true) do
    # Once HEADERS is handed off, its remaining CONTINUATION frames must reach
    # END_HEADERS. Otherwise remove the entire unsent block for this stream.
    state =
      if state.outgoing_block == id do
        state
      else
        output =
          :queue.filter(
            fn
              {_, {:headers, ^id, _}, _} -> false
              {_, {:header_fragment, ^id}, _} -> false
              _ -> true
            end,
            state.output
          )

        %{state | output: output}
      end

    case state.streams[id] do
      nil ->
        state

      stream ->
        for operation <- [stream.read, stream.poll], operation != nil do
          Process.cancel_timer(operation.timer)
          GenServer.reply(operation.from, {:error, :closed})
        end

        if is_map(stream.write) do
          Process.cancel_timer(stream.write.timer)
          GenServer.reply(stream.write.from, {:error, :closed})
        end

        cancel_start(state, stream)
        if stream.monitor, do: Process.demonitor(stream.monitor, [:flush])
        if kill and stream.worker, do: Process.exit(stream.worker, :kill)

        credit_connection(
          %{
            state
            | streams: Map.delete(state.streams, id),
              starting: if(state.starting == id, do: nil, else: state.starting)
          },
          stream.queued_wire + stream.delivered_wire
        )
    end
  end

  defp failure(%{closing: true} = state, _), do: state

  defp failure(state, reason) do
    enqueue(
      %{state | closing: true, close_after_write: true},
      Frame.encode(7, 0, 0, <<state.accepted::32, Frame.code(reason)::32>>),
      nil
    )
  end

  defp partial_timer(state) do
    partial = not state.preface or state.continuation != nil or state.buffer != ""

    cond do
      partial and state.partial_timer == nil ->
        token = make_ref()
        timer = Process.send_after(self(), {:h2_partial_timeout, token}, state.h2.frame_timeout)
        %{state | partial_timer: timer, partial_token: token}

      not partial and state.partial_timer != nil ->
        Process.cancel_timer(state.partial_timer)
        %{state | partial_timer: nil, partial_token: nil}

      true ->
        state
    end
  end

  def close(state) when is_map(state) do
    Enum.each(state.streams, fn {_, stream} ->
      cancel_start(state, stream)
      if stream.worker, do: Process.exit(stream.worker, :kill)
    end)

    send(state.writer, :stop)
    :ok
  end

  def close(_), do: :ok
end
