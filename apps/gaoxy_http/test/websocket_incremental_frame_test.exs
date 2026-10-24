defmodule Gaoxy.HTTP.WebSocket.IncrementalFrameTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.WebSocket.{Frame, Message}

  test "split headers and mask keys deliver payload before the frame is complete" do
    wire = masked(2, "abcdefghij")
    <<header::binary-size(6), first::binary-size(3), rest::binary>> = wire

    decoder =
      for <<byte <- header>>, reduce: Frame.decoder() do
        decoder ->
          assert {:ok, events, decoder} = Frame.consume(decoder, <<byte>>)
          assert events in [[], [{:start, :binary, true, 10}]]
          decoder
      end

    assert {:ok, [{:payload, "abc"}], decoder} = Frame.consume(decoder, first)
    assert {:ok, [{:payload, "defghij"}, :end], decoder} = Frame.consume(decoder, rest)
    assert {:ok, [], _} = Frame.consume(decoder, "")
  end

  test "mask offsets survive every input boundary across successive frames" do
    payload = :binary.list_to_bin(Enum.to_list(0..255))
    wire = masked(2, payload) <> masked(9, "ping") <> masked(2, "next")

    for quantum <- [1, 2, 3, 5, 17, 129] do
      {events, _} = consume_chunks(wire, quantum)

      assert [{:data, :binary, ^payload}, {:control, :ping, "ping"}, {:data, :binary, "next"}] =
               messages(events)
    end
  end

  test "partial payload retention belongs to the message immediately" do
    assert {:ok, [{:start, :binary, true, 12}, {:payload, "part"}], _} =
             Frame.consume(Frame.decoder(), binary_part(masked(2, "partrestdata"), 0, 10))

    assert {:ok, nil, state} = Message.consume(Message.new(), {:start, :binary, true, 12})
    assert {:ok, nil, %{bytes: 4}} = Message.consume(state, {:payload, "part"})
  end

  test "UTF-8 can cross reads and actual fragments with interleaved controls" do
    wire =
      masked(1, <<0xE2>>, false) <>
        masked(9, "p") <>
        masked(0, "", false) <> masked(0, <<0x82, 0xAC>>)

    {events, _} = consume_chunks(wire, 1)
    assert [{:control, :ping, "p"}, {:data, :text, "€"}] = messages(events)
  end

  test "empty fragments do not accumulate retained payload entries" do
    state =
      Enum.reduce(1..256, Message.new(), fn index, state ->
        opcode = if index == 1, do: :binary, else: :continuation
        assert {:ok, nil, state} = Message.push(state, %{opcode: opcode, fin: false, payload: ""})
        assert state.parts == []
        state
      end)

    assert {:ok, {:data, :binary, "done"}, _} =
             Message.push(state, %{opcode: :continuation, fin: true, payload: "done"})
  end

  test "omitted policies accept messages above the previous byte and fragment ceilings" do
    payload = :binary.copy("a", 1_048_577)

    assert {:ok, {:data, :binary, ^payload}, _} =
             Message.push(Message.new(), %{opcode: :binary, fin: true, payload: payload})

    {events, _} = consume_chunks(masked(2, payload), 4096)
    assert [{:data, :binary, ^payload}] = messages(events)

    assert {:ok, %{payload: ^payload}, "tail"} =
             Frame.decode(masked(2, payload) <> "tail", :infinity)
  end

  test "valid 63-bit advertised lengths do not require retaining a complete frame" do
    length = 9_223_372_036_854_775_807
    header = <<0x82, 0xFF, length::64, 1, 2, 3, 4>>

    assert {:ok, [{:start, :binary, true, ^length}], decoder} =
             Frame.consume(Frame.decoder(), header)

    assert {:ok, [{:payload, "a"}], _} = Frame.consume(decoder, <<Bitwise.bxor(?a, 1)>>)
  end

  test "explicit frame, message and fragment policies still reject oversized input" do
    assert {:error, 1009, :frame_limit} =
             Frame.consume(Frame.decoder(max_frame_size: 3), masked(2, "four"))

    assert {:ok, nil, state} =
             Message.consume(Message.new(max_message_bytes: 3), {:start, :binary, true, 4})

    assert {:error, 1009, :message_limit} = Message.consume(state, {:payload, "four"})

    assert {:ok, nil, state} =
             Message.push(Message.new(max_fragments: 1), %{
               opcode: :binary,
               fin: false,
               payload: ""
             })

    assert {:error, 1009, :fragment_limit} =
             Message.consume(state, {:start, :continuation, true, 0})
  end

  test "mandatory framing rejection survives incremental parsing" do
    for wire <- [
          <<0x81, 0>>,
          <<0xC1, 0x80>>,
          <<0x83, 0x80>>,
          <<0x09, 0x80>>,
          <<0x89, 0xFE, 126::16>>,
          <<0x81, 0xFE, 1::16>>,
          <<0x81, 0xFF, 1::64>>,
          <<0x81, 0xFF, 1::1, 0::63>>
        ] do
      assert {:error, 1002, _} = Frame.consume(Frame.decoder(), wire)
    end
  end

  test "control payloads are validated completely before emitting" do
    wire = masked(8, <<1000::16, "bye">>)
    <<first::binary-size(8), rest::binary>> = wire
    assert {:ok, [], decoder} = Frame.consume(Frame.decoder(), first)
    assert {:ok, [{:control, :close, <<1000::16, "bye">>}], _} = Frame.consume(decoder, rest)

    for payload <- [<<1>>, <<1005::16>>, <<999::16>>, <<5000::16>>] do
      assert {:error, 1002, _} = Frame.consume(Frame.decoder(), masked(8, payload))
    end

    assert {:error, 1007, :invalid_utf8} =
             Frame.consume(Frame.decoder(), masked(8, <<1000::16, 255>>))
  end

  test "incremental messages preserve ordering and final UTF-8 rejection" do
    assert {:error, 1002, :fragment_order} = Message.push(Message.new(), %{opcode: :unknown})

    assert {:error, 1002, :fragment_order} =
             Message.consume(Message.new(), {:start, :continuation, true, 0})

    assert {:ok, nil, state} = Message.consume(Message.new(), {:start, :binary, false, 0})
    assert {:ok, nil, state} = Message.consume(state, :end)
    assert {:error, 1002, :fragment_order} = Message.consume(state, {:start, :text, true, 0})
    assert {:ok, nil, state} = Message.consume(Message.new(), {:start, :text, true, 1})
    assert {:ok, nil, state} = Message.consume(state, {:payload, <<255>>})
    assert {:error, 1007, :invalid_utf8} = Message.consume(state, :end)
  end

  test "encoder traverses nested and improper iodata in bounded wire chunks" do
    payload = [:binary.copy("a", 300 * 1024), [0, [1, 255 | "tail"]], [], "end"]
    binary = IO.iodata_to_binary(payload)
    assert {:ok, cursor} = Frame.encoder(:binary, payload)
    assert cursor.bytes == byte_size(binary) + 10

    for quantum <- [1, 7, 4096] do
      chunks = encoded_chunks(cursor, quantum)
      assert Enum.all?(chunks, &(byte_size(&1) in 1..quantum))
      assert IO.iodata_to_binary(chunks) == <<0x82, 127, byte_size(binary)::64, binary::binary>>
    end
  end

  test "encoder validates text across iodata boundaries before transmission" do
    assert {:ok, cursor} = Frame.encoder(:text, [<<0xE2>>, [<<0x82>>, <<0xAC>>]])
    assert IO.iodata_to_binary(encoded_chunks(cursor, 1)) == <<0x81, 3, "€">>
    assert {:error, 1007, :invalid_utf8} = Frame.encoder(:text, ["ok", <<255>>])
    assert {:error, 1007, :invalid_utf8} = Frame.encoder(:text, [<<0xE2>>])
    assert {:ok, _} = Frame.encoder(:text, <<0xE2>>, false)
    assert {:error, 1002, :control_frame} = Frame.encoder(:ping, :binary.copy("p", 126))
    assert {:error, 1002, :close_code} = Frame.encoder(:close, <<1005::16>>)
    assert {:error, 1002, :opcode} = Frame.encoder(:unknown, "")
  end

  test "encoder emits empty data and control frames exactly once" do
    for opcode <- [:binary, :ping, :close] do
      assert {:ok, cursor} = Frame.encoder(opcode, [])
      assert {:ok, expected} = Frame.encode(opcode, [])
      assert IO.iodata_to_binary(encoded_chunks(cursor, 1)) == expected
    end
  end

  test "text validation carries partial UTF-8 across bounded validation chunks" do
    payload = [:binary.copy("x", 4095), <<0xE2>>, [<<0x82>>, <<0xAC>>], :binary.copy("y", 4096)]
    binary = IO.iodata_to_binary(payload)
    assert {:ok, cursor} = Frame.encoder(:text, payload)

    assert IO.iodata_to_binary(encoded_chunks(cursor, 13)) ==
             <<0x81, 126, byte_size(binary)::16, binary::binary>>

    assert {:error, 1007, :invalid_utf8} =
             Frame.encoder(:text, [:binary.copy("x", 4095), <<0xE2>>])

    assert {:error, 1007, :invalid_utf8} =
             Frame.encoder(:text, [:binary.copy("x", 4095), <<0xE2, 0>>])
  end

  defp consume_chunks(wire, quantum) do
    wire
    |> binary_chunks(quantum)
    |> Enum.reduce({[], Frame.decoder()}, fn chunk, {events, decoder} ->
      assert {:ok, next, decoder} = Frame.consume(decoder, chunk)
      {events ++ next, decoder}
    end)
  end

  defp messages(events) do
    {messages, _} =
      Enum.reduce(events, {[], Message.new()}, fn event, {messages, state} ->
        assert {:ok, result, state} = Message.consume(state, event)
        {if(is_nil(result), do: messages, else: [result | messages]), state}
      end)

    Enum.reverse(messages)
  end

  defp encoded_chunks(cursor, quantum) do
    case Frame.next_chunk(cursor, quantum) do
      :done -> []
      {:ok, chunk, cursor} -> [chunk | encoded_chunks(cursor, quantum)]
    end
  end

  defp binary_chunks("", _), do: []

  defp binary_chunks(binary, quantum) do
    size = min(byte_size(binary), quantum)
    <<chunk::binary-size(size), rest::binary>> = binary
    [chunk | binary_chunks(rest, quantum)]
  end

  defp masked(opcode, payload, fin \\ true) do
    size = byte_size(payload)
    final = if fin, do: 1, else: 0

    prefix =
      cond do
        size < 126 -> <<final::1, 0::3, opcode::4, 1::1, size::7>>
        size <= 65_535 -> <<final::1, 0::3, opcode::4, 1::1, 126::7, size::16>>
        true -> <<final::1, 0::3, opcode::4, 1::1, 127::7, size::64>>
      end

    encoded =
      for {byte, index} <- Enum.with_index(:binary.bin_to_list(payload)),
          into: <<>>,
          do: <<Bitwise.bxor(byte, rem(index, 4) + 1)>>

    prefix <> <<1, 2, 3, 4>> <> encoded
  end
end
