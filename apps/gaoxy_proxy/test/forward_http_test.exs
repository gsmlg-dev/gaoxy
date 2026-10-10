defmodule Gaoxy.Proxy.ForwardHTTPTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.ForwardHTTP
  @timeout 3_000

  test "forward configuration requires explicit authentication and destination rules" do
    for options <- [
          %{},
          %{policy: %{}},
          %{policy: %{authenticate: fn _ -> {:ok, "owner"} end, rules: []}}
        ] do
      assert {:error, _} = ForwardHTTP.init(options)
    end
  end

  test "authorized forward HTTP pins the destination and strips proxy credentials" do
    owner = self()

    {port, peer} =
      peer(fn socket ->
        head = head(socket)
        send(owner, {:upstream_head, self(), head})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(port)
    socket = connect(server)

    :ok =
      :gen_tcp.send(
        socket,
        "GET http://localhost:#{port}/a%2Fb?x=%2F HTTP/1.1\r\nHost: localhost:#{port}\r\nProxy-Authorization: Bearer secret\r\nConnection: close\r\n\r\n"
      )

    assert until_fin(socket) =~ "\r\n\r\nok"
    assert_receive {:upstream_head, ^peer, upstream}, @timeout
    assert upstream =~ "GET /a%2Fb?x=%2F HTTP/1.1"
    assert String.downcase(upstream) =~ "host: localhost:#{port}\r\n"
    refute String.downcase(upstream) =~ "proxy-authorization"
    refute upstream =~ "secret"
    assert_peer(peer)
    restored(server)
  end

  test "missing, invalid, duplicate credentials and denied destinations never dial" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)
    server = server(port)

    for {fields, host, status} <- [
          {"", "localhost", 407},
          {"Proxy-Authorization: Bearer wrong\r\n", "localhost", 407},
          {"Proxy-Authorization: Bearer secret\r\nProxy-Authorization: Bearer secret\r\n",
           "localhost", 407},
          {"Proxy-Authorization: Bearer secret\r\n", "127.0.0.2", 403}
        ] do
      socket = connect(server)

      :ok =
        :gen_tcp.send(
          socket,
          "GET http://#{host}:#{port}/ HTTP/1.1\r\nHost: #{host}:#{port}\r\n#{fields}Connection: close\r\n\r\n"
        )

      response = until_fin(socket)
      assert response =~ "HTTP/1.1 #{status} "
      if status == 407, do: assert(String.downcase(response) =~ "proxy-authenticate: bearer")
      refute response =~ "secret"
    end

    assert {:error, :timeout} = :gen_tcp.accept(listener, 100)
    restored(server)
  end

  test "userinfo, authority mismatch and framed CONNECT reject before a dial" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)
    server = server(port)

    for request <- [
          "GET http://user:password@localhost:#{port}/ HTTP/1.1\r\nHost: localhost:#{port}\r\n",
          "GET http://localhost:#{port}/ HTTP/1.1\r\nHost: other.test:#{port}\r\n",
          "CONNECT localhost:#{port} HTTP/1.1\r\nHost: localhost:#{port}\r\nContent-Length: 0\r\n"
        ] do
      socket = connect(server)

      :ok =
        :gen_tcp.send(
          socket,
          request <> "Proxy-Authorization: Bearer secret\r\nConnection: close\r\n\r\n"
        )

      assert until_fin(socket) =~ "HTTP/1.1 400 "
    end

    assert {:error, :timeout} = :gen_tcp.accept(listener, 100)
    restored(server)
  end

  test "CONNECT transfers buffered bytes exactly once and preserves FIN then the reverse reply" do
    prefix = :binary.copy("early", 1_000)
    later = :binary.copy(<<0, 255, 1>>, 60_000)
    expected = prefix <> later

    {port, peer} =
      peer(fn socket ->
        assert ^expected = until_fin(socket)
        :ok = :gen_tcp.send(socket, "reply-after-fin")
        :ok = :gen_tcp.shutdown(socket, :write)
      end)

    server = server(port)
    socket = connect(server)

    :ok =
      :gen_tcp.send(socket, [
        "CONNECT localhost:#{port} HTTP/1.1\r\nHost: localhost:#{port}\r\nProxy-Authorization: Bearer secret\r\n\r\n",
        prefix
      ])

    assert head(socket) == "HTTP/1.1 200 Connection Established\r\n\r\n"
    :ok = :gen_tcp.send(socket, later)
    :ok = :gen_tcp.shutdown(socket, :write)
    assert "reply-after-fin" = until_fin(socket)
    assert_peer(peer)
    restored(server)
  end

  test "a CONNECT dial failure emits no successful tunnel response" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    :gen_tcp.close(listener)
    server = server(port)
    socket = connect(server)

    :ok =
      :gen_tcp.send(
        socket,
        "CONNECT localhost:#{port} HTTP/1.1\r\nHost: localhost:#{port}\r\nProxy-Authorization: Bearer secret\r\nConnection: close\r\n\r\n"
      )

    response = until_fin(socket)
    assert response =~ "HTTP/1.1 502 "
    refute response =~ "200 Connection Established"
    restored(server)
  end

  test "CONNECT lifetime is the original HTTP request budget and force stop closes the upstream" do
    owner = self()

    for stop <- [false, true] do
      {port, peer} =
        peer(fn socket ->
          send(owner, {:connected, self()})
          assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
        end)

      server = server(port, if(stop, do: 3_000, else: 150))
      socket = connect(server)

      :ok =
        :gen_tcp.send(
          socket,
          "CONNECT localhost:#{port} HTTP/1.1\r\nHost: localhost:#{port}\r\nProxy-Authorization: Bearer secret\r\n\r\n"
        )

      assert head(socket) == "HTTP/1.1 200 Connection Established\r\n\r\n"
      assert_receive {:connected, ^peer}, @timeout
      if stop, do: assert(:ok = Gaoxy.stop(server, 500))
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      assert_peer(peer)
      if not stop, do: restored(server)
    end
  end

  @tag :tmp_dir
  test "a verified TLS forward listener accepts an authorized absolute HTTP target", %{
    tmp_dir: dir
  } do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)
    owner = self()

    {port, peer} =
      peer(fn socket ->
        request = head(socket)
        send(owner, {:tls_forward_head, self(), request})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 7\r\n\r\nforward")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server =
      server(port, @timeout,
        transport: :tls,
        tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
      )

    assert {:ok, {ip, listener_port}} = Gaoxy.info(server, :http).local

    assert {:ok, socket} =
             :ssl.connect(
               ip,
               listener_port,
               [
                 :binary,
                 active: false,
                 verify: :verify_peer,
                 cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
                 server_name_indication: ~c"localhost",
                 customize_hostname_check: [
                   match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
                 ]
               ],
               @timeout
             )

    on_exit(fn -> :ssl.close(socket, 0) end)

    :ok =
      :ssl.send(
        socket,
        "GET http://localhost:#{port}/secure-forward HTTP/1.1\r\nHost: localhost:#{port}\r\nProxy-Authorization: Bearer secret\r\nConnection: close\r\n\r\n"
      )

    response = tls_fin(socket)
    assert response =~ "HTTP/1.1 200 "
    assert response =~ "\r\n\r\nforward"
    assert_receive {:tls_forward_head, ^peer, request}, @timeout
    assert request =~ "GET /secure-forward HTTP/1.1"
    refute String.downcase(request) =~ "proxy-authorization"
    assert_peer(peer)
    restored(server)
  end

  defp server(port, timeout \\ @timeout, extras \\ []) do
    policy = %{
      authenticate: fn
        "Bearer secret" -> {:ok, "owner"}
        _ -> {:error, :invalid}
      end,
      rules: [
        %{
          principals: ["owner"],
          hosts: ["localhost"],
          ports: [port],
          operations: [:forward, :connect],
          methods: :any,
          cidrs: ["127.0.0.1/32", "::1/128"],
          allow_reserved: true
        }
      ]
    }

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        Keyword.merge(
          [
            endpoint: {ForwardHTTP, %{policy: policy}},
            http_limits: %{request_timeout: timeout},
            limits: %{max_bytes: 33_554_432, max_active: 128}
          ],
          extras
        )
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp tls_fin(socket, bytes \\ "") do
    case :ssl.recv(socket, 0, @timeout) do
      {:ok, data} -> tls_fin(socket, bytes <> data)
      {:error, :closed} -> bytes
    end
  end

  defp connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local

    {:ok, socket} =
      :gen_tcp.connect(ip, port, [:binary, active: false, exit_on_close: false], @timeout)

    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp head(socket, bytes \\ "") do
    if String.ends_with?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (
          {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
          head(socket, bytes <> byte)
        )
  end

  defp until_fin(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, data} -> until_fin(socket, bytes <> data)
      {:error, :closed} -> bytes
    end
  end

  defp peer(fun) do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, exit_on_close: false, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    pid =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            fun.(socket)
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

    {port, pid}
  end

  defp assert_peer(peer) do
    receive do
      {:peer_done, ^peer} -> :ok
      {:peer_error, ^peer, error} -> flunk(error)
    after
      @timeout -> flunk("forward peer did not finish")
    end
  end

  defp restored(server, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.status(server, :http)

    if not match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        1 -> restored(server, deadline)
      end
    else
      assert status.cleanup_failed == nil
    end
  end
end
