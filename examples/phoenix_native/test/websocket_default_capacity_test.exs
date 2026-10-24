defmodule PhoenixNative.WebSocketDefaultCapacityTest do
  use ExUnit.Case

  defmodule Composer do
    use Phoenix.LiveView
    def mount(_, _, socket), do: {:ok, assign(socket, :body, String.duplicate("a", 320 * 1024))}

    def render(assigns) do
      ~H"""
      <div id="large-initial-render">{@body}</div>
      """
    end
  end

  defmodule Router do
    use Phoenix.Router
    import Phoenix.LiveView.Router

    pipeline :browser do
      plug(:accepts, ["html"])
      plug(:fetch_session)
      plug(:fetch_live_flash)
      plug(:put_root_layout, html: {PhoenixNative.Layouts, :root})
      plug(:protect_from_forgery)
    end

    scope "/" do
      pipe_through(:browser)
      live("/compose", Composer)
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    @session [store: :cookie, key: "_default_capacity", signing_salt: "default_capacity"]
    socket("/live", Phoenix.LiveView.Socket,
      websocket: [timeout: :infinity, connect_info: [session: @session]],
      longpoll: false
    )

    plug(Plug.Session, @session)
    plug(Router)
  end

  setup do
    Application.put_env(:phoenix_native, Endpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      http: [ip: {127, 0, 0, 1}, port: 0],
      url: [host: "localhost"],
      secret_key_base: String.duplicate("default_capacity", 8),
      pubsub_server: PhoenixNative.PubSub,
      live_view: [signing_salt: "default_capacity"],
      check_origin: false,
      code_reloader: false,
      debug_errors: false
    )

    on_exit(fn -> Application.delete_env(:phoenix_native, Endpoint) end)
    start_supervised!(Endpoint)
    {:ok, {_, port}} = Endpoint.server_info(:http)
    %{port: port}
  end

  test "actual LiveView initial reply exceeds 313781 bytes with complete render and heartbeat", %{
    port: port
  } do
    {socket, _topic} = join_live(port, page(port), String.duplicate("a", 320 * 1024))
    send_json(socket, [nil, "2", "phoenix", "heartbeat", %{}])
    assert [nil, "2", "phoenix", "phx_reply", %{"status" => "ok"}] = receive_json(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {8, <<1000::16>>} == frame(socket)
  end

  defp receive_initial_json(socket) do
    assert {1, payload} = frame(socket)
    assert byte_size(payload) >= 313_781
    Jason.decode!(payload)
  end

  defp page(port, cookie \\ "") do
    socket = connect(port)

    :ok =
      :gen_tcp.send(socket, [
        "GET /compose HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n",
        cookie_header(cookie),
        "\r\n"
      ])

    [head, html] = socket |> recv_all([]) |> :binary.split("\r\n\r\n")
    assert head =~ "HTTP/1.1 200"

    cookie =
      case Regex.run(~r/\r\nset-cookie: ([^;\r\n]+)/i, head) do
        [_, value] -> value
        nil -> cookie
      end

    assert cookie != ""

    %{
      html: html,
      cookie: cookie,
      csrf: attribute(html, ~r/name="csrf-token" content="([^"]+)"/),
      id: attribute(html, ~r/id="(phx-[^"]+)"/),
      session: attribute(html, ~r/data-phx-session="([^"]+)"/),
      static: attribute(html, ~r/data-phx-static="([^"]*)"/)
    }
  end

  defp join_live(port, page, expected) do
    path = "/live/websocket?" <> URI.encode_query(%{"vsn" => "2.0.0", "_csrf_token" => page.csrf})
    socket = upgrade(port, path, page.cookie)
    topic = "lv:" <> page.id

    send_json(socket, [
      "1",
      "1",
      topic,
      "phx_join",
      %{
        "url" => "http://localhost:#{port}/compose",
        "params" => %{"_csrf_token" => page.csrf, "_mounts" => 0},
        "session" => page.session,
        "static" => page.static
      }
    ])

    assert [
             "1",
             "1",
             ^topic,
             "phx_reply",
             %{"status" => "ok", "response" => %{"rendered" => rendered}}
           ] = receive_initial_json(socket)

    if expected, do: assert(Jason.encode!(rendered) =~ expected)
    {socket, topic}
  end

  defp attribute(html, regex) do
    assert [_, value] = Regex.run(regex, html)
    value
  end

  defp upgrade(port, path, cookie) do
    socket = connect(port)

    :ok =
      :gen_tcp.send(socket, [
        "GET ",
        path,
        " HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n",
        cookie_header(cookie),
        "\r\n"
      ])

    assert response_head(socket, "") =~ "HTTP/1.1 101"
    socket
  end

  defp cookie_header(""), do: ""
  defp cookie_header(cookie), do: "Cookie: " <> cookie <> "\r\n"

  defp connect(port) do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp recv_all(socket, bytes) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, next} -> recv_all(socket, [bytes, next])
      {:error, :closed} -> IO.iodata_to_binary(bytes)
    end
  end

  defp send_json(socket, message), do: :gen_tcp.send(socket, masked(1, Jason.encode!(message)))

  defp receive_json(socket) do
    assert {1, payload} = frame(socket)
    Jason.decode!(payload)
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

    {:ok, payload} = :gen_tcp.recv(socket, length, 5_000)
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
