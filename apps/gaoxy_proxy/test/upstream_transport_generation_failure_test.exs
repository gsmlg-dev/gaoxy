defmodule Gaoxy.Proxy.UpstreamTransportGenerationFailureTest do
  use ExUnit.Case, async: false

  alias Gaoxy.HTTP.{Generation, Resources, Router}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @moduletag :capture_log
  @moduletag :generation_peers
  @timeout 3_000

  test "invalid candidate routes release fresh and shared preparation without changing the active baseline" do
    active_peer = peer(:active)
    rejected_peer = peer(:invalid)
    fixture = fixture()
    active = install(fixture, active_peer)
    before = accounting(fixture.transports)
    candidate = coordinator()
    rejected = prepare_transport(candidate, fixture.transports, rejected_peer.source)
    hold_shared(candidate, active.transport)

    routes = [route(rejected), %{path: "/bad%gg", target: {ProxyHTTP, options(active)}}]
    assert {:error, :invalid_route_path} = prepare_routes(candidate, fixture.store, routes)
    assert_current(fixture, active)
    release_coordinator(candidate)
    rejected = join_resource(rejected)
    assert accounting(fixture.transports) == before
    assert_current(fixture, active)
    request_current(fixture, active_peer, "/after-invalid%2Froute?")
    finish(fixture, [active, rejected], [active_peer, rejected_peer])
  end

  test "candidate transport capacity failure rolls back an admitted prefix and preserves shared active handles" do
    active_peer = peer(:active)
    rejected_peer = peer(:capacity)
    fixture = fixture(%{max_resources: 2})
    active = install(fixture, active_peer)
    before = accounting(fixture.transports)
    candidate = coordinator()
    rejected = prepare_transport(candidate, fixture.transports, rejected_peer.source)
    hold_shared(candidate, active.transport)
    held = accounting(fixture.transports)
    assert %{resources: 2, reserved_connections: 4, pins: 3, request_tokens: 0} = held

    assert {:error, {:capacity, :resources}} =
             rpc(candidate, fn pins ->
               {Transports.prepare(fixture.transports, rejected_peer.source, self(), deadline()),
                pins}
             end)

    assert accounting(fixture.transports) == held
    assert_current(fixture, active)
    release_coordinator(candidate)
    rejected = join_resource(rejected)
    assert accounting(fixture.transports) == before
    assert_current(fixture, active)
    request_current(fixture, active_peer, "/after-transport-capacity")
    finish(fixture, [active, rejected], [active_peer, rejected_peer])
  end

  test "candidate group capacity failure cancels provisional dependency pins and retires only its fresh transport" do
    active_peer = peer(:active)
    rejected_peer = peer(:group_capacity)
    fixture = fixture(%{}, %{max_groups: 1, max_probes: 1})
    active = install(fixture, active_peer, :group)
    healthy(active.group, active_peer)
    before = accounting(fixture.transports)
    group_before = group_accounting(active.group)
    candidate = coordinator()
    rejected = prepare_transport(candidate, fixture.transports, rejected_peer.source)
    hold_shared(candidate, active.transport)
    held = accounting(fixture.transports)

    assert {:error, :group_capacity} =
             rpc(candidate, fn pins ->
               {:ok, compiled} = group_options(rejected)
               {UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline()), pins}
             end)

    # Public status calls share the coordinator's ordering with dependency cancel.
    assert rpc(candidate, fn pins -> {accounting(fixture.transports), pins} end) == held
    assert group_accounting(active.group) == group_before
    assert_current(fixture, active)
    release_coordinator(candidate)
    rejected = join_resource(rejected)
    assert accounting(fixture.transports) == before
    assert group_accounting(active.group) == group_before
    assert_current(fixture, active)
    request_current(fixture, active_peer, "/after-group-capacity")
    finish(fixture, [active, rejected], [active_peer, rejected_peer])
  end

  test "partial baseline acquisition across two real owners rolls back the first batch exactly" do
    active_peer = peer(:active)
    first_peer = peer(:partial_first)
    second_peer = peer(:partial_second)
    fixture = fixture()
    other = transport_owner(fixture.instance, %{})
    # Establish the batch-key order before allocating candidates, so the active
    # baseline has an exact isolated accounting sample. Real handles below must
    # confirm this order through the public Resources batching normalization.
    [{{Transports, first_owner}, _}, {{Transports, second_owner}, _}] =
      Enum.group_by([fixture.transports, other], &{Transports, &1}) |> Enum.to_list()

    fixture = %{fixture | transports: first_owner, owners: [first_owner, second_owner]}
    active = install(fixture, active_peer)
    active_before = accounting(first_owner)
    candidate = coordinator()
    first = prepare_transport(candidate, first_owner, first_peer.source)
    second = prepare_transport(candidate, second_owner, second_peer.source)
    second_handle = second.transport
    hold_shared(candidate, active.transport)

    routes = [
      route(active),
      Map.put(route(first), :path, "/first"),
      Map.put(route(second), :path, "/second")
    ]

    assert {:ok, router} = prepare_routes(candidate, fixture.store, routes)

    assert [{{Transports, ^first_owner}, _}, {{Transports, ^second_owner}, _}] =
             Enum.group_by(router.resources, &{&1.provider, &1.owner}) |> Enum.to_list()

    assert :ok =
             rpc(candidate, fn pins ->
               {closed, remaining} = Enum.split_with(pins, &(second_handle in &1.handles))
               assert :ok = Resources.release(closed)
               {:ok, remaining}
             end)

    second = join_resource(second)
    before = accounting(first_owner)
    observe_baseline(first_owner, fixture.store)
    barrier = baseline_input_barrier(second_owner, fixture.store)
    operation = make_ref()
    coordinator = candidate.pid

    send(
      coordinator,
      {:run, operation,
       fn pins ->
         {Generation.activate(fixture.store, active.generation, router, @timeout), pins}
       end}
    )

    assert_receive {:baseline_input_held, ^second_owner, ^barrier}, @timeout
    assert_receive {:provisional_baseline, ^first_owner, provisional}, @timeout
    assert provisional.kind == :baseline
    assert provisional.holder == fixture.store
    assert MapSet.new(provisional.handles) == MapSet.new([active.transport, first.transport])
    charged = accounting(first_owner)
    assert charged.pins == before.pins + 2
    assert charged.owned_serialized_payload_bytes > before.owned_serialized_payload_bytes

    assert Map.drop(charged, [:pins, :owned_serialized_payload_bytes]) ==
             Map.drop(before, [:pins, :owned_serialized_payload_bytes])

    send(second_owner, {:continue_baseline, barrier})

    assert_receive {:coordinator_result, ^coordinator, ^operation, {:error, :invalid_resource}},
                   @timeout

    await(fn -> accounting(first_owner) == before end)
    assert_current(fixture, active)
    release_coordinator(candidate)
    first = join_resource(first)
    assert accounting(first_owner) == active_before
    assert_zero(second_owner)
    assert_current(fixture, active)
    request_current(fixture, active_peer, "/after-partial-baseline")
    finish(fixture, [active, first, second], [active_peer, first_peer, second_peer])
  end

  for kind <- [:fixed, :group] do
    @kind kind
    test "#{kind} lost coordinator-result delivery after successful CAS keeps the observed new baseline through release and death" do
      old_peer = peer(:old)
      new_peer = peer(:new)
      fixture = fixture(%{}, if(@kind == :group, do: %{max_probes: 1}))
      old = install(fixture, old_peer, @kind)
      if old.group, do: healthy(old.group, old_peer)
      request_current(fixture, old_peer, "/before-lost-result")
      candidate = coordinator()
      fresh = prepare_transport(candidate, fixture.transports, new_peer.source)
      fresh = if @kind == :group, do: prepare_group(candidate, fixture.groups, fresh), else: fresh
      if fresh.group, do: healthy(fresh.group, new_peer)
      assert {:ok, router} = prepare_routes(candidate, fixture.store, [route(fresh)])
      barrier = make_ref()
      send(candidate.pid, {:activate_hold_result, barrier, fixture.store, old.generation, router})
      coordinator = candidate.pid
      assert_receive {:activation_result_held, ^coordinator, ^barrier}, @timeout
      # This barrier loses the embedding result, not Store's GenServer reply.
      # Observe the exact prepared generation once; do not retry activation.
      assert {:ok, generation, ^router} = Generation.snapshot(fixture.store)
      assert generation == router.generation
      refute generation == old.generation
      fresh = Map.merge(fresh, %{router: router, generation: generation})
      assert_current(fixture, fresh)
      send(coordinator, {:release_preparation, barrier})
      assert_receive {:preparation_released, ^coordinator, ^barrier}, @timeout
      old = join_resource(old)

      if old.group,
        do: await(fn -> UpstreamGroups.status(old.group) == {:error, :stale_group} end)

      assert %{resources: 1, pins: 1, helpers: 0, request_tokens: 0} =
               accounting(fixture.transports)

      before = accounting(fixture.transports)
      group_before = if fresh.group, do: group_accounting(fresh.group)
      Process.exit(coordinator, :kill)
      monitor = candidate.monitor
      assert_receive {:DOWN, ^monitor, :process, ^coordinator, :killed}, @timeout
      refute_receive {:coordinator_result, ^coordinator, ^barrier, _}, 0
      assert accounting(fixture.transports) == before
      if fresh.group, do: assert(group_accounting(fresh.group) == group_before)
      assert_current(fixture, fresh)
      request_current(fixture, new_peer, "/after-lost-result%2Ffresh?")
      finish(fixture, [old, fresh], [old_peer, new_peer])
    end
  end

  defp fixture(limits \\ %{}, group_limits \\ nil) do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    owner = transport_owner(instance, limits)

    groups =
      if group_limits do
        {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: group_limits)
        Process.unlink(groups)
        cleanup_actor(groups)
        groups
      end

    {:ok, store} = Generation.start_link(routes: [])
    Process.unlink(store)
    cleanup_actor(store)
    cleanup_actor(instance)
    %{instance: instance, store: store, transports: owner, owners: [owner], groups: groups}
  end

  defp transport_owner(instance, limits) do
    {:ok, owner} =
      Transports.start_link(
        instance: instance,
        limits:
          Map.merge(
            %{
              max_resources: 4,
              max_pins: 32,
              max_request_tokens: 64,
              max_owned_payload_bytes: 4_194_304
            },
            limits
          )
      )

    Process.unlink(owner)
    cleanup_actor(owner)
    owner
  end

  defp coordinator do
    parent = self()

    {pid, monitor} =
      spawn_monitor(fn -> coordinator_loop(parent, [], Lifecycle.deadline(30_000)) end)

    on_exit(fn ->
      if Process.alive?(pid) do
        monitor = Process.monitor(pid)
        send(pid, :release)

        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          @timeout -> Process.exit(pid, :kill)
        end
      end
    end)

    %{pid: pid, monitor: monitor}
  end

  defp coordinator_loop(parent, pins, deadline) do
    receive do
      {:run, ref, fun} ->
        {result, pins} = fun.(pins)
        send(parent, {:coordinator_result, self(), ref, result})
        coordinator_loop(parent, pins, deadline)

      {:activate_hold_result, barrier, store, expected, router} ->
        assert {:ok, generation} = Generation.activate(store, expected, router, @timeout)
        assert generation == router.generation
        send(parent, {:activation_result_held, self(), barrier})

        receive do
          {:release_preparation, ^barrier} ->
            assert :ok = Resources.release(pins)
            send(parent, {:preparation_released, self(), barrier})

            receive do
              {:deliver_result, ^barrier} ->
                send(parent, {:coordinator_result, self(), barrier, {:ok, generation}})

              :release ->
                :ok
            after
              Lifecycle.remaining(deadline) -> raise "lost-result coordinator join expired"
            end

          :release ->
            assert :ok = Resources.release(pins)
        after
          Lifecycle.remaining(deadline) -> raise "activation result barrier expired"
        end

      :release ->
        assert :ok = Resources.release(pins)
    after
      Lifecycle.remaining(deadline) ->
        Resources.release(pins)
        raise "candidate coordinator deadline expired"
    end
  end

  defp rpc(candidate, fun) do
    ref = make_ref()
    send(candidate.pid, {:run, ref, fun})
    pid = candidate.pid
    assert_receive {:coordinator_result, ^pid, ^ref, result}, @timeout
    result
  end

  defp release_coordinator(candidate) do
    send(candidate.pid, :release)
    pid = candidate.pid
    monitor = candidate.monitor
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
  end

  defp prepare_transport(candidate, owner, source) do
    resource =
      rpc(candidate, fn pins ->
        assert {:ok, transport, preparation} =
                 Transports.prepare(owner, source, self(), Lifecycle.deadline(15_000))

        creator = :sys.get_state(owner).records[transport.resource].custodian

        {%{transport: transport, source: source, group: nil, creator: creator, joined: false},
         pins ++ preparation}
      end)

    Map.put(resource, :creator_monitor, Process.monitor(resource.creator))
  end

  defp hold_shared(candidate, transport) do
    assert :ok =
             rpc(candidate, fn pins ->
               assert {:ok, shared} =
                        Resources.pin_many(
                          [transport],
                          self(),
                          :preparation,
                          Lifecycle.deadline(15_000)
                        )

               {:ok, pins ++ shared}
             end)
  end

  defp prepare_group(candidate, owner, resource) do
    rpc(candidate, fn pins ->
      assert {:ok, compiled} = group_options(resource)

      assert {:ok, group, preparation} =
               UpstreamGroups.prepare(owner, compiled, self(), Lifecycle.deadline(15_000))

      {%{resource | group: group}, pins ++ preparation}
    end)
  end

  defp group_options(resource) do
    UpstreamGroups.compile(%{
      id: "candidate",
      members: [%{id: "member", upstream: resource.source.origin, transport: resource.transport}],
      health: %{
        path: "/health",
        interval: 60_000,
        stale_after: 120_000,
        timeout: 2_000,
        jitter: 0,
        recovery_threshold: 1
      }
    })
  end

  defp options(resource), do: %{upstream: resource.source.origin, transport: resource.transport}
  defp route(%{group: nil} = resource), do: %{target: {ProxyHTTP, options(resource)}}
  defp route(resource), do: %{target: {GroupEndpoint, %{group: resource.group}}}

  defp prepare_routes(candidate, store, routes),
    do: rpc(candidate, fn pins -> {Generation.prepare(store, routes, @timeout), pins} end)

  defp activate_candidate(candidate, store, expected, router),
    do:
      rpc(candidate, fn pins -> {Generation.activate(store, expected, router, @timeout), pins} end)

  defp install(fixture, peer, kind \\ :fixed) do
    candidate = coordinator()
    resource = prepare_transport(candidate, fixture.transports, peer.source)

    resource =
      if kind == :group, do: prepare_group(candidate, fixture.groups, resource), else: resource

    assert {:ok, router} = prepare_routes(candidate, fixture.store, [route(resource)])
    assert {:ok, expected, _} = Generation.snapshot(fixture.store)
    assert {:ok, generation} = activate_candidate(candidate, fixture.store, expected, router)
    release_coordinator(candidate)
    Map.merge(resource, %{router: router, generation: generation})
  end

  defp assert_current(fixture, resource) do
    generation = resource.generation
    router = resource.router
    assert {:ok, ^generation, ^router} = Generation.snapshot(fixture.store)

    assert {:ok, ^generation, ^router, pins} =
             Generation.snapshot_for_request(fixture.store, self(), deadline())

    expected =
      if resource.group, do: [resource.group, resource.transport], else: [resource.transport]

    assert MapSet.new(Enum.flat_map(pins, & &1.handles)) == MapSet.new(expected)

    for pin <- pins do
      assert pin.kind == :request

      case pin.provider do
        Transports ->
          assert map_size(pin) == 8
          assert pin.holder == self()
          hold = :sys.get_state(fixture.transports).pins[pin.ref]
          assert hold.public == pin
          assert hold.acquirer == fixture.store

        UpstreamGroups ->
          assert map_size(pin) == 7
          assert pin.owner == fixture.groups
          hold = :sys.get_state(fixture.groups).pins[pin.ref]
          assert hold.holder == self()
          assert hold.acquirer == fixture.store
          assert hold.kind == pin.kind
          assert hold.operation == pin.operation
          assert hold.keys == [{resource.group.group, resource.group.generation}]
      end
    end

    assert :ok = Resources.release(pins)

    assert :ok =
             Transports.validate_endpoint(
               resource.transport,
               %{
                 origin: resource.source.origin,
                 upstream_protocol: :http1,
                 instance: fixture.instance
               },
               deadline()
             )

    assert {:ok, {module, config}} =
             Router.match(router, %{host: "downstream.test", method: "GET", path: "/"})

    assert module == if(resource.group, do: GroupEndpoint, else: ProxyHTTP)
    assert MapSet.new(module.resources(config)) == MapSet.new(expected)
  end

  defp observe_baseline(owner, store) do
    parent = self()

    debug = fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {^store, _}, {:pin_many, _, ^store, :baseline, _, _}}} ->
          :baseline

        {:out, {:ok, pin}, _, _} when state == :baseline ->
          send(parent, {:provisional_baseline, self(), pin})
          nil

        {:out, _, _, _} ->
          nil

        _ ->
          state
      end
    end

    assert :ok = :sys.install(owner, {debug, nil})
  end

  defp baseline_input_barrier(owner, store) do
    parent = self()
    barrier = make_ref()

    debug = fn seen, event, _ ->
      case event do
        {:in, {:"$gen_call", {^store, _}, {:pin_many, _, ^store, :baseline, _, _}}}
        when not seen ->
          send(parent, {:baseline_input_held, self(), barrier})

          receive do
            {:continue_baseline, ^barrier} -> :ok
          after
            @timeout -> raise "second-owner baseline input barrier expired"
          end

          true

        _ ->
          seen
      end
    end

    assert :ok = :sys.install(owner, {debug, false})
    on_exit(fn -> send(owner, {:continue_baseline, barrier}) end)
    barrier
  end

  defp accounting(owner) do
    assert {:ok, status} = Transports.status(owner)
    status
  end

  defp group_accounting(group) do
    assert %{
             lifecycle: :active,
             probes: 0,
             probe_bytes: 0,
             inflight: 0,
             pins: 1,
             members: [%{health: :healthy, inflight: 0, probe: false}]
           } = status = UpstreamGroups.status(group)

    Map.take(status, [:lifecycle, :probes, :probe_bytes, :inflight, :pins])
  end

  defp healthy(group, peer) do
    label = peer.label
    assert_receive {:peer_head, ^label, head}, @timeout
    assert head =~ "HEAD /health HTTP/1.1\r\n"
    assert String.downcase(head) =~ "\r\nhost: #{URI.parse(peer.source.origin).authority}\r\n"

    await(fn ->
      match?(
        %{probes: 0, probe_bytes: 0, members: [%{health: :healthy, probe: false}]},
        UpstreamGroups.status(group)
      )
    end)
  end

  defp join_resource(resource) do
    await(fn -> Transports.status(resource.transport) == {:error, :invalid_resource} end)
    creator = resource.creator
    monitor = resource.creator_monitor
    assert_receive {:DOWN, ^monitor, :process, ^creator, :normal}, @timeout
    %{resource | joined: true}
  end

  defp request_current(fixture, peer, target) do
    case Gaoxy.info(fixture.instance, :http) do
      {:error, :not_running} -> add_service(fixture)
      %{local: _} -> :ok
    end

    {:ok, {ip, port}} = Gaoxy.info(fixture.instance, :http).local
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)

    assert :ok =
             :gen_tcp.send(
               socket,
               "GET #{target} HTTP/1.1\r\nHost: downstream.test\r\nConnection: close\r\n\r\n"
             )

    head = read_head(socket, deadline())
    assert head =~ "HTTP/1.1 200 "
    assert {:ok, bytes} = :gen_tcp.recv(socket, byte_size(peer.body), @timeout)
    assert bytes == peer.body
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    assert :ok = :gen_tcp.close(socket)
    label = peer.label
    assert_receive {:peer_get, ^label, upstream_head}, @timeout
    assert upstream_head =~ "GET #{target} HTTP/1.1\r\n"

    assert String.downcase(upstream_head) =~
             "\r\nhost: #{URI.parse(peer.source.origin).authority}\r\n"

    await(fn ->
      match?(
        %{active: 0, cleanup_pending: 0, retained_bytes: 0},
        Gaoxy.status(fixture.instance, :http)
      ) and
        match?(%{request_tokens: 0, helpers: 0, pins: 1}, accounting(fixture.transports))
    end)
  end

  defp add_service(fixture) do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :http,
               endpoint: {Generation, fixture.store},
               limits: %{max_bytes: 33_554_432}
             )

    assert {:ok, _} = Gaoxy.add(fixture.instance, spec)
  end

  defp finish(fixture, resources, peers) do
    store_monitor = Process.monitor(fixture.store)
    assert :ok = GenServer.stop(fixture.store, :normal, @timeout)
    assert_receive {:DOWN, ^store_monitor, :process, _, :normal}, @timeout

    for owner <- fixture.owners do
      assert {:ok, receipt} = Transports.retire(owner, deadline())
      assert :ok = Transports.await_retirement(receipt, deadline())
      assert_zero(owner)
    end

    for resource <- resources do
      unless resource.joined, do: join_resource(resource)

      if resource.group,
        do: await(fn -> UpstreamGroups.status(resource.group) == {:error, :stale_group} end)
    end

    owner_monitors = for owner <- fixture.owners, do: {owner, Process.monitor(owner)}

    if fixture.groups do
      await(fn ->
        match?(
          %{groups: groups, pins: pins, tokens: tokens, probes: probes, bytes: 0, probe_bytes: 0}
          when map_size(groups) == 0 and map_size(pins) == 0 and map_size(tokens) == 0 and
                 map_size(probes) == 0,
          :sys.get_state(fixture.groups)
        )
      end)

      group_monitor = Process.monitor(fixture.groups)
      assert :ok = GenServer.stop(fixture.groups, :normal, @timeout)
      assert_receive {:DOWN, ^group_monitor, :process, _, :normal}, @timeout
    end

    instance_monitor = Process.monitor(fixture.instance)
    assert :ok = Gaoxy.stop(fixture.instance, @timeout)
    assert_receive {:DOWN, ^instance_monitor, :process, _, :normal}, @timeout

    for {owner, monitor} <- owner_monitors do
      assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}, @timeout
    end

    for peer <- peers do
      # A second queued connection is a duplicate/fallback, never successful cleanup.
      assert {:error, :timeout} = :gen_tcp.accept(peer.listener, 0)
      assert :ok = :gen_tcp.close(peer.listener)
      pid = peer.pid
      monitor = peer.monitor
      assert_receive {:peer_joined, ^pid, result}, @timeout
      assert result == if(peer.label in [:active, :old, :new], do: :eof, else: :unused)
      label = peer.label
      if result == :eof, do: assert_receive({:peer_eof, ^label}, @timeout)
      refute_receive {:peer_get, ^label, _}, 0
      refute_receive {:peer_head, ^label, _}, 0
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end
  end

  defp assert_zero(owner) do
    assert %{
             resources: 0,
             pins: 0,
             request_tokens: 0,
             helpers: 0,
             reserved_connections: 0,
             owned_serialized_payload_bytes: 0
           } = accounting(owner)
  end

  defp peer(label) do
    assert {:ok, listener} =
             :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    assert {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    body = <<0, Atom.to_string(label)::binary, 255>>

    {pid, monitor} =
      spawn_monitor(fn ->
        result =
          case :gen_tcp.accept(listener, 15_000) do
            {:ok, socket} ->
              try do
                serve(socket, parent, label, body, Lifecycle.deadline(30_000))
              after
                :gen_tcp.close(socket)
              end

            {:error, :closed} ->
              :unused

            {:error, :timeout} ->
              raise "candidate peer accept deadline expired"
          end

        send(parent, {:peer_joined, self(), result})
      end)

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
      label: label,
      body: body,
      source: %{origin: "http://localhost:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}
    }
  end

  defp serve(socket, parent, label, body, deadline) do
    case :gen_tcp.recv(socket, 1, Lifecycle.remaining(deadline)) do
      {:ok, byte} ->
        head = read_head(socket, deadline, byte)

        response =
          if String.starts_with?(head, "HEAD /health HTTP/1.1\r\n") do
            send(parent, {:peer_head, label, head})
            "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
          else
            assert String.starts_with?(head, "GET ")
            send(parent, {:peer_get, label, head})
            ["HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(body)}\r\n\r\n", body]
          end

        assert :ok = :gen_tcp.send(socket, response)
        serve(socket, parent, label, body, deadline)

      {:error, :closed} ->
        send(parent, {:peer_eof, label})
        :eof

      {:error, :timeout} ->
        raise "candidate peer EOF deadline expired"
    end
  end

  defp read_head(socket, deadline, bytes \\ "") do
    assert byte_size(bytes) <= 65_536
    assert Lifecycle.remaining(deadline) > 0

    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, byte} = :gen_tcp.recv(socket, 1, Lifecycle.remaining(deadline))
      read_head(socket, deadline, bytes <> byte)
    end
  end

  defp await(fun, deadline \\ nil) do
    deadline = deadline || deadline()

    if fun.() do
      :ok
    else
      remaining = Lifecycle.remaining(deadline)
      assert remaining > 0, "candidate failure fixture did not settle before deadline"

      receive do
      after
        min(2, remaining) -> await(fun, deadline)
      end
    end
  end

  defp deadline, do: Lifecycle.deadline(@timeout)

  defp cleanup_actor(pid) do
    on_exit(fn ->
      if Process.alive?(pid) do
        Lifecycle.protect(fn -> GenServer.stop(pid, :normal, @timeout) end)
        if Process.alive?(pid), do: Process.exit(pid, :kill)
      end
    end)
  end
end
