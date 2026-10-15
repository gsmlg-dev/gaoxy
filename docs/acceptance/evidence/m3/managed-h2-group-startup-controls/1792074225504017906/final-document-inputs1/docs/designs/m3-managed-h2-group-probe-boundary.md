# Managed H2 group Probe and owner transfer boundary — design version4

Status: DONE locally at `1f32850e4d1cfd2e5c5b913e12bb574bfe924f5b`, tree `b4185c690df1ad113618fda7b0de63ec7a0d917d`. Independent implementation SPEC30/0, CODE15/0 and fresh format/forced strict compile/pure141/0/H1 compatibility70/0 passed. Final document rebind passed after one retained docs-only failure/repair; raw disk/index audit and all131 actual feature-tree paths authenticated. No activation or publication.

## Chosen bounded result

Wire concrete normal and recovery argument constructors into the real owner and Probe consumers, narrow each owner member before child-start argument construction, and implement the H2 Probe preparation/open/result/drop/client-routing path behind unconditional accounting-not-ready denial. Reuse the accepted `ManagedH2GroupBoundary.prepare/4` and `activation/0`; therefore H2 normal startup acquires an explicit seventh `group` key. Legacy normal startup remains six keys. Recovery remains exactly four keys and its runtime state five keys.

The H2 producer rejects before the existing H1 reservation formula and before starting a Probe. Probe independently denies H2 before claim/transport checkout and again before any ManagedH2Client.open. Options and public group preparation remain H1-only. No numeric H2 Probe reservation is adopted. These guards are required source behavior, not disabled assertions or a test flag. Supporting H2 code is deliberately unreachable from public configuration until separate accounting/admission and activation work.

Scope is four code/test files:

| Ownership after root assigns execution | Path | Responsibility |
| --- | --- | --- |
| Owner author | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex` | Narrow startup member; actual pure normal/recovery argument constructors; early H2 denial; H2-specific owner claim with full stored handle equality. Preserve legacy claim, scheduling, private counters and recovery outcomes. |
| Owner author | `apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs` | Complete pure constructor/rejection/opaque identity cases, including unchanged legacy normal shape. |
| Probe author | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex` | Consume strict constructor only in H2/recovery init; preserve legacy init; H2-only preparation/result/drop helpers and guarded continuations; protocol-specific client calls and original-handle cleanup. |
| Probe author | `apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs` | Complete pure Probe transformations, original handle and deadline/error cases. |

Root alone integrates repository edits, runs commands, freezes evidence, adopts scoped documents and commits. Authors are not alone and must preserve others' work. The two authors may draft independently only after signatures/shapes are frozen; root serializes integration and all runtime commands. No edits to Options, HTTP admission, GroupEndpoint, Session, Boundary, reservations, dependencies, fixed projector, existing assertions or E2E are part of this package. If a required implementation cannot fit these contracts, report the concrete scope/design issue before expanding. No detached accounting module, configurable schema registry, new process or fake adapter.

## Source findings and limits

`upstream_groups.ex:625–666` already narrows request checkout to id/config/max_inflight. In contrast, `715–785` holds a private expanded member in the candidate list and places it whole in six-key Probe args at743–750. The member includes checked/failures/successes/inflight/probe/due/health; private counters have no finite lifetime bound at788–847. They must remain owner-local rather than being normalized into a new transferred health schema.

`probe.ex:11–14` has a distinct recovery init; normal init16–38 adds operational controls. Normal open41–81 hard-codes endpoint protocol :http1, and102–149 hard-codes HTTPFetchClient and its options. Poll/event/subscribe/cleanup later also use that client. Normal bind is transport then group; normal completion is original request cleanup, transport finish, pins release, then probe_finished. Preserve this ordering.

Recovery851–870 constructs owner/recovery/completion/deadline, and Probe155–173 repeatedly awaits the same public completion. HTTPFetchClient.await_completion is already a protocol-neutral RequestCompletion facade. Do not add a client field, wrap/reconstruct the completion or switch await semantics. Transport owner guardian-DOWN recovery proceeds independently (`upstream_transports.ex:1263–1328`); the group helper only observes public completion. Strict cross-owner recovery release order is UNKNOWN, a future accounting/activation obligation. This package neither proves nor changes it. Successful normal transport-first finish is not evidence of a recovery ordering guarantee.

