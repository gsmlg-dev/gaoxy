defmodule Gaoxy.HTTP2CodecTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.HTTP2.{Headers, Limits}
  alias HTTP.HTTP2.HPACK

  test "RFC 7541 Huffman request vectors retain the dynamic table across blocks" do
    first = Base.decode16!("828684418CF1E3C2E5F23A6BA0AB90F4FF")
    second = Base.decode16!("828684BE5886A8EB10649CBF")
    assert {:ok, table, fields} = HPACK.decode(HPACK.new_decoder(), first)

    assert fields == [
             {":method", "GET"},
             {":scheme", "http"},
             {":path", "/"},
             {":authority", "www.example.com"}
           ]

    assert {:ok, _, fields} = HPACK.decode(table, second)
    assert List.last(fields) == {"cache-control", "no-cache"}
    assert {":authority", "www.example.com"} in fields
  end

  test "repeated dynamic indices stay within the pre-decode payload and term reservation" do
    field = {"x", String.duplicate("a", 4_000)}
    {_, encoded} = HPACK.encode_headers(HPACK.new_encoder(), [field], indexing: :incremental)
    {:ok, h2} = Limits.normalize(%{})
    decoder = HPACK.new_decoder(Limits.decoder_options(h2))
    assert {:ok, table, [^field]} = HPACK.decode(decoder, encoded)
    block = :binary.copy(<<0xBE>>, 16_384)
    assert {:ok, _, fields} = HPACK.decode(table, block)
    assert length(fields) == 16_384
    assert Headers.bytes(fields) <= byte_size(block) * (4_096 + 2)

    reserve =
      Limits.reservation(
        %{max_header_bytes: 32_768, max_read_chunk: 16_384, max_buffer_bytes: 65_536},
        h2
      )

    assert :erts_debug.flat_size(fields) * :erlang.system_info(:wordsize) +
             2 * Headers.bytes(fields) < reserve.decode
  end

  test "decoder limits retain the configured compressed-block boundary" do
    {:ok, h2} = Limits.normalize(%{max_header_block: 65_536})
    decoder = HPACK.new_decoder(Limits.decoder_options(h2))
    block = :binary.copy(<<0x82>>, h2.max_header_block)
    assert {:ok, _, fields} = HPACK.decode(decoder, block)
    assert length(fields) == h2.max_header_block
    assert Enum.all?(fields, &(&1 == {":method", "GET"}))
    assert {:error, :hpack_block_too_large} = HPACK.decode(decoder, block <> <<0x82>>)
  end

  test "decoder permits Huffman field expansion under the existing reservation bound" do
    {:ok, h2} = Limits.normalize(%{table_size: 1})
    field = {"x", String.duplicate("a", 20_000)}

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), [field], huffman: :always)

    assert byte_size(block) < h2.max_header_block
    decoder = HPACK.new_decoder(Limits.decoder_options(h2))
    assert {:ok, _, [^field]} = HPACK.decode(decoder, block)
  end

  test "malformed indices integers Huffman strings and table updates fail closed" do
    corpus = [
      <<0x80>>,
      <<0xFF>>,
      <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F>>,
      <<0x40>>,
      <<0x40, 1, ?x, 0x81, 0xFF>>,
      <<0x3F, 0xE2, 0x1F>>,
      <<0x82, 0x20>>
    ]

    for block <- corpus do
      assert {:error, _} = HPACK.decode(HPACK.new_decoder(), block)
    end
  end
end
