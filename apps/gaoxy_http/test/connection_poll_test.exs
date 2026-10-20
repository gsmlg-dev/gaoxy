defmodule Gaoxy.HTTP.ConnectionPollTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.HTTP.HTTP1.Parser

  defmodule Endpoint do
    @behaviour Gaoxy.HTTP.Endpoint
    def init(options), do: {:ok, options}
    def call(exchange, _options), do: {:ok, exchange}
  end

  test "poll retains exactly one wire byte without consuming the following pipeline" do
    {exchange, client} = exchange(buffer: "P")
    :ok = :gen_tcp.send(client, "GET")

    assert {:more, next} = Exchange.poll_connection(exchange, 100)
    assert next.buffer == "PG"
    assert next.body == exchange.body
    assert next.deadline == exchange.deadline
    assert next.poll_buffer_bytes == 4
    assert Exchange.retained_bytes(next) == Exchange.retained_bytes(exchange) - 1 + 4
    assert {:ok, "ET"} = Hell.Socket.recv(next.socket, 2, 100)
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "a zero wait polls available bytes without a blocking read" do
    {exchange, client} = exchange()
    :ok = :gen_tcp.send(client, "x")
    assert {:more, next} = poll_ready(exchange, Gaoxy.Lifecycle.deadline(500))
    assert next.buffer == "x"
    assert next.poll_buffer_bytes == 2
    assert {:pending, pending} = Exchange.poll_connection(next, 0)
    assert pending.buffer == next.buffer
    assert pending.body == exchange.body
    assert pending.deadline == exchange.deadline
    assert pending.poll_buffer_bytes == 4
    assert {:pending, ^pending} = Exchange.poll_connection(pending, 0)
    assert Gaoxy.Admission.status(pending.gate).retained_bytes == Exchange.retained_bytes(pending)
  end

  test "pending preserves buffered pipeline and retains the admitted poll floor" do
    {exchange, _client} = exchange(buffer: "GET /next")
    assert {:pending, next} = Exchange.poll_connection(exchange, 5)
    assert next.buffer == exchange.buffer
    assert next.body == exchange.body
    assert next.deadline == exchange.deadline
    assert next.poll_buffer_bytes == 2 * byte_size(exchange.buffer) + 2

    assert Exchange.retained_bytes(next) ==
             Exchange.retained_bytes(exchange) - byte_size(exchange.buffer) +
               next.poll_buffer_bytes

    assert {:pending, ^next} = Exchange.poll_connection(next, 0)
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "a finite poll cannot extend the original request deadline" do
    {exchange, _client} = exchange()
    exchange = %{exchange | deadline: Gaoxy.Lifecycle.deadline(10)}
    started = System.monotonic_time(:millisecond)

    assert {:error, :timeout, next} = Exchange.poll_connection(exchange, 500)
    assert System.monotonic_time(:millisecond) - started < 250
    assert next.buffer == exchange.buffer
    assert next.body == exchange.body
    assert next.deadline == exchange.deadline
    assert next.poll_buffer_bytes == 2
    assert Exchange.retained_bytes(next) == Exchange.retained_bytes(exchange) + 2
    assert {:error, :timeout, ^next} = Exchange.poll_connection(next, 0)

    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "full pipeline buffer rejects before taking another wire byte" do
    {exchange, client} = exchange(buffer: "ab")
    exchange = %{exchange | limits: %{exchange.limits | max_buffer_bytes: 2}}
    :ok = :gen_tcp.send(client, "z")

    assert {:error, :buffer_limit, ^exchange} = Exchange.poll_connection(exchange, 100)
    assert exchange.poll_buffer_bytes == 0
    assert {:ok, "z"} = Hell.Socket.recv(exchange.socket, 1, 100)

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes ==
             Exchange.retained_bytes(exchange)
  end

  test "admission denies a read before consuming unreserved input" do
    {exchange, client} = exchange(no_credit: true)
    :ok = :gen_tcp.send(client, "z")

    assert {:error, :byte_limit, ^exchange} = Exchange.poll_connection(exchange, 100)
    assert exchange.poll_buffer_bytes == 0
    assert {:ok, "z"} = Hell.Socket.recv(exchange.socket, 1, 100)

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes ==
             Exchange.retained_bytes(exchange)
  end

  test "buffer-copy admission denies polling before consuming a byte that alone would fit" do
    {exchange, client} = exchange(buffer: :binary.copy("p", 64), credit: 1)
    :ok = :gen_tcp.send(client, "z")

    assert {:error, :byte_limit, ^exchange} = Exchange.poll_connection(exchange, 100)
    assert exchange.poll_buffer_bytes == 0
    assert {:ok, "z"} = Hell.Socket.recv(exchange.socket, 1, 100)

    assert Gaoxy.Admission.status(exchange.gate).retained_bytes ==
             Exchange.retained_bytes(exchange)
  end

  test "peer close is detected after body EOF without losing pipeline state" do
    {exchange, client} = exchange(buffer: "GET /")
    assert exchange.body.phase == :done
    :ok = :gen_tcp.close(client)

    assert {:error, :closed, next} = Exchange.poll_connection(exchange, 100)
    assert next.buffer == exchange.buffer
    assert next.body == exchange.body
    assert next.deadline == exchange.deadline
    assert next.poll_buffer_bytes == 2 * byte_size(exchange.buffer) + 2

    assert Exchange.retained_bytes(next) ==
             Exchange.retained_bytes(exchange) - byte_size(exchange.buffer) +
               next.poll_buffer_bytes

    assert {:error, :enotconn, ^next} = Exchange.poll_connection(next, 0)
    assert Gaoxy.Admission.status(next.gate).retained_bytes == Exchange.retained_bytes(next)
  end

  test "invalid waits preserve state and do not consume socket bytes" do
    {exchange, client} = exchange()
    :ok = :gen_tcp.send(client, "z")

    for wait <- [-1, :infinity, 1.5] do
      assert {:error, :invalid_read_timeout, ^exchange} = Exchange.poll_connection(exchange, wait)
    end

    assert exchange.poll_buffer_bytes == 0
    assert {:ok, "z"} = Hell.Socket.recv(exchange.socket, 1, 100)
  end

  defp poll_ready(exchange, deadline) do
    case Exchange.poll_connection(exchange, 0) do
      {:pending, next} ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0
        poll_ready(next, deadline)

      result ->
        result
    end
  end

  defp exchange(options \\ []) do
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})

    {:ok, request, ""} =
      Parser.parse_head(
        "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n",
        spec.handler_options.http_limits
      )

    buffer = Keyword.get(options, :buffer, "")
    retained = 2 * request.head_bytes + byte_size(buffer)

    limits =
      cond do
        options[:no_credit] -> %{spec.limits | max_bytes: retained}
        is_integer(options[:credit]) -> %{spec.limits | max_bytes: retained + options[:credit]}
        true -> spec.limits
      end

    gate =
      start_supervised!(
        {Gaoxy.Admission, {limits, %{instance: make_ref(), service: :test}}},
        id: make_ref()
      )

    {:ok, lease} = Gaoxy.Admission.acquire(gate, retained)

    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(listener)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1000)
    {:ok, raw} = :gen_tcp.accept(listener, 1000)
    :ok = :gen_tcp.close(listener)

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

    exchange =
      Exchange.new(
        request,
        socket,
        gate,
        lease,
        Gaoxy.Lifecycle.deadline(1000),
        spec.handler_options.http_limits,
        buffer
      )

    {exchange, client}
  end
end
