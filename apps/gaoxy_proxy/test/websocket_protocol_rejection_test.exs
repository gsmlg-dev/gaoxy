defmodule Gaoxy.Proxy.WebSocketProtocolRejectionTest do
  use ExUnit.Case, async: false
  alias HTTP.HTTP2.HPACK

  defmodule Local do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "local")
  end

  test "H2 rejects ordinary HTTP and unsupported WebSocket CONNECT before opening upstream" do
    {:ok, upstream} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(upstream) end)
    {:ok, {_, upstream_port}} = :inet.sockname(upstream)

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        protocols: [:http2],
        h2c: :prior_knowledge,
        extended_connect: true,
        endpoint:
          {Gaoxy.HTTP.Router,
           [
             %{
               path: "/ws",
               target: {Gaoxy.Proxy.WebSocket, %{upstream: "ws://127.0.0.1:#{upstream_port}"}}
             },
             %{path: "/local", target: {Local, []}}
           ]}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    {4, _, 0, _} = next(socket, 4, 0)
    :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))

    for {id, method, path, extra, status, body} <- [
          {1, "GET", "/ws", [], "400", ""},
          {3, "CONNECT", "/ws", [{":protocol", "websocket"}, {"sec-websocket-version", "13"}],
           "400", ""},
          {5, "GET", "/local", [], "200", "local"}
        ] do
      fields =
        [
          {":method", method},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", path}
        ] ++ extra

      {_, block} =
        HPACK.encode_headers(HPACK.set_max_dynamic_size(HPACK.new_encoder(), 0), fields,
          indexing: :never,
          huffman: :never
        )

      :ok = :gen_tcp.send(socket, frame(1, 5, id, block))
      {1, flags, ^id, block} = next(socket, 1, id)
      assert {:ok, _, response} = HPACK.decode(HPACK.new_decoder(max_dynamic_size: 0), block)
      assert {":status", status} in response
      refute List.keymember?(response, "connection", 0)

      if Bitwise.band(flags, 1) == 0 do
        assert {0, 1, ^id, ^body} = next(socket, 0, id)
      else
        assert body == ""
      end
    end

    assert DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor) == []
    assert {:error, :timeout} = :gen_tcp.accept(upstream, 0)
    assert :ok = Gaoxy.stop(server)
  end

  defp frame(type, flags, id, bytes),
    do: [<<IO.iodata_length(bytes)::24, type, flags, 0::1, id::31>>, bytes]

  defp next(socket, type, id, left \\ 12)
  defp next(_, _, _, 0), do: flunk("H2 response did not arrive")

  defp next(socket, type, id, left) do
    assert {:ok, <<size::24, actual, flags, _::1, stream::31>>} = :gen_tcp.recv(socket, 9, 2_000)

    bytes =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, size, 2_000)
        bytes
      end

    assert actual not in [3, 7], "unexpected H2 reset/GOAWAY"

    if actual == type and stream == id,
      do: {actual, flags, stream, bytes},
      else: next(socket, type, id, left - 1)
  end
end