The accepted source inventory and readiness investigation are in `docs/acceptance/evidence/m3/managed-h2-group-source-foundation/1792064671198695595/gaoxy-h2-group-request-copy-inventory.{md,json}` and `gaoxy-h2-group-accounting-readiness-investigation.{md,json}`. Their source snapshots are historical. Retain their failure/unknown dispositions; the older detached-ledger recommendation is not adopted here. This package establishes real consumers before any accounting evaluator.

## Pure owner argument helpers and real consumers

Add only these internal pure owner exports:

```elixir
probe_start_arguments(args)
# {:ok, exact_args} | {:error, :invalid_probe_arguments}

probe_recovery_arguments(args)
# {:ok, original_exact_args} | {:error, :invalid_probe_arguments}
```

Both are called by the real owner immediately before its applicable DynamicSupervisor.start_child path. The strict normal constructor is also consumed by H2 Probe.init, and the recovery constructor by recovery init. The legacy normal Probe.init clause stays unchanged and is NOT routed through the strict normal constructor; its broader source compatibility contract is specified below. No clock, owner call, process, timer, pin, await or serialization of opaque interiors occurs inside them. They validate originals, not lossy projections. They do not grant owner authority.

Actual normal producer first performs `Map.take(member, [:id, :config, :max_inflight])` in its own local scope BEFORE constructing args. This is the same exact Selected schema as accepted request checkout. Never pass the expanded member into the constructor/start_child and discard it later. A local config alias is not another retained config sidecar. The private candidate list is not copied into startup args.

Normal legacy args are exactly:

```elixir
%{owner: pid, token: ref, member: selected, deadline: integer,
  health: health, url: binary}
```

This is the exact NEW OWNER-PRODUCED H1 contract, not the general accepted shape of legacy Probe.init. For this owner constructor require Selected3 and the actual supported H1 HTTP config/client already produced by current Options. Retain existing H1 config, health/path acceptance, URL, deadline and behavior; do not reinterpret caller health, tighten existing H1 backing rules, alter timeouts or change scheduling/outcomes. Return the same produced values. New H2 restrictions below must not bleed into this branch.

**Legacy init compatibility:** Current `Probe.init(args)` only reads args.health.timeout and args.owner before merging runtime controls; deadline is optional through Map.get's existing fallback. Its later opening logic reads member.config, never member.id or member.max_inflight. Thus valid direct/internal H1 fixtures may use member=%{config:config}, health=%{timeout:n}, optional deadline, or an existing expanded legacy member. Do not route these inputs through the strict owner-produced Selected3/six-key/full-health constructor and do not change their assertions to fit it. Leave the legacy init clause, fallback deadline calculation and resulting values unchanged. The actual owner now produces narrower args; that is a producer guarantee, not a universal legacy input schema.

H2 intent from group profile, selected protocol or ManagedH2Client is classified BEFORE legacy init. An H2-intended malformed input must reject in its strict H2 clause and never reach the compatibility clause. Legacy compatibility grants no H2 permission and adds no caller selector flag.

Current scoped search across all apps/test source and test support found no direct Probe.init/Probe.start_link call. Existing `upstream_group_probe_test.exs:181–215` prepares through the real owner and inspects real child state; `upstream_group_transport_probe_test.exs:728–784` observes actual supervisor startup through a deterministic barrier. This is source inspection, not proof that external/root-only or later direct fixtures do not exist. Root must include any such fixtures in the adoption inventory; preserve their valid current H1 behavior. The source compatibility requirement above is unconditional.

Normal H2 args are exactly these SEVEN keys:

```elixir
%{owner: pid, token: ref, member: selected, deadline: signed64,
  health: health, url: compact_binary, group: h2_handle}
```

Selected is exactly id/config/max_inflight: compact id1..128, max1..1024, complete accepted Envelope.validate_config H2/h2c config, nonnil exact transport handle. H is the accepted exact eight-key provider/owner/owner_epoch/group/generation/max_url_bytes/transports/execution_profile=:managed_h2 shell, with compact group1..128, max_url1..8192, proper unique1..32 exact T handles and complete flattened Resources.validate([H|Ts]) bound64/65536. Require H.owner===args.owner and selected T exact membership. Preserve unique supplied order. Pure equality/coherence is not owner-record authentication.

