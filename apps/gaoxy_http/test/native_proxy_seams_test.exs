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
    def send(owner, bytes) do
      Kernel.send(owner, {:failed_write, IO.iodata_to_binary(bytes)})
      {:error, :closed}
    end

    def recv(_, _, _), do: {:error, :closed}
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
    assert {:ok, wire} = :gen_tcp.recv(client, 0, 100)
    assert String.ends_with?(wire, "2\r\nhi\r\n0\r\nx-two: a\r\nx-one: b\r\nx-two: c\r\n\r\n")
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

  defp exchange(framing, buffer, options \\ []) do
    {:ok, spec} =
      Gaoxy.HTTP.service_spec(endpoint: {Endpoint, fn exchange -> {:ok, exchange} end})

    {:ok, gate} =
      Gaoxy.Admission.start_link({spec.limits, %{instance: make_ref(), service: :test}})

    on_exit(fn -> if Process.alive?(gate), do: GenServer.stop(gate) end)
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
      struct!(ThousandIsland.Socket,
        socket: raw,
        transport_module: ThousandIsland.Transports.TCP,
        read_timeout: 1000,
        handshake_timeout: 1000,
        silent_terminate_on_error: false,
        span: ThousandIsland.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    {:ok, request, ""} =
      Parser.parse_head(
        "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n",
        spec.handler_options.http_limits
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
