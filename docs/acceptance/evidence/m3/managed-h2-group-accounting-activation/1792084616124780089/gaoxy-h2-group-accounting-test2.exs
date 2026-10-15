defmodule Gaoxy.Proxy.ManagedH2GroupAccountingTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{GroupEndpoint, ManagedH2Client, ManagedH2Envelope, ManagedH2GroupBoundary}
  alias Gaoxy.Proxy.{ManagedH2Preparation, ManagedH2Reservation, UpstreamGroups, UpstreamTransports}
  alias Gaoxy.Proxy.HTTP.Session
  alias Gaoxy.Proxy.UpstreamGroups.{Options, Probe}
  alias Gaoxy.HTTP.{Exchange, Request, Resources}

  @accounting Gaoxy.Proxy.ManagedH2GroupAccounting
  @invalid {:error, :invalid_group_accounting}
  @capacity {:error, :group_accounting_capacity}
  @min -9_223_372_036_854_775_808
  @max 9_223_372_036_854_775_807
  @caps %{
    p: 1_048_576, s: 2_359_296, l: 196_608, n: 205_337, k: 1_183_744,
    x: 131_072, r: 205_337, o: 1_572_864, a: 786_432, w: 851_968,
    i: 393_216, u: 8_192, e: 131_072
  }
  @phases %{
    startup: {[p: 1, a: 1, w: 1, a: 1, s: 1, e: 1], 5_963_776},
    selected: {[p: 1, s: 1, l: 1, i: 1, k: 1, e: 1], 5_312_512},
    boundary: {[p: 1, s: 1, l: 1, n: 1, k: 1, x: 1, r: 1, o: 1, e: 1], 7_033_906},
    open: {[p: 1, s: 1, o: 1, u: 1, i: 1, e: 1], 5_513_216},
    streaming: {[p: 1, s: 1, e: 1], 3_538_944},
    cleanup: {[p: 1, s: 1, i: 1, e: 1], 3_932_160}
  }
  @session_keys ~w(owner service instance gate started_at deadline config selector
    transport_handoff request_options monitors client cleanup_deadline cleanup_requested_deadline
    cleanup_started opening_timer activated_at opening_deadline total_timer selection
    awaiting_transport transport_pins transport_selection managed_transport managed_path submitted_url
    poll_timer original_request outcome token request headers delivery trailers cancelled consumed)a
  @probe_keys ~w(owner token member deadline health url group cleanup_deadline owner_monitor timer
    request original_request managed_transport transport_selection transport_pins terminal cancelled
    headers outcome client limits request_options submitted_url)a
  @fixed_families ~w(activate cleanup_cancel handoff down timer cast acknowledge task data trailers
    stream_end stream_error ready handoff_request delivery drain)a

  # These are structural source-constructor fixtures. self()/make_ref() establish
  # actual public scalar shapes, never an owner admission, pin or completion right.
  # Public owner/probe/Service effects and real protocol acceptance live in their
  # dedicated integration suites, not in simulated successful replies here.

  test "contract preserves the fixed ledger and contains every original role" do
    c = call(:contract)
    assert c.version == 1
    assert c.unit == :external_term_payload_bytes
    assert c.role_caps == @caps
    assert c.fixed_bytes == 9_444_956
    assert c.group_bytes == 7_033_906
    assert c.reservation_bytes == 16_478_862
    assert c.startup_bytes == 5_963_776
    assert c.config_growth_bytes == 131_072
    assert c.group_record_cap == 12_582_912
    assert c.control_total_cap == 16_777_216
    assert c.control_record_caps == %{pin: 196_608, selection: 32_768, probe: 32_768}
    assert Map.keys(c.phases) |> Enum.sort() == Map.keys(@phases) |> Enum.sort()
    assert ManagedH2Reservation.activation_contract().reservation_per_request == 9_444_956
    assert call(:reservation_bytes) == 16_478_862
    assert call(:startup_bytes) == 5_963_776
  end

  for {phase, {roles, total}} <- @phases do
    test "#{phase} charges every containing source role with its prescribed multiplicity" do
      roles = unquote(Macro.escape(roles))
      total = unquote(total)
      assert Enum.reduce(roles, 0, fn {role, count}, acc -> acc + @caps[role] * count end) == total
      assert {:ok, %{roles: ^roles, bytes: ^total}} = call(:phase, [unquote(phase)])
      assert call(:contract).phases[unquote(phase)] == %{roles: roles, bytes: total}
    end
  end

  test "maximum and full request/probe/startup-overlap totals have no optional discounts" do
    maximum = @phases |> Map.values() |> Enum.map(&elem(&1, 1)) |> Enum.max()
    assert maximum == 7_033_906
    assert maximum + 9_444_956 == call(:reservation_bytes)
    assert 32 * call(:reservation_bytes) == 527_323_584
    assert 4 * call(:reservation_bytes) == 65_915_448
    assert call(:startup_bytes) + call(:reservation_bytes) == 22_442_638
    assert 32 * (call(:startup_bytes) + call(:reservation_bytes)) == 718_164_416
    assert 16 * 2_048 + 4 * 24_576 == @caps.e
    assert @invalid == call(:phase, [:unknown])
  end

  for protocol <- [:http2, :h2c] do
    test "#{protocol} complete L N K X R O roots preserve original containing values" do
      f = fixture(unquote(protocol))
      for {selector, original, role} <- [
            {:selected, f.member, :l}, {:neutral, f.neutral, :n}, {:context, f.context, :x},
            {:request, f.options.request, :r}
          ] do
        receipt = accepted(selector, original, role)
        assert receipt.projection === original
      end
      k = accepted(:checked, f.checked, :k)
      assert k.projection.policy === f.checked.policy
      assert k.projection.fetch_options === f.checked.fetch_options
      assert k.projection.transport_scope == {:opaque, HTTP.ManagedTransport}
      o = accepted(:options, f.options, :o)
      assert o.projection.request === f.options.request
      assert o.projection.managed_transport === k.projection
      assert Map.keys(o.projection) |> Enum.sort() == Map.keys(f.options) |> Enum.sort()
      for key <- [:timeout, :opening_timeout, :write_timeout, :deadline, :opening_deadline],
        do: assert(o.projection[key] === f.options[key])
    end

    test "#{protocol} original target escaping and absent or empty query survive complete R/O" do
      f = fixture(unquote(protocol))
      for target <- ["/a", "/a?", "/a??x", "/a%2fb%2F?x=%2f", "//other.test/a?", "///a"] do
        neutral = %{f.neutral | target: target}
        {:ok, options, _} = ManagedH2GroupBoundary.prepare(f.member, neutral, f.checked, f.context)
        assert accepted(:neutral, neutral, :n).projection === neutral
        assert accepted(:options, options, :o).projection.request.url == root(f.member.config) <> target
        expected_query = if String.contains?(target, "?"), do: String.split(target, "?", parts: 2) |> List.last(), else: nil
        assert URI.parse(options.request.url).query === expected_query
      end
    end

    test "#{protocol} actual maximum group root and target fit all complete boundary roles" do
      f = maximal_fixture(unquote(protocol))
      assert byte_size(root(f.member.config)) == 8_192
      assert byte_size(f.neutral.target) == 57_344
      assert f.neutral.fields == []
      assert byte_size(f.options.request.url) == 65_536
      assert :ok == ManagedH2Envelope.validate_config(f.member.config)
      assert :ok == ManagedH2Envelope.validate_group_source(f.neutral)
      assert :ok == ManagedH2Envelope.validate_request(f.options.request)
      for {selector, original, role} <- [
            {:selected, f.member, :l}, {:neutral, f.neutral, :n}, {:checked, f.checked, :k},
            {:context, f.context, :x}, {:request, f.options.request, :r}, {:options, f.options, :o}
          ], do: accepted(selector, original, role)
    end
  end

  test "neutral max256 and65536 bytes and actual prepared effective256 are separate admitted maxima" do
    f = fixture()
    fields = List.duplicate({"x", ""}, 255) ++ [{"x", :binary.copy("v", 65_280)}]
    neutral = %{f.neutral | fields: fields}
    assert :ok == ManagedH2Envelope.validate_group_source(neutral)
    assert length(fields) == 256
    assert Enum.sum(Enum.map(fields, fn {a, b} -> byte_size(a) + byte_size(b) end)) == 65_536
    assert accepted(:neutral, neutral, :n).projection === neutral
    # Four pseudo-fields are part of the effective256/65536 request bound.
    # Include user-agent explicitly so canonical preparation adds no field.
    target = "/"
    pseudo = [{":method", "POST"}, {":scheme", "https"}, {":authority", "upstream.test"}, {":path", target}]
    fixed = Enum.sum(Enum.map(pseudo, fn {a, b} -> byte_size(a) + byte_size(b) + 32 end))
    empty = List.duplicate({"x", ""}, 251)
    value_bytes = 65_536 - fixed - 251 * 33 - 32 - byte_size("user-agent")
    source = %{f.neutral | target: target, fields: empty ++ [{"user-agent", :binary.copy("v", value_bytes)}]}
    assert {:ok, options, _} = ManagedH2GroupBoundary.prepare(f.member, source, f.checked, f.context)
    assert :ok == ManagedH2Envelope.validate_request(options.request)
    assert length(options.request.fields) + 4 == 256
    accepted(:neutral, source, :n)
    accepted(:request, options.request, :r)
    accepted(:options, options, :o)
  end

  test "complete C may reach its65536 raw URL bound before group-specific root association" do
    f = fixture()
    c = config(:http2, f.transport, long_origin(:http2, 65_536))
    assert byte_size(root(c)) == 65_536
    assert :ok == ManagedH2Envelope.validate_config(c)
    member = %{f.member | config: c}
    assert accepted(:selected, member, :l).projection === member
    # The group boundary's independent8192 raw-root gate remains authoritative.
    assert {:error, :invalid_group_opening} == ManagedH2GroupBoundary.prepare(member, f.neutral, f.checked, f.context)
  end

  test "full checked policy supports 128 bounded trust values and projects only scope interior" do
    f = fixture()
    checked = checked(:http2, root(f.member.config), List.duplicate(:binary.copy("a", 8_100), 128))
    assert :ok == ManagedH2Envelope.validate_checked_client(checked, :http2)
    r = accepted(:checked, checked, :k)
    assert r.bytes > 1_000_000
    assert r.projection.policy === checked.policy
    assert r.projection.fetch_options === checked.fetch_options
    assert r.projection.transport_scope === {:opaque, HTTP.ManagedTransport}
  end

  test "opaque interiors never enter retained ETF while their exact public shells are required" do
    f = fixture()
    sentinel = fn -> raise "opaque interior must never be invoked or serialized" end
    scope = Map.new(Map.to_list(f.checked.transport_scope), fn
      {:__struct__, module} -> {:__struct__, module}
      {key, _} -> {key, sentinel}
    end)
    original = %{f.checked | transport_scope: scope}
    a = accepted(:checked, original, :k)
    b = accepted(:checked, f.checked, :k)
    assert a.projection === b.projection
    assert a.bytes == b.bytes
    completion = %HTTP.RequestCompletion{tracker: sentinel, latch: sentinel, unsupported: sentinel}
    h = handle(completion)
    u = accepted(:open_result, {:ok, h, nil}, :u)
    assert u.projection == {:ok, safe_handle(h), nil}
    assert accepted({:args, :recovery}, recovery_args(completion), :a).projection.completion == {:opaque, HTTP.RequestCompletion}
    invalid(:checked, %{original | transport_scope: Map.put(scope, :extra, sentinel)})
    invalid(:open_result, {:ok, %{h | completion: Map.put(completion, :extra, sentinel)}, nil})
  end

  test "closed dispatch and unknown fields reject without retaining diagnostic payload" do
    f = fixture()
    assert @invalid == call(:project, [:unknown, fn -> :never end])
    for {selector, original} <- roots(f) do
      assert is_map(original)
      invalid(selector, Map.put(original, :unrecognized, fn -> :never end))
      for key <- Map.keys(original), do: invalid(selector, Map.delete(original, key))
    end
    for selector <- [nil, [], {:state, :unknown}, {:args, :unknown}, {:control, :unknown}, {:caller, String}],
      do: invalid(selector, %{})
  end

  test "bad list count tail and backing fail before an original can become a sized role" do
    f = fixture()
    for fields <- [[{"x", "v"} | :improper], List.duplicate({"x", "v"}, 257), [{"x", :binary.copy("v", 65_536)}]] do
      invalid(:neutral, %{f.neutral | fields: fields})
    end
    for target <- ["", "relative", "/%", "/#fragment", "/bad space", :binary.copy("/", 65_537), slice("/valid", 65_537)] do
      invalid(:neutral, %{f.neutral | target: target})
    end
    invalid(:neutral, %{f.neutral | fields: [{"x", slice(:binary.copy("v", 100), 65_537)}]})
    invalid(:selected, %{f.member | id: slice(:binary.copy("m", 100), 65_537)})
    invalid(:group_handle, %{f.group | transports: [f.transport | :improper]})
    invalid(:group_handle, %{f.group | transports: List.duplicate(f.transport, 33)})
    invalid(:group_handle, %{f.group | transports: [f.transport, f.transport]})
  end

  test "signed64 and finite elapsed-budget limits are checked before arithmetic" do
    f = fixture()
    for {now, total, opening} <- [{@min, 86_400_000, 1}, {@max - 1_001, 1, 1}, {-100, 1, 1}] do
      x = %{f.context | now: now, deadline: now + total, opening_deadline: now + opening}
      accepted(:context, x, :x)
    end
    for key <- [:now, :deadline, :opening_deadline], value <- [@min - 1, @max + 1, nil, :infinity, 1.0],
      do: invalid(:context, Map.put(f.context, key, value))
    for change <- [%{opening_deadline: f.context.now}, %{opening_deadline: f.context.deadline + 1},
                   %{deadline: @max}, %{deadline: f.context.now + 86_400_001}],
      do: invalid(:context, Map.merge(f.context, change))
    for key <- [:timeout, :opening_timeout, :write_timeout], value <- [0, 86_400_001, :infinity],
      do: invalid(:options, Map.put(f.options, key, value))
  end

  test "options validate original checked protocol authority and request identity together" do
    f = fixture()
    for bad <- [checked(:h2c, "http://upstream.test"), checked(:http2, "https://other.test"),
                checked(:http2, "https://upstream.test:444")],
      do: invalid(:options, %{f.options | managed_transport: bad})
    invalid(:options, %{f.options | opening_deadline: f.options.deadline + 1})
    invalid(:options, %{f.options | request: Map.put(f.options.request, :extra, nil)})
    invalid(:context, %{f.context | group: %{f.group | execution_profile: :http1}})
    invalid(:group_handle, %{f.group | owner: make_ref()})
    invalid(:group_handle, %{f.group | owner_epoch: self()})
  end

  test "Session args10 and complete initial state36 retain all matching G pins" do
    f = fixture()
    pins = [group_pin(f.group), group_pin(other_group(f.transport))]
    args = session_args(f, pins)
    assert map_size(args) == 10
    a = accepted({:args, :session}, args, :a)
    assert a.projection === args
    s = session_state(args)
    assert map_size(s) == 36
    assert Enum.sort(Map.keys(s)) == Enum.sort(@session_keys)
    r = accepted({:state, :session}, s, :s)
    assert r.projection.config === args.config
    assert r.projection.selector === {:group, f.group, pins}
    assert r.projection.request_options === f.neutral
    assert r.projection.monitors === s.monitors
  end

  test "Session three-H awaiting and checked alternatives charge original aliases" do
    f = maximal_fixture()
    initial = session_state(session_args(f, [group_pin(f.group)]))
    selected = %{initial | selection: {f.group, make_ref()}, token: make_ref(), activated_at: 10_000,
      opening_deadline: 12_000, opening_timer: make_ref(), total_timer: make_ref()}
    awaiting = %{selected | awaiting_transport: %{handle: f.transport, member: f.member}}
    r = accepted({:state, :session}, awaiting, :s)
    assert r.projection.config.group === f.group
    assert elem(r.projection.selector, 1) === f.group
    assert elem(r.projection.selection, 0) === f.group
    assert r.projection.awaiting_transport === awaiting.awaiting_transport
    checked_state = %{selected | managed_transport: f.checked,
      transport_selection: {f.transport, make_ref()}, transport_pins: [transport_pin(f.transport)]}
    k = accepted({:state, :session}, checked_state, :s)
    assert k.projection.managed_transport.policy === f.checked.policy
    assert k.projection.managed_transport.transport_scope == {:opaque, HTTP.ManagedTransport}
    assert k.projection.transport_pins === checked_state.transport_pins
    mismatch = %{f.group | generation: make_ref()}
    invalid({:state, :session}, %{awaiting | selector: {:group, mismatch, elem(awaiting.selector, 2)}})
    invalid({:state, :session}, %{awaiting | awaiting_transport: %{handle: other_transport(), member: f.member}})
  end

  test "Session staged then submitted cleanup alternatives preserve ledgers and known controls" do
    f = fixture()
    s = active_session(f)
    staged = %{Session.drop_group_opening(s) | config: %{limits: f.member.config.limits},
      request_options: {:group_prepared, f.options}}
    r = accepted({:state, :session}, staged, :s)
    assert r.projection.request_options == {:group_prepared, accepted(:options, f.options, :o).projection}
    assert r.projection.selector == nil
    assert r.projection.selection === s.selection
    h = handle()
    submitted = %{Session.drop_group_opening(staged) | request: h, original_request: h,
      submitted_url: f.options.request.url, headers: true, delivery: make_ref(), trailers: [{"x-end", "yes"}]}
    result = accepted({:state, :session}, submitted, :s)
    assert result.projection.request === safe_handle(h)
    assert result.projection.original_request === safe_handle(h)
    assert result.projection.transport_selection === submitted.transport_selection
    assert result.projection.transport_pins === submitted.transport_pins
    assert result.projection.submitted_url == {:slot, :session_request_url}
    assert result.projection.trailers == {:slot, :terminal_trailer_lists}
    cleanup = %{submitted | cleanup_started: true, cleanup_deadline: 21_000,
      cleanup_requested_deadline: 21_000, cancelled: true, consumed: true}
    accepted({:state, :session}, cleanup, :s)
    invalid({:state, :session}, Map.put(cleanup, :raw_reason, fn -> :unbounded end))
    invalid({:state, :session}, %{cleanup | outcome: %{raw: :reason}})
    invalid({:state, :session}, %{cleanup | monitors: Map.new(1..5, fn _ -> {make_ref(), self()} end)})
  end

  test "normal Probe args7 state23 and recovery args4 state5 use distinct exact constructors" do
    f = fixture()
    args = probe_args(f)
    assert {:ok, ^args} = UpstreamGroups.probe_start_arguments(args)
    assert accepted({:args, :probe}, args, :a).projection === args
    state = probe_state(args)
    assert map_size(state) == 23
    assert Enum.sort(Map.keys(state)) == Enum.sort(@probe_keys)
    accepted({:state, :probe}, state, :s)
    recover = recovery_args()
    assert {:ok, ^recover} = UpstreamGroups.probe_recovery_arguments(recover)
    assert map_size(recover) == 4
    recovered = Map.put(recover, :owner_monitor, make_ref())
    assert map_size(recovered) == 5
    accepted({:args, :recovery}, recover, :a)
    accepted({:state, :recovery}, recovered, :s)
    invalid({:state, :probe}, recovered)
    invalid({:state, :recovery}, state)
    invalid({:args, :probe}, Map.delete(args, :group))
    invalid({:args, :recovery}, Map.put(recover, :group, f.group))
  end

  test "Probe staged checked and cleanup roots keep transport holds and original completions" do
    f = maximal_fixture()
    state = %{probe_state(probe_args(f)) | managed_transport: f.checked,
      transport_selection: {f.transport, make_ref()}, transport_pins: [transport_pin(f.transport)]}
    r = accepted({:state, :probe}, state, :s)
    assert r.projection.member === state.member
    assert r.projection.group === state.group
    assert r.projection.managed_transport.policy === f.checked.policy
    assert {:ok, staged, :group_open} = Probe.prepare_group_open(state, self(), 19_000)
    accepted({:state, :probe}, staged, :s)
    h = handle()
    result = %{Probe.drop_group_opening(staged) | request: h, original_request: h,
      submitted_url: f.options.request.url, terminal: true, cancelled: true}
    projected = accepted({:state, :probe}, result, :s).projection
    assert projected.request === safe_handle(h)
    assert projected.transport_pins === result.transport_pins
    invalid({:state, :probe}, %{result | cleanup_deadline: @max + 1})
  end

  for mode <- [:session, :probe, :recovery] do
    test "#{mode} startup accounts caller wrapper and supported public supervisor W" do
      f = fixture()
      {module, args} = startup_fixture(unquote(mode), f)
      caller = {module, args}
      a = accepted({:caller, module}, caller, :a)
      assert {:ok, result} = call(:startup, [module, args])
      assert result == %{argument_bytes: a.bytes, request_bound_bytes: a.bytes + 65_536}
      assert result.request_bound_bytes <= @caps.w
      normalized = {{module, :start_link, [args]}, :temporary, 5_000, :worker, [module]}
      public = {:"$gen_call", {self(), make_ref()}, {:start_child, normalized}}
      w = accepted({:supervisor, module}, public, :w)
      assert w.bytes <= result.request_bound_bytes
      invalid({:supervisor, module}, {:"$gen_call", {self(), make_ref()}, {:start_child, Tuple.append(normalized, :extra)}})
      assert @invalid == call(:startup, [String, args])
    end
  end

  test "pending pump has exact13 keys and genuine future scalar identities remain absent before effects" do
    f = fixture()
    pins = [group_pin(f.group), transport_pin(f.transport)]
    started = pump(f, pins)
    pending = %{started | session: nil, monitor: nil}
    assert map_size(pending) == 13
    assert Enum.sort(Map.keys(pending)) == Enum.sort(~w(exchange config client policy response_policy session monitor deadline transport_handoff upload ready upload_stopped last_activity)a)
    projected = accepted(:pump, pending, :p).projection
    assert projected.session == nil and projected.monitor == nil
    assert projected.exchange.resource_pins === pins
    assert projected.config === started.config
    assert projected.transport_handoff === started.transport_handoff
    accepted(:pump, started, :p)
    invalid(:pump, %{pending | session: self()})
    invalid(:pump, %{pending | monitor: make_ref()})
    invalid(:pump, Map.put(pending, :future_monitor, make_ref()))
  end

  test "full64 resource router capture keeps unrelated routes with only33 own H/T dependencies" do
    f = fixture()
    unrelated = for _ <- 1..62, do: %{f.transport | resource: make_ref()}
    manifest = [f.group, f.transport | unrelated]
    assert length(manifest) == 64
    assert {:ok, ^manifest} = Resources.validate(manifest)
    all_t = [f.transport | unrelated]
    pins = [group_pin(f.group), transport_pin(f.transport, all_t)]
    assert Gaoxy.Proxy.HTTP.captured_resources?(pins, [f.group, f.transport])
    assert :erlang.external_size(pins) <= 65_536
    projected = accepted(:captured_pins, pins, :i).projection
    assert projected === pins
    p = pump(f, pins)
    result = accepted(:pump, p, :p).projection
    assert result.exchange.resource_pins === pins
    assert result.transport_handoff.handles === f.group.transports
    assert result.transport_handoff.source_pins === [List.last(pins)]
    assert result.config === p.config
  end

  test "nested Generation captures may repeat64-resource batches without a global unique-handle cap" do
    f = fixture()
    batch = fn ->
      ts = [f.transport | for(_ <- 1..62, do: %{f.transport | resource: make_ref()})]
      [group_pin(f.group), transport_pin(f.transport, ts)]
    end
    pins = batch.() ++ batch.()
    unique = pins |> Enum.flat_map(& &1.handles) |> Enum.uniq()
    assert length(unique) > 64
    assert length(pins) == 4
    assert :erlang.external_size(pins) < 65_536
    assert Gaoxy.Proxy.HTTP.captured_resources?(pins, [f.group, f.transport])
    assert accepted(:captured_pins, pins, :i).projection === pins
    p = pump(f, pins)
    assert accepted(:pump, p, :p).projection.exchange.resource_pins === pins
    g_pins = Enum.filter(pins, &(&1.provider == UpstreamGroups))
    assert accepted({:args, :session}, session_args(f, g_pins), :a).projection.selector === {:group, f.group, g_pins}
  end

  test "G7 has no invented public holder T8 keeps original holder and both reject expansion" do
    f = fixture()
    g = group_pin(f.group)
    t = transport_pin(f.transport)
    assert map_size(g) == 7 and not Map.has_key?(g, :holder)
    assert map_size(t) == 8 and t.holder === self()
    assert accepted(:captured_pins, [g, t], :i).projection === [g, t]
    invalid(:captured_pins, [Map.put(g, :holder, self()), t])
    invalid(:captured_pins, [g, Map.delete(t, :holder)])
    invalid(:captured_pins, [g, %{t | owner_epoch: self()}])
    invalid(:captured_pins, [g, %{t | owner: make_ref()}])
    invalid(:captured_pins, [g, %{t | operation: self()}])
    invalid(:captured_pins, [g, %{t | handles: [%{f.transport | owner_epoch: make_ref()}]}])
    invalid(:captured_pins, [g | :improper])
    invalid(:captured_pins, List.duplicate(g, 65))
  end

  test "unrelated existing H1 G6/G7 captures keep accepted backing and original data" do
    f = fixture()
    h1 = %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(),
      group: slice(:binary.copy("h", 128), 1_048_576), generation: make_ref(), max_url_bytes: 8_192}
    assert UpstreamGroups.valid_handle?(h1)
    h1_with_t = Map.put(h1, :transports, [f.transport])
    assert UpstreamGroups.valid_handle?(h1_with_t)
    for unrelated <- [h1, h1_with_t] do
      pins = [group_pin(f.group), group_pin(unrelated), transport_pin(f.transport)]
      assert :erlang.external_size(pins) < 65_536
      assert Gaoxy.Proxy.HTTP.captured_resources?(pins, [f.group, f.transport])
      assert accepted(:captured_pins, pins, :i).projection === pins
      assert accepted(:pump, pump(f, pins), :p).projection.exchange.resource_pins === pins
    end
  end

  test "aggregate capture enforces complete65536 and per-provider64 without trimming roots" do
    f = fixture()
    pins = for _ <- 1..64, do: group_pin(f.group)
    assert length(pins) == 64
    assert :erlang.external_size(pins) < 65_536
    accepted(:captured_pins, pins, :i)
    huge_batches = for _ <- 1..64, do: transport_pin(f.transport, for(_ <- 1..64, do: %{f.transport | resource: make_ref()}))
    assert :erlang.external_size(huge_batches) > 65_536
    rejected(:captured_pins, huge_batches)
    invalid(:captured_pins, [transport_pin(f.transport, List.duplicate(f.transport, 65))])
  end

  test "all32 original T dependencies fit H P A S and preserve complete handoff" do
    f = maximal_fixture()
    transports = [f.transport | for(_ <- 2..32, do: %{f.transport | resource: make_ref()})]
    f = %{f | group: %{f.group | transports: transports}}
    assert {:ok, _} = Resources.validate([f.group | transports])
    accepted(:group_handle, f.group, :x)
    pins = [group_pin(f.group), transport_pin(f.transport, transports)]
    accepted(:pump, pump(f, pins), :p)
    args = session_args(f, [hd(pins)])
    accepted({:args, :session}, args, :a)
    s = %{active_session(f) | config: args.config, selector: args.selector,
      awaiting_transport: %{handle: f.transport, member: f.member}, managed_transport: nil,
      transport_selection: nil, transport_pins: []}
    accepted({:state, :session}, s, :s)
  end

  test "actual complete owner call and pin response envelopes charge H pins and scalar wrappers" do
    f = fixture()
    gp = group_pin(f.group)
    tp = transport_pin(f.transport)
    token = make_ref()
    calls = [
      {:group, :pin, {:pin, [f.group], self(), :request, gp.operation, 20_000}},
      {:group, :release, {:release, gp}},
      {:group, :checkout, {:checkout, f.group, [gp], self(), %{}, 20_000}},
      {:group, :bind, {:bind, f.group, token, handle().completion}},
      {:group, :finish, {:finish, f.group, token, :success}},
      {:transport, :pin, {:pin_many, [f.transport], self(), :request, tp.operation, 20_000}},
      {:transport, :release, {:release, tp}},
      {:transport, :checkout, {:checkout, f.transport, [tp], self(), 20_000}},
      {:transport, :bind, {:bind_completion, f.transport, token, handle().completion}},
      {:transport, :finish, {:finish, f.transport, token}}
    ]
    for {owner, op, original} <- calls do
      receipt = accepted({:owner_call, owner, op}, original, :i)
      assert tuple_size(receipt.projection) == tuple_size(original)
      wrapped = {:"$gen_call", {self(), make_ref()}, original}
      assert accepted({:owner_call, owner, op}, wrapped, :i).bytes > receipt.bytes
      invalid({:owner_call, owner, op}, Tuple.append(original, :unexpected))
    end
    for {owner, pin} <- [{:group, gp}, {:transport, tp}] do
      reply = {:ok, pin}
      assert accepted({:owner_reply, owner, :pin}, reply, :i).projection === reply
      wrapped = {make_ref(), reply}
      assert accepted({:owner_reply, owner, :pin}, wrapped, :i).projection === wrapped
    end
    authority = {:http2, :https, "upstream.test", 443}
    delegate = {:delegate_request_pin, f.transport, tp, self(), authority, self(), make_ref(), 20_000}
    accepted({:owner_call, :transport, :delegate}, delegate, :i)
    invalid({:owner_call, :group, :checkout}, {:checkout, f.group, [tp], self(), %{}, 20_000})
  end

  test "open U retains genuine task shell and completion alias and never substitutes original identity" do
    f = fixture()
    h = handle()
    assert ManagedH2Client.completion(h) === h.completion
    for upload <- [nil, self()] do
      r = accepted(:open_result, {:ok, h, upload}, :u)
      assert r.projection == {:ok, safe_handle(h), upload}
    end
    other = %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil}
    invalid(:open_result, {:ok, %{h | promise: %{h.promise | completion: other}}, nil})
    invalid(:open_result, {:ok, h, make_ref()})
    invalid(:open_result, {:ok, Map.put(h, :extra, nil), nil})
    invalid(:open_result, {:ok, %{h | promise: %{h.promise | task: %{h.promise.task | owner: make_ref()}}}, nil})
    accepted(:open_result, {:error, :timeout}, :u)
    accepted(:open_result, {:error, {:cleanup_unconfirmed, :timeout}}, :u)
    invalid(:open_result, {:error, %{unbounded: f.neutral}})
  end

  test "complete32 member owner config charges compiled and runtime C plus growth exactly" do
    f = maximal_fixture()
    group = owner_group(f, 32)
    assert length(group.compiled.members) == 32
    assert length(group.members) == 32
    assert Enum.all?(group.members, &(map_size(&1) == 10))
    base = :erlang.external_size(Map.delete(group, :bytes))
    assert {:ok, bytes} = call(:group_charge, [group])
    assert bytes == base + 131_072
    assert bytes <= 12_582_912
    retained = %{group | bytes: bytes}
    assert :ok == call(:group_update, [retained, bytes])
    changed_member = List.update_at(group.members, 0, fn m -> %{m | config: %{m.config | limits: %{m.config.limits | idle_timeout: 1}}} end)
    invalid_group = %{group | members: changed_member}
    assert @invalid == call(:group_charge, [invalid_group])
    assert @invalid == call(:group_charge, [Map.put(group, :extra, fn -> :never end)])
  end

  test "owner H2 mutable32-ref controls fit stable growth charge and thresholds are finite" do
    f = fixture()
    group = owner_group(f, 32)
    {:ok, bytes} = call(:group_charge, [group])
    members = Enum.map(group.members, fn m -> %{m | health: :unhealthy, checked: @max,
      failures: group.compiled.health.failure_threshold, successes: group.compiled.health.recovery_threshold,
      inflight: m.max_inflight, probe: make_ref(), due: @min} end)
    # Group max is1024 and32 members*16=512; all controls are genuine finite source scalars.
    update = %{group | members: members, cursor: 31, inflight: 512, lifecycle: :retiring, bytes: bytes}
    assert :ok == call(:group_update, [update, bytes])
    assert :erlang.external_size(Map.delete(update, :bytes)) <= bytes
    for {field, value} <- [failures: 101, successes: 101, checked: @max + 1, due: @min - 1, inflight: 17] do
      bad = %{update | members: List.update_at(members, 0, &Map.put(&1, field, value))}
      assert @invalid == call(:group_update, [bad, bytes])
    end
    assert @invalid == call(:group_update, [%{update | bytes: bytes + 1}, bytes])
    assert @capacity == call(:group_update, [%{update | bytes: 1}, 1])
    assert @invalid == call(:group_update, [Map.put(update, :history, []), bytes])
  end

  test "owner config reserve includes full data twice and never accepts arbitrary self bytes" do
    f = fixture()
    g = owner_group(f, 1)
    {:ok, amount} = call(:group_charge, [g])
    assert amount == :erlang.external_size(Map.delete(g, :bytes)) + 131_072
    huge = %{g | compiled: %{g.compiled | members: List.duplicate(f.member, 33)}}
    assert @invalid == call(:group_charge, [huge])
    assert @invalid == call(:group_charge, [%{g | bytes: :infinity}])
    assert @invalid == call(:group_update, [%{g | bytes: 12_582_913}, 12_582_913])
    assert amount > 2 * :erlang.external_size(f.member.config)
  end

  for kind <- [:pin, :selection, :probe] do
    test "#{kind} exact control self-accounting preserves whole record and reconciles provisional cap" do
      kind = unquote(kind)
      f = fixture()
      record = control(kind, f)
      expected = safe_control(record)
      assert {:ok, bytes} = call(:control_charge, [kind, record])
      assert bytes == :erlang.external_size(expected)
      installed = Map.put(record, :control_bytes, bytes)
      assert {:ok, ^bytes} = call(:control_charge, [kind, installed])
      partial = provisional(kind, record)
      assert {:ok, reserve} = call(:control_reserve, [kind, partial])
      assert reserve == if(kind == :pin, do: 196_608, else: 32_768)
      assert reserve >= bytes
      held = 100 + reserve
      reconciled = held - (reserve - bytes)
      assert reconciled - bytes == 100
      assert @invalid == call(:control_charge, [kind, Map.put(record, :extra, nil)])
      assert @invalid == call(:control_charge, [kind, Map.put(record, :control_bytes, :infinity)])
      assert @invalid == call(:control_reserve, [kind, Map.delete(partial, pin_key(:key, kind))])
    end
  end

  test "probe full request bytes are distinct from self control bytes throughout recovery" do
    f = fixture()
    record = control(:probe, f)
    assert record.bytes == 16_478_862
    {:ok, original} = call(:control_charge, [:probe, record])
    completion = handle().completion
    recovered = Map.merge(record, %{completion: completion, monitor: nil, recovery: self(), recovery_monitor: make_ref()})
    {:ok, recovered_bytes} = call(:control_charge, [:probe, recovered])
    assert recovered_bytes == :erlang.external_size(safe_control(recovered))
    assert recovered_bytes > original
    assert recovered.bytes == 16_478_862
    assert recovered_bytes < recovered.bytes
    partial = Map.drop(recovered, [:recovery, :recovery_monitor])
    assert {:ok, 32_768} == call(:control_reserve, [:probe, partial])
    invalid_record = %{record | bytes: 0}
    assert @invalid == call(:control_charge, [:probe, invalid_record])
  end

  test "a shared H2/H1 pin is charged in full and bounded by real64-key record" do
    f = fixture()
    record = control(:pin, f)
    keys = [record.keys |> hd() | for(n <- 1..63, do: {"unrelated-#{n}", make_ref()})]
    record = %{record | keys: keys}
    {:ok, amount} = call(:control_charge, [:pin, record])
    assert amount == :erlang.external_size(record)
    assert amount > :erlang.external_size(%{record | keys: [hd(keys)]})
    assert @invalid == call(:control_charge, [:pin, %{record | keys: keys ++ [{"over", make_ref()}]}])
    assert @invalid == call(:control_charge, [:pin, %{record | keys: [hd(keys) | :bad]}])
  end

  test "held selection recovery includes original opaque completion and extra monitor" do
    f = fixture()
    r = control(:selection, f)
    completion = %HTTP.RequestCompletion{tracker: fn -> :opaque end, latch: fn -> :opaque end, unsupported: nil}
    recovered = Map.merge(r, %{completion: completion, recovery: self(), recovery_monitor: make_ref(), monitor: nil})
    {:ok, measured} = call(:control_charge, [:selection, recovered])
    assert measured == :erlang.external_size(safe_control(recovered))
    assert @invalid == call(:control_charge, [:selection, %{recovered | recovery: nil}])
    assert @invalid == call(:control_charge, [:selection, %{recovered | index: 32}])
    assert @invalid == call(:control_charge, [:selection, %{recovered | deadline: @max + 1}])
  end

  for family <- @fixed_families do
    test "closed fixed #{family} envelope fits its full2048 slot" do
      f = fixture()
      original = fixed_control(unquote(family), f)
      r = accepted({:control, unquote(family)}, original, :e, 2_048)
      assert r.bytes <= 2_048
      assert @invalid == call(:project, [{:control, unquote(family)}, {original, :expanded}])
    end
  end

  test "raw8192 identity plus real handle and signed scalar shell uses full group24576 slot" do
    f = maximal_fixture()
    identity = %{origin: root(f.member.config), upstream_protocol: :http2, instance: self()}
    original = {:gaoxy_proxy_http, self(), {:transport_handoff, make_ref(), f.transport, identity, @max - 1_000}}
    r = accepted({:control, :identity}, original, :e, 24_576)
    assert r.projection === original
    assert r.bytes > 8_192
    assert r.bytes == :erlang.external_size(original)
    invalid({:control, :identity}, {:gaoxy_proxy_http, self(), {:transport_handoff, make_ref(), f.transport, Map.put(identity, :extra, nil), @max}})
    invalid({:control, :identity}, {:gaoxy_proxy_http, self(), {:transport_handoff, make_ref(), f.transport, %{identity | origin: slice(identity.origin, 65_537)}, @max}})
  end

  test "group admission owner and probe E constructors keep scalar authority and named payload roles" do
    f = fixture()
    lease = make_ref()
    token = make_ref()
    for original <- [{:adjust_bytes, lease, 5_963_776}, {:adjust_bytes, lease, -5_963_776},
                     {:attach_cleanup, self(), lease, self(), 16_478_862, 20_000},
                     {:attach_cleanup, self(), lease, self(), 16_478_862, 20_000, token}] do
      r = accepted({:control, :admission}, original, :e, 24_576)
      assert r.projection === original
    end
    owner_call = {:"$gen_call", {self(), make_ref()}, {:checkout, f.group, [group_pin(f.group)], self(), %{}, 20_000}}
    owner = accepted({:control, :owner}, owner_call, :e, 24_576)
    assert elem(owner.projection, 1) === elem(owner_call, 1)
    assert elem(owner.projection, 2) == {:slot, :i}
    for original <- [{:claim_probe, token, 20_000}, {:claim_probe, token, f.group, 20_000},
                     {:probe_finished, token, :success}, {:recovered, :probe, token, self(), :ok}] do
      accepted({:control, :probe}, original, :e, 24_576)
    end
    invalid({:control, :admission}, {:adjust_bytes, lease, :infinity})
    invalid({:control, :probe}, {:recovered, :other, token, self(), :ok})
    invalid({:control, :owner}, {:"$gen_call", {self(), make_ref()}, {:unknown, f.group}})
  end

  test "E refuses combined-over-cap shape despite individually bounded public scalars" do
    # Untrusted representable ETF shapes exercise only refusal. They are never
    # sent, used as authority, or substituted for actual generated identities.
    {pid, ref} = large_untrusted_scalars()
    assert is_pid(pid) and is_reference(ref)
    assert :erlang.external_size(pid) <= 2_048
    assert :erlang.external_size(ref) <= 2_048
    envelope = {:DOWN, ref, :process, pid, :timeout}
    assert :erlang.external_size(envelope) > 2_048
    assert @capacity == call(:project, [{:control, :down}, envelope])
    # Maximal signed scalars and genuine generated identities remain admitted.
    accepted({:control, :down}, {:DOWN, make_ref(), :process, self(), :timeout}, :e, 2_048)
    accepted({:control, :drain}, {:gaoxy_drain, self(), make_ref(), @max}, :e, 2_048)
  end

  test "control diagnostics are finite after normalization and never raw retained payloads" do
    raw = {:opaque_external, fn -> :unbounded end}
    result = accepted({:control, :down}, {:DOWN, make_ref(), :process, self(), raw}, :e, 2_048)
    assert elem(result.projection, 4) == Session.finite_reason(raw)
    result = accepted({:control, :cleanup_cancel}, {:gaoxy_cleanup_cancel, make_ref(), raw, @min}, :e, 2_048)
    assert elem(result.projection, 2) == Session.finite_reason(raw)
    assert @invalid == call(:project, [{:control, :new_retained_queue}, [raw]])
  end

  defp call(function, arguments \\ []), do: apply(@accounting, function, arguments)

  defp accepted(selector, original, role, cap \\ nil) do
    assert {:ok, result} = call(:project, [selector, original])
    assert Enum.sort(Map.keys(result)) == Enum.sort([:role, :projection, :bytes, :cap])
    assert result.role == role
    expected_cap = cap || @caps[role]
    # Auxiliary roots use their independently specified effective capture caps.
    case selector do
      :captured_pins -> assert result.cap == 65_536
      :group_handle -> assert result.cap <= @caps.x
      _ -> assert result.cap == expected_cap
    end
    assert result.bytes == :erlang.external_size(result.projection)
    assert result.bytes <= result.cap
    assert :ok == call(:validate, [selector, original])
    result
  end

  defp invalid(selector, original) do
    assert @invalid == call(:project, [selector, original])
    assert @invalid == call(:validate, [selector, original])
  end

  defp rejected(selector, original) do
    assert call(:project, [selector, original]) in [@invalid, @capacity]
    assert call(:validate, [selector, original]) in [@invalid, @capacity]
  end

  defp fixture(protocol \\ :http2) do
    transport = other_transport()
    config = config(protocol, transport, origin(protocol))
    member = %{id: "member", config: config, max_inflight: 16}
    group = group(transport)
    neutral = %{target: "/a%2Fb?", method: :post, fields: [{"x-trace", "one"}],
      body_mode: :none, request_limits: request_limits(), max_upload_bytes: 65_536}
    context = %{group: group, instance: self(), limits: limits(), deadline: 20_000,
      opening_deadline: 12_000, now: 10_000}
    checked = checked(protocol, origin(protocol))
    {:ok, options, _} = ManagedH2GroupBoundary.prepare(member, neutral, checked, context)
    %{transport: transport, member: member, group: group, neutral: neutral,
      context: context, checked: checked, options: options}
  end

  defp maximal_fixture(protocol \\ :http2) do
    f = fixture(protocol)
    config = config(protocol, f.transport, long_origin(protocol, 8_192))
    member = %{f.member | config: config, id: :binary.copy("m", 128)}
    neutral = %{f.neutral | target: :binary.copy("/" <> :binary.copy("a", 57_343)), fields: []}
    checked = checked(protocol, origin(protocol))
    {:ok, options, _} = ManagedH2GroupBoundary.prepare(member, neutral, checked, f.context)
    %{f | member: member, neutral: neutral, checked: checked, options: options}
  end

  defp config(protocol, transport, origin) do
    uri = URI.parse(origin) |> Map.to_list() |> Map.new(fn
      {key, value} when is_binary(value) -> {key, :binary.copy(value)}
      pair -> pair
    end)
    %Gaoxy.Proxy.HTTP{uri: uri, cacertfile: nil, connect_address: nil, transport: transport,
      limits: limits(), upstream_protocol: protocol, client: ManagedH2Client}
  end

  defp checked(protocol, origin, trust \\ nil) do
    trust = if protocol == :http2, do: trust || [<<48, 3, 2, 1, 1>>], else: nil
    {:ok, policy, _} = ManagedH2Preparation.prepare_policy(%{protocol: protocol, origin: origin,
      connect_address: {127, 0, 0, 1}, trust: trust})
    %{policy: policy, transport_scope: struct(HTTP.ManagedTransport), fetch_options: [
      http_version: protocol, tls_backend: :ssl, http2_profile: :native_v1, http2_reuse: true,
      redirect: :manual, request_mode: :proxy, decode_body: false, stream_response: true, telemetry: false]}
  end

  defp other_transport, do: %{provider: UpstreamTransports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}
  defp group(t), do: %{provider: UpstreamGroups, owner: self(), owner_epoch: make_ref(),
    group: "group", generation: make_ref(), max_url_bytes: 8_192, transports: [t], execution_profile: :managed_h2}
  defp other_group(t), do: %{group(t) | group: "unrelated", generation: make_ref()}
  defp group_pin(g), do: %{provider: UpstreamGroups, owner: g.owner, owner_epoch: g.owner_epoch,
    ref: make_ref(), operation: make_ref(), handles: [g], kind: :request}
  defp transport_pin(t, handles \\ nil), do: %{provider: UpstreamTransports, owner: t.owner,
    owner_epoch: t.owner_epoch, ref: make_ref(), operation: make_ref(), handles: handles || [t], kind: :request, holder: self()}
  defp limits, do: %{max_chunk_bytes: 65_536, opening_timeout: 5_000, idle_timeout: 60_000, write_timeout: 3_000, max_lifetime: 30_000}
  defp request_limits, do: %{max_headers: 256, max_header_bytes: 65_536, max_trailers: 128, max_trailer_bytes: 65_536}
  defp health, do: %{path: "/health", interval: 5_000, timeout: 2_000, stale_after: 15_000, failure_threshold: 3, recovery_threshold: 2, jitter: 500}
  defp origin(:http2), do: "https://upstream.test"
  defp origin(:h2c), do: "http://upstream.test"
  defp root(config), do: config.uri.scheme <> "://" <> config.uri.authority
  defp long_origin(protocol, bytes) do
    prefix = origin(protocol) <> ":"
    port = if protocol == :http2, do: "443", else: "80"
    :binary.copy(prefix <> :binary.copy("0", bytes - byte_size(prefix) - byte_size(port)) <> port)
  end
  defp slice(value, bytes) do
    backing = :binary.copy(value <> :binary.copy("p", bytes - byte_size(value)))
    binary_part(backing, 0, byte_size(value))
  end

  defp session_args(f, pins) do
    %{owner: self(), service: self(), instance: self(), gate: self(), started_at: 10_000,
      deadline: 20_000, config: %GroupEndpoint{group: f.group, limits: limits()},
      selector: {:group, f.group, pins}, transport_handoff: make_ref(), request_options: f.neutral}
  end
  defp session_state(args) do
    Map.merge(args, %{monitors: %{make_ref() => self()}, client: ManagedH2Client,
      cleanup_deadline: nil, cleanup_requested_deadline: nil, cleanup_started: false,
      opening_timer: nil, activated_at: nil, opening_deadline: nil, total_timer: nil,
      selection: nil, awaiting_transport: nil, transport_pins: [], transport_selection: nil,
      managed_transport: nil, managed_path: true, submitted_url: nil, poll_timer: nil,
      original_request: nil, outcome: :cancelled, token: nil, request: nil, headers: false,
      delivery: nil, trailers: [], cancelled: false, consumed: false})
  end
  defp active_session(f) do
    %{session_state(session_args(f, [group_pin(f.group)])) | token: make_ref(),
      activated_at: 10_000, opening_deadline: 12_000, opening_timer: make_ref(), total_timer: make_ref(),
      selection: {f.group, make_ref()}, transport_selection: {f.transport, make_ref()},
      transport_pins: [transport_pin(f.transport)], managed_transport: f.checked}
  end
  defp probe_args(f), do: %{owner: self(), token: make_ref(), member: f.member, deadline: 20_000,
    health: health(), url: :binary.copy(root(f.member.config) <> health().path), group: f.group}
  defp probe_state(args) do
    Map.merge(args, %{cleanup_deadline: args.deadline + 1_000, owner_monitor: make_ref(), timer: make_ref(),
      request: nil, original_request: nil, managed_transport: nil, transport_selection: nil,
      transport_pins: [], terminal: false, cancelled: false, headers: false, outcome: :failure,
      client: ManagedH2Client, limits: args.member.config.limits, request_options: nil, submitted_url: nil})
  end
  defp recovery_args(completion \\ nil), do: %{owner: self(), recovery: {:probe, make_ref()},
    completion: completion || handle().completion, deadline: 21_000}
  defp startup_fixture(:session, f), do: {Session, session_args(f, [group_pin(f.group)])}
  defp startup_fixture(:probe, f), do: {Probe, probe_args(f)}
  defp startup_fixture(:recovery, _), do: {Probe, recovery_args()}

  defp handle(completion \\ nil) do
    completion = completion || %HTTP.RequestCompletion{tracker: self(), latch: make_ref(), unsupported: nil}
    %{promise: %HTTP.Promise{task: %Task{owner: self(), pid: self(), ref: make_ref(), mfa: nil}, completion: completion},
      completion: completion, stream: nil, resolved: false}
  end
  defp safe_handle(h), do: %{h | completion: {:opaque, HTTP.RequestCompletion},
    promise: %{h.promise | completion: {:opaque, HTTP.RequestCompletion}}}

  defp pump(f, pins) do
    exchange = %Exchange{request: %Request{method: "GET", target: "/a?", target_form: :origin,
      version: :"HTTP/1.1", path: "/a", query_string: "", host: "downstream.test", port: 80,
      scheme: :http, headers: [], body: :none, keep_alive: true},
      body: Gaoxy.HTTP.HTTP1.Body.new(:none), buffer: "", gate: self(), lease: make_ref(),
      deadline: 20_000, limits: native_limits(), service: self(), instance: self(),
      peer: {{127, 0, 0, 1}, 12_345}, local: {{127, 0, 0, 1}, 80}, resource_pins: pins}
    %{exchange: exchange, config: %GroupEndpoint{group: f.group, limits: limits()}, client: ManagedH2Client,
      policy: %{allowed: [], dropped: [], max_count: 128, max_bytes: 65_536}, response_policy: nil,
      session: self(), monitor: make_ref(), deadline: 20_000,
      transport_handoff: %{ref: make_ref(), handles: f.group.transports,
        source_pins: Enum.filter(pins, &(&1.provider == UpstreamTransports)), used: false},
      upload: nil, ready: false, upload_stopped: false, last_activity: 10_000}
  end
  defp native_limits, do: %{max_request_line: 8_192, max_header_bytes: 32_768, max_headers: 100,
    max_body_bytes: 8_388_608, max_chunk_line: 1_024, max_trailer_bytes: 8_192, max_trailers: 32,
    max_read_chunk: 16_384, max_buffer_bytes: 65_536, request_timeout: 30_000, header_timeout: 5_000,
    read_timeout: 5_000, write_timeout: 5_000, max_write_chunk: 65_536}

  defp owner_group(f, count) do
    members = for n <- 1..count do
      t = if n == 1, do: f.transport, else: %{f.transport | resource: make_ref()}
      %{f.member | id: :binary.copy("member-#{n}"), config: %{f.member.config | transport: t}}
    end
    compiled = %Options{id: f.group.group, members: members, health: health(), max_inflight: 1_024}
    runtime = Enum.map(members, &Map.merge(&1, %{health: :unknown, checked: nil, failures: 0,
      successes: 0, inflight: 0, probe: nil, due: 10_000}))
    %{compiled: compiled, members: runtime, cursor: 0, inflight: 0, lifecycle: :active, bytes: 0,
      handle: %{f.group | transports: Enum.map(members, & &1.config.transport)}}
  end
  defp control(:pin, f), do: %{keys: [{f.group.group, f.group.generation}], holder: self(), acquirer: self(),
    kind: :request, operation: make_ref(), deadline: 20_000, monitor: make_ref(), timer: make_ref()}
  defp control(:selection, f), do: %{key: {f.group.group, f.group.generation}, index: 0,
    guardian: self(), monitor: make_ref(), completion: nil, deadline: 20_000, recovery: nil}
  defp control(:probe, f), do: %{pid: self(), key: {f.group.group, f.group.generation}, index: 0,
    bytes: 16_478_862, completion: nil, claimed: false, monitor: make_ref(), recovery: nil, deadline: 20_000}
  defp provisional(:pin, r), do: Map.drop(r, [:monitor, :timer])
  defp provisional(:selection, r), do: Map.delete(r, :monitor)
  defp provisional(:probe, r), do: Map.drop(r, [:pid, :monitor])
  defp pin_key(_, :pin), do: :keys
  defp pin_key(key, _), do: key
  defp safe_control(r) do
    r = Map.delete(r, :control_bytes)
    if Map.get(r, :completion) == nil, do: r, else: %{r | completion: {:opaque, HTTP.RequestCompletion}}
  end

  defp roots(f), do: [{:selected, f.member}, {:neutral, f.neutral}, {:checked, f.checked},
    {:context, f.context}, {:request, f.options.request}, {:options, f.options},
    {:group_handle, f.group}, {{:args, :session}, session_args(f, [group_pin(f.group)])},
    {{:state, :session}, session_state(session_args(f, [group_pin(f.group)]))},
    {{:args, :probe}, probe_args(f)}, {{:state, :probe}, probe_state(probe_args(f))},
    {{:args, :recovery}, recovery_args()}, {{:state, :recovery}, Map.put(recovery_args(), :owner_monitor, make_ref())}]

  defp fixed_control(:activate, _), do: {:gaoxy_cleanup_activate, make_ref()}
  defp fixed_control(:cleanup_cancel, _), do: {:gaoxy_cleanup_cancel, make_ref(), :timeout, @max}
  defp fixed_control(:handoff, f), do: {:gaoxy_transport_handoff, make_ref(), {:ok, transport_pin(f.transport)}, 20_000}
  defp fixed_control(:down, _), do: {:DOWN, make_ref(), :process, self(), :timeout}
  defp fixed_control(:timer, _), do: :opening_expired
  defp fixed_control(:cast, _), do: {:"$gen_cast", :cancel}
  defp fixed_control(:acknowledge, _), do: {:"$gen_cast", {:acknowledge, make_ref()}}
  defp fixed_control(:task, _), do: {make_ref(), {:error, :timeout}}
  defp fixed_control(:data, _), do: {:stream_chunk, self(), :binary.copy("d", 1_048_576), make_ref()}
  defp fixed_control(:trailers, _), do: {:stream_trailers, self(), %HTTP.Headers{headers: [{"x-end", "yes"}]}}
  defp fixed_control(:stream_end, _), do: {:stream_end, self()}
  defp fixed_control(:stream_error, _), do: {:stream_error, self(), :timeout}
  defp fixed_control(:ready, _), do: {:gaoxy_proxy_http, self(), {:ready, nil, limits(), @max}}
  defp fixed_control(:handoff_request, f), do: {:gaoxy_proxy_http, self(), {:transport_handoff,
    make_ref(), f.transport, %{origin: root(f.member.config), upstream_protocol: :http2, instance: self()}, 20_000}}
  defp fixed_control(:delivery, _), do: {:gaoxy_proxy_http, self(), {:chunk, "data", make_ref()}}
  defp fixed_control(:drain, _), do: {:gaoxy_drain, self(), make_ref(), @min}

  defp large_untrusted_scalars do
    # NEW_PID_EXT and NEWER_REFERENCE_EXT with a1020-byte valid UTF8 node atom.
    # The values are public decoded types used ONLY as rejected input.
    node = :binary.copy("😀", 255)
    atom = <<118, byte_size(node)::16, node::binary>>
    pid = :erlang.binary_to_term(<<131, 88, atom::binary, 1::32, 0::32, 0::32>>)
    ref = :erlang.binary_to_term(<<131, 90, 3::16, atom::binary, 0::32, 1::32, 2::32, 3::32>>)
    {pid, ref}
  end
end