Health is exactly seven keys path/interval/timeout/stale_after/failure_threshold/recovery_threshold/jitter. Keep current logical ranges: path1..8192 beginning slash, ASCII33..126 excluding ?/#/backslash and malformed percent escapes; times1..3600000, jitter0..3600000, timeout<=5000, thresholds<=100, stale_after>=interval. For H2 additionally require compact path and validate all scalars before copy/ETF. H2 URL is compact, exactly raw selected scheme+"://"+authority+health.path, root<=H.max_url_bytes and8192, joined URL<=65536 and advertised H.max_url_bytes+path<=65536. No URL canonicalization or private owner counter is copied.

The H2 owner candidate computes its absolute budget from one explicit launch now:

```text
budget = min(health.timeout, selected.config.limits.opening_timeout,
             selected.config.limits.max_lifetime)
deadline = launch_now + budget
```

Validate signed64 launch_now/addition and deadline+1000 headroom before constructing candidate args. Legacy H1 deadline construction remains unchanged. H2 preparation later uses opening_deadline=deadline: a HEAD Probe has one finite opening/total budget, already no larger than each original limit. Waiting/startup never renews it from child init now. Constructor validates the signed64/headroom shell; expiration is handled by normal callback cancellation, not by a constructor that would crash an otherwise valid delayed child.

Actual launch classifies H2 intent from selected protocol/client or H.profile BEFORE computing the H1 URL reservation or entering a legacy default. A coherent H2 candidate is checked by probe_start_arguments, then the fixed public gate dispatch below returns the unchanged owner state: no reserve calculation, token/probe record, health change, pin or child start. Invalid H2 intent likewise fails closed. Keep the actual H1 start path through its existing capacity/reserve logic, after narrowing and constructor success. A future successful activation branch must not start an H2 child using the H1 reserve or zero bytes; validated H2 admission is a separate required change before gate removal.

Recovery args are exactly:

```elixir
%{owner: pid, recovery: {kind, token}, completion: original, deadline: signed64}
# kind in [:selection, :probe]; token reference
```

The helper checks exact four keys, PID/reference/kind, signed deadline and exact public RequestCompletion shell keys only. It preserves `completion === original` and the original deadline. No interior traversal, ETF, replacement capability, additional client/H/member/url/health or newly calculated deadline. Existing actual owner still computes max(held.deadline, Lifecycle.deadline(1000)) before this helper; actual Probe.init adds ONLY owner_monitor and schedules existing :recover. Do not reject expired recovery args before the first abort/await attempt or change its retries, release outcome or hold semantics. Unsupported-completion/error results remain current public facade behavior; no new success is inferred from a shell. Malformed internal args fail the existing start-failure/fail-closed owner path.

## Fixed public gate dispatch and strict compilation

The public `ManagedH2GroupBoundary.activation/0` retains its single literal `{:error,:accounting_not_ready}` clause unchanged. Each actual owner/Probe consumer uses this exact fixed dispatch when retaining its future :ok branch:

```elixir
apply(Gaoxy.Proxy.ManagedH2GroupBoundary, :activation, [])
```

The module, function and empty argument list are constants in source. No settings, caller flags, function arguments, configurable dispatch, specs, compiler-warning suppression or alternate test callee. This is the existing Session compatibility approach: a direct remote call under Elixir1.18.5 inferred the literal error and warned that the future :ok clause was unreachable; warnings-as-errors failed strict compile. Root reports fixed apply passed its isolated strict compile and the actual one-line Session repair passed forced strict compile. This draft does not rerun or reclassify those checks.

Producer denial still precedes the wrong H1 reserve/start. Probe denial still precedes claim/transport checkout and its later staged open. Fixed apply is the real supported public gate, never a bypass. Independent CODE must read each actual source branch and establish dominance and constant callee/arguments; complete initial and fresh forced strict compiles must pass with future code retained. Do not weaken the public literal denial or remove required future source to make compilation pass.

## Actual H2 owner claim authority

Preserve claim_probe/3 and its H1 call/message. Add one H2-specific internal facade `claim_probe(owner, token, H, deadline)` with wire body `{:claim_probe, token, H, deadline}`. This introduces a complete H payload in claim call/receiver wrappers; it is accounted explicitly below.

