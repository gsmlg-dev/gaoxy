defmodule Gaoxy.Proxy.ManagedH2GroupAccountingOwnerTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{ManagedH2Client, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.UpstreamGroups.Options

  @control_limit 16_777_216
  @growth 131_072
  @group_cap 12_582_912
  @pin_cap 196_608
  @timeout 30_000

  for protocol <- [:http2, :h2c] do
    test "#{protocol} compiles homogeneous managed members and recompiles the exact struct" do
      protocol = unquote(protocol)
      transport = transport_identity()
      input = group_input(protocol, transport, "homogeneous", 32)
      assert {:ok, %Options{} = compiled} = UpstreamGroups.compile(input)
      assert compiled.id === input.id
      assert compiled.max_inflight === 64
      assert Enum.map(compiled.members, & &1.id) === Enum.map(input.members, & &1.id)

      for member <- compiled.members do
        assert member.config.upstream_protocol === protocol
        assert member.config.client === ManagedH2Client
        assert member.config.transport === transport
        assert :ok === Gaoxy.Proxy.ManagedH2Envelope.validate_config(member.config)
        assert compact_binaries?(member)
      end

      assert {:ok, ^compiled} = UpstreamGroups.compile(compiled)
      refute_received {:"$gen_call", _, _}
    end

    test "#{protocol} rejects backing-heavy IDs and health paths without changing H1 acceptance" do
      protocol = unquote(protocol)
      input = group_input(protocol, transport_identity())
      [member] = input.members

      for invalid <- [
            %{input | id: slice(String.duplicate("g", 100))},
            %{input | members: [%{member | id: slice(String.duplicate("m", 100))}]},
            Map.put(input, :health, %{path: slice("/" <> String.duplicate("h", 99))}),
            Map.put(input, :health, %{path: "/health?ready"}),
            %{input | id: String.duplicate("g", 129)},
            Map.put(input, :health, %{path: "/" <> String.duplicate("x", 8_192)})
          ] do
        assert {:error, :invalid_upstream_group} = UpstreamGroups.compile(invalid)
      end

      legacy = %{
        id: slice(String.duplicate("g", 100)),
        members: [%{id: slice(String.duplicate("m", 100)), upstream: "http://peer.test"}],
        health: %{path: slice("/health?" <> String.duplicate("r", 100))}
      }

      assert {:ok, compiled} = UpstreamGroups.compile(legacy)
      assert {:ok, ^compiled} = UpstreamGroups.compile(compiled)
      assert hd(compiled.members).config.client === Gaoxy.Proxy.HTTPFetchClient
    end

    test "#{protocol} preserves complete raw roots at 8192 bytes and refuses one over" do
      protocol = unquote(protocol)
      transport = transport_identity()
      root = raw_origin(protocol, 8_192)
      input = group_input(protocol, transport)
      [member] = input.members
      assert {:ok, compiled} = UpstreamGroups.compile(%{input | members: [%{member | upstream: root}]})
      [stored] = compiled.members
      assert raw_root(stored.config) === root
      assert compact_binaries?(stored)
      assert {:ok, ^compiled} = UpstreamGroups.compile(compiled)

      assert {:error, :invalid_upstream_group} =
               UpstreamGroups.compile(%{input | members: [%{member | upstream: raw_origin(protocol, 8_193)}]})
    end

    test "#{protocol} prepares a real H8 and charges both compiled and runtime configs" do
      protocol = unquote(protocol)
      f = fixture(protocol)
      input = group_input(protocol, f.transport, "prepared", 32)
      assert {:ok, compiled} = UpstreamGroups.compile(input)
      assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
      assert map_size(handle) === 8
      assert handle.execution_profile === :managed_h2
      assert handle.transports === [f.transport]
      assert handle.max_url_bytes === byte_size(f.origin)
      assert UpstreamGroups.valid_handle?(handle)
      assert [^handle, transport] = UpstreamGroups.resources(handle)
      assert transport === f.transport
      assert {:ok, [^handle, ^transport]} = Resources.validate(UpstreamGroups.resources(handle))
      assert Enum.sort(Map.keys(handle)) ===
               Enum.sort(~w(provider owner owner_epoch group generation max_url_bytes transports execution_profile)a)

      state = :sys.get_state(f.groups)
      record = Map.fetch!(state.groups, {handle.group, handle.generation})
      assert record.compiled === compiled
      assert Enum.map(record.members, &Map.take(&1, [:id, :config, :max_inflight])) === compiled.members
      assert record.bytes === :erlang.external_size(Map.delete(record, :bytes)) + @growth
      assert record.bytes <= @group_cap
      assert state.bytes === record.bytes
      assert record.bytes > :erlang.external_size(compiled) + :erlang.external_size(handle.transports)
      assert_exact_controls(state)
      assert %{config_bytes: bytes, control_bytes: control, control_limit: @control_limit,
               inflight: 0, probes: 0, probe_bytes: 0, pins: 1} = UpstreamGroups.status(handle)
      assert bytes === record.bytes
      assert control === state.control_bytes
      assert {:error, :accounting_not_ready} === Gaoxy.Proxy.ManagedH2GroupBoundary.activation()
      assert :ok = Resources.release(preparation)
      assert_empty_groups(f.groups)
    end

    test "#{protocol} validates real protocol raw-root instance and resource identities before group admission" do
      protocol = unquote(protocol)
      f = fixture(protocol)
      foreign = fixture(protocol)
      other_protocol = fixture(if(protocol == :http2, do: :h2c, else: :http2))
      wrong_root = String.replace(f.origin, "peer.test", "wrong.test")

      for {transport, origin, expected} <- [
            {f.transport, wrong_root, :transport_endpoint_mismatch},
            {foreign.transport, foreign.origin, :transport_endpoint_mismatch},
            {other_protocol.transport, f.origin, :transport_endpoint_mismatch},
            {%{f.transport | owner_epoch: make_ref()}, f.origin, :invalid_resource},
            {%{f.transport | resource: make_ref()}, f.origin, :invalid_resource}
          ] do
        input = group_input(protocol, transport)
        [member] = input.members
        assert {:ok, compiled} = UpstreamGroups.compile(%{input | members: [%{member | upstream: origin}]})
        before = owner_snapshot(f.groups)
        transport_before = UpstreamTransports.status(f.transport.owner)
        assert {:error, ^expected} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
        assert owner_snapshot(f.groups) === before
        assert UpstreamTransports.status(f.transport.owner) === transport_before
        assert_empty_groups(f.groups)
      end
    end

    test "#{protocol} refuses config capacity including runtime duplicates before monitor or timer effects" do
      protocol = unquote(protocol)
      f = fixture(protocol, max_config_bytes: @growth)
      assert {:ok, compiled} = UpstreamGroups.compile(group_input(protocol, f.transport, "denied", 32))
      assert :erlang.external_size(compiled) < @growth
      before = owner_snapshot(f.groups)
      transport_before = UpstreamTransports.status(f.transport.owner)
      assert {:error, :group_capacity} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
      assert owner_snapshot(f.groups) === before
      assert UpstreamTransports.status(f.transport.owner) === transport_before
      assert_empty_groups(f.groups)
    end

    test "#{protocol} pin capacity denial creates no monitor timer token or probe and keeps exact charges" do
      protocol = unquote(protocol)
      f = fixture(protocol, max_pins: 1)
      assert {:ok, compiled} = UpstreamGroups.compile(group_input(protocol, f.transport))
      assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
      before = owner_snapshot(f.groups)
      assert {:error, :group_capacity} = Resources.pin_many([handle], self(), :request, deadline())
      assert owner_snapshot(f.groups) === before
      assert_exact_controls(:sys.get_state(f.groups))
      assert :ok = Resources.release(preparation)
      assert_empty_groups(f.groups)
    end

    test "#{protocol} records exact real pin bytes and refunds duplicates once while a baseline keeps the group" do
      protocol = unquote(protocol)
      f = fixture(protocol)
      assert {:ok, compiled} = UpstreamGroups.compile(group_input(protocol, f.transport))
      assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
      assert {:ok, baseline} = Resources.pin_many([handle], self(), :baseline, deadline())
      assert :ok = Resources.release(preparation)
      before = :sys.get_state(f.groups)
      assert {:ok, [request]} = Resources.pin_many([handle], self(), :request, deadline())
      state = :sys.get_state(f.groups)
      held = Map.fetch!(state.pins, request.ref)
      assert map_size(request) === 7
      refute Map.has_key?(request, :holder)
      assert held.keys === [{handle.group, handle.generation}]
      assert held.holder === self()
      assert held.acquirer === self()
      assert held.operation === request.operation
      assert is_reference(held.monitor)
      assert is_reference(held.timer)
      assert held.control_bytes === :erlang.external_size(Map.delete(held, :control_bytes))
      assert held.control_bytes <= @pin_cap
      assert state.control_bytes === before.control_bytes + held.control_bytes
      assert state.bytes === before.bytes
      assert_exact_controls(state)
      assert :ok = Resources.release([request])
      after_release = owner_snapshot(f.groups)
      assert elem(after_release, 0).control_bytes === before.control_bytes
      assert :ok = Resources.release([request])
      assert owner_snapshot(f.groups) === after_release
      assert :ok = Resources.release(baseline)
      assert_empty_groups(f.groups)
    end
  end

  test "mixed H1 H2 profiles and mixed H2 protocols are refused in raw and struct forms" do
    transport = transport_identity()
    h2 = group_input(:http2, transport)
    [h2_member] = h2.members
    [h2c_member] = group_input(:h2c, transport).members
    legacy = %{id: "legacy", upstream: "http://peer.test"}
    assert {:ok, compiled} = UpstreamGroups.compile(h2)
    assert {:ok, legacy_compiled} = UpstreamGroups.compile(%{id: "h1", members: [legacy]})
    assert {:ok, h2c_compiled} = UpstreamGroups.compile(group_input(:h2c, transport))

    for invalid <- [
          %{h2 | members: [h2_member, %{legacy | id: "other"}]},
          %{h2 | members: [h2_member, %{h2c_member | id: "other"}]},
          %{compiled | members: compiled.members ++ legacy_compiled.members},
          %{compiled | members: compiled.members ++ Enum.map(h2c_compiled.members, &%{&1 | id: "other"})}
        ] do
      assert {:error, :invalid_upstream_group} = UpstreamGroups.compile(invalid)
    end
  end

  test "strict H8 rejects expanded incomplete duplicate and backing-heavy manifests" do
    transport = transport_identity()
    handle = %{
      provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(), group: "group",
      generation: make_ref(), max_url_bytes: 8_192, transports: [transport],
      execution_profile: :managed_h2
    }
    assert UpstreamGroups.valid_handle?(handle)
    assert {:ok, [^handle, ^transport]} = Resources.validate(UpstreamGroups.resources(handle))

    for bad <- [
          Map.delete(handle, :transports), Map.delete(handle, :generation),
          Map.put(handle, :authority, "https://other.test"),
          %{handle | execution_profile: :http1}, %{handle | group: slice(String.duplicate("g", 100))},
          %{handle | max_url_bytes: 8_193}, %{handle | transports: []},
          %{handle | transports: [transport, transport]},
          %{handle | transports: [transport | :improper]},
          %{handle | transports: for(_ <- 1..33, do: transport_identity())},
          %{handle | transports: [Map.put(transport, :policy, %{})]}
        ] do
      refute UpstreamGroups.valid_handle?(bad)
      assert {:error, :invalid_endpoint_resources} === UpstreamGroups.resources(bad)
    end
  end

  test "a real H2 pin containing H1 keys charges the whole record and H1 status stays unchanged" do
    f = fixture(:h2c)
    assert {:ok, h2} = UpstreamGroups.compile(group_input(:h2c, f.transport, "h2"))
    assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, h2, self(), deadline())
    assert {:ok, h1} = UpstreamGroups.compile(%{id: "h1", members: [%{id: "old", upstream: "http://peer.test"}]})
    assert {:ok, legacy, legacy_preparation} = UpstreamGroups.prepare(f.groups, h1, self(), deadline())
    before = :sys.get_state(f.groups)
    assert {:ok, pin} = UpstreamGroups.pin_many([handle, legacy], self(), :request, make_ref(), deadline())
    state = :sys.get_state(f.groups)
    held = Map.fetch!(state.pins, pin.ref)
    assert held.keys === [{handle.group, handle.generation}, {legacy.group, legacy.generation}]
    assert held.control_bytes === :erlang.external_size(Map.delete(held, :control_bytes))
    assert held.control_bytes > :erlang.external_size(%{Map.delete(held, :control_bytes) | keys: [hd(held.keys)]})
    assert state.control_bytes === before.control_bytes + held.control_bytes
    assert Enum.sort(Map.keys(UpstreamGroups.status(legacy))) ===
             Enum.sort(~w(lifecycle inflight members probe_bytes probes pins)a)
    assert_exact_controls(state)
    assert :ok = UpstreamGroups.release(pin)
    assert :sys.get_state(f.groups).control_bytes === before.control_bytes
    assert :ok = Resources.release(preparation ++ legacy_preparation)
    assert_empty_groups(f.groups)
  end

  @tag timeout: 120_000
  test "internal control capacity denies real multi-group pins atomically and stored removal refunds exactly" do
    f = fixture(:h2c, max_groups: 128, max_pins: 16_384, max_config_bytes: 67_108_864)
    prepared =
      for n <- 1..64 do
        id = Integer.to_string(n) <> String.duplicate("g", 128 - byte_size(Integer.to_string(n)))
        assert {:ok, compiled} = UpstreamGroups.compile(group_input(:h2c, f.transport, id))
        assert {:ok, handle, pins} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
        {handle, pins}
      end
    handles = Enum.map(prepared, &elem(&1, 0))
    before = :sys.get_state(f.groups)
    pins = fill_control(f.groups, handles, [], Lifecycle.deadline(60_000))
    assert pins != []
    denied = owner_snapshot(f.groups)
    state = elem(denied, 0)
    assert map_size(state.pins) < state.limits.max_pins
    assert state.control_bytes <= @control_limit
    assert state.control_bytes + @pin_cap > @control_limit
    assert_exact_controls(state)
    assert {:error, :group_capacity} = UpstreamGroups.pin_many(handles, self(), :baseline, make_ref(), deadline())
    assert owner_snapshot(f.groups) === denied
    [removed | remaining] = pins
    removed_record = Map.fetch!(state.pins, removed.ref)
    assert :ok = UpstreamGroups.release(removed)
    refunded = owner_snapshot(f.groups)
    assert elem(refunded, 0).control_bytes === state.control_bytes - removed_record.control_bytes
    assert :ok = UpstreamGroups.release(removed)
    assert owner_snapshot(f.groups) === refunded
    for pin <- remaining, do: assert(:ok === UpstreamGroups.release(pin))
    assert :sys.get_state(f.groups).control_bytes === before.control_bytes
    for {_handle, preparation} <- prepared, do: assert(:ok === Resources.release(preparation))
    assert_empty_groups(f.groups)
  end


  test "complete H2 config charge admits its exact budget and refuses one byte less" do
    f = fixture(:h2c)
    assert {:ok, compiled} = UpstreamGroups.compile(group_input(:h2c, f.transport, "exact"))
    assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
    bytes = UpstreamGroups.status(handle).config_bytes
    assert :ok = Resources.release(preparation)
    assert_empty_groups(f.groups)

    fitting = start_supervised!({UpstreamGroups, instance: f.instance,
      limits: %{probe_bytes: 1, max_config_bytes: bytes}}, id: make_ref())
    short = start_supervised!({UpstreamGroups, instance: f.instance,
      limits: %{probe_bytes: 1, max_config_bytes: bytes - 1}}, id: make_ref())
    assert {:ok, fitted, fitted_preparation} = UpstreamGroups.prepare(fitting, compiled, self(), deadline())
    assert UpstreamGroups.status(fitted).config_bytes === bytes
    denied = owner_snapshot(short)
    assert {:error, :group_capacity} = UpstreamGroups.prepare(short, compiled, self(), deadline())
    assert owner_snapshot(short) === denied
    assert_empty_groups(short)
    assert :ok = Resources.release(fitted_preparation)
    assert_empty_groups(fitting)
  end

  test "real H8 manifest preserves first occurrence order and the complete 32-resource set" do
    f = fixture(:h2c)
    transports = [f.transport | for(_ <- 1..31, do: prepare_transport(f, :h2c))]
    member_transports = Enum.reverse(transports)
    input = %{id: "manifest", members: for({transport, n} <- Enum.with_index(member_transports), do: %{
      id: "member-#{n}", upstream: f.origin, upstream_protocol: :h2c, transport: transport
    })}
    assert {:ok, compiled} = UpstreamGroups.compile(input)
    assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
    assert handle.transports === member_transports
    assert UpstreamGroups.resources(handle) === [handle | member_transports]
    assert {:ok, resources} = Resources.validate(UpstreamGroups.resources(handle))
    assert resources === [handle | member_transports]
    assert :ok = Resources.release(preparation)
    assert_empty_groups(f.groups)
  end

  test "prepared max_url_bytes retains the actual complete raw 8192-byte origin" do
    f = fixture(:h2c)
    root = raw_origin(:h2c, 8_192)
    input = group_input(:h2c, f.transport)
    [member] = input.members
    assert {:ok, compiled} = UpstreamGroups.compile(%{input | members: [%{member | upstream: root}]})
    assert {:ok, handle, preparation} = UpstreamGroups.prepare(f.groups, compiled, self(), deadline())
    assert handle.max_url_bytes === 8_192
    record = Map.fetch!(:sys.get_state(f.groups).groups, {handle.group, handle.generation})
    assert raw_root(hd(record.members).config) === root
    assert record.bytes === :erlang.external_size(Map.delete(record, :bytes)) + @growth
    assert :ok = Resources.release(preparation)
    assert_empty_groups(f.groups)
  end

  test "control limit remains internal and the fixed H2 endpoint reservation is unchanged" do
    assert {:error, :invalid_group_owner_options} =
             Options.owner(instance: self(), limits: %{max_control_bytes: @control_limit})
    assert {:error, :invalid_group_owner_options} =
             Options.owner(instance: self(), control_limit: @control_limit)
    assert ManagedH2Client.reservation_bytes([], byte_size("http://peer.test/"), 65_536) === 9_444_956
  end

  defp fixture(protocol, group_limits \\ []) do
    assert {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    assert {:ok, owner} = UpstreamTransports.start_link(instance: instance, limits: %{
      max_resources: 64, max_pins: 4_096, max_request_tokens: 64,
      max_owned_payload_bytes: 67_108_864
    })
    Process.unlink(owner)
    assert {:ok, groups} = UpstreamGroups.start_link(instance: instance,
      limits: Map.merge(%{probe_bytes: 1}, Map.new(group_limits)))
    Process.unlink(groups)
    on_exit(fn ->
      group_monitor = Process.monitor(groups)
      owner_monitor = Process.monitor(owner)
      if Process.alive?(groups), do: GenServer.stop(groups, :normal, 3_000)
      assert_receive {:DOWN, ^group_monitor, :process, ^groups, _}, 3_000
      if Process.alive?(owner) do
        assert {:ok, receipt} = UpstreamTransports.retire(owner, Lifecycle.deadline(10_000))
        assert :ok = UpstreamTransports.await_retirement(receipt, Lifecycle.deadline(10_000))
        assert {:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0}} = UpstreamTransports.status(owner)
      end
      assert :ok = Gaoxy.stop(instance, 10_000)
      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, 3_000
    end)
    origin = if protocol == :http2, do: "https://peer.test", else: "http://peer.test"
    source = %{protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1},
      trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)}
    assert {:ok, transport, preparation} = UpstreamTransports.prepare(owner, source, self(), deadline())
    assert {:ok, _baseline} = Resources.pin_many([transport], self(), :baseline, deadline())
    assert :ok = Resources.release(preparation)
    %{instance: instance, groups: groups, transport: transport, origin: origin}
  end

  defp prepare_transport(f, protocol) do
    source = %{protocol: protocol, origin: f.origin, connect_address: {127, 0, 0, 1},
      trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)}
    assert {:ok, transport, preparation} = UpstreamTransports.prepare(f.transport.owner, source, self(), deadline())
    assert {:ok, _baseline} = Resources.pin_many([transport], self(), :baseline, deadline())
    assert :ok = Resources.release(preparation)
    transport
  end

  defp fill_control(owner, handles, pins, limit) do
    assert Lifecycle.remaining(limit) > 0, "public control admission did not terminate before its finite deadline"
    assert length(pins) < 16_384, "count capacity hid the required control-byte refusal"
    case UpstreamGroups.pin_many(handles, self(), :baseline, make_ref(), limit) do
      {:ok, pin} -> fill_control(owner, handles, [pin | pins], limit)
      {:error, :group_capacity} -> pins
      other -> flunk("unexpected public pin result: #{inspect(other)}")
    end
  end

  defp assert_exact_controls(state) do
    records = Map.values(state.pins) ++ Map.values(state.tokens) ++ Map.values(state.probes)
    charged = Enum.filter(records, &Map.has_key?(&1, :control_bytes))
    assert state.control_bytes === Enum.sum(Enum.map(charged, & &1.control_bytes))
    for held <- charged do
      assert held.control_bytes === :erlang.external_size(Map.delete(held, :control_bytes))
      assert held.control_bytes > 0
    end
    assert state.control_bytes <= @control_limit
  end

  defp owner_snapshot(owner) do
    state = :sys.get_state(owner)
    {:monitors, monitors} = Process.info(owner, :monitors)
    {state, Enum.sort(monitors)}
  end

  defp assert_empty_groups(owner) do
    state = :sys.get_state(owner)
    assert state.groups === %{}
    assert state.pins === %{}
    assert state.tokens === %{}
    assert state.probes === %{}
    assert state.bytes === 0
    assert state.control_bytes === 0
    assert state.probe_bytes === 0
  end

  defp group_input(protocol, transport, id \\ "group", count \\ 1) do
    origin = if protocol == :http2, do: "https://peer.test", else: "http://peer.test"
    %{id: id, members: for(n <- 1..count, do: %{
      id: "member-#{n}", upstream: origin, upstream_protocol: protocol, transport: transport
    })}
  end

  # Pure constructor identity only. Runtime preparation cases use real T owners.
  defp transport_identity, do: %{provider: UpstreamTransports, owner: self(),
    owner_epoch: make_ref(), resource: make_ref()}
  defp raw_root(config), do: config.uri.scheme <> "://" <> config.uri.authority
  defp raw_origin(protocol, bytes) do
    {prefix, port} = if protocol == :http2, do: {"https://peer.test:", "443"}, else: {"http://peer.test:", "80"}
    :binary.copy(prefix <> :binary.copy("0", bytes - byte_size(prefix) - byte_size(port)) <> port)
  end
  defp slice(value), do: binary_part(:binary.copy(value <> "x", 4_096), 0, byte_size(value))
  defp compact_binaries?(binary) when is_binary(binary), do: :binary.referenced_byte_size(binary) === byte_size(binary)
  defp compact_binaries?(map) when is_map(map), do: Enum.all?(Map.to_list(map), fn {key, value} -> compact_binaries?(key) and compact_binaries?(value) end)
  defp compact_binaries?(list) when is_list(list), do: Enum.all?(list, &compact_binaries?/1)
  defp compact_binaries?(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> compact_binaries?()
  defp compact_binaries?(_), do: true
  defp deadline, do: Lifecycle.deadline(@timeout)
end
