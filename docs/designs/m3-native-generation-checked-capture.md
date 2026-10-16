# Native Generation checked capture: bounded runtime design2

Task `native_generation_checked_capture_design`, direct source-only assignment, prepared 2026-10-16; revision2 closes two accepted source-readiness findings. Revision1 and its FAIL readiness receipt remain immutable. This documentation correction adds no runtime repair round. Decision: execute ONE runtime integration stage, automatically after the pure worksheet predecessor closes. Its endpoint is accounted native Generation → Store → real public managed owners → Router → bounded cleanup, including native H1 and downstream-H2 smoke and the mandatory actual-source pre-Admission constructor gate. Constructor arithmetic is an internal TDD task of this integration stage; it is not a third pure worksheet stage.

## Custody and release condition

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, revision1 inspected HEAD `48a71a70acbe9cb46f99b82e4062c6f5f25d9667`; revision2 read-only rebind HEAD `94d47d11fbd9040bd49e15829e8405d82fd0618d`. Parent has advanced the predecessor commit and owns current worksheet-doc modifications/closure receipts; this author preserves that work and does not independently infer full predecessor acceptance from the new SHA. At inspection the worksheet module/test, worksheet docs and worksheet evidence directory were untracked parent-owned work. Preserve them and all unrelated user files. Parent alone owns repository/runtime/build/test/format/evidence/index/Git; this author owns only the paired /tmp design2, plan2 and decision2.json. No implementation, runtime test or local commit was performed by this author.

Parent reports worksheet green2: 24 tests/0 failures, format/compile PASS; SPEC/CODE/fresh verification/local commit were not all closed at assignment. Those reports are not this author's executed checks. Before runtime edits, parent records actual passing predecessor SPEC and CODE, fresh nonzero scoped verification, committed source/index custody, and current HEAD. This document can be prepared now; disposition is PREPARED_CONDITIONAL_ON_PREDECESSOR, not runtime implementation released or accepted. Rebind source hashes and toolchain at execution; concurrent parent changes are not permission to overwrite.

Counters remain worksheet failedGREEN1 / test-contract repair1 / production repairs0; inherited group failedGREEN24 / root failure-events27 / Astra2/2 exhausted. This source-only assignment adds no repair round. Preserve subsequent parent counters, no reset or third Astra. Necessary local Sol repairs continue under authorization with fresh independent review and unchanged assertions.

## Selected optional seam and preserved surface

Add a small behavior `Gaoxy.HTTP.Generation.Accounting` in gaoxy_http, not a core dependency on proxy. Its callbacks are implemented by `Gaoxy.Proxy.ManagedGenerationAccounting`; gaoxy/gaoxy_http have NO `Gaoxy.Proxy` module references. Existing `Generation.init(store)`, config `%{store: pid, snapshot_bytes: 2*M}`, call behavior, Store start/options/prepare/activate/snapshot and `snapshot_for_request/3` remain accepted as before. Generic Resources.validate/pin_many/release and legacy five/six-key pins and baseline/preparation/request kinds retain their existing assertions.

Opt-in endpoint input is exactly `Generation.init({store, accounting: module})`, with one unique keyword. It resolves Store/limits with the existing initialization procedure and returns `%{store: pid, max_config_bytes: M, accounting: module}`. M remains ANY configured positive integer; default1048576 is not a cap. Validate module load/exported behavior callbacks at initialization. Put the explicit opt-in init and call clauses before legacy clauses. Do not fall back to legacy on a checked error. No runtime registry, mode process or automatic activation toggle.

Behavior contracts (all errors below are finite checked atoms):

```elixir
reservation(m, {store, holder, gate, lease, :request, deadline, retained})
  # => {:ok, {:native_generation_capture_v1, m, 65_536, 65_536, b}} | {:error, reason}
validate_manifest(normalized_handles) # => :ok | {:error, reason}
correlate(pin, {provider, owner, operation, original_batch}, original_holder)
  # => :ok | {:error, reason}; validates complete pin schema AND exact original correlation
preflight_cons(actual_pin, actual_pins) # existing actual-operand result, no candidate construction
preflight_append(actual_new, actual_existing) # existing actual-operand result
finite_checked_reason(raw_reason) # existing finite atom mapping, no recursive diagnostic retention
release(accepted_pin, absolute_cleanup_deadline) # => :ok | {:error, finite_reason}
```

