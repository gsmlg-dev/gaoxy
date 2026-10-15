defmodule Gaoxy.Proxy.ManagedGenerationAccounting do
  @moduledoc false
  alias Gaoxy.Proxy.ManagedH2GroupAccounting
  @invalid {:error, :invalid_generation_capture}
  @capacity {:error, :generation_capture_capacity}
  @min -9_223_372_036_854_775_808
  @max 9_223_372_036_854_775_807
  @finite ~w(invalid_generation_capture generation_capture_capacity generation_unavailable
    generation_pin_release_failed cleanup_unconfirmed invalid_resource_holder byte_limit
    stale_generation deadline_exceeded cleanup_pending)a
  @prerequisites ~w(checked_acquisition_preflight qualified_provider_constructors
    finite_checked_errors selected_context_and_plan observable_release_outcomes)a

  # Conditional source-role arithmetic only. No runtime reservation is activated.
  def worksheet(m, {store, holder, gate, lease, :request, deadline, retained})
      when is_integer(m) and m > 0 and is_pid(store) and is_pid(holder) and is_pid(gate) and
             is_reference(lease) and is_integer(deadline) and deadline >= @min and
             deadline <= @max - 1_000 and is_integer(retained) and retained >= 0 do
    if Enum.all?([store, holder, gate, lease], &scalar?/1),
      do: settle(m, retained, 0, 0),
      else: @invalid
  end

  def worksheet(_, _), do: @invalid

  def preflight_cons(pin, pins) do
    if pin?(pin) and captures?(pins) do
      pin_bytes = e(pin)
      if pin_bytes <= bounds().genuine_pin,
        do: cons_preflight(pin_bytes, {length(pins), e(pins)}),
        else: @capacity
    else
      @invalid
    end
  end

  def preflight_append(new_pins, existing_pins) do
    if captures?(new_pins) and captures?(existing_pins),
      do: append_preflight({length(new_pins), e(new_pins)},
                          {length(existing_pins), e(existing_pins)}),
      else: @invalid
  end

  def finite_checked_reason(reason) when reason in @finite, do: reason
  def finite_checked_reason(:timeout), do: :deadline_exceeded
  def finite_checked_reason({:timeout, _}), do: :deadline_exceeded
  def finite_checked_reason({:operation_exit, :timeout}), do: :deadline_exceeded
  def finite_checked_reason({:operation_exit, {:timeout, _}}), do: :deadline_exceeded
  def finite_checked_reason(_), do: :generation_unavailable

  defp scalar?(value), do: :erlang.external_size(value) <= 2_048

  defp pin?(%{provider: provider, kind: :request} = pin)
       when provider in [Gaoxy.Proxy.UpstreamGroups, Gaoxy.Proxy.UpstreamTransports] do
    owner = if provider == Gaoxy.Proxy.UpstreamGroups, do: :group, else: :transport
    ManagedH2GroupAccounting.validate({:owner_reply, owner, :pin}, {:ok, pin}) == :ok
  end

  defp pin?(_), do: false

  defp captures?(pins) do
    ManagedH2GroupAccounting.validate(:captured_pins, pins) == :ok and
      Enum.all?(pins, &(&1.kind === :request))
  end

  @h 65_536
  @q 65_536
  @s 2_048
  @k 64
  @g Gaoxy.Proxy.UpstreamGroups
  @t Gaoxy.Proxy.UpstreamTransports
  @accounting __MODULE__

  defp e(term), do: :erlang.external_size(term)
  defp b(term), do: e(term) - 1
  # All arithmetic arguments below are complete ETF sizes, never sample values.
  defp tuple(sizes), do: 3 + Enum.sum(Enum.map(sizes, &(&1 - 1)))
  defp map_size_etf(pairs), do: 6 + Enum.sum(Enum.map(pairs, fn {k, v} -> k + v - 2 end))
  defp list_size_etf([]), do: 2
  defp list_size_etf(sizes), do: 7 + Enum.sum(Enum.map(sizes, &(&1 - 1)))
  defp list_from_summary(0, 0), do: 2
  defp list_from_summary(n, body_sum) when n > 0, do: 7 + body_sum
  defp body_sum(0, 2), do: 0
  defp body_sum(n, size) when n > 0, do: size - 7

  # No candidate list is created: operands must already have passed shape, raw
  # count<=64 and ETF<=Q. pin size may be larger than Q, paid by genuine R role.
  defp cons_preflight(pin_size, {n, size}) do
    prospective = list_from_summary(n + 1, pin_size - 1 + body_sum(n, size))
    if n + 1 <= @k and prospective <= @q,
      do: {:ok, %{count: n + 1, bytes: prospective}}, else: {:error, :generation_capture_capacity}
  end

  defp append_preflight({an, ae}, {bn, be}) do
    prospective = list_from_summary(an + bn, body_sum(an, ae) + body_sum(bn, be))
    if an + bn <= @k and prospective <= @q,
      do: {:ok, %{count: an + bn, bytes: prospective}}, else: {:error, :generation_capture_capacity}
  end

  # FUTURE-REF CONDITION: NEW_PID_EXT E(pid)=E(node)+13 and generated
  # NEWER_REFERENCE_EXT length<=5 => E(ref)<=E(node)+27. Thus owner PID cap S
  # implies future owner ref cap S+14. Source/toolchain gate must establish it.
  defp future_ref_bound, do: @s + 14
  defp alias_tag(ref_size), do: 6 + b(:alias) + ref_size - 1
  defp from(pid_size, ref_size), do: tuple([pid_size, alias_tag(ref_size)])
  defp call(payload_size, pid_size, ref_size),
    do: tuple([e(:"$gen_call"), from(pid_size, ref_size), payload_size])
  defp reply(payload_size, ref_size), do: tuple([alias_tag(ref_size), payload_size])

  defp pin(provider, handle_size, owner_size, epoch_size, operation_size, ref_size, holder_size) do
    fields = [provider: e(provider), owner: owner_size, owner_epoch: epoch_size,
              ref: ref_size, operation: operation_size, handles: handle_size, kind: e(:request)]
    fields = if provider == @t, do: fields ++ [holder: holder_size], else: fields
    map_size_etf(Enum.map(fields, fn {key, size} -> {e(key), size} end))
  end

  defp bounds do
    r = future_ref_bound()
    pg = pin(@g, @h, @s, @s, r, r, @s)
    pt = pin(@t, @h, @s, @s, r, r, @s)
    %{h: @h, q: @q, s: @s, k: @k, future_ref: r,
      g_pin: pg, t_pin: pt, genuine_pin: max(pg, pt),
      g_singleton: list_size_etf([pg]), t_singleton: list_size_etf([pt])}
  end

  # Exact finite replacement vocabulary proposed for checked path only.
  # Existing Lifecycle raw errors DO NOT currently satisfy this contract.
  defp finite_error_size do
    [:invalid_generation_capture, :generation_capture_capacity, :generation_unavailable,
     :generation_pin_release_failed, :cleanup_unconfirmed, :invalid_resource_holder,
     :byte_limit, :stale_generation, :deadline_exceeded, :cleanup_pending]
    |> Enum.map(&e/1) |> Enum.max()
  end

  defp rows(m, retained, assumed_b) when is_integer(m) and m > 0 and retained >= 0 do
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
    # Elixir GenServer.call1117..1131 repeats server/request/timeout on failure.
    # This is conditional on a bounded reason; raw Lifecycle operation_exit and
    # protect throw/exit reasons remain UNQUALIFIED in current production code.
    finite_call_reason = max(finite_error_size(), tuple([e(:deadline_exceeded), e(:cleanup_pending)]))
    call_failure = [update, snapshot_call, pin_call, release]
      |> Enum.map(fn request ->
        descriptor = tuple([e(GenServer), e(:call), list_size_etf([s, request, d])])
        tuple([finite_call_reason, descriptor])
      end)
      |> Enum.max()
    monitor_down = tuple([e(:DOWN), r, e(:process), s, finite_call_reason])
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
      {:cancel_control, z.k, cancel},
      {:known_call_failure_descriptor, 1, call_failure},
      {:known_monitor_down, 1, monitor_down},
      {:cleanup_observation, 2, cleanup},
      {:finite_failure_payload, 1, err}
    ]
  end

  # Machine-readable complete role descriptors; documentation table expands the
  # constructor-size variables. These descriptors are worksheet output only;
  # the proposed retained plan is the five-element tuple paid by :plan.
  defp role_specs(rs) do
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
      known_call_failure_descriptor: {:caller, "{finite_reason,{GenServer,:call,[server,complete_request,timeout]}}", :call_return},
      known_monitor_down: {:caller, "{:DOWN,monitor,:process,pid,finite_reason}", :call_return},
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
  defp settle(m, retained, assumed_b, iterations) when iterations < 64 do
    rs = rows(m, retained, assumed_b)
    total = Enum.reduce(rs, 0, fn {_, count, bytes}, sum -> sum + count * bytes end)
    if total == assumed_b,
      do: {:ok, %{qualification: :conditional_not_runtime_ready, m: m, retained: retained,
            bounds: bounds(), roles: role_specs(rs), total: total, fixed_point_iterations: iterations,
            prerequisites: @prerequisites}},
      else: settle(m, retained, total, iterations + 1)
  end

  defp settle(_, _, _, _), do: @capacity
end
