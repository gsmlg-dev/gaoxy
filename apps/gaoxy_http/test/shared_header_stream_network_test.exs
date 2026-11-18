defmodule Gaoxy.HTTP.SharedHeaderStreamNetworkTest do
  use ExUnit.Case, async: true

  defmodule Stream do
    def init(options), do: options

    def call(conn, {mode, count, observer}) do
      parent = :binary.copy("v", 8_700)
      headers = for n <- 1..count, do: {"x-test-#{n}", binary_part(parent, n * 100, 100)}

      headers =
        if mode == :compact,
          do: Enum.map(headers, fn {k, v} -> {k, :binary.copy(v)} end),
          else: headers

      send(observer, {:backing, mode, :binary.referenced_byte_size(elem(hd(headers), 1))})

      conn =
        Enum.reduce(headers, conn, fn {name, value}, conn ->
          Plug.Conn.put_resp_header(conn, name, value)
        end)

      conn = Plug.Conn.put_resp_content_type(conn, "text/event-stream")
      conn = Plug.Conn.send_chunked(conn, 200)
      {:ok, conn} = Plug.Conn.chunk(conn, "event: done\ndata: terminal\n\n")
      conn
    end
  end

  for mode <- [:shared, :compact], count <- [4, 8] do
    @mode mode
    @count count
    test "#{count} #{mode} headers start HTTP 200 and deliver the terminal SSE event" do
      {:ok, server} =
        Gaoxy.HTTP.start_link(
          plug: {Stream, {@mode, @count, self()}},
          port: 0,
          protocols: [:http1]
        )

      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 2_000) end)
      {:ok, {ip, port}} = Gaoxy.info(server, :http).local
      {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
      on_exit(fn -> :gen_tcp.close(socket) end)

      :ok =
        :gen_tcp.send(socket, "GET / HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n")

      wire = receive_all(socket, "")
      assert_receive {:backing, @mode, backing}, 2_000
      assert backing == if(@mode == :shared, do: 8_700, else: 100)
      assert String.starts_with?(wire, "HTTP/1.1 200 OK\r\n")
      for n <- 1..@count, do: assert(wire =~ "x-test-#{n}: #{:binary.copy("v", 100)}\r\n")
      assert wire =~ "event: done\ndata: terminal\n\n"
      assert String.ends_with?(wire, "\r\n0\r\n\r\n")
    end
  end

  defmodule Trailers do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options), do: {:ok, options}

    def call(exchange, observer) do
      parent = :binary.copy("v", 4_000)
      trailers = for n <- 1..8, do: {"x-trailer-#{n}", binary_part(parent, n * 100, 100)}
      names = Enum.map_join(trailers, ", ", &elem(&1, 0))
      {:ok, exchange} = Gaoxy.HTTP.Response.send_chunked(exchange, 200, [{"trailer", names}])
      :ok = Gaoxy.HTTP.Response.chunk(exchange, "event: done\ndata: terminal\n\n")
      result = Gaoxy.HTTP.Response.finish(exchange, trailers)

      outcome =
        case result do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      send(observer, {:trailers_finished, outcome})
      result
    end
  end

  test "shared trailer values finish a streamed response within retained renderer bounds" do
    {:ok, server} =
      Gaoxy.HTTP.start_link(endpoint: {Trailers, self()}, port: 0, protocols: [:http1])

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, 2_000) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, "GET / HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n\r\n")
    wire = receive_all(socket, "")
    assert_receive {:trailers_finished, :ok}, 2_000
    assert String.starts_with?(wire, "HTTP/1.1 200 OK\r\n")
    assert wire =~ "event: done\ndata: terminal\n\n"
    for n <- 1..8, do: assert(wire =~ "x-trailer-#{n}: #{:binary.copy("v", 100)}\r\n")
    assert String.ends_with?(wire, "\r\n\r\n")
  end

  defp receive_all(socket, accumulated) do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, bytes} -> receive_all(socket, accumulated <> bytes)
      {:error, :closed} -> accumulated
      other -> flunk("unexpected socket result: #{inspect(other)}")
    end
  end
end