The behavior does not interpret managed G/T schemas. Only the supplied module knows G/T. Checked Resources code invokes callback modules directly, without constructing apply-argument lists or runtime worksheet/role objects. The callback is trusted application code; arbitrary callback allocation or blocking is outside this selected source-role contract. Invalid/missing callback results normalize to `:generation_unavailable`, never silently select legacy.

Add public `Generation.snapshot_for_request/4` with accounting module, preserving arity3. Wire is `{:snapshot_for_request, holder, deadline, module}`. Store checks holder===actual GenServer caller before invoking any provider. Success remains `{:ok, generation, complete_router, accepted_pins}`. Checked error is `{:error, finite_reason, :clean | :cleanup_unconfirmed}`. The new checked arity normalizes GenServer call failures, including timeout descriptor, without altering legacy request/3 outcomes. Store never receives lease/gate/telemetry scope.

Add `Resources.pin_many_checked(handles, holder, deadline, accounting)` and `release_checked(pins, cleanup_deadline, accounting)`; leave existing functions untouched. Checked acquisition accepts only request-kind managed inputs selected by the callback. Generic Resources.validate deduplicates the raw <=64, ETF<=H manifest; checked validation allows only G/T owners with PID/epoch scalars<=S and a consistent original owner_epoch within each provider/owner batch. It does not add a global resource/group/depth cap. No invented minimal handles or projection of original batches. Unknown provider fails before invocation.

## Authentic custody, correlation and preflight order

Store executes checked acquisition synchronously, under original request deadline D, without a new worker. Partition normalized handles by `{provider,owner}` using the existing complete-batch behavior. For every batch:

1. Check remaining(D)>0 and live holder; allocate operation once.
2. Construct entry `{provider, owner, operation, original_batch}` and ledger-cons it BEFORE invoking that provider. This includes the current operation even when the callback fails or returns malformed success. Ledger entries are bounded trusted manifest facts; ledger construction is not capture-list cons and has its own complete role budget.
3. Invoke original `provider.pin_many(batch, holder, :request, operation, D)`. Catch/normalize callback raise/throw/exit immediately; do not retain raw diagnostics in a returned result, ledger, plan, event or history. Current Lifecycle is unchanged.
4. On success, validate complete G7/T8 original pin. Exact provider, owner, original operation, full batch handles with order/values, every original epoch, and kind===:request must match. T.holder===original requester. G has no public holder key; do not invent one. New ref follows existing schema/source premise. Reject a structurally valid pin with a substituted operation/owner/handles/epoch/holder. Never construct a reduced pin to make it fit.
5. Call actual-operand `preflight_cons(pin,pins)` BEFORE `[pin | pins]`. Genuine receipt can exceed Q while fitting source R; account it and reject capacity before cons. On any error cancel ALL original ledger entries using original provider/owner/operation, not identity extracted from the failed pin.
6. Before Store publishes success, recheck D/live holder; expired/dead-holder acquisition cancels the original ledger and cannot publish a late usable snapshot. Success drops Store ledger; it is never sent to requester or retained in Store state.

Requester calls `preflight_append(new_pins,exchange.resource_pins)` BEFORE `new_pins ++ existing_pins`. Both inputs must be actual accepted request-only lists, each <=64/Q; existing invalid/baseline/preparation pins fail only on opt-in path. If append rejects after successful snapshot, requester releases the accepted new pins using bounded checked release, returns original finite preflight error, and emits acquisition uncertainty only if that release is unconfirmed. It never dispatches Router or attempts provider.cancel as requester: provider cancel authority is the original Store acquirer.

Store failure after any operation was dispatched sends one rollback cancellation for each original ledger entry; cancellation returning :ok only means sent. Existing T.pin_many/5 has an ADDITIONAL public-path send: after a successful owner reply, its deadline/holder postcheck may fail and T.cancel/2 sends cancellation for the current original operation before returning pending. Store must still rollback its full original ledger, including that current operation. Thus the serial checked path with k<=64 started batches can have k+1<=65 asynchronous cancellation controls outstanding, two for the failed current T operation. Preserve T legacy semantics; do not suppress its send or deduplicate Store rollback by reading a failed receipt. Checked result status stays cleanup_unconfirmed. With no started ledger a validation failure is clean. A checked Store call transport failure is conservatively cleanup_unconfirmed at requester; its original finite error remains primary, and Store retains responsibility for any late rollback. Do not add a new requester cancellation issuer, cleanup process or global tombstone ledger; the existing T public callback send and Store original-ledger rollback are both retained and budgeted. Owner deadline/holder monitoring remains the existing lifetime boundary; B is retained until ordinary request/lease teardown, not a claim that every asynchronous cancellation is confirmed before that teardown.

