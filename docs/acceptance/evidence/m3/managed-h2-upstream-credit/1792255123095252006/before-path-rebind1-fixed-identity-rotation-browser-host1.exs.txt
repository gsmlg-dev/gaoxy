# Fixed same-authority identity rotation browser host; proposal only.
# Derived from accepted Generation fixture; preserves original custody/accounting gates.
Code.require_file(
  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-response-prefix/1792251316888813330/fixed-identity-rotation-browser-cohort1.exs"
)

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
defmodule FixedH2GenerationBrowserDraft do
  alias Gaoxy.Lifecycle
  alias Gaoxy.HTTP.{Generation, Resources}
  alias Gaoxy.Proxy.UpstreamTransports, as: T

  defmodule Captured do
    alias Gaoxy.Lifecycle
    alias Gaoxy.Proxy.HTTP, as: ProxyHTTP

    def init({options, host, label}) when label in [:old, :new] do
      with {:ok, config} <- ProxyHTTP.init(options), do: {:ok, {config, host, label}}
    end

    def resources({config, _, _}), do: ProxyHTTP.resources(config)
    def generation_validate({config, _, _}), do: ProxyHTTP.generation_validate(config)

    def call(exchange, {config, host, label}) do
      ref = make_ref()
      send(host, {:capture, label, self(), ref, exchange})

      receive do
        {:dispatch, ^ref} ->
          result = ProxyHTTP.call(exchange, config)
          # This runs in the ORIGINAL native actor AFTER real Session join.
          # Do not move it to Store/provider/coordinator or rewrite Exchange/result.
          send(host, {:returned, label, self(), ref, result})

          receive do
            {:return, ^ref} -> result
          after
            min(10_000, Lifecycle.remaining(exchange.deadline)) ->
              raise "fixed Generation return barrier expired"
          end
      after
        min(10_000, Lifecycle.remaining(exchange.deadline)) ->
          raise "fixed Generation dispatch barrier expired"
      end
    end
  end

  def deadline, do: Lifecycle.deadline(10_000)

  def wait_until(fun, deadline) do
    if fun.() do
      :ok
    else
      true = Lifecycle.remaining(deadline) > 0

      receive do
      after
        2 -> wait_until(fun, deadline)
      end
    end
  end

  # Runs in the host, which is the AUTHENTIC preparation holder. Do not release
  # these pins in another process. A separate coordinator is unnecessary for the
  # serial browser host; socket/failure fixtures retain their coordinator coverage.
  def public_pem(path) do
    bytes = File.open!(path, [:read, :binary], fn io -> IO.binread(io, 1_048_577) end)
    true = is_binary(bytes) and byte_size(bytes) > 0 and byte_size(bytes) <= 1_048_576
    bytes
  end

  def trust_file(path) do
    pem = public_pem(path)

    certificates =
      pem
      |> :public_key.pem_decode()
      |> Enum.map(fn {:Certificate, der, :not_encrypted} -> :binary.copy(der) end)

    true = length(certificates) in 1..128
    true = Enum.all?(certificates, &(byte_size(&1) > 0 and byte_size(&1) <= 65_536))
    true = Enum.sum(Enum.map(certificates, &byte_size/1)) <= 1_048_576

    {certificates,
     %{
       path: path,
       pem_sha256: digest(pem),
       der_sha256: Enum.map(certificates, &digest/1),
       der_count: length(certificates),
       der_bytes: Enum.sum(Enum.map(certificates, &byte_size/1))
     }}
  end

  def replace_slots(readies, paths) do
    true = length(readies) == length(paths)

    Enum.zip(readies, paths)
    |> Enum.map(fn {ready, path} ->
      pem = public_pem(ready["ca"])
      File.write!(path, pem)
      true = public_pem(path) === pem
      Map.put(ready, "trust_path", path)
    end)
  end

  def numeric_address(ready) do
    true = ready["bind_address"] in ["127.0.0.1", "127.0.0.2", "127.0.0.3", "127.0.0.4"]
    {:ok, address} = :inet.parse_address(String.to_charlist(ready["bind_address"]))
    address
  end

  def retained_policy(owner, transport, source) do
    policy = Map.fetch!(:sys.get_state(owner, 1_000).records, transport.resource).policy
    true = policy.protocol === :http2 and policy.origin === source.origin
    true = policy.host === "localhost" and policy.scheme === :https
    true = policy.connect_address === source.connect_address
    options = policy.open_options
    true = Keyword.fetch!(options, :origin) === source.origin
    true = Keyword.fetch!(options, :connect_address) === source.connect_address
    true = Keyword.fetch!(options, :http_version) === :http2
    true = Keyword.fetch!(options, :max_connections) === 2
    true = Keyword.fetch!(options, :max_requests) === 32
    true = Keyword.fetch!(options, :max_pending) === 0
    ssl = Keyword.fetch!(options, :ssl)
    true = Keyword.fetch!(ssl, :verify) === :verify_peer
    true = Keyword.fetch!(ssl, :server_name_indication) === ~c"localhost"
    true = Keyword.fetch!(ssl, :cacerts) === source.trust
    true = not Keyword.has_key?(ssl, :cacertfile)
    policy
  end

  def assert_rotation(old, new) do
    true = length(old.identities) == length(new.identities)

    rows =
      Enum.zip(old.identities, new.identities)
      |> Enum.map(fn {a, b} ->
        true = a.trust.path === b.trust.path and a.trust.pem_sha256 !== b.trust.pem_sha256
        true = a.trust.der_sha256 !== b.trust.der_sha256 and a.leaf_sha256 !== b.leaf_sha256
        true = a.transport !== b.transport
        true = a.source.origin === b.source.origin
        true = a.policy.host === b.policy.host and a.policy.port === b.policy.port
        true = a.source.connect_address !== b.source.connect_address
        true = retained_policy(old.owner, a.transport, a.source) === a.policy
        true = retained_policy(new.owner, b.transport, b.source) === b.policy

        %{
          path: a.trust.path,
          origin: a.source.origin,
          host: a.policy.host,
          port: a.policy.port,
          old: identity_row(a),
          new: identity_row(b),
          old_policy_unchanged: true
        }
      end)

    # Invalidate the actual caller paths before permitting either cold GET.
    for row <- rows do
      File.write!(row.path, "invalid public trust source after preparation\n")
      [] = row.path |> public_pem() |> :public_key.pem_decode()
    end

    # The actual retained policies still carry OLD/NEW DER after invalidation.
    for c <- [old, new], i <- c.identities do
      true = retained_policy(c.owner, i.transport, i.source) === i.policy
    end

    NativeWorkerBrowserHost.emit("identity_rotation", %{
      rows: rows,
      same_path_replaced: true,
      source_invalidated: true,
      retained_policies_checked: true,
      old_capture_before_replacement: true
    })

    :ok
  end

  def identity_row(i) do
    %{
      address: :inet.ntoa(i.source.connect_address) |> to_string(),
      resource: inspect(i.transport.resource),
      pem_sha256: i.trust.pem_sha256,
      der_sha256: i.trust.der_sha256,
      der_count: i.trust.der_count,
      der_bytes: i.trust.der_bytes,
      leaf_sha256: i.leaf_sha256,
      policy_sha256: digest(:erlang.term_to_binary(i.policy))
    }
  end

  def digest(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  def prepare_candidate(owner, store, ready, protocol, host, label) do
    true = protocol === :http2
    true = ready["protocol"] == if(protocol == :http2, do: "tls", else: "h2c")

    {trust, trust_identity} = trust_file(ready["trust_path"])
    true = trust_identity.pem_sha256 === ready["caller_ca_sha256"]

    source = %{
      protocol: protocol,
      origin: "#{if(protocol == :http2, do: "https", else: "http")}://localhost:#{ready["port"]}",
      connect_address: numeric_address(ready),
      trust: trust
    }

    {:ok, transport, preparation} = T.prepare(owner, source, self(), deadline())
    options = %{upstream: source.origin, upstream_protocol: protocol, transport: transport}
    routes = [%{target: {Captured, {options, host, label}}}]
    {:ok, router} = Generation.prepare(store, routes, 5_000)
    record = Map.fetch!(:sys.get_state(owner, 1_000).records, transport.resource)
    custodian = record.custodian
    true = is_pid(custodian) and Process.alive?(custodian)

    %{
      source: source,
      identities: [
        %{
          source: source,
          transport: transport,
          policy: retained_policy(owner, transport, source),
          trust: trust_identity,
          leaf_sha256: digest(public_pem(ready["cert"]))
        }
      ],
      transport: transport,
      preparation: preparation,
      router: router,
      custodian: custodian,
      custodian_monitor: Process.monitor(custodian),
      label: label,
      owner: owner,
      protocol: protocol,
      ready: ready
    }
  end

  def activate_candidate(store, candidate, expected) do
    {:ok, generation} = Generation.activate(store, expected, candidate.router, 5_000)
    {:ok, ^generation, router} = Generation.snapshot(store)
    true = router === candidate.router
    # The Store baseline must exist BEFORE the authentic holder releases prep.
    baseline = :sys.get_state(store, 1_000).baseline
    [pin] = baseline
    true = pin.kind == :baseline and pin.holder == store
    true = pin.handles === [candidate.transport]
    :ok = Resources.release(candidate.preparation)
    wait_until(fn -> configured_pins(candidate) == [:baseline] end, deadline())
    Map.put(candidate, :generation, generation)
  end

  def configured_pins(candidate) do
    for {_, hold} <- :sys.get_state(candidate.owner, 1_000).pins,
        candidate.transport in hold.public.handles,
        hold.public.kind in [:preparation, :baseline],
        do: hold.public.kind
  end

  # Call after E1 complete-cohort capture + independent B + actual native W
  # assertions. 'original' is the ONE observed Store->T pin_many input, with
  # its synchronously observed original Gate cut, not a manufactured receipt.
  def assert_source(candidate, store, native, exchange, original) do
    [pin] = exchange.resource_pins

    true =
      Enum.sort(Map.keys(pin)) ==
        Enum.sort([:provider, :owner, :owner_epoch, :operation, :ref, :handles, :kind, :holder])

    true = pin.provider === T and pin.owner === candidate.owner
    true = pin.owner_epoch === candidate.transport.owner_epoch
    true = pin.holder === native and pin.handles === [candidate.transport]
    true = pin.kind === :request and is_reference(pin.ref)
    true = original.owner === candidate.owner and original.holder === native
    true = original.batch === [candidate.transport] and original.operation === pin.operation
    true = original.deadline === exchange.deadline

    :ok =
      Gaoxy.Proxy.ManagedGenerationAccounting.correlate(
        pin,
        {T, candidate.owner, original.operation, original.batch},
        native
      )

    state = :sys.get_state(candidate.owner, 1_000)
    hold = Map.fetch!(state.pins, pin.ref)
    true = hold.public === pin and hold.acquirer === store and not Map.get(hold, :derived, false)

    true =
      not Enum.any?(state.tokens, fn {_, t} -> t.resource == candidate.transport.resource end)

    [^pin] =
      for {_, p} <- state.pins,
          p.public.kind === :request and candidate.transport in p.public.handles,
          do: p.public

    true = Process.alive?(candidate.custodian)
    pin
  end

  # CAS new while original native is at Captured dispatch barrier. Store is FREE.
  # No ordinary re-pin and no owner-wide retirement. No fallback/re-selection.
  def cas_while_captured(store, instance, old, new, native, source_pin) do
    new = activate_candidate(store, new, old.generation)

    wait_until(
      fn ->
        state = :sys.get_state(old.owner, 1_000)
        hold = Map.get(state.pins, source_pin.ref)

        configured_pins(old) == [] and hold != nil and hold.public === source_pin and
          Map.fetch!(state.records, old.transport.resource).admission == :closed
      end,
      deadline()
    )

    true = source_pin.holder === native and Process.alive?(native)
    true = Process.alive?(old.custodian)

    {:error, :resource_admission_closed} =
      T.validate_endpoint(
        old.transport,
        %{origin: old.source.origin, upstream_protocol: old.protocol, instance: instance},
        deadline()
      )

    new
  end

  # Trigger from runner only after the independent peer observed old/new request,
  # while its manual response is still held. Read GAOXY Session/owner only;
  # original_request is opaque and its PUBLIC completion method is authoritative.
  def bound(candidate, source_pin, native, session, session_monitor) do
    wait_until(
      fn ->
        Enum.any?(:sys.get_state(candidate.owner, 1_000).tokens, fn {_, token} ->
          token.resource === candidate.transport.resource and
            match?(%HTTP.RequestCompletion{}, token.completion)
        end)
      end,
      deadline()
    )

    owner = :sys.get_state(candidate.owner, 1_000)

    [{token_ref, token}] =
      Enum.filter(owner.tokens, fn {_, t} ->
        t.resource === candidate.transport.resource
      end)

    true = token.guardian === session and session !== native
    true = Process.alive?(session) and is_reference(session_monitor)
    native_hold = Map.fetch!(owner.pins, source_pin.ref)
    true = native_hold.public === source_pin and not Map.get(native_hold, :derived, false)

    [child] =
      for {_, hold} <- owner.pins,
          hold.public.kind === :request and hold.public.holder === session and
            hold.public.handles === [candidate.transport],
          do: hold

    true = child.derived and child.source_ref === source_pin.ref
    true = child.acquirer === native and child.public.ref !== source_pin.ref
    true = child.public.owner_epoch === source_pin.owner_epoch
    true = map_size(child.public) == 8 and child.public.holder === session
    state = :sys.get_state(session, 1_000)
    true = state.transport_selection === {candidate.transport, token_ref}
    true = state.transport_pins === [child.public]
    completion = state.client.completion(state.original_request)
    true = completion === token.completion
    {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
    # Integrating host retains E1 real Service attachment token/lease/bytes
    # assertions too; this helper does not replace those with owner pin evidence.
    %{
      session: session,
      session_monitor: session_monitor,
      completion: completion,
      token_ref: token_ref,
      child_pin: child.public,
      source_pin: source_pin
    }
  end

  # Invoked at {:returned,...}; authentic monitor was installed on child receipt,
  # BEFORE the peer response. Never replace with a new late :noproc monitor.
  def assert_returned_source_held(candidate, native, custody) do
    :ok = HTTP.RequestCompletion.await(custody.completion, 0)

    if not Map.get(custody, :session_joined, false) do
      receive do
        {:DOWN, ref, :process, session, :normal}
        when ref === custody.session_monitor and session === custody.session ->
          :ok
      after
        5_000 -> raise "original Session normal DOWN missing"
      end
    end

    true = not Process.alive?(custody.session)
    owner = :sys.get_state(candidate.owner, 1_000)
    true = not Map.has_key?(owner.tokens, custody.token_ref)
    true = not Map.has_key?(owner.pins, custody.child_pin.ref)
    hold = Map.fetch!(owner.pins, custody.source_pin.ref)
    true = hold.public === custody.source_pin and custody.source_pin.holder === native
    record = Map.fetch!(owner.records, candidate.transport.resource)
    true = Process.alive?(candidate.custodian)
    true = not record.retirement_requested

    if candidate.label === :old do
      true = record.admission === :closed and configured_pins(candidate) == []
    end

    :ok
  end

  # Only after authentic {:return,ref} to the ORIGINAL native old actor. Runner
  # separately joins old peer physical EOF/connection_reset BEFORE peer stop.
  def retired(candidate, source_pin) do
    wait_until(
      fn ->
        owner = :sys.get_state(candidate.owner, 1_000)

        not Map.has_key?(owner.pins, source_pin.ref) and
          not Map.has_key?(owner.records, candidate.transport.resource)
      end,
      deadline()
    )

    ref = candidate.custodian_monitor
    pid = candidate.custodian

    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} -> :ok
    after
      5_000 -> raise "original old custodian normal DOWN missing"
    end

    true = not Process.alive?(pid)
    :ok
  end

  def rebind({{127, 0, 0, 1} = ip, port}) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, ip: ip, reuseaddr: true])
    :ok = :gen_tcp.close(socket)
  end
