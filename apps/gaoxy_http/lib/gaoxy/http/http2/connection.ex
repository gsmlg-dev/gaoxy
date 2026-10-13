defmodule Gaoxy.HTTP.HTTP2.Connection do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, HTTP2.Frame, HTTP2.Headers, HTTP2.Limits, HTTP2.Settings}
  alias Gaoxy.HTTP.HTTP2.{Stream, Writer, Transport}
  alias ThousandIsland.Socket
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
         limits: options.http_limits,
         h2: h2,
         reserves: reserves,
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
         outgoing_block: nil,
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
            received = stream.received + byte_size(bytes)
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
  end

  defp trailers(state, id, fields, ended) do
    stream = state.streams[id]

    valid_length =
      not match?({:length, _}, stream.request.body) or
        stream.received == elem(stream.request.body, 1)

    if ended and not stream.eof and valid_length and Headers.trailers(fields, state.limits) == :ok do
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
        case Headers.request(fields, state.secure, state.limits) do
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
        owner = self()

        case Task.Supervisor.start_child(Gaoxy.HTTP.Tasks, fn ->
               Stream.run(
                 owner,
                 id,
                 stream.token,
                 state.gate,
                 state.reserves.stream,
                 stream.deadline
               )
             end) do
          {:ok, worker} ->
            put_in(%{state | starting: id}.streams[id], %{
              stream
              | worker: worker,
                monitor: Process.monitor(worker)
            })

          _ ->
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

  defp operation(state, stream, {:head, status, fields, ended}, from) do
    final = status >= 200

    cond do
      stream.write != nil or stream.local_closed or stream.committed ->
        reply_error(state, from, :invalid_response_state)

      Headers.response(
        fields,
        state.limits.max_headers - 1,
        state.limits.max_header_bytes - Headers.bytes([{":status", Integer.to_string(status)}])
      ) != :ok ->
        reply_error(state, from, :invalid_response_headers)

      true ->
        stream = %{
          stream
          | committed: stream.committed or final,
            local_closed: ended,
            write: :headers
        }

        encode_headers(
          put_in(state.streams[stream.id], stream),
          stream.id,
          [{":status", Integer.to_string(status)} | fields],
          ended,
          from
        )
    end
  end

  defp operation(state, stream, {:trailers, fields}, from) do
    if stream.write == nil and stream.committed and not stream.local_closed and
         Headers.trailers(fields, state.limits) == :ok do
      stream = %{stream | local_closed: true, write: :headers}
      encode_headers(put_in(state.streams[stream.id], stream), stream.id, fields, true, from)
    else
      reply_error(state, from, :invalid_response_state)
    end
  end

  defp operation(state, stream, {:data, bytes, ended}, from)
       when is_binary(bytes) and byte_size(bytes) <= 16_384 and is_boolean(ended) do
    if stream.write == nil and stream.committed and not stream.local_closed do
      put_in(state.streams[stream.id].write, %{bytes: bytes, ended: ended, from: from})
    else
      reply_error(state, from, :invalid_response_state)
    end
  end

  defp operation(state, _, _, from), do: reply_error(state, from, :invalid_operation)

  defp reply_error(state, from, reason) do
    GenServer.reply(from, {:error, reason})
    state
  end

  defp deliver(state, id) do
    stream = state.streams[id]

    if stream.read != nil and (stream.input != "" or stream.eof) do
      read = stream.read
      Process.cancel_timer(read.timer)
      count = min(read.credit, byte_size(stream.input))
      <<bytes::binary-size(count), rest::binary>> = stream.input
      ended = rest == "" and stream.eof
      # Payload credit follows the next consumer call; padding travels with the final piece.
      wire = if rest == "", do: stream.queued_wire, else: count
      GenServer.reply(read.from, {if(ended, do: :ok, else: :more), bytes, ended, stream.trailers})

      put_in(state.streams[id], %{
        stream
        | input: rest,
          read: nil,
          queued_wire: stream.queued_wire - wire,
          delivered_wire: wire
      })
    else
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

  defp encode_headers(state, id, fields, ended, from) do
    # Every block declares an empty dynamic table. A canceled unsent block can
    # then be removed without losing a SETTINGS resize required by a later block.
    {block, _encoder} = HPAX.encode(:never_store, fields, HPAX.resize(HPAX.new(0), 0))
    bytes = IO.iodata_to_binary(block)
    header_frames(state, id, bytes, ended, from, true)
  end

  defp header_frames(state, id, bytes, ended, from, first) do
    count = min(byte_size(bytes), min(16_384, state.settings.max_frame))
    <<piece::binary-size(count), rest::binary>> = bytes
    flags = if(rest == "", do: 4, else: 0) + if(first and ended, do: 1, else: 0)
    callback = if rest == "", do: {:headers, id, from}, else: {:header_fragment, id}

    state =
      enqueue(
        state,
        Frame.encode(if(first, do: 1, else: 9), flags, id, piece),
        callback,
        state.streams[id].deadline
      )

    if rest == "", do: state, else: header_frames(state, id, rest, ended, from, false)
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
        send_frame(
          %{state | output: queue},
          bytes,
          callback,
          deadline || Lifecycle.deadline(state.limits.write_timeout)
        )

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
    ready =
      Enum.filter(Enum.sort(state.streams), fn {_, stream} ->
        is_map(stream.write) and
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
          stream.deadline
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

    %{state | inflight: {token, callback}, outgoing_block: outgoing_block}
  end

  def info(message, socket, state) do
    case message(state, message) do
      :close -> {:stop, {:shutdown, :local_closed}, {socket, state}}
      next -> {:noreply, {socket, schedule(next)}}
    end
  end

  defp message(state, {:h2_writer_ready, writer}) when writer == state.writer,
    do: %{state | writer_ready: true}

  defp message(_state, {:h2_writer_failed, _}), do: :close

  defp message(state, {:h2_written, writer, token, :ok}) when writer == state.writer do
    case state.inflight do
      {^token, callback} -> written(%{state | inflight: nil}, callback)
      _ -> state
    end
  end

  defp message(_state, {:h2_written, _, _, {:error, _}}), do: :close

  defp message(state, {:h2_stream_ready, worker, id, token, lease}) do
    case state.streams[id] do
      %{worker: ^worker, token: ^token} = stream ->
        request = stream.request
        limits = Map.put(state.limits, :max_write_chunk, 16_384)

        exchange = %Exchange{
          request: request,
          gate: state.gate,
          lease: lease,
          deadline: stream.deadline,
          limits: limits,
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
          ssl: state.ssl,
          peer_cert: state.peer_cert,
          service: Map.get(state, :service),
          instance: Map.get(state, :instance),
          protocol_bytes: state.reserves.stream
        }

        send(worker, {:h2_dispatch, self(), exchange, state.spec.handler_options.endpoint})

        start_next(
          put_in(%{state | starting: nil, accepted: max(state.accepted, id)}.streams[id], %{
            stream
            | lease: lease
          })
        )

      _ ->
        Process.exit(worker, :kill)
        state
    end
  end

  defp message(state, {:h2_stream_failed, worker, id, token, _}) do
    case state.streams[id] do
      %{worker: ^worker, token: ^token, lease: nil} when state.starting == id ->
        start_next(reset(%{state | starting: nil}, id, :refused_stream))

      _ ->
        state
    end
  end

  defp message(state, {:h2_stream_done, worker, id, token, {:error, :endpoint_failed}}) do
    case state.streams[id] do
      %{worker: ^worker, token: ^token} -> reset(state, id, :cancel)
      _ -> state
    end
  end

  defp message(state, {:h2_stream_done, worker, id, token, _outcome}) do
    case state.streams[id] do
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

  defp message(state, {:DOWN, monitor, :process, _, _}) do
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
          state
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

  defp message(state, {:h2_poll_timeout, id, token}) do
    case state.streams[id] do
      %{poll: %{token: ^token, from: from}} ->
        GenServer.reply(from, :ok)
        put_in(state.streams[id].poll, nil)

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
  defp message(state, _), do: state

  defp written(state, nil), do: state
  defp written(state, {:header_fragment, _id}), do: state

  defp written(state, {:headers, id, from}) do
    GenServer.reply(from, :ok)
    state = %{state | outgoing_block: nil}
    if Map.has_key?(state.streams, id), do: put_in(state.streams[id].write, nil), else: state
  end

  defp written(state, {:data, id, true, from}) do
    GenServer.reply(from, :ok)
    if Map.has_key?(state.streams, id), do: put_in(state.streams[id].write, nil), else: state
  end

  defp written(state, {:data, _, false, _}), do: state

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

        if is_map(stream.write), do: GenServer.reply(stream.write.from, {:error, :closed})
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
      if stream.worker, do: Process.exit(stream.worker, :kill)
    end)

    send(state.writer, :stop)
    :ok
  end

  def close(_), do: :ok
end