## Bounded calls and ordinary lifetime

Charge before effects. On opt-in call, form the bounded original context, let retained=Exchange.retained_bytes(exchange), run the compact pure reservation callback, verify exact five-tuple/M/H/Q/nonnegative B, then set charged.route_bytes=exchange.route_bytes+B. This ADDITION replaces the legacy2*M allowance only in the opt-in branch; do not add both or overwrite prior nested route reservations. Call public Admission.update with total `Exchange.retained_bytes(charged)` BEFORE any checked snapshot request/Store/provider effect. If admission fails, return finite error with charged exchange and no Store/provider call; the proposed route_bytes is never interpreted as a successful gate charge.

Necessary additive API: `Admission.update(gate,lease,bytes,timeout)` calls GenServer.call with explicit finite positive timeout; update/3 keeps its existing default5000 behavior. Checked path selects timeout=min(5000,remaining(D)), rejects zero without dispatch, normalizes call failures finitely and preserves the exact original absolute deadline. Test no provider/Store dispatch when the real gate refuses or has not replied. GenServer timeout can leave a gate update queued: it does not authorize proceeding to snapshot or refunding a possible gate charge. No generic Admission state-machine semantics change.

Existing G/T expose only release/1. G currently uses fresh100ms and T fresh1000ms; there is no release/2 today. Add supported public `release(pin, absolute_deadline)` to both same-repository owners; preserve release/1 guards/errors/defaults and existing assertions. Checked accounting.release/2 dispatches the matched G/T public release/2 with shared deadline Dc=D+1000, never raw private owner calls. This is a necessary compatibility repair, already authorized by parent, not an upstream dependency workaround. Cleanup checks remaining(Dc)>0 before each synchronous release; all releases share Dc, never restart per-pin timeouts. At/after Dc, stop synchronous dispatch and return unconfirmed. With <=64 accepted pins, the whole serial synchronous cleanup wait is bounded by the one absolute Dc plus scheduling overhead, not64*5000ms. Provider callbacks and synchronous telemetry handlers are trusted code; do not claim a hard scheduler/subscriber execution-time bound. No unpriced proxy helper/new process.

Acquire uses D. Known GenServer relative timeout terms for snapshot/provider/release are bounded by selected signed64 context: D<=signed64max-1000 and signed64min<=now for the executing supported clock; require positive remaining timeout<=signed64max before dispatch, reject otherwise. Dc and timeout terms therefore fit d=12 complete ETF. Admission timeout<=5000 but is safely paid by d. At/after Dc asynchronous original-ledger cancellation sends may still be issued (no synchronous waiting), retaining uncertainty. Do not start a synchronous release after the shared deadline.

Every absolute retained-byte update after capture must include unchanged accumulated route_bytes, including body poll, response writes, trailer/finalization and failure paths. No decrement on provider release, sent cancel, release timeout, observer emission or successful Router return. Existing normal teardown releases lease; it is the only refund boundary in this stage. No worker transfer, cleanup attachment, native handoff ownership redesign or new Exchange field.

## C5: exact primary preservation and one bounded observation

Only requester emits the event. Store/Resources return a finite cleanup status and never emit. This single owner gives once-per-failed-capture cleanup emission without a dedup token/table or event history. No event on admission refusal (no capture effect) or clean prevalidation failure. A checked snapshot-call error emits once conservatively; late Store rollback does not emit another event.

Use existing `Telemetry.emit(:generation_capture_cleanup,%{count: 1},%{},metadata)` with metadata exactly `%{store: original_store, holder: original_requester, lease: original_lease, stage: :acquisition | :release, cleanup: :cleanup_unconfirmed}`. Empty scope only. No raw error/result/stack, pin, handles, arbitrary scope or exception module. A local observer wrapper catches every raise/throw/exit and drops it; it cannot change the endpoint primary. No second event when observing fails.

