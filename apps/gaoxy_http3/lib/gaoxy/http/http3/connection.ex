defmodule Gaoxy.HTTP.HTTP3.Connection do
  @moduledoc false
  @behaviour Gaoxy.QUICHandler
  alias Gaoxy.QUIC
  alias Gaoxy.HTTP.HTTP3.Protocol
  alias QuicHttp3.{Control, Frame, Qpack}

  @impl true
  def init(
        connection,
        metadata,
        %{endpoint: {Gaoxy.HTTP3Fixture.Endpoint, %{profile: :minimal} = fixture}} = options
      ) do
    with {:ok, protocol} <- Protocol.new(options) do
      if is_pid(fixture[:observer]),
        do: send(fixture.observer, {:http3_fixture_connection, fixture[:id], connection.gate})

      {:ok,
       %{
         connection: connection,
         options: options,
         metadata: metadata,
         protocol: protocol,
         ready: false,
         control: nil,
         control_bytes: Control.local_payload(protocol.control),
         control_deadline: nil,
         streams: %{},
         order: :queue.new(),
         pending: %{},
         closed: false,
         turn_deadline: nil
       }}
    end
  end

  def init(_, _, _), do: {:error, :http3_endpoint_not_implemented}

  @impl true
  def handle_event({:ready, metadata}, state) do
    cond do
      metadata[:alpn] != "h3" ->
        {:stop, :unsupported_http3_alpn, state}

      metadata[:tls_complete] != true or metadata[:parameters_valid] != true ->
        {:stop, :http3_not_authenticated, state}

      true ->
        progress(%{state | ready: true, metadata: metadata})
    end
  end

  def handle_event({:stream_open, key, :uni}, %{control: key} = state), do: {:ok, state}

  def handle_event({:stream_open, key, kind}, state) do
    if map_size(state.streams) >= 2 * state.options.h3_limits.max_streams + 4 do
      fail(state, 0x107, :owner_stream_limit)
    else
      entry = %{
        kind: kind,
        request: nil,
        mode: nil,
        out: <<>>,
        send_fin: false,
        send_done: false,
        recv_fin: false,
        fin_pending: false,
        cancel: [],
        deadline: now() + state.options.http_limits.request_timeout,
        header_deadline: now() + state.options.http_limits.header_timeout,
        output_deadline: nil,
        work_deadline: if(kind == :uni, do: now() + state.options.http_limits.header_timeout),
        write_quantum:
          min(state.connection.limits.max_output, state.options.h3_limits.control_quantum)
      }

      state = %{
        state
        | streams: Map.put(state.streams, key, entry),
          order: :queue.in(key, state.order)
      }

      requests = Enum.count(state.streams, fn {_, stream} -> stream.kind == :bidi end)

      if kind == :bidi and requests > state.options.h3_limits.max_streams,
        do: {:ok, cancel(state, key, 0x107)},
        else: transition(state, key, Protocol.open(state.protocol, key, kind))
    end
  end

  def handle_event({:stopped, key, _code}, %{control: key} = state),
    do: fail(state, 0x104, :closed_local_control)

  def handle_event({:stopped, key, code}, state), do: peer_cancel(state, key, code)

  def handle_event({:closed, _}, state), do: {:stop, :normal, clear(state)}
  def handle_event(event, state) when event in [:tick, :writable], do: progress(state)
  def handle_event({:readable, _}, state), do: progress(state)
  def handle_event(_, state), do: {:ok, state}

  @impl true
  def terminate(_, _), do: :ok

  defp progress(%{ready: false} = state), do: {:ok, state}
  defp progress(%{closed: true} = state), do: {:stop, :normal, state}

  defp progress(state) do
    state = %{state | turn_deadline: now() + min(100, state.connection.limits.callback_timeout)}

    with {:ok, state} <- control(state) do
      if state.control == nil or state.control_bytes != <<>>,
        do: {:ok, state},
        else: turns(state, min(:queue.len(state.order), state.options.h3_limits.control_turn))
    end
  end

  defp control(%{control: nil} = state) do
    deadline = state.control_deadline || now() + state.options.http_limits.write_timeout
    state = %{state | control_deadline: deadline}

    case operation(state, :open_control, deadline, fn opts ->
           QUIC.open_stream(state.connection, :uni, opts)
         end) do
      {:ok, state, {:ok, handle}} ->
        stream =
          case handle do
            %QUIC.Stream{} = stream -> stream
            opaque -> %QUIC.Stream{handle: opaque, connection: state.connection}
          end

        # The engine may enqueue local open before an uncertain result resolves.
        # Remove that provisional peer entry before any destructive stream read.
        state = drop(state, stream)

        state = %{
          state
          | protocol: %{state.protocol | streams: Map.delete(state.protocol.streams, stream)}
        }

        control(%{state | control: stream})

      {:wait, state} ->
        {:ok, state}

      {:ok, state, {:blocked, _}} ->
        {:ok, state}

      {:ok, state, failure} ->
        fail(state, 0x102, {:control_open, failure})

      failure ->
        failure
    end
  end

  defp control(%{control_bytes: <<>>} = state), do: {:ok, state}

  defp control(state) do
    case operation(state, :control_write, state.control_deadline, fn opts ->
           QUIC.send_stream(state.control, state.control_bytes, false, opts)
         end) do
      {:ok, state, {:ok, _}} -> {:ok, %{state | control_bytes: <<>>, control_deadline: nil}}
      {:wait, state} -> {:ok, state}
      {:ok, state, {:blocked, _}} -> {:ok, state}
      {:ok, state, failure} -> fail(state, 0x102, {:control_write, failure})
      failure -> failure
    end
  end

  defp turns(state, remaining) when remaining <= 0, do: {:ok, state}

  defp turns(state, remaining) do
    if now() >= state.turn_deadline do
      {:ok, state}
    else
      case :queue.out(state.order) do
        {:empty, _} ->
          {:ok, state}

        {{:value, key}, rest} ->
          state = %{state | order: rest}

          if Map.has_key?(state.streams, key) do
            case stream_turn(state, key) do
              {:ok, next} ->
                next =
                  if Map.has_key?(next.streams, key),
                    do: %{next | order: :queue.in(key, next.order)},
                    else: next

                turns(next, remaining - 1)

              failure ->
                failure
            end
          else
            turns(state, remaining - 1)
          end
      end
    end
  end

  defp stream_turn(state, key) do
    entry = state.streams[key]

    cond do
      entry.cancel != [] ->
        cleanup_stream(state, key)

      entry.kind == :uni and entry.work_deadline != nil and now() >= entry.work_deadline ->
        fail(state, 0x107, :incomplete_uni_timeout)

      entry.kind == :bidi and now() >= entry.deadline ->
        cleanup_stream(cancel(state, key, 0x10C), key)

      entry.kind == :bidi and entry.request == nil and now() >= entry.header_deadline ->
        cleanup_stream(cancel(state, key, 0x10C), key)

      true ->
        with {:ok, state} <- flush(state, key),
             {:ok, state} <- receive_stream(state, key),
             {:ok, state} <- flush(state, key),
             do: {:ok, retire(state, key)}
    end
  end

  defp receive_stream(state, key) do
    case state.streams[key] do
      nil ->
        {:ok, state}

      %{cancel: [_ | _]} ->
        {:ok, state}

      %{recv_fin: true} ->
        {:ok, state}

      entry ->
        # Preserve the exact write completion while its admission is uncertain.
        # Reserve one read quantum plus DATA framing before consuming application bytes.
        credit = state.options.h3_limits.max_pending_output - byte_size(entry.out) - 32

        if Map.has_key?(state.pending, {key, :write}) or
             (entry.kind == :bidi and credit < state.options.http_limits.max_read_chunk) do
          {:ok, state}
        else
          before = state.protocol.streams[key]

          with {:ok, state} <- transition(state, key, Protocol.feed(state.protocol, key, <<>>)) do
            after_feed = state.protocol.streams[key]

            cond do
              state.streams[key] == nil or state.streams[key].cancel != [] ->
                {:ok, state}

              before != after_feed ->
                {:ok, state}

              entry.fin_pending ->
                finish_receive(state, key)

              true ->
                read_stream(state, key, min(credit, state.options.http_limits.max_read_chunk))
            end
          end
        end
    end
  end

  defp read_stream(state, key, maximum) do
    deadline = now() + state.options.http_limits.read_timeout

    case operation(state, {key, :read}, deadline, fn opts -> QUIC.read(key, maximum, opts) end) do
      {:ok, state, {:ok, items}} ->
        Enum.reduce_while(items, {:ok, state}, fn item, {:ok, acc} ->
          case read_item(acc, key, item) do
            {:ok, next} -> {:cont, {:ok, next}}
            failure -> {:halt, failure}
          end
        end)

      {:wait, state} ->
        {:ok, state}

      {:ok, state, {:blocked, _}} ->
        {:ok, state}

      {:ok, state, {:error, :not_established}} ->
        {:stop, :normal, clear(state)}

      {:ok, state, {:error, :invalid_operation}} ->
        {:stop, :normal, clear(state)}

      {:ok, state, failure} ->
        fail(state, 0x102, {:read, failure})

      failure ->
        failure
    end
  end

  defp read_item(state, key, {:data, _id, bytes}) do
    if state.streams[key] == nil or state.streams[key].cancel != [],
      do: {:ok, state},
      else: transition(state, key, Protocol.feed(state.protocol, key, bytes))
  end

  defp read_item(state, key, {:fin, _id}) do
    {:ok, update_entry(state, key, &%{&1 | fin_pending: true})}
  end

  defp read_item(state, key, {:reset, _id, code, _final_size}),
    do: peer_cancel(state, key, code)

  defp finish_receive(state, key) do
    with {:ok, state} <- transition(state, key, Protocol.fin(state.protocol, key)) do
      {:ok, update_entry(state, key, &%{&1 | recv_fin: true, fin_pending: false})}
    end
  end

  defp transition(state, key, {:ok, protocol, actions}) do
    Enum.reduce_while(actions, {:ok, %{state | protocol: protocol}}, fn action, {:ok, acc} ->
      case action(acc, action) do
        {:ok, next} -> {:cont, {:ok, next}}
        failure -> {:halt, failure}
      end
    end)
    |> case do
      {:ok, next} -> {:ok, work_deadline(next, key)}
      failure -> failure
    end
  end

  defp transition(state, key, {:error, :stream, code, _reason, protocol}),
    do: {:ok, cancel(%{state | protocol: protocol}, key, code)}

  defp transition(state, _, {:error, :connection, code, reason, protocol}),
    do: fail(%{state | protocol: protocol}, code, reason)

  defp action(state, {:headers, key, request}) do
    {status, body, mode} =
      case {request.method, request.path} do
        {"GET", "/ok"} -> {200, "ok", :discard}
        {"HEAD", "/ok"} -> {200, <<>>, :discard}
        {"POST", "/echo"} -> {200, <<>>, :echo}
        {"CONNECT", _} -> {501, <<>>, :discard}
        _ -> {404, <<>>, :discard}
      end

    {:ok, block} = Qpack.encode_header_block([{":status", Integer.to_string(status)}])
    bytes = Frame.encode!(:headers, block)
    bytes = if body == <<>>, do: bytes, else: bytes <> Frame.encode!(:data, body)

    state =
      update_entry(state, key, &%{&1 | request: request, mode: mode, send_fin: mode != :echo})

    enqueue(state, key, bytes)
  end

  defp action(state, {:data, key, bytes}) do
    if state.streams[key].mode == :echo,
      do: enqueue(state, key, Frame.encode!(:data, bytes)),
      else: {:ok, state}
  end

  defp action(state, {:trailers, key, fields}) do
    if state.streams[key].mode == :echo do
      {:ok, block} = Qpack.encode_header_block(fields)
      enqueue(state, key, Frame.encode!(:headers, block))
    else
      {:ok, state}
    end
  end

  defp action(state, {:complete, key}),
    do:
      {:ok,
       update_entry(
         state,
         key,
         &%{
           &1
           | send_fin: true,
             output_deadline:
               &1.output_deadline || now() + state.options.http_limits.write_timeout
         }
       )}

  defp action(state, {:cancelled, key}), do: {:ok, cancel(state, key, 0x10C)}
  defp action(state, {:discard, key}), do: {:ok, cancel(state, key, 0x100, [:stop])}
  defp action(state, {:settings, _}), do: {:ok, state}
  defp action(state, {:goaway, _}), do: {:ok, state}

  defp enqueue(state, key, bytes) do
    entry = state.streams[key]

    if byte_size(entry.out) + byte_size(bytes) <= state.options.h3_limits.max_pending_output do
      {:ok,
       update_entry(
         state,
         key,
         &%{
           &1
           | out: &1.out <> bytes,
             output_deadline:
               &1.output_deadline || now() + state.options.http_limits.write_timeout
         }
       )}
    else
      {:ok, cancel(state, key, 0x107)}
    end
  end

  defp flush(state, key) do
    case state.streams[key] do
      nil ->
        {:ok, state}

      %{cancel: [_ | _]} ->
        {:ok, state}

      %{send_done: true} ->
        {:ok, state}

      %{out: <<>>, send_fin: false} ->
        {:ok, state}

      entry ->
        size =
          min(
            byte_size(entry.out),
            entry.write_quantum
          )

        <<chunk::binary-size(size), rest::binary>> = entry.out
        fin = entry.send_fin and rest == <<>>

        case operation(state, {key, :write}, entry.output_deadline, fn opts ->
               QUIC.send_stream(key, chunk, fin, opts)
             end) do
          {:ok, state, {:ok, _}} ->
            {:ok,
             update_entry(
               state,
               key,
               &%{
                 &1
                 | out: rest,
                   send_done: fin,
                   write_quantum:
                     min(
                       2 * &1.write_quantum,
                       min(
                         state.connection.limits.max_output,
                         state.options.h3_limits.control_quantum
                       )
                     ),
                   output_deadline: if(rest == <<>>, do: nil, else: &1.output_deadline)
               }
             )}

          {:wait, state} ->
            {:ok, state}

          {:ok, state, {:blocked, _}} ->
            {:ok, update_entry(state, key, &%{&1 | write_quantum: max(1, div(size, 2))})}

          {:ok, state, {:error, :stopped}} ->
            {:ok, cancel(state, key, 0x10C)}

          {:ok, state, {:error, :not_established}} ->
            {:stop, :normal, clear(state)}

          {:ok, state, failure} ->
            fail(state, 0x102, {:write, failure})

          failure ->
            failure
        end
    end
  end

  defp peer_cancel(state, key, code) do
    case state.streams[key] do
      # A reflexive peer event must not replace the first terminal decision or
      # requeue an admitted command while its remaining cleanup is unresolved.
      %{cancel: [_ | _]} ->
        {:ok, state}

      _ ->
        case transition(state, key, Protocol.reset(state.protocol, key)) do
          {:ok, next} -> {:ok, cancel(next, key, code)}
          failure -> failure
        end
    end
  end

  defp cancel(state, key, code, commands \\ [:reset, :stop]) do
    state = %{
      state
      | protocol: %{state.protocol | streams: Map.delete(state.protocol.streams, key)}
    }

    update_entry(
      state,
      key,
      &%{
        &1
        | out: <<>>,
          send_fin: false,
          cancel: Enum.map(commands, fn kind -> {kind, code} end),
          output_deadline: &1.output_deadline || now() + state.options.http_limits.write_timeout
      }
    )
  end

  defp cleanup_stream(state, key) do
    entry = state.streams[key]
    [{kind, code} | rest] = entry.cancel

    case operation(state, {key, kind}, entry.output_deadline, fn opts ->
           case kind do
             :reset -> QUIC.reset_stream(key, code, opts)
             :stop -> QUIC.stop_stream(key, code, opts)
           end
         end) do
      {:ok, state, {:ok, _}} ->
        if rest == [],
          do: {:ok, drop(state, key)},
          else: {:ok, update_entry(state, key, &%{&1 | cancel: rest})}

      {:wait, state} ->
        {:ok, state}

      {:ok, state, {:blocked, _}} ->
        {:ok, state}

      {:ok, state, {:error, :stopped}} ->
        if rest == [],
          do: {:ok, drop(state, key)},
          else: {:ok, update_entry(state, key, &%{&1 | cancel: rest})}

      {:ok, state, failure} ->
        fail(state, 0x102, {:cancel, failure})

      failure ->
        failure
    end
  end

  # Each uncertain reference is polled, never resubmitted. Its original deadline
  # stays fixed, including when a public read may have consumed bytes already.
  defp operation(state, key, deadline, fun) do
    case state.pending[key] do
      {reference, original_deadline} ->
        if now() >= original_deadline do
          fail(state, 0x102, :operation_timeout)
        else
          case QUIC.operation_status(state.connection, reference) do
            %{result: result} -> {:ok, %{state | pending: Map.delete(state.pending, key)}, result}
            :unknown -> {:wait, state}
            failure -> fail(state, 0x102, {:operation_status, failure})
          end
        end

      nil ->
        cond do
          now() >= deadline ->
            fail(state, 0x102, :operation_timeout)

          now() >= state.turn_deadline ->
            {:wait, state}

          true ->
            case fun.(
                   timeout: min(50, state.connection.limits.callback_timeout),
                   deadline: max(1, min(deadline, state.turn_deadline) - now())
                 ) do
              {:unknown, reference} ->
                {:wait, %{state | pending: Map.put(state.pending, key, {reference, deadline})}}

              {:blocked, _} = result ->
                {:ok, state, result}

              result ->
                {:ok, state, result}
            end
        end
    end
  end

  defp work_deadline(state, key) do
    case state.protocol.streams[key] do
      %{kind: kind} = parser when kind != :request ->
        incomplete =
          case parser.phase do
            :type -> parser.buffer != <<>>
            :qpack -> parser.buffer != <<>>
            _ -> true
          end

        update_entry(state, key, fn entry ->
          %{
            entry
            | work_deadline:
                if(incomplete,
                  do: entry.work_deadline || now() + state.options.http_limits.request_timeout,
                  else: nil
                )
          }
        end)

      _ ->
        state
    end
  end

  defp retire(state, key) do
    case state.streams[key] do
      %{recv_fin: true, send_done: true} -> drop(state, key)
      %{recv_fin: true, kind: :uni} -> drop(state, key)
      _ -> state
    end
  end

  defp drop(state, key),
    do: %{
      state
      | streams: Map.delete(state.streams, key),
        pending:
          Map.reject(state.pending, fn {slot, _} -> is_tuple(slot) and elem(slot, 0) == key end)
    }

  defp update_entry(state, key, fun) do
    if Map.has_key?(state.streams, key),
      do: %{state | streams: Map.update!(state.streams, key, fun)},
      else: state
  end

  defp fail(state, code, reason) do
    _ =
      QUIC.close(state.connection, code, <<>>,
        timeout: min(50, state.connection.limits.callback_timeout)
      )

    {:stop, {:http3, code, reason}, clear(state)}
  end

  defp clear(state),
    do: %{
      state
      | streams: %{},
        protocol: %{state.protocol | streams: %{}},
        order: :queue.new(),
        pending: %{},
        control: nil,
        control_bytes: <<>>,
        closed: true
    }

  defp now, do: System.monotonic_time(:millisecond)
end
