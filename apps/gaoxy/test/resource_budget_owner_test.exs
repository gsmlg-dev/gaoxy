defmodule Gaoxy.ResourceBudget.OwnerTest do
  use ExUnit.Case, async: false
  @moduletag :component
  import ExUnit.CaptureLog
  alias Gaoxy.ResourceBudget, as: Budget
  @mib 1_048_576
  @usage600 600 * @mib
  @usage300 300 * @mib
  @usage30 30 * @mib
  @usage40 40 * @mib
  @usage100 100 * @mib
  @usage200 200 * @mib

  defp api(name, args), do: apply(Budget, name, args)
  defp deadline, do: System.monotonic_time(:millisecond) + 5000

  defp setup_budget(options \\ []) do
    identity = make_ref()
    now = Keyword.get(options, :now, fn -> System.monotonic_time(:millisecond) end)
    capacity = Keyword.get(options, :capacity, 1000 * @mib)

    probe =
      Keyword.get(options, :capacity_probe, fn ->
        %{capacity: capacity, fallback?: false, source: :controlled}
      end)

    safety =
      Keyword.get(options, :safety_probe, fn _ ->
        {:ok,
         %{
           available_bytes: 1000 * @mib,
           cgroup_headroom_bytes: nil,
           sampled_at: now.(),
           high_pressure?: false
         }}
      end)

    opts = [
      identity: identity,
      capacity_probe: probe,
      safety_probe: safety,
      now: now,
      processes: Keyword.get(options, :processes, fn -> %{count: 10, limit: 1000} end)
    ]

    sup = start_supervised!({Gaoxy.ResourceBudget.Supervisor, opts})
    server = Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Authority, identity)
    assert :ok = api(:refresh, [server])
    {sup, server}
  end

  defp scope(
         server,
         instance_policy \\ %{},
         service_policy \\ %{},
         service_id \\ :service,
         owner \\ self()
       ) do
    assert {:ok, instance} =
             api(:register_instance, [server, self(), instance_policy, deadline()])

    policy =
      Map.merge(
        %{
          max_active: nil,
          max_bytes: nil,
          max_connections: 1000,
          max_requests: 1000,
          max_streams: 1000,
          provenance: %{}
        },
        service_policy
      )

    assert {:ok, service} =
             api(:register_service, [
               server,
               instance,
               %{id: service_id, owner: self(), generation: make_ref()},
               policy,
               deadline()
             ])

    assert {:ok, client} = api(:register_gate, [server, service, owner, deadline()])
    {instance, client}
  end

  defp reserve(client, bytes, op, kind \\ :writer),
    do: api(:reserve, [client, self(), kind, bytes, op, deadline()])

  defp snapshot(server, instance), do: api(:snapshot, [server, instance])

  defp release(client, receipt, op),
    do:
      api(:release, [
        client,
        receipt.token,
        receipt.revision,
        %{owner: self(), revision: receipt.revision, terminal: :confirmed},
        op,
        deadline()
      ])

  defp accounting(bytes, memberships),
    do: %{
      retained_bytes: bytes,
      temporary_bytes: 0,
      transport_bytes: bytes,
      websocket_bytes: 0,
      memberships: memberships,
      pending_processes: 0
    }

  test "exact boundaries admit warning and reject projected hard overflow without changing state" do
    {_, server} = setup_budget()
    {instance, client} = scope(server, %{soft_limit: 100, hard_limit: 200})
    assert {:ok, a} = reserve(client, 100, 1)
    assert %{state: :normal, usage: 100} = snapshot(server, instance)
    assert {:ok, _} = reserve(client, 100, 2)
    assert %{state: :warning, usage: 200} = snapshot(server, instance)
    assert {:error, :memory_hard_limit} = reserve(client, 1, 3)

    assert %{state: :warning, usage: 200, rejections: %{memory_hard_limit: 1}} =
             snapshot(server, instance)

    assert {:ok, _} = release(client, a, 4)
    assert %{state: :normal, usage: 100} = snapshot(server, instance)
  end

  test "multiple instances share one VM pool" do
    {_, server} = setup_budget(capacity: 1000 * @mib)
    {i1, c1} = scope(server)

    other =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> Process.exit(other, :kill) end)
    assert {:ok, i2} = api(:register_instance, [server, other, %{}, deadline()])
    p = %{max_connections: 1000, max_requests: 1000, max_streams: 1000}

    assert {:ok, service} =
             api(:register_service, [
               server,
               i2,
               %{id: :two, owner: self(), generation: make_ref()},
               p,
               deadline()
             ])

    assert {:ok, c2} = api(:register_gate, [server, service, self(), deadline()])
    assert {:ok, _} = reserve(c1, 600 * @mib, 1)
    assert {:error, :memory_hard_limit} = reserve(c2, 401 * @mib, 1)
    assert %{usage: @usage600, vm: %{usage: @usage600}} = snapshot(server, i1)
    assert %{usage: 0, vm: %{usage: @usage600}} = snapshot(server, i2)
  end

  test "racing gate reservations cannot overspend shared projected usage" do
    {_, server} = setup_budget(capacity: 1000 * @mib)
    {i, c1} = scope(server, %{soft_limit: 50, hard_limit: 100})
    {^i, c2} = scope(server, %{soft_limit: 50, hard_limit: 100}, %{}, :other)
    results = for c <- [c1, c2], do: Task.async(fn -> reserve(c, 60, 1) end)
    outcomes = Enum.map(results, &Task.await/1)
    assert Enum.count(outcomes, &match?({:ok, _}, &1)) == 1
    assert Enum.count(outcomes, &(&1 == {:error, :memory_hard_limit})) == 1
    assert %{usage: 60} = snapshot(server, i)
  end

  test "explicit service max_bytes is undoubled and excludes websocket retention" do
    {_, server} = setup_budget()
    {i, c} = scope(server, %{}, %{max_bytes: 100, max_active: 2})
    ws = %{retained_bytes: 150, temporary_bytes: 0, transport_bytes: 100, websocket_bytes: 50}
    assert {:ok, _} = reserve(c, ws, 1)
    assert {:error, :byte_limit} = reserve(c, 1, 2)
    assert {:ok, _} = reserve(c, 0, 3)
    assert {:error, :active_limit} = reserve(c, 0, 4)
    assert %{usage: 150, transport_bytes: 100, websocket_bytes: 50} = snapshot(server, i)
  end

  test "overlapping request and stream identities count once and websocket ends request ownership" do
    {_, server} = setup_budget()
    {i, c} = scope(server, %{}, %{max_requests: 1, max_streams: 2})
    ids = %{request: :request1, h2_stream: :stream1}
    assert {:ok, a} = reserve(c, accounting(10, ids), 1, :h2_stream)
    assert {:ok, b} = reserve(c, accounting(5, %{request: :request1}), 2, :request)
    assert %{active_requests: 1, active_h2_streams: 1} = snapshot(server, i)

    assert {:error, :request_limit} =
             reserve(c, accounting(0, %{request: :request2}), 3, :request)

    assert {:ok, a2} =
             api(:replace, [
               c,
               a.token,
               a.revision,
               accounting(10, %{h2_stream: :stream1}),
               4,
               deadline()
             ])

    assert {:ok, _} = api(:replace, [c, b.token, b.revision, accounting(5, %{}), 5, deadline()])
    assert %{active_requests: 0, active_h2_streams: 1, usage: 15} = snapshot(server, i)
    assert {:ok, _} = release(c, a2, 6)
  end

  test "distinct connection and stream quotas reject only their memberships" do
    {_, server} = setup_budget()
    {_, c} = scope(server, %{}, %{max_connections: 1, max_streams: 1})
    assert {:ok, _} = reserve(c, accounting(0, %{connection: :one}), 1, :connection)

    assert {:error, :connection_limit} =
             reserve(c, accounting(0, %{connection: :two}), 2, :connection)

    assert {:ok, _} = reserve(c, accounting(0, %{request: :r, h3_stream: :s}), 3, :h3_stream)

    assert {:error, :stream_limit} =
             reserve(c, accounting(0, %{request: :r2, h3_stream: :s2}), 4, :h3_stream)

    assert {:ok, _} = reserve(c, 0, 5, :guardian)
  end

  test "identical retries keep committed receipt after deadline and conflicting reuse fails" do
    {_, server} = setup_budget()
    {i, c} = scope(server)
    d = deadline()
    assert {:ok, a} = api(:reserve, [c, self(), :writer, 10, 1, d])
    assert {:ok, ^a} = api(:reserve, [c, self(), :writer, 10, 1, d - 10_000])
    assert {:error, :operation_conflict} = reserve(c, 11, 1)
    assert %{usage: 10} = snapshot(server, i)
  end

  test "expired fresh mutation does not commit and rejection retry is stable" do
    {_, server} = setup_budget()
    {i, c} = scope(server, %{soft_limit: 10, hard_limit: 20})

    assert {:error, :deadline_exceeded} =
             api(:reserve, [c, self(), :writer, 10, 1, 0 - 9_000_000_000_000])

    assert {:error, :memory_hard_limit} = reserve(c, 21, 2)
    assert {:error, :memory_hard_limit} = reserve(c, 21, 2)

    assert %{usage: 0, rejections: %{memory_hard_limit: 1, deadline_exceeded: 1}} =
             snapshot(server, i)
  end

  test "receipt eviction retains watermark and closed allocations cannot reopen" do
    {_, server} = setup_budget()
    {i, c} = scope(server)
    assert {:ok, a} = reserve(c, 1, 1)
    assert {:ok, _} = release(c, a, 2)
    for n <- 3..70, do: assert({:ok, _} = reserve(c, 0, n))
    assert {:error, :operation_expired} = reserve(c, 1, 1)

    assert {:error, :closed_allocation} =
             api(:replace, [c, a.token, a.revision, 1, 71, deadline()])

    assert %{usage: 0, receipt_count: 64} = snapshot(server, i)
  end

  test "stale revisions cannot replace or release a newer allocation" do
    {_, server} = setup_budget()
    {_, c} = scope(server)
    assert {:ok, a} = reserve(c, 10, 1)
    assert {:ok, b} = api(:replace, [c, a.token, a.revision, 20, 2, deadline()])
    assert b.revision == a.revision + 1
    assert {:error, :stale_revision} = release(c, a, 3)
    assert {:ok, _} = release(c, b, 4)
  end

  test "ownership transfer preserves exact memory and logical quotas" do
    {_, server} = setup_budget()
    {i, c} = scope(server)

    target =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> Process.exit(target, :kill) end)
    assert {:ok, a} = reserve(c, accounting(10, %{request: :r}), 1, :request)
    assert {:ok, b} = api(:transfer, [c, a.token, a.revision, target, 2, deadline()])
    assert %{usage: 10, active_requests: 1} = snapshot(server, i)
    assert {:error, :invalid_terminal_receipt} = release(c, b, 3)

    assert {:ok, _} =
             api(:release, [
               c,
               b.token,
               b.revision,
               %{owner: target, revision: b.revision, terminal: :confirmed},
               4,
               deadline()
             ])
  end

  test "authority restart reconstructs explicit policy provenance usage and receipt cache" do
    {sup, server} = setup_budget()

    policy = %{
      soft_limit: 100,
      hard_limit: 200,
      provenance: %{soft_limit: :explicit, hard_limit: :explicit}
    }

    {i, c} = scope(server, policy)
    assert {:ok, a} = reserve(c, 150, 1)
    assert :ok = Supervisor.terminate_child(sup, Gaoxy.ResourceBudget.Authority)
    assert {:ok, _} = Supervisor.restart_child(sup, Gaoxy.ResourceBudget.Authority)
    assert :ok = api(:refresh, [server])
    assert %{usage: 150, soft_limit: 100, hard_limit: 200, policy: ^policy} = snapshot(server, i)
    assert {:ok, ^a} = reserve(c, 150, 1)
    assert {:error, :memory_hard_limit} = reserve(c, 51, 2)
  end

  test "ledger loss fences replacement without fabricating zero usage" do
    {sup, server} = setup_budget()
    {i, c} = scope(server)
    assert {:ok, _} = reserve(c, 10, 1)
    assert :ok = Supervisor.terminate_child(sup, Gaoxy.ResourceBudget.Ledger)
    assert {:ok, _} = Supervisor.restart_child(sup, Gaoxy.ResourceBudget.Ledger)
    assert :ok = api(:refresh, [server])
    assert %{availability: :fenced, usage: :unknown} = snapshot(server, i)
    assert {:error, :ledger_fenced} = reserve(c, 1, 2)
  end

  test "gate and owner DOWN retain charges and live service reconciles confirmed terminal receipt" do
    {_, server} = setup_budget()

    gate =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {i, c} = scope(server, %{}, %{}, :service, gate)
    assert {:ok, a} = reserve(c, 10, 1)
    ref = Process.monitor(gate)
    Process.exit(gate, :kill)
    assert_receive {:DOWN, ^ref, :process, ^gate, :killed}
    assert %{usage: 10} = snapshot(server, i)
    assert {:error, :orphaned} = reserve(c, 1, 2)
    assert {:ok, _} = release(c, a, 3)
    assert %{usage: 0} = snapshot(server, i)
  end

  test "drain fences growth and retirement requires confirmed empty obligations" do
    {_, server} = setup_budget()
    {i, c} = scope(server)
    assert {:ok, a} = reserve(c, 10, 1)
    assert {:ok, _} = api(:set_mode, [c, :draining, 2, deadline()])
    assert {:error, :draining} = reserve(c, 0, 3)
    assert {:error, :cleanup_pending} = api(:retire, [c, %{terminal: :confirmed}, 4, deadline()])
    assert {:ok, _} = release(c, a, 5)
    assert {:ok, _} = api(:retire, [c, %{terminal: :confirmed}, 6, deadline()])
    assert {:error, :unknown_generation} = reserve(c, 0, 7)
    assert %{usage: 0} = snapshot(server, i)
  end

  test "stale pressure prevents new growth while release and committed replacement credit remain usable" do
    {:ok, clock} = Agent.start_link(fn -> System.monotonic_time(:millisecond) end)
    on_exit(fn -> if Process.alive?(clock), do: Agent.stop(clock) end)
    {_, server} = setup_budget(now: fn -> Agent.get(clock, & &1) end)
    {_, c} = scope(server)
    assert {:ok, a} = reserve(c, 10, 1)
    Agent.update(clock, &(&1 + 4000))
    assert {:error, :safety_sample_unavailable} = reserve(c, 1, 2)
    assert {:ok, b} = api(:replace, [c, a.token, a.revision, 10, 3, deadline()])
    assert {:ok, _} = release(c, b, 4)
  end

  test "raced reservations share safety headroom rather than spending the sample twice" do
    {_, server} =
      setup_budget(
        safety_probe: fn _ ->
          {:ok,
           %{
             available_bytes: 100 * @mib,
             cgroup_headroom_bytes: nil,
             sampled_at: System.monotonic_time(:millisecond),
             high_pressure?: false
           }}
        end
      )

    {i, c} = scope(server)
    assert {:ok, _} = reserve(c, 30 * @mib, 1)
    assert {:error, :system_memory_pressure} = reserve(c, 30 * @mib, 2)
    assert %{usage: @usage30} = snapshot(server, i)
  end

  test "refresh retains outstanding temporary commitments in safety debit" do
    {_, server} =
      setup_budget(
        safety_probe: fn _ ->
          {:ok,
           %{
             available_bytes: 100 * @mib,
             cgroup_headroom_bytes: nil,
             sampled_at: System.monotonic_time(:millisecond),
             high_pressure?: false
           }}
        end
      )

    {_, c} = scope(server)

    peak = %{
      retained_bytes: 0,
      temporary_bytes: 40 * @mib,
      transport_bytes: 40 * @mib,
      websocket_bytes: 0
    }

    assert {:ok, _} = reserve(c, peak, 1)
    assert :ok = api(:refresh, [server])
    assert {:error, :system_memory_pressure} = reserve(c, 11 * @mib, 2)
  end

  test "capacity shrink preserves admitted work and release permits automatic recovery" do
    {:ok, cap} = Agent.start_link(fn -> 1000 * @mib end)
    on_exit(fn -> if Process.alive?(cap), do: Agent.stop(cap) end)

    {_, server} =
      setup_budget(
        capacity_probe: fn ->
          %{capacity: Agent.get(cap, & &1), fallback?: false, source: :controlled}
        end
      )

    {i, c} = scope(server)
    assert {:ok, a} = reserve(c, 300 * @mib, 1)
    Agent.update(cap, fn _ -> 200 * @mib end)
    assert :ok = api(:refresh, [server])
    assert %{state: :over_limit, usage: @usage300} = snapshot(server, i)
    assert {:error, :memory_hard_limit} = reserve(c, 0, 2)
    assert {:ok, _} = release(c, a, 3)
    assert {:ok, _} = reserve(c, 1, 4)
  end

  test "warning telemetry records committed transition once and logs are rate limited" do
    {_, server} = setup_budget()
    {i, c} = scope(server, %{soft_limit: 10, hard_limit: 20})
    id = make_ref()

    :ok =
      :telemetry.attach(
        id,
        [:gaoxy, :resource_budget_state],
        fn _, m, meta, pid -> send(pid, {:state_event, m, meta}) end,
        self()
      )

    on_exit(fn -> :telemetry.detach(id) end)

    log =
      capture_log(fn ->
        assert {:ok, _} = reserve(c, 11, 1)
        assert {:ok, _} = reserve(c, 1, 2)
        assert {:error, :memory_hard_limit} = reserve(c, 100, 3)
      end)

    assert length(Regex.scan(~r/resource budget warning/, log)) == 1
    assert_receive {:state_event, %{usage: 11}, %{instance: ^i, state: :warning}}
    refute_receive {:state_event, _, _}
  end

  test "invalid policies accounting and unknown scope never acquire fallback ownership" do
    {_, server} = setup_budget()

    assert {:error, :invalid_policy} =
             api(:register_instance, [server, self(), %{hard_limit: 100}, deadline()])

    {_, c} = scope(server)
    bad = %{retained_bytes: 10, temporary_bytes: 0, transport_bytes: 11, websocket_bytes: 0}
    assert {:error, :invalid_accounting} = reserve(c, bad, 1)

    assert {:error, :unknown_instance} =
             api(:register_service, [
               server,
               make_ref(),
               %{id: :x, owner: self(), generation: make_ref()},
               %{},
               deadline()
             ])
  end

  test "process guard protects pending spawn reservations" do
    {_, server} = setup_budget(processes: fn -> %{count: 871, limit: 1000} end)
    {_, c} = scope(server)
    bytes = Map.put(accounting(0, %{}), :pending_processes, 1)
    assert {:ok, _} = reserve(c, bytes, 1)
    assert {:error, :process_capacity} = reserve(c, bytes, 2)
  end

  test "cleanup guardians preserve explicit aggregate lease ceiling for ordinary leases" do
    {_, server} = setup_budget()
    {i, c} = scope(server, %{}, %{max_active: 1})
    assert {:ok, _} = reserve(c, 0, 1, :writer)
    assert {:ok, _} = reserve(c, 10, 2, :guardian)
    assert {:error, :active_limit} = reserve(c, 0, 3, :writer)
    assert %{leases: 2, legacy_leases: 1, usage: 10} = snapshot(server, i)
  end

  test "instance and service registrations retire only after scoped drain and terminal proof" do
    {_, server} = setup_budget()
    {i, c} = scope(server)
    assert {:ok, _} = api(:set_mode, [c, {:instance, :draining}, 1, deadline()])
    assert {:error, :draining} = reserve(c, 0, 2)
    assert {:ok, _} = api(:retire, [c, %{terminal: :confirmed, scope: :instance}, 3, deadline()])
    assert {:error, :unknown_instance} = snapshot(server, i)
    assert {:error, :unknown_generation} = reserve(c, 1, 4)
  end

  test "draining an instance fences every service without scanning its allocations" do
    {_, server} = setup_budget()
    {i, c1} = scope(server)
    {^i, c2} = scope(server, %{}, %{}, :second)
    assert {:ok, _} = api(:set_mode, [c1, {:instance, :draining}, 1, deadline()])
    assert {:error, :draining} = reserve(c2, 0, 1)

    assert {:error, :cleanup_pending} =
             api(:retire, [c1, %{terminal: :confirmed, scope: :instance}, 2, deadline()])

    assert {:ok, _} = api(:set_mode, [c2, :draining, 2, deadline()])
    assert {:ok, _} = api(:retire, [c2, %{terminal: :confirmed, scope: :service}, 3, deadline()])
    assert {:ok, _} = api(:retire, [c1, %{terminal: :confirmed, scope: :instance}, 3, deadline()])
  end

  test "expired mailbox mutation never allocates after its absolute deadline" do
    {_, server} = setup_budget()
    {i, c} = scope(server)

    ledger =
      Gaoxy.ResourceBudget.Supervisor.name(
        Gaoxy.ResourceBudget.Ledger,
        elem(server, 1) |> elem(2)
      )

    :ok = :sys.suspend(ledger)

    task =
      Task.async(fn ->
        api(:reserve, [c, self(), :writer, 10, 1, System.monotonic_time(:millisecond) + 10])
      end)

    Process.sleep(25)
    :ok = :sys.resume(ledger)
    assert {:error, :budget_timeout} = Task.await(task)
    assert {:error, :deadline_exceeded} = api(:operation_status, [c, 1])
    assert %{usage: 0} = snapshot(server, i)
  end

  test "final commit rechecks deadline after the live process safety observation" do
    {_, server} =
      setup_budget(
        processes: fn ->
          Process.sleep(30)
          %{count: 10, limit: 1000}
        end
      )

    {i, c} = scope(server)
    input = Map.put(accounting(1, %{}), :pending_processes, 1)

    assert {:error, :budget_timeout} =
             api(:reserve, [
               c,
               self(),
               :writer,
               input,
               1,
               System.monotonic_time(:millisecond) + 10
             ])

    assert {:error, :deadline_exceeded} = api(:operation_status, [c, 1])
    assert %{usage: 0, pending_processes: 0} = snapshot(server, i)
  end

  test "a live parent reconciles resource-owner DOWN without treating DOWN as terminal proof" do
    {_, server} = setup_budget()
    {i, c} = scope(server)

    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    assert {:ok, a} = api(:reserve, [c, owner, :writer, 10, 1, deadline()])
    ref = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^ref, :process, ^owner, :killed}
    assert %{usage: 10} = snapshot(server, i)

    assert {:error, :invalid_terminal_receipt} =
             api(:release, [
               c,
               a.token,
               a.revision,
               %{owner: owner, revision: a.revision, terminal: :down},
               2,
               deadline()
             ])

    assert {:ok, _} =
             api(:release, [
               c,
               a.token,
               a.revision,
               %{owner: owner, revision: a.revision, terminal: :confirmed},
               3,
               deadline()
             ])
  end

  test "sample installation retains growth committed while its probe was in flight" do
    parent = self()
    {:ok, control} = Agent.start_link(fn -> false end)
    on_exit(fn -> if Process.alive?(control), do: Agent.stop(control) end)

    probe = fn _ ->
      if Agent.get(control, & &1) do
        send(parent, {:probing, self()})

        receive do
          :continue -> :ok
        end
      end

      {:ok,
       %{
         available_bytes: 100 * @mib,
         cgroup_headroom_bytes: nil,
         sampled_at: System.monotonic_time(:millisecond),
         high_pressure?: false
       }}
    end

    {_, server} = setup_budget(safety_probe: probe)
    {i, c} = scope(server)
    Agent.update(control, fn _ -> true end)
    refreshing = Task.async(fn -> api(:refresh, [server]) end)
    assert_receive {:probing, worker}
    assert {:ok, _} = reserve(c, 40 * @mib, 1)
    send(worker, :continue)
    assert :ok = Task.await(refreshing)
    assert {:error, :system_memory_pressure} = reserve(c, 11 * @mib, 2)
    assert %{usage: @usage40} = snapshot(server, i)
  end

  test "sample baseline accounts releases and regrowth while the probe is in flight" do
    parent = self()
    {:ok, control} = Agent.start_link(fn -> false end)
    on_exit(fn -> if Process.alive?(control), do: Agent.stop(control) end)

    probe = fn _ ->
      if Agent.get(control, & &1) do
        send(parent, {:probing, self()})

        receive do
          :continue -> :ok
        end
      end

      {:ok,
       %{
         available_bytes: 100 * @mib,
         cgroup_headroom_bytes: nil,
         sampled_at: System.monotonic_time(:millisecond),
         high_pressure?: false
       }}
    end

    {_, server} = setup_budget(safety_probe: probe)
    {_, c} = scope(server)
    assert {:ok, a} = reserve(c, 40 * @mib, 1)
    Agent.update(control, fn _ -> true end)
    refreshing = Task.async(fn -> api(:refresh, [server]) end)
    assert_receive {:probing, worker}
    assert {:ok, _} = release(c, a, 2)
    assert {:ok, _} = reserve(c, 40 * @mib, 3)
    send(worker, :continue)
    assert :ok = Task.await(refreshing)
    assert {:error, :system_memory_pressure} = reserve(c, 11 * @mib, 4)
  end

  test "coalesced refresh owns one worker and supervisor shutdown confirms its cleanup" do
    parent = self()
    {:ok, control} = Agent.start_link(fn -> false end)
    on_exit(fn -> if Process.alive?(control), do: Agent.stop(control) end)

    probe = fn _ ->
      if Agent.get(control, & &1) do
        send(parent, {:probing, self()})

        receive do
          :continue -> :ok
        end
      end

      {:ok,
       %{
         available_bytes: 1000 * @mib,
         cgroup_headroom_bytes: nil,
         sampled_at: System.monotonic_time(:millisecond),
         high_pressure?: false
       }}
    end

    {sup, server} = setup_budget(safety_probe: probe)
    Agent.update(control, fn _ -> true end)
    t1 = Task.async(fn -> api(:refresh, [server]) end)
    assert_receive {:probing, worker}
    t2 = Task.async(fn -> api(:refresh, [server]) end)
    refute_receive {:probing, _}, 20
    send(worker, :continue)
    assert :ok = Task.await(t1)
    assert :ok = Task.await(t2)
    t3 = Task.async(fn -> api(:refresh, [server]) end)
    assert_receive {:probing, pending}
    ref = Process.monitor(pending)
    assert :ok = Supervisor.stop(sup)
    assert_receive {:DOWN, ^ref, :process, ^pending, _}
    assert {:error, :budget_unavailable} = Task.await(t3)
  end

  test "registration retries retain policies and explicit legacy caps never gain a multiplier" do
    {_, server} = setup_budget()
    policy = %{soft_limit: 10, hard_limit: 15, provenance: %{hard_limit: :explicit}}
    {i, c} = scope(server, policy)
    assert {:ok, ^i} = api(:register_instance, [server, self(), policy, -9_000_000_000_000])

    assert {:error, :operation_conflict} =
             api(:register_instance, [
               server,
               self(),
               %{soft_limit: 10, hard_limit: 20},
               deadline()
             ])

    assert {:ok, _} = reserve(c, 15, 1)
    assert {:error, :memory_hard_limit} = reserve(c, 1, 2)

    assert {:error, :invalid_policy} =
             api(:register_service, [
               server,
               i,
               %{id: :bad, owner: self(), generation: make_ref()},
               %{unexpected: 1},
               deadline()
             ])
  end

  test "registration controls retire an empty instance with bounded idempotent terminal receipt" do
    {_, server} = setup_budget()
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])
    scope = {:instance, i}
    assert {:ok, mode} = api(:set_registration_mode, [server, scope, :draining, 1, deadline()])

    assert {:ok, ^mode} =
             api(:set_registration_mode, [server, scope, :draining, 1, -9_000_000_000_000])

    assert {:error, :operation_conflict} =
             api(:set_registration_mode, [server, scope, :ready, 1, deadline()])

    proof = %{terminal: :confirmed}
    assert {:ok, retired} = api(:retire_registration, [server, scope, proof, 2, deadline()])

    assert {:ok, ^retired} =
             api(:retire_registration, [server, scope, proof, 2, -9_000_000_000_000])

    assert {:error, :unknown_instance} = snapshot(server, i)

    assert {:error, :unknown_generation} =
             api(:set_registration_mode, [server, scope, :ready, 3, deadline()])
  end

  test "failed startup service without a gate is retired by its live registered parent" do
    {_, server} = setup_budget()
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])

    child =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    assert {:ok, service} =
             api(:register_service, [
               server,
               i,
               %{id: :failed, owner: child, generation: make_ref()},
               %{},
               deadline()
             ])

    ref = Process.monitor(child)
    Process.exit(child, :kill)
    assert_receive {:DOWN, ^ref, :process, ^child, :killed}

    assert {:ok, _} =
             api(:retire_registration, [
               server,
               {:service, service},
               %{terminal: :confirmed},
               1,
               deadline()
             ])

    assert {:ok, _} =
             api(:set_registration_mode, [server, {:instance, i}, :draining, 1, deadline()])

    assert {:ok, _} =
             api(:retire_registration, [
               server,
               {:instance, i},
               %{terminal: :confirmed},
               2,
               deadline()
             ])
  end

  test "unregistered stale parent cannot mutate registration policy or retire it" do
    {_, server} = setup_budget()
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])

    task =
      Task.async(fn ->
        api(:set_registration_mode, [server, {:instance, i}, :draining, 1, deadline()])
      end)

    assert {:error, :unauthorized_owner} = Task.await(task)
    assert %{mode: :ready} = snapshot(server, i)
  end

  test "logical IDs are scoped by service and accept connection-local stream identities" do
    {_, server} = setup_budget()
    {i, c1} = scope(server)
    {^i, c2} = scope(server, %{}, %{}, :other)

    for c <- [c1, c2] do
      assert {:ok, _} =
               reserve(
                 c,
                 accounting(0, %{request: :one, h2_stream: {:connection1, 1}}),
                 1,
                 :h2_stream
               )
    end

    assert %{active_requests: 2, active_h2_streams: 2, vm: %{requests: 2, h2_streams: 2}} =
             snapshot(server, i)
  end

  test "owner names are scoped to the current BEAM node" do
    assert {:global, {current_node, Gaoxy.ResourceBudget.Authority, :gaoxy}} = api(:server, [])
    assert current_node == node()
  end

  test "live parent enumerates canonical post-crash allocation revisions in bounded pages" do
    {_, server} = setup_budget()

    gate =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {_, c} = scope(server, %{}, %{}, :service, gate)

    receipts =
      for n <- 1..65 do
        assert {:ok, row} = reserve(c, 1, n)
        row
      end

    first = hd(receipts)
    assert {:ok, updated} = api(:replace, [c, first.token, first.revision, 10, 66, deadline()])
    ref = Process.monitor(gate)
    Process.exit(gate, :kill)
    assert_receive {:DOWN, ^ref, :process, ^gate, :killed}

    assert {:ok, %{allocations: rows, cursor: cursor, watermark: 66, next_operation: 67}} =
             api(:allocations, [c, :start])

    assert length(rows) == 64

    assert Enum.any?(
             rows,
             &(&1.token == updated.token and &1.revision == updated.revision and
                 &1.owner == self())
           )

    assert {:ok, _} =
             api(:release, [
               c,
               updated.token,
               updated.revision,
               %{owner: self(), revision: updated.revision, terminal: :confirmed},
               67,
               deadline()
             ])

    assert {:ok, %{allocations: [_], cursor: :done, watermark: 67, next_operation: 68}} =
             api(:allocations, [c, cursor])

    intruder = Task.async(fn -> api(:allocations, [c, :start]) end)
    assert {:error, :unauthorized_owner} = Task.await(intruder)
  end

  test "snapshot telemetry contains numeric limits usage categories and logical resource counts" do
    {_, server} = setup_budget()
    {i, c} = scope(server)
    assert {:ok, _} = reserve(c, accounting(10, %{connection: :c, request: :r}), 1, :connection)
    id = make_ref()

    :ok =
      :telemetry.attach(
        id,
        [:gaoxy, :resource_budget_snapshot],
        &__MODULE__.forward_snapshot/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(id) end)
    assert :ok = api(:refresh, [server])
    assert_receive {:snapshot_event, measurements, %{instance: :vm}}

    for key <- [
          :capacity,
          :soft_limit,
          :hard_limit,
          :usage,
          :retained_bytes,
          :temporary_bytes,
          :active_connections,
          :active_requests,
          :active_h2_streams,
          :active_h3_streams
        ] do
      assert is_integer(measurements[key])
    end

    assert measurements.usage == 10
    assert measurements.active_requests == 1
    assert %{usage: 10} = snapshot(server, i)
    assert_receive {:snapshot_event, %{usage: 10, active_connections: 1}, %{instance: ^i}}
  end

  test "probe timeout cleans up worker and exposes unavailable safety without freeing live ownership" do
    parent = self()
    {:ok, control} = Agent.start_link(fn -> false end)
    on_exit(fn -> if Process.alive?(control), do: Agent.stop(control) end)

    probe = fn _ ->
      if Agent.get(control, & &1) do
        send(parent, {:probing, self()})

        receive do
          :continue -> :ok
        end
      end

      {:ok,
       %{
         available_bytes: 1000 * @mib,
         cgroup_headroom_bytes: nil,
         sampled_at: System.monotonic_time(:millisecond),
         high_pressure?: false
       }}
    end

    {_, server} = setup_budget(safety_probe: probe)
    {i, c} = scope(server)
    assert {:ok, a} = reserve(c, 10, 1)
    Agent.update(control, fn _ -> true end)
    task = Task.async(fn -> api(:refresh, [server]) end)
    assert_receive {:probing, worker}
    ref = Process.monitor(worker)
    assert :ok = Task.await(task, 4000)
    assert_receive {:DOWN, ^ref, :process, ^worker, :killed}
    assert %{usage: 10, safety: nil} = snapshot(server, i)
    assert {:error, :safety_sample_unavailable} = reserve(c, 1, 2)
    assert {:ok, _} = release(c, a, 3)
  end

  def forward_snapshot(_, measurements, metadata, pid),
    do: send(pid, {:snapshot_event, measurements, metadata})

  test "shared warning logs when every individual instance remains below its own soft limit" do
    {_, server} = setup_budget()
    {i, first} = scope(server)

    other =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> Process.exit(other, :kill) end)
    assert {:ok, second_instance} = api(:register_instance, [server, other, %{}, deadline()])

    assert {:ok, service} =
             api(:register_service, [
               server,
               second_instance,
               %{id: :second, owner: self(), generation: make_ref()},
               %{},
               deadline()
             ])

    assert {:ok, second} = api(:register_gate, [server, service, self(), deadline()])
    assert {:ok, _} = reserve(first, 300 * @mib, 1)

    log =
      capture_log(fn ->
        assert {:ok, _} = reserve(second, 300 * @mib, 1)
        assert {:ok, _} = reserve(second, 1, 2)
      end)

    assert length(Regex.scan(~r/resource budget warning/, log)) == 1
    assert %{state: :normal, vm: %{state: :warning}} = snapshot(server, i)
    assert %{state: :normal, vm: %{state: :warning}} = snapshot(server, second_instance)
  end

  test "paused authority calls respect the mutation budget and reconcile after timeout" do
    {_, server} = setup_budget()
    {i, c} = scope(server)
    :ok = :sys.suspend(server)
    started = System.monotonic_time(:millisecond)

    try do
      assert {:error, :budget_timeout} = api(:reserve, [c, self(), :writer, 10, 1, started + 25])
      assert System.monotonic_time(:millisecond) - started < 1000
    after
      :ok = :sys.resume(server)
    end

    assert {:error, :deadline_exceeded} = api(:operation_status, [c, 1])
    assert %{usage: 0} = snapshot(server, i)
  end

  test "projected transport category increases respect explicit caps without memory growth" do
    {_, server} = setup_budget()
    {i, c} = scope(server, %{}, %{max_bytes: 50})

    websocket = %{
      retained_bytes: 100,
      temporary_bytes: 0,
      transport_bytes: 0,
      websocket_bytes: 100
    }

    assert {:ok, a} = reserve(c, websocket, 1)
    assert {:ok, _} = reserve(c, 25, 2)

    convert = fn transport ->
      %{websocket | transport_bytes: transport, websocket_bytes: 100 - transport}
    end

    assert {:error, :byte_limit} =
             api(:replace, [c, a.token, a.revision, convert.(100), 3, deadline()])

    assert {:error, :byte_limit} =
             api(:replace, [c, a.token, a.revision, convert.(26), 4, deadline()])

    assert %{usage: 125, transport_bytes: 25, websocket_bytes: 100} = snapshot(server, i)
    assert {:ok, updated} = api(:replace, [c, a.token, a.revision, convert.(25), 5, deadline()])
    assert updated.revision == a.revision + 1
    assert %{usage: 125, transport_bytes: 50, websocket_bytes: 75} = snapshot(server, i)
  end

  test "equal-total transport conversion remains usable above shrunk shared hard limit" do
    {:ok, cap} = Agent.start_link(fn -> 1000 * @mib end)
    on_exit(fn -> if Process.alive?(cap), do: Agent.stop(cap) end)

    {_, server} =
      setup_budget(
        capacity_probe: fn ->
          %{capacity: Agent.get(cap, & &1), fallback?: false, source: :controlled}
        end
      )

    {i, c} = scope(server, %{}, %{max_bytes: 100 * @mib})

    websocket = %{
      retained_bytes: 100 * @mib,
      temporary_bytes: 0,
      transport_bytes: 0,
      websocket_bytes: 100 * @mib
    }

    assert {:ok, a} = reserve(c, websocket, 1)
    Agent.update(cap, fn _ -> 50 * @mib end)
    assert :ok = api(:refresh, [server])
    assert %{state: :over_limit} = snapshot(server, i)
    assert {:ok, converted} = api(:replace, [c, a.token, a.revision, 100 * @mib, 2, deadline()])

    assert %{state: :over_limit, websocket_bytes: 0, transport_bytes: @usage100} =
             snapshot(server, i)

    assert {:ok, _} = release(c, converted, 3)
    assert %{usage: 0} = snapshot(server, i)
  end

  test "instance registration rolls back when the commit clock reaches its deadline" do
    {server, clock} = commit_clock_budget()
    d = expire_at_commit(clock)

    assert {:error, :deadline_exceeded} =
             api(:register_instance, [server, self(), %{soft_limit: 10, hard_limit: 20}, d])

    policy = %{soft_limit: 20, hard_limit: 40}
    assert {:ok, i} = api(:register_instance, [server, self(), policy, deadline()])
    assert %{soft_limit: 20, hard_limit: 40} = snapshot(server, i)
    retire_empty_registration(server, {:instance, i})
    assert_no_budget_monitor(server)
  end

  test "service registration rolls back scope counters and monitors after commit expiry" do
    {server, clock} = commit_clock_budget()
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])
    service_scope = %{id: :late, owner: self(), generation: make_ref()}
    d = expire_at_commit(clock)

    assert {:error, :deadline_exceeded} =
             api(:register_service, [server, i, service_scope, %{max_bytes: 10}, d])

    assert {:ok, service} =
             api(:register_service, [server, i, service_scope, %{max_bytes: 20}, deadline()])

    retire_empty_registration(server, {:service, service})
    retire_empty_registration(server, {:instance, i})
    assert_no_budget_monitor(server)
  end

  test "gate registration rolls back parent counts and monitor effects after commit expiry" do
    {server, clock} = commit_clock_budget()
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])

    assert {:ok, service} =
             api(:register_service, [
               server,
               i,
               %{id: :late, owner: self(), generation: make_ref()},
               %{},
               deadline()
             ])

    d = expire_at_commit(clock)
    assert {:error, :deadline_exceeded} = api(:register_gate, [server, service, self(), d])
    assert {:ok, c} = api(:register_gate, [server, service, self(), deadline()])
    assert {:ok, _} = api(:set_mode, [c, {:instance, :draining}, 1, deadline()])
    assert {:ok, _} = api(:retire, [c, %{terminal: :confirmed, scope: :instance}, 2, deadline()])
    assert {:error, :unknown_instance} = snapshot(server, i)
    assert_no_budget_monitor(server)
  end

  test "instance registration mode rejects commit-time expiry without changing mode" do
    registration_mode_expiry(:instance)
  end

  test "service registration mode rejects commit-time expiry without changing mode" do
    registration_mode_expiry(:service)
  end

  test "instance retirement expiry retains its registration and rejects the original retry" do
    registration_retirement_expiry(:instance)
  end

  test "service retirement expiry retains its registration and rejects the original retry" do
    registration_retirement_expiry(:service)
  end

  test "manual refresh during safety-only sampling coalesces one fresh capacity follow-up" do
    parent = self()
    {:ok, control} = Agent.start_link(fn -> %{capacity: 1000 * @mib, block_next: false} end)
    on_exit(fn -> if Process.alive?(control), do: Agent.stop(control) end)

    capacity = fn ->
      send(parent, {:capacity_probe, self()})
      %{capacity: Agent.get(control, & &1.capacity), fallback?: false, source: :controlled}
    end

    safety = fn _ ->
      block? =
        Agent.get_and_update(control, fn state ->
          {state.block_next, %{state | block_next: false}}
        end)

      if block? do
        send(parent, {:safety_only_probe, self()})

        receive do
          :continue -> :ok
        end
      end

      {:ok,
       %{
         available_bytes: 1000 * @mib,
         cgroup_headroom_bytes: nil,
         sampled_at: System.monotonic_time(:millisecond),
         high_pressure?: false
       }}
    end

    {_, server} = setup_budget(capacity_probe: capacity, safety_probe: safety)
    {i, _} = scope(server)
    assert_receive {:capacity_probe, _}

    receive do
      {:capacity_probe, _} -> :ok
    after
      0 -> :ok
    end

    identity = elem(elem(server, 1), 2)
    sampler = Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Sampler, identity)
    Agent.update(control, &%{&1 | block_next: true})
    send(GenServer.whereis(sampler), :tick)
    assert_receive {:safety_only_probe, worker}
    Agent.update(control, &%{&1 | capacity: 200 * @mib})
    first = :gen_server.send_request(sampler, :refresh)
    second = :gen_server.send_request(sampler, :refresh)
    # Same-sender system-message barrier confirms both requests reached the sampler.
    _ = :sys.get_state(sampler)
    assert :timeout = :gen_server.wait_response(first, 0)
    assert :timeout = :gen_server.wait_response(second, 0)
    send(worker, :continue)
    assert_receive {:capacity_probe, _}
    assert {:reply, :ok} = :gen_server.receive_response(first, 1000)
    assert {:reply, :ok} = :gen_server.receive_response(second, 1000)
    assert %{capacity: @usage200, hard_limit: @usage200} = snapshot(server, i)
    refute_receive {:capacity_probe, _}, 20
  end

  defp commit_clock_budget do
    {:ok, clock} = Agent.start_link(fn -> %{ledger: nil, observations: []} end)
    on_exit(fn -> if Process.alive?(clock), do: Agent.stop(clock) end)

    now = fn ->
      caller = self()

      Agent.get_and_update(clock, fn state ->
        case {state.ledger == caller, state.observations} do
          {true, [observation | rest]} -> {observation, %{state | observations: rest}}
          _ -> {System.monotonic_time(:millisecond), state}
        end
      end)
    end

    {_, server} = setup_budget(now: now)
    identity = elem(elem(server, 1), 2)

    ledger =
      GenServer.whereis(
        Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Ledger, identity)
      )

    Agent.update(clock, &%{&1 | ledger: ledger})
    {server, clock}
  end

  defp expire_at_commit(clock) do
    d = deadline()
    Agent.update(clock, &%{&1 | observations: [d - 1, d]})
    d
  end

  defp registration_fixture(server, :instance) do
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])
    {i, {:instance, i}, nil}
  end

  defp registration_fixture(server, :service) do
    assert {:ok, i} = api(:register_instance, [server, self(), %{}, deadline()])
    spec = %{id: :late, owner: self(), generation: make_ref()}
    assert {:ok, service} = api(:register_service, [server, i, spec, %{}, deadline()])
    {i, {:service, service}, spec}
  end

  defp registration_mode_expiry(kind) do
    {server, clock} = commit_clock_budget()
    {i, target, _} = registration_fixture(server, kind)
    d = expire_at_commit(clock)

    assert {:error, :deadline_exceeded} =
             api(:set_registration_mode, [server, target, :draining, 1, d])

    assert {:error, :deadline_exceeded} =
             api(:set_registration_mode, [server, target, :draining, 1, deadline()])

    assert {:ok, _} = api(:set_registration_mode, [server, target, :ready, 2, deadline()])
    assert %{mode: :ready} = snapshot(server, i)
    assert {:ok, _} = api(:set_registration_mode, [server, target, :draining, 3, deadline()])

    assert {:ok, _} =
             api(:retire_registration, [server, target, %{terminal: :confirmed}, 4, deadline()])

    if kind == :service, do: retire_empty_registration(server, {:instance, i})
    assert_no_budget_monitor(server)
  end

  defp registration_retirement_expiry(kind) do
    {server, clock} = commit_clock_budget()
    {i, target, spec} = registration_fixture(server, kind)
    assert {:ok, _} = api(:set_registration_mode, [server, target, :draining, 1, deadline()])
    d = expire_at_commit(clock)
    proof = %{terminal: :confirmed}
    assert {:error, :deadline_exceeded} = api(:retire_registration, [server, target, proof, 2, d])

    assert {:error, :deadline_exceeded} =
             api(:retire_registration, [server, target, proof, 2, deadline()])

    case kind do
      :instance ->
        assert {:ok, ^i} = api(:register_instance, [server, self(), %{}, deadline()])

      :service ->
        {:service, service} = target
        assert {:ok, ^service} = api(:register_service, [server, i, spec, %{}, deadline()])
    end

    assert {:ok, _} = api(:retire_registration, [server, target, proof, 3, deadline()])
    if kind == :service, do: retire_empty_registration(server, {:instance, i})
    assert_no_budget_monitor(server)
  end

  defp retire_empty_registration(server, scope) do
    assert {:ok, _} = api(:set_registration_mode, [server, scope, :draining, 1, deadline()])

    assert {:ok, _} =
             api(:retire_registration, [server, scope, %{terminal: :confirmed}, 2, deadline()])
  end

  defp assert_no_budget_monitor(server) do
    authority = GenServer.whereis(server)
    assert {:monitored_by, monitors} = Process.info(self(), :monitored_by)
    refute authority in monitors
  end
end
