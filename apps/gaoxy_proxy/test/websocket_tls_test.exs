defmodule Gaoxy.Proxy.WebSocketTLSTest do
  # Cleanup assertions observe shared application supervisors after async tests finish.
  use ExUnit.Case, async: false
  import Bitwise

  alias Gaoxy.Proxy.WebSocket, as: Proxy
  @moduletag :loopback
  @moduletag :capture_log
  @timeout 3_000

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-proxy-wss-#{System.unique_integer([:positive])}")

    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    trusted = Path.join(directory, "trusted")
    untrusted = Path.join(directory, "untrusted")
    on_exit(fn -> File.rm_rf!(directory) end)

    for output <- [trusted, untrusted] do
      {log, status} = System.cmd("bash", [script, output], stderr_to_stdout: true)
      assert status == 0, log
    end

    {:ok, trusted: trusted, untrusted: untrusted}
  end

  test "configured private CA verifies WSS and forwards text, binary and Close", context do
    baseline = supervisor_counts()

    {url, peer} =
      tls_peer(context.trusted, "localhost", fn socket ->
        request = head(:ssl, socket)
        assert request =~ "GET /secure?q=%2F HTTP/1.1\r\n"
        :ok = :ssl.send(socket, handshake(request) <> frame(1, "secure upstream"))
        assert {1, "secure downstream"} = read_frame(:ssl, socket, 1)
        :ok = :ssl.send(socket, frame(2, <<255, 0, 1>>))
        assert {2, <<0, 255, 2>>} = read_frame(:ssl, socket, 1)
        assert {8, <<1000::16, "done">>} = read_frame(:ssl, socket, 1)
        :ok = :ssl.send(socket, frame(8, <<1000::16, "done">>))
      end)

    server = server(url, Path.join(context.trusted, "ca.pem"))
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert_receive {:tls_attempt, ^peer}, @timeout
    assert head(:gen_tcp, socket) =~ "101 Switching Protocols"
    assert {1, "secure upstream"} = read_frame(:gen_tcp, socket, 0)
    :ok = :gen_tcp.send(socket, masked(1, "secure downstream"))
    assert {2, <<255, 0, 1>>} = read_frame(:gen_tcp, socket, 0)
    :ok = :gen_tcp.send(socket, masked(2, <<0, 255, 2>>))
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16, "done">>))
    assert {8, <<1000::16, "done">>} = read_frame(:gen_tcp, socket, 0)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_receive {:tls_finished, ^peer, :ok}, @timeout
    assert_cleanup(server, baseline)
    assert_no_replay(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "untrusted CA fails before downstream 101 without replay and releases cleanup", context do
    assert_rejected(
      context.trusted,
      "localhost",
      Path.join(context.untrusted, "ca.pem"),
      :unknown_ca
    )
  end

  test "trusted certificate for another host fails before downstream 101 without fallback",
       context do
    # The generated SAN contains localhost and 127.0.0.1. A wildcard listener
    # remains reachable through this different loopback address on Linux.
    assert_rejected(
      context.trusted,
      "127.0.0.2",
      Path.join(context.trusted, "ca.pem"),
      :bad_certificate
    )
  end

  defp assert_rejected(directory, hostname, ca, alert) do
    baseline = supervisor_counts()

    {url, peer} =
      tls_peer(directory, hostname, fn _ -> flunk("TLS verification was bypassed") end)

    server = server(url, ca)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request())
    assert_receive {:tls_attempt, ^peer}, @timeout
    response = head(:gen_tcp, socket)
    assert response =~ "502 Bad Gateway"
    refute response =~ "101 Switching Protocols"
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_receive {:tls_finished, ^peer, {:error, {:tls_alert, {^alert, _}}}}, @timeout
    assert_cleanup(server, baseline)
    assert_no_replay(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  defp server(url, ca) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint:
          {Proxy,
           %{
             upstream: url,
             cacertfile: ca,
             max_message_bytes: 1024,
             opening_timeout: 1000,
             close_timeout: 200
           }},
        limits: %{max_bytes: 8_388_608}
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

  defp tls_peer(directory, hostname, exchange) do
    {:ok, listener} =
      :ssl.listen(0, [
        :binary,
        active: false,
        ip: {0, 0, 0, 0},
        certfile: String.to_charlist(Path.join(directory, "cert.pem")),
        keyfile: String.to_charlist(Path.join(directory, "key.pem")),
        verify: :verify_none,
        alpn_preferred_protocols: ["http/1.1"]
      ])

    {:ok, {_, port}} = :ssl.sockname(listener)
    observer = self()

    peer =
      spawn(fn ->
        try do
          {:ok, transport} = :ssl.transport_accept(listener, @timeout)
          send(observer, {:tls_attempt, self()})

          result =
            case :ssl.handshake(transport, @timeout) do
              {:ok, socket} ->
                try do
                  exchange.(socket)
                  :ok
                after
                  :ssl.close(socket)
                end

              {:error, reason} ->
                :ssl.close(transport)
                {:error, reason}
            end

          send(observer, {:tls_finished, self(), result})

          receive do
            :verify_no_replay ->
              # Cleanup has already removed every upstream connection/session.
              # An accidental replay or plaintext fallback would still be queued.
              case :ssl.transport_accept(listener, 100) do
                {:error, :timeout} ->
                  send(observer, {:no_replay, self()})

                {:ok, socket} ->
                  :ssl.close(socket)
                  send(observer, {:unexpected_replay, self()})
              end
          after
            @timeout -> send(observer, {:peer_error, self(), "verification was not requested"})
          end
        rescue
          error ->
            send(observer, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          :ssl.close(listener)
        end
      end)

    on_exit(fn ->
      if Process.alive?(peer), do: Process.exit(peer, :kill)
      :ssl.close(listener)
    end)

    {"wss://#{hostname}:#{port}", peer}
  end

  defp assert_no_replay(peer) do
    send(peer, :verify_no_replay)
    assert_receive {:no_replay, ^peer}, @timeout
    refute_receive {:unexpected_replay, ^peer}, 0
    refute_receive {:peer_error, ^peer, _}, 0
  end

  defp supervisor_counts do
    for supervisor <- [Gaoxy.Proxy.SessionSupervisor, HTTP.WebSocket.ConnectionSupervisor],
        into: %{},
        do: {supervisor, DynamicSupervisor.count_children(supervisor).active}
  end

  defp assert_cleanup(server, baseline, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.status(server, :http)

    if match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, status) and
         supervisor_counts() == baseline do
      assert %{active: 0, cleanup_pending: 0, retained_bytes: 0, cleanup_failed: nil} = status
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        2 -> assert_cleanup(server, baseline, deadline)
      end
    end
  end

  defp request do
    "GET /secure?q=%2F HTTP/1.1\r\nHost: downstream.test\r\nUpgrade: websocket\r\n" <>
      "Connection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" <>
      "Sec-WebSocket-Version: 13\r\n\r\n"
  end

  defp head(transport, socket, bytes \\ "") do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = transport.recv(socket, 1, @timeout)
      head(transport, socket, bytes <> byte)
    end
  end

  defp handshake(request) do
    [key] = Regex.run(~r/(?im)^sec-websocket-key: ([^\r]+)\r$/, request, capture: :all_but_first)
    accept = Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

    "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" <>
      "Sec-WebSocket-Accept: #{accept}\r\n\r\n"
  end

  defp frame(opcode, payload),
    do: <<1::1, 0::3, opcode::4, 0::1, byte_size(payload)::7>> <> payload

  defp masked(opcode, payload),
    do: <<1::1, 0::3, opcode::4, 1::1, byte_size(payload)::7, 0::32>> <> payload

  defp read_frame(transport, socket, masked) do
    {:ok, <<1::1, 0::3, opcode::4, ^masked::1, length::7>>} = transport.recv(socket, 2, @timeout)

    mask =
      if masked == 1 do
        {:ok, mask} = transport.recv(socket, 4, @timeout)
        :binary.bin_to_list(mask) |> List.to_tuple()
      end

    bytes =
      if length == 0 do
        ""
      else
        {:ok, bytes} = transport.recv(socket, length, @timeout)
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
