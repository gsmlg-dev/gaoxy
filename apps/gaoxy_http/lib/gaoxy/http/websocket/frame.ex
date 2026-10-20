defmodule Gaoxy.HTTP.WebSocket.Frame do
  @moduledoc "RFC 6455 framing: masked client input, unmasked server output, no extensions."
  import Bitwise
  defstruct [:opcode, :payload, fin: true]
  @opcodes %{0 => :continuation, 1 => :text, 2 => :binary, 8 => :close, 9 => :ping, 10 => :pong}

  def decode(bytes, limit) when byte_size(bytes) < 2 and is_integer(limit), do: :more

  def decode(<<fin::1, rsv::3, opcode::4, mask::1, length::7, rest::binary>>, limit) do
    with :ok <- validate_header(fin, rsv, opcode, mask, length),
         {:ok, length, rest} <- length(length, rest),
         true <- length <= limit || {:error, 1009, :frame_limit} do
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

  def encode(opcode, payload, fin \\ true) do
    payload = IO.iodata_to_binary(payload)
    code = Enum.find_value(@opcodes, fn {code, name} -> if name == opcode, do: code end)
    final = if fin, do: 1, else: 0
    size = byte_size(payload)

    with true <- not is_nil(code) || {:error, 1002, :opcode},
         :ok <- validate_header(final, 0, code, 1, min(size, 126)),
         :ok <- validate_text(opcode, fin, payload),
         :ok <- validate_payload(opcode, payload) do
      prefix =
        cond do
          size < 126 -> <<final::1, 0::3, code::4, 0::1, size::7>>
          size <= 65_535 -> <<final::1, 0::3, code::4, 0::1, 126::7, size::16>>
          true -> <<final::1, 0::3, code::4, 0::1, 127::7, size::64>>
        end

      {:ok, prefix <> payload}
    end
  end

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

  defp unmask(payload, key) do
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

  defp validate_text(:text, true, payload),
    do: if(String.valid?(payload), do: :ok, else: {:error, 1007, :invalid_utf8})

  defp validate_text(_, _, _), do: :ok
end
