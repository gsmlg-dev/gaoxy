# H2 group accounting readiness investigation

Task `h2_group_accounting_readiness`: **DONE** for the assigned read-only investigation. R-GROUP-ACCOUNTING remains **ACCOUNTING_NOT_READY**. No ETF measurements, Mix, tests, live group prepare, peers, or browser were run. The extra 2,097,152 / total 11,542,108 numbers remain **PROPOSED_UNPROVED**.

## Scope, custody and source

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`. Start HEAD `31f23eb2d915ba715a1016f254b90d9805f18a1a`; root committed the predecessor while this read-only investigation was active. Report HEAD and complete inspected-source/draft hashes are in the companion JSON. Root owns all repository writes, index, commits and runtime. This worker wrote only the two requested `/tmp` reports. Existing diff was parent-owned; none was changed.

Inherited counters remain fixed Sol19, fixture Sol20 RED1/GREEN1, collector Sol17, 0.21.10 full58 failed2, Astra2/2 exhausted. This task used zero repair rounds and no escalation. No predecessor result is reclassified. Historical memory only informed authorization/#97 boundaries; current technical findings are from these sources.

## Concrete recommendation

Start with one **pure prerequisite** that adds exactly three files, leaves H2 group compilation/prepare disabled and adopts no numeric runtime reserve:

| Owner | File | Contract |
| --- | --- | --- |
| One accounting author | `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex` | Internal closed component validators and explicit phase/slot ledger evaluator; no owner calls, processes, timers, networking or reservation callback. |
| Same author | `apps/gaoxy_proxy/test/support/managed_h2_group_projection.exs` | New exact group Session/pump/start/probe/recovery/message/workspace projectors. Preserve fixed projector byte-for-byte. |
| Same author | `apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs` | Constructed maximal complete values, rejection cases, aggregate phase bundles, slot counts and arithmetic; pure tests only. |

Root owns edits to the adopted design/plan and assigns independent SPEC then CODE reviewers who did not write these files. Do not modify ManagedH2Reservation, HTTP, Session, group Options/Owner/Probe, dependencies, fixed evidence/projector or existing assertions in this initial package. This isolates schema discovery from live activation and does not change public interfaces. Later runtime wiring has exact ownership listed below.

Suggested small internal API:

* `schema_contract/0`: versioned list of accepted component shapes/ranges and slot names, initially marked `:accounting_not_ready`; no numeric runtime admission return.
* `validate_component(kind, value)`: exact finite allowed `kind` clauses; returns `:ok | {:error, :invalid_group_accounting_component}`. Validate map keys, proper bounded lists, scalar ranges, logical/backing caps and compact retained fields before bounded ETF measurement. Reject unknown kinds/keys/struct tags. No recursive catch-all serialization.
* `evaluate_phase(phase, bundle)`: exact phase-specific wrapper/scalar shape; validates every marker's complete original value and explicit slot assignment, counts actual simultaneously retained roots, returns typed projections/bytes/counts or finite error. No opaque scope/completion interiors. Unknown family, unassigned payload, sixth request/config copy or third checked-policy copy fails; extra needed copies require explicit ledger revision, never a marker discount.

These names are proposed internal interfaces, not an architecture rewrite. Keep source linked phase fixtures in test data, not a configurable public accounting framework.

## Confirmed corrections to the draft

1. **Selected is already narrow.** `upstream_groups.ex:666` returns `{:ok, Map.take(member, [:id, :config, :max_inflight]), token}`. The draft's full 11-key Selected schema is wrong for checkout. Require exactly those three member keys with compact id1..128, validated complete H2 HTTP config and max_inflight1..1024. Preserve exact success/reply/GenServer wrappers, token and caller alias. Probe launch at743–750 currently sends the full expanded member. Narrow it before args construction to the same three-key member; this removes checked/failures/successes/inflight/probe/due/health from copied start state instead of adding a new health-counter normalization scheme. Private owner counters currently grow without a finite lifetime cap (`798–847`); do not serialize them through PC/PR. If a future contract exports one, specify finite pre-copy range first.

2. **Recovery is a separate actor schema.** Probe recovery start args are exactly `owner/recovery/completion/deadline`; `recovery={:selection|:probe, token}`. `Probe.init` adds only `owner_monitor` (`probe.ex:11–14`). Include `:recover`, owner DOWN, `{recovered, kind, token, helper_pid, :ok|{:error,finite_reason}}`, await-completion result and supervisor start/failure wrappers (`probe.ex:157–182`, owner851–870). Its owner selection/probe record already stores original completion and later adds recovery/recovery_monitor. Keep that capability opaque after shape/provenance validation; count copied shells and startup controls. Recovery may start while the failed original child and its final state are still retained; model that transition explicitly, not only a steady live PR.

3. **Backing and scalar enforcement is missing today.** `Options.id?/path?` check logical bytes but no backing; `group_handle` retains id directly; health path retains caller backing. `HTTP.group_limits/1` accepts positive integer times without the fixed H2 upper bound (`http.ex:247–255`). New H2 validators must establish compact id/path and signed timestamp/finite limits before retention/copy. Existing whole options ETF<=1MiB does not bound a tiny subbinary's backing. Preserve H1 behavior; this task does not silently cap all owner counters or redesign owner memory.

4. **Existing fixed projector cannot be reused unchanged.** It asserts group selection nil, accepts fixed selector only, one handoff transport/source pin and one Exchange resource pin, and rejects nonnil downstream ssl/peer_cert (`managed_h2_control_projection.exs:23–27,365–393,470–498`). New group projector needs complete group/transport pin-list controls and explicit H1/H2 Exchange shell shapes. Native H2 Exchange uses transport_state `{connection_pid, stream_id, token}` (`http2/connection.ex:1031–1050`); preserve those controls. For TLS browser coverage, validate the public native lease boundary before replacing socket/TLS/certificate payloads with named native-lease markers. A generic map marker or fixed fixture's nil-only assumption cannot prove that path. Do not serialize native/private interiors or broaden this into native-memory certification.

5. **Temporary supervisor args do not live for the child lifetime.** Installed Elixir1.18.5 DynamicSupervisor source at438–440 sends normalized child via `{:start_child, child}`;783–819 applies the MFA and saves child with MFA args `:undefined` for `restart: :temporary`. Both Session and Probe use temporary restart. Thus no persistent fifth supervisor-args copy is required after successful save_child. The transient parent caller / supervisor call / child init args / returned child state overlap still needs four explicit root projections. `2PC + 2PR` could cover the control part of four startup roots only after mapping them; `2PC` alone is not the complete proof. Confirm the canonical Nix Elixir source identity before accepting this installed-source observation as runtime cohort evidence. Start-error wrappers can contain arbitrary exception/stack diagnostics: project only existing finite normalized retained results, and explicitly account bounded pre-copy own payload arguments without serializing arbitrary diagnostics.

6. **Owner config budget is a different claim.** `prepare_record` charges serialized compiled plus transports once, then retains compiled, expanded members and handle (`owner249–307`). Do not call max_config_bytes whole-owner-memory proof, and do not use it to zero copied launch config. The requested readiness work needs transferred config and wrappers counted independently; it does not authorize an owner-memory rewrite.

## Closed component inventory for the pure module

Use the draft caps only as candidate rejection thresholds tested by complete ETF values. This report accepts none of them numerically.

| Component | Exact contract/corrections |
| --- | --- |
| H | Exactly provider/owner/owner_epoch/group/generation/max_url_bytes/transports/execution_profile; correct providers/profile; PID/ref types; scalar serialized caps; compact group1..128; max_url_bytes1..8192; ordered unique1..32 exact T handles. Validate complete H **and** complete flattened `[H|transports]` within existing64/65536 manifest limits. |
| E | Exact GroupEndpoint struct tag/group/limits; exact five fixed limits and ranges; complete wrapper measured. Post-open Session config must be a separately specified exact limits-only shape, not a fake HTTP or incomplete GroupEndpoint struct. |
| T | Exactly provider/owner/owner_epoch/resource and scalar type/finite serialized cap. |
| GPins | Complete proper endpoint group-pin list: one seven-key request pin with exact provider/owner/owner_epoch/ref/operation/handles/kind, handles exactly `[H]`. Owner equality and matching H are distinct from shape authority. Wrapper/list must fit as a whole. |
| TPins | Proper list of up to32 eight-key transport pins, each handles containing a nonempty owner-coherent subset of the flattened Ts, kind=request and holder=pump. Across list require exact intended handle coverage/order contract, no duplicate handle coverage or unexpected providers/owners. A single pin may hold several handles; don't assume one per handle. Validate full Exchange pin list (group+transport) separately before filtering/copying. |
| Delegated | Exact eight-key transport pin, one selected T and expected Session/Probe holder; complete pin size cap. GPins never gains a fabricated holder field. |
| Neutral | Exactly target/method/fields/body_mode/request_limits/max_upload_bytes. Proper finite fields, token/value rules, body/range checks, target origin syntax/escapes/present empty query, source and retained backing/compactness; complete source belongs to a named request slot. H.max_url_bytes+target<=65536 checked before Session creation. |
| Selected | Exact three-key member. Validate config through ManagedH2Envelope.validate_config and complete147456 candidate cap; unknown diagnostics rejected. Config is a fixed config slot; only exact remaining wrapper/id/counter bytes are extra control. |
| Probe-start | Exactly owner/token/member/deadline/health/url. Member is narrowed Selected. Health exactly path/interval/timeout/stale_after/failure_threshold/recovery_threshold/jitter with existing ranges and compact bounded path. URL bounded/compact; it consumes a named request slot, not free PC bytes if projected out. |
| Probe-state | Probe-start keys plus cleanup_deadline/owner_monitor/timer/request/original_request/managed_transport/transport_selection/transport_pins/terminal/cancelled/headers/outcome, plus proposed client/submitted_url. Require exact nil/boolean/enums, real H2 protocol/client, finite deadlines and one delegated pin/T token. Do not silently include Session-only fields or fabricated poll timer. |
| Recovery-start/state | Separate exact shapes described above; normal probe-state validator must reject them, and vice versa. |

Scalar tests must cover actual allowed encoded PID/reference bounds, not only tiny self()/make_ref(). Use a bounded pure encoded constructor valid on the pinned OTP or a conservative analytic cap plus a valid reachable maximizing fixture; do not create atoms in unbounded loops or start distributed nodes to produce large scalar fixtures. Component marginal maxima must respect manifest coupling; e.g. choosing H65536 and an independently maximum transport sidecar is not jointly admissible.

## Required five-slot and two-policy proof

Current fixed contract is five request slots205337 each, five config147456 each, checked policy2*1183744. These totals are global for the request phase, not per P/S/PC/PR/M projection. Preserve complete preparation return including accounting in one slot, not prepared projection plus an extra zero-cost accounting map. Submitted URL is part of the existing Session request slot after envelope release.

The pure test's explicit candidate slot inventory should start with the following meanings. This is a **proof obligation**, not an assertion that the successor currently fits:

| Slot set | Candidate allocation | Required demonstration |
| --- | --- | --- |
| Q1..Q5 | ingress/start-source or assembly; Session Neutral/envelope then submitted_url; complete canonical preparation return; source Fetch options; submitted Fetch representation | At Neutral→selected URL→Envelope→Fetch boundaries include old callback source, new envelope, bounded URL/target temporaries, nil-body validation return and actual upload-PID preparation return. Show any predecessor source no longer independently retained before reusing its slot. If pump/start source and old Neutral survive while all five fixed opening roots coexist, that is a sixth copy: fail or add explicit charged slot. |
| C1..C5 request | selected checkout owner reply; receiver/opening config; awaiting config; old/new control transition/config validation locals | Group E lives in group controls, not a fixed HTTP config slot. Account complete selected config occurrences across reply+old/new Session+handoff/open. No sixth copy is silently merged. |
| C1..C5 probe startup | owner launch args; DynamicSupervisor call; child init args; returned Probe state; opening/validation config | Same five total slots, alternative phase to request startup. Owner retained config budget remains separate. Post-save_child start args are dropped for temporary child. |
| K1..K2 | Session/Probe checkout client and open/Fetch checked client | Call reply and old/new managed_transport payload need count inspection; no third checked policy marker for free. Scope interior stays one validated opaque capability. |

Use exact phase fixtures: request-start, selected-reply, handoff, envelope-prepare, Fetch-open, response-head, cleanup; probe-start, probe-open, probe-cleanup and recovery-start/finish. For each list every actor/root with owner, complete value/schema, assigned payload slot, control projection, creation/release boundary. Distinguish alias paths inside one already charged complete representation from independently retained old/new/message/start roots under the chosen conservative convention. Do not assume object sharing to justify a missing root. This closes the specific uncertainty without inventing a new lifecycle.

## Messages, old/new state and workspace

Maintain all sixteen fixed families unchanged. Add an explicit finite family registry for group checkout, transport validation/pin/checkout/delegation, group/transport bind/finish/release, group selection startup, probe claim/bind/finished/cancel/expired, start-child success/failure and recovery receipts. Each entry includes complete `'$gen_call'/{caller,alias}/request` and response wrappers as applicable, not just the application request body. Public origin identity is exact origin/upstream_protocol/instance; UpstreamTransports normalizes it to `{protocol,scheme,lowercase_host,port}` before its owner wire call (`1370–1401`); preserve both bounded forms in the correct phase.

Evaluate simultaneous actor bundles, not unrelated marginal maxima:

* Request: old/new pump, old/new Session, both actors' active call argument/request/reply/handoff candidates and one assembly workspace each. A synchronous call serializes one actor; it does not serialize pump against Session. Pending reply already queued while a caller unwinds needs explicit treatment.
* Probe: old/new owner launch controls, supervisor/child startup controls, old/new Probe controls and their call/reply candidates/workspaces. Owner candidate/group/private config stays under its separate existing ledger; only copied controls assigned here. Include claim call waiting behind owner launch until owner registers PID/token/reserve.
* Recovery: original failed-child final controls, owner recovery-start controls, helper startup/new state and completion recovery messages, with exact release boundaries. Do not retain two uncharged completions or extra request/client payloads.

Each W must include exact construction temporaries: original Neutral, selected root string, joined URL, target, seven-key source, eight-key envelope, validation/preparation return, field-copy lists and pin-filter output as applicable. Anything assigned to Q/C/K is counted there exactly once; remainder is complete W, preserving map/list/tuple/scalar overhead. No opaque external_size of arbitrary state. Both per-actor W slots must be measured in complete aggregate bundles. Candidate2P+2S+2M+2W=2097152 and probe2PC+2PR+2M+2W=1310720 are arithmetically correct but do not establish that the listed roots fit those counts/caps. There is no numerical reserve recommendation until these bundles pass.

## Exact pure tests and acceptance receipts

1. Exact keys/type/ranges/provider/profile/holder; unknown key/family/struct tag; mismatched selected protocol; duplicate/out-of-order/foreign transports; extra pins; wrong group pin holder schema; nonproper/overcount lists; oversized scalar; backing-heavy subbinaries; invalid/unbounded times; health/config diagnostics rejected.
2. Complete valid maximizers for H/E/all pins/Neutral/Selected/probe/recovery/control messages; include list/map/tuple wrappers and joint flattened manifest constraints. Show both largest valid constructed value and why every admitted constructor/range fits cap. Where a fixed schema cannot attain exact cap, test the nearest structurally valid boundary and first over-cap value; do not invent fields/padding to manufacture equality.
3. Exact-bound/over-bound variable binary/list components, including complete group-pin list and full Exchange.resource_pins aggregate. Reject before copying/retaining. Retain fixed ETF formulas and all existing assertions.
4. Five-slot phase tests require full assignment inventory; deliberately add sixth request/config or third policy and assert rejection. Unknown/unassigned marker is an error. Full prepared return and its accounting not double charged. Nil/absent optional payload never reduces reservation basis.
5. Construct maximal old/new/call/reply/workspace bundles for every phase; print/export deterministic per-component and total ETF bytes and complete constructor/copy tables. Do not call owner, DynamicSupervisor, HTTP.fetch, resource pinning or Probe.start_link from these pure tests. Startup modeling uses pinned source + constructed public wrappers, not a live group fixture.
6. Test no side effects by module source audit/allowed function registry; every test in the new file is pure and runs without filtering. Parent command after its source check: `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs --warnings-as-errors --max-cases 1 --seed 33012`. Record real nonzero executed/failure/skip/exclusion counts and exit, pinned runtime, before/after source hashes. This command is **NOT RUN** here.

## Narrow runtime integration after the pure proof

Passing a detached pure module is schema/arithmetic readiness, not full R-GROUP-ACCOUNTING or runtime acceptance. Before live Options/prepare is enabled, root separately assigns these exact calls to the frozen pure validators and independently reviews the source paths:

| Owner from draft | Scope and enforcement |
| --- | --- |
| A | `upstream_groups/options.ex`, `upstream_groups.ex`, `group_endpoint.ex`: compile/profile marker, H/E limits/backing, narrow launch member before child args, validate launch/recovery controls, correct reserve charged before authorized Probe open; keep live H2 compilation unavailable until all boundaries/probe implementation land. |
| B | `http.ex`, `http/session.ex`, new accounting module: pre-source/pre-Session full E/pin-list validation; closed Neutral; selected reply; handoff receive; transition-to-envelope and explicit post-open limits-only config branch. Freeze slot release points. `managed_h2_reservation.ex` gets separate group contract/reserve **only after** measured ledger/reviews; fixed reservation_bytes/3 remains exact. |
| C | `upstream_groups/probe.ex`: validate exact normal/recovery starts and selected config, H2 envelope/client/submitted_url lifecycle, finite reason and original completion; keep normal/recovery schemas distinct and pin/selection payloads bounded. |
| Same test author | Pure accounting test/projector wiring tests exercise boundary functions without live group prepare; later real phase snapshots must match the frozen schema/slot table. |

R-GROUP-ACCOUNTING can pass only after pure schema/aggregate measurements, complete slot/start/recovery table, source boundary enforcement, exact source hashes and independent SPEC→CODE review all pass. The separately prescribed real group/probe network/browser/lifecycle acceptance still follows; mismatching real phase snapshots invalidates readiness. No local numeric workaround and no speculative11542108 runtime amount. No new user decision is needed for this bounded pure prerequisite.

All worker commands completed; no runtime/build/peer/browser/agent started. No repository edit, commit, network, publication or deployment was performed.
