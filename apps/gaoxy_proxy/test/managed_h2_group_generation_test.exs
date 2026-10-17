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

  # The route publishes OLD resources; only its explicit negative call uses
  # NEW config, retained before capture inside the real bounded route/Exchange.
  defmodule RotationMisuseGroup do
    @behaviour Gaoxy.HTTP.Endpoint
    def init({old_options, new_options, parent, label}) do
      with {:ok, old_config} <- Gaoxy.Proxy.GroupEndpoint.init(old_options),
           {:ok, new_config} <- Gaoxy.Proxy.GroupEndpoint.init(new_options),
           do: {:ok, {old_config, new_config, parent, label}}
    end

    def resources({old_config, _, _, _}), do: Gaoxy.Proxy.GroupEndpoint.resources(old_config)

    def call(exchange, {_old_config, explicit_new_config, parent, label}) do
      ref = make_ref()
      send(parent, {:group_generation_capture, self(), ref, label, exchange})

      receive do
        {:dispatch, ^ref} -> :ok
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "group identity misuse dispatch barrier expired"
      end

      # Authentic Exchange and source pins remain unchanged for finally release.
      result = Gaoxy.Proxy.GroupEndpoint.call(exchange, explicit_new_config)
      send(parent, {:group_generation_return, self(), ref, label, result})

      receive do
        {:return, ^ref} -> result
      after
        min(5_000, Gaoxy.Lifecycle.remaining(exchange.deadline)) ->
          raise "group identity misuse return barrier expired"
      end
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

  for downstream <- [:http1, :http2] do
    @rotation_downstream downstream
    @tag :managed_h2_identity_rotation
    @tag :tmp_dir
    test "#{downstream} to TLS H2 rotated groups select0→1→0 with cold same-authority identity",
         %{tmp_dir: tmp_dir} do
      peers = rotation_peers(tmp_dir)
      f = environment(:http2, @rotation_downstream)
      old = healthy(f, candidate(f, Enum.map(peers.old, & &1.source), :old), peers.old)
      assert {:ok, initial, _} = Generation.snapshot(f.store)
      old = activate(f, old, initial)
      old_policies = rotation_policies(f, old)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)

      old_calls =
        rotation_capture_requests(f, old, :old, Enum.map(0..2, &"/old#{&1}%2Fpath?raw=%2F"))

      assert_no_open(f, old)
      old = rotation_close_health(f, old)
      new_sources = rotation_replacement_sources(peers)
      fresh = healthy(f, candidate(f, new_sources, :new), peers.new)
      fresh = rotation_close_health(f, fresh)
      fresh = activate(f, fresh, old.generation)
      proof = rotation_identity_policies(f, peers, old, fresh, old_policies)
      await_closed(f, old, Enum.map(old_calls, & &1.captured))
      old_calls = rotation_dispatch_calls(f, old, old_calls, peers.old, [0, 1, 0])

      new_calls =
        rotation_capture_requests(f, fresh, :new, Enum.map(0..2, &"/new#{&1}%2Fpath?"))
        |> then(&rotation_dispatch_calls(f, fresh, &1, peers.new, [0, 1, 0]))

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

      # The completed B health socket was already joined. Its fresh connection
      # and actual T/custodian still remain until the last original [A,B] source.
      assert last.bound.index == 0 and last.captured.tpin.handles === old.transports

      for peer <- peers.old do
        F.no_event(peer.pid, "eof")
        F.no_event(peer.pid, "connection_reset")
      end

      return_endpoint(last.captured)
      join_resource(f, old)
      close_calls(f, old_calls)
      for call <- old_calls ++ new_calls, do: assert_effect_counts(f, call.captured, call.bound)

      finish(
        f,
        fresh.creators,
        Enum.map(Enum.zip(peers.old ++ peers.new, [3, 2, 3, 2]), fn {peer, requests} ->
          {peer.pid, 2, requests}
        end),
        2
      )

      IO.puts(
        JSON.encode!(%{
          event: "group_identity_rotation",
          downstream: f.downstream,
          identities: proof,
          old_capture_before_replacement: true,
          source_invalidated: true,
          old_policy_unchanged: true,
          selection: [0, 1, 0],
          health_connections_closed: [1, 1, 1, 1],
          forward_connections: Enum.map(old_calls ++ new_calls, & &1.request["connection"]),
          accepts: [2, 2, 2, 2],
          requests: [3, 2, 3, 2],
          proxy_authorization_stripped: true,
          origin_authorization_isolated: true,
          original_completions_and_resource_joins: true
        })
      )
    end
  end

  @tag :managed_h2_identity_rotation
  @tag :tmp_dir
  test "equal authority NEW group cannot consume authentic OLD Generation G T captures",
       %{tmp_dir: tmp_dir} do
    peers = rotation_peers(tmp_dir)
    f = environment(:http2, :http1)
    # Negative-only order freezes explicit NEW config inside OLD's measured M
    # before capture. Positive cells above perform replacement after OLD capture.
    fresh = healthy(f, candidate(f, rotation_replacement_sources(peers), :new), peers.new)

    old =
      healthy(
        f,
        candidate(f, Enum.map(peers.old, & &1.source), :rotation_misuse,
          explicit_new_group: fresh.group
        ),
        peers.old
      )

    assert {:ok, initial, _} = Generation.snapshot(f.store)
    old = activate(f, old, initial)
    old_policies = rotation_policies(f, old)
    add_listener(f)
    observe_owner(f)
    call = capture_request(f, old, :rotation_misuse, "/cross-group%2Fnever?raw=%2F")
    fresh = activate(f, fresh, old.generation)
    proof = rotation_identity_policies(f, peers, old, fresh, old_policies)
    await_closed(f, old, [call.captured])
    assert_no_open(f, old)
    assert_no_open(f, fresh)
    before_t = :sys.get_state(f.owner)
    before_g = :sys.get_state(f.groups)
    _ = collect_effects([])
    trace_session = rotation_misuse_observe(call.captured.native)
    dispatch(call.captured)
    failure_response(f, call, 503)
    native = call.captured.native
    delivered = :trace.delivered(trace_session, native)
    assert_receive {:trace_delivered, ^native, ^delivered}, @timeout

    refute_receive {:trace, ^native, :call, {DynamicSupervisor, :start_child, 2},
                    :group_rotation_misuse_session_start},
                   0

    refute_receive {:trace, ^native, :call, {HTTP, :fetch, 2}, :group_rotation_misuse_fetch},
                   0

    # Synchronous reads fence the owner observers before checking effects.
    # No source/selection/token/member/policy state is changed by the refusal.
    assert :sys.get_state(f.owner) === before_t
    assert :sys.get_state(f.groups) === before_g
    assert_sources(f, old, call.captured)
    assert_no_open(f, old)
    assert_no_open(f, fresh)
    effects = collect_effects([])

    refute Enum.any?(effects, fn {_, _, tag, _} ->
             tag in [:checkout, :delegate_request_pin, :bind, :bind_completion, :finish]
           end)

    refute Enum.any?(effects, fn {_, caller, tag, _} ->
             caller == native and tag in [:pin, :pin_many]
           end)

    for peer <- peers.old ++ peers.new do
      F.no_event(peer.pid, "accept")
      F.no_event(peer.pid, "tls")
      F.no_event(peer.pid, "request")
    end

    assert_cleanup(f, 0)
    assert_group_ledgers(f)
    for {pid, _} <- old.creators, do: assert(Process.alive?(pid))
    failure_close_returned(f, call)
    join_resource(f, old)
    finish(f, fresh.creators, peer_totals(peers.old ++ peers.new, [1, 1, 1, 1]))

    IO.puts(
      JSON.encode!(%{
        event: "group_identity_rotation_misuse",
        downstream: :http1,
        identities: proof,
        same_authority: true,
        negative_config_retained_before_capture: true,
        authentic_old_exchange_unchanged: true,
        refused_before_session_selection_delegation_checkout_fetch: true,
        owner_states_unchanged: true,
        requests: [1, 1, 1, 1],
        request_scope: "health HEAD only; no selected forwarding"
      })
    )
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

        state.streams == %{} and state.starting == nil and
          not Map.has_key?(
            :sys.get_state(first.captured.exchange.gate).leases,
            first.captured.exchange.lease
          )
      end)

      assert_cleanup(f, 0)

      target = "/new-slice/" <> :binary.copy("~", 100)
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

      actual_target = captured.exchange.request.target
      assert actual_target == target
      assert byte_size(actual_target) < :binary.referenced_byte_size(actual_target)
      assert :binary.referenced_byte_size(actual_target) <= 65_536
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

  defp rotation_peers(tmp_dir) do
    {old_a, old_a_ready} =
      F.peer(:http2, ["--manual", "--bind-address", "127.0.0.1", "--listen-port", "0"])

    port = old_a_ready["port"]
    assert port in 1..65_535

    more =
      Enum.map(["127.0.0.3", "127.0.0.2", "127.0.0.4"], fn address ->
        {pid, ready} =
          F.peer(:http2, [
            "--manual",
            "--bind-address",
            address,
            "--listen-port",
            Integer.to_string(port)
          ])

        assert ready["bind_address"] == address and ready["port"] == port
        %{pid: pid, ready: ready}
      end)

    assert old_a_ready["bind_address"] == "127.0.0.1"
    [ob, na, nb] = more
    oa = %{pid: old_a, ready: old_a_ready}
    all = [oa, ob, na, nb]

    assert Enum.uniq(Enum.map(all, &{&1.ready["bind_address"], &1.ready["port"]})) ==
             [{"127.0.0.1", port}, {"127.0.0.3", port}, {"127.0.0.2", port}, {"127.0.0.4", port}]

    assert length(Enum.uniq(Enum.map(all, & &1.ready["identity"]["certificate_sha256"]))) == 4
    paths = Enum.map(["a", "b"], &Path.join(tmp_dir, "member-#{&1}-ca.pem"))

    old =
      Enum.zip_with([oa, ob], paths, fn peer, path ->
        File.cp!(peer.ready["ca"], path)
        {:ok, address} = :inet.parse_address(String.to_charlist(peer.ready["bind_address"]))
        Map.put(peer, :source, rotation_source(port, address, path))
      end)

    %{
      old: old,
      new: [na, nb],
      paths: paths,
      old_pem_sha256: Enum.map(paths, &rotation_hash(rotation_pem(&1))),
      origin: "https://localhost:#{port}",
      port: port
    }
  end

  defp rotation_replacement_sources(peers) do
    Enum.zip([peers.new, peers.paths, peers.old, peers.old_pem_sha256])
    |> Enum.map(fn {peer, path, old, old_pem_sha256} ->
      File.cp!(peer.ready["ca"], path)
      refute rotation_hash(rotation_pem(path)) == old_pem_sha256
      {:ok, address} = :inet.parse_address(String.to_charlist(peer.ready["bind_address"]))
      source = rotation_source(peers.port, address, path)
      assert source.origin === old.source.origin and source.origin === peers.origin
      refute source.trust === old.source.trust
      refute source.connect_address == old.source.connect_address
      source
    end)
  end

  defp rotation_source(port, address, path) do
    assert [{:Certificate, der, :not_encrypted}] = :public_key.pem_decode(rotation_pem(path))
    assert byte_size(der) in 1..65_536

    %{
      protocol: :http2,
      origin: "https://localhost:#{port}",
      connect_address: address,
      trust: [:binary.copy(der)]
    }
  end

  defp rotation_pem(path) do
    File.open!(path, [:read, :binary], fn file ->
      pem = IO.binread(file, 1_048_577)
      assert is_binary(pem) and byte_size(pem) in 1..1_048_576
      pem
    end)
  end

  defp rotation_hash(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp rotation_policies(f, candidate) do
    records = :sys.get_state(f.owner).records
    Enum.map(candidate.transports, &records[&1.resource].policy)
  end

  defp rotation_identity_policies(f, peers, old, fresh, old_policies) do
    assert rotation_policies(f, old) === old_policies
    fresh_policies = rotation_policies(f, fresh)
    refute group_key(old.group) == group_key(fresh.group)
    assert length(Enum.uniq(Enum.map(old.transports ++ fresh.transports, & &1.resource))) == 4

    proof =
      Enum.zip([
        old.transports,
        fresh.transports,
        old.sources,
        fresh.sources,
        old_policies,
        fresh_policies,
        peers.old,
        peers.new,
        peers.paths,
        peers.old_pem_sha256
      ])
      |> Enum.map(fn {ot, nt, os, ns, op, np, old_peer, new_peer, path, old_pem_sha256} ->
        assert os.origin === ns.origin and os.origin === peers.origin
        assert op.origin === np.origin and op.host == "localhost" and np.host == "localhost"
        assert op.port == peers.port and np.port == peers.port
        assert op.protocol == :http2 and np.protocol == :http2
        assert op.connect_address === os.connect_address
        assert np.connect_address === ns.connect_address
        assert op.open_options[:ssl][:cacerts] === os.trust
        assert np.open_options[:ssl][:cacerts] === ns.trust
        refute op.connect_address == np.connect_address
        refute op.open_options[:ssl][:cacerts] === np.open_options[:ssl][:cacerts]
        assert op.open_options[:ssl][:server_name_indication] == ~c"localhost"
        assert np.open_options[:ssl][:server_name_indication] == ~c"localhost"

        assert op.open_options[:http_version] == :http2 and
                 np.open_options[:http_version] == :http2

        assert op.open_options[:ssl][:verify] == :verify_peer
        assert np.open_options[:ssl][:verify] == :verify_peer

        old_identity = rotation_identity(old.group, ot, old_peer.ready, old_pem_sha256, op)

        new_identity =
          rotation_identity(
            fresh.group,
            nt,
            new_peer.ready,
            rotation_hash(rotation_pem(path)),
            np
          )

        refute old_identity.pem_sha256 == new_identity.pem_sha256
        refute old_identity.der_sha256 == new_identity.der_sha256
        refute old_identity.leaf_sha256 == new_identity.leaf_sha256
        File.write!(path, "invalid public source after both member preparations\n")
        %{path: path, old: old_identity, new: new_identity}
      end)

    assert rotation_policies(f, old) === old_policies
    assert rotation_policies(f, fresh) === fresh_policies
    assert length(Enum.uniq(Enum.flat_map(proof, &[&1.old.pem_sha256, &1.new.pem_sha256]))) == 4
    assert length(Enum.uniq(Enum.flat_map(proof, &[&1.old.der_sha256, &1.new.der_sha256]))) == 4
    proof
  end

  defp rotation_identity(group, transport, ready, pem_sha256, policy) do
    leaf_sha256 = rotation_hash(rotation_pem(ready["cert"]))
    assert leaf_sha256 == ready["identity"]["certificate_sha256"]

    %{
      group: inspect(group_key(group)),
      resource: inspect(transport.resource),
      origin: policy.origin,
      host: policy.host,
      port: policy.port,
      connect_address: policy.connect_address |> :inet.ntoa() |> to_string(),
      pem_sha256: pem_sha256,
      der_sha256: Enum.map(policy.open_options[:ssl][:cacerts], &rotation_hash/1),
      leaf_sha256: leaf_sha256
    }
  end

  defp rotation_close_health(f, candidate) do
    assert_no_open(f, candidate)
    assert_group_ledgers(f)

    health =
      Enum.with_index(candidate.health, fn entry, index ->
        # healthy/3 already witnessed the original HEAD completion, normal Probe
        # DOWN and restored accounting. GOAWAY uses that exact completed stream.
        assert :ok = HTTP.RequestCompletion.await(entry.completion, 0)
        request = entry.request
        assert request["connection"] == 1

        assert [":authority", URI.parse(Enum.at(candidate.sources, index).origin).authority] in request[
                 "headers"
               ]

        assert [":scheme", "https"] in request["headers"]
        stream = request["stream"]

        assert %{
                 "op" => "goaway",
                 "connection" => 1,
                 "stream" => ^stream,
                 "last_stream" => ^stream,
                 "code" => 0
               } =
                 F.command(entry.peer, request, "goaway", %{"last_stream" => stream, "code" => 0})

        # GOAWAY is an admission/drain signal, not a TCP close guarantee.
        # End only the peer write side; the original reader must observe EOF/reset.
        assert %{"op" => "write_half_close", "connection" => 1, "stream" => ^stream} =
                 close_ack = F.command(entry.peer, request, "write_half_close")

        assert %{"connection" => 1} = termination = F.physical_termination(entry.peer)
        F.no_event(entry.peer, "accept")
        F.no_event(entry.peer, "tls")
        F.no_event(entry.peer, "request")

        entry
        |> Map.put(:write_half_close, close_ack)
        |> Map.put(:physical_termination, termination)
      end)

    assert_no_open(f, candidate)
    assert_group_ledgers(f)
    Map.put(candidate, :health, health)
  end

  defp rotation_fields(marker) do
    [
      {"proxy-authorization", "Basic synthetic-group-proxy-" <> marker},
      {"authorization", "Bearer synthetic-group-origin-" <> marker}
    ]
  end

  defp rotation_capture_requests(%{downstream: :http1} = f, c, label, targets) do
    Enum.with_index(targets, fn target, index ->
      {socket, baseline} = connect(f)
      marker = "#{label}-#{index}"
      assert :ok = F.send_request(f, socket, "GET", target, rotation_fields(marker))
      %{socket: socket, captured: capture(f, c, label, baseline), target: target, marker: marker}
    end)
  end

  defp rotation_capture_requests(%{downstream: :http2} = f, c, label, targets) do
    {socket, _} = connect(f)

    Enum.with_index(targets, fn target, index ->
      baseline = Gaoxy.status(f.instance, :http)
      id = 2 * index + 1
      marker = "#{label}-#{index}"
      assert :ok = F.send_request(f, socket, "GET", target, rotation_fields(marker), true, id)

      %{
        socket: socket,
        id: id,
        captured: capture(f, c, label, baseline),
        target: target,
        marker: marker
      }
    end)
  end

  defp rotation_dispatch_calls(f, c, calls, peers, indices) do
    {dispatched, _connections} =
      Enum.zip(calls, indices)
      |> Enum.map_reduce(%{}, fn {call, index}, connections ->
        peer = Enum.at(peers, index)
        dispatch(call.captured)
        request = rotation_request_at(f, peer.pid, c, index, call.target, connections[index])

        assert Enum.filter(request["headers"], fn [name, _] -> name == "proxy-authorization" end) ==
                 []

        assert Enum.filter(request["headers"], fn [name, _] -> name == "authorization" end) ==
                 [["authorization", "Bearer synthetic-group-origin-" <> call.marker]]

        held = bound(f, c, call.captured, index)
        result = Map.merge(call, %{peer: peer.pid, request: request, bound: held})
        {result, Map.put(connections, index, request["connection"])}
      end)

    dispatched
  end

  defp rotation_request_at(_f, peer, candidate, index, target, previous_connection) do
    health = Enum.at(candidate.health, index)
    assert health.peer == peer and health.physical_termination["connection"] == 1

    if is_nil(previous_connection) do
      assert %{"connection" => 2} = F.event(peer, "accept")
      assert %{"connection" => 2, "alpn" => "h2", "sni" => "localhost"} = F.event(peer, "tls")
    else
      assert previous_connection == 2
      F.no_event(peer, "accept")
      F.no_event(peer, "tls")
    end

    request = F.event(peer, "request")
    assert request["connection"] == 2
    refute request["connection"] == health.request["connection"]
    assert request["target"] == target and request["ended"]
    assert [":method", "GET"] in request["headers"]
    assert [":scheme", "https"] in request["headers"]

    assert [":authority", URI.parse(Enum.at(candidate.sources, index).origin).authority] in request[
             "headers"
           ]

    request
  end

  defp rotation_misuse_observe(native) do
    session = :trace.session_create(:group_generation_rotation_misuse, self(), [])
    on_exit(fn -> :trace.session_destroy(session) end)

    assert :trace.function(
             session,
             {DynamicSupervisor, :start_child, 2},
             [{:_, [], [{:message, :group_rotation_misuse_session_start}]}],
             []
           ) == 1

    assert :trace.function(
             session,
             {HTTP, :fetch, 2},
             [{:_, [], [{:message, :group_rotation_misuse_fetch}]}],
             []
           ) == 1

    assert :trace.process(session, native, true, [:call, :arity]) == 1
    session
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

            target =
              case Keyword.get(opts, :explicit_new_group) do
                nil -> target
                new_group -> {RotationMisuseGroup, {options, %{group: new_group}, parent, label}}
              end

            routes = [%{target: target}]
            {:ok, router} = Generation.prepare(f.store, routes)

            if Keyword.has_key?(opts, :explicit_new_group) do
              assert :erlang.external_size(routes) <= 1_048_576
              assert :erlang.external_size(router) <= 1_048_576
            end

            transports = Enum.map(unique, &elem(&1, 1))

            creators =
              Enum.map(transports, fn transport ->
                :sys.get_state(f.owner).records[transport.resource].custodian
              end)

            send(
              parent,
              {:group_candidate, self(), group, transports, members, routes, router, creators,
               compiled}
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
                    creators, compiled},
                   @timeout

    %{
      coordinator: coordinator,
      monitor: monitor,
      compiled: compiled,
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

  defp finish(f, creators, peers, expected_connection \\ 1) do
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
        assert %{"connection" => ^expected_connection} = F.physical_termination(peer)
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
      parent = self()
      old_native = call.captured.native
      barrier = make_ref()

      debug = fn held, event, _ ->
        case event do
          {:in, {:"$gen_call", {native, _} = from, {:begin_request, lease, _, _}}}
          when not held and native != old_native ->
            send(parent, {:group_store_death_begin_request, barrier, native, from, lease})

            receive do
              {:group_store_death_continue, ^barrier} -> :ok
            after
              @timeout -> raise "Store death begin_request barrier expired"
            end

            true

          _ ->
            held
        end
      end

      release = fn ->
        send(gate, {:group_store_death_continue, barrier})

        try do
          :sys.remove(gate, barrier, @timeout)
        catch
          :exit, {:noproc, _} -> :ok
          :exit, {:normal, _} -> :ok
        end
      end

      on_exit(release)
      :ok = :sys.install(gate, {barrier, debug, false})

      try do
        assert :ok = F.send_request(f, fresh, "GET", "/after-store-death")

        assert_receive {:group_store_death_begin_request, ^barrier, native, _from, _lease},
                       @timeout

        monitor = Process.monitor(native)
        release.()
        assert %{status: 500, body: ""} = F.response(f, fresh)
        assert_receive {:DOWN, ^monitor, :process, ^native, {:shutdown, :local_closed}}, @timeout
        assert :ok = :gen_tcp.close(fresh)
      after
        release.()
      end

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

  # Each test keeps the same owners, epochs, Store, listener and admission gate.
  # The vector and changing-inventory field sets are fixed before any resources.
  for protocol <- [:h2c, :http2], downstream <- [:http1, :http2], profile <- [:active, :idle] do
    @reload_protocol protocol
    @reload_downstream downstream
    @reload_profile profile
    @tag :managed_h2_group_reload_plateau
    @tag reload_profile: profile, reload_upstream: protocol, reload_downstream: downstream
    test "#{downstream} to #{protocol} group #{profile} twenty reloads retain exact plateau" do
      entered = System.monotonic_time(:millisecond)

      context = %{
        upstream: @reload_protocol,
        downstream: @reload_downstream,
        profile: @reload_profile
      }

      inventory = reload_inventory_fields()

      reload_emit(context, "contract", %{
        inventory: inventory,
        outer_exunit_timeout_ms: 60_000,
        embedding_lifetime_ms: 120_000,
        peer_lifetime_ms: 180_000,
        retirement_hold_ms: 2_000,
        planned_generations: 23,
        planned_transports: 46,
        planned_replacement_cas: 22,
        planned_heads: 46,
        planned_gets: if(@reload_profile == :active, do: 112, else: 46)
      })

      peers = reload_peers(@reload_protocol)
      embedding_before = System.monotonic_time(:millisecond)
      f = environment(@reload_protocol, @reload_downstream, group_limits: %{max_groups: 2})
      embedding_after = System.monotonic_time(:millisecond)
      classes = Enum.map(reload_epoch(peers, 0), & &1.class)
      f = Map.put(f, :reload_classes, classes)
      initial = reload_candidate(f, reload_epoch(peers, 0), 0)
      assert {:ok, empty, _} = Generation.snapshot(f.store)
      initial = activate(f, initial, empty)
      add_listener(f)
      observe_owner(f)
      observe_startup(f)
      {connections, seed} = reload_seed(f, initial, reload_epoch(peers, 0), 0)
      identity = reload_identity(f)
      gate = service_gate(f)
      reload_sample(f, initial, gate, classes)

      initial_row = %{
        index: 0,
        initial_publication: %{
          expected: reload_id(empty),
          activated: reload_id(initial.generation)
        },
        health: reload_health_receipts(initial),
        seed: seed,
        inventory: reload_inventory(f, initial, gate)
      }

      reload_emit(context, "setup", %{
        identity: reload_id(identity),
        entered_monotonic_ms: entered,
        setup_elapsed_ms: System.monotonic_time(:millisecond) - entered,
        embedding_creation_interval_monotonic_ms: [embedding_before, embedding_after],
        peers: Enum.map(peers, &reload_peer_public/1),
        classes: classes,
        ordered_pair_class: reload_pair_class(reload_epoch(peers, 0)),
        initial: initial_row
      })

      {current, connections, firststeady, samples, ledger} =
        Enum.reduce(1..22, {initial, connections, nil, [], [initial_row]}, fn cycle,
                                                                              {old,
                                                                               old_connections,
                                                                               steady, samples,
                                                                               ledger} ->
          assert reload_identity(f) === identity

          {fresh, connections, vector, row} =
            reload_cycle(f, peers, old, old_connections, @reload_profile, cycle)

          assert reload_identity(f) === identity
          steady = if cycle == 2, do: vector, else: steady
          if cycle >= 3, do: assert(vector === steady)
          samples = if cycle >= 3, do: [vector | samples], else: samples

          reload_emit(context, "cycle", %{
            cycle: cycle,
            measured: cycle >= 3,
            vector: vector,
            ledger: row,
            elapsed_ms: System.monotonic_time(:millisecond) - entered
          })

          {fresh, connections, steady, samples, ledger ++ [row]}
        end)

      assert firststeady != nil and length(samples) == 20
      assert Enum.all?(samples, &(&1 === firststeady))
      assert length(ledger) == 23
      assert reload_identity(f) === identity
      teardown_started = System.monotonic_time(:millisecond)
      # Keep the original Store monitor unread for finish/4.
      assert :ok = GenServer.stop(f.store, :normal, @timeout)
      final = reload_join_retired(f, current, reload_epoch(peers, 22), connections)
      final_epochs = Enum.map(reload_epoch(peers, 22), &reload_join_peer(&1, @reload_profile))
      final_zero = reload_zero(f, gate)
      summary = reload_totals(ledger, final, peers, @reload_profile)
      assert Process.alive?(f.owner) and Process.alive?(f.groups)
      finish(f, [], [])

      reload_emit(context, "finished", %{
        measured_samples: length(samples),
        totals: summary,
        final_retirement: final,
        final_epochs: final_epochs,
        final_zero: final_zero,
        teardown_elapsed_ms: System.monotonic_time(:millisecond) - teardown_started,
        profile_elapsed_ms: System.monotonic_time(:millisecond) - entered
      })
    end
  end

  defp reload_peers(protocol) do
    # First A and B choose different real ports while both .1 listeners remain live.
    peers =
      Enum.reduce(0..2, [], fn index, epochs ->
        Enum.reduce([:a, :b], epochs, fn lane, epochs ->
          previous = Enum.find(epochs, &(&1.lane == lane))
          port = if previous, do: previous.ready["port"], else: 0
          address = {127, 0, 0, index + 1}
          text = "127.0.0.#{index + 1}"
          started = System.monotonic_time(:millisecond)

          {peer, ready} =
            F.peer(protocol, [
              "--manual",
              "--bind-address",
              text,
              "--listen-port",
              Integer.to_string(port)
            ])

          assert ready["bind_address"] == text and ready["port"] in 1..65_535
          if previous, do: assert(ready["port"] == port)

          epochs ++
            [
              %{
                index: index,
                lane: lane,
                peer: peer,
                pid: peer,
                ready: ready,
                address: address,
                ready_elapsed_ms: System.monotonic_time(:millisecond) - started
              }
            ]
        end)
      end)

    assert length(Enum.uniq(Enum.map(peers, & &1.peer))) == 6
    [a, b] = Enum.take(peers, 2)
    assert a.ready["port"] != b.ready["port"]

    trust =
      if protocol == :http2 do
        ders =
          Enum.map(peers, fn epoch ->
            # Only the public CA file is opened; keys are never read or copied.
            assert [{:Certificate, der, :not_encrypted}] =
                     :public_key.pem_decode(rotation_pem(epoch.ready["ca"]))

            assert byte_size(der) in 1..65_536
            :binary.copy(der)
          end)

        assert length(Enum.uniq(ders)) == 6
        assert Enum.sum(Enum.map(ders, &byte_size/1)) <= 1_048_576
        leaves = Enum.map(peers, & &1.ready["identity"]["certificate_sha256"])
        assert Enum.all?(leaves, &(is_binary(&1) and byte_size(&1) == 64))
        assert length(Enum.uniq(leaves)) == 6
        ders
      else
        nil
      end

    scheme = if protocol == :http2, do: "https", else: "http"

    peers =
      Enum.map(peers, fn epoch ->
        source = %{
          protocol: protocol,
          origin: "#{scheme}://localhost:#{epoch.ready["port"]}",
          connect_address: epoch.address,
          trust: trust
        }

        Map.merge(epoch, %{source: source, class: reload_class(source)})
      end)

    for lane <- [:a, :b] do
      [first | rest] = Enum.filter(peers, &(&1.lane == lane))

      assert Enum.all?(
               rest,
               &(&1.class === first.class and &1.source.origin === first.source.origin)
             )
    end

    pair = reload_pair_class(reload_epoch(peers, 0))
    for index <- [8, 16], do: assert(reload_pair_class(reload_epoch(peers, index)) === pair)
    peers
  end

  defp reload_class(source) do
    assert Enum.sort(Map.keys(source)) == [:connect_address, :origin, :protocol, :trust]
    assert {:ok, policy, manifest} = Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(source)

    %{
      source: :erlang.external_size(source),
      policy: :erlang.external_size(policy),
      manifest: :erlang.external_size(manifest),
      trust: :erlang.external_size(source.trust)
    }
  end

  defp reload_pair_class(epochs) do
    %{
      sources: :erlang.external_size(Enum.map(epochs, & &1.source)),
      classes: Enum.map(epochs, & &1.class),
      source_sum: Enum.sum(Enum.map(epochs, & &1.class.source)),
      policy_sum: Enum.sum(Enum.map(epochs, & &1.class.policy)),
      manifest_sum: Enum.sum(Enum.map(epochs, & &1.class.manifest)),
      trust_sum: Enum.sum(Enum.map(epochs, & &1.class.trust))
    }
  end

  defp reload_epoch(peers, index) when index in 0..22,
    do:
      Enum.map([:a, :b], fn lane ->
        Enum.find(peers, &(&1.index == div(index, 8) and &1.lane == lane))
      end)

  defp reload_candidate(f, epochs, index) do
    c = candidate(f, Enum.map(epochs, & &1.source), :reload)
    assert length(c.transports) == 2 and length(Enum.uniq(c.transports)) == 2
    assert length(c.creators) == 2
    original = :sys.get_state(f.groups).groups[group_key(c.group)]
    c = Map.merge(c, %{reload_reserve: original.bytes, reload_index: index})
    reload_assert_class(f, c)
    reload_watch_retirement(f, c, index == 2)

    F.eventually(fn ->
      probes = for {_, p} <- :sys.get_state(f.groups).probes, p.key == group_key(c.group), do: p
      length(probes) == 2 and Enum.all?(probes, &reload_probe_completion?(&1))
    end)

    probes =
      for {ref, p} <- :sys.get_state(f.groups).probes,
          p.key == group_key(c.group),
          do: %{
            ref: ref,
            index: p.index,
            pid: p.pid,
            monitor: Process.monitor(p.pid),
            completion: p.completion,
            bytes: p.bytes
          }

    c = healthy(f, c, epochs)

    for p <- probes do
      pid = p.pid
      monitor = p.monitor
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
      health = Enum.at(c.health, p.index)
      assert health.completion === p.completion and p.bytes == @reserve
    end

    Map.put(c, :reload_probes, probes)
  end

  defp reload_probe_completion?(p),
    do: p.claimed and match?(%HTTP.RequestCompletion{}, p.completion)

  defp reload_assert_class(f, current) do
    assert Enum.map(current.sources, &reload_class/1) === f.reload_classes

    for {transport, index} <- Enum.with_index(current.transports) do
      source = Enum.at(current.sources, index)
      record = :sys.get_state(f.owner).records[transport.resource]
      class = Enum.at(f.reload_classes, index)
      assert record.policy.connect_address === source.connect_address
      assert :erlang.external_size(record.policy) == class.policy

      if f.protocol == :http2,
        do: assert(record.policy.open_options[:ssl][:cacerts] === source.trust),
        else: assert(source.trust == nil)
    end
  end

  defp reload_identity(f) do
    for pid <- [f.instance, f.owner, f.groups, f.store, f.embedding],
        do: assert(Process.alive?(pid))

    gate = service_gate(f)
    state = :sys.get_state(gate)

    {f.instance, f.owner, :sys.get_state(f.owner).epoch, f.groups, :sys.get_state(f.groups).epoch,
     f.store, Gaoxy.info(f.instance, :http).local, gate, state.service, f.embedding}
  end

  defp reload_open(f, c, epochs, index, kind) do
    indices = if kind == :seed, do: [0, 1], else: [0, 1, 0]

    targets =
      Enum.with_index(indices, fn _, slot ->
        "/reload/#{kind}/#{reload_index(index)}/#{slot}?raw=%2F"
      end)

    calls = capture_requests(f, c, :reload, targets)
    calls = dispatch_calls(f, c, calls, epochs, indices)

    Enum.zip_with(calls, indices, fn call, member ->
      epoch = Enum.at(epochs, member)
      connection = call.request["connection"]
      stream = call.request["stream"]

      assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 0} =
               F.event(epoch.peer, "upload_end")

      assert connection == rem(c.reload_index, 8) + 1
      F.no_event(epoch.peer, "accept")
      F.no_event(epoch.peer, "tls")
      Map.merge(call, %{epoch: epoch, member: member, source_acquirer: f.store})
    end)
  end

  defp reload_seed(f, c, epochs, index) do
    calls = reload_open(f, c, epochs, index, :seed)

    for call <- calls do
      complete_return(f, call, <<0, "seed", 255>>)
      return_endpoint(call.captured)
    end

    reload_close_calls(f, calls)
    for call <- calls, do: assert_effect_counts(f, call.captured, call.bound)
    reload_idle(f, c)

    connections =
      Enum.map(calls, fn call ->
        %{
          epoch: call.epoch.index,
          lane: call.epoch.lane,
          peer: call.peer,
          connection: call.request["connection"],
          first_stream: call.request["stream"],
          gate: call.captured.exchange.gate
        }
      end)

    {connections, Enum.map(calls, &reload_request_receipt(c, &1))}
  end

  defp reload_active(f, old, epochs, cycle), do: reload_open(f, old, epochs, cycle, :held)

  defp reload_index(index), do: index |> Integer.to_string() |> String.pad_leading(2, "0")

  defp reload_close_calls(f, calls) do
    if f.downstream == :http2 do
      F.eventually(fn -> Enum.all?(calls, &(not Process.alive?(&1.captured.native))) end)
    end

    close_calls(f, calls)
  end

  defp reload_idle(f, c) do
    F.eventually(fn ->
      t = :sys.get_state(f.owner)
      g = :sys.get_state(f.groups)

      not Enum.any?(t.pins, fn {_, p} ->
        p.public.kind == :request and Enum.any?(c.transports, &(&1 in p.public.handles))
      end) and
        not Enum.any?(g.pins, fn {_, p} -> p.kind == :request and group_key(c.group) in p.keys end) and
        not Enum.any?(t.tokens, fn {_, token} ->
          Enum.any?(c.transports, &(&1.resource == token.resource))
        end) and
        not Enum.any?(g.tokens, fn {_, token} -> token.key == group_key(c.group) end)
    end)

    assert_no_open(f, c)
    status = UpstreamGroups.status(c.group)
    assert %{inflight: 0, probes: 0, probe_bytes: 0} = status

    assert Enum.all?(
             status.members,
             &(&1.health == :healthy and &1.inflight == 0 and not &1.probe and not &1.stale)
           )

    for transport <- c.transports do
      assert configured_pins(f, transport) == [:baseline]
      record = :sys.get_state(f.owner).records[transport.resource]

      assert {:ok, %{active_requests: 0, preparing_requests: 0, pending: 0, connections: 1}} =
               HTTP.ManagedTransport.snapshot(record.scope, @timeout)
    end

    assert :sys.get_state(f.groups).groups[group_key(c.group)].cursor == 0
  end

  defp reload_cycle(f, peers, old, old_connections, profile, cycle) do
    old_epochs = reload_epoch(peers, cycle - 1)
    epochs = reload_epoch(peers, cycle)

    if profile == :idle do
      reload_idle(f, old)
      reload_service_zero(f, hd(old_connections).gate)
    end

    # healthy/3 requires owner-wide zero tokens before OLD requests are opened.
    fresh = reload_candidate(f, epochs, cycle)

    calls =
      if profile == :active do
        reload_active(f, old, old_epochs, cycle)
      else
        []
      end

    rollback = if cycle == 3, do: reload_group_rollback(f, fresh, peers), else: nil
    fresh = activate(f, fresh, old.generation)

    {connections, seed, capacity, retired, held} =
      if profile == :active do
        await_closed(f, old, Enum.map(calls, & &1.captured))
        {connections, seed} = reload_seed(f, fresh, epochs, cycle)
        [first, second, last] = calls

        for call <- [first, second] do
          assert {:error, :cleanup_pending} =
                   HTTP.RequestCompletion.await(call.bound.completion, 0)

          complete_return(f, call, <<255, "old", 0>>)
          return_endpoint(call.captured)
        end

        F.eventually(fn ->
          t = :sys.get_state(f.owner)
          g = :sys.get_state(f.groups)

          sources =
            for {ref, p} <- t.pins,
                not Map.get(p, :derived, false) and p.public.kind == :request and
                  Enum.any?(old.transports, &(&1 in p.public.handles)),
                do: ref

          gpins =
            for {ref, p} <- g.pins, p.kind == :request and group_key(old.group) in p.keys, do: ref

          sources == [last.captured.tpin.ref] and gpins == [last.captured.gpin.ref]
        end)

        child = :sys.get_state(f.owner).pins[last.bound.child.ref]
        assert child.public === last.bound.child
        assert child.derived and child.source_ref === last.captured.tpin.ref
        assert child.public.handles === [last.bound.selected]
        assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(last.bound.completion, 0)
        complete_return(f, last, <<255, "old", 0>>)
        assert_no_open(f, old)
        assert_sources(f, old, last.captured)
        assert last.bound.index == 0 and last.captured.tpin.handles === old.transports
        assert :sys.get_state(f.groups).groups[group_key(old.group)].lifecycle == :retiring

        for transport <- old.transports do
          record = :sys.get_state(f.owner).records[transport.resource]
          assert record.admission == :closed and Process.alive?(record.custodian)
        end

        held = %{
          last_selected_member: 0,
          retained_unselected_member: 1,
          original_sources: %{
            group: reload_id(last.captured.gpin),
            transports: reload_id(last.captured.tpin)
          },
          requests: Enum.map(calls, &reload_request_receipt(old, &1))
        }

        return_endpoint(last.captured)
        capacity = if cycle == 3, do: reload_capacity(f, old, fresh, peers), else: nil
        retired = reload_join_retired(f, old, old_epochs, old_connections)
        # Both retirement barriers and original public receipt joins precede this wait.
        reload_close_calls(f, calls)
        for call <- calls, do: assert_effect_counts(f, call.captured, call.bound)
        {connections, seed, capacity, retired, held}
      else
        capacity = if cycle == 3, do: reload_capacity(f, old, fresh, peers), else: nil
        retired = reload_join_retired(f, old, old_epochs, old_connections)
        {connections, seed} = reload_seed(f, fresh, epochs, cycle)
        {connections, seed, capacity, retired, nil}
      end

    joined =
      if hd(old_epochs).index != hd(epochs).index,
        do: Enum.map(old_epochs, &reload_join_peer(&1, profile)),
        else: []

    gate = hd(connections).gate
    vector = reload_sample(f, fresh, gate, f.reload_classes)

    {fresh, connections, vector,
     %{
       index: cycle,
       cas: %{expected: reload_id(old.generation), activated: reload_id(fresh.generation)},
       health: reload_health_receipts(fresh),
       seed: seed,
       held: held,
       retirement: retired,
       rollback: rollback,
       capacity: capacity,
       epoch_joins: joined,
       inventory: reload_inventory(f, fresh, gate)
     }}
  end

  defp reload_watch_retirement(f, candidate, hold?) do
    state = :sys.get_state(f.owner)

    for transport <- candidate.transports do
      record = state.records[transport.resource]
      assert Enum.any?(candidate.creators, fn {pid, _} -> pid == record.custodian end)
      reload_watch_one_retirement(f, %{transport: transport, creator: record.custodian}, hold?)
    end
  end

  defp reload_watch_one_retirement(f, candidate, hold?) do
    parent = self()
    resource = candidate.transport.resource
    custodian = candidate.creator
    record = :sys.get_state(f.owner).records[resource]
    assert record.custodian == custodian
    capability = record.capability
    id = make_ref()
    barrier = make_ref()

    debug = fn seen, event, _ ->
      case event do
        {:in, message} when is_tuple(message) ->
          case message do
            {:retire, ^capability} when hold? and not seen ->
              send(
                parent,
                {:reload_retirement_held, id, resource, self(), barrier,
                 System.monotonic_time(:millisecond)}
              )

              receive do
                {:reload_retirement_continue, ^barrier} -> :ok
              after
                2_000 -> raise "test-owned retirement input barrier timed out"
              end

            {:retire_result, helper, result} ->
              send(parent, {:reload_retire_result, id, resource, self(), helper, result})

            {:DOWN, monitor, :process, helper, reason} ->
              send(parent, {:reload_helper_down, id, resource, self(), monitor, helper, reason})

            _ ->
              :ok
          end

          seen or elem(message, 0) == :retire

        {:noreply, %{retire_helper: {helper, monitor}}} ->
          send(parent, {:reload_helper_slot, id, resource, self(), helper, monitor})
          seen

        _ ->
          seen
      end
    end

    :ok = :sys.install(custodian, {id, debug, false})

    :ok =
      :sys.install(
        f.owner,
        {id,
         fn observed, event, _ ->
           observed =
             case event do
               {:in, {tag, ^resource, ^custodian, ^capability, helper}}
               when tag in [:custodian_helper_started, :custodian_helper_finished] ->
                 send(
                   parent,
                   {:reload_owner_helper, id, self(), resource, custodian, capability, tag,
                    helper}
                 )

                 observed

               {:in, {:custodian_retired, ^resource, ^custodian, ^capability}} ->
                 send(parent, {:reload_owner_before_confirmation, id, observed.entry})

                 send(
                   parent,
                   {:reload_owner_confirmed, id, self(), resource, custodian, capability}
                 )

                 %{observed | confirmed: true}

               _ ->
                 observed
             end

           actual =
             case event do
               {:out, _, _, actual} -> actual
               {:noreply, actual} -> actual
               _ -> nil
             end

           if is_map(actual) do
             entry = actual.records[resource]

             if entry == nil and not observed.confirmed,
               do: send(parent, {:reload_removed_before_confirmation, id, resource})

             %{observed | entry: entry}
           else
             observed
           end
         end, %{confirmed: false, entry: record}}
      )

    # Test-only metadata is bounded by the original 46 transport custodians.
    Process.put({__MODULE__, :reload_watch, custodian}, %{
      id: id,
      barrier: barrier,
      capability: capability,
      resource: resource
    })

    on_exit(fn ->
      send(custodian, {:reload_retirement_continue, barrier})
      reload_remove_observer(custodian, id)
      reload_remove_observer(f.owner, id)
    end)

    :ok
  end

  defp reload_remove_observer(pid, id) do
    if Process.alive?(pid) do
      try do
        :sys.remove(pid, id)
      catch
        :exit, {:noproc, _} -> :ok
        :exit, {:normal, _} -> :ok
      end
    end
  end

  defp reload_join_retired(f, candidate, epochs, connections) do
    owner = f.owner

    rows =
      Enum.with_index(candidate.transports, fn transport, index ->
        resource = transport.resource
        # Correlate original custodian by resource, rather than creator list order.
        {custodian, %{id: id, capability: capability}} =
          Enum.find_value(candidate.creators, fn {pid, _} ->
            watch = Process.get({__MODULE__, :reload_watch, pid})
            if watch && watch.resource === resource, do: {pid, watch}
          end)

        assert_receive {:reload_retire_result, ^id, ^resource, ^custodian, helper,
                        {:ok, receipt}},
                       @timeout

        assert :ok = HTTP.ManagedTransport.await_retired(receipt, @timeout)

        assert_receive {:reload_helper_slot, ^id, ^resource, ^custodian, ^helper, monitor},
                       @timeout

        assert_receive {:reload_helper_down, ^id, ^resource, ^custodian, ^monitor, ^helper,
                        :normal},
                       @timeout

        assert_receive {:reload_owner_helper, ^id, ^owner, ^resource, ^custodian, ^capability,
                        :custodian_helper_started, ^helper},
                       @timeout

        assert_receive {:reload_owner_helper, ^id, ^owner, ^resource, ^custodian, ^capability,
                        :custodian_helper_finished, ^helper},
                       @timeout

        assert_receive {:reload_owner_before_confirmation, ^id, charged}, @timeout
        assert charged.resource === resource and charged.custodian === custodian
        assert charged.capability === capability and charged.transport_confirmed == false
        assert charged.payload_bytes == :erlang.external_size(charged.payload)
        assert charged.payload_bytes > 0

        assert_receive {:reload_owner_confirmed, ^id, ^owner, ^resource, ^custodian, ^capability},
                       @timeout

        refute_receive {:reload_removed_before_confirmation, ^id, ^resource}, 0
        refute_receive {:reload_retire_result, ^id, ^resource, ^custodian, _, _}, 0

        refute_receive {:reload_owner_helper, ^id, ^owner, ^resource, ^custodian, ^capability,
                        :custodian_helper_started, _},
                       0

        reload_remove_observer(owner, id)
        Process.delete({__MODULE__, :reload_watch, custodian})
        epoch = Enum.at(epochs, index)
        connection = Enum.at(connections, index)
        physical = F.physical_termination(epoch.peer)
        assert physical["connection"] == connection.connection
        assert Enum.at(candidate.health, index).request["connection"] == connection.connection

        row = %{
          resource: reload_id(resource),
          creator: reload_id(custodian),
          capability: reload_id(capability),
          helper: reload_id(helper),
          helper_monitor: reload_id(monitor),
          receipt: reload_opaque_id(:retirement_receipt, receipt),
          public_await: :ok,
          helper_down: :normal,
          owner_confirmed: true,
          charged_until_confirmation_bytes: charged.payload_bytes,
          creator_down: :normal,
          removed: true,
          epoch: epoch.index,
          lane: epoch.lane,
          peer: reload_id(epoch.peer),
          physical: physical
        }

        key = {__MODULE__, :reload_closed, epoch.peer}
        Process.put(key, Process.get(key, []) ++ [row])
        row
      end)

    # This is the sole consumption of the original candidate creator monitors.
    join_resource(f, candidate)
    key = group_key(candidate.group)
    groups = :sys.get_state(f.groups)
    refute Map.has_key?(groups.groups, key)
    refute Enum.any?(groups.pins, fn {_, p} -> key in p.keys end)
    refute Enum.any?(groups.tokens, fn {_, t} -> t.key == key end)
    refute Enum.any?(groups.probes, fn {_, p} -> p.key == key end)

    %{
      group: reload_id(candidate.group),
      group_removed: true,
      original_creators_down: :normal,
      transports: rows
    }
  end

  defp reload_group_rollback(f, fresh, peers) do
    parent = self()
    id = make_ref()
    t_before = reload_transport_snapshot(f)
    g_before = reload_group_snapshot(f)
    store = :sys.get_state(f.store)
    assert map_size(g_before.groups) == 2 and g_before.limits.max_groups == 2

    debug = fn observed, event, _ ->
      case event do
        {:in,
         {:"$gen_call", {^parent, _} = from,
          {:pin_many, handles, ^parent, :preparation, operation, deadline}}} ->
          send(
            parent,
            {:reload_rollback_prefix_input, id, self(), from, handles, operation, deadline}
          )

          %{observed | pending: {from, operation}}

        {:out, {:ok, pin}, from, actual} ->
          case observed.pending do
            {^from, operation} ->
              assert pin.operation === operation and pin.kind == :preparation
              assert actual.pins[pin.ref].public === pin

              send(
                parent,
                {:reload_rollback_prefix_acquired, id, self(), pin, actual.pins[pin.ref],
                 :erlang.external_size(actual.pins[pin.ref])}
              )

              %{observed | pin: pin, pending: nil}

            _ ->
              observed
          end

        {:in, {:cancel_pins, ^parent, operation}} ->
          case observed.pin do
            %{operation: ^operation} = pin ->
              send(parent, {:reload_rollback_cancel_input, id, self(), operation, pin.ref})
              %{observed | cancelling: true}

            _ ->
              observed
          end

        {:noreply, actual} when observed.cancelling ->
          ref = observed.pin.ref
          assert not Map.has_key?(actual.pins, ref)
          send(parent, {:reload_rollback_cancel_processed, id, self(), ref})
          %{observed | cancelling: false}

        _ ->
          observed
      end
    end

    :ok = :sys.install(f.owner, {id, debug, %{pending: nil, pin: nil, cancelling: false}})

    try do
      result =
        UpstreamGroups.prepare(f.groups, fresh.compiled, self(), Lifecycle.deadline(15_000))

      assert result == {:error, :group_capacity}
      owner = f.owner

      assert_receive {:reload_rollback_prefix_input, ^id, ^owner, from, handles, operation,
                      deadline},
                     @timeout

      assert handles === fresh.transports and is_reference(operation)
      assert Lifecycle.remaining(deadline) > 0

      assert_receive {:reload_rollback_prefix_acquired, ^id, ^owner, pin, original, bytes},
                     @timeout

      assert pin.handles === fresh.transports and pin.holder == self()
      assert pin.operation === operation and original.acquirer == self()
      assert original.public === pin and bytes == :erlang.external_size(original)
      assert_receive {:reload_rollback_cancel_input, ^id, ^owner, ^operation, ref}, @timeout
      assert ref === pin.ref
      assert_receive {:reload_rollback_cancel_processed, ^id, ^owner, ^ref}, @timeout
      F.eventually(fn -> not Map.has_key?(:sys.get_state(f.owner).pins, ref) end)
      t_after = reload_transport_snapshot(f)
      g_after = reload_group_snapshot(f)
      assert t_after === t_before
      assert g_after === g_before
      assert :sys.get_state(f.store) === store
      reload_no_peer_effects(peers)

      %{
        result: reload_id(result),
        prefix: reload_id(pin),
        caller: reload_id(from),
        operation: reload_id(operation),
        original_pin_bytes: bytes,
        pin_acquired: true,
        cancel_observed: true,
        cancellation_processed: true,
        no_retained_delta: true,
        transport_before: reload_snapshot_receipt(t_before),
        transport_after: reload_snapshot_receipt(t_after),
        group_before: reload_group_snapshot_receipt(g_before),
        group_after: reload_group_snapshot_receipt(g_after),
        store: reload_store_receipt(store)
      }
    after
      reload_remove_observer(f.owner, id)
    end
  end

  defp reload_transport_snapshot(f) do
    {state, bytes, status} = reload_owner_bytes(f.owner)

    %{
      records: state.records,
      pins: state.pins,
      tokens: state.tokens,
      bytes: bytes,
      status: status,
      monitors: reload_monitors(f.owner)
    }
  end

  defp reload_group_snapshot(f) do
    assert_group_ledgers(f)
    state = :sys.get_state(f.groups)

    %{
      groups: state.groups,
      pins: state.pins,
      tokens: state.tokens,
      probes: state.probes,
      bytes: state.bytes,
      control_bytes: state.control_bytes,
      probe_bytes: state.probe_bytes,
      limits: state.limits,
      monitors: reload_monitors(f.groups)
    }
  end

  defp reload_monitors(owner) do
    assert {:monitors, monitors} = Process.info(owner, :monitors)
    MapSet.new(monitors)
  end

  defp reload_capacity(f, old, fresh, peers) do
    watches =
      Enum.map(old.creators, fn {pid, _} ->
        Map.put(Process.get({__MODULE__, :reload_watch, pid}), :custodian, pid)
      end)

    result =
      try do
        starts =
          Enum.map(watches, fn %{
                                 id: id,
                                 barrier: barrier,
                                 resource: resource,
                                 custodian: custodian
                               } ->
            assert_receive {:reload_retirement_held, ^id, ^resource, ^custodian, ^barrier,
                            started},
                           @timeout

            {id, started}
          end)

        held_deadline = Enum.min(Enum.map(starts, &elem(&1, 1))) + 2_000

        read_held = fn pid ->
          remaining = Lifecycle.remaining(held_deadline)
          assert remaining > 0
          :sys.get_state(pid, remaining)
        end

        F.eventually(
          fn ->
            groups = read_held.(f.groups)
            store = read_held.(f.store)

            map_size(groups.groups) == 1 and
              Map.has_key?(groups.groups, group_key(fresh.group)) and
              not Map.has_key?(groups.groups, group_key(old.group)) and
              map_size(groups.pins) == 1 and groups.tokens == %{} and groups.probes == %{} and
              store.router === fresh.router and store.preparation == nil and store.retired == []
          end,
          held_deadline
        )

        before = reload_transport_snapshot(f)

        assert %{
                 resources: 4,
                 pins: 2,
                 request_tokens: 0,
                 helpers: 0,
                 reserved_connections: 8,
                 failed_resources: 0
               } = before.status

        expected = Enum.map(old.transports ++ fresh.transports, & &1.resource)
        assert MapSet.new(Map.keys(before.records)) == MapSet.new(expected)

        retained =
          Enum.map(watches, fn watch ->
            record = before.records[watch.resource]
            assert record.custodian === watch.custodian
            assert record.transport_confirmed == false and record.custodian_down == false

            assert record.admission == :closed and record.retirement_requested and
                     record.payload_bytes > 0

            assert Process.alive?(watch.custodian)
            %{resource: reload_id(watch.resource), original_payload_bytes: record.payload_bytes}
          end)

        groups = reload_group_snapshot(f)

        assert map_size(groups.groups) == 1 and
                 Map.has_key?(groups.groups, group_key(fresh.group))

        refute Map.has_key?(groups.groups, group_key(old.group))
        assert map_size(groups.pins) == 1 and groups.tokens == %{} and groups.probes == %{}
        store = :sys.get_state(f.store)
        assert store.router === fresh.router and store.preparation == nil and store.retired == []
        assert length(store.baseline) == 2

        assert Enum.sort(Enum.flat_map(store.baseline, & &1.handles)) ==
                 Enum.sort([fresh.group | fresh.transports])

        attempt =
          Transports.prepare(f.owner, hd(fresh.sources), self(), Lifecycle.deadline(15_000))

        case attempt do
          {:ok, _, pin} ->
            on_exit(fn -> if Process.alive?(f.owner), do: Resources.release(pin) end)

          {:error, _} ->
            :ok
        end

        assert attempt == {:error, {:capacity, :resources}}
        after_state = reload_transport_snapshot(f)
        assert after_state === before
        assert reload_group_snapshot(f) === groups
        assert :sys.get_state(f.store) === store
        reload_no_peer_effects(peers)

        elapsed =
          Enum.map(starts, fn {id, started} ->
            ms = System.monotonic_time(:millisecond) - started
            assert ms < 2_000
            %{id: reload_id(id), started: started, transaction_elapsed_ms: ms}
          end)

        %{
          result: reload_id(attempt),
          no_delta: true,
          starts: starts,
          holds: elapsed,
          retained: retained,
          transport_before: reload_snapshot_receipt(before),
          transport_after: reload_snapshot_receipt(after_state),
          group: reload_group_snapshot_receipt(groups),
          store: reload_store_receipt(store)
        }
      after
        # Always release BOTH original barriers, including on a failed assertion.
        for watch <- watches,
            do: send(watch.custodian, {:reload_retirement_continue, watch.barrier})
      end

    clocks =
      Enum.map(result.starts, fn {id, started} ->
        elapsed = System.monotonic_time(:millisecond) - started
        assert elapsed < 2_000
        %{id: reload_id(id), through_continue_elapsed_ms: elapsed}
      end)

    result |> Map.delete(:starts) |> Map.put(:through_continue, clocks)
  end

  defp reload_no_peer_effects(peers) do
    for epoch <- peers, name <- ["accept", "tls", "request"], do: F.no_event(epoch.peer, name)
  end

  defp reload_owner_bytes(owner) do
    state = :sys.get_state(owner)

    for {_, entry} <- state.records,
        do: assert(entry.payload_bytes == :erlang.external_size(entry.payload))

    payloads = Enum.sum(for {_, entry} <- state.records, do: :erlang.external_size(entry.payload))
    pins = Enum.sum(for {_, hold} <- state.pins, do: :erlang.external_size(hold))
    tokens = Enum.sum(for {_, hold} <- state.tokens, do: hold.payload_bytes)
    bytes = payloads + pins + tokens
    assert {:ok, status} = Transports.status(owner)
    assert status.owned_serialized_payload_bytes == bytes
    {state, bytes, status}
  end

  defp reload_sample(f, current, gate, classes) do
    reload_idle(f, current)
    reload_assert_class(f, current)
    {t, total, status} = reload_owner_bytes(f.owner)

    assert %{
             resources: 2,
             pins: 2,
             request_tokens: 0,
             helpers: 0,
             reserved_connections: 4,
             failed_resources: 0,
             lifecycle: :running
           } = status

    assert status.limits == %{
             max_resources: 4,
             max_pins: 256,
             max_request_tokens: 64,
             max_owned_payload_bytes: 8_388_608
           }

    assert MapSet.new(Map.keys(t.records)) ==
             MapSet.new(Enum.map(current.transports, & &1.resource))

    assert [{_, tpin}] = Map.to_list(t.pins)
    assert tpin.public.kind == :baseline and tpin.public.holder == f.store
    assert tpin.public.handles === current.transports
    assert t.tokens == %{}

    snapshots =
      Enum.map(current.transports, fn transport ->
        record = t.records[transport.resource]
        assert record.admission == :open and not record.retirement_requested
        assert not record.opening and record.helpers == %{}
        assert not record.transport_confirmed and not record.custodian_down
        assert {:ok, snapshot} = HTTP.ManagedTransport.snapshot(record.scope, @timeout)
        assert %{active_requests: 0, preparing_requests: 0, pending: 0, connections: 1} = snapshot
        # Only the four specified public numeric fields are plateau scalars.
        Map.take(snapshot, [:active_requests, :preparing_requests, :pending, :connections])
      end)

    payloads =
      Enum.map(current.transports, &:erlang.external_size(t.records[&1.resource].payload))

    pin_bytes = for {_, pin} <- t.pins, do: :erlang.external_size(pin)
    token_bytes = for {_, token} <- t.tokens, do: token.payload_bytes
    assert total == Enum.sum(payloads) + Enum.sum(pin_bytes) + Enum.sum(token_bytes)

    assert_group_ledgers(f)
    g = :sys.get_state(f.groups)
    assert map_size(g.groups) == 1 and map_size(g.pins) == 1
    assert g.tokens == %{} and g.probes == %{} and g.probe_bytes == 0
    record = g.groups[group_key(current.group)]
    assert record.handle === current.group and record.compiled === current.compiled
    assert record.bytes === current.reload_reserve
    assert record.lifecycle == :active and record.inflight == 0 and record.cursor == 0
    assert length(record.members) == 2

    assert Enum.all?(
             record.members,
             &(&1.health == :healthy and &1.inflight == 0 and &1.probe == nil)
           )

    config_reserves = [record.bytes]
    config_used = [:erlang.external_size(Map.delete(record, :bytes))]
    assert hd(config_used) <= hd(config_reserves)

    controls =
      for {kind, records} <- [pin: g.pins, selection: g.tokens, probe: g.probes],
          {_, hold} <- records do
        safe = Map.delete(hold, :control_bytes)

        safe =
          if Map.get(safe, :completion) != nil,
            do: %{safe | completion: {:opaque, HTTP.RequestCompletion}},
            else: safe

        bytes = :erlang.external_size(safe)
        assert hold.control_bytes == bytes
        assert bytes <= if(kind == :pin, do: 196_608, else: 32_768)
        %{kind: kind, bytes: bytes}
      end

    probe_bytes = for {_, p} <- g.probes, do: p.bytes
    assert g.bytes == Enum.sum(config_reserves)
    assert g.control_bytes == Enum.sum(Enum.map(controls, & &1.bytes))
    assert g.probe_bytes == Enum.sum(probe_bytes)
    public = UpstreamGroups.status(current.group)
    assert public.config_bytes == g.bytes and public.control_bytes == g.control_bytes
    assert public.probe_bytes == g.probe_bytes and public.probes == map_size(g.probes)
    assert public.pins == map_size(g.pins) and public.control_limit == 16_777_216
    assert [%{keys: [key], kind: :baseline, holder: holder}] = Map.values(g.pins)
    assert key === group_key(current.group) and holder == f.store

    store = :sys.get_state(f.store)
    assert store.preparation == nil and store.retired == []
    assert store.router === current.router
    assert Enum.sort(store.router.resources) == Enum.sort([current.group | current.transports])
    assert length(store.baseline) == 2
    assert Enum.all?(store.baseline, &(&1.kind == :baseline))

    assert Enum.sort(Enum.flat_map(store.baseline, & &1.handles)) ==
             Enum.sort([current.group | current.transports])

    assert Enum.find(store.baseline, &(&1.provider == Transports)) === tpin.public
    gpin = Enum.find(store.baseline, &(&1.provider == UpstreamGroups))
    assert gpin.handles === [current.group]
    assert Map.has_key?(g.pins, gpin.ref)
    zero = reload_service_zero(f, gate)

    %{
      transport: status,
      transport_bytes: %{
        payloads: payloads,
        pin_records: pin_bytes,
        token_payloads: token_bytes,
        total: total
      },
      transport_pin_batches: map_size(t.pins),
      transport_snapshots: snapshots,
      group: %{
        groups: map_size(g.groups),
        member_count: length(record.members),
        lifecycle: record.lifecycle,
        inflight: record.inflight,
        cursor: record.cursor,
        pins: map_size(g.pins),
        pin_handles: Enum.sum(for {_, p} <- g.pins, do: length(p.keys)),
        tokens: map_size(g.tokens),
        probes: map_size(g.probes),
        config_bytes: g.bytes,
        control_bytes: g.control_bytes,
        probe_bytes: g.probe_bytes,
        config_reserves: config_reserves,
        full_current_record_bytes: config_used,
        control_records: controls,
        probe_reservations: probe_bytes,
        control_limit: public.control_limit,
        limits: g.limits,
        members:
          Enum.zip_with(record.members, public.members, fn member, status ->
            %{
              id: member.id,
              health: member.health,
              inflight: member.inflight,
              failures: member.failures,
              successes: member.successes,
              probe: member.probe != nil,
              stale: status.stale,
              config_bytes: :erlang.external_size(member.config),
              full_member_bytes: :erlang.external_size(member)
            }
          end)
      },
      store: %{
        resources: length(store.router.resources),
        group_handles: 1,
        transport_handles: 2,
        baseline_batches: length(store.baseline),
        baseline_handles: 3,
        retired: length(store.retired),
        preparation: store.preparation,
        router_bytes: :erlang.external_size(store.router),
        baseline_bytes: :erlang.external_size(store.baseline),
        baseline_record_bytes: Enum.map(store.baseline, &:erlang.external_size/1)
      },
      source_classes: classes,
      ordered_pair_class: %{
        sources: :erlang.external_size(current.sources),
        source_sum: Enum.sum(Enum.map(classes, & &1.source)),
        policy_sum: Enum.sum(Enum.map(classes, & &1.policy)),
        manifest_sum: Enum.sum(Enum.map(classes, & &1.manifest)),
        trust_sum: Enum.sum(Enum.map(classes, & &1.trust))
      },
      service: zero.service,
      gate: zero.gate
    }
  end

  defp reload_service_zero(f, gate) do
    F.eventually(fn ->
      match?(
        %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil},
        Gaoxy.status(f.instance, :http)
      ) and
        match?(
          %{leases: leases, cleanups: cleanups, bytes: 0}
          when map_size(leases) == 0 and map_size(cleanups) == 0,
          :sys.get_state(gate)
        )
    end)

    service_status = Gaoxy.status(f.instance, :http)
    gate_state = :sys.get_state(gate)
    service_state = :sys.get_state(gate_state.service)
    gate_status = Gaoxy.Admission.status(gate)
    leases = Enum.sum(for {_, hold} <- gate_state.leases, do: hold.bytes)
    cleanups = Enum.sum(for {_, hold} <- gate_state.cleanups, do: hold.bytes)
    assert gate_state.bytes == leases + cleanups and leases == 0 and cleanups == 0
    assert gate_state.leases == %{} and gate_state.cleanups == %{} and gate_state.spawns == %{}
    assert service_state.cleanups == %{} and service_state.cleanup_failed == nil
    assert service_state.gate == gate

    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil} =
             service_status

    assert %{active: 0, retained_bytes: 0, cleanup_pending: 0, queued_items: 0, queued_bytes: 0} =
             gate_status

    %{
      service:
        Map.merge(
          Map.take(service_status, [:active, :retained_bytes, :cleanup_pending, :cleanup_failed]),
          %{cleanup_records: map_size(service_state.cleanups)}
        ),
      gate:
        Map.merge(
          Map.take(gate_status, [
            :active,
            :retained_bytes,
            :cleanup_pending,
            :queued_items,
            :queued_bytes
          ]),
          %{
            leases: map_size(gate_state.leases),
            cleanups: map_size(gate_state.cleanups),
            spawns: map_size(gate_state.spawns),
            lease_bytes: leases,
            cleanup_bytes: cleanups
          }
        )
    }
  end

  defp reload_zero(f, gate) do
    F.eventually(fn ->
      match?(
        {:ok,
         %{
           resources: 0,
           pins: 0,
           request_tokens: 0,
           helpers: 0,
           reserved_connections: 0,
           failed_resources: 0,
           owned_serialized_payload_bytes: 0
         }},
        Transports.status(f.owner)
      )
    end)

    {t, bytes, _} = reload_owner_bytes(f.owner)
    assert t.records == %{} and t.pins == %{} and t.tokens == %{} and bytes == 0

    F.eventually(fn ->
      g = :sys.get_state(f.groups)

      g.groups == %{} and g.pins == %{} and g.tokens == %{} and g.probes == %{} and
        g.bytes == 0 and g.control_bytes == 0 and g.probe_bytes == 0
    end)

    zero = reload_service_zero(f, gate)

    Map.merge(zero, %{
      transport: reload_snapshot_receipt(reload_transport_snapshot(f)),
      group: reload_group_snapshot_receipt(reload_group_snapshot(f))
    })
  end

  defp reload_join_peer(epoch, profile) do
    completed = Process.get({__MODULE__, :reload_closed, epoch.peer}, [])
    accepts = if epoch.index < 2, do: 8, else: 7

    requests =
      case {profile, epoch.lane, epoch.index} do
        {:active, :a, 2} -> 26
        {:active, :a, _} -> 32
        {:active, :b, 2} -> 20
        {:active, :b, _} -> 24
        {:idle, _, 2} -> 14
        {:idle, _, _} -> 16
      end

    assert length(completed) == accepts

    assert Enum.all?(
             completed,
             &(&1.epoch == epoch.index and &1.lane == epoch.lane and
                 &1.public_await == :ok and &1.owner_confirmed and &1.removed and
                 &1.creator_down == :normal)
           )

    assert Enum.map(completed, & &1.physical["connection"]) == Enum.to_list(1..accepts)
    peer = epoch.peer
    assert Process.get({F, :observed_requests, peer}) == requests
    monitor = Process.monitor(peer)
    send(peer, {:command, %{"op" => "stop"}})
    joined = F.event(peer, "joined")

    assert %{
             "forced" => 0,
             "live" => 0,
             "failed" => false,
             "accepts" => ^accepts,
             "requests" => ^requests
           } = joined

    for name <- ["accept", "tls", "request"], do: F.no_event(peer, name)
    assert_receive {:fixed_h2_peer_exit, ^peer, 0}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^peer, :normal}, @timeout

    assert {:ok, rebound} =
             :gen_tcp.listen(
               epoch.ready["port"],
               [:binary, active: false, ip: epoch.address, reuseaddr: true]
             )

    assert :ok = :gen_tcp.close(rebound)

    row = %{
      epoch: epoch.index,
      lane: epoch.lane,
      peer: reload_id(peer),
      address: reload_id(epoch.address),
      port: epoch.ready["port"],
      resources: completed,
      joined: joined,
      exit: 0,
      collector_down: :normal,
      rebound: true
    }

    key = {__MODULE__, :reload_peer_joins}
    Process.put(key, Process.get(key, []) ++ [row])
    row
  end

  defp reload_totals(ledger, final, peers, profile) do
    health = Enum.flat_map(ledger, & &1.health)
    seeds = Enum.flat_map(ledger, & &1.seed)

    held =
      Enum.flat_map(ledger, fn row -> if Map.get(row, :held), do: row.held.requests, else: [] end)

    retired = Enum.flat_map(tl(ledger), & &1.retirement.transports) ++ final.transports
    joins = Process.get({__MODULE__, :reload_peer_joins}, [])
    groups = Enum.map(tl(ledger), & &1.retirement.group) ++ [final.group]
    assert length(health) == 46 and length(seeds) == 46
    assert length(held) == if(profile == :active, do: 66, else: 0)
    assert length(retired) == 46 and length(Enum.uniq(Enum.map(retired, & &1.resource))) == 46
    assert length(groups) == 23 and length(Enum.uniq(groups)) == 23
    assert Enum.all?(tl(ledger), & &1.retirement.group_removed) and final.group_removed
    assert length(joins) == 6 and length(peers) == 6
    assert Enum.count(tl(ledger), &Map.has_key?(&1, :cas)) == 22
    assert Enum.count(tl(ledger), &(&1.rollback != nil)) == 1
    assert Enum.count(tl(ledger), &(&1.capacity != nil)) == 1
    assert Enum.sum(Enum.map(joins, & &1.joined["accepts"])) == 46
    requests = length(health) + length(seeds) + length(held)
    assert requests == if(profile == :active, do: 158, else: 92)
    assert Enum.sum(Enum.map(joins, & &1.joined["requests"])) == requests
    assert Enum.all?(health, &(&1.public_await == :ok and &1.probe_down == :normal))
    assert Enum.all?(seeds ++ held, &(&1.original_complete == :ok and &1.session_down == :normal))

    %{
      generations: length(groups),
      distinct_transports: length(retired),
      initial_publication: 1,
      replacement_cas: 22,
      heads: length(health),
      seed_gets: length(seeds),
      active_gets: length(held),
      gets: length(seeds) + length(held),
      requests: requests,
      retirement_receipts: length(retired),
      physical_closes: length(retired),
      group_removals: length(groups),
      peer_joins: length(joins),
      accepts: Enum.sum(Enum.map(joins, & &1.joined["accepts"]))
    }
  end

  defp reload_inventory_fields do
    %{
      plateau: [
        :transport,
        :transport_bytes,
        :transport_pin_batches,
        :transport_snapshots,
        :group,
        :store,
        :source_classes,
        :ordered_pair_class,
        :service,
        :gate
      ],
      identities: [
        :sut,
        :generation,
        :group,
        :transports,
        :creators,
        :creator_monitors,
        :group_baseline,
        :transport_baseline,
        :group_member_configs,
        :transport_controls,
        :request_source_batches,
        :request_children,
        :tokens,
        :sessions,
        :completions,
        :native_workers,
        :native_actors,
        :retirement_receipts,
        :retirement_helpers,
        :peer_epochs,
        :peer_connections,
        :peer_streams
      ],
      absolute_times: [
        :transport_preparation_deadline,
        :group_pin_deadline,
        :checked,
        :due,
        :scheduling_lag,
        :request_deadline,
        :hold_started,
        :entered_monotonic_ms,
        :embedding_creation_interval_monotonic_ms
      ],
      cumulative: [
        :service_retained_high_water,
        :service_rejected,
        :gate_retained_high_water,
        :gate_rejected,
        :owner_effects,
        :group_probe_cursor,
        :observed_peer_requests
      ],
      original_full_serialized_byte_fields_retained: [
        :transport_payload,
        :transport_pin_record,
        :transport_token_payload,
        :group_installed_config_reserve,
        :group_full_current_record,
        :group_member_config,
        :group_full_member,
        :group_control_record,
        :group_probe_reservation,
        :source,
        :prepared_policy,
        :manifest,
        :trust,
        :ordered_sources,
        :router,
        :baseline_list,
        :baseline_record,
        :service_cleanup,
        :gate_lease,
        :gate_cleanup
      ]
    }
  end

  defp reload_inventory(f, current, gate) do
    g = :sys.get_state(f.groups)
    t = :sys.get_state(f.owner)
    actual_gate = :sys.get_state(gate)
    service = Gaoxy.status(f.instance, :http)
    group = g.groups[group_key(current.group)]
    public = UpstreamGroups.status(current.group)
    store = :sys.get_state(f.store)
    effects = collect_effects(Process.get({__MODULE__, :effects}, []))
    Process.put({__MODULE__, :effects}, effects)

    %{
      sut: reload_id(reload_identity(f)),
      generation: reload_id(current.generation),
      group: reload_id(current.group),
      transports: Enum.map(current.transports, &reload_id/1),
      creators:
        Enum.map(current.creators, fn {pid, monitor} ->
          %{pid: reload_id(pid), monitor: reload_id(monitor)}
        end),
      baseline: Enum.map(store.baseline, &reload_id/1),
      group_member_configs: Enum.map(group.members, &reload_id(&1.config)),
      group_members_absolute_times:
        Enum.zip_with(group.members, public.members, fn original, status ->
          %{
            id: original.id,
            checked: original.checked,
            due: original.due,
            scheduling_lag: status.scheduling_lag
          }
        end),
      transport_controls:
        Enum.map(current.transports, fn transport ->
          entry = t.records[transport.resource]

          %{
            resource: reload_id(transport.resource),
            custodian: reload_id(entry.custodian),
            custodian_monitor: reload_id(entry.custodian_monitor),
            capability: reload_id(entry.capability),
            preparer: reload_id(entry.preparer),
            preparer_monitor: reload_id(entry.preparer_monitor),
            preparation_deadline: entry.deadline,
            payload_control_slots: reload_id(entry.payload.control_slots)
          }
        end),
      group_pin_deadlines:
        Enum.map(g.pins, fn {ref, p} ->
          %{
            ref: reload_id(ref),
            deadline: p.deadline,
            monitor: reload_id(p.monitor),
            timer: reload_id(p.timer),
            operation: reload_id(p.operation)
          }
        end),
      cumulative: %{
        service_retained_high_water: service.retained_high_water,
        service_rejected: service.rejected,
        gate_retained_high_water: actual_gate.high_water,
        gate_rejected: actual_gate.rejected,
        owner_effects: length(effects),
        group_probe_cursor: g.probe_cursor
      }
    }
  end

  defp reload_health_receipts(current) do
    Enum.with_index(current.health, fn health, index ->
      probe = Enum.find(current.reload_probes, &(&1.index == index))

      %{
        member: index,
        resource: reload_id(Enum.at(current.transports, index).resource),
        generation: reload_id(current.generation),
        peer: reload_id(health.peer),
        request: health.request,
        completion: reload_opaque_id(:request_completion, health.completion),
        probe: reload_id(probe.pid),
        probe_monitor: reload_id(probe.monitor),
        probe_ref: reload_id(probe.ref),
        probe_bytes: probe.bytes,
        public_await: :ok,
        probe_down: :normal
      }
    end)
  end

  defp reload_request_receipt(current, call) do
    %{
      epoch: call.epoch.index,
      lane: call.epoch.lane,
      member: call.member,
      peer: reload_id(call.peer),
      generation: reload_id(current.generation),
      group: reload_id(current.group),
      selected: reload_id(call.bound.selected),
      request: call.request,
      source_batches: %{
        group: reload_id(call.captured.gpin),
        transports: reload_id(call.captured.tpin)
      },
      source_inputs: %{
        holder: reload_id(call.captured.native),
        acquirer: reload_id(call.source_acquirer),
        deadline: call.captured.exchange.deadline
      },
      child: reload_id(call.bound.child),
      child_source_ref: reload_id(call.captured.tpin.ref),
      group_token: reload_id(call.bound.group_token),
      transport_token: reload_id(call.bound.transport_token),
      completion: reload_opaque_id(:request_completion, call.bound.completion),
      session: reload_id(call.bound.session),
      session_monitor: reload_id(call.bound.monitor),
      native: reload_id(call.captured.native),
      native_monitor: reload_id(call.captured.native_monitor),
      native_actors:
        Enum.map(call.captured.actors, fn {pid, ref, reason} ->
          %{pid: reload_id(pid), monitor: reload_id(ref), expected_down: reload_id(reason)}
        end),
      native_reservation: call.captured.reservation,
      retained_bytes: call.captured.retained,
      original_complete: :ok,
      session_down: :normal,
      child_and_token_removed_before_source: true
    }
  end

  defp reload_snapshot_receipt(snapshot) do
    %{
      status: snapshot.status,
      independent_bytes: snapshot.bytes,
      records:
        Enum.map(snapshot.records, fn {resource, record} ->
          %{
            resource: reload_id(resource),
            custodian: reload_id(record.custodian),
            capability: reload_id(record.capability),
            lifecycle: record.lifecycle,
            admission: record.admission,
            retirement_requested: record.retirement_requested,
            transport_confirmed: record.transport_confirmed,
            custodian_down: record.custodian_down,
            original_payload_bytes: record.payload_bytes,
            independent_payload_bytes: :erlang.external_size(record.payload),
            helpers: map_size(record.helpers),
            opening: record.opening
          }
        end),
      pins:
        Enum.map(snapshot.pins, fn {ref, pin} ->
          %{
            ref: reload_id(ref),
            original: reload_id(pin),
            independent_bytes: :erlang.external_size(pin)
          }
        end),
      tokens:
        Enum.map(snapshot.tokens, fn {ref, token} ->
          %{
            ref: reload_id(ref),
            payload_bytes: token.payload_bytes,
            resource: reload_id(token.resource),
            completion: reload_opaque_id(:request_completion, token.completion)
          }
        end),
      monitors: Enum.map(snapshot.monitors, &reload_id/1)
    }
  end

  defp reload_group_snapshot_receipt(snapshot) do
    %{
      groups:
        Enum.map(snapshot.groups, fn {key, record} ->
          %{
            key: reload_id(key),
            installed_reserve: record.bytes,
            full_record_bytes: :erlang.external_size(Map.delete(record, :bytes)),
            lifecycle: record.lifecycle,
            inflight: record.inflight,
            cursor: record.cursor
          }
        end),
      pins:
        Enum.map(snapshot.pins, fn {ref, pin} ->
          %{ref: reload_id(ref), original: reload_id(pin), control_bytes: pin.control_bytes}
        end),
      tokens:
        Enum.map(snapshot.tokens, fn {ref, token} ->
          %{
            ref: reload_id(ref),
            key: reload_id(token.key),
            control_bytes: token.control_bytes,
            completion: reload_opaque_id(:request_completion, token.completion)
          }
        end),
      probes:
        Enum.map(snapshot.probes, fn {ref, probe} ->
          %{
            ref: reload_id(ref),
            key: reload_id(probe.key),
            bytes: probe.bytes,
            control_bytes: probe.control_bytes,
            completion: reload_opaque_id(:request_completion, probe.completion)
          }
        end),
      config_bytes: snapshot.bytes,
      control_bytes: snapshot.control_bytes,
      probe_bytes: snapshot.probe_bytes,
      limits: snapshot.limits,
      monitors: Enum.map(snapshot.monitors, &reload_id/1)
    }
  end

  defp reload_store_receipt(store) do
    %{
      generation: reload_id(store.router.generation),
      router: reload_id(store.router),
      full_router_bytes: :erlang.external_size(store.router),
      baseline: Enum.map(store.baseline, &reload_id/1),
      full_baseline_bytes: :erlang.external_size(store.baseline),
      preparation: reload_id(store.preparation),
      retired: reload_id(store.retired)
    }
  end

  defp reload_peer_public(epoch) do
    %{
      epoch: epoch.index,
      lane: epoch.lane,
      peer: reload_id(epoch.peer),
      address: reload_id(epoch.address),
      port: epoch.ready["port"],
      observed_setup_to_ready_ms: epoch.ready_elapsed_ms,
      source_class: epoch.class,
      source_sha256: reload_hash(epoch.source),
      peer_identity: epoch.ready["identity"],
      public_ca_bundle:
        Enum.map(
          epoch.source.trust || [],
          &%{bytes: byte_size(&1), sha256: reload_hash_binary(&1)}
        )
    }
  end

  # Opaque capability identity is correlated by === without traversing or
  # serializing its interior. Public PIDs/refs/finite source pins use inspect.
  defp reload_opaque_id(kind, term) do
    key = {__MODULE__, :reload_opaque_ids}
    entries = Process.get(key, [])

    case Enum.find(entries, fn {actual_kind, original, _} ->
           actual_kind == kind and original === term
         end) do
      {_, _, id} ->
        %{opaque: kind, identity: id}

      nil ->
        id = length(entries) + 1
        assert id <= 512
        Process.put(key, [{kind, term, id} | entries])
        %{opaque: kind, identity: id}
    end
  end

  defp reload_id(%{__struct__: module} = term), do: reload_opaque_id(module, term)

  defp reload_id(term),
    do: %{inspect: inspect(term, limit: :infinity, printable_limit: :infinity)}

  defp reload_hash(term), do: term |> :erlang.term_to_binary() |> reload_hash_binary()
  defp reload_hash_binary(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp reload_emit(context, event, row),
    do:
      IO.puts(JSON.encode!(Map.merge(context, Map.put(row, :event, "group_h2_reload_#{event}"))))
end
