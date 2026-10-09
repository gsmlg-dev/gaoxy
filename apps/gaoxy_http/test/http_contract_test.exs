defmodule Gaoxy.HTTP.ContractTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Exchange

  defmodule Plug do
    def init(options), do: options

    def call(conn, options) do
      case conn.request_path do
        "/metadata" ->
          Elixir.Plug.Conn.send_resp(conn, 200, "#{conn.scheme}:#{conn.host}:#{conn.port}")

        "/processing" ->
          conn = Elixir.Plug.Conn.inform(conn, 102, [])
          Elixir.Plug.Conn.send_resp(conn, 200, "ok")

        "/large-inform" ->
          conn = Elixir.Plug.Conn.inform(conn, 103, [{"link", String.duplicate("a", 1024)}])
          Elixir.Plug.Conn.send_resp(conn, 200, "ok")

        "/reset" ->
          Elixir.Plug.Conn.send_resp(conn, 205, "must not be sent")

        "/file" ->
          Elixir.Plug.Conn.send_file(conn, 200, options[:file])

        "/prepared" ->
          Elixir.Plug.Conn.resp(conn, 200, "prepared")

        "/bad-request" ->
          raise Elixir.Plug.BadRequestError

        "/invalid-body" ->
          {:ok, _, conn} = Elixir.Plug.Conn.read_body(conn)
          Elixir.Plug.Conn.send_resp(conn, 200, "read")

        "/close" ->
          conn
          |> Elixir.Plug.Conn.put_resp_header("connection", "keep-alive, Close")
          |> Elixir.Plug.Conn.send_resp(200, "closed")

        "/slow-chunk" ->
          send(options[:owner], {:reading, self()})

          case Elixir.Plug.Conn.read_body(conn, read_timeout: 60) do
            {:error, :timeout} -> Elixir.Plug.Conn.send_resp(conn, 408, "timeout")
            _ -> Elixir.Plug.Conn.send_resp(conn, 200, "read")
          end
      end
    end
  end

  defmodule CaptureTransport do
    def send(owner, data) do
      {:binary, binaries} = Process.info(self(), :binary)

      Kernel.send(
        owner,
        {:wire_write, IO.iodata_length(data),
         Enum.map(binaries, &elem(&1, 1)) |> Enum.max(fn -> 0 end)}
      )

      :ok
    end
  end

  test "iodata output never creates a full-body binary before bounded writes" do
    {:ok, spec} = Gaoxy.HTTP.service_spec(plug: {Plug, []})

    {:ok, gate} =
      Gaoxy.Admission.start_link(
        {%{spec.limits | max_bytes: 4096}, %{instance: make_ref(), service: :test}}
      )

    on_exit(fn -> if Process.alive?(gate), do: GenServer.stop(gate) end)
    {:ok, lease} = Gaoxy.Admission.acquire(gate, 0)

    socket =
      struct!(ThousandIsland.Socket,
        socket: self(),
        transport_module: CaptureTransport,
        read_timeout: 1000,
        handshake_timeout: 1000,
        silent_terminate_on_error: false,
        span: ThousandIsland.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    exchange = %Exchange{
      socket: socket,
      gate: gate,
      lease: lease,
      buffer: "",
      limits: %{max_write_chunk: 1024}
    }

    payload = List.duplicate(:binary.copy(<<1>>, 256), 256)
    assert :ok = Exchange.send_bytes(exchange, payload)

    for _ <- 1..64 do
      assert_receive {:wire_write, 1024, largest}
      assert largest <= 4096
    end
  end

  test "Host without a port uses the scheme default, not the ephemeral bind port" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "GET /metadata HTTP/1.1\r\nHost: example.test\r\nConnection: close\r\n\r\n"
    )

    assert all(socket) =~ "\r\n\r\nhttp:example.test:80"
  end

  test "205 has no payload" do
    {socket, _} = connect()
    :gen_tcp.send(socket, "GET /reset HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = all(socket)
    assert response =~ "HTTP/1.1 205 Reset Content"
    assert String.ends_with?(response, "\r\n\r\n")
  end

  test "an informational 102 is followed by a final response" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "GET /processing HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )

    assert all(socket) =~ "HTTP/1.1 102 Processing\r\n\r\nHTTP/1.1 200 OK"
  end

  test "oversized informational headers are rejected before any response bytes" do
    {socket, _} = connect([], http_limits: %{max_header_bytes: 256})

    :gen_tcp.send(
      socket,
      "GET /large-inform HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )

    response = all(socket)
    assert response =~ "HTTP/1.1 500 Internal Server Error"
    refute response =~ "HTTP/1.1 103"
    refute response =~ String.duplicate("a", 1024)
  end

  @tag :tmp_dir
  test "a failed file read after headers never creates a second response", %{tmp_dir: dir} do
    # Directories stat successfully, but pread returns eisdir after the headers.
    {socket, _} = connect(file: dir)
    :gen_tcp.send(socket, "GET /file HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = all(socket)
    assert response =~ "HTTP/1.1 200 OK"
    refute response =~ "HTTP/1.1 500"
  end

  test "the body read deadline cannot be extended by chunk-metadata progress" do
    {socket, _} = connect(owner: self())

    :gen_tcp.send(
      socket,
      "POST /slow-chunk HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n1;"
    )

    assert_receive {:reading, _}

    for _ <- 1..3 do
      assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 15)
      :ok = :gen_tcp.send(socket, "x")
    end

    assert {:ok, response} = :gen_tcp.recv(socket, 0, 40)
    assert response =~ "HTTP/1.1 408"
  end

  test "invalid normalized limits are rejected before binding" do
    assert {:error, _} =
             Gaoxy.HTTP.Options.normalize(%{
               endpoint: {Plug, []},
               initialized: true,
               http_limits: %{request_timeout: 0}
             })
  end

  test "response Connection close token forbids a pipelined request" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "GET /close HTTP/1.1\r\nHost: localhost\r\n\r\nGET /metadata HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )

    response = all(socket)
    assert response =~ "closed"
    assert length(String.split(response, "HTTP/1.1 200 OK")) == 2
  end

  test "HTTP 1.0 persistence is advertised and can serve a second request" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "GET /metadata HTTP/1.0\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\n"
    )

    assert {:ok, head} = :gen_tcp.recv(socket, 0, 1000)
    assert head =~ "connection: keep-alive\r\n"
    :gen_tcp.send(socket, "GET /metadata HTTP/1.0\r\nHost: localhost\r\n\r\n")
    assert all(socket) =~ "HTTP/1.0 200 OK"
  end

  test "HTTP-only TLS rejects advertisement of an unimplemented protocol" do
    assert {:error, :unsupported_http_alpn} =
             Gaoxy.HTTP.service_spec(
               plug: {Plug, []},
               transport: :tls,
               tls: %{certfile: "cert.pem", keyfile: "key.pem", alpn: ["h2"]}
             )
  end

  test "malformed TLS options return a validation error before binding" do
    for tls <- [[certfile: "cert.pem", keyfile: "key.pem"], nil, :invalid, "tls"] do
      assert {:error, :invalid_options} =
               Gaoxy.HTTP.service_spec(plug: {Plug, []}, transport: :tls, tls: tls)
    end
  end

  test "a prepared Plug response is sent when the pipeline returns" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "GET /prepared HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )

    assert all(socket) =~ "\r\n\r\nprepared"
  end

  test "Plug exceptions preserve their HTTP error status" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "GET /bad-request HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    )

    assert all(socket) =~ "HTTP/1.1 400 Bad Request"
  end

  test "malformed chunked request bodies produce a client error and close" do
    {socket, _} = connect()

    :gen_tcp.send(
      socket,
      "POST /invalid-body HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\nnot-hex\r\n"
    )

    assert all(socket) =~ "HTTP/1.1 400 Bad Request"
  end

  defp connect(options \\ [], server_options \\ []) do
    {:ok, server} = Gaoxy.HTTP.start_link(Keyword.put(server_options, :plug, {Plug, options}))
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    {socket, server}
  end

  defp all(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, data} -> all(socket, acc <> data)
      {:error, :closed} -> acc
    end
  end
end