The H2 owner clause requires the same one-use probe token, actual caller PID, stored monitor, ready/live instance, active group and matching unexpired original deadline as the legacy check, plus `deadline === probe.deadline`, stored group.handle===H, H owner==self and owner_epoch==state.epoch, group key/generation matching the probe record and profile=:managed_h2. Compare against the full stored handle; do not authorize an ordered transport permutation merely because the pure helper accepts both permutations. Mark claimed only after all checks and return existing {:ok, state.instance}. No public H2 compile/prepare path or new token creation is added. Stored owner record and actual launch PID are authority; pure Selected/T/H/PID shells are coherence only.

## Pure Probe state transformations used by callbacks

Add only three internal pure Probe exports, used by actual H2 callbacks:

```elixir
prepare_group_open(state, instance, now)
# {:ok, staged, :group_open} | {:error, finite_reason, dropped}

drop_group_opening(state)
# group-H2 -> dropped state; legacy H1/recovery -> exact identity

group_open_result(staged, result, now)
# {:ok, bind_state, :group_bind} | {:error, finite_reason, dropped}
```

No hidden clocks, runtime calls, timers, owner/service processes, pin/checkout, client.open, completion await or synthetic adapter inside these helpers. now is explicit signed64. Tests call these public pure functions through apply until missing-function RED is captured. These are concrete production state transitions, not detached validators or an accounting framework.

Production owner-created legacy normal runtime is its six args plus cleanup_deadline/owner_monitor/timer/request/original_request/managed_transport/transport_selection/transport_pins/terminal/cancelled/headers/outcome: eighteen keys in total. This count describes the owner-produced form, not every broader legacy init fixture. H2 normal init starts with seven args and the same twelve operational additions, then adds exactly client/limits/request_options/submitted_url: twenty-three keys. client=ManagedH2Client, initial limits=member.config.limits, options/url residual=nil. Recovery runtime is exactly its four args plus owner_monitor: five keys. Do not store instance, checked policy, Selected or config a second time under another field.

H2 `handle_continue(:open, ...)` must precede all legacy open clauses, including transport:nil. Check existing opening_allowed mailbox/cancel/deadline/owner logic, then the fixed public gate dispatch below. Current denial drops and settles as terminal/cancelled/outcome=:cancelled with no claim, endpoint validation, pins, checkout or open. On the separately future-enabled branch, claim exact H first, validate selected T with actual selected protocol/raw root/returned instance/deadline, obtain its request pin and checkout, preserving existing checks between waits. No rewrite via a former client policy. Install only transport_selection and managed_transport temporarily; pass returned instance locally to prepare_group_open.

Preparation requires coherent H/owner/Selected/selected T, exact checked client, transport_selection T equality and request-pin coverage under current public pin shape. Validate originals before constructing Neutral. Use health.path unchanged as target, method=:head, fields=[], body_mode=:none, max_upload_bytes=1 and exact current maximum request_limits256/65536/128/65536. Require startup URL===raw root+path; it is not a caller override. Effective endpoint limits are selected.config.limits with opening_timeout, write_timeout and max_lifetime each additionally clamped by health.timeout; idle_timeout/chunk stay selected values. Call accepted Boundary.prepare(selected, neutral, checked, %{group:H, instance:instance, limits:endpoint_limits, deadline:state.deadline, opening_deadline:state.deadline, now:now}). No additional Boundary export or context key.

Success stores only request_options={:group_prepared,options} and limits=effective limits, clears member/group/health/url/managed_transport to nil and keeps stable client=ManagedH2Client. Owner/token/transport_selection/pins, request/original_request, deadlines/timer/monitor and terminal/cancelled/header/outcome controls survive. No clock/timer reset; the original launch deadline and cleanup_deadline remain unchanged. Return the actual continuation :group_open.

Drop is H2-only and idempotent. It clears member/group/health/url/request_options/managed_transport/submitted_url to nil and preserves finite five limits, or nil on malformed limits. It retains stable client, owner/token, actual original completion/handle, transport selection/pins, deadlines/timer/monitor and all terminal/outcome controls. It returns legacy normal and recovery values identically. Group intent must be recognized from startup H profile and/or selected H2 member before legacy fallback; stable H2 client identifies sanitized stages. No complete Selected/config/health/checked policy remains in staged, bind or cleanup state.

