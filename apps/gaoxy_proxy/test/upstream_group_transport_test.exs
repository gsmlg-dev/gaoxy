defmodule Gaoxy.Proxy.UpstreamGroupTransportTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Resources, Router}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups, UpstreamTransports}

  @tag :group_transport_pure
  test "managed transport survives both group option forms without owner calls" do
    transport = %{
      provider: UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

    input = %{
      id: "api",
      members: [
        %{id: "one", upstream: "http://peer.test", transport: transport},
        %{id: "two", upstream: "http://peer.test", transport: transport}
      ]
    }

    assert {:ok, compiled} = UpstreamGroups.compile(input)
    assert Enum.all?(compiled.members, &(&1.config.transport == transport))
    assert {:ok, ^compiled} = UpstreamGroups.compile(compiled)
    refute_received {_, {_, _}, _}
  end

  @tag :group_transport_pure
  test "mixed dedicated and managed members retain their transport and limits" do
    first = transport()
    second = transport()

    members = [
      %{id: "dedicated", upstream: "http://peer.test", max_inflight: 2},
      %{id: "first", upstream: "http://peer.test", transport: first, max_inflight: 3},
      %{id: "shared", upstream: "http://peer.test", transport: first},
      %{id: "second", upstream: "http://other.test", transport: second}
    ]

    assert {:ok, compiled} = UpstreamGroups.compile(%{id: "mixed", members: members})

    assert [
             %{id: "dedicated", config: %{transport: nil}, max_inflight: 2},
             %{id: "first", config: %{transport: ^first}, max_inflight: 3},
             %{id: "shared", config: %{transport: ^first}, max_inflight: 16},
             %{id: "second", config: %{transport: ^second}, max_inflight: 16}
           ] = compiled.members

    assert {:ok, ^compiled} = UpstreamGroups.compile(compiled)
  end

  @tag :group_transport_pure
  test "group options keep managed H1 protocol and no override rules in both forms" do
    handle = transport()
    member = %{id: "one", upstream: "http://peer.test", transport: handle}
    assert {:ok, compiled} = UpstreamGroups.compile(%{id: "api", members: [member]})
    [stored] = compiled.members

    for change <- [
          %{upstream_protocol: :http2},
          %{upstream_protocol: :http3},
          %{cacertfile: "/does/not/exist"},
          %{connect_address: {127, 0, 0, 1}},
          %{ssl: []},
          %{http1_reuse: true},
          %{transport_scope: make_ref()},
          %{transport: Map.put(handle, :policy, %{})},
          %{transport: Map.delete(handle, :resource)},
          %{transport: %{handle | owner_epoch: 1}},
          %{transport: %{handle | resource: 1}}
        ] do
      assert {:error, :invalid_upstream_group} =
               UpstreamGroups.compile(%{id: "api", members: [Map.merge(member, change)]})
    end

    for change <- [
          %{upstream_protocol: :http2},
          %{upstream_protocol: :http3},
          %{client: __MODULE__},
          %{cacertfile: "/does/not/exist"},
          %{connect_address: {127, 0, 0, 1}},
          %{transport: Map.put(handle, :scope, make_ref())}
        ] do
      invalid = %{compiled | members: [%{stored | config: Map.merge(stored.config, change)}]}
      assert {:error, :invalid_upstream_group} = UpstreamGroups.compile(invalid)
    end
  end

  @tag :group_transport_pure
  test "managed groups preserve the 32 member and strict configuration bounds" do
    handle = transport()

    members =
      for n <- 1..32, do: %{id: "member-#{n}", upstream: "http://peer.test", transport: handle}

    assert {:ok, compiled} = UpstreamGroups.compile(%{id: "api", members: members})
    assert Enum.map(compiled.members, & &1.id) == Enum.map(members, & &1.id)
    assert {:ok, ^compiled} = UpstreamGroups.compile(compiled)

    for input <- [
          %{id: "api", members: members ++ [%{hd(members) | id: "member-33"}]},
          %{id: "api", members: [hd(members), hd(members)]},
          %{id: String.duplicate("x", 129), members: members},
          %{id: "api", members: members, retry: true},
          %{id: "api", members: members, health: %{unknown: 1}},
          %{id: "api", members: members, max_inflight: 0}
        ] do
      assert {:error, :invalid_upstream_group} = UpstreamGroups.compile(input)
    end
  end

  @tag :group_transport_pure
  test "six field dedicated and seven field managed handles declare exact ordered resources" do
    dedicated = group("dedicated")
    first = transport()
    second = transport()
    managed = Map.put(group("managed"), :transports, [second, first])
    assert map_size(dedicated) == 6
    assert map_size(managed) == 7
    assert UpstreamGroups.valid_handle?(dedicated)
    assert UpstreamGroups.valid_handle?(managed)
    assert [^dedicated] = apply(UpstreamGroups, :resources, [dedicated])
    assert [^managed, ^second, ^first] = apply(UpstreamGroups, :resources, [managed])

    assert {:ok, dedicated_config} = GroupEndpoint.init(%{group: dedicated})
    assert [^dedicated] = GroupEndpoint.resources(dedicated_config)
    assert {:ok, config} = GroupEndpoint.init(%{group: managed})
    assert [^managed, ^second, ^first] = GroupEndpoint.resources(config)
    assert {:ok, ^config} = GroupEndpoint.init(config)

    assert {:ok, [^managed, ^second, ^first]} =
             Resources.validate(GroupEndpoint.resources(config))
  end

  @tag :group_transport_pure
  test "managed sidecars reject extra authority, malformed and noncanonical resource declarations" do
    first = transport()
    managed = Map.put(group("managed"), :transports, [first])

    invalid = [
      Map.put(managed, :policy, %{}),
      Map.put(managed, :cacerts, [<<1>>]),
      Map.put(managed, :scope, make_ref()),
      Map.put(group("dedicated"), :unknown, true),
      Map.delete(managed, :generation),
      %{managed | provider: __MODULE__},
      %{managed | owner: :not_a_pid},
      %{managed | owner_epoch: 1},
      %{managed | generation: 1},
      %{managed | group: ""},
      %{managed | max_url_bytes: 8193},
      %{managed | transports: []},
      %{managed | transports: :invalid},
      %{managed | transports: [first, first]},
      %{managed | transports: [Map.put(first, :policy, %{})]},
      %{managed | transports: [Map.put(first, :cacerts, [<<1>>])]},
      %{managed | transports: [Map.put(first, :scope, make_ref())]},
      %{managed | transports: [Map.delete(first, :resource)]},
      %{managed | transports: [%{first | provider: UpstreamGroups}]},
      %{managed | transports: [%{first | owner: :not_a_pid}]},
      %{managed | transports: [%{first | owner_epoch: 1}]},
      %{managed | transports: [%{first | resource: 1}]},
      %{managed | transports: for(_ <- 1..33, do: transport())}
    ]

    for handle <- invalid do
      refute UpstreamGroups.valid_handle?(handle)
      assert {:error, :invalid_group_endpoint_options} = GroupEndpoint.init(%{group: handle})
    end
  end

  @tag :group_transport_pure
  test "pure endpoint and resource discovery never contact a nonresponsive owner" do
    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    monitor = Process.monitor(owner)
    first = %{transport() | owner: owner}
    managed = Map.put(%{group("api") | owner: owner}, :transports, [first])

    try do
      assert {:ok, config} = GroupEndpoint.init(%{group: managed})
      assert [^managed, ^first] = GroupEndpoint.resources(config)
      assert [^managed, ^first] = apply(UpstreamGroups, :resources, [managed])
      assert {:ok, _router} = Router.compile([route(managed)])
      assert {:message_queue_len, 0} = Process.info(owner, :message_queue_len)
    after
      send(owner, :stop)
      assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}, 3_000
    end
  end

  @tag :group_transport_pure
  test "Router deduplicates shared transports and rejects resource 65 across group routes" do
    shared = transport()
    groups = for n <- 1..64, do: Map.put(group("group-#{n}"), :transports, [shared])
    accepted = Enum.take(groups, 63)
    assert {:ok, router} = Router.compile(Enum.map(accepted, &route/1))
    resources = Router.resources(router)
    assert MapSet.new(resources) == MapSet.new([shared | accepted])
    assert Enum.count(resources, &(&1 == shared)) == 1
    assert {:error, :invalid_endpoint_resources} = Router.compile(Enum.map(groups, &route/1))
  end

  @tag :group_transport_pure
  test "Router enforces serialized resource bytes even when its union has at most 64 handles" do
    transports = for _ <- 1..32, do: transport()
    groups = for n <- 1..32, do: Map.put(group("group-#{n}"), :transports, transports)

    over_count =
      Enum.find(1..32, fn n ->
        :erlang.external_size(Enum.take(groups, n) ++ transports) > 65_536
      end)

    assert over_count in 2..32
    within = Enum.take(groups, over_count - 1)
    over = Enum.take(groups, over_count)
    assert :erlang.external_size(within ++ transports) <= 65_536
    assert :erlang.external_size(over ++ transports) > 65_536
    assert length(over ++ transports) <= 64
    for handle <- over, do: assert({:ok, _} = GroupEndpoint.init(%{group: handle}))
    assert {:ok, router} = Router.compile(Enum.map(within, &route/1))
    assert MapSet.new(Router.resources(router)) == MapSet.new(within ++ transports)
    assert {:error, :invalid_endpoint_resources} = Router.compile(Enum.map(over, &route/1))
  end

  @tag :group_transport_prepare
  test "preparation derives ordered shared sidecars and embeds the complete baseline" do
    fixture = fixture(owners: 2)
    [first, second] = fixture.transports
    compiled = managed_group(fixture, [second, first, second], "shared")

    assert {:ok, handle, preparation} =
             UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline())

    assert map_size(handle) == 7
    assert [^second, ^first] = handle.transports
    assert [^handle, ^second, ^first] = UpstreamGroups.resources(handle)

    assert Enum.sort(Enum.flat_map(preparation, & &1.handles)) ==
             Enum.sort([handle, first, second])

    assert Enum.all?(preparation, &(&1.kind == :preparation))

    owned = :sys.get_state(fixture.groups)

    assert owned.bytes >=
             :erlang.external_size(compiled) + :erlang.external_size(handle.transports)

    assert {:ok, baseline} =
             Resources.pin_many(UpstreamGroups.resources(handle), self(), :baseline, deadline())

    assert :ok = Resources.release(preparation)
    assert %{lifecycle: :active, pins: 1, inflight: 0} = UpstreamGroups.status(handle)

    for owner <- fixture.owners,
        do: assert({:ok, %{pins: 2, request_tokens: 0}} = UpstreamTransports.status(owner))

    assert :ok = Resources.release(baseline)
    eventually(fn -> :sys.get_state(fixture.groups).groups == %{} end)
    assert_transport_pins(fixture, 1)
    refute_received {:unexpected_upstream, _}
  end

  @tag :group_transport_prepare
  test "authority instance and stale transport rejection publish no group or token" do
    fixture = fixture()
    foreign = fixture(source: fixture.source)
    [handle] = fixture.transports
    [cross_instance] = foreign.transports

    for {transport, origin} <- [
          {handle, "http://wrong.test:#{URI.parse(fixture.source.origin).port}"},
          {cross_instance, fixture.source.origin},
          {%{handle | owner_epoch: make_ref()}, fixture.source.origin},
          {%{handle | resource: make_ref()}, fixture.source.origin}
        ] do
      assert {:ok, compiled} =
               UpstreamGroups.compile(%{
                 id: "denied",
                 members: [%{id: "a", upstream: origin, transport: transport}]
               })

      assert {:error, _} = UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline())
      assert_empty_groups(fixture.groups)
      assert_transport_pins(fixture, 1)
      assert_transport_pins(foreign, 1)
    end

    assert {:ok, valid, preparation} =
             UpstreamGroups.prepare(fixture.groups, managed_group(fixture), self(), deadline())

    assert valid.transports == [handle]
    assert :ok = Resources.release(preparation)
  end

  @tag :group_transport_prepare
  test "managed preparation authenticates its caller and rejects dead or expired preparers" do
    fixture = fixture()
    compiled = managed_group(fixture)

    {other, monitor} =
      spawn_monitor(fn ->
        receive do
          :stop -> :ok
        after
          3_000 -> :ok
        end
      end)

    try do
      assert {:error, :unauthorized} =
               UpstreamGroups.prepare(fixture.groups, compiled, other, deadline())

      send(other, :stop)
      assert_receive {:DOWN, ^monitor, :process, ^other, :normal}, 3_000

      assert {:error, :unauthorized} =
               UpstreamGroups.prepare(fixture.groups, compiled, other, deadline())

      assert {:error, {:deadline_exceeded, :cleanup_pending}} =
               UpstreamGroups.prepare(fixture.groups, compiled, self(), Lifecycle.now())

      assert_empty_groups(fixture.groups)
      assert_transport_pins(fixture, 1)
    after
      send(other, :stop)
      Process.demonitor(monitor, [:flush])
    end
  end

  @tag :group_transport_prepare
  test "group capacity denial rolls back acquired dependency pins and preserves existing configuration" do
    fixture = fixture(group_limits: %{max_groups: 1})
    compiled = managed_group(fixture)

    assert {:ok, active, preparation} =
             UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline())

    assert {:ok, baseline} =
             Resources.pin_many(UpstreamGroups.resources(active), self(), :baseline, deadline())

    assert :ok = Resources.release(preparation)
    [owner] = fixture.owners
    barrier = call_barrier(fixture.groups, :prepare)
    caller = prepare_caller(fixture.groups, %{compiled | id: "candidate"}, deadline())
    assert_receive {:call_held, groups, ^caller, {:prepare, _, _, _, _}}, 3_000
    assert groups == fixture.groups
    assert {:ok, %{pins: 3, request_tokens: 0}} = UpstreamTransports.status(owner)
    send(groups, {:continue_call, barrier})
    assert_receive {:candidate_result, ^caller, {:error, :group_capacity}}, 3_000
    join_caller(caller)

    eventually(fn ->
      match?({:ok, %{pins: 2, request_tokens: 0}}, UpstreamTransports.status(owner))
    end)

    assert %{lifecycle: :active, pins: 1, inflight: 0} = UpstreamGroups.status(active)
    assert map_size(:sys.get_state(groups).groups) == 1
    assert :ok = Resources.release(baseline)
  end

  @tag :group_transport_prepare
  test "partial multiowner pin refusal rolls back the first provider and leaves the active candidate usable" do
    fixture = fixture(owners: 2)
    batches = Enum.group_by(fixture.transports, &{&1.provider, &1.owner}) |> Enum.to_list()
    [{{_, first_owner}, [first]}, {{_, denied_owner}, [_]}] = batches
    active_compiled = managed_group(fixture, [first], "active")

    assert {:ok, active, preparation} =
             UpstreamGroups.prepare(fixture.groups, active_compiled, self(), deadline())

    assert {:ok, baseline} =
             Resources.pin_many(UpstreamGroups.resources(active), self(), :baseline, deadline())

    assert :ok = Resources.release(preparation)

    :sys.replace_state(denied_owner, fn state ->
      %{state | limits: %{state.limits | max_pins: 1}}
    end)

    barrier = call_barrier(denied_owner, :pin_many)
    caller = prepare_caller(fixture.groups, managed_group(fixture), deadline())
    assert_receive {:call_held, ^denied_owner, ^caller, {:pin_many, _, _, _, _, _}}, 3_000
    assert {:ok, %{pins: 3, request_tokens: 0}} = UpstreamTransports.status(first_owner)
    send(denied_owner, {:continue_call, barrier})
    assert_receive {:candidate_result, ^caller, {:error, {:capacity, :pins}}}, 3_000
    join_caller(caller)

    eventually(fn ->
      match?({:ok, %{pins: 2, request_tokens: 0}}, UpstreamTransports.status(first_owner))
    end)

    assert {:ok, %{pins: 1, request_tokens: 0}} = UpstreamTransports.status(denied_owner)
    assert %{lifecycle: :active, pins: 1} = UpstreamGroups.status(active)

    :sys.replace_state(denied_owner, fn state ->
      %{state | limits: %{state.limits | max_pins: 16}}
    end)

    assert {:ok, candidate, candidate_preparation} =
             UpstreamGroups.prepare(fixture.groups, managed_group(fixture), self(), deadline())

    assert candidate.transports == fixture.transports
    assert :ok = Resources.release(candidate_preparation)
    assert :ok = Resources.release(baseline)
  end

  @tag :group_transport_prepare
  test "late group prepare reply is cancelled by its caller and cannot leave dependency pins" do
    fixture = fixture()
    barrier = call_barrier(fixture.groups, :prepare)
    caller = prepare_caller(fixture.groups, managed_group(fixture), Lifecycle.deadline(150))
    assert_receive {:call_held, groups, ^caller, {:prepare, _, ^caller, operation, _}}, 3_000
    assert groups == fixture.groups
    [owner] = fixture.owners
    assert {:ok, %{pins: 2, request_tokens: 0}} = UpstreamTransports.status(owner)

    assert_receive {:candidate_result, ^caller, {:error, {:deadline_exceeded, :cleanup_pending}}},
                   3_000

    send(groups, {:continue_call, barrier})
    assert_receive {:operation_cancelled, ^groups, ^caller, ^operation}, 3_000
    assert_empty_groups(groups)
    assert_transport_pins(fixture, 1)
    join_caller(caller)
  end

  @tag :group_transport_prepare
  test "preparer DOWN before a held owner reply rolls back without publishing a group" do
    fixture = fixture()
    barrier = call_barrier(fixture.groups, :prepare)
    caller = prepare_caller(fixture.groups, managed_group(fixture), deadline())
    assert_receive {:call_held, groups, ^caller, {:prepare, _, ^caller, _, _}}, 3_000
    assert groups == fixture.groups
    [owner] = fixture.owners
    assert {:ok, %{pins: 2, request_tokens: 0}} = UpstreamTransports.status(owner)
    monitor = Process.monitor(caller)
    Process.exit(caller, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :killed}, 3_000
    send(groups, {:continue_call, barrier})

    eventually(fn ->
      :sys.get_state(groups).groups == %{} and :sys.get_state(groups).pins == %{}
    end)

    assert_transport_pins(fixture, 1)
  end

  @tag :group_transport_prepare
  test "preparer death after publication drops both preparation ledgers but preserves another baseline" do
    fixture = fixture()
    caller = prepare_caller(fixture.groups, managed_group(fixture), deadline())
    assert_receive {:candidate_result, ^caller, {:ok, handle, preparation}}, 3_000

    assert Enum.sort(Enum.flat_map(preparation, & &1.handles)) ==
             Enum.sort(UpstreamGroups.resources(handle))

    assert_transport_pins(fixture, 2)
    join_caller(caller)
    eventually(fn -> :sys.get_state(fixture.groups).groups == %{} end)
    assert_transport_pins(fixture, 1)
    [transport] = fixture.transports
    assert {:ok, %{resources: 1, request_tokens: 0}} = UpstreamTransports.status(transport)
  end

  @tag :group_transport_prepare
  test "owner exact handle identity rejects structurally valid sidecar and generation forgeries" do
    fixture = fixture(owners: 2)
    [first, second] = fixture.transports

    assert {:ok, handle, preparation} =
             UpstreamGroups.prepare(fixture.groups, managed_group(fixture), self(), deadline())

    assert {:ok, baseline} =
             Resources.pin_many(UpstreamGroups.resources(handle), self(), :baseline, deadline())

    assert {:ok, request} =
             Resources.pin_many(UpstreamGroups.resources(handle), self(), :request, deadline())

    assert :ok = Resources.release(preparation)

    for forged <- [
          %{handle | transports: [second, first]},
          %{handle | transports: [first]},
          %{handle | generation: make_ref()},
          %{handle | owner_epoch: make_ref()},
          Map.delete(handle, :transports)
        ] do
      assert UpstreamGroups.valid_handle?(forged)
      assert {:error, :stale_group} = UpstreamGroups.status(forged)
      assert {:error, :stale_group} = Resources.pin_many([forged], self(), :request, deadline())

      assert {:error, :unavailable} =
               UpstreamGroups.checkout(forged, request, self(), %{}, deadline())

      assert %{inflight: 0, pins: 2} = UpstreamGroups.status(handle)
      assert :sys.get_state(fixture.groups).tokens == %{}
    end

    assert :ok = Resources.release(request)
    assert :ok = Resources.release(baseline)
  end

  @tag :group_transport_prepare
  test "facade provider waits do not block group identity and owner inspection" do
    fixture = fixture()
    [owner] = fixture.owners
    barrier = call_barrier(owner, :validate_endpoint)
    caller = prepare_caller(fixture.groups, managed_group(fixture), deadline())
    assert_receive {:call_held, ^owner, ^caller, {:validate_endpoint, _, _, _, _}}, 3_000
    assert {:ok, instance} = apply(UpstreamGroups, :instance, [fixture.groups, deadline()])
    assert instance == fixture.instance
    assert_empty_groups(fixture.groups)
    send(owner, {:continue_call, barrier})
    assert_receive {:candidate_result, ^caller, {:ok, _, _}}, 3_000
    join_caller(caller)
    assert_transport_pins(fixture, 1)

    assert {:error, :stale_probe} =
             apply(UpstreamGroups, :claim_probe, [fixture.groups, make_ref(), deadline()])
  end

  @tag :group_transport_prepare
  test "closed transport admission rejects without group publication or a request token" do
    fixture = fixture()
    [owner] = fixture.owners
    assert :ok = embedding_release(fixture)

    eventually(fn ->
      match?({:ok, %{resources: 0, pins: 0, request_tokens: 0}}, UpstreamTransports.status(owner))
    end)

    assert {:error, _} =
             UpstreamGroups.prepare(fixture.groups, managed_group(fixture), self(), deadline())

    assert_empty_groups(fixture.groups)
    assert {:ok, %{resources: 0, pins: 0, request_tokens: 0}} = UpstreamTransports.status(owner)
  end

  @tag :group_transport_prepare
  test "owned sidecar payload is charged before publication and rolls back at the byte limit" do
    fixture = fixture()
    compiled = managed_group(fixture)

    :sys.replace_state(fixture.groups, fn state ->
      %{state | limits: %{state.limits | max_config_bytes: :erlang.external_size(compiled)}}
    end)

    assert {:error, :group_capacity} =
             UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline())

    assert_empty_groups(fixture.groups)
    assert_transport_pins(fixture, 1)
  end

  defp managed_group(fixture, handles \\ nil, id \\ "api") do
    handles = handles || fixture.transports

    members =
      for {handle, index} <- Enum.with_index(handles),
          do: %{id: "member-#{index}", upstream: fixture.source.origin, transport: handle}

    assert {:ok, compiled} = UpstreamGroups.compile(%{id: id, members: members})
    compiled
  end

  defp fixture(options \\ []) do
    parent = self()

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)

        {:ok, listener} =
          :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

        {:ok, {_, port}} = :inet.sockname(listener)

        source =
          Keyword.get(options, :source, %{
            origin: "http://127.0.0.1:#{port}",
            connect_address: {127, 0, 0, 1},
            trust: nil
          })

        peer = spawn(fn -> preparation_peer(listener, parent) end)

        limits = %{
          max_resources: 4,
          max_pins: 16,
          max_request_tokens: 64,
          max_owned_payload_bytes: 2_097_152
        }

        owners =
          for _ <- 1..Keyword.get(options, :owners, 1) do
            {:ok, owner} = UpstreamTransports.start_link(instance: instance, limits: limits)
            Process.unlink(owner)
            owner
          end

        # Existing reservation denial isolates preparation ledgers. Managed HEAD
        # scheduling and wire acceptance run with normal capacity in the Probe suite.
        group_limits = Map.merge(%{probe_bytes: 1}, Keyword.get(options, :group_limits, %{}))
        {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: group_limits)
        Process.unlink(groups)
        send(parent, {:fixture_ready, self(), instance, groups, owners, source})
        fixture_loop(instance, groups, owners, listener, peer, [])
      end)

    assert_receive {:fixture_ready, ^embedding, instance, groups, owners, source}, 3_000

    on_exit(fn ->
      monitor = Process.monitor(embedding)
      send(embedding, {:cleanup, self()})
      assert_receive {:fixture_cleaned, ^embedding, result}, 10_000
      assert result == :ok, inspect(result)
      assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, 3_000
    end)

    transports =
      for owner <- owners do
        assert {:ok, handle, preparation} =
                 UpstreamTransports.prepare(owner, source, self(), deadline())

        send(embedding, {:baseline, handle, self()})
        assert_receive {:baseline_ready, ^embedding, ^handle, :ok}, 3_000
        assert :ok = Resources.release(preparation)
        handle
      end

    %{
      embedding: embedding,
      instance: instance,
      groups: groups,
      owners: owners,
      source: source,
      transports: transports
    }
  end

  defp fixture_loop(instance, groups, owners, listener, peer, baseline) do
    receive do
      {:baseline, handle, caller} ->
        assert {:ok, pins} = Resources.pin_many([handle], self(), :baseline, deadline())
        send(caller, {:baseline_ready, self(), handle, :ok})
        fixture_loop(instance, groups, owners, listener, peer, pins ++ baseline)

      {:release_baseline, caller} ->
        result = Resources.release(baseline)
        send(caller, {:baseline_released, self(), result})
        fixture_loop(instance, groups, owners, listener, peer, [])

      {:cleanup, caller} ->
        result =
          Lifecycle.protect(fn ->
            if Process.alive?(instance), do: assert(:ok == Gaoxy.stop(instance, 3_000))
            assert :ok = Resources.release(baseline)
            eventually(fn -> :sys.get_state(groups).groups == %{} end)
            GenServer.stop(groups, :normal, 3_000)

            for owner <- owners do
              assert {:ok, receipt} = UpstreamTransports.retire(owner, deadline())
              assert :ok = UpstreamTransports.await_retirement(receipt, deadline())

              assert {:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0}} =
                       UpstreamTransports.status(owner)

              GenServer.stop(owner, :normal, 3_000)
            end

            monitor = Process.monitor(peer)
            :gen_tcp.close(listener)
            assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, 3_000
            :ok
          end)

        send(caller, {:fixture_cleaned, self(), result})
    end
  end

  defp preparation_peer(listener, parent) do
    case :gen_tcp.accept(listener, 1_000) do
      {:error, :timeout} ->
        preparation_peer(listener, parent)

      {:error, :closed} ->
        :ok

      {:ok, socket} ->
        send(parent, {:unexpected_upstream, self()})
        :gen_tcp.close(socket)
        preparation_peer(listener, parent)
    end
  end

  defp embedding_release(fixture) do
    send(fixture.embedding, {:release_baseline, self()})
    assert_receive {:baseline_released, embedding, result}, 3_000
    assert embedding == fixture.embedding
    result
  end

  defp prepare_caller(groups, compiled, d) do
    parent = self()

    caller =
      spawn(fn ->
        result = UpstreamGroups.prepare(groups, compiled, self(), d)
        send(parent, {:candidate_result, self(), result})

        receive do
          :stop -> :ok
        after
          3_000 -> :ok
        end
      end)

    on_exit(fn -> send(caller, :stop) end)
    caller
  end

  defp join_caller(caller) do
    monitor = Process.monitor(caller)
    send(caller, :stop)
    assert_receive {:DOWN, ^monitor, :process, ^caller, :normal}, 3_000
  end

  defp call_barrier(owner, operation) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, message}}
        when not held and is_tuple(message) and elem(message, 0) == operation ->
          send(parent, {:call_held, self(), caller, message})

          receive do
            {:continue_call, ^barrier} -> :ok
          after
            3_000 -> raise "group test owner barrier timed out"
          end

          true

        {:in, {:cancel_pin, caller, op}} ->
          send(parent, {:operation_cancelled, self(), caller, op})
          held

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {debug, false})
    on_exit(fn -> send(owner, {:continue_call, barrier}) end)
    barrier
  end

  defp assert_empty_groups(owner) do
    assert %{groups: groups, pins: pins, tokens: tokens, probes: probes, bytes: 0} =
             :sys.get_state(owner)

    assert {groups, pins, tokens, probes} == {%{}, %{}, %{}, %{}}
  end

  defp assert_transport_pins(fixture, count) do
    for owner <- fixture.owners do
      eventually(fn ->
        match?({:ok, %{pins: ^count, request_tokens: 0}}, UpstreamTransports.status(owner))
      end)
    end
  end

  defp deadline, do: Lifecycle.deadline(3_000)

  defp eventually(fun, d \\ nil) do
    d = d || deadline()

    if fun.() do
      :ok
    else
      assert Lifecycle.remaining(d) > 0,
             "group transport condition did not settle before deadline"

      receive do
      after
        5 -> eventually(fun, d)
      end
    end
  end

  defp transport do
    %{provider: UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
  end

  defp group(id) do
    %{
      provider: UpstreamGroups,
      owner: self(),
      owner_epoch: make_ref(),
      group: id,
      generation: make_ref(),
      max_url_bytes: 64
    }
  end

  defp route(handle), do: %{target: {GroupEndpoint, %{group: handle}}}
end
