# Managed H2 Group Generation Implementation Plan

> **For agentic workers:** Execute task by task using the executing-plans workflow. Root is the sole repository/evidence/Git writer and sole runtime/build operator; independently delegated specification/code reviewers own reports only. Continuing authorization selects this approach without routine approval questions.

**Goal:** Qualify one managed-H2 two-member group per old/new checked Generation snapshot on one transport owner, including selected0→1→0, authentic batch custody and dedup.

**Architecture:** Reuse canonical GroupEndpoint, checked Store capture, native one-use T handoff and independent Session G/T completion holds. No production constructor/API/cap change is expected. Browser uses two navigations/memberA; sockets prove memberB and wraparound.

**Tech stack:** Elixir1.18.5/OTP28 Nix environment, HTTP Fetch/Runtime0.21.10, Python h2 peers, native H1/H2 and Chrome/CDP.

Status: VERIFIED LOCALLY ON DISK; final document/custody review and local commit pending. Complete full-stage SPEC1→CODE1 and bounded stop-race SPEC1→CODE1 passed before fresh final gates. Three serialized batches executed239+170+475=884 test invocations over32 distinct paths, zero failures/skips/exclusions/compiler-test warnings, exit0; strict compile, complete active format/syntax and isolated consumers1/0+2/0 passed. Final browser4/4 and all8 root-viewed images passed. Historical failures remain unchanged; whole M3/composite Task5 remain incomplete. See the matching acceptance and evidence final-acceptance-facts1.json for exact source, commands and scope.

## Files and serialized ownership

Root creates `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs`, `docs/designs/m3-managed-h2-group-generation.md`, `docs/plans/m3-managed-h2-group-generation.md`, `docs/acceptance/m3-managed-h2-group-generation.md` and `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/`. Current roadmap sync is limited to `docs/plans/m3-upstream-transport.md` and `implement-plan.md` after factual gates. Source repair files are selected only by evidence; preserve lock/deps and unrelated files/prompts. Browser root contains `group-generation-browser-host1.exs`, `group-generation-browser-runner1.py`, unchanged copied `group-generation-browser-cohort1.exs` and immutable receipts. The frozen starting browser sources are `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/fixed-generation-browser-host3.exs`, `fixed-generation-browser-runner4.py`, `fixed-generation-browser-cohort2.exs` and `browser-command-collector1.py`; their hashes are in kickoff1.json. New host/runner/cohort/collector live directly under this stage evidence root and must be frozen/reviewed before use. Initial host1/runner1 and failed snapshots remain immutable; the current bounded correction uses versioned host2/runner2. The new browser command will be `python3 -B docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-collector1.py --name browser-green1 --receipt browser-command-green1 --runner group-generation-browser-runner1.py`; this original invocation completed FAIL and is retained. The corrected invocation `--name browser-green2 --receipt browser-command-green2 --runner group-generation-browser-runner2.py` passed its bounded source checkpoint and actually completed FAIL; retain its exact source snapshots and early-return classification.

### Task0: Bind predecessor and review readiness

- [x] Verify actual worktree/branch/HEAD/status and fixed local closure receipt; distinguish parent/user changes. Archive draft investigations, source hashes and inherited counters without rewriting historical evidence.
- [x] Create unique evidence root and write kickoff source/environment/command inventory, protected-file hashes and precise accepted-profile checklist. Confirm required Nix/Python h2/Chrome/node prerequisites; unavailable gate is BLOCKED_ENV, never waived.
- [x] Review source constructor/API trace against design: H8/G7/T8, checked64/H/Q, actual P/N/W/B, group reservation/control/config. Freeze full design/plan/source candidate; independent complete readiness SPEC then CODE, additive resolution/rebind until both pass.

### Task1: Genuine admission and two-member fixture

**Create:** new group Generation test file. **Reuse:** fixed test `candidate:1036`, `capture:1170`, `bound:1301`, `environment:1543`, checked listener `1601`; H1 group test `candidate:2323`, `capture:2457`, `await_closed:2488`, `bound_request:2530`; real group fixture health/control/close helpers. Include defining `managed_h2_fixed_endpoint_test.exs` in Mix.

