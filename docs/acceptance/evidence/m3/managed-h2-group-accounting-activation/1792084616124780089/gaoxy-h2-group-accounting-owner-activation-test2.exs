defmodule Gaoxy.Proxy.ManagedH2GroupAccountingOwnerActivationTest do
  use ExUnit.Case, async: false

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F

  @moduletag :capture_log
  @timeout 5_000
  @reserve 16_478_862

  # These cases are intentionally a later, separately authenticated success gate.
  # Before F controlled activation each fails the first public activation assertion.
  # There is no skip, exclusion, feature-flag override or fabricated owner reply.
  for protocol <- [:http2, :h2c] do
    test "#{protocol} genuine normal Probe binds the original completion and refunds both own ledgers once" do
      assert :ok === ManagedH2GroupBoundary.activation()
      f = fixture(unquote(protocol))
      seen = F.event(f.peer, "request")
      assert [":method", "HEAD"] in seen["headers"]
      assert seen["target"] === "/health"
      assert seen["ended"] === true
      {token, held} = bound_probe(f)
      completion = held.completion
      probe = held.pid
      monitor = Process.monitor(probe)
      state = :sys.get_state(f.groups)
      record = Map.fetch!(state.groups, group_key(f.group))
      config_bytes = record.bytes
      assert held.key === group_key(f.group)
      assert held.index === 0
      assert held.claimed === true
      assert held.bytes === @reserve
      assert state.probe_bytes === @reserve
      assert held.control_bytes === control_charge(:probe, held)
      assert control_sum(state) === state.control_bytes
      assert %{probes: 1, probe_bytes: @reserve, config_bytes: ^config_bytes} = UpstreamGroups.status(f.group)
      assert %HTTP.RequestCompletion{} = completion
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      [{transport_token, transport_hold}] = Map.to_list(:sys.get_state(f.transports).tokens)
      assert transport_hold.guardian === probe
      assert transport_hold.completion === completion
      probe_state = :sys.get_state(probe)
      assert probe_state.original_request.completion === completion
      assert probe_state.transport_selection === {f.transport, transport_token}
      assert Enum.all?(probe_state.transport_pins, &(&1.holder === probe and &1.kind === :request))

      assert {:error, :stale_probe} = UpstreamGroups.claim_probe(f.groups, token, f.group, held.deadline)
      assert {:error, :stale_probe} = UpstreamGroups.claim_probe(f.groups, token, held.deadline)
      assert {:error, :stale_probe} = UpstreamGroups.bind_probe(f.groups, token, completion)
      assert {:error, :stale_probe} = UpstreamGroups.probe_finished(f.groups, token, :success)
      assert :sys.get_state(f.groups).probes[token] === held
      answer_head(f, seen)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^probe, :normal}, @timeout
      F.eventually(fn -> UpstreamGroups.status(f.group).probes === 0 end)
      assert %{probe_bytes: 0, inflight: 0, config_bytes: ^config_bytes,
               members: [%{health: :healthy}]} = UpstreamGroups.status(f.group)
      F.eventually(fn -> match?({:ok, %{request_tokens: 0, helpers: 0}}, UpstreamTransports.status(f.transports)) end)
      before = owner_snapshot(f.groups)
      assert {:error, :stale_probe} = UpstreamGroups.probe_finished(f.groups, token, :success)
      send(f.groups, {:DOWN, held.monitor, :process, probe, :normal})
      assert owner_snapshot(f.groups) === before
      F.no_event(f.peer, "request")
    end

    test "#{protocol} thirty-two genuine selections enforce exact no-effect one-over admission and duplicate refunds" do
      assert :ok === ManagedH2GroupBoundary.activation()
      f = fixture(unquote(protocol), %{max_tokens: 32})
      establish_health(f)
      assert {:ok, request} = Resources.pin_many([f.group], self(), :request, deadline())
      before = :sys.get_state(f.groups)
      tokens = for _ <- 1..32 do
        assert {:ok, selected, token} = UpstreamGroups.checkout(f.group, request, self(), %{}, deadline())
        assert selected === hd(Map.fetch!(before.groups, group_key(f.group)).compiled.members)
        assert is_reference(token)
        token
      end
      held = :sys.get_state(f.groups)
      assert map_size(held.tokens) === 32
      assert UpstreamGroups.status(f.group).inflight === 32
      for token <- tokens do
        record = held.tokens[token]
        assert record.key === group_key(f.group)
        assert record.index === 0
        assert record.guardian === self()
        assert record.completion === nil
        assert is_reference(record.monitor)
        assert record.control_bytes === control_charge(:selection, record)
      end
      assert held.control_bytes === control_sum(held)
      denied = owner_snapshot(f.groups)
      assert {:error, :unavailable} = UpstreamGroups.checkout(f.group, request, self(), %{}, deadline())
      assert owner_snapshot(f.groups) === denied
      [first | rest] = tokens
      first_bytes = held.tokens[first].control_bytes
      assert :ok = UpstreamGroups.finish(f.group, first, :cancelled)
      refunded = owner_snapshot(f.groups)
      assert elem(refunded, 0).control_bytes === held.control_bytes - first_bytes
      assert :ok = UpstreamGroups.finish(f.group, first, :cancelled)
      assert owner_snapshot(f.groups) === refunded
      for token <- rest, do: assert(:ok === UpstreamGroups.finish(f.group, token, :cancelled))
      assert :sys.get_state(f.groups).control_bytes === before.control_bytes
      assert UpstreamGroups.status(f.group).inflight === 0
      assert :ok = Resources.release(request)
      F.no_event(f.peer, "request")
    end

    test "#{protocol} guardian loss before real selection bind preserves the nil-completion hold" do
      assert :ok === ManagedH2GroupBoundary.activation()
      f = fixture(unquote(protocol))
      establish_health(f)
      assert {:ok, request} = Resources.pin_many([f.group], self(), :request, deadline())
      parent = self()
      guardian = spawn(fn ->
        result = UpstreamGroups.checkout(f.group, request, self(), %{}, deadline())
        send(parent, {:real_selection, self(), result})
        receive do
          :stop -> :ok
        after
          10_000 -> exit(:test_guardian_deadline)
        end
      end)
      on_exit(fn -> if Process.alive?(guardian), do: send(guardian, :stop) end)
      assert_receive {:real_selection, ^guardian, {:ok, _, token}}, @timeout
      original = :sys.get_state(f.groups).tokens[token]
      assert original.completion === nil
      assert {:error, :invalid_selection_token} = UpstreamGroups.finish(f.group, token, :success)
      monitor = Process.monitor(guardian)
      Process.exit(guardian, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :killed}, @timeout
      F.eventually(fn -> UpstreamGroups.status(f.group).lifecycle === :failed end)
      state = :sys.get_state(f.groups)
      held = state.tokens[token]
      assert held.guardian === guardian
      assert held.monitor === nil
      assert held.completion === nil
      assert held.recovery === nil
      assert held.key === original.key
      assert held.index === original.index
      assert held.control_bytes === control_charge(:selection, held)
      assert state.control_bytes === control_sum(state)
      assert UpstreamGroups.status(f.group).inflight === 1
      assert :ok = Resources.release(request)
      assert :sys.get_state(f.groups).tokens[token] === held
      assert UpstreamGroups.status(f.group).inflight === 1
      F.no_event(f.peer, "request")
    end

    test "#{protocol} genuine completed-Probe recovery preserves original identity and refunds duplicate outcomes once" do
      assert :ok === ManagedH2GroupBoundary.activation()
      f = fixture(unquote(protocol))
      seen = F.event(f.peer, "request")
      {token, held} = bound_probe(f)
      probe = held.pid
      completion = held.completion
      :ok = :sys.suspend(probe)
      on_exit(fn -> if Process.alive?(probe), do: :sys.resume(probe) end)
      answer_head(f, seen)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert UpstreamGroups.status(f.group).probe_bytes === @reserve
      {supervisor, barrier, debug} = recovery_barrier(f.groups)
      monitor = Process.monitor(probe)
      Process.exit(probe, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^probe, :killed}, @timeout
      assert_receive {:real_recovery_start, ^supervisor, args}, @timeout
      assert args.owner === f.groups
      assert args.recovery === {:probe, token}
      assert args.completion === completion
      assert args.deadline >= held.deadline
      send(supervisor, {:continue_real_recovery, barrier})
      assert_receive {:real_recovery_pid, ^supervisor, recovery}, @timeout
      :ok = :sys.remove(supervisor, debug)
      recovery_monitor = Process.monitor(recovery)
      assert_receive {:DOWN, ^recovery_monitor, :process, ^recovery, reason}
                     when reason in [:normal, :noproc], @timeout
      F.eventually(fn -> UpstreamGroups.status(f.group).probes === 0 end)
      assert UpstreamGroups.status(f.group).probe_bytes === 0
      assert :sys.get_state(f.groups).control_bytes === control_sum(:sys.get_state(f.groups))
      F.eventually(fn -> match?({:ok, %{request_tokens: 0, helpers: 0}}, UpstreamTransports.status(f.transports)) end)
      before = owner_snapshot(f.groups)
      send(f.groups, {:recovered, :probe, token, recovery, :ok})
      send(f.groups, {:DOWN, held.monitor, :process, probe, :killed})
      assert owner_snapshot(f.groups) === before
      F.no_event(f.peer, "request")
    end

    test "#{protocol} real health failures and recoveries saturate thresholds within the stable group charge" do
      assert :ok === ManagedH2GroupBoundary.activation()
      f = fixture(unquote(protocol), %{}, %{interval: 1_000, stale_after: 10_000})
      initial_bytes = UpstreamGroups.status(f.group).config_bytes
      for {status, health, failures, successes} <- [
            {500, :unknown, 1, 0}, {500, :unhealthy, 2, 0}, {500, :unhealthy, 2, 0},
            {200, :unhealthy, 0, 1}, {200, :healthy, 0, 2}, {200, :healthy, 0, 2}
          ] do
        seen = F.event(f.peer, "request")
        assert [":method", "HEAD"] in seen["headers"]
        {_token, held} = bound_probe(f)
        F.command(f.peer, seen, "respond", %{"status" => status,
          "fields" => [["content-length", "0"]], "ended" => true})
        assert :ok = HTTP.RequestCompletion.await(held.completion, @timeout)
        F.eventually(fn -> UpstreamGroups.status(f.group).probes === 0 end)
        state = :sys.get_state(f.groups)
        record = Map.fetch!(state.groups, group_key(f.group))
        assert [%{health: ^health, failures: ^failures, successes: ^successes,
                  probe: nil}] = record.members
        assert record.bytes === initial_bytes
        assert :ok === ManagedH2GroupAccounting.group_update(record, initial_bytes)
        assert state.probe_bytes === 0
        assert state.control_bytes === control_sum(state)
      end
    end

    test "#{protocol} one-byte-short full Probe reservation creates no real child or HEAD" do
      assert :ok === ManagedH2GroupBoundary.activation()
      f = fixture(unquote(protocol), %{probe_bytes: @reserve - 1})
      {supervisor, debug} = observe_starts(f.groups)
      before = owner_snapshot(f.groups)
      send(f.groups, :kick_probes)
      assert owner_snapshot(f.groups) === before
      assert %{probes: 0, probe_bytes: 0, members: [%{health: :unknown}]} = UpstreamGroups.status(f.group)
      refute_receive {:unexpected_real_probe_start, ^supervisor, _}, 0
      F.no_event(f.peer, "request")
      :ok = :sys.remove(supervisor, debug)
    end
  end

  defp fixture(protocol, limits \\ %{}, health \\ %{}) do
    {peer, ready} = F.peer(protocol, ["--manual"])
    origin = (if protocol == :http2, do: "https", else: "http") <> "://localhost:#{ready["port"]}"
    caller = self()
    embedding = spawn(fn ->
      assert {:ok, instance} = Gaoxy.start_link()
      Process.unlink(instance)
      assert {:ok, transports} = UpstreamTransports.start_link(instance: instance, limits: %{
        max_resources: 2, max_pins: 256, max_request_tokens: 64, max_owned_payload_bytes: 4_194_304
      })
      Process.unlink(transports)
      assert {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: limits)
      Process.unlink(groups)
      send(caller, {:activation_owner_ready, self(), instance, transports, groups})
      receive do
        {:cleanup, reply} ->
          result =
            try do
              joins = for pid <- [groups, transports, instance], do: {pid, Process.monitor(pid)}
              assert :ok = GenServer.stop(groups, :normal, @timeout)
              assert {:ok, receipt} = UpstreamTransports.retire(transports, deadline())
              assert :ok = UpstreamTransports.await_retirement(receipt, deadline())
              assert {:ok, %{resources: 0, pins: 0, request_tokens: 0, helpers: 0}} =
                UpstreamTransports.status(transports)
              assert :ok = Gaoxy.stop(instance, 10_000)
              for {pid, monitor} <- joins do
                assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
              end
              :ok
            rescue
              error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
            end
          send(reply, {:activation_owner_cleanup, self(), result})
      after
        120_000 -> raise "test-owned activation owner cleanup deadline expired"
      end
    end)
    assert_receive {:activation_owner_ready, ^embedding, instance, transports, groups}, @timeout
    on_exit(fn ->
      monitor = Process.monitor(embedding)
      send(embedding, {:cleanup, self()})
      assert_receive {:activation_owner_cleanup, ^embedding, :ok}, 30_000
      assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
    end)
    source = %{protocol: protocol, origin: origin, connect_address: {127, 0, 0, 1},
      trust: if(protocol == :http2, do: F.certificates(ready["ca"]), else: nil)}
    assert {:ok, transport, transport_preparation} = UpstreamTransports.prepare(transports, source, self(), deadline())
    assert {:ok, _transport_baseline} = Resources.pin_many([transport], self(), :baseline, deadline())
    assert :ok = Resources.release(transport_preparation)
    assert {:ok, compiled} = UpstreamGroups.compile(%{
      id: "real-owner", max_inflight: 32,
      health: Map.merge(%{path: "/health", interval: 3_600_000, stale_after: 3_600_000,
        timeout: 5_000, jitter: 0, failure_threshold: 2, recovery_threshold: 2}, health),
      members: [%{id: "only", upstream: origin, upstream_protocol: protocol,
        transport: transport, max_inflight: 32}]
    })
    assert {:ok, group, preparation} = UpstreamGroups.prepare(groups, compiled, self(), deadline())
    assert {:ok, _baseline} = Resources.pin_many([group], self(), :baseline, deadline())
    assert :ok = Resources.release(preparation)
    %{instance: instance, transports: transports, transport: transport, groups: groups,
      group: group, peer: peer, protocol: protocol, origin: origin}
  end

  defp establish_health(f) do
    seen = F.event(f.peer, "request")
    assert [":method", "HEAD"] in seen["headers"]
    {_token, held} = bound_probe(f)
    answer_head(f, seen)
    assert :ok = HTTP.RequestCompletion.await(held.completion, @timeout)
    F.eventually(fn -> match?(%{probes: 0, members: [%{health: :healthy}]}, UpstreamGroups.status(f.group)) end)
    F.eventually(fn -> match?({:ok, %{request_tokens: 0, helpers: 0}}, UpstreamTransports.status(f.transports)) end)
  end

  defp bound_probe(f) do
    F.eventually(fn ->
      case Map.to_list(:sys.get_state(f.groups).probes) do
        [{_token, %{completion: %HTTP.RequestCompletion{}, claimed: true}}] -> true
        _ -> false
      end
    end)
    [entry] = Map.to_list(:sys.get_state(f.groups).probes)
    entry
  end

  defp answer_head(f, seen), do: F.command(f.peer, seen, "respond", %{
    "status" => 200, "fields" => [["content-length", "0"]], "ended" => true
  })
  defp control_charge(kind, held) do
    assert {:ok, bytes} = ManagedH2GroupAccounting.control_charge(kind, held)
    bytes
  end
  defp control_sum(state), do: Enum.sum(for record <- Map.values(state.pins) ++ Map.values(state.tokens) ++ Map.values(state.probes),
    do: Map.get(record, :control_bytes, 0))
  defp group_key(group), do: {group.group, group.generation}
  defp owner_snapshot(owner) do
    state = :sys.get_state(owner)
    {:monitors, monitors} = Process.info(owner, :monitors)
    {state, Enum.sort(monitors)}
  end
  defp deadline, do: Lifecycle.deadline(@timeout)

  defp recovery_barrier(owner) do
    parent = self()
    supervisor = Process.whereis(Gaoxy.Proxy.ProbeSupervisor)
    barrier = make_ref()
    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:start_child, spec}}} when not held ->
          case recovery_args(spec, owner) do
            nil -> false
            args ->
              send(parent, {:real_recovery_start, self(), args})
              receive do
                {:continue_real_recovery, ^barrier} -> :ok
              after
                @timeout -> raise "real recovery startup barrier expired"
              end
              true
          end
        {:out, {:ok, pid}, _, _} when held ->
          send(parent, {:real_recovery_pid, self(), pid})
          false
        _ -> held
      end
    end
    :ok = :sys.install(supervisor, {debug, false})
    on_exit(fn ->
      send(supervisor, {:continue_real_recovery, barrier})
      if Process.alive?(supervisor), do: :sys.remove(supervisor, debug)
    end)
    {supervisor, barrier, debug}
  end

  defp observe_starts(owner) do
    parent = self()
    supervisor = Process.whereis(Gaoxy.Proxy.ProbeSupervisor)
    debug = fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:start_child, spec}}} ->
          if owner_args?(spec, owner), do: send(parent, {:unexpected_real_probe_start, self(), spec})
        _ -> :ok
      end
      state
    end
    :ok = :sys.install(supervisor, {debug, nil})
    on_exit(fn -> if Process.alive?(supervisor), do: :sys.remove(supervisor, debug) end)
    {supervisor, debug}
  end
  defp recovery_args(%{owner: owner, recovery: _} = args, owner), do: args
  defp recovery_args(tuple, owner) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> recovery_args(owner)
  defp recovery_args(list, owner) when is_list(list), do: Enum.find_value(list, &recovery_args(&1, owner))
  defp recovery_args(_, _), do: nil
  defp owner_args?(%{owner: owner, member: _}, owner), do: true
  defp owner_args?(tuple, owner) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> owner_args?(owner)
  defp owner_args?(list, owner) when is_list(list), do: Enum.any?(list, &owner_args?(&1, owner))
  defp owner_args?(_, _), do: false
end
