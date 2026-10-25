defmodule Gaoxy.HTTP.HTTP2WebSocketIdleTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Connection
  alias Gaoxy.HTTP.HTTP2.{Frame, Headers}

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _), do: {:ok, exchange}
  end

  test "valid opening fences an already queued owner idle notification and retains write deadline" do
    {socket, state} = fixture(30)
    # A callback can still be in progress when the old notification is queued.
    assert_receive {:timeout, _, :hell_read_timeout} = old, 500
    {:noreply, {socket, state}} = open(socket, state, 1)
    assert state.streams[1].websocket
    assert state.streams[1].committed
    assert socket.read_timeout == :infinity
    assert is_integer(Process.read_timer(state.streams[1].write.timer))
    assert {:noreply, {^socket, ^state}} = Connection.handle_info(old, {socket, state})
    Process.cancel_timer(state.streams[1].write.timer)
  end

  test "rejected opening preserves the original finite owner interval" do
    {socket, state} = fixture(30)
    state = put_in(state.limits.extended_connect, false)
    {:noreply, {same, state}} = open(socket, state, 1)
    assert same == socket
    refute state.streams[1].websocket
    assert_receive {:timeout, _, :hell_read_timeout} = idle, 500

    assert {:stop, {:shutdown, :read_timeout}, {^same, ^state}} =
             Connection.handle_info(idle, {same, state})
  end

  test "only the last completed WebSocket restores a fresh original owner interval" do
    {socket, state} = fixture(40)
    socket = Hell.Handler.set_read_timeout(socket, :infinity)
    stream = %{state.streams[1] | websocket: true, local_closed: true, eof: true}
    second = %{stream | id: 3, token: make_ref()}
    state = %{state | streams: %{1 => stream, 3 => second}}

    assert {:noreply, {^socket, ^state}} =
             Connection.handle_info(
               {:h2_stream_done, stream.worker, 1, make_ref(), :ok},
               {socket, state}
             )

    {:noreply, {socket, state}} = done(socket, state, 1)
    assert socket.read_timeout == :infinity
    assert Map.has_key?(state.streams, 3)
    started = System.monotonic_time(:millisecond)
    {:noreply, {socket, state}} = done(socket, state, 3)
    assert state.streams == %{}
    assert socket.read_timeout == 40
    assert_receive {:timeout, _, :hell_read_timeout} = idle, 500
    assert System.monotonic_time(:millisecond) - started >= 35

    assert {:stop, {:shutdown, :read_timeout}, {^socket, ^state}} =
             Connection.handle_info(idle, {socket, state})
  end

  test "peer reset restores idle through the public network continuation contract" do
    {socket, state} = fixture(40)
    socket = Hell.Handler.set_read_timeout(socket, :infinity)
    state = put_in(state.streams[1].websocket, true)

    assert {:continue, next, {:persistent, 40}} =
             Connection.handle_data(
               IO.iodata_to_binary(Frame.encode(3, 0, 1, <<Frame.code(:cancel)::32>>)),
               socket,
               state
             )

    assert next.streams == %{}
  end

  test "ordinary local messages do not restart an unchanged owner idle interval" do
    {socket, state} = fixture(30)
    assert_receive {:timeout, _, :hell_read_timeout} = idle, 500
    {:noreply, {socket, state}} = Connection.handle_info(:unrelated, {socket, state})

    assert {:stop, {:shutdown, :read_timeout}, {^socket, ^state}} =
             Connection.handle_info(idle, {socket, state})
  end

  test "opening still expires its own finite write while owner idle is suspended" do
    {socket, state} = fixture(40)
    {:noreply, {socket, state}} = open(socket, state, 1, 30)
    assert socket.read_timeout == :infinity
    assert_receive {:h2_write_timeout, 1, _} = timeout, 500
    {:noreply, {socket, state}} = Connection.handle_info(timeout, {socket, state})
    assert state.streams[1].write == nil
    assert state.streams[1].write_failed
    assert socket.read_timeout == :infinity
    {:noreply, {socket, state}} = done(socket, state, 1)
    assert state.streams == %{}
    assert socket.read_timeout == 40
    Hell.Handler.set_read_timeout(socket, :infinity)
  end

  defp open(socket, state, id, write_timeout \\ 1_000) do
    stream = state.streams[id]

    Connection.handle_call(
      {:h2_operation, id, stream.token,
       {:websocket_open, [], :infinity, Gaoxy.Lifecycle.deadline(write_timeout)}},
      {stream.worker, make_ref()},
      {socket, state}
    )
  end

  defp done(socket, state, id) do
    stream = state.streams[id]

    Connection.handle_info(
      {:h2_stream_done, stream.worker, id, stream.token, :ok},
      {socket, state}
    )
  end

  defp fixture(idle) do
    {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []}, extended_connect: true)
    options = spec.handler_options
    limits = Map.put(options.http_limits, :extended_connect, true)

    {:ok, request} =
      Headers.request(
        [
          {":method", "CONNECT"},
          {":protocol", "websocket"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/ws"},
          {"sec-websocket-version", "13"}
        ],
        false,
        limits,
        true
      )

    worker =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(worker), do: Process.exit(worker, :kill) end)

    stream = %{
      id: 1,
      token: make_ref(),
      worker: worker,
      monitor: nil,
      startup: nil,
      request: request,
      deadline: Gaoxy.Lifecycle.deadline(1_000),
      websocket: false,
      committed: false,
      eof: false,
      read: nil,
      poll: nil,
      write: nil,
      write_failed: false,
      local_closed: false,
      renderer_blocks: 0,
      renderer_projection_bytes: 0,
      queued_wire: 0,
      delivered_wire: 0
    }

    state = %{
      phase: :http2,
      highest: 1,
      default_read_timeout: idle,
      limits: limits,
      h2: options.h2_limits,
      streams: %{1 => stream},
      starting: nil,
      writer_ready: false,
      output: :queue.new(),
      outgoing_block: nil,
      closing: false,
      close_after_write: false,
      draining: false,
      buffer: "",
      settings_ack: true,
      preface: true,
      first: false,
      continuation: nil,
      rate_start: Gaoxy.Lifecycle.now(),
      rate: 0,
      partial_timer: nil,
      partial_token: nil
    }

    socket = %Hell.Socket{
      socket: make_ref(),
      transport_module: Hell.Transport.TCP,
      read_timeout: idle,
      handshake_timeout: 1_000,
      silent_terminate_on_error: false,
      span: nil
    }

    {Hell.Handler.set_read_timeout(socket, idle), state}
  end
end
