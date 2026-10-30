defmodule Gaoxy.HTTP.HTTP2.Connection do
  @moduledoc false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, HTTP2.Frame, HTTP2.Headers, HTTP2.Limits, HTTP2.Settings}
  alias Gaoxy.HTTP.RendererBounds
  alias Gaoxy.HTTP.HTTP2.{Stream, Writer, Transport, WorkerAccounting}
  alias Hell.Socket
  alias HTTP.HTTP2.HPACK
  @preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
  @max_window 2_147_483_647

  def start(socket, context) do
    options = context.spec.handler_options
    h2 = options.h2_limits
    member = Map.get(context, :connection_member, make_ref())

    with :ok <- Limits.validate_budget(options.http_limits, h2, context.spec.limits),
         :ok <- Limits.validate_host(if(Socket.secure?(socket), do: :tls, else: :tcp)),
         :ok <- tls_policy(socket),
         {:ok, delivery} <- receive_options(socket),
         reserves = Limits.reservation(options.http_limits, h2, delivery),
         {:ok, lease} <- owner_lease(context, reserves.connection, member),
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
      startup_deadline = (Map.get(context, :first_input) || Lifecycle.now()) + h2.frame_timeout

      timer =
        Process.send_after(
          self(),
          {:h2_start_timeout, token},
          Lifecycle.remaining(startup_deadline)
        )

      state =
        Map.merge(context, %{
          phase: :http2,
          default_read_timeout: socket.read_timeout,
          lease: lease,
          connection_member: member,
          limits: Map.put(options.http_limits, :extended_connect, options.extended_connect),
          h2: h2,
          reserves: reserves,
          decode_reservation: 0,
          funded_floor: nil,
          accounted_bytes: reserves.connection,
          buffer: "",
          preface: false,
          first: true,
          decoder: HPACK.new_decoder(Limits.decoder_options(h2)),
          settings: Settings.defaults(),
          streams: %{},
          retiring_streams: %{},
          retirement_timer: nil,
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
          start_deadline: startup_deadline,
          start_token: token,
          start_timer: timer,
          settings_ack: false,
          rate_start: Lifecycle.now(),
          rate: 0,
          last_sent: 0,
          partial_timer: nil,
          partial_token: nil
        })

      case resize_connection(state, 0) do
        {:ok, state} -> {:continue, state}
        {:error, _, state} -> {:close, state}
      end
    else
      :closed -> {:close, context}
      {:error, reason} -> {:error, reason, context}
    end
  end

  defp receive_options(socket) do
    case Socket.setopts(socket,
           recbuf: Limits.receive_buffer(),
           buffer: Limits.receive_buffer()
         ) do
      {:error, {:options, {:socket_options, _, reason}}} = error
      when reason in [:closed, :einval, :enotconn] ->
        disconnected_option_error(socket, error)

      {:error, reason} = error when reason in [:closed, :einval, :enotconn] ->
        disconnected_option_error(socket, error)

      :ok ->
        if Socket.secure?(socket) do
          # SSL may coalesce multiple records; keep its conservative profile.
          {:ok, Limits.max_delivery()}
        else
          case Socket.getopts(socket, [:buffer]) do
            {:ok, options} ->
              case Keyword.get(options, :buffer) do
                bytes when is_integer(bytes) and bytes > 0 ->
                  {:ok, max(bytes, Limits.receive_buffer())}

                _ ->
                  {:error, :unsupported_http2_receive_buffer}
              end

            error ->
              disconnected_option_error(socket, error)
          end
        end

      result ->
        result
    end
  end

  defp disconnected_option_error(socket, error) do
    # OTP SSL can wrap a transport failure as an invalid-option error. Confirm
    # the peer is gone before treating that setup failure as an orderly close.
    case Socket.peername(socket) do
      {:error, reason} when reason in [:closed, :einval, :enotconn] -> :closed
      _ -> error
    end
  end

  defp owner_lease(%{gate: gate, lease: lease} = context, bytes, member) do
    accounting = connection_accounting(context, 0, bytes, member)

    case Admission.update_until(gate, lease, accounting, make_ref(), Lifecycle.deadline(50)) do
      :ok -> {:ok, lease}
      error -> error
    end
  end

  defp owner_lease(%{gate: gate} = context, bytes, member),
    do:
      Admission.acquire(gate, connection_accounting(context, 0, bytes, member),
        kind: :connection,
        memberships: %{connection: member},
        drain_notify: true
      )

  defp budgeted?(state), do: is_pid(Map.get(state, :instance))

  defp connection_accounting(state, retained, temporary, member) do
    if budgeted?(state) do
      %{
        retained_bytes: retained,
        temporary_bytes: temporary,
        transport_bytes: retained + temporary,
        websocket_bytes: 0,
        memberships: %{connection: member},
        pending_processes: 0
      }
    else
      retained + temporary
    end
  end

  defp resize_connection(state, decode_bytes) do
    # Only completion credit is reusable. The independent receive/copy floor
    # and the current decoder peak remain promised before further allocation.
    state =
      if budgeted?(state) and Map.get(state, :funded_floor) == nil do
        # Pay the bounded integer representation of these two bookkeeping
        # fields before replacing their initial values.
        Map.merge(state, %{
          funded_floor: retained_connection(state) + state.reserves.connection + 32,
          accounted_bytes: state.reserves.connection
        })
      else
        state
      end

    retained = if budgeted?(state), do: retained_connection(state), else: 0

    total =
      if budgeted?(state),
        do: max(state.funded_floor, retained + state.reserves.receive) + decode_bytes,
        else: state.reserves.connection + decode_bytes

    temporary = total - retained
    accounting = connection_accounting(state, retained, temporary, state.connection_member)

    mutation =
      if budgeted?(state) and total <= state.accounted_bytes,
        do: :repartition_until,
        else: :update_until

    case apply(Admission, mutation, [
           state.gate,
           state.lease,
           accounting,
           make_ref(),
           Lifecycle.deadline(50)
         ]) do
      :ok ->
        next = %{state | decode_reservation: decode_bytes}
        {:ok, if(budgeted?(state), do: Map.put(next, :accounted_bytes, total), else: next)}

      {:error, reason} ->
        {:error, reason, state}
    end
  catch
    :exit, _ -> {:error, :closed, state}
  end

  # Retained slices must not pin an entire old delivery. The independent
  # receive/copy floor pays these copies before parser and consumer handoff.
  defp detach(bytes) do
    if :binary.referenced_byte_size(bytes) > byte_size(bytes),
      do: :binary.copy(bytes),
      else: bytes
  end

  defp retained_connection(state) do
    :erlang.external_size(Map.drop(state, [:decode_reservation])) +
      Enum.reduce(state.streams, 0, fn {_, stream}, total -> total + stream.delivered_wire end)
  end

  defp progress(state) do
    state = state |> schedule() |> settle_retired()

    case resize_connection(state, state.decode_reservation) do
      {:ok, next} -> next
      {:error, _, next} -> schedule(failure(next, :enhance_your_calm))
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

  def data(bytes, socket, state) do
    cond do
      not state.settings_ack and Lifecycle.remaining(state.start_deadline) == 0 ->
        network_continue(socket, progress(failure(state, :settings_timeout)))

      byte_size(state.buffer) + byte_size(bytes) > state.limits.max_buffer_bytes ->
        {:close, state}

      true ->
        state = %{state | buffer: detach(state.buffer <> bytes)}
        state = parse(state, state.h2.control_turn)
        network_continue(socket, progress(partial_timer(state)))
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
        <<_::binary-size(^size), rest::binary>> = state.buffer

        initial =
          <<1::16, state.h2.table_size::32, 3::16, state.h2.max_streams::32, 4::16,
            state.h2.receive_window::32, 5::16, state.h2.max_frame::32, 6::16,
            state.limits.max_header_bytes::32>>

        initial =
          if state.limits.extended_connect,
            do: initial <> <<8::16, 1::32>>,
            else: initial

        state =
          enqueue(
            %{state | preface: true, buffer: detach(rest)},
            Frame.encode(4, 0, 0, initial),
            nil
          )

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
        state = %{state | buffer: detach(rest)}
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

      Frame.flag?(flags, 1) and Lifecycle.remaining(state.start_deadline) == 0 ->
        failure(state, :settings_timeout)

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
              %{
                state
                | continuation: %{id: id, block: detach(block), ended: ended, error: stream_error}
              }
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
        else: %{state | continuation: %{cont | block: detach(block)}}
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
                    input: detach(stream.input <> bytes),
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
        {:ok, state} ->
          decoded = decode_reserved_headers(state, id, block, ended, stream_error)
          # The expanded fields have either moved to bounded retained state or
          # been rejected; the decoder's temporary peak is no longer live.
          case resize_connection(decoded, 0) do
            {:ok, next} -> next
            {:error, _, next} -> failure(next, :enhance_your_calm)
          end

        {:error, _, state} ->
          failure(state, :enhance_your_calm)
      end
    end
  end

  defp reserve_decode(state, block_bytes),
    do: resize_connection(state, Limits.decode_reservation(state.h2, block_bytes))

  defp decode_reserved_headers(state, id, block, ended, stream_error) do
    case HPACK.decode(state.decoder, block) do
      {:ok, decoder, fields} ->
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

      state.draining or
          map_size(state.streams) + map_size(state.retiring_streams) >= state.h2.max_streams ->
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
                # Admission and activation retain a finite startup deadline.
                # The dispatched worker selects its configured request lifetime.
                deadline:
                  Lifecycle.deadline(
                    if(state.limits.request_timeout == :infinity,
                      do: state.limits.header_timeout,
                      else: state.limits.request_timeout
                    )
                  ),
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
            accounting = %{
              retained_bytes: bytes - state.reserves.stream,
              temporary_bytes: state.reserves.stream,
              transport_bytes: bytes,
              websocket_bytes: 0,
              memberships: %{},
              pending_processes: 0
            }

            metadata = [
              kind: :h2_stream,
              memberships: %{h2_stream: {state.lease, id}, request: stream.token}
            ]

            request =
              Admission.spawn_request(
                state.gate,
                state.lease,
                stream.token,
                accounting,
                stream.deadline,
                {Stream, :run,
                 [self(), id, stream.token, state.gate, protocol_bytes, stream.deadline]},
                metadata,
                :phase_receipt
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
        state = progress(state)
        {:noreply, {owner_timeout(socket, state), state}}

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

  defp operation(state, stream, :infinite_request, from) do
    if state.limits.request_timeout == :infinity and not state.draining and
         not stream.committed and not stream.websocket and stream.read == nil and
         stream.poll == nil and Lifecycle.remaining(stream.deadline) != 0 do
      GenServer.reply(from, :ok)
      put_in(state.streams[stream.id].deadline, :infinity)
    else
      reply_error(state, from, :invalid_request_transition)
    end
  end

  defp operation(state, stream, {:begin_stream, deadline}, from)
       when deadline == :infinity or is_integer(deadline) do
    if not state.draining and not stream.committed and not stream.websocket and
         stream.eof and stream.input == "" and stream.read == nil and stream.poll == nil and
         Lifecycle.remaining(stream.deadline) != 0 and Lifecycle.remaining(deadline) != 0 do
      GenServer.reply(from, :ok)
      put_in(state.streams[stream.id].deadline, deadline)
    else
      reply_error(state, from, :invalid_stream_transition)
    end
  end

  defp operation(state, stream, {:websocket_open, headers, lifetime, write_deadline}, from)
       when (is_integer(lifetime) or lifetime == :infinity) and is_integer(write_deadline) do
    valid =
      state.limits.extended_connect and not stream.websocket and
        not stream.committed and not stream.eof and stream.read == nil and stream.poll == nil and
        Lifecycle.remaining(stream.deadline) != 0 and Lifecycle.remaining(lifetime) != 0 and
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
    deadline = Lifecycle.earlier(deadline, stream.deadline)

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
        <<bytes::binary-size(^count), rest::binary>> = stream.input
        bytes = detach(bytes)
        rest = detach(rest)
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
        <<bytes::binary-size(^count), rest::binary>> = stream.input
        bytes = detach(bytes)
        rest = detach(rest)
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
         {block, _encoder} <-
           encode_field_blocks(fields, HPACK.set_max_dynamic_size(HPACK.new_encoder(), 0)),
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
    {encoder, block} = HPACK.encode_headers(encoder, [], indexing: :never, huffman: :never)
    {[block], encoder}
  end

  defp encode_field_blocks([field | fields], encoder) do
    {encoder, block} = HPACK.encode_headers(encoder, [field], indexing: :never, huffman: :never)
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

        <<bytes::binary-size(^size), rest::binary>> = write.bytes
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
      :close ->
        {:stop, {:shutdown, :local_closed}, {socket, state}}

      next ->
        next = progress(next)
        {:noreply, {owner_timeout(socket, next), next}}
    end
  end

  # The H2 owner outlives individual streams. Only WebSocket ownership changes
  # its host idle policy; ordinary local messages must not refresh the interval.
  defp read_timeout(state) do
    if Enum.any?(state.streams, fn {_, stream} -> stream.websocket end),
      do: :infinity,
      else: state.default_read_timeout
  end

  defp owner_timeout(socket, state) do
    timeout = read_timeout(state)

    if socket.read_timeout == timeout,
      do: socket,
      else: Hell.Handler.set_read_timeout(socket, timeout)
  end

  defp network_continue(socket, state) do
    timeout = read_timeout(state)

    if socket.read_timeout == timeout,
      do: {:continue, state},
      else: {:continue, state, {:persistent, timeout}}
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

  defp message(state, :h2_retire_resources), do: %{state | retirement_timer: nil}

  defp message(state, {:gaoxy_drain, gate, lease, deadline})
       when gate == state.gate and lease == state.lease do
    Process.send_after(self(), :h2_close, Lifecycle.remaining(deadline))

    enqueue(
      Map.put(%{state | draining: true}, :drain_deadline, deadline),
      Frame.encode(7, 0, 0, <<state.accepted::32, 0::32>>),
      nil,
      deadline
    )
  end

  defp message(_state, :h2_close), do: :close
  defp message(state, message), do: startup_response(state, message)

  defp startup_response(state, message) do
    state = retirement_response(state, message)

    case state.streams[state.starting] do
      %{startup: %{request: request} = startup} = stream ->
        case :gen_server.check_response(message, request) do
          {:reply, {:ok, worker, lease}} when is_pid(worker) and is_reference(lease) ->
            if startup.token == stream.token and startup.parent_lease == state.lease and
                 startup.deadline == stream.deadline and node(worker) == node() and
                 Process.alive?(worker) and Lifecycle.remaining(stream.deadline) != 0 do
              Process.cancel_timer(startup.timer)
              dispatch(state, stream, worker, lease, startup.protocol_bytes)
            else
              reset(state, stream.id, :refused_stream, {:success, lease})
            end

          :no_reply ->
            state

          {:reply, {:error, reason}} ->
            reset(state, stream.id, :refused_stream, {:error, reason})

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
        else: Map.drop(state.limits, [:extended_connect])

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

    exchange =
      if budgeted?(state) do
        Exchange.fund(
          exchange,
          protocol_bytes + 2 * stream.request.head_bytes,
          state.reserves.stream,
          %{h2_stream: {state.lease, id}, request: token}
        )
      else
        exchange
      end

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
    # Keep the original spawn outcome alias in the bounded retiring record.
    # A cancellation acknowledgment alone is no terminal resource proof.
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

  defp reset(state, id, reason, outcome \\ :pending) do
    state =
      enqueue(
        discard(state, id, true, outcome),
        Frame.encode(3, 0, id, <<Frame.code(reason)::32>>),
        nil
      )

    if state.closing, do: state, else: start_next(state)
  end

  defp discard(state, id, kill \\ true, outcome \\ :pending) do
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

        state = retire_stream(state, stream, outcome)

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

  defp retire_stream(state, stream, outcome) do
    if budgeted?(state) and (stream.lease != nil or stream.startup != nil) do
      lease =
        case outcome do
          {:success, lease} -> lease
          _ -> stream.lease
        end

      pending = stream.startup != nil and outcome == :pending

      retirement = %{
        lease: lease,
        token: stream.token,
        operation: make_ref(),
        resource: if(lease, do: {:lease, lease}, else: {:spawn, stream.token}),
        request: if(pending, do: stream.startup.request),
        outcome: outcome,
        stream_done: false,
        resources_done: false
      }

      put_in(state.retiring_streams[stream.id], retirement)
    else
      state
    end
  end

  defp retirement_response(state, message) do
    retirements =
      Map.new(state.retiring_streams, fn {id, retired} ->
        retired =
          if retired.request do
            case :gen_server.check_response(message, retired.request) do
              {:reply, {:ok, _, lease}} ->
                %{retired | request: nil, lease: lease, outcome: :success}

              {:reply, {:error, reason}} ->
                %{retired | request: nil, outcome: {:error, reason}}

              _ ->
                retired
            end
          else
            retired
          end

        {id, retired}
      end)

    %{state | retiring_streams: retirements}
  end

  defp settle_retired(state, deadline \\ nil) do
    retired =
      Enum.reduce(state.retiring_streams, %{}, fn {id, retired}, pending ->
        stream_done =
          retired.stream_done or
            terminal_call(fn ->
              Admission.end_stream(
                state.gate,
                state.lease,
                :h2_stream,
                id,
                deadline || Lifecycle.deadline(50)
              )
            end)

        buffers_done = not stream_output?(state, id)

        resources_done =
          retired.resources_done or
            (buffers_done and
               terminal_call(fn ->
                 # Pin the proof target to the stable operation: learning a late lease
                 # must not change an ambiguous spawn-token proof's fingerprint.
                 case retired.resource do
                   {:lease, lease} ->
                     Admission.finish_stream_resources(
                       state.gate,
                       state.lease,
                       lease,
                       retired.operation,
                       deadline || Lifecycle.deadline(50)
                     )

                   {:spawn, token} ->
                     Admission.finish_spawn_resources(
                       state.gate,
                       state.lease,
                       token,
                       retired.operation,
                       deadline || Lifecycle.deadline(50)
                     )
                 end
               end)) or
            (buffers_done and definite_spawn_rejection?(retired.outcome, retired.token))

        retired = %{retired | stream_done: stream_done, resources_done: resources_done}

        if stream_done and resources_done do
          if retired.request, do: :gen_server.receive_response(retired.request, 0)
          pending
        else
          Map.put(pending, id, retired)
        end
      end)

    state = %{state | retiring_streams: retired}

    if map_size(retired) > 0 and state.retirement_timer == nil,
      do: %{state | retirement_timer: Process.send_after(self(), :h2_retire_resources, 10)},
      else: state
  end

  defp terminal_call(fun) do
    fun.() == :ok
  catch
    :exit, _ -> false
  end

  # These errors are returned before reserve/activation can create a child.
  # An ambiguous timeout, cancelled worker or stale token is never absence proof.
  defp definite_spawn_rejection?({:error, {:not_reserved, token, :deadline_exceeded}}, token),
    do: true

  defp definite_spawn_rejection?({:error, reason}, _token),
    do:
      reason in [
        :byte_limit,
        :active_limit,
        :connection_limit,
        :request_limit,
        :stream_limit,
        :lease_capacity,
        :memory_hard_limit,
        :system_memory_pressure,
        :safety_sample_unavailable,
        :process_capacity
      ]

  defp definite_spawn_rejection?(_, _), do: false

  defp stream_output?(state, id) do
    state.outgoing_block == id or
      (state.inflight != nil and elem(state.inflight, 1) != nil and
         callback_id(elem(state.inflight, 1)) == id) or
      Enum.any?(:queue.to_list(state.output), fn
        {_, nil, _} -> false
        {_, callback, _} -> callback_id(callback) == id
      end)
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
    # local_closed plus a cleared, successful write slot proves completion. A
    # peer can close immediately after END_STREAM while that worker commits its
    # final Admission bookkeeping. Keep the parent alive for that bounded join.
    deadline =
      Lifecycle.earlier(
        Lifecycle.deadline(Lifecycle.cleanup_headroom()),
        Map.get(state, :drain_deadline, :infinity)
      )

    state = settle_final_write(state, deadline)

    {completed, deadline} =
      Enum.reduce(state.streams, {%{}, deadline}, fn {_, stream}, {completed, deadline} ->
        cancel_start(state, stream)

        cond do
          stream.worker == nil ->
            {completed, deadline}

          stream.local_closed and stream.eof and stream.write == nil and not stream.write_failed ->
            monitor = Process.monitor(stream.worker)

            {Map.put(completed, monitor, stream.worker),
             Lifecycle.earlier(deadline, stream.deadline)}

          true ->
            Process.exit(stream.worker, :kill)
            {completed, deadline}
        end
      end)

    join_completed(completed, deadline)

    if budgeted?(state) do
      monitor = Process.monitor(state.writer)
      send(state.writer, :stop)

      if writer_terminal?(state.writer, monitor, deadline) do
        # Writer DOWN proves its independent frame references are gone. Drop
        # every parent stream/carry/output reference before resource proof;
        # Admission still independently joins child DOWN/EXIT and commits.
        state = Enum.reduce(Map.keys(state.streams), state, &discard(&2, &1, false))

        state = %{
          state
          | buffer: "",
            continuation: nil,
            output: :queue.new(),
            inflight: nil,
            inflight_write: nil,
            outgoing_block: nil
        }

        if Lifecycle.remaining(deadline) > 0, do: settle_retired(state, deadline)
      end
    else
      send(state.writer, :stop)
    end

    :ok
  end

  def close(_), do: :ok

  # A socket close can overtake the writer's receipt even though the peer has
  # already received END_STREAM. Accept only that original final-write token;
  # never treat a queued FIN or peer close itself as successful completion.
  defp settle_final_write(
         %{inflight: {token, callback}, inflight_write: %{id: id, deadline: write_deadline}} =
           state,
         deadline
       ) do
    stream = state.streams[id]
    final = match?({:headers, ^id, _}, callback) or match?({:data, ^id, true, _}, callback)

    if stream && stream.local_closed && stream.eof && final do
      await_final_write(state, token, Lifecycle.earlier(deadline, write_deadline))
    else
      state
    end
  end

  defp settle_final_write(state, _deadline), do: state

  defp await_final_write(state, token, deadline) do
    writer = state.writer

    receive do
      {:h2_write_started, ^writer, ^token} = receipt ->
        case message(state, receipt) do
          :close -> state
          next -> await_final_write(next, token, deadline)
        end

      {:h2_written, ^writer, ^token, :ok} = receipt ->
        case message(state, receipt) do
          :close -> state
          next -> next
        end

      {:h2_written, ^writer, ^token, _} ->
        state
    after
      Lifecycle.remaining(deadline) -> state
    end
  end

  defp writer_terminal?(writer, monitor, deadline) do
    receive do
      {:DOWN, ^monitor, :process, ^writer, _} -> true
    after
      Lifecycle.remaining(deadline) ->
        Process.demonitor(monitor, [:flush])
        false
    end
  end

  defp join_completed(completed, _deadline) when map_size(completed) == 0, do: :ok

  defp join_completed(completed, deadline) do
    receive do
      {:DOWN, monitor, :process, _, _} when is_map_key(completed, monitor) ->
        join_completed(Map.delete(completed, monitor), deadline)
    after
      Lifecycle.remaining(deadline) ->
        Enum.each(completed, fn {monitor, worker} ->
          Process.demonitor(monitor, [:flush])
          Process.exit(worker, :kill)
        end)
    end
  end
end
