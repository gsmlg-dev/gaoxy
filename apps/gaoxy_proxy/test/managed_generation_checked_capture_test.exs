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
    {:partition_map, :store, :acquisition_end, 1, 199_551, 199_551},
    {:provider_handle_normalization, :provider, :provider_return, 3, 65536, 196_608},
    {:provider_request_payload, :store, :provider_return, 1, 69676, 69676},
    {:provider_call_wire, :provider, :provider_return, 1, 73811, 73811},
    {:provider_owner_payload, :provider, :provider_return, 1, 69676, 69676},
    {:provider_owner_from, :provider, :provider_return, 1, 4123, 4123},
    {:genuine_provider_pin, :provider, :receipt_validation, 1, 75921, 75921},
    {:provider_result_payload, :provider, :provider_return, 1, 75927, 75927},
    {:provider_reply_wire, :store, :receipt_validation, 1, 78002, 78002},
    {:provider_store_received_result, :store, :receipt_validation, 1, 75927, 75927},
    {:checked_acquisition_accumulator, :store, :snapshot_return, 3, 65542, 196_626},
    {:original_provenance, :store, :acquisition_end, 3, 331_456, 994_368},
    {:store_snapshot_payload, :store, :snapshot_return, 1, 196_612, 196_612},
    {:store_snapshot_wire, :requester, :snapshot_return, 1, 198_687, 198_687},
    {:requester_snapshot_received, :requester, :request_end, 1, 196_612, 196_612},
    {:caller_capture_inputs_and_output, :requester, :request_end, 3, 65536, 196_608},
    {:release_payload, :requester, :release_return, 1, 65541, 65541},
    {:release_call_wire, :provider, :release_return, 1, 69676, 69676},
    {:release_reply_wire, :requester, :release_return, 1, 2116, 2116},
    {:cancel_control, :provider, :cancellation_uncertain, 65, 4124, 268_060},
    {:known_call_failure_descriptor, :caller, :call_return, 1, 71829, 71829},
    {:known_monitor_down, :caller, :call_return, 1, 4187, 4187},
    {:cleanup_observation, :requester, :emit_return, 2, 6276, 12552},
    {:finite_failure_payload, :requester, :request_end, 1, 62, 62},
    {:original_current_entry, :store, :acquisition_end, 1, 69685, 69685},
    {:manifest_normalization, :store, :acquisition_end, 2, 65536, 131_072},
    {:manifest_validation_result, :store, :acquisition_end, 1, 65542, 65542},
    {:acquisition_control, :store, :acquisition_end, 3, 397_001, 1_191_003},
    {:partition_scratch, :store, :acquisition_end, 2, 199_551, 399_102},
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
             Enum.sort(
               ~w(qualification profile m retained bounds roles total fixed_point_iterations prerequisites)a
             )

    assert report.qualification == :conditional_not_runtime_ready
    assert report.profile == :native_generation_checked_capture
    assert report.m == 65_536
    assert report.retained == 0
    assert report.total == 5_350_589
    assert report.fixed_point_iterations == 2
    assert report.prerequisites == @prerequisites

    assert report.bounds == %{
             h: 65_536,
             q: 65_536,
             s: 2048,
             k: 64,
             future_ref: 2062,
             g_pin: 73862,
             t_pin: 75921,
             genuine_pin: 75921,
             g_singleton: 73868,
             t_singleton: 75927,
             cancel_controls: 65
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

    assert l([]) == 2
    assert e(0) == 3
    assert e(255) == 3
    assert e(256) == 6
    assert e(2_147_483_647) == 6
    assert e(2_147_483_648) == 8
    assert t([e(:deadline_exceeded), e(:cleanup_pending)]) == 39
    assert t([e(:error), Enum.max(Enum.map(@finite, &e/1)), e(:cleanup_unconfirmed)]) == 62

    inner_plan =
      t([e(:native_generation_capture_v1), e(65_536), e(65_536), e(65_536), e(5_350_589)])

    assert inner_plan == 53
    assert t([e(:ok), inner_plan]) == 59
    assert t([e(:error), e(:invalid_generation_capture)]) == 38
    assert t([e(:error), e(:generation_capture_capacity)]) == 39
    assert t([e(:ok), map_e(count: e(64), bytes: e(65_536))]) == 33
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
      {1, 4_957_367, 2},
      {255, 4_958_891, 2},
      {256, 4_958_909, 2},
      {65536, 5_350_589, 2},
      {1_048_576, 11_248_829, 2},
      {357_087_712, 2_147_483_645, 2},
      {357_087_713, 2_147_483_669, 3},
      {357_087_715, 2_147_483_681, 3},
      {357_087_716, 2_147_483_687, 3},
      {2_147_483_647, 12_889_859_282, 2},
      {2_147_483_648, 12_889_859_296, 2},
      {4_294_967_295, 25_774_761_178, 2},
      {4_294_967_296, 25_774_761_188, 2},
      {18_446_744_073_709_551_616, 110_680_464_442_262_267_160, 2}
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
      {0, 5_350_589, 2},
      {255, 5_350_589, 2},
      {256, 5_350_598, 2},
      {2_142_133_049, 5_350_598, 2},
      {2_142_133_050, 5_350_606, 3},
      {2_142_133_067, 5_350_606, 2},
      {2_142_133_068, 5_350_606, 2},
      {2_147_483_647, 5_350_606, 2},
      {2_147_483_648, 5_350_612, 2},
      {4_294_967_295, 5_350_616, 2},
      {4_294_967_296, 5_350_619, 2},
      {18_446_744_073_709_551_615, 5_350_644, 2},
      {18_446_744_073_709_551_616, 5_350_647, 2}
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

    too_many_transports = %{
      f.g32
      | transports: f.g32.transports ++ [%{f.t | resource: make_ref()}]
    }

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
          nil,
          :handles,
          %{count: 0, bytes: 2},
          [f.g6 | :improper],
          [%{f.g6 | provider: UnknownProvider}],
          [Map.put(f.g6, :extra, :x)],
          [Map.put(f.t, :extra, :x)],
          [%{f.g6 | owner: make_ref()}],
          [%{f.g6 | owner_epoch: self()}],
          [%{f.t | resource: self()}],
          [%{f.g6 | generation: self()}],
          [%{f.g6 | max_url_bytes: 8193}],
          [%{f.g6 | group: ""}],
          [f.g6, other_epoch]
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
          %{pin | handles: Enum.reverse(pin.handles)},
          %{pin | handles: [f.g6]},
          %{pin | handles: [f.g6, %{second | group: "changed"}]},
          Map.put(pin, :holder, self()),
          Map.put(pin, :extra, :x),
          Map.delete(pin, :operation),
          %{pin | handles: [f.g6 | :improper]}
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

    for original <- [
          nil,
          [],
          {:partial, self()},
          {UpstreamGroups, :owner, f.g_pin.operation, f.g_pin.handles},
          {UpstreamGroups, self(), self(), f.g_pin.handles},
          {UnknownProvider, self(), f.g_pin.operation, f.g_pin.handles},
          {UpstreamGroups, self(), f.g_pin.operation, []}
        ] do
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

    for bad <- [
          %{count: 0, bytes: 2},
          %{count: 1, bytes: 1, pins: [f.g_pin]},
          [f.g_pin | :improper],
          List.duplicate(f.g_pin, 65),
          nil
        ] do
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

    provider_call =
      max(
        t([e(:pin), h, s, e(:request), f, d]),
        t([e(:pin_many), h, s, e(:request), f, d])
      )

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
      t([
        l([e(:gaoxy), e(:generation_capture_cleanup)]),
        map_e(count: e(1)),
        map_e(
          store: s,
          holder: s,
          lease: s,
          stage: max(e(:release), e(:acquisition)),
          cleanup: e(:cleanup_unconfirmed)
        )
      ])

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
      checked_config: map_e(store: s, max_config_bytes: e(m), accounting: e(@accounting)),
      checked_preflight_result:
        Enum.max([
          t([e(:ok), map_e(count: e(64), bytes: e(q))]),
          t([e(:error), e(:invalid_generation_capture)]),
          t([e(:error), e(:generation_capture_capacity)])
        ]),
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
    fields = [
      provider: e(provider),
      owner: 2048,
      owner_epoch: 2048,
      ref: 2062,
      operation: 2062,
      handles: 65_536,
      kind: e(:request)
    ]

    fields = if provider == UpstreamTransports, do: fields ++ [holder: 2048], else: fields
    map_e(fields)
  end

  defp t(sizes), do: 3 + Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)
  defp l([]), do: 2
  defp l(sizes), do: 7 + Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)

  defp map_e(pairs),
    do: 6 + Enum.reduce(pairs, 0, fn {key, value}, sum -> sum + e(key) + value - 2 end)

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

    g6 = %{
      provider: UpstreamGroups,
      owner: owner,
      owner_epoch: epoch,
      group: "g",
      generation: make_ref(),
      max_url_bytes: 8192
    }

    g7 = Map.put(g6, :transports, [t])
    g8 = Map.put(g7, :execution_profile, :managed_h2)
    transports = for _ <- 1..32, do: %{t | resource: make_ref()}
    g32 = %{g8 | transports: transports}

    g_pin = %{
      provider: UpstreamGroups,
      owner: owner,
      owner_epoch: epoch,
      ref: make_ref(),
      operation: make_ref(),
      handles: [g6],
      kind: :request
    }

    t_pin = %{
      provider: UpstreamTransports,
      owner: owner,
      owner_epoch: epoch,
      ref: make_ref(),
      operation: make_ref(),
      handles: [t],
      kind: :request,
      holder: owner
    }

    %{g6: g6, g7: g7, g8: g8, g32: g32, t: t, g_pin: g_pin, t_pin: t_pin}
  end

  # Input calibration uses only schema-permitted full group IDs/transports. It
  # chooses operands, never expected preflight results, and asserts exact ETF.
  defp group_handles_at_size(target, f \\ fixtures()) do
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
    pin = %{f.g_pin | handles: group_handles_at_size(target - overhead, f)}
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

    assert function_exported?(Gaoxy.HTTP.Resources, :pin_many_checked, 4),
           "missing checked acquisition API"

    assert function_exported?(Gaoxy.HTTP.Resources, :release_checked, 3),
           "missing checked release API"

    assert Code.ensure_loaded?(Generation)

    assert function_exported?(Generation, :snapshot_for_request, 4),
           "missing checked snapshot API"

    :ok
  end

  @tag :checked_capture_constructor
  test "real T success then failed postcheck sends its own cancel plus exact Store-ledger cancel" do
    {instance, owner} = owner()
    assert is_pid(instance)

    assert {:ok, handle, preparation} =
             Transports.prepare(owner, policy_source(), self(), deadline())

    assert {:ok, router} = Router.compile([%{target: {Endpoint, [handle]}}])
    store = start_supervised!({Generation, router: router})
    assert :ok = Gaoxy.HTTP.Resources.release(preparation)
    assert {:ok, %{pins: 1}} = Transports.status(owner)
    assert {:ok, generation, ^router} = Generation.snapshot(store)
    before = :sys.get_state(store)
    observer = self()
    debug_id = make_ref()

    :ok =
      :sys.install(
        owner,
        {debug_id,
         fn state, event, _ ->
           case event do
             {:in,
              {:"$gen_call", {^store, _}, {:pin_many, batch, holder, :request, operation, d}}} ->
               :erlang.suspend_process(store)
               send(observer, {:real_t_suspended, store, batch, holder, operation, d})

             {:in, {:cancel_pins, ^store, operation}} ->
               send(observer, {:real_t_cancel_received, store, operation})

             _ ->
               :ok
           end

           state
         end, debug_id}
      )

    assert :erlang.trace(owner, true, [:send, {:tracer, observer}]) == 1
    assert :erlang.trace(store, true, [:send, {:tracer, observer}]) == 1
    d = deadline(300)
    token = make_ref()

    {caller, monitor} =
      spawn_monitor(fn ->
        result =
          GenServer.call(
            store,
            {:snapshot_for_request, self(), d, ManagedGenerationAccounting},
            3_000
          )

        send(observer, {token, result})

        receive do
          :finish -> :ok
        after
          3_000 -> exit(:real_t_requester_not_finished)
        end
      end)

    try do
      assert_receive {:real_t_suspended, ^store, [^handle], ^caller, operation, ^d}, 1_000
      # A real owner-generated public reply must exist BEFORE D/resume. No fake
      # provider, manufactured receipt, or production test hook can satisfy this.
      assert_receive {:trace, ^owner, :send,
                      {_alias_tag,
                       {:ok,
                        %{
                          provider: Transports,
                          owner: ^owner,
                          operation: ^operation,
                          handles: [^handle],
                          holder: ^caller,
                          kind: :request
                        } = real_pin}}, _destination},
                     1_000

      assert is_reference(real_pin.ref)
      assert map_size(real_pin) == 8
      assert {:ok, %{pins: 2}} = Transports.status(owner)

      receive do
      after
        max(d - System.monotonic_time(:millisecond), 0) -> :ok
      end

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

    {:ok, owner} =
      Transports.start_link(
        instance: instance,
        limits: %{
          max_resources: 2,
          max_pins: 8,
          max_request_tokens: 64,
          max_owned_payload_bytes: 131_072
        }
      )

    Process.unlink(owner)

    on_exit(fn ->
      actors =
        if Process.alive?(owner) do
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

  defp policy_source,
    do: %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}

  defp deadline(ms \\ 1_000), do: System.monotonic_time(:millisecond) + ms
