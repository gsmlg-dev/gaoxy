defmodule Gaoxy.HTTP2PreSettingsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.{HTTP, Lifecycle}
  alias Gaoxy.HTTP.HTTP2.Frame
  @window 16_384
  @timeout 5_000

  defmodule Endpoint do
    alias Gaoxy.HTTP.{Exchange, Response}
    alias Gaoxy.Lifecycle

    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      if exchange.request.path == "/sibling" do
        Response.send_resp(exchange, 200, [], "sibling")
      else
        send(owner, {:window_held, self(), exchange.transport_state})

        receive do
          :release -> echo(exchange, "")
        after
          Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
        end
      end
    end

    defp echo(exchange, body) do
      case Exchange.read_body_step(exchange, 16_384, Lifecycle.remaining(exchange.deadline)) do
        {:more, bytes, next} -> echo(next, body <> bytes)
        {:ok, bytes, next} -> Response.send_resp(next, 200, [], body <> bytes)
        {:error, reason, next} -> {:error, reason, next}
        {:pending, next} -> {:error, :timeout, next}
      end
    end
  end

  setup do
    deadline = Lifecycle.deadline(@timeout)

    {:ok, server} =
      HTTP.start_link(
        ip: {127, 0, 0, 1},
        port: 0,
        endpoint: {Endpoint, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{request_timeout: @timeout, write_timeout: @timeout},
        h2_limits: %{receive_window: @window, frame_timeout: @timeout}
      )

    {:ok, {ip, port}} = Gaoxy.info(server, :http).local

    [listener] =
      Enum.filter(:erlang.ports(), fn socket -> :inet.sockname(socket) == {:ok, {ip, port}} end)

    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], remaining(deadline))

    on_exit(fn ->
      :gen_tcp.close(socket)
      if Process.alive?(server), do: Gaoxy.stop(server, @timeout)
    end)

    :ok =
      :gen_tcp.send(socket, [
        "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
        Frame.encode(4, 0, 0, "")
      ])

    {4, 0, 0, settings} = recv_frame(socket, deadline)
    assert {4, @window} in for(<<id::16, value::32 <- settings>>, do: {id, value})
    assert {4, 1, 0, ""} = recv_frame(socket, deadline)
    {:ok, socket: socket, server: server, port: port, listener: listener, deadline: deadline}
  end

  test "two full DATA frames use the standard initial window before SETTINGS ACK", context do
    before_ack_echo(context, 2)
  end

  test "three full DATA frames use the standard initial window before SETTINGS ACK", context do
    before_ack_echo(context, 3)
  end

  test "empty DATA FIN remains legal when SETTINGS ACK makes the queued window negative",
       context do
    %{socket: socket, deadline: deadline} = context
    payload = :binary.copy(<<3>>, 3 * @window)
    worker = hold(socket, byte_size(payload), deadline)
    send_data(socket, payload, false)
    ping(socket, "queued03", deadline)

    :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
    ping(socket, "acked003", deadline)
    :ok = :gen_tcp.send(socket, Frame.encode(0, 1, 1, ""))
    ping(socket, "emptyfin", deadline)
    send(worker, :release)
    assert_echo_and_cleanup(context, payload)
  end

  test "duplicate SETTINGS ACK does not subtract the configured window twice", context do
    %{socket: socket, deadline: deadline} = context
    payload = :binary.copy(<<4>>, 2 * @window)
    worker = hold(socket, byte_size(payload), deadline)
    send_data(socket, binary_part(payload, 0, @window), false)
    ping(socket, "queued01", deadline)

    :ok =
      :gen_tcp.send(socket, [Frame.encode(4, 1, 0, ""), Frame.encode(4, 1, 0, "")])

    ping(socket, "acked002", deadline)
    send(worker, :release)
    # The next body read returns credit for the first delivered DATA frame.
    # Another full frame must fit exactly; a second ACK adjustment would reset it.
    assert_window_update(socket, deadline)
    send_data(socket, binary_part(payload, @window, @window), true)
    assert_echo_and_cleanup(context, payload)
  end

  test "SETTINGS ACK applies the selected window to an already open stream", context do
    %{socket: socket, deadline: deadline} = context
    worker = hold(socket, @window + 1, deadline)
    :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
    ping(socket, "existing", deadline)
    assert_oversend_and_cleanup(context, worker)
  end

  test "a stream opened after SETTINGS ACK enforces the selected window", context do
    %{socket: socket, deadline: deadline} = context
    :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
    ping(socket, "newacked", deadline)
    worker = hold(socket, @window + 1, deadline)
    assert_oversend_and_cleanup(context, worker)
  end

  defp before_ack_echo(%{socket: socket, deadline: deadline} = context, count) do
    payload = :binary.copy(<<count>>, count * @window)
    worker = hold(socket, byte_size(payload), deadline)
    send_data(socket, payload, true)
    # The endpoint has not read: no WINDOW_UPDATE can replenish the initial 65_535.
    ping(socket, "before00", deadline)
    :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
    ping(socket, "afterack", deadline)
    send(worker, :release)
    assert_echo_and_cleanup(context, payload)
  end

  defp hold(socket, length, deadline) do
    send_headers(socket, 1, "/echo", false, [{"content-length", Integer.to_string(length)}])
    assert_receive {:window_held, worker, {_owner, 1, _token}}, remaining(deadline)
    worker
  end

  defp send_headers(socket, id, path, ended, extra \\ []) do
    fields = [
      {":method", if(path == "/echo", do: "POST", else: "GET")},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", path}
    ]

    {block, _} = HPAX.encode(:never_store, fields ++ extra, HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
  end

  defp send_data(socket, payload, ended) do
    frames =
      for offset <- 0..div(byte_size(payload) - 1, @window) do
        start = offset * @window
        size = min(@window, byte_size(payload) - start)
        flags = if ended and start + size == byte_size(payload), do: 1, else: 0
        Frame.encode(0, flags, 1, binary_part(payload, start, size))
      end

    :ok = :gen_tcp.send(socket, frames)
  end

  defp recv_frame(socket, deadline) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} =
             :gen_tcp.recv(socket, 9, remaining(deadline))

    payload =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, size, remaining(deadline))
        bytes
      end

    {type, flags, id, payload}
  end

  defp ping(socket, value, deadline) do
    :ok = :gen_tcp.send(socket, Frame.encode(6, 0, 0, value))
    await_ping(socket, value, deadline)
  end

  defp await_ping(socket, value, deadline) do
    case recv_frame(socket, deadline) do
      {6, 1, 0, ^value} ->
        :ok

      other ->
        flunk("unexpected frame before PING ACK: #{inspect(other)}")
    end
  end

  defp assert_window_update(socket, deadline) do
    case recv_frame(socket, deadline) do
      {8, 0, 1, <<0::1, @window::31>>} -> :ok
      {8, 0, 0, <<0::1, @window::31>>} -> assert_window_update(socket, deadline)
      other -> flunk("expected exact returned stream credit: #{inspect(other)}")
    end
  end

  defp assert_oversend_and_cleanup(%{socket: socket, deadline: deadline} = context, worker) do
    monitor = Process.monitor(worker)
    send_data(socket, :binary.copy(<<5>>, @window), false)
    ping(socket, "fits16kb", deadline)
    send_data(socket, <<5>>, true)
    assert_flow_control_reset(socket, deadline)
    assert_receive {:DOWN, ^monitor, :process, ^worker, _reason}, remaining(deadline)
    assert_sibling_and_cleanup(context)
  end

  defp assert_flow_control_reset(socket, deadline) do
    case recv_frame(socket, deadline) do
      {3, 0, 1, <<3::32>>} -> :ok
      {8, 0, 0, <<0::1, @window::31>>} -> assert_flow_control_reset(socket, deadline)
      other -> flunk("expected exact FLOW_CONTROL_ERROR reset: #{inspect(other)}")
    end
  end

  defp assert_echo_and_cleanup(%{socket: socket, deadline: deadline} = context, expected) do
    response = response(socket, 1, deadline)
    assert response.body == expected
    assert Enum.filter(response.headers, &(elem(&1, 0) == ":status")) == [{":status", "200"}]
    assert_sibling_and_cleanup(context)
  end

  defp response(socket, id, deadline, result \\ %{headers: [], body: ""}) do
    {type, flags, stream, payload} = recv_frame(socket, deadline)

    next =
      case {type, stream} do
        {1, ^id} ->
          assert Frame.flag?(flags, 4), "response HEADERS must be complete"
          assert {:ok, fields, _} = HPAX.decode(payload, HPAX.new(4_096))
          %{result | headers: result.headers ++ fields}

        {0, ^id} ->
          %{result | body: result.body <> payload}

        {8, _} ->
          result

        other ->
          flunk("unexpected frame while reading response: #{inspect({other, flags, payload})}")
      end

    if stream == id and type in [0, 1] and Frame.flag?(flags, 1),
      do: next,
      else: response(socket, id, deadline, next)
  end

  defp assert_sibling_and_cleanup(%{
         socket: socket,
         server: server,
         deadline: deadline,
         port: port,
         listener: listener
       }) do
    send_headers(socket, 3, "/sibling", true)
    result = response(socket, 3, deadline)
    assert result.body == "sibling"
    assert Enum.filter(result.headers, &(elem(&1, 0) == ":status")) == [{":status", "200"}]
    :ok = :gen_tcp.close(socket)
    await_zero(server, deadline)
    monitor = Process.monitor(server)
    assert :ok = Gaoxy.stop(server, remaining(deadline))
    assert_receive {:DOWN, ^monitor, :process, ^server, :normal}, remaining(deadline)
    assert {:error, _} = :inet.sockname(listener)

    result = :gen_tcp.listen(port, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    if match?({:error, _}, result) do
      IO.inspect({port, :inet.info(listener), System.cmd("ss", ["-tnap", "sport = :#{port}"])},
        label: "initial-window rebind diagnostic"
      )
    end

    assert {:ok, rebound} = result

    :ok = :gen_tcp.close(rebound)
  end

  defp await_zero(server, deadline) do
    status = Gaoxy.status(server, :http)
    assert status.cleanup_failed == nil, inspect(status)

    unless status.active == 0 and status.retained_bytes == 0 and status.cleanup_pending == 0 do
      remaining(deadline)

      receive do
      after
        1 -> await_zero(server, deadline)
      end
    end
  end

  defp remaining(deadline) do
    value = Lifecycle.remaining(deadline)
    assert value > 0, "original initial-window regression deadline expired"
    value
  end
end
