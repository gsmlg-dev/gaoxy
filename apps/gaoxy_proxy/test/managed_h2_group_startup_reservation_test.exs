unless Code.ensure_loaded?(Gaoxy.Proxy.ManagedH2FixedFixture) do
  Code.require_file("managed_h2_fixed_endpoint_test.exs", __DIR__)
end

Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupStartupReservationTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias Gaoxy.Proxy.{HTTP, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.HTTP.Session
  alias Elixir.HTTP.RequestCompletion
  @startup 5_963_776

  defmodule BudgetEndpoint do
    def init(options) do
      {available, options} = Map.pop(options, :startup_available)
      {observer, options} = Map.pop(options, :budget_observer)

      with {:ok, endpoint} <- Gaoxy.Proxy.GroupEndpoint.init(options),
           do: {:ok, {endpoint, available, observer}}
    end

    def resources({endpoint, _, _}), do: Gaoxy.Proxy.GroupEndpoint.resources(endpoint)

    def call(exchange, {endpoint, available, observer}) do
      # Native H2 owns a separate connection reservation. Fill the actual
      # authenticated request lease to test identical remaining capacity on
      # both downstream protocols without changing native H2's budget gate.
      before = Gaoxy.Admission.status(exchange.gate)
      limit = 1_073_741_824
      filler = limit - before.retained_bytes - available
      :ok = Gaoxy.Admission.adjust_bytes(exchange.gate, exchange.lease, filler)
      send(observer, {:startup_budget, exchange.lease, filler, before.retained_bytes})

      # Native writes update the lease from Exchange's retained byte fields.
      # Keep this genuine test-owned reservation represented across that update.
      padded = %{exchange | route_bytes: exchange.route_bytes + filler}

      result =
        try do
          Gaoxy.Proxy.GroupEndpoint.call(padded, endpoint)
        after
          :ok = Gaoxy.Admission.adjust_bytes(exchange.gate, exchange.lease, -filler)
          send(observer, {:startup_budget_refunded, exchange.lease, filler})
        end

      case result do
        {:ok, next} ->
          {:ok, %{next | route_bytes: next.route_bytes - filler}}

        {:error, reason, next} ->
          {:error, reason, %{next | route_bytes: next.route_bytes - filler}}
      end
    end
  end

  defmodule ObservedEndpoint do
    def init(options) do
      {observer, options} = Map.pop(options, :startup_observer)

      with {:ok, endpoint} <- Gaoxy.Proxy.GroupEndpoint.init(options),
           do: {:ok, {endpoint, observer}}
    end

    def resources({endpoint, _}), do: Gaoxy.Proxy.GroupEndpoint.resources(endpoint)

    def call(exchange, {endpoint, observer}) do
      send(
        observer,
        {:positive_startup_before, self(), exchange.lease, :sys.get_state(exchange.gate)}
      )

      Gaoxy.Proxy.GroupEndpoint.call(exchange, endpoint)
    end
  end

  for protocol <- [:http2, :h2c], downstream <- [:http1, :http2] do
    test "#{downstream} to #{protocol} successful attach retains startup until helper return then refunds exactly once" do
      f =
        G.fixture(unquote(protocol), unquote(downstream), ["--manual"], %{
          endpoint_module: ObservedEndpoint,
          endpoint: %{startup_observer: self()}
        })

      barrier = observe_successful_startup(f.gate)
      patterns = trace_patterns()

      for pattern <- patterns,
          do: :erlang.trace_pattern(pattern, [{:_, [], [{:return_trace}]}], [:local])

      :erlang.trace(:all, true, [:call, :set_on_spawn, {:tracer, self()}])

      try do
        socket = G.connect(f)
        :ok = G.send_request(f, socket, "GET", "/startup-overlap?")
        assert_receive {:positive_startup_before, pump, lease, before}, 5_000
        assert before.leases[lease].pid === pump
        assert before.cleanups === %{}

        assert_receive {:positive_startup_gate_output, :startup, {^pump, _}, ^lease, reserved},
                       5_000

        assert reserved.leases[lease].bytes === before.leases[lease].bytes + @startup
        assert reserved.bytes === before.bytes + @startup
        assert reserved.cleanups === %{}

        assert_receive {:positive_startup_gate_output, :attach, {service, _}, ^lease, attached},
                       5_000

        assert service === f.service
        [token] = Map.keys(attached.cleanups)
        assert attached.cleanups[token].lease === lease
        assert attached.cleanups[token].bytes === 16_478_862
        assert attached.cleanups[token].receipt === false
        assert attached.leases[lease].cleanup === token
        assert attached.leases[lease].bytes === reserved.leases[lease].bytes
        assert attached.bytes === before.bytes + @startup + 16_478_862
        assert attached.high_water >= attached.bytes
        assert attached.high_water <= f.service_bytes

        gate = f.gate
        assert_receive {:positive_startup_refund_held, ^gate, ^barrier, ^pump, ^lease}, 5_000
        delivered = :erlang.trace_delivered(:all)
        assert_receive {:trace_delivered, :all, ^delivered}, 5_000
        recorded = events([])
        [guardian] = starts(recorded)
        assert Process.alive?(guardian)
        assert adjustments(recorded, gate) === [{lease, @startup}, {lease, -@startup}]

        assert [
                 {^pump,
                  {Gaoxy.Service, :attach_cleanup,
                   [^service, ^gate, ^lease, ^guardian, 16_478_862, deadline]}}
               ] =
                 for(
                   {:call, caller, {Gaoxy.Service, :attach_cleanup, _} = call} <- recorded,
                   do: {caller, call}
                 )

        assert is_integer(deadline)

        helper_return =
          Enum.find_index(
            recorded,
            &match?(
              {:return_from, ^pump, {HTTP, :start_group_session, 5}, {:ok, ^guardian, _, _, _}},
              &1
            )
          )

        refund = -@startup

        refund_call =
          Enum.find_index(
            recorded,
            &match?(
              {:call, ^pump, {Gaoxy.Admission, :adjust_bytes, [^gate, ^lease, ^refund]}},
              &1
            )
          )

        assert is_integer(helper_return) and is_integer(refund_call)
        assert helper_return < refund_call
        refute_receive {:positive_startup_gate_output, :refund, _, _, _}, 0

        send(gate, {:positive_startup_continue, barrier})

        assert_receive {:positive_startup_gate_output, :refund, {^pump, _}, ^lease, refunded},
                       5_000

        assert refunded.leases[lease].bytes === before.leases[lease].bytes
        assert refunded.cleanups === attached.cleanups
        assert refunded.bytes === before.bytes + 16_478_862
        refute_receive {:positive_startup_gate_output, :refund, _, _, _}, 0

        seen = G.event(f.peer, "request")
        assert seen["target"] === "/startup-overlap?"
        G.eventually(fn -> G.held_selection(f, "/startup-overlap?") != nil end)
        {_, held} = G.held_selection(f, "/startup-overlap?")
        assert held.guardian === guardian
        completion = held.completion
        assert %RequestCompletion{} = completion
        assert :sys.get_state(guardian).original_request.completion === completion
        assert G.assert_cleanup(f, 1) === 16_478_862
        G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
        assert %{status: 200, body: ""} = G.response(f, socket)
        :ok = :gen_tcp.close(socket)
        assert :ok = RequestCompletion.await(completion, 5_000)
        G.clean(f)
        G.no_event(f.peer, "request")
        G.close(f)
        :erlang.trace(:all, false, [:call, :set_on_spawn])
        delivered = :erlang.trace_delivered(:all)
        assert_receive {:trace_delivered, :all, ^delivered}, 5_000

        assert adjustments(recorded ++ events([]), gate) ===
                 [{lease, @startup}, {lease, -@startup}]
      after
        :erlang.trace(:all, false, [:call, :set_on_spawn])
        for pattern <- patterns, do: :erlang.trace_pattern(pattern, false, [:local])
      end
    end

    test "#{downstream} to #{protocol} startup denial precedes child creation and neutral copies" do
      f =
        G.fixture(unquote(protocol), unquote(downstream), ["--manual"], %{
          await_health: false,
          group_limits: %{probe_bytes: 16_478_861},
          endpoint_module: BudgetEndpoint,
          endpoint: %{startup_available: @startup - 1, budget_observer: self()}
        })

      children = children()
      {response, events} = observed_request(f)
      assert response.status === 503
      assert_receive {:startup_budget, lease, filler, baseline}, 5_000
      assert filler > 0

      assert adjustments(events, f.gate) === [
               {lease, filler},
               {lease, @startup},
               {lease, -filler}
             ]

      assert starts(events) === []
      refute Enum.any?(events, &match?({:return_from, _, {HTTP, :start_group_session, 5}, _}, &1))
      assert children() === children

      assert %{
               cleanup_pending: 0,
               cleanup_failed: nil,
               retained_bytes: 0,
               retained_high_water: high,
               rejected: rejected
             } = Gaoxy.status(f.instance, :http)

      assert high - filler - baseline < @startup
      assert high <= f.service_bytes
      assert rejected >= 1
      assert_no_effect(f)
      G.close(f)
    end

    test "#{downstream} to #{protocol} attach denial joins the real inactive child before startup refund" do
      f =
        G.fixture(unquote(protocol), unquote(downstream), ["--manual"], %{
          await_health: false,
          group_limits: %{probe_bytes: 16_478_861},
          endpoint_module: BudgetEndpoint,
          endpoint: %{startup_available: 8_388_608, budget_observer: self()}
        })

      children = children()
      {response, events} = observed_request(f)
      assert response.status === 503
      assert_receive {:startup_budget, lease, filler, baseline}, 5_000
      assert filler > 0

      assert adjustments(events, f.gate) ===
               [{lease, filler}, {lease, @startup}, {lease, -@startup}, {lease, -filler}]

      assert [pid] = starts(events)

      assert [
               {_,
                {Gaoxy.Service, :attach_cleanup,
                 [service, gate, ^lease, ^pid, 16_478_862, deadline]}}
             ] =
               for(
                 {:call, caller, {Gaoxy.Service, :attach_cleanup, _} = call} <- events,
                 do: {caller, call}
               )

      assert service === f.service and gate === f.gate and is_integer(deadline)
      refute Process.alive?(pid)
      assert children() === children

      helper_return =
        Enum.find_index(
          events,
          &match?({:return_from, _, {HTTP, :start_group_session, 5}, _}, &1)
        )

      refund_call =
        Enum.find_index(events, fn
          {:call, _, {Gaoxy.Admission, :adjust_bytes, [gate, _, delta]}} ->
            gate === f.gate and delta === -@startup

          _ ->
            false
        end)

      assert is_integer(helper_return) and is_integer(refund_call)
      assert helper_return < refund_call

      assert %{
               cleanup_pending: 0,
               cleanup_failed: nil,
               retained_bytes: 0,
               retained_high_water: high
             } = Gaoxy.status(f.instance, :http)

      assert high - filler - baseline >= @startup
      assert high <= f.service_bytes
      assert_no_effect(f)
      G.close(f)
    end
  end

  # Observe actual gate reply states; hold only the authenticated refund input.
  # The gate never substitutes a result or changes application state for us.
  defp observe_successful_startup(gate) do
    caller = self()
    barrier = make_ref()
    debug_id = make_ref()

    debug = fn held, event, _ ->
      case {held.pending, event} do
        {nil, {:in, {:"$gen_call", from, {:adjust_bytes, lease, @startup}}}} ->
          %{pending: {from, :startup, lease}}

        {nil, {:in, {:"$gen_call", from, {:attach_cleanup, _, lease, _, 16_478_862, _, _}}}} ->
          %{pending: {from, :attach, lease}}

        {nil, {:in, {:"$gen_call", {pump, _} = from, {:adjust_bytes, lease, delta}}}}
        when delta === -@startup ->
          send(caller, {:positive_startup_refund_held, gate, barrier, pump, lease})
          monitor = Process.monitor(caller)

          try do
            receive do
              {:positive_startup_continue, ^barrier} -> :ok
              {:DOWN, ^monitor, :process, ^caller, _} -> :ok
            after
              5_000 -> raise "successful startup refund barrier expired"
            end
          after
            Process.demonitor(monitor, [:flush])
          end

          %{pending: {from, :refund, lease}}

        {{from, phase, lease}, {:out, :ok, actual_from, state}} when actual_from === from ->
          send(caller, {:positive_startup_gate_output, phase, from, lease, state})
          if phase === :refund, do: :done, else: %{pending: nil}

        _ ->
          held
      end
    end

    :ok = :sys.install(gate, {debug_id, debug, %{pending: nil}})

    on_exit(fn ->
      if Process.alive?(gate), do: :sys.remove(gate, debug_id)
    end)

    barrier
  end

  defp trace_patterns do
    [
      {Gaoxy.Admission, :adjust_bytes, 3},
      {Session, :start_link, 1},
      {Gaoxy.Service, :attach_cleanup, 6},
      {HTTP, :start_group_session, 5}
    ]
  end

  defp observed_request(f) do
    patterns = trace_patterns()

    for pattern <- patterns,
        do: :erlang.trace_pattern(pattern, [{:_, [], [{:return_trace}]}], [:local])

    :erlang.trace(:all, true, [:call, :set_on_spawn, {:tracer, self()}])

    try do
      socket = G.connect(f)
      :ok = G.send_request(f, socket, "GET", "/startup?")
      response = G.response(f, socket)
      # The response can reach the socket before this real endpoint frame has
      # returned. Wait for its exact test-owned refund before closing H2.
      assert_receive {:startup_budget_refunded, _, _}, 5_000
      :ok = :gen_tcp.close(socket)
      G.clean(f)
      :erlang.trace(:all, false, [:call, :set_on_spawn])
      delivered = :erlang.trace_delivered(:all)
      assert_receive {:trace_delivered, :all, ^delivered}, 5_000
      {response, events([])}
    after
      :erlang.trace(:all, false, [:call, :set_on_spawn])
      for pattern <- patterns, do: :erlang.trace_pattern(pattern, false, [:local])
    end
  end

  defp events(acc) do
    receive do
      {:trace, pid, :call, call} ->
        events([{:call, pid, call} | acc])

      {:trace, pid, :return_from, call, result} ->
        events([{:return_from, pid, call, result} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp adjustments(events, gate) do
    for {:call, _, {Gaoxy.Admission, :adjust_bytes, [^gate, lease, delta]}} <- events,
        do: {lease, delta}
  end

  defp starts(events),
    do: for({:return_from, _, {Session, :start_link, 1}, {:ok, pid}} <- events, do: pid)

  defp children,
    do: DynamicSupervisor.which_children(Gaoxy.Proxy.SessionSupervisor) |> Enum.sort()

  defp assert_no_effect(f) do
    assert %{inflight: 0, probes: 0, probe_bytes: 0} = UpstreamGroups.status(f.group)
    assert {:ok, %{request_tokens: 0, helpers: 0}} = UpstreamTransports.status(f.owner)
    G.no_event(f.peer, "request")
  end
end
