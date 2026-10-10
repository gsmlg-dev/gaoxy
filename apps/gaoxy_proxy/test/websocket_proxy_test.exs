defmodule Gaoxy.Proxy.WebSocketTest do
  use ExUnit.Case, async: false
  import Bitwise

  alias Gaoxy.Proxy.WebSocket, as: Proxy
  @timeout 3_000

  defmodule Local do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.HTTP1.Response.send_resp(exchange, 200, [], "local")
  end

  test "configuration requires one fixed authority, verified TLS and finite limits" do
    assert {:ok, _} = Proxy.init(%{upstream: "wss://localhost:443"})

    for upstream <- [
          "http://localhost",
          "ws://user:secret@localhost",
          "ws://localhost/path",
          "ws://localhost?query",
          "ws://localhost#fragment",
          "ws://"
        ] do
      assert {:error, _} = Proxy.init(%{upstream: upstream})
    end

    assert {:error, _} = Proxy.init(%{upstream: "wss://localhost", ssl: [verify: :verify_none]})
    assert {:error, _} = Proxy.init(%{upstream: "ws://localhost", idle_timeout: :infinity})
  end

  @tag :proxy_policy
  test "local routing and WebSocket proxy preserve path, protocol, binary and close semantics" do
    {url, peer} =
      peer(fn socket, owner ->
        head = head(socket)
        send(owner, {:upstream_head, self(), head})
        receive do: (:open -> :ok)
        :ok = :gen_tcp.send(socket, handshake(head, "chat") <> frame(1, "hello"))
        assert {2, <<0, 1, 255>>} = client_frame(socket)
        :ok = :gen_tcp.send(socket, frame(2, <<255, 1, 0>>))
        assert {8, <<1008::16, "policy">>} = client_frame(socket)
        :ok = :gen_tcp.send(socket, frame(8, <<1008::16, "policy">>))
      end)

    server = server(url)
    local = connect(server)

    :ok =
      :gen_tcp.send(local, "GET /local HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

    assert head(local) =~ "200 OK"
    assert {:ok, "local"} = :gen_tcp.recv(local, 5, @timeout)

    socket = connect(server)

    :ok =
      :gen_tcp.send(
        socket,
        request("/ws/a%2Fb?q=%2F&x=1", [
          {"X-Trace", "one"},
          {"X-Trace", "two"},
          {"Proxy-Connection", "keep-alive"},
          {"Connection", "X-Remove"},
          {"X-Remove", "secret"},
          {"Forwarded", "for=spoofed"},
          {"X-Forwarded-For", "spoofed"}
        ])
      )

    assert_receive {:upstream_head, ^peer, upstream}, @timeout
    assert upstream =~ "GET /ws/a%2Fb?q=%2F&x=1 HTTP/1.1\r\n"
    assert upstream =~ "X-Trace: one\r\nX-Trace: two\r\n"
    refute String.downcase(upstream) =~ "x-remove:"
    refute String.downcase(upstream) =~ "proxy-connection:"
    refute upstream =~ "spoofed"
    assert String.downcase(upstream) =~ "x-forwarded-for: 127.0.0.1\r\n"
    assert {:error, :timeout} = :gen_tcp.recv(socket, 1, 20)
    send(peer, :open)
    response = head(socket)
    assert response =~ "101 Switching Protocols"
    assert response =~ "sec-websocket-protocol: chat\r\n"
    assert {1, "hello"} = server_frame(socket)
    :ok = :gen_tcp.send(socket, masked(9, "ping"))
    assert {10, "ping"} = server_frame(socket)
    :ok = :gen_tcp.send(socket, masked(2, <<0, 1, 255>>))
    assert {2, <<255, 1, 0>>} = server_frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1008::16, "policy">>))
    assert {8, <<1008::16, "policy">>} = server_frame(socket)
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  @tag :proxy_policy
  test "a present empty query remains in the upstream raw target" do
    {url, peer} =
      peer(fn socket, owner ->
        head = head(socket)
        send(owner, {:raw_target, self(), head})
        :ok = :gen_tcp.send(socket, handshake(head))
        assert {8, <<1000::16>>} = client_frame(socket)
        :gen_tcp.send(socket, frame(8, <<1000::16>>))
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("/ws?"))
    assert head(socket) =~ "101 Switching Protocols"
    assert_receive {:raw_target, ^peer, upstream}, @timeout
    assert String.starts_with?(upstream, "GET /ws? HTTP/1.1\r\n")
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {8, <<1000::16>>} = server_frame(socket)
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  for payload <- [<<>>, <<1011::16, "upstream error">>] do
    @payload payload
    test "upstream Close #{inspect(payload)} reaches downstream without rewriting" do
      payload = @payload

      {url, peer} =
        peer(fn socket, _ ->
          head = head(socket)
          :ok = :gen_tcp.send(socket, handshake(head) <> frame(8, payload))
          assert {8, ^payload} = client_frame(socket)
        end)

      server = server(url)
      socket = connect(server)
      :ok = :gen_tcp.send(socket, request())
      assert head(socket) =~ "101 Switching Protocols"
      assert {8, ^payload} = server_frame(socket)
      :ok = :gen_tcp.send(socket, masked(8, payload))
      assert_peer(peer)
      assert :ok = Gaoxy.stop(server, @timeout)
    end
  end

  test "upstream rejection produces an HTTP error before downstream upgrade" do
    {url, peer} =
      peer(fn socket, _ ->
        _ = head(socket)
        :gen_tcp.send(socket, "HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert head(socket) =~ "502 Bad Gateway"
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "service drain closes both peers and confirms the upstream process is gone" do
    {url, peer} =
      peer(fn socket, owner ->
        :ok = :gen_tcp.send(socket, handshake(head(socket)))
        assert {8, <<1001::16>>} = client_frame(socket)
        send(owner, {:upstream_closing, self()})
        receive do: (:close -> :ok)
        :gen_tcp.send(socket, frame(8, <<1001::16>>))
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert head(socket) =~ "101 Switching Protocols"
    stop = Task.async(fn -> Gaoxy.stop(server, @timeout) end)
    assert {8, <<1001::16>>} = server_frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1001::16>>))
    assert_receive {:upstream_closing, ^peer}, @timeout
    assert Task.yield(stop, 20) == nil
    send(peer, :close)
    assert_peer(peer)
    assert Task.await(stop, @timeout) == :ok
  end

  test "insufficient service byte budget rejects before opening upstream" do
    assert sessions() == []

    {url, peer} =
      peer(fn socket, owner ->
        send(owner, {:unexpected_upstream, self()})
        :gen_tcp.close(socket)
      end)

    server = server(url, max_bytes: 1_024)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert head(socket) =~ "503 Service Unavailable"
    refute_receive {:unexpected_upstream, ^peer}, 20
    eventually(fn -> sessions() == [] end)
  end

  for payload <- [<<>>, <<1000::16>>, <<1001::16, "away">>, <<1011::16, "failed">>] do
    @payload payload
    test "downstream Close #{inspect(payload)} preserves its details upstream" do
      payload = @payload

      {url, peer} =
        peer(fn socket, _ ->
          :ok = :gen_tcp.send(socket, handshake(head(socket)))
          assert {8, ^payload} = client_frame(socket)
          :gen_tcp.send(socket, frame(8, payload))
        end)

      server = server(url)
      socket = connect(server)
      :ok = :gen_tcp.send(socket, request())
      assert head(socket) =~ "101 Switching Protocols"
      :ok = :gen_tcp.send(socket, masked(8, payload))
      assert {8, ^payload} = server_frame(socket)
      assert_peer(peer)
      assert :ok = Gaoxy.stop(server, @timeout)
    end
  end

  test "killing the downstream owner confirms upstream cleanup independently of terminate callbacks" do
    {url, peer} =
      peer(fn socket, _ ->
        :ok = :gen_tcp.send(socket, handshake(head(socket)))
        assert {8, <<1001::16>>} = client_frame(socket)
        :gen_tcp.send(socket, frame(8, <<1001::16>>))
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert head(socket) =~ "101 Switching Protocols"
    [session] = sessions()
    %{owner: owner, socket: %HTTP.WebSocket{pid: upstream}} = :sys.get_state(session)
    guardian_monitor = Process.monitor(session)
    upstream_monitor = Process.monitor(upstream)
    assert Gaoxy.status(server, :http).cleanup_pending == 1
    Process.exit(owner, :kill)
    assert_peer(peer)
    assert_receive {:DOWN, ^upstream_monitor, :process, ^upstream, :normal}, @timeout
    assert_receive {:DOWN, ^guardian_monitor, :process, ^session, :normal}, @timeout

    eventually(fn ->
      status = Gaoxy.status(server, :http)
      status.active == 0 and status.cleanup_pending == 0 and status.retained_bytes == 0
    end)

    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "stop deadline returns cleanup pending while the guardian awaits upstream termination" do
    {url, peer} =
      peer(fn socket, owner ->
        :ok = :gen_tcp.send(socket, handshake(head(socket)))
        assert {8, <<1001::16>>} = client_frame(socket)
        send(owner, {:holding_close, self()})
        receive do: (:close -> :ok)
        :gen_tcp.send(socket, frame(8, <<1001::16>>))
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert head(socket) =~ "101 Switching Protocols"
    [session] = sessions()
    %{socket: %HTTP.WebSocket{pid: upstream}} = :sys.get_state(session)
    monitor = Process.monitor(session)
    stop = Task.async(fn -> Gaoxy.stop(server, 100) end)
    assert {8, <<1001::16>>} = server_frame(socket)
    :ok = :gen_tcp.send(socket, masked(8, <<1001::16>>))
    assert_receive {:holding_close, ^peer}, @timeout
    assert Task.await(stop, @timeout) == {:error, {:deadline_exceeded, :cleanup_pending}}
    assert Process.alive?(session)
    assert Process.alive?(upstream)
    send(peer, :close)
    assert_peer(peer)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    eventually(fn -> not Process.alive?(server) end)
  end

  defp sessions do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor), do: pid
  end

  defp eventually(fun), do: eventually(fun, Gaoxy.Lifecycle.deadline(@timeout))

  defp eventually(fun, deadline) do
    unless fun.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> eventually(fun, deadline)
      end
    end
  end

  defp server(url, limits \\ []) do
    config = %{upstream: url, max_message_bytes: 1024, close_timeout: 1000}

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint:
          {Gaoxy.HTTP.Router,
           [
             %{path: "/local", target: {Local, []}},
             %{path: {:prefix, "/ws"}, target: {Proxy, config}}
           ]},
        limits: Map.new(Keyword.merge([max_bytes: 8_388_608], limits))
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp request(path \\ "/ws", headers \\ []) do
    "GET #{path} HTTP/1.1\r\nHost: downstream.test\r\nUpgrade: websocket\r\n" <>
      "Connection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" <>
      "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: chat\r\n" <>
      Enum.map_join(headers, "", fn {k, v} -> "#{k}: #{v}\r\n" end) <> "\r\n"
  end

  defp peer(fun) do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    pid =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            fun.(socket, owner)
            send(owner, {:peer_done, self()})
          after
            :gen_tcp.close(socket)
          end
        rescue
          error ->
            send(owner, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          :gen_tcp.close(listener)
        end
      end)

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
      :gen_tcp.close(listener)
    end)

    {"ws://127.0.0.1:#{port}", pid}
  end

  defp assert_peer(peer) do
    receive do
      {:peer_done, ^peer} -> :ok
      {:peer_error, ^peer, error} -> flunk(error)
    after
      @timeout -> flunk("upstream did not finish")
    end
  end

  defp head(socket, bytes \\ "") do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
      head(socket, bytes <> byte)
    end
  end

  defp handshake(head, protocol \\ "") do
    [key] = Regex.run(~r/(?im)^sec-websocket-key: ([^\r]+)\r$/, head, capture: :all_but_first)
    accept = Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

    "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" <>
      "Sec-WebSocket-Accept: #{accept}\r\n" <>
      if(protocol == "", do: "\r\n", else: "Sec-WebSocket-Protocol: #{protocol}\r\n\r\n")
  end

  defp frame(opcode, payload),
    do: <<1::1, 0::3, opcode::4, 0::1, byte_size(payload)::7>> <> payload

  defp masked(opcode, payload),
    do: <<1::1, 0::3, opcode::4, 1::1, byte_size(payload)::7, 0::32>> <> payload

  defp server_frame(socket), do: read_frame(socket, 0)
  defp client_frame(socket), do: read_frame(socket, 1)

  defp read_frame(socket, mask_bit) do
    {:ok, <<1::1, 0::3, opcode::4, ^mask_bit::1, length::7>>} = :gen_tcp.recv(socket, 2, @timeout)

    mask =
      if mask_bit == 1 do
        {:ok, mask} = :gen_tcp.recv(socket, 4, @timeout)
        :binary.bin_to_list(mask) |> List.to_tuple()
      end

    bytes =
      if length == 0 do
        ""
      else
        {:ok, bytes} = :gen_tcp.recv(socket, length, @timeout)
        bytes
      end

    bytes =
      if mask do
        for {byte, i} <- Enum.with_index(:binary.bin_to_list(bytes)),
            into: <<>>,
            do: <<bxor(byte, elem(mask, rem(i, 4)))>>
      else
        bytes
      end

    {opcode, bytes}
  end
end
