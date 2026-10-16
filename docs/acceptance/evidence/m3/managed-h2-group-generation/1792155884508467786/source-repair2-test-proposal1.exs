# Load managed_h2_fixed_endpoint_test.exs in the same Mix test invocation.
defmodule Gaoxy.Proxy.ManagedH2GroupGenerationTest.Arithmetic do
  alias Gaoxy.HTTP.Exchange
  alias Gaoxy.HTTP.HTTP2.{Stream, Transport}
  alias Gaoxy.Admission.WorkerBootstrap
  @dispatch ~w(replacement_limits body_map parent_exchange dispatch_envelope
    child_exchange matched_endpoint transport_state)a
  def reservation(owner, worker, state, stream),
    do: settle(owner, worker, state, stream, 0, 0, 0, 0, 0)

  defp settle(owner, worker, state, stream, a, j, n, w, i) when i < 64 do
    rows =
      constructors(
        state,
        stream,
        %{startup_bytes: a, dispatch_bytes: j, protocol_bytes: n, bytes: w, iterations: i},
        owner,
        worker
      )

    {na, nj} =
      Enum.reduce(rows, {0, 0}, fn {name, cap, count}, {sa, sj} ->
        if name in @dispatch, do: {sa, sj + cap * count}, else: {sa + cap * count, sj}
      end)

    nn = state.reserves.stream + na + nj
    nw = nn + 2 * stream.request.head_bytes

    if na <= a and nj <= j and nn <= n and nw <= w do
      %{
        startup_bytes: a,
        dispatch_bytes: j,
        protocol_bytes: n,
        bytes: w,
        iterations: i,
        rows:
          Enum.map(rows, fn {name, cap, count} ->
            %{name: name, cap: cap, multiplicity: count, subtotal: cap * count}
          end)
      }
    else
      settle(owner, worker, state, stream, max(na, a), max(nj, j), max(nn, n), max(nw, w), i + 1)
    end
  end

  defp settle(_, _, _, _, _, _, _, _, _),
    do: raise("independent group Generation W did not converge")

  defp constructors(s, r, report, owner, worker) do
    a = report.startup_bytes
    j = report.dispatch_bytes
    n = report.protocol_bytes
    w = report.bytes
    i = report.iterations
    gate = s.gate
    child_lease = make_ref()
    monitor = make_ref()
    activation = make_ref()
    expiry = make_ref()
    timer = make_ref()
    reqid = make_ref()
    # Original parent lease/token retain measured widths. Only newly generated
    # refs use the source-qualified future-reference upper bound.
    future = MapSet.new([child_lease, monitor, activation, expiry, timer, reqid])
    c = fn term -> cap(term, future) end
    args = [owner, r.id, r.token, gate, n, r.deadline]
    mfa = {Stream, :run, args}
    spawn_args = [gate, owner, activation, r.deadline, mfa]
    from = {owner, [:alias | reqid]}
    payload = {:spawn_request, s.lease, r.token, w, r.deadline, mfa}
    success = {:ok, worker, child_lease}
    # This is the longest ordinary source-controlled finite reason, checked
    # against all native/core finite constructors by the source checkpoint.
    failure = {:error, :invalid_spawn_request}
    reply = max_size(success, failure, c)

    public_result =
      [
        c.({:reply, success}),
        c.({:reply, failure}),
        c.({:error, {:invalid_spawn_request, gate}}),
        c.(:no_reply),
        c.(:timeout)
      ]
      |> Enum.max()

    cancel_result =
      [
        c.({:reply, :ok}),
        c.({:reply, failure}),
        c.({:error, {:invalid_spawn_request, gate}}),
        c.(:no_reply),
        c.(:timeout)
      ]
      |> Enum.max()

    lease = %{
      pid: worker,
      monitor: monitor,
      bytes: w,
      token: expiry,
      timer: timer,
      send: nil,
      drain_notify: true,
      request_active: true,
      cleanup: nil,
      deadline: r.deadline
    }

    correlation = %{
      owner: owner,
      parent_lease: s.lease,
      worker: worker,
      lease: child_lease,
      activation: activation,
      from: from,
      deadline: r.deadline,
      phase: :pending_activation,
      exit_seen: false,
      down_seen: false
    }

    watchdog = {:expired, child_lease, expiry}
    activated = {:gaoxy_admitted_worker_activate, activation, child_lease}
    cancel = {:cancel_spawn, s.lease, r.token}
    down_owner = {:DOWN, monitor, :process, owner, :invalid_spawn_request}
    down_gate = {:DOWN, monitor, :process, gate, :invalid_spawn_request}
    down_child = {:DOWN, monitor, :process, worker, :invalid_spawn_request}
    limits = Map.put(s.limits, :max_write_chunk, 16_384)
    body = %{phase: :done, total: 0, trailers: [], trailer_bytes: 0}
    transport = {owner, r.id, r.token}

    exchange = %Exchange{
      request: r.request,
      socket: nil,
      gate: gate,
      lease: child_lease,
      deadline: r.deadline,
      limits: limits,
      body: body,
      buffer: "",
      peer: s.peer,
      local: s.local,
      service: Map.get(s, :service),
      instance: Map.get(s, :instance),
      response: :unset,
      response_trailers: [],
      close: false,
      route_bytes: 0,
      resource_pins: [],
      protocol_bytes: n,
      poll_buffer_bytes: 0,
      transport: Transport,
      transport_state: transport,
      secure: s.secure,
      ssl: nil,
      peer_cert: s.peer_cert,
      expect_sent: false
    }

    dispatch = {:h2_dispatch, owner, exchange, s.spec.handler_options.endpoint}
    done = {:h2_stream_done, worker, r.id, r.token, {:error, :response_failed}}

    startup = %{
      request: reqid,
      timer: timer,
      token: r.token,
      parent_lease: s.lease,
      protocol_bytes: n,
      bytes: w,
      deadline: r.deadline
    }

    input =
      {e(owner), e(gate), e(s.lease), e(r.id), e(r.token), e(r.deadline), s.reserves.stream,
       r.request.head_bytes, e(r.request), e(s.spec.handler_options.endpoint), e(limits),
       e(s.peer), e(s.local), e(Map.get(s, :service)), e(Map.get(s, :instance)), e(s.secure),
       e(s.peer_cert), e(s.spec.limits.max_bytes), e(s.spec.limits.max_active), e(node()) + 13,
       e(node()) + 27, e(s.limits.request_timeout)}

    plan = {:native_http2_worker_v1, n, w}

    raw = [
      {:planning_context,
       c.(
         {owner, gate, s.lease, r.id, r.token, r.deadline, s.reserves.stream,
          r.request.head_bytes}
       ), 1},
      {:numeric_a, e(a), 2},
      {:numeric_j, e(j), 2},
      {:numeric_n, e(n), 2},
      {:numeric_w, e(w), 2},
      {:numeric_next, e(n), 2},
      {:numeric_iteration, e(i), 2},
      {:input_size_summary, e(input), 1},
      {:input_summary_return, e({:ok, input}), 1},
      {:input_scalar_size_roots,
       Enum.reduce(Tuple.to_list(input), 0, fn value, sum -> sum + e(value) end), 1},
      {:reservation_plan, e(plan), 1},
      {:reservation_return, e({:ok, plan}), 1},
      {:settle_return, e({:ok, {a, j, n, w, i}}), 1},
      {:totals_return, e({a, j}), 1},
      {:spawn_payload, c.(payload), 2},
      {:spawn_wire, c.({:"$gen_call", from, payload}), 1},
      {:spawn_from, c.(from), 1},
      {:spawn_reply_payload, reply, 2},
      {:spawn_reply_wire, max(c.({[:alias | reqid], success}), c.({[:alias | reqid], failure})),
       1},
      {:spawn_request_id, c.(reqid), 1},
      {:spawn_public_result, public_result, 1},
      {:spawn_alias_retirement_result, public_result, 1},
      {:known_failure_control, c.(failure), 1},
      {:reserved_transition,
       e(%{bytes: s.spec.limits.max_bytes, active: s.spec.limits.max_active}), 1},
      {:mfa, c.(mfa), 1},
      {:original_args, c.(args), 1},
      {:gate_spawn_args, c.(spawn_args), 1},
      {:spawn_mfa, c.({WorkerBootstrap, :run, spawn_args}), 1},
      {:spawn_result, max(c.({worker, monitor}), c.(:error)), 1},
      {:spawn_options, c.([:link, :monitor]), 1},
      {:spawn_opt_frame, c.([WorkerBootstrap, :run, spawn_args, [:link, :monitor]]), 1},
      {:spawn_timer_result, max(c.({:ok, timer}), c.(:error)), 1},
      {:ordinary_lease, c.(lease), 1},
      {:lease_entry, c.({child_lease, lease}), 1},
      {:lease_timer_replacement_overlap, c.(lease), 1},
      {:lease_terminal_replacement_overlap, c.(lease), 1},
      {:correlation, c.(correlation), 1},
      {:correlation_entry, c.({r.token, correlation}), 1},
      {:phase_replacement_overlap, c.(correlation), 1},
      {:terminal_replacement_overlap, c.(correlation), 1},
      {:watchdog_payload, c.(watchdog), 1},
      {:activation_continuation, c.({:activate_spawn, r.token}), 1},
      {:gate_link_root, c.(gate), 1},
      {:worker_gate_link_root, c.(worker), 1},
      {:owner_link_root, c.(owner), 1},
      {:worker_owner_link_root, c.(worker), 1},
      {:gate_child_monitor_root, c.(monitor), 1},
      {:child_owner_monitor_root, c.(monitor), 1},
      {:child_gate_monitor_root, c.(monitor), 1},
      {:worker_exit_envelope, c.({:EXIT, worker, :invalid_spawn_request}), 2},
      {:owner_down_envelope, c.(down_owner), 2},
      {:gate_down_envelope, c.(down_gate), 2},
      {:watchdog_timer_ref, c.(timer), 1},
      {:watchdog_timer_payload, c.(watchdog), 1},
      {:trap_exit_prior_result, e(false), 1},
      {:child_spawn_args, c.(spawn_args), 1},
      {:bootstrap_run_frame, c.(spawn_args), 1},
      {:activation_payload, c.(activated), 2},
      {:activation_ref, c.(activation), 1},
      {:bootstrap_owner_monitor_ref, c.(monitor), 2},
      {:bootstrap_gate_monitor_ref, c.(monitor), 2},
      {:bootstrap_owner_down, c.(down_owner), 2},
      {:bootstrap_gate_down, c.(down_gate), 2},
      {:apply_frame, c.({Stream, :run, [child_lease | args]}), 1},
      {:apply_args, c.([child_lease | args]), 1},
      {:child_lease_scalar, c.(child_lease), 1},
      {:cancel_payload, c.(cancel), 2},
      {:cancel_wire, c.({:"$gen_call", from, cancel}), 1},
      {:cancel_from, c.(from), 1},
      {:cancel_reply_wire, max(c.({[:alias | reqid], :ok}), c.({[:alias | reqid], failure})), 1},
      {:cancel_reply_payload, max(c.(:ok), c.(failure)), 2},
      {:native_pending_timer_payload, c.({:h2_worker_start_timeout, r.id, r.token}), 1},
      {:cancel_request_id, c.(reqid), 1},
      {:native_startup_correlation, c.(startup), 1},
      {:native_timer_ref, c.(timer), 1},
      {:native_worker_pid, c.(worker), 1},
      {:native_child_lease, c.(child_lease), 1},
      {:native_worker_monitor, c.(monitor), 1},
      {:native_protocol_n, e(n), 1},
      {:native_bytes_w, e(w), 1},
      {:native_deadline, e(r.deadline), 1},
      {:cancel_public_result, cancel_result, 1},
      {:replacement_limits, c.(limits), 1},
      {:body_map, c.(body), 1},
      {:parent_exchange, c.(exchange), 1},
      {:dispatch_envelope, c.(dispatch), 2},
      {:child_exchange, c.(exchange), 1},
      {:matched_endpoint, c.(s.spec.handler_options.endpoint), 1},
      {:transport_state, c.(transport), 1},
      {:done_payload, c.(done), 2},
      {:finite_error_reply, c.(failure), 2},
      {:child_monitor_down, c.(down_child), 2},
      {:terminal_deadline, e(r.deadline), 3},
      {:terminal_timeout, e(s.limits.request_timeout), 3}
    ]

    caps = raw |> Enum.map(fn {_, size, _} -> size end) |> List.to_tuple()
    # Explicit independent complete tuple construction includes its own appended
    # size root; equality is against a real ETF measurement, not production math.
    cap_summary = summary_size(caps, e(caps))
    raw ++ [{:numeric_cap_summary, cap_summary, 2}]
  end

  defp summary_size(caps, assumed) do
    actual = e(Tuple.insert_at(caps, tuple_size(caps), assumed))
    if actual <= assumed, do: assumed, else: summary_size(caps, actual)
  end

  defp max_size(a, b, c), do: max(c.(a), c.(b))
  defp e(term), do: :erlang.external_size(term)
  defp cap(term, future), do: e(term) + ref_delta(term, future)

  defp ref_delta(term, future) when is_reference(term),
    do: if(MapSet.member?(future, term), do: e(node()) + 27 - e(term), else: 0)

  defp ref_delta(term, future) when is_tuple(term),
    do:
      term
      |> Tuple.to_list()
      |> Enum.reduce(0, fn value, sum -> sum + ref_delta(value, future) end)

  defp ref_delta(term, future) when is_map(term),
    do:
      Enum.reduce(Map.to_list(term), 0, fn {key, value}, sum ->
        sum + ref_delta(key, future) + ref_delta(value, future)
      end)

  defp ref_delta([head | tail], future), do: ref_delta(head, future) + ref_delta(tail, future)
  defp ref_delta(_, _), do: 0
