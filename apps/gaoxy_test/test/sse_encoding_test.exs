defmodule Gaoxy.Test.SseEncodingTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.Test.SSE

  test "SSE encoding handles multiline data and rejects field injection" do
    assert IO.iodata_to_binary(
             SSE.encode(%{data: "a\r\nb\rc\n", id: "7", event: "update", retry: 0})
           ) ==
             "event: update\nid: 7\nretry: 0\ndata: a\ndata: b\ndata: c\ndata: \n\n"

    assert_raise ArgumentError, fn -> SSE.encode(%{data: "value", id: "bad\ninjected"}) end
    assert_raise ArgumentError, fn -> SSE.encode(%{data: "value", event: "bad\rname"}) end
    assert_raise ArgumentError, fn -> SSE.encode(%{data: "value", retry: -1}) end
  end
end
