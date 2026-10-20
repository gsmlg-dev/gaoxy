defmodule Gaoxy.HTTP2WorkerStartupTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP2.Frame
  @wait 3_000

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, {observer, payload}) do
      send(observer, {:worker_endpoint, self(), exchange, payload})

      receive do
        :finish -> Response.send_resp(exchange, 200, [], "complete")
      after
        3_000 -> {:error, :fixture_timeout, exchange}
      end
    end
  end

  test "complete initialized endpoint and initial Exchange have an owned precharged lease" do
    payload = :binary.copy(<<0, 1, 254, 255>>, 32_769)
    endpoint = {Endpoint, {self(), payload}}
    {socket, server} = connect(endpoint)
    send_headers(socket, 1)
    assert_receive {:worker_endpoint, worker, exchange, received}, @wait
    assert received == payload
    assert :crypto.hash(:sha256, received) == :crypto.hash(:sha256, payload)
    gate = :sys.get_state(exchange.gate, @wait)
    assert gate.leases[exchange.lease].pid == worker
    assert gate.leases[exchange.lease].deadline == exchange.deadline
    assert gate.leases[exchange.lease].request_active
    assert gate.leases[exchange.lease].bytes == Exchange.retained_bytes(exchange)
    p = 2 * exchange.limits.max_header_bytes + 4 * exchange.limits.max_read_chunk + 65_536
    assert exchange.protocol_bytes > p + :erlang.external_size(endpoint)
    monitor = Process.monitor(worker)
    send(worker, :finish)
    assert response(socket, 1) == {"200", "complete"}
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @wait
    :ok = :gen_tcp.close(socket)

    eventually(fn ->
      match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, Gaoxy.status(server, :http))
    end)
  end

  defp connect(endpoint) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: endpoint,
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{request_timeout: 10_000}
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @wait) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @wait)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    {socket, server}
  end

  defp send_headers(socket, id) do
    fields = [
      {":method", "GET"},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", "/"}
    ]

    {block, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, id, block))
  end

  defp response(socket, id, status \\ nil, body \\ "", decoder \\ HPAX.new(4_096)) do
    {:ok, <<size::24, type, flags, _::1, sid::31>>} = :gen_tcp.recv(socket, 9, @wait)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @wait), 1)

    case {type, sid} do
      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, id, status, body, decoder)

      {1, ^id} ->
        assert Frame.flag?(flags, 4)
        {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
        {":status", status} = List.keyfind(fields, ":status", 0)

        if Frame.flag?(flags, 1),
          do: {status, body},
          else: response(socket, id, status, body, decoder)

      {0, ^id} ->
        body = body <> bytes

        if Frame.flag?(flags, 1),
          do: {status, body},
          else: response(socket, id, status, body, decoder)

      other ->
        flunk("unexpected native frame #{inspect(other)}: #{inspect(bytes)}")
    end
  end

  defp eventually(predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@wait)

    unless predicate.() do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> eventually(predicate, deadline)
      end
    end
  end
end

defmodule Gaoxy.HTTP2WorkerStartupExtendedTest do
  use ExUnit.Case, async: false
  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP2.{Frame, WorkerAccounting}

  @wait 3_000
  @large_budget 536_870_912
  @capacity_path "/capacity/" <> String.duplicate("t", 4_096)

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, %{observer: observer, payload: payload}) do
      if exchange.request.path == "/seed" do
        send(observer, {:native_seed, exchange.transport_state, exchange.gate})
        Response.send_resp(exchange, 200, [], "seed")
      else
        send(observer, {:native_entered, self(), exchange, payload})
        loop(exchange, observer)
      end
    end

    defp loop(exchange, observer) do
      receive do
        {:read, credit} ->
          case Exchange.read_body_step(exchange, credit, 1_000) do
            {kind, bytes, next} when kind in [:ok, :more] ->
              send(observer, {:native_step, self(), :read, {kind, bytes}, next})
              loop(next, observer)

            {:pending, next} ->
              send(observer, {:native_step, self(), :read, :pending, next})
              loop(next, observer)

            {:error, reason, next} ->
              send(observer, {:native_step, self(), :read, {:error, reason}, next})
              loop(next, observer)
          end

        :poll ->
          {:pending, next} = Exchange.poll_connection(exchange, 0)
          send(observer, {:native_step, self(), :poll, :pending, next})
          loop(next, observer)

        :invalid_read ->
          {:error, :invalid_read_length, next} = Exchange.read_body_step(exchange, 0, 0)
          send(observer, {:native_step, self(), :invalid_read, :invalid_read_length, next})
          loop(next, observer)

        :finish ->
          {:ok, next} = Response.send_resp(exchange, 200, [], "complete")
          send(observer, {:native_step, self(), :normal_response, :ok, next})
          return_after_barrier({:ok, next})

        :chunk_error ->
          {:ok, next} = Response.send_chunked(exchange, 200, [])
          {:ok, next} = Response.chunk(next, "partial")
          send(observer, {:native_step, self(), :chunked, :ok, next})

          receive do
            :fail ->
              send(observer, {:native_step, self(), :endpoint_error, :fixture_error, next})
              return_after_barrier({:error, :fixture_error, next})
          after
            5_000 -> {:error, :fixture_failure_barrier_timeout, next}
          end
      after
        5_000 -> {:error, :fixture_command_timeout, exchange}
      end
    end

    defp return_after_barrier(result) do
      receive do
        :return -> result
      after
        5_000 -> {:error, :fixture_return_timeout, elem(result, tuple_size(result) - 1)}
      end
    end
  end

  test "real configured capacity refuses W-1 and accepts exact startup W" do
    assert_accounting_api!()
    payload = payload()
    calibration = seeded(@large_budget, payload)
    baseline = connection_baseline!(calibration)
    assert :ok = :sys.suspend(calibration.gate, @wait)
    send_headers(calibration.socket, 3, @capacity_path, true)
    {state, stream} = await_startup(calibration, 3)

    assert {:ok, {:native_http2_worker_v1, n, w}} =
             WorkerAccounting.reservation(state, stream)

    assert %{protocol_bytes: ^n, bytes: ^w} = stream.startup
    assert w == n + 2 * stream.request.head_bytes

    assert n >
             state.reserves.stream +
               :erlang.external_size({Endpoint, %{observer: self(), payload: payload}})

    send_reset(calibration.socket, 3)
    await_owner(calibration.owner, &(not Map.has_key?(&1.streams, 3)))
    assert :ok = :sys.resume(calibration.gate, @wait)
    await_baseline(calibration, baseline)
    close_clean(calibration)

    for delta <- [-1, 0] do
      configured = baseline + w + delta
      context = seeded(configured, payload)
      assert connection_baseline!(context) == baseline
      assert :sys.get_state(context.gate, @wait).limits.max_bytes == configured
      assert :ok = :sys.suspend(context.gate, @wait)
      send_headers(context.socket, 3, @capacity_path, true)
      {actual_state, actual} = await_startup(context, 3)

      assert {:ok, {:native_http2_worker_v1, ^n, ^w}} =
               WorkerAccounting.reservation(actual_state, actual)

      assert actual.startup.bytes == w
      trace_spawns(context.gate)
      assert :ok = :sys.resume(context.gate, @wait)

      if delta == -1 do
        assert_reset(context.socket, 3, :refused_stream)
        await_owner(context.owner, &(not Map.has_key?(&1.streams, 3)))
        await_baseline(context, baseline)
        trace_flush(context.gate)
        %{gate: gate, owner: owner} = context
        refute_receive {:trace, ^gate, :spawn, _, _}, 0
        refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0
      else
        {worker, exchange} = entered(context, 3, payload)
        assert exchange.protocol_bytes == n
        assert_owned_exact!(worker, exchange)
        assert Admission.status(context.gate).retained_bytes == baseline + w
        # Startup acceptance uses the exact W budget. Later response/read
        # transient reservations have separate existing admission obligations.
        monitor = Process.monitor(worker)
        send_reset(context.socket, 3)
        assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
        await_baseline(context, baseline)
      end

      close_clean(context)
    end
  end

  test "paused Gate creates no prelease worker while native PING and RST parsing progresses" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    assert 1 == :erlang.trace(context.owner, true, [:send, {:tracer, self()}])
    assert :ok = :sys.suspend(context.gate, @wait)

    try do
      send_headers(context.socket, 3, "/paused", true)
      {_state, stream} = await_startup(context, 3)
      assert stream.worker == nil and stream.lease == nil and stream.monitor == nil
      assert is_reference(stream.startup.request)
      assert is_reference(stream.startup.timer)
      assert stream.startup.parent_lease == context.parent_lease
      assert stream.startup.token == stream.token
      assert stream.startup.deadline == stream.deadline
      ping = <<17, 18, 19, 20, 21, 22, 23, 24>>
      assert :ok = :gen_tcp.send(context.socket, Frame.encode(6, 0, 0, ping))
      ack = Frame.encode(6, 1, 0, ping)
      owner = context.owner
      writer = context.writer

      assert_receive {:trace, ^owner, :send, {:h2_write, ^owner, _operation, ^ack, _deadline},
                      ^writer},
                     @wait

      # Writer itself is blocked at Admission.start_send while Gate is paused.
      # This asserts real native parsing/enqueue, not an impossible wire ACK.
      send_reset(context.socket, 3)
      send_headers(context.socket, 5, "/sibling", true)

      current =
        await_owner(owner, fn state ->
          not Map.has_key?(state.streams, 3) and state.starting == 5 and
            match?(%{worker: nil, lease: nil, startup: %{request: _}}, state.streams[5])
        end)

      assert current.streams[5].startup.request != stream.startup.request
      assert Process.alive?(owner)
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0
      assert :ok = :sys.resume(context.gate, @wait)
      assert_ping(context.socket, ping)
      {worker, exchange} = entered(context, 5, context.payload)
      assert_owned_exact!(worker, exchange)
      normal_response(context, worker, exchange)
      await_baseline(context, baseline)
    after
      safe_resume(context.gate)
      close_clean(context)
    end
  end

  test "stale async failure cannot replace current5 or advance queued7 after reset3" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    assert :ok = :sys.suspend(context.gate, @wait)

    try do
      send_headers(context.socket, 3, "/canceled", true)
      {_state, old} = await_startup(context, 3)
      send_reset(context.socket, 3)
      send_headers(context.socket, 5, "/five", true)
      send_headers(context.socket, 7, "/seven", true)

      before =
        await_owner(context.owner, fn state ->
          state.starting == 5 and not Map.has_key?(state.streams, 3) and
            match?(%{worker: nil, startup: %{request: _}}, state.streams[5]) and
            match?(%{worker: nil, startup: nil}, state.streams[7])
        end)

      # Controlled delayed already-produced failure for the actual old public
      # request identity, not a claim to have observed this naturally on wire.
      send(context.owner, {[:alias | old.startup.request], {:error, :active_limit}})
      {_socket, after_receipt} = :sys.get_state(context.owner, @wait)
      assert after_receipt.starting == 5
      assert after_receipt.streams[5].startup == before.streams[5].startup
      assert after_receipt.streams[5].token == before.streams[5].token
      assert after_receipt.streams[5].worker == nil
      assert after_receipt.streams[7].worker == nil
      assert after_receipt.streams[7].startup == nil
      assert :ok = :sys.resume(context.gate, @wait)
      {five, exchange5} = entered(context, 5, context.payload)
      {seven, exchange7} = entered(context, 7, context.payload)
      assert five != seven
      assert_owned_exact!(five, exchange5)
      assert_owned_exact!(seven, exchange7)
      send(five, :finish)
      send(seven, :finish)
      assert_step(five, :normal_response, :ok, exchange5.protocol_bytes)
      assert_step(seven, :normal_response, :ok, exchange7.protocol_bytes)

      assert responses(context.socket, [5, 7]) == %{
               5 => %{status: "200", body: "complete"},
               7 => %{status: "200", body: "complete"}
             }

      return_and_join(five)
      return_and_join(seven)
      await_baseline(context, baseline)
    after
      safe_resume(context.gate)
      close_clean(context)
    end
  end

  test "terminal trailers buffered before admission need consumption and exact returned charge" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    trailers = [{"x-check", "first"}, {"x-check", "last"}]
    assert :ok = :sys.suspend(context.gate, @wait)

    try do
      send_headers(context.socket, 3, "/trailers", false, [{"trailer", "x-check"}], "POST")
      send_trailers(context.socket, 3, trailers)

      await_owner(context.owner, fn state ->
        match?(
          %{worker: nil, lease: nil, eof: true, trailers: ^trailers, startup: %{request: _}},
          state.streams[3]
        )
      end)

      assert :ok = :sys.resume(context.gate, @wait)
      {worker, initial} = entered(context, 3, context.payload)
      assert not Exchange.body_complete?(initial)
      assert Exchange.request_trailers(initial) == []
      assert_owned_exact!(worker, initial)
      send(worker, {:read, 1})
      returned = assert_step(worker, :read, {:ok, ""}, initial.protocol_bytes)
      assert Exchange.body_complete?(returned)
      assert Exchange.request_trailers(returned) == trailers
      assert returned.body.trailer_bytes == Gaoxy.HTTP.HTTP2.Headers.bytes(trailers)
      # One byte of body credit does not bound retained terminal trailers.
      # The returned state needs its full exact charge, including both pairs.
      assert_owned_exact!(worker, returned)
      send(worker, :poll)
      polled = assert_step(worker, :poll, :pending, initial.protocol_bytes)
      assert Exchange.request_trailers(polled) == trailers
      assert_owned_exact!(worker, polled)
      normal_response(context, worker, polled)
      await_baseline(context, baseline)
    after
      safe_resume(context.gate)
      close_clean(context)
    end
  end

  test "terminal trailer final admission refusal preserves progressed metadata and actual charge" do
    assert_accounting_api!()
    path = "/trailers-admission-refusal"
    headers = [{"trailer", "x-check"}]
    trailers = [{"x-check", "first"}, {"x-check", "last"}]
    calibration = seeded()
    baseline = connection_baseline!(calibration)
    send_headers(calibration.socket, 3, path, false, headers, "POST")
    {calibration_worker, calibration_exchange} = entered(calibration, 3, calibration.payload)
    assert_owned_exact!(calibration_worker, calibration_exchange)
    w = Exchange.retained_bytes(calibration_exchange)
    calibration_monitor = Process.monitor(calibration_worker)
    send_reset(calibration.socket, 3)
    assert_receive {:DOWN, ^calibration_monitor, :process, ^calibration_worker, :killed}, @wait
    await_baseline(calibration, baseline)
    close_clean(calibration)

    context = seeded(baseline + w + 2)
    assert connection_baseline!(context) == baseline
    send_headers(context.socket, 3, path, false, headers, "POST")
    {worker, initial} = entered(context, 3, context.payload)
    assert Exchange.retained_bytes(initial) == w
    assert_owned_exact!(worker, initial)
    send_trailers(context.socket, 3, trailers)
    await_owner(context.owner, &match?(%{eof: true, trailers: ^trailers}, &1.streams[3]))
    send(worker, {:read, 1})
    rejected = assert_step(worker, :read, {:error, :byte_limit}, initial.protocol_bytes)
    assert Exchange.body_complete?(rejected)
    assert Exchange.request_trailers(rejected) == trailers
    assert rejected.body.total == 0
    assert rejected.body.trailer_bytes == Gaoxy.HTTP.HTTP2.Headers.bytes(trailers)
    assert Exchange.retained_bytes(rejected) == w + 2 * rejected.body.trailer_bytes
    # The progressed error state was refused, so its larger charge is not admitted.
    gate = :sys.get_state(context.gate, @wait)
    assert gate.leases[initial.lease].pid == worker
    assert gate.leases[initial.lease].bytes == w + 2
    assert gate.bytes == baseline + w + 2
    monitor = Process.monitor(worker)
    send_reset(context.socket, 3)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
    await_baseline(context, baseline)
    close_clean(context)
  end

  test "full N remains exactly charged through read poll validation error and normal response" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    send_headers(context.socket, 3, "/body", false, [{"content-length", "5"}], "POST")
    {worker, initial} = entered(context, 3, context.payload)
    assert_owned_exact!(worker, initial)
    assert :ok = :gen_tcp.send(context.socket, Frame.encode(0, 1, 3, "hello"))
    await_owner(context.owner, &match?(%{received: 5, eof: true}, &1.streams[3]))
    send(worker, {:read, 16_384})
    read = assert_step(worker, :read, {:ok, "hello"}, initial.protocol_bytes)
    assert Exchange.body_complete?(read)
    assert read.body.total == 5
    assert_owned_exact!(worker, read)
    send(worker, :poll)
    polled = assert_step(worker, :poll, :pending, initial.protocol_bytes)
    assert_owned_exact!(worker, polled)
    send(worker, :invalid_read)
    failed = assert_step(worker, :invalid_read, :invalid_read_length, initial.protocol_bytes)
    assert failed == polled
    assert_owned_exact!(worker, failed)
    normal_response(context, worker, failed)
    await_baseline(context, baseline)
    close_clean(context)
  end

  test "chunked endpoint error retains N then emits RST without successful END_STREAM" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    send_headers(context.socket, 3, "/chunked-error", true)
    {worker, initial} = entered(context, 3, context.payload)
    send(worker, :chunk_error)
    chunked = assert_step(worker, :chunked, :ok, initial.protocol_bytes)
    assert chunked.response == :chunked
    assert_owned_exact!(worker, chunked)
    assert read_partial(context.socket, 3) == %{status: "200", body: "partial"}
    send(worker, :fail)
    failed = assert_step(worker, :endpoint_error, :fixture_error, initial.protocol_bytes)
    assert failed == chunked
    assert_owned_exact!(worker, failed)
    monitor = Process.monitor(worker)
    send(worker, :return)
    assert_reset(context.socket, 3, :cancel)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @wait
    await_baseline(context, baseline)
    send_headers(context.socket, 5, "/surviving-sibling", true)
    {sibling, exchange} = entered(context, 5, context.payload)
    normal_response(context, sibling, exchange)
    await_baseline(context, baseline)
    close_clean(context)
  end

  test "blocked endpoint leaves Gate-running wire PING and sibling response responsive" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    send_headers(context.socket, 3, "/blocked", true)
    {worker, exchange} = entered(context, 3, context.payload)
    assert_owned_exact!(worker, exchange)
    ping = <<1, 3, 5, 7, 9, 11, 13, 15>>
    assert :ok = :gen_tcp.send(context.socket, Frame.encode(6, 0, 0, ping))
    assert_ping(context.socket, ping)
    send_headers(context.socket, 5, "/sibling", true)
    {sibling, next} = entered(context, 5, context.payload)
    normal_response(context, sibling, next)
    assert Process.alive?(worker)
    monitor = Process.monitor(worker)
    send_reset(context.socket, 3)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, @wait
    await_baseline(context, baseline)
    close_clean(context)
  end

  test "peer close with queued startup joins connection writer and leaves no late worker" do
    assert_accounting_api!()
    context = seeded()
    assert :ok = :sys.suspend(context.gate, @wait)

    try do
      trace_spawns(context.gate)
      send_headers(context.socket, 3, "/queued-close", true)
      {_state, pending} = await_startup(context, 3)
      assert pending.worker == nil
      owner_monitor = Process.monitor(context.owner)
      writer_monitor = Process.monitor(context.writer)
      assert :ok = :gen_tcp.close(context.socket)

      assert_receive {:DOWN, ^owner_monitor, :process, owner, _}
                     when owner == context.owner,
                     @wait

      assert_receive {:DOWN, ^writer_monitor, :process, writer, _}
                     when writer == context.writer,
                     @wait

      assert :ok = :sys.resume(context.gate, @wait)
      await_gate_zero(context.gate)
      trace_flush(context.gate)
      %{gate: gate, owner: owner} = context
      refute_receive {:trace, ^gate, :spawn, _, _}, 0
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0

      stop_clean(context.server)
    after
      safe_resume(context.gate)
    end
  end

  defp assert_accounting_api! do
    assert Code.ensure_loaded?(WorkerAccounting)
    assert function_exported?(WorkerAccounting, :reservation, 2)
  end

  @tag :controlled_late_receipt
  test "authentic canceled success cannot replace current5 or advance queued7" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)

    try do
      receipt = retain_native_success3(context)
      assert_running_dispatch_wait!(context, receipt)
      old_monitor = Process.monitor(receipt.worker)
      assert :ok = :sys.suspend(context.gate, @wait)

      send_reset(context.socket, 3)
      send_headers(context.socket, 5, "/five", true)
      send_headers(context.socket, 7, "/seven", true)

      before =
        await_owner(context.owner, fn state ->
          state.starting == 5 and not Map.has_key?(state.streams, 3) and
            match?(
              %{worker: nil, lease: nil, monitor: nil, startup: %{request: _}},
              state.streams[5]
            ) and
            match?(%{worker: nil, lease: nil, monitor: nil, startup: nil}, state.streams[7])
        end)

      assert before.streams[5].startup.request != receipt.old.startup.request
      assert before.streams[5].token != receipt.old.token
      assert Process.alive?(receipt.worker)
      assert Process.alive?(context.owner)
      owner = context.owner
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0

      # Deliver the original captured envelope unchanged, to the owner PID. Its
      # original alias was retired by native cancel_start; sending TO that alias
      # would discard the delayed receipt before the native handler could see it.
      send(context.owner, receipt.raw)
      {_socket, after_receipt} = :sys.get_state(context.owner, @wait)
      assert after_receipt.starting == 5
      assert not Map.has_key?(after_receipt.streams, 3)
      assert after_receipt.streams[5] == before.streams[5]
      assert after_receipt.streams[7] == before.streams[7]
      assert after_receipt.accepted == before.accepted
      assert after_receipt.writer == before.writer
      assert after_receipt.lease == before.lease
      assert after_receipt.writer_monitor == before.writer_monitor
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0

      assert :ok = :sys.resume(context.gate, @wait)

      assert_receive {:DOWN, ^old_monitor, :process, old_worker, :killed}
                     when old_worker == receipt.worker,
                     @wait

      {five, exchange5} = entered(context, 5, context.payload)
      {seven, exchange7} = entered(context, 7, context.payload)
      assert five != seven and five != receipt.worker and seven != receipt.worker
      assert_owned_exact!(five, exchange5)
      assert_owned_exact!(seven, exchange7)
      send(five, :finish)
      send(seven, :finish)
      assert_step(five, :normal_response, :ok, exchange5.protocol_bytes)
      assert_step(seven, :normal_response, :ok, exchange7.protocol_bytes)

      assert responses(context.socket, [5, 7]) == %{
               5 => %{status: "200", body: "complete"},
               7 => %{status: "200", body: "complete"}
             }

      return_and_join(five)
      return_and_join(seven)
      await_baseline(context, baseline)
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0
    after
      safe_resume(context.gate)
      close_clean(context)
    end
  end

  for mode <- [:normal, :kill] do
    @native_death_mode mode
    @tag :controlled_late_receipt
    test "native owner #{mode} death after activation before success handling joins child" do
      native_owner_death(@native_death_mode)
    end
  end

  defp native_owner_death(mode) do
    assert_accounting_api!()
    context = seeded()

    try do
      receipt = retain_native_success3(context)
      assert_running_dispatch_wait!(context, receipt)
      owner = context.owner
      worker = receipt.worker
      writer = context.writer
      owner_monitor = Process.monitor(owner)
      worker_monitor = Process.monitor(worker)
      writer_monitor = Process.monitor(writer)
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0

      if mode == :normal do
        # Public OTP system termination invokes actual Handler termination/close.
        assert :ok = :sys.terminate(owner, :normal, @wait)
      else
        # Real untrappable abnormal death exercises Gate/child owner monitoring.
        assert Process.exit(owner, :kill)
      end

      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, reason}, @wait
      assert reason == if(mode == :normal, do: :normal, else: :killed)
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _}, @wait
      assert_receive {:DOWN, ^writer_monitor, :process, ^writer, _}, @wait
      await_gate_zero(context.gate)
      gate = :sys.get_state(context.gate, @wait)
      assert gate.spawns == %{}
      assert gate.leases == %{}
      assert gate.cleanups == %{}
      assert gate.bytes == 0
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0
      assert :ok = :gen_tcp.close(context.socket)
      stop_clean(context.server)
    after
      safe_resume(context.gate)
      :gen_tcp.close(context.socket)
      # Existing seeded on_exit stops server on any assertion failure. Do not
      # call close_clean here: the owner/writer are already explicitly joined.
    end
  end

  # Exact cut: post-native-HEADERS3 state, before gen_server's next mailbox input.
  # Gate is initially suspended only to make the armed handshake deterministic.
  defp retain_native_success3(context) do
    assert :ok = :sys.suspend(context.gate, @wait)
    observer = self()
    hook = make_ref()
    owner = context.owner

    assert :ok =
             :sys.install(
               owner,
               {hook,
                fn previous, event, _ ->
                  case event do
                    {:noreply, {socket, %{phase: :http2, starting: 3, streams: streams} = state}} ->
                      case streams[3] do
                        %{worker: nil, lease: nil, monitor: nil, startup: %{request: request}} =
                            old
                        when is_reference(request) ->
                          tag = [:alias | request]

                          send(
                            observer,
                            {:native_success_armed, hook, self(), socket, state, old}
                          )

                          receive do
                            {^tag, {:ok, worker, lease}} = raw
                            when is_pid(worker) and is_reference(lease) ->
                              send(
                                observer,
                                {:native_success_retained, hook, self(), raw, state, old}
                              )
                          after
                            @wait -> send(observer, {:native_success_capture_timeout, hook})
                          end

                          :done

                        _ ->
                          previous
                      end

                    _ ->
                      previous
                  end
                end, nil},
               @wait
             )

    send_headers(context.socket, 3, "/canceled", true)
    assert_receive {:native_success_armed, ^hook, ^owner, _socket, armed, old}, @wait
    assert armed.streams[3] == old
    assert old.startup.token == old.token
    assert old.startup.parent_lease == context.parent_lease
    assert old.startup.deadline == old.deadline
    assert :ok = :sys.resume(context.gate, @wait)
    assert_receive {:native_success_retained, ^hook, ^owner, raw, ^armed, ^old}, @wait
    tag = [:alias | old.startup.request]
    assert {^tag, {:ok, worker, lease}} = raw
    {_socket, unchanged} = :sys.get_state(owner, @wait)
    assert unchanged.streams[3] == old
    assert unchanged.starting == 3
    %{raw: raw, worker: worker, lease: lease, old: old, state: armed}
  end

  defp assert_running_dispatch_wait!(context, receipt) do
    gate = :sys.get_state(context.gate, @wait)
    operation = Map.fetch!(gate.spawns, receipt.old.token)
    assert operation.phase == :running
    assert operation.owner == context.owner
    assert operation.parent_lease == context.parent_lease
    assert operation.worker == receipt.worker
    assert operation.lease == receipt.lease
    assert operation.deadline == receipt.old.deadline
    assert operation.from == nil and operation.activation == nil
    lease = Map.fetch!(gate.leases, receipt.lease)
    assert lease.pid == receipt.worker
    assert lease.bytes == receipt.old.startup.bytes
    assert lease.deadline == receipt.old.deadline
    assert lease.request_active and lease.drain_notify
    await_native_dispatch_wait(receipt.worker, context.owner, context.gate)
  end

  defp await_native_dispatch_wait(worker, owner, gate, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    assert Lifecycle.remaining(deadline) > 0, "activated child did not await real dispatch"

    case Process.info(worker, [:status, :current_function, :messages, :links, :monitors]) do
      [
        status: :waiting,
        current_function: {Gaoxy.HTTP.HTTP2.Stream, :run, 7},
        messages: [],
        links: links,
        monitors: monitors
      ] ->
        assert owner in links and gate in links
        assert {:process, owner} in monitors
        assert {:process, gate} in monitors
        :ok

      nil ->
        flunk("activated native child died before dispatch cut")

      _ ->
        await_native_dispatch_wait(worker, owner, gate, deadline)
    end
  end

  for stage <- [:pending_activation, :dispatch_wait, :endpoint_blocked] do
    @service_stop_stage stage
    @tag timeout: 15_000
    test "real service stop at #{stage} joins admitted worker and native listener" do
      service_stop_case(@service_stop_stage)
    end
  end

  defp service_stop_case(stage) do
    context = seeded()
    snapshot = service_stop_snapshot(context)
    token = make_ref()
    service_stop_telemetry(snapshot.service, token)
    {cut, hook} = service_stop_cut(context, stage, token)
    worker = cut.worker
    owner = context.owner
    monitors = Map.put(snapshot.monitors, worker, Process.monitor(worker))

    # These are all genuine, live original actors before the stop request.
    assert Process.alive?(worker)
    assert Process.alive?(owner) and Process.alive?(context.writer)
    refute_receive {:native_entered, ^worker, _, _}, 0

    observer = self()

    {stopper, stopper_monitor} =
      spawn_monitor(fn ->
        send(observer, {:service_stop_result, token, self(), Gaoxy.stop(context.server, @wait)})
      end)

    on_exit(fn ->
      # Failure cleanup only: release any retained original continuation, close
      # the fixture client, then let the pre-existing seeded cleanup own server.
      # A fallback kill is never counted as a successful service-stop assertion.
      send(context.gate, {:service_stop_release, token})
      safe_resume(context.gate)
      :gen_tcp.close(context.socket)
      if Process.alive?(stopper), do: Process.exit(stopper, :kill)
    end)

    assert_receive {:service_stop_draining, ^token, gate, draining}, @wait
    assert gate == context.gate
    assert draining.mode == :draining
    assert draining.drain_deadline > Lifecycle.now()

    case stage do
      :pending_activation ->
        # The genuine service drain was queued ahead of the retained actual
        # activation; Gate's next callback must deny it and join that child.
        assert cut.state.spawns[cut.stream_token].phase == :pending_activation

      :dispatch_wait ->
        # An accepted worker legitimately waits for its original dispatch/D.
        # The real client cancels its stream AFTER service drain began.
        # Without that cancellation this is not a graceful-finish test.
        assert_native_draining_dispatch_wait!(context, cut.receipt, draining.drain_deadline)
        service_stop_reset_and_join(context, worker, token, draining.drain_deadline)

      :endpoint_blocked ->
        # Drain must allow existing admitted work to finish; no forced cleanup
        # or timeout is accepted as a substitute for completing this response.
        assert Process.alive?(worker)
        send(worker, :finish)
        sent = assert_step(worker, :normal_response, :ok, cut.exchange.protocol_bytes)
        assert sent.response == :sent
        assert service_stop_response(context.socket, 3) == {"200", "complete"}
        send(worker, :return)
    end

    assert_receive {:service_stop_zero, ^token, gate, status, zero}, @wait
    assert gate == context.gate
    assert status.active == 0 and status.retained_bytes == 0 and status.cleanup_pending == 0
    assert zero.leases == %{} and zero.spawns == %{} and zero.cleanups == %{}
    assert zero.bytes == 0 and zero.mode == :draining

    # Service's actual lifecycle telemetry must classify this as completed;
    # :forced, timeout and cleanup_failed are rejected even if actors later die.
    assert_receive {:service_stop_outcome, ^token, service, :completed}, @wait
    assert service == snapshot.service
    assert_receive {:service_stop_result, ^token, ^stopper, :ok}, @wait
    assert_receive {:DOWN, ^stopper_monitor, :process, ^stopper, :normal}, @wait

    reasons = service_stop_joins(monitors)
    assert reasons[context.server] == :normal
    assert reasons[snapshot.service] == :normal
    assert reasons[snapshot.backend] == :normal
    assert reasons[context.owner] == {:shutdown, :local_closed}
    assert reasons[context.writer] == :normal
    # Orderly service disposal intentionally kills its now-empty Gate.
    assert reasons[context.gate] == :killed
    assert reasons[worker] == if(stage == :endpoint_blocked, do: :normal, else: :killed)
    for port <- snapshot.ports, do: assert(Port.info(port) == nil)
    assert Enum.all?(Map.keys(monitors), &(not Process.alive?(&1)))

    if stage != :endpoint_blocked do
      refute_receive {:native_entered, _, %{transport_state: {^owner, 3, _}}, _}, 0
    end

    # Bind exactly the prior native listener address, proving release of that
    # listener independently of process-monitor receipts or connection refusal.
    {ip, port} = snapshot.local

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    assert :ok = :gen_tcp.close(rebound)
    assert :ok = :gen_tcp.close(context.socket)
    refute_receive {:service_stop_zero, ^token, _, _, _}, 0
    # Hook lives only on the now genuinely joined Gate. No :sys call is made
    # against a dead actor; on_exit also releases it on earlier failures.
    assert is_reference(hook)
  end

  defp service_stop_reset_and_join(context, worker, token, drain_deadline) do
    observer = self()
    owner = context.owner
    monitor = Process.monitor(worker)
    hook = make_ref()
    deadline = min(Lifecycle.deadline(@wait), drain_deadline)
    release = {:service_stop_reset_release, token}

    # RST queues Gate cancellation asynchronously. Keep the native owner at its
    # genuine post-RST callback until that cancellation joins the child, before
    # the owner's already-queued local close can propagate through their link.
    assert :ok =
             :sys.install(
               owner,
               {hook,
                fn previous, event, _ ->
                  case event do
                    {:noreply,
                     {_socket, %{phase: :http2, draining: true, starting: nil, streams: streams}}}
                    when not is_map_key(streams, 3) ->
                      send(observer, {:service_stop_reset_cut, token, self()})

                      receive do
                        ^release -> :done
                      after
                        Lifecycle.remaining(deadline) -> exit(:service_stop_reset_join_timeout)
                      end

                    _ ->
                      previous
                  end
                end, nil},
               Lifecycle.remaining(deadline)
             )

    on_exit(fn ->
      send(owner, release)

      if Process.alive?(owner) do
        try do
          :sys.remove(owner, hook, 100)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    try do
      send_reset(context.socket, 3)
      assert_receive {:service_stop_reset_cut, ^token, ^owner}, Lifecycle.remaining(deadline)
      assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, Lifecycle.remaining(deadline)
    after
      send(owner, release)
    end
  end

  defp assert_native_draining_dispatch_wait!(context, receipt, drain_deadline) do
    state = :sys.get_state(context.gate, @wait)
    assert state.spawns[receipt.old.token].phase == :running
    assert state.leases[receipt.lease].pid == receipt.worker
    assert state.leases[receipt.lease].bytes == receipt.old.startup.bytes
    expected = {:gaoxy_drain, context.gate, receipt.lease, drain_deadline}
    await_native_drain_wait(receipt.worker, context.owner, context.gate, expected)
  end

  defp await_native_drain_wait(worker, owner, gate, expected, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)

    assert Lifecycle.remaining(deadline) > 0,
           "activated child did not retain its exact drain message"

    case Process.info(worker, [:status, :current_function, :messages, :links, :monitors]) do
      [
        status: :waiting,
        current_function: {Gaoxy.HTTP.HTTP2.Stream, :run, 7},
        messages: [^expected],
        links: links,
        monitors: monitors
      ] ->
        assert owner in links and gate in links
        assert {:process, owner} in monitors
        assert {:process, gate} in monitors
        :ok

      nil ->
        flunk("activated native child died before client cancellation")

      _ ->
        await_native_drain_wait(worker, owner, gate, expected, deadline)
    end
  end

  # Public :sys inspection of Gaoxy-owned state, not private backend APIs.
  defp service_stop_snapshot(context) do
    gate_state = :sys.get_state(context.gate, @wait)
    service = gate_state.service
    assert is_pid(service) and service != context.server
    service_state = :sys.get_state(service, @wait)
    assert service_state.gate == context.gate and service_state.mode == :ready
    backend = service_state.backend
    {:ok, local} = Gaoxy.info(context.server, :http).local

    pids =
      Enum.uniq([
        context.server,
        service,
        context.gate,
        context.owner,
        context.writer
        | Lifecycle.resources(backend, service)
      ])

    assert Enum.all?(pids, &Process.alive?/1)

    ports =
      for port <- Port.list(),
          Port.info(port, :name) == {:name, ~c"tcp_inet"},
          {:connected, pid} = Port.info(port, :connected),
          pid in pids,
          do: port

    # The accepted socket and original listening socket share local address;
    # the listener has a distinct controlling process from the native owner.
    assert Enum.any?(ports, fn port ->
             :inet.sockname(port) == {:ok, local} and
               Port.info(port, :connected) != {:connected, context.owner}
           end)

    %{
      service: service,
      backend: backend,
      local: local,
      ports: ports,
      monitors: Map.new(pids, &{&1, Process.monitor(&1)})
    }
  end

  defp service_stop_cut(context, :pending_activation, token) do
    hook = service_stop_gate_hook(context, token, true)
    send_headers(context.socket, 3, "/stop-pending", true)
    gate = context.gate

    assert_receive {:service_stop_committed, ^token, ^gate, stream_token, worker, lease, state},
                   @wait

    operation = state.spawns[stream_token]
    row = state.leases[lease]
    assert operation.phase == :pending_activation
    assert operation.owner == context.owner and operation.parent_lease == context.parent_lease
    assert operation.worker == worker and operation.lease == lease
    assert operation.deadline == row.deadline and Lifecycle.remaining(row.deadline) > 0
    assert row.pid == worker and row.request_active and row.drain_notify
    assert state.bytes == Enum.sum(Enum.map(state.leases, fn {_, v} -> v.bytes end))
    assert map_size(state.leases) == 3
    {%{worker: worker, lease: lease, stream_token: stream_token, state: state}, hook}
  end

  defp service_stop_cut(context, :dispatch_wait, token) do
    receipt = retain_native_success3(context)
    assert_running_dispatch_wait!(context, receipt)
    hook = service_stop_gate_hook(context, token, false)
    {%{worker: receipt.worker, receipt: receipt}, hook}
  end

  defp service_stop_cut(context, :endpoint_blocked, token) do
    send_headers(context.socket, 3, "/stop-endpoint", true)
    {worker, exchange} = entered(context, 3, context.payload)
    assert_owned_exact!(worker, exchange)
    hook = service_stop_gate_hook(context, token, false)
    {%{worker: worker, exchange: exchange}, hook}
  end

  defp service_stop_gate_hook(context, token, hold_activation) do
    observer = self()
    gate = context.gate
    owner = context.owner
    hook = make_ref()

    assert :ok =
             :sys.install(
               gate,
               {hook,
                fn acc, event, _ ->
                  acc =
                    case {acc.pending, event} do
                      {true, {:noreply, state}} ->
                        case Enum.find(state.spawns, fn {_, op} -> op.owner == owner end) do
                          {stream_token, %{phase: :pending_activation} = op} ->
                            # Retain ONLY the real self-continuation, never synthesize one.
                            activation =
                              receive do
                                {:activate_spawn, ^stream_token} = actual -> actual
                              after
                                @wait -> exit(:service_stop_actual_activation_missing)
                              end

                            send(
                              observer,
                              {:service_stop_committed, token, self(), stream_token, op.worker,
                               op.lease, state}
                            )

                            receive do
                              {:"$gen_call", _from, {:drain, _deadline}} = actual_drain ->
                                # Replay each authentic original once, with unchanged alias,
                                # owner, deadline and token. Drain now precedes activation.
                                send(self(), actual_drain)
                                send(self(), activation)

                              {:service_stop_release, ^token} ->
                                send(self(), activation)
                            after
                              @wait ->
                                send(self(), activation)
                                send(observer, {:service_stop_hold_timeout, token})
                            end

                            %{acc | pending: false}

                          nil ->
                            acc
                        end

                      _ ->
                        acc
                    end

                  acc =
                    case event do
                      {:out, :ok, _from, %{mode: :draining, drain_deadline: d} = state}
                      when is_integer(d) ->
                        if not acc.draining,
                          do: send(observer, {:service_stop_draining, token, self(), state})

                        %{acc | draining: true}

                      _ ->
                        acc
                    end

                  case event do
                    {:out, %{active: 0, retained_bytes: 0, cleanup_pending: 0} = status, _from,
                     state} ->
                      if not acc.zero,
                        do: send(observer, {:service_stop_zero, token, self(), status, state})

                      %{acc | zero: true}

                    _ ->
                      acc
                  end
                end, %{pending: hold_activation, draining: false, zero: false}},
               @wait
             )

    on_exit(fn ->
      send(gate, {:service_stop_release, token})

      if Process.alive?(gate) do
        try do
          :sys.remove(gate, hook, 100)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    hook
  end

  defp service_stop_telemetry(service, token) do
    observer = self()
    hook = {__MODULE__, token}

    assert :ok =
             :telemetry.attach(
               hook,
               [:gaoxy, :drain],
               fn _, _, meta, _ ->
                 if self() == service,
                   do: send(observer, {:service_stop_outcome, token, self(), meta.outcome})
               end,
               nil
             )

    on_exit(fn -> :telemetry.detach(hook) end)
  end

  defp service_stop_joins(monitors) do
    deadline = Lifecycle.deadline(@wait)

    Map.new(monitors, fn {pid, monitor} ->
      assert_receive {:DOWN, ^monitor, :process, ^pid, reason}, Lifecycle.remaining(deadline)
      refute reason == :noproc
      {pid, reason}
    end)
  end

  # Keep the existing responses/2 helper strict. This separate drain-response
  # reader accepts only successful GOAWAY plus the exact original response stream.
  defp service_stop_response(
         socket,
         id,
         status \\ nil,
         body \\ "",
         decoder \\ HPAX.new(4_096),
         deadline \\ nil
       ) do
    deadline = deadline || Lifecycle.deadline(@wait)

    case frame(socket, deadline) do
      {7, 0, 0, <<reserved::1, last::31, code::32, debug::binary>>} ->
        assert reserved == 0 and last == id and code == 0 and debug == ""
        service_stop_response(socket, id, status, body, decoder, deadline)

      {1, flags, ^id, bytes} ->
        assert Frame.flag?(flags, 4)
        {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
        {":status", status} = List.keyfind(fields, ":status", 0)

        if Frame.flag?(flags, 1),
          do: {status, body},
          else: service_stop_response(socket, id, status, body, decoder, deadline)

      {0, flags, ^id, bytes} ->
        if Frame.flag?(flags, 1),
          do: {status, body <> bytes},
          else: service_stop_response(socket, id, status, body <> bytes, decoder, deadline)

      other ->
        control(socket, other)
        service_stop_response(socket, id, status, body, decoder, deadline)
    end
  end

  defp payload, do: :binary.copy(<<0, 1, 254, 255>>, 32_769)

  defp seeded(budget \\ @large_budget, initialized_payload \\ nil) do
    initialized_payload = initialized_payload || payload()
    endpoint = {Endpoint, %{observer: self(), payload: initialized_payload}}

    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: endpoint,
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: budget, max_active: 128},
        http_limits: %{request_timeout: 15_000}
      )

    on_exit(fn ->
      if Process.alive?(server) do
        try do
          Gaoxy.stop(server, @wait)
        catch
          :exit, _ -> Process.exit(server, :kill)
        end
      end
    end)

    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @wait)
    on_exit(fn -> :gen_tcp.close(socket) end)

    assert :ok =
             :gen_tcp.send(
               socket,
               ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")]
             )

    send_headers(socket, 1, "/seed", true)
    assert_receive {:native_seed, {owner, 1, _}, gate}, @wait
    on_exit(fn -> safe_resume(gate) end)
    assert responses(socket, [1]) == %{1 => %{status: "200", body: "seed"}}
    await_owner(owner, fn state -> map_size(state.streams) == 0 and state.starting == nil end)

    # Isolate worker admission from decoder admission. Decoding a valid block on
    # the closed seed stream grows the reserve without admitting a large-header
    # worker, which would distort the tests' exact worker-capacity boundary.
    padding = String.duplicate("a", 16_300)

    seed_fields = [
      {":method", "GET"},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", "/seed"},
      {"x-precharge", padding}
    ]

    {seed, _} = HPAX.encode(:never_store, seed_fields, HPAX.new(4_096))
    padding = padding <> String.duplicate("a", 16_384 - IO.iodata_length(seed))

    {seed, _} =
      HPAX.encode(
        :never_store,
        List.keyreplace(seed_fields, "x-precharge", 0, {"x-precharge", padding}),
        HPAX.new(4_096)
      )

    assert IO.iodata_length(seed) == 16_384
    assert :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 1, seed))
    assert_reset(socket, 1, :stream_closed)

    state =
      await_owner(owner, fn state ->
        map_size(state.streams) == 0 and state.starting == nil and
          state.inflight == nil and :queue.is_empty(state.output)
      end)

    context = %{
      server: server,
      socket: socket,
      owner: owner,
      gate: gate,
      writer: state.writer,
      parent_lease: state.lease,
      payload: initialized_payload
    }

    await_baseline(
      context,
      state.reserves.connection + state.decode_reservation + state.reserves.writer
    )

    context
  end

  defp connection_baseline!(context) do
    {_socket, state} = :sys.get_state(context.owner, @wait)
    connection = state.reserves.connection + state.decode_reservation
    expected = connection + state.reserves.writer
    gate = :sys.get_state(context.gate, @wait)
    assert map_size(gate.leases) == 2
    assert gate.leases[state.lease].pid == context.owner
    assert gate.leases[state.lease].bytes == connection

    writer =
      Enum.find_value(gate.leases, fn {_, row} ->
        if row.pid == context.writer, do: row
      end)

    assert writer.bytes == state.reserves.writer
    assert gate.bytes == expected
    assert %{active: 2, retained_bytes: ^expected} = Admission.status(context.gate)
    expected
  end

  defp await_startup(context, id) do
    state =
      await_owner(context.owner, fn state ->
        state.starting == id and
          match?(
            %{worker: nil, lease: nil, startup: %{request: request}} when is_reference(request),
            state.streams[id]
          )
      end)

    {state, state.streams[id]}
  end

  defp entered(context, id, expected_payload) do
    owner = context.owner

    assert_receive {:native_entered, worker, %{transport_state: {^owner, ^id, _}} = exchange,
                    received},
                   @wait

    assert received == expected_payload
    assert :crypto.hash(:sha256, received) == :crypto.hash(:sha256, expected_payload)
    assert exchange.gate == context.gate
    {worker, exchange}
  end

  defp assert_owned_exact!(worker, exchange) do
    gate = :sys.get_state(exchange.gate, @wait)
    lease = Map.fetch!(gate.leases, exchange.lease)
    assert lease.pid == worker
    assert lease.deadline == exchange.deadline
    assert lease.request_active and lease.drain_notify
    assert lease.bytes == Exchange.retained_bytes(exchange)
    assert lease.bytes >= exchange.protocol_bytes + 2 * exchange.request.head_bytes
  end

  defp assert_step(worker, phase, result, n) do
    assert_receive {:native_step, ^worker, ^phase, ^result, exchange}, @wait
    assert exchange.protocol_bytes == n
    assert Process.alive?(worker)
    exchange
  end

  defp normal_response(context, worker, exchange) do
    {_, id, _} = exchange.transport_state
    send(worker, :finish)
    sent = assert_step(worker, :normal_response, :ok, exchange.protocol_bytes)
    assert sent.response == :sent
    assert_owned_exact!(worker, sent)
    assert responses(context.socket, [id]) == %{id => %{status: "200", body: "complete"}}
    return_and_join(worker)
  end

  defp return_and_join(worker) do
    ref = Process.monitor(worker)
    send(worker, :return)
    assert_receive {:DOWN, ^ref, :process, ^worker, :normal}, @wait
  end

  defp send_headers(socket, id, path, ended, extra \\ [], method \\ "GET") do
    fields =
      [{":method", method}, {":scheme", "http"}, {":authority", "localhost"}, {":path", path}] ++
        extra

    {block, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))
    assert :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
  end

  defp send_trailers(socket, id, trailers) do
    {block, _} = HPAX.encode(:never_store, trailers, HPAX.new(4_096))
    assert :ok = :gen_tcp.send(socket, Frame.encode(1, 5, id, block))
  end

  defp send_reset(socket, id),
    do: assert(:ok == :gen_tcp.send(socket, Frame.encode(3, 0, id, <<Frame.code(:cancel)::32>>)))

  defp frame(socket, deadline) do
    assert Lifecycle.remaining(deadline) > 0, "native wire deadline exceeded"

    assert {:ok, <<size::24, type, flags, _::1, id::31>>} =
             :gen_tcp.recv(socket, 9, Lifecycle.remaining(deadline))

    bytes =
      if size == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, size, Lifecycle.remaining(deadline))
        bytes
      end

    {type, flags, id, bytes}
  end

  defp control(socket, {4, flags, 0, bytes}) do
    assert bytes == "" or not Frame.flag?(flags, 1)

    unless Frame.flag?(flags, 1),
      do: assert(:ok == :gen_tcp.send(socket, Frame.encode(4, 1, 0, "")))

    :ok
  end

  defp control(_socket, {8, _, _, <<_::32>>}), do: :ok
  defp control(_socket, event), do: flunk("unexpected native frame #{inspect(event)}")

  defp assert_ping(socket, payload, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)

    case frame(socket, deadline) do
      {6, flags, 0, ^payload} ->
        assert Frame.flag?(flags, 1)

      other ->
        control(socket, other)
        assert_ping(socket, payload, deadline)
    end
  end

  defp assert_reset(socket, id, reason, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)

    case frame(socket, deadline) do
      {3, _, ^id, <<code::32>>} ->
        assert code == Frame.code(reason)

      {type, flags, ^id, _} when type in [0, 1] ->
        refute Frame.flag?(flags, 1), "successful END_STREAM before expected RST"
        assert_reset(socket, id, reason, deadline)

      other ->
        control(socket, other)
        assert_reset(socket, id, reason, deadline)
    end
  end

  defp responses(socket, ids) do
    collect(
      socket,
      Map.new(ids, &{&1, %{status: nil, body: ""}}),
      ids,
      HPAX.new(4_096),
      Lifecycle.deadline(@wait)
    )
  end

  defp collect(_socket, results, [], _decoder, _deadline), do: results

  defp collect(socket, results, remaining, decoder, deadline) do
    case frame(socket, deadline) do
      {1, flags, id, bytes} when is_map_key(results, id) ->
        assert Frame.flag?(flags, 4)
        {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
        {":status", status} = List.keyfind(fields, ":status", 0)
        results = put_in(results[id].status, status)
        remaining = if Frame.flag?(flags, 1), do: List.delete(remaining, id), else: remaining
        collect(socket, results, remaining, decoder, deadline)

      {0, flags, id, bytes} when is_map_key(results, id) ->
        results = update_in(results[id].body, &(&1 <> bytes))
        remaining = if Frame.flag?(flags, 1), do: List.delete(remaining, id), else: remaining
        collect(socket, results, remaining, decoder, deadline)

      other ->
        control(socket, other)
        collect(socket, results, remaining, decoder, deadline)
    end
  end

  defp read_partial(
         socket,
         id,
         status \\ nil,
         body \\ "",
         decoder \\ HPAX.new(4_096),
         deadline \\ nil
       ) do
    deadline = deadline || Lifecycle.deadline(@wait)

    case frame(socket, deadline) do
      {1, flags, ^id, bytes} ->
        refute Frame.flag?(flags, 1)
        assert Frame.flag?(flags, 4)
        {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
        {":status", status} = List.keyfind(fields, ":status", 0)
        read_partial(socket, id, status, body, decoder, deadline)

      {0, flags, ^id, bytes} ->
        refute Frame.flag?(flags, 1)
        next = body <> bytes

        if next == "partial",
          do: %{status: status, body: next},
          else: read_partial(socket, id, status, next, decoder, deadline)

      other ->
        control(socket, other)
        read_partial(socket, id, status, body, decoder, deadline)
    end
  end

  defp await_owner(owner, predicate, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    assert Lifecycle.remaining(deadline) > 0, "native owner deadline exceeded"
    {_socket, state} = :sys.get_state(owner, Lifecycle.remaining(deadline))

    if predicate.(state) do
      state
    else
      assert Lifecycle.remaining(deadline) > 0, "native owner did not reach exact state barrier"
      await_owner(owner, predicate, deadline)
    end
  end

  defp await_baseline(context, bytes), do: await_gate(context.gate, 2, bytes)
  defp await_gate_zero(gate), do: await_gate(gate, 0, 0)

  defp await_gate(gate, active, bytes, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    assert Lifecycle.remaining(deadline) > 0, "Gate accounting deadline exceeded"

    case GenServer.call(gate, :status, Lifecycle.remaining(deadline)) do
      %{active: ^active, retained_bytes: ^bytes, cleanup_pending: 0} ->
        :ok

      _ ->
        assert Lifecycle.remaining(deadline) > 0, "Gate did not reach exact accounting barrier"
        await_gate(gate, active, bytes, deadline)
    end
  end

  defp close_clean(context) do
    owner_monitor = Process.monitor(context.owner)
    writer_monitor = Process.monitor(context.writer)
    :ok = :gen_tcp.close(context.socket)

    assert_receive {:DOWN, ^owner_monitor, :process, owner, _}
                   when owner == context.owner,
                   @wait

    assert_receive {:DOWN, ^writer_monitor, :process, writer, _}
                   when writer == context.writer,
                   @wait

    await_gate_zero(context.gate)
    stop_clean(context.server)
  end

  defp stop_clean(server) do
    monitor = Process.monitor(server)
    assert :ok = Gaoxy.stop(server, @wait)
    assert_receive {:DOWN, ^monitor, :process, ^server, :normal}, @wait
  end

  defp safe_resume(gate) do
    if Process.alive?(gate), do: :sys.resume(gate, 100)
  catch
    :exit, _ -> :ok
  end

  defp trace_spawns(gate),
    do: assert(1 == :erlang.trace(gate, true, [:procs, {:tracer, self()}]))

  defp trace_flush(gate) do
    ref = :erlang.trace_delivered(gate)
    assert_receive {:trace_delivered, ^gate, ^ref}, @wait
  end
end

defmodule Gaoxy.HTTP2StartupMetadataTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Admission
  alias Gaoxy.HTTP.Connection
  @wait 3_000

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:unexpected_startup_endpoint, self()})
      {:error, :unexpected_startup_endpoint, exchange}
    end
  end

  defmodule TLSBarrier do
    @wait 3_000
    def secure?, do: true

    def negotiated_protocol({native, owner, token}) do
      actual = :ssl.negotiated_protocol(native)
      send(owner, {:startup_alpn, self(), token, actual})

      receive do
        {:observe_peer_close, ^token} ->
          closed = :ssl.recv(native, 0, @wait)
          peer = :ssl.peername(native)
          send(owner, {:startup_tls_closed, self(), token, closed, peer})
      after
        @wait -> raise "startup peer-close observation deadline"
      end

      receive do
        {:resume_alpn, ^token} -> actual
      after
        @wait -> raise "startup ALPN release deadline"
      end
    end

    def peername({native, owner, token}) do
      actual = :ssl.peername(native)
      send(owner, {:startup_peername, self(), token, actual})
      actual
    end

    def sockname({native, _, _}), do: :ssl.sockname(native)
    def connection_information({native, _, _}), do: :ssl.connection_information(native)
    def peercert({native, _, _}), do: :ssl.peercert(native)
    def setopts({native, _, _}, options), do: :ssl.setopts(native, options)
    def getstat({native, _, _}), do: :ssl.getstat(native)
    def close({native, _, _}), do: :ssl.close(native)
  end

  defmodule CloseAfterPeername do
    def secure?, do: false

    def peername({native, owner}) do
      actual = :inet.peername(native)
      send(owner, {:startup_open_peername, actual})
      :ok = :gen_tcp.close(native)
      actual
    end

    def sockname({native, owner}) do
      actual = :inet.sockname(native)
      send(owner, {:startup_closed_sockname, actual})
      actual
    end
  end

  test "closed real TCP metadata ends startup without admission" do
    {native, _client} = tcp_pair()
    assert :ok = :gen_tcp.close(native)
    assert {:error, :einval} = :inet.peername(native)
    {context, hook} = context([])
    socket = socket(native, Hell.Transports.TCP)
    assert {:close, ^context} = Connection.handle_connection(socket, context)
    assert_no_admission(context.gate, hook)
  end

  test "real socket closure after peername handles sockname failure without admission" do
    {native, _client} = tcp_pair()
    {context, hook} = context([])
    socket = socket({native, self()}, CloseAfterPeername)
    assert {:close, ^context} = Connection.handle_connection(socket, context)
    assert_receive {:startup_open_peername, {:ok, {{127, 0, 0, 1}, port}}}, @wait
    assert port > 0
    assert_receive {:startup_closed_sockname, {:error, :einval}}, @wait
    assert_no_admission(context.gate, hook)
  end

  @tag :tmp_dir
  test "real TLS peer closes after actual h2 ALPN and generated startup ends orderly", %{
    tmp_dir: dir
  } do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, dir], stderr_to_stdout: true)
    cert = Path.join(dir, "cert.pem")
    key = Path.join(dir, "key.pem")

    {context, hook} =
      context(transport: :tls, tls: %{certfile: cert, keyfile: key}, h2c: :disabled)

    {:ok, listener} =
      :ssl.listen(0, [
        :binary,
        active: false,
        reuseaddr: true,
        ip: {127, 0, 0, 1},
        certfile: String.to_charlist(cert),
        keyfile: String.to_charlist(key),
        alpn_preferred_protocols: ["h2"]
      ])

    on_exit(fn -> :ssl.close(listener) end)
    {:ok, {_, port}} = :ssl.sockname(listener)
    owner = self()
    token = make_ref()

    {worker, monitor} =
      spawn_monitor(fn ->
        {:ok, accepted} = :ssl.transport_accept(listener, @wait)
        {:ok, native} = :ssl.handshake(accepted, @wait)
        socket = socket({native, owner, token}, TLSBarrier)

        try do
          result = Connection.handle_continue(:handle_connection, {socket, context})
          send(owner, {:startup_continuation, self(), token, result})

          case result do
            {:stop, reason, {^socket, ^context}} ->
              Connection.terminate(reason, {socket, context})

            _ ->
              :ok
          end
        after
          :ssl.close(native)
        end
      end)

    on_exit(fn -> stop_owned_worker(worker) end)

    {:ok, client} =
      :ssl.connect(
        {127, 0, 0, 1},
        port,
        [
          :binary,
          active: false,
          verify: :verify_peer,
          cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
          server_name_indication: ~c"localhost",
          alpn_advertised_protocols: ["h2"]
        ],
        @wait
      )

    on_exit(fn -> :ssl.close(client) end)
    assert {:ok, "h2"} = :ssl.negotiated_protocol(client)
    assert_receive {:startup_alpn, ^worker, ^token, {:ok, "h2"}}, @wait
    assert :ok = :ssl.close(client, @wait)
    send(worker, {:observe_peer_close, token})

    assert_receive {:startup_tls_closed, ^worker, ^token, {:error, :closed}, {:error, reason}},
                   @wait

    assert reason in [:closed, :einval, :enotconn]
    send(worker, {:resume_alpn, token})
    assert_receive {:DOWN, ^monitor, :process, ^worker, terminal}, @wait
    assert terminal == :normal
    assert_receive {:startup_peername, ^worker, ^token, {:error, actual}}, @wait
    assert actual in [:closed, :einval, :enotconn]

    assert_receive {:startup_continuation, ^worker, ^token,
                    {:stop, {:shutdown, :local_closed}, {_socket, ^context}}},
                   @wait

    assert_no_admission(context.gate, hook)
  end

  defp context(extra) do
    options =
      Keyword.merge(
        [
          endpoint: {Endpoint, self()},
          protocols: [:http2],
          h2c: :prior_knowledge,
          limits: %{max_bytes: 536_870_912}
        ],
        extra
      )

    {:ok, spec} = Gaoxy.HTTP.service_spec(options)

    gate =
      start_supervised!({Admission, {spec.limits, %{instance: make_ref(), service: :metadata}}})

    owner = self()
    hook = make_ref()

    :ok =
      :sys.install(
        gate,
        {hook,
         fn previous, event, _ ->
           case event do
             {:in, {:"$gen_call", _, {:acquire, _, _}}} -> send(owner, {:startup_acquire, hook})
             _ -> :ok
           end

           previous
         end, nil},
        @wait
      )

    {%{spec: spec, gate: gate}, hook}
  end

  defp socket(native, transport) do
    struct!(Hell.Socket,
      socket: native,
      transport_module: transport,
      read_timeout: @wait,
      handshake_timeout: @wait,
      silent_terminate_on_error: false,
      span: Hell.Telemetry.start_span(:connection, %{}, %{handler: Connection})
    )
  end

  defp tcp_pair do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, {_, port}} = :inet.sockname(listener)
    {:ok, client} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], @wait)
    on_exit(fn -> :gen_tcp.close(client) end)
    {:ok, native} = :gen_tcp.accept(listener, @wait)
    on_exit(fn -> :gen_tcp.close(native) end)
    {native, client}
  end

  defp assert_no_admission(gate, hook) do
    # Same-Gate reply follows any debug notification sent before that callback.
    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0} = Admission.status(gate)
    refute_receive {:startup_acquire, ^hook}, 0
    refute_receive {:unexpected_startup_endpoint, _}, 0
  end

  defp stop_owned_worker(worker) do
    monitor = Process.monitor(worker)
    if Process.alive?(worker), do: Process.exit(worker, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^worker, _} -> :ok
    after
      @wait -> raise "owned metadata fixture cleanup join deadline"
    end
  end
end
