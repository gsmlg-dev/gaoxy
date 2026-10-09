defmodule Gaoxy.HTTP.WebSocket.NetworkTest do
  use ExUnit.Case, async: true

  defmodule Handler do
    @behaviour WebSock
    def init(owner) do
      send(owner, {:ws_init, self()})
      {:ok, owner}
    end

    def handle_in({"stop", _}, owner), do: {:stop, :normal, {1000, "bye"}, owner}

    def handle_in({"block", _}, owner) do
      send(owner, {:ws_blocked, self()})

      receive do
        :never -> {:ok, owner}
      end
    end

    def handle_in({bytes, opcode: opcode}, owner), do: {:push, {opcode, bytes}, owner}

    def handle_control({bytes, opcode: opcode}, owner) do
      send(owner, {:ws_control, opcode, bytes})
      {:ok, owner}
    end

    def handle_info({:push, bytes}, owner), do: {:reply, :ignored, {:text, bytes}, owner}
    def terminate(reason, owner), do: send(owner, {:ws_terminated, reason})
  end

  defmodule Upgrade do
    import Plug.Conn
    def init(opts), do: opts

    def call(conn, opts) do
      if opts[:before_upgrade] do
        send(opts[:owner], {:before_upgrade, self()})

        receive do
          :upgrade -> :ok
        end
      end

      conn
      |> put_resp_header("sec-websocket-protocol", "echo")
      |> WebSockAdapter.upgrade(Handler, opts[:owner], Keyword.get(opts, :websocket, []))
    end
  end

  test "native dispatch preserves response headers and runs the WebSock lifecycle in its owner" do
    {socket, _server} = connect()
    assert_receive {:ws_init, owner}
    :ok = :gen_tcp.send(socket, masked(1, "hello"))
    assert {1, "hello"} = frame(socket)
    send(owner, {:push, "info"})
    assert {1, "info"} = frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {8, <<1000::16>>} = frame(socket)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert_receive {:ws_terminated, :remote}
    refute_receive {:ws_terminated, _}, 20
  end

  test "fragmentation allows interleaved ping, auto-pong and control callback" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, masked(1, "hel", false) <> masked(9, "p") <> masked(0, "lo"))
    assert {10, "p"} = frame(socket)
    assert {1, "hello"} = frame(socket)
    assert_receive {:ws_control, :ping, "p"}
  end

  test "invalid client framing receives a protocol close" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, <<0x81, 1, ?x>>)
    assert {8, <<1002::16>>} = frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1002::16>>))
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end

  test "local stop sends close and invokes terminate once with its original reason" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, masked(1, "stop"))
    assert {8, <<1000::16, "bye">>} = frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert_receive {:ws_terminated, :normal}
  end

  test "drain closes WebSocket with a bounded handshake before confirming service removal" do
    {socket, server} = connect()
    task = Task.async(fn -> Gaoxy.remove(server, :http, 1000) end)
    assert {8, <<1001::16>>} = frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1001::16>>))
    assert :ok = Task.await(task)
    assert_receive {:ws_terminated, :shutdown}
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end

  test "a blocked WebSock callback cannot outlive its callback budget" do
    {socket, _} = connect(websocket: [callback_timeout: 50])
    :ok = :gen_tcp.send(socket, masked(1, "block"))
    assert_receive {:ws_blocked, owner}
    monitor = Process.monitor(owner)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}, 1000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
  end

  test "upgrade establishes its own lifetime and idle budget" do
    {socket, _} =
      connect(websocket: [timeout: 200, max_lifetime: 1000], http_limits: %{request_timeout: 50})

    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 80)
    :ok = :gen_tcp.send(socket, masked(1, "alive"))
    assert {1, "alive"} = frame(socket)
  end

  test "Phoenix transport policies can accompany the WebSock wire options" do
    {socket, _} =
      connect(
        websocket: [
          path: "/websocket",
          serializer: [{:json, "2"}],
          error_handler: {__MODULE__, :unused, []},
          transport_log: false,
          connect_info: [:peer_data],
          check_origin: ["https://example.test"],
          check_csrf: true
        ]
      )

    :ok = :gen_tcp.send(socket, masked(1, "phoenix"))
    assert {1, "phoenix"} = frame(socket)
  end

  test "an upgrade crossing the pause barrier never commits a 101 response" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Upgrade, [owner: self(), before_upgrade: true]})
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :gen_tcp.send(socket, request())
    assert_receive {:before_upgrade, owner}
    assert :ok = Gaoxy.pause(server, :http)
    send(owner, :upgrade)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    refute_receive {:ws_init, _}, 20
    refute_receive {:ws_terminated, _}, 20
  end

  test "WebSock state is included in retained byte accounting" do
    {_socket, server} = connect()
    assert_receive {:ws_init, _}
    assert Gaoxy.status(server, :http).retained_bytes >= :erlang.external_size(self())
  end

  test "close handshake times out when peer never acknowledges" do
    {socket, _} = connect(websocket: [close_timeout: 30])
    :ok = :gen_tcp.send(socket, masked(1, "stop"))
    assert {8, <<1000::16, "bye">>} = frame(socket)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1000)
    assert_receive {:ws_terminated, :normal}
  end

  defp connect(options \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {Upgrade, [owner: self(), websocket: Keyword.get(options, :websocket, [])]},
        http_limits: Keyword.get(options, :http_limits, %{})
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, request())
    head = head(socket, "")
    assert head =~ "HTTP/1.1 101 Switching Protocols\r\n"
    assert head =~ "sec-websocket-protocol: echo\r\n"
    assert head =~ "sec-websocket-accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"
    {socket, server}
  end

  defp request,
    do:
      "GET /socket HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: echo\r\n\r\n"

  defp head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (case :gen_tcp.recv(socket, 1, 1000) do
           {:ok, byte} -> head(socket, bytes <> byte)
         end)
  end

  defp frame(socket) do
    {:ok, <<1::1, 0::3, opcode::4, 0::1, length::7>>} = :gen_tcp.recv(socket, 2, 1000)

    length =
      case length do
        126 ->
          {:ok, <<size::16>>} = :gen_tcp.recv(socket, 2, 1000)
          size

        127 ->
          {:ok, <<size::64>>} = :gen_tcp.recv(socket, 8, 1000)
          size

        size ->
          size
      end

    if length == 0,
      do: {opcode, ""},
      else:
        (case :gen_tcp.recv(socket, length, 1000) do
           {:ok, bytes} -> {opcode, bytes}
         end)
  end

  defp masked(opcode, payload, fin \\ true) do
    final = if fin, do: 1, else: 0
    <<final::1, 0::3, opcode::4, 1::1, byte_size(payload)::7, 0::32>> <> payload
  end
end
