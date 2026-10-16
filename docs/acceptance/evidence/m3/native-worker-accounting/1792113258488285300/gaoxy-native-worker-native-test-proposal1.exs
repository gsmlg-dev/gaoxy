# SOURCE-ONLY extension proposal; not installed, parsed, compiled or executed.
# Preserve root's HTTP2WorkerStartupTest old-source regression in full.
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
        :read ->
          case Exchange.read_body_step(exchange, 16_384, 1_000) do
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
    assert n > state.reserves.stream + :erlang.external_size({Endpoint,
      %{observer: self(), payload: payload}})
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
        refute_receive {:trace, gate, :spawn, _, _} when gate == context.gate, 0
        refute_receive {:native_entered, _, %{transport_state: {owner, 3, _}}, _}
          when owner == context.owner, 0
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
      assert_receive {:trace, ^owner, :send,
        {:h2_write, ^owner, _operation, ^ack, _deadline}, ^writer}, @wait
      # Writer itself is blocked at Admission.start_send while Gate is paused.
      # This asserts real native parsing/enqueue, not an impossible wire ACK.
      send_reset(context.socket, 3)
      send_headers(context.socket, 5, "/sibling", true)
      current = await_owner(owner, fn state ->
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
      before = await_owner(context.owner, fn state ->
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
        7 => %{status: "200", body: "complete"}}
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
        match?(%{worker: nil, lease: nil, eof: true, trailers: ^trailers,
                 startup: %{request: _}}, state.streams[3])
      end)
      assert :ok = :sys.resume(context.gate, @wait)
      {worker, initial} = entered(context, 3, context.payload)
      assert not Exchange.body_complete?(initial)
      assert Exchange.request_trailers(initial) == []
      assert_owned_exact!(worker, initial)
      send(worker, :read)
      returned = assert_step(worker, :read, {:ok, ""}, initial.protocol_bytes)
      assert Exchange.body_complete?(returned)
      assert Exchange.request_trailers(returned) == trailers
      assert returned.body.trailer_bytes == Gaoxy.HTTP.HTTP2.Headers.bytes(trailers)
      # Deliberately exact: current transport restores old Exchange bytes before
      # constructing returned trailers. Preserve this assertion if it exposes
      # that necessary post-read compatibility repair.
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

  test "full N remains exactly charged through read poll validation error and normal response" do
    assert_accounting_api!()
    context = seeded()
    baseline = connection_baseline!(context)
    send_headers(context.socket, 3, "/body", false, [{"content-length", "5"}], "POST")
    {worker, initial} = entered(context, 3, context.payload)
    assert_owned_exact!(worker, initial)
    assert :ok = :gen_tcp.send(context.socket, Frame.encode(0, 1, 3, "hello"))
    await_owner(context.owner, &match?(%{received: 5, eof: true}, &1.streams[3]))
    send(worker, :read)
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
        when owner == context.owner, @wait
      assert_receive {:DOWN, ^writer_monitor, :process, writer, _}
        when writer == context.writer, @wait
      assert :ok = :sys.resume(context.gate, @wait)
      await_gate_zero(context.gate)
      trace_flush(context.gate)
      refute_receive {:trace, gate, :spawn, _, _} when gate == context.gate, 0
      refute_receive {:native_entered, _, %{transport_state: {owner, 3, _}}, _}
        when owner == context.owner, 0
      stop_clean(context.server)
    after
      safe_resume(context.gate)
    end
  end

  defp assert_accounting_api! do
    assert Code.ensure_loaded?(WorkerAccounting)
    assert function_exported?(WorkerAccounting, :reservation, 2)
  end

  defp payload, do: :binary.copy(<<0, 1, 254, 255>>, 32_769)

  defp seeded(budget \\ @large_budget, initialized_payload \\ nil) do
    initialized_payload = initialized_payload || payload()
    endpoint = {Endpoint, %{observer: self(), payload: initialized_payload}}
    {:ok, server} = Gaoxy.HTTP.start_link(endpoint: endpoint,
      protocols: [:http2], h2c: :prior_knowledge,
      limits: %{max_bytes: budget, max_active: 128},
      http_limits: %{request_timeout: 15_000})
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
    assert :ok = :gen_tcp.send(socket,
      ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    send_headers(socket, 1, "/seed", true)
    assert_receive {:native_seed, {owner, 1, _}, gate}, @wait
    on_exit(fn -> safe_resume(gate) end)
    assert responses(socket, [1]) == %{1 => %{status: "200", body: "seed"}}
    state = await_owner(owner, fn state ->
      map_size(state.streams) == 0 and state.starting == nil and
        state.inflight == nil and :queue.is_empty(state.output)
    end)
    context = %{server: server, socket: socket, owner: owner, gate: gate,
      writer: state.writer, parent_lease: state.lease, payload: initialized_payload}
    await_baseline(context, state.reserves.connection + state.reserves.writer)
    context
  end

  defp connection_baseline!(context) do
    {_socket, state} = :sys.get_state(context.owner, @wait)
    expected = state.reserves.connection + state.reserves.writer
    gate = :sys.get_state(context.gate, @wait)
    assert map_size(gate.leases) == 2
    assert gate.leases[state.lease].pid == context.owner
    assert gate.leases[state.lease].bytes == state.reserves.connection
    writer = Enum.find_value(gate.leases, fn {_, row} ->
      if row.pid == context.writer, do: row
    end)
    assert writer.bytes == state.reserves.writer
    assert gate.bytes == expected
    assert %{active: 2, retained_bytes: ^expected} = Admission.status(context.gate)
    expected
  end

  defp await_startup(context, id) do
    state = await_owner(context.owner, fn state ->
      state.starting == id and match?(%{worker: nil, lease: nil,
        startup: %{request: request}} when is_reference(request), state.streams[id])
    end)
    {state, state.streams[id]}
  end

  defp entered(context, id, expected_payload) do
    owner = context.owner
    assert_receive {:native_entered, worker,
      %{transport_state: {^owner, ^id, _}} = exchange, received}, @wait
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
    fields = [{":method", method}, {":scheme", "http"},
      {":authority", "localhost"}, {":path", path}] ++ extra
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
    bytes = if size == 0 do
      ""
    else
      assert {:ok, bytes} = :gen_tcp.recv(socket, size, Lifecycle.remaining(deadline))
      bytes
    end
    {type, flags, id, bytes}
  end

  defp control(socket, {4, flags, 0, bytes}) do
    assert bytes == "" or not Frame.flag?(flags, 1)
    unless Frame.flag?(flags, 1), do: assert(:ok == :gen_tcp.send(socket, Frame.encode(4, 1, 0, "")))
    :ok
  end
  defp control(_socket, {8, _, _, <<_::32>>}), do: :ok
  defp control(_socket, event), do: flunk("unexpected native frame #{inspect(event)}")

  defp assert_ping(socket, payload, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    case frame(socket, deadline) do
      {6, flags, 0, ^payload} -> assert Frame.flag?(flags, 1)
      other -> control(socket, other); assert_ping(socket, payload, deadline)
    end
  end

  defp assert_reset(socket, id, reason, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@wait)
    case frame(socket, deadline) do
      {3, _, ^id, <<code::32>>} -> assert code == Frame.code(reason)
      {type, flags, ^id, _} when type in [0, 1] ->
        refute Frame.flag?(flags, 1), "successful END_STREAM before expected RST"
        assert_reset(socket, id, reason, deadline)
      other -> control(socket, other); assert_reset(socket, id, reason, deadline)
    end
  end

  defp responses(socket, ids) do
    collect(socket, Map.new(ids, &{&1, %{status: nil, body: ""}}), ids,
      HPAX.new(4_096), Lifecycle.deadline(@wait))
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
      other -> control(socket, other); collect(socket, results, remaining, decoder, deadline)
    end
  end

  defp read_partial(socket, id, status \\ nil, body \\ "", decoder \\ HPAX.new(4_096),
         deadline \\ nil) do
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
        if next == "partial", do: %{status: status, body: next},
          else: read_partial(socket, id, status, next, decoder, deadline)
      other -> control(socket, other); read_partial(socket, id, status, body, decoder, deadline)
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
      %{active: ^active, retained_bytes: ^bytes, cleanup_pending: 0} -> :ok
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
      when owner == context.owner, @wait
    assert_receive {:DOWN, ^writer_monitor, :process, writer, _}
      when writer == context.writer, @wait
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
