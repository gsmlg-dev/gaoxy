# SOURCE-ONLY PROPOSAL. Insert into HTTP2WorkerStartupExtendedTest.
# Reuses seeded/0, entered/3, assert_step/4, frame/2, control/2 and other
# existing finite helpers. Also requires the other proposal's already integrated
# retain_native_success3/1 and assert_running_dispatch_wait!/2.
# No existing assertion/helper is replaced. No production change is proposed.

for stage <- [:pending_activation, :dispatch_wait, :endpoint_blocked] do
  @tag timeout: 15_000
  test "real service stop at #{stage} joins admitted worker and native listener" do
    context = seeded()
    stage = unquote(stage)
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
        assert_running_dispatch_wait!(context, cut.receipt)
        send_reset(context.socket, 3)

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
    assert {:ok, rebound} = :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])
    assert :ok = :gen_tcp.close(rebound)
    assert :ok = :gen_tcp.close(context.socket)
    refute_receive {:service_stop_zero, ^token, _, _, _}, 0
    # Hook lives only on the now genuinely joined Gate. No :sys call is made
    # against a dead actor; on_exit also releases it on earlier failures.
    assert is_reference(hook)
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
  local = Gaoxy.info(context.server, :http).local
  pids = Enum.uniq([context.server, service, context.gate, context.owner, context.writer |
                    Lifecycle.resources(backend, service)])
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
  %{service: service, backend: backend, local: local, ports: ports,
    monitors: Map.new(pids, &{&1, Process.monitor(&1)})}
end

defp service_stop_cut(context, :pending_activation, token) do
  hook = service_stop_gate_hook(context, token, true)
  send_headers(context.socket, 3, "/stop-pending", true)
  gate = context.gate
  assert_receive {:service_stop_committed, ^token, ^gate, stream_token, worker, lease, state}, @wait
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

  assert :ok = :sys.install(gate, {hook,
    fn acc, event, _ ->
      acc =
        case {acc.pending, event} do
          {true, {:noreply, state}} ->
            case Enum.find(state.spawns, fn {_, op} -> op.owner == owner end) do
              {stream_token, %{phase: :pending_activation} = op} ->
                # Retain ONLY the real self-continuation, never synthesize one.
                activation = receive do
                  {:activate_spawn, ^stream_token} = actual -> actual
                after
                  @wait -> exit(:service_stop_actual_activation_missing)
                end
                send(observer, {:service_stop_committed, token, self(), stream_token,
                                op.worker, op.lease, state})
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
              nil -> acc
            end
          _ -> acc
        end

      acc = case event do
        {:out, :ok, _from, %{mode: :draining, drain_deadline: d} = state}
        when is_integer(d) ->
          if not acc.draining, do: send(observer, {:service_stop_draining, token, self(), state})
          %{acc | draining: true}
        _ -> acc
      end

      case event do
        {:out, %{active: 0, retained_bytes: 0, cleanup_pending: 0} = status, _from, state} ->
          if not acc.zero, do: send(observer, {:service_stop_zero, token, self(), status, state})
          %{acc | zero: true}
        _ -> acc
      end
    end, %{pending: hold_activation, draining: false, zero: false}}, @wait)

  on_exit(fn ->
    send(gate, {:service_stop_release, token})
    if Process.alive?(gate) do
      try do :sys.remove(gate, hook, 100) catch :exit, _ -> :ok end
    end
  end)
  hook
end

defp service_stop_telemetry(service, token) do
  observer = self()
  hook = {__MODULE__, token}
  assert :ok = :telemetry.attach(hook, [:gaoxy, :drain], fn _, _, meta, _ ->
    if self() == service, do: send(observer, {:service_stop_outcome, token, self(), meta.outcome})
  end, nil)
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
defp service_stop_response(socket, id, status \\ nil, body \\ "",
                           decoder \\ HPAX.new(4_096), deadline \\ nil) do
  deadline = deadline || Lifecycle.deadline(@wait)
  case frame(socket, deadline) do
    {7, 0, 0, <<reserved::1, last::31, code::32, debug::binary>>} ->
      assert reserved == 0 and last == id and code == 0 and debug == ""
      service_stop_response(socket, id, status, body, decoder, deadline)
    {1, flags, ^id, bytes} ->
      assert Frame.flag?(flags, 4)
      {:ok, fields, decoder} = HPAX.decode(bytes, decoder)
      {":status", status} = List.keyfind(fields, ":status", 0)
      if Frame.flag?(flags, 1), do: {status, body},
        else: service_stop_response(socket, id, status, body, decoder, deadline)
    {0, flags, ^id, bytes} ->
      if Frame.flag?(flags, 1), do: {status, body <> bytes},
        else: service_stop_response(socket, id, status, body <> bytes, decoder, deadline)
    other ->
      control(socket, other)
      service_stop_response(socket, id, status, body, decoder, deadline)
  end
end
