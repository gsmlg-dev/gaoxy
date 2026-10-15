# Managed H2 group canonical transfer and overlap accounting — design draft1

Status: NEXT-STAGE DRAFT; not adopted or executed. The preceding Probe/owner package is still under independent implementation review. Root reports initial format, forced strict compile, pure141/0 and compatibility70/0 with zero skips/exclusions; this document does not promote those results to predecessor acceptance, invent a new commit, or replace its pending SPEC/CODE/fresh gates. Source inspection HEAD is faa07702344b47129119f4902938481ddce03023 plus the current parent-owned implementation diff. Exact inspected hashes accompany decision1.json.

## Chosen bounded result

Implement a **source-linked test-support transfer projector and complete phase measurements** for the real group request, Probe, owner and recovery consumers now present, with canonical Elixir/OTP startup-source binding. Add no production accounting facade, admission number or configurable registry. The current production constructors and Boundary/Envelope validators are the validation oracles where applicable. Independent source review links each modeled constructor/retention/release to its actual consumer; source-text/AST tests do not substitute for that review.

This is the smallest useful accounting increment: it produces executable complete-control projections, analytic bounds, joint admissible maximizers, opaque-capability custody counts and explicit unresolved branches. A detached production schema would create another unused contract; immediately changing reservation/admission would assume a bound that has not been established. A documentation-only inventory would leave the copy/flattening arithmetic untested.

The successful stage disposition is `TRANSFER_CONTROL_EVIDENCE_READY`, scoped to the source families and canonical cohort proved below. `R-GROUP-ACCOUNTING=ACCOUNTING_NOT_READY` remains mandatory. The numeric fixed reserve9444956 stays unchanged. Five fixed Q/config and two checked-policy slots are prior fixed-profile facts, **not** assumed group multiplicities. 9Q/8C/4K, extra2097152 and total11542108 remain unproved/unadopted. No activation, public H2 group Options, Session/Probe/owner/transport behavior, dependencies or existing fixed projector changes.

## Owned implementation paths

1. `apps/gaoxy_proxy/test/support/managed_h2_group_transfer_projection.exs`: new test-only closed projector, namespace `Gaoxy.Proxy.ManagedH2GroupTransferProjection`.
2. `apps/gaoxy_proxy/test/managed_h2_group_transfer_projection_test.exs`: complete component/message/negative tests and real pure-constructor integration.
3. `apps/gaoxy_proxy/test/managed_h2_group_transfer_phase_test.exs`: complete jointly admissible startup/open/bind/cleanup/recovery-overlap bundles, independent structural upper-bound formulas and maximizing fixtures.
4. `scripts/managed_h2_group_canonical_sources.exs`: read-only canonical runtime/source/BEAM/child-spec metadata collector, never starts an owner, Probe, Session, supervisor, adapter, pin or request.
5. Adopted design/plan/acceptance and evidence under `docs/{designs,plans,acceptance}/m3-managed-h2-group-transfer-accounting*`, plus the stage pointer in `implement-plan.md`.

Root owns repository edits, all runtime/build/Git/evidence and local commit. Authors write assigned /tmp artifacts only. Current-stage authors cannot independently review their own implementation. Pure projection/phase authors may work in parallel only after exact contracts are frozen; runtime and repository writes remain serialized. Preserve the existing fixed projector and all prior evidence/assertions byte-for-byte.

## Exact internal pure API

Only the new test-support module exports:

```elixir
contract()
# closed version1, literal source-family/phase enum, unit=:external_term_payload_bytes,
# disposition=:transfer_controls_only, reservation_bytes=nil,
# recovery_order=:unproved, opaque_interiors=:excluded

project(kind, original)
# {:ok, %{control: closed_term, control_bytes: nonnegative_integer,
#         payload_bytes: %{request: proper_integer_list,
#                          config: proper_integer_list,
#                          checked_policy: proper_integer_list},
#         opaque_shells: %{scope: nonnegative_integer,
#                          completion: nonnegative_integer,
#                          native_lease: nonnegative_integer}}}
# | {:error, :invalid_group_transfer}

phase(name, original_bundle)
# {:ok, %{control_bytes: nonnegative_integer, payload_bytes: exact_counts_and_sums,
#         complete_bundle_bytes: nonnegative_integer,
#         roots: exact_source_root_names, disposition: :transfer_controls_only,
#         recovery_order: :unproved, reservation_bytes: nil}}
# | {:error, :invalid_group_transfer}
```

