defmodule Gaoxy.HTTP.HTTP3.WebSocketTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.HTTP3.{Connection, Headers, Options, Protocol}
  alias QuicHttp3.{Control, Frame, Qpack, Settings, Varint}

  @http %{
    max_headers: 100,
    max_header_bytes: 32_768,
    max_request_line: 8192,
    max_body_bytes: 1,
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
    {":method", "CONNECT"},
    {":protocol", "websocket"},
    {":scheme", "https"},
    {":authority", "example.test"},
    {":path", "/socket%2Fchat?vsn=2.0.0"},
    {"sec-websocket-version", "13"}
  ]

  defmodule Endpoint do
    def init(owner) do
      send(owner, :initialized)
      {:ok, owner}
    end

    def call(exchange, _), do: {:ok, exchange}
  end

  defp service_options do
    [endpoint: {Endpoint, self()}, tls: %{certfile: "fixture.pem", keyfile: "fixture-key.pem"}]
  end

  defp request(fields, enabled \\ true) do
    assert Code.ensure_loaded?(Headers) and function_exported?(Headers, :request, 3),
           "missing enabled H3 extended CONNECT parser"

    apply(Headers, :request, [fields, @http, enabled])
  end

  defp fresh(enabled \\ true) do
    {:ok, state} = Protocol.new(%{http_limits: @http, h3_limits: @h3, extended_connect: enabled})
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

  defp accept(state, key) do
    assert Code.ensure_loaded?(Protocol) and function_exported?(Protocol, :websocket_open, 2),
           "missing accepted H3 tunnel transition"

    apply(Protocol, :websocket_open, [state, key])
  end

  test "exchange limits keep WebSocket settings only for actual WebSocket requests" do
    ordinary = [
      {":method", "GET"},
      {":scheme", "https"},
      {":authority", "example.test"},
      {":path", "/ordinary"}
    ]

    for enabled <- [false, true] do
      assert {:ok, spec} = Options.normalize(service_options() ++ [extended_connect: enabled])
      assert_receive :initialized
      requests = if enabled, do: [ordinary, @fields], else: [ordinary]

      for fields <- requests do
        assert {:ok, state} =
                 Connection.init(
                   %{gate: self(), limits: spec.limits},
                   %{remote: {{127, 0, 0, 1}, 1234}, local: {{127, 0, 0, 1}, 4321}},
                   spec.handler_options
                 )

        key = make_ref()
        assert {:ok, state} = Connection.handle_event({:stream_open, key, :bidi}, state)

        assert {:ok, protocol, [{:headers, ^key, request}]} =
                 Protocol.feed(state.protocol, key, head(fields))

        entry = %{state.streams[key] | request: request}
        state = %{state | protocol: protocol, streams: Map.put(state.streams, key, entry)}
        exchange = Connection.exchange(state, key, make_ref())
        native = Map.put(spec.handler_options.http_limits, :max_write_chunk, 16_384)

        if request.protocol == "websocket" do
          assert exchange.limits ==
                   Map.merge(native, %{
                     extended_connect: true,
                     websocket_limits: Map.take(spec.limits, [:max_state, :max_bytes])
                   })
        else
          assert exchange.limits == native
        end

        assert :ok = Connection.terminate(:test_complete, state)
      end
    end
  end

  test "listener option is strict, defaults disabled, and reaches the H3 handler" do
    assert {:ok, disabled} = Options.normalize(service_options())
    assert Map.get(disabled.handler_options, :extended_connect, :missing) == false
    assert_receive :initialized
    assert {:ok, enabled} = Options.normalize(service_options() ++ [extended_connect: true])
    assert enabled.handler_options.extended_connect == true
    assert enabled.handler_options.h3_limits.dynamic_table_capacity == 0
    assert_receive :initialized

    for invalid <- [nil, 1, :true_value, "true"] do
      assert {:error, :invalid_http3_options} =
               Options.normalize(service_options() ++ [extended_connect: invalid])
    end

    refute_received :initialized
  end

  test "local setting8 is advertised only when enabled and retains zero-capacity QPACK" do
    for enabled <- [true, false] do
      state = fresh(enabled)
      <<0, bytes::binary>> = Control.local_payload(state.control)
      assert {:ok, %{type: 4, payload: payload}, ""} = Frame.decode(bytes)
      assert {:ok, settings} = Settings.decode(payload)
      assert {1, 0} in settings
      assert {7, 0} in settings
      assert {8, 1} in settings == enabled
      refute {8, 0} in settings
    end
  end

  test "enabled extended CONNECT retains wire method, escaped local route and opaque protocol" do
    assert {:ok, req} = request(@fields)

    assert %{
             method: "CONNECT",
             protocol: "websocket",
             version: :"HTTP/3",
             body: :tunnel,
             target_form: :origin,
             target: "/socket%2Fchat?vsn=2.0.0",
             path: "/socket%2Fchat",
             query_string: "vsn=2.0.0",
             host: "example.test",
             port: 443,
             scheme: :https
           } = req

    assert req.head_bytes == Headers.bytes(@fields)

    assert {:ok, %{protocol: "custom-protocol", body: :tunnel}} =
             request(List.keyreplace(@fields, ":protocol", 0, {":protocol", "custom-protocol"}))

    assert {:ok, %{protocol: nil, target_form: :authority}} =
             request([{":method", "CONNECT"}, {":authority", "example.test:443"}])
  end

  test "disabled and malformed pseudoheaders remain stream message errors" do
    assert {:error, :stream, 0x10E, _} = request(@fields, false)

    for fields <- [
          List.keyreplace(@fields, ":method", 0, {":method", "GET"}),
          List.keyreplace(@fields, ":protocol", 0, {":protocol", "bad protocol"}),
          List.keydelete(@fields, ":scheme", 0),
          List.keydelete(@fields, ":authority", 0),
          List.keydelete(@fields, ":path", 0),
          List.keyreplace(@fields, ":scheme", 0, {":scheme", "http"}),
          List.keyreplace(@fields, ":path", 0, {":path", "*"}),
          List.keyreplace(@fields, ":path", 0, {":path", "/bad%q"}),
          [{":protocol", "websocket"} | @fields],
          @fields ++ [{":protocol", "websocket"}],
          @fields ++ [{"host", "other.test"}],
          @fields ++ [{"content-length", "0"}]
        ] do
      assert {:error, :stream, 0x10E, _} = request(fields)
    end
  end

  test "peer setting8 never authorizes disabled local extended CONNECT" do
    state = fresh(false) |> open(:control, :uni) |> open(:request)
    control = <<0>> <> Frame.encode!(:settings, Settings.encode!([{8, 1}]))
    assert {:ok, state, [{:settings, [{8, 1}]}]} = Protocol.feed(state, :control, control)
    assert {:error, :stream, 0x10E, _, _} = Protocol.feed(state, :request, head())
  end

  test "accepted tunnel DATA does not accumulate ordinary body totals and leaves its sibling intact" do
    state = fresh() |> open(:websocket) |> open(:http)

    assert {:ok, state, [{:headers, :websocket, %{body: :tunnel}}]} =
             Protocol.feed(state, :websocket, head())

    assert {:ok, state} = accept(state, :websocket)

    ordinary = [
      {":method", "GET"},
      {":scheme", "https"},
      {":authority", "example.test"},
      {":path", "/ok"}
    ]

    assert {:ok, state, [{:headers, :http, _}]} = Protocol.feed(state, :http, head(ordinary))

    assert {:ok, state, [{:data, :websocket, "first"}]} =
             Protocol.feed(state, :websocket, Frame.encode!(:data, "first"))

    assert {:ok, state, [{:data, :websocket, "second"}]} =
             Protocol.feed(state, :websocket, Frame.encode!(:data, "second"))

    assert state.streams.websocket.body_bytes == 0
    assert state.streams.websocket.buffer == ""
    assert {:ok, state, [{:complete, :http}]} = Protocol.fin(state, :http)
    assert {:ok, _, [{:complete, :websocket}]} = Protocol.fin(state, :websocket)
  end

  test "only an accepted websocket skips HTTP body limits and forbids HTTP trailers" do
    assert {:ok, candidate, _} = Protocol.feed(open(fresh(), :r), :r, head())

    assert {:error, :stream, 0x107, :body_limit, _} =
             Protocol.feed(candidate, :r, Frame.encode!(:data, "too much"))

    assert {:ok, state} = accept(candidate, :r)
    assert {:error, :stream, 0x10E, :websocket_trailers, _} = Protocol.feed(state, :r, head([]))
    unknown = List.keyreplace(@fields, ":protocol", 0, {":protocol", "other"})
    assert {:ok, state, _} = Protocol.feed(open(fresh(), :other), :other, head(unknown))
    assert {:error, :stream, 0x10E, _, _} = accept(state, :other)
  end

  test "invalid peer setting8 value remains an H3 settings error" do
    bytes = <<0>> <> Frame.encode!(:settings, Varint.encode!(8) <> Varint.encode!(2))

    assert {:error, :connection, 0x109, _, _} =
             Protocol.feed(open(fresh(), :control, :uni), :control, bytes)
  end
end
