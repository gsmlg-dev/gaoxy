defmodule Gaoxy.HTTP.WebSocket.DefaultCapacityNetworkTest do
  use ExUnit.Case, async: true

  defmodule Handler do
    def init(state), do: {:push, {:binary, :binary.copy("a", state.reply_size)}, state}

    def handle_in({"batch", _}, state),
      do: {:push, List.duplicate({:binary, String.duplicate("b", 3000)}, 129), state}

    def handle_in({bytes, opcode: opcode}, state), do: {:push, {opcode, bytes}, state}
    def handle_info(_, state), do: {:ok, state}
  end

  defmodule Upgrade do
    def init(options), do: options

    def call(conn, options) do
      state =
        case conn.path_info do
          ["large-state"] ->
            %{reply_size: 300 * 1024, retained: String.duplicate("s", 600 * 1024)}

          ["large-output"] ->
            %{reply_size: 10_000_001}

          _ ->
            %{reply_size: 300 * 1024}
        end

      WebSockAdapter.upgrade(conn, Handler, state, options)
    end
  end

  test "default H1 sends a complete 300KiB init reply and remains usable through normal close" do
    {server, socket} = connect()
    assert Gaoxy.status(server, :http).transport_bytes <= 268_435_456
    assert {2, :binary.copy("a", 300 * 1024)} == frame(socket)
    :ok = :gen_tcp.send(socket, masked(9, "after-large-reply"))
    assert {10, "after-large-reply"} == frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {8, <<1000::16>>} == frame(socket)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 2_000)
  end

  test "default input and output exceed former frame, message and adapter ceilings" do
    {server, socket} = connect("/large-output", limits: %{max_bytes: 1_048_576})
    assert {2, :binary.copy("a", 10_000_001)} == frame(socket)

    for size <- [300 * 1024, 2 * 1024 * 1024, 10_000_001] do
      payload = :binary.copy("z", size)
      :ok = :gen_tcp.send(socket, masked(2, payload))
      assert {2, ^payload} = frame(socket)

      assert %{transport_bytes: transport, websocket_bytes: retained} =
               Gaoxy.status(server, :http)

      assert transport <= 1_048_576
      assert retained >= 0
      assert %{rejected: 0} = Gaoxy.status(server, :http)
    end

    ping_and_close(socket)
  end

  test "129 legal fragments and a 129 message callback batch remain valid" do
    {_server, socket} = connect()
    assert {2, _} = frame(socket)

    for index <- 1..129 do
      :ok = :gen_tcp.send(socket, masked(if(index == 1, do: 2, else: 0), "f", index == 129))
    end

    assert {2, String.duplicate("f", 129)} == frame(socket)
    :ok = :gen_tcp.send(socket, masked(1, "batch"))
    for _ <- 1..129, do: assert({2, String.duplicate("b", 3000)} == frame(socket))
    ping_and_close(socket)
  end

  test "explicit generic budgets do not cap retained application state or cumulative transfer" do
    {server, socket} =
      connect("/large-state", limits: %{max_bytes: 1_048_576, max_state: 131_072})

    assert {2, _} = frame(socket)

    for _ <- 1..12 do
      payload = String.duplicate("r", 200 * 1024)
      :ok = :gen_tcp.send(socket, masked(2, payload))
      assert {2, ^payload} = frame(socket)

      assert %{transport_bytes: transport, websocket_bytes: retained} =
               Gaoxy.status(server, :http)

      assert transport <= 1_048_576
      assert retained >= 600 * 1024
    end

    ping_and_close(socket)
    await_idle(server, Gaoxy.Lifecycle.deadline(2_000))
  end

  test "default persistence survives the ordinary HTTP idle interval" do
    {_server, socket} = connect("/", limits: %{idle_timeout: 60})
    assert {2, _} = frame(socket)
    Process.send_after(self(), :after_ordinary_idle, 180)
    assert_receive :after_ordinary_idle, 500
    ping_and_close(socket)
  end

  defp connect(path \\ "/", options \\ []) do
    server = start_supervised!({Gaoxy.HTTP, [plug: {Upgrade, []}, port: 0] ++ options})
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(socket, [
        "GET ",
        path,
        " HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n",
        "Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
      ])

    assert response_head(socket, "") =~ "HTTP/1.1 101"
    {server, socket}
  end

  defp ping_and_close(socket) do
    :ok = :gen_tcp.send(socket, masked(9, "reusable"))
    assert {10, "reusable"} == frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {8, <<1000::16>>} == frame(socket)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 2_000)
  end

  defp await_idle(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0, transport_bytes: 0, websocket_bytes: 0} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

        receive do
        after
          5 -> await_idle(server, deadline)
        end
    end
  end

  defp response_head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, 2_000)
      response_head(socket, bytes <> byte)
    end
  end

  defp frame(socket) do
    {:ok, <<1::1, 0::3, opcode::4, 0::1, length::7>>} = :gen_tcp.recv(socket, 2, 5_000)

    length =
      case length do
        126 ->
          {:ok, <<size::16>>} = :gen_tcp.recv(socket, 2, 5_000)
          size

        127 ->
          {:ok, <<size::64>>} = :gen_tcp.recv(socket, 8, 5_000)
          size

        size ->
          size
      end

    payload =
      if length == 0 do
        ""
      else
        {:ok, payload} = :gen_tcp.recv(socket, length, 5_000)
        payload
      end

    {opcode, payload}
  end

  defp masked(opcode, payload, fin \\ true) do
    final = if fin, do: 1, else: 0
    size = byte_size(payload)

    prefix =
      cond do
        size < 126 -> <<final::1, 0::3, opcode::4, 1::1, size::7>>
        size <= 65_535 -> <<final::1, 0::3, opcode::4, 1::1, 126::7, size::16>>
        true -> <<final::1, 0::3, opcode::4, 1::1, 127::7, size::64>>
      end

    prefix <> <<0::32>> <> payload
  end
end