`kind` and `name` have only explicit clauses; no caller-supplied schema, count/cap, marker, slot assignment, callback, source ID override or runtime selector. Returned markers are produced internally only after validating the complete original field. Reject a supplied pre-projected marker even if its label matches. No recursive serialize-anything fallback. The evaluator never calls Lifecycle.call, init/start_link, timers, pin/checkout, Fetch/open, completion await or networking.

The output includes all residual map/list/tuple wrappers and scalars; `complete_bundle_bytes` is the conservative sum of complete control projections and every separately assigned complete payload occurrence. It is **not** ETF of opaque interiors or a VM/heap/RSS/native bound. The sum includes each separate semantic root even when originals compare equal. Aliases within one already counted complete representation are documented separately and never used to erase an independent message, old/new callback or startup root.

## Closed component and transfer families

The exact eight-key H, ordered unique1..32 T manifest, Selected3, strict normal H2 args7, normal H2 state23, legacy owner-produced H1 args6/state18, recovery args4/state5, checked client3, original public handle4 and options7 are the current adopted consumers' shapes. H1 legacy direct init remains broader; do not assert state18 is its universal schema or tighten it through this package. H2 Probe producer remains denied before any child start; its seven-key/startup bundles are constructor-admissible prospective source models, not proof that an active H2 Probe has run.

Use these `kind` atoms only:

- `:group_handle`, `:selected`, `:normal_probe_arguments`, `:normal_probe_state`, `:recovery_arguments`, `:recovery_state`.
- `:session_arguments`, `:session_state`, `:pump_state`, `:exchange`, `:opening_options`, `:original_handle`.
- `:finite_call`, `:finite_reply`, `:startup_call`, `:startup_reply`, `:control_message`, `:group_hold`, `:transport_hold`.

Each kind has an exact closed shape, stage-specific nil/enum constraints and finite allowed subvariants documented in the adoption inventory before test drafting. Full owner state/compiled member collections are **not** projected: private candidate lists/config/health counters remain under the separate owner claim; project only the exact selected hold record and named transferred values. Expanded members are invalid in Selected/startup input.

Validation obligations:

- Call real `UpstreamGroups.probe_start_arguments/1` and `probe_recovery_arguments/1` on original args; preserve original completion identity. Use real `ManagedH2Envelope` validators and real `ManagedH2GroupBoundary.prepare/4` with context6 for original config/Neutral/options. Exercise both http2/h2c, raw leading-zero authority, compact producer URLs and original absolute deadline; no repair-by-copy inside projector validation.
- H must pass complete joint `[H|H.transports]` Resources.validate64/65536 as well as exact profile/provider/identifier/backing/scalars. Each pin's handles is source-coherent; flatten the **complete** Exchange pin list before filtering it. Group pin is7 keys without fabricated holder; transport pin is8 keys with actual holder. Permit a grouped owner-coherent T subset, not an assumed one-pin-per-T map. Require exact intended coverage/no duplicates; independent source proof reconciles group/pump pin ownership and permitted order.
- Full Selected.config occupies one config occurrence. URL and health.path are payloads, even when removed from control maps. Options.request and complete canonical preparation/accounting return occupy named complete request occurrences. K policy is measured only after validating its complete public checked shell; scope is a validated opaque marker.
- Task/Promise/original handle preserve exact public shapes and strict same-completion equality. Validate only exact RequestCompletion shell keys, never traverse/ETF/reconstruct tracker/latch/unsupported interiors. The original completion appears independently in child/request/owner/helper wrappers as source demands. Child-local capture of a late/unsupported successful original does not publish it to an owner-held record.
- Native Exchange lease handling must read the actual H1/H2 public source shell: H2 transport_state is `{connection_pid,stream_id,token}`; preserve PID/stream/token controls. Validate exact native-lease public shape before replacing socket/TLS/certificate capability fields with a named native-lease marker. Never infer TLS/browser coverage from the fixed projector's ssl=nil/peer_cert=nil fixture. If no finite public lease shape can be justified from source, `:exchange`/affected phases reject that variant and explicitly retain `NATIVE_LEASE_PROJECTION_UNPROVED`; they cannot be counted as covered or group activation ready.
- Before any ETF operation establish proper bounded collections, finite signed clocks/headroom, scalar types/encoded bounds, binary logical/backing bounds, exact keys and supported variants. Newly assembled positive fixtures copy their own URL/path at construction; backed-negative originals remain rejected. No marker masking of unknown payload/diagnostics.

