defmodule Gaoxy.ResourceBudget.AdmissionTest do
  use ExUnit.Case, async: false
  @moduletag :component
  alias Gaoxy.{Admission, ResourceBudget}

  defp deadline, do: System.monotonic_time(:millisecond) + 1000

  defp budget do
    identity = make_ref()

    start_supervised!(
      {Gaoxy.ResourceBudget.Supervisor,
       identity: identity,
       capacity_probe: fn -> %{capacity: 1_000_000_000, fallback?: false, source: :controlled} end,
       safety_probe: fn _ ->
         {:ok,
          %{
            available_bytes: 1_000_000_000,
            cgroup_headroom_bytes: nil,
            sampled_at: System.monotonic_time(:millisecond),
            high_pressure?: false
          }}
       end,
       processes: fn -> %{count: 1, limit: 1000} end}
    )

    server = Gaoxy.ResourceBudget.Supervisor.name(Gaoxy.ResourceBudget.Authority, identity)
    assert :ok = ResourceBudget.refresh(server)

    assert {:ok, instance} =
             ResourceBudget.register_instance(
               server,
               self(),
               %{soft_limit: 100, hard_limit: 200},
               deadline()
             )

    {server, instance}
  end

  defp gate({server, instance}, policy \\ %{}) do
    id = make_ref()

    policy =
      Map.merge(
        %{
          max_active: nil,
          max_bytes: nil,
          max_connections: 10,
          max_requests: 10,
          max_streams: 10,
          provenance: %{}
        },
        policy
      )

    assert {:ok, service} =
             ResourceBudget.register_service(
               server,
               instance,
               %{id: id, owner: self(), generation: make_ref()},
               policy,
               deadline()
             )

    scope = %{
      instance: make_ref(),
      service: id,
      generation: make_ref(),
      service_pid: self(),
      budget: %{server: server, instance: instance, service: service}
    }

    start_supervised!(
      Supervisor.child_spec(
        {Admission, {%{max_active: 1, max_bytes: 1, callback_timeout: 5000}, scope}},
        id: id,
        restart: :temporary
      )
    )
  end

  defp snapshot({server, instance}), do: ResourceBudget.snapshot(server, instance)

  test "native reservation survives callback death before its split and releases by guardian proof" do
    b = budget()
    g = gate(b, %{max_connections: 1})
    owner = native_process()
    guardian = native_process()
    token = make_ref()
    lease = make_ref()
    assert :ok = Admission.reserve_native(g, owner, lease, token, 150, 10, deadline())
    assert_receive {:gaoxy_native_reserved, ^token, _}
    stop_native(owner, :kill)

    assert %{usage: 160, active_connections: 1, active_requests: 0, pending_processes: 1} =
             snapshot(b)

    assert %{active: 0, cleanup_pending: 1} = Admission.status(g)
    assert :ok = Admission.split_native(g, token, guardian, deadline())
    assert_receive {:gaoxy_native_activated, ^token, ^lease, _}
    eventually(fn -> Admission.status(g).active == 0 end)
    assert %{usage: 160, active_connections: 1, pending_processes: 0} = snapshot(b)

    assert {:error, :connection_limit} =
             Admission.acquire(g, 0, kind: :connection, memberships: %{connection: make_ref()})

    assert :ok = Admission.complete_cleanup(g, token)
    stop_native(guardian, :normal)
    eventually(fn -> snapshot(b).usage == 0 end)
    assert %{active_connections: 0, leases: 0} = snapshot(b)
  end

  test "native terminal proof before callback death refunds only native ownership" do
    b = budget()
    g = gate(b)
    token = make_ref()
    lease = make_ref()
    guardian = native_process()
    assert :ok = Admission.reserve_native(g, self(), lease, token, 100, 10, deadline())
    assert :ok = Admission.split_native(g, token, guardian, deadline())
    assert :ok = Admission.end_request(g, lease, 30, deadline())
    assert :ok = Admission.update_native(g, lease, 120, deadline())
    assert %{usage: 160, active_connections: 1, active_requests: 0} = snapshot(b)
    assert :ok = Admission.complete_cleanup(g, token)
    assert %{usage: 160} = snapshot(b)
    stop_native(guardian, :normal)
    eventually(fn -> snapshot(b).usage == 30 end)
    assert %{active_connections: 0, leases: 1} = snapshot(b)
    assert %{active: 1, cleanup_pending: 0} = Admission.status(g)
  end

  test "native registration and updates reject unauthenticated, duplicate and expired attempts" do
    b = budget()
    g = gate(b)
    token = make_ref()
    lease = make_ref()
    guardian = native_process()

    assert {:error, :unauthorized_service} =
             Task.async(fn ->
               Admission.reserve_native(g, self(), lease, token, 10, 10, deadline())
             end)
             |> Task.await()

    assert {:error, :deadline_exceeded} =
             Admission.reserve_native(g, self(), lease, token, 10, 10, deadline() - 2_000)

    assert %{usage: 0, leases: 0} = snapshot(b)
    assert :ok = Admission.reserve_native(g, self(), lease, token, 10, 10, deadline())

    assert {:error, :invalid_native_reservation} =
             Admission.reserve_native(g, self(), lease, token, 10, 10, deadline())

    assert {:error, :unauthorized_service} =
             Task.async(fn ->
               Admission.split_native(g, token, guardian, deadline())
             end)
             |> Task.await()

    assert :ok = Admission.split_native(g, token, guardian, deadline())
    assert {:error, :stale_cleanup} = Admission.split_native(g, token, guardian, deadline())

    assert {:error, :stale_cleanup} =
             Task.async(fn ->
               Admission.update_native(g, lease, 0, deadline())
             end)
             |> Task.await()

    assert {:error, :deadline_exceeded} = Admission.update_native(g, lease, 0, deadline() - 2_000)

    assert {:error, :unauthorized_service} =
             Task.async(fn ->
               Admission.complete_cleanup(g, token)
             end)
             |> Task.await()

    assert %{usage: 20, active_connections: 1, leases: 2} = snapshot(b)
    assert :ok = Admission.complete_cleanup(g, token)
    stop_native(guardian, :normal)
    eventually(fn -> snapshot(b).usage == 0 end)
  end

  test "native split enforces max_active without losing its pinned connection or bytes" do
    b = budget()
    g = gate(b, %{max_active: 1})
    assert {:ok, _} = Admission.acquire(g, 10)
    token = make_ref()
    lease = make_ref()
    guardian = native_process()
    assert :ok = Admission.reserve_native(g, self(), lease, token, 100, 10, deadline())
    assert {:error, :active_limit} = Admission.split_native(g, token, guardian, deadline())
    assert %{usage: 120, active_connections: 1, pending_processes: 1, leases: 2} = snapshot(b)
    assert %{active: 1, cleanup_pending: 1} = Admission.status(g)
    assert :ok = Admission.complete_cleanup(g, token)
    stop_native(guardian, :normal)
    eventually(fn -> snapshot(b).usage == 10 end)
    assert %{active_connections: 0, pending_processes: 0} = snapshot(b)
  end

  test "guardian loss never refunds the native charge or connection quota" do
    b = budget()
    g = gate(b)
    token = make_ref()
    guardian = native_process()
    assert :ok = Admission.reserve_native(g, self(), make_ref(), token, 100, 10, deadline())
    assert :ok = Admission.split_native(g, token, guardian, deadline())
    stop_native(guardian, :kill)
    eventually(fn -> :sys.get_state(g).mode == :failed end)
    assert %{usage: 110, active_connections: 1, leases: 2} = snapshot(b)
    assert %{cleanup_pending: 1} = Admission.status(g)
  end

  test "a timed-out native reservation that later commits stays pinned after callback death" do
    {server, _} = b = budget()
    g = gate(b)
    owner = native_process()
    guardian = native_process()
    token = make_ref()
    lease = make_ref()
    observer = self()
    ledger = :sys.get_state(server).ledger
    frozen_now = System.monotonic_time(:millisecond)
    barrier = make_ref()
    # Control only our Ledger clock/commit barrier. The API wait clock still
    # expires, while the canonical clock remains before the original deadline.
    :sys.replace_state(ledger, fn state ->
      %{
        state
        | now: fn ->
            unless Process.get(barrier) do
              Process.put(barrier, true)
              send(observer, {:native_commit_held, self()})

              receive do
                :release_native_commit -> :ok
              end
            end

            frozen_now
          end
      }
    end)

    try do
      assert {:error, :budget_timeout} =
               Admission.reserve_native(g, owner, lease, token, 100, 10, deadline())

      assert_receive {:native_commit_held, ledger_pid}
      stop_native(owner, :kill)
      send(ledger_pid, :release_native_commit)
      assert_receive {:gaoxy_native_reserved, ^token, _}, 1_000
      assert %{usage: 110, active_connections: 1, pending_processes: 1} = snapshot(b)
      assert :ok = Admission.split_native(g, token, guardian, deadline())
      eventually(fn -> Admission.status(g).active == 0 end)
      assert %{usage: 110, active_connections: 1} = snapshot(b)
      assert :ok = Admission.complete_cleanup(g, token)
      stop_native(guardian, :normal)
      eventually(fn -> snapshot(b).usage == 0 end)
    after
      send(GenServer.whereis(ledger), :release_native_commit)
    end
  end

  test "ambiguous native split retains the same obligation through late commit and callback death" do
    {server, _} = b = budget()
    g = gate(b)
    owner = native_process()
    guardian = native_process()
    token = make_ref()
    lease = make_ref()
    assert :ok = Admission.reserve_native(g, owner, lease, token, 100, 10, deadline())
    hold_native_commit(server)
    assert {:error, :budget_timeout} = Admission.split_native(g, token, guardian, deadline())
    assert_receive {:native_commit_held, ledger}, 1_000
    stop_native(owner, :kill)
    assert %{cleanup_pending: 1} = Admission.status(g)
    send(ledger, :release_native_commit)
    assert_receive {:gaoxy_native_activated, ^token, ^lease, _}, 1_000
    eventually(fn -> Admission.status(g).active == 0 end)
    assert %{usage: 110, active_connections: 1, pending_processes: 0, leases: 1} = snapshot(b)
    assert :ok = Admission.complete_cleanup(g, token)
    stop_native(guardian, :normal)
    eventually(fn -> snapshot(b).usage == 0 end)
  end

  test "a guardian lost before registration cannot drop the Service-pinned native reservation" do
    b = budget()
    g = gate(b)
    guardian = native_process()
    token = make_ref()
    assert :ok = Admission.reserve_native(g, self(), make_ref(), token, 100, 10, deadline())
    stop_native(guardian, :kill)
    assert {:error, :invalid_guardian} = Admission.split_native(g, token, guardian, deadline())
    assert %{usage: 110, active_connections: 1, pending_processes: 1, leases: 1} = snapshot(b)
    assert %{active: 0, cleanup_pending: 1} = Admission.status(g)
  end

  test "a late native measurement commit preserves the received guardian terminal pair" do
    {server, _} = b = budget()
    g = gate(b)
    guardian = native_process()
    token = make_ref()
    lease = make_ref()
    assert :ok = Admission.reserve_native(g, self(), lease, token, 100, 10, deadline())
    assert :ok = Admission.split_native(g, token, guardian, deadline())
    hold_native_commit(server)
    assert {:error, :budget_timeout} = Admission.update_native(g, lease, 120, deadline())
    assert_receive {:native_commit_held, ledger}, 1_000
    assert :ok = Admission.complete_cleanup(g, token)
    stop_native(guardian, :normal)
    eventually(fn -> :sys.get_state(g).cleanups[token].down_seen end)
    send(ledger, :release_native_commit)
    eventually(fn -> snapshot(b).usage == 0 end)
    assert %{active_connections: 0, leases: 1} = snapshot(b)
    assert %{cleanup_pending: 0} = Admission.status(g)
  end

  test "native termination may use paid callback state during drain but cannot admit growth" do
    b = budget()
    g = gate(b)
    assert {:ok, ordinary} = Admission.acquire(g, 10)

    assert {:error, :invalid_native_cleanup} =
             Admission.begin_native_cleanup(g, ordinary, 10, deadline())

    guardian = native_process()
    token = make_ref()
    lease = make_ref()
    assert :ok = Admission.reserve_native(g, self(), lease, token, 10, 10, deadline())
    assert :ok = Admission.split_native(g, token, guardian, deadline())
    assert :ok = Admission.end_request(g, lease, 10, deadline())
    assert :ok = Admission.drain(g, deadline())
    assert {:error, :draining} = Admission.begin_callback(g, lease, 10, deadline())

    assert {:error, :invalid_native_cleanup} =
             Admission.begin_native_cleanup(g, lease, 11, deadline())

    assert :ok = Admission.begin_native_cleanup(g, lease, 10, deadline())
    assert %{usage: 40, active_connections: 1, active_requests: 0} = snapshot(b)
    assert :ok = Admission.complete_cleanup(g, token)
    stop_native(guardian, :normal)
    eventually(fn -> snapshot(b).usage == 20 end)
  end

  defp hold_native_commit(server) do
    observer = self()
    ledger = :sys.get_state(server).ledger
    frozen_now = System.monotonic_time(:millisecond)
    barrier = make_ref()

    :sys.replace_state(ledger, fn state ->
      %{
        state
        | now: fn ->
            unless Process.get(barrier) do
              Process.put(barrier, true)
              send(observer, {:native_commit_held, self()})

              receive do
                :release_native_commit -> :ok
              end
            end

            frozen_now
          end
      }
    end)

    on_exit(fn ->
      if pid = GenServer.whereis(ledger), do: send(pid, :release_native_commit)
    end)
  end

  defp native_process do
    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    pid
  end

  defp stop_native(pid, reason) do
    monitor = Process.monitor(pid)
    if reason == :normal, do: send(pid, :stop), else: Process.exit(pid, reason)
    expected = if reason == :kill, do: :killed, else: reason
    assert_receive {:DOWN, ^monitor, :process, ^pid, ^expected}, 1_000
  end

  test "production budget ignores omitted numeric legacy caps and commits before acknowledgment" do
    b = budget()
    gate = gate(b)
    assert {:ok, _} = Admission.acquire(gate, 100)
    assert {:ok, _} = Admission.acquire(gate, 100)
    assert %{usage: 200, state: :warning} = snapshot(b)
    assert {:error, :memory_hard_limit} = Admission.acquire(gate, 1)
  end

  test "two gates share instance accounting and recover after reduction" do
    b = budget()
    a = gate(b)
    c = gate(b)
    assert {:ok, lease} = Admission.acquire(a, 120)
    assert {:error, :memory_hard_limit} = Admission.acquire(c, 81)
    assert :ok = Admission.update(a, lease, 20)
    assert {:ok, _} = Admission.acquire(c, 81)
    assert %{usage: 101} = snapshot(b)
  end

  test "status and work telemetry distinguish retained temporary and total high waters" do
    b = budget()
    g = gate(b)
    handler = make_ref()
    observer = self()
    scope = :sys.get_state(g).scope

    :ok =
      :telemetry.attach(
        handler,
        [:gaoxy, :work],
        fn _, measurements, metadata, _ ->
          if metadata.service == scope.service, do: send(observer, {:work, measurements})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    assert {:ok, lease} =
             Admission.acquire(g, %{retained_bytes: 20, temporary_bytes: 80, transport_bytes: 100})

    assert %{
             retained_bytes: 20,
             temporary_bytes: 80,
             usage: 100,
             retained_high_water: 20,
             temporary_high_water: 80,
             usage_high_water: 100,
             transport_bytes: 100
           } = Admission.status(g)

    assert_receive {:work,
                    %{
                      retained_bytes: 20,
                      temporary_bytes: 80,
                      usage: 100,
                      retained_high_water: 20,
                      temporary_high_water: 80,
                      usage_high_water: 100
                    }}

    assert :ok =
             Admission.repartition_until(
               g,
               lease,
               %{retained_bytes: 70, temporary_bytes: 30},
               make_ref(),
               deadline()
             )

    assert %{
             retained_bytes: 70,
             temporary_bytes: 30,
             usage: 100,
             retained_high_water: 70,
             temporary_high_water: 80,
             usage_high_water: 100
           } = Admission.status(g)

    assert :ok =
             Admission.repartition_until(
               g,
               lease,
               %{retained_bytes: 0, temporary_bytes: 100},
               make_ref(),
               deadline()
             )

    assert %{
             retained_bytes: 0,
             temporary_bytes: 100,
             usage: 100,
             retained_high_water: 70,
             temporary_high_water: 100,
             usage_high_water: 100
           } = Admission.status(g)

    assert :sys.get_state(g).bytes == 100
    assert :sys.get_state(g).leases[lease].bytes == 100
    assert {:error, :memory_hard_limit} = Admission.acquire(g, 101)
    assert %{usage: 100} = snapshot(b)
  end

  test "guardian retained metrics survive receipt until the actual terminal boundary" do
    b = budget()
    g = gate(b)
    accounting = %{retained_bytes: 20, temporary_bytes: 80, transport_bytes: 100}
    assert {:ok, lease} = Admission.acquire(g, accounting, drain_notify: true)
    limit = deadline()
    assert :ok = Admission.begin_request(g, lease, accounting, limit)
    guardian = spawn(fn -> receive do: (:finish -> :ok) end)
    on_exit(fn -> if Process.alive?(guardian), do: Process.exit(guardian, :kill) end)
    token = make_ref()
    assert :ok = Admission.attach_cleanup(g, self(), lease, guardian, 5, limit, token)

    assert %{retained_bytes: 25, temporary_bytes: 80, usage: 105, cleanup_pending: 1} =
             Admission.status(g)

    assert :ok = Admission.complete_cleanup(g, token)

    assert %{retained_bytes: 25, temporary_bytes: 80, usage: 105, cleanup_pending: 1} =
             Admission.status(g)

    send(guardian, :finish)
    eventually(fn -> Admission.status(g).cleanup_pending == 0 end)

    assert %{
             retained_bytes: 20,
             temporary_bytes: 80,
             usage: 100,
             retained_high_water: 25,
             usage_high_water: 105
           } = Admission.status(g)

    assert %{usage: 100} = snapshot(b)
  end

  defp phase_spawn(g, parent, token, limit) do
    apply(Admission, :spawn_request, [
      g,
      parent,
      token,
      20,
      limit,
      {__MODULE__, :token_worker, [self(), token]},
      [kind: :h2_stream, memberships: %{h2_stream: {parent, 1}, request: token}],
      :phase_receipt
    ])
  end

  test "phase receipt proves only authenticated valid-token pre-reserve expiry" do
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    token = make_ref()
    expired = deadline() - 2000
    request = phase_spawn(g, parent, token, expired)

    assert {:reply, {:error, {:not_reserved, ^token, :deadline_exceeded}}} =
             :gen_server.receive_response(request, 1000)

    assert %{usage: 0, leases: 1, h2_streams: 0} = snapshot(b)
    assert :sys.get_state(g).spawns == %{}
    refute_receive {:token_worker_started, _, _}, 0
    legacy = token_spawn(g, parent, make_ref(), :h2_stream, expired)
    assert {:reply, {:error, :deadline_exceeded}} = :gen_server.receive_response(legacy, 1000)
    invalid = phase_spawn(g, parent, :invalid, expired)

    assert {:reply, {:error, :invalid_spawn_request}} =
             :gen_server.receive_response(invalid, 1000)

    foreign =
      Task.async(fn ->
        :gen_server.receive_response(phase_spawn(g, parent, make_ref(), expired), 1000)
      end)

    assert {:reply, {:error, :stale_generation}} = Task.await(foreign)
  end

  test "live retained and recently retired spawn tokens cannot receive absence proofs" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    token = make_ref()
    request = phase_spawn(g, parent, token, deadline())
    assert {:reply, {:ok, worker, lease}} = :gen_server.receive_response(request, 1000)
    assert_receive {:token_worker_started, ^worker, ^token}
    duplicate = phase_spawn(g, parent, token, deadline() - 2000)

    assert {:reply, {:error, :invalid_spawn_request}} =
             :gen_server.receive_response(duplicate, 1000)

    send(worker, :finish)
    eventually(fn -> :sys.get_state(g).spawns == %{} end)
    retained = phase_spawn(g, parent, token, deadline() - 2000)

    assert {:reply, {:error, :invalid_spawn_request}} =
             :gen_server.receive_response(retained, 1000)

    assert :ok = Admission.end_stream(g, parent, :h2_stream, 1, deadline())
    assert :ok = Admission.finish_stream_resources(g, parent, lease, make_ref(), deadline())
    eventually(fn -> snapshot(b).usage == 0 end)
    retired = phase_spawn(g, parent, token, deadline() - 2000)

    assert {:reply, {:error, :invalid_spawn_request}} =
             :gen_server.receive_response(retired, 1000)
  end

  test "pending canonical reservation cannot be mistaken for definite absence" do
    b = {server, _} = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    token = make_ref()
    assert :ok = :sys.suspend(server)

    try do
      request = phase_spawn(g, parent, token, System.monotonic_time(:millisecond) + 20)
      assert {:reply, {:error, :budget_timeout}} = :gen_server.receive_response(request, 1000)
      assert :sys.get_state(g).budget.pending != nil
      retry = phase_spawn(g, parent, token, deadline() - 2000)
      assert {:reply, {:error, :budget_pending}} = :gen_server.receive_response(retry, 1000)
    after
      :ok = :sys.resume(server)
    end

    eventually(fn -> :sys.get_state(g).budget.pending == nil end)
    assert %{usage: 0, leases: 1} = snapshot(b)
  end

  test "phase receipt preserves ambiguous post-reserve activation expiry ownership" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    token = make_ref()
    barrier = make_ref()
    observer = self()

    debug = fn
      :armed, {:noreply, state}, _ ->
        case state.spawns[token] do
          %{worker: worker} ->
            send(observer, {:spawn_bound, barrier, worker})

            # Keep the real activation ahead of the later watchdog/DOWN/EXIT
            # messages so this exercises activation expiry, not worker failure.
            receive do
              {:release_bound, ^barrier} -> :done
            after
              1000 -> exit(:bound_barrier_timeout)
            end

          _ ->
            :armed
        end

      current, _, _ ->
        current
    end

    assert :ok = :sys.install(g, {barrier, debug, :armed})
    request = phase_spawn(g, parent, token, System.monotonic_time(:millisecond) + 200)
    assert_receive {:spawn_bound, ^barrier, worker}, 1000
    monitor = Process.monitor(worker)

    try do
      assert %{usage: 20, h2_streams: 1} = snapshot(b)
      assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, 1000
    after
      send(g, {:release_bound, barrier})
    end

    assert {:reply, {:error, :deadline_exceeded}} = :gen_server.receive_response(request, 1000)
    eventually(fn -> :sys.get_state(g).spawns == %{} end)
    assert %{usage: 20, h2_streams: 1} = snapshot(b)
    assert :ok = Admission.end_stream(g, parent, :h2_stream, 1, deadline())
    assert %{usage: 20} = snapshot(b)
    assert :ok = Admission.finish_spawn_resources(g, parent, token, make_ref(), deadline())
    eventually(fn -> snapshot(b).usage == 0 end)
    refute_receive {:token_worker_started, _, _}, 0
  end

  test "request completion removes quota and watchdog without releasing connection bytes" do
    b = budget()
    g = gate(b, %{max_requests: 1})
    assert {:ok, a} = Admission.acquire(g, 10, kind: :connection, memberships: %{connection: :a})
    assert {:ok, c} = Admission.acquire(g, 10, kind: :connection, memberships: %{connection: :c})
    assert :ok = Admission.begin_request(g, a, 20, deadline())
    assert {:error, :request_limit} = Admission.begin_request(g, c, 20, deadline())
    assert :ok = apply(Admission, :end_request, [g, a, 10, deadline()])
    assert :ok = Admission.begin_request(g, c, 20, deadline())
    assert %{usage: 30, requests: 1, connections: 2} = snapshot(b)
  end

  test "full accounting keeps temporary credit and websocket ownership through scalar mutations" do
    b = budget()
    g = gate(b)

    accounting = %{
      retained_bytes: 20,
      temporary_bytes: 10,
      transport_bytes: 20,
      websocket_bytes: 10,
      memberships: %{connection: :one}
    }

    assert {:ok, lease} = Admission.acquire(g, accounting, kind: :connection)
    assert :ok = Admission.update(g, lease, 40)
    assert %{usage: 50, temporary_bytes: 10, websocket_bytes: 10, connections: 1} = snapshot(b)
    assert :ok = Admission.adjust_bytes(g, lease, -10)
    assert %{usage: 40, temporary_bytes: 10, websocket_bytes: 10} = snapshot(b)
  end

  test "explicit transport and ordinary lease caps remain exact" do
    b = budget()
    g = gate(b, %{max_bytes: 20, max_active: 2})
    assert {:ok, lease} = Admission.acquire(g, 20, drain_notify: true)
    assert {:error, :byte_limit} = Admission.acquire(g, 1)
    assert :ok = Admission.begin_request(g, lease, 20, deadline())

    assert :ok =
             Admission.upgrade(g, lease, %{transport_bytes: 20, websocket_bytes: 30}, deadline())

    assert {:ok, _} = Admission.acquire(g, 0)
    assert {:error, :active_limit} = Admission.acquire(g, 0)
    assert %{usage: 50, transport_bytes: 20, websocket_bytes: 30, requests: 0} = snapshot(b)
  end

  test "committed credit repartitions repeatedly during drain without adding ownership" do
    b = budget()
    g = gate(b)
    original = %{retained_bytes: 20, temporary_bytes: 80, transport_bytes: 100}

    assert {:ok, lease} =
             Admission.acquire(g, original, kind: :connection, memberships: %{connection: :one})

    assert :ok =
             Admission.begin_request(
               g,
               lease,
               Map.put(original, :memberships, %{connection: :one}),
               deadline()
             )

    assert :ok = Admission.drain(g, deadline())

    for _ <- 1..3 do
      for {retained, temporary} <- [{70, 30}, {20, 80}] do
        accounting = %{retained_bytes: retained, temporary_bytes: temporary}

        assert :ok =
                 apply(Admission, :repartition_until, [
                   g,
                   lease,
                   accounting,
                   make_ref(),
                   deadline()
                 ])

        assert %{
                 usage: 100,
                 retained_bytes: ^retained,
                 temporary_bytes: ^temporary,
                 connections: 1,
                 requests: 1
               } = snapshot(b)

        if retained == 70 do
          replacement = Map.put(original, :memberships, %{connection: :one, request: lease})

          assert {:error, :draining} =
                   Admission.update_until(g, lease, replacement, make_ref(), deadline())
        end
      end
    end

    assert {:error, :credit_exceeded} =
             apply(Admission, :repartition_until, [
               g,
               lease,
               %{retained_bytes: 21, temporary_bytes: 80, transport_bytes: 101},
               make_ref(),
               deadline()
             ])

    assert {:error, :invalid_repartition} =
             apply(Admission, :repartition_until, [
               g,
               lease,
               %{pending_processes: 1},
               make_ref(),
               deadline()
             ])

    assert {:error, :invalid_repartition} =
             apply(Admission, :repartition_until, [
               g,
               lease,
               %{memberships: %{connection: :two}},
               make_ref(),
               deadline()
             ])

    assert {:error, :draining} = Admission.acquire(g, 0)

    assert %{usage: 100, retained_bytes: 20, temporary_bytes: 80, connections: 1, requests: 1} =
             snapshot(b)
  end

  test "repartition preserves deadline ownership and operation identity" do
    b = budget()
    g = gate(b)

    assert {:ok, lease} =
             Admission.acquire(g, %{retained_bytes: 20, temporary_bytes: 80, transport_bytes: 100})

    input = %{retained_bytes: 70, temporary_bytes: 30}
    operation = make_ref()
    expired = deadline() - 2000

    assert {:error, :deadline_exceeded} =
             apply(Admission, :repartition_until, [g, lease, input, make_ref(), expired])

    assert %{retained_bytes: 20, temporary_bytes: 80} = snapshot(b)
    assert :ok = apply(Admission, :repartition_until, [g, lease, input, operation, deadline()])
    assert :ok = apply(Admission, :repartition_until, [g, lease, input, operation, expired])

    assert {:error, :operation_conflict} =
             Admission.update_until(g, lease, input, operation, deadline())

    task =
      Task.async(fn ->
        apply(Admission, :repartition_until, [g, lease, input, make_ref(), deadline()])
      end)

    assert {:error, :stale_generation} = Task.await(task)
    assert %{usage: 100, retained_bytes: 70, temporary_bytes: 30} = snapshot(b)
  end

  test "repartition cannot increase the explicit transport category allowance" do
    b = budget()
    g = gate(b, %{max_bytes: 80})

    assert {:ok, lease} =
             Admission.acquire(g, %{
               retained_bytes: 20,
               temporary_bytes: 80,
               transport_bytes: 50,
               websocket_bytes: 50
             })

    assert :ok = Admission.drain(g, deadline())

    assert {:error, :byte_limit} =
             apply(Admission, :repartition_until, [
               g,
               lease,
               %{transport_bytes: 81, websocket_bytes: 19},
               make_ref(),
               deadline()
             ])

    assert :ok =
             apply(Admission, :repartition_until, [
               g,
               lease,
               %{transport_bytes: 80, websocket_bytes: 20},
               make_ref(),
               deadline()
             ])

    assert %{
             usage: 100,
             retained_bytes: 20,
             temporary_bytes: 80,
             transport_bytes: 80,
             websocket_bytes: 20
           } = snapshot(b)
  end

  test "legacy local gates also enforce their transport cap during repartition" do
    g =
      start_supervised!(
        {Admission,
         {%{max_active: 2, max_bytes: 50, callback_timeout: 5_000},
          %{instance: make_ref(), service: :legacy, generation: make_ref()}}}
      )

    assert {:ok, lease} = Admission.acquire(g, 50, drain_notify: true)
    assert :ok = Admission.begin_request(g, lease, 50, deadline())

    assert :ok =
             Admission.upgrade(g, lease, %{transport_bytes: 50, websocket_bytes: 50}, deadline())

    assert {:error, :byte_limit} =
             apply(Admission, :repartition_until, [
               g,
               lease,
               %{transport_bytes: 51, websocket_bytes: 49},
               make_ref(),
               deadline()
             ])

    assert %{transport_bytes: 50, websocket_bytes: 50} = Admission.status(g)
  end

  test "expired internal updates never execute while public queued update compatibility remains" do
    b = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 10)

    assert {:error, :deadline_exceeded} =
             apply(Admission, :update_until, [g, lease, 20, make_ref(), deadline() - 2000])

    assert %{usage: 10} = snapshot(b)
  end

  test "invalid acquire metadata fails before allocation" do
    b = budget()
    g = gate(b)
    assert {:error, :invalid_options} = Admission.acquire(g, 0, kind: :unknown)

    assert {:error, :invalid_membership} =
             Admission.acquire(g, 0, kind: :h2_stream, memberships: %{h2_stream: :one})

    assert %{usage: 0} = snapshot(b)
  end

  test "mode and drain fence shared mutations while reductions remain possible" do
    b = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 20)
    assert :ok = Admission.drain(g, deadline())
    assert {:error, :draining} = Admission.acquire(g, 0)
    assert :ok = Admission.update(g, lease, 10)
    assert %{usage: 10} = snapshot(b)
  end

  def worker(lease, observer, gate) do
    send(observer, {:worker_started, self(), lease, Admission.status(gate)})

    receive do
      :finish ->
        :ok

      {:end_request, bytes} ->
        result = Admission.end_request(gate, lease, bytes, deadline())
        send(observer, {:request_ended, result})

        receive do
          :finish -> :ok
        end
    end
  end

  defp eventually(fun, until \\ nil) do
    until = until || deadline()

    if fun.(),
      do: :ok,
      else:
        (
          assert System.monotonic_time(:millisecond) < until

          receive do
          after
            1 -> eventually(fun, until)
          end
        )
  end

  defp start_stream(gate, parent, kind, id) do
    request =
      Admission.spawn_request(
        gate,
        parent,
        make_ref(),
        20,
        deadline(),
        {__MODULE__, :worker, [self(), gate]},
        kind: kind,
        memberships: %{kind => {parent, id}, :request => make_ref()}
      )

    assert {:reply, {:ok, worker, lease}} = :gen_server.receive_response(request, 1000)
    assert_receive {:worker_started, ^worker, ^lease, _}
    {worker, lease}
  end

  def token_worker(_lease, observer, token) do
    send(observer, {:token_worker_started, self(), token})

    receive do
      :finish -> :ok
    end
  end

  defp token_spawn(gate, parent, token, kind, limit) do
    Admission.spawn_request(
      gate,
      parent,
      token,
      20,
      limit,
      {__MODULE__, :token_worker, [self(), token]},
      kind: kind,
      memberships: %{kind => {parent, 1}, :request => token}
    )
  end

  defp unobserved_stream(gate, parent, token, kind, limit) do
    assert :ok = :sys.suspend(gate)

    try do
      request = token_spawn(gate, parent, token, kind, limit)
      assert :timeout = :gen_server.receive_response(request, 0)
    after
      :ok = :sys.resume(gate)
    end

    assert_receive {:token_worker_started, worker, ^token}, 1000
    worker
  end

  defp cancellation_barrier(gate, token, phase) do
    observer = self()
    barrier = make_ref()

    debug = fn
      :armed, {:noreply, state}, _ ->
        case state.spawns[token] do
          %{worker: worker} ->
            continuation =
              if phase != :activated do
                receive do
                  {:activate_spawn, ^token} = message -> message
                after
                  1000 -> exit(:missing_activation_continuation)
                end
              end

            send(observer, {:spawn_bound, barrier, worker})

            receive do
              {:release_bound, ^barrier} -> :ok
            after
              1000 -> exit(:bound_barrier_timeout)
            end

            if continuation, do: send(self(), continuation)
            :cancel

          _ ->
            :armed
        end

      :cancel, {:out, :ok, _, state}, _ ->
        case state.spawns[token] do
          %{phase: :cancelled} ->
            send(observer, {:cancel_acknowledged, barrier})

            receive do
              {:release_cancel, ^barrier} -> :done
            after
              1000 -> exit(:cancel_barrier_timeout)
            end

          _ ->
            :cancel
        end

      current, _, _ ->
        current
    end

    assert :ok = :sys.install(gate, {barrier, debug, :armed})
    barrier
  end

  defp spawn_phase_flags(phase), do: {phase == :queued, phase == :activated}

  for kind <- [:h2_stream, :h3_stream], phase <- [:queued, :bound, :activated] do
    test "unobserved #{kind} #{phase} spawn retains caller-token cleanup ownership" do
      Process.flag(:trap_exit, true)
      kind = unquote(kind)
      phase = unquote(phase)
      {queued?, activated?} = spawn_phase_flags(phase)
      b = budget()
      g = gate(b)
      assert {:ok, parent} = Admission.acquire(g, 0)
      token = make_ref()
      proof = make_ref()
      limit = System.monotonic_time(:millisecond) + 5000
      barrier = cancellation_barrier(g, token, phase)
      if queued?, do: :sys.suspend(g)
      request = token_spawn(g, parent, token, kind, limit)
      queued_cancel = if queued?, do: Admission.cancel_spawn(g, parent, token)

      if queued? do
        assert :timeout = :gen_server.receive_response(request, 0)
        assert :ok = :sys.resume(g)
      end

      try do
        assert_receive {:spawn_bound, ^barrier, worker}, 1000
        monitor = Process.monitor(worker)

        if not queued? do
          assert :timeout = :gen_server.receive_response(request, 0)
        end

        cancel =
          if activated? do
            send(g, {:release_bound, barrier})
            assert_receive {:token_worker_started, ^worker, ^token}, 1000

            assert :ok =
                     apply(Admission, :finish_spawn_resources, [
                       g,
                       parent,
                       token,
                       proof,
                       deadline()
                     ])

            assert :ok = Admission.end_stream(g, parent, kind, 1, deadline())
            assert %{usage: 20, leases: 2} = snapshot(b)
            assert Process.alive?(worker)
            Admission.cancel_spawn(g, parent, token)
          else
            cancel = queued_cancel || Admission.cancel_spawn(g, parent, token)
            send(g, {:release_bound, barrier})
            cancel
          end

        assert {:reply, :ok} = :gen_server.receive_response(cancel, 1000)
        assert_receive {:cancel_acknowledged, ^barrier}, 1000
        # Even an acknowledged cancellation cannot refund an unprocessed terminal pair.
        assert %{usage: 20, leases: 2, legacy_leases: 2} = snapshot(b)
        repeated = Admission.cancel_spawn(g, parent, token)
        send(g, {:release_cancel, barrier})
        assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 1000
        assert {:reply, :ok} = :gen_server.receive_response(repeated, 1000)

        if not activated? do
          refute_receive {:token_worker_started, ^worker, ^token}, 0
          eventually(fn -> snapshot(b).legacy_leases == 1 end)
          assert %{usage: 20, leases: 2} = snapshot(b)
          assert :ok = Admission.end_stream(g, parent, kind, 1, deadline())
          assert %{usage: 20, requests: 0, h2_streams: 0, h3_streams: 0} = snapshot(b)

          assert :ok =
                   apply(Admission, :finish_spawn_resources, [g, parent, token, proof, deadline()])
        end

        eventually(fn -> snapshot(b).leases == 1 end)
        assert %{usage: 0, requests: 0, h2_streams: 0, h3_streams: 0} = snapshot(b)

        assert :ok =
                 apply(Admission, :finish_spawn_resources, [
                   g,
                   parent,
                   token,
                   proof,
                   deadline() - 2000
                 ])

        repeated = Admission.cancel_spawn(g, parent, token)
        assert {:reply, :ok} = :gen_server.receive_response(repeated, 1000)
        state = :sys.get_state(g)
        assert state.spawns == %{}
        assert state.stream_spawns == %{}
        assert map_size(state.update_receipts) <= 64
        assert :queue.len(state.update_order) <= 64
      after
        send(g, {:release_bound, barrier})
        send(g, {:release_cancel, barrier})
      end
    end
  end

  test "spawn-token proof authenticates binding and retains only bounded retry receipts" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    assert {:ok, wrong_parent} = Admission.acquire(g, 0)
    token = make_ref()
    _worker = unobserved_stream(g, parent, token, :h2_stream, deadline())
    observer = self()

    spawn(fn ->
      result =
        apply(Admission, :finish_spawn_resources, [g, parent, token, make_ref(), deadline()])

      send(observer, {:unowned_token_proof, result})
    end)

    assert_receive {:unowned_token_proof, {:error, :stale_generation}}

    assert {:error, :stale_generation} =
             apply(Admission, :finish_spawn_resources, [
               g,
               wrong_parent,
               token,
               make_ref(),
               deadline()
             ])

    assert {:error, :stale_generation} =
             apply(Admission, :finish_spawn_resources, [
               g,
               parent,
               make_ref(),
               make_ref(),
               deadline()
             ])

    proof = make_ref()

    assert {:error, :deadline_exceeded} =
             apply(Admission, :finish_spawn_resources, [
               g,
               parent,
               token,
               proof,
               deadline() - 2000
             ])

    assert :ok =
             apply(Admission, :finish_spawn_resources, [g, parent, token, proof, deadline()])

    assert {:error, :operation_conflict} =
             apply(Admission, :finish_spawn_resources, [g, parent, make_ref(), proof, deadline()])

    assert %{usage: 20} = snapshot(b)
    cancel = Admission.cancel_spawn(g, parent, token)
    assert {:reply, :ok} = :gen_server.receive_response(cancel, 1000)
    assert :ok = Admission.end_stream(g, parent, :h2_stream, 1, deadline())
    eventually(fn -> snapshot(b).leases == 2 end)
    assert %{usage: 0} = snapshot(b)

    for _ <- 1..70 do
      cancel = Admission.cancel_spawn(g, parent, token)
      assert {:reply, :ok} = :gen_server.receive_response(cancel, 1000)
    end

    assert :queue.len(:sys.get_state(g).update_order) == 2

    reused = token_spawn(g, parent, token, :h2_stream, deadline())
    assert {:reply, {:error, :invalid_spawn_request}} = :gen_server.receive_response(reused, 1000)

    for _ <- 1..70 do
      assert :ok = Admission.update_until(g, parent, 0, make_ref(), deadline())
    end

    state = :sys.get_state(g)
    assert state.stream_spawns == %{}
    assert map_size(state.update_receipts) == 64
    assert :queue.len(state.update_order) == 64
    cancel = Admission.cancel_spawn(g, parent, token)
    assert {:reply, {:error, :stale_generation}} = :gen_server.receive_response(cancel, 1000)
    assert %{usage: 0, leases: 2} = snapshot(b)
  end

  test "cancelled activated token retains output and independent guardian until their proofs" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    token = make_ref()
    limit = deadline()
    worker = unobserved_stream(g, parent, token, :h3_stream, limit)
    # Service-side fixture instrumentation supplies its attachment lease; all
    # cancellation and output cleanup below use only the caller-known spawn token.
    lease = :sys.get_state(g).spawns[token].lease

    guardian =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(guardian), do: Process.exit(guardian, :kill) end)
    cleanup = make_ref()
    assert :ok = Admission.attach_cleanup(g, worker, lease, guardian, 5, limit, cleanup)
    cancel = Admission.cancel_spawn(g, parent, token)
    assert {:reply, :ok} = :gen_server.receive_response(cancel, 1000)
    eventually(fn -> :sys.get_state(g).spawns == %{} end)
    assert :ok = Admission.end_stream(g, parent, :h3_stream, 1, deadline())
    assert %{usage: 25, leases: 3} = snapshot(b)

    assert :ok =
             apply(Admission, :finish_spawn_resources, [g, parent, token, make_ref(), deadline()])

    eventually(fn -> snapshot(b).usage == 5 end)
    assert %{cleanup_pending: 1} = Admission.status(g)
    assert :ok = Admission.complete_cleanup(g, cleanup)
    assert %{usage: 5, leases: 2} = snapshot(b)
    send(guardian, :finish)
    eventually(fn -> snapshot(b).usage == 0 end)
    assert %{cleanup_pending: 0} = Admission.status(g)
    assert %{usage: 0, leases: 1} = snapshot(b)
    assert :sys.get_state(g).stream_spawns == %{}
  end

  test "worker credit transfers before activation and terminal pair retains the same nonlegacy stream token" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b, %{max_active: 2, max_streams: 1})

    assert {:ok, parent} =
             Admission.acquire(g, 10, kind: :connection, memberships: %{connection: :parent})

    request =
      Admission.spawn_request(
        g,
        parent,
        make_ref(),
        20,
        deadline(),
        {__MODULE__, :worker, [self(), g]},
        kind: :h2_stream,
        memberships: %{request: :request, h2_stream: {parent, 1}}
      )

    assert {:reply, {:ok, worker, lease}} = :gen_server.receive_response(request, 1000)
    assert_receive {:worker_started, ^worker, ^lease, %{active: 2, retained_bytes: 30}}

    assert %{usage: 30, pending_processes: 0, requests: 1, h2_streams: 1, legacy_leases: 2} =
             snapshot(b)

    assert {:ok, client} = Admission.budget_client(g)
    assert {:ok, page} = ResourceBudget.allocations(client)
    original = Enum.find(page.allocations, &(&1.kind == :h2_stream))
    monitor = Process.monitor(worker)
    send(worker, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}
    eventually(fn -> snapshot(b).legacy_leases == 1 end)
    assert %{usage: 30, requests: 0, h2_streams: 1, leases: 2} = snapshot(b)
    assert {:ok, page} = ResourceBudget.allocations(client)
    retained = Enum.find(page.allocations, &(&1.kind == :stream_retention))
    assert retained.token == original.token
    assert retained.owner == self()
    assert retained.revision == original.revision + 1
    assert {:ok, _} = Admission.acquire(g, 0, kind: :writer)
    assert :ok = Admission.end_stream(g, parent, :h2_stream, 1, deadline())
    assert %{usage: 30, requests: 0, h2_streams: 0} = snapshot(b)

    assert :ok =
             apply(Admission, :finish_stream_resources, [g, parent, lease, make_ref(), deadline()])

    eventually(fn -> snapshot(b).usage == 10 end)
  end

  test "stream end is independent of live worker and request-end bytes" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)

    assert {:ok, parent} =
             Admission.acquire(g, 10, kind: :connection, memberships: %{connection: :parent})

    request =
      Admission.spawn_request(
        g,
        parent,
        make_ref(),
        20,
        deadline(),
        {__MODULE__, :worker, [self(), g]},
        kind: :h3_stream,
        memberships: %{request: :request, h3_stream: {parent, 2}}
      )

    assert {:reply, {:ok, worker, lease}} = :gen_server.receive_response(request, 1000)
    assert_receive {:worker_started, ^worker, ^lease, _}
    assert :ok = Admission.end_stream(g, parent, :h3_stream, 2, deadline())
    assert Process.alive?(worker)
    assert %{usage: 30, requests: 1, h3_streams: 0} = snapshot(b)
    send(worker, {:end_request, 12})
    assert_receive {:request_ended, :ok}
    assert %{usage: 22, requests: 0, h3_streams: 0} = snapshot(b)

    assert :ok =
             apply(Admission, :finish_stream_resources, [g, parent, lease, make_ref(), deadline()])

    assert %{usage: 22} = snapshot(b)
    send(worker, :finish)
    eventually(fn -> snapshot(b).leases == 1 end)
    assert %{usage: 10} = snapshot(b)
  end

  for {kind, ordering} <- [
        {:h2_stream, [:resources, :stream, :worker]},
        {:h3_stream, [:resources, :worker, :stream]},
        {:h2_stream, [:stream, :resources, :worker]},
        {:h3_stream, [:stream, :worker, :resources]},
        {:h2_stream, [:worker, :resources, :stream]},
        {:h3_stream, [:worker, :stream, :resources]}
      ] do
    counter = if kind == :h2_stream, do: :h2_streams, else: :h3_streams

    test "stream terminal boundaries converge for #{kind} #{inspect(ordering)}" do
      Process.flag(:trap_exit, true)
      kind = unquote(kind)
      stream_counter = unquote(counter)
      b = budget()
      g = gate(b)
      assert {:ok, parent} = Admission.acquire(g, 0)
      {worker, lease} = start_stream(g, parent, kind, 1)
      monitor = Process.monitor(worker)
      assert {:ok, client} = Admission.budget_client(g)
      assert {:ok, page} = ResourceBudget.allocations(client)
      original = Enum.find(page.allocations, &(&1.kind == kind))
      operation = make_ref()

      Enum.reduce(unquote(ordering), MapSet.new(), fn event, completed ->
        case event do
          :resources ->
            assert :ok =
                     apply(Admission, :finish_stream_resources, [
                       g,
                       parent,
                       lease,
                       operation,
                       deadline()
                     ])

          :stream ->
            assert :ok = Admission.end_stream(g, parent, kind, 1, deadline())

          :worker ->
            send(worker, :finish)
            assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}
            eventually(fn -> :sys.get_state(g).spawns == %{} end)
        end

        completed = MapSet.put(completed, event)
        worker_done = MapSet.member?(completed, :worker)
        memory_done = worker_done and MapSet.member?(completed, :resources)
        stream_done = MapSet.member?(completed, :stream)
        expected_usage = if memory_done, do: 0, else: 20
        expected_leases = if memory_done and stream_done, do: 1, else: 2
        expected_streams = if stream_done, do: 0, else: 1
        expected_legacy = if worker_done, do: 1, else: 2

        eventually(fn ->
          observed = snapshot(b)

          observed.usage == expected_usage and observed.leases == expected_leases and
            observed[stream_counter] == expected_streams and
            observed.legacy_leases == expected_legacy
        end)

        unless worker_done, do: assert(Process.alive?(worker))
        assert {:ok, page} = ResourceBudget.allocations(client)
        row = Enum.find(page.allocations, &(&1.token == original.token))

        if memory_done and stream_done do
          assert row == nil
        else
          assert row.token == original.token
          assert row.accounting.retained_bytes == expected_usage
        end

        completed
      end)

      assert %{usage: 0, h2_streams: 0, h3_streams: 0, requests: 0, leases: 1} = snapshot(b)

      assert :ok =
               apply(Admission, :finish_stream_resources, [
                 g,
                 parent,
                 lease,
                 operation,
                 deadline() - 2000
               ])
    end
  end

  test "stream memory terminal proof authenticates parent binding and operation identity" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)
    assert {:ok, first_parent} = Admission.acquire(g, 0)
    assert {:ok, other_parent} = Admission.acquire(g, 0)
    {first_worker, first_lease} = start_stream(g, first_parent, :h2_stream, 1)
    {other_worker, other_lease} = start_stream(g, other_parent, :h2_stream, 2)
    observer = self()

    spawn(fn ->
      result =
        apply(Admission, :finish_stream_resources, [
          g,
          first_parent,
          first_lease,
          make_ref(),
          deadline()
        ])

      send(observer, {:foreign_finish, result})
    end)

    assert_receive {:foreign_finish, {:error, :stale_generation}}

    assert {:error, :stale_generation} =
             apply(Admission, :finish_stream_resources, [
               g,
               other_parent,
               first_lease,
               make_ref(),
               deadline()
             ])

    assert {:error, :stale_generation} =
             apply(Admission, :finish_stream_resources, [
               g,
               first_parent,
               other_lease,
               make_ref(),
               deadline()
             ])

    operation = make_ref()

    assert :ok =
             apply(Admission, :finish_stream_resources, [
               g,
               first_parent,
               first_lease,
               operation,
               deadline()
             ])

    assert :ok =
             apply(Admission, :finish_stream_resources, [
               g,
               first_parent,
               first_lease,
               operation,
               deadline() - 2000
             ])

    assert {:error, :operation_conflict} =
             apply(Admission, :finish_stream_resources, [
               g,
               other_parent,
               other_lease,
               operation,
               deadline()
             ])

    assert %{usage: 40, leases: 4, h2_streams: 2} = snapshot(b)
    assert Process.alive?(first_worker) and Process.alive?(other_worker)

    assert :ok =
             apply(Admission, :finish_stream_resources, [
               g,
               other_parent,
               other_lease,
               make_ref(),
               deadline()
             ])

    assert :ok = Admission.end_stream(g, first_parent, :h2_stream, 1, deadline())
    assert :ok = Admission.end_stream(g, other_parent, :h2_stream, 2, deadline())
    send(first_worker, :finish)
    send(other_worker, :finish)
    eventually(fn -> snapshot(b).leases == 2 end)
    assert %{usage: 0, h2_streams: 0, requests: 0} = snapshot(b)
  end

  test "stream memory completion preserves independent guardian charges until terminal receipt" do
    Process.flag(:trap_exit, true)
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 0)
    {worker, lease} = start_stream(g, parent, :h3_stream, 1)

    guardian =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(guardian), do: Process.exit(guardian, :kill) end)
    token = make_ref()
    request_deadline = :sys.get_state(g).leases[lease].deadline
    assert :ok = Admission.attach_cleanup(g, worker, lease, guardian, 5, request_deadline, token)

    assert :ok =
             apply(Admission, :finish_stream_resources, [g, parent, lease, make_ref(), deadline()])

    assert %{usage: 25} = snapshot(b)
    assert :ok = Admission.end_stream(g, parent, :h3_stream, 1, deadline())
    send(worker, :finish)
    eventually(fn -> snapshot(b).usage == 5 end)
    assert %{usage: 5, leases: 2} = snapshot(b)
    assert %{cleanup_pending: 1} = Admission.status(g)
    assert :ok = Admission.complete_cleanup(g, token)
    assert %{usage: 5} = snapshot(b)
    send(guardian, :finish)
    eventually(fn -> snapshot(b).usage == 0 end)
    assert %{cleanup_pending: 0} = Admission.status(g)
    assert %{usage: 0, leases: 1, h3_streams: 0} = snapshot(b)
  end

  test "another caller cannot end a parent's stream" do
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 10)
    observer = self()

    spawn(fn ->
      send(observer, {:ended, Admission.end_stream(g, parent, :h2_stream, 1, deadline())})
    end)

    assert_receive {:ended, {:error, :stale_generation}}
    assert %{usage: 10} = snapshot(b)
  end

  test "expired spawn reserves no memory or process slot and cannot enter callback" do
    b = budget()
    g = gate(b)
    assert {:ok, parent} = Admission.acquire(g, 10)

    request =
      Admission.spawn_request(
        g,
        parent,
        make_ref(),
        20,
        deadline() - 2000,
        {__MODULE__, :worker, [self(), g]}
      )

    assert {:reply, {:error, :deadline_exceeded}} = :gen_server.receive_response(request, 1000)
    refute_receive {:worker_started, _, _, _}, 0
    assert %{usage: 10, pending_processes: 0, leases: 1} = snapshot(b)
  end

  test "ambiguous reservation retains sequence and never creates an unconfirmed lease" do
    b = {server, _} = budget()
    g = gate(b)
    assert :ok = :sys.suspend(server)

    try do
      assert {:error, :budget_timeout} = Admission.acquire(g, 10)
      state = :sys.get_state(g)
      assert state.budget.pending.sequence == 1
      assert state.leases == %{}
      assert {:error, :budget_pending} = Admission.acquire(g, 10)
    after
      :ok = :sys.resume(server)
    end

    eventually(fn -> :sys.get_state(g).budget.pending == nil end)
    assert %{usage: 0, leases: 0} = snapshot(b)
    assert {:ok, _} = Admission.acquire(g, 10)
    assert %{usage: 10, leases: 1} = snapshot(b)
  end

  test "update identity returns confirmed result after deadline and rejects conflicting reuse" do
    b = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 10)
    operation = make_ref()
    assert :ok = Admission.update_until(g, lease, 20, operation, deadline())
    assert {:ok, client} = Admission.budget_client(g)
    assert {:ok, before} = ResourceBudget.allocations(client)
    assert :ok = Admission.update_until(g, lease, 20, operation, deadline() - 2000)
    assert {:ok, after_retry} = ResourceBudget.allocations(client)
    assert before == after_retry

    assert {:error, :operation_conflict} =
             Admission.update_until(g, lease, 21, operation, deadline())

    assert %{usage: 20} = snapshot(b)
  end

  test "ambiguous update retains its terminal rejection for identical retries" do
    b = {server, _} = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 10)
    assert {:ok, client} = Admission.budget_client(g)
    assert {:ok, before} = ResourceBudget.allocations(client)
    operation = make_ref()
    assert :ok = :sys.suspend(server)

    try do
      limit = System.monotonic_time(:millisecond) + 20

      assert {:error, :budget_timeout} =
               Admission.update_until(g, lease, 20, operation, limit)

      state = :sys.get_state(g)
      assert state.budget.pending.deadline == limit
      assert elem(state.update_pending, 0) == operation
      assert System.monotonic_time(:millisecond) >= limit
    after
      :ok = :sys.resume(server)
    end

    eventually(fn -> :sys.get_state(g).budget.pending == nil end)

    assert {:error, :deadline_exceeded} =
             Admission.update_until(g, lease, 20, operation, deadline())

    assert {:error, :deadline_exceeded} =
             Admission.update_until(g, lease, 20, operation, deadline() - 2000)

    assert {:error, :operation_conflict} =
             Admission.update_until(g, lease, 21, operation, deadline())

    assert :sys.get_state(g).update_pending == nil
    assert {:ok, after_retry} = ResourceBudget.allocations(client)
    assert after_retry.allocations == before.allocations
    assert %{usage: 10} = snapshot(b)
    assert :ok = Admission.update_until(g, lease, 30, make_ref(), deadline())
    assert %{usage: 30} = snapshot(b)
  end

  test "a competing update cannot clear pending identity or cache a transient rejection" do
    b = {server, _} = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 10)
    operation = make_ref()
    competing = make_ref()
    assert :ok = :sys.suspend(server)

    try do
      assert {:error, :budget_timeout} =
               Admission.update_until(
                 g,
                 lease,
                 20,
                 operation,
                 System.monotonic_time(:millisecond) + 20
               )

      pending = :sys.get_state(g).update_pending

      assert {:error, :budget_pending} =
               Admission.update_until(g, lease, 30, competing, deadline())

      state = :sys.get_state(g)
      assert state.update_pending == pending
      refute Map.has_key?(state.update_receipts, competing)

      assert {:error, :operation_conflict} =
               Admission.update_until(g, lease, 21, operation, deadline())
    after
      :ok = :sys.resume(server)
    end

    eventually(fn -> :sys.get_state(g).budget.pending == nil end)

    assert {:error, :deadline_exceeded} =
             Admission.update_until(g, lease, 20, operation, deadline())

    assert :ok = Admission.update_until(g, lease, 30, competing, deadline())
    assert %{usage: 30} = snapshot(b)
  end

  test "cleanup is nonlegacy and normal DOWN without receipt remains charged" do
    b = budget()
    g = gate(b, %{max_active: 1})
    assert {:ok, lease} = Admission.acquire(g, 10, drain_notify: true)
    d = deadline()
    assert :ok = Admission.begin_request(g, lease, 10, d)

    guardian =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    token = make_ref()
    assert :ok = Admission.attach_cleanup(g, self(), lease, guardian, 5, d, token)
    assert %{usage: 15, leases: 2, legacy_leases: 1} = snapshot(b)
    send(guardian, :finish)
    eventually(fn -> :sys.get_state(g).mode == :failed end)
    assert %{usage: 15, leases: 2} = snapshot(b)
    assert %{cleanup_pending: 1} = Admission.status(g)
  end

  test "cleanup releases only after receipt and normal terminal boundary" do
    b = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 10, drain_notify: true)
    d = deadline()
    assert :ok = Admission.begin_request(g, lease, 10, d)

    guardian =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    token = make_ref()
    assert :ok = Admission.attach_cleanup(g, self(), lease, guardian, 5, d, token)
    assert :ok = Admission.complete_cleanup(g, token)
    assert %{usage: 15} = snapshot(b)
    send(guardian, :finish)
    eventually(fn -> snapshot(b).usage == 10 end)
    assert %{cleanup_pending: 0} = Admission.status(g)
  end

  test "gate-loss reconciler binds guardian receipt to exact canonical token" do
    b = {server, instance} = budget()
    g = gate(b)
    assert {:ok, client} = Admission.budget_client(g)

    guardian =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    assert {:ok, a} = ResourceBudget.reserve(client, guardian, :guardian, 5, 1, deadline())
    assert {:ok, c} = ResourceBudget.reserve(client, guardian, :guardian, 7, 2, deadline())
    monitor = Process.monitor(g)
    Process.exit(g, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^g, :killed}
    monitor = Process.monitor(guardian)
    send(guardian, :finish)
    assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}
    context = %{server: server, instance: instance, service: client.service, client: client}

    assert {:error, :cleanup_unconfirmed} =
             Gaoxy.Admission.Reconciler.finish(context, g, %{a.token => :normal}, deadline())

    assert %{usage: 7, leases: 1} = snapshot(b)
    assert {:ok, %{allocations: [%{token: token}]}} = ResourceBudget.allocations(client)
    assert token == c.token

    assert {:ok, _} =
             Gaoxy.Admission.Reconciler.finish(context, g, %{c.token => :normal}, deadline())

    assert %{usage: 0, leases: 0} = snapshot(b)
  end

  test "gate-loss page reads respect cleanup deadline and retain uncertain allocations" do
    Process.flag(:trap_exit, true)
    b = {server, instance} = budget()
    g = gate(b)
    assert {:ok, _lease} = Admission.acquire(g, 10)
    assert {:ok, client} = Admission.budget_client(g)
    assert {:ok, before} = ResourceBudget.allocations(client)
    monitor = Process.monitor(g)
    Process.exit(g, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^g, :killed}
    context = %{server: server, instance: instance, service: client.service, client: client}
    assert :ok = :sys.suspend(server)

    {result, elapsed} =
      try do
        started = System.monotonic_time(:millisecond)

        result =
          Gaoxy.Admission.Reconciler.finish(context, g, %{}, started + 100, false)

        {result, System.monotonic_time(:millisecond) - started}
      after
        :ok = :sys.resume(server)
      end

    assert {:error, :budget_timeout} = result
    assert %{usage: 10, leases: 1} = snapshot(b)
    assert {:ok, after_retry} = ResourceBudget.allocations(client)
    assert after_retry.allocations == before.allocations
    assert elapsed < 250
  end

  test "begin retain adjust and send paths retain canonical ownership" do
    b = budget()
    g = gate(b)
    assert {:ok, lease} = Admission.acquire(g, 10)
    assert :ok = Admission.begin(g, lease, 20)
    assert %{usage: 20} = snapshot(b)
    assert :ok = Admission.retain(g, lease, 15)
    assert :ok = Admission.adjust_bytes(g, lease, 3)
    assert {:ok, operation} = Admission.start_send(g, lease, 5)
    assert %{usage: 18} = snapshot(b)
    assert :ok = Admission.finish_send(g, lease, operation, :ok)
    assert %{usage: 18} = snapshot(b)
    assert :ok = Admission.update(g, lease, 12)
    assert %{usage: 12} = snapshot(b)
  end

  defmodule RejectPrepare do
    def prepare_service(_, _), do: {:error, :controlled_preflight}
  end

  test "pre-gate service failure retires its registration without an Instance callback" do
    Process.flag(:trap_exit, true)
    b = {server, instance} = budget()
    table = :ets.new(:pre_gate, [:set, :public])
    live = :ets.new(:pre_gate_live, [:set, :public])

    spec = %{
      id: :pre_gate,
      handler_mode: :datagram_dispatcher,
      handler: RejectPrepare,
      handler_options: %{},
      limits: %{callback_timeout: 100},
      budget_policy: %{max_connections: 1, max_requests: 1, max_streams: 1}
    }

    :ets.insert(table, {:pre_gate, spec})

    context = %{
      telemetry_scope: make_ref(),
      instance_pid: self(),
      budget: %{server: server, instance: instance}
    }

    assert {:error, {:handler_preflight, :controlled_preflight}} =
             Gaoxy.Service.start_link({table, live, :pre_gate, context})

    assert %{usage: 0, leases: 0} = snapshot(b)

    ledger =
      Gaoxy.ResourceBudget.Supervisor.name(
        Gaoxy.ResourceBudget.Ledger,
        elem(server, 1) |> elem(2)
      )

    assert :sys.get_state(ledger).services == %{}
  end

  test "empty production instance exposes public snapshot and retires its scope" do
    assert {:ok, instance} =
             Gaoxy.start_link(services: [], resource_budget: %{soft_limit: 101, hard_limit: 202})

    context = GenServer.call(instance, :resource_budget_context)

    assert %{usage: 0, soft_limit: 101, hard_limit: 202, mode: :ready} =
             Gaoxy.resource_budget(instance)

    assert :ok = Gaoxy.stop(instance, 1000)
    assert {:error, :unknown_instance} = ResourceBudget.snapshot(context.server, context.instance)
  end

  test "connection quota is independent from ordinary writers" do
    b = budget()
    g = gate(b, %{max_connections: 1})
    assert {:ok, _} = Admission.acquire(g, 0, kind: :writer)
    assert {:ok, _} = Admission.acquire(g, 0, kind: :connection, memberships: %{connection: :one})

    assert {:error, :connection_limit} =
             Admission.acquire(g, 0, kind: :connection, memberships: %{connection: :two})

    assert %{connections: 1, leases: 2} = snapshot(b)
  end
end
