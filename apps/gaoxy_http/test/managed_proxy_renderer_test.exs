defmodule Gaoxy.HTTP.ManagedProxyRendererTest do
  use ExUnit.Case, async: true
  @moduletag :unit
  alias Gaoxy.HTTP.{Exchange, HTTP1.Response, HTTP2.Frame}
  @bounds Gaoxy.HTTP.RendererBounds

  test "proper rendered iodata accepts exactly 64KiB and rejects excess wire bytes" do
    assert {:ok, 65_536} = apply(@bounds, :iodata, [[:binary.copy("x", 65_536)], 81_920])

    assert {:error, :renderer_limit} =
             apply(@bounds, :iodata, [[:binary.copy("x", 65_537)], 81_920])

    assert {:ok, 3} = apply(@bounds, :iodata, [[65, "bc"], 81_920])
  end

  test "rendered backing is bounded before conversion even for a short subbinary" do
    backing = :binary.copy("x", 65_537)
    short = binary_part(backing, 0, 100)
    assert :binary.referenced_byte_size(short) > 65_536
    assert {:error, :renderer_limit} = apply(@bounds, :iodata, [[short], 131_072])
  end

  test "malformed iodata cannot enter a renderer traversal or raise" do
    for value <- [nil, :unexpected, 256, -1, [256], [-1], ["x" | "tail"], [{"x"}], [<<1::1>>]] do
      assert {:error, :invalid_renderer_iodata} = apply(@bounds, :iodata, [value, 131_072])
    end

    assert {:ok, 0} = apply(@bounds, :iodata, [[], 81_920])
  end

  test "finite constructor count and nesting depth reject before serialization" do
    # A cons and its binary/byte leaf each count once; an empty tail counts zero.
    assert {:ok, 0} = apply(@bounds, :iodata, [List.duplicate("", 4_096), 131_072])

    assert {:error, :renderer_limit} =
             apply(@bounds, :iodata, [List.duplicate("", 4_097), 131_072])

    assert {:ok, 1} = apply(@bounds, :iodata, [nested(16), 81_920])
    assert {:error, :renderer_limit} = apply(@bounds, :iodata, [nested(17), 81_920])
  end

  test "complete rendered external representation is separately limited" do
    # ETF VERSION(1), LIST(5), BINARY(5+3), NIL(1) = 15.
    assert {:ok, 3} = apply(@bounds, :iodata, [["abc"], 15])
    assert {:error, :renderer_limit} = apply(@bounds, :iodata, [["abc"], 14])
  end

  test "field preflight bounds proper pairs, count, logical bytes and backing" do
    assert :ok = apply(@bounds, :fields, [[{"x", :binary.copy("a", 65_535)}], 256, 65_536])

    assert {:error, :renderer_limit} =
             apply(@bounds, :fields, [[{"x", :binary.copy("a", 65_536)}], 256, 65_536])

    assert :ok = apply(@bounds, :fields, [List.duplicate({"x", ""}, 256), 256, 65_536])

    assert {:error, :renderer_limit} =
             apply(@bounds, :fields, [List.duplicate({"x", ""}, 257), 256, 65_536])

    for fields <- [[{"x", "a"} | :tail], [{"x", "a", "b"}], [%{x: "a"}], [{"x", nil}]] do
      assert {:error, :invalid_renderer_fields} = apply(@bounds, :fields, [fields, 256, 65_536])
    end

    backing = :binary.copy("a", 65_537)

    assert {:error, :renderer_limit} =
             apply(@bounds, :fields, [[{"x", binary_part(backing, 0, 100)}], 256, 65_536])
  end

  test "H2 compact header block produces at most four bounded queue frames" do
    block = :binary.copy("b", 65_536)
    from = {self(), make_ref()}
    assert {:ok, entries} = apply(@bounds, :header_frames, [block, 3, true, from, -1])
    assert length(entries) == 4
    assert :erlang.external_size({:queue.from_list(entries), 3}) <= 73_728

    for {{bytes, callback, -1}, index} <- Enum.with_index(entries) do
      <<size::24, type, flags, 0::1, 3::31, payload::binary>> = bytes
      assert size == 16_384
      assert payload == :binary.copy("b", 16_384)
      assert type == if(index == 0, do: 1, else: 9)
      assert flags == if(index == 0, do: 1, else: if(index == 3, do: 4, else: 0))
      assert callback == if(index == 3, do: {:headers, 3, from}, else: {:header_fragment, 3})
    end
  end

  test "H2 rejects oversized or backed blocks and unbounded queue controls before enqueue" do
    from = {self(), make_ref()}

    assert {:error, :renderer_limit} =
             apply(@bounds, :header_frames, [:binary.copy("x", 65_537), 1, false, from, 0])

    backing = :binary.copy("x", 65_537)

    assert {:error, :renderer_limit} =
             apply(@bounds, :header_frames, [binary_part(backing, 0, 100), 1, false, from, 0])

    for {id, ended, caller, deadline} <- [
          {0, true, from, 0},
          {1, nil, from, 0},
          {1, false, {:bad, make_ref()}, 0},
          {1, false, {self(), {:arbitrary, :payload}}, 0},
          {1, false, from, 9_223_372_036_854_775_808}
        ] do
      assert {:error, :invalid_renderer_control} =
               apply(@bounds, :header_frames, ["", id, ended, caller, deadline])
    end

    assert {:ok, [{bytes, {:headers, 1, ^from}, 0}]} =
             apply(@bounds, :header_frames, ["", 1, false, from, 0])

    assert bytes == IO.iodata_to_binary(Frame.encode(1, 4, 1, ""))
  end

  test "H1 rejects oversized field backing before final commitment or any write" do
    backing = :binary.copy("a", 65_537)
    headers = [{"x", binary_part(backing, 0, 100)}]
    assert {:error, :response_header_limit} = Response.send_chunked(exchange(), 200, headers)
    refute_receive {:plug_conn, :sent}
  end

  test "H1 rejects improper fields and declaration amplification before rendering" do
    assert {:error, :invalid_response_headers} =
             Response.send_chunked(exchange(), 200, [{"x", "a"} | :improper])

    assert {:error, :invalid_response_trailers} =
             Response.send_chunked(exchange(), 200, [
               {"trailer", Enum.join(List.duplicate("x", 129), ",")}
             ])

    refute_receive {:plug_conn, :sent}
  end

  defp nested(depth), do: Enum.reduce(1..depth, "x", fn _, value -> [value] end)

  defp exchange do
    %Exchange{
      request: %{method: "GET", version: :"HTTP/1.1"},
      body: %{phase: :done},
      limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      },
      close: false
    }
  end
end