- [x] Add holder-owned candidate coordinator: prepare A/B Ts, compile homogeneous two-member group, prepare G, call `Generation.prepare`, return actual Router/custodians; keep every G/T prep pin until complete Store baseline exists. `try/after` and failure-safe joins release only genuine holder-owned pins.
- [x] Use real endpoint wrapper forwarding GroupEndpoint.init/resources; send original Exchange after checked Store reply, wait original absolute-deadline dispatch, forward Exchange/result unchanged, then finite return barrier. Never hold Store or inject source pins.
- [x] Add direct real GroupEndpoint prepare/public/raw activation/initial routes/router cases for h2c/TLS-H2. Missing/substituted sidecar errors occur before new owner effects; snapshot unchanged. The path is reachable: no artificial RED or unconditional production edit. Diagnose actual failures and preserve assertions.
- [x] Build four peers/old+new groups, one T owner max_resources4/pins256/tokens64/payload8MiB and existing Service536,870,912 bytes (512MiB). Real HEAD per member, recovery_threshold1/jitter0/long finite freshness; await original Probe completion/normal DOWN and all health/control ledgers before capture observations.

Canonical API composition:

```elixir
{:ok, compiled} = UpstreamGroups.compile(%{id: "generation", members: members,
  health: %{path: "/health", interval: 3_600_000, stale_after: 3_600_000,
    timeout: 5_000, jitter: 0, recovery_threshold: 1}})
{:ok, group, group_preparation} = UpstreamGroups.prepare(groups, compiled, self(), deadline)
{:ok, router} = Generation.prepare(store, [%{target: {GroupEndpoint, %{group: group}}}])
# Positive no-barrier admission case. Barrier tests use the forwarding wrapper.
{:ok, generation} = Generation.activate(store, expected, router)
:ok = Resources.release(group_preparation ++ transport_preparation)
```

### Task2: Four socket cells and independent lifetimes

- [x] Cross downstream H1/H2 with upstream h2c/TLS-H2. Capture three old native requests before CAS. At both original Store provider inputs observe actual Gate precharge from independent B/actual R and native95 W; correlate exact G7 `[G]` and T8 `[A,B]`, holder native/acquirer Store. Two effects/receipts, three handles; no batch-order assumption, Session/token/forward yet.
- [x] CAS real replacement, release holder preparations, prove old G retiring/probes0/baselines absent and both T admissions closed. Fresh ordinary old pin acquisition fails while authentic sources/custodians survive.
- [x] Serial dispatch old0→1→0: release one native, await exact G selected index/token, original pending completion at G/T/Session and exact peer, then next. Derive one selected singleton T child per Session with native acquirer/source_ref; no unselected child/checkout, retry/replay or extra outer acquire. Dispatch fresh three independently0→1→0 and finish them while old completions pending.
- [x] Verify actual six cleanup reservations98,873,172, separate startup5,963,776 lifetimes, exact G config/control sum and genuine Gate/Service counters; preserve native P/N/W/B/full cohort. Measure all actual operands; never copy fixed-wrapper W.
- [x] Complete old three but hold native returns. Require original completion success, Session normal DOWN, children/G/T tokens gone, sources/G/both custodians alive. Release A0 and B1 returns: final source selected A2 still holds B. Release A2 last, then join G deletion/both custodians/physical EOF or reset.
- [x] Close actual native connections/workers/Writers; assert Gate0/cleanup0/failed nil, owner all-zero, normal custody/instance joins, rebind listener. Exact peer totals Aold3/Bold2/Anew3/Bnew2, four HEAD+six GET, forced0/live0/failedfalse and Python exit0. Failure paths must join owned actors too.

### Task3: Dedup and genuine failure coverage

