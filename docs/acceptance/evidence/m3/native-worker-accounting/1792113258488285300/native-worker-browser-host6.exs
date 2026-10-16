Code.require_file("native-worker-browser-cohort3.exs", __DIR__)

# Evidence-only independent arithmetic. Actual complete source constructors are
# instantiated with the original native owner and captured real worker. No
# production WorkerAccounting function supplies an expected cap or total.
defmodule NativeWorkerBrowserArithmetic do
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

  defp settle(_, _, _, _, _, _, _, _, _), do: raise("independent browser W did not converge")

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

# Source-only E5 proposal. Root must source-review and qualify the constructor gate before execution.
defmodule NativeWorkerBrowserHost do
  alias Gaoxy.{Admission, Lifecycle}
  alias NativeWorkerBrowserCohort, as: Cohort
  alias Gaoxy.HTTP.{Exchange, Generation, Resources, Router}
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedGenerationAccounting, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: T
  @m 1_048_576
  defmodule Captured do
    def init({group, host}) do
      with {:ok, config} <- GroupEndpoint.init(%{group: group}), do: {:ok, {config, host}}
    end

    def resources({config, _}), do: GroupEndpoint.resources(config)

    def call(exchange, {config, host}) do
      token = make_ref()
      send(host, {:capture, self(), token, exchange})

      receive do
        {:dispatch, ^token} -> GroupEndpoint.call(exchange, config)
      after
        min(10_000, Lifecycle.remaining(exchange.deadline)) ->
          {:error, :native_worker_browser_barrier_expired, exchange}
      end
    end
  end

  def emit(event, fields \\ %{}),
    do: IO.puts("NATIVE_WORKER_BROWSER " <> JSON.encode!(Map.put(fields, :event, event)))

  def deadline, do: Lifecycle.deadline(10_000)

  def wait_until(fun, d) do
    if fun.() do
      :ok
    else
      true = Lifecycle.remaining(d) > 0

      receive do
      after
        2 -> wait_until(fun, d)
      end
    end
  end

  def identity do
    root = File.cwd!() |> Path.expand()

    applications =
      for app <- [:gaoxy, :gaoxy_http, :gaoxy_proxy], module <- Application.spec(app, :modules) do
        Code.ensure_loaded!(module)
        {^module, bytes, beam_path} = :code.get_object_code(module)
        beam_path = to_string(beam_path) |> Path.expand()
        true = String.starts_with?(beam_path, root <> "/_build/")
        ^bytes = File.read!(beam_path)
        {:ok, {^module, md5}} = :beam_lib.md5(bytes)
        ^md5 = module.module_info(:md5)

        source =
          module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string() |> Path.expand()

        true = String.starts_with?(source, root <> "/apps/#{app}/")

        %{
          module: to_string(module),
          source: source,
          source_sha256: hash(File.read!(source)),
          beam: beam_path,
          beam_sha256: hash(bytes),
          loaded_md5: Base.encode16(md5, case: :lower)
        }
      end

    fixtures =
      for module <- [
            NativeWorkerBrowserHost,
            NativeWorkerBrowserHost.Captured,
            NativeWorkerBrowserArithmetic,
            NativeWorkerBrowserCohort
          ] do
        source =
          module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string() |> Path.expand()

        true =
          String.starts_with?(
            source,
            root <> "/docs/acceptance/evidence/m3/native-worker-accounting/"
          )

        %{
          module: to_string(module),
          source: source,
          source_sha256: hash(File.read!(source)),
          loaded_md5: Base.encode16(module.module_info(:md5), case: :lower)
        }
      end

    applications ++ fixtures
  end

  def hash(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  def run(port, evidence, mode, certificates) do
    Process.flag(:trap_exit, true)
    before = identity()
    File.write!(Path.join(evidence, "host-loaded-before.json"), JSON.encode!(before))
    {:ok, instance} = Gaoxy.start_link()

    {:ok, transports} =
      T.start_link(
        instance: instance,
        limits: %{
          max_resources: 32,
          max_pins: 4096,
          max_request_tokens: 64,
          max_owned_payload_bytes: 67_108_864
        }
      )

    {:ok, groups} =
      UpstreamGroups.start_link(
        instance: instance,
        limits: %{max_groups: 64, max_pins: 1024, max_probes: 1, max_config_bytes: 67_108_864}
      )

    source = %{origin: "http://localhost:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}
    {:ok, t, tp} = T.prepare(transports, source, self(), deadline())

    {:ok, compiled} =
      UpstreamGroups.compile(%{
        id: "checked-browser",
        members: [
          %{id: "one", upstream: source.origin, transport: t, connect_address: nil}
        ],
        health: %{
          path: "/health",
          interval: 60_000,
          stale_after: 120_000,
          timeout: 2_000,
          jitter: 0,
          recovery_threshold: 1
        }
      })

    {:ok, g, gp} = UpstreamGroups.prepare(groups, compiled, self(), deadline())
    {:ok, router} = Router.compile([%{target: {Captured, {g, self()}}}])
    {:ok, store} = Generation.start_link(router: router, max_config_bytes: @m)
    :ok = Resources.release(gp ++ tp)

    wait_until(
      fn ->
        match?(
          %{members: [%{health: :healthy, probe: false}], probes: 0},
          UpstreamGroups.status(g)
        )
      end,
      deadline()
    )

    wait_until(
      fn -> UpstreamGroups.status(g).pins == 1 and elem(T.status(transports), 1).pins == 1 end,
      deadline()
    )

    host = self()

    options = [
      endpoint: {Generation, {store, accounting: ManagedGenerationAccounting}},
      protocols: if(mode == "h2", do: [:http2], else: [:http1]),
      h2c: :disabled,
      limits: %{max_bytes: if(mode == "h2", do: 536_870_912, else: 67_108_864)},
      http_limits: %{request_timeout: 15_000}
    ]

    options =
      if mode == "h2",
        do:
          options ++
            [
              transport: :tls,
              tls: %{
                certfile: Path.join(certificates, "cert.pem"),
                keyfile: Path.join(certificates, "key.pem")
              }
            ],
        else: options

    {:ok, spec} = Gaoxy.HTTP.service_spec(options)
    telemetry = :ets.new(:native_cohort, [:set, :public])
    telemetry_id = make_ref()

    :ok =
      :telemetry.attach_many(
        telemetry_id,
        [
          [:gaoxy, :lifecycle],
          [:thousand_island, :listener, :start],
          [:thousand_island, :acceptor, :start],
          [:thousand_island, :connection, :start]
        ],
        &__MODULE__.cohort_event/4,
        %{host: host, table: telemetry}
      )

    {:ok, handle} = Gaoxy.add(instance, spec)

    service =
      receive do
        {:cohort_service, pid, generation} when generation == handle.generation -> pid
      after
        1000 -> raise "native service-ready identity missing"
      end

    service_state = :sys.get_state(service, 1000)
    true = service_state.generation == handle.generation
    true = service_state.spec.id == :http
    gate = service_state.gate
    {:ok, {{127, 0, 0, 1}, listen_port}} = Gaoxy.info(instance, :http).local
    [{:listener, listener, ^listen_port}] = :ets.lookup(telemetry, :listener)
    {:ok, cohort} = Cohort.install(gate, %{service: service, mode: String.to_atom(mode)})
    cohort_monitor = Process.monitor(cohort)
    Process.put(:native_worker_browser_cohort, cohort)
    true = :ets.insert_new(telemetry, {:observer, cohort, service, listener})

    for owner <- [groups, transports] do
      :ok =
        :sys.install(
          owner,
          {make_ref(),
           fn previous, event, _ ->
             case event do
               {:in, {:"$gen_call", {^store, _}, {tag, batch, holder, :request, op, d}}}
               when tag in [:pin, :pin_many] ->
                 send(
                   host,
                   {:original, owner, batch, holder, op, d, Cohort.snapshot(cohort, gate)}
                 )

               _ ->
                 :ok
             end

             previous
           end, nil}
        )

      1 = :erlang.trace(owner, true, [:send, {:tracer, self()}])
    end

    input =
      spawn_link(fn ->
        Stream.repeatedly(fn -> IO.gets("") end)
        |> Enum.reduce_while(nil, fn
          :eof, _ ->
            send(host, :input_eof)
            {:halt, nil}

          line, _ ->
            send(host, {:command, JSON.decode!(line)})
            {:cont, nil}
        end)
      end)

    input_monitor = Process.monitor(input)

    emit("ready", %{
      port: listen_port,
      mode: mode,
      endpoint: "Generation checked ManagedGenerationAccounting"
    })

    loop(%{
      instance: instance,
      transports: transports,
      groups: groups,
      store: store,
      g: g,
      t: t,
      input: input,
      input_monitor: input_monitor,
      evidence: evidence,
      before: before,
      captures: 0,
      originals: [],
      receipts: [],
      mode: mode,
      native: nil,
      native_monitor: nil,
      connection: nil,
      writer: nil,
      gate: gate,
      cohort: cohort,
      cohort_monitor: cohort_monitor,
      telemetry: telemetry,
      telemetry_id: telemetry_id,
      spec: service_state.spec,
      service: service,
      backend: service_state.backend,
      target: nil,
      lease: nil,
      native_baseline: nil,
      connection_monitor: nil,
      writer_monitor: nil,
      connection_joined: false,
      writer_joined: false,
      attachment: nil,
      source_t_pin: nil,
      session: nil,
      session_monitor: nil,
      session_joined: false,
      native_joined: false,
      request_cleaned: false,
      browser_close_authorized: false,
      custody: nil
    })
  end

  def independent_b(retained, b \\ 0, n \\ 0)

  def independent_b(retained, b, n) when n < 64 do
    e = &:erlang.external_size/1

    next =
      6 * @m + 4_957_373 + 3 * (e.(retained) - 3) + 5 * (e.(b) - 6) + 4 * (e.(retained + b) - 6)

    if next == b, do: b, else: independent_b(retained, next, n + 1)
  end

  def independent_b(_, _, _), do: raise("browser B did not converge")

  def loop(s) do
    receive do
      {:original, owner, batch, holder, op, d, status} ->
        loop(%{
          s
          | originals:
              s.originals ++
                [
                  %{
                    owner: owner,
                    batch: batch,
                    holder: holder,
                    operation: op,
                    deadline: d,
                    status: status
                  }
                ]
        })

      {:capture, native, token, exchange} ->
        true = s.captures == 0
        true = exchange.transport == if(s.mode == "h2", do: Gaoxy.HTTP.HTTP2.Transport, else: nil)
        # Messages from distinct owners can arrive after the captured endpoint message.
        originals = collect_originals(s.originals, 2)
        true = length(exchange.resource_pins) == 2

        true =
          MapSet.new(Enum.flat_map(exchange.resource_pins, & &1.handles)) ==
            MapSet.new([s.g, s.t])

        retained = Exchange.retained_bytes(exchange) - exchange.route_bytes
        b = independent_b(retained)
        ^b = exchange.route_bytes

        {:ok, {:native_generation_capture_v1, @m, 65_536, 65_536, ^b}} =
          ManagedGenerationAccounting.reservation(
            @m,
            {s.store, native, exchange.gate, exchange.lease, :request, exchange.deadline,
             retained}
          )

        {_total, worker_accounting, native_ids} =
          native_accounting(s.mode, native, exchange, retained, b, s)

        native_monitor = Process.monitor(native)

        connection_monitor =
          if native_ids.connection != native,
            do: Process.monitor(native_ids.connection),
            else: nil

        writer_monitor = if native_ids.writer, do: Process.monitor(native_ids.writer), else: nil
        observer = self()

        :ok =
          :sys.install(
            exchange.gate,
            {make_ref(),
             fn previous, event, _ ->
               case event do
                 {:in,
                  {:"$gen_call", _,
                   {:attach_cleanup, owner, lease, guardian, bytes, d, cleanup_token}}} ->
                   send(
                     observer,
                     {:cleanup_attachment, guardian, cleanup_token, owner, lease, bytes, d}
                   )

                 _ ->
                   :ok
               end

               previous
             end, nil}
          )

        target =
          Map.merge(native_ids, %{
            lease: exchange.lease,
            deadline: exchange.deadline,
            bytes: retained + b,
            present: true
          })

        original_cuts =
          for original <- originals do
            true = original.holder === native and original.deadline === exchange.deadline
            validate_cut(original.status, s, target)
          end

        for pin <- exchange.resource_pins do
          true = map_size(pin) == if(pin.provider == T, do: 8, else: 7)
          original = Enum.find(originals, &(&1.owner === pin.owner))

          :ok =
            ManagedGenerationAccounting.correlate(
              pin,
              {pin.provider, original.owner, original.operation, original.batch},
              native
            )

          if pin.provider == T, do: true = pin.holder === native
          owner = pin.owner

          if not Enum.any?(s.receipts, fn {p, observed} -> p === owner and observed === pin end) do
            receive do
              {:trace, ^owner, :send, {_tag, {:ok, observed}}, _} when observed === pin -> :ok
            after
              1000 -> raise "actual public owner receipt missing"
            end
          end
        end

        cut = Cohort.snapshot(s.cohort, exchange.gate)
        cut_evidence = validate_cut(cut, s, target)
        true = Map.fetch!(cut.leases, exchange.lease).bytes == retained + b
        File.write!(Path.join(s.evidence, "capture-cohort.log"), inspect(cut, limit: :infinity))

        emit("captured", %{
          pins:
            Enum.map(exchange.resource_pins, fn p ->
              %{
                provider: to_string(p.provider),
                kind: to_string(p.kind),
                fields: map_size(p),
                bytes: :erlang.external_size(p),
                operation: inspect(p.operation)
              }
            end),
          mode: s.mode,
          holder: inspect(native),
          native_ids: Map.new(native_ids, fn {key, value} -> {key, inspect(value)} end),
          worker_accounting: worker_accounting,
          retained: retained,
          reservation: b,
          gate_bytes: cut.bytes,
          cohort: cut_evidence,
          original_cohorts: original_cuts,
          original_owner_effects: length(originals),
          original_gate_bytes: Enum.map(originals, & &1.status.status.retained_bytes)
        })

        send(native, {:dispatch, token})
        source_t = Enum.find(exchange.resource_pins, &(&1.provider == T))

        loop(%{
          s
          | captures: 1,
            originals: originals,
            native: native,
            native_monitor: native_monitor,
            gate: exchange.gate,
            target: target,
            lease: exchange.lease,
            source_t_pin: source_t,
            connection: native_ids.connection,
            writer: native_ids.writer,
            native_baseline:
              if(worker_accounting,
                do: worker_accounting.connection_bytes + worker_accounting.writer_bytes,
                else: 0
              ),
            connection_monitor: connection_monitor,
            writer_monitor: writer_monitor
        })

      {:command, %{"op" => "request_clean"}} ->
        true = s.captures == 1 and s.custody != nil

        wait_until(
          fn ->
            UpstreamGroups.status(s.g).pins == 1 and elem(T.status(s.transports), 1).pins == 1 and
              UpstreamGroups.status(s.g).inflight == 0 and
              elem(T.status(s.transports), 1).request_tokens == 0 and
              elem(T.status(s.transports), 1).helpers == 0
          end,
          deadline()
        )

        wait_until(fn -> Admission.status(s.gate).cleanup_pending == 0 end, deadline())
        s = join_session(s)
        s = request_native_clean(s)
        s = %{s | request_cleaned: true}

        emit("request_clean", %{
          session: inspect(s.session),
          session_joined: s.session_joined,
          custody: s.custody,
          native_worker_joined: s.native_joined,
          group: Map.take(UpstreamGroups.status(s.g), [:pins, :inflight, :probes]),
          transport:
            Map.take(elem(T.status(s.transports), 1), [
              :pins,
              :request_tokens,
              :helpers,
              :resources
            ])
        })

        loop(s)

      {:command, %{"op" => "authorize_browser_close"}} ->
        true = s.request_cleaned and not s.browser_close_authorized
        cut = Cohort.snapshot(s.cohort, s.gate)
        validate_cut(cut, s, clean_target(s))
        assert_target_live(cut, s.connection, s.writer)
        {_socket, connection_state} = :sys.get_state(s.connection, 1000)

        if s.mode == "h2" do
          true =
            connection_state.phase == :http2 and not connection_state.closing and
              not connection_state.draining and not connection_state.close_after_write
        else
          true = connection_state.phase == :idle and connection_state.buffer == ""
        end

        true = Process.alive?(s.connection) and not s.connection_joined
        if s.mode == "h1", do: true = not s.native_joined
        if s.mode == "h2", do: true = Process.alive?(s.writer) and not s.writer_joined
        s = %{s | browser_close_authorized: true}

        emit("browser_close_authorized", %{
          mode: s.mode,
          connection: inspect(s.connection),
          connection_alive: true
        })

        loop(s)

      {:command, %{"op" => "stop"}} ->
        true = s.request_cleaned and s.browser_close_authorized
        # Runner sends this only after Chrome's real normal exit. Suspend stops
        # acceptance only; it never closes an existing native connection or Gate.
        :ok = ThousandIsland.suspend(s.backend)

        wait_until(
          fn ->
            {:ok, connections} = ThousandIsland.connection_pids(s.backend)
            connections == [] and terminals_observed?(Cohort.facts(s.cohort))
          end,
          deadline()
        )

        wait_until(
          fn ->
            match?(
              %{active: 0, retained_bytes: 0, cleanup_pending: 0, cleanup_failed: nil},
              Gaoxy.status(s.instance, :http)
            )
          end,
          deadline()
        )

        native_reason = if s.mode == "h1", do: {:shutdown, :peer_closed}, else: :normal
        join_native(s.native, s.native_monitor, s.native_joined, native_reason)

        if s.connection_monitor,
          do:
            join_native(
              s.connection,
              s.connection_monitor,
              s.connection_joined,
              {:shutdown, :peer_closed}
            )

        if s.writer_monitor, do: join_native(s.writer, s.writer_monitor, s.writer_joined)

        final = Cohort.snapshot(s.cohort, s.gate)
        validate_cut(final, s, %{s.target | present: false})
        joins = validate_terminals(final, s)
        File.write!(Path.join(s.evidence, "final-cohort.log"), inspect(final, limit: :infinity))
        :ok = :telemetry.detach(s.telemetry_id)
        true = :ets.delete(s.telemetry)
        observer_monitor = s.cohort_monitor
        :ok = Cohort.stop(s.cohort, s.gate)

        receive do
          {:DOWN, ^observer_monitor, :process, observer, :normal} when observer == s.cohort -> :ok
        after
          1000 -> raise "cohort observer normal join missing"
        end

        emit("closed_browser_clean", %{
          cohort_joins: joins,
          observer_joined: true,
          connection_joined: true,
          connection_reason: inspect({:shutdown, :peer_closed}),
          service:
            Map.take(Gaoxy.status(s.instance, :http), [
              :active,
              :retained_bytes,
              :cleanup_pending,
              :cleanup_failed
            ])
        })

        stop_join(s.store)

        wait_until(
          fn ->
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
              T.status(s.transports)
            )
          end,
          deadline()
        )

        stop_join(s.groups)
        ref = Process.monitor(s.transports)
        :ok = Gaoxy.stop(s.instance, 10_000)

        receive do
          {:DOWN, ^ref, :process, pid, :normal} when pid == s.transports -> :ok
        after
          10_000 -> raise "transport shutdown join deadline"
        end

        true = not Process.alive?(s.instance)
        after_identity = identity()
        true = s.before === after_identity
        File.write!(Path.join(s.evidence, "host-loaded-after.json"), JSON.encode!(after_identity))

        emit("stopped", %{
          cleanup_confirmed: true,
          source_stable: true,
          captures: s.captures,
          mode: s.mode,
          session_joined: s.session_joined,
          native_actors_joined: true
        })

        receive do
          {:command, %{"op" => "exit"}} -> :ok
        after
          10_000 -> raise "host exit command deadline"
        end

        input_ref = s.input_monitor

        receive do
          {:DOWN, ^input_ref, :process, pid, :normal} when pid == s.input -> :ok
        after
          1000 -> raise "host stdin helper join deadline"
        end

        emit("exited")

      :input_eof ->
        raise "stdin closed before stop"

      {:trace, owner, :send, {_tag, {:ok, %{provider: T, kind: :request} = pin}}, _}
      when s.captures == 1 and s.session == nil ->
        true = owner == s.transports and pin.holder != s.native
        hold = Map.fetch!(:sys.get_state(owner, 1000).pins, pin.ref)
        true = hold.public == pin and hold.derived == true
        true = hold.source_ref == s.source_t_pin.ref and hold.acquirer == s.native
        true = pin.handles == [s.t]
        session = pin.holder
        monitor = Process.monitor(session)

        {cleanup_token, attachment_owner, attachment_lease, attachment_bytes, attachment_d} =
          attachment(s, session)

        cleanup = Map.fetch!(:sys.get_state(s.gate, 1000).cleanups, cleanup_token)

        true =
          attachment_owner == s.native and cleanup.lease == attachment_lease and
            cleanup.lease == s.lease

        true = attachment_bytes == cleanup.bytes and Lifecycle.remaining(attachment_d) > 0
        true = cleanup.bytes > 0 and Admission.status(s.gate).cleanup_pending == 1

        custody = %{
          native: inspect(s.native),
          session: inspect(session),
          owner: inspect(owner),
          source_ref: inspect(hold.source_ref),
          child_ref: inspect(pin.ref),
          acquirer: inspect(hold.acquirer),
          derived: hold.derived,
          cleanup_token: inspect(cleanup_token),
          cleanup_lease: inspect(cleanup.lease),
          cleanup_bytes: cleanup.bytes,
          public_t8_fields: map_size(pin)
        }

        emit("session_custody", custody)
        loop(%{s | session: session, session_monitor: monitor, custody: custody})

      {:cleanup_attachment, session, token, owner, lease, bytes, d} ->
        true = s.attachment == nil
        loop(%{s | attachment: {session, token, owner, lease, bytes, d}})

      {:DOWN, monitor, :process, owner, {:shutdown, :peer_closed}}
      when s.browser_close_authorized and owner == s.connection and
             (monitor == s.connection_monitor or
                (s.mode == "h1" and monitor == s.native_monitor)) ->
        loop(%{
          s
          | connection_joined: true,
            native_joined: if(s.mode == "h1", do: true, else: s.native_joined)
        })

      {:DOWN, monitor, :process, writer, :normal}
      when s.browser_close_authorized and monitor == s.writer_monitor and writer == s.writer ->
        loop(%{s | writer_joined: true})

      {:DOWN, monitor, :process, native, :normal}
      when s.mode == "h2" and monitor == s.native_monitor and native == s.native ->
        loop(%{s | native_joined: true})

      {:DOWN, monitor, :process, session, :normal}
      when monitor == s.session_monitor and session == s.session ->
        loop(%{s | session_joined: true})

      {:trace, owner, :send, {_tag, {:ok, %{kind: :request} = pin}}, _} when s.captures == 0 ->
        true = length(s.receipts) < 2
        loop(%{s | receipts: s.receipts ++ [{owner, pin}]})

      {:trace, _, :send, _, _} ->
        loop(s)

      {:cohort_trace, observer, fact} when observer == s.cohort ->
        File.write!(Path.join(s.evidence, "causal-metadata.log"), inspect(fact) <> "\n", [:append])

        loop(s)

      {:EXIT, _, :normal} ->
        loop(s)

      other ->
        raise "unexpected host message: #{inspect(other)}"
    after
      30_000 -> raise "host command/capture deadline"
    end
  end

  def collect_originals(rows, count) when length(rows) == count, do: rows

  def collect_originals(rows, count) do
    receive do
      {:original, owner, batch, holder, op, d, status} ->
        collect_originals(
          rows ++
            [
              %{
                owner: owner,
                batch: batch,
                holder: holder,
                operation: op,
                deadline: d,
                status: status
              }
            ],
          count
        )
    after
      1000 -> raise "owner input observation missing"
    end
  end

  def cohort_event(
        [:gaoxy, :lifecycle],
        _,
        %{service: :http, state: :ready, generation: generation},
        %{host: host}
      ) do
    send(host, {:cohort_service, self(), generation})
  end

  def cohort_event(
        [:thousand_island, :listener, :start],
        _,
        %{handler: Gaoxy.HTTP.Connection, telemetry_span_context: span, local_port: port},
        %{table: table}
      ) do
    true = :ets.insert_new(table, {:listener, span, port})
  end

  def cohort_event(
        [:thousand_island, :acceptor, :start],
        _,
        %{
          handler: Gaoxy.HTTP.Connection,
          telemetry_span_context: span,
          parent_telemetry_span_context: listener
        },
        %{table: table}
      ) do
    [{:listener, ^listener, _}] = :ets.lookup(table, :listener)
    true = :ets.insert_new(table, {{:acceptor, span}, listener})
  end

  def cohort_event(
        [:thousand_island, :connection, :start],
        _,
        %{
          handler: Gaoxy.HTTP.Connection,
          telemetry_span_context: span,
          parent_telemetry_span_context: acceptor
        },
        %{table: table}
      ) do
    [{{:acceptor, ^acceptor}, listener}] = :ets.lookup(table, {:acceptor, acceptor})
    [{:observer, observer, service, ^listener}] = :ets.lookup(table, :observer)

    :ok =
      Cohort.native_start(observer, self(), %{
        service: service,
        listener: listener,
        acceptor: acceptor,
        span: span
      })
  end

  def cohort_event(_, _, _, _), do: :ok

  def native_accounting("h1", native, exchange, retained, b, s) do
    true = exchange.protocol_bytes == 0
    ids = %{connection: native, writer: nil, worker: native, worker_lease: exchange.lease}

    target =
      Map.merge(ids, %{
        lease: exchange.lease,
        deadline: exchange.deadline,
        bytes: retained + b,
        present: true
      })

    cut = Cohort.snapshot(s.cohort, exchange.gate)
    validate_cut(cut, s, target)
    {cut.bytes, nil, ids}
  end

  def native_accounting("h2", native, exchange, retained, b, s) do
    {owner, id, token} = exchange.transport_state
    true = native != owner and Process.alive?(native)
    {socket, state} = :sys.get_state(owner, 1000)
    {:ok, "h2"} = ThousandIsland.Socket.negotiated_protocol(socket)
    true = state.secure and exchange.secure
    true = state.spec == s.spec and state.gate == s.gate
    %{worker: ^native, lease: lease, token: ^token, startup: nil} = Map.fetch!(state.streams, id)
    true = lease == exchange.lease and state.gate == exchange.gate
    stream = Map.fetch!(state.streams, id)
    true = stream.request == exchange.request and stream.deadline == exchange.deadline
    accounting = NativeWorkerBrowserArithmetic.reservation(owner, native, state, stream)
    true = length(accounting.rows) == 95
    true = exchange.protocol_bytes == accounting.protocol_bytes
    true = retained == accounting.bytes
    true = accounting.bytes == accounting.protocol_bytes + 2 * stream.request.head_bytes
    {connection, writer} = ordinary_reserves(s)
    true = state.reserves.connection == connection and state.reserves.writer == writer
    cut = Cohort.snapshot(s.cohort, exchange.gate)

    [{writer_lease, writer_record}] =
      Enum.filter(cut.leases, fn {_, record} ->
        record.pid == state.writer
      end)

    true = writer_record.bytes == writer

    ids = %{
      connection: owner,
      writer: state.writer,
      worker: native,
      connection_lease: state.lease,
      writer_lease: writer_lease,
      worker_lease: exchange.lease,
      token: token
    }

    target =
      Map.merge(ids, %{
        lease: exchange.lease,
        deadline: exchange.deadline,
        bytes: retained + b,
        present: true
      })

    validate_cut(cut, s, target)

    evidence =
      Map.merge(accounting, %{
        connection_bytes: connection,
        writer_bytes: writer,
        worker_bytes: accounting.bytes + b,
        gate_active: cut.status.active,
        downstream_alpn: "h2",
        secure: true
      })

    {cut.bytes, evidence, ids}
  end

  def ordinary_reserves(%{mode: "h1"}), do: {0, nil}

  def ordinary_reserves(s) do
    http = s.spec.handler_options.http_limits
    h2 = s.spec.handler_options.h2_limits
    block = h2.max_header_block
    table = h2.table_size
    decode = 2 * block * (max(table, 128) + 2) + 512 * block + 2 * table

    {decode + 16_777_216 + 65_535 + 4 * http.max_buffer_bytes +
       8 * (100 * 16_384 + 18_437), 4 * 16_384 + 1_024}
  end

  def prove_acquisitions(cut, s) do
    {connection_bytes, writer_bytes} = ordinary_reserves(s)
    starts = Map.new(cut.ledger.native_starts, &{&1.pid, &1})
    true = map_size(starts) == length(cut.ledger.native_starts)

    for start <- Map.values(starts) do
      true = start.service == s.service

      true =
        is_reference(start.listener) and is_reference(start.acceptor) and
          is_reference(start.span) and is_reference(start.monitor)
    end

    ready = Map.new(cut.ledger.ready, &{&1.writer, &1})
    true = map_size(ready) == length(cut.ledger.ready)
    acquired = Enum.filter(cut.ledger.acquisitions, &(&1.sequence < cut.sequence))
    true = length(acquired) == MapSet.size(MapSet.new(Enum.map(acquired, & &1.lease)))
    true = length(acquired) == MapSet.size(MapSet.new(Enum.map(acquired, & &1.pid)))
    # Validate EVERY acquired ordinary lease, even one removed before the first
    # checkpoint. Active membership is derived separately by authentic DOWN seq.
    for a <- acquired do
      {pid, [:alias | request]} = a.from

      true =
        pid == a.pid and is_reference(request) and is_reference(a.lease) and
          is_reference(a.monitor)

      {role, bytes} =
        if Map.has_key?(starts, a.pid) do
          {:connection, connection_bytes}
        else
          true = s.mode == "h2"
          fact = Map.fetch!(ready, a.pid)
          true = fact.delivery == :send
          true = fact.writer == a.pid and fact.owner != a.pid
          true = Map.has_key?(starts, fact.owner)
          [parent] = Enum.filter(acquired, &(&1.pid == fact.owner))
          true = parent.sequence < a.sequence and parent.bytes == connection_bytes
          {:writer, writer_bytes}
        end

      true = a.bytes == bytes and a.options == [drain_notify: true]
      Map.merge(a, %{role: role, expected_bytes: bytes})
    end
  end

  def validate_cut(cut, s, target) do
    acquired = prove_acquisitions(cut, s)
    # Ordinary leases can only be removed by their authentic Gate-monitor DOWN.
    active =
      Enum.reject(acquired, fn a ->
        Enum.any?(cut.ledger.terminal, fn event ->
          event.source == :authenticated_gate_monitor and event.pid == a.pid and
            event.monitor == a.monitor and event.lease == a.lease and
            event.sequence < cut.sequence
        end)
      end)

    rows =
      for a <- active do
        record = Map.fetch!(cut.leases, a.lease)
        true = record.pid == a.pid and record.monitor == a.monitor
        true = record.drain_notify and is_reference(record.monitor)

        expected =
          if s.mode == "h1" and target.present and a.lease == target.lease,
            do: target.bytes,
            else: a.expected_bytes

        true = record.bytes == expected

        if s.mode == "h1" and target.present and a.lease == target.lease do
          true = record.request_active and record.deadline == target.deadline
        else
          true = not record.request_active and record.deadline == nil
        end

        %{lease: a.lease, pid: a.pid, role: a.role, bytes: expected}
      end

    rows =
      if s.mode == "h2" and target.present do
        child = Map.fetch!(cut.leases, target.lease)
        true = child.pid == target.worker and child.bytes == target.bytes
        true = child.deadline == target.deadline and child.request_active and child.drain_notify

        %{
          worker: worker,
          lease: child_ref,
          parent_lease: parent_ref,
          owner: owner,
          phase: :running,
          from: nil,
          activation: nil,
          exit_seen: false,
          down_seen: false
        } =
          Map.fetch!(cut.spawns, target.token)

        true =
          worker == target.worker and child_ref == target.lease and
            parent_ref == target.connection_lease and owner == target.connection

        true = Map.keys(cut.spawns) == [target.token]
        true = Map.fetch!(cut.leases, target.connection_lease).pid == target.connection
        true = Map.fetch!(cut.leases, target.writer_lease).pid == target.writer

        rows ++
          [%{lease: target.lease, pid: target.worker, role: :request_worker, bytes: target.bytes}]
      else
        true = cut.spawns == %{}
        rows
      end

    true = MapSet.new(Map.keys(cut.leases)) == MapSet.new(Enum.map(rows, & &1.lease))
    total = Enum.sum(Enum.map(rows, & &1.bytes))
    true = cut.bytes == total and cut.status.retained_bytes == total
    true = cut.status.active == length(rows) and cut.status.cleanup_pending == 0
    true = cut.cleanups == %{}

    if target.present do
      true = Map.has_key?(cut.leases, target.lease)
      assert_target_live(cut, target.connection, target.writer)
    end

    %{
      sequence: cut.sequence,
      active: length(rows),
      retained_bytes: total,
      target_bytes: if(target.present, do: target.bytes, else: 0),
      roles:
        Enum.map(rows, fn row ->
          Map.new(row, fn
            {:lease, value} -> {:lease, inspect(value)}
            {:pid, value} -> {:pid, inspect(value)}
            pair -> pair
          end)
        end)
    }
  end

  def assert_target_live(cut, connection, writer) do
    for pid <- [connection, writer], pid != nil do
      true = Process.alive?(pid)
      true = not Enum.any?(cut.ledger.terminal, &(&1.pid == pid))
    end
  end

  def clean_target(%{mode: "h1"} = s), do: %{s.target | bytes: 0}
  def clean_target(s), do: %{s.target | present: false}

  def terminals_observed?(ledger) do
    pids =
      MapSet.new(
        Enum.map(ledger.native_starts, & &1.pid) ++
          Enum.map(ledger.acquisitions, & &1.pid)
      )

    Enum.all?(pids, fn pid ->
      not Process.alive?(pid) and
        Enum.any?(ledger.terminal, fn event ->
          event.pid == pid and event.reason != :noproc
        end)
    end)
  end

  def validate_terminals(cut, s) do
    true = cut.leases == %{} and cut.spawns == %{} and cut.cleanups == %{}

    pids =
      MapSet.new(
        Enum.map(cut.ledger.native_starts, & &1.pid) ++
          Enum.map(cut.ledger.acquisitions, & &1.pid)
      )

    rows =
      for pid <- pids do
        true = not Process.alive?(pid)
        events = Enum.filter(cut.ledger.terminal, &(&1.pid == pid))
        genuine = Enum.reject(events, &(&1.reason == :noproc))
        true = genuine != []
        reasons = Enum.uniq(Enum.map(genuine, & &1.reason))
        [reason] = reasons
        is_connection = Enum.any?(cut.ledger.native_starts, &(&1.pid == pid))
        acquired = Enum.any?(cut.ledger.acquisitions, &(&1.pid == pid))

        cond do
          is_connection and acquired ->
            true = reason == {:shutdown, :peer_closed}

          is_connection ->
            # Before any lease, the H2 metadata-close path returns TI's local close.
            # Admitted connections and the target retain their peer-closed assertion.
            true =
              reason in [
                {:shutdown, :peer_closed},
                {:shutdown, {:handshake, :closed}},
                {:shutdown, :local_closed}
              ]

          true ->
            true = reason == :normal
        end

        %{
          pid: inspect(pid),
          reason: inspect(reason),
          connection: is_connection,
          admitted: acquired,
          genuine_terminal: true
        }
      end

    true = Enum.any?(rows, &(&1.pid == inspect(s.connection)))
    rows
  end

  def attachment(%{attachment: {session, token, owner, lease, bytes, d}}, session),
    do: {token, owner, lease, bytes, d}

  def attachment(_, session) do
    receive do
      {:cleanup_attachment, ^session, token, owner, lease, bytes, d} ->
        {token, owner, lease, bytes, d}
    after
      1000 -> raise "actual Service cleanup attachment observation missing"
    end
  end

  def join_session(%{session_joined: true} = s), do: s

  def join_session(s) do
    join_native(s.session, s.session_monitor, false)
    %{s | session_joined: true}
  end

  def request_native_clean(%{mode: "h1"} = s) do
    wait_until(
      fn ->
        cut = Cohort.snapshot(s.cohort, s.gate)
        record = Map.fetch!(cut.leases, s.lease)
        record.bytes == 0 and cut.status.cleanup_pending == 0
      end,
      deadline()
    )

    cut = Cohort.snapshot(s.cohort, s.gate)
    validate_cut(cut, s, clean_target(s))
    {_socket, idle} = :sys.get_state(s.connection, 1000)
    true = idle.phase == :idle and idle.buffer == "" and idle.deadline == nil
    true = idle.lease == s.lease and idle.gate == s.gate
    File.write!(Path.join(s.evidence, "request-clean-cohort.log"), inspect(cut, limit: :infinity))
    s
  end

  def request_native_clean(%{mode: "h2"} = s) do
    join_native(s.native, s.native_monitor, s.native_joined)

    wait_until(
      fn ->
        cut = Cohort.snapshot(s.cohort, s.gate)

        not Map.has_key?(cut.leases, s.lease) and cut.spawns == %{} and
          cut.status.cleanup_pending == 0
      end,
      deadline()
    )

    cut = Cohort.snapshot(s.cohort, s.gate)
    validate_cut(cut, s, clean_target(s))
    true = Map.fetch!(cut.leases, s.target.connection_lease).pid == s.connection
    true = Map.fetch!(cut.leases, s.target.writer_lease).pid == s.writer
    assert_target_live(cut, s.connection, s.writer)
    File.write!(Path.join(s.evidence, "request-clean-cohort.log"), inspect(cut, limit: :infinity))
    %{s | native_joined: true}
  end

  def join_native(pid, monitor, joined, reason \\ :normal)

  def join_native(pid, monitor, true, _reason) do
    true = not Process.alive?(pid)
    true = is_reference(monitor)
    :ok
  end

  def join_native(pid, monitor, false, reason) do
    receive do
      {:DOWN, ^monitor, :process, ^pid, ^reason} -> :ok
    after
      5000 -> raise "actual native/session exact terminal join missing: #{inspect(reason)}"
    end

    true = not Process.alive?(pid)
  end

  def stop_join(pid) do
    ref = Process.monitor(pid)
    :ok = GenServer.stop(pid, :normal, 5000)

    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
    after
      5000 -> raise "host actor join deadline"
    end
  end
end

[port, evidence, mode, certificates] = System.argv()
true = mode in ["h2", "h1"]

try do
  NativeWorkerBrowserHost.run(String.to_integer(port), evidence, mode, certificates)
rescue
  error ->
    if observer = Process.get(:native_worker_browser_cohort) do
      if Process.alive?(observer) do
        facts = NativeWorkerBrowserCohort.facts(observer)
        File.write!(Path.join(evidence, "failure-cohort.log"), inspect(facts, limit: :infinity))
      end
    end

    reraise error, __STACKTRACE__
end