The actual :group_open continuation rechecks opening_allowed and fresh absolute remaining time, replaces only options.timeout/opening_timeout by deadline-now, then invokes the fixed public gate dispatch below before any ManagedH2Client.open. Current denial drops and settles neutrally. No caller flag/environment/test override. This second barrier protects a sanitized stage even if an earlier branch is changed incorrectly; independent CODE review establishes actual dominance without AST/source-text tests.

Result success is exactly {:ok, original_handle, nil}, because the accepted HEAD/none constructor creates no upload. Validate through ManagedH2Client.completion and exact public RequestCompletion shell/strict handle completion identity, retain the original handle unchanged in request and original_request BEFORE cancel/deadline checks, set submitted_url from the validated staged envelope, clear opening payloads/K and return :group_bind. Never derive an upload from handle.stream, add a handle key or fabricate completion.

**Every malformed or unsupported result tagged :ok returns exactly `{:error, {:cleanup_unconfirmed, :invalid_response}, dropped}`.** This includes :ok itself, all tuples with first element :ok and wrong arity, invalid/unsupported original handles, every nonnil upload (PID or otherwise), and expanded/extra successful return shapes. A supported original handle is retained unchanged in request/original_request for cleanup when one is available; a valid handle with impossible nonnil upload still gets this mandatory discriminator. Arbitrary malformed handles/uploads/diagnostics are never retained. No supported completion means cleanup evidence is absent, never confirmed.

Late valid successful original handles remain installed on cancelled/expired drops; no bind/success is emitted. Finite local errors are invalid_request/cancelled/request_timeout/timeout. Raw client cleanup-unconfirmed atom/tuple is recognized before ordinary finite error mapping and produces {:cleanup_unconfirmed, flat_finite_atom}; unknown inner diagnostics reduce to cleanup_unconfirmed. Unsupported :ok results ALWAYS retain the full cleanup-unconfirmed/invalid_response discriminator above, never ordinary :invalid_response. Ordinary client errors use the accepted finite ManagedH2/Session vocabulary and unknowns become upstream_failure.

**Consumer dispatch order is mandatory:** handle `{:error, {:cleanup_unconfirmed, atom}, dropped}` BEFORE ordinary result errors. Stop with its finite cleanup-unconfirmed reason and dropped state, preserving any original supported handle and all owner/transport selection holds and pins. This applies even when request=nil, original_request=nil and/or transport_selection=nil. Never send probe_finished, release/refund a hold, or fall through rejected, settle(request:nil), complete or an ordinary error branch for this discriminator. Existing raw cleanup-unconfirmed atom/tuple results follow the same stop/hold rule. Retaining a supported original in dropped/stopped child state preserves child-local cleanup custody and transformation identity; it does NOT publish completion to an owner record or prove cleanup. Existing owner recovery can use only an original completion already stored by a successful bind. A pre-bind malformed success may leave held.completion=nil: current fail-closed lifecycle/hold/uncertainty remains authoritative, because owner recover reads its held record and never the stopped child state. No early bind, death-state inspection, new wire/API, completion-publication step or recovery guarantee is introduced. Any need to recover these pre-bind originals remains separately designed accounting/activation work. Normal local denial uses cancelled health; genuine attempted ordinary upstream errors retain current failure health semantics. No accounting success follows from an error normalization.

Actual :group_bind binds exactly the same original completion transport-first then UpstreamGroups.bind_probe; only both successful binds schedule header polling. A failed transport bind never attempts group bind. Either bind failure drops payloads/URL and settles with original handle and both ledgers retained; no early refund. Normal H2 finish remains original-handle cleanup, transport finish, pins release, then probe_finished. Existing H1 clauses keep their client/cleanup behavior.

H2 poll/event receive transient `{request, submitted_url}` contexts required by ManagedH2Client. Header acceptance clears submitted_url; resolved handles may then use nil URL. Subscription uses the selected client on the public handle. Cleanup chooses original_request from stable client=ManagedH2Client, even after managed_transport has been dropped, rather than the old nonnil-K heuristic. All terminal paths clear submitted_url. Existing H1 and recovery paths retain HTTPFetchClient and existing behavior. New helpers do not certify peer delivery, completion provenance or lifecycle races.