| Primary | Checked cleanup | Observable endpoint result |
|---|---|---|
| Finite checked acquisition/preflight error | unconfirmed | Preserve that finite primary; one stage:acquisition event; no Router dispatch |
| Router `{:ok,latest_exchange}` | all :ok | Exact Router result |
| Router `{:ok,latest_exchange}` | any non-ok/exception/deadline | `{:error,:generation_pin_release_failed,latest_exchange}`; one stage:release event |
| Router `{:error,reason,latest_exchange}` | any | EXACT original result; emit once only if cleanup unconfirmed |
| Router raise/throw/exit | any | EXACT original class/value/stack via `:erlang.raise/3`; emit once only if unconfirmed |

Do not enclose a newly constructed endpoint outcome wrapper in the accounting plan. Structure the Router try/catch narrowly: its catch saves original `__STACKTRACE__`, performs total checked cleanup/observation, then `:erlang.raise(kind,value,stack)`. After a normal Router return, cleanup and outcome selection run outside that catch. Cleanup itself returns finite statuses and catches provider/observer failures, preventing duplicate releases or masking primary. Arbitrary original Router result/exception remains ordinary endpoint-owned data; this reservation does not certify arbitrary endpoint heap or duplicate raw exception contents into new controls. A release error after a committed response is an endpoint outcome; do not assert a second wire response.

## Complete constructor rederivation inside the runtime stage

The historical worksheet64-cancel model and its conditional totals (M65536:2758572; M1048576:8656812, retained0) MUST NOT be copied into runtime or described as a complete current public-path budget. T.pin_many/5 lines108–127 has a post-owner-reply self-cancel omitted by that historical model. Preserve its64 multiplicity, numerical assertions and immutable evidence as the explicitly conditional historical model; runtime profile uses65 and all constructor changes below. The integration changes constructors. Add an independently checked runtime profile to worksheet output, without changing the historical worksheet report/old numerical assertions. Existing worksheet/2 keeps historical meaning. New `reservation/2` calls ONLY numeric arithmetic and returns the five-tuple. It must never call worksheet/2, rows/3, role_specs/1, build report/bounds maps or row lists, even transiently before Admission. Compile-time fixed atoms/constants and direct integer arithmetic are allowed. Share scalar numeric size functions and fixed-point summation; diagnostic role rows are built exclusively by explicit worksheet/report requests. Runtime reserve/report-equivalent sums are independently compared in tests.

Notation: E(t)=complete default ETF size; T(x...)=3+sum(x-1); Map(pairs)=6+sum(k+v-2); L(nonempty)=7+sum(element_size-1), L(empty)=2. H=Q65536, S2048, k64; A=max(E(G),E(T)); F=S+14=2062 from bound loaded OTP source. D/d=12 complete ETF for signed64. C=context T(S,S,S,S,E(:request),d,E(retained)); P=plan T(E(:native_generation_capture_v1),E(M),E(H),E(Q),E(B)). No global33-group/list/depth bound is introduced. R_G73862/R_T75921 remain genuine source-receipt bounds; existing validator may reject some actual scalars sooner. Real small-node receipts corroborate constructor formulas, not maxPID/ref samples.

Start with ALL34 old roles, then REPLACE or ADD the following full roles. This is a conservative union of enumerated source roots, not a sharing deduction. Parent must source-bind exact implementation roots to this table before charging. Any actual new wrapper not listed requires updating numeric sum/report/test in this SAME runtime stage before adoption.

