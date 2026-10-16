defmodule Gaoxy.Proxy.ManagedGenerationCheckedCaptureTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, UpstreamGroups, UpstreamTransports}

  @accounting Gaoxy.Proxy.ManagedGenerationAccounting
  @invalid {:error, :invalid_generation_capture}
  @capacity {:error, :generation_capture_capacity}
  @min -9_223_372_036_854_775_808
  @max 9_223_372_036_854_775_807
  @finite ~w(invalid_generation_capture generation_capture_capacity generation_unavailable
    generation_pin_release_failed cleanup_unconfirmed invalid_resource_holder byte_limit
    stale_generation deadline_exceeded cleanup_pending)a
  @prerequisites ~w(checked_runtime_constructors pre_admission_constructor_gate
    real_public_owner_boundaries native_h1_capture downstream_h2_capture final_independent_review)a

  # Literal independent design2 + full callback-envelope forecast at M65536/retained0. This source-only
  # proposal is NOT evidence of actual owner receipts or an Admission reserve.
  # Each row is {name, owner, lifetime, multiplicity, complete_cap, subtotal}.
  @ledger [
    {:context, :requester, :request_end, 1, 8213, 8213},
    {:plan, :requester, :request_end, 1, 59, 59},
    {:admission_update_payload, :requester, :admission_return, 1, 2063, 2063},
    {:admission_update_wire, :admission, :admission_return, 1, 6198, 6198},
    {:admission_update_reply, :requester, :admission_return, 1, 2116, 2116},
    {:snapshot_requester_payload, :requester, :snapshot_return, 1, 2131, 2131},
    {:snapshot_call_wire, :store, :snapshot_return, 1, 6266, 6266},
    {:snapshot_store_payload, :store, :snapshot_return, 1, 2131, 2131},
    {:snapshot_store_from, :store, :snapshot_return, 1, 4123, 4123},
    {:validated_manifest, :store, :snapshot_return, 1, 65536, 65536},
    {:partition_map, :store, :acquisition_end, 1, 199551, 199551},
    {:provider_handle_normalization, :provider, :provider_return, 3, 65536, 196608},
    {:provider_request_payload, :store, :provider_return, 1, 69676, 69676},
    {:provider_call_wire, :provider, :provider_return, 1, 73811, 73811},
    {:provider_owner_payload, :provider, :provider_return, 1, 69676, 69676},
    {:provider_owner_from, :provider, :provider_return, 1, 4123, 4123},
    {:genuine_provider_pin, :provider, :receipt_validation, 1, 75921, 75921},
    {:provider_result_payload, :provider, :provider_return, 1, 75927, 75927},
    {:provider_reply_wire, :store, :receipt_validation, 1, 78002, 78002},
    {:provider_store_received_result, :store, :receipt_validation, 1, 75927, 75927},
    {:checked_acquisition_accumulator, :store, :snapshot_return, 3, 65542, 196626},
    {:original_provenance, :store, :acquisition_end, 3, 331456, 994368},
    {:store_snapshot_payload, :store, :snapshot_return, 1, 196612, 196612},
    {:store_snapshot_wire, :requester, :snapshot_return, 1, 198687, 198687},
    {:requester_snapshot_received, :requester, :request_end, 1, 196612, 196612},
    {:caller_capture_inputs_and_output, :requester, :request_end, 3, 65536, 196608},
    {:release_payload, :requester, :release_return, 1, 65541, 65541},
    {:release_call_wire, :provider, :release_return, 1, 69676, 69676},
    {:release_reply_wire, :requester, :release_return, 1, 2116, 2116},
    {:cancel_control, :provider, :cancellation_uncertain, 65, 4124, 268060},
    {:known_call_failure_descriptor, :caller, :call_return, 1, 71829, 71829},
    {:known_monitor_down, :caller, :call_return, 1, 4187, 4187},
    {:cleanup_observation, :requester, :emit_return, 2, 6276, 12552},
    {:finite_failure_payload, :requester, :request_end, 1, 62, 62},
    {:original_current_entry, :store, :acquisition_end, 1, 69685, 69685},
    {:manifest_normalization, :store, :acquisition_end, 2, 65536, 131072},
    {:manifest_validation_result, :store, :acquisition_end, 1, 65542, 65542},
    {:acquisition_control, :store, :acquisition_end, 3, 397001, 1191003},
    {:partition_scratch, :store, :acquisition_end, 2, 199551, 399102},
    {:checked_config, :requester, :request_end, 1, 2143, 2143},
    {:checked_preflight_result, :caller, :preflight_return, 2, 39, 78},
    {:checked_acquisition_failure, :store, :acquisition_end, 2, 62, 124},
    {:checked_release_status, :requester, :cleanup_end, 2, 41, 82},
    {:cleanup_deadline, :requester, :cleanup_end, 1, 12, 12},
    {:finite_control_status, :caller, :request_end, 2, 22, 44},
    {:original_deadline, :caller, :request_end, 1, 12, 12},
    {:numeric_m, :requester, :reservation_return, 2, 6, 12},
    {:numeric_retained, :requester, :reservation_return, 2, 3, 6},
    {:numeric_reservation, :requester, :reservation_return, 2, 6, 12},
    {:numeric_retained_plus_reservation, :requester, :reservation_return, 2, 6, 12},
    {:numeric_next, :requester, :reservation_return, 2, 6, 12},
    {:numeric_iterations, :requester, :reservation_return, 2, 3, 6},
    {:numeric_timing, :requester, :cleanup_end, 3, 12, 36}
  ]

  @tag :checked_capture_constructor
  test "runtime diagnostic has exact report grammar and all 53 literal role signatures" do
    assert {:ok, report} = call(:runtime_worksheet, [65_536, context()])
    assert Enum.sort(Map.keys(report)) ==
             Enum.sort(~w(qualification profile m retained bounds roles total fixed_point_iterations prerequisites)a)
    assert report.qualification == :conditional_not_runtime_ready
    assert report.profile == :native_generation_checked_capture
    assert report.m == 65_536
    assert report.retained == 0
    assert report.total == 5_350_589
    assert report.fixed_point_iterations == 2
    assert report.prerequisites == @prerequisites
    assert report.bounds == %{
             h: 65_536, q: 65_536, s: 2048, k: 64, future_ref: 2062,
             g_pin: 73862, t_pin: 75921, genuine_pin: 75921,
             g_singleton: 73868, t_singleton: 75927, cancel_controls: 65
           }
    assert Enum.map(report.roles, &signature/1) == @ledger
    assert length(Enum.uniq_by(report.roles, & &1.name)) == 53
    assert Enum.sum(Enum.map(report.roles, & &1.subtotal)) == 5_350_589
    assert_descriptors(report.roles)
  end

  @tag :checked_capture_constructor
  test "independent complete ETF algebra matches every literal baseline cap" do
    assert independent_caps(65_536, 0, 5_350_589) ==
             Map.new(@ledger, fn {name, _, _, _, cap, _} -> {name, cap} end)
    assert e(0) == 3
    assert e(255) == 3
    assert e(256) == 6
    assert e(2_147_483_647) == 6
    assert e(2_147_483_648) == 8
    assert t([e(:deadline_exceeded), e(:cleanup_pending)]) == 39
    assert t([e(:error), Enum.max(Enum.map(@finite, &e/1)), e(:cleanup_unconfirmed)]) == 62
    inner_plan = t([e(:native_generation_capture_v1), e(65_536), e(65_536), e(65_536), e(5_350_589)])
    assert inner_plan == 53
    assert t([e(:ok), inner_plan]) == 59
    assert t([e(:error), e(:invalid_generation_capture)]) == 38
    assert t([e(:error), e(:generation_capture_capacity)]) == 39
    assert t([e(:ok), map_e([count: e(64), bytes: e(65_536)])]) == 33
    assert e([:alias | make_ref()]) != e([:alias, make_ref()])
  end

  @tag :checked_capture_constructor
  test "compact reservation returns exactly the reviewed five tuple and same diagnostic B" do
    for {m, expected} <- [{65_536, 5_350_589}, {1_048_576, 11_248_829}] do
      c = context()
      assert {:ok, {:native_generation_capture_v1, ^m, 65_536, 65_536, ^expected}} =
               call(:reservation, [m, c])
      assert {:ok, report} = call(:runtime_worksheet, [m, c])
      assert report.total == expected
      assert_report_rows(report, m, 0, expected)
    end
  end

  @tag :checked_capture_constructor
  test "configured default pays all three complete snapshot roots and whole row table" do
    assert {:ok, report} = call(:runtime_worksheet, [1_048_576, context()])
    assert report.total == 11_248_829
    assert report.fixed_point_iterations == 2
    assert_report_rows(report, 1_048_576, 0, 11_248_829)
    r = Map.new(report.roles, &{&1.name, &1})
    assert r.store_snapshot_payload.cap == 2_162_692
    assert r.store_snapshot_wire.cap == 2_164_767
    assert r.requester_snapshot_received.cap == 2_162_692
    assert r.known_call_failure_descriptor.cap == 71_829
    assert r.known_monitor_down.cap == 4187
  end

  @tag :checked_capture_constructor
  test "M and reservation integer widths have independently anchored precision boundaries" do
    # Full callback envelopes move the signed32 edge: M357087712 is last
    # fitting B; M357087713 crosses it from B0=0. Old edge points stay covered.
    cases = [
      {1, 4957367, 2},
      {255, 4958891, 2},
      {256, 4958909, 2},
      {65536, 5350589, 2},
      {1048576, 11248829, 2},
      {357087712, 2147483645, 2},
      {357087713, 2147483669, 3},
      {357087715, 2147483681, 3},
      {357087716, 2147483687, 3},
      {2147483647, 12889859282, 2},
      {2147483648, 12889859296, 2},
      {4294967295, 25774761178, 2},
      {4294967296, 25774761188, 2},
      {18446744073709551616, 110680464442262267160, 2}
    ]
    for {m, total, iterations} <- cases do
      assert {:ok, report} = call(:runtime_worksheet, [m, context()])
      assert report.total == total
      assert report.fixed_point_iterations == iterations
      assert {:ok, {:native_generation_capture_v1, ^m, 65_536, 65_536, ^total}} =
               call(:reservation, [m, context()])
      assert_report_rows(report, m, 0, total)
    end
  end

  @tag :checked_capture_constructor
  test "retained and retained plus B cross standalone ETF widths independently" do
    # At retained2142133049, retained+B reaches signed32 max exactly.
    # The next byte crosses E(retained+B); solve all whole rows from B0=0.
    cases = [
      {0, 5350589, 2},
      {255, 5350589, 2},
      {256, 5350598, 2},
      {2142133049, 5350598, 2},
      {2142133050, 5350606, 3},
      {2142133067, 5350606, 2},
      {2142133068, 5350606, 2},
      {2147483647, 5350606, 2},
      {2147483648, 5350612, 2},
      {4294967295, 5350616, 2},
      {4294967296, 5350619, 2},
      {18446744073709551615, 5350644, 2},
      {18446744073709551616, 5350647, 2}
    ]
    for {retained, total, iterations} <- cases do
      assert {:ok, report} = call(:runtime_worksheet, [65_536, context(retained)])
      assert report.total == total
      assert report.fixed_point_iterations == iterations
      assert {:ok, {:native_generation_capture_v1, 65_536, 65_536, 65_536, ^total}} =
               call(:reservation, [65_536, context(retained)])
      assert_report_rows(report, 65_536, retained, total)
    end
  end

  @tag :checked_capture_constructor
  test "public pure APIs preserve selected signed64 context grammar without a clock" do
    for deadline <- [@min, -1, 0, 1, @max - 1000],
        api <- [:runtime_worksheet, :reservation] do
      assert {:ok, _} = call(api, [65_536, put_elem(context(), 5, deadline)])
    end
  end

  @tag :checked_capture_constructor
  test "both new pure APIs reject malformed M context scalar kind and retained inputs" do
    c = context()
    for api <- [:runtime_worksheet, :reservation],
        m <- [0, -1, 1.0, nil, :default, %{max_config_bytes: 65_536}] do
      assert @invalid == call(api, [m, c])
    end
    bad =
      [nil, [], Tuple.to_list(c), %{context: c}, Tuple.insert_at(c, tuple_size(c), :extra)] ++
        for(index <- 0..2, v <- [nil, make_ref(), :owner], do: put_elem(c, index, v)) ++
        for(v <- [self(), nil, 0], do: put_elem(c, 3, v)) ++
        for(v <- [:baseline, :preparation, nil], do: put_elem(c, 4, v)) ++
        for(v <- [@min - 1, @max - 999, @max + 1, 1.0, nil], do: put_elem(c, 5, v)) ++
        for v <- [-1, 1.0, nil], do: put_elem(c, 6, v)
    for api <- [:runtime_worksheet, :reservation], value <- bad do
      assert @invalid == call(api, [65_536, value])
    end
  end

  @tag :checked_capture_constructor
  test "manifest allows empty and all source G variants without global33 resource cutoff" do
    f = fixtures()
    assert :ok == call(:validate_manifest, [[]])
    assert :ok == call(:validate_manifest, [[f.g6, f.g7, f.g8, f.g32, f.t]])
    groups = for _ <- 1..64, do: %{f.g6 | generation: make_ref()}
    assert length(groups) == 64
    assert :ok == call(:validate_manifest, [groups])
    assert @invalid == call(:validate_manifest, [groups ++ [%{f.g6 | generation: make_ref()}]])
    too_many_transports = %{f.g32 | transports: f.g32.transports ++ [%{f.t | resource: make_ref()}]}
    assert @invalid == call(:validate_manifest, [[too_many_transports]])
    # Epoch consistency is per {provider,owner}, not cross-provider/global.
    independent_t = %{f.t | owner_epoch: make_ref()}
    assert :ok == call(:validate_manifest, [[f.g6, independent_t]])
  end

  @tag :checked_capture_constructor
  test "manifest validates original complete H byte boundary without trimming fields" do
    exact = group_handles_at_size(65_536)
    over = group_handles_at_size(65_537)
    assert e(exact) == 65_536
    assert e(over) == 65_537
    assert :ok == call(:validate_manifest, [exact])
    assert @invalid == call(:validate_manifest, [over])
  end

  @tag :checked_capture_constructor
  test "manifest rejects malformed schema unknown provider and inconsistent original batch epoch" do
    f = fixtures()
    other_epoch = %{f.g6 | owner_epoch: make_ref(), generation: make_ref()}
    for manifest <- [
          nil, :handles, %{count: 0, bytes: 2}, [f.g6 | :improper],
          [%{f.g6 | provider: UnknownProvider}], [Map.put(f.g6, :extra, :x)],
          [Map.put(f.t, :extra, :x)], [%{f.g6 | owner: make_ref()}],
          [%{f.g6 | owner_epoch: self()}], [%{f.t | resource: self()}],
          [%{f.g6 | generation: self()}], [%{f.g6 | max_url_bytes: 8193}],
          [%{f.g6 | group: ""}], [f.g6, other_epoch]
        ] do
      assert @invalid == call(:validate_manifest, [manifest])
    end
  end

  @tag :checked_capture_constructor
  test "correlation accepts complete G7 and T8 against separately supplied original facts" do
    f = fixtures()
    for pin <- [f.g_pin, f.t_pin] do
      original = {pin.provider, pin.owner, pin.operation, pin.handles}
      assert :ok == call(:correlate, [pin, original, self()])
      assert map_size(pin) == if(pin.provider == UpstreamGroups, do: 7, else: 8)
    end
    refute Map.has_key?(f.g_pin, :holder)
    assert f.t_pin.holder === self()
  end

  @tag :checked_capture_constructor
  test "shape valid provider owner epoch operation kind and T holder substitutions cannot correlate" do
    f = fixtures()
    other_pid = Process.group_leader()
    refute other_pid === self()
    owner_pin = %{f.g_pin | owner: other_pid, handles: [%{f.g6 | owner: other_pid}]}
    epoch = make_ref()
    epoch_pin = %{f.g_pin | owner_epoch: epoch, handles: [%{f.g6 | owner_epoch: epoch}]}
    mutations = [
      {f.t_pin, entry(f.g_pin)},
      {owner_pin, entry(f.g_pin)},
      {epoch_pin, entry(f.g_pin)},
      {%{f.g_pin | operation: make_ref()}, entry(f.g_pin)},
      {%{f.g_pin | kind: :baseline}, entry(f.g_pin)},
      {%{f.g_pin | kind: :preparation}, entry(f.g_pin)},
      {%{f.t_pin | holder: other_pid}, entry(f.t_pin)}
    ]
    for {pin, original} <- mutations do
      owner = if pin.provider == UpstreamGroups, do: :group, else: :transport
      assert :ok == ManagedH2GroupAccounting.validate({:owner_reply, owner, :pin}, {:ok, pin})
      assert @invalid == call(:correlate, [pin, original, self()])
    end
  end

  @tag :checked_capture_constructor
  test "correlation requires complete ordered original handles and exact G7 T8 keysets" do
    f = fixtures()
    second = %{f.g6 | generation: make_ref(), group: "second"}
    pin = %{f.g_pin | handles: [f.g6, second]}
    original = entry(pin)
    assert :ok == call(:correlate, [pin, original, self()])
    for changed <- [
          %{pin | handles: Enum.reverse(pin.handles)}, %{pin | handles: [f.g6]},
          %{pin | handles: [f.g6, %{second | group: "changed"}]},
          Map.put(pin, :holder, self()), Map.put(pin, :extra, :x),
          Map.delete(pin, :operation), %{pin | handles: [f.g6 | :improper]}
        ] do
      assert @invalid == call(:correlate, [changed, original, self()])
    end
    for changed <- [Map.delete(f.t_pin, :holder), Map.put(f.t_pin, :extra, :x)] do
      assert @invalid == call(:correlate, [changed, entry(f.t_pin), self()])
    end
  end

  @tag :checked_capture_constructor
  test "correlation validates authentic input facts and accepts only schema constrained new refs" do
    f = fixtures()
    for original <- [nil, [], {:partial, self()}, {UpstreamGroups, :owner, f.g_pin.operation, f.g_pin.handles},
                     {UpstreamGroups, self(), self(), f.g_pin.handles},
                     {UnknownProvider, self(), f.g_pin.operation, f.g_pin.handles},
                     {UpstreamGroups, self(), f.g_pin.operation, []}] do
      assert @invalid == call(:correlate, [f.g_pin, original, self()])
    end
    assert @invalid == call(:correlate, [f.t_pin, entry(f.t_pin), make_ref()])
    assert @invalid == call(:correlate, [%{f.g_pin | ref: self()}, entry(f.g_pin), self()])
    # The original context does not contain the new owner-created ref. A pure
    # correlation API validates its schema, not an invented authentic ref value.
    assert :ok == call(:correlate, [%{f.g_pin | ref: make_ref()}, entry(f.g_pin), self()])
  end

  @tag :checked_capture_constructor
  test "preflights account actual empty and nonempty original operands before construction" do
    f = fixtures()
    assert {:ok, %{count: 0, bytes: 2}} == call(:preflight_append, [[], []])
    assert {:ok, %{count: 1, bytes: e([f.g_pin])}} == call(:preflight_cons, [f.g_pin, []])
    assert {:ok, %{count: 1, bytes: e([f.g_pin])}} == call(:preflight_append, [[f.g_pin], []])
    assert {:ok, %{count: 1, bytes: e([f.t_pin])}} == call(:preflight_append, [[], [f.t_pin]])
    expected = %{count: 2, bytes: e([f.g_pin, f.t_pin])}
    assert expected.bytes == e([f.g_pin]) + e([f.t_pin]) - 7
    assert {:ok, expected} == call(:preflight_cons, [f.g_pin, [f.t_pin]])
    assert {:ok, expected} == call(:preflight_append, [[f.g_pin], [f.t_pin]])
  end

  @tag :checked_capture_constructor
  test "preflight exact Q singleton fits and next byte fails without an aggregate candidate" do
    exact = group_pin_at_size(65_530)
    over = group_pin_at_size(65_531)
    assert e(exact) == 65_530
    assert e([exact]) == 65_536
    assert :ok == ManagedH2GroupAccounting.validate({:owner_reply, :group, :pin}, {:ok, over})
    assert {:ok, %{count: 1, bytes: 65_536}} == call(:preflight_cons, [exact, []])
    assert @capacity == call(:preflight_cons, [over, []])
    assert @invalid == call(:preflight_append, [[over], []])
    left = [exact]
    right = [exact]
    assert e(left) + e(right) - 7 == 131_065
    assert @capacity == call(:preflight_append, [left, right])
    assert @capacity == call(:preflight_cons, [exact, right])
  end

  @tag :checked_capture_constructor
  test "count64 fits while prospective65 and forged improper operands cannot bypass bounds" do
    f = fixtures()
    pins = for _ <- 1..64, do: %{f.g_pin | ref: make_ref(), operation: make_ref()}
    assert e(pins) <= 65_536
    assert {:ok, %{count: 64, bytes: e(pins)}} == call(:preflight_append, [pins, []])
    assert @capacity == call(:preflight_cons, [f.g_pin, pins])
    assert @capacity == call(:preflight_append, [pins, pins])
    for bad <- [%{count: 0, bytes: 2}, %{count: 1, bytes: 1, pins: [f.g_pin]},
                [f.g_pin | :improper], List.duplicate(f.g_pin, 65), nil] do
      assert @invalid == call(:preflight_cons, [f.g_pin, bad])
      assert @invalid == call(:preflight_append, [bad, []])
      assert @invalid == call(:preflight_append, [[], bad])
    end
  end

  @tag :checked_capture_constructor
  test "request only pure contract preserves legacy baseline and preparation validation" do
    f = fixtures()
    for kind <- [:baseline, :preparation] do
      pin = %{f.g_pin | kind: kind}
      assert :ok == ManagedH2GroupAccounting.validate(:captured_pins, [pin])
      assert @invalid == call(:preflight_cons, [pin, []])
      assert @invalid == call(:preflight_append, [[pin], []])
      assert @invalid == call(:correlate, [pin, entry(f.g_pin), self()])
    end
  end

  @tag :checked_capture_constructor
  test "finite normalization preserves deadline exceeded with pending Lifecycle cleanup" do
    assert :deadline_exceeded ==
             call(:finite_checked_reason, [{:deadline_exceeded, :cleanup_pending}])
  end

  @tag :checked_capture_constructor
  test "historical worksheet64 remains distinct from new65 complete cancellation controls" do
    assert {:ok, old} = call(:worksheet, [65_536, context()])
    assert old.total == 2_758_572
    assert old.qualification == :conditional_not_runtime_ready
    assert {:ok, new} = call(:runtime_worksheet, [65_536, context()])
    a = Enum.find(old.roles, &(&1.name == :cancel_control))
    b = Enum.find(new.roles, &(&1.name == :cancel_control))
    assert {a.multiplicity, a.cap, a.subtotal} == {64, 4124, 263_936}
    assert {b.multiplicity, b.cap, b.subtotal} == {65, 4124, 268_060}
    assert b.subtotal - a.subtotal == 4124
    # This arithmetic is not the genuine T postcheck regression: Task3 must run
    # the real public provider path and Task3.5 must bind that source/receipt.
  end

  defp signature(row),
    do: {row.name, row.owner, row.release, row.multiplicity, row.cap, row.subtotal}

  defp assert_descriptors(rows) do
    for row <- rows do
      assert Enum.sort(Map.keys(row)) ==
               Enum.sort(~w(name owner constructor cap multiplicity subtotal release)a)
      assert is_binary(row.constructor) and byte_size(row.constructor) > 0
      assert row.subtotal == row.cap * row.multiplicity
    end
    # Exact spelling is not a contract. Independent source review must verify
    # that each nonempty description names its actual complete constructor.
  end

  defp assert_report_rows(report, m, retained, b) do
    caps = independent_caps(m, retained, b)
    assert Enum.sort(Map.keys(caps)) == Enum.sort(Enum.map(@ledger, &elem(&1, 0)))
    expected =
      Enum.map(@ledger, fn {name, owner, release, count, _, _} ->
        cap = Map.fetch!(caps, name)
        {name, owner, release, count, cap, count * cap}
      end)
    assert Enum.map(report.roles, &signature/1) == expected
    assert Enum.reduce(expected, 0, fn {_, _, _, _, _, subtotal}, sum -> sum + subtotal end) == b
    assert report.total == b
    assert report.m == m
    assert report.retained == retained
    assert report.qualification == :conditional_not_runtime_ready
    assert report.profile == :native_generation_checked_capture
    assert_descriptors(report.roles)
  end

  # Independent ETF grammar over complete sizes. Fixed S/F bounds are source
  # inequalities, not fabricated max-sized PID/ref terms or sampled maxima.
  defp independent_caps(m, retained, b) do
    h = 65_536
    q = 65_536
    s = 2048
    f = 2062
    d = 12
    k = 64
    atom = max(e(UpstreamGroups), e(UpstreamTransports))
    max_finite = Enum.max(Enum.map(@finite, &e/1))
    err2 = t([e(:error), max_finite])
    err3 = t([e(:error), max_finite, max(e(:clean), e(:cleanup_unconfirmed))])
    finite_call = max(max(max_finite, t([e(:deadline_exceeded), e(:cleanup_pending)])), err3)
    batches = 6 + (h - 7) + k * (8 + atom - 1 + s - 1)
    ledger = h + k * (atom + s + f + 5)
    context = t([s, s, s, s, e(:request), d, e(retained)])
    inner_plan = t([e(:native_generation_capture_v1), e(m), e(h), e(q), e(b)])
    plan = max(inner_plan, t([e(:ok), inner_plan]))
    update = t([e(:update), s, e(retained + b)])
    snapshot_call = t([e(:snapshot_for_request), s, d, e(@accounting)])
    provider_call = max(t([e(:pin), h, s, e(:request), f, d]),
                        t([e(:pin_many), h, s, e(:request), f, d]))
    pin_size = max(pin_size(UpstreamGroups), pin_size(UpstreamTransports))
    provider_result = max(t([e(:ok), pin_size]), err2)
    snapshot = max(t([e(:ok), m, m, q]), err3)
    release = t([e(:release), q - 6])
    cancel = max(t([e(:cancel_pin), s, f]), t([e(:cancel_pins), s, f]))
    failure =
      [update, snapshot_call, provider_call, release]
      |> Enum.map(fn payload ->
        t([finite_call, t([e(GenServer), e(:call), l([s, payload, d])])])
      end)
      |> Enum.max()
    cleanup =
      t([l([e(:gaoxy), e(:generation_capture_cleanup)]), map_e([count: e(1)]),
         map_e([store: s, holder: s, lease: s, stage: max(e(:release), e(:acquisition)),
                cleanup: e(:cleanup_unconfirmed)])])
    %{
      context: context,
      plan: plan,
      admission_update_payload: update,
      admission_update_wire: call_size(update, s, f),
      admission_update_reply: reply_size(max(e(:ok), err2), f),
      snapshot_requester_payload: snapshot_call,
      snapshot_call_wire: call_size(snapshot_call, s, f),
      snapshot_store_payload: snapshot_call,
      snapshot_store_from: from_size(s, f),
      validated_manifest: h,
      partition_map: batches,
      provider_handle_normalization: h,
      provider_request_payload: provider_call,
      provider_call_wire: call_size(provider_call, s, f),
      provider_owner_payload: provider_call,
      provider_owner_from: from_size(s, f),
      genuine_provider_pin: pin_size,
      provider_result_payload: provider_result,
      provider_reply_wire: reply_size(provider_result, f),
      provider_store_received_result: provider_result,
      checked_acquisition_accumulator: t([e(:ok), q]),
      original_provenance: ledger,
      store_snapshot_payload: snapshot,
      store_snapshot_wire: reply_size(snapshot, f),
      requester_snapshot_received: snapshot,
      caller_capture_inputs_and_output: q,
      release_payload: release,
      release_call_wire: call_size(release, s, f),
      release_reply_wire: reply_size(max(e(:ok), err2), f),
      cancel_control: cancel,
      known_call_failure_descriptor: failure,
      known_monitor_down: t([e(:DOWN), f, e(:process), s, finite_call]),
      cleanup_observation: cleanup,
      finite_failure_payload: err3,
      original_current_entry: t([atom, s, f, h]),
      manifest_normalization: h,
      manifest_validation_result: t([e(:ok), h]),
      acquisition_control: max(t([e(:cont), t([q, ledger])]), t([e(:halt), err3])),
      partition_scratch: batches,
      checked_config: map_e([store: s, max_config_bytes: e(m), accounting: e(@accounting)]),
      checked_preflight_result:
        Enum.max([t([e(:ok), map_e([count: e(64), bytes: e(q)])]),
                  t([e(:error), e(:invalid_generation_capture)]),
                  t([e(:error), e(:generation_capture_capacity)])]),
      checked_acquisition_failure: err3,
      checked_release_status: max(e(:ok), t([e(:error), e(:generation_pin_release_failed)])),
      cleanup_deadline: d,
      finite_control_status: max(e(:clean), e(:cleanup_unconfirmed)),
      original_deadline: d,
      numeric_m: e(m),
      numeric_retained: e(retained),
      numeric_reservation: e(b),
      numeric_retained_plus_reservation: e(retained + b),
      numeric_next: e(b),
      numeric_iterations: e(64),
      numeric_timing: d
    }
  end

  defp pin_size(provider) do
    fields = [provider: e(provider), owner: 2048, owner_epoch: 2048,
              ref: 2062, operation: 2062, handles: 65_536, kind: e(:request)]
    fields = if provider == UpstreamTransports, do: fields ++ [holder: 2048], else: fields
    map_e(fields)
  end

  defp t(sizes), do: 3 + Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)
  defp l([]), do: 2
  defp l(sizes), do: 7 + Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)
  defp map_e(pairs), do: 6 + Enum.reduce(pairs, 0, fn {key, value}, sum -> sum + e(key) + value - 2 end)
  defp alias_size(ref_size), do: 6 + e(:alias) - 1 + ref_size - 1
  defp from_size(pid_size, ref_size), do: t([pid_size, alias_size(ref_size)])
  defp call_size(payload_size, pid_size, ref_size),
    do: t([e(:"$gen_call"), from_size(pid_size, ref_size), payload_size])
  defp reply_size(payload_size, ref_size), do: t([alias_size(ref_size), payload_size])
  defp e(term), do: :erlang.external_size(term)
  defp call(api, args), do: apply(@accounting, api, args)
  defp context(retained \\ 0), do: {self(), self(), self(), make_ref(), :request, 1, retained}
  defp entry(pin), do: {pin.provider, pin.owner, pin.operation, pin.handles}

  # Complete schema fixtures only; none is claimed to be an actual owner reply.
  # Real public G/T receipt, postcheck and native acceptance remain later gates.
  defp fixtures do
    owner = self()
    epoch = make_ref()
    t = %{provider: UpstreamTransports, owner: owner, owner_epoch: epoch, resource: make_ref()}
    g6 = %{provider: UpstreamGroups, owner: owner, owner_epoch: epoch,
           group: "g", generation: make_ref(), max_url_bytes: 8192}
    g7 = Map.put(g6, :transports, [t])
    g8 = Map.put(g7, :execution_profile, :managed_h2)
    transports = for _ <- 1..32, do: %{t | resource: make_ref()}
    g32 = %{g8 | transports: transports}
    g_pin = %{provider: UpstreamGroups, owner: owner, owner_epoch: epoch,
              ref: make_ref(), operation: make_ref(), handles: [g6], kind: :request}
    t_pin = %{provider: UpstreamTransports, owner: owner, owner_epoch: epoch,
              ref: make_ref(), operation: make_ref(), handles: [t], kind: :request, holder: owner}
    %{g6: g6, g7: g7, g8: g8, g32: g32, t: t, g_pin: g_pin, t_pin: t_pin}
  end

  # Input calibration uses only schema-permitted full group IDs/transports. It
  # chooses operands, never expected preflight results, and asserts exact ETF.
  defp group_handles_at_size(target) do
    f = fixtures()
    transports = for _ <- 1..32, do: %{f.t | resource: make_ref()}
    groups = for _ <- 1..64, do: %{f.g7 | generation: make_ref(), transports: [hd(transports)]}
    step = e(hd(transports)) - 1
    extra = div(target - e(groups), step)
    assert extra >= 0 and extra <= 64 * 31
    grown =
      Enum.with_index(groups, fn group, index ->
        count = 1 + min(31, max(0, extra - index * 31))
        %{group | transports: Enum.take(transports, count)}
      end)
    padding = target - e(grown)
    assert padding >= 0 and padding <= 64 * 127
    handles =
      Enum.with_index(grown, fn group, index ->
        size = 1 + min(127, max(0, padding - index * 127))
        %{group | group: :binary.copy("g", size)}
      end)
    assert e(handles) == target
    handles
  end

  defp group_pin_at_size(target) do
    f = fixtures()
    overhead = e(f.g_pin) - e(f.g_pin.handles)
    pin = %{f.g_pin | handles: group_handles_at_size(target - overhead)}
    assert e(pin) == target
    assert :ok == ManagedH2GroupAccounting.validate({:owner_reply, :group, :pin}, {:ok, pin})
    pin
  end
