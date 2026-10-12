defmodule Gaoxy.HTTP.HTTP3.QpackTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.Headers
  alias QuicHttp3.Qpack

  test "independent static QPACK vector" do
    # RFC 9204 Appendix A: indexes 17 (GET), 23 (https), 1 (/).
    assert {:ok, [{":method", "GET"}, {":scheme", "https"}, {":path", "/"}]} =
             Headers.decode(<<0, 0, 0xD1, 0xD7, 0xC1>>, 100)
  end

  test "independent literal and Huffman vectors" do
    assert {:ok, [{"x", "y"}]} = Headers.decode(<<0, 0, 0x21, ?x, 1, ?y>>, 100)
    # RFC 7541 C.4 Huffman value for www.example.com, reused by QPACK.
    value = Base.decode16!("F1E3C2E5F23A6BA0AB90F4FF")

    assert {:ok, [{":authority", "www.example.com"}]} =
             Headers.decode(<<0, 0, 0x50, 0x8C>> <> value, 100)
  end

  test "literal codec semantic failures are stream errors" do
    assert {:error, :stream, 0x10E, :invalid_fields} =
             Headers.decode(<<0, 0, 0x21, ?X, 1, ?y>>, 100)

    assert {:error, :stream, 0x107, :field_limit} = Headers.decode(<<0, 0, 0xD1, 0xD7>>, 1)
  end

  test "malformed compression and dynamic references close the connection" do
    for block <- [
          <<>>,
          <<0>>,
          <<1, 0>>,
          <<0, 0, 0x80>>,
          <<0, 0, 0xFF, 0x7F>>,
          <<0, 0, 0x50, 0x81, 0xFF>>
        ] do
      assert {:error, :connection, 0x200, _} = Headers.decode(block, 100)
    end
  end

  test "literal codec output can be decoded without dynamic state" do
    assert {:ok, bytes} =
             Qpack.encode_header_block([{"x-long-name", "value"}], never_indexed: true)

    assert {:ok, [{"x-long-name", "value"}]} = Headers.decode(bytes, 100)
  end
end