end

defmodule Gaoxy.Proxy.ManagedH2GroupGenerationTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Generation, Resources}
  alias Gaoxy.Lifecycle
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedGenerationAccounting, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias __MODULE__.Arithmetic
  @moduletag :capture_log
  @timeout 5_000
  @reserve 16_478_862
  # Independent source-role sum, not Accounting.startup_bytes/0.
  @startup 1_048_576 + 2 * 786_432 + 851_968 + 2_359_296 + 131_072

  defmodule CapturedGroup do
    @behaviour Gaoxy.HTTP.Endpoint
    def init({options, parent, label, mutation}) do
      with {:ok, config} <- Gaoxy.Proxy.GroupEndpoint.init(options),
           do: {:ok, {config, parent, label, mutation}}
    end

    def resources({config, _, _, _}), do: Gaoxy.Proxy.GroupEndpoint.resources(config)

    def call(exchange, {config, parent, label, mutation}) do
      ref = make_ref()
      send(parent, {:group_generation_capture, self(), ref, label, exchange})

      receive do
        {:dispatch, ^ref} -> :ok
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "group Generation dispatch barrier expired"
      end

      # The capture message and Generation's finally path retain authentic
      # originals. Only the explicitly negative endpoint input is mutated.
      input = mutate(exchange, mutation)
      result = Gaoxy.Proxy.GroupEndpoint.call(input, config)
      send(parent, {:group_generation_return, self(), ref, label, result})

      receive do
        {:return, ^ref} -> result
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "group Generation return barrier expired"
      end
    end

    defp mutate(exchange, :none), do: exchange
    defp mutate(exchange, {:instance, pid}), do: %{exchange | instance: pid}

    defp mutate(exchange, mutation) do
      groups = Gaoxy.Proxy.UpstreamGroups
      transports = Gaoxy.Proxy.UpstreamTransports

      pins =
        Enum.flat_map(exchange.resource_pins, fn pin ->
          cond do
            mutation == :missing_group and pin.provider == groups ->
              []

            pin.provider == groups ->
              [
                case mutation do
                  :forged_group_ref -> %{pin | ref: make_ref()}
                  :forged_group_operation -> %{pin | operation: make_ref()}
                  :forged_group_epoch -> %{pin | owner_epoch: make_ref()}
                  _ -> pin
                end
              ]

            pin.provider == transports ->
              [
                case mutation do
                  :missing_selected -> %{pin | handles: Enum.drop(pin.handles, 1)}
                  :missing_unselected -> %{pin | handles: Enum.take(pin.handles, 1)}
                  :forged_transport_ref -> %{pin | ref: make_ref()}
                  :wrong_transport_holder -> %{pin | holder: exchange.instance}
                  _ -> pin
                end
              ]
          end
        end)

      %{exchange | resource_pins: pins}
    end
  end

  test "owner pin refusal keeps the normalized finite grammar closed" do
    accounting = Gaoxy.Proxy.ManagedH2GroupAccounting
    selector = {:owner_reply, :transport, :pin}
    raw = {:error, :transport_endpoint_mismatch}
    assert {:error, :invalid_group_accounting} = accounting.validate(selector, raw)
    assert Gaoxy.Proxy.HTTP.Session.finite_reason(elem(raw, 1)) == :unavailable
    assert :ok = accounting.validate(selector, {:error, :unavailable})
  end

  for protocol <- [:h2c, :http2], boundary <- [:prepare, :public, :direct] do
    @protocol protocol
    @boundary boundary
    test "#{protocol} two-member group passes genuine #{boundary} admission" do
      peers = peers(@protocol, 2)
      f = environment(@protocol, :http1)
      c = candidate(f, Enum.map(peers, & &1.source), :direct, endpoint: :direct)
      c = healthy(f, c, peers)
      assert map_size(c.group) == 8
      assert c.group.transports === c.transports
      assert c.router.resources === [c.group | c.transports]
      assert {:ok, expected, _} = Generation.snapshot(f.store)

      if @boundary == :prepare do
        abort(c)
        join_resource(f, c)
        add_listener(f)
        finish(f, [], peer_totals(peers, [1, 1]))
      else
        c = activate(f, c, expected, @boundary)
        add_listener(f)
        finish(f, c.creators, peer_totals(peers, [1, 1]))
      end
    end
  end

  for protocol <- [:h2c, :http2], initial <- [:routes, :router] do
    @protocol protocol
    @initial initial
    test "#{protocol} complete group sidecar supports initial #{initial}" do
      peers = peers(@protocol, 2)
      f = environment(@protocol, :http1)
      c = candidate(f, Enum.map(peers, & &1.source), :initial, endpoint: :direct)
      c = healthy(f, c, peers)
      send(c.coordinator, {:initial, @initial})
      coordinator = c.coordinator
      assert_receive {:group_candidate_initial, ^coordinator, {:ok, store}}, @timeout
      monitor = Process.monitor(store)

      on_exit(fn ->
        if Process.alive?(store) do
          cleanup_monitor = Process.monitor(store)
          assert :ok = GenServer.stop(store, :normal, @timeout)
          assert_receive {:DOWN, ^cleanup_monitor, :process, ^store, :normal}, @timeout
        end
      end)

      assert_receive {:DOWN, cmonitor, :process, ^coordinator, :normal}, @timeout
      assert cmonitor == c.monitor
      assert {:ok, generation, router} = Generation.snapshot(store)
      assert generation == router.generation and router.resources === [c.group | c.transports]
      baseline = :sys.get_state(store).baseline
      assert Enum.all?(baseline, &(&1.kind == :baseline))
      assert Enum.sort(Enum.flat_map(baseline, & &1.handles)) == Enum.sort(router.resources)
      assert :ok = GenServer.stop(store, :normal, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^store, :normal}, @timeout
      join_resource(f, c)
      add_listener(f)
      finish(f, [], peer_totals(peers, [1, 1]))
    end
  end

  for protocol <- [:h2c, :http2] do
    @protocol protocol
    test "#{protocol} missing/substituted group sidecars fail before any new provider effect" do
      peers = peers(@protocol, 2)
      f = environment(@protocol, :http1)
      c = healthy(f, candidate(f, Enum.map(peers, & &1.source), :sidecar), peers)
      assert {:ok, expected, original} = Generation.snapshot(f.store)
      before_t = :sys.get_state(f.owner)
      before_g = :sys.get_state(f.groups)
      [first, second] = c.transports

      for handles <- [[c.group, first], [first, second], [c.group, second, second]] do
        invalid = %{c.router | resources: handles}
        assert {:error, _} = Generation.activate(f.store, expected, invalid)

        assert {:error, _} =
                 GenServer.call(
                   f.store,
                   {:activate, expected, invalid, Lifecycle.deadline(@timeout)},
                   @timeout
                 )

        assert {:ok, ^expected, ^original} = Generation.snapshot(f.store)
        after_t = :sys.get_state(f.owner)
        after_g = :sys.get_state(f.groups)
        assert after_t.pins === before_t.pins and after_t.tokens === before_t.tokens
        assert after_g.pins === before_g.pins and after_g.tokens === before_g.tokens
      end

      abort(c)
      join_resource(f, c)
      add_listener(f)
      finish(f, [], peer_totals(peers, [1, 1]))
    end
  end

  for protocol <- [:h2c, :http2], downstream <- [:http1, :http2] do
    @protocol protocol
    @downstream downstream
    test "#{downstream} to #{protocol} real old/fresh groups select0→1→0 and last A source retains unselected B" do
      # Prepare every independent TLS peer before starting native deadlines.
      [oa, ob, na, nb] = all = peers(@protocol, 4)
      f = environment(@protocol, @downstream)
      old = healthy(f, candidate(f, [oa.source, ob.source], :old), [oa, ob])
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      old = activate(f, old, initial)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      old_calls = capture_requests(f, old, :old, Enum.map(0..2, &"/old#{&1}%2Fpath?raw=%2F"))
      assert_no_open(f, old)
      fresh = healthy(f, candidate(f, [na.source, nb.source], :new), [na, nb])
      fresh = activate(f, fresh, old.generation)
      await_closed(f, old, Enum.map(old_calls, & &1.captured))
      old_calls = dispatch_calls(f, old, old_calls, [oa, ob], [0, 1, 0])

      new_calls =
        capture_requests(f, fresh, :new, Enum.map(0..2, &"/new#{&1}%2Fpath?"))
        |> then(&dispatch_calls(f, fresh, &1, [na, nb], [0, 1, 0]))

      assert_cleanup(f, 6)
      assert length(:sys.get_state(f.groups).tokens |> Map.values()) == 6

      for call <- new_calls do
        complete_return(f, call, "new:" <> call.target)
        return_endpoint(call.captured)
      end

      close_calls(f, new_calls)

      for call <- old_calls do
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(call.bound.completion, 0)
        complete_return(f, call, "old:" <> call.target)
      end

      assert_cleanup(f, 0)
      assert_no_open(f, old)
      [first, second, last] = old_calls
      return_endpoint(first.captured)
      return_endpoint(second.captured)

      F.eventually(fn ->
        state = :sys.get_state(f.owner)

        Enum.count(state.pins, fn {_, p} ->
          p.public.kind == :request and
            Enum.any?(old.transports, &(&1 in p.public.handles))
        end) == 1
      end)

      assert_sources(f, old, last.captured)
      assert :sys.get_state(f.groups).groups[group_key(old.group)].lifecycle == :retiring

      for t <- old.transports do
        record = :sys.get_state(f.owner).records[t.resource]
        assert record.admission == :closed and Process.alive?(record.custodian)
      end

      # Last selected A still owns the original [A,B] batch; B cannot retire.
      assert last.bound.index == 0 and last.captured.tpin.handles === old.transports
      return_endpoint(last.captured)
      join_resource(f, old)
      close_calls(f, old_calls)
      for call <- old_calls ++ new_calls, do: assert_effect_counts(f, call.captured, call.bound)
      finish(f, fresh.creators, peer_totals(all, [3, 2, 3, 2]))
    end
  end

  for protocol <- [:h2c, :http2] do
    @protocol protocol
    test "#{protocol} two distinct member IDs dedup one T while selecting both real members" do
      [peer] = peers(@protocol, 1)
      f = environment(@protocol, :http1, group_limits: %{max_probes: 1})
      c = candidate(f, [peer.source, peer.source], :dedup)
      c = healthy(f, c, [peer, peer])
      assert [transport] = c.transports
      assert c.group.transports === [transport]
      assert c.router.resources === [c.group, transport]
      assert {:ok, expected, _} = Generation.snapshot(f.store)
      c = activate(f, c, expected)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      calls = Enum.map(0..1, &capture_request(f, c, :dedup, "/dedup#{&1}"))
      calls = dispatch_calls(f, c, calls, [peer, peer], [0, 1])
      assert_cleanup(f, 2)

      for call <- calls do
        assert call.captured.tpin.handles === [transport]

        assert Enum.sort(Enum.flat_map(call.captured.pins, & &1.handles)) ==
                 Enum.sort([c.group, transport])

        complete_return(f, call, "dedup:" <> call.target)
        return_endpoint(call.captured)
        close_native(f, call.socket, call.captured)
        assert_effect_counts(f, call.captured, call.bound)
      end

      finish(f, c.creators, peer_totals([peer], [4]))
    end
  end

  for protocol <- [:h2c, :http2] do
    @protocol protocol
    test "#{protocol} reused native H2 stream prepares bounded noncompact fields after group replacement" do
      [oa, ob, na, nb] = all = peers(@protocol, 4)
      f = environment(@protocol, :http2)
      old = healthy(f, candidate(f, [oa.source, ob.source], :old), [oa, ob])
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      old = activate(f, old, initial)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      first = capture_request(f, old, :old, "/old-slice")
      fresh = healthy(f, candidate(f, [na.source, nb.source], :new), [na, nb])
      fresh = activate(f, fresh, old.generation)
      await_closed(f, old, [first.captured])
      [first] = dispatch_calls(f, old, [first], [oa, ob], [0])
      complete_return(f, first, "old-slice")
      return_endpoint(first.captured)
      join_resource(f, old)
      F.eventually(fn -> not Process.alive?(first.captured.native) end)
      {connection, 1, _} = first.captured.exchange.transport_state

      F.eventually(fn ->
        {_, state} = :sys.get_state(connection)

        state.streams == %{} and state.startups == %{} and
          not Map.has_key?(
            :sys.get_state(first.captured.exchange.gate).leases,
            first.captured.exchange.lease
          )
      end)

      assert_cleanup(f, 0)

      target = "/new-slice"
      value = :binary.copy("v", 100)
      # Valid HPACK literals with Huffman-bit0 retain a real input subbinary.
      # Static :methodGET/:schemehttp and literal :authority/:path use no table
      # state; stream3 reuses the original native connection and Writer.
      block =
        <<0x82, 0x86, 1, 15, "downstream.test", 4, byte_size(target), target::binary, 0, 7,
          "x-slice", byte_size(value), value::binary>>

      baseline = Gaoxy.status(f.instance, :http)
      assert :ok = :gen_tcp.send(first.socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 3, block))
      captured = capture(f, fresh, :new, baseline)
      assert {^connection, 3, _} = captured.exchange.transport_state
      assert {^connection, 1, _} = first.captured.exchange.transport_state

      assert Enum.map(captured.actors, &elem(&1, 0)) ==
               Enum.map(first.captured.actors, &elem(&1, 0))

      assert {"x-slice", actual} = List.keyfind(captured.exchange.request.headers, "x-slice", 0)
      assert actual == value
      assert byte_size(actual) < :binary.referenced_byte_size(actual)
      assert :binary.referenced_byte_size(actual) <= 65_536
      next = %{socket: first.socket, id: 3, captured: captured, target: target}
      [next] = dispatch_calls(f, fresh, [next], [na, nb], [0])
      assert ["x-slice", value] in next.request["headers"]
      complete_return(f, next, "new-slice")
      return_endpoint(next.captured)
      close_calls(f, [first, next])
      assert_cleanup(f, 0)
      assert_effect_counts(f, first.captured, first.bound)
      assert_effect_counts(f, next.captured, next.bound)
      finish(f, fresh.creators, peer_totals(all, [2, 1, 2, 1]))
    end
  end

  defp peers(protocol, count) do
    Enum.map(1..count, fn _ ->
      {pid, ready} = F.peer(protocol, ["--manual"])
      %{pid: pid, ready: ready, source: source(protocol, ready)}
    end)
  end

  defp peer_totals(peers, totals) do
    Enum.zip_with(peers, totals, fn peer, requests -> {peer.pid, 1, requests} end)
  end

  defp candidate(f, sources, label, opts \\ []) do
    parent = self()

    {coordinator, monitor} =
      spawn_monitor(fn ->
        deadline = Lifecycle.deadline(15_000)

        with_transports(f.owner, Enum.uniq(sources), deadline, [], fn unique,
                                                                      transport_preparation ->
          handles =
            Enum.map(sources, fn source ->
              Enum.find_value(unique, fn {actual, handle} -> if actual === source, do: handle end)
            end)

          members =
            Enum.zip_with(sources, handles, fn source, transport ->
              %{
                id: "member-#{Enum.find_index(unique, fn {_, t} -> t === transport end)}",
                upstream: source.origin,
                upstream_protocol: source.protocol,
                transport: transport,
                max_inflight: 32
              }
            end)

          # IDs remain unique even when A and B share the exact same T.
          members = Enum.with_index(members, fn member, i -> %{member | id: "member-#{i}"} end)

          {:ok, compiled} =
            UpstreamGroups.compile(%{
              id: "generation",
              members: members,
              health: %{
                path: "/health",
                interval: 3_600_000,
                stale_after: 3_600_000,
                timeout: 5_000,
                jitter: 0,
                recovery_threshold: 1
              }
            })

          {:ok, group, group_preparation} =
            UpstreamGroups.prepare(f.groups, compiled, self(), deadline)

          try do
            options = Map.merge(%{group: group}, Keyword.get(opts, :endpoint_overrides, %{}))

            target =
              if Keyword.get(opts, :endpoint) == :direct,
                do: {GroupEndpoint, options},
                else:
                  {CapturedGroup, {options, parent, label, Keyword.get(opts, :mutation, :none)}}

            routes = [%{target: target}]
            {:ok, router} = Generation.prepare(f.store, routes)
            transports = Enum.map(unique, &elem(&1, 1))

            creators =
              Enum.map(transports, fn transport ->
                :sys.get_state(f.owner).records[transport.resource].custodian
              end)

            send(
              parent,
              {:group_candidate, self(), group, transports, members, routes, router, creators}
            )

            result =
              receive do
                {:activate, expected} ->
                  Generation.activate(f.store, expected, router)

                {:activate, expected, :public} ->
                  Generation.activate(f.store, expected, router)

                {:activate, expected, :direct} ->
                  GenServer.call(
                    f.store,
                    {:activate, expected, router, Lifecycle.deadline(@timeout)},
                    @timeout
                  )

                {:initial, mode} when mode in [:routes, :router] ->
                  options = if mode == :routes, do: [routes: routes], else: [router: router]
                  result = Generation.start_link(options)
                  if match?({:ok, _}, result), do: Process.unlink(elem(result, 1))
                  send(parent, {:group_candidate_initial, self(), result})
                  :initial

                :invalid_route ->
                  invalid = Generation.prepare(f.store, [%{path: :invalid, target: target}])
                  send(parent, {:group_candidate_invalid, self(), invalid})
                  :aborted

                :abort ->
                  :aborted
              after
                @timeout -> raise "group candidate publication barrier expired"
              end

            if match?({:ok, _}, result) do
              baseline = :sys.get_state(f.store).baseline

              assert Enum.sort(Enum.flat_map(baseline, & &1.handles)) ==
                       Enum.sort([group | transports])

              assert Enum.all?(baseline, &(&1.kind == :baseline))
            end

            # Group prepare returned its real dependency pin in addition to G.
            # Keep both layers until the complete Store baseline exists.
            assert :ok = Resources.release(group_preparation)
            assert :ok = Resources.release(transport_preparation)

            if result not in [:initial, :aborted],
              do: send(parent, {:group_candidate_activation, self(), result})
          after
            assert :ok = Resources.release(group_preparation)
          end
        end)
      end)

    on_exit(fn ->
      if Process.alive?(coordinator) do
        ref = Process.monitor(coordinator)
        send(coordinator, :abort)
        assert_receive {:DOWN, ^ref, :process, ^coordinator, :normal}, @timeout
      end
    end)

    assert_receive {:group_candidate, ^coordinator, group, transports, members, routes, router,
                    creators},
                   @timeout

    %{
      coordinator: coordinator,
      monitor: monitor,
      group: group,
      transports: transports,
      members: members,
      sources: sources,
      routes: routes,
      router: router,
      creators: Enum.map(creators, &{&1, Process.monitor(&1)}),
      label: label
    }
  end

  defp with_transports(owner, [source | rest], deadline, acc, fun) do
    {:ok, transport, pins} = Transports.prepare(owner, source, self(), deadline)

    try do
      with_transports(owner, rest, deadline, acc ++ [{source, transport, pins}], fun)
    after
      assert :ok = Resources.release(pins)
    end
  end

  defp with_transports(_, [], _, acc, fun) do
    fun.(
      Enum.map(acc, fn {source, handle, _} -> {source, handle} end),
      Enum.flat_map(acc, &elem(&1, 2))
    )
  end

  defp activate(f, c, expected, boundary \\ :public) do
    send(c.coordinator, {:activate, expected, boundary})
    coordinator = c.coordinator
    monitor = c.monitor
    assert_receive {:group_candidate_activation, ^coordinator, {:ok, generation}}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
    assert {:ok, ^generation, router} = Generation.snapshot(f.store)
    assert router === c.router and generation == c.router.generation
    for transport <- c.transports, do: assert(configured_pins(f, transport) == [:baseline])

    assert [%{kind: :baseline}] =
             for({_, p} <- :sys.get_state(f.groups).pins, group_key(c.group) in p.keys, do: p)

    Map.put(c, :generation, generation)
  end

  defp abort(c) do
    send(c.coordinator, :abort)
    coordinator = c.coordinator
    monitor = c.monitor
    assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout
  end

  defp healthy(f, c, peers) do
    health =
      Enum.with_index(peers, fn peer, index ->
        if Enum.find_index(peers, &(&1.pid == peer.pid)) == index do
          assert %{"connection" => connection} = F.event(peer.pid, "accept")

          if f.protocol == :http2 do
            assert %{"connection" => ^connection, "alpn" => "h2", "sni" => "localhost"} =
                     F.event(peer.pid, "tls")
          end
        end

        request = F.event(peer.pid, "request")
        assert request["target"] == "/health" and request["ended"]
        assert [":method", "HEAD"] in request["headers"]
        connection = request["connection"]
        stream = request["stream"]

        assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 0} =
                 F.event(peer.pid, "upload_end")

        F.eventually(fn ->
          Enum.any?(:sys.get_state(f.groups).probes, fn {_, p} ->
            p.key == group_key(c.group) and p.index == index and
              match?(%HTTP.RequestCompletion{}, p.completion)
          end)
        end)

        [{_, probe}] =
          Enum.filter(:sys.get_state(f.groups).probes, fn {_, p} ->
            p.key == group_key(c.group) and p.index == index
          end)

        assert probe.claimed and probe.bytes == @reserve
        monitor = Process.monitor(probe.pid)
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(probe.completion, 0)

        F.command(peer.pid, request, "respond", %{
          "fields" => [["content-length", "0"]],
          "ended" => true
        })

        assert :ok = HTTP.RequestCompletion.await(probe.completion, @timeout)
        pid = probe.pid
        assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
        %{peer: peer.pid, request: request, completion: probe.completion}
      end)

    F.eventually(fn ->
      status = UpstreamGroups.status(c.group)

      is_map(status) and status.probes == 0 and status.probe_bytes == 0 and
        Enum.all?(status.members, &(&1.health == :healthy and not &1.probe)) and
        match?({:ok, %{request_tokens: 0, helpers: 0}}, Transports.status(f.owner))
    end)

    assert_group_ledgers(f)
    Map.put(c, :health, health)
  end

  defp observe_owner(f) do
    parent = self()
    store = f.store

    for {owner, provider, tag} <- [
          {f.groups, UpstreamGroups, :pin},
          {f.owner, Transports, :pin_many}
        ] do
      id = make_ref()

      debug = fn acc, event, _ ->
        case event do
          {:in, {:"$gen_call", {^store, _}, {^tag, handles, native, :request, operation, d}}} ->
            status = Gaoxy.status(f.instance, :http)

            send(
              parent,
              {:group_owner_capture_input, self(), provider, handles, native, operation, d,
               status}
            )

            receive do
              {:group_owner_continue, ^operation} -> :ok
              :group_owner_unblock -> :ok
            after
              @timeout -> raise "group original provider input barrier expired"
            end

          {:in, {:"$gen_call", {caller, _}, message}} when is_tuple(message) ->
            send(parent, {:group_owner_effect, self(), caller, elem(message, 0), message})

          {:in, {:cancel_pins, caller, operation}} ->
            send(parent, {:group_owner_cancel, self(), caller, operation})

          _ ->
            :ok
        end

        acc
      end

      :ok = :sys.install(owner, {id, debug, nil})

      on_exit(fn ->
        if Process.alive?(owner) do
          send(owner, :group_owner_unblock)
          :sys.remove(owner, id)
        end
      end)
    end
  end

  defp observe_startup(f) do
    parent = self()
    gate = service_gate(f)
    id = make_ref()

    debug = fn pending, event, _ ->
      case event do
        {:in, {:"$gen_call", {native, _} = from, {:adjust_bytes, lease, delta}}}
        when delta in [@startup, -@startup] ->
          Map.put(pending, from, {native, lease, delta})

        {:out, :ok, from, state} ->
          case Map.pop(pending, from) do
            {nil, _} ->
              pending

            {{native, lease, delta}, rest} ->
              send(
                parent,
                {:group_startup_cut, native, lease, delta, state.leases[lease].bytes, state.bytes}
              )

              rest
          end

        _ ->
          pending
      end
    end

    :ok = :sys.install(gate, {id, debug, %{}})
    on_exit(fn -> if Process.alive?(gate), do: :sys.remove(gate, id) end)
  end

  defp capture_request(f, c, label, target) do
    {socket, baseline} = connect(f)
    assert :ok = F.send_request(f, socket, "GET", target)
    %{socket: socket, captured: capture(f, c, label, baseline), target: target}
  end

  defp capture_requests(%{downstream: :http1} = f, c, label, targets),
    do: Enum.map(targets, &capture_request(f, c, label, &1))

  defp capture_requests(%{downstream: :http2} = f, c, label, targets) do
    # Charge P and the Writer once per real connection. Each request still has
    # its own native stream worker, actual W+B, authentic batches and completion.
    {socket, _} = connect(f)

    Enum.with_index(targets, fn target, index ->
      baseline = Gaoxy.status(f.instance, :http)
      id = 2 * index + 1
      assert :ok = F.send_request(f, socket, "GET", target, [], true, id)
      %{socket: socket, id: id, captured: capture(f, c, label, baseline), target: target}
    end)
  end

  defp capture(f, c, label, baseline) do
    inputs =
      Enum.map(1..2, fn _ ->
        assert_receive {:group_owner_capture_input, owner, provider, handles, native, operation,
                        d, status},
                       @timeout

        expected = if provider == UpstreamGroups, do: [c.group], else: c.transports
        assert owner == if(provider == UpstreamGroups, do: f.groups, else: f.owner)
        assert handles === expected and is_reference(operation)
        send(owner, {:group_owner_continue, operation})

        %{
          owner: owner,
          provider: provider,
          handles: handles,
          native: native,
          operation: operation,
          deadline: d,
          status: status
        }
      end)

    assert Enum.sort(Enum.map(inputs, & &1.provider)) == Enum.sort([UpstreamGroups, Transports])
    [native] = Enum.uniq(Enum.map(inputs, & &1.native))
    assert_receive {:group_generation_capture, ^native, ref, ^label, exchange}, @timeout

    on_exit(fn ->
      send(native, {:dispatch, ref})
      send(native, {:return, ref})
    end)

    assert length(exchange.resource_pins) == 2
    gpin = Enum.find(exchange.resource_pins, &(&1.provider == UpstreamGroups))
    tpin = Enum.find(exchange.resource_pins, &(&1.provider == Transports))
    assert map_size(gpin) == 7 and map_size(tpin) == 8
    assert gpin.handles === [c.group] and tpin.handles === c.transports

    assert Enum.sort(Enum.flat_map(exchange.resource_pins, & &1.handles)) ==
             Enum.sort([c.group | c.transports])

    for input <- inputs do
      pin = Enum.find(exchange.resource_pins, &(&1.provider == input.provider))

      assert pin.owner == input.owner and pin.operation == input.operation and
               pin.kind == :request and pin.handles === input.handles

      assert input.deadline == exchange.deadline and Lifecycle.remaining(input.deadline) > 0

      assert :ok =
               ManagedGenerationAccounting.correlate(
                 pin,
                 {input.provider, input.owner, input.operation, input.handles},
                 native
               )
    end

    retained = Gaoxy.HTTP.Exchange.retained_bytes(exchange) - exchange.route_bytes
    b = expected_b(retained)
    assert exchange.route_bytes == b

    assert {:ok, {:native_generation_capture_v1, 1_048_576, 65_536, 65_536, ^b}} =
             ManagedGenerationAccounting.reservation(
               1_048_576,
               {f.store, native, exchange.gate, exchange.lease, :request, exchange.deadline,
                retained}
             )

    for input <- inputs,
        do: assert(input.status.retained_bytes == baseline.retained_bytes + retained + b)

    gate = :sys.get_state(exchange.gate)

    assert gate.leases[exchange.lease].pid == native and
             gate.leases[exchange.lease].bytes == retained + b

    assert gate.bytes == baseline.retained_bytes + retained + b
    assert_gate_sum(gate)
    actors = native_accounting(f, native, exchange, retained)

    captured = %{
      native: native,
      native_monitor: Process.monitor(native),
      ref: ref,
      label: label,
      exchange: exchange,
      pins: exchange.resource_pins,
      gpin: gpin,
      tpin: tpin,
      actors: actors,
      retained: retained,
      reservation: b
    }

    assert_sources(f, c, captured)
    assert_no_native_effect(f, native)
    captured
  end

  defp native_accounting(%{downstream: :http1}, native, exchange, retained) do
    assert exchange.transport == nil and exchange.protocol_bytes == 0
    assert retained == 2 * exchange.request.head_bytes
    assert Process.alive?(native)
    []
  end

  defp native_accounting(%{downstream: :http2}, native, exchange, retained) do
    assert exchange.transport == Gaoxy.HTTP.HTTP2.Transport
    {connection, id, token} = exchange.transport_state
    {_, state} = :sys.get_state(connection)
    stream = state.streams[id]

    assert stream.worker == native and stream.lease == exchange.lease and
             stream.token == token and stream.startup == nil and
             stream.request === exchange.request

    report = Arithmetic.reservation(connection, native, state, stream)
    assert length(report.rows) == 95
    assert retained == report.bytes and exchange.protocol_bytes == report.protocol_bytes
    assert report.bytes == report.protocol_bytes + 2 * exchange.request.head_bytes
    http = state.spec.handler_options.http_limits
    h2 = state.spec.handler_options.h2_limits

    decode =
      2 * h2.max_header_block * (max(h2.table_size, 128) + 2) +
        512 * h2.max_header_block + 2 * h2.table_size

    p = decode + 16_777_216 + 65_535 + 4 * http.max_buffer_bytes + 8 * (100 * 16_384 + 18_437)
    writer_bytes = 4 * 16_384 + 1_024
    assert state.reserves.connection == p and state.reserves.writer == writer_bytes
    gate = :sys.get_state(exchange.gate)
    assert gate.leases[state.lease].pid == connection and gate.leases[state.lease].bytes == p
    [{_, writer}] = Enum.filter(gate.leases, fn {_, l} -> l.pid == state.writer end)
    assert writer.bytes == writer_bytes

    [
      {connection, Process.monitor(connection), {:shutdown, :peer_closed}},
      {state.writer, Process.monitor(state.writer), :normal}
    ]
  end

  defp assert_sources(f, c, captured) do
    t = :sys.get_state(f.owner).pins[captured.tpin.ref]
    assert t.public === captured.tpin and t.acquirer == f.store
    assert t.public.holder == captured.native and not Map.get(t, :derived, false)
    g = :sys.get_state(f.groups).pins[captured.gpin.ref]
    assert g.holder == captured.native and g.acquirer == f.store and g.kind == :request
    assert g.operation == captured.gpin.operation and g.keys == [group_key(c.group)]
    assert captured.tpin.handles === c.transports
  end

  defp dispatch_calls(f, c, calls, peers, indices) do
    Enum.zip_with(calls, indices, fn call, index ->
      dispatch(call.captured)
      peer = Enum.at(peers, index)
      request = request_at(f, peer.pid, c, index, call.target)
      held = bound(f, c, call.captured, index)
      Map.merge(call, %{peer: peer.pid, request: request, bound: held})
    end)
  end

  defp request_at(f, peer, c, index, target) do
    seen = F.event(peer, "request")
    assert seen["target"] == target and seen["ended"]
    assert [":method", "GET"] in seen["headers"]

    assert [":authority", URI.parse(Enum.at(c.sources, index).origin).authority] in seen[
             "headers"
           ]

    assert [":scheme", if(f.protocol == :http2, do: "https", else: "http")] in seen["headers"]
    health = Enum.at(c.health, index)
    assert health.peer == peer and health.request["connection"] == seen["connection"]
    seen
  end

  defp bound(f, c, captured, index) do
    F.eventually(fn ->
      Enum.any?(:sys.get_state(f.groups).tokens, fn {_, token} ->
        token.key == group_key(c.group) and token.index == index and
          match?(%HTTP.RequestCompletion{}, token.completion) and
          Process.alive?(token.guardian) and
          :sys.get_state(token.guardian).owner == captured.native
      end)
    end)

    [{group_token, gh}] =
      Enum.filter(:sys.get_state(f.groups).tokens, fn {_, token} ->
        token.key == group_key(c.group) and token.index == index and
          :sys.get_state(token.guardian).owner == captured.native
      end)

    session = gh.guardian

    F.eventually(fn ->
      Enum.any?(:sys.get_state(f.owner).tokens, fn {_, t} ->
        t.guardian == session and t.completion === gh.completion
      end)
    end)

    [{transport_token, th}] =
      Enum.filter(:sys.get_state(f.owner).tokens, fn {_, t} -> t.guardian == session end)

    selected = Enum.at(c.members, index).transport
    assert th.resource == selected.resource
    state = :sys.get_state(session)
    assert state.owner == captured.native and state.client == Gaoxy.Proxy.ManagedH2Client
    assert state.client.completion(state.original_request) === gh.completion
    assert th.completion === gh.completion
    assert state.selection === {c.group, group_token}
    assert state.transport_selection === {selected, transport_token}
    assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(gh.completion, 0)
    ledger = :sys.get_state(f.owner)
    [child] = for {_, p} <- ledger.pins, p.public.holder == session, do: p

    assert child.derived and child.source_ref == captured.tpin.ref and
             child.acquirer == captured.native

    assert child.public.handles === [selected] and child.public.kind == :request
    refute child.public.ref == captured.tpin.ref

    assert ledger.pins[captured.tpin.ref].delegations[selected.resource] ==
             %{guardian: session, operation: child.public.operation, ref: child.public.ref}

    refute Enum.any?(:sys.get_state(f.groups).pins, fn {_, p} -> p.holder == session end)
    assert_sources(f, c, captured)
    # Observe the real temporary allowance twice; it is not part of R+B or C.
    native = captured.native
    lease = captured.exchange.lease
    assert_receive {:group_startup_cut, ^native, ^lease, @startup, with_startup, _}, @timeout
    assert with_startup == captured.retained + captured.reservation + @startup
    assert_receive {:group_startup_cut, ^native, ^lease, negative, after_startup, _}, @timeout
    assert negative == -@startup and after_startup == captured.retained + captured.reservation
    assert_cleanup(f, map_size(:sys.get_state(f.groups).tokens))
    assert_group_ledgers(f)

    %{
      session: session,
      monitor: Process.monitor(session),
      completion: gh.completion,
      group_token: group_token,
      transport_token: transport_token,
      child: child.public,
      selected: selected,
      index: index
    }
  end

  defp complete_return(f, call, body) do
    F.command(call.peer, call.request, "respond", %{
      "body64" => Base.encode64(body),
      "fields" => [
        ["content-length", Integer.to_string(byte_size(body))],
        ["x-order", "first"],
        ["x-order", "second"]
      ]
    })

    assert %{status: 200, body: ^body, headers: headers} =
             F.response(f, call.socket, "GET", Map.get(call, :id, 1))

    assert Enum.filter(headers, fn {name, _} -> name == "x-order" end) ==
             [{"x-order", "first"}, {"x-order", "second"}]

    held = call.bound
    assert :ok = HTTP.RequestCompletion.await(held.completion, @timeout)
    session = held.session
    monitor = held.monitor
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
    captured = call.captured
    native = captured.native
    ref = captured.ref
    label = captured.label
    assert_receive {:group_generation_return, ^native, ^ref, ^label, result}, @timeout
    assert {:ok, %Gaoxy.HTTP.Exchange{deadline: deadline}} = result
    assert deadline == captured.exchange.deadline and Process.alive?(native)
    t = :sys.get_state(f.owner)
    g = :sys.get_state(f.groups)
    refute Map.has_key?(t.tokens, held.transport_token)
    refute Map.has_key?(t.pins, held.child.ref)
    refute Map.has_key?(g.tokens, held.group_token)
    assert t.pins[captured.tpin.ref].public === captured.tpin
    assert g.pins[captured.gpin.ref].holder == native
    assert_gate_sum(:sys.get_state(captured.exchange.gate))
  end

  defp assert_cleanup(f, count) do
    gate = service_gate(f)
    F.eventually(fn -> map_size(:sys.get_state(gate).cleanups) == count end)
    state = :sys.get_state(gate)
    assert Enum.all?(state.cleanups, fn {_, record} -> record.bytes == @reserve end)
    total = Enum.sum(for {_, record} <- state.cleanups, do: record.bytes)
    assert total == count * @reserve
    if count == 6, do: assert(total == 98_873_172)
    assert state.bytes <= 536_870_912 and state.high_water <= 536_870_912
    assert_gate_sum(state)
    assert Gaoxy.status(f.instance, :http).cleanup_pending == count
  end

  defp assert_gate_sum(state) do
    assert state.bytes ==
             Enum.sum(for {_, l} <- state.leases, do: l.bytes) +
               Enum.sum(for {_, c} <- state.cleanups, do: c.bytes)

    assert state.bytes <= state.limits.max_bytes and state.high_water <= state.limits.max_bytes
  end

  defp assert_group_ledgers(f) do
    state = :sys.get_state(f.groups)
    config = Enum.sum(for {_, record} <- state.groups, do: record.bytes)
    assert state.bytes == config

    for {_, record} <- state.groups do
      assert record.bytes <= 12_582_912
      # Configuration reserve is installed once and remains valid as compact
      # ordinary runtime members change; it is not resized to current ETF size.
      assert :erlang.external_size(Map.delete(record, :bytes)) <= record.bytes
    end

    controls =
      for {kind, records} <- [pin: state.pins, selection: state.tokens, probe: state.probes],
          {_, record} <- records do
        safe = Map.delete(record, :control_bytes)

        safe =
          if Map.get(safe, :completion) != nil,
            do: %{safe | completion: {:opaque, HTTP.RequestCompletion}},
            else: safe

        bytes = :erlang.external_size(safe)
        assert record.control_bytes == bytes
        assert bytes <= if(kind == :pin, do: 196_608, else: 32_768)
        bytes
      end

    assert state.control_bytes == Enum.sum(controls) and state.control_bytes <= 16_777_216
    assert state.probe_bytes == Enum.sum(for {_, p} <- state.probes, do: p.bytes)
  end

  defp await_closed(f, c, captures) do
    F.eventually(fn ->
      state = :sys.get_state(f.groups)
      group = state.groups[group_key(c.group)]

      group.lifecycle == :retiring and UpstreamGroups.status(c.group).probes == 0 and
        not Enum.any?(state.pins, fn {_, p} ->
          group_key(c.group) in p.keys and p.kind in [:baseline, :preparation]
        end) and
        Enum.all?(c.transports, fn t ->
          configured_pins(f, t) == [] and
            Transports.validate_endpoint(t, identity(f, c, t), Lifecycle.deadline(@timeout)) ==
              {:error, :resource_admission_closed}
        end)
    end)

    group = :sys.get_state(f.groups).groups[group_key(c.group)]
    assert group.lifecycle == :retiring
    assert UpstreamGroups.status(c.group).probes == 0

    refute Enum.any?(:sys.get_state(f.groups).pins, fn {_, p} ->
             group_key(c.group) in p.keys and p.kind in [:baseline, :preparation]
           end)

    for t <- c.transports do
      assert {:error, _} = Resources.pin_many([t], self(), :request, Lifecycle.deadline(@timeout))
      assert :sys.get_state(f.owner).records[t.resource].admission == :closed
    end

    assert {:error, _} =
             Resources.pin_many([c.group], self(), :request, Lifecycle.deadline(@timeout))

    for captured <- captures, do: assert_sources(f, c, captured)
    for {pid, _} <- c.creators, do: assert(Process.alive?(pid))
  end

  defp join_resource(f, c) do
    F.eventually(fn ->
      not Map.has_key?(:sys.get_state(f.groups).groups, group_key(c.group)) and
        Enum.all?(c.transports, &(not Map.has_key?(:sys.get_state(f.owner).records, &1.resource)))
    end)

    for {pid, ref} <- c.creators,
        do: assert_receive({:DOWN, ^ref, :process, ^pid, :normal}, @timeout)
  end

  defp configured_pins(f, t) do
    for {_, p} <- :sys.get_state(f.owner).pins,
        t in p.public.handles and p.public.kind in [:baseline, :preparation],
        do: p.public.kind
  end

  defp identity(f, c, t) do
    i = Enum.find_index(c.members, &(&1.transport === t))
    %{origin: Enum.at(c.sources, i).origin, upstream_protocol: f.protocol, instance: f.instance}
  end

  defp assert_no_open(f, c) do
    t = :sys.get_state(f.owner)

    refute Enum.any?(t.tokens, fn {_, p} ->
             Enum.any?(c.transports, &(&1.resource == p.resource))
           end)

    refute Enum.any?(t.pins, fn {_, p} ->
             Map.get(p, :derived, false) and
               Enum.any?(c.transports, &(&1 in p.public.handles))
           end)

    refute Enum.any?(:sys.get_state(f.groups).tokens, fn {_, p} -> p.key == group_key(c.group) end)
  end

  defp assert_no_native_effect(_f, native) do
    # Synchronous owner reads above make earlier observer sends available.
    effects = collect_effects(Process.get({__MODULE__, :effects}, []))
    Process.put({__MODULE__, :effects}, effects)

    refute Enum.any?(effects, fn {_, caller, tag, _} ->
             caller == native and
               tag in [:pin, :pin_many, :checkout, :delegate_request_pin, :bind, :bind_completion]
           end)
  end

  defp assert_effect_counts(f, captured, held) do
    :sys.get_state(f.owner)
    :sys.get_state(f.groups)
    effects = collect_effects(Process.get({__MODULE__, :effects}, []))
    Process.put({__MODULE__, :effects}, effects)
    native = captured.native
    session = held.session

    assert Enum.count(effects, fn {owner, caller, tag, _} ->
             owner == f.owner and caller == native and tag == :delegate_request_pin
           end) == 1

    for {owner, tags} <- [
          {f.groups, [:checkout, :bind, :finish]},
          {f.owner, [:checkout, :bind_completion, :finish]}
        ],
        tag <- tags do
      assert Enum.count(effects, fn {o, caller, actual, _} ->
               o == owner and caller == session and actual == tag
             end) == 1
    end

    refute Enum.any?(effects, fn {_, caller, tag, _} ->
             caller == native and tag in [:pin, :pin_many]
           end)
  end

  defp collect_effects(acc) do
    receive do
      {:group_owner_effect, owner, caller, tag, message} ->
        collect_effects([{owner, caller, tag, message} | acc])
    after
      0 -> acc
    end
  end

  defp dispatch(c), do: send(c.native, {:dispatch, c.ref})
  defp return_endpoint(c), do: send(c.native, {:return, c.ref})
  defp group_key(g), do: {g.group, g.generation}

  defp service_gate(f) do
    [{:http, service, _}] = :ets.lookup(:sys.get_state(f.instance).live, :http)
    :sys.get_state(service).gate
  end

  defp expected_b(retained), do: expected_b(retained, 0, 0)

  defp expected_b(retained, b, iteration) when iteration < 64 do
    next =
      6 * 1_048_576 + 4_957_373 +
        3 * (:erlang.external_size(retained) - 3) +
        5 * (:erlang.external_size(b) - 6) +
        4 * (:erlang.external_size(retained + b) - 6)

    if b == next, do: b, else: expected_b(retained, next, iteration + 1)
  end

  defp expected_b(_, _, _), do: flunk("group independent B did not converge")

  defp close_native(f, socket, captured) do
    assert :ok = :gen_tcp.close(socket)
    native = captured.native
    ref = captured.native_monitor
    reason = if f.downstream == :http2, do: :normal, else: {:shutdown, :peer_closed}
    assert_receive {:DOWN, ^ref, :process, ^native, ^reason}, @timeout

    for {pid, monitor, expected} <- captured.actors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, ^expected}, @timeout
    end
  end

  defp close_calls(%{downstream: :http1} = f, calls) do
    for call <- calls, do: close_native(f, call.socket, call.captured)
  end

  defp close_calls(%{downstream: :http2}, calls) do
    # Join every real stream after its source return before closing their shared
    # connection. Then require every original connection/Writer monitor terminal.
    for %{captured: captured} <- calls do
      native = captured.native
      monitor = captured.native_monitor
      assert_receive {:DOWN, ^monitor, :process, ^native, :normal}, @timeout
    end

    for socket <- Enum.uniq(Enum.map(calls, & &1.socket)),
        do: assert(:ok == :gen_tcp.close(socket))

    for %{captured: captured} <- calls, {pid, monitor, expected} <- captured.actors do
      assert_receive {:DOWN, ^monitor, :process, ^pid, ^expected}, @timeout
    end
  end

  defp source(protocol, ready) do
    scheme = if protocol == :http2, do: "https", else: "http"

    %{
      protocol: protocol,
      origin: scheme <> "://localhost:#{ready["port"]}",
      connect_address: {127, 0, 0, 1},
      trust: if(protocol == :http2, do: F.certificates(ready["ca"]), else: nil)
    }
  end

  defp connect(f) do
    before = Gaoxy.status(f.instance, :http)
    socket = F.connect(f)
    increment = if f.downstream == :http2, do: 2, else: 1
    F.eventually(fn -> Gaoxy.status(f.instance, :http).active == before.active + increment end)
    {socket, Gaoxy.status(f.instance, :http)}
  end

  defp environment(protocol, downstream, opts \\ []) do
    parent = self()

    limits =
      Map.merge(
        %{
          max_resources: 4,
          max_pins: 256,
          max_request_tokens: 64,
          max_owned_payload_bytes: 8_388_608
        },
        Keyword.get(opts, :transport_limits, %{})
      )

    assert limits.max_resources <= 4 and limits.max_pins <= 256 and
             limits.max_request_tokens <= 64 and limits.max_owned_payload_bytes <= 8_388_608

    group_limits = Keyword.get(opts, :group_limits, %{})

    {embedding, embedding_monitor} =
      spawn_monitor(fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)
        {:ok, owner} = Transports.start_link(instance: instance, limits: limits)
        Process.unlink(owner)
        {:ok, groups} = UpstreamGroups.start_link(instance: instance, limits: group_limits)
        Process.unlink(groups)
        {:ok, store} = Generation.start_link(routes: [])
        Process.unlink(store)
        send(parent, {:group_generation_environment, self(), instance, owner, groups, store})

        receive do
          {:stop, reply} ->
            if Process.alive?(store), do: :ok = GenServer.stop(store, :normal, @timeout)
            result = Gaoxy.stop(instance, @timeout)
            if Process.alive?(groups), do: :ok = GenServer.stop(groups, :normal, @timeout)
            send(reply, {:group_generation_environment_stopped, self(), result})
        after
          120_000 -> exit(:group_generation_environment_deadline)
        end
      end)

    assert_receive {:group_generation_environment, ^embedding, instance, owner, groups, store},
                   @timeout

    joins = Enum.map([instance, owner, groups, store], &{&1, Process.monitor(&1)})

    on_exit(fn ->
      if Process.alive?(embedding) do
        monitor = Process.monitor(embedding)
        send(embedding, {:stop, self()})
        assert_receive {:group_generation_environment_stopped, ^embedding, :ok}, 3 * @timeout
        assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
      end
    end)

    %{
      instance: instance,
      owner: owner,
      transports: owner,
      groups: groups,
      store: store,
      protocol: protocol,
      downstream: downstream,
      embedding: embedding,
      embedding_monitor: embedding_monitor,
      joins: joins
    }
  end

  defp add_listener(f) do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :http,
               endpoint: {Generation, {f.store, accounting: ManagedGenerationAccounting}},
               protocols: [f.downstream],
               h2c: if(f.downstream == :http2, do: :prior_knowledge, else: :disabled),
               limits: %{max_bytes: 536_870_912},
               http_limits: %{request_timeout: 15_000}
             )

    assert {:ok, _} = Gaoxy.add(f.instance, spec)
  end

  defp finish(f, creators, peers) do
    F.eventually(fn ->
      match?(
        %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil},
        Gaoxy.status(f.instance, :http)
      )
    end)

    gate = service_gate(f)
    assert :sys.get_state(gate).bytes == 0 and :sys.get_state(gate).cleanups == %{}
    assert {:ok, address} = Gaoxy.info(f.instance, :http).local
    store_monitor = Enum.find_value(f.joins, fn {pid, ref} -> if pid == f.store, do: ref end)
    if Process.alive?(f.store), do: assert(:ok == GenServer.stop(f.store, :normal, @timeout))
    assert_receive {:DOWN, ^store_monitor, :process, _, :normal}, @timeout

    F.eventually(fn ->
      match?(
        {:ok,
         %{
           resources: 0,
           pins: 0,
           request_tokens: 0,
           helpers: 0,
           reserved_connections: 0,
           owned_serialized_payload_bytes: 0
         }},
        Transports.status(f.owner)
      )
    end)

    F.eventually(fn ->
      state = :sys.get_state(f.groups)

      state.groups == %{} and state.pins == %{} and state.tokens == %{} and state.probes == %{} and
        state.bytes == 0 and state.control_bytes == 0 and state.probe_bytes == 0
    end)

    for {pid, monitor} <- creators,
        do: assert_receive({:DOWN, ^monitor, :process, ^pid, :normal}, @timeout)

    for {peer, accepts, requests} <- peers do
      if accepts > 0 do
        assert %{"connection" => 1} = F.physical_termination(peer)
      end

      assert Process.get({F, :observed_requests, peer}) == requests
    end

    send(f.embedding, {:stop, self()})
    embedding = f.embedding
    assert_receive {:group_generation_environment_stopped, ^embedding, :ok}, 3 * @timeout

    for {pid, monitor} <- f.joins, pid != f.store do
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end

    monitor = f.embedding_monitor
    assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout
    {ip, port} = address

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    assert :ok = :gen_tcp.close(rebound)

    for {peer, accepts, requests} <- peers do
      monitor = Process.monitor(peer)
      send(peer, {:command, %{"op" => "stop"}})

      assert %{
               "forced" => 0,
               "live" => 0,
               "failed" => false,
               "accepts" => ^accepts,
               "requests" => ^requests
             } = F.event(peer, "joined")

      assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
      assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
    end
  end

  # Negative cases run genuine native H1 for both upstream protocols. The four
  # socket cells above retain the independent native H1/H2 matrix.
  for protocol <- [:h2c, :http2] do
    @failure_protocol protocol

    for fate <- [:stale, :invalid_route, :abandon, :coordinator_death] do
      @failure_fate fate
      test "#{protocol} #{@failure_fate} retires only a genuinely prepared two-member candidate" do
        [aa, ab, ra, rb] = all = peers(@failure_protocol, 4)
        f = environment(@failure_protocol, :http1)
        assert {:ok, stale, _} = Generation.snapshot(f.store)
        active = healthy(f, candidate(f, [aa.source, ab.source], :active), [aa, ab])
        active = activate(f, active, stale)
        add_listener(f)
        observe_owner(f)
        observe_startup(f)
        rejected = healthy(f, candidate(f, [ra.source, rb.source], :rejected), [ra, rb])
        coordinator = rejected.coordinator
        monitor = rejected.monitor

        case @failure_fate do
          :stale ->
            send(coordinator, {:activate, stale})

            assert_receive {:group_candidate_activation, ^coordinator,
                            {:error, :stale_generation}},
                           @timeout

            assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout

          :invalid_route ->
            send(coordinator, :invalid_route)

            assert_receive {:group_candidate_invalid, ^coordinator,
                            {:error, :invalid_route_path}},
                           @timeout

            assert_receive {:DOWN, ^monitor, :process, ^coordinator, :normal}, @timeout

          :abandon ->
            abort(rejected)

          :coordinator_death ->
            Process.exit(coordinator, :kill)
            assert_receive {:DOWN, ^monitor, :process, ^coordinator, :killed}, @timeout
        end

        join_resource(f, rejected)
        failure_assert_active(f, active)
        call = capture_request(f, active, :active, "/after-candidate-failure?")
        [call] = dispatch_calls(f, active, [call], [aa, ab], [0])
        complete_return(f, call, "active")
        return_endpoint(call.captured)
        close_native(f, call.socket, call.captured)
        assert_effect_counts(f, call.captured, call.bound)
        finish(f, active.creators, peer_totals(all, [2, 1, 1, 1]))
      end
    end

    test "#{protocol} Store death leaves genuine old G T rights valid and fresh admission fails before effects" do
      [a, b] = all = peers(@failure_protocol, 2)
      f = environment(@failure_protocol, :http1)
      c = healthy(f, candidate(f, [a.source, b.source], :store_death), all)
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      c = activate(f, c, initial)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      call = capture_request(f, c, :store_death, "/before-store-death")
      assert :ok = GenServer.stop(f.store, :normal, @timeout)
      assert {:error, :generation_unavailable} = Generation.snapshot(f.store)
      await_closed(f, c, [call.captured])
      before_t = :sys.get_state(f.owner)
      before_g = :sys.get_state(f.groups)
      _ = collect_effects([])
      {fresh, _} = connect(f)
      gate = service_gate(f)

      [native] =
        for {_, lease} <- :sys.get_state(gate).leases,
            lease.pid != call.captured.native,
            do: lease.pid

      monitor = Process.monitor(native)
      assert :ok = F.send_request(f, fresh, "GET", "/after-store-death")
      assert %{status: 500, body: ""} = F.response(f, fresh)
      assert_receive {:DOWN, ^monitor, :process, ^native, {:shutdown, :local_closed}}, @timeout
      assert :ok = :gen_tcp.close(fresh)
      after_t = :sys.get_state(f.owner)
      after_g = :sys.get_state(f.groups)
      assert after_t.pins === before_t.pins and after_t.tokens === before_t.tokens
      assert after_g.pins === before_g.pins and after_g.tokens === before_g.tokens
      effects = collect_effects([])

      refute Enum.any?(effects, fn {_, _, tag, _} ->
               tag in [:pin, :pin_many, :checkout, :delegate_request_pin, :bind, :bind_completion]
             end)

      [call] = dispatch_calls(f, c, [call], all, [0])
      complete_return(f, call, "survives")
      return_endpoint(call.captured)
      join_resource(f, c)
      close_native(f, call.socket, call.captured)
      finish(f, [], peer_totals(all, [2, 1]))
    end

    for mutation <- [
          :missing_group,
          :missing_selected,
          :missing_unselected,
          :forged_group_ref,
          :forged_group_operation,
          :forged_group_epoch,
          :forged_transport_ref,
          :wrong_transport_holder
        ] do
      @failure_mutation mutation
      @failure_group_attempt if(
                               mutation in [
                                 :forged_group_ref,
                                 :forged_group_operation,
                                 :forged_transport_ref
                               ],
                               do: 1,
                               else: 0
                             )
      @failure_status if(
                        mutation in [
                          :forged_group_ref,
                          :forged_group_operation,
                          :forged_transport_ref
                        ],
                        do: 502,
                        else: 503
                      )
      @failure_delegation if(mutation == :forged_transport_ref, do: 1, else: 0)
      test "#{protocol} #{@failure_mutation} of nonempty genuine capture refuses without alternate allocation" do
        [a, b] = all = peers(@failure_protocol, 2)
        f = environment(@failure_protocol, :http1)

        c =
          healthy(
            f,
            candidate(f, [a.source, b.source], :corrupt, mutation: @failure_mutation),
            all
          )

        assert {:ok, initial, _} = Generation.snapshot(f.store)
        c = activate(f, c, initial)
        add_listener(f)
        observe_owner(f)
        call = capture_request(f, c, :corrupt, "/refused")
        before = failure_health(f, c)
        dispatch(call.captured)

        failure_response(f, call, @failure_status)

        assert_sources(f, c, call.captured)
        assert_no_open(f, c)
        assert failure_health(f, c) === before
        effects = collect_effects([])

        group_attempt = @failure_group_attempt

        assert Enum.count(effects, fn {o, _, tag, _} -> o == f.groups and tag == :checkout end) ==
                 group_attempt

        delegation = @failure_delegation

        assert Enum.count(effects, fn {o, _, tag, _} ->
                 o == f.owner and tag == :delegate_request_pin
               end) == delegation

        refute Enum.any?(effects, fn {o, _, tag, _} ->
                 o == f.owner and tag in [:checkout, :bind_completion]
               end)

        refute Enum.any?(effects, fn {_, caller, tag, _} ->
                 caller == call.captured.native and tag in [:pin, :pin_many]
               end)

        failure_close_returned(f, call)
        finish(f, c.creators, peer_totals(all, [1, 1]))
      end
    end

    test "#{protocol} genuine selected transport rejects a foreign instance before checkout" do
      [a, b] = all = peers(@failure_protocol, 2)
      f = environment(@failure_protocol, :http1)
      assert {:ok, foreign} = Gaoxy.start_link()
      Process.unlink(foreign)
      monitor = Process.monitor(foreign)
      on_exit(fn -> if Process.alive?(foreign), do: Gaoxy.stop(foreign, @timeout) end)

      c =
        healthy(
          f,
          candidate(f, [a.source, b.source], :mismatch, mutation: {:instance, foreign}),
          all
        )

      assert {:ok, initial, _} = Generation.snapshot(f.store)
      c = activate(f, c, initial)
      add_listener(f)
      observe_owner(f)
      failure_observe_delegation(f.owner)
      call = capture_request(f, c, :mismatch, "/foreign-instance")
      health = failure_health(f, c)
      dispatch(call.captured)
      failure_response(f, call, 503)
      owner = f.owner
      native = call.captured.native

      assert_receive {:group_failure_delegation_result, ^owner, ^native,
                      {:error, :transport_endpoint_mismatch}},
                     @timeout

      assert_sources(f, c, call.captured)
      assert_no_open(f, c)
      assert failure_health(f, c) === health
      effects = collect_effects([])

      assert Enum.count(effects, fn {o, _, tag, _} ->
               o == owner and tag == :delegate_request_pin
             end) == 1

      refute Enum.any?(effects, fn {o, _, tag, _} ->
               o == owner and tag in [:checkout, :bind_completion]
             end)

      failure_close_returned(f, call)
      finish(f, c.creators, peer_totals(all, [1, 1]))
      assert :ok = Gaoxy.stop(foreign, @timeout)
      assert_receive {:DOWN, ^monitor, :process, ^foreign, :normal}, @timeout
    end

    test "#{protocol} cancellation revokes the exact original selected delegation before checkout" do
      [a, b] = all = peers(@failure_protocol, 2)
      f = environment(@failure_protocol, :http1)
      c = healthy(f, candidate(f, [a.source, b.source], :cancel), all)
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      c = activate(f, c, initial)
      add_listener(f)
      observe_owner(f)
      failure_observe_delegation(f.owner)
      call = capture_request(f, c, :cancel, "/cancel-at-original-input")
      health = failure_health(f, c)
      barrier = failure_delegation_barrier(f.owner)
      dispatch(call.captured)
      owner = f.owner
      native = call.captured.native
      source = call.captured.tpin

      assert_receive {:group_failure_delegation_held, ^owner, ^native, selected, ^source, session,
                      operation, deadline},
                     @timeout

      assert selected === hd(c.transports) and is_reference(operation)
      assert deadline <= call.captured.exchange.deadline
      state = :sys.get_state(session)
      assert state.owner === native and state.awaiting_transport.handle === selected
      assert state.transport_pins == [] and state.original_request == nil and state.request == nil
      monitor = Process.monitor(session)
      Gaoxy.Proxy.HTTP.Session.cancel(session)
      assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, @timeout
      send(owner, {:group_failure_continue, barrier})

      assert_receive {:group_failure_delegation_result, ^owner, ^native,
                      {:error, {:deadline_exceeded, :cleanup_pending}}},
                     @timeout

      failure_response(f, call, 502)
      assert_receive {:group_owner_cancel, ^owner, ^native, ^operation}, @timeout
      assert :sys.get_state(owner).pins[source.ref].delegations == %{}
      assert_no_open(f, c)
      assert failure_health(f, c) === health
      effects = collect_effects([])

      assert Enum.count(effects, fn {o, caller, tag, message} ->
               o == owner and caller == native and
                 tag == :delegate_request_pin and elem(message, 6) == operation
             end) == 1

      refute Enum.any?(effects, fn {o, _, tag, _} ->
               o == owner and tag in [:checkout, :bind_completion]
             end)

      failure_close_returned(f, call)
      finish(f, c.creators, peer_totals(all, [1, 1]))
    end

    test "#{protocol} same-owner global token denial cancels selected G without alternate Fetch or health change" do
      [a, b] = all = peers(@failure_protocol, 2)

      f =
        environment(@failure_protocol, :http1,
          transport_limits: %{max_request_tokens: 1},
          group_limits: %{max_probes: 1}
        )

      c = healthy(f, candidate(f, [a.source, b.source], :global_denial), all)
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      c = activate(f, c, initial)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      first = capture_request(f, c, :global_denial, "/global-first")
      [first] = dispatch_calls(f, c, [first], all, [0])
      health = failure_health(f, c)
      assert {:ok, %{request_tokens: 1}} = Transports.status(f.owner)
      second = capture_request(f, c, :global_denial, "/global-denied")
      dispatch(second.captured)
      failure_response(f, second, 503)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(first.bound.completion, 0)
      assert failure_health(f, c) === health
      effects = collect_effects([])
      native = second.captured.native

      [{_, _, :delegate_request_pin, delegation}] =
        Enum.filter(effects, fn {o, caller, tag, _} ->
          o == f.owner and caller == native and tag == :delegate_request_pin
        end)

      session = elem(delegation, 3)

      [{_, ^session, :checkout, group_input}] =
        Enum.filter(effects, fn {o, caller, tag, _} ->
          o == f.groups and caller == session and tag == :checkout
        end)

      assert elem(group_input, 1) === c.group

      [{_, ^session, :checkout, transport_input}] =
        Enum.filter(effects, fn {o, caller, tag, _} ->
          o == f.owner and caller == session and tag == :checkout
        end)

      assert elem(transport_input, 1) === Enum.at(c.transports, 1)

      [{_, ^session, :finish, finish_input}] =
        Enum.filter(effects, fn {o, caller, tag, _} ->
          o == f.groups and caller == session and tag == :finish
        end)

      assert elem(finish_input, 3) == :cancelled

      refute Enum.any?(effects, fn {o, caller, tag, _} ->
               o == f.owner and caller == session and tag == :bind_completion
             end)

      assert Enum.count(:sys.get_state(f.groups).tokens, fn {_, t} ->
               t.guardian == first.bound.session
             end) == 1

      failure_close_returned(f, second)
      complete_return(f, first, "original")
      return_endpoint(first.captured)
      close_native(f, first.socket, first.captured)
      finish(f, c.creators, peer_totals(all, [2, 1]))
    end
  end

  defp failure_assert_active(f, c) do
    generation = c.generation
    assert {:ok, ^generation, router} = Generation.snapshot(f.store)
    assert router === c.router
    for t <- c.transports, do: assert(configured_pins(f, t) == [:baseline])
    assert :sys.get_state(f.groups).groups[group_key(c.group)].lifecycle == :active
  end

  defp failure_health(f, c) do
    for m <- :sys.get_state(f.groups).groups[group_key(c.group)].members,
        do: Map.take(m, [:health, :failures, :successes, :checked, :due, :probe])
  end

  defp failure_response(f, call, status) do
    assert %{status: ^status, body: ""} = F.response(f, call.socket)
    native = call.captured.native
    ref = call.captured.ref
    label = call.captured.label

    assert_receive {:group_generation_return, ^native, ^ref, ^label,
                    {:ok, %Gaoxy.HTTP.Exchange{close: true}}},
                   @timeout

    assert :sys.get_state(f.owner).pins[call.captured.tpin.ref].public === call.captured.tpin
    assert :sys.get_state(f.groups).pins[call.captured.gpin.ref].holder === native
  end

  defp failure_close_returned(_f, call) do
    return_endpoint(call.captured)
    native = call.captured.native
    monitor = call.captured.native_monitor
    assert_receive {:DOWN, ^monitor, :process, ^native, {:shutdown, :local_closed}}, @timeout
    assert :ok = :gen_tcp.close(call.socket)
  end

  defp failure_delegation_barrier(owner) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      case event do
        {:in,
         {:"$gen_call", {native, _},
          {:delegate_request_pin, handle, source, session, _, _, operation, deadline}}}
        when not held ->
          send(
            parent,
            {:group_failure_delegation_held, self(), native, handle, source, session, operation,
             deadline}
          )

          receive do
            {:group_failure_continue, ^barrier} -> :ok
          after
            @timeout -> raise "original selected delegation barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, false})
    on_exit(fn -> send(owner, {:group_failure_continue, barrier}) end)
    barrier
  end

  defp failure_observe_delegation(owner) do
    parent = self()

    debug = fn phase, event, _ ->
      case event do
        {:in, {:"$gen_call", {native, _}, {:delegate_request_pin, _, _, _, _, _, _, _}}} ->
          {:delegating, native}

        {:out, result, _, _} ->
          case phase do
            {:delegating, native} ->
              send(parent, {:group_failure_delegation_result, self(), native, result})

            _ ->
              :ok
          end

          nil

        _ ->
          phase
      end
    end

    :ok = :sys.install(owner, {make_ref(), debug, nil})
  end

  for protocol <- [:h2c, :http2] do
    @late_protocol protocol
    test "#{protocol} short stop failure survives genuine original completion and late physical cleanup" do
      [a, b] = all = peers(@late_protocol, 2)
      peer = a.pid
      f = environment(@late_protocol, :http1)
      active = healthy(f, candidate(f, [a.source, b.source], :late), all)
      assert {:ok, expected, _} = Generation.snapshot(f.store)
      active = activate(f, active, expected)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      {socket, baseline} = connect(f)
      :ok = F.send_request(f, socket, "GET", "/late-original-completion")
      captured = capture(f, active, :late, baseline)
      dispatch(captured)
      seen = request_at(f, peer, active, 0, "/late-original-completion")
      held = bound(f, active, captured, 0)
      owner = f.owner
      native = captured.native
      session = held.session
      native_monitor = captured.native_monitor
      completion = held.completion
      assert {:ok, address} = Gaoxy.info(f.instance, :http).local
      {:ok, service, _} = GenServer.call(f.instance, {:lookup, :http})
      service_monitor = Process.monitor(service)

      F.command(peer, seen, "respond", %{"fields" => [["content-length", "4"]], "ended" => false})
      assert F.h1_head(socket) =~ "200 OK"
      assert :erlang.suspend_process(native)
      on_exit(fn -> failure_safe_resume(native) end)

      try do
        F.command(peer, seen, "data", %{"body64" => Base.encode64("late"), "ended" => false})
        F.eventually(fn -> :sys.get_state(session).delivery != nil end)
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
        ledger = :sys.get_state(owner)
        assert ledger.tokens[held.transport_token].completion === completion
        assert ledger.pins[held.child.ref].public === held.child
        assert ledger.pins[captured.tpin.ref].public === captured.tpin
        gs = :sys.get_state(f.groups)
        assert gs.tokens[held.group_token].completion === completion
        assert gs.pins[captured.gpin.ref].holder === native
        assert_group_ledgers(f)

        [baseline] =
          for pin <- :sys.get_state(f.store).baseline, pin.provider == Transports, do: pin

        assert baseline.kind == :baseline and baseline.handles === active.transports
        assert baseline.holder == f.store
        assert ledger.pins[baseline.ref].public === baseline
        assert ledger.pins[baseline.ref].acquirer == f.store
        refute Map.get(ledger.pins[baseline.ref], :derived, false)
        assert captured.tpin.kind == :request and captured.tpin.handles === active.transports
        assert captured.tpin.holder == native
        assert ledger.pins[captured.tpin.ref].acquirer == f.store
        refute Map.get(ledger.pins[captured.tpin.ref], :derived, false)
        child = Map.fetch!(ledger.pins, held.child.ref)
        assert child.public === held.child and child.public.kind == :request
        assert child.public.handles === [held.selected] and child.public.holder == session

        assert child.acquirer == native and child.derived and
                 child.source_ref == captured.tpin.ref

        assert ledger.pins[captured.tpin.ref].delegations == %{
                 held.selected.resource => %{
                   guardian: session,
                   operation: held.child.operation,
                   ref: held.child.ref
                 }
               }

        assert MapSet.new(Map.keys(ledger.pins)) ==
                 MapSet.new([baseline.ref, captured.tpin.ref, held.child.ref])

        assert map_size(ledger.pins) == 3
        assert Enum.sum(for {_, p} <- ledger.pins, do: length(p.public.handles)) == 5

        assert {:ok,
                %{
                  resources: 2,
                  reserved_connections: 4,
                  request_tokens: 1,
                  pins: 5,
                  helpers: 0,
                  failed_resources: 0
                }} = Transports.status(owner)

        assert %{cleanup_pending: 1, retained_bytes: bytes, cleanup_failed: nil} =
                 Gaoxy.status(f.instance, :http)

        assert bytes > 0

        cleanup_token = :sys.get_state(session).token
        gate = captured.exchange.gate

        observed =
          failure_late_ledgers(
            service,
            gate,
            native,
            captured.exchange.lease,
            session,
            cleanup_token
          )

        cancellation = failure_late_barrier(session, :session_cancel)
        retirement = failure_late_barrier(owner, :owner_retire)
        instance_done = failure_late_barrier(f.instance, :instance_done)
        failure = Gaoxy.stop(f.instance, 0)
        assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
        assert_receive {:group_failure_late_held, ^owner, :owner_retire, issued}, @timeout
        assert Lifecycle.remaining(issued) == 0
        assert_receive {:group_failure_late_held, ^session, :session_cancel, _}, @timeout
        assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, @timeout
        instance = f.instance
        assert_receive {:group_failure_late_held, ^instance, :instance_done, ^failure}, @timeout
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

        assert_receive {:trace, ^gate, :call, {Gaoxy.Admission, :handle_call, 3},
                        {:group_late_gate_force, 1, 1, total, native_bytes, cleanup_bytes, true,
                         true, true, false}},
                       @timeout

        assert {total, native_bytes, cleanup_bytes} == observed.charged
        gate_monitor = observed.gate_monitor
        assert_receive {:DOWN, ^gate_monitor, :process, ^gate, :killed}, @timeout

        # The real original public barrier joins independently AFTER failed stop.
        # Session still holds the expired Service cancellation, so no zero-time
        # abort can convert an in-flight original cleanup into uncertainty.
        assert :ok = HTTP.RequestCompletion.abort_and_await(completion, @timeout)
        assert :ok = HTTP.RequestCompletion.await(completion, 0)
        assert Process.alive?(session)

        send(owner, {:group_failure_continue, retirement})
        assert {:ok, receipt} = Transports.retire(owner, Lifecycle.deadline(@timeout))
        assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
        # Only now release actual original-request cancellation and join it.
        send(session, {:group_failure_continue, cancellation})
        assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
        session_monitor = held.monitor
        assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, @timeout
        assert_receive {:group_late_service_receipt, ^service, true, 1, nil}, @timeout

        assert_receive {:trace, ^service, :call, {Gaoxy.Service, :terminate, 2},
                        {:group_late_service_terminal, :normal, :stopped, 0, nil, true}},
                       @timeout

        for p <- all do
          assert %{"connection" => 1} = F.physical_termination(p.pid)
        end

        F.eventually(fn -> failure_owner_zero?(owner) end)
        assert :sys.get_state(owner).retirement.result == failure
        assert Transports.await_retirement(receipt, Lifecycle.deadline(@timeout)) == failure
        # Store still exists; terminal owner settlement must not rewrite receipt.
        assert :ok = GenServer.stop(f.store, :normal, @timeout)
        assert :sys.get_state(owner).retirement.result == failure
        assert :ok = HTTP.RequestCompletion.await(completion, 0)

        F.eventually(fn ->
          g = :sys.get_state(f.groups)

          g.groups == %{} and g.pins == %{} and g.tokens == %{} and g.probes == %{} and
            g.bytes == 0 and g.probe_bytes == 0 and g.control_bytes == 0
        end)

        assert :ok = GenServer.stop(f.groups, :normal, @timeout)
        send(instance, {:group_failure_continue, instance_done})
        failure_finish_stopped(f, active, all, address, service, service_monitor)
        assert failure == {:error, {:deadline_exceeded, :cleanup_pending}}
      after
        failure_safe_resume(native)
        :gen_tcp.close(socket)
      end
    end
  end

  defp failure_late_ledgers(service, gate, native, lease_ref, guardian, cleanup_token) do
    caller = self()
    original = :sys.get_state(gate)
    original_lease = Map.fetch!(original.leases, lease_ref)
    original_cleanup = Map.fetch!(original.cleanups, cleanup_token)
    assert original_lease.pid == native
    assert original_lease.cleanup == cleanup_token
    assert original_cleanup.lease == lease_ref
    assert original_cleanup.receipt == false
    assert map_size(original.leases) == 1
    assert map_size(original.cleanups) == 1
    assert original.bytes == original_lease.bytes + original_cleanup.bytes
    assert original_lease.bytes > 0 and original_cleanup.bytes > 0
    gate_monitor = Process.monitor(gate)

    trace_session = :trace.session_create(:group_generation_late_ledger, caller, [])
    on_exit(fn -> :trace.session_destroy(trace_session) end)

    # Only compact integers/booleans leave the match specification. :arity means
    # the call trace contains MFA arity, NEVER the actual state argument.
    lease = {:map_get, lease_ref, :"$1"}
    cleanup = {:map_get, cleanup_token, :"$2"}

    gate_projection =
      {{:group_late_gate_force, {:map_size, :"$1"}, {:map_size, :"$2"}, :"$3",
        {:map_get, :bytes, lease}, {:map_get, :bytes, cleanup},
        {:"=:=", {:map_get, :pid, lease}, native},
        {:"=:=", {:map_get, :cleanup, lease}, cleanup_token},
        {:"=:=", {:map_get, :lease, cleanup}, lease_ref}, {:map_get, :receipt, cleanup}}}

    gate_pattern = [
      {[:force, {service, :_}, %{service: service, leases: :"$1", cleanups: :"$2", bytes: :"$3"}],
       [], [{:message, gate_projection}]}
    ]

    service_pattern = [
      {[
         :"$1",
         %{
           gate: gate,
           generation: :"$2",
           mode: :"$3",
           cleanups: :"$4",
           cleanup_failed: :"$5",
           drain: :"$6"
         }
       ], [{:"=:=", :"$2", {:const, :sys.get_state(service).generation}}],
       [
         {:message,
          {{:group_late_service_terminal, :"$1", :"$3", {:map_size, :"$4"}, :"$5",
            {:"=:=", :"$6", nil}}}}
       ]}
    ]

    assert :trace.function(trace_session, {Gaoxy.Admission, :handle_call, 3}, gate_pattern, [
             :local
           ]) == 1

    assert :trace.function(trace_session, {Gaoxy.Service, :terminate, 2}, service_pattern, [
             :local
           ]) == 1

    assert :trace.process(trace_session, gate, true, [:call, :arity]) == 1
    assert :trace.process(trace_session, service, true, [:call, :arity]) == 1

    # Real post-receipt callback state is safe through :sys here: this Service
    # cannot process its guardian DOWN until its own current debug hook returns.
    receipt_debug = fn phase, event, _ ->
      case {phase, event} do
        {:waiting, {:in, {:"$gen_call", {^guardian, _}, {:complete_cleanup, ^cleanup_token}}}} ->
          :receipt

        {:receipt, {:out, :ok, _, actual}} ->
          send(
            caller,
            {:group_late_service_receipt, service, actual.cleanups[cleanup_token].receipt,
             map_size(actual.cleanups), actual.cleanup_failed}
          )

          :done

        _ ->
          phase
      end
    end

    :ok = :sys.install(service, {make_ref(), receipt_debug, :waiting})

    %{
      trace_session: trace_session,
      gate_monitor: gate_monitor,
      charged: {original.bytes, original_lease.bytes, original_cleanup.bytes}
    }
  end

  defp failure_late_barrier(pid, family) do
    parent = self()
    barrier = make_ref()

    debug = fn held, event, _ ->
      value =
        case {family, event} do
          {:session_cancel, {:in, {:gaoxy_cleanup_cancel, _, _, _} = message}} -> {:hold, message}
          {:owner_retire, {:in, {:gaoxy_lifecycle_drain, _, _, _, deadline}}} -> {:hold, deadline}
          {:instance_done, {:in, {:operation_done, _, result}}} -> {:hold, result}
          _ -> :continue
        end

      case {held, value} do
        {false, {:hold, operand}} ->
          send(parent, {:group_failure_late_held, self(), family, operand})

          receive do
            {:group_failure_continue, ^barrier} -> :ok
          after
            5_000 -> raise "fixed failure late cleanup barrier expired"
          end

          true

        _ ->
          held
      end
    end

    :ok = :sys.install(pid, {make_ref(), debug, false})
    on_exit(fn -> send(pid, {:group_failure_continue, barrier}) end)
    barrier
  end

  defp failure_owner_zero?(owner) do
    match?(
      {:ok,
       %{
         resources: 0,
         pins: 0,
         request_tokens: 0,
         helpers: 0,
         reserved_connections: 0,
         owned_serialized_payload_bytes: 0
       }},
      Transports.status(owner)
    )
  end

  defp failure_safe_resume(pid) do
    if Process.alive?(pid), do: :erlang.resume_process(pid)
  catch
    :error, :badarg -> :ok
  end

  defp failure_finish_stopped(f, active, peers, {ip, port}, service, service_monitor) do
    for {pid, monitor} <- f.joins do
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end

    for {pid, monitor} <- active.creators do
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end

    assert_receive {:DOWN, ^service_monitor, :process, ^service, :normal}, @timeout
    send(f.embedding, {:stop, self()})
    embedding = f.embedding

    assert_receive {:group_generation_environment_stopped, ^embedding, {:error, :not_running}},
                   2 * @timeout

    monitor = f.embedding_monitor
    assert_receive {:DOWN, ^monitor, :process, ^embedding, :normal}, @timeout

    assert {:ok, rebound} =
             :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])

    assert :ok = :gen_tcp.close(rebound)

    for {p, expected} <- Enum.zip(peers, [2, 1]) do
      peer = p.pid
      monitor = Process.monitor(peer)
      assert Process.get({F, :observed_requests, peer}) == expected
      send(peer, {:command, %{"op" => "stop"}})

      assert %{
               "forced" => 0,
               "live" => 0,
               "failed" => false,
               "accepts" => 1,
               "requests" => ^expected
             } = F.event(peer, "joined")

      assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
      assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout
    end
  end
end
