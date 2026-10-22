defmodule Gaoxy.HTTP.HTTP2WebSocketNetworkTest do
  alias HTTP.HTTP2.HPACK
  use ExUnit.Case, async: true

  defmodule Echo do
    def init(state) do
      send(self(), :push)
      {:ok, state}
    end

    def handle_in({bytes, opcode: opcode}, state), do: {:push, {opcode, bytes}, state}
    def handle_info(:push, state), do: {:push, {:text, "push"}, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule EndpointPlug do
    def init(options), do: options

    def call(%{request_path: "/ws"} = conn, _) do
      Plug.Conn.upgrade_adapter(conn, :websocket, {Echo, nil, [max_lifetime: 10_000]})
    end

    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, conn.request_path)
  end

  test "ordinary h2c Plug WebSocket sends an idle push, echoes, closes and serves a sibling" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {EndpointPlug, []},
        protocols: [:http2],
        h2c: :prior_knowledge,
        extended_connect: true
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    {4, 0, 0, settings} = next(socket, 4, 0)
    assert {8, 1} in for(<<id::16, value::32 <- settings>>, do: {id, value})
    :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))

    headers = [
      {":method", "CONNECT"},
      {":protocol", "websocket"},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", "/ws"},
      {"sec-websocket-version", "13"}
    ]

    :ok = send_headers(socket, 1, 4, headers)
    {1, flags, 1, block} = next(socket, 1, 1)
    assert Bitwise.band(flags, 1) == 0
    assert {:ok, _, response_fields} = HPACK.decode(HPACK.new_decoder(max_dynamic_size: 0), block)
    assert {":status", "200"} in response_fields

    assert Enum.all?(response_fields, fn {name, _} ->
             name not in [
               "connection",
               "upgrade",
               "content-length",
               "transfer-encoding",
               "sec-websocket-accept"
             ]
           end)

    assert {0, 0, 1, <<0x81, 4, "push">>} = next(socket, 0, 1)
    :ok = :gen_tcp.send(socket, frame(0, 0, 1, masked(1, "hello")))
    assert {0, 0, 1, <<0x81, 5, "hello">>} = next(socket, 0, 1)
    :ok = :gen_tcp.send(socket, frame(0, 0, 1, masked(8, <<1000::16>>)))
    assert {0, 0, 1, <<0x88, 2, 1000::16>>} = next(socket, 0, 1)
    assert {0, 1, 1, ""} = next(socket, 0, 1)
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, ""))

    :ok =
      send_headers(socket, 3, 5, [
        {":method", "GET"},
        {":scheme", "http"},
        {":authority", "localhost"},
        {":path", "/sibling"}
      ])

    {1, _, 3, block} = next(socket, 1, 3)
    assert {:ok, _, fields} = HPACK.decode(HPACK.new_decoder(max_dynamic_size: 0), block)
    assert {":status", "200"} in fields
    assert {0, 1, 3, "/sibling"} = next(socket, 0, 3)
    :ok = :gen_tcp.close(socket)
    assert :ok = Gaoxy.stop(server)
  end

  defmodule LimitsEndpoint do
    def init(options), do: {:ok, options}

    def call(exchange, {owner, enabled}) do
      send(owner, {:ordinary_limits, enabled, exchange.limits})
      Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "ordinary")
    end
  end

  test "ordinary h2c exchanges keep native limits with extended CONNECT enabled or disabled" do
    for enabled <- [false, true] do
      options = [
        endpoint: {LimitsEndpoint, {self(), enabled}},
        protocols: [:http2],
        h2c: :prior_knowledge,
        extended_connect: enabled
      ]

      assert {:ok, spec} = Gaoxy.HTTP.service_spec(options)
      assert {:ok, server} = Gaoxy.HTTP.start_link(options)
      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
      assert {:ok, {_, port}} = Gaoxy.info(server, :http).local

      assert {:ok, socket} =
               :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 2_000)

      on_exit(fn -> :gen_tcp.close(socket) end)
      :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
      {4, 0, 0, _settings} = next(socket, 4, 0)
      :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))

      :ok =
        send_headers(socket, 1, 5, [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/ordinary"}
        ])

      {1, _, 1, block} = next(socket, 1, 1)
      assert {:ok, _, fields} = HPACK.decode(HPACK.new_decoder(max_dynamic_size: 0), block)
      assert {":status", "200"} in fields
      assert {0, 1, 1, "ordinary"} = next(socket, 0, 1)
      assert_receive {:ordinary_limits, ^enabled, limits}
      assert limits == Map.put(spec.handler_options.http_limits, :max_write_chunk, 16_384)
      :ok = :gen_tcp.close(socket)
      assert :ok = Gaoxy.stop(server)
    end
  end

  defp send_headers(socket, stream, flags, fields) do
    {_, block} =
      HPACK.encode_headers(HPACK.set_max_dynamic_size(HPACK.new_encoder(), 0), fields,
        indexing: :never,
        huffman: :never
      )

    :gen_tcp.send(socket, frame(1, flags, stream, block))
  end

  defp frame(type, flags, stream, bytes),
    do: [<<IO.iodata_length(bytes)::24, type, flags, 0::1, stream::31>>, bytes]

  defp masked(opcode, bytes) do
    mask = <<1, 2, 3, 4>>

    payload =
      bytes
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.map(fn {byte, index} -> Bitwise.bxor(byte, :binary.at(mask, rem(index, 4))) end)

    [<<1::1, 0::3, opcode::4, 1::1, byte_size(bytes)::7>>, mask, payload]
  end

  defp next(socket, type, stream, left \\ 12)
  defp next(_, _, _, 0), do: flunk("ordinary H2 response did not arrive")

  defp next(socket, type, stream, left) do
    assert {:ok, <<size::24, actual_type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, 2_000)

    payload =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, size, 2_000)
        bytes
      end

    assert actual_type not in [3, 7], "unexpected reset/GOAWAY"

    if actual_type == type and id == stream,
      do: {actual_type, flags, id, payload},
      else: next(socket, type, stream, left - 1)
  end
end
