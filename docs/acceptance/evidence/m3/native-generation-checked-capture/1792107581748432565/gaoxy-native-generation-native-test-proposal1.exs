defmodule Gaoxy.Proxy.ManagedGenerationCheckedNativeTest do
  use ExUnit.Case, async: false

  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Generation, Resources, Router}
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedGenerationAccounting, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @moduletag :capture_log
  @timeout 5_000
  @fixture_timeout 30_000
  @m 1_048_576
  @h 65_536

  # A test Router boundary around a genuine H1 GroupEndpoint. The listener's
  # endpoint is directly the production checked Generation seam.
  defmodule CapturedEndpoint do
    def init({group, parent, label}) do
      with {:ok, config} <- GroupEndpoint.init(%{group: group}),
        do: {:ok, {config, parent, label}}
    end

    def resources({config, _, _}), do: GroupEndpoint.resources(config)

    def call(exchange, {config, parent, label}) do
      token = make_ref()
      send(parent, {:checked_native_capture, self(), token, label, exchange})
      receive do
        {:checked_dispatch, ^token} -> GroupEndpoint.call(exchange, config)
      after
        min(10_000, Lifecycle.remaining(exchange.deadline)) ->
          {:error, :checked_native_fixture_barrier_expired, exchange}
      end
    end
  end

  # Supported test endpoint manifest, used only by direct checked Store tests.
  # Its resource list is exactly public owner handles; it never creates a pin.
  defmodule ManifestEndpoint do
    def init({handles, parent}), do: {:ok, {handles, parent}}
    def resources({handles, _}), do: handles
    def call(exchange, {_, parent}) do
      send(parent, {:unexpected_checked_manifest_dispatch, self()})
      {:ok, exchange}
    end
  end

  @tag :checked_capture_constructor
  test "checked Store returns genuine public G7 and T8 receipts with original correlation and bounded release" do
    f = fixture()
    peer = peer(:genuine)
    {t, tp} = prepare_transport(f, peer.source)
    {g, gp} = prepare_group(f, peer.source, [t], "genuine")
    router = manifest_router([g, t])
    store = start_store(router)
    assert :ok == Resources.release(gp ++ tp)
    await_healthy(g)
    eventually(fn -> UpstreamGroups.status(g).pins == 1 and transport_pins(f) == 1 end)
    observe_owners(f, store, :observe)
    trace_replies(f)
    d = deadline()
    assert {:ok, generation, ^router, pins} =
             Generation.snapshot_for_request(store, self(), d, ManagedGenerationAccounting)
    assert generation == router.generation
    assert [%{provider: UpstreamGroups} = gpin] = Enum.filter(pins, &(&1.provider == UpstreamGroups))
    assert [%{provider: Transports} = tpin] = Enum.filter(pins, &(&1.provider == Transports))
    assert map_size(gpin) == 7
    assert map_size(tpin) == 8
    refute Map.has_key?(gpin, :holder)
    assert tpin.holder === self()
    originals = for _ <- 1..2 do
      assert_receive {:checked_owner_input, owner, ^store, batch, holder, operation, ^d, nil}, @timeout
      assert holder === self()
      %{owner: owner, handles: batch, holder: holder, operation: operation}
    end
    for pin <- [gpin, tpin] do
      original = Enum.find(originals, &(&1.owner === pin.owner))
      assert pin.operation === original.operation
      assert pin.handles === original.handles
      assert :ok == ManagedGenerationAccounting.correlate(pin,
        {pin.provider, original.owner, original.operation, original.handles}, original.holder)
      assert_owned_reply(pin)
      assert_pin_algebra(pin)
    end
    assert :ok == Resources.release_checked(pins, deadline(), ManagedGenerationAccounting)
    eventually(fn -> UpstreamGroups.status(g).pins == 1 and transport_pins(f) == 1 end)
    stop_store(store)
    finish(f, [peer], [])
    refute_receive {:unexpected_checked_manifest_dispatch, _}, 0
  end

  @tag :checked_capture_constructor
  @tag timeout: 120_000
  test "real near H G H1 public manifest yields genuine singleton above Q before checked cons" do
    f = fixture()
    peer = peer(:above_q)
    prepared = for _ <- 1..32, do: prepare_transport(f, peer.source)
    transports = Enum.map(prepared, &elem(&1, 0))
    transport_preparation = Enum.flat_map(prepared, &elem(&1, 1))
    [first_t | _] = transports

    # Measure one REAL prepared handle, then choose supported member counts and
    # group ID lengths. All final handles are freshly returned by public prepare.
    {sample, sample_pins} = prepare_group(f, peer.source, [first_t], "samp")
    base_bytes = 7 + 64 * (e(sample) - 1)
    step = e(first_t) - 1
    extra = div(@h - base_bytes, step)
    padding = @h - base_bytes - extra * step
    assert extra in 0..(64 * 31)
    assert padding in 0..(64 * 124)
    assert :ok == Resources.release(sample_pins)
    eventually(fn -> UpstreamGroups.status(sample) == {:error, :stale_group} end)

    groups = for index <- 0..63 do
      count = 1 + min(31, max(0, extra - index * 31))
      pad = min(124, max(0, padding - index * 124))
      id = "g" <> String.pad_leading(Integer.to_string(index), 3, "0") <> :binary.copy("x", pad)
      prepare_group(f, peer.source, Enum.take(transports, count), id)
    end
    handles = Enum.map(groups, &elem(&1, 0))
    group_preparation = Enum.flat_map(groups, &elem(&1, 1))
    [first_g | _] = handles
    assert e(handles) == @h
    assert {:ok, ^handles} = Resources.validate(handles)
    assert :ok == ManagedGenerationAccounting.validate_manifest(handles)
    assert Enum.all?(handles, &(map_size(&1) == 7 and UpstreamGroups.valid_handle?(&1)))
    router = manifest_router(handles)
    store = start_store(router)
    # T preparations intentionally remain held: this no-dispatch manifest test
    # exposes only real G handles and must not retire their genuine dependencies.
    assert :ok == Resources.release(group_preparation)
    baseline_pins = UpstreamGroups.status(first_g).pins
    assert baseline_pins == 1
    observe_owners(f, store, :observe)
    trace_replies(f)
    assert :erlang.trace(store, true, [:send, {:tracer, self()}]) == 1
    on_exit(fn -> if Process.alive?(store), do: :erlang.trace(store, false, [:send]) end)
    d = deadline()
    assert {:error, :generation_capture_capacity, :cleanup_unconfirmed} ==
             Generation.snapshot_for_request(store, self(), d, ManagedGenerationAccounting)
    owner = f.groups
    assert_receive {:checked_owner_input, ^owner, ^store, ^handles, holder, operation, ^d, nil}, @timeout
    assert holder === self()
    assert_receive {:trace, ^owner, :send, {tag, {:ok, %{operation: ^operation} = pin}} = wire, _}, @timeout
    assert pin.provider === UpstreamGroups
    assert pin.owner === owner
    assert pin.handles === handles
    assert pin.kind === :request
    assert map_size(pin) == 7
    assert :ok == ManagedGenerationAccounting.correlate(pin, {UpstreamGroups, owner, operation, handles}, self())
    assert_pin_algebra(pin)
    assert e(wire) == tuple_size_etf([e(tag), tuple_size_etf([e(:ok), e(pin)])])
    assert e([pin]) == e(pin) + 6
    assert e([pin]) > @h
    assert e(pin) <= 73_862
    assert {:error, :generation_capture_capacity} == ManagedGenerationAccounting.preflight_cons(pin, [])
    assert_receive {:trace, ^store, :send, {:cancel_pin, ^store, ^operation}, ^owner}, @timeout
    assert_receive {:checked_original_cancel, ^owner, ^store, ^operation}, @timeout
    # A sent cancellation is uncertainty at the checked API boundary. Only a
    # subsequent public owner status corroborates that this real hold settled.
    eventually(fn -> UpstreamGroups.status(first_g).pins == baseline_pins end)
    assert {:ok, generation, ^router} = Generation.snapshot(store)
    assert generation === router.generation
    refute_receive {:unexpected_checked_manifest_dispatch, _}, 0
    stop_store(store)
    finish(f, [peer], transport_preparation)
  end

  for protocol <- [:http1, :http2] do
    @protocol protocol
    @tag :checked_capture_runtime
    @tag timeout: 120_000
    test "#{protocol} checked native old and new captures pay Admission before real owners and finish wire cleanup" do
      protocol = @protocol
      f = fixture()
      old_peer = peer(:old)
      new_peer = peer(:new)
      old = candidate(f, old_peer.source, :old)
      store = start_store(old.router)
      assert :ok == Resources.release(old.preparation)
      await_healthy(old.group)
      eventually(fn -> transport_pins(f) == 1 and UpstreamGroups.status(old.group).pins == 1 end)
      observe_owners(f, store, {:hold, :http})
      trace_replies(f)
      add_listener(f, store, protocol)
      socket = connect(f.instance)
      baseline = protocol_baseline(socket, f.instance, protocol)
      send_request(socket, protocol, 1, "/old%2Fpath?raw=%2F")
      first = capture_native(f, store, protocol, socket, baseline, old, 1)
      old_native = first.native
      old_monitor = Process.monitor(old_native)
      assert_native_identity(protocol, first.exchange)

      # Retain the actual old checked snapshot while replacing Store baseline.
      next = candidate(f, new_peer.source, :new)
      await_healthy(next.group)
      assert {:ok, next_generation} = Generation.activate(store, old.router.generation, next.router, @timeout)
      assert next_generation === next.router.generation
      assert :ok == Resources.release(next.preparation)
      assert {:ok, ^next_generation, next_router} = Generation.snapshot(store)
      assert next_router === next.router
      assert Enum.any?(first.exchange.resource_pins, &(old.group in &1.handles))
      send(first.native, {:checked_dispatch, first.token})
      assert_receive {:checked_peer_request, :old, worker, head}, @timeout
      assert head =~ "GET /old%2Fpath?raw=%2F HTTP/1.1\r\n"
      refute_receive {:checked_peer_request, :new, _, _}, 0
      send(worker, {:respond, "old-body"})
      assert response(socket, protocol, 1) == {200, "old-body"}
      assert_native_down(protocol, old_native, old_monitor)
      eventually(fn -> transport_pins(f) == 1 and UpstreamGroups.status(next.group).pins == 1 end)

      socket = if protocol == :http1, do: connect(f.instance), else: socket
      baseline = if protocol == :http1 do
        %{retained_bytes: 0}
      else
        eventually(fn ->
          status = Gaoxy.status(f.instance, :http)
          status.active == baseline.active and status.retained_bytes == baseline.retained_bytes
        end)
        Gaoxy.status(f.instance, :http)
      end
      send_request(socket, protocol, 3, "/new%2Fpath?")
      fresh = capture_native(f, store, protocol, socket, baseline, next, 3)
      fresh_monitor = Process.monitor(fresh.native)
      refute fresh.native === old_native
      send(fresh.native, {:checked_dispatch, fresh.token})
      assert_receive {:checked_peer_request, :new, next_worker, next_head}, @timeout
      assert next_head =~ "GET /new%2Fpath? HTTP/1.1\r\n"
      send(next_worker, {:respond, "new-body"})
      assert response(socket, protocol, 3) == {200, "new-body"}
      assert_native_down(protocol, fresh.native, fresh_monitor)
      :ok = :gen_tcp.close(socket)
      eventually(fn -> match?(%{active: 0, cleanup_pending: 0, retained_bytes: 0}, Gaoxy.status(f.instance, :http)) end)
      eventually(fn -> transport_pins(f) == 1 and UpstreamGroups.status(next.group).pins == 1 end)
      stop_store(store)
      finish(f, [old_peer, new_peer], [])
    end
  end

  defp fixture do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    {:ok, transports} = Transports.start_link(instance: instance, limits: %{
      max_resources: 32, max_pins: 4096, max_request_tokens: 64,
      max_owned_payload_bytes: 67_108_864
    })
    Process.unlink(transports)
    {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: %{
      max_groups: 64, max_pins: 1024, max_probes: 1,
      max_config_bytes: 67_108_864
    })
    Process.unlink(groups)
    on_exit(fn ->
      for pid <- [groups, transports], Process.alive?(pid) do
        send(pid, :checked_fixture_unblock)
      end
      for pid <- [groups, instance, transports], Process.alive?(pid) do
        Lifecycle.protect(fn -> GenServer.stop(pid, :normal, @timeout) end)
      end
    end)
    %{instance: instance, transports: transports, groups: groups}
  end

  defp prepare_transport(f, source) do
    assert {:ok, handle, preparation} = Transports.prepare(f.transports, source, self(), deadline(@fixture_timeout))
    {handle, preparation}
  end

  defp prepare_group(f, source, transports, id) do
    members = for {transport, index} <- Enum.with_index(transports), do: %{
      id: "m#{index}", upstream: source.origin, transport: transport,
      connect_address: nil
    }
    assert {:ok, compiled} = UpstreamGroups.compile(%{
      id: id, members: members,
      health: %{path: "/health", interval: 60_000, stale_after: 120_000,
        timeout: 2_000, jitter: 0, recovery_threshold: 1}
    })
    assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline(@fixture_timeout))
    assert map_size(handle) == 7
    {handle, preparation}
  end

  defp candidate(f, source, label) do
    {transport, tp} = prepare_transport(f, source)
    {group, gp} = prepare_group(f, source, [transport], Atom.to_string(label))
    assert {:ok, router} = Router.compile([%{target: {CapturedEndpoint, {group, self(), label}}}])
    %{transport: transport, group: group, router: router, preparation: gp ++ tp, label: label}
  end

  defp manifest_router(handles) do
    assert {:ok, router} = Router.compile([%{target: {ManifestEndpoint, {handles, self()}}}])
    router
  end

  defp start_store(router) do
    assert {:ok, store} = Generation.start_link(router: router, max_config_bytes: @m)
    Process.unlink(store)
    on_exit(fn -> if Process.alive?(store), do: GenServer.stop(store, :normal, @timeout) end)
    store
  end

  defp stop_store(store) do
    monitor = Process.monitor(store)
    assert :ok == GenServer.stop(store, :normal, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^store, :normal}, @timeout
  end

  defp observe_owners(f, store, mode) do
    parent = self()
    for owner <- [f.groups, f.transports] do
      id = make_ref()
      :ok = :sys.install(owner, {id, fn state, event, _ ->
        case event do
          {:in, {:"$gen_call", {^store, _}, {tag, batch, holder, :request, operation, d}}}
          when tag in [:pin, :pin_many] ->
            status = case mode do
              {:hold, service} -> Gaoxy.status(f.instance, service)
              :observe -> nil
            end
            send(parent, {:checked_owner_input, owner, store, batch, holder, operation, d, status})
            if mode != :observe do
              receive do
                {:checked_owner_continue, ^operation} -> :ok
                :checked_fixture_unblock -> :ok
              after
                @timeout -> raise "checked genuine owner fixture barrier expired"
              end
            end
          {:in, {tag, ^store, operation}} when tag in [:cancel_pin, :cancel_pins] ->
            send(parent, {:checked_original_cancel, owner, store, operation})
          _ -> :ok
        end
        state
      end, id})
      on_exit(fn ->
        if Process.alive?(owner) do
          send(owner, :checked_fixture_unblock)
          :sys.remove(owner, id)
        end
      end)
    end
  end

  defp trace_replies(f) do
    for owner <- [f.groups, f.transports] do
      assert :erlang.trace(owner, true, [:send, {:tracer, self()}]) == 1
      on_exit(fn -> if Process.alive?(owner), do: :erlang.trace(owner, false, [:send]) end)
    end
  end

  defp assert_owned_reply(pin) do
    owner = pin.owner
    operation = pin.operation
    assert_receive {:trace, ^owner, :send, {tag, {:ok, %{operation: ^operation} = observed}} = wire, _}, @timeout
    assert observed === pin
    assert e(wire) == tuple_size_etf([e(tag), tuple_size_etf([e(:ok), e(pin)])])
  end

  defp assert_pin_algebra(pin) do
    fields = Map.to_list(pin)
    expected = 6 + Enum.reduce(fields, 0, fn {k, v}, sum -> sum + e(k) + e(v) - 2 end)
    assert e(pin) == expected
    assert e({:ok, pin}) == tuple_size_etf([e(:ok), e(pin)])
    assert e([pin]) == 7 + e(pin) - 1
  end

  defp add_listener(f, store, protocol) do
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(
      endpoint: {Generation, {store, accounting: ManagedGenerationAccounting}},
      protocols: [protocol], h2c: if(protocol == :http2, do: :prior_knowledge, else: :disabled),
      limits: %{max_bytes: 67_108_864}, http_limits: %{request_timeout: 15_000}
    )
    assert {:ok, _} = Gaoxy.add(f.instance, spec)
  end

  defp capture_native(f, store, protocol, socket, baseline, candidate, _stream) do
    originals = for index <- 1..2 do
      assert_receive {:checked_owner_input, owner, ^store, batch, native, operation, d, status}, @timeout
      assert is_pid(native)
      assert Lifecycle.remaining(d) > 0
      assert status.retained_bytes >= 11_248_829
      if index == 1 do
        if protocol == :http2 do
          assert_ping(socket, "holdping")
        else
          sibling = connect(f.instance)
          eventually(fn -> Gaoxy.status(f.instance, :http).active == 2 end)
          :ok = :gen_tcp.close(sibling)
          eventually(fn -> Gaoxy.status(f.instance, :http).active == 1 end)
        end
      end
      send(owner, {:checked_owner_continue, operation})
      %{owner: owner, handles: batch, holder: native, operation: operation, deadline: d, status: status}
    end
    label = candidate.label
    assert_receive {:checked_native_capture, native, token, ^label, exchange}, @timeout
    on_exit(fn -> send(native, {:checked_dispatch, token}) end)
    assert_native_identity(protocol, exchange)
    assert Enum.all?(originals, &(&1.holder === native and &1.deadline === exchange.deadline))
    assert Enum.count(exchange.resource_pins) == 2
    assert MapSet.new(Enum.flat_map(exchange.resource_pins, & &1.handles)) ==
             MapSet.new([candidate.group, candidate.transport])
    # This scalar forecast is independently checked by Task1/3.5. These tests
    # are runtime-tagged and may execute only AFTER that whole source gate.
    retained = Exchange.retained_bytes(exchange) - exchange.route_bytes
    b = expected_default_b(retained)
    assert exchange.route_bytes == b
    assert {:ok, {:native_generation_capture_v1, @m, @h, @h, ^b}} =
      ManagedGenerationAccounting.reservation(@m, {store, native, exchange.gate,
        exchange.lease, :request, exchange.deadline, retained})
    overhead = if protocol == :http2, do: baseline.retained_bytes, else: 0
    expected_charge = overhead + retained + b
    assert Enum.all?(originals, &(&1.status.retained_bytes == expected_charge))
    assert Admission.status(exchange.gate).retained_bytes == expected_charge
    assert Gaoxy.status(f.instance, :http).retained_bytes == expected_charge
    for pin <- exchange.resource_pins do
      original = Enum.find(originals, &(&1.owner === pin.owner))
      assert original.handles === pin.handles
      assert :ok == ManagedGenerationAccounting.correlate(pin,
        {pin.provider, original.owner, original.operation, original.handles}, native)
      if pin.provider == Transports, do: assert(pin.holder === native)
      assert_owned_reply(pin)
      assert_pin_algebra(pin)
    end
    %{native: native, token: token, exchange: exchange}
  end

  defp expected_default_b(retained), do: expected_default_b(retained, 0, 0)
  defp expected_default_b(retained, b, iterations) when iterations < 64 do
    next = 6 * @m + 4_957_373 + 3 * (e(retained) - 3) +
      5 * (e(b) - 6) + 4 * (e(retained + b) - 6)
    if next == b, do: b, else: expected_default_b(retained, next, iterations + 1)
  end
  defp expected_default_b(_, _, _), do: flunk("independent default B did not converge")

  defp assert_native_identity(:http1, exchange), do: assert(exchange.transport == nil)
  defp assert_native_identity(:http2, exchange) do
    assert exchange.transport == Gaoxy.HTTP.HTTP2.Transport
    assert {connection, id, token} = exchange.transport_state
    assert is_pid(connection)
    assert id in [1, 3]
    assert is_reference(token)
  end

  defp assert_native_down(:http1, native, monitor) do
    assert_receive {:DOWN, ^monitor, :process, ^native, {:shutdown, :local_closed}}, @timeout
  end
  defp assert_native_down(:http2, native, monitor) do
    assert_receive {:DOWN, ^monitor, :process, ^native, :normal}, @timeout
  end

  defp await_healthy(group) do
    eventually(fn -> match?(%{members: [%{health: :healthy, probe: false}], probes: 0}, UpstreamGroups.status(group)) end)
  end
  defp transport_pins(f) do
    assert {:ok, status} = Transports.status(f.transports)
    status.pins
  end

  defp finish(f, peers, preparations) do
    assert :ok == Resources.release(preparations)
    eventually(fn -> match?({:ok, %{resources: 0, pins: 0, request_tokens: 0,
      helpers: 0, reserved_connections: 0, owned_serialized_payload_bytes: 0}}, Transports.status(f.transports)) end, deadline(@fixture_timeout))
    monitor = Process.monitor(f.groups)
    assert :ok == GenServer.stop(f.groups, :normal, @timeout)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    monitor = Process.monitor(f.transports)
    assert :ok == Gaoxy.stop(f.instance, @timeout)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    for peer <- peers do
      :ok = :gen_tcp.close(peer.listener)
      pid = peer.pid
      monitor = peer.monitor
      assert_receive {:checked_peer_joined, ^pid, :ok}, @timeout
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end
  end

  defp peer(label) do
    assert {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])
    assert {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    {pid, monitor} = spawn_monitor(fn -> accept_loop(listener, parent, label, []) end)
    on_exit(fn ->
      :gen_tcp.close(listener)
      if Process.alive?(pid) do
        failure_monitor = Process.monitor(pid)
        receive do
          {:DOWN, ^failure_monitor, :process, ^pid, _} -> :ok
        after
          2 * @timeout -> flunk("checked peer and owned workers did not join during fixture cleanup")
        end
      end
    end)
    %{pid: pid, monitor: monitor, listener: listener,
      source: %{origin: "http://localhost:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}}
  end

  defp accept_loop(listener, parent, label, workers) do
    case :gen_tcp.accept(listener, 50) do
      {:ok, socket} ->
        peer = self()
        {worker, monitor} = spawn_monitor(fn ->
          receive do
            :checked_socket_ready ->
              result = try do
                serve_peer(socket, parent, label)
              after
                :gen_tcp.close(socket)
              end
              send(peer, {:checked_worker_done, self(), result})
          after
            @timeout -> exit(:checked_peer_transfer_expired)
          end
        end)
        assert :ok == :gen_tcp.controlling_process(socket, worker)
        send(worker, :checked_socket_ready)
        accept_loop(listener, parent, label, [{worker, monitor} | workers])
      {:error, :timeout} -> accept_loop(listener, parent, label, workers)
      {:error, :closed} ->
        for {worker, monitor} <- workers do
          assert_receive {:checked_worker_done, ^worker, :ok}, @timeout
          assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
        end
        send(parent, {:checked_peer_joined, self(), :ok})
    end
  end

  defp serve_peer(socket, parent, label) do
    case :gen_tcp.recv(socket, 1, @timeout) do
      {:ok, first} ->
        head = read_head(socket, first)
        if String.starts_with?(head, "HEAD /health HTTP/1.1\r\n") do
          :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        else
          send(parent, {:checked_peer_request, label, self(), head})
          receive do
            {:respond, body} ->
              :ok = :gen_tcp.send(socket, ["HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(body)}\r\n\r\n", body])
          after
            @timeout -> exit(:checked_peer_response_expired)
          end
        end
        serve_peer(socket, parent, label)
      {:error, :timeout} -> serve_peer(socket, parent, label)
      {:error, :closed} -> :ok
    end
  end

  defp connect(instance) do
    assert {:ok, {ip, port}} = Gaoxy.info(instance, :http).local
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end
  defp protocol_baseline(_socket, _instance, :http1), do: %{retained_bytes: 0}
  defp protocol_baseline(socket, instance, :http2) do
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    assert_ping(socket, "baseline")
    Gaoxy.status(instance, :http)
  end
  defp send_request(socket, :http1, _id, path) do
    :ok = :gen_tcp.send(socket, "GET #{path} HTTP/1.1\r\nHost: downstream.test\r\nConnection: close\r\n\r\n")
  end
  defp send_request(socket, :http2, id, path) do
    {bytes, _} = HPAX.encode(:never_store, [{":method", "GET"}, {":scheme", "http"},
      {":authority", "downstream.test"}, {":path", path}], HPAX.new(4096))
    :ok = :gen_tcp.send(socket, frame(1, 5, id, bytes))
  end
  defp frame(type, flags, id, bytes), do: [<<IO.iodata_length(bytes)::24, type, flags, 0::1, id::31>>, bytes]
  defp recv_frame(socket) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    payload = if size == 0, do: "", else: recv_exact(socket, size)
    {type, flags, id, payload}
  end
  defp assert_ping(socket, payload) do
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, payload))
    await_ping(socket, payload, deadline())
  end
  defp await_ping(socket, payload, d) do
    assert Lifecycle.remaining(d) > 0
    case recv_frame(socket) do
      {6, 1, 0, ^payload} -> :ok
      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        await_ping(socket, payload, d)
      {4, 1, 0, ""} -> await_ping(socket, payload, d)
      other -> flunk("unexpected H2 control while capture held: #{inspect(other)}")
    end
  end
  defp response(socket, :http1, _id) do
    head = read_head(socket, "")
    [_, status] = Regex.run(~r/^HTTP\/1\.1 ([0-9]{3}) /, head)
    [_, size] = Regex.run(~r/\r\ncontent-length: ([0-9]+)\r\n/i, head)
    body = case String.to_integer(size) do
      0 -> ""
      n -> recv_exact(socket, n)
    end
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    {String.to_integer(status), body}
  end
  defp response(socket, :http2, id), do: response_h2(socket, id, [], "", HPAX.new(4096), deadline())
  defp response_h2(socket, id, headers, body, decoder, d) do
    assert Lifecycle.remaining(d) > 0
    {type, flags, stream, payload} = recv_frame(socket)
    case {type, stream} do
      {4, 0} ->
        if flags == 0, do: :gen_tcp.send(socket, frame(4, 1, 0, ""))
        response_h2(socket, id, headers, body, decoder, d)
      {1, ^id} ->
        assert Bitwise.band(flags, 4) == 4
        assert {:ok, fields, decoder} = HPAX.decode(payload, decoder)
        headers = headers ++ fields
        if Bitwise.band(flags, 1) == 1, do: h2_result(headers, body),
          else: response_h2(socket, id, headers, body, decoder, d)
      {0, ^id} ->
        body = body <> payload
        if Bitwise.band(flags, 1) == 1, do: h2_result(headers, body),
          else: response_h2(socket, id, headers, body, decoder, d)
      other -> flunk("unexpected H2 response frame: #{inspect(other)}")
    end
  end
  defp h2_result(headers, body) do
    assert {":status", status} = List.keyfind(headers, ":status", 0)
    {String.to_integer(status), body}
  end
  defp recv_exact(socket, size) do
    assert {:ok, bytes} = :gen_tcp.recv(socket, size, @timeout)
    bytes
  end
  defp read_head(socket, bytes) do
    assert byte_size(bytes) <= @h
    if String.ends_with?(bytes, "\r\n\r\n"), do: bytes,
      else: read_head(socket, bytes <> recv_exact(socket, 1))
  end
  defp deadline(ms \\ @timeout), do: Lifecycle.deadline(ms)
  defp e(term), do: :erlang.external_size(term)
  defp tuple_size_etf(sizes), do: 3 + Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)
  defp eventually(fun, d \\ nil) do
    d = d || deadline()
    if fun.(), do: :ok, else: (
      assert Lifecycle.remaining(d) > 0, "checked public fixture did not settle before finite deadline"
      receive do after 2 -> eventually(fun, d) end
    )
  end
end