## Exact transfer/root inventory for later accounting

This slice supplies actual producers/consumers for future source-linked measurements; it adopts no PC/PR/H/Q/C/K byte cap or multiplicity. A URL or health.path projected out of a control map still occupies a payload root. The H2 seventh field is additional H, not free six-key control bytes.

| Transition | Complete shape/root to retain in the inventory | Release / unknown |
| --- | --- | --- |
| Owner normal candidate/start | caller `{Probe,args6}` or `{Probe,args7}`; owner-local narrow Selected.config C; URL Q and health.path payload; H in args7 only | Expanded owner health member stays private; local aliases inside args are not separately charged. Owner immutable config remains separately owned. |
| DynamicSupervisor call | `{'$gen_call', from, {:start_child, {{Probe,:start_link,[args]},:temporary,5000,:worker,[Probe]}}}` under current installed default child spec; capture actual caller alias/from and start success/failure wrappers | Canonical runtime binding and actual child spec/default shutdown must be verified by root; do not trust this installed-source description as a measured canonical proof. Never serialize arbitrary start exceptions/stacks. |
| Child init/return | child args6/args7 and returned eighteen-/twenty-three-key state independently, simultaneous with caller and supervisor roots | Four startup roots: owner caller, supervisor normalized call/MFA, child init args, returned child state. H2 H and Selected C and URL/path payload occur in each relevant root. Temporary save_child changes MFA args to :undefined after successful start; no lifetime-long retained startup args claim. |
| H2 claim | public call arguments plus `{'$gen_call',from,{:claim_probe,token,H,deadline}}`; owner received H; {:ok,instance} reply | New claim H is copied explicitly. Stored owner record equality is an authority check, not a pure H cap. |
| Validate/pin/checkout | public raw origin/protocol/instance and normalized transport wire authority; complete pins call/reply; checked client sender/receiver transfer | Existing checked K and selected C are charged through actual stage boundary; no hidden client/config sidecar. Exact call/from/reply wrappers remain in phase bundles. |
| H2 stage/open/result | old normal state Selected C+H+health/URL, Boundary Neutral/assembly/preparation scratch, new tagged options Q/K; continuation old/new state; client prepare/Fetch complete source/return wrappers | Drop only establishes the returned-state boundary, not GC or all old-root death. Source-linked overlap/maximal complete bundles remain necessary. |
| Bind/finish | original opaque completion shell in original/request aliases, transport/group bind calls/replies, transport finish, pins release, probe_finished | Preserve original identity and normal order; completion interiors never serialized. |
| Recovery start | exact args4 in caller/supervisor/init and returned state5; owner held.completion plus recovery/recovery_monitor; original failed-child final state may coexist | Four recovery startup roots plus retained failed-child/owner overlaps. No normal member/H/URL/K in recovery args. The same capability is opaque, never reconstructed. |
| Recovery control | :recover; exact owner monitor DOWN; `{:recovered,kind,token,helper_pid,:ok|{:error,public_reason}}`; current await result and start failure wrappers | Current public unsupported completion tuple and pending/unconfirmed are not invented success. Strict cross-owner transport/group recovery release ordering remains UNKNOWN and outside this acceptance. |

The original author inspected older22fy installed source; that is historical only. The adopted current source inventory below uses canonical jc6g Elixir and vp5p OTP package hashes and the actual generated child-spec metadata. Source-to-BEAM reproduction, executed transfer envelopes and aggregate four-root bounds remain unproved. Payload sharing/alias reuse does not erase distinct conservative semantic roots. Keep all complete wrappers and jointly admissible flattened H/pin caps; no independent uncoupled maxima.

## Acceptance and explicit future obligations

Independent DESIGN-READINESS SPEC on the complete adopted documents precedes any tests/code. Root then captures intended missing-function RED for both complete new pure files, implements through actual owner/Probe consumers, and obtains complete initial GREEN for scoped format, forced strict compile, both complete new/related pure files and required existing real H1 compatibility. Only after complete GREEN, freeze the full implementation candidate and obtain independent FULL IMPLEMENTATION SPEC against every adopted requirement. This is a separate gate from design readiness and cannot be inferred from pure GREEN. After implementation SPEC PASS, obtain independent CODE review of that candidate. Resolve findings without weaker assertions, refresh required GREEN and affected reviews, then run fresh scoped format/forced strict compile/nonzero pure and existing real H1 compatibility tests on the final reviewed source before the local commit. No filtered/skipped/excluded required cases. Actual owner/Probe routing, full record equality, early denial, single config root, original identity, client dispatch and timer/order effects are direct independent source review obligations, not AST tests or fake network acceptance.

