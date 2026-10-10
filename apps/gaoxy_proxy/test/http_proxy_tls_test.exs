defmodule Gaoxy.Proxy.HTTPTLSTest do
  use ExUnit.Case, async: false

  @moduletag :loopback
  @moduletag :capture_log
  @timeout 5_000

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-proxy-https-#{System.unique_integer([:positive])}")

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

  test "a configured private CA verifies HTTPS and preserves binary request and response bytes",
       context do
    baseline = supervisor_counts()
    bytes = <<0, "secure", 255>>

    {url, peer} =
      tls_peer(context.trusted, "localhost", fn socket ->
        request = head(:ssl, socket)
        assert request =~ "POST /secure?q=%2F HTTP/1.1\r\n"
        assert String.downcase(request) =~ "content-length: 8\r\n"
        assert {:ok, ^bytes} = :ssl.recv(socket, byte_size(bytes), @timeout)

        :ok =
          :ssl.send(socket, [
            "HTTP/1.1 200 OK\r\nContent-Length: 8\r\n",
            "Set-Cookie: one=1\r\nSet-Cookie: two=2\r\n\r\n",
            bytes
          ])

        assert {:error, :closed} = :ssl.recv(socket, 0, @timeout)
      end)

    server = server(url, Path.join(context.trusted, "ca.pem"))
    socket = connect(server)
    :ok = :gen_tcp.send(socket, [request(), bytes])
    assert_receive {:tls_attempt, ^peer}, @timeout
    response = head(:gen_tcp, socket)
    assert response =~ "200 OK"
    assert String.downcase(response) =~ "set-cookie: one=1\r\nset-cookie: two=2\r\n"
    assert {:ok, ^bytes} = :gen_tcp.recv(socket, byte_size(bytes), @timeout)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_receive {:tls_finished, ^peer, :ok}, @timeout
    assert_cleanup(server, baseline)
    assert_no_replay(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "a wrong CA rejects HTTPS without plaintext fallback or a second upstream connection",
       context do
    assert_rejected(
      context.trusted,
      "localhost",
      Path.join(context.untrusted, "ca.pem"),
      :unknown_ca
    )
  end

  test "a trusted certificate for another hostname rejects HTTPS without fallback or replay",
       context do
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
      tls_peer(directory, hostname, fn _socket -> flunk("TLS verification was bypassed") end)

    server = server(url, ca)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, [request(), <<0, "secure", 255>>])
    assert_receive {:tls_attempt, ^peer}, @timeout
    response = head(:gen_tcp, socket)
    assert response =~ "502 Bad Gateway"
    refute response =~ "200 OK"
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert_receive {:tls_finished, ^peer, {:error, {:tls_alert, {^alert, _message}}}}, @timeout
    assert_cleanup(server, baseline)
    assert_no_replay(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  defp server(url, ca) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Gaoxy.Proxy.HTTP, %{upstream: url, cacertfile: ca, opening_timeout: 1_000}},
        limits: %{max_bytes: 16_777_216}
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

    {"https://#{hostname}:#{port}", peer}
  end

  defp assert_no_replay(peer) do
    monitor = Process.monitor(peer)
    send(peer, :verify_no_replay)
    assert_receive {:no_replay, ^peer}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
    refute_receive {:unexpected_replay, ^peer}, 0
    refute_receive {:peer_error, ^peer, _error}, 0
  end

  defp supervisor_counts do
    for supervisor <- [
          Gaoxy.Proxy.SessionSupervisor,
          :http_fetch_task_supervisor,
          :http_runtime_task_supervisor
        ],
        into: %{},
        do: {supervisor, Supervisor.count_children(supervisor).active}
  end

  defp assert_cleanup(server, baseline, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.status(server, :http)

    if match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, status) and
         supervisor_counts() == baseline do
      assert %{
               state: :ready,
               active: 0,
               cleanup_pending: 0,
               retained_bytes: 0,
               cleanup_failed: nil
             } = status
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        2 -> assert_cleanup(server, baseline, deadline)
      end
    end
  end

  defp request do
    "POST /secure?q=%2F HTTP/1.1\r\nHost: downstream.test\r\nContent-Length: 8\r\n" <>
      "Connection: close\r\n\r\n"
  end

  defp head(transport, socket, bytes \\ "") do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      {:ok, byte} = transport.recv(socket, 1, @timeout)
      head(transport, socket, bytes <> byte)
    end
  end
end
