# PROPOSAL ONLY: insert these tests/helpers into HTTP2WorkerStartupExtendedTest.
# Not standalone; deliberately reuses its real h2c fixtures and finite helpers.
# Keep all existing stale-failure, sibling, full-response and cleanup tests.
# No synthetic {:ok, worker, lease}: replay only the retained genuine raw term.

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
          match?(%{worker: nil, lease: nil, monitor: nil, startup: %{request: _}}, state.streams[5]) and
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
  @tag :controlled_late_receipt
  test "native owner #{mode} death after activation before success handling joins child" do
    assert_accounting_api!()
    context = seeded()
    mode = unquote(mode)

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
                      %{worker: nil, lease: nil, monitor: nil,
                        startup: %{request: request}} = old when is_reference(request) ->
                        tag = [:alias | request]
                        send(observer, {:native_success_armed, hook, self(), socket, state, old})

                        receive do
                          {^tag, {:ok, worker, lease}} = raw
                          when is_pid(worker) and is_reference(lease) ->
                            send(observer, {:native_success_retained, hook, self(), raw, state, old})
                        after
                          @wait -> send(observer, {:native_success_capture_timeout, hook})
                        end

                        :done

                      _ -> previous
                    end

                  _ -> previous
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
    [status: :waiting, current_function: {Gaoxy.HTTP.HTTP2.Stream, :run, 7},
     messages: [], links: links, monitors: monitors] ->
      assert owner in links and gate in links
      assert {:process, owner} in monitors
      assert {:process, gate} in monitors
      :ok

    nil -> flunk("activated native child died before dispatch cut")
    _ -> await_native_dispatch_wait(worker, owner, gate, deadline)
  end
end
