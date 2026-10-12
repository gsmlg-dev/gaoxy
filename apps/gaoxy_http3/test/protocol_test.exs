defmodule Gaoxy.HTTP.HTTP3.ProtocolTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.Protocol
  alias QuicHttp3.{Frame, Qpack, Settings, Varint}

  @http %{
    max_headers: 100,
    max_header_bytes: 32_768,
    max_request_line: 8192,
    max_body_bytes: 8_388_608,
    max_trailers: 32,
    max_trailer_bytes: 8192,
    max_buffer_bytes: 65_536
  }
  @h3 %{
    max_streams: 8,
    max_header_block: 32_768,
    max_pending_output: 65_536,
    control_turn: 32,
    control_quantum: 16_384,
    dynamic_table_capacity: 0,
    blocked_streams: 0
  }
  @fields [
    {":method", "POST"},
    {":scheme", "https"},
    {":authority", "example.test"},
    {":path", "/"}
  ]

  defp fresh(http \\ @http, h3 \\ @h3) do
    {:ok, state} = Protocol.new(%{http_limits: http, h3_limits: h3})
    state
  end

  defp open(state, key, kind \\ :bidi) do
    {:ok, state, []} = Protocol.open(state, key, kind)
    state
  end

  defp head(fields \\ @fields) do
    {:ok, block} = Qpack.encode_header_block(fields)
    Frame.encode!(:headers, block)
  end

  defp control(settings \\ []) do
    <<0>> <> Frame.encode!(:settings, Settings.encode!(settings))
  end

  test "requests are accepted before peer control SETTINGS" do
    state = open(fresh(), :request)

    assert {:ok, state, [{:headers, :request, %{version: :"HTTP/3"}}]} =
             Protocol.feed(state, :request, head())

    assert {:ok, _, [{:complete, :request}]} = Protocol.fin(state, :request)
  end

  test "every split point in request framing and DATA preserves actions" do
    bytes = head(@fields ++ [{"content-length", "3"}]) <> Frame.encode!(:data, "abc")

    for split <- 0..byte_size(bytes) do
      <<first::binary-size(split), second::binary>> = bytes
      assert {:ok, state, a} = Protocol.feed(open(fresh(), :r), :r, first)
      assert {:ok, state, b} = Protocol.feed(state, :r, second)
      assert [{:headers, :r, _} | pieces] = a ++ b
      assert Enum.map_join(pieces, fn {:data, :r, piece} -> piece end) == "abc"
      assert {:ok, _, [{:complete, :r}]} = Protocol.fin(state, :r)
    end
  end

  test "multi-byte frame varints survive each split" do
    bytes = Varint.encode!(0x21, 8) <> Varint.encode!(70, 4) <> :binary.copy("x", 70) <> head()

    for split <- 0..byte_size(bytes) do
      <<a::binary-size(split), b::binary>> = bytes
      assert {:ok, state, left} = Protocol.feed(open(fresh(), :r), :r, a)
      assert {:ok, state, right} = Protocol.feed(state, :r, b)
      assert [{:headers, :r, _}] = left ++ right
      assert {:ok, _, [{:complete, :r}]} = Protocol.fin(state, :r)
    end
  end

  test "trailers end DATA and can occur once" do
    {:ok, trailer} = Qpack.encode_header_block([{"x-checksum", "ok"}])
    bytes = head() <> Frame.encode!(:data, "x") <> Frame.encode!(:headers, trailer)

    assert {:ok, state,
            [{:headers, :r, _}, {:data, :r, "x"}, {:trailers, :r, [{"x-checksum", "ok"}]}]} =
             Protocol.feed(open(fresh(), :r), :r, bytes)

    assert {:error, :connection, 0x105, _, _} =
             Protocol.feed(state, :r, Frame.encode!(:data, "x"))

    assert {:error, :connection, 0x105, _, _} =
             Protocol.feed(state, :r, Frame.encode!(:headers, trailer))
  end

  test "DATA before initial HEADERS and control frames on requests are forbidden" do
    for bytes <- [
          Frame.encode!(:data, "x"),
          Frame.encode!(:settings, ""),
          Frame.encode!(:push_promise, "")
        ] do
      assert {:error, :connection, 0x105, _, _} = Protocol.feed(open(fresh(), :r), :r, bytes)
    end
  end

  test "FIN inside a frame fails and missing request headers is a message error" do
    for bytes <- [<<0x40>>, <<1>>, <<1, 3, 0>>, head() <> <<0, 2, ?x>>] do
      assert {:ok, state, _} = Protocol.feed(open(fresh(), :r), :r, bytes)
      assert {:error, :connection, 0x106, _, _} = Protocol.fin(state, :r)
    end

    assert {:error, :stream, 0x10E, _, _} = Protocol.fin(open(fresh(), :r), :r)
  end

  test "content-length checks overflow immediately and underflow at FIN" do
    assert {:ok, state, _} =
             Protocol.feed(open(fresh(), :r), :r, head(@fields ++ [{"content-length", "3"}]))

    assert {:error, :stream, 0x10E, :content_length, _} =
             Protocol.feed(state, :r, Frame.encode!(:data, "abcd"))

    assert {:ok, state, _} = Protocol.feed(state, :r, Frame.encode!(:data, "ab"))
    assert {:error, :stream, 0x10E, :content_length, _} = Protocol.fin(state, :r)
  end

  test "stream message failure preserves a sibling request" do
    state = fresh() |> open(:bad) |> open(:good)
    assert {:ok, state, _} = Protocol.feed(state, :good, head())

    assert {:error, :stream, 0x10E, _, state} =
             Protocol.feed(state, :bad, head(@fields ++ [{"host", "evil.test"}]))

    assert {:ok, _, [{:complete, :good}]} = Protocol.fin(state, :good)
  end

  test "DATA streams without retaining a whole large frame" do
    assert {:ok, state, _} =
             Protocol.feed(open(fresh(), :r), :r, head() <> <<0>> <> Varint.encode!(100_000))

    for _ <- 1..3, reduce: state do
      state ->
        assert {:ok, next, [{:data, :r, chunk}]} =
                 Protocol.feed(state, :r, :binary.copy("x", 16_384))

        assert byte_size(chunk) == 16_384
        assert next.streams.r.buffer == ""
        next
    end
  end

  test "huge unknown frames discard incrementally without retaining payload" do
    state = open(fresh(), :r)

    assert {:ok, state, []} =
             Protocol.feed(state, :r, Varint.encode!(0x21) <> Varint.encode!(1_000_000_000))

    assert {:ok, state, []} = Protocol.feed(state, :r, :binary.copy("x", 16_384))
    assert state.streams.r.buffer == ""
  end

  test "turn bound keeps remainder for empty-input continuation" do
    state = open(fresh(@http, %{@h3 | control_turn: 2}), :r)
    assert {:ok, state, []} = Protocol.feed(state, :r, head())
    assert byte_size(state.streams.r.buffer) > 0
    assert {:ok, _, [{:headers, :r, _}]} = Protocol.feed(state, :r, "")
  end

  test "request state slots are bounded and recovered on FIN/reset" do
    state = open(fresh(@http, %{@h3 | max_streams: 1}), :one)
    assert {:error, :stream, 0x107, _, _} = Protocol.open(state, :two, :bidi)
    assert {:ok, state, _} = Protocol.reset(state, :one)
    assert {:ok, _, []} = Protocol.open(state, :two, :bidi)

    assert {:ok, state, _} =
             Protocol.feed(open(fresh(@http, %{@h3 | max_streams: 1}), :one), :one, head())

    assert {:ok, state, _} = Protocol.fin(state, :one)
    assert {:ok, _, []} = Protocol.open(state, :two, :bidi)
  end

  test "compressed HEADERS and incoming retained bytes are bounded before buffering" do
    assert {:error, :stream, 0x107, _, _} =
             Protocol.feed(open(fresh(), :r), :r, <<1>> <> Varint.encode!(32_769))

    assert {:error, :stream, 0x107, _, _} =
             Protocol.feed(open(fresh(), :r), :r, :binary.copy("x", 65_537))
  end

  test "control type and SETTINGS survive every split" do
    bytes =
      Varint.encode!(0, 8) <> Frame.encode!(:settings, Settings.encode!([{1, 4096}, {7, 2}]))

    for split <- 0..byte_size(bytes) do
      <<a::binary-size(split), b::binary>> = bytes
      assert {:ok, state, left} = Protocol.feed(open(fresh(), :c, :uni), :c, a)
      assert {:ok, _, right} = Protocol.feed(state, :c, b)
      assert [{:settings, [{1, 4096}, {7, 2}]}] = left ++ right
    end
  end

  test "SETTINGS first, uniqueness and reserved identifiers have precise errors" do
    assert {:error, :connection, 0x10A, _, _} =
             Protocol.feed(open(fresh(), :c, :uni), :c, <<0>> <> Frame.encode!(0x21, ""))

    assert {:error, :connection, 0x105, _, _} =
             Protocol.feed(open(fresh(), :c, :uni), :c, control() <> Frame.encode!(:settings, ""))

    for payload <- [<<1, 0, 1, 0>>, <<2, 0>>, <<8, 2>>, <<1>>] do
      assert {:error, :connection, 0x109, _, _} =
               Protocol.feed(
                 open(fresh(), :c, :uni),
                 :c,
                 <<0>> <> Frame.encode!(:settings, payload)
               )
    end
  end

  test "duplicate critical uni streams are connection errors" do
    for type <- [0, 2, 3] do
      state = fresh() |> open(:first, :uni) |> open(:second, :uni)
      assert {:ok, state, _} = Protocol.feed(state, :first, <<type>>)
      assert {:error, :connection, 0x103, _, _} = Protocol.feed(state, :second, <<type>>)
    end
  end

  test "critical stream FIN and RESET are connection errors" do
    for type <- [0, 2, 3] do
      assert {:ok, state, _} = Protocol.feed(open(fresh(), :c, :uni), :c, <<type>>)
      assert {:error, :connection, 0x104, _, _} = Protocol.fin(state, :c)
      assert {:error, :connection, 0x104, _, _} = Protocol.reset(state, :c)
    end
  end

  test "unknown uni streams are stopped and push streams forbidden" do
    assert {:ok, state, [{:discard, :u}]} = Protocol.feed(open(fresh(), :u, :uni), :u, <<0x21>>)
    assert state.streams == %{}
    assert {:error, :connection, 0x103, _, _} = Protocol.feed(open(fresh(), :p, :uni), :p, <<1>>)
  end

  test "unknown large control extension is skipped after SETTINGS" do
    bytes = control() <> Varint.encode!(0x21) <> Varint.encode!(1_000_000)
    assert {:ok, state, [{:settings, []}]} = Protocol.feed(open(fresh(), :c, :uni), :c, bytes)
    assert {:ok, state, []} = Protocol.feed(state, :c, :binary.copy("x", 16_384))
    assert state.streams.c.buffer == ""
  end

  test "HTTP2-reserved frame types are forbidden on control and request streams" do
    for type <- [2, 6, 8, 9] do
      assert {:error, :connection, 0x105, _, _} =
               Protocol.feed(open(fresh(), :r), :r, Frame.encode!(type, ""))

      assert {:error, :connection, 0x105, _, _} =
               Protocol.feed(open(fresh(), :c, :uni), :c, control() <> Frame.encode!(type, ""))
    end
  end

  test "MAX_PUSH_ID is monotonic and CANCEL_PUSH cannot refer to an unissued push" do
    bytes = control() <> Frame.encode!(:max_push_id, <<5>>)
    assert {:ok, state, [{:settings, []}]} = Protocol.feed(open(fresh(), :c, :uni), :c, bytes)
    assert {:ok, state, []} = Protocol.feed(state, :c, Frame.encode!(:max_push_id, <<5>>))

    assert {:error, :connection, 0x108, _, _} =
             Protocol.feed(state, :c, Frame.encode!(:max_push_id, <<4>>))

    assert {:error, :connection, 0x108, _, _} =
             Protocol.feed(state, :c, Frame.encode!(:cancel_push, <<0>>))

    assert {:error, :connection, 0x106, _, _} =
             Protocol.feed(state, :c, Frame.encode!(:max_push_id, <<0, 0>>))
  end

  test "client GOAWAY push identifier decreases and does not ban requests" do
    assert {:ok, state, [{:settings, []}, {:goaway, 3}]} =
             Protocol.feed(
               open(fresh(), :c, :uni),
               :c,
               control() <> Frame.encode!(:goaway, <<3>>)
             )

    assert {:error, :connection, 0x108, _, _} =
             Protocol.feed(state, :c, Frame.encode!(:goaway, <<4>>))

    assert {:ok, state, []} = Protocol.open(state, :r, :bidi)
    assert {:ok, _, [{:headers, :r, _}]} = Protocol.feed(state, :r, head())
  end

  test "zero capacity encoder instructions work at every split point" do
    # Set Dynamic Table Capacity = 31, forbidden.
    bytes = <<2, 0x3F, 0>>
    assert {:error, :connection, 0x201, _, _} = Protocol.feed(open(fresh(), :q, :uni), :q, bytes)
    assert {:ok, _, []} = Protocol.feed(open(fresh(), :q, :uni), :q, <<2, 0x20>>)

    for instruction <- [<<0x80>>, <<0x40>>, <<0>>] do
      assert {:error, :connection, 0x201, _, _} =
               Protocol.feed(open(fresh(), :q, :uni), :q, <<2>> <> instruction)
    end
  end

  test "decoder instructions inconsistent with static encoding fail" do
    for instruction <- [<<0x80>>, <<1>>, <<0>>] do
      assert {:error, :connection, 0x202, _, _} =
               Protocol.feed(open(fresh(), :q, :uni), :q, <<3>> <> instruction)
    end
  end

  test "zero-capacity decoder Stream Cancellation is legal and preserves sibling requests" do
    state = fresh() |> open(:request) |> open(:decoder, :uni)
    assert {:ok, state, _} = Protocol.feed(state, :request, head())
    assert {:ok, state, []} = Protocol.feed(state, :decoder, <<3, 0x40>>)
    assert {:ok, _, [{:complete, :request}]} = Protocol.fin(state, :request)
  end

  test "Stream Cancellation identifier supports every split and finite continuations" do
    {:ok, instruction} = Qpack.encode_integer(Varint.max(), 6, 0x40)
    bytes = Varint.encode!(3, 8) <> instruction

    for split <- 0..byte_size(bytes) do
      <<a::binary-size(split), b::binary>> = bytes
      assert {:ok, state, []} = Protocol.feed(open(fresh(), :q, :uni), :q, a)
      assert {:ok, state, []} = Protocol.feed(state, :q, b)
      assert state.streams.q.buffer == ""
    end

    state = open(fresh(@http, %{@h3 | control_turn: 2}), :q, :uni)
    assert {:ok, state, []} = Protocol.feed(state, :q, <<3, 0x40, 0x40, 0x40>>)
    assert state.streams.q.buffer == <<0x40, 0x40>>
    assert {:ok, state, []} = Protocol.feed(state, :q, "")
    assert state.streams.q.buffer == ""
  end

  test "malformed or out-of-range Stream Cancellation remains a decoder connection error" do
    # Continuation value 2^62 - 1 plus the saturated six-bit prefix exceeds
    # the largest QUIC stream identifier. A generic integer decoder is not
    # the authority for the HTTP/3 stream identifier range.
    oversized = <<0x7F>> <> :binary.copy(<<0xFF>>, 8) <> <<0x3F>>

    for instruction <- [<<0x7F>> <> :binary.copy(<<0xFF>>, 10), oversized] do
      assert {:error, :connection, 0x202, _, _} =
               Protocol.feed(open(fresh(), :q, :uni), :q, <<3>> <> instruction)
    end
  end

  test "QPACK semantic/resource/compression errors retain their scope" do
    for {block, scope, code} <- [
          {<<0, 0, 0x21, ?X, 1, ?y>>, :stream, 0x10E},
          {<<1, 0>>, :connection, 0x200},
          {<<0, 0, 0xD1, 0xD7>>, :stream, 0x107}
        ] do
      state = fresh(%{@http | max_headers: 1}) |> open(:r)

      assert {:error, ^scope, ^code, _, _} =
               Protocol.feed(state, :r, Frame.encode!(:headers, block))
    end
  end

  test "partial unidirectional type FIN is a stream creation error" do
    assert {:ok, state, []} = Protocol.feed(open(fresh(), :u, :uni), :u, <<0xC0>>)
    assert {:error, :connection, 0x103, _, _} = Protocol.fin(state, :u)
  end

  test "byte quantum bounds incremental DATA and leaves credited continuation" do
    state = open(fresh(@http, %{@h3 | control_quantum: 8}), :r)

    state =
      Enum.reduce(:binary.bin_to_list(head()), state, fn byte, state ->
        {:ok, next, _} = Protocol.feed(state, :r, <<byte>>)
        next
      end)

    assert {:ok, state, [{:data, :r, "abcdef"}]} =
             Protocol.feed(state, :r, Frame.encode!(:data, "abcdefghijklmn"))

    assert {:ok, state, [{:data, :r, "ghijklmn"}]} = Protocol.feed(state, :r, "")
    assert {:ok, _, [{:complete, :r}]} = Protocol.fin(state, :r)
  end

  test "decoded field-section and trailer byte ceilings are enforced" do
    fields = @fields ++ [{"x", :binary.copy("a", 200)}]
    state = open(fresh(%{@http | max_header_bytes: 300}), :r)
    assert {:error, :stream, 0x107, _, _} = Protocol.feed(state, :r, head(fields))
    state = open(fresh(%{@http | max_trailer_bytes: 32}), :r)
    assert {:ok, state, _} = Protocol.feed(state, :r, head())
    assert {:error, :stream, 0x107, _, _} = Protocol.feed(state, :r, head([{"x", "y"}]))
  end

  test "unknown DATA length cannot bypass the total body ceiling" do
    state = open(fresh(%{@http | max_body_bytes: 2}), :r)

    assert {:error, :stream, 0x107, :body_limit, _} =
             Protocol.feed(state, :r, head() <> Frame.encode!(:data, "abc"))
  end

  test "encoder integer errors and fragmented instructions have QPACK scope" do
    assert {:ok, state, []} = Protocol.feed(open(fresh(), :q, :uni), :q, <<2, 0x3F>>)
    assert {:error, :connection, 0x201, _, _} = Protocol.feed(state, :q, <<0>>)

    assert {:error, :connection, 0x201, _, _} =
             Protocol.feed(state, :q, :binary.copy(<<0xFF>>, 10))
  end

  test "unclassified uni streams have a finite parser slot ceiling" do
    state = Enum.reduce(1..11, fresh(), fn key, state -> open(state, key, :uni) end)
    assert {:error, :connection, 0x107, _, _} = Protocol.open(state, 12, :uni)
  end

  test "control identifier lengths are validated before accumulation" do
    assert {:ok, state, _} = Protocol.feed(open(fresh(), :c, :uni), :c, control())

    assert {:error, :connection, 0x106, _, _} =
             Protocol.feed(state, :c, Varint.encode!(7) <> Varint.encode!(9))

    assert {:error, :connection, 0x106, _, _} =
             Protocol.feed(state, :c, Frame.encode!(:goaway, <<>>))
  end

  test "one-byte HEADERS fragmentation stays within the parser state reservation" do
    bytes = head(@fields ++ [{"x", :binary.copy("a", 32_000)}])
    <<prefix::binary-size(byte_size(bytes) - 1), last>> = bytes

    state =
      Enum.reduce(:binary.bin_to_list(prefix), open(fresh(), :r), fn byte, state ->
        assert {:ok, next, []} = Protocol.feed(state, :r, <<byte>>)
        next
      end)

    # Serialized application parser state only, not a VM/native memory claim.
    assert :erlang.external_size(state.streams.r) <= 2 * @h3.max_header_block + 16_384
    assert {:ok, _, [{:headers, :r, _}]} = Protocol.feed(state, :r, <<last>>)
  end
end