- [x] Both protocols: two unique member IDs share real same-authority T. Assert two real HEADs, selected indices0/1, independent G/T original completions and Session children; H8.transports `[T]`, complete sidecar `[G,T]`, exactly G7+one authentic T8 batch, no duplicate source acquisition. Release all holder preparations, sources and real actors/ledgers; preserve exact peer totals.
- [x] Per protocol stale CAS/rejected candidate, invalid prepared route, coordinator death/abandonment: only candidate resources retire; active Router/baseline/real forwarding stay unchanged. Retain generic partial-provider rollback tests; no new multi-owner claim.
- [x] Store death after actual capture: old authentic G/T rights finish; fresh request fails finitely before selection/delegation/Fetch. Test nonempty missing G, selected T or unselected T; forged G ref/operation/epoch, T ref/holder; genuine identity mismatch. Inspect actual owner records/effects, preserve authentic Store receipts for cleanup; [] remains standalone semantics.
- [x] Hold exact original selected delegation input; cancel real actor and release barrier. Assert same operation revoked, no late checkout/Fetch or surviving child/token, finite original deadline and actual joins.
- [x] Use a separate same-owner capacity fixture with `max_request_tokens:1` and group `max_probes:1`. Complete both real HEADs serially, hold one genuine group forward with original completion pending, then send a second native request: G selects once, T global token denial occurs before Fetch. Check cancelled second G outcome/unchanged member health/no alternate checkout/Fetch; release its authentic child/source holds, then finish/join the original held forward. Label global denial precisely: selected-A saturation with B available remains open broader coverage. If added later, unchanged R32 requires32 real held A requests and original cleanup; never fake unbound requests or lower canonical profile.
- [x] One short-stop/late cleanup case: original G/T completion pending retains charged G/T/Service custody and sticky failed/expired receipt. Join late real completion/owner cleanup without rewriting earlier failure. Normal all-zero/peer-close gates remain mandatory and separate from forced fixture teardown.

### Task4: Reviewed browser adaptation and initial scoped qualification

- [x] Root copies latest fixed browser Cohort unchanged/hash-bound; reuse actual Actor/CDP/all-child/process-group/readers/adopted-child custody. Adapt host only for real two-member old/new preparation/HEADs, two authentic batches, G controls/tokens and both-member retirement.
- [x] Four rows: Chrome TLS HTTP/2 and clear HTTP/1.1 downstream, each to h2c/TLS-H2. Exactly two labeled old/new navigations select A; B receives genuine HEAD only. Socket gate supplies B/wraparound. Bind full actual initialized endpoints/native95 W+B, visible DOM/title/URL/status/protocol, console silence and eight screenshots.
- [x] Freeze complete browser fixture/collector; independent fixture SPEC then CODE before execution. Verify Python/embedded-JS syntax and exact host format. Resolve findings additively with re-review.
- [x] Execute initial scoped union/browser, retaining true source-bound exits/nonzero counts/terminal joins. Require actual request_clean/live-before-close/explicitclose, all peer/custodian/native/Actor joins, Gate0/all-zero/rebind; root views every screenshot. Failures enter diagnosis, immutable evidence/counters retained, no third Astra.

### Task5: Final full review and fresh exact gate inventory

- [x] Freeze full-stage candidate1 and complete independent full-stage SPEC1 then CODE1. Freeze candidate2 with only the deterministic native startup-test stop-order repair; bounded SPEC1 then CODE1 rebind passed. Source/test/fixture operands and lifetimes retain their reviewed constructors.
- [x] Run the complete unfiltered union in three serialized batches on candidate2:239/0,170/0,475/0, exit0. There are9+7+17=33 path entries/32 distinct paths; the whole fixture-defining fixed-endpoint file is intentionally loaded in batches1 and3. Zero skips/exclusions/compiler-test warnings. Nix dirty-tree notices are preserved.

