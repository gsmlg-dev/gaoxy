defmodule PhoenixNative.WebSocketPhoenixCompatibilityTest do
  use ExUnit.Case
  @frame_limit 2_097_152

  defmodule DraftStore do
    use Agent
    def start_link(_), do: Agent.start_link(fn -> "" end, name: __MODULE__)
    def read, do: Agent.get(__MODULE__, & &1)
    def write(body), do: Agent.update(__MODULE__, fn _ -> body end)
  end

  defmodule Composer do
    use Phoenix.LiveView
    def mount(_params, _session, socket), do: {:ok, assign(socket, :body, DraftStore.read())}

    def handle_event("change-draft", %{"draft" => %{"text_body" => body}}, socket) do
      DraftStore.write(body)
      {:noreply, assign(socket, :body, body)}
    end

    def render(assigns) do
      ~H"""
      <form id="composer" phx-change="change-draft">
        <textarea id="draft-body" name="draft[text_body]">{@body}</textarea>
      </form>
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

  defmodule Channel do
    use Phoenix.Channel

    def join("compatibility", %{"observe" => true}, socket) do
      send(
        Process.whereis(PhoenixNative.WebSocketPhoenixCompatibilityTest),
        {:channel_joined, self(), socket.transport_pid}
      )

      {:ok, socket}
    end

    def join("compatibility", _, socket), do: {:ok, socket}
    def handle_in("echo", payload, socket), do: {:reply, {:ok, payload}, socket}
  end

  defmodule Socket do
    use Phoenix.Socket
    channel("compatibility", Channel)
    def connect(_, socket, _), do: {:ok, socket}
    def id(_), do: "compatibility:disconnect"
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    @session [store: :cookie, key: "_compatibility", signing_salt: "compatibility"]
    socket("/application", Socket, websocket: [log: false, code_reloader: false], longpoll: false)

    socket("/live", Phoenix.LiveView.Socket,
      websocket: [max_frame_size: 2_097_152, connect_info: [session: @session]],
      longpoll: false
    )

    plug(Plug.Session, @session)
    plug(Router)
  end

  setup do
    start_supervised!(DraftStore)

    Application.put_env(:phoenix_native, Endpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      http: [ip: {127, 0, 0, 1}, port: 0, limits: %{max_bytes: 16_777_216}],
      url: [host: "localhost"],
      secret_key_base: String.duplicate("compatibility", 8),
      pubsub_server: PhoenixNative.PubSub,
      live_view: [signing_salt: "compatibility"],
      check_origin: false,
      code_reloader: false,
      debug_errors: false
    )

    on_exit(fn -> Application.delete_env(:phoenix_native, Endpoint) end)
    start_supervised!(Endpoint)
    {:ok, {_, port}} = Endpoint.server_info(:http)
    %{port: port}
  end

  test "Phoenix log:false and code_reloader:false complete an H1 upgrade and channel exchange", %{
    port: port
  } do
    socket = upgrade(port, "/application/websocket?vsn=2.0.0", "")
    send_json(socket, ["1", "1", "compatibility", "phx_join", %{}])
    assert ["1", "1", "compatibility", "phx_reply", %{"status" => "ok"}] = receive_json(socket)
    send_json(socket, ["1", "2", "compatibility", "echo", %{"message" => "wire-ok"}])

    assert [
             "1",
             "2",
             "compatibility",
             "phx_reply",
             %{"status" => "ok", "response" => %{"message" => "wire-ok"}}
           ] = receive_json(socket)
  end

  test "Phoenix disconnect broadcast closes normally and cleans up the transport and channel", %{
    port: port
  } do
    Process.register(self(), __MODULE__)
    socket = upgrade(port, "/application/websocket?vsn=2.0.0", "")
    send_json(socket, ["1", "1", "compatibility", "phx_join", %{"observe" => true}])
    assert ["1", "1", "compatibility", "phx_reply", %{"status" => "ok"}] = receive_json(socket)
    assert_receive {:channel_joined, channel, transport}, 2_000
    channel_ref = Process.monitor(channel)
    transport_ref = Process.monitor(transport)

    :ok = Endpoint.broadcast("compatibility:disconnect", "disconnect", %{})
    assert {8, <<1000::16>>} = frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    # H1 closes its connection owner with :local_closed after the WebSocket
    # close handshake; Phoenix propagates that process exit to its channel.
    assert_receive {:DOWN, ^transport_ref, :process, ^transport, {:shutdown, :local_closed}},
                   2_000

    assert_receive {:DOWN, ^channel_ref, :process, ^channel, {:shutdown, :local_closed}}, 2_000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 2_000)
  end

  for fragmented <- [false, true] do
    test "actual LiveView preserves and reconnects escaped 300KiB composer input, fragmented=#{fragmented}",
         %{port: port} do
      page = page(port)
      {socket, topic} = join_live(port, page)
      body = String.duplicate("\"", 300 * 1024)
      encoded_form = URI.encode_query(%{"draft[text_body]" => body})

      payload =
        Jason.encode!([
          "1",
          "2",
          topic,
          "event",
          %{"type" => "form", "event" => "change-draft", "value" => encoded_form}
        ])

      assert byte_size(payload) > 900_000
      assert byte_size(payload) < @frame_limit

      if unquote(fragmented) do
        <<first::binary-size(200_000), rest::binary>> = payload
        :ok = :gen_tcp.send(socket, masked(1, first, false))
        :ok = :gen_tcp.send(socket, masked(9, "composer-ping"))
        assert {10, "composer-ping"} = frame(socket)
        :ok = :gen_tcp.send(socket, masked(0, rest))
      else
        :ok = :gen_tcp.send(socket, masked(1, payload))
      end

      assert ["1", "2", ^topic, "phx_reply", %{"status" => "ok", "response" => response}] =
               receive_json(socket)

      escaped = String.duplicate("&quot;", 300 * 1024)
      assert response |> Jason.encode!() |> String.contains?(escaped)
      assert DraftStore.read() == body
      :gen_tcp.close(socket)

      reloaded = page(port, page.cookie)
      assert reloaded.html =~ escaped
      assert DraftStore.read() == body
      {_reconnected, _topic} = join_live(port, reloaded, escaped)
      assert DraftStore.read() == body
    end
  end

  for fragmented <- [false, true] do
    test "actual LiveView rejects configured oversize input, fragmented=#{fragmented}", %{
      port: port
    } do
      {socket, topic} = join_live(port, page(port))

      payload =
        Jason.encode!([
          "1",
          "2",
          topic,
          "event",
          %{
            "type" => "form",
            "event" => "change-draft",
            "value" => String.duplicate("x", @frame_limit)
          }
        ])

      if unquote(fragmented) do
        <<first::binary-size(1_100_000), rest::binary>> = payload
        :ok = :gen_tcp.send(socket, masked(1, first, false))
        :ok = :gen_tcp.send(socket, masked(0, rest))
      else
        :ok = :gen_tcp.send(socket, masked(1, payload))
      end

      assert {8, <<1009::16>>} = frame(socket)
      assert DraftStore.read() == ""
    end
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

  defp join_live(port, page, expected \\ nil) do
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
           ] = receive_json(socket)

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
