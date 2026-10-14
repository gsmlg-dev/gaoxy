defmodule Gaoxy.Proxy.UpstreamTransportGenerationTest do
  use ExUnit.Case, async: false

  alias Gaoxy.HTTP.{Generation, Resources}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @moduletag :capture_log
  @moduletag :generation_handoff
  @timeout 3_000

  defmodule SnapshotEndpoint do
    @behaviour Gaoxy.HTTP.Endpoint

    def init({module, options, parent, label, corruption}) do
      with {:ok, config} <- module.init(options),
           do: {:ok, {module, config, parent, label, corruption}}
    end

    def resources({module, config, _, _, _}), do: module.resources(config)

    def call(exchange, {module, config, parent, label, corruption}) do
      barrier = make_ref()
      handles = module.resources(config)

      send(parent, {:captured_snapshot, self(), barrier, label, exchange.resource_pins, handles})

      receive do
        {:dispatch, ^barrier} ->
          pins = corrupt(exchange.resource_pins, corruption)
          module.call(%{exchange | resource_pins: pins}, config)
      after
        min(3_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "Generation native snapshot barrier expired"
      end
    end

    defp corrupt(pins, :none), do: pins

    defp corrupt(pins, :missing_group),
      do: Enum.reject(pins, &(&1.provider == Gaoxy.Proxy.UpstreamGroups))

    defp corrupt(pins, :missing_transport),
      do: Enum.reject(pins, &(&1.provider == Gaoxy.Proxy.UpstreamTransports))

    defp corrupt(pins, :fake_transport),
      do:
        Enum.map(pins, fn pin ->
          if pin.provider == Gaoxy.Proxy.UpstreamTransports,
            do: %{pin | ref: make_ref()},
            else: pin
        end)
  end

  for kind <- [:fixed, :group] do
    @kind kind
    test "#{kind} native old snapshot dispatches only to its old peer after baseline closure" do
      old_peer = peer(:old)
      new_peer = peer(:new)
      fixture = fixture(@kind)
      initial = candidate(fixture, old_peer.source, :old)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      old = activate(fixture, initial, expected)
      old = healthy(fixture, old)
      add_service(fixture)

      old_socket = connect(fixture.instance)
      :ok = :gen_tcp.send(old_socket, request("/old%2Fpath?raw=%2F"))
      captured = capture(fixture, old, :old)
      native_monitor = Process.monitor(captured.native)
      assert_no_native_outer_acquisition(fixture, captured.native)

      next = candidate(fixture, new_peer.source, :new)
      next = healthy(fixture, next)
      replacement = activate(fixture, next, old.generation)
      refute replacement.generation == old.generation
      await_closed(fixture, old, captured)

      send(captured.native, {:dispatch, captured.barrier})
      assert_receive {:peer_request, :old, old_worker, old_head}, @timeout
      assert_receive {:peer_accepted, :old, ^old_worker}, @timeout
      if old.group, do: assert(old_worker == old.health_worker)
      assert old_head =~ "GET /old%2Fpath?raw=%2F HTTP/1.1\r\n"

      assert old_head =~ "Host: #{URI.parse(old_peer.source.origin).authority}\r\n" or
               String.downcase(old_head) =~
                 "host: #{URI.parse(old_peer.source.origin).authority}\r\n"

      {old_guardian, old_completion} = bound_request(fixture, old, captured)
      old_guardian_monitor = Process.monitor(old_guardian)
      assert_no_native_outer_acquisition(fixture, captured.native)

      new_socket = connect(fixture.instance)
      :ok = :gen_tcp.send(new_socket, request("/new%2Fpath?"))
      fresh = capture(fixture, replacement, :new)
      fresh_native_monitor = Process.monitor(fresh.native)
      send(fresh.native, {:dispatch, fresh.barrier})
      assert_receive {:peer_request, :new, new_worker, new_head}, @timeout
      assert_receive {:peer_accepted, :new, ^new_worker}, @timeout
      if replacement.group, do: assert(new_worker == replacement.health_worker)
      assert new_head =~ "GET /new%2Fpath? HTTP/1.1\r\n"
      {new_guardian, new_completion} = bound_request(fixture, replacement, fresh)
      new_guardian_monitor = Process.monitor(new_guardian)
      assert_no_native_outer_acquisition(fixture, fresh.native)

      send(new_worker, {:respond, <<255, "new", 0>>})
      assert response(new_socket) == {200, <<255, "new", 0>>}
      assert :ok = HTTP.RequestCompletion.await(new_completion, @timeout)
      assert_receive {:DOWN, ^new_guardian_monitor, :process, ^new_guardian, :normal}, @timeout

      assert_receive {:DOWN, ^fresh_native_monitor, :process, _, {:shutdown, :local_closed}},
                     @timeout

      send(old_worker, {:respond, <<0, "old", 255>>})
      assert response(old_socket) == {200, <<0, "old", 255>>}
      assert :ok = HTTP.RequestCompletion.await(old_completion, @timeout)
      assert_receive {:DOWN, ^old_guardian_monitor, :process, ^old_guardian, :normal}, @timeout
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
      join_retired(fixture, old)
      assert_receive {:peer_eof, :old, ^old_worker}, @timeout
      refute_receive {:peer_request, :old, _, _}, 0
      refute_receive {:peer_request, :new, _, _}, 0
      assert_no_native_outer_acquisition(fixture, captured.native)
      assert_no_native_outer_acquisition(fixture, fresh.native)
      finish_fixture(fixture, [old_peer, new_peer], [replacement])
      assert_receive {:peer_eof, :new, ^new_worker}, @timeout
      refute_receive {:peer_accepted, :old, _}, 0
      refute_receive {:peer_accepted, :new, _}, 0
    end
  end

  test "a real Service attach_cleanup barrier permits no Session pin token or Fetch before activation" do
    upstream = peer(:activation)
    fixture = fixture(:fixed)
    prepared = candidate(fixture, upstream.source, :activation)
    assert {:ok, expected, _} = Generation.snapshot(fixture.store)
    current = activate(fixture, prepared, expected)
    add_service(fixture)
    {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})
    barrier = attach_barrier(service)
    socket = connect(fixture.instance)
    :ok = :gen_tcp.send(socket, request("/activation"))
    captured = capture(fixture, current, :activation)
    native_monitor = Process.monitor(captured.native)
    send(captured.native, {:dispatch, captured.barrier})

    assert_receive {:attach_cleanup_held, ^service, native, guardian}, @timeout
    assert native == captured.native
    guardian_monitor = Process.monitor(guardian)
    state = :sys.get_state(guardian)
    assert state.token == nil
    assert state.request == nil
    assert state.transport_pins == []
    assert state.transport_selection == nil
    assert {:ok, %{request_tokens: 0}} = Transports.status(fixture.transports)

    refute Enum.any?(:sys.get_state(fixture.transports).pins, fn {_, hold} ->
             hold.public.holder == guardian
           end)

    refute_receive {:transport_input, _, ^native, :delegate_request_pin}, 0
    refute_receive {:peer_request, :activation, _, _}, 0
    refute_receive {:peer_accepted, :activation, _}, 0
    assert {:error, :timeout} = :gen_tcp.accept(upstream.listener, 0)
    assert_no_native_outer_acquisition(fixture, captured.native)

    send(service, {:continue_attach, barrier})
    assert_receive {:peer_request, :activation, worker, head}, @timeout
    assert_receive {:peer_accepted, :activation, ^worker}, @timeout
    assert head =~ "GET /activation HTTP/1.1\r\n"
    {^guardian, completion} = bound_request(fixture, current, captured)
    send(worker, {:respond, "activated"})
    assert response(socket) == {200, "activated"}
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
    assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
    finish_fixture(fixture, [upstream], [current])
    assert_receive {:peer_eof, :activation, ^worker}, @timeout
  end

  for corruption <- [:missing_group, :missing_transport, :fake_transport] do
    @corruption corruption
    test "#{corruption} nonempty captured group set fails closed without new transport allocation" do
      upstream = peer(@corruption)
      fixture = fixture(:group)
      prepared = candidate(fixture, upstream.source, @corruption, @corruption)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      current = activate(fixture, prepared, expected)
      current = healthy(fixture, current)
      flush_transport_inputs(fixture.transports)
      health_before = health_state(fixture, current.group)
      label = @corruption
      health_worker = current.health_worker
      assert_receive {:peer_accepted, ^label, ^health_worker}, @timeout
      add_service(fixture)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("/denied"))
      captured = capture(fixture, current, @corruption)
      native_monitor = Process.monitor(captured.native)
      assert length(captured.pins) == 2
      assert {:ok, %{request_tokens: 0}} = Transports.status(fixture.transports)
      send(captured.native, {:dispatch, captured.barrier})
      expected_status = if @corruption == :fake_transport, do: 502, else: 503
      assert response(socket) == {expected_status, ""}
      settled(fixture)
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
      assert_no_native_outer_acquisition(fixture, captured.native)
      refute_receive {:transport_input, _, _, :checkout}, 0

      if @corruption == :fake_transport do
        owner = fixture.transports
        native = captured.native
        assert_receive {:transport_input, ^owner, ^native, :delegate_request_pin}, @timeout

        assert_receive {:delegation_result, ^owner, ^native, {:error, :invalid_resource_pin}},
                       @timeout
      end

      refute_receive {:transport_input, _, _, :delegate_request_pin}, 0
      assert health_state(fixture, current.group) == health_before
      refute_receive {:peer_request, @corruption, _, _}, 0
      refute_receive {:peer_accepted, ^label, _}, 0
      finish_fixture(fixture, [upstream], [current])
      assert_receive {:peer_eof, ^label, ^health_worker}, @timeout
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_peers
    test "#{kind} stale CAS retires only the rejected candidate and preserves the active baseline" do
      active_peer = peer(:active)
      rejected_peer = peer(:rejected)
      fixture = fixture(@kind)
      assert {:ok, stale, _} = Generation.snapshot(fixture.store)
      initial = candidate(fixture, active_peer.source, :active)
      active = activate(fixture, initial, stale)
      active = healthy(fixture, active)
      add_service(fixture)
      rejected = candidate(fixture, rejected_peer.source, :rejected)
      rejected = healthy(fixture, rejected)
      send(rejected.coordinator, {:activate, stale})
      coordinator = rejected.coordinator
      monitor = rejected.monitor
      assert_receive {:candidate_activated, ^coordinator, {:error, :stale_generation}}, @timeout
      assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
      assert {:ok, generation, router} = Generation.snapshot(fixture.store)
      assert generation == active.generation
      assert router == active.router
      assert configured_pins(fixture, active.transport) == [:baseline]
      join_retired(fixture, rejected)

      if rejected.group do
        worker = rejected.health_worker
        assert_receive {:peer_eof, :rejected, ^worker}, @timeout
      end

      worker = complete_request(fixture, active, "/after-stale?", "active")
      refute_receive {:peer_request, :rejected, _, _}, 0
      finish_fixture(fixture, [active_peer, rejected_peer], [active])
      assert_receive {:peer_eof, :active, ^worker}, @timeout
    end

    @tag :generation_peers
    test "#{kind} candidate coordinator death before activation releases preparation without changing routing" do
      active_peer = peer(:active)
      abandoned_peer = peer(:abandoned)
      fixture = fixture(@kind)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      initial = candidate(fixture, active_peer.source, :active)
      active = activate(fixture, initial, expected)
      active = healthy(fixture, active)
      add_service(fixture)
      abandoned = candidate(fixture, abandoned_peer.source, :abandoned)
      abandoned = healthy(fixture, abandoned)
      coordinator = abandoned.coordinator
      monitor = abandoned.monitor
      Process.exit(coordinator, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^coordinator, :killed}, @timeout
      join_retired(fixture, abandoned)
      assert {:ok, generation, router} = Generation.snapshot(fixture.store)
      assert generation == active.generation
      assert router == active.router
      assert configured_pins(fixture, active.transport) == [:baseline]

      if abandoned.group do
        worker = abandoned.health_worker
        assert_receive {:peer_eof, :abandoned, ^worker}, @timeout
      end

      worker = complete_request(fixture, active, "/after-coordinator-death", "active")
      refute_receive {:peer_request, :abandoned, _, _}, 0
      finish_fixture(fixture, [active_peer, abandoned_peer], [active])
      assert_receive {:peer_eof, :active, ^worker}, @timeout
    end

    @tag :generation_lifecycle
    test "#{kind} store death closes configuration while a captured native request retains its old right" do
      upstream = peer(:store_death)
      fixture = fixture(@kind)
      initial = candidate(fixture, upstream.source, :store_death)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      current = activate(fixture, initial, expected)
      current = healthy(fixture, current)
      add_service(fixture)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("/held-before-store-death"))
      captured = capture(fixture, current, :store_death)
      native_monitor = Process.monitor(captured.native)
      store_monitor = Process.monitor(fixture.store)
      assert :ok = GenServer.stop(fixture.store, :normal, @timeout)
      assert_receive {:DOWN, ^store_monitor, :process, _, :normal}, @timeout
      assert {:error, _} = Generation.snapshot(fixture.store)
      await_closed(fixture, current, captured)
      flush_transport_inputs(fixture.transports)
      fresh = connect(fixture.instance)
      :ok = :gen_tcp.send(fresh, request("/after-store-death"))
      assert response(fresh) == {500, ""}
      assert {:ok, %{request_tokens: 0, pins: 1}} = Transports.status(fixture.transports)
      refute_receive {:captured_snapshot, _, _, :store_death, _, _}, 0
      refute_receive {:transport_input, _, _, :delegate_request_pin}, 0
      refute_receive {:transport_input, _, _, :checkout}, 0
      assert_no_native_outer_acquisition(fixture, captured.native)
      refute_receive {:peer_request, :store_death, _, _}, 0
      send(captured.native, {:dispatch, captured.barrier})
      assert_receive {:peer_request, :store_death, worker, head}, @timeout
      assert head =~ "GET /held-before-store-death HTTP/1.1\r\n"
      {guardian, completion} = bound_request(fixture, current, captured)
      guardian_monitor = Process.monitor(guardian)
      assert_no_native_outer_acquisition(fixture, captured.native)
      send(worker, {:respond, <<0, "survives", 255>>})
      assert response(socket) == {200, <<0, "survives", 255>>}
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
      join_retired(fixture, current)
      assert_receive {:peer_eof, :store_death, ^worker}, @timeout
      refute_receive {:peer_request, :store_death, _, _}, 0
      finish_fixture(fixture, [upstream], [])
    end

    @tag :generation_lifecycle
    @tag timeout: 120_000
    test "#{kind} two warmups and twenty reloads plateau after old physical resources join" do
      upstream = peer(:reload)
      fixture = fixture(@kind)
      initial = candidate(fixture, upstream.source, :reload)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      current = activate(fixture, initial, expected)
      current = healthy(fixture, current)
      add_service(fixture)
      worker = complete_request(fixture, current, "/initial?", <<0, "initial", 255>>)

      {current, worker, samples} =
        Enum.reduce(1..22, {current, worker, []}, fn cycle, {old, old_worker, samples} ->
          next = candidate(fixture, upstream.source, :reload)
          next = healthy(fixture, next)
          next = activate(fixture, next, old.generation)
          join_retired(fixture, old)
          assert_receive {:peer_eof, :reload, ^old_worker}, @timeout
          worker = complete_request(fixture, next, "/cycle%2F#{cycle}?", <<0, "cycle", 255>>)
          sample = steady_sample(fixture)
          samples = if cycle > 2, do: [sample | samples], else: samples
          {next, worker, samples}
        end)

      assert length(samples) == 20
      [baseline | rest] = samples
      assert Enum.all?(rest, &(&1 == baseline))
      finish_fixture(fixture, [upstream], [current])
      assert_receive {:peer_eof, :reload, ^worker}, @timeout
      refute_receive {:peer_request, :reload, _, _}, 0
      refute_receive {:peer_accepted, :reload, _}, 0
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_peers
    @tag :tmp_dir
    test "#{kind} TLS swaps numeric IP and DER atomically at one authority and port", context do
      old_chain = tls_chain(Path.join(context.tmp_dir, "old"))
      new_chain = tls_chain(Path.join(context.tmp_dir, "new"))
      refute old_chain.ca == new_chain.ca
      refute old_chain.leaf == new_chain.leaf
      old_peer = tls_peer(:tls_old, {127, 0, 0, 1}, 0, old_chain)
      port = URI.parse(old_peer.source.origin).port
      new_peer = tls_peer(:tls_new, {127, 0, 0, 2}, port, new_chain)
      assert old_peer.source.origin == new_peer.source.origin
      fixture = fixture(@kind)
      initial = candidate(fixture, old_peer.source, :tls_old)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      old = activate(fixture, initial, expected)
      old = healthy(fixture, old)
      old_policy = :sys.get_state(fixture.transports).records[old.transport.resource].policy
      assert old_policy.connect_address == {127, 0, 0, 1}
      assert old_policy.open_options[:ssl][:cacerts] == [old_chain.ca]
      add_service(fixture)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("/tls%2Fold?raw=%2F"))
      captured = capture(fixture, old, :tls_old)
      native_monitor = Process.monitor(captured.native)
      next = candidate(fixture, new_peer.source, :tls_new)
      next = healthy(fixture, next)
      next = activate(fixture, next, old.generation)
      await_closed(fixture, old, captured)
      new_policy = :sys.get_state(fixture.transports).records[next.transport.resource].policy
      assert new_policy.connect_address == {127, 0, 0, 2}
      assert new_policy.open_options[:ssl][:cacerts] == [new_chain.ca]

      assert :sys.get_state(fixture.transports).records[old.transport.resource].policy ==
               old_policy

      # Request/probe execution must use captured DER, never this source file.
      File.write!(Path.join(old_chain.directory, "ca.pem"), "replaced after preparation")
      File.write!(Path.join(new_chain.directory, "ca.pem"), "replaced after preparation")
      send(captured.native, {:dispatch, captured.barrier})
      assert_receive {:peer_request, :tls_old, old_worker, head}, @timeout
      assert_receive {:peer_accepted, :tls_old, ^old_worker}, @timeout
      assert head =~ "GET /tls%2Fold?raw=%2F HTTP/1.1\r\n"
      assert String.downcase(head) =~ "host: localhost:#{port}\r\n"
      old_leaf = old_chain.leaf
      assert_receive {:peer_tls, :tls_old, ^old_worker, "localhost", nil, ^old_leaf}, @timeout
      {guardian, completion} = bound_request(fixture, old, captured)
      guardian_monitor = Process.monitor(guardian)
      assert_no_native_outer_acquisition(fixture, captured.native)
      # Fresh dispatch completes while the old request still retains its peer.
      new_worker = complete_request(fixture, next, "/tls%2Fnew?", <<255, "new TLS", 0>>, false)
      new_leaf = new_chain.leaf
      assert_receive {:peer_tls, :tls_new, ^new_worker, "localhost", nil, ^new_leaf}, @timeout
      send(old_worker, {:respond, <<0, "old TLS", 255>>})
      assert response(socket) == {200, <<0, "old TLS", 255>>}
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
      join_retired(fixture, old)
      assert_receive {:peer_eof, :tls_old, ^old_worker}, @timeout
      refute_receive {:peer_request, :tls_old, _, _}, 0
      refute_receive {:peer_accepted, :tls_old, _}, 0
      refute_receive {:peer_accepted, :tls_new, _}, 0
      finish_fixture(fixture, [old_peer, new_peer], [next])
      assert_receive {:peer_eof, :tls_new, ^new_worker}, @timeout
    end
  end

  for reason <- [:wrong_ca, :wrong_host] do
    @reason reason
    @tag :generation_peers
    @tag :tmp_dir
    test "TLS #{@reason} generation fails verification without request replay or alternate peer",
         context do
      trusted = tls_chain(Path.join(context.tmp_dir, "trusted"))
      untrusted = tls_chain(Path.join(context.tmp_dir, "untrusted"))
      upstream = tls_peer(@reason, {127, 0, 0, 1}, 0, trusted, :reject)

      source =
        case @reason do
          :wrong_ca ->
            %{upstream.source | trust: [untrusted.ca]}

          :wrong_host ->
            %{
              upstream.source
              | origin: String.replace(upstream.source.origin, "localhost", "other.invalid")
            }
        end

      fixture = fixture(:fixed)
      initial = candidate(fixture, source, @reason)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      current = activate(fixture, initial, expected)
      policy = :sys.get_state(fixture.transports).records[current.transport.resource].policy
      scope = :sys.get_state(fixture.transports).records[current.transport.resource].scope
      registration = :sys.get_state(fixture.transports).registration
      add_service(fixture)
      {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})
      service_barrier = denied_tls_service_barrier(service)
      owner_barrier = denied_tls_completion_barrier(fixture.transports)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("/never-unverified?"))
      captured = capture(fixture, current, @reason)
      native_monitor = Process.monitor(captured.native)
      send(captured.native, {:dispatch, captured.barrier})
      owner = fixture.transports
      handle = current.transport
      assert_receive {:tls_bind_held, ^owner, guardian, ^handle, token, completion}, @timeout
      assert %HTTP.RequestCompletion{} = completion
      guardian_monitor = Process.monitor(guardian)
      send(owner, {:continue_tls_bind, owner_barrier})
      assert response(socket) == {502, ""}
      label = @reason
      assert_receive {:peer_accepted, ^label, worker}, @timeout
      assert_receive {:peer_tls_rejected, ^label, ^worker, {:error, _}}, @timeout

      assert_receive {:transport_completion, ^owner, _, %HTTP.RequestCompletion{} = completion},
                     @timeout

      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      assert_receive {:tls_service_down_held, ^service, ^guardian,
                      {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      refute_receive {:tls_service_completion, ^service, ^guardian, _}, 0
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
      assert {:error, :transport_scope_retired} = HTTP.ManagedTransport.snapshot(scope, @timeout)
      assert {:ok, scope_receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, @timeout)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, 0)

      eventually(fn ->
        match?(
          {:ok, %{resources: 1, pins: 1, request_tokens: 1, reserved_connections: 2, helpers: 0}},
          Transports.status(owner)
        )
      end)

      hold = :sys.get_state(owner).tokens[token]
      assert hold.completion == completion
      assert hold.guardian_down
      assert hold.abort_helper == nil
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout

      assert :sys.get_state(fixture.transports).records[current.transport.resource].policy ==
               policy

      refute_receive {:peer_request, ^label, _, _}, 0
      refute_receive {:peer_tls, ^label, _, _, _, _}, 0
      refute_receive {:peer_accepted, ^label, _}, 0
      observe_denied_tls_retirement(owner, handle)

      assert {:error,
              {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}],
               [{^registration, {:error, :cleanup_unconfirmed}}]}} =
               stop_denied_tls_after_service_down(fixture.instance, service, service_barrier)

      for expected <- [
            :custodian_retiring,
            :custodian_helper_started,
            :custodian_helper_finished,
            :custodian_failed,
            :instance_down,
            :custodian_retiring,
            :custodian_helper_started,
            :custodian_helper_finished
          ] do
        assert_receive {:tls_retirement_phase, ^owner, event}, @timeout
        assert event == expected
      end

      store_monitor = Process.monitor(fixture.store)
      assert :ok = GenServer.stop(fixture.store, :normal, @timeout)
      assert_receive {:DOWN, ^store_monitor, :process, _, :normal}, @timeout

      eventually(fn ->
        match?(
          {:ok,
           %{
             resources: 1,
             pins: 0,
             request_tokens: 1,
             reserved_connections: 2,
             failed_resources: 1,
             helpers: 0
           }},
          Transports.status(owner)
        )
      end)

      record = :sys.get_state(owner).records[handle.resource]
      assert record.lifecycle == :failed
      assert record.transport_confirmed == false
      assert record.policy == policy
      custodian = :sys.get_state(record.custodian)
      assert custodian.failed
      assert custodian.confirmed == false
      assert custodian.control_calls == 2
      assert custodian.initial_mode == :graceful
      assert custodian.mode == :abort
      assert custodian.retire_helper == nil
      assert custodian.retry_helper == nil
      refute_receive {:tls_retirement_phase, ^owner, :custodian_retired}, 0
      assert {:ok, receipt} = Transports.retire(owner, Lifecycle.deadline(@timeout))

      assert {:error, :cleanup_unconfirmed} =
               Transports.await_retirement(receipt, Lifecycle.deadline(@timeout))

      assert {:error, :cleanup_unconfirmed} =
               Transports.await_retirement(receipt, Lifecycle.deadline(@timeout))

      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, 0)

      assert_no_native_outer_acquisition(fixture, captured.native)
      # Retained uncertainty is proved above. Dismantle only test-owned failed
      # actors; their DOWN is not a successful retirement or capacity refund.
      assert :ok = GenServer.stop(current.creator, :normal, @timeout)
      creator_monitor = current.creator_monitor
      assert_receive {:DOWN, ^creator_monitor, :process, _, :normal}, @timeout
      owner_monitor = Process.monitor(owner)
      assert :ok = GenServer.stop(owner, :normal, @timeout)
      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, @timeout
      :ok = upstream.wire.close(upstream.listener)
      peer_pid = upstream.pid
      peer_monitor = upstream.monitor
      assert_receive {:peer_joined, ^peer_pid, :ok}, @timeout
      assert_receive {:DOWN, ^peer_monitor, :process, ^peer_pid, :normal}, @timeout
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    test "#{kind} authenticates handoff events and consumes only one grant across duplicate replies" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :duplicates)

      native = captured.native
      owner = fixture.transports
      guardian_monitor = Process.monitor(guardian)
      native_monitor = Process.monitor(native)
      state = :sys.get_state(guardian)
      ref = state.transport_handoff
      identity = identity(fixture, current)
      event = {:transport_handoff, ref, current.transport, identity, state.deadline}
      delegation = delegation_barrier(owner)
      reply = handoff_reply_barrier(guardian)

      # These are queued before activation allows the genuine Session event.
      send(native, {:gaoxy_proxy_http, self(), event})

      send(
        native,
        {:gaoxy_proxy_http, guardian,
         {:transport_handoff, make_ref(), current.transport, identity, state.deadline}}
      )

      send(
        native,
        {:gaoxy_proxy_http, guardian,
         {:transport_handoff, ref, %{current.transport | resource: make_ref()}, identity,
          state.deadline}}
      )

      send(guardian, {:gaoxy_transport_handoff, make_ref(), {:error, :forged}, state.deadline})
      send(service, {:continue_attach, attach})

      assert_receive {:delegation_held, ^owner, ^native, handle, ^guardian, operation, deadline},
                     @timeout

      assert handle == current.transport
      assert :sys.get_state(guardian).awaiting_transport.handle == current.transport
      assert is_reference(operation)
      assert deadline <= state.deadline
      send(native, {:gaoxy_proxy_http, guardian, event})
      send(native, {:gaoxy_proxy_http, guardian, event})
      send(owner, {:continue_delegation, delegation})
      assert_receive {:handoff_reply_held, ^guardian, ^ref, {:ok, pin}, result_deadline}, @timeout
      assert pin.holder == guardian
      assert pin.handles == [current.transport]
      assert {:ok, %{pins: 3, request_tokens: 0}} = Transports.status(owner)
      assert_no_fetch(fixture, :duplicates)
      send(guardian, {:gaoxy_transport_handoff, ref, {:ok, pin}, result_deadline})
      send(guardian, {:gaoxy_transport_handoff, make_ref(), {:ok, pin}, result_deadline})
      send(guardian, {:continue_handoff_reply, reply})
      assert_receive {:peer_request, :duplicates, worker, head}, @timeout
      assert_receive {:peer_accepted, :duplicates, ^worker}, @timeout
      assert head =~ "GET /adversarial HTTP/1.1\r\n"
      if current.group, do: assert(worker == current.health_worker)
      {^guardian, completion} = bound_request(fixture, current, captured)
      send(native, {:gaoxy_proxy_http, guardian, event})
      send(guardian, {:gaoxy_transport_handoff, ref, {:ok, pin}, result_deadline})
      send(guardian, {:gaoxy_transport_handoff, ref, {:error, :stale}, result_deadline})
      # A system reply joins processing of the queued duplicate result messages.
      assert :sys.get_state(guardian).transport_pins == [pin]
      assert_once_transport_input(owner, native, :delegate_request_pin)
      assert_once_transport_input(owner, guardian, :checkout)
      send(worker, {:respond, "once"})
      assert response(socket) == {200, "once"}
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout

      assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                     @timeout

      send(guardian, {:gaoxy_transport_handoff, ref, {:ok, pin}, result_deadline})
      settled(fixture)
      refute_receive {:transport_input, ^owner, _, :delegate_request_pin}, 0
      refute_receive {:transport_input, ^owner, _, :checkout}, 0
      refute_receive {:peer_request, :duplicates, _, _}, 0
      assert_no_native_outer_acquisition(fixture, native)
      finish_fixture(fixture, [upstream], [current])
      assert_receive {:peer_eof, :duplicates, ^worker}, @timeout
    end
  end

  for kind <- [:fixed, :group], trigger <- [:cancel, :opening_timer, :native_down] do
    @kind kind
    @trigger trigger
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} awaiting Session responds to #{trigger} while delegation owner is withheld" do
      limits = if @trigger == :opening_timer, do: %{opening_timeout: 300}, else: %{}

      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :awaiting, limits)

      native = captured.native
      owner = fixture.transports
      native_monitor = Process.monitor(native)
      guardian_monitor = Process.monitor(guardian)
      health_before = if current.group, do: health_state(fixture, current.group)
      observe_session(guardian)
      barrier = delegation_barrier(owner)
      send(service, {:continue_attach, attach})
      assert_receive {:delegation_held, ^owner, ^native, _, ^guardian, operation, _}, @timeout
      state = :sys.get_state(guardian)
      assert state.awaiting_transport.handle == current.transport
      assert state.transport_pins == []
      assert state.request == nil
      assert state.transport_selection == nil

      case @trigger do
        :cancel ->
          Gaoxy.Proxy.HTTP.Session.cancel(guardian)

        :opening_timer ->
          assert is_reference(state.opening_timer)
          assert_receive {:session_input, ^guardian, :opening_expired}, @timeout
          assert Lifecycle.remaining(state.opening_deadline) == 0

        :native_down ->
          Process.exit(native, :kill)
      end

      # DOWN precedes owner release: awaiting does not synchronously block Session.
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_no_fetch(fixture, :awaiting)
      if current.group, do: assert(health_state(fixture, current.group) == health_before)
      send(owner, {:continue_delegation, barrier})
      assert_receive {:delegation_result, ^owner, ^native, {:error, _}}, @timeout
      :ok = :gen_tcp.close(socket)

      expected = if @trigger == :native_down, do: :killed, else: {:shutdown, :local_closed}
      assert_receive {:DOWN, ^native_monitor, :process, ^native, ^expected}, @timeout
      settled(fixture)
      assert_no_fetch(fixture, :awaiting)

      refute Enum.any?(:sys.get_state(owner).pins, fn {_, hold} ->
               hold.public.kind == :request
             end)

      if @trigger != :native_down do
        assert_receive {:delegation_cancel, ^owner, ^native, ^operation}, @timeout
      end

      assert_no_native_outer_acquisition(fixture, native)
      finish_fixture(fixture, [upstream], [current])
      if current.group, do: assert_receive({:peer_eof, :awaiting, _}, @timeout)
    end
  end

  for kind <- [:fixed, :group], actor <- [:session, :native] do
    @kind kind
    @actor actor
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} #{actor} death after grant before reply checkout leaves no surviving request hold" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :undelivered)

      native = captured.native
      native_monitor = Process.monitor(native)
      guardian_monitor = Process.monitor(guardian)
      ref = :sys.get_state(guardian).transport_handoff
      health_before = if current.group, do: health_state(fixture, current.group)

      if @actor == :session do
        handoff_reply_barrier(guardian)
        send(service, {:continue_attach, attach})
        assert_receive {:handoff_reply_held, ^guardian, ^ref, {:ok, pin}, _}, @timeout
        assert {:ok, %{pins: 3, request_tokens: 0}} = Transports.status(fixture.transports)
        assert pin.holder == guardian
        assert_no_fetch(fixture, :undelivered)
        service_down = denied_tls_service_barrier(service, guardian)
        Process.exit(guardian, :kill)
        assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :killed}, @timeout
        assert_receive {:tls_service_down_held, ^service, ^guardian, :killed}, @timeout
        assert response(socket) == {502, ""}

        assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                       @timeout

        eventually(fn ->
          match?({:ok, %{pins: 1, request_tokens: 0}}, Transports.status(fixture.transports))
        end)

        assert_no_fetch(fixture, :undelivered)

        if current.group do
          eventually(fn ->
            :sys.get_state(fixture.groups).groups[{current.group.group, current.group.generation}].lifecycle ==
              :failed
          end)

          assert [held] = Map.values(:sys.get_state(fixture.groups).tokens)
          assert held.guardian == guardian
          assert held.completion == nil
          assert health_state(fixture, current.group) == health_before
        end

        finish_killed_session(fixture, current, upstream, service, service_down)
      else
        owner = fixture.transports
        barrier = delegation_barrier(owner)
        send(service, {:continue_attach, attach})
        assert_receive {:delegation_held, ^owner, ^native, _, ^guardian, _, _}, @timeout
        assert :erlang.suspend_process(native)
        on_exit(fn -> if Process.alive?(native), do: :erlang.resume_process(native) end)
        send(owner, {:continue_delegation, barrier})
        assert_receive {:delegation_result, ^owner, ^native, {:ok, pin}}, @timeout
        assert pin.holder == guardian
        assert {:ok, %{pins: 3, request_tokens: 0}} = Transports.status(owner)
        assert :sys.get_state(guardian).transport_pins == []
        assert :sys.get_state(guardian).awaiting_transport.handle == current.transport
        assert_no_fetch(fixture, :undelivered)
        Process.exit(native, :kill)
        assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, @timeout
        assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
        :ok = :gen_tcp.close(socket)
        settled(fixture)
        assert_no_fetch(fixture, :undelivered)
        if current.group, do: assert(health_state(fixture, current.group) == health_before)

        refute Enum.any?(:sys.get_state(fixture.transports).pins, fn {_, hold} ->
                 hold.public.kind == :request
               end)

        finish_fixture(fixture, [upstream], [current])
        if current.group, do: assert_receive({:peer_eof, :undelivered, _}, @timeout)
      end
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} real native drain shortens a withheld delegation deadline and revokes as acquirer" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :drain)

      native = captured.native
      owner = fixture.transports
      native_monitor = Process.monitor(native)
      guardian_monitor = Process.monitor(guardian)
      ref = :sys.get_state(guardian).transport_handoff
      health_before = if current.group, do: health_state(fixture, current.group)
      barrier = delegation_barrier(owner)
      assert :erlang.trace(native, true, [:send, :receive]) == 1
      on_exit(fn -> if Process.alive?(native), do: :erlang.trace(native, false, [:all]) end)
      send(service, {:continue_attach, attach})

      assert_receive {:delegation_held, ^owner, ^native, _, ^guardian, operation, opening},
                     @timeout

      gate = :sys.get_state(guardian).gate
      deadline = Lifecycle.deadline(200)
      assert deadline < opening
      assert :ok = Gaoxy.Admission.drain(gate, deadline)

      eventually(fn ->
        {:messages, messages} = Process.info(native, :messages)
        Enum.any?(messages, &match?({:gaoxy_drain, ^gate, _, ^deadline}, &1))
      end)

      timer = make_ref()
      Process.send_after(self(), {:drain_deadline_elapsed, timer}, Lifecycle.remaining(deadline))
      assert_receive {:drain_deadline_elapsed, ^timer}, @timeout
      assert Lifecycle.remaining(deadline) == 0
      send(owner, {:continue_delegation, barrier})
      assert_receive {:delegation_result, ^owner, ^native, {:ok, pin}}, @timeout
      assert pin.holder == guardian

      assert_receive {:trace, ^native, :send,
                      {:gaoxy_transport_handoff, ^ref, {:error, :timeout}, ^deadline}, ^guardian},
                     @timeout

      assert_receive {:delegation_cancel, ^owner, ^native, ^operation}, @timeout

      assert_receive {:trace, ^native, :send, {:cancel_pins, ^native, ^operation}, ^owner},
                     @timeout

      refute Map.has_key?(:sys.get_state(owner).pins, pin.ref)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      :ok = :gen_tcp.close(socket)

      assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                     @timeout

      settled(fixture)
      assert_no_fetch(fixture, :drain)
      if current.group, do: assert(health_state(fixture, current.group) == health_before)
      refute Map.has_key?(:sys.get_state(owner).pins, pin.ref)
      finish_fixture(fixture, [upstream], [current])
      if current.group, do: assert_receive({:peer_eof, :drain, _}, @timeout)
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} Session death before Service activation allocates no grant or Fetch" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :session_down)

      guardian_monitor = Process.monitor(guardian)
      native_monitor = Process.monitor(captured.native)
      health_before = if current.group, do: health_state(fixture, current.group)
      Process.exit(guardian, :kill)
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :killed}, @timeout
      send(service, {:continue_attach, attach})
      assert response(socket) == {503, ""}
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
      settled(fixture)
      assert_no_fetch(fixture, :session_down)
      refute_receive {:transport_input, _, _, :delegate_request_pin}, 0
      if current.group, do: assert(health_state(fixture, current.group) == health_before)
      finish_fixture(fixture, [upstream], [current])
      if current.group, do: assert_receive({:peer_eof, :session_down, _}, @timeout)
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} explicit owner retirement overrides a closed old snapshot before dispatch" do
      old_peer = peer(:retired_old)
      new_peer = peer(:retired_new)
      fixture = fixture(@kind)
      old = candidate(fixture, old_peer.source, :retired_old)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      old = fixture |> activate(old, expected) |> then(&healthy(fixture, &1))
      add_service(fixture)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("/retired"))
      captured = capture(fixture, old, :retired_old)
      native_monitor = Process.monitor(captured.native)
      next = candidate(fixture, new_peer.source, :retired_new)
      next = healthy(fixture, next)
      next = activate(fixture, next, old.generation)
      await_closed(fixture, old, captured)
      health_before = if old.group, do: health_state(fixture, old.group)
      flush_transport_inputs(fixture.transports)
      deadline = Lifecycle.deadline(@timeout)
      assert {:ok, receipt} = Transports.retire(fixture.transports, deadline)
      assert :ok = Transports.await_retirement(receipt, deadline)
      assert_zero_transport(fixture.transports)
      send(captured.native, {:dispatch, captured.barrier})
      assert response(socket) == {502, ""}
      assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
      settled(fixture, 0)
      assert_no_fetch(fixture, :retired_old)
      assert_no_fetch(fixture, :retired_new)

      if old.group do
        # The record may already have retired after its original native pin.
        stored = :sys.get_state(fixture.groups).groups[{old.group.group, old.group.generation}]

        if stored,
          do:
            assert(
              Enum.map(stored.members, &Map.take(&1, [:health, :checked, :failures, :successes])) ==
                health_before
            )
      end

      assert :ok = Transports.await_retirement(receipt, Lifecycle.deadline(@timeout))
      assert_no_native_outer_acquisition(fixture, captured.native)
      finish_fixture(fixture, [old_peer, new_peer], [old, next], 0)

      if @kind == :group do
        assert_receive {:peer_eof, :retired_old, _}, @timeout
        assert_receive {:peer_eof, :retired_new, _}, @timeout
      end
    end
  end

  for kind <- [:fixed, :group], cancellation <- [:session_cancel, :native_down] do
    @kind kind
    @cancellation cancellation
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} original completion and response ACK remain charged across #{cancellation}" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :retained_ack)

      native = captured.native
      owner = fixture.transports
      guardian_monitor = Process.monitor(guardian)
      native_monitor = Process.monitor(native)
      send(service, {:continue_attach, attach})
      assert_receive {:peer_request, :retained_ack, worker, _}, @timeout
      assert_receive {:peer_accepted, :retained_ack, ^worker}, @timeout
      {^guardian, completion} = bound_request(fixture, current, captured)
      send(worker, :respond_stream)
      assert head(socket) =~ "200 OK"
      assert :erlang.suspend_process(native)

      try do
        send(worker, :stream_chunk)
        eventually(fn -> :sys.get_state(guardian).delivery != nil end)
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

        assert {:ok, %{request_tokens: 1, pins: 3, reserved_connections: 2}} =
                 Transports.status(owner)

        assert %{active: 1, cleanup_pending: 1, retained_bytes: bytes} =
                 Gaoxy.status(fixture.instance, :http)

        assert bytes > 0
        gate = :sys.get_state(guardian).gate
        [cleanup] = Map.values(:sys.get_state(gate).cleanups)
        assert cleanup.bytes > 0
        barrier = cancellation_barrier(guardian, @cancellation, native)

        if @cancellation == :session_cancel do
          Gaoxy.Proxy.HTTP.Session.cancel(guardian)
        else
          Process.exit(native, :kill)
          assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, @timeout
        end

        assert_receive {:session_cancellation_held, ^guardian, trigger}, @timeout
        assert trigger == @cancellation
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
        expected_pins = if @cancellation == :native_down, do: 2, else: 3

        eventually(fn ->
          match?(
            {:ok, %{request_tokens: 1, pins: ^expected_pins, reserved_connections: 2}},
            Transports.status(owner)
          )
        end)

        assert {:ok, %{request_tokens: 1, pins: ^expected_pins, reserved_connections: 2}} =
                 Transports.status(owner)

        assert %{cleanup_pending: 1, retained_bytes: retained} =
                 Gaoxy.status(fixture.instance, :http)

        expected_bytes = if @cancellation == :native_down, do: cleanup.bytes, else: bytes
        assert retained == expected_bytes
        send(guardian, {:continue_session_cancellation, barrier})
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
        if Process.alive?(native), do: :erlang.resume_process(native)
        :ok = :gen_tcp.close(socket)

        if @cancellation == :session_cancel do
          assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                         @timeout
        end

        settled(fixture)
        refute_receive {:peer_request, :retained_ack, _, _}, 0
        finish_fixture(fixture, [upstream], [current])
        assert_receive {:peer_eof, :retained_ack, ^worker}, @timeout
      after
        if Process.alive?(native), do: :erlang.resume_process(native)
      end
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} short owner retirement and stop failures survive independent late completion" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :late_join)

      native = captured.native
      owner = fixture.transports
      guardian_monitor = Process.monitor(guardian)
      native_monitor = Process.monitor(native)
      instance_monitor = Process.monitor(fixture.instance)
      owner_monitor = Process.monitor(owner)
      send(service, {:continue_attach, attach})
      assert_receive {:peer_request, :late_join, worker, _}, @timeout
      assert_receive {:peer_accepted, :late_join, ^worker}, @timeout
      {^guardian, completion} = bound_request(fixture, current, captured)
      send(worker, :respond_stream)
      assert head(socket) =~ "200 OK"
      assert :erlang.suspend_process(native)

      try do
        send(worker, :stream_chunk)
        eventually(fn -> :sys.get_state(guardian).delivery != nil end)
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

        assert {:ok, %{request_tokens: 1, pins: 3, reserved_connections: 2}} =
                 Transports.status(owner)

        cancellation = cancellation_barrier(guardian, :service_cancel, native)
        retirement = lifecycle_retirement_barrier(owner)
        instance_completion = instance_completion_barrier(fixture.instance)
        stop_failure = Gaoxy.stop(fixture.instance, 0)
        assert stop_failure == {:error, {:deadline_exceeded, :cleanup_pending}}
        assert_receive {:lifecycle_retirement_held, ^owner, issued_deadline}, @timeout
        assert Lifecycle.remaining(issued_deadline) == 0
        assert_receive {:session_cancellation_held, ^guardian, :service_cancel}, @timeout
        assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, @timeout
        assert_receive {:instance_completion_held, instance, operation_result}, @timeout
        assert instance == fixture.instance
        assert operation_result == stop_failure
        # Both actual cleanup paths are held: the failed public stop precedes
        # the independent original-completion/EOF join below.
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
        send(owner, {:continue_lifecycle_retirement, retirement})
        assert {:ok, receipt} = Transports.retire(owner, Lifecycle.deadline(@timeout))
        failure = Transports.await_retirement(receipt, Lifecycle.deadline(@timeout))
        assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
        send(guardian, {:continue_session_cancellation, cancellation})
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        assert_receive {:peer_eof, :late_join, ^worker}, @timeout
        assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
        eventually(fn -> zero_transport?(owner) end)
        assert :sys.get_state(owner).retirement.result == failure
        assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
        send(fixture.instance, {:continue_instance_completion, instance_completion})
        assert_receive {:DOWN, ^instance_monitor, :process, _, :normal}, @timeout
        assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, @timeout
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
        assert stop_failure == {:error, {:deadline_exceeded, :cleanup_pending}}
        assert :ok = GenServer.stop(fixture.store, :normal, @timeout)

        if fixture.groups do
          eventually(fn ->
            state = :sys.get_state(fixture.groups)

            state.groups == %{} and state.pins == %{} and state.tokens == %{} and
              state.probes == %{} and state.bytes == 0 and state.probe_bytes == 0
          end)

          group_monitor = Process.monitor(fixture.groups)
          assert :ok = GenServer.stop(fixture.groups, :normal, @timeout)
          assert_receive {:DOWN, ^group_monitor, :process, _, :normal}, @timeout
        end

        creator = current.creator
        creator_monitor = current.creator_monitor
        assert_receive {:DOWN, ^creator_monitor, :process, ^creator, :normal}, @timeout
        close_peer(upstream)
      after
        if Process.alive?(native), do: :erlang.resume_process(native)
        :gen_tcp.close(socket)
      end
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} actual Service monitor remains responsive while delegation is withheld" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :service_down)

      native = captured.native
      owner = fixture.transports
      guardian_monitor = Process.monitor(guardian)
      native_monitor = Process.monitor(native)
      service_monitor = Process.monitor(service)
      health_before = if current.group, do: health_state(fixture, current.group)
      barrier = delegation_barrier(owner)
      send(service, {:continue_attach, attach})
      assert_receive {:delegation_held, ^owner, ^native, _, ^guardian, _, _}, @timeout
      assert :sys.get_state(guardian).awaiting_transport.handle == current.transport
      Process.exit(service, :kill)
      assert_receive {:DOWN, ^service_monitor, :process, ^service, :killed}, @timeout
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_no_fetch(fixture, :service_down)
      if current.group, do: assert(health_state(fixture, current.group) == health_before)
      send(owner, {:continue_delegation, barrier})
      assert_receive {:delegation_result, ^owner, ^native, {:error, _}}, @timeout
      :ok = :gen_tcp.close(socket)
      assert_receive {:DOWN, ^native_monitor, :process, ^native, _}, @timeout
      # Service is transient: its replacement has independent admission state.
      eventually(fn ->
        match?(
          {:ok, replacement, _} when replacement != service,
          GenServer.call(fixture.instance, {:lookup, :http})
        )
      end)

      settled(fixture)
      assert_no_fetch(fixture, :service_down)
      finish_fixture(fixture, [upstream], [current])
      if current.group, do: assert_receive({:peer_eof, :service_down, _}, @timeout)
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    test "#{kind} public instance stop overrides an actually closed held snapshot" do
      old_peer = peer(:stopped_old)
      new_peer = peer(:stopped_new)
      fixture = fixture(@kind)
      old = candidate(fixture, old_peer.source, :stopped_old)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      old = fixture |> activate(old, expected) |> then(&healthy(fixture, &1))
      add_service(fixture)
      socket = connect(fixture.instance)
      :ok = :gen_tcp.send(socket, request("/stopped"))
      captured = capture(fixture, old, :stopped_old)
      native = captured.native
      native_monitor = Process.monitor(native)
      owner_monitor = Process.monitor(fixture.transports)
      instance_monitor = Process.monitor(fixture.instance)
      next = candidate(fixture, new_peer.source, :stopped_new)
      next = healthy(fixture, next)
      next = activate(fixture, next, old.generation)
      await_closed(fixture, old, captured)
      flush_transport_inputs(fixture.transports)
      parent = self()

      {caller, caller_monitor} =
        spawn_monitor(fn ->
          send(parent, {:instance_stop_result, self(), Gaoxy.stop(fixture.instance, @timeout)})
        end)

      eventually(fn ->
        {:messages, messages} = Process.info(native, :messages)
        Enum.any?(messages, &match?({:gaoxy_drain, _, _, _}, &1))
      end)

      eventually(fn -> zero_transport?(fixture.transports) end)
      assert_no_fetch(fixture, :stopped_old)
      assert_no_fetch(fixture, :stopped_new)
      send(native, {:dispatch, captured.barrier})
      assert response(socket) == {503, ""}

      assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                     @timeout

      assert_receive {:instance_stop_result, ^caller, :ok}, @timeout
      assert_receive {:DOWN, ^caller_monitor, :process, ^caller, :normal}, @timeout
      assert_receive {:DOWN, ^instance_monitor, :process, _, :normal}, @timeout
      assert_receive {:DOWN, ^owner_monitor, :process, _, :normal}, @timeout
      assert :ok = GenServer.stop(fixture.store, :normal, @timeout)

      for candidate <- [old, next] do
        creator = candidate.creator
        monitor = candidate.creator_monitor
        assert_receive {:DOWN, ^monitor, :process, ^creator, :normal}, @timeout
      end

      if fixture.groups do
        eventually(fn ->
          state = :sys.get_state(fixture.groups)

          state.groups == %{} and state.pins == %{} and state.tokens == %{} and
            state.probes == %{} and state.bytes == 0 and state.probe_bytes == 0
        end)

        assert :ok = GenServer.stop(fixture.groups, :normal, @timeout)
      end

      close_peer(old_peer)
      close_peer(new_peer)

      if @kind == :group do
        assert_receive {:peer_eof, :stopped_old, _}, @timeout
        assert_receive {:peer_eof, :stopped_new, _}, @timeout
      end
    end
  end

  for kind <- [:fixed, :group] do
    @kind kind
    @tag :generation_adversarial
    @tag :generation_lifecycle
    @tag :generation_revocation_deadline
    test "#{kind} expired real drain revokes without waiting on the held grant owner" do
      {fixture, current, upstream, socket, captured, service, attach, guardian} =
        awaiting_fixture(@kind, :revocation_held)

      native = captured.native
      owner = fixture.transports
      native_monitor = Process.monitor(native)
      guardian_monitor = Process.monitor(guardian)
      ref = :sys.get_state(guardian).transport_handoff
      gate = :sys.get_state(guardian).gate
      health_before = if current.group, do: health_state(fixture, current.group)
      admission = delegation_barrier(owner)
      grant = granted_reply_barrier(owner)
      assert :erlang.trace(native, true, [:send]) == 1
      assert :erlang.trace(gate, true, [:send]) == 1

      on_exit(fn ->
        for actor <- [native, gate],
            Process.alive?(actor),
            do: :erlang.trace(actor, false, [:all])
      end)

      send(service, {:continue_attach, attach})

      assert_receive {:delegation_held, ^owner, ^native, _, ^guardian, operation, opening},
                     @timeout

      deadline = Lifecycle.deadline(200)
      assert deadline < opening
      assert :ok = Gaoxy.Admission.drain(gate, deadline)

      assert_receive {:trace, ^gate, :send, {:gaoxy_drain, ^gate, lease, ^deadline}, ^native},
                     @timeout

      assert is_reference(lease)
      elapsed = make_ref()

      Process.send_after(
        self(),
        {:revocation_deadline_elapsed, elapsed},
        Lifecycle.remaining(deadline)
      )

      assert_receive {:revocation_deadline_elapsed, ^elapsed}, @timeout
      assert Lifecycle.remaining(deadline) == 0
      send(owner, {:continue_delegation, admission})
      assert_receive {:granted_reply_held, ^owner, ^native, ^operation, pin}, @timeout
      assert pin.holder == guardian
      assert pin.operation == operation
      assert pin.handles == [current.transport]

      # Owner has sent the authentic success reply and is now withheld. The
      # observation budget is the same 200ms drain budget, not a new operation D;
      # it excludes the fresh 1000ms synchronous release currently used here.
      assert_receive {:trace, ^native, :send, {:cancel_pins, ^native, ^operation}, ^owner}, 200

      assert_receive {:trace, ^native, :send,
                      {:gaoxy_transport_handoff, ^ref, {:error, :timeout}, ^deadline}, ^guardian},
                     200

      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_no_fetch(fixture, :revocation_held)
      if current.group, do: assert(health_state(fixture, current.group) == health_before)

      # Preserve a real failed public retirement while the owner is still held;
      # later confirmation and zero accounting must not rewrite its result.
      failure = Transports.retire(owner, Lifecycle.deadline(0))
      assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
      send(owner, {:continue_granted_reply, grant})
      assert_receive {:delegation_cancel, ^owner, ^native, ^operation}, @timeout
      :ok = :gen_tcp.close(socket)

      assert_receive {:DOWN, ^native_monitor, :process, ^native, {:shutdown, :local_closed}},
                     @timeout

      settled(fixture, 0)
      assert {:ok, receipt} = Transports.retire(owner, Lifecycle.deadline(@timeout))
      assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
      eventually(fn -> zero_transport?(owner) end)
      refute Map.has_key?(:sys.get_state(owner).pins, pin.ref)
      assert :sys.get_state(owner).retirement.result == failure
      assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
      assert_no_native_outer_acquisition(fixture, native)
      assert_no_fetch(fixture, :revocation_held)
      assert :ok = GenServer.stop(fixture.store, :normal, @timeout)
      join_retired(fixture, current)

      if fixture.groups do
        eventually(fn ->
          state = :sys.get_state(fixture.groups)

          state.groups == %{} and state.pins == %{} and state.tokens == %{} and
            state.probes == %{} and state.bytes == 0 and state.probe_bytes == 0
        end)

        group_monitor = Process.monitor(fixture.groups)
        assert :ok = GenServer.stop(fixture.groups, :normal, @timeout)
        assert_receive {:DOWN, ^group_monitor, :process, _, :normal}, @timeout
        assert_receive {:peer_eof, :revocation_held, worker}, @timeout
        assert worker == current.health_worker
      else
        assert {:error, :timeout} = :gen_tcp.accept(upstream.listener, 0)
      end

      assert_zero_transport(owner)
      assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
      owner_monitor = Process.monitor(owner)
      instance_monitor = Process.monitor(fixture.instance)
      assert Gaoxy.stop(fixture.instance, @timeout) == failure
      assert_receive {:DOWN, ^instance_monitor, :process, _, :normal}, @timeout
      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, @timeout
      close_peer(upstream)
      assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
    end
  end

  defp granted_reply_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn state, event, _ ->
      case {state, event} do
        {:waiting,
         {:in, {:"$gen_call", {caller, _}, {:delegate_request_pin, _, _, _, _, _, operation, _}}}} ->
          {:reply_pending, caller, operation}

        {{:reply_pending, caller, operation}, {:out, {:ok, pin}, _, _}} ->
          send(parent, {:granted_reply_held, self(), caller, operation, pin})

          receive do
            {:continue_granted_reply, ^barrier} -> :ok
          after
            @timeout -> raise "Generation post-grant owner barrier expired"
          end

          :held

        _ ->
          state
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, :waiting})
    on_exit(fn -> send(owner, {:continue_granted_reply, barrier}) end)
    barrier
  end

  for kind <- [:fixed, :group], protocol <- [:tcp, :tls] do
    @kind kind
    @protocol protocol
    @tag :generation_peers
    @tag :generation_streaming
    @tag :tmp_dir
    test "#{kind} #{protocol} old and fresh snapshots preserve streamed POST bodies and ordered trailers",
         context do
      {old_peer, new_peer, chains} = streamed_generation_peers(@protocol, context)
      fixture = fixture(@kind)
      prepared = candidate(fixture, old_peer.source, :stream_old)
      assert {:ok, expected, _} = Generation.snapshot(fixture.store)
      old = activate(fixture, prepared, expected)
      old = healthy(fixture, old)
      add_service(fixture)
      old_target = "/old%2Fupload?raw=%2F&empty="
      old_parts = [<<0, 255, "old\r\n">>, <<1, 2, "tail", 0>>]

      old_trailers = [
        {"x-trace", "old first"},
        {"x-checksum", "old 00ff"},
        {"x-trace", "old last"}
      ]

      old_socket = connect(fixture.instance)
      :ok = :gen_tcp.send(old_socket, [streamed_post(old_target), chunk_frame(hd(old_parts))])
      captured = capture(fixture, old, :stream_old)
      old_native_monitor = Process.monitor(captured.native)
      assert_no_native_outer_acquisition(fixture, captured.native)

      prepared = candidate(fixture, new_peer.source, :stream_new)
      prepared = healthy(fixture, prepared)
      fresh = activate(fixture, prepared, old.generation)
      refute fresh.generation == old.generation
      await_closed(fixture, old, captured)
      flush_transport_inputs(fixture.transports)
      assert_streamed_policy(fixture, old, fresh, chains)

      {old_worker, old_guardian, old_completion, old_guardian_monitor} =
        dispatch_streamed_post(
          fixture,
          old,
          old_peer,
          captured,
          old_socket,
          old_target,
          old_parts,
          old_trailers
        )

      assert_streamed_tls(old_worker, :stream_old, chains, :old)

      new_target = "/fresh%2Fupload?"
      new_parts = [<<255, 0, "new">>, <<3, 4, "\r\nlast", 255>>]

      new_trailers = [
        {"x-trace", "new first"},
        {"x-checksum", "new ff00"},
        {"x-trace", "new last"}
      ]

      new_socket = connect(fixture.instance)
      :ok = :gen_tcp.send(new_socket, [streamed_post(new_target), chunk_frame(hd(new_parts))])
      fresh_capture = capture(fixture, fresh, :stream_new)
      fresh_native_monitor = Process.monitor(fresh_capture.native)

      {new_worker, new_guardian, new_completion, new_guardian_monitor} =
        dispatch_streamed_post(
          fixture,
          fresh,
          new_peer,
          fresh_capture,
          new_socket,
          new_target,
          new_parts,
          new_trailers
        )

      assert_streamed_tls(new_worker, :stream_new, chains, :new)
      refute old_completion == new_completion
      old_response = [<<255, 0, "old response\r\n">>, <<0, 1, "end">>]
      new_response = [<<0, 255, "fresh response">>, <<2, 3, "\r\nend">>]

      old_response_trailers = [
        {"x-trace", "old response first"},
        {"x-checksum", "old response sum"},
        {"x-trace", "old response last"}
      ]

      new_response_trailers = [
        {"x-trace", "new response first"},
        {"x-checksum", "new response sum"},
        {"x-trace", "new response last"}
      ]

      # The fresh request completes while the authentic old request still owns
      # its closed Generation resource and waits on its old physical peer.
      send(new_worker, {:respond_trailers, new_response, new_response_trailers})

      assert streamed_response(new_socket) ==
               {IO.iodata_to_binary(new_response), new_response_trailers}

      assert :ok = HTTP.RequestCompletion.await(new_completion, @timeout)
      assert_receive {:DOWN, ^new_guardian_monitor, :process, ^new_guardian, :normal}, @timeout

      assert_receive {:DOWN, ^fresh_native_monitor, :process, _, {:shutdown, :local_closed}},
                     @timeout

      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(old_completion, 0)
      send(old_worker, {:respond_trailers, old_response, old_response_trailers})

      assert streamed_response(old_socket) ==
               {IO.iodata_to_binary(old_response), old_response_trailers}

      assert :ok = HTTP.RequestCompletion.await(old_completion, @timeout)
      assert_receive {:DOWN, ^old_guardian_monitor, :process, ^old_guardian, :normal}, @timeout

      assert_receive {:DOWN, ^old_native_monitor, :process, _, {:shutdown, :local_closed}},
                     @timeout

      join_retired(fixture, old)
      assert_receive {:peer_eof, :stream_old, ^old_worker}, @timeout
      assert_no_native_outer_acquisition(fixture, captured.native)
      assert_no_native_outer_acquisition(fixture, fresh_capture.native)
      refute_receive {:peer_request, :stream_old, _, _}, 0
      refute_receive {:peer_request, :stream_new, _, _}, 0
      refute_receive {:peer_accepted, :stream_old, _}, 0
      refute_receive {:peer_accepted, :stream_new, _}, 0
      settled(fixture)
      retirement_deadline = Lifecycle.deadline(@timeout)
      assert {:ok, receipt} = Transports.retire(fixture.transports, retirement_deadline)
      assert :ok = Transports.await_retirement(receipt, retirement_deadline)
      assert_zero_transport(fixture.transports)
      finish_fixture(fixture, [old_peer, new_peer], [fresh], 0)
      assert_receive {:peer_eof, :stream_new, ^new_worker}, @timeout
      refute_receive {:peer_request, :stream_old, _, _}, 0
      refute_receive {:peer_request, :stream_new, _, _}, 0
      refute_receive {:peer_accepted, :stream_old, _}, 0
      refute_receive {:peer_accepted, :stream_new, _}, 0
    end
  end

  defp streamed_generation_peers(:tcp, _context), do: {peer(:stream_old), peer(:stream_new), nil}

  defp streamed_generation_peers(:tls, context) do
    old_chain = tls_chain(Path.join(context.tmp_dir, "stream-old"))
    new_chain = tls_chain(Path.join(context.tmp_dir, "stream-new"))
    refute old_chain.ca == new_chain.ca
    refute old_chain.leaf == new_chain.leaf
    old_peer = tls_peer(:stream_old, {127, 0, 0, 1}, 0, old_chain)
    port = URI.parse(old_peer.source.origin).port
    new_peer = tls_peer(:stream_new, {127, 0, 0, 2}, port, new_chain)
    assert old_peer.source.origin == new_peer.source.origin
    {old_peer, new_peer, %{old: old_chain, new: new_chain}}
  end

  defp assert_streamed_policy(_fixture, _old, _fresh, nil), do: :ok

  defp assert_streamed_policy(fixture, old, fresh, chains) do
    state = :sys.get_state(fixture.transports)
    old_policy = state.records[old.transport.resource].policy
    new_policy = state.records[fresh.transport.resource].policy
    assert old_policy.connect_address == {127, 0, 0, 1}
    assert new_policy.connect_address == {127, 0, 0, 2}
    assert old_policy.open_options[:ssl][:cacerts] == [chains.old.ca]
    assert new_policy.open_options[:ssl][:cacerts] == [chains.new.ca]
  end

  defp assert_streamed_tls(_worker, _label, nil, _generation), do: :ok

  defp assert_streamed_tls(worker, label, chains, generation) do
    leaf = chains[generation].leaf
    assert_receive {:peer_tls, ^label, ^worker, "localhost", nil, ^leaf}, @timeout
    refute_receive {:peer_tls, ^label, _, _, _, _}, 0
  end

  defp dispatch_streamed_post(
         fixture,
         candidate,
         peer,
         captured,
         socket,
         target,
         [first, last],
         trailers
       ) do
    owner = fixture.transports
    label = candidate.label
    native = captured.native
    transport = candidate.transport
    transport_barrier = stream_binding_barrier(owner, :transport)
    group_barrier = if candidate.group, do: stream_binding_barrier(fixture.groups, :group)
    send(native, {:dispatch, captured.barrier})

    assert_receive {:stream_binding_held, ^owner, guardian, :transport, ^transport, token,
                    completion},
                   @timeout

    guardian_monitor = Process.monitor(guardian)
    assert match?(%HTTP.RequestCompletion{}, completion)
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    assert :erlang.trace(guardian, true, [:send]) == 1
    on_exit(fn -> if Process.alive?(guardian), do: :erlang.trace(guardian, false, [:all]) end)
    refute_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, _, {:ready, _, _, _}}, _}, 0
    assert_receive {:peer_request, ^label, worker, upstream_head}, @timeout
    assert_receive {:peer_accepted, ^label, ^worker}, @timeout
    if candidate.group, do: assert(worker == candidate.health_worker)
    assert String.starts_with?(upstream_head, "POST #{target} HTTP/1.1\r\n")
    fields = stream_fields(upstream_head)
    assert {"host", URI.parse(peer.source.origin).authority} in fields
    assert {"transfer-encoding", "chunked"} in fields
    assert {"trailer", "x-trace, x-checksum"} in fields
    refute Enum.any?(fields, fn {name, _} -> name == "content-length" end)
    send(worker, {:stream_upload, first})
    assert_receive {:peer_upload_waiting, ^label, ^worker}, @timeout
    send(owner, {:continue_stream_binding, transport_barrier})

    if candidate.group do
      groups = fixture.groups
      group = candidate.group

      assert_receive {:stream_binding_held, ^groups, ^guardian, :group, ^group, _, ^completion},
                     @timeout

      held = :sys.get_state(owner).tokens[token]
      assert held.guardian == guardian
      assert held.completion == completion
      refute_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, _, {:ready, _, _, _}}, _}, 0
      send(worker, :assert_no_upload)
      assert_receive {:peer_upload_blocked, ^label, ^worker}, @timeout
      send(groups, {:continue_stream_binding, group_barrier})
    end

    assert_receive {:trace, ^guardian, :send, {:gaoxy_proxy_http, ^guardian, {:ready, _, _, _}},
                    ^native},
                   @timeout

    assert :erlang.trace(guardian, false, [:send]) == 1
    assert {^guardian, ^completion} = bound_request(fixture, candidate, captured)
    state = :sys.get_state(guardian)
    assert state.transport_selection == {transport, token}
    assert state.client.completion(state.original_request) == completion
    assert_no_native_outer_acquisition(fixture, native)
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    send(worker, {:read_upload, first})
    assert_receive {:peer_upload_first, ^label, ^worker, ^first}, @timeout
    # Receipt of the first real upstream body gates the second fragmented chunk
    # and final ordered trailers; the upload cannot be a single buffered replay.
    :ok = :gen_tcp.send(socket, [Integer.to_string(byte_size(last), 16), "\r"])
    :ok = :gen_tcp.send(socket, ["\n", last, "\r\n0\r\n"])
    :ok = :gen_tcp.send(socket, [trailer_frame(trailers), "\r\n"])
    body = first <> last
    assert_receive {:peer_upload_complete, ^label, ^worker, ^body, ^trailers}, @timeout
    refute_receive {:peer_upload_complete, ^label, _, _, _}, 0
    assert_once_transport_input(owner, native, :delegate_request_pin)
    assert_once_transport_input(owner, guardian, :checkout)
    {worker, guardian, completion, guardian_monitor}
  end

  defp stream_binding_barrier(owner, kind) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, {operation, handle, token, completion}}}
        when not held and
               ((kind == :transport and operation == :bind_completion) or
                  (kind == :group and operation == :bind)) ->
          send(parent, {:stream_binding_held, self(), caller, kind, handle, token, completion})

          receive do
            {:continue_stream_binding, ^barrier} -> :ok
          after
            @timeout -> raise "Generation streamed completion binding barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, false})
    on_exit(fn -> send(owner, {:continue_stream_binding, barrier}) end)
    barrier
  end

  defp streamed_post(target),
    do:
      "POST #{target} HTTP/1.1\r\nHost: downstream.test\r\nTransfer-Encoding: chunked\r\nTrailer: x-trace, x-checksum\r\nConnection: close\r\n\r\n"

  defp chunk_frame(bytes), do: [Integer.to_string(byte_size(bytes), 16), "\r\n", bytes, "\r\n"]

  defp trailer_frame(trailers),
    do: Enum.map(trailers, fn {name, value} -> [name, ": ", value, "\r\n"] end)

  defp stream_fields(head) do
    [_start | fields] = String.split(head, "\r\n", trim: true)

    Enum.map(fields, fn field ->
      [name, value] = String.split(field, ":", parts: 2)
      {String.downcase(name), String.trim(value)}
    end)
  end

  defp await_streamed_upload(wire, socket, parent, label, first) do
    receive do
      :assert_no_upload ->
        assert {:error, :timeout} = wire.recv(socket, 1, 0)
        send(parent, {:peer_upload_blocked, label, self()})
        await_streamed_upload(wire, socket, parent, label, first)

      {:read_upload, ^first} ->
        {body, trailers} = chunked_payload(wire, socket, "", {parent, label, first})
        send(parent, {:peer_upload_complete, label, self(), body, trailers})

        receive do
          {:respond_trailers, chunks, response_trailers} ->
            assert chunks != []

            :ok =
              wire.send(socket, [
                "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: x-trace, x-checksum\r\n\r\n",
                Enum.map(chunks, &chunk_frame/1),
                "0\r\n",
                trailer_frame(response_trailers),
                "\r\n"
              ])
        after
          @timeout -> raise "Generation streamed response barrier expired"
        end
    after
      @timeout -> raise "Generation streamed upload barrier expired"
    end
  end

  defp streamed_response(socket) do
    response_head = head(socket)
    assert String.starts_with?(response_head, "HTTP/1.1 200 OK\r\n")
    fields = stream_fields(response_head)

    assert Enum.filter(fields, fn {name, _} -> name == "transfer-encoding" end) ==
             [{"transfer-encoding", "chunked"}]

    assert Enum.filter(fields, fn {name, _} -> name == "trailer" end) ==
             [{"trailer", "x-trace, x-checksum"}]

    refute Enum.any?(fields, fn {name, _} -> name == "content-length" end)
    result = chunked_payload(:gen_tcp, socket, "", nil)
    # This consumes the sole zero chunk, ordered trailers and final CRLF above;
    # physical close here rejects a second terminator or trailing/replayed body.
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    :ok = :gen_tcp.close(socket)
    result
  end

  defp chunked_payload(wire, socket, body, progress) do
    size_line = stream_line(wire, socket)
    assert size_line =~ ~r/^[0-9a-fA-F]+\r\n$/
    size = size_line |> String.trim_trailing("\r\n") |> String.to_integer(16)
    assert size <= 65_536

    if size == 0 do
      assert progress == nil
      {body, stream_trailers(wire, socket, [])}
    else
      assert {:ok, bytes} = wire.recv(socket, size, @timeout)
      assert {:ok, "\r\n"} = wire.recv(socket, 2, @timeout)
      body = body <> bytes
      assert byte_size(body) <= 65_536

      progress =
        case progress do
          {parent, label, first} when byte_size(body) >= byte_size(first) ->
            assert body == first
            send(parent, {:peer_upload_first, label, self(), body})
            nil

          _ ->
            progress
        end

      chunked_payload(wire, socket, body, progress)
    end
  end

  defp stream_line(wire, socket, bytes \\ "") do
    assert byte_size(bytes) <= 4_096
    assert {:ok, byte} = wire.recv(socket, 1, @timeout)
    bytes = bytes <> byte
    if String.ends_with?(bytes, "\r\n"), do: bytes, else: stream_line(wire, socket, bytes)
  end

  defp stream_trailers(wire, socket, reversed) do
    assert length(reversed) <= 16

    case stream_line(wire, socket) do
      "\r\n" ->
        Enum.reverse(reversed)

      field ->
        [name, value] = field |> String.trim_trailing("\r\n") |> String.split(":", parts: 2)
        assert String.downcase(name) in ["x-trace", "x-checksum"]
        stream_trailers(wire, socket, [{String.downcase(name), String.trim(value)} | reversed])
    end
  end

  defp awaiting_fixture(kind, label, limits \\ %{}) do
    upstream = peer(label)
    fixture = fixture(kind)
    prepared = candidate(fixture, upstream.source, label, :none, limits)
    assert {:ok, expected, _} = Generation.snapshot(fixture.store)
    current = activate(fixture, prepared, expected)
    current = healthy(fixture, current)
    flush_transport_inputs(fixture.transports)
    add_service(fixture)
    {:ok, service, _} = GenServer.call(fixture.instance, {:lookup, :http})
    attach = attach_barrier(service)
    socket = connect(fixture.instance)
    :ok = :gen_tcp.send(socket, request("/adversarial"))
    captured = capture(fixture, current, label)
    send(captured.native, {:dispatch, captured.barrier})
    assert_receive {:attach_cleanup_held, ^service, native, guardian}, @timeout
    assert native == captured.native
    assert :sys.get_state(guardian).transport_pins == []
    {fixture, current, upstream, socket, captured, service, attach, guardian}
  end

  defp delegation_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in,
         {:"$gen_call", {caller, _},
          {:delegate_request_pin, handle, _, guardian, _, _, operation, deadline}}}
        when not held ->
          send(parent, {:delegation_held, self(), caller, handle, guardian, operation, deadline})

          receive do
            {:continue_delegation, ^barrier} -> :ok
          after
            @timeout -> raise "Generation delegation barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, false})
    on_exit(fn -> send(owner, {:continue_delegation, barrier}) end)
    barrier
  end

  defp handoff_reply_barrier(guardian) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:gaoxy_transport_handoff, ref, {:ok, _} = result, deadline}} when not held ->
          send(parent, {:handoff_reply_held, self(), ref, result, deadline})

          receive do
            {:continue_handoff_reply, ^barrier} -> :ok
          after
            @timeout -> raise "Generation Session reply barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(guardian, {make_ref(), debug, false})
    on_exit(fn -> send(guardian, {:continue_handoff_reply, barrier}) end)
    barrier
  end

  defp observe_session(guardian) do
    parent = self()

    debug = fn state, event, _ ->
      case event do
        {:in, :opening_expired} -> send(parent, {:session_input, self(), :opening_expired})
        _ -> :ok
      end

      state
    end

    :ok = :sys.install(guardian, {make_ref(), debug, nil})
  end

  defp cancellation_barrier(guardian, trigger, native) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      matches =
        case event do
          {:in, {:"$gen_cast", :cancel}} -> trigger == :session_cancel
          {:in, {:gaoxy_cleanup_cancel, _, _, _}} -> trigger == :service_cancel
          {:in, {:DOWN, _, :process, ^native, :killed}} -> trigger == :native_down
          _ -> false
        end

      if matches and not held do
        send(parent, {:session_cancellation_held, self(), trigger})

        receive do
          {:continue_session_cancellation, ^barrier} -> :ok
        after
          @timeout -> raise "Generation Session cancellation barrier expired"
        end

        true
      else
        held
      end
    end

    :ok = :sys.install(guardian, {make_ref(), debug, false})
    on_exit(fn -> send(guardian, {:continue_session_cancellation, barrier}) end)
    barrier
  end

  defp lifecycle_retirement_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:gaoxy_lifecycle_drain, _, _, _, deadline}} when not held ->
          send(parent, {:lifecycle_retirement_held, self(), deadline})

          receive do
            {:continue_lifecycle_retirement, ^barrier} -> :ok
          after
            @timeout -> raise "Generation owner retirement barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, false})
    on_exit(fn -> send(owner, {:continue_lifecycle_retirement, barrier}) end)
    barrier
  end

  defp instance_completion_barrier(instance) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:operation_done, _, result}} when not held ->
          send(parent, {:instance_completion_held, self(), result})

          receive do
            {:continue_instance_completion, ^barrier} -> :ok
          after
            @timeout -> raise "Generation instance completion barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(instance, {make_ref(), debug, false})
    on_exit(fn -> send(instance, {:continue_instance_completion, barrier}) end)
    barrier
  end

  defp assert_once_transport_input(owner, caller, operation) do
    :sys.get_state(owner)
    assert_receive {:transport_input, ^owner, ^caller, ^operation}, @timeout
    refute_receive {:transport_input, ^owner, _, ^operation}, 0
  end

  defp assert_no_fetch(fixture, label) do
    owner = fixture.transports
    refute_receive {:transport_input, ^owner, _, :checkout}, 0
    refute_receive {:peer_request, ^label, _, _}, 0
    if fixture.kind == :fixed, do: refute_receive({:peer_accepted, ^label, _}, 0)
  end

  defp zero_transport?(owner) do
    match?(
      {:ok,
       %{
         resources: 0,
         pins: 0,
         request_tokens: 0,
         helpers: 0,
         reserved_connections: 0,
         owned_serialized_payload_bytes: 0
       }},
      Transports.status(owner)
    )
  end

  defp assert_zero_transport(owner), do: assert(zero_transport?(owner))

  defp close_peer(peer) do
    :ok = peer.wire.close(peer.listener)
    pid = peer.pid
    monitor = peer.monitor
    assert_receive {:peer_joined, ^pid, :ok}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
  end

  defp finish_killed_session(fixture, current, upstream, service, service_barrier) do
    deadline = Lifecycle.deadline(@timeout)
    assert {:ok, receipt} = Transports.retire(fixture.transports, deadline)
    assert :ok = Transports.await_retirement(receipt, deadline)
    assert_zero_transport(fixture.transports)
    assert :ok = GenServer.stop(fixture.store, :normal, @timeout)
    join_retired_transport(current)

    if current.group do
      state = :sys.get_state(fixture.groups)
      assert map_size(state.tokens) == 1
      assert map_size(state.groups) == 1
      assert state.pins == %{}
      assert state.bytes > 0
      assert state.groups[{current.group.group, current.group.generation}].lifecycle == :failed
      # Dismantling this failed test actor is not a public selection receipt or
      # a successful capacity refund; the charged uncertainty above is retained.
      monitor = Process.monitor(fixture.groups)
      assert :ok = GenServer.stop(fixture.groups, :normal, @timeout)
      assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    end

    owner_monitor = Process.monitor(fixture.transports)

    assert {:error,
            {:shutdown, [{:http, {:error, {:cleanup_failed, :cleanup_receipt_missing}}}], []}} =
             stop_denied_tls_after_service_down(fixture.instance, service, service_barrier)

    assert_receive {:DOWN, ^owner_monitor, :process, _, :normal}, @timeout
    close_peer(upstream)
    if current.group, do: assert_receive({:peer_eof, :undelivered, _}, @timeout)
  end

  defp join_retired_transport(candidate) do
    creator = candidate.creator
    monitor = candidate.creator_monitor
    assert_receive {:DOWN, ^monitor, :process, ^creator, :normal}, @timeout
  end

  defp denied_tls_completion_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {guardian, _}, {:bind_completion, handle, token, completion}}}
        when not held ->
          send(parent, {:tls_bind_held, self(), guardian, handle, token, completion})

          receive do
            {:continue_tls_bind, ^barrier} -> :ok
          after
            @timeout -> raise "Generation denied TLS completion barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {debug, false})
    on_exit(fn -> send(owner, {:continue_tls_bind, barrier}) end)
    barrier
  end

  defp denied_tls_service_barrier(service, initial_guardian \\ nil) do
    parent = self()
    barrier = make_ref()

    debug = fn guardian, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:attach_cleanup, _, _, next, _, _}}} ->
          next

        {:in, {:"$gen_call", {caller, _}, {:complete_cleanup, token}}} ->
          send(parent, {:tls_service_completion, self(), caller, token})
          guardian

        {:in, {:DOWN, _, :process, pid, reason}} when pid == guardian ->
          send(parent, {:tls_service_down_held, self(), pid, reason})

          receive do
            {:continue_tls_service_down, ^barrier} -> :ok
          after
            @timeout -> raise "Generation denied TLS Service DOWN barrier expired"
          end

          guardian

        _ ->
          guardian
      end
    end

    :ok = :sys.install(service, {debug, initial_guardian})
    on_exit(fn -> send(service, {:continue_tls_service_down, barrier}) end)
    barrier
  end

  defp stop_denied_tls_after_service_down(instance, service, barrier) do
    parent = self()

    {caller, monitor} =
      spawn_monitor(fn ->
        send(parent, {:tls_stop_result, self(), Gaoxy.stop(instance, @timeout)})
      end)

    eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)

    send(service, {:continue_tls_service_down, barrier})
    assert_receive {:tls_stop_result, ^caller, result}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, @timeout
    result
  end

  defp observe_denied_tls_retirement(owner, handle) do
    parent = self()
    resource = handle.resource
    instance_monitor = :sys.get_state(owner).instance_monitor

    debug = fn state, event, _ ->
      case event do
        {:in, {kind, ^resource, _, _}}
        when kind in [:custodian_retiring, :custodian_failed, :custodian_retired] ->
          send(parent, {:tls_retirement_phase, self(), kind})

        {:in, {kind, ^resource, _, _, _}}
        when kind in [:custodian_helper_started, :custodian_helper_finished] ->
          send(parent, {:tls_retirement_phase, self(), kind})

        {:in, {:DOWN, ^instance_monitor, :process, _, _}} ->
          send(parent, {:tls_retirement_phase, self(), :instance_down})

        _ ->
          :ok
      end

      state
    end

    :ok = :sys.install(owner, {debug, nil})
  end

  defp complete_request(fixture, candidate, target, bytes, await_settled \\ true) do
    socket = connect(fixture.instance)
    :ok = :gen_tcp.send(socket, request(target))
    captured = capture(fixture, candidate, candidate.label)
    native_monitor = Process.monitor(captured.native)
    send(captured.native, {:dispatch, captured.barrier})
    label = candidate.label
    assert_receive {:peer_request, ^label, worker, head}, @timeout
    assert_receive {:peer_accepted, ^label, ^worker}, @timeout
    if candidate.group, do: assert(worker == candidate.health_worker)
    assert head =~ "GET #{target} HTTP/1.1\r\n"
    {guardian, completion} = bound_request(fixture, candidate, captured)
    guardian_monitor = Process.monitor(guardian)
    assert_no_native_outer_acquisition(fixture, captured.native)
    send(worker, {:respond, bytes})
    assert response(socket) == {200, bytes}
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
    assert_receive {:DOWN, ^native_monitor, :process, _, {:shutdown, :local_closed}}, @timeout
    if await_settled, do: settled(fixture)
    worker
  end

  defp steady_sample(fixture) do
    settled(fixture)
    assert {:ok, transport} = Transports.status(fixture.transports)

    assert %{resources: 1, pins: 1, request_tokens: 0, helpers: 0, reserved_connections: 2} =
             transport

    groups =
      if fixture.groups do
        state = :sys.get_state(fixture.groups)
        assert map_size(state.groups) == 1
        assert map_size(state.pins) == 1
        assert state.tokens == %{}
        assert state.probes == %{}
        assert state.probe_bytes == 0
        %{groups: map_size(state.groups), pins: map_size(state.pins), bytes: state.bytes}
      end

    {Map.take(transport, [
       :resources,
       :pins,
       :request_tokens,
       :helpers,
       :reserved_connections,
       :owned_serialized_payload_bytes
     ]), groups}
  end

  defp fixture(kind) do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)

    {:ok, transports} =
      Transports.start_link(
        instance: instance,
        limits: %{
          max_resources: 4,
          max_pins: 32,
          max_request_tokens: 64,
          max_owned_payload_bytes: 4_194_304
        }
      )

    Process.unlink(transports)

    groups =
      if kind == :group do
        {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: %{max_probes: 1})
        Process.unlink(groups)
        groups
      end

    {:ok, store} = Generation.start_link(routes: [])
    Process.unlink(store)

    fixture = %{
      kind: kind,
      instance: instance,
      transports: transports,
      groups: groups,
      store: store
    }

    observe_transport(transports)

    on_exit(fn ->
      # Failure-only actor cleanup is not a successful acceptance receipt.
      for actor <- [store, instance, groups, transports],
          is_pid(actor) and Process.alive?(actor) do
        Lifecycle.protect(fn -> GenServer.stop(actor, :normal, @timeout) end)
        if Process.alive?(actor), do: Process.exit(actor, :kill)
      end
    end)

    fixture
  end

  defp candidate(fixture, source, label, corruption \\ :none, limits \\ %{}) do
    parent = self()

    {coordinator, monitor} =
      spawn_monitor(fn ->
        deadline = Lifecycle.deadline(15_000)

        {:ok, transport, preparation} =
          Transports.prepare(fixture.transports, source, self(), deadline)

        {module, options, group, pins} =
          if fixture.kind == :group do
            {:ok, compiled} =
              UpstreamGroups.compile(%{
                id: "generation",
                members: [%{id: "member", upstream: source.origin, transport: transport}],
                health: %{
                  path: "/health",
                  interval: 60_000,
                  stale_after: 120_000,
                  timeout: 2_000,
                  jitter: 0,
                  recovery_threshold: 1
                }
              })

            {:ok, group, group_preparation} =
              UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline)

            {GroupEndpoint, %{group: group}, group, preparation ++ group_preparation}
          else
            {ProxyHTTP, %{upstream: source.origin, transport: transport}, nil, preparation}
          end

        options = Map.merge(options, limits)
        routes = [%{target: {SnapshotEndpoint, {module, options, parent, label, corruption}}}]
        {:ok, router} = Generation.prepare(fixture.store, routes, @timeout)
        creator = :sys.get_state(fixture.transports).records[transport.resource].custodian
        send(parent, {:candidate_ready, self(), transport, group, router, creator})

        receive do
          {:activate, expected} ->
            result = Generation.activate(fixture.store, expected, router, @timeout)

            if match?({:ok, _}, result) do
              baseline = :sys.get_state(fixture.store).baseline
              assert transport in Enum.flat_map(baseline, & &1.handles)
              assert Enum.all?(baseline, &(&1.kind == :baseline))
            end

            assert :ok = Resources.release(pins)
            send(parent, {:candidate_activated, self(), result})

          :abort ->
            Resources.release(pins)
        after
          @timeout ->
            Resources.release(pins)
            raise "Generation candidate activation barrier expired"
        end
      end)

    on_exit(fn ->
      send(coordinator, :abort)

      if Process.alive?(coordinator) do
        monitor = Process.monitor(coordinator)

        receive do
          {:DOWN, ^monitor, :process, ^coordinator, _} -> :ok
        after
          @timeout -> Process.exit(coordinator, :kill)
        end
      end
    end)

    assert_receive {:candidate_ready, ^coordinator, transport, group, router, creator}, @timeout

    %{
      coordinator: coordinator,
      monitor: monitor,
      transport: transport,
      group: group,
      router: router,
      creator: creator,
      creator_monitor: Process.monitor(creator),
      source: source,
      label: label
    }
  end

  defp activate(fixture, candidate, expected) do
    send(candidate.coordinator, {:activate, expected})
    coordinator = candidate.coordinator
    monitor = candidate.monitor
    assert_receive {:candidate_activated, ^coordinator, {:ok, generation}}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
    assert {:ok, ^generation, router} = Generation.snapshot(fixture.store)
    assert router == candidate.router
    assert configured_pins(fixture, candidate.transport) == [:baseline]
    Map.put(candidate, :generation, generation)
  end

  defp healthy(_fixture, %{group: nil} = candidate), do: candidate

  defp healthy(fixture, candidate) do
    label = candidate.label
    assert_receive {:peer_head, ^label, worker, head}, @timeout
    assert head =~ "HEAD /health HTTP/1.1\r\n"

    eventually(fn ->
      case UpstreamGroups.status(candidate.group) do
        %{members: [%{health: :healthy, probe: false}], probes: 0, inflight: 0} ->
          match?({:ok, %{request_tokens: 0}}, Transports.status(fixture.transports))

        _ ->
          false
      end
    end)

    Map.put(candidate, :health_worker, worker)
  end

  defp add_service(fixture) do
    {:ok, spec} =
      Gaoxy.HTTP.service_spec(
        id: :http,
        endpoint: {Generation, fixture.store},
        limits: %{max_bytes: 33_554_432}
      )

    assert {:ok, _} = Gaoxy.add(fixture.instance, spec)
  end

  defp capture(fixture, candidate, label) do
    assert_receive {:captured_snapshot, native, barrier, ^label, pins, handles}, @timeout
    on_exit(fn -> send(native, {:dispatch, barrier}) end)

    expected =
      if candidate.group, do: [candidate.group, candidate.transport], else: [candidate.transport]

    assert MapSet.new(handles) == MapSet.new(expected)
    assert MapSet.new(Enum.flat_map(pins, & &1.handles)) == MapSet.new(expected)

    for pin <- pins do
      if pin.provider == Transports do
        hold = :sys.get_state(fixture.transports).pins[pin.ref]
        assert hold.public == pin
        assert map_size(pin) == 8
        assert pin.kind == :request
        assert pin.holder == native
        assert hold.acquirer == fixture.store
      else
        assert pin.provider == UpstreamGroups
        hold = :sys.get_state(fixture.groups).pins[pin.ref]
        assert hold.kind == :request
        assert hold.holder == native
        assert hold.acquirer == fixture.store
      end
    end

    assert Enum.count(pins, &(&1.provider == Transports)) == 1
    %{native: native, barrier: barrier, pins: pins, handles: handles}
  end

  defp await_closed(fixture, old, captured) do
    eventually(fn ->
      configured_pins(fixture, old.transport) == [] and
        Transports.validate_endpoint(
          old.transport,
          identity(fixture, old),
          Lifecycle.deadline(@timeout)
        ) ==
          {:error, :resource_admission_closed}
    end)

    hold = :sys.get_state(fixture.transports).pins[transport_pin(captured).ref]
    assert hold.public == transport_pin(captured)
    assert :sys.get_state(fixture.transports).records[old.transport.resource].admission == :closed

    if old.group do
      state = :sys.get_state(fixture.groups)
      assert state.groups[{old.group.group, old.group.generation}].lifecycle == :retiring

      refute Enum.any?(state.pins, fn {_, pin} ->
               {old.group.group, old.group.generation} in pin.keys and
                 pin.kind in [:baseline, :preparation]
             end)

      assert UpstreamGroups.status(old.group).probes == 0
    end
  end

  defp configured_pins(fixture, transport),
    do:
      for(
        {_, hold} <- :sys.get_state(fixture.transports).pins,
        transport in hold.public.handles,
        hold.public.kind in [:baseline, :preparation],
        do: hold.public.kind
      )

  defp identity(fixture, candidate),
    do: %{origin: candidate.source.origin, upstream_protocol: :http1, instance: fixture.instance}

  defp transport_pin(captured), do: Enum.find(captured.pins, &(&1.provider == Transports))

  defp bound_request(fixture, candidate, captured) do
    eventually(fn ->
      Enum.any?(:sys.get_state(fixture.transports).tokens, fn {_, hold} ->
        hold.resource == candidate.transport.resource and
          match?(%HTTP.RequestCompletion{}, hold.completion)
      end)
    end)

    [{_, token}] =
      Enum.filter(:sys.get_state(fixture.transports).tokens, fn {_, hold} ->
        hold.resource == candidate.transport.resource
      end)

    guardian = token.guardian
    state = :sys.get_state(fixture.transports)

    native_pins =
      for {_, hold} <- state.pins,
          hold.public.kind == :request and hold.public.holder == captured.native,
          candidate.transport in hold.public.handles,
          do: hold.public

    assert native_pins == [transport_pin(captured)]

    guardian_pins =
      for {_, hold} <- state.pins,
          hold.public.kind == :request and hold.public.holder == guardian,
          candidate.transport in hold.public.handles,
          do: hold.public

    assert [guardian_pin] = guardian_pins
    refute guardian_pin.ref == transport_pin(captured).ref

    if candidate.group do
      eventually(fn ->
        Enum.any?(:sys.get_state(fixture.groups).tokens, fn {_, hold} ->
          hold.guardian == guardian and hold.completion == token.completion
        end)
      end)
    end

    {guardian, token.completion}
  end

  defp observe_transport(owner) do
    parent = self()

    debug = fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, {:pin_many, handles, holder, :request, _, _}}} ->
          send(parent, {:native_outer_acquisition, self(), caller, holder, handles})
          state

        {:in, {:"$gen_call", {caller, _}, {:bind_completion, _, _, completion}}} ->
          send(parent, {:transport_completion, self(), caller, completion})
          send(parent, {:transport_input, self(), caller, :bind_completion})
          state

        {:in, {:cancel_pins, caller, operation}} ->
          send(parent, {:delegation_cancel, self(), caller, operation})
          state

        {:in, {:"$gen_call", {caller, _}, {:release, pin}}} ->
          send(parent, {:delegated_pin_release, self(), caller, [pin]})
          send(parent, {:transport_input, self(), caller, :release})
          state

        {:in, {:"$gen_call", {caller, _}, message}}
        when is_tuple(message) and elem(message, 0) == :delegate_request_pin ->
          send(parent, {:transport_input, self(), caller, :delegate_request_pin})
          {:delegating, caller}

        {:out, result, _, _} ->
          case state do
            {:delegating, caller} -> send(parent, {:delegation_result, self(), caller, result})
            _ -> :ok
          end

          nil

        {:in, {:"$gen_call", {caller, _}, message}} when is_tuple(message) ->
          send(parent, {:transport_input, self(), caller, elem(message, 0)})
          state

        _ ->
          state
      end
    end

    # An explicit ID keeps tuple callback state distinct from sys's named
    # callback entry; otherwise {:delegating, caller} removes this observer.
    :ok = :sys.install(owner, {make_ref(), debug, nil})
  end

  defp flush_transport_inputs(owner) do
    # Owner-to-test messages preceding this system reply are already delivered.
    # Healthy probes have joined before this observation boundary.
    :sys.get_state(owner)
    drain_transport_inputs(owner)
  end

  defp drain_transport_inputs(owner) do
    receive do
      {:transport_input, ^owner, _, _} -> drain_transport_inputs(owner)
    after
      0 -> :ok
    end
  end

  defp health_state(fixture, group) do
    stored = :sys.get_state(fixture.groups).groups[{group.group, group.generation}]
    Enum.map(stored.members, &Map.take(&1, [:health, :checked, :failures, :successes]))
  end

  defp assert_no_native_outer_acquisition(fixture, native) do
    owner = fixture.transports
    refute_receive {:native_outer_acquisition, ^owner, ^native, _, _}, 0
  end

  defp attach_barrier(service) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {native, _}, {:attach_cleanup, _, _, guardian, _, _}}}
        when not held ->
          send(parent, {:attach_cleanup_held, self(), native, guardian})

          receive do
            {:continue_attach, ^barrier} -> :ok
          after
            @timeout -> raise "Generation Service activation barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(service, {debug, false})
    on_exit(fn -> send(service, {:continue_attach, barrier}) end)
    barrier
  end

  defp settled(fixture, expected_pins \\ nil) do
    expected_pins = expected_pins || if(Process.alive?(fixture.store), do: 1, else: 0)

    eventually(fn ->
      match?(
        %{active: 0, cleanup_pending: 0, retained_bytes: 0},
        Gaoxy.status(fixture.instance, :http)
      ) and
        match?(
          {:ok, %{request_tokens: 0, helpers: 0, pins: ^expected_pins}},
          Transports.status(fixture.transports)
        )
    end)
  end

  defp join_retired(fixture, candidate) do
    eventually(fn ->
      not Map.has_key?(:sys.get_state(fixture.transports).records, candidate.transport.resource)
    end)

    creator = candidate.creator
    monitor = candidate.creator_monitor
    assert_receive {:DOWN, ^monitor, :process, ^creator, :normal}, @timeout

    if candidate.group do
      refute Map.has_key?(
               :sys.get_state(fixture.groups).groups,
               {candidate.group.group, candidate.group.generation}
             )
    end
  end

  defp finish_fixture(fixture, peers, candidates, expected_pins \\ nil) do
    settled(fixture, expected_pins)

    if Process.alive?(fixture.store) do
      monitor = Process.monitor(fixture.store)
      assert :ok = GenServer.stop(fixture.store, :normal, @timeout)
      assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    end

    eventually(fn ->
      match?(
        {:ok,
         %{
           resources: 0,
           pins: 0,
           request_tokens: 0,
           helpers: 0,
           reserved_connections: 0,
           owned_serialized_payload_bytes: 0
         }},
        Transports.status(fixture.transports)
      )
    end)

    for candidate <- candidates, do: join_retired(fixture, candidate)

    if fixture.groups do
      eventually(fn ->
        state = :sys.get_state(fixture.groups)

        state.groups == %{} and state.pins == %{} and state.tokens == %{} and
          state.probes == %{} and state.bytes == 0 and state.probe_bytes == 0
      end)

      monitor = Process.monitor(fixture.groups)
      assert :ok = GenServer.stop(fixture.groups, :normal, @timeout)
      assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    end

    monitor = Process.monitor(fixture.transports)
    assert :ok = Gaoxy.stop(fixture.instance, @timeout)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout

    for peer <- peers do
      :ok = peer.wire.close(peer.listener)
      assert_receive {:peer_joined, pid, :ok} when pid == peer.pid, @timeout
      monitor = peer.monitor
      assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    end
  end

  defp peer(label) do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()

    {pid, monitor} =
      spawn_monitor(fn -> accept_loop(:gen_tcp, listener, parent, label, [], nil) end)

    on_exit(fn ->
      :gen_tcp.close(listener)

      if Process.alive?(pid) do
        monitor = Process.monitor(pid)

        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          @timeout -> Process.exit(pid, :kill)
        end
      end
    end)

    %{
      pid: pid,
      monitor: monitor,
      listener: listener,
      wire: :gen_tcp,
      source: %{origin: "http://localhost:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}
    }
  end

  defp tls_chain(directory) do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    {log, status} = System.cmd("bash", [script, directory], stderr_to_stdout: true)
    assert status == 0, log

    [{:Certificate, ca, :not_encrypted}] =
      :public_key.pem_decode(File.read!(Path.join(directory, "ca.pem")))

    [{:Certificate, leaf, :not_encrypted}] =
      :public_key.pem_decode(File.read!(Path.join(directory, "cert.pem")))

    %{directory: directory, ca: ca, leaf: leaf}
  end

  defp tls_peer(label, address, port, chain, expected \\ :accept) do
    assert {:ok, listener} =
             :ssl.listen(port, [
               :binary,
               active: false,
               ip: address,
               reuseaddr: true,
               certfile: Path.join(chain.directory, "cert.pem"),
               keyfile: Path.join(chain.directory, "key.pem"),
               alpn_preferred_protocols: ["h2", "http/1.1"]
             ])

    assert {:ok, {^address, port}} = :ssl.sockname(listener)
    parent = self()
    tls = %{expected: expected, leaf: chain.leaf}
    {pid, monitor} = spawn_monitor(fn -> accept_loop(:ssl, listener, parent, label, [], tls) end)

    on_exit(fn ->
      :ssl.close(listener)

      if Process.alive?(pid) do
        monitor = Process.monitor(pid)

        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          @timeout -> Process.exit(pid, :kill)
        end
      end
    end)

    %{
      pid: pid,
      monitor: monitor,
      listener: listener,
      wire: :ssl,
      source: %{origin: "https://localhost:#{port}", connect_address: address, trust: [chain.ca]}
    }
  end

  defp accept_loop(wire, listener, parent, label, workers, tls) do
    accepted =
      if wire == :ssl,
        do: :ssl.transport_accept(listener, @timeout),
        else: :gen_tcp.accept(listener, @timeout)

    case accepted do
      {:ok, socket} ->
        peer = self()

        {worker, monitor} =
          spawn_monitor(fn ->
            receive do
              :ready ->
                result =
                  try do
                    if wire == :ssl do
                      result = :ssl.handshake(socket, @timeout)

                      if tls.expected == :reject do
                        assert {:error, _} = result
                        send(parent, {:peer_tls_rejected, label, self(), result})
                        :ok
                      else
                        assert {:ok, socket} = result

                        assert {:ok, information} =
                                 :ssl.connection_information(socket, [:sni_hostname])

                        assert {:error, :protocol_not_negotiated} =
                                 :ssl.negotiated_protocol(socket)

                        send(
                          parent,
                          {:peer_tls, label, self(), to_string(information[:sni_hostname]), nil,
                           tls.leaf}
                        )

                        serve(wire, socket, parent, label)
                      end
                    else
                      serve(wire, socket, parent, label)
                    end
                  rescue
                    error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
                  after
                    wire.close(socket)
                  end

                send(peer, {:worker_finished, self(), result})
            after
              @timeout -> raise "Generation peer ownership barrier expired"
            end
          end)

        :ok = wire.controlling_process(socket, worker)
        send(worker, :ready)
        send(parent, {:peer_accepted, label, worker})
        accept_loop(wire, listener, parent, label, [{worker, monitor} | workers], tls)

      {:error, :timeout} ->
        accept_loop(wire, listener, parent, label, workers, tls)

      {:error, :closed} ->
        results =
          for {worker, monitor} <- workers do
            assert_receive {:worker_finished, ^worker, result}, @timeout
            assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
            result
          end

        send(parent, {:peer_joined, self(), Enum.find(results, :ok, &(&1 != :ok))})
    end
  end

  defp serve(wire, socket, parent, label) do
    case wire.recv(socket, 1, @timeout) do
      {:ok, first} ->
        head = upstream_head(wire, socket, first)

        if String.starts_with?(head, "HEAD /health HTTP/1.1\r\n") do
          send(parent, {:peer_head, label, self(), head})
          :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        else
          send(parent, {:peer_request, label, self(), head})

          if label in [:missing_group, :missing_transport, :fake_transport] do
            # Erroneous admission must fail the strict denial assertion directly,
            # rather than wait for a response command that denial never sends.
            bytes = "unexpected admitted GET"

            :ok =
              wire.send(socket, [
                "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(bytes)}\r\n\r\n",
                bytes
              ])
          else
            receive do
              {:respond, bytes} ->
                :ok =
                  wire.send(socket, [
                    "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(bytes)}\r\n\r\n",
                    bytes
                  ])

              :respond_stream ->
                :ok = wire.send(socket, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")

                receive do
                  :stream_chunk -> :ok
                after
                  @timeout -> raise "Generation stream chunk barrier expired"
                end

                :ok = wire.send(socket, "4\r\nbody\r\n")

              {:stream_upload, first} ->
                assert {:error, :timeout} = wire.recv(socket, 1, 0)
                send(parent, {:peer_upload_waiting, label, self()})
                await_streamed_upload(wire, socket, parent, label, first)
            after
              @timeout -> raise "Generation peer response barrier expired"
            end
          end
        end

        serve(wire, socket, parent, label)

      {:error, :closed} ->
        send(parent, {:peer_eof, label, self()})
        :ok

      {:error, :timeout} ->
        serve(wire, socket, parent, label)
    end
  end

  defp upstream_head(wire, socket, bytes) do
    assert byte_size(bytes) <= 65_536

    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, byte} = wire.recv(socket, 1, @timeout)
      upstream_head(wire, socket, bytes <> byte)
    end
  end

  defp connect(instance) do
    {:ok, {ip, port}} = Gaoxy.info(instance, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp request(target),
    do: "GET #{target} HTTP/1.1\r\nHost: downstream.test\r\nConnection: close\r\n\r\n"

  defp head(socket, bytes \\ "") do
    assert byte_size(bytes) <= 65_536

    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
      head(socket, bytes <> byte)
    end
  end

  defp response(socket) do
    headers = head(socket)
    [_, status] = Regex.run(~r/^HTTP\/1\.1 ([0-9]{3}) /, headers)
    [_, length] = Regex.run(~r/\r\ncontent-length: ([0-9]+)\r\n/i, headers)
    length = String.to_integer(length)

    bytes =
      if length == 0 do
        ""
      else
        assert {:ok, bytes} = :gen_tcp.recv(socket, length, @timeout)
        bytes
      end

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    :gen_tcp.close(socket)
    {String.to_integer(status), bytes}
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@timeout)

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(deadline) > 0,
             "Generation fixture did not settle before deadline"

      receive do
      after
        2 -> eventually(fun, deadline)
      end
    end
  end
end
