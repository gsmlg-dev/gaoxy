defmodule Gaoxy.HTTP.WebSocket.WebsocketConfiguredLimitsNetworkTest do
  use ExUnit.Case, async: true

  defmodule Handler do
    def init(state), do: {:ok, state}
    def handle_in({bytes, opcode: opcode}, state), do: {:push, {opcode, bytes}, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule Upgrade do
    def init(options), do: options
    def call(conn, options), do: WebSockAdapter.upgrade(conn, Handler, nil, options)
  end

  defp response_head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, 2000)
      response_head(socket, bytes <> byte)
    end
  end

  test "a direct WebSock user retains an explicitly lower message limit on the wire" do
    server =
      start_supervised!(
        {Gaoxy.HTTP, plug: {Upgrade, [max_frame_size: 1024, max_message_size: 32]}, port: 0}
      )

    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(socket, [
        "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n",
        "Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
      ])

    assert response_head(socket, "") =~ "HTTP/1.1 101"
    :ok = :gen_tcp.send(socket, <<0x81, 0xA0, 0::32>> <> String.duplicate("x", 32))
    assert {:ok, <<0x81, 32>>} = :gen_tcp.recv(socket, 2, 2000)
    assert {:ok, String.duplicate("x", 32)} == :gen_tcp.recv(socket, 32, 2000)
    :ok = :gen_tcp.send(socket, <<0x81, 0xA1, 0::32>> <> String.duplicate("x", 33))
    assert {:ok, <<0x88, 2, 1009::16>>} = :gen_tcp.recv(socket, 4, 2000)
  end
end