`finite_call`/`finite_reply` are selected by their actual complete body shapes, covering group checkout/claim/bind/finish/probe_finished; transport endpoint validation, pin/delegation/checkout/bind/finish/release; recovery result; startup finite success/error. Include caller arguments, receiver normalized authority and returned-client/preparation wrappers in their phases. Keep source/receiver/reply forms separate:

```elixir
# Lifecycle.call -> finite GenServer.call -> OTP28 alias monitor branch
{:'$gen_call', {caller_pid, [:alias | monitor_ref]}, body}
{[:alias | monitor_ref], reply}

# DynamicSupervisor local call -> :infinity -> ordinary monitor reference
{:'$gen_call', {caller_pid, monitor_ref},
 {:start_child, {{module, :start_link, [args]}, :temporary, 5_000, :worker, [module]}}}
{monitor_ref, {:ok, child_pid}}
```

The improper alias list is intentional only in its exact OTP shape. Do not reject it as a generic proper-list rule, convert it to a proper list, or apply it to DynamicSupervisor. Include GenServer callback returns (`{:reply,reply,new_state}`, `{:noreply,state,{:continue,...}}`, init return) separately where concurrently retained. Public endpoint identity is `%{origin: raw_root, upstream_protocol: protocol, instance: pid}`; transport owner receives normalized `{protocol,scheme,lowercase_host,port}` plus instance/deadline. Do not count one as the other.

`control_message` includes existing16 fixed families unchanged plus exact group handoff, claim, Probe cancel/expired/poll, owner DOWN, recovery trigger/result, request-abort-result/helper-DOWN and stage-specific finite errors. No blanket acceptance of arbitrary DOWN exit reason, operation_exit, start exception/stack or :ok-expanded diagnostics. `project` rejects unsupported diagnostic forms without serializing them. Such rejection is an explicit **unclosed actual-source branch**, never evidence the runtime cannot transfer it; the final coverage table must retain `UNBOUNDED_DIAGNOSTIC_TRANSFER_UNPROVED` wherever a real source branch has not been bounded/normalized before transfer. Do not claim a universal transfer bound while this branch remains.

## Canonical runtime and four startup roots

Bind actual current canonical package/source:

- Elixir `/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5`.
- OTP `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7` / stdlib7.3.0.3.
- Current DynamicSupervisor BEAM SHA256 `3da9dcd2ae32c8caf8734e5139aa4f17a714e49aa9279e4bf1317a95fcc0350b`.
- Same-package `dynamic_supervisor.ex`, `gen_server.ex`, `supervisor.ex`, and OTP `gen.erl`, `gen_server.erl`, `proc_lib.erl`; retain exact individual hashes/NAR identity and absence of stripped BEAM compile `:source` metadata.

Root's `startup-child-spec-metadata1` receipt in the current evidence package records actual Probe.child_spec and Supervisor.child_spec preserving an opaque argument marker, restart temporary, default shutdown5000/type worker/modules[Probe], current source9f3de8... and BEAMc84b...; exit0, zero tests, no startup. This is useful metadata only; regenerate against the **final accepted predecessor commit** before new-stage readiness and actual final reviewed source before fresh acceptance. Preserve older22fy observations historically; do not use them as current canonical evidence.

