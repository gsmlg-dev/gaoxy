defmodule Gaoxy.HTTP.RequestLifetimeNetworkTest do
  use ExUnit.Case, async: true

  defmodule StoragePlug do
    def init(options), do: options

    def call(conn, options) do
      owner = Keyword.fetch!(options, :owner)
      send(owner, {:request_started, self(), conn.request_path})

      case conn.request_path do
        path when path in ["/upload", "/reset"] ->
          upload(conn, owner, 0)

        "/file" ->
          receive do
            :send_file -> Plug.Conn.send_file(conn, 200, Keyword.fetch!(options, :file))
          after
            2_000 -> raise "file dispatch deadline"
          end

        "/download" ->
          Plug.Conn.send_file(conn, 200, Keyword.fetch!(options, :file))

        "/ok" ->
          Plug.Conn.send_resp(conn, 200, "sibling-ok")
      end
    end

    defp upload(conn, owner, received) do
      case Plug.Conn.read_body(conn, length: 16, read_length: 16, read_timeout: 1_000) do
        {kind, bytes, next} when kind in [:ok, :more] ->
          received = received + byte_size(bytes)
          send(owner, {:body_progress, self(), received})

          if next.request_path == "/reset" and received == 16,
            do: Plug.Conn.inform(next, 103, [])

          if kind == :ok,
            do: Plug.Conn.send_resp(next, 200, Integer.to_string(received)),
            else: upload(next, owner, received)

        {:error, reason} ->
          send(owner, {:body_error, self(), reason})
          Plug.Conn.send_resp(conn, 408, "idle body")
      end
    end
  end

  test "infinite request lifetime permits a progressing bounded upload beyond a finite deadline" do
    {server, port} = server()
    socket = connect(port)
    upload_head(socket)
    assert_receive {:request_started, worker, "/upload"}, 1_000
    monitor = Process.monitor(worker)
    started = Gaoxy.Lifecycle.now()

    for index <- 1..8 do
      receive do
      after
        80 -> :ok
      end

      :ok = :gen_tcp.send(socket, :binary.copy(<<index>>, 16))
      received = index * 16
      assert_receive {:body_progress, ^worker, ^received}, 1_000
    end

    assert Gaoxy.Lifecycle.now() - started >= 600
    response = recv_closed(socket)
    assert response =~ "200 OK"
    assert String.ends_with?(response, "128")
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert_idle(server)
  end

  test "a finite request deadline still expires while the upload is progressing" do
    {server, port} = server(%{request_timeout: 250})
    socket = connect(port)
    upload_head(socket)
    assert_receive {:request_started, worker, "/upload"}, 1_000
    monitor = Process.monitor(worker)

    for index <- 1..2 do
      :ok = :gen_tcp.send(socket, :binary.copy(<<index>>, 16))
      received = index * 16
      assert_receive {:body_progress, ^worker, ^received}, 1_000

      receive do
      after
        80 -> :ok
      end
    end

    assert recv_closed(socket) == ""
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert_idle(server)
  end

  test "infinite upload retains finite body inactivity and partial header deadlines" do
    {server, port} = server(%{header_timeout: 150, read_timeout: 150})
    partial = connect(port)
    :ok = :gen_tcp.send(partial, "PUT /upload HTTP/1.1\r\nHost:")
    assert recv_closed(partial) == ""

    socket = connect(port)
    upload_head(socket)
    assert_receive {:request_started, worker, "/upload"}, 1_000
    monitor = Process.monitor(worker)
    assert_receive {:body_error, ^worker, :timeout}, 1_000
    assert recv_closed(socket) =~ "408 Request Timeout"
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert_idle(server)
  end

  @tag :tmp_dir
  test "send_file inherits infinite request lifetime without a chunked-response transition", %{
    tmp_dir: tmp_dir
  } do
    file = Path.join(tmp_dir, "object")
    bytes = :binary.copy("storage-object", 8_192)
    File.write!(file, bytes)
    {server, port} = server(%{}, file: file)
    socket = connect(port)

    :ok =
      :gen_tcp.send(socket, "GET /file HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

    assert_receive {:request_started, worker, "/file"}, 1_000

    receive do
    after
      650 -> :ok
    end

    send(worker, :send_file)
    response = recv_closed(socket)
    assert response =~ "200 OK"
    assert [_headers, ^bytes] = :binary.split(response, "\r\n\r\n")
    assert_idle(server)
  end

  test "peer abandonment of an infinite upload releases its admission ownership" do
    {server, port} = server()
    socket = connect(port)
    upload_head(socket)
    assert_receive {:request_started, worker, "/upload"}, 1_000
    monitor = Process.monitor(worker)
    :ok = :gen_tcp.close(socket)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert_idle(server)
  end

  test "infinite uploads support a bounded 100 Continue handshake" do
    {server, port} = server()
    socket = connect(port)

    :ok =
      :gen_tcp.send(
        socket,
        "PUT /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 16\r\nExpect: 100-continue\r\nConnection: close\r\n\r\n"
      )

    assert_receive {:request_started, worker, "/upload"}, 1_000
    assert {:ok, "HTTP/1.1 100 Continue\r\n\r\n"} = :gen_tcp.recv(socket, 25, 1_000)
    :ok = :gen_tcp.send(socket, :binary.copy("x", 16))
    assert_receive {:body_progress, ^worker, 16}, 1_000
    assert recv_closed(socket) =~ "200 OK"
    assert_idle(server)
  end

  @tag :tmp_dir
  test "an infinite file response retains a finite write timeout for a nonreading peer", %{
    tmp_dir: tmp_dir
  } do
    file = Path.join(tmp_dir, "object")
    File.write!(file, :binary.copy("s", 8_388_608))
    {server, port} = server(%{}, file: file)

    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, recbuf: 1_024], 1_000)

    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /download HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    assert_receive {:request_started, worker, "/download"}, 1_000
    monitor = Process.monitor(worker)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 2_000
    :ok = :gen_tcp.close(socket)
    assert_idle(server)
  end

  test "server stop joins an active infinite upload within its shutdown budget" do
    {server, port} = server()
    socket = connect(port)
    upload_head(socket)
    assert_receive {:request_started, worker, "/upload"}, 1_000
    monitor = Process.monitor(worker)
    started = Gaoxy.Lifecycle.now()

    assert Gaoxy.stop(server, 500) in [
             :ok,
             {:error, {:deadline_exceeded, :cleanup_pending}},
             {:error, {:services, [http: {:error, {:deadline_exceeded, :cleanup_pending}}]}}
           ]

    assert Gaoxy.Lifecycle.now() - started < 1_500
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
  end

  @tag :tmp_dir
  test "independent H2 peer proves uploads, files, idle/reset cleanup and bounded blocked writes",
       %{
         tmp_dir: tmp_dir
       } do
    file = Path.join(tmp_dir, "object")
    File.write!(file, :binary.copy("s", 131_072))

    {server, port} =
      server(%{header_timeout: 150}, file: file, protocols: [:http2], h2c: :prior_knowledge)

    python =
      System.get_env("GAOXY_QUIC_PYTHON") ||
        Path.expand("../../../.audit/h2peer/bin/python", __DIR__)

    assert {output, 0} =
             System.cmd(
               python,
               [
                 Path.join(__DIR__, "support/request_lifetime_h2_peer.py"),
                 Integer.to_string(port)
               ],
               stderr_to_stdout: true
             )

    assert output =~ "PASS upload, file, idle, reset, sibling, write deadline"
    assert_idle(server)
  end

  test "a finite H2 listener still expires a progressing upload" do
    {server, port} = server(%{request_timeout: 250}, protocols: [:http2], h2c: :prior_knowledge)

    python =
      System.get_env("GAOXY_QUIC_PYTHON") ||
        Path.expand("../../../.audit/h2peer/bin/python", __DIR__)

    assert {output, 0} =
             System.cmd(
               python,
               [
                 Path.join(__DIR__, "support/request_lifetime_h2_peer.py"),
                 Integer.to_string(port),
                 "finite"
               ],
               stderr_to_stdout: true
             )

    assert output =~ "PASS finite request deadline"
    assert_idle(server)
  end

  defp server(overrides \\ %{}, options \\ []) do
    {plug_options, listener_options} = Keyword.split(options, [:file])

    limits =
      Map.merge(%{request_timeout: :infinity, read_timeout: 300, write_timeout: 300}, overrides)

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        [plug: {StoragePlug, [owner: self()] ++ plug_options}, http_limits: limits] ++
          listener_options
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 1_000) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local
    {server, port}
  end

  defp connect(port) do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp upload_head(socket) do
    :ok =
      :gen_tcp.send(
        socket,
        "PUT /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 128\r\nConnection: close\r\n\r\n"
      )
  end

  defp recv_closed(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, chunk} -> recv_closed(socket, bytes <> chunk)
      {:error, :closed} -> bytes
    end
  end

  defp assert_idle(server, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)

    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0} ->
        :ok

      _ ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0

        receive do
        after
          5 -> assert_idle(server, deadline)
        end
    end
  end
end
