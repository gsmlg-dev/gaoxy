defmodule Gaoxy.HTTP.WebSocket.ConfiguredLimitsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.WebSocket

  defmodule Handler do
    def init(state), do: {:ok, state}
    def handle_in({bytes, opcode: opcode}, state), do: {:push, {opcode, bytes}, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule Upgrade do
    def init(options), do: options
    def call(conn, options), do: WebSockAdapter.upgrade(conn, Handler, nil, options)
  end

  test "the omitted message limit follows an explicitly larger frame limit" do
    assert %{max_frame_size: 16_777_216, max_message_size: 16_777_216} =
             limits(max_frame_size: 16_777_216)
  end

  test "the omitted message limit also follows a smaller frame limit" do
    assert %{max_frame_size: 1024, max_message_size: 1024} = limits(max_frame_size: 1024)
  end

  test "the default frame and message capacities remain 256 KiB" do
    assert %{max_frame_size: 262_144, max_message_size: 262_144} = limits([])
  end

  test "explicit message limits remain independent of frame limits" do
    assert %{max_frame_size: 1_048_576, max_message_size: 1024} =
             limits(max_frame_size: 1_048_576, max_message_size: 1024)

    assert %{max_frame_size: 262_144, max_message_size: 1_048_576} =
             limits(max_message_size: 1_048_576)
  end

  test "invalid frame and message limits are still rejected" do
    for key <- [:max_frame_size, :max_message_size], value <- [0, -1, nil, :infinity] do
      assert {:error, :invalid_websocket_upgrade} = prepare([{key, value}])
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

  defp limits(options) do
    {:ok, %{response: {:websocket, Handler, nil, limits, []}}} = prepare(options)
    limits
  end

  defp prepare(options) do
    request = %{
      method: "GET",
      version: :"HTTP/1.1",
      body: :none,
      headers: [
        {"upgrade", "websocket"},
        {"connection", "Upgrade"},
        {"sec-websocket-version", "13"},
        {"sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ=="}
      ]
    }

    WebSocket.prepare(%{request: request, response: nil}, {Handler, nil, options})
  end

  defp response_head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, 2000)
      response_head(socket, bytes <> byte)
    end
  end
end