| Change | Complete constructor/cap and multiplicity | End/owner |
|---|---|---|
| Replace cancel_control multiplicity | Ccancel=max(T(E(:cancel_pin),S,F),T(E(:cancel_pins),S,F)), count65=(k+1), subtotal65*Ccancel; historical worksheet remains count64 | original providers; cancellation confirmation/uncertainty |
| Replace original_provenance | Full ledger with entries T(A,S,F,E(batch)); bound L4=H+k*(A+S+F+5), count3 input/current/output ledger roots | Store, acquisition end |
| Add original_current_entry | T(A,S,F,H), count1; current original facts remain before provider call | Store, acquisition end |
| Add manifest normalization | 2*H additional raw/unique roots, retaining existing validated_manifest H; additionally one complete generic validation result T(E(:ok),H) | Store, acquisition end |
| Add acquisition control roots | Three complete max(T(E(:cont),T(Q,L4)),T(E(:halt),err3)) wrappers if using reduce_while; keep separately paid pins/ledger roots conservatively. Do not retain a raw provider result in this accumulator | Store, acquisition end |
| Add partition scratch | 2*K additional complete partition map roots, retaining existing K; K=6+(H-7)+k*(8+(A-1)+(S-1)) | Store, acquisition end |
| Add initialized checked config | Map(store:S,max_config_bytes:E(M),accounting:E(module)), count1 | requester/router lifetime; conservative request copy |
| Add checked preflight result | T(E(:ok),Map(count:E(64),bytes:E(Q))), count2 | Store/requester, preflight return |
| Replace finite_failure_payload | err3=T(E(:error),max_finite_atom,max(E(:clean),E(:cleanup_unconfirmed))), count1 | requester, request end |
| Resize Store snapshot roots | max(T(E(:ok),M,M,Q),err3), same payload/wire/received multiplicities1 each, include full alias reply | Store/requester, snapshot return/request end |
| Add checked acquisition failure | err3,count2 for Resources failure and Store checked-status selection; no provenance or pin in error | Store, acquisition end |
| Add checked release status | max(E(:ok),T(E(:error),E(:generation_pin_release_failed))), count2 | requester, cleanup return |
| Add bounded release callback transport | Complete {:release,pin} remains old release payload/call/reply role; no extra tuple for direct module.release(pin,Dc). Dc adds one d scalar root | requester, cleanup end |
| Add finite control status | max E(:clean/:cleanup_unconfirmed), count2 plus one d original deadline root; no outcome/exception wrapper | requester/Store, request/acquisition end |
| Resize numeric roots | E(M),E(retained),E(B),E(retained+B),E(Bnext), iterationE(64), count2 each as conservative current/next scalar roots, plus3*d timing roots | requester, reservation/cleanup return |

All old roles not replaced remain: full context/compact plan; Admission update/wire/reply; snapshot requester/wire/Store payload/from; validated manifest and partition map; three provider normalization lists; provider payload/call/owner/from; complete genuine pin/result/reply/received; three accepted acquisition accumulators; complete snapshot results including generation REPEATED outside complete router; three capture input/output Q roots; serial release payload/call/reply; ALL65 asynchronous cancel controls (64 Store ledger rollback sends plus at most one current T postcheck send); known full Elixir call-failure descriptor and DOWN; TWO complete cleanup observation/merged-metadata roots. No rejected combined list is constructed or budgeted. Successful complete snapshot stays2*M+Q+E(:ok)-1, notM+Q. Known call-failure/DOWN rows are recomputed against new maximum request and finite status, including explicit Admission timeout and shared release deadline. Unknown arbitrary raw death/callback diagnostics are outside accepted/finite source-role scope, never declared bounded by this descriptor.

For numeric summation first replace the historical64*Ccancel subtotal by65*Ccancel (add exactly one complete Ccancel, not a scalar operation-only allowance), then replace the old provenance subtotal by3*L4, add current-entry and explicit extra roles, resize error/snapshot/descriptor maxima, and recompute EVERY row's integer dependencies at each iteration. Define Bnext=sum_runtime_roles(M,retained,B), starting B0=0 and finishing only Bnext===B. Iteration bound64 is an arithmetic failure guard, not a product depth bound; failure is finite capacity error, never fallback to oldB. E(retained+B) and E(B) are exact integer encodings at that iteration. Direct numeric sum must not materialize roles. Independently handwritten expectations cover integer encoding transitions and both M65536/defaultM1048576. Preserve old worksheet totals as historical assertions; publish new numeric B only from this implementation's source-bound passing evidence. No numeric runtime B is qualified by this source-only document.

### Exact diagnostic and compact API contracts

`worksheet/2` keeps its historical input/output/role names,64-cancel model and assertions exactly. New diagnostic API is `runtime_worksheet/2`, with the SAME actual `(M,{store,holder,gate,lease,:request,D,retained})` input grammar as reservation/2. It is pure explicit review tooling; it is NEVER called by reservation/2 or any pre-Admission path. Return grammar is exactly:

