defmodule Gaoxy.Proxy.HTTPRuntimeTest do
  use ExUnit.Case, async: true
  @timeout 3_000

  defmodule ObservedEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init({config, owner}) do
      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(config), do: {:ok, {config, owner}}
    end

    def call(exchange, {config, owner}) do
      :ok = Hell.Socket.setopts(exchange.socket, sndbuf: 8192)
      send(owner, {:native_owner, self()})
      Gaoxy.Proxy.HTTP.call(exchange, config)
    end
  end

  test "configuration rejects unsafe authority, unknown options and unbounded limits" do
    assert {:ok, _} = Gaoxy.Proxy.HTTP.init(%{upstream: "http://localhost:1234"})

    for options <- [
          %{upstream: "http://user:pass@localhost"},
          %{upstream: "http://localhost/path"},
          %{upstream: "http://localhost?"},
          %{upstream: "http://localhost#fragment"},
          %{upstream: "ws://localhost"},
          %{upstream: "https://localhost", verify: :verify_none},
          %{upstream: "http://localhost", idle_timeout: :infinity},
          %{upstream: "http://localhost", max_chunk_bytes: 65_537}
        ] do
      assert {:error, :invalid_http_proxy_options} = Gaoxy.Proxy.HTTP.init(options)
    end
  end

  test "normal completion clears the guardian before a pipelined next proxy request" do
    {url, peer} =
      peer(
        fn socket, owner, index ->
          {head, _rest} = recv_head(socket)
          send(owner, {:upstream_head, index, head})
          :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\n#{index}")
          :gen_tcp.recv(socket, 0, @timeout)
        end,
        2
      )

    {server, client} = proxy(url)

    :ok =
      :gen_tcp.send(client, [
        "GET /one HTTP/1.1\r\nHost: client.test\r\n\r\n",
        "GET /two HTTP/1.1\r\nHost: client.test\r\nConnection: close\r\n\r\n"
      ])

    wire = receive_all(client)
    assert wire =~ "\r\n\r\n1HTTP/1.1 200 OK"
    assert String.ends_with?(wire, "\r\n\r\n2")
    assert_receive {:upstream_head, 1, first}, @timeout
    assert_receive {:upstream_head, 2, second}, @timeout
    assert first =~ "GET /one HTTP/1.1"
    assert second =~ "GET /two HTTP/1.1"
    assert_receive {:peer_done, ^peer, [{:error, :closed}, {:error, :closed}]}, @timeout
    assert_ready(server)
  end

  test "an early final response survives upload source termination" do
    {url, peer} =
      peer(fn socket, _owner, _index ->
        recv_head(socket)
        :ok = :gen_tcp.send(socket, "HTTP/1.1 413 Content Too Large\r\nContent-Length: 0\r\n\r\n")
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    {server, client} = proxy(url)

    :ok =
      :gen_tcp.send(
        client,
        "POST / HTTP/1.1\r\nHost: client.test\r\nContent-Length: 1000000\r\n\r\n"
      )

    wire = receive_all(client)
    assert wire =~ "HTTP/1.1 413"
    refute wire =~ "502"
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
    assert_ready(server)
  end

  test "disconnect during an idle upstream SSE response cancels and releases the guardian" do
    {url, peer} =
      peer(fn socket, _owner, _index ->
        recv_head(socket)

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n"
          )

        :gen_tcp.recv(socket, 0, @timeout)
      end)

    {server, client} = proxy(url)
    :ok = :gen_tcp.send(client, "GET /events HTTP/1.1\r\nHost: client.test\r\n\r\n")
    {head, ""} = recv_head(client)
    assert head =~ "200 OK"
    :ok = :gen_tcp.close(client)
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
    assert_ready(server)
  end

  @tag :tmp_dir
  test "TLS abort after an observed streaming prefix promptly cancels the idle upstream", %{
    tmp_dir: directory
  } do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, directory], stderr_to_stdout: true)

    {url, peer} =
      peer(fn socket, _owner, _index ->
        recv_head(socket)

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n9\r\nprogress-\r\n"
          )

        :gen_tcp.recv(socket, 0, @timeout)
      end)

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {ObservedEndpoint, {%{upstream: url, max_lifetime: 5_000}, self()}},
        transport: :tls,
        tls: %{
          certfile: Path.join(directory, "cert.pem"),
          keyfile: Path.join(directory, "key.pem")
        },
        http_limits: %{request_timeout: 5_000},
        limits: %{max_bytes: 16_777_216}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local

    python = ~S"""
    import asyncio
    import ssl
    import sys

    async def main():
        context = ssl.create_default_context(cafile=sys.argv[2])
        context.set_alpn_protocols(["http/1.1"])
        async with asyncio.timeout(3):
            reader, writer = await asyncio.open_connection(
                "127.0.0.1", int(sys.argv[1]), ssl=context, server_hostname="localhost")
            assert writer.get_extra_info("ssl_object").selected_alpn_protocol() == "http/1.1"
            writer.write(b"GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n")
            await writer.drain()
            head = await reader.readuntil(b"\r\n\r\n")
            assert head.startswith(b"HTTP/1.1 200 OK\r\n"), head
            assert b"transfer-encoding: chunked\r\n" in head.lower(), head
            assert await reader.readuntil(b"\r\n") == b"9\r\n"
            assert await reader.readexactly(9) == b"progress-"
            assert await reader.readexactly(2) == b"\r\n"
            print("TLS_PREFIX_OBSERVED", flush=True)
            assert sys.stdin.readline() == "abort\n", "missing TLS abort release"
            writer.transport.abort()
            print("TLS_TRANSPORT_ABORTED", flush=True)
            await writer.wait_closed()

    asyncio.run(main())
    """

    executable = System.get_env("GAOXY_QUIC_PYTHON") || System.find_executable("python3")

    client =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: ["-u", "-c", python, Integer.to_string(port), Path.join(directory, "ca.pem")]
      ])

    await_marker = fn recur, output, marker, deadline ->
      if String.contains?(output, marker) do
        output
      else
        receive do
          {^client, {:data, bytes}} -> recur.(recur, output <> bytes, marker, deadline)
          {^client, {:exit_status, status}} -> flunk("TLS peer exit #{status}: #{output}")
        after
          Gaoxy.Lifecycle.remaining(deadline) -> flunk("missing #{marker}: #{output}")
        end
      end
    end

    output =
      await_marker.(await_marker, "", "TLS_PREFIX_OBSERVED\n", Gaoxy.Lifecycle.deadline(@timeout))

    assert_receive {:native_owner, native}, @timeout
    guardian = guardian(native)
    monitor = Process.monitor(guardian)
    assert %{active: 1, cleanup_pending: 1} = Gaoxy.status(server, :http)
    deadline = Gaoxy.Lifecycle.deadline(1_000)
    assert Port.command(client, "abort\n")
    await_marker.(await_marker, output, "TLS_TRANSPORT_ABORTED\n", deadline)
    assert_receive {^client, {:exit_status, 0}}, Gaoxy.Lifecycle.remaining(deadline)
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, Gaoxy.Lifecycle.remaining(deadline)

    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal},
                   Gaoxy.Lifecycle.remaining(deadline)

    assert_ready(server, deadline)
  end

  test "owner kill before headers leaves independently owned upstream cleanup" do
    {url, peer} =
      peer(fn socket, owner, _index ->
        recv_head(socket)
        send(owner, {:upstream_waiting, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {ObservedEndpoint, {%{upstream: url}, self()}},
        limits: %{max_bytes: 16_777_216}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    client = connect(server)
    :ok = :gen_tcp.send(client, "GET / HTTP/1.1\r\nHost: client.test\r\n\r\n")
    assert_receive {:native_owner, native}, @timeout
    assert_receive {:upstream_waiting, ^peer}, @timeout
    assert Gaoxy.status(server, :http).cleanup_pending == 1
    Process.exit(native, :kill)
    assert {:error, :closed} = :gen_tcp.recv(client, 0, @timeout)
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
    assert_ready(server)
  end

  test "service shutdown cancels an admitted upstream request without headers" do
    {url, peer} =
      peer(fn socket, owner, _index ->
        recv_head(socket)
        send(owner, {:upstream_waiting, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    {server, client} = proxy(url)
    :ok = :gen_tcp.send(client, "GET / HTTP/1.1\r\nHost: client.test\r\n\r\n")
    assert_receive {:upstream_waiting, ^peer}, @timeout
    assert :ok = Gaoxy.stop(server, 2_000)
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
  end

  test "a zero caller deadline leaves cleanup owned outside the instance force-stop tree" do
    {url, peer} = idle_sse_peer()
    {server, client} = observed_proxy(url)
    :ok = :gen_tcp.send(client, "GET /events HTTP/1.1\r\nHost: client.test\r\n\r\n")
    assert_receive {:native_owner, native}, @timeout
    {head, ""} = recv_head(client)
    assert head =~ "200 OK"
    guardian = guardian(native)
    guardian_monitor = Process.monitor(guardian)
    native_monitor = Process.monitor(native)
    instance_monitor = Process.monitor(server)
    :ok = :sys.suspend(guardian)

    try do
      assert Gaoxy.stop(server, 0) == {:error, {:deadline_exceeded, :cleanup_pending}}
      assert_receive {:DOWN, ^native_monitor, :process, ^native, _}, @timeout
      assert Process.alive?(guardian)
      assert Process.alive?(server)
      :ok = :sys.resume(guardian)
      assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_receive {:DOWN, ^instance_monitor, :process, ^server, :normal}, @timeout
    after
      if Process.alive?(guardian), do: :sys.resume(guardian)
    end
  end

  test "abrupt instance death after headers cancels idle SSE in the external guardian" do
    {url, peer} = idle_sse_peer()
    {server, client} = observed_proxy(url)
    :ok = :gen_tcp.send(client, "GET /events HTTP/1.1\r\nHost: client.test\r\n\r\n")
    assert_receive {:native_owner, native}, @timeout
    {head, ""} = recv_head(client)
    assert head =~ "200 OK"
    guardian = guardian(native)
    guardian_monitor = Process.monitor(guardian)
    instance_monitor = Process.monitor(server)
    Process.unlink(server)
    Process.exit(server, :kill)

    assert_receive {:DOWN, ^instance_monitor, :process, ^server, :killed}, @timeout
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
    assert {:error, :closed} = :gen_tcp.recv(client, 0, @timeout)
  end

  test "HEAD and 204 complete without invented body framing before the next request" do
    {url, peer} =
      peer(
        fn socket, owner, index ->
          {head, _} = recv_head(socket)
          send(owner, {:upstream_head, index, head})

          response =
            if index == 1,
              do: "HTTP/1.1 200 OK\r\nContent-Length: 42\r\n\r\n",
              else: "HTTP/1.1 204 No Content\r\n\r\n"

          :ok = :gen_tcp.send(socket, response)
          :gen_tcp.recv(socket, 0, @timeout)
        end,
        2
      )

    {server, client} = proxy(url)

    :ok =
      :gen_tcp.send(
        client,
        "HEAD /head HTTP/1.1\r\nHost: client.test\r\n\r\nGET /empty HTTP/1.1\r\nHost: client.test\r\nConnection: close\r\n\r\n"
      )

    wire = receive_all(client)
    assert wire =~ "content-length: 42\r\n\r\nHTTP/1.1 204"
    refute wire =~ "transfer-encoding"
    assert String.ends_with?(wire, "\r\n\r\n")
    assert_receive {:upstream_head, 1, head}, @timeout
    assert head =~ "HEAD /head HTTP/1.1"
    assert_receive {:peer_done, ^peer, [{:error, :closed}, {:error, :closed}]}, @timeout
    assert_ready(server)
  end

  test "opening timeout cancels a connected upstream before headers" do
    {url, peer} =
      peer(fn socket, owner, _ ->
        recv_head(socket)
        send(owner, {:upstream_waiting, self()})
        :gen_tcp.recv(socket, 0, @timeout)
      end)

    {server, client} = proxy(url, %{opening_timeout: 100})
    :ok = :gen_tcp.send(client, "GET / HTTP/1.1\r\nHost: client.test\r\n\r\n")
    assert_receive {:upstream_waiting, ^peer}, @timeout
    assert receive_all(client) =~ "504 Gateway Timeout"
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
    assert_ready(server)
  end

  test "maximum lifetime cancels an idle response after its committed head" do
    {url, peer} = idle_sse_peer()
    {server, client} = proxy(url, %{max_lifetime: 150})
    :ok = :gen_tcp.send(client, "GET /events HTTP/1.1\r\nHost: client.test\r\n\r\n")
    {head, ""} = recv_head(client)
    assert head =~ "200 OK"
    assert {:error, :closed} = :gen_tcp.recv(client, 0, 1_000)
    assert_receive {:peer_done, ^peer, [{:error, :closed}]}, @timeout
    assert_ready(server)
  end

  test "upstream closure before headers is not replayed" do
    {listener, url} = listener()
    owner = self()

    peer =
      spawn(fn ->
        {:ok, socket} = :gen_tcp.accept(listener, @timeout)
        recv_head(socket)
        :gen_tcp.close(socket)
        send(owner, {:closed_before_headers, self()})
      end)

    {server, client} = proxy(url)

    :ok =
      :gen_tcp.send(
        client,
        "POST /once HTTP/1.1\r\nHost: client.test\r\nContent-Length: 0\r\n\r\n"
      )

    assert receive_all(client) =~ "502 Bad Gateway"
    assert_receive {:closed_before_headers, ^peer}, @timeout
    assert_ready(server)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
  end

  test "the default byte budget denies admission before upstream activation" do
    {listener, url} = listener()
    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Gaoxy.Proxy.HTTP, %{upstream: url}})
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    client = connect(server)
    :ok = :gen_tcp.send(client, "GET / HTTP/1.1\r\nHost: client.test\r\n\r\n")
    assert receive_all(client) =~ "503 Service Unavailable"
    assert_ready(server)
    assert {:error, :timeout} = :gen_tcp.accept(listener, 0)
  end

  for {name, limits} <- [
        {"write timeout", %{write_timeout: 80, max_lifetime: 5_000}},
        {"maximum lifetime", %{write_timeout: 5_000, max_lifetime: 250}}
      ] do
    @tag timeout: 10_000
    test "a blocked downstream write respects the endpoint #{name} and bounded retention" do
      {url, peer} =
        peer(fn socket, owner, _ ->
          recv_head(socket)
          :ok = :inet.setopts(socket, send_timeout: 2_000, send_timeout_close: true)
          :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 16777216\r\n\r\n")
          send(owner, {:flood_ready, self()})

          receive do
            :flood -> :ok
          after
            @timeout -> raise "missing flood barrier"
          end

          _ = :gen_tcp.send(socket, List.duplicate(:binary.copy("x", 65_536), 256))
          :gen_tcp.recv(socket, 0, @timeout)
        end)

      {server, client} =
        observed_proxy(url, unquote(Macro.escape(limits)), recbuf: 1024, buffer: 1024)

      :ok = :gen_tcp.send(client, "GET /slow HTTP/1.1\r\nHost: client.test\r\n\r\n")
      assert_receive {:native_owner, native}, @timeout
      monitor = Process.monitor(native)
      assert_receive {:flood_ready, ^peer}, @timeout
      send(peer, :flood)
      assert_receive {:DOWN, ^monitor, :process, ^native, _}, 1_000
      assert_receive {:peer_done, ^peer, [{:error, _}]}, @timeout
      assert_ready(server)
      assert Gaoxy.status(server, :http).retained_high_water <= 16_777_216
    end
  end

  defp listener do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)
    {listener, "http://127.0.0.1:#{port}"}
  end

  defp idle_sse_peer do
    peer(fn socket, _owner, _index ->
      recv_head(socket)

      :ok =
        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n"
        )

      :gen_tcp.recv(socket, 0, @timeout)
    end)
  end

  defp observed_proxy(url, options \\ %{}, socket_options \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {ObservedEndpoint, {Map.put(options, :upstream, url), self()}},
        limits: %{max_bytes: 16_777_216}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {server, connect(server, socket_options)}
  end

  defp guardian(owner) do
    Enum.find_value(DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor), fn
      {_, pid, _, [Gaoxy.Proxy.HTTP.Session]} ->
        try do
          if :sys.get_state(pid).owner == owner, do: pid
        catch
          :exit, _ -> nil
        end

      _ ->
        nil
    end) || flunk("HTTP cleanup guardian missing")
  end

  defp proxy(url, options \\ %{}) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Gaoxy.Proxy.HTTP, Map.put(options, :upstream, url)},
        limits: %{max_bytes: 16_777_216}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {server, connect(server)}
  end

  defp connect(server, options \\ []) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false] ++ options, @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp assert_ready(server), do: assert_ready(server, Gaoxy.Lifecycle.deadline(@timeout))

  defp assert_ready(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{state: :ready, active: 0, retained_bytes: 0, cleanup_pending: 0} ->
        :ok

      status ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

        receive do
        after
          5 -> assert_ready(server, deadline)
        end
    end
  end

  defp peer(fun, count \\ 1) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    pid =
      spawn(fn ->
        try do
          results =
            for index <- 1..count do
              {:ok, socket} = :gen_tcp.accept(listener, @timeout)

              try do
                fun.(socket, owner, index)
              after
                :gen_tcp.close(socket)
              end
            end

          send(owner, {:peer_done, self(), results})
        rescue
          error ->
            send(owner, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          :gen_tcp.close(listener)
        end
      end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {"http://127.0.0.1:#{port}", pid}
  end

  defp recv_head(socket, bytes \\ "") do
    case :binary.split(bytes, "\r\n\r\n") do
      [head, rest] ->
        {head <> "\r\n\r\n", rest}

      [_] ->
        assert {:ok, more} = :gen_tcp.recv(socket, 0, @timeout)
        recv_head(socket, bytes <> more)
    end
  end

  defp receive_all(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, more} -> receive_all(socket, bytes <> more)
      {:error, :closed} -> bytes
      error -> flunk(inspect(error))
    end
  end
end
