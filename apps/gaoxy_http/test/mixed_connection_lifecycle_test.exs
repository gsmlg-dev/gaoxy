defmodule Gaoxy.HTTP.MixedConnectionLifecycleTest do
  use ExUnit.Case, async: false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.Connection
  alias Gaoxy.HTTP.HTTP2.{Frame, Limits}
  @preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:request, exchange.request.path, exchange.deadline})
      Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "ok")
    end
  end

  test "mixed initialization holds exactly one drain-notified lease without H2 state" do
    {socket, context, _client} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert state.phase == :detecting
    assert state.buffer == ""
    assert state.first_input == nil
    refute Map.has_key?(state, :writer)
    refute Map.has_key?(state, :decoder)
    assert %{active: 1, retained_bytes: 0} = Admission.status(state.gate)
    assert :sys.get_state(state.gate).leases[state.lease].drain_notify
  end

  test "detection keeps one absolute deadline and charges copied carry" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("P", socket, state)
    assert first.detector_deadline == first.first_input + 2_000
    assert {:continue, next} = Connection.handle_data("RI", socket, first)
    assert next.first_input == first.first_input
    assert next.detector_deadline == first.detector_deadline
    assert next.detector_timer == first.detector_timer
    assert next.detector_token == first.detector_token
    assert next.lease == state.lease
    assert %{active: 1, retained_bytes: 3} = Admission.status(next.gate)
    Connection.handle_close(socket, next)
    assert Process.read_timer(first.detector_timer) == false
  end

  test "empty input preserves the first byte idle phase" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, same} = Connection.handle_data("", socket, state)
    assert same == state
  end

  test "H1 selection preserves the original header and request budgets and lease" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("P", socket, state)
    first = %{first | first_input: first.first_input - 1_000}
    assert {:continue, selected} = Connection.handle_data("OST / HTTP/1.1\r\n", socket, first)
    assert selected.phase == :header
    assert selected.lease == first.lease
    assert selected.deadline == first.first_input + 6_000
    assert Process.read_timer(selected.header_timer) <= 3_000
    assert Process.read_timer(first.detector_timer) == false
    assert %{active: 1} = Admission.status(selected.gate)
  end

  test "H2 selection replays the whole preface and SETTINGS on the original lease" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("PRI", socket, state)
    bytes = binary_part(@preface, 3, 21) <> IO.iodata_to_binary(Frame.encode(4, 0, 0, ""))
    assert {:continue, selected} = Connection.handle_data(bytes, socket, first)
    assert selected.phase == :http2
    assert selected.lease == first.lease
    assert selected.preface
    refute selected.first
    assert selected.buffer == ""
    refute selected.settings_ack
    assert Process.read_timer(first.detector_timer) == false

    reserves =
      Limits.reservation(
        context.spec.handler_options.http_limits,
        context.spec.handler_options.h2_limits
      )

    assert :sys.get_state(selected.gate).leases[selected.lease].bytes == reserves.connection

    assert Enum.count(:sys.get_state(selected.gate).leases, fn {_, lease} ->
             lease.pid == self()
           end) == 1

    Connection.handle_close(socket, selected)
  end

  test "H2 startup receives the remaining allowance and still waits for server SETTINGS ACK" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("P", socket, state)
    first = %{first | first_input: first.first_input - 1_000}

    assert {:continue, selected} =
             Connection.handle_data(
               binary_part(@preface, 1, 23) <> IO.iodata_to_binary(Frame.encode(4, 0, 0, "")),
               socket,
               first
             )

    refute selected.settings_ack
    assert Process.read_timer(selected.start_timer) <= 1_000
    assert Process.read_timer(selected.start_timer) > 0

    assert {:continue, acknowledged} =
             Connection.handle_data(
               IO.iodata_to_binary(Frame.encode(4, 1, 0, "")),
               socket,
               selected
             )

    assert acknowledged.settings_ack
    assert Process.read_timer(selected.start_timer) == false
    Connection.handle_close(socket, acknowledged)
  end

  test "stale detector tokens never reach H2 delegation" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("PRI", socket, state)

    assert {:continue, selected} =
             Connection.handle_data(binary_part(@preface, 3, 21), socket, first)

    assert {:noreply, {^socket, ^selected}} =
             Connection.handle_info(
               {:gaoxy_http_detect_timeout, first.detector_token},
               {socket, selected}
             )

    Connection.handle_close(socket, selected)
  end

  test "matching detector timeout closes while obsolete tokens are ignored" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("PRI", socket, state)

    assert {:noreply, {^socket, ^first}} =
             Connection.handle_info({:gaoxy_http_detect_timeout, make_ref()}, {socket, first})

    assert {:stop, :normal, {^socket, stopped}} =
             Connection.handle_info(
               {:gaoxy_http_detect_timeout, first.detector_token},
               {socket, first}
             )

    assert stopped.phase == :detecting
    assert Process.read_timer(first.detector_timer) == false
  end

  test "undecided drain closes immediately and reservation updates do not admit requests" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, state} = Connection.handle_data("P", socket, state)
    deadline = Lifecycle.deadline(1_000)
    assert :ok = Admission.drain(state.gate, deadline)
    assert_receive {:gaoxy_drain, gate, lease, ^deadline}
    assert gate == state.gate
    assert lease == state.lease

    assert {:stop, :normal, {^socket, stopped}} =
             Connection.handle_info({:gaoxy_drain, gate, lease, deadline}, {socket, state})

    assert stopped.closing
    assert Process.read_timer(state.detector_timer) == false

    assert {:close, _} =
             Connection.handle_data("OST / HTTP/1.1\r\nHost: localhost\r\n\r\n", socket, state)

    refute_receive {:request, _, _}
  end

  test "failed H2 budget validation preserves a safely cleanable detecting context" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    state = put_in(state.spec.limits.max_bytes, 1)
    assert {:error, :http2_byte_budget, failed} = Connection.handle_data(@preface, socket, state)
    assert failed.phase == :detecting
    refute Map.has_key?(failed, :decoder)
    refute Map.has_key?(failed, :writer)
    assert :ok = Connection.handle_error(:init_failed, socket, failed)
    assert %{active: 1, retained_bytes: 0} = Admission.status(state.gate)
  end

  test "H2 reservation is denied before decoder or writer allocation" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)

    reserves =
      Limits.reservation(
        context.spec.handler_options.http_limits,
        context.spec.handler_options.h2_limits
      )

    {:ok, _other} =
      Admission.acquire(state.gate, context.spec.limits.max_bytes - reserves.connection + 1)

    children = Task.Supervisor.children(Gaoxy.HTTP.Tasks)
    assert {:error, :byte_limit, failed} = Connection.handle_data(@preface, socket, state)
    assert failed.phase == :detecting
    assert failed.lease == state.lease
    refute Map.has_key?(failed, :writer)
    assert Task.Supervisor.children(Gaoxy.HTTP.Tasks) == children
  end

  test "expired first input cannot select an engine even with a complete deciding delivery" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("P", socket, state)
    expired = %{first | detector_deadline: Lifecycle.now() - 1}

    assert {:close, _} =
             Connection.handle_data("OST / HTTP/1.1\r\nHost: localhost\r\n\r\n", socket, expired)

    refute_receive {:request, _, _}
  end

  test "detecting close error shutdown and idle timeout cancel their timer" do
    for event <- [:handle_close, :handle_shutdown, :handle_timeout, :handle_error] do
      {socket, context, _} = context()
      assert {:continue, state} = Connection.handle_connection(socket, context)
      assert {:continue, first} = Connection.handle_data("P", socket, state)
      args = if event == :handle_error, do: [:closed, socket, first], else: [socket, first]
      assert :ok = apply(Connection, event, args)
      assert Process.read_timer(first.detector_timer) == false
    end
  end

  test "detection chooses the minimum existing header request and frame allowance" do
    for {header, request, frame, expected} <- [
          {300, 600, 900, 300},
          {600, 300, 900, 300},
          {600, 900, 300, 300}
        ] do
      {socket, context, _} = context()

      context =
        context
        |> put_in([:spec, :handler_options, :http_limits, :header_timeout], header)
        |> put_in([:spec, :handler_options, :http_limits, :request_timeout], request)
        |> put_in([:spec, :handler_options, :h2_limits, :frame_timeout], frame)

      assert {:continue, state} = Connection.handle_connection(socket, context)
      assert {:continue, first} = Connection.handle_data("P", socket, state)
      assert first.detector_deadline == first.first_input + expected
      Connection.handle_close(socket, first)
    end
  end

  test "runtime host validation is retained on H2 selection and fails without frames" do
    {socket, context, client} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    previous = Application.fetch_env(:kernel, :inet_backend)

    try do
      Application.put_env(:kernel, :inet_backend, :socket)

      assert {:error, :unsupported_http2_host, failed} =
               Connection.handle_data(@preface, socket, state)

      assert failed.phase == :detecting
      refute Map.has_key?(failed, :writer)
      assert :ok = Connection.handle_close(socket, failed)
      assert {:error, :timeout} = :gen_tcp.recv(client, 0, 20)
    after
      case previous do
        {:ok, value} -> Application.put_env(:kernel, :inet_backend, value)
        :error -> Application.delete_env(:kernel, :inet_backend)
      end
    end
  end

  test "H2 ingress bound rejects before writer allocation and replay concatenation" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    limit = context.spec.handler_options.http_limits.max_buffer_bytes
    children = Task.Supervisor.children(Gaoxy.HTTP.Tasks)

    assert {:close, failed} =
             Connection.handle_data(@preface <> :binary.copy("x", limit), socket, state)

    assert failed.phase == :detecting
    refute Map.has_key?(failed, :writer)
    assert Task.Supervisor.children(Gaoxy.HTTP.Tasks) == children
    assert :sys.get_state(state.gate).leases[state.lease].bytes == 0
  end

  test "H2 partial frame timer remains separate after startup SETTINGS ACK" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("P", socket, state)

    bytes =
      IO.iodata_to_binary([
        binary_part(@preface, 1, 23),
        Frame.encode(4, 0, 0, ""),
        Frame.encode(4, 1, 0, ""),
        <<0>>
      ])

    assert {:continue, selected} = Connection.handle_data(bytes, socket, first)
    assert selected.settings_ack
    assert selected.buffer == <<0>>
    assert Process.read_timer(selected.start_timer) == false
    assert Process.read_timer(selected.partial_timer) > 0
    assert selected.partial_token != selected.start_token
    Connection.handle_close(socket, selected)
  end

  test "elapsed H2 initialization cannot accept a coalesced startup ACK ahead of its timeout" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    assert {:continue, first} = Connection.handle_data("P", socket, state)

    # Model synchronous initialization consuming the startup allowance. Keep the
    # detector deadline live so selection reaches the engine, whose first-input
    # startup clock is already exhausted before queued timer messages can run.
    first = %{
      first
      | first_input: Lifecycle.now() - first.spec.handler_options.h2_limits.frame_timeout - 1
    }

    replay =
      IO.iodata_to_binary([
        binary_part(@preface, 1, 23),
        Frame.encode(4, 0, 0, ""),
        Frame.encode(4, 1, 0, "")
      ])

    assert {:continue, selected} = Connection.handle_data(replay, socket, first)
    refute selected.settings_ack
    assert selected.closing
    refute selected.preface
    assert selected.buffer == ""
    assert selected.start_deadline == first.first_input + selected.h2.frame_timeout
    Connection.handle_close(socket, selected)
  end

  test "a late startup ACK cannot cancel the absolute H2 deadline before its queued timeout" do
    {socket, context, _} = context()
    assert {:continue, state} = Connection.handle_connection(socket, context)
    replay = IO.iodata_to_binary([@preface, Frame.encode(4, 0, 0, "")])
    assert {:continue, selected} = Connection.handle_data(replay, socket, state)
    refute selected.settings_ack
    expired = Map.put(selected, :start_deadline, Lifecycle.now() - 1)

    assert {:continue, rejected} =
             Connection.handle_data(
               IO.iodata_to_binary(Frame.encode(4, 1, 0, "")),
               socket,
               expired
             )

    refute rejected.settings_ack
    assert rejected.closing
    # The ACK must not cancel startup as though it completed successfully.
    assert Process.read_timer(selected.start_timer) > 0
    Connection.handle_close(socket, rejected)
  end

  defp context do
    {:ok, spec} =
      Gaoxy.HTTP.service_spec(
        endpoint: {Endpoint, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{header_timeout: 4_000, request_timeout: 6_000},
        h2_limits: %{frame_timeout: 2_000}
      )

    spec = put_in(spec.handler_options.protocols, [:http2, :http1])

    gate =
      start_supervised!({Admission, {spec.limits, %{instance: make_ref(), service: :test}}},
        id: make_ref()
      )

    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {ip, port}} = :inet.sockname(listener)
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    {:ok, raw} = :gen_tcp.accept(listener, 1_000)
    :gen_tcp.close(listener)

    on_exit(fn ->
      :gen_tcp.close(client)
      :gen_tcp.close(raw)
    end)

    socket =
      struct!(Hell.Socket,
        socket: raw,
        transport_module: Hell.Transports.TCP,
        read_timeout: 1_000,
        handshake_timeout: 1_000,
        silent_terminate_on_error: false,
        span: Hell.Telemetry.start_span(:connection, %{}, %{handler: __MODULE__})
      )

    {socket, %{spec: spec, gate: gate}, client}
  end
end
