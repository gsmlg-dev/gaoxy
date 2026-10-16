# Managed H2 Group Generation Implementation Plan

> **For agentic workers:** Execute task by task using the executing-plans workflow. Root is the sole repository/evidence/Git writer and sole runtime/build operator; independently delegated specification/code reviewers own reports only. Continuing authorization selects this approach without routine approval questions.

**Goal:** Qualify one managed-H2 two-member group per old/new checked Generation snapshot on one transport owner, including selected0→1→0, authentic batch custody and dedup.

**Architecture:** Reuse canonical GroupEndpoint, checked Store capture, native one-use T handoff and independent Session G/T completion holds. No production constructor/API/cap change is expected. Browser uses two navigations/memberA; sockets prove memberB and wraparound.

**Tech stack:** Elixir1.18.5/OTP28 Nix environment, HTTP Fetch/Runtime0.21.10, Python h2 peers, native H1/H2 and Chrome/CDP.

Status: IMPLEMENTING. Readiness SPEC2→CODE1 and browser-fixture SPEC3→CODE2 passed source review. Initial scoped1 remains FAIL90/7/84 warnings/exit2. Scoped2/scoped-diagnostic1 remain custody FAIL despite91/0/no warnings. Collector2 CODE1 FAIL C1 and corrected collector3 SPEC2→CODE2/17 mocks/initial3 PASS91 are preserved. Browser-green1/green2/diagnostic1 remain FAIL; diagnostic1 localized invalid_group_source while exact rejected field and green2 initiating cause remain UNKNOWN. Repair2 uses existing bounded prepare_group_source. Version1 header-only SPEC1 FAIL C1 and version2 RED1 FAIL_INVALID_REGRESSION (missing startups KeyError) remain immutable. Corrected version3 SPEC3→CODE2 passed; actual RED2 executed93/2/ex2 with only new raw-target peer assertions failing, then exact candidate was restored and scoped-initial4 PASS93/0/zero warnings/skips/exclusions/ex0/stable/clean completed. Browser-green3 actual first-row FAIL: both old/new200 DOM/completion/request_clean and explicit Chrome close/native cohort/Gate0 pass; host fails exact group_owner terminal, hostexit1/four peers forcedTERM. Root viewed its two screenshots. Source diagnosis finds directly owned UpstreamGroups requires explicit normal stop after Gaoxy.stop; final actual group PID terminal state was not logged. Versioned host4/runner4 add only that finite normal stop and path rebind; bounded review/new four-row browser and full-stage/final gates remain pending. No historical failure is reclassified.

## Files and serialized ownership

Root creates `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs`, `docs/designs/m3-managed-h2-group-generation.md`, `docs/plans/m3-managed-h2-group-generation.md`, `docs/acceptance/m3-managed-h2-group-generation.md` and `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/`. Current roadmap sync is limited to `docs/plans/m3-upstream-transport.md` and `implement-plan.md` after factual gates. Source repair files are selected only by evidence; preserve lock/deps and unrelated files/prompts. Browser root contains `group-generation-browser-host1.exs`, `group-generation-browser-runner1.py`, unchanged copied `group-generation-browser-cohort1.exs` and immutable receipts. The frozen starting browser sources are `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/fixed-generation-browser-host3.exs`, `fixed-generation-browser-runner4.py`, `fixed-generation-browser-cohort2.exs` and `browser-command-collector1.py`; their hashes are in kickoff1.json. New host/runner/cohort/collector live directly under this stage evidence root and must be frozen/reviewed before use. Initial host1/runner1 and failed snapshots remain immutable; the current bounded correction uses versioned host2/runner2. The new browser command will be `python3 -B docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-collector1.py --name browser-green1 --receipt browser-command-green1 --runner group-generation-browser-runner1.py`; this original invocation completed FAIL and is retained. The corrected invocation `--name browser-green2 --receipt browser-command-green2 --runner group-generation-browser-runner2.py` passed its bounded source checkpoint and actually completed FAIL; retain its exact source snapshots and early-return classification.

### Task0: Bind predecessor and review readiness

- [x] Verify actual worktree/branch/HEAD/status and fixed local closure receipt; distinguish parent/user changes. Archive draft investigations, source hashes and inherited counters without rewriting historical evidence.
- [x] Create unique evidence root and write kickoff source/environment/command inventory, protected-file hashes and precise accepted-profile checklist. Confirm required Nix/Python h2/Chrome/node prerequisites; unavailable gate is BLOCKED_ENV, never waived.
- [x] Review source constructor/API trace against design: H8/G7/T8, checked64/H/Q, actual P/N/W/B, group reservation/control/config. Freeze full design/plan/source candidate; independent complete readiness SPEC then CODE, additive resolution/rebind until both pass.

### Task1: Genuine admission and two-member fixture