end

defmodule Gaoxy.Proxy.ManagedGenerationCheckedOwnerTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Generation, Router}
  alias Gaoxy.Proxy.ManagedGenerationAccounting
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  defmodule Endpoint do
    def init(handles), do: {:ok, handles}
    def resources(handles), do: handles
    def call(exchange, _), do: {:ok, exchange}
  end

  setup do
    assert Code.ensure_loaded?(Gaoxy.HTTP.Resources)
    assert function_exported?(Gaoxy.HTTP.Resources, :pin_many_checked, 4), "missing checked acquisition API"
    assert function_exported?(Gaoxy.HTTP.Resources, :release_checked, 3), "missing checked release API"
    assert function_exported?(Generation, :snapshot_for_request, 4), "missing checked snapshot API"
    :ok
  end

  @tag :checked_capture_constructor
  test "real T success then failed postcheck sends its own cancel plus exact Store-ledger cancel" do
    {instance, owner} = owner()
    assert is_pid(instance)
    assert {:ok, handle, preparation} = Transports.prepare(owner, policy_source(), self(), deadline())
    assert {:ok, router} = Router.compile([%{target: {Endpoint, [handle]}}])
    store = start_supervised!({Generation, router: router})
    assert :ok = Gaoxy.HTTP.Resources.release(preparation)
    assert {:ok, %{pins: 1}} = Transports.status(owner)
    assert {:ok, generation, ^router} = Generation.snapshot(store)
    before = :sys.get_state(store)
    observer = self()
    debug_id = make_ref()

    :ok = :sys.install(owner, {debug_id, fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {^store, _}, {:pin_many, batch, holder, :request, operation, d}}} ->
          :erlang.suspend_process(store)
          send(observer, {:real_t_suspended, store, batch, holder, operation, d})
        {:in, {:cancel_pins, ^store, operation}} ->
          send(observer, {:real_t_cancel_received, store, operation})
        _ -> :ok
      end
      state
    end, debug_id})

    assert :erlang.trace(owner, true, [:send, {:tracer, observer}]) == 1
    assert :erlang.trace(store, true, [:send, {:tracer, observer}]) == 1
    d = deadline(300)
    token = make_ref()
    {caller, monitor} = spawn_monitor(fn ->
      result = GenServer.call(store, {:snapshot_for_request, self(), d, ManagedGenerationAccounting}, 3_000)
      send(observer, {token, result})
      receive do :finish -> :ok after 3_000 -> exit(:real_t_requester_not_finished) end
    end)

    try do
      assert_receive {:real_t_suspended, ^store, [^handle], ^caller, operation, ^d}, 1_000
      # A real owner-generated public reply must exist BEFORE D/resume. No fake
      # provider, manufactured receipt, or production test hook can satisfy this.
      assert_receive {:trace, ^owner, :send, {_alias_tag, {:ok, %{
        provider: Transports, owner: ^owner, operation: ^operation,
        handles: [^handle], holder: ^caller, kind: :request
      } = real_pin}}, _destination}, 1_000
      assert is_reference(real_pin.ref)
      assert map_size(real_pin) == 8
      assert {:ok, %{pins: 2}} = Transports.status(owner)
      receive do after max(d - System.monotonic_time(:millisecond), 0) -> :ok end
      resume_from_owner(owner, store)
      assert_receive {^token, {:error, :deadline_exceeded, :cleanup_unconfirmed}}, 1_000

      # Both genuine controls have the SAME original Store acquirer/operation.
      for _ <- 1..2 do
        assert_receive {:trace, ^store, :send, {:cancel_pins, ^store, ^operation}, ^owner}, 1_000
        assert_receive {:real_t_cancel_received, ^store, ^operation}, 1_000
      end
      assert {:ok, %{pins: 1}} = Transports.status(owner)
      # Synchronize trace delivery; a zero-time mailbox check alone is too weak.
      trace_barrier = :erlang.trace_delivered(store)
      assert_receive {:trace_delivered, ^store, ^trace_barrier}, 1_000
      refute_receive {:trace, ^store, :send, {:cancel_pins, ^store, ^operation}, ^owner}, 0
      refute_receive {:real_t_cancel_received, ^store, ^operation}, 0
      assert Process.alive?(caller)
      assert :sys.get_state(store) === before
      assert {:ok, ^generation, ^router} = Generation.snapshot(store)
      refute_receive {^token, {:ok, _, _, _}}, 0
    after
      resume_from_owner(owner, store)
      if Process.alive?(owner) do
        :erlang.trace(owner, false, [:send])
        :sys.remove(owner, debug_id)
      end
      if Process.alive?(store), do: :erlang.trace(store, false, [:send])
      send(caller, :finish)
      receive do
        {:DOWN, ^monitor, :process, ^caller, _} -> :ok
      after
        4_000 -> flunk("real T checked requester did not join")
      end
    end
  end

  defp resume_from_owner(owner, store) do
    if Process.alive?(owner) do
      :sys.replace_state(owner, fn state ->
        if Process.info(store, :status) == {:status, :suspended},
          do: :erlang.resume_process(store)
        state
      end)
    end
  end

  defp owner do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)
    {:ok, owner} = Transports.start_link(instance: instance, limits: %{
      max_resources: 2, max_pins: 8, max_request_tokens: 64, max_owned_payload_bytes: 131_072
    })
    Process.unlink(owner)
    on_exit(fn ->
      actors = if Process.alive?(owner) do
        state = :sys.get_state(owner)
        creators = Enum.map(state.records, fn {_, record} -> record.custodian end)
        helpers = for {_, hold} <- state.tokens, {pid, _} <- [hold.abort_helper], do: pid
        Enum.uniq(creators ++ helpers)
      else
        []
      end
      monitors = Enum.map(actors, &{&1, Process.monitor(&1)})
      if Process.alive?(owner), do: GenServer.stop(owner, :normal, 1_000)
      for {pid, monitor} <- monitors do
        receive do
          {:DOWN, ^monitor, :process, ^pid, _} -> :ok
        after
          6_000 -> flunk("real T owned actor did not join")
        end
      end
      Gaoxy.stop(instance, 100)
    end)
    {instance, owner}
  end

  defp policy_source, do: %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}
  defp deadline(ms \\ 1_000), do: System.monotonic_time(:millisecond) + ms
end
