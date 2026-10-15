defmodule Gaoxy.Proxy.ManagedGenerationAccountingTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.{ManagedH2GroupAccounting, ManagedH2Reservation}
  alias Gaoxy.Proxy.{UpstreamGroups, UpstreamTransports}

  @accounting Gaoxy.Proxy.ManagedGenerationAccounting
  @invalid {:error, :invalid_generation_capture}
  @capacity {:error, :generation_capture_capacity}
  @min -9_223_372_036_854_775_808
  @max 9_223_372_036_854_775_807
  @finite ~w(invalid_generation_capture generation_capture_capacity generation_unavailable
    generation_pin_release_failed cleanup_unconfirmed invalid_resource_holder byte_limit
    stale_generation deadline_exceeded cleanup_pending)a
  @prerequisites ~w(checked_acquisition_preflight qualified_provider_constructors
    finite_checked_errors selected_context_and_plan observable_release_outcomes)a

  # Source-bound P2 expected ledger at M=65536, retained=0. These are literal
  # reviewed expectations, not results obtained from the production calculator.
  @ledger [
    {:context, :requester, "{store,holder,gate,lease,:request,deadline,retained}", :request_end, 1, 8213, 8213},
    {:plan, :requester, "{:native_generation_capture_v1,M,H,Q,B}", :request_end, 1, 53, 53},
    {:admission_update_payload, :requester, "{:update,lease,retained+B}", :admission_return, 1, 2063, 2063},
    {:admission_update_wire, :admission, "$gen_call(update)", :admission_return, 1, 6198, 6198},
    {:admission_update_reply, :requester, "{alias_tag,:ok|finite_error}", :admission_return, 1, 2116, 2116},
    {:snapshot_requester_payload, :requester, "{:snapshot_for_request,holder,deadline,module}", :snapshot_return, 1, 2131, 2131},
    {:snapshot_call_wire, :store, "$gen_call(snapshot_request)", :snapshot_return, 1, 6266, 6266},
    {:snapshot_store_payload, :store, "{:snapshot_for_request,holder,deadline,module}", :snapshot_return, 1, 2131, 2131},
    {:snapshot_store_from, :store, "{requester,alias_tag}", :snapshot_return, 1, 4123, 4123},
    {:validated_manifest, :store, "complete validated current Router.resources", :snapshot_return, 1, 65536, 65536},
    {:partition_map, :store, "%{{provider,owner}=>complete_batch}", :acquisition_end, 1, 199551, 199551},
    {:provider_handle_normalization, :provider, "complete input/reverse_acc/unique_output lists", :provider_return, 3, 65536, 196608},
    {:provider_request_payload, :store, "{:pin|:pin_many,batch,holder,:request,operation,deadline}", :provider_return, 1, 69676, 69676},
    {:provider_call_wire, :provider, "$gen_call(provider_request)", :provider_return, 1, 73811, 73811},
    {:provider_owner_payload, :provider, "{:pin|:pin_many,batch,holder,:request,operation,deadline}", :provider_return, 1, 69676, 69676},
    {:provider_owner_from, :provider, "{store,alias_tag}", :provider_return, 1, 4123, 4123},
    {:genuine_provider_pin, :provider, "complete actual G7/T8 public pin", :receipt_validation, 1, 75921, 75921},
    {:provider_result_payload, :provider, "{:ok,complete_pin}|finite_error", :provider_return, 1, 75927, 75927},
    {:provider_reply_wire, :store, "{alias_tag,provider_result}", :receipt_validation, 1, 78002, 78002},
    {:provider_store_received_result, :store, "{:ok,complete_pin}|finite_error", :receipt_validation, 1, 75927, 75927},
    {:checked_acquisition_accumulator, :store, "{:ok,complete_pins} input/current/output roots", :snapshot_return, 3, 65542, 196626},
    {:original_provenance, :store, "[{original_provider,original_owner,original_operation}]", :acquisition_end, 1, 265543, 265543},
    {:store_snapshot_payload, :store, "{:ok,generation,complete_router,complete_pins}|finite_error", :snapshot_return, 1, 196612, 196612},
    {:store_snapshot_wire, :requester, "{alias_tag,complete_snapshot_result}", :snapshot_return, 1, 198687, 198687},
    {:requester_snapshot_received, :requester, "{:ok,generation,complete_router,complete_pins}|finite_error", :request_end, 1, 196612, 196612},
    {:caller_capture_inputs_and_output, :requester, "complete_existing,complete_new,complete_accepted_combined lists", :request_end, 3, 65536, 196608},
    {:release_payload, :requester, "{:release,complete_accepted_pin}", :release_return, 1, 65541, 65541},
    {:release_call_wire, :provider, "$gen_call(release)", :release_return, 1, 69676, 69676},
    {:release_reply_wire, :requester, "{alias_tag,:ok|finite_error}", :release_return, 1, 2116, 2116},
    {:cancel_control, :provider, "{:cancel_pin|:cancel_pins,store,original_operation}", :acquisition_end, 64, 4124, 263936},
    {:known_call_failure_descriptor, :caller, "{finite_reason,{GenServer,:call,[server,complete_request,timeout]}}", :call_return, 1, 71806, 71806},
    {:known_monitor_down, :caller, "{:DOWN,monitor,:process,pid,finite_reason}", :call_return, 1, 4164, 4164},
    {:cleanup_observation, :requester, "{[:gaoxy,:generation_capture_cleanup],%{count:1},bounded_metadata}", :emit_return, 2, 6276, 12552},
    {:finite_failure_payload, :requester, "{:error,finite_checked_reason}", :request_end, 1, 41, 41}
  ]

  # self/make_ref establish public scalar shapes, never provider authority or
  # successful runtime acquisition. No Store/provider/process API is exercised.

  test "worksheet reports the full conditional ledger and each source lifetime" do
    assert {:ok, report} = call(:worksheet, [65_536, context()])
    assert report.qualification == :conditional_not_runtime_ready
    assert report.m == 65_536
    assert report.retained == 0
    assert report.prerequisites == @prerequisites
    assert report.total == 2_758_572
    assert report.fixed_point_iterations == 2
    assert report.bounds == %{
             h: 65_536, q: 65_536, s: 2048, k: 64, future_ref: 2062,
             g_pin: 73862, t_pin: 75921, genuine_pin: 75921,
             g_singleton: 73868, t_singleton: 75927
           }

    assert length(report.roles) == 34
    assert Enum.map(report.roles, & &1.name) == Enum.map(@ledger, &elem(&1, 0))

    for {name, owner, constructor, release, count, cap, subtotal} <- @ledger do
      assert Enum.find(report.roles, &(&1.name == name)) == %{
               name: name, owner: owner, constructor: constructor, release: release,
               multiplicity: count, cap: cap, subtotal: subtotal
             }
      assert count * cap == subtotal
    end

    assert Enum.sum(Enum.map(report.roles, & &1.subtotal)) == 2_758_572
  end

  test "actual default M retains all three complete snapshot roots" do
    assert {:ok, report} = call(:worksheet, [1_048_576, context()])
    assert report.total == 8_656_812
    assert report.m == 1_048_576
    assert report.fixed_point_iterations == 2
    rows = Map.new(report.roles, &{&1.name, &1})
    assert rows.store_snapshot_payload.cap == 2_162_692
    assert rows.store_snapshot_wire.cap == 2_164_767
    assert rows.requester_snapshot_received.cap == 2_162_692
    assert Enum.sum(for name <- [:store_snapshot_payload, :store_snapshot_wire,
                                :requester_snapshot_received], do: rows[name].subtotal) == 6_490_151
    assert Enum.sum(for row <- report.roles,
                       row.name not in [:store_snapshot_payload, :store_snapshot_wire,
                                        :requester_snapshot_received], do: row.subtotal) == 2_166_661
  end

  test "positive M has no invented universal byte cap" do
    for m <- [1, 65_537, 1_048_577, 18_446_744_073_709_551_616] do
      assert {:ok, report} = call(:worksheet, [m, context()])
      assert report.m == m
      assert report.qualification == :conditional_not_runtime_ready
      assert report.total > 6 * m
      assert report.total == Enum.sum(Enum.map(report.roles, & &1.subtotal))
      assert report.fixed_point_iterations in 1..63
    end
  end

  test "unbounded M pays the ETF widths of both M and the fixed point B" do
    m = 18_446_744_073_709_551_616
    assert {:ok, report} = call(:worksheet, [m, context()])
    # E(M)=E(B)=13 rather than the baseline INTEGER_EXT size5. This
    # independently adds8 for M,8 for plan B and16 for the two update roots.
    assert report.total == 110_680_464_442_259_675_084
    assert report.total == 6 * m + 2_365_388
    rows = Map.new(report.roles, &{&1.name, &1})
    assert rows.plan.cap == 69
    assert rows.admission_update_payload.cap == 2071
    assert rows.admission_update_wire.cap == 6206
    assert e(m) == 13
    assert e(report.total) == 13
  end

  test "retained integer encoding and retained plus B cross their own boundaries" do
    # For this table B itself stays in INTEGER_EXT. Only context E(retained)
    # and the two complete update roots change. The first int32-sum boundary
    # uses retained = 2147483647 - (2758572 + 3), not a sampled maximum.
    expected = [
      {0, 2_758_572}, {255, 2_758_572}, {256, 2_758_575},
      {2_144_725_072, 2_758_575}, {2_144_725_073, 2_758_581},
      {2_147_483_647, 2_758_581}, {2_147_483_648, 2_758_584},
      {4_294_967_295, 2_758_586}, {4_294_967_296, 2_758_587},
      {18_446_744_073_709_551_615, 2_758_598},
      {18_446_744_073_709_551_616, 2_758_599}
    ]

    for {retained, expected_total} <- expected do
      assert {:ok, report} = call(:worksheet, [65_536, context(retained)])
      assert report.retained == retained
      assert report.total == expected_total
      assert report.total == Enum.sum(Enum.map(report.roles, & &1.subtotal))
      rows = Map.new(report.roles, &{&1.name, &1})
      assert rows.context.cap == 8213 + e(retained) - 2
      assert rows.plan.cap == 53
      assert rows.admission_update_payload.cap == 2063 + e(retained + expected_total) - 5
      assert rows.admission_update_wire.cap == 6198 + e(retained + expected_total) - 5
    end
  end

  test "worksheet accepts signed64 past deadlines and exact cleanup headroom without a clock" do
    for deadline <- [@min, -1, 0, 1, @max - 1000] do
      assert {:ok, %{qualification: :conditional_not_runtime_ready}} =
               call(:worksheet, [65_536, put_elem(context(), 5, deadline)])
    end
  end

  test "worksheet rejects invalid M and every malformed original context scalar" do
    c = context()
    for m <- [0, -1, 1.0, nil, :default, %{max_config_bytes: 65_536}] do
      assert @invalid == call(:worksheet, [m, c])
    end

    bad = [nil, [], Tuple.to_list(c), %{context: c}, Tuple.append(c, :extra)] ++
            (for index <- 0..2, value <- [nil, make_ref(), :owner], do: put_elem(c, index, value)) ++
            (for value <- [self(), nil, 0], do: put_elem(c, 3, value)) ++
            (for value <- [:baseline, :preparation, nil], do: put_elem(c, 4, value)) ++
            (for value <- [@min - 1, @max - 999, @max + 1, 1.0, nil], do: put_elem(c, 5, value)) ++
            (for value <- [-1, 1.0, nil], do: put_elem(c, 6, value))
    for value <- bad, do: assert(@invalid == call(:worksheet, [65_536, value]))
  end

  test "small actual ETF constructors independently establish wrapper version accounting" do
    pid = self()
    ref = make_ref()
    alias_tag = [:alias | ref]
    payload = {:release, %{a: 1}}
    from = {pid, alias_tag}
    assert e([]) == 2
    assert e([%{a: 1}]) == e(%{a: 1}) + 6
    assert e({:ok, :x}) == e(:ok) + e(:x) + 1
    assert e(%{a: 1, b: :ok}) == 6 + e(:a) + e(1) + e(:b) + e(:ok) - 4
    assert e(alias_tag) == 6 + e(:alias) - 1 + e(ref) - 1
    assert e(alias_tag) != e([:alias, ref])
    assert e(from) == 3 + e(pid) - 1 + e(alias_tag) - 1
    assert e({:"$gen_call", from, payload}) ==
             3 + e(:"$gen_call") - 1 + e(from) - 1 + e(payload) - 1
    assert e({alias_tag, {:ok, payload}}) ==
             3 + e(alias_tag) - 1 + e({:ok, payload}) - 1
  end

  test "complete G7 and T8 pin maps preserve their actual ETF and request kind" do
    f = fixtures()
    for pin <- [f.g_pin, f.t_pin] do
      expected_size = 6 + Enum.sum(for {key, value} <- pin, do: e(key) + e(value) - 2)
      assert e(pin) == expected_size
      assert {:ok, %{count: 1, bytes: bytes}} = call(:preflight_cons, [pin, []])
      assert bytes == e([pin])
    end
    assert map_size(f.g_pin) == 7
    assert map_size(f.t_pin) == 8
    refute Map.has_key?(f.g_pin, :holder)
    assert f.t_pin.holder === self()
  end

  test "H1 G6 G7 and H2 G8 handles and 32 transports remain compatible" do
    f = fixtures()
    for group <- [f.g6, f.g7, f.g8, f.g32] do
      pin = %{f.g_pin | handles: [group]}
      assert {:ok, %{count: 1, bytes: bytes}} = call(:preflight_cons, [pin, []])
      assert bytes == e([pin])
    end
    assert map_size(f.g6) == 6
    assert map_size(f.g7) == 7
    assert map_size(f.g8) == 8
    assert length(f.g32.transports) == 32
    bad = %{f.g32 | transports: f.g32.transports ++ [%{f.t | resource: make_ref()}]}
    assert @invalid == call(:preflight_cons, [%{f.g_pin | handles: [bad]}, []])
  end

  test "capture preflight has no invented global 33 resource cutoff" do
    f = fixtures()
    groups = for _ <- 1..34, do: %{f.g6 | generation: make_ref()}
    pin = %{f.g_pin | handles: groups}
    assert length(pin.handles) == 34
    assert {:ok, %{count: 1, bytes: bytes}} = call(:preflight_cons, [pin, []])
    assert bytes == e([pin])
  end

  test "cons and append measure original complete operands including empty lists" do
    f = fixtures()
    assert {:ok, %{count: 0, bytes: 2}} == call(:preflight_append, [[], []])
    assert {:ok, %{count: 1, bytes: e([f.g_pin])}} == call(:preflight_append, [[f.g_pin], []])
    assert {:ok, %{count: 1, bytes: e([f.t_pin])}} == call(:preflight_append, [[], [f.t_pin]])
    expected = %{count: 2, bytes: e([f.g_pin, f.t_pin])}
    assert {:ok, expected} == call(:preflight_cons, [f.g_pin, [f.t_pin]])
    assert {:ok, expected} == call(:preflight_append, [[f.g_pin], [f.t_pin]])
    assert expected.bytes == e([f.g_pin]) + e([f.t_pin]) - 7
  end

  test "an exact 65536 byte singleton fits and the next byte fails prospectively" do
    exact = sized_group_pin(65_530)
    over = sized_group_pin(65_531)
    assert e(exact) == 65_530
    assert e([exact]) == 65_536
    assert :ok == ManagedH2GroupAccounting.validate({:owner_reply, :group, :pin}, {:ok, over})
    assert {:ok, %{count: 1, bytes: 65_536}} == call(:preflight_cons, [exact, []])
    assert {:ok, %{count: 1, bytes: 65_536}} == call(:preflight_append, [[exact], []])
    assert @capacity == call(:preflight_cons, [over, []])
    assert @invalid == call(:preflight_append, [[over], []])
    assert @invalid == call(:preflight_cons, [exact, [over]])
  end

  test "two individually bounded byte operands reject before combined list construction" do
    pin = sized_group_pin(65_530)
    left = [pin]
    right = [pin]
    assert e(left) == 65_536
    assert e(right) == 65_536
    # Only arithmetic describes the rejected candidate. Do not build left++right.
    assert e(left) + e(right) - 7 == 131_065
    assert @capacity == call(:preflight_append, [left, right])
    assert @capacity == call(:preflight_cons, [pin, right])
  end

  test "64 captures fit but a prospective 65th capture does not" do
    f = fixtures()
    pins = for _ <- 1..64, do: %{f.g_pin | ref: make_ref(), operation: make_ref()}
    assert e(pins) <= 65_536
    assert {:ok, %{count: 64, bytes: e(pins)}} == call(:preflight_append, [pins, []])
    assert @capacity == call(:preflight_cons, [f.g_pin, pins])
    assert @capacity == call(:preflight_append, [[f.g_pin], pins])
    assert @capacity == call(:preflight_append, [pins, pins])
  end

  test "malformed complete pin maps and handle association cannot pass schema validation" do
    f = fixtures()
    malformed = [nil, [], {:ok, f.g_pin}, Map.put(f.g_pin, :extra, :x),
                 Map.delete(f.g_pin, :operation), %{f.g_pin | provider: UnknownProvider},
                 %{f.g_pin | owner: make_ref()}, %{f.g_pin | owner_epoch: self()},
                 %{f.g_pin | operation: self()}, %{f.g_pin | ref: self()},
                 %{f.g_pin | kind: :unknown}, %{f.g_pin | kind: nil},
                 %{f.g_pin | handles: []}, %{f.g_pin | handles: [f.g6 | :improper]},
                 %{f.g_pin | handles: [%{f.g6 | owner_epoch: make_ref()}]},
                 %{f.g_pin | handles: [f.t]}, %{f.g_pin | handles: [Map.put(f.g6, :extra, 1)]},
                 %{f.t_pin | handles: [Map.put(f.t, :extra, 1)]},
                 %{f.t_pin | holder: make_ref()}, Map.delete(f.t_pin, :holder)]
    for pin <- malformed do
      assert @invalid == call(:preflight_cons, [pin, []])
      assert @invalid == call(:preflight_append, [[pin], []])
      assert @invalid == call(:preflight_append, [[], [pin]])
    end
  end

  test "request-only preflights leave legacy baseline and preparation validation unchanged" do
    f = fixtures()
    for kind <- [:baseline, :preparation] do
      pin = %{f.g_pin | kind: kind}
      assert :ok == ManagedH2GroupAccounting.validate(:captured_pins, [pin])
      assert @invalid == call(:preflight_cons, [pin, []])
      assert @invalid == call(:preflight_append, [[pin], []])
      assert @invalid == call(:preflight_append, [[], [pin]])
    end
  end

  test "malformed actual lists and forged count byte summaries are never authority" do
    f = fixtures()
    for operand <- [nil, :pins, %{count: 0, bytes: 2}, %{count: 1, bytes: 1, pins: [f.g_pin]},
                    [f.g_pin | :improper], List.duplicate(f.g_pin, 65)] do
      assert @invalid == call(:preflight_cons, [f.g_pin, operand])
      assert @invalid == call(:preflight_append, [operand, []])
      assert @invalid == call(:preflight_append, [[], operand])
    end
    assert @invalid == call(:preflight_cons, [%{count: 1, bytes: 1}, []])
  end

  test "different real operation refs are schema-valid without authentic request context" do
    f = fixtures()
    changed = %{f.t_pin | operation: make_ref()}
    assert changed.operation !== f.t_pin.operation
    assert {:ok, %{count: 2, bytes: bytes}} = call(:preflight_append, [[changed], [f.t_pin]])
    assert bytes == e([changed, f.t_pin])
  end

  test "each finite checked reason is retained exactly as an atom" do
    for reason <- @finite, do: assert(call(:finite_checked_reason, [reason]) === reason)
  end

  test "only specified top level timeout shapes normalize to deadline exceeded" do
    raw = %{diagnostic: :binary.copy("x", 70_000)}
    for term <- [:timeout, {:timeout, raw}, {:operation_exit, :timeout},
                 {:operation_exit, {:timeout, raw}}] do
      assert call(:finite_checked_reason, [term]) === :deadline_exceeded
    end
  end

  test "nonrunning shapes normalize to generation unavailable without retaining diagnostics" do
    raw = %{diagnostic: :binary.copy("x", 70_000)}
    for inner <- [:noproc, :nodedown, {:noproc, raw}, {:nodedown, raw}],
        term <- [inner, {:operation_exit, inner}] do
      assert call(:finite_checked_reason, [term]) === :generation_unavailable
    end
  end

  test "unknown deep thrown exited and exception diagnostics normalize nonrecursively" do
    deep = Enum.reduce(1..2000, :timeout, fn _, acc -> {:operation_exit, acc} end)
    raw = :binary.copy("diagnostic", 10_000)
    for term <- [nil, 1, raw, deep, {:error, :timeout}, {:throw, raw}, {:exit, raw},
                 {:operation_exit, {:operation_exit, :timeout}},
                 {:operation_exit, :byte_limit}, RuntimeError.exception(raw),
                 {:timeout, raw, :extra}, %{reason: :timeout}, fn -> :timeout end] do
      result = call(:finite_checked_reason, [term])
      assert result === :generation_unavailable
      assert result in @finite
      assert e(result) <= 33
    end
  end

  test "existing fixed service group and startup reservations remain distinct" do
    assert ManagedH2Reservation.activation_contract().reservation_per_request == 9_444_956
    assert ManagedH2GroupAccounting.reservation_bytes() == 16_478_862
    assert ManagedH2GroupAccounting.startup_bytes() == 5_963_776
    assert {:ok, report} = call(:worksheet, [65_536, context()])
    refute report.total in [9_444_956, 16_478_862, 5_963_776]
  end

  defp context(retained \\ 0),
    do: {self(), self(), self(), make_ref(), :request, 1, retained}

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
              ref: make_ref(), operation: make_ref(), handles: [t], kind: :request,
              holder: owner}
    %{t: t, g6: g6, g7: g7, g8: g8, g32: g32, g_pin: g_pin, t_pin: t_pin}
  end

  # Calibrate a real complete G7 pin by growing only schema-permitted original
  # group IDs and transport lists. This helper determines inputs, never expected
  # preflight outputs; target is independently checked with the VM ETF encoder.
  defp sized_group_pin(target) do
    f = fixtures()
    transports = for _ <- 1..32, do: %{f.t | resource: make_ref()}
    groups = for _ <- 1..64, do: %{f.g7 | generation: make_ref(), transports: [hd(transports)]}
    base = %{f.g_pin | handles: groups}
    step = e(hd(transports)) - 1
    extra = div(target - e(base), step)
    assert extra >= 0 and extra <= 64 * 31
    grown = Enum.with_index(groups, fn group, index ->
      count = 1 + min(31, max(0, extra - index * 31))
      %{group | transports: Enum.take(transports, count)}
    end)
    pin = %{base | handles: grown}
    padding = target - e(pin)
    assert padding >= 0 and padding <= 64 * 127
    handles = Enum.with_index(grown, fn group, index ->
      size = 1 + min(127, max(0, padding - index * 127))
      %{group | group: :binary.copy("g", size)}
    end)
    pin = %{pin | handles: handles}
    assert e(pin) == target
    assert :ok == ManagedH2GroupAccounting.validate({:owner_reply, :group, :pin}, {:ok, pin})
    pin
  end

  defp e(term), do: :erlang.external_size(term)
  defp call(function, arguments), do: apply(@accounting, function, arguments)
end
