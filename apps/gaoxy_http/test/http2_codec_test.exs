defmodule Gaoxy.HTTP2CodecTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP2.{Headers, Limits}

  test "RFC 7541 Huffman request vectors retain the dynamic table across blocks" do
    first = Base.decode16!("828684418CF1E3C2E5F23A6BA0AB90F4FF")
    second = Base.decode16!("828684BE5886A8EB10649CBF")
    assert {:ok, fields, table} = HPAX.decode(first, HPAX.new(4_096))

    assert fields == [
             {":method", "GET"},
             {":scheme", "http"},
             {":path", "/"},
             {":authority", "www.example.com"}
           ]

    assert {:ok, fields, _} = HPAX.decode(second, table)
    assert List.last(fields) == {"cache-control", "no-cache"}
    assert {":authority", "www.example.com"} in fields
  end

  test "repeated dynamic indices stay within the pre-decode payload and term reservation" do
    field = {"x", String.duplicate("a", 4_000)}
    {encoded, _} = HPAX.encode(:store, [field], HPAX.new(4_096))
    assert {:ok, [^field], table} = HPAX.decode(IO.iodata_to_binary(encoded), HPAX.new(4_096))
    block = :binary.copy(<<0xBE>>, 16_384)
    assert {:ok, fields, _} = HPAX.decode(block, table)
    assert length(fields) == 16_384
    assert Headers.bytes(fields) <= byte_size(block) * (4_096 + 2)
    {:ok, h2} = Limits.normalize(%{})

    reserve =
      Limits.reservation(
        %{max_header_bytes: 32_768, max_read_chunk: 16_384, max_buffer_bytes: 65_536},
        h2
      )

    assert :erts_debug.flat_size(fields) * :erlang.system_info(:wordsize) +
             2 * Headers.bytes(fields) < reserve.decode
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
      assert {:error, _} = HPAX.decode(block, HPAX.new(4_096))
    end
  end
end