end

defmodule Gaoxy.Proxy.ManagedGenerationCheckedNativeTest do
  use ExUnit.Case, async: false

  alias Gaoxy.{Admission, Lifecycle}
  alias Gaoxy.HTTP.{Exchange, Generation, Resources, Router}
  alias Gaoxy.Proxy.{GroupEndpoint, ManagedGenerationAccounting, UpstreamGroups}
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias HTTP.HTTP2.HPACK

  @moduletag :capture_log
  @timeout 5_000
  @fixture_timeout 30_000
  @m 1_048_576
  @h 65_536

  # A test Router boundary around a genuine H1 GroupEndpoint. The listener's
  # endpoint is directly the production checked Generation seam.
  defmodule CapturedEndpoint do
    def init({group, parent, label}) do
      with {:ok, config} <- GroupEndpoint.init(%{group: group}),
           do: {:ok, {config, parent, label}}
    end

    def resources({config, _, _}), do: GroupEndpoint.resources(config)

    def call(exchange, {config, parent, label}) do
      token = make_ref()
      send(parent, {:checked_native_capture, self(), token, label, exchange})

      receive do
        {:checked_dispatch, ^token} -> GroupEndpoint.call(exchange, config)
      after
        min(10_000, Lifecycle.remaining(exchange.deadline)) ->
          {:error, :checked_native_fixture_barrier_expired, exchange}
      end
    end
  end

  # Supported test endpoint manifest, used only by direct checked Store tests.
  # Its resource list is exactly public owner handles; it never creates a pin.
  defmodule ManifestEndpoint do
    def init({handles, parent}), do: {:ok, {handles, parent}}
    def resources({handles, _}), do: handles

    def call(exchange, {_, parent}) do
      send(parent, {:unexpected_checked_manifest_dispatch, self()})
      {:ok, exchange}
    end
  end

  @tag :checked_capture_constructor
  test "checked Store returns genuine public G7 and T8 receipts with original correlation and bounded release" do
    f = fixture()
    peer = peer(:genuine)
    {t, tp} = prepare_transport(f, peer.source)
    {g, gp} = prepare_group(f, peer.source, [t], "genuine")
    router = manifest_router([g, t])
    store = start_store(router)
    assert :ok == Resources.release(gp ++ tp)
    await_healthy(g)
    eventually(fn -> UpstreamGroups.status(g).pins == 1 and transport_pins(f) == 1 end)
    observe_owners(f, store, :observe)
    trace_replies(f)
    d = deadline()

    assert {:ok, generation, ^router, pins} =
             Generation.snapshot_for_request(store, self(), d, ManagedGenerationAccounting)

    assert generation == router.generation

    assert [%{provider: UpstreamGroups} = gpin] =
             Enum.filter(pins, &(&1.provider == UpstreamGroups))

    assert [%{provider: Transports} = tpin] = Enum.filter(pins, &(&1.provider == Transports))
    assert map_size(gpin) == 7
    assert map_size(tpin) == 8
    refute Map.has_key?(gpin, :holder)
    assert tpin.holder === self()

    originals =
      for _ <- 1..2 do
        assert_receive {:checked_owner_input, owner, ^store, batch, holder, operation, ^d, nil},
                       @timeout

        assert holder === self()
        %{owner: owner, handles: batch, holder: holder, operation: operation}
      end

    for pin <- [gpin, tpin] do
      original = Enum.find(originals, &(&1.owner === pin.owner))
      assert pin.operation === original.operation
      assert pin.handles === original.handles

      assert :ok ==
               ManagedGenerationAccounting.correlate(
                 pin,
                 {pin.provider, original.owner, original.operation, original.handles},
                 original.holder
               )

      assert_owned_reply(pin)
      assert_pin_algebra(pin)
    end

    assert :ok == Resources.release_checked(pins, deadline(), ManagedGenerationAccounting)
    eventually(fn -> UpstreamGroups.status(g).pins == 1 and transport_pins(f) == 1 end)
    stop_store(store)
    finish(f, [peer], [])
    refute_receive {:unexpected_checked_manifest_dispatch, _}, 0
  end

  @tag :checked_capture_constructor
  @tag timeout: 120_000
  test "real near H G H1 public manifest yields genuine singleton above Q before checked cons" do
    # This constructor case needs genuine prepared handles without dispatch.
    # Keep unrelated health traffic outside its supported probe budget so
    # releasing the sample/final anchors cannot cancel an in-flight peer reply.
    f = fixture(probe_bytes: 1)
    assert :sys.get_state(f.groups).limits.probe_bytes == 1
    peer = peer(:above_q)
    prepared = for _ <- 1..32, do: prepare_transport(f, peer.source)
    transports = Enum.map(prepared, &elem(&1, 0))
    transport_preparation = Enum.flat_map(prepared, &elem(&1, 1))
    [first_t | _] = transports

    # Measure one REAL prepared handle, then choose supported member counts and
    # group ID lengths. All final handles are freshly returned by public prepare.
    {sample, sample_pins} = prepare_group(f, peer.source, [first_t], "samp")
    base_bytes = 7 + 64 * (e(sample) - 1)
    step = e(first_t) - 1
    extra = div(@h - base_bytes, step)
    padding = @h - base_bytes - extra * step
    assert extra in 0..(64 * 31)
    assert padding in 0..(64 * 124)
    assert :ok == Resources.release(sample_pins)
    eventually(fn -> UpstreamGroups.status(sample) == {:error, :stale_group} end)

    groups =
      for index <- 0..63 do
        count = 1 + min(31, max(0, extra - index * 31))
        pad = min(124, max(0, padding - index * 124))
        id = "g" <> String.pad_leading(Integer.to_string(index), 3, "0") <> :binary.copy("x", pad)
        prepare_group(f, peer.source, Enum.take(transports, count), id)
      end

    handles = Enum.map(groups, &elem(&1, 0))
    group_preparation = Enum.flat_map(groups, &elem(&1, 1))
    [first_g | _] = handles
    assert e(handles) == @h
    assert {:ok, ^handles} = Resources.validate(handles)
    assert :ok == ManagedGenerationAccounting.validate_manifest(handles)
    assert Enum.all?(handles, &(map_size(&1) == 7 and UpstreamGroups.valid_handle?(&1)))
    router = manifest_router(handles)
    store = start_store(router)
    # T preparations intentionally remain held: this no-dispatch manifest test
    # exposes only real G handles and must not retire their genuine dependencies.
    assert :ok == Resources.release(group_preparation)
    assert %{pins: baseline_pins, probes: 0, probe_bytes: 0} = UpstreamGroups.status(first_g)
    assert baseline_pins == 1
    observe_owners(f, store, :observe)
    trace_replies(f)
    assert :erlang.trace(store, true, [:send, {:tracer, self()}]) == 1
    on_exit(fn -> if Process.alive?(store), do: :erlang.trace(store, false, [:send]) end)
    d = deadline()

    assert {:error, :generation_capture_capacity, :cleanup_unconfirmed} ==
             Generation.snapshot_for_request(store, self(), d, ManagedGenerationAccounting)

    owner = f.groups

    assert_receive {:checked_owner_input, ^owner, ^store, ^handles, holder, operation, ^d, nil},
                   @timeout

    assert holder === self()

    assert_receive {:trace, ^owner, :send, {tag, {:ok, %{operation: ^operation} = pin}} = wire,
                    _},
                   @timeout

    assert pin.provider === UpstreamGroups
    assert pin.owner === owner
    assert pin.handles === handles
    assert pin.kind === :request
    assert map_size(pin) == 7

    assert :ok ==
             ManagedGenerationAccounting.correlate(
               pin,
               {UpstreamGroups, owner, operation, handles},
               self()
             )

    assert_pin_algebra(pin)
    assert e(wire) == tuple_size_etf([e(tag), tuple_size_etf([e(:ok), e(pin)])])
    assert e([pin]) == e(pin) + 6
    assert e([pin]) > @h
    assert e(pin) <= 73_862

    assert {:error, :generation_capture_capacity} ==
             ManagedGenerationAccounting.preflight_cons(pin, [])

    assert_receive {:trace, ^store, :send, {:cancel_pin, ^store, ^operation}, ^owner}, @timeout
    assert_receive {:checked_original_cancel, ^owner, ^store, ^operation}, @timeout
    # A sent cancellation is uncertainty at the checked API boundary. Only a
    # subsequent public owner status corroborates that this real hold settled.
    eventually(fn -> UpstreamGroups.status(first_g).pins == baseline_pins end)
    assert {:ok, generation, ^router} = Generation.snapshot(store)
    assert generation === router.generation
    refute_receive {:unexpected_checked_manifest_dispatch, _}, 0
    assert %{probes: 0, probe_bytes: 0} = UpstreamGroups.status(first_g)
    stop_store(store)
    finish(f, [peer], transport_preparation)
  end

  for protocol <- [:http1, :http2] do
    @protocol protocol
    @tag :checked_capture_runtime
    @tag timeout: 120_000
    test "#{protocol} checked native old and new captures pay Admission before real owners and finish wire cleanup" do
      run_native(@protocol)
    end
  end

  defp run_native(protocol) do
    f = fixture()
    old_peer = peer(:old)
    new_peer = peer(:new)
    old = candidate(f, old_peer.source, :old)
    store = start_store(old.router)
    assert :ok == Resources.release(old.preparation)
    await_healthy(old.group)
    eventually(fn -> transport_pins(f) == 1 and UpstreamGroups.status(old.group).pins == 1 end)
    observe_owners(f, store, {:hold, :http})
    trace_replies(f)
    add_listener(f, store, protocol)
    socket = connect(f.instance)
    baseline = protocol_baseline(socket, f.instance, protocol)
    send_request(socket, protocol, 1, "/old%2Fpath?raw=%2F")
    first = capture_native(f, store, protocol, socket, baseline, old, 1)
    old_native = first.native
    old_monitor = Process.monitor(old_native)
    assert_native_identity(protocol, first.exchange)

    # Retain the actual old checked snapshot while replacing Store baseline.
    next = candidate(f, new_peer.source, :new)
    await_healthy(next.group)

    assert {:ok, next_generation} =
             Generation.activate(store, old.router.generation, next.router, @timeout)

    assert next_generation === next.router.generation
    assert :ok == Resources.release(next.preparation)
    assert {:ok, ^next_generation, next_router} = Generation.snapshot(store)
    assert next_router === next.router
    assert Enum.any?(first.exchange.resource_pins, &(old.group in &1.handles))
    send(first.native, {:checked_dispatch, first.token})
    assert_receive {:checked_peer_request, :old, worker, head}, @timeout
    assert head =~ "GET /old%2Fpath?raw=%2F HTTP/1.1\r\n"
    refute_receive {:checked_peer_request, :new, _, _}, 0
    send(worker, {:respond, "old-body"})
    assert response(socket, protocol, 1) == {200, "old-body"}
    assert_native_down(protocol, old_native, old_monitor)
    eventually(fn -> transport_pins(f) == 1 and UpstreamGroups.status(next.group).pins == 1 end)

    socket = if protocol == :http1, do: connect(f.instance), else: socket

    baseline =
      if protocol == :http1 do
        %{active: 0, retained_bytes: 0}
      else
        eventually(fn ->
          status = Gaoxy.status(f.instance, :http)
          status.active == baseline.active and status.retained_bytes == baseline.retained_bytes
        end)

        Gaoxy.status(f.instance, :http)
      end

    send_request(socket, protocol, 3, "/new%2Fpath?")
    fresh = capture_native(f, store, protocol, socket, baseline, next, 3)
    fresh_monitor = Process.monitor(fresh.native)
    refute fresh.native === old_native
    send(fresh.native, {:checked_dispatch, fresh.token})
    assert_receive {:checked_peer_request, :new, next_worker, next_head}, @timeout
    assert next_head =~ "GET /new%2Fpath? HTTP/1.1\r\n"
    send(next_worker, {:respond, "new-body"})
    assert response(socket, protocol, 3) == {200, "new-body"}
    assert_native_down(protocol, fresh.native, fresh_monitor)
    :ok = :gen_tcp.close(socket)

    eventually(fn ->
      match?(
        %{active: 0, cleanup_pending: 0, retained_bytes: 0},
        Gaoxy.status(f.instance, :http)
      )
    end)

    eventually(fn -> transport_pins(f) == 1 and UpstreamGroups.status(next.group).pins == 1 end)
    stop_store(store)
    finish(f, [old_peer, new_peer], [])
  end

  defp fixture(options \\ []) do
    {:ok, instance} = Gaoxy.start_link()
    Process.unlink(instance)

    {:ok, transports} =
      Transports.start_link(
        instance: instance,
        limits: %{
          max_resources: 32,
          max_pins: 4096,
          max_request_tokens: 64,
          max_owned_payload_bytes: 67_108_864
        }
      )

    Process.unlink(transports)

    {:ok, groups} =
      UpstreamGroups.start_link(
        instance: instance,
        limits: %{
          max_groups: 64,
          max_pins: 1024,
          max_probes: 1,
          probe_bytes: Keyword.get(options, :probe_bytes, 67_108_864),
          max_config_bytes: 67_108_864
        }
      )

    Process.unlink(groups)

    on_exit(fn ->
      for pid <- [groups, transports], Process.alive?(pid) do
        send(pid, :checked_fixture_unblock)
      end

      for pid <- [groups, instance, transports], Process.alive?(pid) do
        Lifecycle.protect(fn -> GenServer.stop(pid, :normal, @timeout) end)
      end
    end)

    %{instance: instance, transports: transports, groups: groups}
  end

  defp prepare_transport(f, source) do
    assert {:ok, handle, preparation} =
             Transports.prepare(f.transports, source, self(), deadline(@fixture_timeout))

    {handle, preparation}
  end

  defp prepare_group(f, source, transports, id) do
    members =
      for {transport, index} <- Enum.with_index(transports),
          do: %{
            id: "m#{index}",
            upstream: source.origin,
            transport: transport,
            connect_address: nil
          }

    assert {:ok, compiled} =
             UpstreamGroups.compile(%{
               id: id,
               members: members,
               health: %{
                 path: "/health",
                 interval: 60_000,
                 stale_after: 120_000,
                 timeout: 2_000,
                 jitter: 0,
                 recovery_threshold: 1
               }
             })

    assert {:ok, handle, preparation} =
             UpstreamGroups.prepare(f.groups, compiled, self(), deadline(@fixture_timeout))

    assert map_size(handle) == 7
    {handle, preparation}
  end

  defp candidate(f, source, label) do
    {transport, tp} = prepare_transport(f, source)
    {group, gp} = prepare_group(f, source, [transport], Atom.to_string(label))
    assert {:ok, router} = Router.compile([%{target: {CapturedEndpoint, {group, self(), label}}}])
    %{transport: transport, group: group, router: router, preparation: gp ++ tp, label: label}
  end

  defp manifest_router(handles) do
    assert {:ok, router} = Router.compile([%{target: {ManifestEndpoint, {handles, self()}}}])
    router
  end

  defp start_store(router) do
    assert {:ok, store} = Generation.start_link(router: router, max_config_bytes: @m)
    Process.unlink(store)
    on_exit(fn -> if Process.alive?(store), do: GenServer.stop(store, :normal, @timeout) end)
    store
  end

  defp stop_store(store) do
    monitor = Process.monitor(store)
    assert :ok == GenServer.stop(store, :normal, @timeout)
    assert_receive {:DOWN, ^monitor, :process, ^store, :normal}, @timeout
  end

  defp observe_owners(f, store, mode) do
    parent = self()

    for owner <- [f.groups, f.transports] do
      id = make_ref()

      :ok =
        :sys.install(
          owner,
          {id,
           fn state, event, _ ->
             case event do
               {:in, {:"$gen_call", {^store, _}, {tag, batch, holder, :request, operation, d}}}
               when tag in [:pin, :pin_many] ->
                 status =
                   case mode do
                     {:hold, service} -> Gaoxy.status(f.instance, service)
                     :observe -> nil
                   end

                 send(
                   parent,
                   {:checked_owner_input, owner, store, batch, holder, operation, d, status}
                 )

                 if mode != :observe do
                   receive do
                     {:checked_owner_continue, ^operation} -> :ok
                     :checked_fixture_unblock -> :ok
                   after
                     @timeout -> raise "checked genuine owner fixture barrier expired"
                   end
                 end

               {:in, {tag, ^store, operation}} when tag in [:cancel_pin, :cancel_pins] ->
                 send(parent, {:checked_original_cancel, owner, store, operation})

               _ ->
                 :ok
             end

             state
           end, id}
        )

      on_exit(fn ->
        if Process.alive?(owner) do
          send(owner, :checked_fixture_unblock)
          :sys.remove(owner, id)
        end
      end)
    end
  end

  defp trace_replies(f) do
    for owner <- [f.groups, f.transports] do
      assert :erlang.trace(owner, true, [:send, {:tracer, self()}]) == 1
      on_exit(fn -> if Process.alive?(owner), do: :erlang.trace(owner, false, [:send]) end)
    end
  end

  defp assert_owned_reply(pin) do
    owner = pin.owner
    operation = pin.operation

    assert_receive {:trace, ^owner, :send,
                    {tag, {:ok, %{operation: ^operation} = observed}} = wire, _},
                   @timeout

    assert observed === pin
    assert e(wire) == tuple_size_etf([e(tag), tuple_size_etf([e(:ok), e(pin)])])
  end

  defp assert_pin_algebra(pin) do
    fields = Map.to_list(pin)
    expected = 6 + Enum.reduce(fields, 0, fn {k, v}, sum -> sum + e(k) + e(v) - 2 end)
    assert e(pin) == expected
    assert e({:ok, pin}) == tuple_size_etf([e(:ok), e(pin)])
    assert e([pin]) == 7 + e(pin) - 1
  end

  defp add_listener(f, store, protocol) do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Generation, {store, accounting: ManagedGenerationAccounting}},
               protocols: [protocol],
               h2c: if(protocol == :http2, do: :prior_knowledge, else: :disabled),
               limits: %{max_bytes: 536_870_912},
               http_limits: %{request_timeout: 15_000}
             )

    assert {:ok, _} = Gaoxy.add(f.instance, spec)
  end

  defp capture_native(f, store, protocol, socket, baseline, candidate, _stream) do
    originals =
      for index <- 1..2 do
        assert_receive {:checked_owner_input, owner, ^store, batch, native, operation, d, status},
                       @timeout

        assert is_pid(native)
        assert Lifecycle.remaining(d) > 0
        assert status.retained_bytes >= 11_248_829

        if index == 1 do
          if protocol == :http2 do
            assert_ping(socket, "holdping")
          else
            sibling = connect(f.instance)
            eventually(fn -> Gaoxy.status(f.instance, :http).active == 2 end)
            :ok = :gen_tcp.close(sibling)
            eventually(fn -> Gaoxy.status(f.instance, :http).active == 1 end)
          end
        end

        send(owner, {:checked_owner_continue, operation})

        %{
          owner: owner,
          handles: batch,
          holder: native,
          operation: operation,
          deadline: d,
          status: status
        }
      end

    label = candidate.label
    assert_receive {:checked_native_capture, native, token, ^label, exchange}, @timeout
    on_exit(fn -> send(native, {:checked_dispatch, token}) end)
    assert_native_identity(protocol, exchange)
    assert Enum.all?(originals, &(&1.holder === native and &1.deadline === exchange.deadline))
    assert Enum.count(exchange.resource_pins) == 2

    assert MapSet.new(Enum.flat_map(exchange.resource_pins, & &1.handles)) ==
             MapSet.new([candidate.group, candidate.transport])

    # This scalar forecast is independently checked by Task1/3.5. These tests
    # are runtime-tagged and may execute only AFTER that whole source gate.
    retained = Exchange.retained_bytes(exchange) - exchange.route_bytes
    b = expected_default_b(retained)
    assert exchange.route_bytes == b

    assert {:ok, {:native_generation_capture_v1, @m, @h, @h, ^b}} =
             ManagedGenerationAccounting.reservation(
               @m,
               {store, native, exchange.gate, exchange.lease, :request, exchange.deadline,
                retained}
             )

    overhead = if protocol == :http2, do: baseline.retained_bytes, else: 0
    expected_charge = overhead + retained + b
    assert Enum.all?(originals, &(&1.status.retained_bytes == expected_charge))
    assert Admission.status(exchange.gate).retained_bytes == expected_charge
    assert Gaoxy.status(f.instance, :http).retained_bytes == expected_charge

    for pin <- exchange.resource_pins do
      original = Enum.find(originals, &(&1.owner === pin.owner))
      assert original.handles === pin.handles

      assert :ok ==
               ManagedGenerationAccounting.correlate(
                 pin,
                 {pin.provider, original.owner, original.operation, original.handles},
                 native
               )

      if pin.provider == Transports, do: assert(pin.holder === native)
      assert_owned_reply(pin)
      assert_pin_algebra(pin)
    end

    %{native: native, token: token, exchange: exchange}
  end

  defp expected_default_b(retained), do: expected_default_b(retained, 0, 0)

  defp expected_default_b(retained, b, iterations) when iterations < 64 do
    next =
      6 * @m + 4_957_373 + 3 * (e(retained) - 3) +
        5 * (e(b) - 6) + 4 * (e(retained + b) - 6)

    if next == b, do: b, else: expected_default_b(retained, next, iterations + 1)
  end

  defp expected_default_b(_, _, _), do: flunk("independent default B did not converge")

  defp assert_native_identity(:http1, exchange), do: assert(exchange.transport == nil)

  defp assert_native_identity(:http2, exchange) do
    assert exchange.transport == Gaoxy.HTTP.HTTP2.Transport
    assert {connection, id, token} = exchange.transport_state
    assert is_pid(connection)
    assert id in [1, 3]
    assert is_reference(token)
  end

  defp assert_native_down(:http1, native, monitor) do
    assert_receive {:DOWN, ^monitor, :process, ^native, {:shutdown, :local_closed}}, @timeout
  end

  defp assert_native_down(:http2, native, monitor) do
    assert_receive {:DOWN, ^monitor, :process, ^native, :normal}, @timeout
  end

  defp await_healthy(group) do
    eventually(fn ->
      match?(
        %{members: [%{health: :healthy, probe: false}], probes: 0},
        UpstreamGroups.status(group)
      )
    end)
  end

  defp transport_pins(f) do
    assert {:ok, status} = Transports.status(f.transports)
    status.pins
  end

  defp finish(f, peers, preparations) do
    assert :ok == Resources.release(preparations)

    eventually(
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
          Transports.status(f.transports)
        )
      end,
      deadline(@fixture_timeout)
    )

    monitor = Process.monitor(f.groups)
    assert :ok == GenServer.stop(f.groups, :normal, @timeout)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout
    monitor = Process.monitor(f.transports)
    assert :ok == Gaoxy.stop(f.instance, @timeout)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}, @timeout

    for peer <- peers do
      :ok = :gen_tcp.close(peer.listener)
      pid = peer.pid
      monitor = peer.monitor
      assert_receive {:checked_peer_joined, ^pid, :ok}, @timeout
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, @timeout
    end
  end

  defp peer(label) do
    assert {:ok, listener} =
             :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    assert {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    {pid, monitor} = spawn_monitor(fn -> accept_loop(listener, parent, label, []) end)

    on_exit(fn ->
      :gen_tcp.close(listener)

      if Process.alive?(pid) do
        failure_monitor = Process.monitor(pid)

        receive do
          {:DOWN, ^failure_monitor, :process, ^pid, _} -> :ok
        after
          2 * @timeout ->
            flunk("checked peer and owned workers did not join during fixture cleanup")
        end
      end
    end)

    %{
      pid: pid,
      monitor: monitor,
      listener: listener,
      source: %{origin: "http://localhost:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}
    }
  end

  defp accept_loop(listener, parent, label, workers) do
    case :gen_tcp.accept(listener, 50) do
      {:ok, socket} ->
        peer = self()

        {worker, monitor} =
          spawn_monitor(fn ->
            receive do
              :checked_socket_ready ->
                result =
                  try do
                    serve_peer(socket, parent, label)
                  after
                    :gen_tcp.close(socket)
                  end

                send(peer, {:checked_worker_done, self(), result})
            after
              @timeout -> exit(:checked_peer_transfer_expired)
            end
          end)

        assert :ok == :gen_tcp.controlling_process(socket, worker)
        send(worker, :checked_socket_ready)
        accept_loop(listener, parent, label, [{worker, monitor} | workers])

      {:error, :timeout} ->
        accept_loop(listener, parent, label, workers)

      {:error, :closed} ->
        for {worker, monitor} <- workers do
          assert_receive {:checked_worker_done, ^worker, :ok}, @timeout
          assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
        end

        send(parent, {:checked_peer_joined, self(), :ok})
    end
  end

  defp serve_peer(socket, parent, label) do
    case :gen_tcp.recv(socket, 1, @timeout) do
      {:ok, first} ->
        head = read_head(socket, first)

        if String.starts_with?(head, "HEAD /health HTTP/1.1\r\n") do
          :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        else
          send(parent, {:checked_peer_request, label, self(), head})

          receive do
            {:respond, body} ->
              :ok =
                :gen_tcp.send(socket, [
                  "HTTP/1.1 200 OK\r\nContent-Length: #{byte_size(body)}\r\n\r\n",
                  body
                ])
          after
            @timeout -> exit(:checked_peer_response_expired)
          end
        end

        serve_peer(socket, parent, label)

      {:error, :timeout} ->
        serve_peer(socket, parent, label)

      {:error, :closed} ->
        :ok
    end
  end

  defp connect(instance) do
    assert {:ok, {ip, port}} = Gaoxy.info(instance, :http).local
    assert {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp protocol_baseline(_socket, _instance, :http1), do: %{active: 0, retained_bytes: 0}

  defp protocol_baseline(socket, instance, :http2) do
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    assert_ping(socket, "baseline")
    Gaoxy.status(instance, :http)
  end

  defp send_request(socket, :http1, _id, path) do
    :ok =
      :gen_tcp.send(
        socket,
        "GET #{path} HTTP/1.1\r\nHost: downstream.test\r\nConnection: close\r\n\r\n"
      )
  end

  defp send_request(socket, :http2, id, path) do
    {_, bytes} =
      HPACK.encode_headers(
        HPACK.new_encoder(),
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "downstream.test"},
          {":path", path}
        ],
        indexing: :never,
        huffman: :never
      )

    :ok = :gen_tcp.send(socket, frame(1, 5, id, bytes))
  end

  defp frame(type, flags, id, bytes),
    do: [<<IO.iodata_length(bytes)::24, type, flags, 0::1, id::31>>, bytes]

  defp recv_frame(socket) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    payload = if size == 0, do: "", else: recv_exact(socket, size)
    {type, flags, id, payload}
  end

  defp assert_ping(socket, payload) do
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, payload))
    await_ping(socket, payload, deadline())
  end

  defp await_ping(socket, payload, d) do
    assert Lifecycle.remaining(d) > 0

    case recv_frame(socket) do
      {6, 1, 0, ^payload} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        await_ping(socket, payload, d)

      {4, 1, 0, ""} ->
        await_ping(socket, payload, d)

      other ->
        flunk("unexpected H2 control while capture held: #{inspect(other)}")
    end
  end

  defp response(socket, :http1, _id) do
    head = read_head(socket, "")
    [_, status] = Regex.run(~r/^HTTP\/1\.1 ([0-9]{3}) /, head)
    [_, size] = Regex.run(~r/\r\ncontent-length: ([0-9]+)\r\n/i, head)

    body =
      case String.to_integer(size) do
        0 -> ""
        n -> recv_exact(socket, n)
      end

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    {String.to_integer(status), body}
  end

  defp response(socket, :http2, id),
    do: response_h2(socket, id, [], "", HPACK.new_decoder(max_dynamic_size: 4096), deadline())

  defp response_h2(socket, id, headers, body, decoder, d) do
    assert Lifecycle.remaining(d) > 0
    {type, flags, stream, payload} = recv_frame(socket)

    case {type, stream} do
      {4, 0} ->
        if flags == 0, do: :gen_tcp.send(socket, frame(4, 1, 0, ""))
        response_h2(socket, id, headers, body, decoder, d)

      {1, ^id} ->
        assert Bitwise.band(flags, 4) == 4
        assert {:ok, decoder, fields} = HPACK.decode(decoder, payload)
        headers = headers ++ fields

        if Bitwise.band(flags, 1) == 1,
          do: h2_result(headers, body),
          else: response_h2(socket, id, headers, body, decoder, d)

      {0, ^id} ->
        body = body <> payload

        if Bitwise.band(flags, 1) == 1,
          do: h2_result(headers, body),
          else: response_h2(socket, id, headers, body, decoder, d)

      other ->
        flunk("unexpected H2 response frame: #{inspect(other)}")
    end
  end

  defp h2_result(headers, body) do
    assert {":status", status} = List.keyfind(headers, ":status", 0)
    {String.to_integer(status), body}
  end

  defp recv_exact(socket, size) do
    assert {:ok, bytes} = :gen_tcp.recv(socket, size, @timeout)
    bytes
  end

  defp read_head(socket, bytes) do
    assert byte_size(bytes) <= @h

    if String.ends_with?(bytes, "\r\n\r\n"),
      do: bytes,
      else: read_head(socket, bytes <> recv_exact(socket, 1))
  end

  defp deadline(ms \\ @timeout), do: Lifecycle.deadline(ms)
  defp e(term), do: :erlang.external_size(term)
  defp tuple_size_etf(sizes), do: 3 + Enum.reduce(sizes, 0, fn size, sum -> sum + size - 1 end)

  defp eventually(fun, d \\ nil) do
    d = d || deadline()

    if fun.(),
      do: :ok,
      else:
        (
          assert Lifecycle.remaining(d) > 0,
                 "checked public fixture did not settle before finite deadline"

          receive do
          after
            2 -> eventually(fun, d)
          end
        )
  end
end