Existing real H1 Probe/transport/owner tests remain required scoped compatibility. New H2 tests here are pure only: no owner/Probe process, :sys state injection, supervisor, timers, pin/open/Fetch/await, network/browser or fake adapters. Do not claim H2 protocol/accounting/lifecycle acceptance from them. All unexpected regressions enter the parent's cumulative diagnosis budget; retain historical failures and receipts.

After this package passes, re-inventory the actual completed Session/Probe/owner/request/recovery transitions, bind the canonical startup source, build complete maximal wrapper/overlap phase bundles, and settle cross-owner recovery ordering before accounting/admission and separately reviewed gate removal. Queued cancel/expiry/DOWN behavior and genuine network/browser/lifecycle acceptance remain future activation gates. 9Q/8C/4K, extra2097152 and total11542108 remain UNPROVED_NOT_ADOPTED; fixed9444956 stays unchanged. R-GROUP-ACCOUNTING remains ACCOUNTING_NOT_READY. No new reserve, H2 Options, deployment, publication, certificates, production data, Vault, public management or disabled E2E change.

Counters are inherited rather than reset: current predecessor boundary parent update is repairSol2/strictCompileFailure1/compatibilityFailure1/pure unsuccessfulGREEN0; expectedRED46 remains separate from repair failures. Complete initial format/forced compile/pure153/0 and36-file compatibility603/0 all passed on stable source with no skips/exclusions. Post-GREEN custodyfailure2 is preserved separately (wrong format glob; candidate1 not released, candidate2 corrected); implementation repairSol2/runtime counts are unchanged. Full predecessor implementation SPEC is in progress; CODE/fresh gates/local commit remain pending; no accepted predecessor commit is invented. Initial pure-module draft1 remains historical; source-foundation repairSol1/failedSPEC1/custodyfailure1/intendedRED1/unsuccessfulGREEN0; earlier fixedSol19, fixtureSol20 RED1/GREEN1, collectorSol17/full58 failed2; Astra2/2 exhausted. Root must append any later current-boundary counters before adopting this draft. This drafting task starts zero implementation/repair/recovery rounds.

Preliminary next-design SPEC1 FAIL at `/tmp/gaoxy-h2-group-probe-design-spec1.json` is preserved unchanged. Finding H2GP-DESIGN-SPEC-001 prompted version3 mandatory unsupported-success discriminator, no-selection stop/hold rule and explicit pure cases. This document does not self-certify closure: renewed independent design review and predecessor acceptance/adoption remain required. Next-slice implementation0/repair0; draft designfailedSPEC1 and designfailedSPEC2 are separate preliminary design counters. SPEC2 preserved at `/tmp/gaoxy-h2-group-probe-design-spec2.json` closes001 at draft level and identifies002; version4 corrects only the child-custody/owner-publication wording. Renewed independent review remains required; this author does not self-certify002 closure.


## Historical root adoption checkpoint

Accepted predecessor: `faa07702344b47129119f4902938481ddce03023`, tree `93fea824f916f36e2326a2d3354db211aeab9e6d`. Evidence: `docs/acceptance/evidence/m3/managed-h2-group-probe-boundary/1792070728396819458`. Current owner/Probe/Options sources remain unchanged at adoption; two planned test files do not exist. Implementation0/repairSol0; preliminary designfailedSPEC2 preserved and both001/002 design findings closed by preliminarySPEC3, with formal adopted readiness still pending. Predecessor counters: boundary implementation1/repairSol2/strictCompileFailure1/compatibilityFailure1/pure unsuccessfulGREEN0; expectedRED46 separate; stage manifest custodyfailure2 (first wrong Resources path, second pre-review format-glob aggregation); no resets. Source-foundation/fixed/collector/fixture and Astra2/2 exhausted remain unchanged.

