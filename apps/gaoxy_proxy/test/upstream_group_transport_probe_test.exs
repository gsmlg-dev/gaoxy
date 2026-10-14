defmodule Gaoxy.Proxy.UpstreamGroupTransportProbeTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamGroups.Probe
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @moduletag :capture_log
  @timeout 3_000

  setup_all do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-managed-probe-#{System.unique_integer([:positive])}")

    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    on_exit(fn -> File.rm_rf!(directory) end)

    for name <- ["trusted", "untrusted"] do
      {log, status} =
        System.cmd("bash", [script, Path.join(directory, name)], stderr_to_stdout: true)

      assert status == 0, log
    end

    {:ok, trusted: Path.join(directory, "trusted"), untrusted: Path.join(directory, "untrusted")}
  end

  for protocol <- [:tcp, :tls] do
    @protocol protocol
    test "#{protocol} HEAD binds the same original completion to both owners with its own transport pin",
         context do
      {source, peer} = peer(@protocol, context)
      fixture = fixture(source)
      {group, preparation} = prepare(fixture, source)
      baseline(fixture, group, preparation)
      assert_receive {:head, ^peer, head, alpn}, @timeout
      assert head =~ "HEAD /health?ready=1 HTTP/1.1\r\n"
      assert alpn == nil

      eventually(fn ->
        case Map.values(:sys.get_state(fixture.transports).tokens) do
          [%{completion: %HTTP.RequestCompletion{}}] -> true
          _ -> false
        end
      end)

      [{group_token, group_hold}] = Map.to_list(:sys.get_state(fixture.groups).probes)
      probe = group_hold.pid
      [{transport_token, transport_hold}] = Map.to_list(:sys.get_state(fixture.transports).tokens)
      assert transport_hold.guardian == probe
      assert %HTTP.RequestCompletion{} = completion = transport_hold.completion

      eventually(fn ->
        :sys.get_state(fixture.groups).probes[group_token].completion == completion
      end)

      state = :sys.get_state(probe)
      assert state.request.completion == completion
      assert state.transport_selection == {fixture.transport, transport_token}
      assert [_] = state.transport_pins
      assert Enum.all?(state.transport_pins, &(&1.holder == probe and &1.kind == :request))
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert UpstreamGroups.status(group).probes == 1

      # A confirmed wire end alone cannot refund either owner's reservation.
      :ok = :sys.suspend(probe)
      on_exit(fn -> if Process.alive?(probe), do: :sys.resume(probe) end)
      send(peer, {:status, 200})
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert UpstreamGroups.status(group).probes == 1
      assert {:ok, %{request_tokens: 1}} = Transports.status(fixture.transports)
      :ok = :sys.resume(probe)
      monitor = Process.monitor(probe)

      assert_receive {:DOWN, ^monitor, :process, ^probe, reason}
                     when reason in [:normal, :noproc],
                     @timeout

      assert [%{health: :healthy, probe: false}] = UpstreamGroups.status(group).members
      assert UpstreamGroups.status(group).probe_bytes == 0
      assert {:ok, %{request_tokens: 0, helpers: 0}} = Transports.status(fixture.transports)
      stop(fixture, peer)
    end
  end

  test "local transport pin capacity denial performs no HEAD and leaves health counters untouched" do
    {source, peer} = peer(:tcp, %{})
    fixture = fixture(source, 2)
    {group, preparation} = prepare(fixture, source)

    eventually(fn ->
      [member] = stored_members(fixture, group)
      member.probe == nil and member.due > Lifecycle.now()
    end)

    assert [%{health: :unknown, checked: nil, failures: 0, successes: 0}] =
             stored_members(fixture, group)

    assert UpstreamGroups.status(group).probes == 0
    assert UpstreamGroups.status(group).probe_bytes == 0
    assert {:ok, %{request_tokens: 0, pins: 2}} = Transports.status(fixture.transports)
    refute_receive {:head, ^peer, _, _}, 0
    assert_no_connection(peer)
    baseline(fixture, group, preparation)
    stop(fixture, peer)
  end

  test "held managed transport validation leaves group status responsive and cancellation joins the original completion" do
    {source, peer} = peer(:tcp, %{})
    fixture = fixture(source)
    barrier = transport_barrier(fixture.transports, :validate_endpoint, 1)
    {group, preparation} = prepare(fixture, source)
    owner = fixture.transports

    assert_receive {:transport_call_held, ^owner, probe, {:validate_endpoint, _, _, _, _}},
                   @timeout

    assert %{lifecycle: :active, probes: 1} = UpstreamGroups.status(group)
    assert_no_connection(peer)
    send(owner, {:continue_transport_call, barrier})
    baseline(fixture, group, preparation)
    assert_receive {:head, ^peer, _, _}, @timeout
    [{_, hold}] = Map.to_list(:sys.get_state(owner).tokens)
    assert %HTTP.RequestCompletion{} = completion = hold.completion
    monitor = Process.monitor(probe)
    send(peer, :await_close)
    Probe.cancel(probe)
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^probe, :normal}, @timeout
    assert {:ok, %{request_tokens: 0, helpers: 0}} = Transports.status(owner)
    assert UpstreamGroups.status(group).probes == 0
    stop(fixture, peer)
  end

  test "retirement before the next authentic claim rejects it with no transport token or second HEAD" do
    {source, peer} = peer(:tcp, %{})
    fixture = fixture(source)
    {group, preparation} = prepare(fixture, source, %{interval: 1_000})
    pins = baseline(fixture, group, preparation, false)
    assert_receive {:head, ^peer, _, _}, @timeout
    {_, first, completion} = bound_probe(fixture)
    monitor = Process.monitor(first)
    send(peer, {:status, 200})
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^first, :normal}, @timeout
    assert [%{health: :healthy}] = UpstreamGroups.status(group).members

    {supervisor, barrier, debug} = probe_start_barrier(fixture.groups)
    assert_receive {:probe_start_held, ^supervisor}, @timeout
    group_pin = Enum.find(pins, &(&1.provider == UpstreamGroups))
    test_owner = self()
    owner = fixture.groups

    # The actual pin holder sends the public release. The status call is queued
    # next, before the supervisor can create a new Probe and its claim call.
    helper =
      spawn(fn ->
        receive do
          {:trace, ^test_owner, :send, {:"$gen_call", _, {:release, _}}, ^owner} -> :ok
        after
          @timeout -> flunk("authentic retirement release was not queued")
        end

        status_caller =
          spawn(fn ->
            receive do
              :status ->
                send(test_owner, {:retiring_status, self(), UpstreamGroups.status(group)})
            end
          end)

        status_monitor = Process.monitor(status_caller)
        :erlang.trace(status_caller, true, [:send, {:tracer, self()}])
        send(status_caller, :status)

        receive do
          {:trace, ^status_caller, :send, {:"$gen_call", _, {:status, ^group}}, ^owner} -> :ok
        after
          @timeout -> flunk("public retirement status was not queued")
        end

        send(supervisor, {:continue_probe_start, barrier})
        assert_receive {:DOWN, ^status_monitor, :process, ^status_caller, :normal}, @timeout
        send(test_owner, {:retirement_helper_joined, self()})
      end)

    helper_monitor = Process.monitor(helper)
    :erlang.trace(owner, true, [:send])
    on_exit(fn -> if Process.alive?(owner), do: :erlang.trace(owner, false, [:send]) end)
    :erlang.trace(self(), true, [:send, {:tracer, helper}])
    assert :ok = Resources.release(group_pin)
    :erlang.trace(self(), false, [:send])
    assert_receive {:retiring_status, _, %{lifecycle: :retiring, probes: 1}}, @timeout
    assert_receive {:probe_spawned, ^supervisor, next}, @timeout
    assert_receive {:trace, ^owner, :send, {_, {:error, :stale_probe}}, _}, @timeout
    :erlang.trace(owner, false, [:send])
    next_monitor = Process.monitor(next)

    assert_receive {:DOWN, ^next_monitor, :process, ^next, reason}
                   when reason in [:normal, :noproc],
                   @timeout

    assert_receive {:retirement_helper_joined, ^helper}, @timeout
    assert_receive {:DOWN, ^helper_monitor, :process, ^helper, :normal}, @timeout
    :ok = :sys.remove(supervisor, debug)
    assert {:error, :stale_group} = UpstreamGroups.status(group)
    assert {:ok, %{request_tokens: 0}} = Transports.status(fixture.transports)
    refute_receive {:head, ^peer, _, _}, 0
    stop(fixture, peer)
  end

  for action <- [:group_owner_death, :guardian_death] do
    @action action
    test "#{action} joins the real HEAD and independent public completion recovery" do
      {source, peer} = peer(:tcp, %{})
      fixture = fixture(source)
      {group, preparation} = prepare(fixture, source)
      baseline(fixture, group, preparation)
      assert_receive {:head, ^peer, _, _}, @timeout
      {_, probe, completion} = bound_probe(fixture)
      monitor = Process.monitor(probe)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      send(peer, :await_close)

      case @action do
        :group_owner_death ->
          owner = fixture.groups
          owner_monitor = Process.monitor(owner)
          Process.exit(owner, :kill)
          assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, @timeout

        :guardian_death ->
          Process.exit(probe, :kill)
      end

      assert_receive {:DOWN, ^monitor, :process, ^probe, reason}, @timeout
      assert reason == if(@action == :guardian_death, do: :killed, else: :owner_unavailable)
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)

      eventually(fn ->
        match?({:ok, %{request_tokens: 0, helpers: 0}}, Transports.status(fixture.transports))
      end)

      if @action == :guardian_death do
        eventually(fn -> UpstreamGroups.status(group).probes == 0 end)
        assert UpstreamGroups.status(group).probe_bytes == 0
        assert [%{failures: 1, successes: 0}] = stored_members(fixture, group)
        assert_no_probe_children(fixture.groups)
      end

      stop(fixture, peer)
    end
  end

  for reason <- [:wrong_ca, :wrong_hostname] do
    @reason reason
    test "TLS #{@reason} retains strict original completion and retirement uncertainty without fallback or replay",
         context do
      hostname = if @reason == :wrong_hostname, do: "127.0.0.2", else: "localhost"
      {source, peer} = peer(:tls, context, hostname: hostname)
      source = if @reason == :wrong_ca, do: %{source | trust: ca(context.untrusted)}, else: source
      fixture = fixture(source)
      expect_uncertainty(fixture)
      barrier = transport_barrier(fixture.transports, :bind_completion, 0)
      {group, preparation} = prepare(fixture, source)
      owner = fixture.transports
      handle = fixture.transport

      assert_receive {:transport_call_held, ^owner, probe,
                      {:bind_completion, ^handle, token, completion}},
                     @timeout

      assert %HTTP.RequestCompletion{} = completion
      monitor = Process.monitor(probe)
      send(owner, {:continue_transport_call, barrier})
      baseline(fixture, group, preparation, false)
      assert_receive {:handshake_failed, ^peer, _}, @timeout

      assert_receive {:DOWN, ^monitor, :process, ^probe, {:cleanup_failed, :cleanup_unconfirmed}},
                     @timeout

      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
      scope = :sys.get_state(owner).records[handle.resource].scope
      assert {:error, :transport_scope_retired} = HTTP.ManagedTransport.snapshot(scope, @timeout)
      assert {:ok, scope_receipt} = HTTP.ManagedTransport.retire(scope, mode: :abort)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, @timeout)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, 0)

      eventually(fn ->
        hold = :sys.get_state(owner).tokens[token]
        hold.completion == completion and hold.guardian_down and hold.abort_helper == nil
      end)

      assert {:ok, %{resources: 1, request_tokens: 1, reserved_connections: 2, helpers: 0}} =
               Transports.status(owner)

      eventually(fn -> UpstreamGroups.status(group).lifecycle == :failed end)
      assert UpstreamGroups.status(group).probes == 1
      assert UpstreamGroups.status(group).probe_bytes > 0
      [{_, group_hold}] = Map.to_list(:sys.get_state(fixture.groups).probes)
      assert group_hold.completion == completion
      assert_joined(group_hold.recovery, [:cleanup_unconfirmed, :noproc])
      assert_receive {:peer_done, ^peer}, @timeout
      assert_joined(peer, [:normal, :noproc])
      refute_receive {:head, ^peer, _, _}, 0
      registration = :sys.get_state(owner).registration

      assert {:error, {:shutdown, [], [{^registration, {:error, :cleanup_unconfirmed}}]}} =
               Gaoxy.stop(fixture.instance, @timeout)

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

      assert {:ok, receipt} = Transports.retire(owner, deadline())
      assert {:error, :cleanup_unconfirmed} = Transports.await_retirement(receipt, deadline())
      assert {:error, :cleanup_unconfirmed} = Transports.await_retirement(receipt, deadline())
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)

      assert {:error, :cleanup_unconfirmed} =
               HTTP.ManagedTransport.await_retired(scope_receipt, 0)

      # The failed scope creator remains charged and alive until test teardown;
      # peer/guardian/recovery joins do not turn its failed retirement into :ok.
      assert Process.alive?(fixture.custodian)
      assert_no_probe_children(fixture.groups)
    end
  end

  test "TLS probes reuse one socket and retain prepared DER after its source CA file is replaced",
       context do
    ca_file = Path.join(context.trusted, "ca.pem")
    original = File.read!(ca_file)
    on_exit(fn -> File.write!(ca_file, original) end)
    {source, peer} = peer(:tls, context)
    fixture = fixture(source)
    File.write!(ca_file, File.read!(Path.join(context.untrusted, "ca.pem")))
    {group, preparation} = prepare(fixture, source, %{interval: 150})
    baseline(fixture, group, preparation)

    completions =
      for index <- 1..2 do
        assert_receive {:head, ^peer, head, nil}, @timeout
        assert head =~ "HEAD /health?ready=1 HTTP/1.1\r\n"
        {_, probe, completion} = bound_probe(fixture)
        monitor = Process.monitor(probe)
        send(peer, {:status, 200})
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        assert_receive {:DOWN, ^monitor, :process, ^probe, :normal}, @timeout

        assert [%{successes: ^index, failures: 0, health: :healthy}] =
                 stored_members(fixture, group)

        completion
      end

    [first, second] = completions
    assert first != second
    stop(fixture, peer)
  end

  test "real HEAD failures and successes preserve failure and recovery thresholds" do
    {source, peer} = peer(:tcp, %{})
    fixture = fixture(source)
    {group, preparation} = prepare(fixture, source, %{interval: 150})
    baseline(fixture, group, preparation)

    for {status, health, failures, successes} <- [
          {200, :healthy, 0, 1},
          {503, :healthy, 1, 0},
          {503, :healthy, 2, 0},
          {503, :unhealthy, 3, 0},
          {200, :unhealthy, 0, 1},
          {200, :healthy, 0, 2}
        ] do
      assert_receive {:head, ^peer, _, _}, @timeout
      {_, probe, completion} = bound_probe(fixture)
      monitor = Process.monitor(probe)
      send(peer, {:status, status})
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^probe, :normal}, @timeout

      assert [%{health: ^health, failures: ^failures, successes: ^successes}] =
               stored_members(fixture, group)
    end

    stop(fixture, peer)
  end

  test "real HEAD opening timeout is a health failure and the next bounded probe recovers" do
    {source, peer} = peer(:tcp, %{}, reconnect: true)
    fixture = fixture(source)
    {group, preparation} = prepare(fixture, source, %{timeout: 500, interval: 150})
    baseline(fixture, group, preparation)
    assert_receive {:head, ^peer, _, _}, @timeout
    {_, probe, completion} = bound_probe(fixture)
    monitor = Process.monitor(probe)
    send(peer, :await_close)
    assert_receive {:peer_closed, ^peer}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^probe, :normal}, @timeout
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
    assert [%{failures: 1, successes: 0, checked: checked}] = stored_members(fixture, group)
    assert is_integer(checked)
    assert_receive {:head, ^peer, _, _}, @timeout
    {_, recovered, next_completion} = bound_probe(fixture)
    recovered_monitor = Process.monitor(recovered)
    send(peer, {:status, 200})
    assert :ok = HTTP.RequestCompletion.await(next_completion, @timeout)
    assert_receive {:DOWN, ^recovered_monitor, :process, ^recovered, :normal}, @timeout
    assert [%{failures: 0, successes: 1, health: :healthy}] = stored_members(fixture, group)
    stop(fixture, peer)
  end

  test "a failed short stop stays failed while releasing a held original bind permits cleanup and joins" do
    {source, peer} = peer(:tcp, %{})
    fixture = fixture(source)
    barrier = transport_barrier(fixture.transports, :bind_completion, 0)
    {group, preparation} = prepare(fixture, source)
    owner = fixture.transports
    handle = fixture.transport

    assert_receive {:transport_call_held, ^owner, probe,
                    {:bind_completion, ^handle, _, completion}},
                   @timeout

    assert_receive {:head, ^peer, _, _}, @timeout
    monitor = Process.monitor(probe)

    workers =
      for actor <- [fixture.instance, owner, fixture.custodian],
          do: {actor, Process.monitor(actor)}

    send(peer, :await_close)
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    assert UpstreamGroups.status(group).probes == 1
    short_result = Gaoxy.stop(fixture.instance, 0)
    assert short_result == {:error, {:deadline_exceeded, :cleanup_pending}}
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    assert UpstreamGroups.status(group).probes == 1
    send(owner, {:continue_transport_call, barrier})
    assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

    assert_receive {:DOWN, ^monitor, :process, ^probe, reason}
                   when reason in [:normal, :owner_unavailable],
                   @timeout

    assert_receive {:peer_done, ^peer}, @timeout
    assert_joined(peer, [:normal, :noproc])

    for {actor, actor_monitor} <- workers do
      assert_receive {:DOWN, ^actor_monitor, :process, ^actor, :normal}, @timeout
    end

    assert UpstreamGroups.status(group).probes == 0
    assert UpstreamGroups.status(group).probe_bytes == 0
    assert_no_probe_children(fixture.groups)
    group_pins = Enum.filter(preparation, &(&1.provider == UpstreamGroups))
    assert :ok = Resources.release(group_pins)
    assert {:error, :stale_group} = UpstreamGroups.status(group)
    groups = fixture.groups
    groups_monitor = Process.monitor(groups)
    GenServer.stop(groups, :normal, @timeout)
    assert_receive {:DOWN, ^groups_monitor, :process, ^groups, :normal}, @timeout
    assert short_result == {:error, {:deadline_exceeded, :cleanup_pending}}
  end

  defp fixture(source, max_pins \\ 32) do
    test_owner = self()

    embedding =
      spawn(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)

        {:ok, transports} =
          Transports.start_link(
            instance: instance,
            limits: %{
              max_resources: 2,
              max_pins: max_pins,
              max_request_tokens: 8,
              max_owned_payload_bytes: 2_097_152
            }
          )

        Process.unlink(transports)
        {:ok, groups} = UpstreamGroups.start_link(instance: instance)
        Process.unlink(groups)
        send(test_owner, {:fixture_ready, self(), instance, transports, groups})
        embedding_loop(instance, transports, groups, [])
      end)

    assert_receive {:fixture_ready, ^embedding, instance, transports, groups}, @timeout

    on_exit(fn ->
      monitor = Process.monitor(embedding)
      send(embedding, {:cleanup, self()})
      assert_receive {:fixture_cleanup, ^embedding, result}, 3 * @timeout
      assert result == :ok, inspect(result)
      assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
    end)

    assert {:ok, transport, preparation} =
             Transports.prepare(transports, source, self(), deadline())

    custodian = :sys.get_state(transports).records[transport.resource].custodian
    send(embedding, {:track, custodian, self()})
    assert_receive {:tracked, ^embedding, ^custodian}, @timeout

    %{
      instance: instance,
      transports: transports,
      groups: groups,
      transport: transport,
      preparation: preparation,
      custodian: custodian,
      embedding: embedding
    }
  end

  defp embedding_loop(instance, transports, groups, actors, mode \\ :ok) do
    receive do
      {:track, actor, caller} ->
        send(caller, {:tracked, self(), actor})

        embedding_loop(
          instance,
          transports,
          groups,
          [{actor, Process.monitor(actor)} | actors],
          mode
        )

      {:expect_uncertainty, caller} ->
        send(caller, {:uncertainty_expected, self()})
        embedding_loop(instance, transports, groups, actors, :tls_unconfirmed)

      {:cleanup, caller} ->
        result =
          try do
            if mode == :ok and Process.alive?(instance),
              do: assert(:ok == Gaoxy.stop(instance, @timeout))

            if mode == :ok and Process.alive?(transports) do
              assert {:ok, receipt} = Transports.retire(transports, deadline())
              assert :ok = Transports.await_retirement(receipt, deadline())

              assert {:ok,
                      %{
                        resources: 0,
                        pins: 0,
                        request_tokens: 0,
                        helpers: 0,
                        reserved_connections: 0
                      }} = Transports.status(transports)

              GenServer.stop(transports, :normal, @timeout)
            end

            if mode == :tls_unconfirmed do
              assert Process.alive?(transports)
              assert {:ok, receipt} = Transports.retire(transports, deadline())

              assert {:error, :cleanup_unconfirmed} =
                       Transports.await_retirement(receipt, deadline())

              assert {:error, :cleanup_unconfirmed} =
                       Transports.await_retirement(receipt, deadline())

              assert {:ok,
                      %{
                        resources: 1,
                        pins: 0,
                        request_tokens: 1,
                        failed_resources: 1,
                        reserved_connections: 2,
                        helpers: 0
                      }} = Transports.status(transports)

              # Dismantle only test-owned failed actors after the immutable
              # public failure and retained ledger have been asserted above.
              for {actor, _} <- actors do
                assert Process.alive?(actor)
                GenServer.stop(actor, :normal, @timeout)
              end

              GenServer.stop(transports, :normal, @timeout)

              if Process.alive?(instance) do
                monitor = Process.monitor(instance)
                Process.exit(instance, :kill)
                assert_receive {:DOWN, ^monitor, :process, ^instance, :killed}, @timeout
              end
            end

            if Process.alive?(groups), do: GenServer.stop(groups, :normal, @timeout)

            for {actor, monitor} <- actors do
              assert_receive {:DOWN, ^monitor, :process, ^actor, reason}
                             when reason in [:normal, :noproc],
                             @timeout
            end

            :ok
          rescue
            error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
          end

        send(caller, {:fixture_cleanup, self(), result})
    after
      30_000 -> raise "test-owned fixture cleanup was not requested"
    end
  end

  defp prepare(fixture, source, policy \\ %{}) do
    assert {:ok, compiled} =
             UpstreamGroups.compile(%{
               id: "managed-health",
               members: [%{id: "one", upstream: source.origin, transport: fixture.transport}],
               health:
                 Map.merge(
                   %{
                     path: "/health?ready=1",
                     interval: 60_000,
                     timeout: 2_500,
                     stale_after: 120_000,
                     jitter: 0
                   },
                   policy
                 )
             })

    assert {:ok, group, preparation} =
             UpstreamGroups.prepare(fixture.groups, compiled, self(), deadline())

    {group, preparation}
  end

  defp baseline(fixture, group, preparation, install_service \\ true) do
    assert :ok = Resources.release(fixture.preparation)
    resources = apply(UpstreamGroups, :resources, [group])
    assert {:ok, pins} = Resources.pin_many(resources, self(), :baseline, deadline())
    assert :ok = Resources.release(preparation)

    if install_service do
      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 id: :health,
                 endpoint: {GroupEndpoint, %{group: group}},
                 limits: %{max_bytes: 16_777_216}
               )

      assert {:ok, _} = Gaoxy.add(fixture.instance, spec)
    end

    pins
  end

  defp expect_uncertainty(fixture) do
    send(fixture.embedding, {:expect_uncertainty, self()})
    embedding = fixture.embedding
    assert_receive {:uncertainty_expected, ^embedding}, @timeout
  end

  defp bound_probe(fixture) do
    eventually(fn ->
      case {Map.to_list(:sys.get_state(fixture.groups).probes),
            Map.to_list(:sys.get_state(fixture.transports).tokens)} do
        {[{_, %{pid: pid, completion: %HTTP.RequestCompletion{} = completion}}],
         [{_, %{guardian: pid, completion: completion}}]} ->
          true

        _ ->
          false
      end
    end)

    [{token, %{pid: pid, completion: completion}}] =
      Map.to_list(:sys.get_state(fixture.groups).probes)

    {token, pid, completion}
  end

  defp assert_no_probe_children(owner) do
    eventually(fn ->
      Enum.all?(DynamicSupervisor.which_children(Gaoxy.Proxy.ProbeSupervisor), fn
        {_, pid, _, [Probe]} ->
          try do
            :sys.get_state(pid).owner != owner
          catch
            :exit, _ -> true
          end

        _ ->
          true
      end)
    end)
  end

  defp assert_joined(actor, reasons) do
    assert is_pid(actor)
    monitor = Process.monitor(actor)
    assert_receive {:DOWN, ^monitor, :process, ^actor, reason}, @timeout
    assert reason in reasons
  end

  defp probe_start_barrier(owner) do
    supervisor = Process.whereis(Gaoxy.Proxy.ProbeSupervisor)
    test_owner = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in, {:"$gen_call", _, {:start_child, spec}}} when not held ->
          if probe_arguments?(spec, owner) do
            monitor = Process.monitor(test_owner)

            try do
              send(test_owner, {:probe_start_held, self()})

              receive do
                {:continue_probe_start, ^barrier} -> :ok
                {:DOWN, ^monitor, :process, ^test_owner, _} -> :ok
              after
                @timeout -> flunk("test-owned Probe startup barrier expired")
              end
            after
              Process.demonitor(monitor, [:flush])
            end

            true
          else
            false
          end

        {:out, {:ok, pid}, _, _} when held ->
          send(test_owner, {:probe_spawned, self(), pid})
          held

        _ ->
          held
      end
    end

    :ok = :sys.install(supervisor, {debug, false})

    on_exit(fn ->
      if Process.alive?(supervisor), do: :sys.remove(supervisor, debug)
    end)

    {supervisor, barrier, debug}
  end

  defp probe_arguments?(%{owner: owner, member: _}, owner), do: true

  defp probe_arguments?(term, owner) when is_tuple(term),
    do: term |> Tuple.to_list() |> Enum.any?(&probe_arguments?(&1, owner))

  defp probe_arguments?(term, owner) when is_list(term),
    do: Enum.any?(term, &probe_arguments?(&1, owner))

  defp probe_arguments?(_, _), do: false

  defp stored_members(fixture, group),
    do: :sys.get_state(fixture.groups).groups[{group.group, group.generation}].members

  defp stop(fixture, peer) do
    send(peer, :finish)
    assert :ok = Gaoxy.stop(fixture.instance, @timeout)
    assert_receive {:peer_done, ^peer}, @timeout
    monitor = Process.monitor(peer)

    assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                   @timeout
  end

  defp transport_barrier(owner, operation, skip) do
    test_owner = self()
    barrier = make_ref()

    debug = fn count, event, _ ->
      case event do
        {:in, {:"$gen_call", {caller, _}, message}} when elem(message, 0) == operation ->
          if count == skip do
            send(test_owner, {:transport_call_held, self(), caller, message})

            receive do
              {:continue_transport_call, ^barrier} -> :ok
            after
              @timeout -> raise "test-owned transport call barrier expired"
            end
          end

          count + 1

        _ ->
          count
      end
    end

    :ok = :sys.install(owner, {debug, 0})
    on_exit(fn -> send(owner, {:continue_transport_call, barrier}) end)
    barrier
  end

  defp peer(protocol, context, peer_options \\ []) do
    wire = if protocol == :tls, do: :ssl, else: :gen_tcp
    options = [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true]

    options =
      if protocol == :tls,
        do:
          options ++
            [
              certfile: Path.join(context.trusted, "cert.pem"),
              keyfile: Path.join(context.trusted, "key.pem")
            ],
        else: options

    assert {:ok, listener} = wire.listen(0, options)

    assert {:ok, {_, port}} =
             if(protocol == :tls, do: :ssl.sockname(listener), else: :inet.sockname(listener))

    test_owner = self()

    peer =
      spawn(fn ->
        try do
          peer_loop(wire, listener, test_owner, peer_options)
        rescue
          error ->
            send(
              test_owner,
              {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)}
            )
        after
          wire.close(listener)
        end
      end)

    on_exit(fn ->
      monitor = Process.monitor(peer)
      wire.close(listener)

      assert_receive {:DOWN, ^monitor, :process, ^peer, reason} when reason in [:normal, :noproc],
                     2 * @timeout
    end)

    trust = if protocol == :tls, do: ca(context.trusted), else: nil
    hostname = Keyword.get(peer_options, :hostname, "localhost")

    source = %{
      origin:
        "#{if protocol == :tls, do: "https://#{hostname}", else: "http://127.0.0.1"}:#{port}",
      connect_address: {127, 0, 0, 1},
      trust: trust
    }

    {source, peer}
  end

  defp ca(directory),
    do:
      for(
        {:Certificate, der, :not_encrypted} <-
          :public_key.pem_decode(File.read!(Path.join(directory, "ca.pem"))),
        do: der
      )

  defp peer_loop(wire, listener, test_owner, options) do
    accepted =
      if wire == :ssl,
        do: :ssl.transport_accept(listener, 20),
        else: :gen_tcp.accept(listener, 20)

    case accepted do
      {:ok, transport} ->
        result = if wire == :ssl, do: :ssl.handshake(transport, @timeout), else: {:ok, transport}

        case result do
          {:ok, socket} ->
            if wire == :ssl do
              assert {:ok, information} = :ssl.connection_information(socket, [:sni_hostname])

              assert to_string(information[:sni_hostname]) ==
                       Keyword.get(options, :hostname, "localhost")

              assert {:error, :protocol_not_negotiated} = :ssl.negotiated_protocol(socket)
            end

            serve_heads(wire, socket, test_owner, head(wire, socket))
            :ok = wire.close(socket)

            if Keyword.get(options, :reconnect, false) do
              send(test_owner, {:peer_closed, self()})
              peer_loop(wire, listener, test_owner, options)
            else
              assert_no_replay(wire, listener)
              send(test_owner, {:peer_done, self()})
            end

          {:error, reason} ->
            :ok = wire.close(transport)
            send(test_owner, {:handshake_failed, self(), reason})
            assert_no_replay(wire, listener)
            send(test_owner, {:peer_done, self()})
        end

      {:error, :timeout} ->
        receive do
          {:assert_no_connection, caller} ->
            reply =
              if wire == :ssl,
                do: :ssl.transport_accept(listener, 0),
                else: :gen_tcp.accept(listener, 0)

            send(caller, {:no_connection, self(), reply})
            peer_loop(wire, listener, test_owner, options)

          :finish ->
            send(test_owner, {:peer_done, self()})
        after
          0 -> peer_loop(wire, listener, test_owner, options)
        end

      {:error, :closed} ->
        :ok
    end
  end

  defp serve_heads(wire, socket, test_owner, bytes) do
    send(test_owner, {:head, self(), bytes, nil})

    receive do
      {:status, status} ->
        :ok = wire.send(socket, "HTTP/1.1 #{status} Response\r\nContent-Length: 0\r\n\r\n")

        case wire.recv(socket, 0, @timeout) do
          {:ok, next} ->
            serve_heads(wire, socket, test_owner, head(wire, socket, next))

          {:error, :closed} ->
            :ok

          error ->
            flunk("managed peer did not observe next HEAD or physical EOF: #{inspect(error)}")
        end

      :await_close ->
        assert {:error, :closed} = wire.recv(socket, 0, @timeout)
    after
      @timeout -> flunk("test-owned HEAD response barrier expired")
    end
  end

  defp assert_no_replay(wire, listener) do
    next =
      if wire == :ssl,
        do: :ssl.transport_accept(listener, 100),
        else: :gen_tcp.accept(listener, 100)

    assert next == {:error, :timeout}, "unexpected replay/fallback connection: #{inspect(next)}"
  end

  defp assert_no_connection(peer) do
    send(peer, {:assert_no_connection, self()})
    assert_receive {:no_connection, ^peer, {:error, :timeout}}, @timeout
  end

  defp head(wire, socket, bytes \\ "") do
    if String.contains?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (
          assert {:ok, more} = wire.recv(socket, 0, @timeout)
          head(wire, socket, bytes <> more)
        )
  end

  defp eventually(fun, finish \\ nil) do
    finish = finish || deadline()

    if fun.(),
      do: :ok,
      else:
        (
          assert Lifecycle.remaining(finish) > 0

          receive do
          after
            2 -> eventually(fun, finish)
          end
        )
  end

  defp deadline, do: Lifecycle.deadline(@timeout)
end
