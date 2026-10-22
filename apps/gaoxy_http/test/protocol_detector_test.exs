defmodule Gaoxy.HTTP.ProtocolDetectorTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.ProtocolDetector
  @preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

  test "complete preface preserves its exact bytes and all trailing input" do
    bytes = @preface <> :binary.copy(<<0>>, 100_000)
    assert {:http2, replay} = ProtocolDetector.classify("", bytes)
    assert IO.iodata_to_binary(replay) == bytes
  end

  test "every split preserves all bytes and bounds copied undecided carry" do
    for split <- 1..23 do
      <<prefix::binary-size(^split), suffix::binary>> = @preface
      assert {:more, carry} = ProtocolDetector.classify("", prefix)
      assert carry == prefix
      assert byte_size(carry) <= 23
      assert :binary.referenced_byte_size(carry) <= 23
      assert {:http2, replay} = ProtocolDetector.classify(carry, suffix <> "trailing")
      assert IO.iodata_to_binary(replay) == @preface <> "trailing"
    end
  end

  test "one byte fragmentation remains undecided until byte 24" do
    carry =
      Enum.reduce(0..22, "", fn index, carry ->
        assert {:more, next} = ProtocolDetector.classify(carry, binary_part(@preface, index, 1))
        next
      end)

    assert {:http2, replay} = ProtocolDetector.classify(carry, "\n")
    assert IO.iodata_to_binary(replay) == @preface
  end

  test "each first mismatch immediately selects H1 with the full input" do
    for index <- 0..23 do
      prefix = binary_part(@preface, 0, index)
      assert {:http1, replay} = ProtocolDetector.classify(prefix, "!GET / HTTP/1.1\r\n\r\n")
      assert IO.iodata_to_binary(replay) == prefix <> "!GET / HTTP/1.1\r\n\r\n"
    end
  end

  test "empty deliveries retain the current undecided prefix" do
    assert {:more, ""} = ProtocolDetector.classify("", "")
    assert {:more, "PRI"} = ProtocolDetector.classify("PRI", "")
  end

  test "small undecided prefixes never retain a large backing binary" do
    backing = @preface <> :binary.copy("x", 1_000_000)
    prefix = binary_part(backing, 0, 23)
    assert {:more, carry} = ProtocolDetector.classify("", prefix)
    assert :binary.referenced_byte_size(carry) == 23
  end
end