Model four independently charged startup semantic roots for Session, normal Probe and recovery:

1. caller argument `{module,args}` and caller's own retained surrounding bounded inputs;
2. complete normalized supervisor call/from/MFA and supervisor startup locals;
3. child `init(args)` input;
4. complete child init return/new runtime state, plus old/new/continuation wrapper during handoff.

Inspect canonical `proc_lib/gen_server` init acknowledgment/return to place release edges and any additional source root. Four is an obligatory minimum inventory, **not a maximum assumed in advance**; add every independently retained wrapper/root found. DynamicSupervisor `start_child/3` uses `extra ++ args`, then `save_child` calls `mfa_for_restart` and changes temporary MFA args to `:undefined`. Include its temporary concat/call/return workspace; no lifetime-long supervisor `[args]` claim after save. A queued reply can overlap caller/supervisor return state. Metadata/source identity does not itself prove that overlap maximum or GC reclamation.

No live supervisor/process startup is required for these source-linked pure fixtures. Pure calls to generated child_spec/Supervisor.child_spec are metadata, never test evidence of max overlap. The read-only collector emits source/path/BEAM/NAR identities, generated child spec and zero-start/zero-test flags; unexpected package drift fails the cohort binding and triggers requalification rather than silently accepting another source path.

## Closed phase bundles and independent bounds

`phase/2` has these exact names: `:request_start`, `:selected_reply`, `:handoff_checkout`, `:request_prepare`, `:fetch_open`, `:normal_bind_cleanup`, `:probe_start`, `:probe_prepare_open`, `:probe_bind_cleanup`, `:recovery_start`, `:recovery_overlap`, `:recovery_finish`.

Before tests, root adopts an exact key table for each bundle. It contains named source semantic roots (not caller-provided lists/counts): applicable old/new pump, old/new Session or Probe, caller/normalized call/receiver/callback return/reply, complete preparation result, assembly workspace and owner/transport held-record projections. No arbitrary extra root or missing required root is allowed. A source-unproved root causes an explicit unclosed phase disposition and cannot be zero-sized. `phase` returns measured known transfer-control bytes only; the acceptance coverage table lists uncovered branches separately and never converts a missing proof into a numeric zero.

For every covered phase require two **independent** constructions:

- Original complete jointly admissible maximal fixture: H/T/pins all satisfy the same flattened64/65536 condition, selected T is an exact member, client policy matches original authority/protocol, health URL/deadline/limits cohere, task/Promise/owner/helper reference the same original completion, and old/new states are connected by real pure prepare/drop/result functions where available. Do not glue unrelated per-component maxima together.
- Analytic structural upper bound from exact map/list/tuple/atom/binary and all allowed scalar encoding lengths under pinned OTP, including full wrappers and repeated semantic roots. Derive the formula from constructor field bounds and source multiplicities, independent of the projector's returned count. Compare against complete ETF of the safe projected fixture and prove each logical/backing/manifest boundary plus first invalid value. An assertion against a copied implementation constant or a handful of small self()/make_ref() fixtures is insufficient.

If an exact maximum is not attainable, report separately the valid reachable maximizing fixture and the conservative analytic upper bound with an explanation of slack. For legal PID/ref encodings use bounded pure ETF constructors with a fixed finite atom set or source-proved full scalar bounds, never unbounded atom creation/distributed nodes. Locally minted self/make_ref controls and externally supplied H/T scalar cases have different source provenance. If a constructor-admissible scalar exceeds the proposed projector bound, fail readiness; do not silently narrow actual production acceptance with a test-only cap.

Count Q/config/K occurrences explicitly by semantic root, **derive** their per-phase counts and record global maximum from complete admissible bundles. Preserve complete canonical preparation+accounting as one complete representation, not an accounting-map discount. Assembly workspace includes raw root, joined URL, Neutral, old/new envelope, field copies, complete preparation return and pin-filter outputs not already assigned as complete payloads. Actor-local synchronous calls do not serialize pump against Session or group owner against transport owner. Do not assume every actor has at most one workspace before source proof.

