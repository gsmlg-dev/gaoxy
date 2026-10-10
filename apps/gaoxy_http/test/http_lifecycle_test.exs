defmodule Gaoxy.HTTP.LifecycleTest do
  use ExUnit.Case, async: true

  defmodule Handler do
    import Plug.Conn
    def init(owner), do: owner

    def call(conn, owner) do
      case conn.request_path do
        "/held" ->
          conn = send_chunked(conn, 200)
          {:ok, conn} = chunk(conn, "first")
          send(owner, {:held, self()})

          receive do
            :finish -> :ok
          end

          {:ok, conn} = chunk(conn, "last")
          conn

        "/blocked-write" ->
          payload = List.duplicate(:binary.copy(<<1>>, 65_536), 8_192)
          send(owner, {:responding, self()})
          send_resp(conn, 200, payload)

        _ ->
          send(owner, {:called, conn.request_path})
          send_resp(conn, 200, "alive")
      end
    end
  end

  test "drain finishes the admitted stream and rejects its pipelined successor" do
    {server, ip, port} = server()
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :gen_tcp.send(
      socket,
      "GET /held HTTP/1.1\r\nHost: localhost\r\n\r\nGET /next HTTP/1.1\r\nHost: localhost\r\n\r\n"
    )

    assert_receive {:held, owner}
    removal = Task.async(fn -> Gaoxy.remove(server, :http, 1000) end)
    wait_draining(server, System.monotonic_time(:millisecond) + 500)
    send(owner, :finish)
    response = all(socket)
    assert response =~ "5\r\nfirst\r\n4\r\nlast\r\n0\r\n\r\n"
    refute_receive {:called, "/next"}, 20
    assert :ok = Task.await(removal)
  end

  test "a slow reader cannot block another connection and has a bounded write lifetime" do
    {server, ip, port} = server(http_limits: %{write_timeout: 80, request_timeout: 2000})
    {:ok, slow} = :gen_tcp.connect(ip, port, [:binary, active: false, recbuf: 1024], 1000)
    on_exit(fn -> :gen_tcp.close(slow) end)
    :gen_tcp.send(slow, "GET /blocked-write HTTP/1.1\r\nHost: localhost\r\n\r\n")
    assert_receive {:responding, owner}
    monitor = Process.monitor(owner)
    {:ok, fast} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(fast) end)
    :gen_tcp.send(fast, "GET /fast HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    assert all(fast) =~ "alive"
    assert_receive {:DOWN, ^monitor, :process, ^owner, _}, 1000
    assert Gaoxy.status(server, :http).retained_high_water <= 1_048_576
  end

  test "request headers retained by a streaming Plug remain charged" do
    {server, ip, port} = server()
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :gen_tcp.send(socket, [
      "GET /held HTTP/1.1\r\nHost: localhost\r\nX-Held: ",
      String.duplicate("x", 512),
      "\r\nConnection: close\r\n\r\n"
    ])

    assert_receive {:held, owner}
    retained = Gaoxy.status(server, :http).retained_bytes
    send(owner, :finish)
    assert all(socket) =~ "last"
    assert retained >= 512
  end

  defp server(options \\ []) do
    {:ok, server} = Gaoxy.HTTP.start_link([plug: {Handler, self()}] ++ options)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {server, ip, port}
  end

  defp wait_draining(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{state: :draining} ->
        :ok

      _ ->
        assert System.monotonic_time(:millisecond) < deadline

        receive do
        after
          5 -> :ok
        end

        wait_draining(server, deadline)
    end
  end

  defp all(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, data} -> all(socket, acc <> data)
      {:error, :closed} -> acc
    end
  end
end
