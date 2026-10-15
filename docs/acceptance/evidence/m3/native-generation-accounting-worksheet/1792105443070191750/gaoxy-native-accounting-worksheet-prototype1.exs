# SOURCE-ONLY arithmetic prototype. NOT a runtime accounting implementation.
# Parent command (NOT RUN by author):
#   elixir /tmp/gaoxy-native-accounting-worksheet-prototype1.exs
# Output is CONDITIONAL: constructor/error/toolchain gates in paired design apply.
# This script invokes no provider, Store, Admission, Registry, timer, process,
# dependency, filesystem or network API. It does not manufacture maximum refs.
defmodule NativeAccountingWorksheetPrototype1 do
  @h 65_536
  @q 65_536
  @s 2_048
  @k 64
  @g Gaoxy.Proxy.UpstreamGroups
  @t Gaoxy.Proxy.UpstreamTransports
  @accounting Gaoxy.Proxy.ManagedGenerationAccounting

  def e(term), do: :erlang.external_size(term)
  def b(term), do: e(term) - 1
  # All arithmetic arguments below are complete ETF sizes, never sample values.
  def tuple(sizes), do: 3 + Enum.sum(Enum.map(sizes, &(&1 - 1)))
  def map_size_etf(pairs), do: 6 + Enum.sum(Enum.map(pairs, fn {k, v} -> k + v - 2 end))
  def list_size_etf([]), do: 2
  def list_size_etf(sizes), do: 7 + Enum.sum(Enum.map(sizes, &(&1 - 1)))
  def list_from_summary(0, 0), do: 2
  def list_from_summary(n, body_sum) when n > 0, do: 7 + body_sum
  def body_sum(0, 2), do: 0
  def body_sum(n, size) when n > 0, do: size - 7

  # No candidate list is created: operands must already have passed shape, raw
  # count<=64 and ETF<=Q. pin size may be larger than Q, paid by genuine R role.
  def cons_preflight(pin_size, {n, size}) do
    prospective = list_from_summary(n + 1, pin_size - 1 + body_sum(n, size))
    if n + 1 <= @k and prospective <= @q,
      do: {:ok, {n + 1, prospective}}, else: {:error, :generation_capture_capacity}
  end

  def append_preflight({an, ae}, {bn, be}) do
    prospective = list_from_summary(an + bn, body_sum(an, ae) + body_sum(bn, be))
    if an + bn <= @k and prospective <= @q,
      do: {:ok, {an + bn, prospective}}, else: {:error, :generation_capture_capacity}
  end

  # FUTURE-REF CONDITION: NEW_PID_EXT E(pid)=E(node)+13 and generated
  # NEWER_REFERENCE_EXT length<=5 => E(ref)<=E(node)+27. Thus owner PID cap S
  # implies future owner ref cap S+14. Source/toolchain gate must establish it.
  def future_ref_bound, do: @s + 14
  def alias_tag(ref_size), do: 6 + b(:alias) + ref_size - 1
  def from(pid_size, ref_size), do: tuple([pid_size, alias_tag(ref_size)])
  def call(payload_size, pid_size, ref_size),
    do: tuple([e(:"$gen_call"), from(pid_size, ref_size), payload_size])
  def reply(payload_size, ref_size), do: tuple([alias_tag(ref_size), payload_size])

  def pin(provider, handle_size, owner_size, epoch_size, operation_size, ref_size, holder_size) do
    fields = [provider: e(provider), owner: owner_size, owner_epoch: epoch_size,
              ref: ref_size, operation: operation_size, handles: handle_size, kind: e(:request)]
    fields = if provider == @t, do: fields ++ [holder: holder_size], else: fields
    map_size_etf(Enum.map(fields, fn {key, size} -> {e(key), size} end))
  end

  def bounds do
    r = future_ref_bound()
    pg = pin(@g, @h, @s, @s, r, r, @s)
    pt = pin(@t, @h, @s, @s, r, r, @s)
    %{h: @h, q: @q, s: @s, k: @k, future_ref: r,
      g_pin: pg, t_pin: pt, genuine_pin: max(pg, pt),
      g_singleton: list_size_etf([pg]), t_singleton: list_size_etf([pt])}
  end

  # Exact finite replacement vocabulary proposed for checked path only.
  # Existing Lifecycle raw errors DO NOT currently satisfy this contract.
  def finite_error_size do
    [:invalid_generation_capture, :generation_capture_capacity, :generation_unavailable,
     :generation_pin_release_failed, :cleanup_unconfirmed, :invalid_resource_holder,
     :byte_limit, :stale_generation, :deadline_exceeded, :cleanup_pending]
    |> Enum.map(&e/1) |> Enum.max()
  end

  def rows(m, retained, assumed_b) when is_integer(m) and m > 0 and retained >= 0 do
    z = bounds()
    s = z.s
    r = z.future_ref
    d = 12 # complete signed64 integer ETF upper bound; deadline gate required
    err = tuple([e(:error), finite_error_size()])
    provider_atom = max(e(@g), e(@t))
    provenance_item = tuple([provider_atom, s, r])
    provenance = list_size_etf(List.duplicate(provenance_item, z.k))
    # All handles preserved; partition map repeats one provider/owner key per batch.
    # map6 + input element bodies(H-7) + k*(key tuple-body2 + list-body6
    # + provider atom-body + owner-body).
    batches = 6 + (z.h - 7) + z.k * (8 + provider_atom - 1 + s - 1)
    # Complete, explicitly chosen future contract tuples; no safe projection.
    context = tuple([s, s, s, s, e(:request), d, e(retained)])
    plan = tuple([e(:native_generation_capture_v1), e(m), e(z.h), e(z.q), e(assumed_b)])
    snapshot_call = tuple([e(:snapshot_for_request), s, d, e(@accounting)])
    pin_call = max(tuple([e(:pin), z.h, s, e(:request), r, d]),
                   tuple([e(:pin_many), z.h, s, e(:request), r, d]))
    pin_ok = tuple([e(:ok), z.genuine_pin])
    pin_result = max(pin_ok, err)
    accumulator = tuple([e(:ok), z.q])
    # Generation repeats outside complete Router. Both complete members bounded M.
    snapshot = tuple([e(:ok), m, m, z.q])
    release = tuple([e(:release), z.q - 6])
    cancel = max(tuple([e(:cancel_pin), s, r]), tuple([e(:cancel_pins), s, r]))
    # Bounded observability via existing Telemetry.emit with empty scope, no raw
    # target result, exception, stack, callback output or arbitrary scope metadata.
    cleanup_metadata = map_size_etf([
      {e(:store), s}, {e(:holder), s}, {e(:lease), s},
      {e(:stage), max(e(:release), e(:acquisition))},
      {e(:cleanup), e(:cleanup_unconfirmed)}])
    cleanup = tuple([list_size_etf([e(:gaoxy), e(:generation_capture_cleanup)]),
                     map_size_etf([{e(:count), e(1)}]), cleanup_metadata])
    update = tuple([e(:update), s, e(retained + assumed_b)])
    [
      {:context, 1, context},
      {:plan, 1, plan},
      {:admission_update_payload, 1, update},
      {:admission_update_wire, 1, call(update, s, r)},
      {:admission_update_reply, 1, reply(max(e(:ok), err), r)},
      {:snapshot_requester_payload, 1, snapshot_call},
      {:snapshot_call_wire, 1, call(snapshot_call, s, r)},
      {:snapshot_store_payload, 1, snapshot_call},
      {:snapshot_store_from, 1, from(s, r)},
      {:validated_manifest, 1, z.h},
      {:partition_map, 1, batches},
      {:provider_handle_normalization, 3, z.h},
      {:provider_request_payload, 1, pin_call},
      {:provider_call_wire, 1, call(pin_call, s, r)},
      {:provider_owner_payload, 1, pin_call},
      {:provider_owner_from, 1, from(s, r)},
      {:genuine_provider_pin, 1, z.genuine_pin},
      {:provider_result_payload, 1, pin_result},
      {:provider_reply_wire, 1, reply(pin_result, r)},
      {:provider_store_received_result, 1, pin_result},
      {:checked_acquisition_accumulator, 3, accumulator},
      {:original_provenance, 1, provenance},
      {:store_snapshot_payload, 1, max(snapshot, err)},
      {:store_snapshot_wire, 1, reply(max(snapshot, err), r)},
      {:requester_snapshot_received, 1, max(snapshot, err)},
      {:caller_capture_inputs_and_output, 3, z.q},
      {:release_payload, 1, release},
      {:release_call_wire, 1, call(release, s, r)},
      {:release_reply_wire, 1, reply(max(e(:ok), err), r)},
      {:cancel_control, 1, cancel},
      {:cleanup_observation, 1, cleanup},
      {:finite_failure_payload, 1, err}
    ]
  end

  # Machine-readable complete role descriptors; documentation table expands the
  # constructor-size variables. These descriptors are worksheet output only;
  # the proposed retained plan is the five-element tuple paid by :plan.
  def role_specs(rs) do
    metadata = %{
      context: {:requester, "{store,holder,gate,lease,:request,deadline,retained}", :request_end},
      plan: {:requester, "{:native_generation_capture_v1,M,H,Q,B}", :request_end},
      admission_update_payload: {:requester, "{:update,lease,retained+B}", :admission_return},
      admission_update_wire: {:admission, "$gen_call(update)", :admission_return},
      admission_update_reply: {:requester, "{alias_tag,:ok|finite_error}", :admission_return},
      snapshot_requester_payload: {:requester, "{:snapshot_for_request,holder,deadline,module}", :snapshot_return},
      snapshot_call_wire: {:store, "$gen_call(snapshot_request)", :snapshot_return},
      snapshot_store_payload: {:store, "{:snapshot_for_request,holder,deadline,module}", :snapshot_return},
      snapshot_store_from: {:store, "{requester,alias_tag}", :snapshot_return},
      validated_manifest: {:store, "complete validated current Router.resources", :snapshot_return},
      partition_map: {:store, "%{{provider,owner}=>complete_batch}", :acquisition_end},
      provider_handle_normalization: {:provider, "complete input/reverse_acc/unique_output lists", :provider_return},
      provider_request_payload: {:store, "{:pin|:pin_many,batch,holder,:request,operation,deadline}", :provider_return},
      provider_call_wire: {:provider, "$gen_call(provider_request)", :provider_return},
      provider_owner_payload: {:provider, "{:pin|:pin_many,batch,holder,:request,operation,deadline}", :provider_return},
      provider_owner_from: {:provider, "{store,alias_tag}", :provider_return},
      genuine_provider_pin: {:provider, "complete actual G7/T8 public pin", :receipt_validation},
      provider_result_payload: {:provider, "{:ok,complete_pin}|finite_error", :provider_return},
      provider_reply_wire: {:store, "{alias_tag,provider_result}", :receipt_validation},
      provider_store_received_result: {:store, "{:ok,complete_pin}|finite_error", :receipt_validation},
      checked_acquisition_accumulator: {:store, "{:ok,complete_pins} input/current/output roots", :snapshot_return},
      original_provenance: {:store, "[{original_provider,original_owner,original_operation}]", :acquisition_end},
      store_snapshot_payload: {:store, "{:ok,generation,complete_router,complete_pins}|finite_error", :snapshot_return},
      store_snapshot_wire: {:requester, "{alias_tag,complete_snapshot_result}", :snapshot_return},
      requester_snapshot_received: {:requester, "{:ok,generation,complete_router,complete_pins}|finite_error", :request_end},
      caller_capture_inputs_and_output: {:requester, "complete_existing,complete_new,complete_accepted_combined lists", :request_end},
      release_payload: {:requester, "{:release,complete_accepted_pin}", :release_return},
      release_call_wire: {:provider, "$gen_call(release)", :release_return},
      release_reply_wire: {:requester, "{alias_tag,:ok|finite_error}", :release_return},
      cancel_control: {:provider, "{:cancel_pin|:cancel_pins,store,original_operation}", :acquisition_end},
      cleanup_observation: {:requester, "{[:gaoxy,:generation_capture_cleanup],%{count:1},bounded_metadata}", :emit_return},
      finite_failure_payload: {:requester, "{:error,finite_checked_reason}", :request_end}
    }
    Enum.map(rs, fn {name, count, cap} ->
      {owner, constructor, release} = Map.fetch!(metadata, name)
      %{name: name, owner: owner, constructor: constructor, cap: cap,
        multiplicity: count, subtotal: count * cap, release: release}
    end)
  end

  # Exact arithmetic fixed point pays ETF byte-length of B itself in plan/update.
  # No circular unpriced integer and no guessed integer cap or wrapper headroom.
  def worksheet(m, retained \\ 0), do: settle(m, retained, 0, 0)
  defp settle(m, retained, assumed_b, iterations) when iterations < 64 do
    rs = rows(m, retained, assumed_b)
    total = Enum.reduce(rs, 0, fn {_, count, bytes}, sum -> sum + count * bytes end)
    if total == assumed_b,
      do: %{qualification: :conditional_not_runtime_ready, m: m, retained: retained,
            bounds: bounds(), rows: rs, roles: role_specs(rs), total: total, fixed_point_iterations: iterations},
      else: settle(m, retained, total, iterations + 1)
  end

  def assertions do
    # Independent syntax expectations, with actual small ordinary constructors.
    true = tuple([e(:ok), e(:x)]) == e({:ok, :x})
    true = map_size_etf([{e(:a), e(1)}, {e(:b), e(:ok)}]) == e(%{a: 1, b: :ok})
    true = list_size_etf([]) == e([])
    true = list_size_etf([e(:x), e(:ok)]) == e([:x, :ok])
    true = append_preflight({0, 2}, {0, 2}) == {:ok, {0, 2}}
    true = append_preflight({0, 2}, {1, 100}) == {:ok, {1, 100}}
    true = append_preflight({1, 100}, {0, 2}) == {:ok, {1, 100}}
    true = append_preflight({1, 100}, {1, 200}) == {:ok, {2, 293}}
    true = cons_preflight(65_530, {0, 2}) == {:ok, {1, 65_536}}
    true = cons_preflight(65_531, {0, 2}) == {:error, :generation_capture_capacity}
    true = append_preflight({1, 65_536}, {1, 65_536}) == {:error, :generation_capture_capacity}
    true = append_preflight({64, 2_000}, {1, 100}) == {:error, :generation_capture_capacity}
    true = cons_preflight(100, {64, 2_000}) == {:error, :generation_capture_capacity}
    true = bounds().g_singleton > 65_536
    true = bounds().t_singleton > bounds().g_singleton
    :ok
  end
end

:ok = NativeAccountingWorksheetPrototype1.assertions()
for m <- [65_536, 1_048_576] do
  w = NativeAccountingWorksheetPrototype1.worksheet(m)
  IO.inspect(Map.drop(w, [:rows, :roles]), label: "CONDITIONAL_ARITHMETIC_ONLY")
  Enum.each(w.rows, fn {name, n, cap} ->
    IO.puts("#{name}\t#{n}\t#{cap}\t#{n * cap}")
  end)
end
