# Native Generation checked capture Implementation Plan1

> **For agentic workers:** Execute task-by-task under continuing authorization; parent owns delegation and repository writes. Source-only reviewers own separate /tmp reports. Use executing-plans for implementation. No additional routine approval prompt.

**Goal:** Complete one accounted native Generation runtime path from Admission through Store/public G/T receipts and Router to finite bounded cleanup, preserving legacy/core isolation.

**Architecture:** An optional gaoxy_http accounting behavior delegates managed schema/arithmetic/release to proxy. Store owns pre-invocation original ledger and rollback; requester owns compact Admission charge, checked append, exact Router outcome precedence and once-only cleanup event.

**Tech Stack:** Current Elixir1.18.5/OTP28.5.0.7 source-bound ETF, existing GenServer/Admission/native H1/H2/public managed owner APIs; no dependency or process addition.

---

Read paired `/tmp/gaoxy-native-generation-checked-capture-design1.md` for exact constructors/custody/error/deadline table. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, inspected baseline48a71a70acbe9cb46f99b82e4062c6f5f25d9667. This is a PREPARED source-only plan, not executed runtime evidence. Every checkbox below starts NOT RUN. Parent-reported worksheet24/0/format/compile are predecessor reports; require its completed independentSPEC/CODE/fresh/localcommit receipt before this plan starts repository edits. Stage arithmetic is part of runtime implementation, not a new prerequisite-only slice.

## Ownership and scope

One parent repository writer serializes dependent edits and actual test/evidence/Git. Independent Sol SPEC/CODE reviewers can run in parallel after candidate and evidence freeze, with separate source-only /tmp reports. Parent may parallelize disjoint-source test proposals and source constructor review; no second concurrent repository writer for Generation/Resources/accounting/owners. Keep inherited counters worksheet1 failedGREEN/1 test-contract repair/0 production repair, group24/root27/Astra2of2; preserve later counters, no third Astra/reset.

Planned production files:

- Create `apps/gaoxy_http/lib/gaoxy/http/generation/accounting.ex`: seven-callback optional behavior, no proxy references.
- Modify `apps/gaoxy_http/lib/gaoxy/http/generation.ex`: explicit opt-in init/config/call, checked arity4 request/Store clause, exact outcome/telemetry ownership; retain all legacy clauses.
- Modify `apps/gaoxy_http/lib/gaoxy/http/resources.ex`: additive checked acquire/release only; authentic ledger, no generic changes.
- Modify `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex`: compact numeric runtime reservation, manifest/correlation/deadline-release callbacks and runtime profile report; keep worksheet report/old totals intact.
- Modify `apps/gaoxy/lib/gaoxy/admission.ex`: additive explicit-timeout update/4 only; update/3 remains5000ms default.
- Modify `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex` and `upstream_transports.ex`: additive public release/2 absolute deadline; unchanged release/1 behavior.
- No expected Exchange runtime change: its retained_bytes already includes route_bytes. If exact scoped tests reveal a changed-path absolute update dropping route_bytes, parent makes only the necessary compatibility repair and expands fresh scoped checks/source table; do not redesign ownership.

Tests: add `apps/gaoxy/test/admission_timeout_test.exs` for explicit-timeout API regressions; retain existing Admission assertions in native_stream_test.exs and cleanup_attachment_test.exs. Add `apps/gaoxy_http/test/generation_checked_capture_test.exs`; add `apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs`; extend existing `managed_generation_accounting_test.exs`, G/T owner tests and Admission tests only where new public compatibility forms need direct regressions. Keep original worksheet/native/legacy/exclusion assertions. New runtime design/plan/acceptance and exact candidate evidence under `docs/{designs,plans,acceptance}/m3-native-generation-checked-capture*` are parent-owned implementation artifacts. Existing historical evidence stays immutable.

## Task 0: Bind predecessor and source identity

- [ ] Record pwd, branch, HEAD, status/diff/untracked, toolchain receipt and source hashes. Preserve pre-existing worksheet/codex/user files. Verify exact predecessor committed bytes and completed independentSPEC/CODE/fresh nonzero result; no claim that this source-only plan closes them.
- [ ] Read paired design and loaded OTP constructor-premises receipt `/tmp/gaoxy-native-generation-constructor-premises1.json`, immutable-source qualification vs runtime boundary distinction. Rebind actual loaded gen/gen_server/Elixir sources; PID29/ref35 are samples, not caps. Preserve constants9444956/16478862/5963776 and H2 Generation exclusion.
- [ ] Publish candidate contract and owner map before writers start. Every following command is run by parent with finite collector, joined exit, exact source identity, environment, nonzero executed count and no silent excluded required tests.

