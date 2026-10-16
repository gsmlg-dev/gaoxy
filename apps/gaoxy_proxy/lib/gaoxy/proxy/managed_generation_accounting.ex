defmodule Gaoxy.Proxy.ManagedGenerationAccounting do
  @moduledoc false
  @behaviour Gaoxy.HTTP.Generation.Accounting
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

  @impl true
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

  @impl true
  def preflight_append(new_pins, existing_pins) do
    if captures?(new_pins) and captures?(existing_pins),
      do:
        append_preflight(
          {length(new_pins), e(new_pins)},
          {length(existing_pins), e(existing_pins)}
        ),
      else: @invalid
  end

  @impl true
  def finite_checked_reason(reason) when reason in @finite, do: reason
  def finite_checked_reason({:deadline_exceeded, :cleanup_pending}), do: :deadline_exceeded
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
      do: {:ok, %{count: n + 1, bytes: prospective}},
      else: {:error, :generation_capture_capacity}
  end

  defp append_preflight({an, ae}, {bn, be}) do
    prospective = list_from_summary(an + bn, body_sum(an, ae) + body_sum(bn, be))

    if an + bn <= @k and prospective <= @q,
      do: {:ok, %{count: an + bn, bytes: prospective}},
      else: {:error, :generation_capture_capacity}
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
    fields = [
      provider: e(provider),
      owner: owner_size,
      owner_epoch: epoch_size,
      ref: ref_size,
      operation: operation_size,
      handles: handle_size,
      kind: e(:request)
    ]

    fields = if provider == @t, do: fields ++ [holder: holder_size], else: fields
    map_size_etf(Enum.map(fields, fn {key, size} -> {e(key), size} end))
  end

  defp bounds do
    r = future_ref_bound()
    pg = pin(@g, @h, @s, @s, r, r, @s)
    pt = pin(@t, @h, @s, @s, r, r, @s)

    %{
      h: @h,
      q: @q,
      s: @s,
      k: @k,
      future_ref: r,
      g_pin: pg,
      t_pin: pt,
      genuine_pin: max(pg, pt),
      g_singleton: list_size_etf([pg]),
      t_singleton: list_size_etf([pt])
    }
  end

  # Exact finite replacement vocabulary proposed for checked path only.
  # Existing Lifecycle raw errors DO NOT currently satisfy this contract.
  defp finite_error_size do
    [
      :invalid_generation_capture,
      :generation_capture_capacity,
      :generation_unavailable,
      :generation_pin_release_failed,
      :cleanup_unconfirmed,
      :invalid_resource_holder,
      :byte_limit,
      :stale_generation,
      :deadline_exceeded,
      :cleanup_pending
    ]
    |> Enum.map(&e/1)
    |> Enum.max()
  end

  defp rows(m, retained, assumed_b) when is_integer(m) and m > 0 and retained >= 0 do
    z = bounds()
    s = z.s
    r = z.future_ref
    # complete signed64 integer ETF upper bound; deadline gate required
    d = 12
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

    pin_call =
      max(
        tuple([e(:pin), z.h, s, e(:request), r, d]),
        tuple([e(:pin_many), z.h, s, e(:request), r, d])
      )

    pin_ok = tuple([e(:ok), z.genuine_pin])
    pin_result = max(pin_ok, err)
    accumulator = tuple([e(:ok), z.q])
    # Generation repeats outside complete Router. Both complete members bounded M.
    snapshot = tuple([e(:ok), m, m, z.q])
    release = tuple([e(:release), z.q - 6])
    cancel = max(tuple([e(:cancel_pin), s, r]), tuple([e(:cancel_pins), s, r]))
    # Bounded observability via existing Telemetry.emit with empty scope, no raw
    # target result, exception, stack, callback output or arbitrary scope metadata.
    cleanup_metadata =
      map_size_etf([
        {e(:store), s},
        {e(:holder), s},
        {e(:lease), s},
        {e(:stage), max(e(:release), e(:acquisition))},
        {e(:cleanup), e(:cleanup_unconfirmed)}
      ])

    cleanup =
      tuple([
        list_size_etf([e(:gaoxy), e(:generation_capture_cleanup)]),
        map_size_etf([{e(:count), e(1)}]),
        cleanup_metadata
      ])

    update = tuple([e(:update), s, e(retained + assumed_b)])
    # Elixir GenServer.call1117..1131 repeats server/request/timeout on failure.
    # This is conditional on a bounded reason; raw Lifecycle operation_exit and
    # protect throw/exit reasons remain UNQUALIFIED in current production code.
    finite_call_reason =
      max(finite_error_size(), tuple([e(:deadline_exceeded), e(:cleanup_pending)]))

    call_failure =
      [update, snapshot_call, pin_call, release]
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
      snapshot_requester_payload:
        {:requester, "{:snapshot_for_request,holder,deadline,module}", :snapshot_return},
      snapshot_call_wire: {:store, "$gen_call(snapshot_request)", :snapshot_return},
      snapshot_store_payload:
        {:store, "{:snapshot_for_request,holder,deadline,module}", :snapshot_return},
      snapshot_store_from: {:store, "{requester,alias_tag}", :snapshot_return},
      validated_manifest:
        {:store, "complete validated current Router.resources", :snapshot_return},
      partition_map: {:store, "%{{provider,owner}=>complete_batch}", :acquisition_end},
      provider_handle_normalization:
        {:provider, "complete input/reverse_acc/unique_output lists", :provider_return},
      provider_request_payload:
        {:store, "{:pin|:pin_many,batch,holder,:request,operation,deadline}", :provider_return},
      provider_call_wire: {:provider, "$gen_call(provider_request)", :provider_return},
      provider_owner_payload:
        {:provider, "{:pin|:pin_many,batch,holder,:request,operation,deadline}", :provider_return},
      provider_owner_from: {:provider, "{store,alias_tag}", :provider_return},
      genuine_provider_pin: {:provider, "complete actual G7/T8 public pin", :receipt_validation},
      provider_result_payload: {:provider, "{:ok,complete_pin}|finite_error", :provider_return},
      provider_reply_wire: {:store, "{alias_tag,provider_result}", :receipt_validation},
      provider_store_received_result:
        {:store, "{:ok,complete_pin}|finite_error", :receipt_validation},
      checked_acquisition_accumulator:
        {:store, "{:ok,complete_pins} input/current/output roots", :snapshot_return},
      original_provenance:
        {:store, "[{original_provider,original_owner,original_operation}]", :acquisition_end},
      store_snapshot_payload:
        {:store, "{:ok,generation,complete_router,complete_pins}|finite_error", :snapshot_return},
      store_snapshot_wire: {:requester, "{alias_tag,complete_snapshot_result}", :snapshot_return},
      requester_snapshot_received:
        {:requester, "{:ok,generation,complete_router,complete_pins}|finite_error", :request_end},
      caller_capture_inputs_and_output:
        {:requester, "complete_existing,complete_new,complete_accepted_combined lists",
         :request_end},
      release_payload: {:requester, "{:release,complete_accepted_pin}", :release_return},
      release_call_wire: {:provider, "$gen_call(release)", :release_return},
      release_reply_wire: {:requester, "{alias_tag,:ok|finite_error}", :release_return},
      cancel_control:
        {:provider, "{:cancel_pin|:cancel_pins,store,original_operation}", :acquisition_end},
      known_call_failure_descriptor:
        {:caller, "{finite_reason,{GenServer,:call,[server,complete_request,timeout]}}",
         :call_return},
      known_monitor_down: {:caller, "{:DOWN,monitor,:process,pid,finite_reason}", :call_return},
      cleanup_observation:
        {:requester, "{[:gaoxy,:generation_capture_cleanup],%{count:1},bounded_metadata}",
         :emit_return},
      finite_failure_payload: {:requester, "{:error,finite_checked_reason}", :request_end}
    }

    Enum.map(rs, fn {name, count, cap} ->
      {owner, constructor, release} = Map.fetch!(metadata, name)

      %{
        name: name,
        owner: owner,
        constructor: constructor,
        cap: cap,
        multiplicity: count,
        subtotal: count * cap,
        release: release
      }
    end)
  end

  # Exact arithmetic fixed point pays ETF byte-length of B itself in plan/update.
  # No circular unpriced integer and no guessed integer cap or wrapper headroom.
  defp settle(m, retained, assumed_b, iterations) when iterations < 64 do
    rs = rows(m, retained, assumed_b)
    total = Enum.reduce(rs, 0, fn {_, count, bytes}, sum -> sum + count * bytes end)

    if total == assumed_b,
      do:
        {:ok,
         %{
           qualification: :conditional_not_runtime_ready,
           m: m,
           retained: retained,
           bounds: bounds(),
           roles: role_specs(rs),
           total: total,
           fixed_point_iterations: iterations,
           prerequisites: @prerequisites
         }},
      else: settle(m, retained, total, iterations + 1)
  end

  defp settle(_, _, _, _), do: @capacity

  @runtime_prerequisites ~w(checked_runtime_constructors pre_admission_constructor_gate
    real_public_owner_boundaries native_h1_capture downstream_h2_capture final_independent_review)a

  @impl true
  def reservation(m, context) do
    if runtime_context?(m, context) do
      case settle_runtime_numeric(m, elem(context, 6), 0, 0) do
        b when is_integer(b) -> {:ok, {:native_generation_capture_v1, m, @h, @q, b}}
        _ -> @capacity
      end
    else
      @invalid
    end
  end

  def runtime_worksheet(m, context) do
    if runtime_context?(m, context),
      do: settle_runtime_report(m, elem(context, 6), 0, 0),
      else: @invalid
  end

  defp runtime_context?(m, {store, holder, gate, lease, :request, deadline, retained})
       when is_integer(m) and m > 0 and is_pid(store) and is_pid(holder) and is_pid(gate) and
              is_reference(lease) and is_integer(deadline) and deadline >= @min and
              deadline <= @max - 1_000 and is_integer(retained) and retained >= 0,
       do: scalar?(store) and scalar?(holder) and scalar?(gate) and scalar?(lease)

  defp runtime_context?(_, _), do: false

  @impl true
  def validate_manifest(handles) when is_list(handles) and length(handles) <= @k do
    if e(handles) <= @h and Enum.all?(handles, &managed_handle?/1) and
         Enum.all?(handles, fn handle ->
           Enum.all?(handles, fn other ->
             other.provider !== handle.provider or other.owner !== handle.owner or
               other.owner_epoch === handle.owner_epoch
           end)
         end),
       do: :ok,
       else: @invalid
  end

  def validate_manifest(_), do: @invalid

  defp managed_handle?(%{provider: @t, owner: owner, owner_epoch: epoch, resource: resource} = h),
    do:
      map_size(h) == 4 and is_pid(owner) and scalar?(owner) and
        is_reference(epoch) and scalar?(epoch) and is_reference(resource) and scalar?(resource)

  defp managed_handle?(
         %{
           provider: @g,
           owner: owner,
           owner_epoch: epoch,
           group: group,
           generation: generation,
           max_url_bytes: bytes
         } = h
       ) do
    is_pid(owner) and scalar?(owner) and is_reference(epoch) and scalar?(epoch) and
      is_reference(generation) and scalar?(generation) and is_binary(group) and
      byte_size(group) in 1..128 and is_integer(bytes) and bytes in 1..8_192 and
      group_dependencies?(h)
  end

  defp managed_handle?(_), do: false

  defp group_dependencies?(h) when map_size(h) == 6, do: true

  defp group_dependencies?(%{transports: transports} = h)
       when map_size(h) in [7, 8] and is_list(transports) and length(transports) in 1..32 do
    (map_size(h) == 7 or Map.get(h, :execution_profile) == :managed_h2) and
      Enum.all?(transports, fn t ->
        is_map(t) and Map.get(t, :provider) == @t and managed_handle?(t)
      end) and Enum.uniq(transports) === transports
  end

  defp group_dependencies?(_), do: false

  @impl true
  def correlate(pin, {provider, owner, operation, [_ | _] = handles}, holder)
      when provider in [@g, @t] and is_pid(owner) and is_reference(operation) and is_pid(holder) do
    if validate_manifest(handles) == :ok and pin?(pin) and pin.provider === provider and
         pin.owner === owner and pin.operation === operation and pin.handles === handles and
         (provider != @t or pin.holder === holder) and
         Enum.all?(handles, fn h ->
           h.provider === provider and h.owner === owner and h.owner_epoch === pin.owner_epoch
         end),
       do: :ok,
       else: @invalid
  end

  def correlate(_, _, _), do: @invalid

  @impl true
  def release(%{provider: provider} = pin, deadline)
      when provider in [@g, @t] and is_integer(deadline) and deadline >= @min and deadline <= @max do
    cond do
      not pin?(pin) ->
        @invalid

      Gaoxy.Lifecycle.remaining(deadline) == 0 ->
        {:error, :deadline_exceeded}

      true ->
        case provider.release(pin, deadline) do
          :ok -> :ok
          {:error, reason} -> {:error, finite_checked_reason(reason)}
          _ -> {:error, :generation_unavailable}
        end
    end
  catch
    _, _ -> {:error, :generation_unavailable}
  end

  def release(_, _), do: @invalid

  # Only scalar arithmetic on the Admission path. In particular no call to
  # bounds/rows/worksheet/role_specs, no role list and no report map is made.
  defp settle_runtime_numeric(m, retained, b, n) when n < 64 do
    next = sum_runtime_numeric(m, retained, b)
    if next == b, do: b, else: settle_runtime_numeric(m, retained, next, n + 1)
  end

  defp settle_runtime_numeric(_, _, _, _), do: :generation_capture_capacity

  defp sum_runtime_numeric(m, retained, b) do
    s = @s
    f = future_ref_bound()
    d = 12
    a = max(e(@g), e(@t))
    r = 75_921
    alias_size = 6 + e(:alias) - 1 + f - 1
    from_size = s + alias_size + 1
    call_head = e(:"$gen_call") + from_size
    reply_head = alias_size + 1
    finite = e(:generation_pin_release_failed)
    err2 = e(:error) + finite + 1
    status = max(e(:clean), e(:cleanup_unconfirmed))
    err3 = e(:error) + finite + status
    context = 4 * s + e(:request) + d + e(retained) - 4
    plan_inner = e(:native_generation_capture_v1) + e(m) + e(@h) + e(@q) + e(b) - 2
    plan = e(:ok) + plan_inner + 1
    update = e(:update) + s + e(retained + b)
    snapshot_call = e(:snapshot_for_request) + s + d + e(@accounting) - 1
    partition = 6 + @h - 7 + @k * (8 + a - 1 + s - 1)
    pin_call = max(e(:pin), e(:pin_many)) + @h + s + e(:request) + f + d - 3
    pin_result = max(e(:ok) + r + 1, err2)
    accumulator = e(:ok) + @q + 1
    ledger = @h + @k * (a + s + f + 5)
    snapshot = max(e(:ok) + 2 * m + @q - 1, err3)
    release = e(:release) + @q - 6 + 1
    cancel = max(e(:cancel_pin), e(:cancel_pins)) + s + f
    reason = max(e(:deadline_exceeded) + e(:cleanup_pending) + 1, err3)
    request = max(max(update, snapshot_call), max(pin_call, release))
    descriptor_args = 7 + s - 1 + request - 1 + d - 1
    call_failure = reason + e(GenServer) + e(:call) + descriptor_args + 1
    down = e(:DOWN) + f + e(:process) + s + reason - 2

    metadata =
      6 + e(:store) + s - 2 + e(:holder) + s - 2 + e(:lease) + s - 2 +
        e(:stage) + max(e(:release), e(:acquisition)) - 2 + e(:cleanup) + e(:cleanup_unconfirmed) -
        2

    cleanup_event = 7 + e(:gaoxy) - 1 + e(:generation_capture_cleanup) - 1
    cleanup_count = 6 + e(:count) + e(1) - 2
    cleanup = cleanup_event + cleanup_count + metadata
    entry = a + s + f + @h - 1
    manifest_result = e(:ok) + @h + 1
    acquisition_control = max(e(:cont) + (@q + ledger + 1) + 1, e(:halt) + err3 + 1)

    config =
      6 + e(:store) + s - 2 + e(:max_config_bytes) + e(m) - 2 +
        e(:accounting) + e(@accounting) - 2

    preflight_summary = 6 + e(:count) + e(@k) - 2 + e(:bytes) + e(@q) - 2

    preflight =
      max(
        e(:ok) + preflight_summary + 1,
        max(
          e(:error) + e(:invalid_generation_capture) + 1,
          e(:error) + e(:generation_capture_capacity) + 1
        )
      )

    release_result = max(e(:ok), e(:error) + e(:generation_pin_release_failed) + 1)

    context + plan + update + (call_head + update) + (reply_head + max(e(:ok), err2)) +
      snapshot_call + (call_head + snapshot_call) + snapshot_call + from_size + @h +
      partition + 3 * @h + pin_call + (call_head + pin_call) + pin_call + from_size +
      r + pin_result + (reply_head + pin_result) + pin_result + 3 * accumulator +
      3 * ledger + snapshot + (reply_head + snapshot) + snapshot + 3 * @q +
      release + (call_head + release) + (reply_head + max(e(:ok), err2)) +
      (@k + 1) * cancel + call_failure + down + 2 * cleanup + err3 + entry + 2 * @h +
      manifest_result + 3 * acquisition_control + 2 * partition + config + 2 * preflight +
      2 * err3 + 2 * release_result + d + 2 * status + d + 2 * e(m) + 2 * e(retained) +
      2 * e(b) + 2 * e(retained + b) + 2 * e(b) + 2 * e(@k) + 3 * d
  end

  defp settle_runtime_report(m, retained, b, n) when n < 64 do
    next = sum_runtime_numeric(m, retained, b)

    if next == b do
      {:ok,
       %{
         qualification: :conditional_not_runtime_ready,
         profile: :native_generation_checked_capture,
         m: m,
         retained: retained,
         bounds: Map.put(bounds(), :cancel_controls, @k + 1),
         roles: runtime_role_specs(runtime_rows(m, retained, b)),
         total: b,
         fixed_point_iterations: n,
         prerequisites: @runtime_prerequisites
       }}
    else
      settle_runtime_report(m, retained, next, n + 1)
    end
  end

  defp settle_runtime_report(_, _, _, _), do: @capacity

  # Diagnostic only: construct the full table AFTER the numeric fixed point.
  defp runtime_rows(m, retained, b) do
    a = max(e(@g), e(@t))
    f = future_ref_bound()
    d = 12
    status = max(e(:clean), e(:cleanup_unconfirmed))
    err3 = tuple([e(:error), finite_error_size(), status])
    ledger = @h + @k * (a + @s + f + 5)
    partition = 6 + @h - 7 + @k * (8 + a - 1 + @s - 1)
    old_reason = max(finite_error_size(), tuple([e(:deadline_exceeded), e(:cleanup_pending)]))
    reason_delta = max(old_reason, err3) - old_reason

    preflight =
      max(
        tuple([e(:ok), map_size_etf([{e(:count), e(@k)}, {e(:bytes), e(@q)}])]),
        max(
          tuple([e(:error), e(:invalid_generation_capture)]),
          tuple([e(:error), e(:generation_capture_capacity)])
        )
      )

    release_status = max(e(:ok), tuple([e(:error), e(:generation_pin_release_failed)]))

    config =
      map_size_etf([
        {e(:store), @s},
        {e(:max_config_bytes), e(m)},
        {e(:accounting), e(@accounting)}
      ])

    control = max(tuple([e(:cont), tuple([@q, ledger])]), tuple([e(:halt), err3]))

    Enum.map(rows(m, retained, b), fn
      {:plan, count, cap} ->
        {:plan, count, max(cap, tuple([e(:ok), cap]))}

      {:original_provenance, _, _} ->
        {:original_provenance, 3, ledger}

      {:cancel_control, _, cap} ->
        {:cancel_control, @k + 1, cap}

      {:finite_failure_payload, count, _} ->
        {:finite_failure_payload, count, err3}

      {name, count, cap} when name in [:known_call_failure_descriptor, :known_monitor_down] ->
        {name, count, cap + reason_delta}

      row ->
        row
    end) ++
      [
        {:original_current_entry, 1, tuple([a, @s, f, @h])},
        {:manifest_normalization, 2, @h},
        {:manifest_validation_result, 1, tuple([e(:ok), @h])},
        {:acquisition_control, 3, control},
        {:partition_scratch, 2, partition},
        {:checked_config, 1, config},
        {:checked_preflight_result, 2, preflight},
        {:checked_acquisition_failure, 2, err3},
        {:checked_release_status, 2, release_status},
        {:cleanup_deadline, 1, d},
        {:finite_control_status, 2, status},
        {:original_deadline, 1, d},
        {:numeric_m, 2, e(m)},
        {:numeric_retained, 2, e(retained)},
        {:numeric_reservation, 2, e(b)},
        {:numeric_retained_plus_reservation, 2, e(retained + b)},
        {:numeric_next, 2, e(b)},
        {:numeric_iterations, 2, e(@k)},
        {:numeric_timing, 3, d}
      ]
  end

  defp runtime_role_specs(rs) do
    metadata = %{
      plan:
        {:requester, "{:ok,{:native_generation_capture_v1,M,H,Q,B}} and retained inner plan",
         :request_end},
      original_provenance:
        {:store,
         "[{original_provider,original_owner,original_operation,complete_original_batch}] input/current/output",
         :acquisition_end},
      cancel_control:
        {:provider,
         "65 complete {:cancel_pin|:cancel_pins,store,original_operation}; T postcheck plus full Store ledger",
         :cancellation_uncertain},
      finite_failure_payload:
        {:requester, "{:error,finite_checked_reason,:clean|:cleanup_unconfirmed}", :request_end},
      original_current_entry:
        {:store, "{provider,owner,operation,complete_original_batch}", :acquisition_end},
      manifest_normalization:
        {:store, "complete raw and normalized manifest roots", :acquisition_end},
      manifest_validation_result:
        {:store, "{:ok,complete_normalized_manifest}", :acquisition_end},
      acquisition_control:
        {:store, "{:cont,{complete_pins,complete_ledger}}|{:halt,checked_error_triple}",
         :acquisition_end},
      partition_scratch:
        {:store, "complete partition input/current/output map roots", :acquisition_end},
      checked_config:
        {:requester, "%{store:pid,max_config_bytes:M,accounting:module}", :request_end},
      checked_preflight_result:
        {:caller,
         "{:ok,%{count:count,bytes:bytes}}|{:error,:invalid_generation_capture|:generation_capture_capacity}",
         :preflight_return},
      checked_acquisition_failure:
        {:store, "{:error,finite_checked_reason,:clean|:cleanup_unconfirmed}", :acquisition_end},
      checked_release_status:
        {:requester, ":ok|{:error,:generation_pin_release_failed}", :cleanup_end},
      cleanup_deadline: {:requester, "absolute original deadline+1000", :cleanup_end},
      finite_control_status: {:caller, ":clean|:cleanup_unconfirmed", :request_end},
      original_deadline: {:caller, "original absolute signed64 deadline", :request_end},
      numeric_m: {:requester, "configured M integer current/next roots", :reservation_return},
      numeric_retained: {:requester, "retained integer current/next roots", :reservation_return},
      numeric_reservation: {:requester, "B integer current/next roots", :reservation_return},
      numeric_retained_plus_reservation:
        {:requester, "retained+B integer current/next roots", :reservation_return},
      numeric_next: {:requester, "Bnext integer current/next roots", :reservation_return},
      numeric_iterations:
        {:requester, "bounded fixed-point iteration integer", :reservation_return},
      numeric_timing: {:requester, "three complete signed64 timing scalar roots", :cleanup_end}
    }

    Enum.map(rs, fn {name, count, cap} ->
      case Map.fetch(metadata, name) do
        {:ok, {owner, constructor, release}} ->
          %{
            name: name,
            owner: owner,
            constructor: constructor,
            cap: cap,
            multiplicity: count,
            subtotal: count * cap,
            release: release
          }

        :error ->
          hd(role_specs([{name, count, cap}]))
      end
    end)
  end
end
