defmodule Gaoxy.HTTP.HTTP3.Protocol do
  @moduledoc """
  Pure bounded HTTP/3 server transitions over opaque peer stream keys.

  `feed/3` processes a finite byte/transition quantum. The owner continues with
  an empty feed when a stream retains input, and supplies body bytes only after
  reserving application credit. No operation in this module performs I/O.
  """
  import Bitwise, only: [band: 2]
  alias Gaoxy.HTTP.HTTP3.Headers
  alias QuicHttp3.{Control, Frame, Qpack, Varint}

  defstruct [
    :http_limits,
    :h3_limits,
    :control,
    extended_connect: false,
    streams: %{},
    critical: %{},
    max_push_id: nil
  ]

  def new(%{http_limits: http, h3_limits: h3} = options) do
    enabled = Map.get(options, :extended_connect, false)
    settings = [{1, 0}, {6, http.max_header_bytes}, {7, 0}]
    settings = if enabled, do: settings ++ [{8, 1}], else: settings

    with {:ok, control} <- Control.new(:server, settings) do
      {:ok,
       %__MODULE__{http_limits: http, h3_limits: h3, control: control, extended_connect: enabled}}
    end
  end

  @doc "Marks an owner-accepted WebSocket without changing HTTP DATA framing or ingress limits."
  def websocket_open(state, key) do
    case state.streams[key] do
      %{kind: :request, message: :body, request: %{protocol: "websocket", body: :tunnel}} = stream ->
        {:ok, put_stream(state, key, %{stream | message: :websocket, body_bytes: 0})}

      _ ->
        error(state, key, :stream, 0x10E, :invalid_websocket_transition)
    end
  end

  def open(state, key, kind) when kind in [:bidi, :uni] do
    requests = Enum.count(state.streams, fn {_, stream} -> stream.kind == :request end)
    unis = map_size(state.streams) - requests

    cond do
      Map.has_key?(state.streams, key) ->
        error(state, key, :connection, 0x103, :duplicate_stream)

      kind == :bidi and requests >= state.h3_limits.max_streams ->
        error(state, key, :stream, 0x107, :request_limit)

      kind == :uni and unis >= state.h3_limits.max_streams + 3 ->
        error(state, key, :connection, 0x107, :uni_stream_limit)

      true ->
        stream = %{
          kind: if(kind == :bidi, do: :request, else: :uni),
          phase: if(kind == :bidi, do: :type, else: :uni_type),
          buffer: <<>>,
          frame_type: nil,
          remaining: 0,
          payload: <<>>,
          request: nil,
          message: :initial_headers,
          body_bytes: 0
        }

        {:ok, put_stream(state, key, stream), []}
    end
  end

  def feed(state, key, bytes) when is_binary(bytes) do
    case Map.fetch(state.streams, key) do
      :error ->
        error(state, key, :stream, 0x10C, :unknown_stream)

      {:ok, stream} ->
        if byte_size(stream.buffer) + byte_size(bytes) > state.http_limits.max_buffer_bytes do
          scope = if stream.kind in [:request, :uni], do: :stream, else: :connection
          error(state, key, scope, 0x107, :ingress_limit)
        else
          state = put_stream(state, key, %{stream | buffer: stream.buffer <> bytes})
          progress(state, key, state.h3_limits.control_turn, state.h3_limits.control_quantum, [])
        end
    end
  end

  def fin(state, key) do
    case Map.fetch(state.streams, key) do
      :error ->
        {:ok, state, []}

      {:ok, %{kind: kind}} when kind in [:control, :qpack_encoder, :qpack_decoder] ->
        error(state, key, :connection, 0x104, :closed_critical_stream)

      {:ok, %{kind: :uni}} ->
        error(state, key, :connection, 0x103, :missing_stream_type)

      {:ok, stream} ->
        cond do
          stream.phase != :type or stream.buffer != <<>> ->
            error(state, key, :connection, 0x106, :truncated_frame)

          stream.request == nil ->
            error(state, key, :stream, 0x10E, :missing_headers)

          not content_length?(stream.request.body, stream.body_bytes) ->
            error(state, key, :stream, 0x10E, :content_length)

          true ->
            {:ok, %{state | streams: Map.delete(state.streams, key)}, [{:complete, key}]}
        end
    end
  end

  def reset(state, key) do
    case Map.fetch(state.streams, key) do
      {:ok, %{kind: kind}} when kind in [:control, :qpack_encoder, :qpack_decoder] ->
        error(state, key, :connection, 0x104, :closed_critical_stream)

      _ ->
        {:ok, %{state | streams: Map.delete(state.streams, key)}, [{:cancelled, key}]}
    end
  end

  defp progress(state, _key, turns, quantum, actions) when turns <= 0 or quantum <= 0,
    do: {:ok, state, Enum.reverse(actions)}

  defp progress(state, key, turns, quantum, actions) do
    case Map.fetch(state.streams, key) do
      :error ->
        {:ok, state, Enum.reverse(actions)}

      {:ok, stream} ->
        case step(state, key, stream, quantum) do
          {:wait, next} ->
            {:ok, next, Enum.reverse(actions)}

          {:step, next, emitted, consumed} ->
            progress(next, key, turns - 1, quantum - consumed, Enum.reverse(emitted, actions))

          {:error, _, _, _, _} = failure ->
            failure
        end
    end
  end

  defp step(state, key, %{phase: :uni_type} = stream, _quantum) do
    case take_varint(stream.buffer) do
      :more ->
        {:wait, state}

      {:ok, type, rest, consumed} ->
        classify(state, key, %{stream | buffer: rest}, type, consumed)
    end
  end

  defp step(state, key, %{phase: :qpack} = stream, _quantum),
    do: qpack_instruction(state, key, stream)

  defp step(state, key, %{phase: :type} = stream, _quantum) do
    case take_varint(stream.buffer) do
      :more ->
        {:wait, state}

      {:ok, type, rest, consumed} ->
        {:step,
         put_stream(state, key, %{stream | phase: :length, frame_type: type, buffer: rest}), [],
         consumed}
    end
  end

  defp step(state, key, %{phase: :length} = stream, _quantum) do
    case take_varint(stream.buffer) do
      :more ->
        {:wait, state}

      {:ok, length, rest, consumed} ->
        stream = %{stream | remaining: length, buffer: rest}

        case frame_mode(state, stream) do
          {:ok, mode} -> {:step, put_stream(state, key, %{stream | phase: mode}), [], consumed}
          {:error, scope, code, reason} -> error(state, key, scope, code, reason)
        end
    end
  end

  defp step(state, key, stream, quantum) do
    amount = min(stream.remaining, min(byte_size(stream.buffer), quantum))

    if amount == 0 and stream.remaining > 0 do
      {:wait, state}
    else
      <<chunk::binary-size(amount), rest::binary>> = stream.buffer
      stream = %{stream | buffer: rest, remaining: stream.remaining - amount}
      payload_step(state, key, stream, chunk, amount)
    end
  end

  defp classify(state, key, stream, type, consumed) when type in [0, 2, 3] do
    kind = %{0 => :control, 2 => :qpack_encoder, 3 => :qpack_decoder}[type]

    if Map.has_key?(state.critical, kind) do
      error(state, key, :connection, 0x103, :duplicate_critical_stream)
    else
      state = %{state | critical: Map.put(state.critical, kind, key)}
      stream = %{stream | kind: kind, phase: if(kind == :control, do: :type, else: :qpack)}

      if kind == :control do
        case Control.receive_peer(state.control, key, <<0>>) do
          {:ok, control, []} ->
            {:step, put_stream(%{state | control: control}, key, stream), [], consumed}

          {:error, reason} ->
            error(state, key, :connection, 0x103, reason)
        end
      else
        {:step, put_stream(state, key, stream), [], consumed}
      end
    end
  end

  defp classify(state, key, _stream, 1, _consumed),
    do: error(state, key, :connection, 0x103, :client_push_stream)

  defp classify(state, key, _stream, _type, consumed),
    do: {:step, %{state | streams: Map.delete(state.streams, key)}, [{:discard, key}], consumed}

  defp frame_mode(_state, %{frame_type: type}) when type in [2, 6, 8, 9],
    do: {:error, :connection, 0x105, :reserved_frame}

  defp frame_mode(state, %{kind: :control, frame_type: type, remaining: length}) do
    cond do
      not state.control.received_settings? and type != 4 ->
        {:error, :connection, 0x10A, :missing_settings}

      type == 4 and state.control.received_settings? ->
        {:error, :connection, 0x105, :duplicate_settings}

      type in [0, 1, 5] ->
        {:error, :connection, 0x105, :forbidden_control_frame}

      type in [3, 7, 13] and length > 8 ->
        {:error, :connection, 0x106, :control_identifier_length}

      type == 4 and length > min(state.h3_limits.max_header_block, 65_536) ->
        {:error, :connection, 0x107, :settings_limit}

      type in [3, 4, 7, 13] ->
        {:ok, :control_frame}

      true ->
        {:ok, :skip}
    end
  end

  defp frame_mode(state, %{kind: :request, frame_type: type, remaining: length, message: message}) do
    cond do
      type in [3, 4, 5, 7, 13] ->
        {:error, :connection, 0x105, :control_frame_on_request}

      type == 0 and message not in [:body, :websocket] ->
        {:error, :connection, 0x105, :data_order}

      type == 1 and message == :websocket ->
        {:error, :stream, 0x10E, :websocket_trailers}

      type == 1 and message == :trailers ->
        {:error, :connection, 0x105, :repeated_trailers}

      type == 1 and length > state.h3_limits.max_header_block ->
        {:error, :stream, 0x107, :header_block_limit}

      type == 1 ->
        {:ok, :headers}

      type == 0 ->
        {:ok, :data}

      true ->
        {:ok, :skip}
    end
  end

  defp payload_step(state, key, %{phase: :data, message: :websocket} = stream, chunk, amount) do
    stream = if stream.remaining == 0, do: next_frame(stream), else: stream
    emitted = if amount == 0, do: [], else: [{:data, key, chunk}]
    {:step, put_stream(state, key, stream), emitted, amount}
  end

  defp payload_step(state, key, %{phase: :data} = stream, chunk, amount) do
    count = stream.body_bytes + amount

    cond do
      not within_length?(stream.request.body, count) ->
        error(state, key, :stream, 0x10E, :content_length)

      count > state.http_limits.max_body_bytes ->
        error(state, key, :stream, 0x107, :body_limit)

      true ->
        stream = %{stream | body_bytes: count}
        stream = if stream.remaining == 0, do: next_frame(stream), else: stream
        emitted = if amount == 0, do: [], else: [{:data, key, chunk}]
        {:step, put_stream(state, key, stream), emitted, amount}
    end
  end

  defp payload_step(state, key, %{phase: :skip} = stream, _chunk, amount) do
    stream = if stream.remaining == 0, do: next_frame(stream), else: stream
    {:step, put_stream(state, key, stream), [], amount}
  end

  defp payload_step(state, key, stream, chunk, amount) do
    stream = %{stream | payload: stream.payload <> chunk}

    if stream.remaining == 0 do
      complete_frame(state, key, stream, stream.payload, amount)
    else
      {:step, put_stream(state, key, stream), [], amount}
    end
  end

  defp complete_frame(state, key, %{phase: :headers} = stream, payload, consumed) do
    max_fields =
      if stream.message == :initial_headers,
        do: state.http_limits.max_headers,
        else: state.http_limits.max_trailers

    with {:ok, fields} <- Headers.decode(payload, max_fields),
         {:ok, stream, action} <- header_action(stream, fields, key, state) do
      {:step, put_stream(state, key, next_frame(stream)), [action], consumed}
    else
      {:error, scope, code, reason} -> error(state, key, scope, code, reason)
    end
  end

  defp complete_frame(state, key, %{phase: :control_frame} = stream, payload, consumed) do
    case control_frame(state, key, stream.frame_type, payload) do
      {:ok, next, actions} ->
        {:step, put_stream(next, key, next_frame(stream)), actions, consumed}

      {:error, scope, code, reason} ->
        error(state, key, scope, code, reason)
    end
  end

  defp header_action(%{message: :initial_headers} = stream, fields, key, state) do
    with {:ok, request} <- Headers.request(fields, state.http_limits, state.extended_connect),
         do: {:ok, %{stream | request: request, message: :body}, {:headers, key, request}}
  end

  defp header_action(stream, fields, key, state) do
    with :ok <- Headers.trailers(fields, state.http_limits),
         do: {:ok, %{stream | message: :trailers}, {:trailers, key, fields}}
  end

  defp control_frame(state, key, type, payload) when type in [4, 7] do
    case Control.receive_peer(state.control, key, Frame.encode!(type, payload)) do
      {:ok, control, events} ->
        {:ok, %{state | control: control}, events}

      {:error, reason} ->
        code =
          cond do
            type == 4 -> 0x109
            reason == :increasing_goaway -> 0x108
            true -> 0x106
          end

        {:error, :connection, code, reason}
    end
  end

  defp control_frame(state, _key, type, payload) when type in [3, 13] do
    case Varint.decode(payload) do
      {:ok, id, <<>>} ->
        cond do
          type == 3 ->
            {:error, :connection, 0x108, :unissued_push}

          state.max_push_id != nil and id < state.max_push_id ->
            {:error, :connection, 0x108, :decreasing_max_push_id}

          true ->
            {:ok, %{state | max_push_id: id}, []}
        end

      _ ->
        {:error, :connection, 0x106, :push_identifier}
    end
  end

  defp qpack_instruction(state, _key, %{buffer: <<>>}), do: {:wait, state}

  defp qpack_instruction(state, key, %{kind: :qpack_decoder} = stream) do
    <<first, _::binary>> = stream.buffer

    if band(first, 0xC0) == 0x40 do
      case Qpack.decode_integer(stream.buffer, 6) do
        :more ->
          {:wait, state}

        {:ok, id, rest} when id < 4_611_686_018_427_387_904 ->
          {:step, put_stream(state, key, %{stream | buffer: rest}), [],
           byte_size(stream.buffer) - byte_size(rest)}

        _ ->
          error(state, key, :connection, 0x202, :decoder_stream_identifier)
      end
    else
      error(state, key, :connection, 0x202, :unexpected_decoder_instruction)
    end
  end

  defp qpack_instruction(state, key, stream) do
    <<first, _::binary>> = stream.buffer

    if band(first, 0xE0) == 0x20 do
      case Qpack.decode_integer(stream.buffer, 5) do
        :more ->
          {:wait, state}

        {:ok, 0, rest} ->
          {:step, put_stream(state, key, %{stream | buffer: rest}), [],
           byte_size(stream.buffer) - byte_size(rest)}

        _ ->
          error(state, key, :connection, 0x201, :encoder_capacity)
      end
    else
      error(state, key, :connection, 0x201, :encoder_instruction)
    end
  end

  defp take_varint(buffer) do
    case Varint.decode(buffer) do
      {:ok, value, rest} -> {:ok, value, rest, byte_size(buffer) - byte_size(rest)}
      :more -> :more
    end
  end

  defp next_frame(stream),
    do: %{stream | phase: :type, frame_type: nil, remaining: 0, payload: <<>>}

  defp put_stream(state, key, stream), do: %{state | streams: Map.put(state.streams, key, stream)}
  defp content_length?({:length, length}, count), do: count == length
  defp content_length?(_, _), do: true
  defp within_length?({:length, length}, count), do: count <= length
  defp within_length?(_, _), do: true

  defp error(state, key, scope, code, reason) do
    next =
      if scope == :stream, do: %{state | streams: Map.delete(state.streams, key)}, else: state

    {:error, scope, code, reason, next}
  end
end
