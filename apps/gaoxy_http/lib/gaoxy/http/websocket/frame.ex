defmodule Gaoxy.HTTP.WebSocket.Frame do
  @moduledoc "RFC 6455 framing: masked client input, unmasked server output, no extensions."
  import Bitwise
  defstruct [:opcode, :payload, fin: true]
  @opcodes %{0 => :continuation, 1 => :text, 2 => :binary, 8 => :close, 9 => :ping, 10 => :pong}

  def decode(bytes, _limit) when byte_size(bytes) < 2, do: :more

  def decode(<<fin::1, rsv::3, opcode::4, mask::1, length::7, rest::binary>>, limit) do
    with :ok <- validate_header(fin, rsv, opcode, mask, length),
         {:ok, length, rest} <- length(length, rest),
         true <- within_limit?(length, limit) || {:error, 1009, :frame_limit} do
      if byte_size(rest) < length + 4 do
        :more
      else
        <<key::32, payload::binary-size(^length), tail::binary>> = rest
        payload = unmask(payload, key)

        with :ok <- validate_payload(@opcodes[opcode], payload) do
          {:ok, %__MODULE__{fin: fin == 1, opcode: @opcodes[opcode], payload: payload},
           :binary.copy(tail)}
        end
      end
    end
  end

  @doc false
  def decoder(options \\ []) do
    %{
      phase: :header,
      buffer: "",
      limit: Keyword.get(options, :max_frame_size, :infinity)
    }
  end

  @doc false
  def consume(decoder, bytes) when is_binary(bytes), do: consume(decoder, bytes, [])

  defp consume(%{phase: :header} = decoder, "", events),
    do: {:ok, Enum.reverse(events), decoder}

  defp consume(%{phase: :header} = decoder, <<byte, rest::binary>>, events) do
    buffer = decoder.buffer <> <<byte>>

    case incremental_header(buffer, decoder.limit) do
      :more ->
        consume(%{decoder | buffer: buffer}, rest, events)

      {:ok, opcode, fin, size, key} ->
        control = opcode in [:close, :ping, :pong]

        decoder = %{
          phase: if(control, do: :control, else: :data),
          buffer: "",
          limit: decoder.limit,
          opcode: opcode,
          fin: fin,
          left: size,
          key: key,
          offset: 0
        }

        events = if control, do: events, else: [{:start, opcode, fin, size} | events]
        consume(decoder, rest, events)

      {:error, _, _} = error ->
        error
    end
  end

  defp consume(%{left: 0, phase: :data} = decoder, rest, events),
    do: consume(decoder(max_frame_size: decoder.limit), rest, [:end | events])

  defp consume(%{left: 0, phase: :control} = decoder, rest, events) do
    with :ok <- validate_payload(decoder.opcode, decoder.buffer) do
      event = {:control, decoder.opcode, decoder.buffer}
      consume(decoder(max_frame_size: decoder.limit), rest, [event | events])
    end
  end

  defp consume(decoder, "", events), do: {:ok, Enum.reverse(events), decoder}

  defp consume(decoder, bytes, events) do
    size = min(decoder.left, byte_size(bytes))
    <<part::binary-size(size), rest::binary>> = bytes
    payload = unmask(part, decoder.key, decoder.offset)
    decoder = %{decoder | left: decoder.left - size, offset: rem(decoder.offset + size, 4)}

    if decoder.phase == :control do
      consume(%{decoder | buffer: decoder.buffer <> payload}, rest, events)
    else
      consume(decoder, rest, [{:payload, payload} | events])
    end
  end

  defp incremental_header(bytes, _) when byte_size(bytes) < 2, do: :more

  defp incremental_header(<<fin::1, rsv::3, opcode::4, mask::1, size::7, rest::binary>>, limit) do
    with :ok <- validate_header(fin, rsv, opcode, mask, size),
         {:ok, size, rest} <- length(size, rest),
         true <- within_limit?(size, limit) || {:error, 1009, :frame_limit} do
      case rest do
        <<key::32>> -> {:ok, @opcodes[opcode], fin == 1, size, key}
        _ -> :more
      end
    end
  end

  @doc false
  def encoder(opcode, payload, fin \\ true) do
    code = Enum.find_value(@opcodes, fn {code, name} -> if name == opcode, do: code end)
    final = if fin, do: 1, else: 0
    size = IO.iodata_length(payload)

    with true <- not is_nil(code) || {:error, 1002, :opcode},
         :ok <- validate_header(final, 0, code, 1, min(size, 126)),
         true <- size < 9_223_372_036_854_775_808 || {:error, 1002, :invalid_length},
         :ok <- validate_output(opcode, fin, payload) do
      prefix =
        cond do
          size < 126 -> <<final::1, 0::3, code::4, 0::1, size::7>>
          size <= 65_535 -> <<final::1, 0::3, code::4, 0::1, 126::7, size::16>>
          true -> <<final::1, 0::3, code::4, 0::1, 127::7, size::64>>
        end

      {:ok, %{stack: [prefix, payload], bytes: byte_size(prefix) + size}}
    end
  end

  @doc false
  def next_chunk(%{bytes: 0}, quantum) when is_integer(quantum) and quantum > 0, do: :done

  def next_chunk(cursor, quantum) when is_integer(quantum) and quantum > 0 do
    {parts, stack, left} = take(cursor.stack, quantum, [])
    chunk = IO.iodata_to_binary(Enum.reverse(parts))
    {:ok, chunk, %{cursor | stack: stack, bytes: cursor.bytes - (quantum - left)}}
  end

  def encode(opcode, payload, fin \\ true) do
    with {:ok, cursor} <- encoder(opcode, payload, fin) do
      {:ok, cursor.stack |> IO.iodata_to_binary()}
    end
  end

  defp take(stack, 0, parts), do: {parts, stack, 0}
  defp take([], left, parts), do: {parts, [], left}
  defp take([[] | stack], left, parts), do: take(stack, left, parts)
  defp take([<<>> | stack], left, parts), do: take(stack, left, parts)

  defp take([[head | tail] | stack], left, parts),
    do: take([head, tail | stack], left, parts)

  defp take([byte | stack], left, parts) when is_integer(byte),
    do: take(stack, left - 1, [byte | parts])

  defp take([binary | stack], left, parts) when byte_size(binary) <= left,
    do: take(stack, left - byte_size(binary), [binary | parts])

  defp take([binary | stack], left, parts) do
    <<part::binary-size(left), rest::binary>> = binary
    {[part | parts], [rest | stack], 0}
  end

  defp validate_output(:text, true, payload),
    do: validate_text_cursor(%{stack: [payload], bytes: IO.iodata_length(payload)}, "")

  defp validate_output(opcode, _, payload) when opcode in [:close, :ping, :pong],
    do: validate_payload(opcode, IO.iodata_to_binary(payload))

  defp validate_output(_, _, _), do: :ok

  defp validate_text_cursor(cursor, carry) do
    case next_chunk(cursor, 4096) do
      :done ->
        if carry == "", do: :ok, else: {:error, 1007, :invalid_utf8}

      {:ok, chunk, cursor} ->
        case :unicode.characters_to_binary(carry <> chunk, :utf8, :utf8) do
          binary when is_binary(binary) -> validate_text_cursor(cursor, "")
          {:incomplete, _, tail} -> validate_text_cursor(cursor, tail)
          {:error, _, _} -> {:error, 1007, :invalid_utf8}
        end
    end
  end

  defp within_limit?(_, :infinity), do: true
  defp within_limit?(size, limit), do: size <= limit

  defp validate_header(fin, rsv, opcode, mask, length) do
    cond do
      rsv != 0 -> {:error, 1002, :reserved_bits}
      not is_map_key(@opcodes, opcode) -> {:error, 1002, :opcode}
      mask != 1 -> {:error, 1002, :unmasked_client}
      opcode >= 8 and (fin != 1 or length > 125) -> {:error, 1002, :control_frame}
      true -> :ok
    end
  end

  defp length(size, rest) when size < 126, do: {:ok, size, rest}
  defp length(126, <<size::16, rest::binary>>) when size >= 126, do: {:ok, size, rest}
  defp length(126, rest) when byte_size(rest) >= 2, do: {:error, 1002, :nonminimal_length}
  defp length(127, <<0::1, size::63, rest::binary>>) when size >= 65_536, do: {:ok, size, rest}
  defp length(127, rest) when byte_size(rest) >= 8, do: {:error, 1002, :invalid_length}
  defp length(_, _), do: :more

  defp unmask(payload, key), do: unmask(payload, key, 0)

  defp unmask(payload, key, offset) do
    mask = <<key::32>>
    <<before::binary-size(offset), after_offset::binary>> = mask
    <<key::32>> = after_offset <> before
    size = div(byte_size(payload), 4) * 4
    <<blocks::binary-size(^size), tail::binary>> = payload
    unmasked = for <<word::32 <- blocks>>, into: <<>>, do: <<bxor(word, key)::32>>
    mask = <<key::32>>

    suffix =
      for {byte, index} <- Enum.with_index(:binary.bin_to_list(tail)),
          into: <<>>,
          do: <<bxor(byte, :binary.at(mask, index))>>

    unmasked <> suffix
  end

  defp validate_payload(:close, <<>>), do: :ok
  defp validate_payload(:close, <<_>>), do: {:error, 1002, :close_payload}

  defp validate_payload(:close, <<code::16, reason::binary>>) do
    cond do
      code not in [1000, 1001, 1002, 1003, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014] and
          code not in 3000..4999 ->
        {:error, 1002, :close_code}

      not String.valid?(reason) ->
        {:error, 1007, :invalid_utf8}

      true ->
        :ok
    end
  end

  defp validate_payload(_, _), do: :ok
end
