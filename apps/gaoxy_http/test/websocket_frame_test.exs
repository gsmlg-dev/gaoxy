defmodule Gaoxy.HTTP.WebSocket.FrameTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.WebSocket.{Frame, Message}

  test "masked frames parse at every delivery boundary and retain following bytes" do
    for data <- ["hello", String.duplicate("a", 126), String.duplicate("b", 65_536)] do
      wire = masked(1, data)

      for size <- Enum.uniq([0, 1, 2, 3, 5, 8, byte_size(wire) - 1]) do
        assert :more = Frame.decode(binary_part(wire, 0, size), 100_000)
      end

      assert {:ok, %{opcode: :text, fin: true, payload: ^data}, "NEXT"} =
               Frame.decode(wire <> "NEXT", 100_000)
    end
  end

  test "rejects unmasked, reserved, nonminimal and oversized control frames" do
    for wire <- [
          <<0x81, 0>>,
          <<0xC1, 0x80, 0::32>>,
          <<0x83, 0x80, 0::32>>,
          <<0x09, 0x80, 0::32>>,
          <<0x89, 0xFE, 126::16>>,
          <<0x81, 0xFE, 1::16>>,
          <<0x81, 0xFF, 1::64>>,
          <<0x81, 0xFF, 1::1, 0::63>>
        ] do
      assert {:error, 1002, _} = Frame.decode(wire, 100_000)
    end

    assert {:error, 1009, :frame_limit} = Frame.decode(<<0x82, 0xFE, 1024::16>>, 100)
  end

  test "close codes and UTF-8 reasons are validated" do
    assert {:ok, %{opcode: :close, payload: ""}, ""} = Frame.decode(masked(8, ""), 1024)
    assert {:ok, %{opcode: :close}, ""} = Frame.decode(masked(8, <<1000::16, "bye">>), 1024)

    for payload <- [<<1>>, <<1005::16>>, <<999::16>>, <<5000::16>>] do
      assert {:error, 1002, _} = Frame.decode(masked(8, payload), 1024)
    end

    assert {:error, 1007, :invalid_utf8} = Frame.decode(masked(8, <<1000::16, 255>>), 1024)
  end

  test "server output is unmasked and retains binary bytes" do
    assert {:ok, <<0x82, 3, 0, 128, 255>>} = Frame.encode(:binary, <<0, 128, 255>>)

    assert {:ok, <<0x81, 126, 126::16, _::binary>>} =
             Frame.encode(:text, String.duplicate("x", 126))

    assert {:error, 1002, _} = Frame.encode(:ping, String.duplicate("x", 126))
    assert {:error, 1007, :invalid_utf8} = Frame.encode(:text, <<255>>)
  end

  test "fragmented UTF-8 is validated as a message with interleaved controls" do
    state = Message.new(max_message_bytes: 1024, max_fragments: 8)

    assert {:ok, nil, state} =
             Message.push(state, %{opcode: :text, fin: false, payload: <<0xE2>>})

    assert {:ok, {:control, :ping, "p"}, state} =
             Message.push(state, %{opcode: :ping, fin: true, payload: "p"})

    assert {:ok, {:data, :text, "€"}, state} =
             Message.push(state, %{opcode: :continuation, fin: true, payload: <<0x82, 0xAC>>})

    assert %{bytes: 0, fragments: 0} = state

    assert {:error, 1007, :invalid_utf8} =
             Message.push(state, %{opcode: :text, fin: true, payload: <<255>>})
  end

  test "continuation ordering, retained bytes and fragment counts are bounded" do
    state = Message.new(max_message_bytes: 3, max_fragments: 2)

    assert {:error, 1002, _} =
             Message.push(state, %{opcode: :continuation, fin: true, payload: "a"})

    assert {:ok, nil, state} = Message.push(state, %{opcode: :binary, fin: false, payload: "ab"})
    assert {:error, 1002, _} = Message.push(state, %{opcode: :text, fin: true, payload: "c"})

    assert {:error, 1009, :message_limit} =
             Message.push(state, %{opcode: :continuation, fin: true, payload: "cd"})

    assert {:ok, nil, state} =
             Message.push(state, %{opcode: :continuation, fin: false, payload: ""})

    assert {:error, 1009, :fragment_limit} =
             Message.push(state, %{opcode: :continuation, fin: true, payload: ""})
  end

  defp masked(opcode, payload) do
    length = byte_size(payload)

    prefix =
      cond do
        length < 126 -> <<1::1, 0::3, opcode::4, 1::1, length::7>>
        length <= 65_535 -> <<1::1, 0::3, opcode::4, 1::1, 126::7, length::16>>
        true -> <<1::1, 0::3, opcode::4, 1::1, 127::7, length::64>>
      end

    key = {1, 2, 3, 4}

    encoded =
      for {byte, index} <- Enum.with_index(:binary.bin_to_list(payload)),
          into: <<>>,
          do: <<Bitwise.bxor(byte, elem(key, rem(index, 4)))>>

    prefix <> <<1, 2, 3, 4>> <> encoded
  end
end