## Concrete recovery-order gap and required conservative treatment

Actual normal Session cleanup is original cleanup -> transport finish -> transport pins -> group finish -> service cleanup (`Session.cleanup_complete/finish_transport/finish_selection`). Normal Probe has corresponding original -> transport -> pins -> probe_finished order. These are source facts to preserve; they are not recovery order proof.

Actual group owner `recover/4` starts a helper only from previously stored `held.completion`, with exact args4 and existing `max(held.deadline, now+1000)` calculation. Helper `:recover` awaits the same public completion then sends `{:recovered,kind,token,self(),:ok}`. Group owner's recovered handler immediately calls finish_token/finish_probe. It receives **no** selected T/token, no transport owner acknowledgment and no transport helper join proof.

Meanwhile transport owner independently handles guardian DOWN, stores guardian_down, starts its abort helper, and removes its token only after both helper DOWN/result and another completion check. The two owners' monitors/mailboxes can run in either order. A shared completion `:ok` establishes request resources, not that the other owner has processed its helper join/released its held token. Therefore strict transport-before-group recovery release is **UNPROVED by construction**, with a possible interleaving group-finish while transport token/helper remains. This is a concrete release-coupling gap for a future per-group reservation/slot reuse proof; do not call it a newly demonstrated production data loss or infer failure of existing H1 tests.

The transfer slice must retain simultaneously: failed-child final safe projection; group held record and recovery handle/monitor; four helper startup roots; transport held record/abort-helper/result/DOWN controls; shared original completion shells; pending result/reply wrappers. Include pre-bind held.completion=nil as failed/uncertain with no helper capability invented. A child's retained original is not owner publication. This overlap measurement does **not** solve the release-coupling gap.

Recommended subsequent bounded behavior design, if a future per-group reserve requires strict release ordering: add an explicit completion-bound transport-release receipt that an owner recovery path can authenticate against an exact stored selected T/token. That requires designing/storing the transport recovery reference before the failure window, defining pre-bind nil-completion behavior and retention, and tests for both owner schedules/helper joins/death. Do **not** merely call existing UpstreamTransports.finish from the recovery child: it authenticates the original guardian caller; the helper is different. Do not add this wire/API/early bind in the present accounting stage. Design must choose between authenticated ordered release and a separately bounded unreleased-overlap ledger; current source alone cannot justify choosing a numeric reserve. No permission pause is needed to prepare/execute that next bounded stage under continuing authorization.

## Acceptance and boundaries

Distinct gates: final predecessor acceptance/commit and fresh source inventory -> independent adopted design readiness SPEC -> complete tests-first missing-interface RED -> projector/collector implementation -> complete initial format/strict compile/pure and related compatibility GREEN -> full independent implementation SPEC -> independent CODE -> fresh same gates -> scoped local commit. No filtered/skipped/excluded tests; source hashes and counts/exits recorded. Readiness is not implementation review. Metadata commands count zero tests and cannot replace nonzero pure gates.

Required acceptance proves only covered transfer/control formulas, current source mapping and exact unknown table. Every phase/family is classified PROVED_FINITE, REJECTED_INVALID_INPUT, CONSTRUCTOR_ADMISSIBLE_BUT_RUNTIME_DENIED, or SOURCE_BRANCH_UNPROVED with exact reason. Unsupported diagnostics/native lease/recovery-release unknowns cannot be called passed aggregate gates. Root auto-advances after this bounded gate to any required concrete recovery/retention repair and then full aggregate admission accounting; it does not end at another plan or remove denial early.

No publication, deployment, Vault, production data/certificates, public management, disabled release-artifact E2E or http_fetch#97 work. No third Astra recovery. Preserve inherited counters; root reports current repairSol1 and old counters separately rather than resetting them for this design.