Preparatory canonical metadata found actual loaded Elixir in `/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5`, rather than the older22fy package inspected by the author. Loaded stdlib BEAM/disk SHA identities and installed same-package source hashes are retained as preparation only. Metadata attempt1 failed because stripped BEAM compile metadata has no source field; attempt2 reports that absence honestly. No aggregate accounting, startup-wrapper/maximal overlap bound or recovery ordering is proved by these read-only identities. Later accounting must use the actual executable/source package and preserve both metadata attempts.

## Historical root implementation entry

Formal adopted readinessSPEC1 PASS,19 requirements/zero findings on candidate SHA2569c737a0fd3c680600daa8a591cb2a79a71334622225552e23df6629ac3526758. Original adopted documents are preserved under distinct design-readiness-inputs1 paths before these status updates. Actual predecessor faa07702344b47129119f4902938481ddce03023 and entry conditions verified. Tests-first authors may now draft the two complete pure files; production drafting waits for each actual missing-interface RED. Implementation1 starts; repairSol0, prior preliminary failedSPEC2 and all inherited counters remain unchanged.

## Complete initial implementation checkpoint

Status: COMPLETE INITIAL GREEN; independent FULL IMPLEMENTATION SPEC and CODE, fresh verification and local commit remain PENDING. Intended complete missing-interface RED executed owner29/29 and Probe26/26 before production drafting. Implementation1/repairSol1/owner unsuccessfulGREEN1; all failures and original assertions are retained. Current initial format and forced strict compile PASS; complete pure141/0 and six-file real H1 compatibility70/0, zero skips/exclusions and stable source. H2 group activation remains ACCOUNTING_NOT_READY.

Evidence is in `docs/acceptance/evidence/m3/managed-h2-group-probe-boundary/1792070728396819458/initial-complete-green1.json`. The adopted `gaoxy-h2-group-probe-transfer-inventory1.{md,json}` and `transfer-inventory-adoption1.json` in that directory authenticate actual consumer/canonical-source/metadata inputs. Local infinity startup From is `{caller_pid, monitor_ref}`; finite Lifecycle calls use `{caller_pid, [:alias | monitor_ref]}`. Worker shutdown5000 is distinct from startup infinity. Four semantic startup roots and recovery/failure overlap remain unmeasured; child-local original custody does not publish owner completion and strict cross-owner recovery release order stays UNKNOWN.

## Final reviewed implementation and fresh verification

Status: VERIFIED FOR LOCAL COMMIT. Independent FULL IMPLEMENTATION SPEC1 PASS (30 requirements/zero findings), CODE1 PASS (15 checks/zero findings), then fresh format, forced strict compile, complete pure141/0 and six-file real H1 compatibility70/0 all PASS; zero skips/exclusions, joined commands and stable source. Local commit follows document rebind and raw/index byte audit. H2 group/probe activation remains ACCOUNTING_NOT_READY.

`fresh-complete-green1.json` binds exact SPEC/CODE and fresh receipts/logs to implementation candidate SHA256bbc55d849a69962f2dc655d1ee9d793e89e83d1c4da1d0a0e8f9466cdd142beb. All43 original tests remain byte-identical. Implementation1/repairSol1/owner unsuccessfulGREEN1 remain unchanged; current report custodyfailure1 records an early /tmp read rejected before final reviewer delivery/adoption. It changed no source or implementation result; final report hash was authenticated after delivery. All inherited counters/failures and Astra2/2 exhausted remain retained. Only review-status/evidence documentation changed after runtime gates; production/test bytes are unchanged. The exact local commit/tree is recorded after commit, without predicting its identity here.

## Actual local commit closure

Actual local-commit receipt is preserved in `docs/acceptance/evidence/m3/managed-h2-group-startup-controls/1792074225504017906/predecessor-local-commit1.json`, SHA256d05f47eb1a789e07924df732958dacfed1b1710b36332142748ab485f70b6e81. It authenticates131 committed paths, protected root files unchanged and clean worktree after commit. Earlier PENDING statuses above describe pre-commit snapshots, not current state. The bounded startup controls catalog now passed FULL SPEC39/39/CODE23/23 and all fresh gates; its final documentation rebind/byte audit/local commit receipt are pending. All aggregate/recovery limitations remain.