```elixir
{:ok, %{
  qualification: :conditional_not_runtime_ready,
  profile: :native_generation_checked_capture,
  m: M,
  retained: retained,
  bounds: %{h: 65_536, q: 65_536, s: 2_048, k: 64, future_ref: 2_062,
            g_pin: 73_862, t_pin: 75_921, genuine_pin: 75_921,
            g_singleton: 73_868, t_singleton: 75_927, cancel_controls: 65},
  roles: [%{name: role_atom, owner: owner_atom, constructor: complete_constructor_string,
            cap: nonnegative_integer, multiplicity: positive_integer,
            subtotal: cap * multiplicity, release: lifetime_atom}],
  total: B,
  fixed_point_iterations: positive_integer,
  prerequisites: [:checked_runtime_constructors, :pre_admission_constructor_gate,
                  :real_public_owner_boundaries, :native_h1_capture,
                  :downstream_h2_capture, :final_independent_review]
}}
```

`roles` is the full ordered53-row list, not the one-item illustrative syntax above. Each constructor string describes the complete actual original term/wire, never a safe projection; release names actual end-of-role lifetime. Runtime owner vocabulary is `:requester | :store | :provider | :admission | :caller`; lifetime vocabulary is `:reservation_return | :admission_return | :snapshot_return | :acquisition_end | :provider_return | :receipt_validation | :preflight_return | :release_return | :cleanup_end | :cancellation_uncertain | :call_return | :emit_return | :request_end`. Follow the table's owner/lifetime (requester config is conservatively request_end); preserve every complete syntax/cap even if physical sharing exists. Unknown/invalid input returns `{:error,:invalid_generation_capture}`; arithmetic nonconvergence/capacity returns `{:error,:generation_capture_capacity}`. No gates dynamically flip qualification: this static report remains conditional until external actual-source/native/final review receipts qualify use; report output itself is never runtime acceptance.

The first34 role names, in exact order, are:

```elixir
[:context, :plan, :admission_update_payload, :admission_update_wire, :admission_update_reply, :snapshot_requester_payload, :snapshot_call_wire, :snapshot_store_payload, :snapshot_store_from, :validated_manifest, :partition_map, :provider_handle_normalization, :provider_request_payload, :provider_call_wire, :provider_owner_payload, :provider_owner_from, :genuine_provider_pin, :provider_result_payload, :provider_reply_wire, :provider_store_received_result, :checked_acquisition_accumulator, :original_provenance, :store_snapshot_payload, :store_snapshot_wire, :requester_snapshot_received, :caller_capture_inputs_and_output, :release_payload, :release_call_wire, :release_reply_wire, :cancel_control, :known_call_failure_descriptor, :known_monitor_down, :cleanup_observation, :finite_failure_payload]
```

The19 appended role names, in exact order, are:

```elixir
[:original_current_entry, :manifest_normalization, :manifest_validation_result, :acquisition_control, :partition_scratch, :checked_config, :checked_preflight_result, :checked_acquisition_failure, :checked_release_status, :cleanup_deadline, :finite_control_status, :original_deadline, :numeric_m, :numeric_retained, :numeric_reservation, :numeric_retained_plus_reservation, :numeric_next, :numeric_iterations, :numeric_timing]
```

In the preceding two lists each entry is an Elixir atom (names below are the normative identifiers). For exact new-row mapping: original_current_entry is T(A,S,F,H)x1; manifest_normalization is Hx2; manifest_validation_result is T(E(:ok),H)x1; acquisition_control is the complete reduce-control maximum x3; partition_scratch is Kx2; checked_config is the complete initialized config map x1; checked_preflight_result is complete preflight tuple/map x2; checked_acquisition_failure is err3x2; checked_release_status is finite release result x2; cleanup_deadline and original_deadline are dx1 each; finite_control_status is maximum clean/unconfirmed atom x2; numeric_m, numeric_retained, numeric_reservation, numeric_retained_plus_reservation, numeric_next, numeric_iterations are E(M),E(retained),E(B),E(retained+B),E(Bnext),E(64) respectively x2 each; numeric_timing is dx3. All corresponding old rows remain unless expressly replaced/resized by the table; cancel_control is count65. `sum(roles.subtotal)===total===B` at the numeric fixed point is an independent assertion.

