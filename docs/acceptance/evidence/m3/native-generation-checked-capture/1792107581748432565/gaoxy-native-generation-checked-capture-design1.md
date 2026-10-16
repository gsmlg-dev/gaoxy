# Native Generation checked capture: bounded runtime design1

Task `native_generation_checked_capture_design`, direct source-only assignment, prepared 2026-10-16. Decision: execute ONE runtime integration stage, automatically after the pure worksheet predecessor closes. Its endpoint is accounted native Generation → Store → real public managed owners → Router → bounded cleanup, including native H1 and downstream-H2 smoke. Constructor arithmetic is an internal TDD task of this integration stage; it is not a third pure worksheet stage.

## Custody and release condition

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, inspected HEAD `48a71a70acbe9cb46f99b82e4062c6f5f25d9667`. At inspection the worksheet module/test, worksheet docs and worksheet evidence directory were untracked parent-owned work. Preserve them and all unrelated user files. Parent alone owns repository/runtime/build/test/format/evidence/index/Git; this author owns only the paired /tmp design1, plan1 and decision1.json. No implementation, runtime test or local commit was performed by this author.

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

Store failure after any operation was dispatched sends original operation cancellations once; cancellation returning :ok only means sent. Checked result status stays cleanup_unconfirmed. With no started ledger a validation failure is clean. A checked Store call transport failure is conservatively cleanup_unconfirmed at requester; its original finite error remains primary, and Store retains responsibility for any late rollback. Do not add a second cancel issuer, cleanup process or global tombstone ledger. Owner deadline/holder monitoring remains the existing lifetime boundary; B is retained until ordinary request/lease teardown, not a claim that every asynchronous cancellation is confirmed before that teardown.

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

The old conditional totals (M65536:2758572; M1048576:8656812, retained0) MUST NOT be copied into runtime. The integration changes constructors. Add an independently checked runtime profile to worksheet output, without changing the historical worksheet report/old numerical assertions. Existing worksheet/2 keeps historical meaning. New `reservation/2` calls ONLY numeric arithmetic and returns the five-tuple. It must never call worksheet/2, rows/3, role_specs/1, build report/bounds maps or row lists, even transiently before Admission. Compile-time fixed atoms/constants and direct integer arithmetic are allowed. Share scalar numeric size functions and fixed-point summation; diagnostic role rows are built exclusively by explicit worksheet/report requests. Runtime reserve/report-equivalent sums are independently compared in tests.

Notation: E(t)=complete default ETF size; T(x...)=3+sum(x-1); Map(pairs)=6+sum(k+v-2); L(nonempty)=7+sum(element_size-1), L(empty)=2. H=Q65536, S2048, k64; A=max(E(G),E(T)); F=S+14=2062 from bound loaded OTP source. D/d=12 complete ETF for signed64. C=context T(S,S,S,S,E(:request),d,E(retained)); P=plan T(E(:native_generation_capture_v1),E(M),E(H),E(Q),E(B)). No global33-group/list/depth bound is introduced. R_G73862/R_T75921 remain genuine source-receipt bounds; existing validator may reject some actual scalars sooner. Real small-node receipts corroborate constructor formulas, not maxPID/ref samples.

Start with ALL34 old roles, then REPLACE or ADD the following full roles. This is a conservative union of enumerated source roots, not a sharing deduction. Parent must source-bind exact implementation roots to this table before charging. Any actual new wrapper not listed requires updating numeric sum/report/test in this SAME runtime stage before adoption.

| Change | Complete constructor/cap and multiplicity | End/owner |
|---|---|---|
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

All old roles not replaced remain: full context/compact plan; Admission update/wire/reply; snapshot requester/wire/Store payload/from; validated manifest and partition map; three provider normalization lists; provider payload/call/owner/from; complete genuine pin/result/reply/received; three accepted acquisition accumulators; complete snapshot results including generation REPEATED outside complete router; three capture input/output Q roots; serial release payload/call/reply; ALL64 asynchronous cancel controls; known full Elixir call-failure descriptor and DOWN; TWO complete cleanup observation/merged-metadata roots. No rejected combined list is constructed or budgeted. Successful complete snapshot stays2*M+Q+E(:ok)-1, notM+Q. Known call-failure/DOWN rows are recomputed against new maximum request and finite status, including explicit Admission timeout and shared release deadline. Unknown arbitrary raw death/callback diagnostics are outside accepted/finite source-role scope, never declared bounded by this descriptor.

For numeric summation replace the old provenance subtotal by3*L4, add current-entry and explicit extra roles, resize error/snapshot/descriptor maxima, and recompute EVERY row's integer dependencies at each iteration. Define Bnext=sum_runtime_roles(M,retained,B), starting B0=0 and finishing only Bnext===B. Iteration bound64 is an arithmetic failure guard, not a product depth bound; failure is finite capacity error, never fallback to oldB. E(retained+B) and E(B) are exact integer encodings at that iteration. Direct numeric sum must not materialize roles. Independently handwritten expectations cover integer encoding transitions and both M65536/defaultM1048576. Preserve old worksheet totals as historical assertions; publish new numeric B only from this implementation's source-bound passing evidence. No numeric runtime B is qualified by this source-only document.

## Real acceptance and bounded exclusions

Acceptance is one end-to-end stage: compact arithmetic + checked Resources/Store/caller integration + public deadline compatibility + real Admission barriers + genuine G/T receipts + native H1 and downstream-H2 captures, independent SPEC/CODE and fresh verification/local conventional commit. The paired plan gives executable scoped commands and synchronization cases. Test doubles exercise malformed receipts and exact exception precedence; they cannot replace genuine owner/public/native gates.

Native H1 uses real listener/client and live G-H1/T public captures at SnapshotEndpoint-style barrier. Native downstream H2 uses actual prior-knowledge TCP HEADERS/HPACK/SETTINGS exchange, a real native stream worker as holder, and an H1/static managed Generation route so it does not activate upstream H2. Verify the same Admission charge/order, snapshot/provider correlation and ordinary cleanup; no claim of worker-transfer activation. Existing `managed_h2_generation_exclusion_test.exs` must remain green and unchanged in assertion strength. Keep Service9444956/group16478862/startup5963776 constants unchanged.

Core-only consumer must actually run after Admission API change, and HTTP-only consumer after optional behavior seam. No core→proxy dependency, no production Bandit, no deps edits, no upstream97 reprise, no publication/deployment/production-data/certs/Vault/public-management/disabled artifact E2E. New genuine upstream blockers route under AGENTS; no silent workaround. All commands started by this author completed; no runtime/background processes were started or touched. Remaining product decisions: none; predecessor closure and implementation evidence are autonomous gates, not user approval requests.