The immutable [inventory6](../acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/final-gate-command-inventory6.json) contains authoritative exact argv arrays, collector prefixes, timeouts and fresh receipt names. Its pre-execution NOT RUN fields are historical planning status; completed receipts and final-acceptance-facts1.json record actual results. These are the seven Mix/consumer argv arrays actually executed, without filters:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_probe_test.exs apps/gaoxy_proxy/test/managed_h2_group_pin_response_test.exs apps/gaoxy_http/test/generation_endpoint_validation_test.exs apps/gaoxy_http/test/generation_resource_consistency_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/http2_worker_startup_test.exs apps/gaoxy_http/test/http2_stale_start_test.exs apps/gaoxy_proxy/test/managed_h2_group_source_test.exs apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' unbuffer mix format --check-formatted apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-host4.exs /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-cohort1.exs apps/gaoxy_http/test/http2_worker_startup_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/external-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/http-consumer.sh
```

Batch1 verifies H2 composition and fixed/group/lifecycle/native-TLS compatibility.
Batch2 preserves H1 Generation, authentic handoff/identity, rollback/sidecar and
checked algebra. Batch3 includes complete group constructors/owners/probes,
source/envelope, generic Store/deadline and native-H2 worker compatibility, plus
the whole fixed-endpoint defining test file. No absent-helper warning is waived.
A separate full startup-file diagnostic ran19/0 before these884 invocations;
core consumer1/0 and HTTP consumer2/0 invocations are separate from the scoped count.

- [x] Forced strict compile and formatcheck pass. The exact format inventory includes the new test, production http.ex, active absolute host4/cohort1 evidence paths and changed startup test. No stale host path qualifies.
- [x] The eighth exact argv array in inventory6, syntax-final1, compiles all four active Python files without executing them and extracts the actual runner4 BROWSER string for node --check. Its receipt/log bind Python input hashes, extracted JS SHA256, node exit0 and source stability; static gates have zero test count.
- [x] Run the fresh post-review browser command below:4/4 rows,8 images actually viewed, original completion/source custody, request_clean/live-before-close, explicit Chrome close, Gate0, all normal owner/native joins and listener rebind pass. All24 direct Actors exit0/nonforced with joined readers/absent groups. Separately21 adopted waits are17status0/four status10(signal10, decoded -10), none remaining. Initial browser-green4 had20 waits and is distinct.

```sh
python3 -B docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-collector3.py --name browser-final1 --receipt browser-command-final1 --runner group-generation-browser-runner4.py
```

Each final browser row binds102 loaded modules before/after:97 compiled modules
with disk BEAM hashes and5 dynamic .exs modules with source/loaded-MD5 identities.
No disk BEAM is invented for dynamic modules. All98 artifact hashes match.
The independent final-command audit verifies all nine commands,897 bound inputs
and30 adopted waits (11status0/19status10); it excludes browser/stage acceptance.
The separate browser audit and final document/custody reviews retain their own
exact inputs and scope.

### Task6: Acceptance, custody and local commit

- [x] Write acceptance with exact single-owner/two-member/dedup/browser-A-only scope, complete commands/counts/exits/source hashes, retained failures/counters and fresh post-review results. Keep multi-owner, selected-A R32/B-available saturation, trust/IP rotation/reload/full matrix/standalone/load/H3 accounting and wholeTask5/M3 open.
- [ ] Complete current roadmap sync, independent document SPEC then CODE and exact disk/index/blob custody audit. Prior nine-document review inputs remain in pre-final-docs1; all failed evidence, unrelated prompts and private-trace/key restrictions are preserved.
- [ ] Root stages only task-owned files, makes a local conventional feature commit, verifies actual commit/tree/blobs against disk/index, then records separately reviewed factual closure. No push/publication/deployment.
- [ ] After actual local closure, automatically design/plan/review and execute the next existing bounded requirement: managed-H2 same-authority trust/numeric-address rotation, fixed then group using existing compact DER/address APIs. The successor mapping is preparation only until that kickoff.

Current cumulative counters: group failedGREEN54/root128/orchestration56; stage failedGREEN9/productionRepair2/fixtureRepair11/orchestrationRepair49/invalidRED1/validRED1; Astra2/2 exhausted. No reset or third Astra recovery. Frozen earlier receipts retain their original cutoffs. Root124–126 are recovered read-only browser-report schema errors; root127 is the independent command-audit integer-count-key JSON round-trip error. Root128 is a recovered read-only optional H1 accounting display TypeError; H1 legitimately has no H2 worker-accounting object. These report-only recoveries change no runtime/source result.

Restrictions remain production data/certificates, Vault, public management,
disabled release-artifact E2E and account/quota changes; history97 dismissal is
preserved. Stop only for genuine new external permissions/product decisions or
an external blocker, continuing other unblocked work. All original failures,
UNKNOWN causes and sticky cleanup failures remain in acceptance/evidence.
