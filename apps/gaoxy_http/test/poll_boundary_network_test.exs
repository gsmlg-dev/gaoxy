defmodule Gaoxy.HTTP.PollBoundaryNetworkTest do
  use ExUnit.Case, async: true

  @limit 65_536
  @timeout 15_000

  defmodule WaitingPlug do
    def init(owner), do: owner

    def call(conn, owner) do
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      if conn.request_path == "/wait" do
        send(owner, {:ready, self(), body})

        receive do
          :observe -> poll(conn, owner, 0)
        after
          10_000 -> raise "poll command timeout"
        end
      else
        Plug.Conn.send_resp(conn, 200, "health:#{byte_size(body)}")
      end
    end

    defp poll(conn, owner, count) do
      case Gaoxy.HTTP.poll_connection(conn, 0) do
        {:more, next} ->
          poll(next, owner, count + 1)

        {:pending, next} ->
          send(owner, {:idle, self(), count})

          receive do
            :observe -> poll(next, owner, count)
            :finish -> Plug.Conn.send_resp(next, 200, "ready")
          after
            10_000 -> raise "poll resume timeout"
          end

        {:error, reason, next} ->
          send(owner, {:poll_error, self(), count, reason})
          {:ok, next} = Gaoxy.HTTP.abort(next)
          next
      end
    end
  end

  for arrival <- [:after_body, :coalesced] do
    @arrival arrival
    @tag timeout: 30_000
    test "exact 65536-byte pipeline completes both responses with #{@arrival} input" do
      {socket, reader, pipeline, observation} = start_wait(@arrival, @limit)
      assert byte_size(pipeline) == @limit
      send(reader, :observe)
      count = await_idle(reader, observation, Gaoxy.Lifecycle.deadline(@timeout))
      assert count <= @limit
      send(reader, :finish)

      wire = receive_responses(socket, "", Gaoxy.Lifecycle.deadline(2_000))
      assert length(:binary.matches(wire, "HTTP/1.1 200 OK\r\n")) == 2
      assert wire =~ "\r\n\r\nreadyHTTP/1.1 200 OK\r\n"
      assert String.ends_with?(wire, "health:65471")
    end

    test "actual excess rejects with bounded polling and #{@arrival} input" do
      {socket, reader, _pipeline, {server, full_charge, _}} = start_wait(@arrival, 256, "z")
      started = System.monotonic_time(:millisecond)
      send(reader, :observe)
      {count, reason} = await_error(reader, Gaoxy.Lifecycle.deadline(2_000))
      assert reason == :buffer_limit
      assert count <= 256
      assert System.monotonic_time(:millisecond) - started < 2_000
      assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
      assert Gaoxy.status(server, :http).retained_high_water <= full_charge + 4 * 256
    end

    test "peer closure is observable at a full buffer with #{@arrival} input" do
      {socket, reader, _pipeline, observation} = start_wait(@arrival, 256)
      send(reader, :observe)
      count = await_idle(reader, observation, Gaoxy.Lifecycle.deadline(2_000))
      :ok = :gen_tcp.close(socket)
      send(reader, :observe)
      assert {^count, :closed} = await_error(reader, Gaoxy.Lifecycle.deadline(2_000))
    end
  end

  defp start_wait(arrival, limit, excess \\ "") do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        plug: {WaitingPlug, self()},
        port: 0,
        http_limits: %{max_buffer_bytes: limit, max_read_chunk: min(limit, 16_384)}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    # The reported pipeline is 65 bytes of headers plus a 65,471-byte body.
    body_size = pipeline_body_size(limit)

    pipeline =
      "POST /health HTTP/1.1\r\nhost: localhost\r\ncontent-length: #{body_size}\r\n\r\n" <>
        :binary.copy("x", body_size)

    assert byte_size(pipeline) == limit
    first = "POST /wait HTTP/1.1\r\nhost: localhost\r\ncontent-length: 3\r\n\r\nabc"

    :ok =
      :gen_tcp.send(
        socket,
        if(arrival == :coalesced, do: first <> pipeline <> excess, else: first)
      )

    assert_receive {:ready, reader, "abc"}, 2_000
    head_charge = 2 * (byte_size(first) - 3)
    initial_buffer_bytes = Gaoxy.status(server, :http).retained_bytes - head_charge
    if arrival == :coalesced, do: assert(initial_buffer_bytes > 0)
    if arrival == :after_body, do: :ok = :gen_tcp.send(socket, pipeline <> excess)
    # Public resource accounting proves the full buffer was observed even when
    # the initial head/body read already retained some of the pipeline.
    full_charge = head_charge + 2 * limit + 2
    observation = {server, full_charge, limit - initial_buffer_bytes}
    {socket, reader, pipeline, observation}
  end

  defp pipeline_body_size(limit) do
    Enum.find((limit - 80)..limit, fn size ->
      size +
        byte_size("POST /health HTTP/1.1\r\nhost: localhost\r\ncontent-length: #{size}\r\n\r\n") ==
        limit
    end)
  end

  defp await_idle(reader, {server, full_charge, expected} = observation, deadline) do
    receive do
      {:idle, ^reader, count} ->
        retained = Gaoxy.status(server, :http).retained_bytes
        assert retained <= full_charge

        if retained == full_charge do
          assert count == expected
          count
        else
          assert Gaoxy.Lifecycle.remaining(deadline) > 0
          send(reader, :observe)
          await_idle(reader, observation, deadline)
        end

      {:poll_error, ^reader, count, reason} ->
        flunk("poll rejected valid pipeline after #{count} bytes: #{inspect(reason)}")
    after
      Gaoxy.Lifecycle.remaining(deadline) -> flunk("pipeline did not reach idle")
    end
  end

  defp await_error(reader, deadline) do
    receive do
      {:poll_error, ^reader, count, reason} ->
        {count, reason}

      {:idle, ^reader, _count} ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0
        send(reader, :observe)
        await_error(reader, deadline)
    after
      Gaoxy.Lifecycle.remaining(deadline) -> flunk("poll error was not observed")
    end
  end

  defp receive_responses(socket, wire, deadline) do
    if String.ends_with?(wire, "health:65471") do
      wire
    else
      assert {:ok, bytes} = :gen_tcp.recv(socket, 0, Gaoxy.Lifecycle.remaining(deadline))
      receive_responses(socket, wire <> bytes, deadline)
    end
  end
end
