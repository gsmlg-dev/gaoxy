defmodule Gaoxy.HTTP.StreamLifetimeTest do
  use ExUnit.Case, async: true

  defmodule StreamPlug do
    def init(options), do: options

    def call(conn, owner) do
      case conn.request_path do
        "/body" ->
          {:ok, _body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, "body")

        "/upload" ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          conn = conn |> Gaoxy.HTTP.put_stream_timeout(:infinity) |> Plug.Conn.send_chunked(200)
          send(owner, {:uploaded_stream, self(), body})
          loop(conn, owner)

        path ->
          conn =
            case path do
              "/infinite" -> Gaoxy.HTTP.put_stream_timeout(conn, :infinity)
              "/finite" -> Gaoxy.HTTP.put_stream_timeout(conn, :request)
              "/short" -> Gaoxy.HTTP.put_stream_timeout(conn, 150)
              _ -> conn
            end

          conn = Plug.Conn.send_chunked(conn, 200)
          send(owner, {:stream_started, self()})
          loop(conn, owner)
      end
    end

    defp loop(conn, owner) do
      receive do
        {:chunk, data} ->
          case Plug.Conn.chunk(conn, data) do
            {:ok, next} ->
              send(owner, {:chunk_sent, self()})
              loop(next, owner)

            {:error, reason} ->
              send(owner, {:stream_error, self(), reason})
              conn
          end

        :flood ->
          Enum.reduce_while(1..4096, conn, fn _, current ->
            case Plug.Conn.chunk(current, :binary.copy("x", 16_384)) do
              {:ok, next} ->
                {:cont, next}

              {:error, reason} ->
                send(owner, {:stream_error, self(), reason})
                {:halt, current}
            end
          end)

        :finish ->
          conn

        :cancel ->
          {:ok, conn} = Gaoxy.HTTP.abort(conn, :cancelled)
          conn
      after
        20 ->
          case Gaoxy.HTTP.poll_connection(conn, 0) do
            {kind, next} when kind in [:pending, :more] ->
              loop(next, owner)

            {:error, reason, next} ->
              send(owner, {:stream_error, self(), reason})
              next
          end
      end
    end
  end

  test "stream lifetime accepts explicit infinity while request and I/O deadlines stay finite" do
    for timeout <- [:infinity, :request, 500] do
      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{stream_timeout: timeout}
               )

      assert spec.handler_options.http_limits.stream_timeout == timeout
    end

    for timeout <- [0, -1, nil, true, 1.5] do
      assert {:error, :invalid_http_limit} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{stream_timeout: timeout}
               )
    end

    for key <- [:request_timeout, :header_timeout, :read_timeout, :write_timeout] do
      assert {:error, :invalid_http_limit} =
               Gaoxy.HTTP.service_spec(
                 plug: {StreamPlug, self()},
                 http_limits: %{key => :infinity}
               )
    end
  end

  test "route opt-in survives multiple absolute request intervals and releases on peer close" do
    {server, port} = server()
    {socket, worker, monitor} = request(port, "/infinite")

    for index <- 1..5 do
      receive do
      after
        100 -> :ok
      end

      heartbeat = "heartbeat-#{index}"
      send(worker, {:chunk, heartbeat})
      assert_receive {:chunk_sent, ^worker}, 1_000
      assert recv_until(socket, heartbeat) =~ heartbeat
    end

    assert Process.alive?(worker)
    send(worker, {:chunk, "survived"})
    assert_receive {:chunk_sent, ^worker}, 1_000
    assert recv_until(socket, "survived") =~ "survived"
    assert Gaoxy.status(server, :http).active > 0
    :gen_tcp.close(socket)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert_idle(server)
  end

  test "listener infinite default coexists with ordinary absolute route deadlines" do
    {server, port} = server(%{stream_timeout: :infinity})
    {_finite, finite, finite_monitor} = request(port, "/finite")
    {infinite_socket, infinite, infinite_monitor} = request(port, "/default")
    assert_receive {:DOWN, ^finite_monitor, :process, ^finite, _}, 1_000
    assert Process.alive?(infinite)
    send(infinite, {:chunk, "still-open"})
    assert_receive {:chunk_sent, ^infinite}, 1_000
    assert recv_until(infinite_socket, "still-open") =~ "still-open"
    send(infinite, :finish)
    assert_receive {:DOWN, ^infinite_monitor, :process, ^infinite, _}, 1_000
    :gen_tcp.close(infinite_socket)
    assert_idle(server)
  end

  test "finite stream lifetime is measured from response start" do
    {server, port} = server(%{request_timeout: 1_000})
    {_socket, worker, monitor} = request(port, "/short")
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 800
    assert_idle(server)
  end

  test "explicit cancellation closes an infinite response and releases its lease" do
    {server, port} = server()
    {socket, worker, monitor} = request(port, "/infinite")
    send(worker, :cancel)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
    assert_idle(server)
  end

  test "infinite streaming does not permit unconsumed request bodies" do
    # This case tests rejection and its exact error response, independently of
    # the 120 ms expiry cases above and the finite body-read case below.
    {server, port} = server(%{stream_timeout: :infinity, request_timeout: 1_000})
    {:ok, socket} = connect(port)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /default HTTP/1.1\r\nHost: localhost\r\nContent-Length: 12\r\n\r\n"
      )

    assert recv_until(socket, "\r\n\r\n") =~ "500"
    refute_receive {:stream_started, _}, 50
    :gen_tcp.close(socket)
    assert_idle(server)
  end

  test "a consumed upload may transition to an infinite streaming response" do
    {server, port} = server()
    {:ok, socket} = connect(port)

    :ok =
      :gen_tcp.send(
        socket,
        "POST /upload HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: 12\r\n\r\nhello-stream"
      )

    assert_receive {:uploaded_stream, worker, "hello-stream"}, 1_000
    monitor = Process.monitor(worker)
    assert recv_until(socket, "\r\n\r\n") =~ "200 OK"

    receive do
    after
      300 -> :ok
    end

    send(worker, {:chunk, "after-upload"})
    assert_receive {:chunk_sent, ^worker}, 1_000
    assert recv_until(socket, "after-upload") =~ "after-upload"
    send(worker, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    :gen_tcp.close(socket)
    assert_idle(server)
  end

  test "infinite stream configuration keeps header and body reads bounded" do
    {server, port} = server(%{stream_timeout: :infinity, header_timeout: 70, read_timeout: 70})
    {:ok, header} = connect(port)
    :ok = :gen_tcp.send(header, "GET /default HTTP/1.1\r\nHost:")
    assert {:error, :closed} = drain(header)
    :gen_tcp.close(header)

    {:ok, body} = connect(port)

    :ok =
      :gen_tcp.send(body, "POST /body HTTP/1.1\r\nHost: localhost\r\nContent-Length: 12\r\n\r\n")

    assert {:error, :closed} = drain(body)
    :gen_tcp.close(body)
    assert_idle(server)
  end

  test "a non-reading peer cannot unbound writes or instance shutdown" do
    {server, port} = server(%{write_timeout: 60})
    {socket, worker, monitor} = request(port, "/infinite", recbuf: 1024)
    send(worker, :flood)
    assert_receive {:stream_error, ^worker, :timeout}, 3_000
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    :gen_tcp.close(socket)
    assert_idle(server)
    assert :ok = Gaoxy.stop(server, 1_000)
  end

  test "shutdown terminates an infinite active stream within the public deadline" do
    {server, port} = server()
    {socket, worker, monitor} = request(port, "/infinite")
    server_monitor = Process.monitor(server)
    started = System.monotonic_time(:millisecond)
    result = Gaoxy.stop(server, 500)

    # ADR 004 preserves the service aggregate when it wins the caller-deadline race.
    assert result in [
             :ok,
             {:error, {:deadline_exceeded, :cleanup_pending}},
             {:error, {:services, [http: {:error, {:deadline_exceeded, :cleanup_pending}}]}}
           ]

    assert System.monotonic_time(:millisecond) - started < 1_500
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    assert_receive {:DOWN, ^server_monitor, :process, ^server, :normal}, 1_000
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
  end

  defp server(overrides \\ %{}) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {StreamPlug, self()},
        http_limits: Map.merge(%{request_timeout: 120}, overrides)
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 1_000) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local
    {server, port}
  end

  defp request(port, path, options \\ []) do
    {:ok, socket} = connect(port, options)

    :ok =
      :gen_tcp.send(socket, [
        "GET ",
        path,
        " HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      ])

    assert_receive {:stream_started, worker}, 1_000
    monitor = Process.monitor(worker)
    assert recv_until(socket, "\r\n\r\n") =~ "200 OK"
    {socket, worker, monitor}
  end

  defp connect(port, options \\ []) do
    result = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false] ++ options, 1_000)

    if match?({:ok, _}, result) do
      {:ok, socket} = result
      on_exit(fn -> :gen_tcp.close(socket) end)
    end

    result
  end

  defp recv_until(socket, text, acc \\ "") do
    if String.contains?(acc, text) do
      acc
    else
      assert {:ok, bytes} = :gen_tcp.recv(socket, 0, 1_000)
      recv_until(socket, text, acc <> bytes)
    end
  end

  defp drain(socket) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, _} -> drain(socket)
      error -> error
    end
  end

  defp assert_idle(server), do: assert_idle(server, Gaoxy.Lifecycle.deadline(1_000))

  defp assert_idle(server, deadline) do
    status = Gaoxy.status(server, :http)

    if status.active == 0 do
      assert status.retained_bytes == 0
    else
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        5 -> :ok
      end

      assert_idle(server, deadline)
    end
  end
end