## Task 1: Red tests for compact reservation and original operand/correlation

- [ ] Extend worksheet test with independent complete runtime-profile algebra, full ledger L4=H+64*(A+S+F+5), three ledger roots, current-entry, manifest/partition scratch, complete validation-result and acquisition-control wrappers, error triples, preflight summaries, timing/scalar/config roots and full snapshot/descriptor rows. Preserve all24 predecessor tests/assertions and old totals. Test M65536/default1048576 and integer size boundaries around255/256, signed32 and BIG_EXT length changes using independently written ETF sums.
- [ ] New behavior test asserts `reservation(M,context)` returns exactly `{:ok,{:native_generation_capture_v1,M,65536,65536,B}}`; no report/map/rows is retained. Source/code review also verifies it never invokes report constructors before Admission; runtime returned shape alone is insufficient evidence. Compare B with independently summed actual complete runtime profile; no oldB fixture reuse.
- [ ] Table-driven correlation cases mutate each actual complete receipt field independently: provider, owner, epoch, operation, handles ordering/content, kind and T.holder; original authentic facts supplied separately. A structurally valid substituted receipt must fail. G has exactly7 keys, T8; reject invented holder/key on G. Existing generic5/6-key pins and kinds are tested via legacy functions unchanged.
- [ ] Keep exact Q boundary preflight cases: pin E=Q-6 fits singleton, Q-5 fails before cons;64/65 count; two individuallyQ capture operands prospective131065/128 fail before append. Do not create candidate list for production validation. Test malformed improper/forged stats input.

Initial behavior RED command, expected absent reservation/correlation/API failures, not compile/fixture errors:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_generation_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs
```

- [ ] Implement runtime numeric fixed-point sum directly with numeric expressions, no row list/report/map. Expose diagnostic runtime profile only through explicit worksheet/report path; historical worksheet/2 stays unchanged. Implement selected callbacks and behavior contract exactly as design; all result/error/status constructors must appear in revised arithmetic before using B.

Concrete compact callback shape (the named private numeric function is introduced in this task):

```elixir
def reservation(m, context) do
  with :ok <- validate_runtime_context(m, context),
       {:ok, b} <- settle_runtime_numeric(m, elem(context, 6), 0, 0) do
    {:ok, {:native_generation_capture_v1, m, 65_536, 65_536, b}}
  end
end
# settle_runtime_numeric uses only scalar sum_runtime_numeric(m,retained,b).
# If next===b return {:ok,b}; at64 iterations return finite capacity error.
# It does not call worksheet/2, rows/3, role_specs/1 or build a bounds map.
```

- [ ] Run this focused group GREEN and capture actual new B/row subtotals/counts/exits. This is an internal checkpoint; proceed to runtime integration under continuing authorization.

## Task 2: Necessary bounded public API compatibility

- [ ] Add owner tests: release/1 existing default/guard/error assertions stay; release/2 with one absolute deadline succeeds on real accepted receipt, refuses/returns finite error when owner unavailable or deadline exhausted, and cannot restart a fresh timeout. Add Admission.update/4 tests using the real gate suspended behind a controlled barrier; chosen finite timeout expires, no later stage starts, release original barrier, joined gate remains consistent. update/3 behavior unchanged.
- [ ] Implement additive APIs:

```elixir
# Admission: retain existing update/3; add finite timeout form.
def update(gate, lease, bytes, timeout) when is_integer(timeout) and timeout > 0,
  do: GenServer.call(gate, {:update, lease, bytes}, timeout)
