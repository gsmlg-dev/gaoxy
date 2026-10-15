Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupFailureTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.{ManagedH2GroupBoundary, UpstreamGroups, UpstreamTransports}
  @moduletag :capture_log
  @timeout 5_000
  @reserve 16_478_862

  setup do
    assert :ok === boundary(:activation)
    :ok
  end

  for protocol <- [:http2, :h2c] do
    @protocol protocol
    test "group #{protocol} actual guardian death retains original ledgers until recovery but missing Service receipt fails shutdown" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {socket, _, guardian, completion} = G.hold(f)
      state = :sys.get_state(guardian)
      service_token = state.token
      {_, group_token} = state.selection
      {_, transport_token} = state.transport_selection
      assert G.assert_cleanup(f, 1) === @reserve
      group_before = :sys.get_state(f.groups)
      transport_before = :sys.get_state(f.owner)
      gate_before = :sys.get_state(f.gate)
      assert group_before.tokens[group_token].completion === completion
      assert transport_before.tokens[transport_token].completion === completion
      assert gate_before.cleanups[service_token].bytes === @reserve
      pump = state.owner
      lease = gate_before.cleanups[service_token].lease

      [{source_ref, source_hold}] =
        Enum.filter(transport_before.pins, fn {_, held} ->
          held.public.kind === :request and held.public.holder === pump
        end)

      assert source_hold.public.handles === [f.handle]
      G.assert_exact_controls(group_before)
      service_barrier = service_down_barrier(f.service, guardian)
      group_barrier = down_barrier(f.groups, group_before.tokens[group_token].monitor, guardian)

      transport_barrier =
        down_barrier(f.owner, transport_before.tokens[transport_token].guardian_monitor, guardian)

      gate_barrier = down_barrier(f.gate, gate_before.cleanups[service_token].monitor, guardian)
      monitor = Process.monitor(guardian)
      Process.exit(guardian, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :killed}, @timeout
      assert_held_down(f.service, guardian, :killed, :service)
      assert_held_down(f.groups, guardian, :killed, :owner)
      assert_held_down(f.owner, guardian, :killed, :owner)
      assert_held_down(f.gate, guardian, :killed, :owner)
      # All actual DOWN handlers are held before their first mutation. These
      # exact original records still own their captured charge and capability.
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      refute_receive {:group_failure_service_receipt, _, ^guardian}, 0
      send(f.groups, {:group_failure_continue, group_barrier})
      send(f.owner, {:group_failure_continue, transport_barrier})
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

      # Recovery joins the original request, but the live pump still owns its
      # source pin while this test deliberately holds the admission gate.
      G.eventually(fn ->
        :sys.get_state(f.groups).tokens === %{} and
          match?(
            {:ok, %{request_tokens: 0, helpers: 0, pins: 2}},
            UpstreamTransports.status(f.owner)
          )
      end)

      assert :sys.get_state(f.groups).pins === group_before.pins
      recovered = :sys.get_state(f.owner)
      assert recovered.pins[source_ref].public === source_hold.public
      assert Map.get(recovered.pins[source_ref], :derived, false) === false
      assert Process.alive?(pump)

      G.eventually(fn ->
        {:messages, messages} = Process.info(f.gate, :messages)

        Enum.any?(messages, fn
          {:"$gen_call", {^pump, _}, {:update, ^lease, bytes}} when is_integer(bytes) -> true
          _ -> false
        end)
      end)

      refute_receive {:group_failure_service_receipt, _, ^guardian}, 0
      send(f.gate, {:group_failure_continue, gate_barrier})

      G.eventually(fn ->
        :sys.get_state(f.groups).tokens === %{} and
          match?(
            {:ok, %{request_tokens: 0, helpers: 0, pins: 1}},
            UpstreamTransports.status(f.owner)
          )
      end)

      G.assert_exact_controls(:sys.get_state(f.groups))
      refute_receive {:group_failure_service_receipt, _, ^guardian}, 0
      :ok = :gen_tcp.close(socket)
      stop = external_stop(f)
      await_drain_queued(f.service)
      send(f.service, {:group_failure_continue, service_barrier})
      assert_failed_shutdown(f, stop, :cleanup_receipt_missing)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      finish_external_embedding(f)
      join_confirmed_owners(f)
      close_peer(f)
    end

    test "group #{protocol} real gate loss joins the original but public shutdown records backend failure" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {socket, _, guardian, completion} = G.hold(f)
      assert G.assert_cleanup(f, 1) === @reserve
      barrier = service_exit_barrier(f.service, f.gate)
      gate = f.gate
      gate_monitor = Process.monitor(gate)
      guardian_monitor = Process.monitor(guardian)
      Process.exit(gate, :kill)
      assert_receive {:DOWN, ^gate_monitor, :process, ^gate, :killed}, @timeout
      service = f.service
      assert_receive {:group_failure_service_exit_held, ^service, ^gate, :killed}, @timeout
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

      G.eventually(fn ->
        :sys.get_state(f.groups).tokens === %{} and
          match?({:ok, %{request_tokens: 0, helpers: 0}}, UpstreamTransports.status(f.owner))
      end)

      # The lost gate has no readable retained-byte report. It is never a zero.
      refute Process.alive?(gate)
      assert Process.alive?(guardian)
      stop = external_stop(f)
      await_drain_queued(service)
      send(service, {:group_failure_continue, barrier})
      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, @timeout
      assert_failed_shutdown(f, stop, {:backend_failed, :killed})
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      :ok = :gen_tcp.close(socket)
      finish_external_embedding(f)
      join_confirmed_owners(f)
      close_peer(f)
    end

    test "group #{protocol} lost original Service has no cleanup receipt while its separate replacement forwards healthy work" do
      f = G.fixture(@protocol, :http1, ["--manual"])
      {socket, seen, guardian, completion} = G.hold(f)
      assert G.assert_cleanup(f, 1) === @reserve
      service = f.service
      old_gate = f.gate
      service_monitor = Process.monitor(service)
      gate_monitor = Process.monitor(old_gate)
      guardian_monitor = Process.monitor(guardian)
      Process.exit(service, :kill)
      assert_receive {:DOWN, ^service_monitor, :process, ^service, :killed}, @timeout
      assert_receive {:DOWN, ^gate_monitor, :process, ^old_gate, :killed}, @timeout
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)

      assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian,
                      {:cleanup_failed, {:service_cleanup_failed, :unavailable}}},
                     @timeout

      refute Process.alive?(service)
      refute Process.alive?(old_gate)

      G.eventually(fn ->
        match?(
          {:ok, replacement, _} when replacement != service,
          GenServer.call(f.instance, {:lookup, :http})
        ) and
          :sys.get_state(f.groups).tokens === %{} and
          match?({:ok, %{request_tokens: 0, helpers: 0}}, UpstreamTransports.status(f.owner))
      end)

      {:ok, replacement, _} = GenServer.call(f.instance, {:lookup, :http})
      replacement_gate = :sys.get_state(replacement).gate
      refute replacement_gate === old_gate

      IO.puts(
        JSON.encode!(%{
          event: "managed_h2_group_service_loss",
          original_service: inspect(service),
          original_gate: inspect(old_gate),
          original_service_cleanup: "UNCONFIRMED_RECEIPT_UNAVAILABLE",
          original_completion: "confirmed",
          replacement_service: inspect(replacement),
          replacement_gate: inspect(replacement_gate)
        })
      )

      :ok = :gen_tcp.close(socket)
      replacement_fixture = %{f | service: replacement, gate: replacement_gate}
      G.clean(replacement_fixture)

      {later_socket, later, _, later_completion} =
        G.hold(replacement_fixture, "/hold/replacement")

      refute {later["connection"], later["stream"]} === {seen["connection"], seen["stream"]}
      G.command(f.peer, later, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = G.response(replacement_fixture, later_socket)
      :ok = :gen_tcp.close(later_socket)
      assert :ok = HTTP.RequestCompletion.await(later_completion, @timeout)
      G.clean(replacement_fixture)
      G.no_event(f.peer, "request")
      G.close(replacement_fixture)
    end

    for count <- [256, 257] do
      @field_count count
      @tag timeout: 90_000
      test "group #{protocol} real HPACK regular field#{count} failure keeps G T holds and unconfirmed original through failed retirement" do
        f = G.fixture(@protocol, :http1, ["--manual"])
        {socket, seen, guardian, completion} = G.hold(f)
        state = :sys.get_state(guardian)
        {_, group_token} = state.selection
        {_, transport_token} = state.transport_selection
        service_token = state.token
        assert G.assert_cleanup(f, 1) === @reserve
        service_barrier = service_down_barrier(f.service, guardian)
        gate_state = :sys.get_state(f.gate)
        gate_barrier = down_barrier(f.gate, gate_state.cleanups[service_token].monitor, guardian)
        on_exit(fn -> dispose_failed_actors(f, completion) end)
        original = state.original_request
        result_ref = original.promise.task.ref
        assert :erlang.trace(guardian, true, [:receive]) === 1
        monitor = Process.monitor(guardian)
        fields = for index <- 1..@field_count, do: ["x-check", Integer.to_string(index)]
        G.command(f.peer, seen, "respond", %{"fields" => fields})

        assert_receive {:trace, ^guardian, :receive,
                        {^result_ref,
                         {:error, {:transport_error, {:hpack, :hpack_field_count_exceeded}}}}},
                       @timeout

        assert %{status: 502, body: ""} = G.response(f, socket)

        assert_receive {:DOWN, ^monitor, :process, ^guardian,
                        {:cleanup_failed, :cleanup_unconfirmed}},
                       @timeout

        assert_held_down(f.service, guardian, {:cleanup_failed, :cleanup_unconfirmed}, :service)
        assert_held_down(f.gate, guardian, {:cleanup_failed, :cleanup_unconfirmed}, :owner)
        assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, @timeout)

        assert {:error, :cleanup_unconfirmed} =
                 HTTP.RequestCompletion.abort_and_await(completion, 0)

        G.eventually(fn ->
          group_state = :sys.get_state(f.groups)

          match?(%{lifecycle: :failed, inflight: 1}, UpstreamGroups.status(f.group)) and
            group_state.tokens[group_token].completion === completion and
            :sys.get_state(f.owner).tokens[transport_token].completion === completion
        end)

        assert %{inflight: 1} = UpstreamGroups.status(f.group)
        assert {:ok, %{request_tokens: 1}} = UpstreamTransports.status(f.owner)
        before_stop = :sys.get_state(f.groups)
        assert before_stop.tokens[group_token].completion === completion
        assert before_stop.tokens[group_token].control_bytes > 0
        G.assert_exact_controls(before_stop)
        refute_receive {:group_failure_service_receipt, _, ^guardian}, 0
        G.no_event(f.peer, "request")
        :ok = :gen_tcp.close(socket)
        stop = external_stop(f)
        await_drain_queued(f.service)
        send(f.gate, {:group_failure_continue, gate_barrier})
        send(f.service, {:group_failure_continue, service_barrier})
        assert_pending_shutdown(f, stop)
        assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
        assert {:ok, retirement} = UpstreamTransports.retire(f.owner, G.deadline())

        assert {:error, {:deadline_exceeded, :cleanup_pending}} =
                 UpstreamTransports.await_retirement(retirement, G.deadline())

        assert {:error, {:deadline_exceeded, :cleanup_pending}} =
                 UpstreamTransports.await_retirement(retirement, G.deadline())

        after_stop = :sys.get_state(f.groups)
        assert after_stop.mode === :draining
        assert after_stop.tokens[group_token].completion === completion
        assert after_stop.tokens[group_token].control_bytes > 0
        assert after_stop.groups[G.group_key(f.group)].lifecycle === :failed
        assert after_stop.groups[G.group_key(f.group)].inflight === 1
        G.assert_exact_controls(after_stop)

        G.eventually(fn ->
          match?(
            {:ok, %{resources: 1, request_tokens: 1, helpers: 0, reserved_connections: 0}},
            UpstreamTransports.status(f.owner)
          )
        end)

        transport_after = :sys.get_state(f.owner)
        assert transport_after.tokens[transport_token].completion === completion
        assert transport_after.tokens[transport_token].guardian === guardian
        assert transport_after.tokens[transport_token].guardian_down
        [entry] = Map.values(transport_after.records)
        assert entry.transport_confirmed
        assert entry.custodian_down
        refute_receive {:group_failure_service_receipt, _, ^guardian}, 0

        IO.puts(
          JSON.encode!(%{
            event: "managed_h2_group_uncertain_cleanup",
            result: "UNCONFIRMED_WITH_RETAINED_FAILURE",
            group_inflight: 1,
            transport_tokens: 1,
            group_control_bytes: after_stop.control_bytes,
            cleanup_reservation_before_failure: @reserve,
            original_completion: "cleanup_unconfirmed",
            shutdown: "deadline_exceeded_cleanup_pending"
          })
        )

        finish_external_embedding(f)

        G.eventually(fn ->
          map_size(:sys.get_state(f.groups).pins) === 0 and
            match?({:ok, %{pins: 0, request_tokens: 1}}, UpstreamTransports.status(f.owner))
        end)

        dispose_failed_actors(f, completion)
        assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)
        close_peer(f)
      end
    end
  end

  defp assert_held_down(actor, guardian, reason, kind) do
    case kind do
      :service ->
        assert_receive {:group_failure_service_down_held, ^actor, ^guardian, ^reason}, @timeout

      :owner ->
        assert_receive {:group_failure_owner_down_held, ^actor, ^guardian, ^reason}, @timeout
    end
  end

  defp down_barrier(actor, actual_monitor, guardian) do
    barrier(actor, fn
      {:in, {:DOWN, ^actual_monitor, :process, ^guardian, reason}} ->
        {:group_failure_owner_down_held, actor, guardian, reason}

      _ ->
        nil
    end)
  end

  defp service_down_barrier(service, guardian) do
    caller = self()

    barrier(service, fn
      {:in, {:"$gen_call", {^guardian, _}, {:complete_cleanup, _}}} ->
        send(caller, {:group_failure_service_receipt, service, guardian})
        nil

      {:in, {:DOWN, _, :process, ^guardian, reason}} ->
        {:group_failure_service_down_held, service, guardian, reason}

      _ ->
        nil
    end)
  end

  defp service_exit_barrier(service, gate) do
    barrier(service, fn
      {:in, {:EXIT, ^gate, reason}} -> {:group_failure_service_exit_held, service, gate, reason}
      _ -> nil
    end)
  end

  defp barrier(actor, match_event) do
    caller = self()
    ref = make_ref()

    debug = fn held, event, _ ->
      case if(held, do: nil, else: match_event.(event)) do
        nil ->
          held

        receipt ->
          send(caller, receipt)
          monitor = Process.monitor(caller)

          try do
            receive do
              {:group_failure_continue, ^ref} -> :ok
              {:DOWN, ^monitor, :process, ^caller, _} -> :ok
            after
              @timeout -> raise "actual failed lifecycle event barrier expired"
            end
          after
            Process.demonitor(monitor, [:flush])
          end

          true
      end
    end

    :ok = :sys.install(actor, {debug, false})
    on_exit(fn -> send(actor, {:group_failure_continue, ref}) end)
    ref
  end

  defp external_stop(f) do
    caller = self()
    service_monitor = Process.monitor(f.service)
    instance_monitor = Process.monitor(f.instance)

    {worker, monitor} =
      spawn_monitor(fn ->
        send(caller, {:group_failure_public_stop, self(), Gaoxy.stop(f.instance, @timeout)})
      end)

    {worker, monitor, service_monitor, instance_monitor}
  end

  defp await_drain_queued(service) do
    G.eventually(fn ->
      {:messages, messages} = Process.info(service, :messages)
      Enum.any?(messages, &match?({:"$gen_call", _, {:drain, _, _}}, &1))
    end)
  end

  defp assert_failed_shutdown(f, {worker, monitor, service_monitor, instance_monitor}, reason) do
    assert_receive {:group_failure_public_stop, ^worker,
                    {:error, {:shutdown, [{:http, {:error, {:cleanup_failed, ^reason}}}], []}}},
                   2 * @timeout

    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
    service = f.service
    instance = f.instance
    assert_receive {:DOWN, ^service_monitor, :process, ^service, :normal}, @timeout
    assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, @timeout
  end

  defp assert_pending_shutdown(f, {worker, monitor, service_monitor, instance_monitor}) do
    assert_receive {:group_failure_public_stop, ^worker,
                    {:error, {:deadline_exceeded, :cleanup_pending}}},
                   2 * @timeout

    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
    service = f.service
    instance = f.instance
    assert_receive {:DOWN, ^service_monitor, :process, ^service, :normal}, @timeout
    assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :normal}, @timeout
  end

  defp finish_external_embedding(f) do
    refute Process.alive?(f.instance)
    embedding = f.embedding
    monitor = Process.monitor(embedding)
    send(embedding, {:finish_external_shutdown, self()})
    assert_receive {:group_h2_external_shutdown_finished, ^embedding, :ok}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
  end

  defp join_confirmed_owners(f) do
    G.eventually(fn ->
      state = :sys.get_state(f.groups)

      state.groups === %{} and state.pins === %{} and state.tokens === %{} and
        state.probes === %{} and state.bytes === 0 and state.control_bytes === 0
    end)

    groups = f.groups
    group_monitor = Process.monitor(groups)
    assert :ok = GenServer.stop(groups, :normal, @timeout)
    assert_receive {:DOWN, ^group_monitor, :process, ^groups, :normal}, @timeout

    for actor <- [f.owner, f.custodian, f.gate] do
      monitor = Process.monitor(actor)
      assert_receive {:DOWN, ^monitor, :process, ^actor, reason}, @timeout
      assert reason in [:normal, :noproc, :shutdown, :killed]
    end
  end

  defp dispose_failed_actors(f, completion) do
    recovery =
      if Process.alive?(f.groups) do
        state = :sys.get_state(f.groups)

        Enum.flat_map(Map.values(state.tokens) ++ Map.values(state.probes), fn held ->
          Enum.filter([held[:pid], held[:recovery]], &is_pid/1)
        end)
      else
        []
      end

    live = Enum.filter(Enum.uniq([f.groups, f.owner, f.custodian | recovery]), &Process.alive?/1)

    if live != [] do
      assert {:error, :cleanup_unconfirmed} = HTTP.RequestCompletion.await(completion, 0)

      IO.puts(
        JSON.encode!(%{
          event: "managed_h2_group_negative_forced_test_disposal",
          actors: length(live),
          public_cleanup: "UNCONFIRMED_WITH_RETAINED_FAILURE"
        })
      )

      for actor <- live do
        monitor = Process.monitor(actor)
        Process.exit(actor, :kill)
        assert_receive {:DOWN, ^monitor, :process, ^actor, :killed}, @timeout
      end
    end
  end

  defp close_peer(f) do
    expected = Process.get({F, :observed_requests, f.peer}, 0)
    assert expected > 0
    F.physical_termination(f.peer)
    peer = f.peer
    monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})
    assert %{"forced" => 0, "live" => 0, "failed" => false} = joined = G.event(peer, "joined")
    assert joined["requests"] === expected
    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
  end

  defp boundary(function), do: apply(ManagedH2GroupBoundary, function, [])
end
