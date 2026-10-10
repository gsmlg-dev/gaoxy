defmodule Gaoxy.HTTP.HTTP1.BodyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP1.Body

  test "fixed bodies honor read credit and preserve pipelined bytes" do
    body = Body.new({:length, 5})
    assert {:more, "ab", body, "cdeNEXT"} = Body.read(body, "abcdeNEXT", 2)
    assert {:ok, "cde", %{phase: :done}, "NEXT"} = Body.read(body, "cdeNEXT", 10)
  end

  test "chunk boundaries and trailers are incremental with bounded data credit" do
    body = Body.new(:chunked)
    assert {:more, "", body, "4;name="} = Body.read(body, "4;name=", 2)

    assert {:more, "Wi", body, "ki\r\n5\r\npedia\r\n0\r\nX-Checksum: ok\r\n\r\nNEXT"} =
             Body.read(
               body,
               "4;name=value\r\nWiki\r\n5\r\npedia\r\n0\r\nX-Checksum: ok\r\n\r\nNEXT",
               2
             )

    assert {:ok, "kipedia", %{phase: :done, trailers: [{"x-checksum", "ok"}]}, "NEXT"} =
             Body.read(body, "ki\r\n5\r\npedia\r\n0\r\nX-Checksum: ok\r\n\r\nNEXT", 20)
  end

  test "every possible delivery boundary decodes the same chunked body" do
    wire = "3\r\nabc\r\n2\r\nde\r\n0\r\nX: a\r\nX: b\r\n\r\nNEXT"

    for split <- 0..(byte_size(wire) - 4) do
      <<first::binary-size(^split), second::binary>> = wire
      {status, bytes, body, rest} = Body.read(Body.new(:chunked), first, 20)
      assert status in [:more, :ok]

      assert {:ok, tail, %{trailers: [{"x", "a"}, {"x", "b"}]}, "NEXT"} =
               Body.read(body, rest <> second, 20)

      assert bytes <> tail == "abcde"
    end
  end

  test "rejects malformed sizes, delimiters and forbidden trailers" do
    for wire <- [
          "+2\r\nab\r\n",
          "-1\r\n",
          "G\r\n",
          "2\nab",
          "2\r\nabXX",
          "1;bad=\r\na\r\n",
          "0\r\nContent-Length: 5\r\n\r\n",
          "0\r\nHost: attacker\r\n\r\n",
          "0\r\n folded: value\r\n\r\n"
        ] do
      assert {:error, 400, _} = Body.read(Body.new(:chunked), wire, 20)
    end
  end

  test "body and framing limits reject before retaining excess input" do
    assert {:error, 413, :body_limit} =
             Body.read(Body.new(:chunked, %{max_body_bytes: 4}), "5\r\n", 2)

    assert {:error, 400, :chunk_line_limit} =
             Body.read(Body.new(:chunked, %{max_chunk_line: 8}), "123456789", 2)

    assert {:error, 431, :trailer_bytes_limit} =
             Body.read(Body.new(:chunked, %{max_trailer_bytes: 8}), "0\r\nLong-Field: value", 2)

    assert {:error, 431, :trailer_count_limit} =
             Body.read(Body.new(:chunked, %{max_trailers: 1}), "0\r\nX: a\r\nY: b\r\n\r\n", 2)
  end

  test "none and empty bodies leave following bytes untouched" do
    for framing <- [:none, {:length, 0}] do
      assert {:ok, "", %{phase: :done}, "NEXT"} = Body.read(Body.new(framing), "NEXT", 1)
    end
  end
end