# G/T: retain release/1 exact old semantics; add public absolute deadline form
# with matching existing pin guards and Lifecycle.call(owner,{:release,pin},deadline).
# Checked accounting.release(pin,Dc) validates provider and dispatches its public release/2.
```

- [ ] Test all synchronous checked cleanup uses shared Dc=D+1000, not64 renewed waits. Use controlled owners and an expired absolute deadline: first blocked release consumes remaining budget; later release-dispatch barriers must never fire. Join every task and restore only test-owned suspended processes in after. At deadline return unconfirmed, preserve charge and primary; async cancels are not confirmation. Test malformed deadline fails finitely without dispatch.
- [ ] Run scoped owner/Admission checks below. Derive actual descriptor timeout terms/source hashes; do not modify generic Lifecycle.

## Task 3: Checked Resources and Store custody

- [ ] Write checked Resources/Store tests with instrumented provider callback and a separate authentic original ledger. At provider entry record actual received original operation, caller, holder and complete batch in the test-owned provider. Source review verifies ledger-cons precedes invocation; black-box malformed-current-receipt failure proves even the failing operation is in rollback. Do not add a production test hook or retain debug ledger state. Trigger prior-success/current malformed-success rollback; expected cancellations reference EXACT original provider/owner/operation for EVERY started batch. Corrupt pin identities must not redirect cleanup. Unknown raw huge/deep reasons normalize without retention.
- [ ] Store direct-call wrong-holder test sends holder different from GenServer caller; assert `{:error,:invalid_resource_holder,:clean}` and zero provider messages. Retain legacy arity3 direct/public tests. Expire D while provider result waits behind barrier; release it and assert no successful snapshot publication, original cancels and finite uncertainty. Actual checked caller timeout emits later only in requester, not Store.
- [ ] Implement checked reduce with entry-before-invocation order:

```elixir
operation = make_ref()
entry = {provider, owner, operation, batch}
ledger = [entry | ledger]
# invoke protected provider using original batch/holder/:request/operation/D
# correlate complete pin against entry and original holder
# preflight_cons(pin,pins), then and only then [pin | pins]
# failure -> cancel every original ledger entry, return {:error,finite,:cleanup_unconfirmed}
```

Do not expose private numeric stats as authority, do not reuse generic rollback that reads pin identities, and do not send the ledger in snapshot error. release_checked iterates accepted pins under one Dc and reports finite status; no errors list/history/new worker.
- [ ] Add arity4/Store message handling with holder===caller and final D/live-holder check; no effect on start/options/prepare/activate/preparation baseline accounting. Success complete generation/router/pins shape stays unchanged; errors triple status is checked-only. Run focused core HTTP tests.

## Task 4: Admission-before-effects and C5 requester integration

- [ ] New `generation_checked_capture_test.exs` uses a REAL Admission lease owned by the actual Generation caller. Put Store/provider at deterministic barriers. Reject exactly one byte short of requiredB; assert no snapshot request/provider entry/Router entry and unchanged real gate charge. At exact required charge, block provider at its entry and inspect actual public Admission.status: charge includes retained+B before provider entry. A mocked Admission callback or synthetic observation is insufficient.
- [ ] Opt-in call must construct only original bounded context plus five-tuple before update. Relative update timeout=min(5000,remainingD); zero refuses before dispatch. On admitted Store success preflight actual new+existing captures then append. On append error bounded-release accepted new pins; keep finite primary and one acquisition event only for uncertainty.
- [ ] Table-driven real Generation.call C5 tests cover Router success, returned error with arbitrary original reason, raise exception struct, throw exact nested value, exit exact reason; combine each with release success/error/raise/throw/exit/shared-deadline. Observe exact original result/class/value/stack (use a stable endpoint stack marker, not newly generated stacks). Assert Router called once, each accepted release at most once, primary never replaced, no raw errors in telemetry. Raising/throwing/exiting observer also cannot replace primary or trigger a second event.
- [ ] Implement narrowly scoped Router try/catch and safe cleanup per paired design. Only requester emits bounded empty-scope event; Store/Resources do not. Success+failed release returns finite `generation_pin_release_failed` with latest exchange; failed/raised Router retains exact original outcome. No second wire response claim.
- [ ] Drive ordinary Exchange body poll, retained buffer updates, response send/trailers/finalize and error result; public gate status must retainB until normal lease teardown. Confirm async cancel sent / cleanup timeout / release success does not refund. No worker-transfer assumptions or new Exchange field.

Run focused integration group:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs
```

## Task 5: Genuine owner boundaries and native capture endpoint

