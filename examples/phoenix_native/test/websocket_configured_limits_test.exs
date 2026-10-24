defmodule PhoenixNative.WebSocketConfiguredLimitsTest do
  use ExUnit.Case

  @frame_limit 1_048_576

  defmodule Channel do
    use Phoenix.Channel
    def join("limits", _payload, socket), do: {:ok, socket}

    def handle_in("size", %{"blob" => blob}, socket) do
      {:reply, {:ok, %{"bytes" => byte_size(blob)}}, socket}
    end
  end

  defmodule Socket do
    use Phoenix.Socket
    channel("limits", Channel)
    def connect(_params, socket, _info), do: {:ok, socket}
    def id(_socket), do: nil
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native

    socket("/large", Socket,
      websocket: [timeout: :infinity, max_frame_size: 1_048_576],
      longpoll: false
    )

    socket("/bounded", Socket,
      websocket: [timeout: :infinity, max_frame_size: 262_144],
      longpoll: false
    )

    plug(:fallback)
    defp fallback(conn, _opts), do: Plug.Conn.send_resp(conn, 200, "limits")
  end

  setup context do
    Application.put_env(:phoenix_native, Endpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      http: [
        ip: {127, 0, 0, 1},
        port: 0,
        limits: %{max_bytes: Map.get(context, :service_bytes, 128 * 1024 * 1024)}
      ],
      url: [host: "localhost"],
      secret_key_base: String.duplicate("limits-test-", 8),
      pubsub_server: PhoenixNative.PubSub,
      check_origin: false,
      code_reloader: false,
      debug_errors: false
    )

    on_exit(fn -> Application.delete_env(:phoenix_native, Endpoint) end)
    start_supervised!(Endpoint)
    {:ok, {_ip, port}} = Endpoint.server_info(:http)
    %{port: port}
  end

  test "a real Phoenix channel accepts an unfragmented message above 256 KiB", %{port: port} do
    socket = connect(port)
    payload = message(300 * 1024)
    assert byte_size(payload) > 262_144
    :ok = :gen_tcp.send(socket, masked(1, payload))
    assert_size(socket, 300 * 1024)
  end

  test "a real Phoenix channel assembles a message above 256 KiB across fragments", %{port: port} do
    socket = connect(port)
    payload = message(400 * 1024)
    <<first::binary-size(200 * 1024), last::binary>> = payload
    :ok = :gen_tcp.send(socket, masked(1, first, false))
    :ok = :gen_tcp.send(socket, masked(9, "between"))
    assert {10, "between"} = frame(socket)
    :ok = :gen_tcp.send(socket, masked(0, last))
    assert_size(socket, 400 * 1024)
  end

  test "the configured frame ceiling rejects an oversized unfragmented message", %{port: port} do
    socket = connect(port)
    :ok = :gen_tcp.send(socket, masked(1, message(@frame_limit)))
    assert {8, <<1009::16>>} = frame(socket)
  end

  test "fragment payload totals cannot exceed the inherited message ceiling", %{port: port} do
    socket = connect(port)
    payload = message(@frame_limit)
    <<first::binary-size(600 * 1024), last::binary>> = payload
    :ok = :gen_tcp.send(socket, masked(1, first, false))
    :ok = :gen_tcp.send(socket, masked(0, last))
    assert {8, <<1009::16>>} = frame(socket)
  end

  test "an explicitly smaller Phoenix frame limit still bounds messages", %{port: port} do
    socket = connect(port, "/bounded")
    :ok = :gen_tcp.send(socket, masked(1, message(300 * 1024)))
    assert {8, <<1009::16>>} = frame(socket)
  end

  @tag service_bytes: 2 * 1024 * 1024
  test "the explicit service transport budget does not clamp Phoenix message data", %{port: port} do
    socket = connect(port)
    :ok = :gen_tcp.send(socket, masked(1, message(300 * 1024)))
    assert_size(socket, 300 * 1024)
    :ok = :gen_tcp.send(socket, masked(1, message(600 * 1024)))
    assert_size(socket, 600 * 1024)
    :ok = :gen_tcp.send(socket, masked(9, "still-open"))
    assert {10, "still-open"} = frame(socket)
  end

  defp message(bytes),
    do: Jason.encode!(["1", "2", "limits", "size", %{"blob" => String.duplicate("x", bytes)}])

  defp assert_size(socket, bytes) do
    assert {1, reply} = frame(socket)

    assert [
             "1",
             "2",
             "limits",
             "phx_reply",
             %{"status" => "ok", "response" => %{"bytes" => ^bytes}}
           ] = Jason.decode!(reply)
  end

  defp connect(port, path \\ "/large") do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 2000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(socket, [
        "GET ",
        path,
        "/websocket?vsn=2.0.0 HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n",
        "Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
      ])

    assert response_head(socket, "") =~ "HTTP/1.1 101"
    :ok = :gen_tcp.send(socket, masked(1, Jason.encode!(["1", "1", "limits", "phx_join", %{}])))
    assert {1, joined} = frame(socket)
    assert ["1", "1", "limits", "phx_reply", %{"status" => "ok"}] = Jason.decode!(joined)
    socket
  end

  defp response_head(socket, bytes) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, 2000)
      response_head(socket, bytes <> byte)
    end
  end

  defp frame(socket) do
    {:ok, <<1::1, 0::3, opcode::4, 0::1, length::7>>} = :gen_tcp.recv(socket, 2, 5000)

    length =
      case length do
        126 ->
          {:ok, <<size::16>>} = :gen_tcp.recv(socket, 2, 5000)
          size

        127 ->
          {:ok, <<size::64>>} = :gen_tcp.recv(socket, 8, 5000)
          size

        size ->
          size
      end

    {:ok, payload} = :gen_tcp.recv(socket, length, 5000)
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
