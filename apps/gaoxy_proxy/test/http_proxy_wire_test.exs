defmodule Gaoxy.Proxy.HTTPWireTest do
  use ExUnit.Case, async: false

  @timeout 5_000

  defmodule Local do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: Gaoxy.HTTP.HTTP1.Response.send_resp(exchange, 200, [], "local")
  end

  test "one listener routes locally and preserves remote raw targets, duplicates and gzip bytes" do
    encoded = :zlib.gzip("transparent compressed response")

    {url, peer} =
      peer(fn socket, owner ->
        send(owner, {:upstream_head, self(), head(socket)})

        :gen_tcp.send(socket, [
          "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n",
          "Set-Cookie: one=1\r\nSet-Cookie: two=2\r\n",
          "Connection: close, X-Remove\r\nX-Remove: private\r\n",
          "Content-Length: #{byte_size(encoded)}\r\n\r\n",
          encoded
        ])
      end)

    server = server(url)
    local = connect(server)
    :ok = :gen_tcp.send(local, request("GET", "/local", [{"Connection", "close"}]))
    assert head(local) =~ "200 OK"
    assert {:ok, "local"} = :gen_tcp.recv(local, 5, @timeout)

    socket = connect(server)

    :ok =
      :gen_tcp.send(
        socket,
        request("GET", "/a%2Fb?q=%2F&x=1", [
          {"Connection", "close, X-Remove"},
          {"X-Remove", "private"},
          {"X-Trace", "one"},
          {"X-Trace", "two"},
          {"Forwarded", "for=spoofed"},
          {"X-Forwarded-For", "spoofed"},
          {"Proxy-Connection", "keep-alive"}
        ])
      )

    response = head(socket)
    assert response =~ "200 OK"
    assert response =~ "content-encoding: gzip\r\n"
    assert response =~ "set-cookie: one=1\r\nset-cookie: two=2\r\n"
    refute response =~ "x-remove:"
    assert {:ok, ^encoded} = :gen_tcp.recv(socket, byte_size(encoded), @timeout)
    assert_receive {:upstream_head, ^peer, upstream}, @timeout
    assert upstream =~ "GET /a%2Fb?q=%2F&x=1 HTTP/1.1\r\n"
    assert String.downcase(upstream) =~ "x-trace: one\r\nx-trace: two\r\n"
    assert String.downcase(upstream) =~ "x-forwarded-for: 127.0.0.1\r\n"
    refute upstream =~ "spoofed"
    refute String.downcase(upstream) =~ "x-remove:"
    refute String.downcase(upstream) =~ "proxy-connection:"
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  for method <- ["POST", "GET", "DELETE"] do
    @method method
    test "#{@method} uploads fixed bytes before downstream EOF and preserves an escaped query" do
      method = @method

      {url, peer} =
        peer(fn socket, owner ->
          upstream = head(socket)
          assert upstream =~ "#{method} /upload?mode=%2F HTTP/1.1\r\n"
          assert String.downcase(upstream) =~ "content-length: 6\r\n"
          assert {:ok, "abc"} = :gen_tcp.recv(socket, 3, @timeout)
          send(owner, {:first_upload_piece, self()})
          assert {:ok, "def"} = :gen_tcp.recv(socket, 3, @timeout)
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
        end)

      server = server(url)
      socket = connect(server)

      :ok =
        :gen_tcp.send(socket, [
          request(method, "/upload?mode=%2F", [{"Content-Length", "6"}, {"Connection", "close"}]),
          "abc"
        ])

      assert_receive {:first_upload_piece, ^peer}, @timeout
      :ok = :gen_tcp.send(socket, "def")
      assert head(socket) =~ "200 OK"
      assert {:ok, "ok"} = :gen_tcp.recv(socket, 2, @timeout)
      assert_peer(peer)
      assert :ok = Gaoxy.stop(server, @timeout)
    end
  end

  test "a present empty query remains distinct from an absent query" do
    # TODO(upstream): gsmlg-dev/http_fetch#64 - retain this failing wire regression.
    {url, peer} =
      peer(fn socket, owner ->
        send(owner, {:upstream_target, self(), head(socket)})
        :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("GET", "/upload?", [{"Connection", "close"}]))
    assert head(socket) =~ "200 OK"
    assert_receive {:upstream_target, ^peer, upstream}, @timeout
    assert upstream =~ "GET /upload? HTTP/1.1\r\n"
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "chunked upload and response preserve ordered declared trailers with hop filtering" do
    {url, peer} =
      peer(fn socket, _owner ->
        upstream = head(socket)
        assert String.downcase(upstream) =~ "transfer-encoding: chunked\r\n"
        assert String.downcase(upstream) =~ "trailer: x-trace\r\n"

        assert {"upload", [{"x-trace", "one"}, {"x-trace", "two"}]} = chunks(socket)

        :gen_tcp.send(socket, [
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n",
          "Connection: X-Remove\r\nX-Remove: private\r\nTrailer: X-Trace\r\n\r\n",
          "4\r\nbody\r\n0\r\nX-Trace: first\r\nX-Trace: last\r\n\r\n"
        ])
      end)

    server = server(url)
    socket = connect(server)

    :ok =
      :gen_tcp.send(socket, [
        request("DELETE", "/upload", [
          {"Transfer-Encoding", "chunked"},
          {"Trailer",
           "X-Trace, X-Remove, Forwarded, X-Forwarded-For, X-Forwarded-Client-Cert, X-Real-IP"},
          {"Connection", "close, X-Remove"}
        ]),
        "6\r\nupload\r\n0\r\nX-Trace: one\r\nX-Remove: private\r\nX-Trace: two\r\n",
        "Forwarded: for=spoofed\r\nX-Forwarded-For: spoofed\r\n",
        "X-Forwarded-Client-Cert: spoofed\r\nX-Real-IP: spoofed\r\n\r\n"
      ])

    assert_peer(peer)
    response = head(socket)
    assert response =~ "200 OK"
    assert response =~ "trailer: x-trace\r\n"
    refute response =~ "x-remove"
    assert {"body", [{"x-trace", "first"}, {"x-trace", "last"}]} = chunks(socket)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "a forbidden upstream trailer cannot produce a successfully terminated response" do
    {url, peer} =
      peer(fn socket, _owner ->
        _ = head(socket)

        :gen_tcp.send(socket, [
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n",
          "Connection: X-Remove\r\nTrailer: X-Trace, X-Remove\r\n\r\n",
          "4\r\nbody\r\n0\r\nX-Trace: first\r\nX-Remove: private\r\n\r\n"
        ])
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("GET", "/forbidden", [{"Connection", "close"}]))
    response = until_close(socket)
    refute response =~ "x-remove: private"
    refute String.ends_with?(response, "\r\n0\r\n\r\n")
    assert response =~ "502 Bad Gateway" or response =~ "200 OK"
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "an early final response reaches a client that never finishes its upload" do
    {url, peer} =
      peer(fn socket, _owner ->
        _ = head(socket)
        :gen_tcp.send(socket, "HTTP/1.1 413 Payload Too Large\r\nContent-Length: 2\r\n\r\nno")
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("POST", "/early", [{"Content-Length", "1000000"}]))
    response = head(socket)
    assert response =~ "413 "
    assert response =~ "connection: close\r\n"
    assert {:ok, "no"} = :gen_tcp.recv(socket, 2, @timeout)
    assert {:error, :closed} = :gen_tcp.recv(socket, 1, @timeout)
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "SSE is delivered incrementally and an idle downstream disconnect cancels upstream" do
    {url, peer} =
      peer(fn socket, owner ->
        _ = head(socket)

        :ok =
          :gen_tcp.send(socket, [
            "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n",
            "Transfer-Encoding: chunked\r\n\r\n9\r\ndata: 1\n\n\r\n"
          ])

        send(owner, {:sse_open, self()})
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("GET", "/events"))
    assert head(socket) =~ "content-type: text/event-stream\r\n"
    assert line(socket) == "9\r\n"
    assert {:ok, "data: 1\n\n\r\n"} = :gen_tcp.recv(socket, 11, @timeout)
    assert_receive {:sse_open, ^peer}, @timeout
    :ok = :gen_tcp.close(socket)
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "redirect responses are returned unchanged without following the Location" do
    {url, peer} =
      peer(fn socket, _owner ->
        _ = head(socket)

        :gen_tcp.send(socket, [
          "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:1/do-not-follow\r\n",
          "Content-Length: 0\r\n\r\n"
        ])
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("GET", "/redirect", [{"Connection", "close"}]))
    response = head(socket)
    assert response =~ "302 Found"
    assert response =~ "location: http://127.0.0.1:1/do-not-follow\r\n"
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  test "a truncated chunked upstream closes a committed response without a success terminator" do
    {url, peer} =
      peer(fn socket, _owner ->
        _ = head(socket)

        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nbody\r\n"
        )
      end)

    server = server(url)
    socket = connect(server)
    :ok = :gen_tcp.send(socket, request("GET", "/truncated"))
    assert head(socket) =~ "200 OK"
    bytes = until_close(socket)
    assert bytes == "4\r\nbody\r\n"
    refute bytes =~ "0\r\n\r\n"
    assert_peer(peer)
    assert :ok = Gaoxy.stop(server, @timeout)
  end

  defp server(url) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint:
          {Gaoxy.HTTP.Router,
           [
             %{path: "/local", target: {Local, []}},
             %{path: :any, target: {Gaoxy.Proxy.HTTP, %{upstream: url}}}
           ]},
        limits: %{max_bytes: 134_217_728}
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

  defp request(method, path, fields \\ []) do
    [
      "#{method} #{path} HTTP/1.1\r\nHost: downstream.test\r\n",
      Enum.map(fields, fn {name, value} -> [name, ": ", value, "\r\n"] end),
      "\r\n"
    ]
  end

  defp peer(fun) do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    peer =
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
      if Process.alive?(peer), do: Process.exit(peer, :kill)
      :gen_tcp.close(listener)
    end)

    {"http://127.0.0.1:#{port}", peer}
  end

  defp assert_peer(peer) do
    monitor = Process.monitor(peer)

    receive do
      {:peer_done, ^peer} -> :ok
      {:peer_error, ^peer, error} -> flunk(error)
    after
      @timeout -> flunk("upstream did not finish")
    end

    assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                   @timeout
  end

  defp head(socket, bytes \\ "") do
    next = bytes <> line(socket)
    if String.ends_with?(next, "\r\n\r\n"), do: next, else: head(socket, next)
  end

  defp line(socket, bytes \\ "") do
    {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
    next = bytes <> byte
    if String.ends_with?(next, "\r\n"), do: next, else: line(socket, next)
  end

  defp chunks(socket, bytes \\ "") do
    size = socket |> line() |> String.trim() |> String.to_integer(16)

    if size == 0 do
      {bytes, trailers(socket)}
    else
      {:ok, chunk} = :gen_tcp.recv(socket, size, @timeout)
      assert {:ok, "\r\n"} = :gen_tcp.recv(socket, 2, @timeout)
      chunks(socket, bytes <> chunk)
    end
  end

  defp trailers(socket, fields \\ []) do
    case line(socket) do
      "\r\n" ->
        Enum.reverse(fields)

      field ->
        [name, value] = String.split(String.trim_trailing(field, "\r\n"), ":", parts: 2)
        trailers(socket, [{String.downcase(name), String.trim(value)} | fields])
    end
  end

  defp until_close(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, more} -> until_close(socket, bytes <> more)
      {:error, :closed} -> bytes
    end
  end
end