**Create:** new group Generation test file. **Reuse:** fixed test `candidate:1036`, `capture:1170`, `bound:1301`, `environment:1543`, checked listener `1601`; H1 group test `candidate:2323`, `capture:2457`, `await_closed:2488`, `bound_request:2530`; real group fixture health/control/close helpers. Include defining `managed_h2_fixed_endpoint_test.exs` in Mix.

- [ ] Add holder-owned candidate coordinator: prepare A/B Ts, compile homogeneous two-member group, prepare G, call `Generation.prepare`, return actual Router/custodians; keep every G/T prep pin until complete Store baseline exists. `try/after` and failure-safe joins release only genuine holder-owned pins.
- [ ] Use real endpoint wrapper forwarding GroupEndpoint.init/resources; send original Exchange after checked Store reply, wait original absolute-deadline dispatch, forward Exchange/result unchanged, then finite return barrier. Never hold Store or inject source pins.
- [ ] Add direct real GroupEndpoint prepare/public/raw activation/initial routes/router cases for h2c/TLS-H2. Missing/substituted sidecar errors occur before new owner effects; snapshot unchanged. The path is reachable: no artificial RED or unconditional production edit. Diagnose actual failures and preserve assertions.
- [ ] Build four peers/old+new groups, one T owner max_resources4/pins256/tokens64/payload8MiB and existing Service536,870,912 bytes (512MiB). Real HEAD per member, recovery_threshold1/jitter0/long finite freshness; await original Probe completion/normal DOWN and all health/control ledgers before capture observations.

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

- [ ] Cross downstream H1/H2 with upstream h2c/TLS-H2. Capture three old native requests before CAS. At both original Store provider inputs observe actual Gate precharge from independent B/actual R and native95 W; correlate exact G7 `[G]` and T8 `[A,B]`, holder native/acquirer Store. Two effects/receipts, three handles; no batch-order assumption, Session/token/forward yet.
- [ ] CAS real replacement, release holder preparations, prove old G retiring/probes0/baselines absent and both T admissions closed. Fresh ordinary old pin acquisition fails while authentic sources/custodians survive.
- [ ] Serial dispatch old0→1→0: release one native, await exact G selected index/token, original pending completion at G/T/Session and exact peer, then next. Derive one selected singleton T child per Session with native acquirer/source_ref; no unselected child/checkout, retry/replay or extra outer acquire. Dispatch fresh three independently0→1→0 and finish them while old completions pending.
- [ ] Verify actual six cleanup reservations98,873,172, separate startup5,963,776 lifetimes, exact G config/control sum and genuine Gate/Service counters; preserve native P/N/W/B/full cohort. Measure all actual operands; never copy fixed-wrapper W.
- [ ] Complete old three but hold native returns. Require original completion success, Session normal DOWN, children/G/T tokens gone, sources/G/both custodians alive. Release A0 and B1 returns: final source selected A2 still holds B. Release A2 last, then join G deletion/both custodians/physical EOF or reset.
- [ ] Close actual native connections/workers/Writers; assert Gate0/cleanup0/failed nil, owner all-zero, normal custody/instance joins, rebind listener. Exact peer totals Aold3/Bold2/Anew3/Bnew2, four HEAD+six GET, forced0/live0/failedfalse and Python exit0. Failure paths must join owned actors too.

### Task3: Dedup and genuine failure coverage

- [ ] Both protocols: two unique member IDs share real same-authority T. Assert two real HEADs, selected indices0/1, independent G/T original completions and Session children; H8.transports `[T]`, complete sidecar `[G,T]`, exactly G7+one authentic T8 batch, no duplicate source acquisition. Release all holder preparations, sources and real actors/ledgers; preserve exact peer totals.
- [ ] Per protocol stale CAS/rejected candidate, invalid prepared route, coordinator death/abandonment: only candidate resources retire; active Router/baseline/real forwarding stay unchanged. Retain generic partial-provider rollback tests; no new multi-owner claim.
- [ ] Store death after actual capture: old authentic G/T rights finish; fresh request fails finitely before selection/delegation/Fetch. Test nonempty missing G, selected T or unselected T; forged G ref/operation/epoch, T ref/holder; genuine identity mismatch. Inspect actual owner records/effects, preserve authentic Store receipts for cleanup; [] remains standalone semantics.
- [ ] Hold exact original selected delegation input; cancel real actor and release barrier. Assert same operation revoked, no late checkout/Fetch or surviving child/token, finite original deadline and actual joins.
- [ ] Use a separate same-owner capacity fixture with `max_request_tokens:1` and group `max_probes:1`. Complete both real HEADs serially, hold one genuine group forward with original completion pending, then send a second native request: G selects once, T global token denial occurs before Fetch. Check cancelled second G outcome/unchanged member health/no alternate checkout/Fetch; release its authentic child/source holds, then finish/join the original held forward. Label global denial precisely: selected-A saturation with B available remains open broader coverage. If added later, unchanged R32 requires32 real held A requests and original cleanup; never fake unbound requests or lower canonical profile.
- [ ] One short-stop/late cleanup case: original G/T completion pending retains charged G/T/Service custody and sticky failed/expired receipt. Join late real completion/owner cleanup without rewriting earlier failure. Normal all-zero/peer-close gates remain mandatory and separate from forced fixture teardown.

