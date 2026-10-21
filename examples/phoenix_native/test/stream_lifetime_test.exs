defmodule PhoenixNative.StreamLifetimeTest do
  use ExUnit.Case, async: false

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    plug(:events)

    defp events(conn, _) do
      timeout = if conn.request_path == "/finite", do: :request, else: :infinity

      conn =
        conn
        |> Gaoxy.HTTP.put_stream_timeout(timeout)
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_chunked(200)

      send(
        Application.fetch_env!(:phoenix_native, :stream_lifetime_observer),
        {:phoenix_stream, self()}
      )

      loop(conn)
    end

    defp loop(conn) do
      receive do
        :finish -> conn
      after
        25 ->
          with {:pending, conn} <- Gaoxy.HTTP.poll_connection(conn, 0),
               {:ok, conn} <- Plug.Conn.chunk(conn, ": keepalive\n\n") do
            loop(conn)
          else
            {:error, _, next} -> next
            {:error, _} -> conn
            {:more, next} -> next
          end
      end
    end
  end

  setup do
    Application.put_env(:phoenix_native, :stream_lifetime_observer, self())

    Application.put_env(:phoenix_native, Endpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      http: [
        ip: {127, 0, 0, 1},
        port: 0,
        http_limits: %{request_timeout: 150, stream_timeout: :infinity}
      ],
      url: [host: "localhost"],
      secret_key_base: String.duplicate("stream-test-", 8),
      code_reloader: false,
      debug_errors: false,
      watchers: []
    )

    on_exit(fn ->
      Application.delete_env(:phoenix_native, :stream_lifetime_observer)
      Application.delete_env(:phoenix_native, Endpoint)
    end)

    start_supervised!(Endpoint)
    {:ok, {{127, 0, 0, 1}, port}} = Endpoint.server_info(:http)
    {:ok, port: port}
  end

  test "Phoenix SSE route survives several request intervals and reclaims its worker on client close",
       %{port: port} do
    {socket, worker, monitor} = request(port, "/events")

    receive do
    after
      650 -> :ok
    end

    assert Process.alive?(worker)
    assert {:ok, bytes} = :gen_tcp.recv(socket, 0, 1_000)
    assert bytes =~ "keepalive"
    :gen_tcp.close(socket)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
  end

  test "Phoenix listener infinite default allows an explicitly finite route", %{port: port} do
    {socket, worker, monitor} = request(port, "/finite")
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    :gen_tcp.close(socket)
  end

  defp request(port, path) do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(socket, [
        "GET ",
        path,
        " HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      ])

    assert_receive {:phoenix_stream, worker}, 1_000
    monitor = Process.monitor(worker)
    assert {:ok, bytes} = :gen_tcp.recv(socket, 0, 1_000)
    assert bytes =~ "200 OK"
    assert bytes =~ "text/event-stream"
    {socket, worker, monitor}
  end
end
