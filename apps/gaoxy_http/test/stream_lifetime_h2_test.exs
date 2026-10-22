defmodule Gaoxy.HTTP.StreamLifetimeH2Test do
  alias HTTP.HTTP2.HPACK
  use ExUnit.Case, async: true

  defmodule StreamPlug do
    def init(owner), do: owner

    def call(conn, owner) do
      if conn.request_path == "/ok" do
        Plug.Conn.send_resp(conn, 200, "sibling-ok")
      else
        conn =
          if conn.request_path == "/finite",
            do: conn,
            else: Gaoxy.HTTP.put_stream_timeout(conn, :infinity)

        conn = Plug.Conn.send_chunked(conn, 200)
        send(owner, {:h2_stream, self(), conn.request_path})
        if conn.request_path == "/cancel", do: Process.send_after(self(), :cancel, 100)
        loop(conn, owner)
      end
    end

    defp loop(conn, owner) do
      receive do
        :cancel ->
          Gaoxy.HTTP.abort(conn, :cancelled)
          conn
      after
        25 ->
          case Plug.Conn.chunk(conn, ": keepalive\n\n") do
            {:ok, next} ->
              loop(next, owner)

            {:error, reason} ->
              send(owner, {:h2_stream_error, self(), reason})
              conn
          end
      end
    end
  end

  test "independent h2 peer proves infinite lifetime, finite sibling, reset, cancel and bounded flow-control writes" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {StreamPlug, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        http_limits: %{request_timeout: 200, write_timeout: 100}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 1_000) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local
    python = Path.expand("../../../.audit/h2peer/bin/python", __DIR__)
    assert File.exists?(python)

    assert {output, 0} =
             System.cmd(
               python,
               [
                 Path.join(__DIR__, "support/stream_lifetime_h2_peer.py"),
                 Integer.to_string(port)
               ],
               stderr_to_stdout: true
             )

    assert output =~
             "PASS stream lifetime, finite sibling, peer reset, application cancel, zero-window deadline"

    assert_idle(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  test "H2 server drain stays bounded with an infinite stream and joins its worker" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {StreamPlug, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        http_limits: %{request_timeout: 200}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 1_000) end)
    {:ok, {_, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    {_, block} =
      HPACK.encode_headers(
        HPACK.new_encoder(),
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/infinite"}
        ],
        indexing: :literal,
        huffman: :never
      )

    :ok =
      :gen_tcp.send(socket, [
        "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
        Gaoxy.HTTP.HTTP2.Frame.encode(4, 0, 0, ""),
        Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block)
      ])

    assert_receive {:h2_stream, worker, "/infinite"}, 1_000
    monitor = Process.monitor(worker)
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
  end

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