`reservation/2` returns only `{:ok,{:native_generation_capture_v1,M,65536,65536,B}}` with that SAME independently recomputed runtimeB, or one of the same two finite errors. The existing five-element tuple tag staysv1; diagnostic profile names do not change that compact contract. Introduce direct scalar `sum_runtime_numeric`/fixed-point functions with no role/rows/report/bounds-map construction. `runtime_worksheet/2` may build full report/rows AFTER invoking the shared numeric calculation because it is explicitly diagnostic. Tests compare full diagnostic numeric rows with compact output; independent expected sums must not simply call the production summation twice.

## Mandatory pre-Admission constructor gate inside this runtime stage

After Task3 actual Resources/Store/owner compatibility constructors exist, and BEFORE Task4 first connects returned B to Admission, parent freezes the exact actual source candidate and completes this gate. This is a checkpoint within this one runtime integration stage, not another pure prerequisite stage. Earlier independent RED/constructor/checked-Store tests can proceed without consuming B; no runtime Admission charge may use an unqualified B.

1. Rebind every actual constructor, wrappers/control roots, maximum timeout, lifetime and multiplicity, including the current T postcheck send plus complete original-ledger rollback65 case. Recalculate the WHOLE numeric fixed point/table/all subtotals from that source; do not merely patch oldB by a guessed delta. Include actual requester context/compact plan and call-constructor code in the frozen review surface before wiring Admission; a design-only forecast is insufficient. Stage any necessary caller constructor code without activating its B-consuming endpoint connection, and add no runtime toggle/process/helper to evade this order.
2. Independent bounded SPEC and CODE constructor reviews must both PASS the actual source and independently expected numeric/table/subtotals. These may be narrowly scoped constructor reviews separate from final end-to-end review. SPEC checks complete public-path coverage; CODE checks numeric-only compact path, complete actual roles and raw-operand construction order. The review receipt records source hashes, exact newB/profile and all rows, not only narrative approval.
3. Run fresh focused NONZERO tests on that exact frozen candidate: runtime compact arithmetic, genuine T postcheck+Store rollback cancellation accounting, checked Resources/Store custody and owner public compatibility. All required counts/exits and source identities must PASS. The known historical64-cancel worksheet tests remain intact and explicitly historical/conditional; their pass cannot stand in for runtime65 coverage.
4. Only after all three receipts pass may Task4 connect B to Admission. Bind the implementation connection to that receipt. If wiring or later repair adds/changes ANY charged constructor, wrapper, timeout, lifetime or multiplicity, reopen this SAME gate and rerun the bounded constructor review/fresh affected checks BEFORE any further B-consuming Admission execution. Task6 final SPEC/CODE/native/fresh acceptance remains required and does not replace this earlier gate.

Real T regression: use actual T.pin_many/5 with real owner receipt. Deterministically hold execution between successful owner reply and T deadline/holder postcheck using a test-owned barrier/BEAM tracing synchronization, then expire original D or terminate only the test-owned holder before allowing postcheck. Preserve the production provider; no fabricated pin or provider implementation. Observe the real current-operation T cancellation followed by Store full authentic-ledger rollback including the same operation. Public fixture/resource/holder cleanup uses finite joins. Assert the current operation has TWO sends with original Store acquirer and full control constructors, all prior started entries one each, finite cleanup_unconfirmed outcome, no Router, no early refund. A small real batch proves that public double-send path; independent source/role arithmetic proves maximum65 at k64, without needing to forge64 owner identities or maxPID. Test either genuine full64 started operations plus failed current T, or pair the real small-path regression with independently derived65*Ccancel maximum constructor/multiplicity/subtotal assertions; do not substitute a test double for the real T postcheck path.

## Real acceptance and bounded exclusions

Acceptance is one end-to-end stage: compact arithmetic + checked Resources/Store/caller integration + public deadline compatibility + real Admission barriers + genuine G/T receipts + native H1 and downstream-H2 captures, independent SPEC/CODE and fresh verification/local conventional commit. The paired plan gives executable scoped commands and synchronization cases. Test doubles exercise malformed receipts and exact exception precedence; they cannot replace genuine owner/public/native gates.

Native H1 uses real listener/client and live G-H1/T public captures at SnapshotEndpoint-style barrier. Native downstream H2 uses actual prior-knowledge TCP HEADERS/HPACK/SETTINGS exchange, a real native stream worker as holder, and an H1/static managed Generation route so it does not activate upstream H2. Verify the same Admission charge/order, snapshot/provider correlation and ordinary cleanup; no claim of worker-transfer activation. Existing `managed_h2_generation_exclusion_test.exs` must remain green and unchanged in assertion strength. Keep Service9444956/group16478862/startup5963776 constants unchanged.

