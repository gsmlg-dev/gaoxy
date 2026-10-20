defmodule Gaoxy.HTTP.NativeProxySeamsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.HTTP.HTTP1.{Parser, Response}

  defmodule Endpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(fun), do: {:ok, fun}
    def call(exchange, fun), do: fun.(exchange)
  end

  defmodule FailedTransport do
    def setopts(_owner, send_timeout: timeout, send_timeout_close: true)
        when is_integer(timeout) and timeout > 0,
        do: :ok

    def send(owner, bytes) do
      Kernel.send(owner, {:failed_write, IO.iodata_to_binary(bytes)})
      {:error, :closed}
    end

    def recv(_, _, _), do: {:error, :closed}
  end

  defmodule ObservedTCP do
    def recv({socket, gate, owner}, length, timeout) do
      send(owner, {:poll_recv_charge, Gaoxy.Admission.status(gate).retained_bytes})
      :gen_tcp.recv(socket, length, timeout)
    end
  end

  test "step retains fragmented chunk-size and trailers across pending waits" do
    {exchange, client} = exchange(:chunked, "2\r")
    assert {:pending, next} = Exchange.read_body_step(exchange, 2, 5)
    assert next.buffer == "2\r"
    assert next.body.phase == :chunk_size
    assert next.deadline == exchange.deadline

    :ok = :gen_tcp.send(client, "\nab\r\n0\r\nx-one: first\r\nx-two: sec")
    assert {:more, "ab", next} = Exchange.read_body_step(next, 2, 100)
    next = read_until_partial_trailer(next)
    assert next.body.phase == :trailers
    assert next.body.trailers == [{"x-one", "first"}]
    assert next.buffer == "x-two: sec"
    :ok = :gen_tcp.send(client, "ond\r\n\r\n")
    assert {:ok, "", next} = Exchange.read_body_step(next, 2, 100)
    assert next.body.trailers == [{"x-one", "first"}, {"x-two", "second"}]
    assert next.body.phase == :done
    assert next.deadline == exchange.deadline
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "failed Continue is not sent again when the error exchange is reused" do
    {exchange, _} = exchange({:length, 1}, "", expect: true)
    socket = %{exchange.socket | socket: self(), transport_module: FailedTransport}
    assert {:error, :closed, next} = Exchange.read_body_step(%{exchange | socket: socket}, 1, 100)
    assert next.expect_sent
    assert_receive {:failed_write, "HTTP/1.1 100 Continue\r\n\r\n"}
    assert {:error, :closed, _} = Exchange.read_body_step(next, 1, 100)
    refute_received {:failed_write, _}
  end

  test "pending and socket errors retain expect state without duplicate Continue" do
    {exchange, client} = exchange({:length, 2}, "", expect: true)
    assert {:pending, next} = Exchange.read_body_step(exchange, 1, 5)
    assert next.expect_sent
    assert {:ok, "HTTP/1.1 100 Continue\r\n\r\n"} = :gen_tcp.recv(client, 0, 100)
    assert {:pending, next} = Exchange.read_body_step(next, 1, 0)
    assert {:error, :timeout} = :gen_tcp.recv(client, 0, 5)
    :ok = :gen_tcp.send(client, "a")
    assert {:more, "a", next} = Exchange.read_body_step(next, 1, 100)
    :ok = :gen_tcp.close(client)
    assert {:error, :closed, failed} = Exchange.read_body_step(next, 1, 100)
    assert failed.body == next.body
    assert failed.buffer == ""
    assert failed.expect_sent
    assert Gaoxy.Admission.status(failed.gate).retained_bytes == Exchange.retained_bytes(failed)
  end

  test "step validates arguments and caps wait at the original request deadline" do
    {exchange, _} = exchange({:length, 1}, "")

    for credit <- [0, -1, :infinity] do
      assert {:error, :invalid_read_length, ^exchange} =
               Exchange.read_body_step(exchange, credit, 1)
    end

    for wait <- [-1, :infinity, 1.5] do
      assert {:error, :invalid_read_timeout, ^exchange} =
               Exchange.read_body_step(exchange, 1, wait)
    end

    exchange = %{exchange | deadline: Gaoxy.Lifecycle.deadline(10)}
    started = System.monotonic_time(:millisecond)
    assert {:error, :timeout, next} = Exchange.read_body_step(exchange, 1, 500)
    assert System.monotonic_time(:millisecond) - started < 250
    assert next.deadline == exchange.deadline
    assert {:error, :timeout, ^next} = Exchange.read_body_step(next, 1, 500)
  end

  test "parser and admission errors retain decoder and buffered input" do
    {exchange, _} = exchange(:chunked, "z\r\n")

    assert {:error, {:request_error, 400, :chunk_size}, next} =
             Exchange.read_body_step(exchange, 2, 1)

    assert next.buffer == "z\r\n"
    assert next.body == exchange.body
    assert_raise Gaoxy.HTTP.RequestError, fn -> Exchange.read_body(exchange, 2, 1) end
    exchange = %{exchange | buffer: "2\r", limits: %{exchange.limits | max_buffer_bytes: 2}}
    assert {:error, :buffer_limit, next} = Exchange.read_body_step(exchange, 2, 100)
    assert next.buffer == "2\r"
    assert next.body.phase == :chunk_size
  end

  test "parser error preserves successful metadata transitions from the same input buffer" do
    {exchange, _} = exchange(:chunked, "0\r\nx-one: first\r\nconnection: close\r\n\r\n")

    assert {:error, {:request_error, 400, :forbidden_trailer}, next} =
             Exchange.read_body_step(exchange, 2, 100)

    assert next.body.phase == :trailers
    assert next.body.trailers == [{"x-one", "first"}]
    assert next.buffer == "connection: close\r\n\r\n"
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "blocking body reader preserves Plug timeout and argument errors" do
    {exchange, _} = exchange({:length, 1}, "")
    assert {:error, :timeout} = Exchange.read_body(exchange, 1, 5)
    assert {:error, :invalid_read_length} = Exchange.read_body(exchange, 0, 5)
    assert {:error, :invalid_read_timeout} = Exchange.read_body(exchange, 1, 0)
  end

  test "finish emits ordered duplicate trailers and exactly one terminator" do
    {exchange, client} = exchange(:none, "")
    assert {:ok, next} = Response.send_chunked(exchange, 200, [{"trailer", "x-one, x-two"}])
    assert :ok = Response.chunk(next, "hi")
    assert {:ok, next} = Response.finish(next, [{"x-two", "a"}, {"x-one", "b"}, {"x-two", "c"}])
    assert next.response == :sent
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
    assert {:ok, ^next} = Response.finish(next)

    expected =
      "HTTP/1.1 200 OK\r\ntransfer-encoding: chunked\r\ntrailer: x-one, x-two\r\n\r\n" <>
        "2\r\nhi\r\n0\r\nx-two: a\r\nx-one: b\r\nx-two: c\r\n\r\n"

    assert {:ok, ^expected} = :gen_tcp.recv(client, byte_size(expected), 100)
    assert {:error, :timeout} = :gen_tcp.recv(client, 0, 5)
  end

  test "finish validates prohibited, malformed, undeclared, and bounded trailers before writing" do
    {exchange, client} = exchange(:none, "")
    assert {:ok, next} = Response.send_chunked(exchange, 200, [{"trailer", "x-one"}])
    assert {:ok, _head} = :gen_tcp.recv(client, 0, 100)

    for trailers <- [
          [{"content-length", "1"}],
          [{"x-other", "a"}],
          [{"x-one", "a\r\nb"}],
          [{"X-One", "a"}],
          :invalid
        ] do
      assert {:error, _} = Response.finish(next, trailers)
    end

    assert {:error, :response_trailer_limit} =
             Response.finish(%{next | limits: %{next.limits | max_trailer_bytes: 5}}, [
               {"x-one", "a"}
             ])

    assert {:error, :response_trailer_limit} =
             Response.finish(%{next | limits: %{next.limits | max_trailers: 1}}, [
               {"x-one", "a"},
               {"x-one", "b"}
             ])

    assert {:error, :timeout} = :gen_tcp.recv(client, 0, 5)
  end

  test "invalid trailer declarations fail before a head is committed" do
    {exchange, client} = exchange(:none, "")

    for declaration <- ["content-length", "x-one,", "x one", "connection"] do
      assert {:error, :invalid_response_trailers} =
               Response.send_chunked(exchange, 200, [{"trailer", declaration}])
    end

    assert {:error, :invalid_response_trailers} =
             Response.send_chunked(exchange, 200, [{"content-length", "0"}, {"trailer", "x-one"}])

    assert {:error, :invalid_response_trailers} =
             Response.send_chunked(exchange, 200, [
               {"connection", "x-hop, close"},
               {"trailer", "x-hop"}
             ])

    assert {:error, :timeout} = :gen_tcp.recv(client, 0, 5)
  end

  test "finish checks fixed length and completes bodyless and close streams" do
    {exchange, client} = exchange(:none, "")

    assert {:error, :content_length_mismatch} =
             Response.finish(%{exchange | response: {:fixed_stream, 1}})

    assert {:ok, %{response: :sent}} = Response.finish(%{exchange | response: {:fixed_stream, 0}})
    assert {:ok, %{response: :sent}} = Response.finish(%{exchange | response: :bodyless_stream})

    assert {:ok, %{response: :sent, close: true}} =
             Response.finish(%{exchange | response: :close_stream})

    assert {:error, :invalid_response_state} = Response.finish(exchange)

    assert {:error, :invalid_response_trailers} =
             Response.finish(%{exchange | response: :bodyless_stream}, [{"x-one", "a"}])

    assert {:error, :timeout} = :gen_tcp.recv(client, 0, 5)
  end

  test "endpoint error after committing chunked response closes without a success terminator" do
    fun = fn exchange ->
      {:ok, next} = Response.send_chunked(exchange, 200, [])
      :ok = Response.chunk(next, "x")
      {:error, :upstream_failed, next}
    end

    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Endpoint, fun})
    on_exit(fn -> Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(client) end)
    :ok = :gen_tcp.send(client, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
    wire = receive_all(client, "")
    assert String.ends_with?(wire, "1\r\nx\r\n")
    refute wire =~ "0\r\n\r\n"
    refute wire =~ "500 Internal Server Error"
  end

  for buffer <- ["", "GET /next"] do
    @poll_buffer buffer
    test "repeated empty polls retain the complete copy floor for #{inspect(buffer)}" do
      {exchange, _client} = exchange(:none, @poll_buffer)
      base = Exchange.retained_bytes(exchange) - byte_size(exchange.buffer)
      expected = base + 2 * byte_size(exchange.buffer) + 2

      :ok =
        Gaoxy.Admission.update(exchange.gate, exchange.lease, Exchange.retained_bytes(exchange))

      trace_updates(exchange.gate)

      next =
        Enum.reduce(1..5, exchange, fn _, current ->
          assert {:pending, next} = Exchange.poll_connection(current, 0)
          assert next.buffer == exchange.buffer
          assert next.body == exchange.body
          assert next.deadline == exchange.deadline
          next
        end)

      updates = traced_updates(exchange.gate, exchange.lease)
      assert length(updates) >= 5
      assert Enum.uniq(updates) == [expected]
      assert Gaoxy.Admission.status(next.gate).retained_bytes == expected
      assert Exchange.retained_bytes(next) == expected
    end
  end

  test "poll copy peak is admitted before recv and returned charge fits the exact cap" do
    buffer = :binary.copy("p", 64)
    {exchange, client} = exchange(:none, buffer, byte_credit: 66)
    base = Exchange.retained_bytes(exchange) - byte_size(buffer)
    expected = base + 130
    :ok = Gaoxy.Admission.update(exchange.gate, exchange.lease, Exchange.retained_bytes(exchange))
    observed = observe_recv(exchange)
    :ok = :gen_tcp.send(client, "zy")

    assert {:more, next} = Exchange.poll_connection(observed, 100)
    assert_receive {:poll_recv_charge, ^expected}
    assert next.buffer == buffer <> "z"
    assert next.body == exchange.body
    assert next.deadline == exchange.deadline
    assert Exchange.retained_bytes(next) == expected
    assert Gaoxy.Admission.status(next.gate).retained_bytes == expected

    assert {:error, :byte_limit, ^next} = Exchange.poll_connection(next, 100)
    refute_received {:poll_recv_charge, _}
    assert {:ok, "y"} = Hell.Socket.recv(exchange.socket, 1, 100)
    assert Gaoxy.Admission.status(next.gate).retained_bytes == expected
  end

  test "one byte short of the full poll copy peak refuses without consuming input" do
    buffer = :binary.copy("p", 64)
    {exchange, client} = exchange(:none, buffer, byte_credit: 65)
    retained = Exchange.retained_bytes(exchange)
    :ok = Gaoxy.Admission.update(exchange.gate, exchange.lease, retained)
    observed = observe_recv(exchange)
    :ok = :gen_tcp.send(client, "z")

    assert {:error, :byte_limit, ^observed} = Exchange.poll_connection(observed, 100)
    refute_received {:poll_recv_charge, _}
    assert {:ok, "z"} = Hell.Socket.recv(exchange.socket, 1, 100)
    assert Gaoxy.Admission.status(exchange.gate).retained_bytes == retained
  end

  test "maximum poll floor stays bounded and a full buffer refuses the following byte" do
    {exchange, client} = exchange(:none, "p")
    exchange = %{exchange | limits: %{exchange.limits | max_buffer_bytes: 2}}
    base = Exchange.retained_bytes(exchange) - 1
    :ok = :gen_tcp.send(client, "zy")

    assert {:more, next} = Exchange.poll_connection(exchange, 100)
    assert next.buffer == "pz"
    assert Exchange.retained_bytes(next) == base + 2 * next.limits.max_buffer_bytes
    assert {:error, :buffer_limit, ^next} = Exchange.poll_connection(next, 100)
    assert {:ok, "y"} = Hell.Socket.recv(exchange.socket, 1, 100)
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "poll floor survives deadline and peer close without renewing the request" do
    {exchange, _client} = exchange(:none, "")
    exchange = %{exchange | deadline: Gaoxy.Lifecycle.deadline(100)}
    base = Exchange.retained_bytes(exchange)
    started = System.monotonic_time(:millisecond)

    assert {:error, :timeout, expired} = Exchange.poll_connection(exchange, 500)
    assert System.monotonic_time(:millisecond) - started < 350
    assert expired.deadline == exchange.deadline
    assert expired.buffer == exchange.buffer
    assert expired.body == exchange.body
    assert Exchange.retained_bytes(expired) == base + 2
    assert {:error, :timeout, ^expired} = Exchange.poll_connection(expired, 0)
    assert Gaoxy.Admission.status(expired.gate).retained_bytes == base + 2

    {exchange, client} = exchange(:none, "GET /")
    base = Exchange.retained_bytes(exchange) - byte_size(exchange.buffer)
    assert {:pending, next} = Exchange.poll_connection(exchange, 0)
    :ok = :gen_tcp.close(client)
    assert {:error, :closed, closed} = Exchange.poll_connection(next, 100)
    assert closed.buffer == exchange.buffer
    assert closed.body == exchange.body
    assert closed.deadline == exchange.deadline
    assert Exchange.retained_bytes(closed) == base + 2 * byte_size(exchange.buffer) + 2
    assert Gaoxy.Admission.status(closed.gate).retained_bytes == Exchange.retained_bytes(closed)
  end

  test "a retained poll floor still validates the gate and lease before every recv" do
    {exchange, client} = exchange(:none, "")
    assert {:pending, next} = Exchange.poll_connection(exchange, 0)
    observed = observe_recv(%{next | lease: make_ref()})
    :ok = :gen_tcp.send(client, "zy")

    assert {:error, :stale_generation, ^observed} = Exchange.poll_connection(observed, 100)
    refute_received {:poll_recv_charge, _}
    assert {:ok, "z"} = Hell.Socket.recv(exchange.socket, 1, 100)

    {:ok, spec} =
      Gaoxy.HTTP.service_spec(endpoint: {Endpoint, fn exchange -> {:ok, exchange} end})

    {:ok, dead_gate} =
      Gaoxy.Admission.start_link({spec.limits, %{instance: make_ref(), service: :test}})

    :ok = GenServer.stop(dead_gate)
    next = %{next | gate: dead_gate}
    assert {:noproc, _} = catch_exit(Exchange.poll_connection(observe_recv(next), 100))
    refute_received {:poll_recv_charge, _}
    assert {:ok, "y"} = Hell.Socket.recv(exchange.socket, 1, 100)
  end

  test "body consumption and response writes preserve the admitted poll floor" do
    {exchange, client} = exchange({:length, 2}, "ab")
    base = Exchange.retained_bytes(exchange) - 2
    floor = base + 6
    assert {:pending, next} = Exchange.poll_connection(exchange, 0)
    trace_updates(next.gate)

    assert {:ok, "ab", next} = Exchange.read_body_step(next, 2, 100)
    assert next.buffer == ""
    assert next.body.phase == :done
    assert Exchange.retained_bytes(next) == floor
    assert Gaoxy.Admission.status(next.gate).retained_bytes == floor
    assert :ok = Exchange.send_bytes(next, "x")
    assert {:ok, "x"} = :gen_tcp.recv(client, 1, 100)
    assert {:ok, next} = Response.send_chunked(next, 200, [])
    assert {:ok, next} = Response.finish(next)
    assert Exchange.retained_bytes(next) == floor
    assert Gaoxy.Admission.status(next.gate).retained_bytes == floor

    updates = traced_updates(next.gate, next.lease)
    assert (floor + 2) in updates
    assert (floor + 1) in updates
    assert Enum.all?(updates, &(&1 >= floor))
  end

  test "native keepalive reuse releases the prior poll floor and admits a fresh request" do
    owner = self()

    fun = fn exchange ->
      send(owner, {:reuse_ready, self(), exchange})

      receive do
        :poll_and_respond ->
          {:pending, next} = Exchange.poll_connection(exchange, 0)
          send(owner, {:reuse_polled, self(), next, Gaoxy.Admission.status(next.gate)})

          case Response.send_resp(next, 200, [], "ok") do
            {:ok, response} -> {:ok, response}
            {:error, reason} -> {:error, reason, next}
          end
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end

    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Endpoint, fun})
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    on_exit(fn -> :gen_tcp.close(client) end)
    request = "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n"
    :ok = :gen_tcp.send(client, request)
    assert_receive {:reuse_ready, reader, first}, 1000
    monitor = Process.monitor(reader)
    first_base = Exchange.retained_bytes(first)
    send(reader, :poll_and_respond)
    assert_receive {:reuse_polled, ^reader, first_polled, first_status}, 1000
    assert first_polled.buffer == ""
    assert Exchange.retained_bytes(first_polled) == first_base + 2
    assert first_status.retained_bytes == first_base + 2
    response = receive_reuse_response(client)
    assert response =~ "HTTP/1.1 200 OK\r\n"
    assert String.ends_with?(response, "\r\n\r\nok")
    await_status(server, &(&1.active == 1 and &1.retained_bytes == 0))

    :ok = :gen_tcp.send(client, request)
    assert_receive {:reuse_ready, ^reader, second}, 1000
    assert second.lease == first.lease
    assert second.buffer == ""
    assert Map.get(second, :poll_buffer_bytes) == 0
    assert Exchange.retained_bytes(second) == first_base
    send(reader, :poll_and_respond)
    assert_receive {:reuse_polled, ^reader, second_polled, second_status}, 1000
    assert Exchange.retained_bytes(second_polled) == first_base + 2
    assert second_status.retained_bytes == first_base + 2
    response = receive_reuse_response(client)
    assert response =~ "HTTP/1.1 200 OK\r\n"
    assert String.ends_with?(response, "\r\n\r\nok")
    await_status(server, &(&1.active == 1 and &1.retained_bytes == 0))
    :ok = :gen_tcp.close(client)
    assert_receive {:DOWN, ^monitor, :process, ^reader, _}, 1000
    await_status(server, &(&1.active == 0 and &1.retained_bytes == 0))
  end

  defp exchange(framing, buffer, options \\ []) do
    {:ok, spec} =
      Gaoxy.HTTP.service_spec(endpoint: {Endpoint, fn exchange -> {:ok, exchange} end})

    {:ok, request, ""} =
      Parser.parse_head(
        "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n",
        spec.handler_options.http_limits
      )

    limits =
      if is_integer(options[:byte_credit]) do
        %{
          spec.limits
          | max_bytes: 2 * request.head_bytes + byte_size(buffer) + options[:byte_credit]
        }
      else
        spec.limits
      end

    gate =
      start_supervised!(
        {Gaoxy.Admission, {limits, %{instance: make_ref(), service: :test}}},
        id: make_ref()
      )

    {:ok, lease} = Gaoxy.Admission.acquire(gate, 0)
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(listener)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    {:ok, raw} = :gen_tcp.accept(listener, 1000)
    :gen_tcp.close(listener)

    on_exit(fn ->
      :gen_tcp.close(client)
      :gen_tcp.close(raw)
    end)

    socket =
      struct!(Hell.Socket,
        socket: raw,
        transport_module: Hell.Transports.TCP,
        read_timeout: 1000,
        handshake_timeout: 1000,
        silent_terminate_on_error: false,
        span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    request = %{request | body: framing, expect_continue: options[:expect] || false}

    exchange =
      Exchange.new(
        request,
        socket,
        gate,
        lease,
        Gaoxy.Lifecycle.deadline(1000),
        Map.put(spec.handler_options.http_limits, :max_write_chunk, 1024),
        buffer
      )

    {exchange, client}
  end

  defp observe_recv(exchange) do
    socket = %{
      exchange.socket
      | socket: {exchange.socket.socket, exchange.gate, self()},
        transport_module: ObservedTCP
    }

    %{exchange | socket: socket}
  end

  defp trace_updates(gate) do
    assert :erlang.trace(gate, true, [:receive, {:tracer, self()}]) == 1

    on_exit(fn ->
      if Process.alive?(gate), do: :erlang.trace(gate, false, [:receive])
    end)
  end

  defp traced_updates(gate, lease) do
    fence = :erlang.trace_delivered(gate)
    assert_receive {:trace_delivered, ^gate, ^fence}, 1000
    collect_updates(gate, lease, [])
  end

  defp collect_updates(gate, lease, acc) do
    receive do
      {:trace, ^gate, :receive, {:"$gen_call", _from, {:update, ^lease, bytes}}} ->
        collect_updates(gate, lease, [bytes | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp await_status(server, predicate, deadline \\ Gaoxy.Lifecycle.deadline(1000)) do
    status = Gaoxy.status(server, :http)

    unless predicate.(status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0,
             "native reuse did not settle: #{inspect(status)}"

      await_status(server, predicate, deadline)
    end
  end

  defp receive_reuse_response(socket, acc \\ "", deadline \\ Gaoxy.Lifecycle.deadline(1000)) do
    if String.ends_with?(acc, "\r\n\r\nok") do
      acc
    else
      remaining = Gaoxy.Lifecycle.remaining(deadline)
      assert remaining > 0, "native reuse response did not finish: #{inspect(acc)}"
      assert {:ok, bytes} = :gen_tcp.recv(socket, 0, remaining)
      receive_reuse_response(socket, acc <> bytes, deadline)
    end
  end

  defp receive_all(socket, acc) do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, bytes} -> receive_all(socket, acc <> bytes)
      {:error, :closed} -> acc
    end
  end

  defp read_until_partial_trailer(exchange) do
    assert {:pending, next} = Exchange.read_body_step(exchange, 2, 5)

    if next.body.phase == :trailers and next.buffer == "x-two: sec",
      do: next,
      else: read_until_partial_trailer(next)
  end
end
