defmodule Gaoxy.HTTP.HTTP1PartialUploadTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.Lifecycle
  @timeout 1_000

  defmodule Endpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    alias Gaoxy.HTTP.Exchange
    alias Gaoxy.HTTP.HTTP1.Response

    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:upload_ready, self(), exchange.deadline})
      read_commands(exchange, owner)
    end

    defp read_commands(exchange, owner) do
      receive do
        {:read, credit, wait} ->
          result = Exchange.read_body_step(exchange, credit, wait)
          next = elem(result, tuple_size(result) - 1)
          send(owner, {:upload_read, self(), result, Gaoxy.Admission.status(next.gate)})
          read_commands(next, owner)

        :respond ->
          Response.send_resp(exchange, 200, [], "complete")

        :abort ->
          {:error, :closed, exchange}
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end
  end

  for transport <- [:tcp, :tls], framing <- [:length, :chunked] do
    @transport transport
    @framing framing
    @tag :tmp_dir
    test "#{transport} #{framing} delivers the last eight prefix bytes before producer EOF", %{
      tmp_dir: dir
    } do
      {server, socket, reader, deadline} = connect(@transport, @framing, 32_781, dir)
      monitor = Process.monitor(reader)
      first = :binary.copy("a", 16_384)
      last_eight = "last0008"
      rest = :binary.copy("z", 16_389)
      start = if @framing == :chunked, do: "800D\r\n", else: ""

      :ok = send_bytes(@transport, socket, start <> first)
      assert collect(reader, 16_384, 16_384, deadline) == first

      # The producer cannot send the remainder or framing EOF until the real
      # native reader has observed ALL eight bytes, despite its larger credit.
      :ok = send_bytes(@transport, socket, last_eight)
      assert collect(reader, 8, 16_384, deadline) == last_eight
      refute_received {:upload_read, ^reader, {:ok, _, _}, _}

      finish = if @framing == :chunked, do: "\r\n0\r\n\r\n", else: ""
      :ok = send_bytes(@transport, socket, rest <> finish)
      {received, final} = collect_to_eof(reader, 16_384, deadline, "")
      assert first <> last_eight <> received == first <> last_eight <> rest
      assert final.body.phase == :done
      assert final.body.total == 32_781
      assert final.buffer == ""
      finish_request(server, socket, reader, monitor, @transport)
    end
  end

  for transport <- [:tcp, :tls] do
    @transport transport
    @tag :tmp_dir
    test "#{transport} reads preserve credit and max_read_chunk caps", %{tmp_dir: dir} do
      {server, socket, reader, deadline} =
        connect(@transport, :length, 19, dir, max_read_chunk: 5)

      monitor = Process.monitor(reader)
      bytes = "123456789abcdefghij"
      :ok = send_bytes(@transport, socket, bytes)
      {received, final} = collect_to_eof(reader, 7, deadline, "", 5)
      assert received == bytes
      assert final.body.phase == :done
      assert final.buffer == ""
      finish_request(server, socket, reader, monitor, @transport)
    end

    @tag :tmp_dir
    test "#{transport} finite pending and closed reads preserve decoder and admission state", %{
      tmp_dir: dir
    } do
      {server, socket, reader, deadline} = connect(@transport, :length, 9, dir)
      monitor = Process.monitor(reader)
      started = System.monotonic_time(:millisecond)
      assert {:pending, initial} = read(reader, 16_384, 10, deadline)
      assert System.monotonic_time(:millisecond) - started < 250
      assert initial.body.phase == {:length, 9}
      assert initial.buffer == ""
      assert {:pending, ^initial} = read(reader, 16_384, 0, deadline)
      assert {:error, :invalid_read_length, ^initial} = read(reader, 0, 10, deadline)
      assert {:error, :invalid_read_timeout, ^initial} = read(reader, 1, -1, deadline)

      :ok = send_bytes(@transport, socket, "q")
      assert {:more, "q", next} = read(reader, 1, 100, deadline)
      assert next.body.phase == {:length, 8}
      :ok = close(@transport, socket)
      assert {:error, :closed, failed} = read(reader, 16_384, 100, deadline)
      assert failed.body == next.body
      assert failed.buffer == next.buffer
      send(reader, :abort)
      assert_receive {:DOWN, ^monitor, :process, ^reader, _}, @timeout
      assert_idle(server, Lifecycle.deadline(@timeout))
    end
  end

  defp read(reader, credit, wait, deadline) do
    send(reader, {:read, credit, wait})
    assert_receive {:upload_read, ^reader, result, status}, @timeout
    next = elem(result, tuple_size(result) - 1)
    assert next.deadline == deadline
    assert status.retained_bytes == Exchange.retained_bytes(next)
    assert byte_size(next.buffer) <= next.limits.max_buffer_bytes
    result
  end

  defp collect(reader, remaining, credit, deadline, acc \\ "")
  defp collect(_reader, 0, _credit, _deadline, acc), do: acc

  defp collect(reader, remaining, credit, deadline, acc) do
    assert {:more, piece, _next} = read(reader, credit, 100, deadline)
    assert byte_size(piece) > 0 and byte_size(piece) <= min(remaining, credit)
    collect(reader, remaining - byte_size(piece), credit, deadline, acc <> piece)
  end

  defp collect_to_eof(reader, credit, deadline, acc, cap \\ 16_384) do
    assert {kind, piece, next} = read(reader, credit, 100, deadline)
    assert kind in [:more, :ok]
    assert byte_size(piece) <= min(credit, cap)

    if kind == :ok do
      {acc <> piece, next}
    else
      assert byte_size(piece) > 0
      collect_to_eof(reader, credit, deadline, acc <> piece, cap)
    end
  end

  defp connect(transport, framing, length, dir, limits \\ []) do
    tls =
      if transport == :tls do
        script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
        assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)

        [
          transport: :tls,
          tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
        ]
      else
        []
      end

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        [endpoint: {Endpoint, self()}, http_limits: Map.new([request_timeout: 5_000] ++ limits)] ++
          tls
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local

    {:ok, socket} =
      if transport == :tls do
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
          @timeout
        )
      else
        :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
      end

    on_exit(fn -> close(transport, socket) end)

    framing_header =
      if framing == :chunked, do: "Transfer-Encoding: chunked", else: "Content-Length: #{length}"

    :ok =
      send_bytes(
        transport,
        socket,
        "POST /upload HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n#{framing_header}\r\n\r\n"
      )

    assert_receive {:upload_ready, reader, deadline}, @timeout
    {server, socket, reader, deadline}
  end

  defp finish_request(server, socket, reader, monitor, transport) do
    send(reader, :respond)
    response = receive_all(transport, socket, "")
    assert response =~ "HTTP/1.1 200 OK\r\n"
    assert String.ends_with?(response, "\r\n\r\ncomplete")
    assert_receive {:DOWN, ^monitor, :process, ^reader, {:shutdown, :local_closed}}, @timeout
    assert_idle(server, Lifecycle.deadline(@timeout))
  end

  defp assert_idle(server, deadline) do
    case Gaoxy.status(server, :http) do
      %{active: 0, retained_bytes: 0} ->
        :ok

      status ->
        assert Lifecycle.remaining(deadline) > 0, "upload cleanup incomplete: #{inspect(status)}"
        assert_idle(server, deadline)
    end
  end

  defp receive_all(transport, socket, acc) do
    case recv(transport, socket) do
      {:ok, bytes} -> receive_all(transport, socket, acc <> bytes)
      {:error, :closed} -> acc
      other -> flunk("response did not finish: #{inspect(other)}")
    end
  end

  defp send_bytes(:tcp, socket, bytes), do: :gen_tcp.send(socket, bytes)
  defp send_bytes(:tls, socket, bytes), do: :ssl.send(socket, bytes)
  defp recv(:tcp, socket), do: :gen_tcp.recv(socket, 0, @timeout)
  defp recv(:tls, socket), do: :ssl.recv(socket, 0, @timeout)
  defp close(:tcp, socket), do: :gen_tcp.close(socket)
  defp close(:tls, socket), do: :ssl.close(socket)
end