### Task4: Reviewed browser adaptation and initial scoped qualification

- [ ] Root copies latest fixed browser Cohort unchanged/hash-bound; reuse actual Actor/CDP/all-child/process-group/readers/adopted-child custody. Adapt host only for real two-member old/new preparation/HEADs, two authentic batches, G controls/tokens and both-member retirement.
- [ ] Four rows: Chrome TLS HTTP/2 and clear HTTP/1.1 downstream, each to h2c/TLS-H2. Exactly two labeled old/new navigations select A; B receives genuine HEAD only. Socket gate supplies B/wraparound. Bind full actual initialized endpoints/native95 W+B, visible DOM/title/URL/status/protocol, console silence and eight screenshots.
- [ ] Freeze complete browser fixture/collector; independent fixture SPEC then CODE before execution. Verify Python/embedded-JS syntax and exact host format. Resolve findings additively with re-review.
- [ ] Execute initial scoped union/browser, retaining true source-bound exits/nonzero counts/terminal joins. Require actual request_clean/live-before-close/explicitclose, all peer/custodian/native/Actor joins, Gate0/all-zero/rebind; root views every screenshot. Failures enter diagnosis, immutable evidence/counters retained, no third Astra.

### Task5: Final full review and fresh exact gate inventory

- [ ] Freeze complete source/tests/docs/browser/evidence candidate; independent full-stage SPEC then CODE. Rebind/re-review actionable repairs; reopen constructor gate for changed operands/lifetimes.
- [ ] After both pass run exact unfiltered union below once in three serialized batches; record command/environment, actual test/failure/skipped/excluded counts, warnings, source before/after, log hash, true exit and actor/process-group joins. Expected nonzero tests, zero failures/skips/exclusions/warnings; no borrowed predecessor pass.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs apps/gaoxy_proxy/test/managed_h2_group_accounting_probe_test.exs apps/gaoxy_proxy/test/managed_h2_group_pin_response_test.exs apps/gaoxy_http/test/generation_endpoint_validation_test.exs apps/gaoxy_http/test/generation_resource_consistency_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/http2_worker_startup_test.exs apps/gaoxy_http/test/http2_stale_start_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' unbuffer mix format --check-formatted apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/external-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/http-consumer.sh
```

Batch1 verifies real H2 production composition/direct fixed+group regressions/lifecycle/native TLS. Batch2 preserves H1 Generation, authentic handoff/identity, rollback/sidecar and independent checked algebra. Batch3 preserves whole32/64-bound G constructors, owner/probe/control grammars, real receipts, generic Store/sidecar/deadline rollback and native H2 worker accounting. Compile detects warnings outside loaded tests; both isolated consumers protect dependency boundaries.

- [ ] Active format inventory includes new browser host/cohort .exs and every actually changed .ex/.exs; root freezes full absolute evidence paths. Syntax gate compiles changed Python source without executing it and checks extracted embedded JS with `node --check`; bind extraction/input hashes. No stale fixture path qualifies.
- [ ] Run fresh post-review four-row browser with unique receipt/run paths and unchanged reviewed hashes/loaded identities, view all eight screenshots, repeat all real custody/zero/rebind gates. Root freezes exact new runner argv before execution; these future fixture paths are not executable gates before the adapted fixture checkpoint.

### Task6: Acceptance, custody and local commit

- [ ] Write acceptance with precise two-member/single-owner/dedup/browser-A-only claims, exact gates/counts/exits/source hashes and retained failures/counters. Keep broad capacity, multi-owner, rotation/reload/full matrix/standalone and fullTask5/M3 open.
- [ ] Sync current roadmap facts only. Independent document and exact disk/index/blob custody audit; archive prior evidence unchanged and protect unrelated prompts/private trace/keys.
- [ ] Root stages task-owned files only, local conventional commit, verifies committed tree/blob identities and clean task tree; no push/publication/deployment. Prepare next bounded existing requirement automatically after closure.

Restrictions remain production data/certificates, Vault, public management, disabled release-artifact E2E and account/quota changes; history97 dismissal is preserved. Stop only for genuine new external permissions/product decisions or external blocker, continuing other unblocked work. Cumulative group52/root107/orchestration36/stagefailed7/production2/fixture10/stageorchestration29/invalidRED1/validRED1/Astra2of2. Initial4 PASS93 qualifies current production/test source; browser-green3 FAIL and all earlier failures remain immutable. Host4/runner4 require bounded SPEC→CODE, fresh syntax and browser-green4/command-green4 four rows/eight root-viewed images. Final inventory4 names active host4/runner4/collector3 and unchanged group_source/envelope compatibility. Full-stage/final gates and stage acceptance remain incomplete.