- [ ] Build REAL managed T and G-H1 resources through current public prepare/activate/handles APIs (existing `upstream_transport_generation_test.exs` fixtures show live Transports, Groups, health peer and SnapshotEndpoint barrier). Acquire via checked Store, not a fabricated provider model. Capture complete G7/T8 public receipts and verify exact constructor formulas/correlation/release. Source R proof remains the conservative73862/75921 scalar-profile maxima; observed small native node/PID/ref samples do not claim those maxima.
- [ ] Genuine >Q case: create a real G-H1 near-H valid batch using public handles and bounded actual resources, with a deterministic source-derived count/payload choice yielding valid manifestETF<=H but complete returned pin singleton>Q (choose manifest in last available bytes belowH; pin overhead measured from complete source constructor with actual public PID/ref/epoch values). Keep exact complete receipt and public acquisition evidence; reject capacity BEFORE accumulator cons, cancel original Store operation, confirm no Router dispatch and uncertainty until public cleanup evidence. Do not invent maxPID, stuff fake owner fields, weaken grammar or shrink the genuine pin. Retain positive real T boundary and complete G/T result/alias arithmetic evidence; scalar maximum proof is source-derived. Test-controlled fixture extension may populate supported bounded handle metadata only where genuine public APIs actually admit it.
- [ ] Native H1: real listener at loopback, endpoint `{Generation,{store,accounting: ManagedGenerationAccounting}}`, real live G-H1/T router resources and raw TCP client. Barrier at endpoint capture proves requester/holder===native process, actual accepted pins and full charged gate status. Return actual HTTP response and release barrier; verify wire completion, owner/public release and ordinary gate teardown. At least one old/new snapshot capture preserves existing native fixture semantics. No claimed native worker transfer.
- [ ] Native downstream-H2: real prior-knowledge loopback TCP preface/SETTINGS/HPACK HEADERS, actual HTTP2 stream worker runs same checked Generation with H1/static managed target. Verify request/response/end-stream, actual G/T capture holder===that worker, Admission before public owner effects, finite deadline, and teardown. Reuse framing idioms from `http2_network_test.exs`; this is downstreamH2 only. Existing upstreamH2 Generation activation exclusion remains tested and unchanged.
- [ ] For both protocols block owner callback behind a finite barrier and verify sibling/listener remains usable where current scope requires; release/join all test-owned peers/tasks/monitors with finite deadlines. No arbitrary sleeps as proof, no private runtime state substituted for actual Admission/public capture boundary. Private test fixture inspection can corroborate, not replace public evidence.

Native focused command (all new acceptance tests in dedicated file; existing regression groups scoped):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs apps/gaoxy_http/test/http2_network_test.exs apps/gaoxy_http/test/native_proxy_seams_test.exs
```

Stage endpoint requires BOTH protocol smokes; a pure helper/model pass does not satisfy it. A genuine public-owner fixture impossibility is evidenced and diagnosed without faking the receipt or declaring PASS; all unblocked stage work continues.

## Task 6: Fresh qualification, independent review and local commit

- [ ] Run new/affected tests above plus direct public owner/API tests. No dedicated Admission test file exists in the inspected checkout; create the assigned admission_timeout_test.exs and preserve native_stream/cleanup_attachment existing regressions. Do not silently run full umbrella. Exact public API checks:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/admission_timeout_test.exs apps/gaoxy/test/native_stream_test.exs apps/gaoxy/test/cleanup_attachment_test.exs apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/external-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/http-consumer.sh
```

Both consumer scripts create isolated fresh consumers; record actual nonzero executed tests. Core-only result must prove no optional HTTP/proxy/Plug/Bandit/QUIC dependency activation. HTTP consumer proves generic seam compiles with proxy absent. Run strict compile and format ONLY explicit changed production/test files (use exact file list from candidate diff, no repository-wide formatter):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
```

- [ ] Freeze candidate source/evidence hashes and assign independent Sol SPEC and CODE. SPEC checks every design requirement including genuine>Q, raw operands, pre-effect charge, C5 exact precedence, sharedDc, legacy and H2 exclusion. CODE checks complete source role arithmetic/compact numeric-only compute, original ledger-before-effect/authority, no unchecked cons/append in checked path, no ignored release, finite error projection and once-only event. These are actual source+evidence reviews, not a request to spend third Astra recovery.
- [ ] Resolve actionable findings without weakening assertions; log cumulative failures/repair counters. Run fresh affected gates after final candidate changes. Unrelated out-of-scope failures stay visible; stop affected broadening and report them, never repair them silently. Required failed/blocked/unexecuted gate prevents runtime acceptance.
- [ ] Parent writes final stage design/plan/acceptance plus immutable source/toolchain/env/commands/counts/exits/B/role subtotals and genuine peer receipts. Classify PASS/FAIL/BLOCKED/NOT RUN distinctly. Verify all owned commands exited/terminated safely, test-owned suspension restored and no peers/helpers left alive. No touching others' processes.
- [ ] Stage ONLY owned changed files; inspect index/blob vs frozen candidate. Make local conventional commit `feat(http): account checked native generation captures`. No commit before SPEC+CODE+fresh gates pass. No push/release/deploy/production/certs/Vault/public management/artifact E2E. Finish this one stage at this endpoint; native-worker transfer and upstream-H2 Generation activation remain explicitly deferred to their separately written next bounded stage.

No routine user decision is needed. Completion verdict must state actual commit/source, executed scoped counts/exits, review/fresh gate results and residual boundaries; prepared docs or conditional arithmetic alone must never be reported as completed runtime accounting.
