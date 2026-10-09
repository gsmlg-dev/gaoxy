defmodule Gaoxy.HTTP.NetworkTest do
  use ExUnit.Case, async: true

  defmodule Echo do
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      case conn.request_path do
        "/body" ->
          {body, conn} = read_all(conn, "")
          send_resp(conn, 200, body)

        "/head" ->
          send_resp(conn, 200, "content")

        "/stream" ->
          conn = send_chunked(conn, 200)
          {:ok, conn} = chunk(conn, "first")
          {:ok, conn} = chunk(conn, "")
          {:ok, conn} = chunk(conn, "second")
          if opts[:owner], do: send(opts[:owner], {:stream_complete, conn.method})
          conn

        "/unread" ->
          send_resp(conn, 200, "done")

        "/large" ->
          send_resp(conn, 200, String.duplicate("a", 2_000))

        "/large-body" ->
          {body, conn} = read_all(conn, "")
          send_resp(conn, 200, Integer.to_string(byte_size(body)))

        "/fixed-stream" ->
          conn = conn |> put_resp_header("content-length", "5") |> send_chunked(200)
          {:ok, conn} = chunk(conn, "hello")
          conn

        "/early" ->
          conn |> inform(103, [{"link", "</asset>; rel=preload"}]) |> send_resp(200, "done")

        "/file" ->
          send_file(conn, 200, opts[:file])

        "/no-content" ->
          send_resp(conn, 204, "ignored")

        "/bad-after" ->
          conn = send_chunked(conn, 200)
          {:ok, _conn} = chunk(conn, "x")
          raise "failed after response began"

        "/tls" ->
          data = Plug.Conn.get_ssl_data(conn)
          send_resp(conn, 200, if(data, do: "secure", else: "insecure"))

        _ ->
          send_resp(conn, 200, conn.request_path)
      end
    end

    defp read_all(conn, acc) do
      case read_body(conn) do
        {:ok, body, conn} -> {acc <> body, conn}
        {:more, body, conn} -> read_all(conn, acc <> body)
      end
    end
  end

  defmodule DirectStream do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(opts), do: {:ok, opts}

    def call(exchange, _opts) do
      {:ok, exchange} = Gaoxy.HTTP.HTTP1.Response.send_chunked(exchange, 200, [])
      :ok = Gaoxy.HTTP.HTTP1.Response.chunk(exchange, "")
      :ok = Gaoxy.HTTP.HTTP1.Response.chunk(exchange, "x")
      {:ok, exchange}
    end
  end

  test "fragmented request and a pipelined request use one native connection" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok = :gen_tcp.send(socket, "GET /one HTTP/1.1\r\nHo")

    :ok =
      :gen_tcp.send(
        socket,
        "st: localhost\r\n\r\nGET /two HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    response = receive_all(socket, "")
    assert response =~ "HTTP/1.1 200 OK\r\n"
    assert response =~ "\r\n\r\n/oneHTTP/1.1 200 OK\r\n"
    assert String.ends_with?(response, "\r\n\r\n/two")
  end

  test "Plug reads a fixed request body from the network" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nConnection: close\r\n\r\nhello"
      )

    assert receive_all(socket, "") =~ "\r\n\r\nhello"
  end

  test "Plug waits for fragmented body bytes without losing the request budget" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nConnection: close\r\n\r\nhe"
      )

    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 20)
    :ok = :gen_tcp.send(socket, "llo")
    assert receive_all(socket, "") =~ "\r\n\r\nhello"
  end

  test "Plug decodes chunked request bodies" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r\nhello\r\n0\r\n\r\n"
      )

    assert receive_all(socket, "") =~ "\r\n\r\nhello"
  end

  test "fragmented chunk metadata is retained until framing is complete" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n5\r"
      )

    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 20)
    :ok = :gen_tcp.send(socket, "\nhello\r\n0\r\n\r\n")
    assert receive_all(socket, "") =~ "\r\n\r\nhello"
  end

  test "chunked responses end their framing before the next request" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /stream HTTP/1.1\r\nHost: localhost\r\n\r\nGET /next HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    response = receive_all(socket, "")
    assert response =~ "transfer-encoding: chunked\r\n"
    assert response =~ "5\r\nfirst\r\n6\r\nsecond\r\n0\r\n\r\nHTTP/1.1 200 OK"
  end

  test "empty direct chunks are no-op rather than premature terminators" do
    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: {DirectStream, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    [_, body] = String.split(receive_all(socket, ""), "\r\n\r\n", parts: 2)
    assert body == "1\r\nx\r\n0\r\n\r\n"
  end

  test "HEAD suppresses payload while preserving its declared length" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(socket, "HEAD /head HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

    response = receive_all(socket, "")
    assert response =~ "content-length: 7\r\n"
    assert String.ends_with?(response, "\r\n\r\n")
  end

  test "HEAD chunked stream accepts chunks without writing payload" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, [owner: self()]})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "HEAD /stream HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    response = receive_all(socket, "")
    assert response =~ "HTTP/1.1 200 OK\r\n"
    assert String.ends_with?(response, "\r\n\r\n")
    refute response =~ "first"
    assert_receive {:stream_complete, "HEAD"}
  end

  test "an unread request body closes after the response" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /unread HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nhelloGET /next HTTP/1.1\r\nHost: localhost\r\n\r\n"
      )

    response = receive_all(socket, "")
    assert response =~ "\r\n\r\ndone"
    assert response =~ "connection: close\r\n"
    refute response =~ "/next"
  end

  test "invalid limits fail before the TCP port is bound" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    :gen_tcp.close(listener)

    assert {:error, _} =
             Gaoxy.HTTP.start_link(plug: {Echo, []}, port: port, http_limits: %{unknown: 1})

    assert {:ok, available} = :gen_tcp.listen(port, [:binary, active: false, ip: {127, 0, 0, 1}])
    :gen_tcp.close(available)
  end

  test "a response larger than the admitted output window streams in bounded writes" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {Echo, []},
        limits: %{max_bytes: 1024, max_output: 512},
        http_limits: %{max_read_chunk: 512}
      )

    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(socket, "GET /large HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

    assert receive_all(socket, "") =~ "\r\n\r\n" <> String.duplicate("a", 2_000)
  end

  test "one large client write streams through a smaller parser buffer" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {Echo, []},
        limits: %{max_bytes: 4096},
        http_limits: %{max_read_chunk: 512, max_buffer_bytes: 1024}
      )

    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    body = String.duplicate("x", 2_000)

    :ok =
      :gen_tcp.send(socket, [
        "POST /large-body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 2000\r\nConnection: close\r\n\r\n",
        body
      ])

    assert receive_all(socket, "") =~ "\r\n\r\n2000"
  end

  test "fragmented headers cannot renew the original header deadline" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {Echo, []},
        http_limits: %{header_timeout: 50, request_timeout: 1_000}
      )

    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok = :gen_tcp.send(socket, "GET /one HTTP/1.1\r\nHo")
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 300)
  end

  test "Expect 100-continue is sent before reading the body" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\nExpect: 100-continue\r\nConnection: close\r\n\r\n"
      )

    assert {:ok, "HTTP/1.1 100 Continue\r\n\r\n"} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.send(socket, "hello")
    assert receive_all(socket, "") =~ "\r\n\r\nhello"
  end

  test "informational response and fixed-length streaming preserve next response framing" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /early HTTP/1.1\r\nHost: localhost\r\n\r\nGET /fixed-stream HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    response = receive_all(socket, "")

    assert response =~
             "HTTP/1.1 103 Early Hints\r\nlink: </asset>; rel=preload\r\n\r\nHTTP/1.1 200 OK"

    assert response =~ "content-length: 5\r\n"
    assert String.ends_with?(response, "\r\n\r\nhello")
  end

  test "file response reads from disk and 204 omits a body" do
    file = Path.join(System.tmp_dir!(), "gaoxy-http-#{System.unique_integer([:positive])}")
    File.write!(file, "file-body")
    on_exit(fn -> File.rm(file) end)
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, [file: file]})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /file HTTP/1.1\r\nHost: localhost\r\n\r\nGET /no-content HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    response = receive_all(socket, "")
    assert response =~ "\r\n\r\nfile-bodyHTTP/1.1 204 No Content\r\n"
    refute response |> String.split("HTTP/1.1 204 No Content") |> List.last() =~ "content-length"
    assert String.ends_with?(response, "\r\n\r\n")
  end

  test "a Plug failure after sending headers closes without a second response" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok = :gen_tcp.send(socket, "GET /bad-after HTTP/1.1\r\nHost: localhost\r\n\r\n")
    response = receive_all(socket, "")
    assert response =~ "HTTP/1.1 200 OK\r\n"
    refute response =~ "500 Internal Server Error"
  end

  @tag :tmp_dir
  test "TLS listener serves Plug with a verified certificate", %{tmp_dir: dir} do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {Echo, []},
        transport: :tls,
        tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
      )

    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local

    {:ok, socket} =
      :ssl.connect(
        ip,
        port,
        [
          :binary,
          active: false,
          verify: :verify_peer,
          cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
          server_name_indication: ~c"localhost",
          alpn_advertised_protocols: ["http/1.1"]
        ],
        1000
      )

    on_exit(fn -> :ssl.close(socket) end)
    :ok = :ssl.send(socket, "GET /tls HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    assert tls_receive_all(socket, "") =~ "\r\n\r\nsecure"
  end

  test "drain closes an idle admitted HTTP connection" do
    {:ok, server} = Gaoxy.HTTP.start_link(plug: {Echo, []})
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    assert_active(server, 1_000)
    assert :ok = Gaoxy.remove(server, :http, 1_000)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
  end

  defp receive_all(socket, acc) do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, bytes} -> receive_all(socket, acc <> bytes)
      {:error, :closed} -> acc
    end
  end

  defp tls_receive_all(socket, acc) do
    case :ssl.recv(socket, 0, 1000) do
      {:ok, bytes} -> tls_receive_all(socket, acc <> bytes)
      {:error, :closed} -> acc
    end
  end

  defp assert_active(server, deadline) do
    if Gaoxy.status(server, :http).active == 1 do
      :ok
    else
      receive do
      after
        5 -> :ok
      end

      if deadline > 5,
        do: assert_active(server, deadline - 5),
        else: flunk("HTTP lease not active")
    end
  end
end