end

defmodule NativeWorkerBrowserHost do
  alias Gaoxy.{Admission, Lifecycle}
  alias NativeWorkerBrowserCohort, as: Cohort
  alias FixedH2GenerationBrowserDraft, as: Fixed
  alias Gaoxy.HTTP.{Exchange, Generation}
  alias Gaoxy.Proxy.ManagedGenerationAccounting
  alias Gaoxy.Proxy.UpstreamTransports, as: T
  @m 1_048_576

  def emit(event, fields \\ %{}),
    do: IO.puts("NATIVE_WORKER_BROWSER " <> JSON.encode!(Map.put(fields, :event, event)))

  def diagnostic_reason(:normal), do: "NORMAL"
  def diagnostic_reason(:killed), do: "KILLED"
  def diagnostic_reason(:noproc), do: "NOPROC"
  def diagnostic_reason(:shutdown), do: "SHUTDOWN"
  def diagnostic_reason({:shutdown, :peer_closed}), do: "SHUTDOWN_PEER_CLOSED"
  def diagnostic_reason(_), do: "OTHER"

  def deadline, do: Lifecycle.deadline(10_000)
  def wait_until(fun, d), do: Fixed.wait_until(fun, d)

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
            FixedH2GenerationBrowserDraft,
            FixedH2GenerationBrowserDraft.Captured,
            NativeWorkerBrowserArithmetic,
            NativeWorkerBrowserCohort
          ] do
        source =
          module.module_info(:compile) |> Keyword.fetch!(:source) |> to_string() |> Path.expand()

        true =
          source in [
            Path.expand(__ENV__.file),
            Path.join(
              root,
              "docs/acceptance/evidence/m3/managed-h2-response-prefix/1792251316888813330/fixed-identity-rotation-browser-cohort1.exs"
            )
          ]

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

  def run(manifest, evidence, mode, certificates, protocol) do
    Process.flag(:trap_exit, true)
    before = identity()
    File.write!(Path.join(evidence, "host-loaded-before.json"), JSON.encode!(before))
    peers = File.read!(manifest) |> JSON.decode!()
    true = protocol === :http2
    true = peers["old"]["port"] === peers["new"]["port"]
    true = peers["old"]["bind_address"] === "127.0.0.1"
    true = peers["new"]["bind_address"] === "127.0.0.2"
    {:ok, instance} = Gaoxy.start_link()
    instance_monitor = Process.monitor(instance)

    {:ok, transports} =
      T.start_link(
        instance: instance,
        limits: %{
          max_resources: 4,
          max_pins: 256,
          max_request_tokens: 64,
          max_owned_payload_bytes: 8_388_608
        }
      )

    owner_monitor = Process.monitor(transports)
    {:ok, store} = Generation.start_link(routes: [], max_config_bytes: @m)
    {:ok, initial, _} = Generation.snapshot(store)
    paths = [Path.join(evidence, "trust-a.pem")]
    [old_ready] = Fixed.replace_slots([peers["old"]], paths)
    old = Fixed.prepare_candidate(transports, store, old_ready, protocol, self(), :old)
    old = Fixed.activate_candidate(store, old, initial)
    new = nil
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

    owner_hook = make_ref()

    :ok =
      :sys.install(
        transports,
        {owner_hook,
         fn previous, event, _ ->
           case event do
             {:in, {:"$gen_call", {^store, _}, {tag, batch, holder, :request, op, d}}}
             when tag in [:pin, :pin_many] ->
               send(
                 host,
                 {:original, transports, batch, holder, op, d, Cohort.snapshot(cohort, gate)}
               )

             _ ->
               :ok
           end

           previous
         end, nil}
      )

    1 = :erlang.trace(transports, true, [:send, {:tracer, self()}])
    cleanup_hook = make_ref()

    :ok =
      :sys.install(
        gate,
        {cleanup_hook,
         fn previous, event, _ ->
           case event do
             {:in, {:"$gen_call", _, {:attach_cleanup, owner, lease, guardian, bytes, d, token}}} ->
               send(host, {:cleanup_attachment, guardian, token, owner, lease, bytes, d})

             _ ->
               :ok
           end

           previous
         end, nil}
      )

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

    monitors = %{
      instance_monitor => %{pid: instance, role: :instance, reason: :normal, joined: false},
      owner_monitor => %{pid: transports, role: :transport_owner, reason: :normal, joined: false},
      old.custodian_monitor => %{
        pid: old.custodian,
        role: :custodian,
        reason: :normal,
        joined: false
      },
      input_monitor => %{pid: input, role: :input, reason: :normal, joined: false}
    }

    emit("ready", %{
      port: listen_port,
      mode: mode,
      upstream_protocol: to_string(protocol),
      endpoint: "Generation checked ManagedGenerationAccounting fixed T"
    })

    loop(%{
      instance: instance,
      transports: transports,
      store: store,
      candidates: %{old: old, new: new},
      peers: peers,
      trust_paths: paths,
      protocol: protocol,
      input: input,
      input_monitor: input_monitor,
      evidence: evidence,
      before: before,
      captures: 0,
      originals: [],
      receipts: [],
      active: nil,
      completed: %{},
      attachments: %{},
      monitors: monitors,
      owner_hook: owner_hook,
      cleanup_hook: cleanup_hook,
      mode: mode,
      gate: gate,
      cohort: cohort,
      cohort_monitor: cohort_monitor,
      telemetry: telemetry,
      telemetry_id: telemetry_id,
      spec: service_state.spec,
      service: service,
      backend: service_state.backend,
      listen_address: {{127, 0, 0, 1}, listen_port},
      native: nil,
      native_monitor: nil,
      connection: nil,
      connection_monitor: nil,
      writer: nil,
      writer_monitor: nil,
      target: nil,
      lease: nil,
      native_joined: false,
      connection_joined: false,
      writer_joined: false,
      session: nil,
      session_monitor: nil,
      session_joined: false,
      request_cleaned: false,
      browser_close_authorized: false
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

  # Registry retains authentic monitors across both serial navigations.
  def track(s, pid, role, reason) do
    case Enum.find(s.monitors, fn {_, entry} -> entry.pid == pid end) do
      {ref, entry} ->
        true = entry.reason === reason and not entry.joined
        {s, ref}

      nil ->
        true = Process.alive?(pid)
        ref = Process.monitor(pid)

        {%{
           s
           | monitors:
               Map.put(s.monitors, ref, %{pid: pid, role: role, reason: reason, joined: false})
         }, ref}
    end
  end

  def mark_joined(s, ref) do
    entry = Map.fetch!(s.monitors, ref)
    true = not entry.joined and not Process.alive?(entry.pid)
    %{s | monitors: Map.put(s.monitors, ref, %{entry | joined: true})}
  end

  def join_tracked(s, ref) do
    entry = Map.fetch!(s.monitors, ref)

    if entry.joined do
      true = not Process.alive?(entry.pid)
      s
    else
      receive do
        {:DOWN, ^ref, :process, pid, reason}
        when pid === entry.pid and reason === entry.reason ->
          mark_joined(s, ref)
      after
        5_000 -> raise "original actor exact terminal missing: #{inspect(entry.role)}"
      end
    end
  end

  def join_roles(s, roles) do
    Enum.reduce(s.monitors, s, fn {ref, entry}, acc ->
      if entry.role in roles, do: join_tracked(acc, ref), else: acc
    end)
  end

  def label!("old"), do: :old
  def label!("new"), do: :new

  def active!(s, label) do
    true = s.active != nil and s.active.label === label
    s.active
  end

  def loop(s) do
    receive do
      {:original, owner, batch, holder, op, d, status} ->
        true = owner === s.transports

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

      {:capture, label, native, token, exchange} ->
        true = s.active == nil

        true =
          (label == :old and s.captures == 0) or
            (label == :new and s.captures == 1 and Map.has_key?(s.completed, :old))

        candidate = Map.fetch!(s.candidates, label)
        {:ok, generation, router} = Generation.snapshot(s.store)
        true = generation === candidate.generation and router === candidate.router
        true = exchange.transport == if(s.mode == "h2", do: Gaoxy.HTTP.HTTP2.Transport, else: nil)
        originals = collect_originals(s.originals, 1)
        [original] = originals
        source_pin = Fixed.assert_source(candidate, s.store, native, exchange, original)

        true =
          Enum.filter(exchange.request.headers, fn {name, _} -> name == "proxy-authorization" end) ===
            []

        true =
          Enum.filter(exchange.request.headers, fn {name, _} -> name == "authorization" end) ===
            [{"authorization", "Bearer synthetic-origin-" <> to_string(label)}]

        retained = Exchange.retained_bytes(exchange) - exchange.route_bytes
        b = independent_b(retained)
        ^b = exchange.route_bytes

        {:ok, {:native_generation_capture_v1, @m, 65_536, 65_536, ^b}} =
          ManagedGenerationAccounting.reservation(
            @m,
            {s.store, native, exchange.gate, exchange.lease, :request, exchange.deadline,
             retained}
          )

        {_total, accounting, ids} = native_accounting(s.mode, native, exchange, retained, b, s)

        {s, native_monitor} =
          track(
            s,
            native,
            if(s.mode == "h2", do: :worker, else: :connection),
            if(s.mode == "h2", do: :normal, else: {:shutdown, :peer_closed})
          )

        {s, connection_monitor} = track(s, ids.connection, :connection, {:shutdown, :peer_closed})

        {s, writer_monitor} =
          if ids.writer, do: track(s, ids.writer, :writer, :normal), else: {s, nil}

        target =
          Map.merge(ids, %{
            lease: exchange.lease,
            deadline: exchange.deadline,
            bytes: retained + b,
            present: true
          })

        true = original.holder === native and original.deadline === exchange.deadline
        original_cuts = [validate_cut(original.status, s, target)]

        if not Enum.any?(s.receipts, fn {owner, pin} ->
             owner === candidate.owner and pin === source_pin
           end) do
          owner = candidate.owner

          receive do
            {:trace, ^owner, :send, {_tag, {:ok, pin}}, _} when pin === source_pin -> :ok
          after
            1_000 -> raise "actual original source public receipt missing"
          end
        end

        cut = Cohort.snapshot(s.cohort, exchange.gate)
        cut_evidence = validate_cut(cut, s, target)
        true = Map.fetch!(cut.leases, exchange.lease).bytes == retained + b

        File.write!(
          Path.join(s.evidence, "#{label}-capture-cohort.log"),
          inspect(cut, limit: :infinity)
        )

        emit("captured", %{
          label: label,
          mode: s.mode,
          holder: inspect(native),
          pins: [
            %{
              provider: to_string(source_pin.provider),
              kind: to_string(source_pin.kind),
              fields: map_size(source_pin),
              bytes: :erlang.external_size(source_pin),
              operation: inspect(source_pin.operation)
            }
          ],
          native_ids: Map.new(ids, fn {k, v} -> {k, inspect(v)} end),
          worker_accounting: accounting,
          retained: retained,
          reservation: b,
          gate_bytes: cut.bytes,
          cohort: cut_evidence,
          original_cohorts: original_cuts,
          original_owner_effects: length(originals),
          original_gate_bytes: Enum.map(originals, & &1.status.status.retained_bytes)
        })

        active = %{
          label: label,
          native: native,
          token: token,
          exchange: exchange,
          source_pin: source_pin,
          dispatched: false,
          returned: false,
          released: false,
          session: nil,
          session_monitor: nil,
          custody: nil,
          bound: nil
        }

        s = %{
          s
          | captures: s.captures + 1,
            active: active,
            originals: originals,
            native: native,
            native_monitor: native_monitor,
            connection: ids.connection,
            connection_monitor: connection_monitor,
            writer: ids.writer,
            writer_monitor: writer_monitor,
            target: target,
            lease: exchange.lease,
            native_joined: false,
            session: nil,
            session_monitor: nil,
            session_joined: false,
            request_cleaned: false
        }

        s =
          if label == :old do
            [new_ready] = Fixed.replace_slots([s.peers["new"]], s.trust_paths)

            prepared =
              Fixed.prepare_candidate(s.transports, s.store, new_ready, s.protocol, self(), :new)

            s = %{
              s
              | monitors:
                  Map.put(s.monitors, prepared.custodian_monitor, %{
                    pid: prepared.custodian,
                    role: :custodian,
                    reason: :normal,
                    joined: false
                  })
            }

            new =
              Fixed.cas_while_captured(
                s.store,
                s.instance,
                candidate,
                prepared,
                native,
                source_pin
              )

            :ok = Fixed.assert_rotation(candidate, new)

            emit("cas", %{
              old_admission_closed: true,
              old_source_alive: true,
              old_custodian_alive: true,
              fresh_old_denied: true,
              snapshot_changed: true,
              preparation_released_by_holder: true
            })

            %{s | candidates: Map.put(s.candidates, :new, new)}
          else
            s
          end

        loop(s)

      {:command, %{"op" => "dispatch", "label" => label}} ->
        a = active!(s, label!(label))
        true = not a.dispatched
        c = Map.fetch!(s.candidates, a.label)

        for i <- c.identities do
          true = Fixed.retained_policy(c.owner, i.transport, i.source) === i.policy
          [] = i.trust.path |> Fixed.public_pem() |> :public_key.pem_decode()
        end

        send(a.native, {:dispatch, a.token})
        loop(%{s | active: %{a | dispatched: true}})

      {:trace, owner, :send, {_tag, {:ok, %{provider: T, kind: :request} = pin}}, _}
      when owner == s.transports ->
        if s.active == nil or pin.holder == s.active.native do
          true = length(s.receipts) < 1
          loop(%{s | receipts: s.receipts ++ [{owner, pin}]})
        else
          a = s.active
          true = a.dispatched and a.session == nil
          candidate = Map.fetch!(s.candidates, a.label)
          hold = Map.fetch!(:sys.get_state(owner, 1_000).pins, pin.ref)
          true = hold.public === pin and hold.derived and hold.acquirer === a.native
          true = hold.source_ref === a.source_pin.ref and pin.handles === [candidate.transport]
          session = pin.holder
          {s, monitor} = track(s, session, :session, :normal)

          {s, {cleanup_token, attachment_owner, attachment_lease, bytes, d}} =
            cleanup_attachment(s, session)

          cleanup = Map.fetch!(:sys.get_state(s.gate, 1_000).cleanups, cleanup_token)
          true = attachment_owner === a.native and attachment_lease === a.exchange.lease
          true = cleanup.lease === attachment_lease and cleanup.bytes === bytes
          true = bytes > 0 and Lifecycle.remaining(d) > 0
          true = Admission.status(s.gate).cleanup_pending == 1

          custody = %{
            label: a.label,
            native: inspect(a.native),
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

          loop(%{
            s
            | active: %{a | session: session, session_monitor: monitor, custody: custody},
              session: session,
              session_monitor: monitor
          })
        end

      {:cleanup_attachment, session, token, owner, lease, bytes, d} ->
        true = not Map.has_key?(s.attachments, session)
        loop(%{s | attachments: Map.put(s.attachments, session, {token, owner, lease, bytes, d})})

      {:command, %{"op" => "prove_bound", "label" => label}} ->
        a = active!(s, label!(label))
        true = a.dispatched and a.bound == nil and a.session != nil

        bound =
          Fixed.bound(
            Map.fetch!(s.candidates, a.label),
            a.source_pin,
            a.native,
            a.session,
            a.session_monitor
          )

        emit("bound", %{
          label: a.label,
          session: inspect(a.session),
          original_completion_equal: true,
          pending: true,
          source_genuine: true,
          child_genuine: true,
          token_genuine: true
        })

        loop(%{s | active: %{a | bound: bound}})

      {:returned, label, native, ref, _original_result} ->
        a = active!(s, label)
        true = a.native === native and a.token === ref and a.bound != nil and not a.returned
        joined = Map.fetch!(s.monitors, a.session_monitor).joined

        Fixed.assert_returned_source_held(
          Map.fetch!(s.candidates, label),
          native,
          Map.put(a.bound, :session_joined, joined)
        )

        s = if joined, do: s, else: mark_joined(s, a.session_monitor)

        emit("returned_source_held", %{
          label: label,
          original_completion_ok: true,
          session_joined: true,
          child_gone: true,
          token_gone: true,
          source_genuine: true,
          custodian_alive: true,
          retirement_requested: false
        })

        loop(%{s | active: %{a | returned: true}, session_joined: true})

      {:command, %{"op" => "release_return", "label" => label}} ->
        a = active!(s, label!(label))
        true = a.returned and not a.released
        send(a.native, {:return, a.token})

        s =
          if a.label == :old do
            Fixed.retired(s.candidates.old, a.source_pin)
            s = mark_joined(s, s.candidates.old.custodian_monitor)

            emit("old_retired", %{
              source_gone: true,
              record_gone: true,
              custodian_normal_down: true
            })

            s
          else
            s
          end

        loop(%{s | active: %{a | released: true}})

      {:command, %{"op" => "request_clean", "label" => label}} ->
        a = active!(s, label!(label))
        true = a.released and a.returned
        s = request_clean(s)

        emit("request_clean", %{
          label: a.label,
          session_joined: true,
          original_source_gone: true,
          custody: a.custody,
          native_worker_joined: s.mode == "h2",
          complete_cohort_validated: true,
          connection_alive: true
        })

        loop(%{
          s
          | active: nil,
            originals: [],
            receipts: [],
            completed: Map.put(s.completed, a.label, a),
            request_cleaned: true
        })

      {:command, %{"op" => "authorize_browser_close"}} ->
        true = s.active == nil and map_size(s.completed) == 2 and not s.browser_close_authorized
        cut = Cohort.snapshot(s.cohort, s.gate)
        validate_cut(cut, s, clean_target(s))
        assert_target_live(cut, s.connection, s.writer)
        {_socket, state} = :sys.get_state(s.connection, 1_000)

        if s.mode == "h2" do
          true =
            state.phase == :http2 and not state.closing and
              not state.draining and not state.close_after_write
        else
          true = state.phase == :idle and state.buffer == ""
        end

        emit("browser_close_authorized", %{
          mode: s.mode,
          connection: inspect(s.connection),
          connection_alive: true
        })

        loop(%{s | browser_close_authorized: true})

      {:command, %{"op" => "stop"}} ->
        true = s.browser_close_authorized and s.request_cleaned and map_size(s.completed) == 2
        finish(s)

      {:DOWN, ref, :process, pid, reason} ->
        entry = Map.fetch!(s.monitors, ref)

        emit("down_diagnostic", %{
          monitor: inspect(ref),
          role: Atom.to_string(entry.role),
          expected_pid: inspect(entry.pid),
          actual_pid: inspect(pid),
          pid_equal: entry.pid === pid,
          reason_equal: entry.reason === reason,
          expected_reason: diagnostic_reason(entry.reason),
          actual_reason: diagnostic_reason(reason)
        })

        true = entry.pid === pid and entry.reason === reason
        loop(mark_joined(s, ref))

      {:trace, _, :send, _, _} ->
        loop(s)

      {:cohort_trace, observer, fact} when observer == s.cohort ->
        File.write!(Path.join(s.evidence, "causal-metadata.log"), inspect(fact) <> "\n", [:append])

        loop(s)

      {:EXIT, _, :normal} ->
        loop(s)

      :input_eof ->
        raise "stdin closed before stop"

      other ->
        raise "unexpected fixed host message: #{inspect(other)}"
    after
      30_000 -> raise "fixed host command/capture deadline"
    end
  end

  def cleanup_attachment(s, session) do
    case Map.fetch(s.attachments, session) do
      {:ok, attachment} ->
        {s, attachment}

      :error ->
        receive do
          {:cleanup_attachment, ^session, token, owner, lease, bytes, d} ->
            attachment = {token, owner, lease, bytes, d}
            {%{s | attachments: Map.put(s.attachments, session, attachment)}, attachment}
        after
          1_000 -> raise "actual Service cleanup attachment missing"
        end
    end
  end

  def request_clean(s) do
    a = s.active
    candidate = Map.fetch!(s.candidates, a.label)

    wait_until(
      fn ->
        owner = :sys.get_state(s.transports, 1_000)

        not Map.has_key?(owner.pins, a.source_pin.ref) and
          not Enum.any?(owner.tokens, fn {_, t} -> t.resource === candidate.transport.resource end) and
          match?(
            {:ok, %{resources: 1, pins: 1, request_tokens: 0, helpers: 0}},
            T.status(s.transports)
          ) and
          if a.label == :old,
            do: not Map.has_key?(owner.records, candidate.transport.resource),
            else: Fixed.configured_pins(candidate) == [:baseline]
      end,
      deadline()
    )

    wait_until(fn -> Admission.status(s.gate).cleanup_pending == 0 end, deadline())
    s = join_tracked(s, a.session_monitor)
    s = if s.mode == "h2", do: join_tracked(s, s.native_monitor), else: s

    wait_until(
      fn ->
        cut = Cohort.snapshot(s.cohort, s.gate)

        if s.mode == "h2" do
          not Map.has_key?(cut.leases, s.lease) and cut.spawns == %{} and cut.cleanups == %{}
        else
          Map.fetch!(cut.leases, s.lease).bytes == 0 and cut.cleanups == %{}
        end
      end,
      deadline()
    )

    cut = Cohort.snapshot(s.cohort, s.gate)
    validate_cut(cut, s, clean_target(s))
    assert_target_live(cut, s.connection, s.writer)

    if s.mode == "h1" do
      {_socket, idle} = :sys.get_state(s.connection, 1_000)
      true = idle.phase == :idle and idle.buffer == "" and idle.deadline == nil
      true = idle.lease === s.lease and idle.gate === s.gate
    end

    File.write!(
      Path.join(s.evidence, "#{a.label}-request-clean-cohort.log"),
      inspect(cut, limit: :infinity)
    )

    %{s | session_joined: true, native_joined: s.mode == "h2"}
  end

  def finish(s) do
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

    s = join_roles(s, [:connection, :worker, :writer, :session])
    final = Cohort.snapshot(s.cohort, s.gate)
    validate_cut(final, s, %{s.target | present: false})
    joins = validate_terminals(final, s)
    File.write!(Path.join(s.evidence, "final-cohort.log"), inspect(final, limit: :infinity))
    :ok = :telemetry.detach(s.telemetry_id)
    true = :ets.delete(s.telemetry)
    :ok = :sys.remove(s.gate, s.cleanup_hook)
    :ok = Cohort.stop(s.cohort, s.gate)
    observer_ref = s.cohort_monitor
    observer = s.cohort

    receive do
      {:DOWN, ^observer_ref, :process, ^observer, :normal} -> :ok
    after
      1_000 -> raise "original cohort observer normal DOWN missing"
    end

    emit("closed_browser_clean", %{
      cohort_joins: joins,
      observer_joined: true,
      connection_joined: true,
      connection_reason: inspect({:shutdown, :peer_closed}),
      service:
        Map.take(
          Gaoxy.status(s.instance, :http),
          [:active, :retained_bytes, :cleanup_pending, :cleanup_failed]
        )
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

    s = join_roles(s, [:custodian])
    :ok = :sys.remove(s.transports, s.owner_hook)
    1 = :erlang.trace(s.transports, false, [:send])
    :ok = Gaoxy.stop(s.instance, 10_000)
    s = join_roles(s, [:transport_owner, :instance])
    Fixed.rebind(s.listen_address)
    after_identity = identity()
    true = s.before === after_identity
    File.write!(Path.join(s.evidence, "host-loaded-after.json"), JSON.encode!(after_identity))

    emit("stopped", %{
      cleanup_confirmed: true,
      source_stable: true,
      captures: s.captures,
      mode: s.mode,
      sessions_joined: map_size(s.completed),
      native_actors_joined: true,
      custodians_normal_down: 2,
      owner_normal_down: true,
      instance_normal_down: true,
      listener_rebound: true
    })

    receive do
      {:command, %{"op" => "exit"}} -> :ok
    after
      10_000 -> raise "host exit command deadline"
    end

    _s = join_tracked(s, s.input_monitor)
    emit("exited")
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

[manifest, evidence, mode, certificates, upstream] = System.argv()
true = mode in ["h2", "h1"]

protocol =
  case upstream do
    "http2" -> :http2
  end

try do
  NativeWorkerBrowserHost.run(manifest, evidence, mode, certificates, protocol)
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