Core-only consumer must actually run after Admission API change, and HTTP-only consumer after optional behavior seam. No core→proxy dependency, no production Bandit, no deps edits, no upstream97 reprise, no publication/deployment/production-data/certs/Vault/public-management/disabled artifact E2E. New genuine upstream blockers route under AGENTS; no silent workaround. All commands started by this author completed; no runtime/background processes were started or touched. Remaining product decisions: none; predecessor closure and implementation evidence are autonomous gates, not user approval requests.

## Execution binding and precision clarification

Execution baseline e189894882bb6a530f2c38538be4efaf384be261. Predecessor feature94d47d11 and closuree189894 have actual committed/index/disk audit, independent SPEC/CODE and fresh24/0 receipts; the earlier conditional preparation language above is historical. Readiness2 PASS_READY_FOR_GATED_RUNTIME_TDD closes design findings only. Runtime and Task3.5 remain NOT RUN.

For conservative known-call-failure/DOWN arithmetic choose max(historical finite-call-reason bound,complete checked err3). validate_manifest/1 and correlate/3 reject with {:error,:invalid_generation_capture}; capacity errors belong to arithmetic/preflight. Descriptor spelling is descriptive; exact row name/order/owner/lifetime/multiplicity/cap/subtotal is normative. New release/2 explicitly checks positive remaining absolute deadline before Lifecycle.call; expired calls return {:error,:deadline_exceeded} without dispatch. release/1 remains unchanged. No new product decision or runtime failure is implied.

Metadata precision: checked_preflight_result uses caller/preflight_return; finite_control_status uses caller/request_end; numeric M/retained/B/retained+B/Bnext/iterations use requester/reservation_return; numeric_timing and cleanup_deadline use requester/cleanup_end; original_deadline uses caller/request_end. All are conservative aggregated roots. Normalize exactly {:deadline_exceeded,:cleanup_pending} to :deadline_exceeded for the real Lifecycle/T public pending outcome; unknown nested reasons still map nonrecursively to generation_unavailable. This keeps the finite vocabulary and constructor caps unchanged.

## Pre-RED complete callback-envelope correction

A source-only precision audit found two result envelopes omitted from the prepared caps. Keep all53 role identifiers and multiplicities, strengthen plan to max(Pinner,T(E(:ok),Pinner)), where Pinner is the compact five-tuple; strengthen checked_preflight_result to max(T(E(:ok),Map(count:E(64),bytes:E(Q))),T(E(:error),E(:invalid_generation_capture)),T(E(:error),E(:generation_capture_capacity))). These are full original callback results, not projected payloads. Preserve frozen revision2/proposal1 evidence; revised independent test table and every fixed point/precision boundary must be rederived before production adoption. This pre-RED source correction is not a runtime failed GREEN or production repair. No B has been consumed by Admission.

## Required browser compatibility check

The local browser acceptance required by AGENTS uses real Chrome/CDP against the same opt-in native H1 Generation endpoint, public G-H1/T route and an independent raw H1 peer. A captured-exchange barrier verifies original receipts and actual public Admission retained bytes before returning the visible page. Request pins and the ordinary lease settle on normal teardown; browser, host and peer children are joined finitely. This is additional verification of the selected seam; it adds no charged production constructor, upstream-H2 activation, public endpoint or release-artifact E2E workflow.

## Final runtime qualification — 2026-10-16

The earlier execution checkpoints are historical. The complete checked-capture source and genuine runtime/native/browser evidence passed independent full-stage SPEC then CODE review, bound by candidate-freeze1.json (230 source/164 evidence hashes). Post-review acceptance-fresh1.json passed493 executed scoped tests with0 failures/warnings/skips/exclusions and unchanged source; both isolated consumers, strict compile, scoped format and the actual Chrome case also pass. See docs/acceptance/m3-native-generation-checked-capture.md for exact receipts and preserved failures. Final index/blob audit and local commit remain pending. This qualifies only this bounded runtime seam; native worker startup/dispatch accounting, upstream-H2 Generation activation and whole-M3 acceptance remain future stages under continuing authorization.
