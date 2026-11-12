defmodule Gaoxy.AdmissionHeadroomTest do
  use ExUnit.Case, async: false
  @moduletag :component
  alias Gaoxy.{Admission, ResourceBudget}

  @capacity 1_000_000_000
  # Safety keeps max(16 MiB, capacity / 20) in reserve below available memory.
  @safety_reserve div(@capacity, 20)

  defp deadline, do: System.monotonic_time(:millisecond) + 1000

  defp budget(options \\ []) do
    identity = make_ref()
    available = Keyword.get(options, :available_bytes, @capacity)

    start_supervised!(
      {Gaoxy.ResourceBudget.Supervisor,
       identity: identity,
       capacity_probe: fn -> %{capacity: @capacity, fallback?: false, source: :controlled} end,
       safety_probe: fn _ ->
         {:ok,
          %{
            available_bytes: available,
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
               Keyword.get(options, :instance, %{soft_limit: 100, hard_limit: 200}),
               deadline()
             )

    {server, instance}
  end

  defp gate(budget, policy \\ %{}) do
    id = make_ref()

    scope = %{
      instance: make_ref(),
      service: id,
      generation: make_ref(),
      service_pid: self()
    }

    scope =
      case budget do
        nil ->
          scope

        {server, instance} ->
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

          Map.put(scope, :budget, %{server: server, instance: instance, service: service})
      end

    gate =
      start_supervised!(
        Supervisor.child_spec(
          {Admission, {%{max_active: 4, max_bytes: 100, callback_timeout: 5000}, scope}},
          id: id,
          restart: :temporary
        )
      )

    {gate, rejections(id)}
  end

  # Collects every Admission and ledger rejection reported for one service.
  defp rejections(service) do
    owner = self()
    reference = make_ref()

    :ok =
      :telemetry.attach_many(
        reference,
        [[:gaoxy, :admission_rejected], [:gaoxy, :resource_budget_rejected]],
        fn event, _, metadata, _ ->
          if metadata[:service] == service, do: send(owner, {reference, event, metadata.reason})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(reference) end)
    reference
  end

  defp snapshot({server, instance}), do: ResourceBudget.snapshot(server, instance)
  defp sequence(gate), do: :sys.get_state(gate).budget.sequence
  defp connection, do: [kind: :connection, memberships: %{connection: make_ref()}]

  defp eventually(fun, until \\ nil) do
    until = until || deadline()

    if fun.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < until, "condition deadline"

      receive do
      after
        1 -> eventually(fun, until)
      end
    end
  end

  test "headroom is funded as temporary transport credit when capacity allows" do
    b = budget()
    {g, events} = gate(b)

    assert {:ok, lease, 14} = Admission.acquire_funded(g, 4, [headroom: 10] ++ connection())
    assert sequence(g) == 2

    assert %{usage: 14, retained_bytes: 4, temporary_bytes: 10, transport_bytes: 14} =
             snapshot(b)

    # The funded total keeps the input retained and the allowance temporary.
    assert :ok = Admission.begin(g, lease, 14)
    assert %{retained_bytes: 4, temporary_bytes: 10, transport_bytes: 14} = snapshot(b)
    assert %{rejected: 0} = Admission.status(g)
    refute_received {^events, _, _}
  end

  for {name, options, policy, input, headroom, reason} <- [
        {"service byte", [], %{max_bytes: 6}, 4, 4, :byte_limit},
        {"instance hard", [], %{}, 150, 100, :memory_hard_limit},
        {"system safety",
         [
           available_bytes: @safety_reserve + 100,
           instance: %{soft_limit: 1_000, hard_limit: 2_000}
         ], %{}, 50, 100, :system_memory_pressure}
      ] do
    test "headroom over the #{name} limit silently falls back to the exact input" do
      input = unquote(input)
      headroom = unquote(headroom)
      reason = unquote(reason)
      b = budget(unquote(Macro.escape(options)))
      {g, events} = gate(b, unquote(Macro.escape(policy)))

      assert {:ok, lease, ^input} =
               Admission.acquire_funded(g, input, [headroom: headroom] ++ connection())

      # The probe used its own canonical operation before the exact reservation.
      assert sequence(g) == 3

      assert %{usage: ^input, retained_bytes: ^input, temporary_bytes: 0, rejections: rejected} =
               snapshot(b)

      assert rejected == %{}
      assert %{rejected: 0, active: 1} = Admission.status(g)
      refute_received {^events, _, _}

      # The silent probe reason is the definite outcome of the same growth.
      assert {:error, ^reason} = Admission.update(g, lease, input + headroom)
      assert_receive {^events, [:gaoxy, :admission_rejected], ^reason}, 1_000
      assert_receive {^events, [:gaoxy, :resource_budget_rejected], ^reason}, 1_000
      refute_received {^events, _, _}
      assert %{rejections: %{^reason => 1}} = snapshot(b)
      assert %{rejected: 1} = Admission.status(g)
    end
  end

  test "count, mode and lease rejections are definite and never retried exactly" do
    b = budget()
    {g, events} = gate(b, %{max_connections: 1})
    assert {:ok, _, 10} = Admission.acquire_funded(g, 5, [headroom: 5] ++ connection())
    assert sequence(g) == 2

    assert {:error, :connection_limit} =
             Admission.acquire_funded(g, 5, [headroom: 5] ++ connection())

    assert sequence(g) == 3
    assert %{rejected: 1, active: 1} = Admission.status(g)
    assert %{rejections: %{connection_limit: 1}} = snapshot(b)
    assert_received {^events, [:gaoxy, :admission_rejected], :connection_limit}
    assert_received {^events, [:gaoxy, :resource_budget_rejected], :connection_limit}
    refute_received {^events, _, _}

    assert :ok = Admission.drain(g, deadline())
    drained = sequence(g)
    assert {:error, :draining} = Admission.acquire_funded(g, 0, headroom: 5)
    assert sequence(g) == drained
    assert %{rejected: 2} = Admission.status(g)
    assert_received {^events, [:gaoxy, :admission_rejected], :draining}
    refute_received {^events, _, _}
  end

  test "an ambiguous headroom probe stays pending and is not retried exactly" do
    b = {server, _} = budget()
    {g, events} = gate(b)
    assert :ok = :sys.suspend(server)

    try do
      assert {:error, :budget_timeout} =
               Admission.acquire_funded(g, 10, [headroom: 5] ++ connection())

      state = :sys.get_state(g)
      assert %{name: :reserve_optional, sequence: 1} = state.budget.pending
      assert state.leases == %{}
      assert %{rejected: 1} = Admission.status(g)
      assert_received {^events, [:gaoxy, :admission_rejected], :budget_timeout}

      assert {:error, :budget_pending} =
               Admission.acquire_funded(g, 10, [headroom: 5] ++ connection())
    after
      :ok = :sys.resume(server)
    end

    # The late probe either commits and is released as unused or definitely
    # expires; either way no exact reservation follows the ambiguous probe.
    eventually(fn -> :sys.get_state(g).budget.pending == nil end)
    eventually(fn -> snapshot(b).leases == 0 end)
    assert %{usage: 0, rejections: rejected} = snapshot(b)
    refute Enum.any?(Map.keys(rejected), &ResourceBudget.capacity_reason?/1)
    assert :sys.get_state(g).leases == %{}
    # Only the ambiguous probe and the pending retry were reported.
    assert %{rejected: 2} = Admission.status(g)
  end

  test "funded datagram output repartitions during drain while growth stays fenced" do
    b = budget()
    {g, events} = gate(b)
    assert {:ok, lease, 10} = Admission.acquire_funded(g, 4, [headroom: 6] ++ connection())
    assert :ok = Admission.begin(g, lease, 10)
    assert :ok = Admission.drain(g, deadline())

    assert :ok =
             Admission.repartition_until(
               g,
               lease,
               %{retained_bytes: 9, temporary_bytes: 1, transport_bytes: 10},
               make_ref(),
               deadline()
             )

    assert %{usage: 10, retained_bytes: 9, temporary_bytes: 1, transport_bytes: 10} =
             snapshot(b)

    refute_received {^events, _, _}

    # Without funded credit, the same reply is new growth and drain rejects it.
    assert {:error, :draining} = Admission.update(g, lease, 11)
    assert %{usage: 10} = snapshot(b)
  end

  test "legacy gates, zero headroom and invalid headroom keep exact acquire behavior" do
    {legacy, _} = gate(nil)
    assert {:ok, lease, 4} = Admission.acquire_funded(legacy, 4, headroom: 10)
    assert %{usage: 4, temporary_bytes: 0} = Admission.status(legacy)
    assert :ok = Admission.begin(legacy, lease, 4)
    assert {:ok, _} = Admission.acquire(legacy, 4, headroom: 10)

    b = budget()
    {g, _} = gate(b)
    assert {:ok, _, 4} = Admission.acquire_funded(g, 4, headroom: 0)
    assert sequence(g) == 2
    assert %{usage: 4, temporary_bytes: 0} = snapshot(b)

    for headroom <- [-1, :all, 1.5] do
      assert {:error, :invalid_options} = Admission.acquire_funded(g, 4, headroom: headroom)
    end

    assert {:error, :invalid_options} = Admission.acquire_funded(g, 4, headroom: 1, headroom: 1)
    assert sequence(g) == 2
  end
end
