# Adaptive resource budget implementation

Baseline: `a6a35438c0a153cd53c87c6a55c19a70a11fb75a`, current branch `main`.
Design: [adaptive resource budget](../designs/adaptive-resource-budget.md).
Goal scope includes implementation, ordinary verification, independent review,
documentation, commit, push and coordinated release. No branch/worktree creation
or production deployment is authorized. Preserve unrelated work and immutable
historical specialist evidence. Unchecked items are outstanding, not implied
complete by a narrower passing test.

## Task routing and cumulative repair record

Current authorization: on 2026-10-30 the user extends the original quota by
24 hours. The fixed window now runs **2026-10-29 22:09:44 through 2026-10-31
10:09:44 Asia/Shanghai** (36 hours total). The original twelve-hour expiry and
model-capacity interruption remain historical evidence. During the extended
window the existing CORE, H1/H2 and H3
tasks may continue Astra recovery without a numerical failure stop. Historical
counts remain cumulative and the earlier pending requests are resolved by this
explicit grant. Keep one active Astra worker, serialize shared validation, and
complete independent review and unchanged acceptance checks before delivery.
The historical checkpoints below retain their actual status at execution time.

| Task | Initial/current worker | State | Sol repairs | Astra repairs | Gate |
| --- | --- | --- | --- | --- | --- |
| ARB-BASE | Sol/Sol | Accepted read-only audit | 0 | 0 | None |
| ARB-ARCH | Astra/Astra | Architecture checkpoint received; coordinator materialized docs | 0 | 0 | PROJECT_ARCHITECTURE |
| ARB-MEM | Sol/Astra | Accepted after recovery and independent 53/0 re-review | 2 | 1 | SOL_REPEATED_FAILURE |
| ARB-MEM-REVIEW | Sol/Sol | Specification/code accepted; fresh 53/0 | 0 | 0 | None |
| ARB-ARCH-REVIEW | Sol/Sol | Four clarified contracts accepted | 0 | 0 | None |
| ARB-OWNER-PREFLIGHT | Sol/Sol | Accepted read-only module/API preflight | 0 | 0 | None |
| ARB-OWNER | Sol/Astra | Accepted after bounded recovery 120/0 and combined 147/0 | 2 | 1 | SOL_REPEATED_FAILURE |
| ARB-CORE-PREFLIGHT | Sol/Sol | Accepted read-only transition/provenance patch map | 0 | 0 | None |
| ARB-CONFIG | Sol/Sol | Accepted specification/code review and fresh combined 147/0 | 0 | 0 | None |
| ARB-PROTOCOL-PREFLIGHT | Sol/Sol | Accepted read-only hook map; same-token stream retention selected | 0 | 0 | None |
| ARB-CORE | Sol/Astra | Production14 unchanged; compatibility16 test synchronization accepted after equal-deadline trace, original37 assertions/deadlines preserved; new exact-source CI pending | 2 | 16 | SOL_REPEATED_FAILURE |
| ARB-ENTRY | Sol/Sol | Gateway/JSON propagation accepted in combined 312/0 | 0 | 0 | None |
| ARB-H1H2 | Sol/Astra | Accepted scoped378/0 and source review; final pinned868/0 passes, prior helper16/1 retained | 2 | 16 | SOL_REPEATED_FAILURE |
| ARB-H1H2-REVIEW | Sol/Sol | Test-only repairs accepted; production review requests expired-start retirement repair | 0 | 0 | None |
| ARB-H1H2-REVIEW2 | Sol/Sol | Frozen source accepted; prior P2 resolved,25 input hashes stable; parent runtime evidence remains separately scoped | 0 | 0 | None |
| ARB-H3 | Sol/Astra | Astra12 scoped233/0 and source review accepted; final pinned868/0 integrated PASS | 2 | 12 | SOL_REPEATED_FAILURE |
| ARB-H3-REVIEW | Sol/Sol | Frozen680 inputs accepted; native P1 and deadline P2 resolved, independent review PASS | 0 | 0 | None |
| ARB-H3-PREFLIGHT | Sol/Sol | Accepted read-only map; typed connection cleanup needs coordinated CORE ownership | 0 | 0 | None |
| ARB-PHOENIX | Sol/Sol | Versioned27/0 component, clients10/0 and unified8/0 PASS; original3/1 retained | 1 | 0 | None |
| ARB-PHOENIX-REVIEW | Sol/Sol | Accepted Phoenix candidate and public guide; stale Proxy moduledoc corrected/re-reviewed | 0 | 0 | None |
| ARB-QUALIFY | Sol/Coordinator | All35 final014 gates PASS on682 frozen inputs: canonical900/0 plus package, Phoenix, clients, standalone, portable and optional QUIC | 0 | 0 | None |
| ARB-QUALIFY-DIAG | Sol/Sol | Read-only helper/startup/lifetime classification; CORE startup ordering confirmed; no repairs | 0 | 0 | None |
| ARB-RELEASE-PREFLIGHT | Sol/Sol | Accepted read-only gate map; provisional 0.14.0 requires live availability check | 0 | 0 | None |
| ARB-META-VERIFY | Sol/Sol | Accepted 36/0 isolated Python gate regressions; tested scripts and manifest unchanged | 0 | 0 | None |
| ARB-RELEASE-NOTES-DRAFT | Sol/Sol | Audit-only 0.14.0 prose prepared; promotion waits for final acceptance and live version recheck | 0 | 0 | None |
| ARB-RELEASE-VERIFIER | Sol/Sol | Parameterized audit tools reviewed; parent80/0 Python controls; actual new-release artifact/runtime verification NOT RUN | 0 | 0 | None |
| ARB-ACCEPTANCE-AUDIT | Sol/Sol | 12 DoD and 20 verification rows mapped; ordinary finite connection-churn evidence missing, H3/final gates open | 0 | 0 | None |
| ARB-CHURN | Sol/Sol | Accepted16/0 including nine connection rounds; inventory868/120, strict compile/format pass, parent owns build lane | 1 | 0 | None |
| ARB-CORE-RELEASE-SPEC | Sol/Sol | Accepted fixed original raw TCP/TLS drain contract and bounded-repair invariants | 0 | 0 | None |
| ARB-CORE-RELEASE-CODE | Sol/Sol | Frozen repair12 accepted; buffer/state/output findings resolved, terminal ownership and raw evidence verified | 0 | 0 | None |
| ARB-FINAL-ACCEPTANCE | Sol/Sol | Final014 source accepted,12DoD/20verification audited and35 gates/682 input hashes verified; ready for authorized delivery | 0 | 0 | None |
| ARB-NETWORK-FIXTURE15-REVIEW | Sol/Sol | Accepted four fixture inputs,678 unchanged inputs,35 original assertions and89 passing network gates; exact-SHA hosted rerun required | 0 | 0 | None |
| ARB-STANDALONE-RECOVERY16-REVIEW | Sol/Sol | Accepted one test-only ordering barrier,681 unchanged inputs and11 passing receipts; original hosted2/1 remains FAIL | 0 | 0 | None |
| ARB-VERSION | Sol/Sol | Accepted0.14.0 alignment; final source gates PASS and6Hex/tag/GitHubrelease live availability rechecked unused | 0 | 0 | None |
| ARB-RELEASE | Coordinator/Coordinator | Implementation4f39c9e4 and fixture15 e57fb086 pushed; both original E2E failures preserved; fixture16 accepted, new CI/publication pending | 0 | 0 | None |

ROUTE task=ARB-BASE agent=sol_worker reason=baseline-investigation
ROUTE task=ARB-ARCH agent=astra_worker reason=PROJECT_ARCHITECTURE
ROUTE task=ARB-MEM agent=sol_worker reason=fixed-interface-detection-and-policy
ROUTE task=ARB-MEM-REVIEW agent=sol_worker reason=independent-specification-and-code-review
ROUTE task=ARB-MEM agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=ARB-ARCH-REVIEW agent=sol_worker reason=independent-written-architecture-review
ROUTE task=ARB-OWNER-PREFLIGHT agent=sol_worker reason=bounded-core-interface-preflight
ROUTE task=ARB-OWNER agent=sol_worker reason=approved-standalone-shared-budget-owners
ROUTE task=ARB-CORE-PREFLIGHT agent=sol_worker reason=bounded-core-integration-investigation
ROUTE task=ARB-CONFIG agent=sol_worker reason=independent-pure-policy-provenance-and-quota-normalization
ROUTE task=ARB-PROTOCOL-PREFLIGHT agent=sol_worker reason=bounded-read-only-protocol-hook-contract
ROUTE task=ARB-OWNER agent=astra_worker reason=SOL_REPEATED_FAILURE

ROUTE task=ARB-CORE agent=sol_worker reason=production-lifecycle-and-admission-integration
ROUTE task=ARB-PHOENIX agent=sol_worker reason=listener-set-and-phoenix-policy-propagation
ROUTE task=ARB-CORE-REVIEW agent=sol_worker reason=independent-production-ownership-review
ROUTE task=ARB-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=ARB-ENTRY agent=sol_worker reason=outer-configuration-policy-propagation
ROUTE task=ARB-H1H2 agent=sol_worker reason=approved-dynamic-protocol-integration
ROUTE task=ARB-H3 agent=sol_worker reason=approved-dynamic-h3-integration
ROUTE task=ARB-H3 agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=ARB-H1H2 agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=ARB-H3-REVIEW agent=sol_worker reason=independent-h3-specification-and-code-review
ROUTE task=ARB-PHOENIX-REVIEW agent=sol_worker reason=independent-phoenix-acceptance-and-public-guide-review
ROUTE task=ARB-H1H2-REVIEW agent=sol_worker reason=independent-controlled-fixture-and-proxy-contract-review
ROUTE task=ARB-QUALIFY agent=coordinator reason=post-review-checks-and-package-prequalification
ROUTE task=ARB-QUALIFY-DIAG agent=sol_worker reason=read-only-frozen-component-failure-classification
ROUTE task=ARB-QUALIFY-DIAG agent=sol_worker reason=read-only-staged-startup-and-protocol-remainder-diagnosis
ROUTE task=ARB-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE-with-explicit-twelve-hour-additional-repair-allowance
ROUTE task=ARB-RELEASE-PREFLIGHT agent=sol_worker reason=read-only-exact-source-delivery-gate-map
ROUTE task=ARB-H1H2 agent=astra_worker reason=SOL_REPEATED_FAILURE-with-explicit-twelve-hour-extra-repair-budget
ROUTE task=ARB-H3-PREFLIGHT agent=sol_worker reason=read-only-existing-public-cleanup-composition-map
ROUTE task=ARB-META-VERIFY agent=sol_worker reason=isolated-python-gate-regressions-without-shared-beam-state
ROUTE task=ARB-RELEASE-NOTES-DRAFT agent=sol_worker reason=bounded-user-facing-release-prose-from-approved-contract
ROUTE task=ARB-H1H2-REVIEW2 agent=sol_worker reason=independent-completion-credit-and-terminal-ownership-review
ROUTE task=ARB-H3 agent=astra_worker reason=SOL_REPEATED_FAILURE-continuation-with-explicit-time-quota-and-typed-CORE-cleanup-ownership
ROUTE task=ARB-RELEASE-VERIFIER agent=sol_worker reason=bounded-audit-tool-adaptation-for-exact-source-public-artifact-verification
ROUTE task=ARB-ACCEPTANCE-AUDIT agent=sol_worker reason=independent-requirement-to-evidence-audit-without-shared-build-state
ROUTE task=ARB-H3-REVIEW agent=sol_worker reason=bounded-read-only-typed-native-cleanup-seam-review
ROUTE task=ARB-CHURN agent=sol_worker reason=missing-ordinary-finite-connection-churn-acceptance-coverage
ROUTE task=ARB-H3-REVIEW agent=sol_worker reason=final-frozen-native-lifetime-and-bounded-progress-review
ROUTE task=ARB-CHURN agent=sol_worker reason=reviewed-test-installation-unit-promotion-and-focused-validation
ROUTE task=ARB-QUALIFY agent=coordinator reason=fresh-integrated-canonical-and-release-source-qualification
ROUTE task=ARB-FINAL-ACCEPTANCE agent=sol_worker reason=independent-final-requirement-and-integration-review
ROUTE task=ARB-VERSION agent=sol_worker reason=coordinated-release-version-and-user-documentation
ROUTE task=ARB-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE-continuation-Astra7-with-explicit-time-quota-and-source-built-release-smoke-failure
ROUTE task=ARB-CORE-RELEASE-SPEC agent=sol_worker reason=independent-read-only-raw-stream-drain-contract-review
ROUTE task=ARB-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE-continuation-repair12-under-explicit-plus24-hour-time-quota
ROUTE task=ARB-CORE-RELEASE-CODE agent=sol_worker reason=independent-read-only-backing-and-compatibility-review-after-time-extension
ROUTE task=ARB-CORE agent=astra_worker reason=existing-native-QUIC-compatibility-failure-after-extended-window-qualification-repair13
ROUTE task=ARB-CORE agent=astra_worker reason=existing-raw-QUIC-listener-close-ordering-after-byte-cap-recovery-repair14

Architecture admission is the explicitly requested system ownership redesign;
it is not a Sol failure/recovery escalation. Other tasks default to Sol. Keep
counters across worker reuse/handoffs. At most two child tasks may be active;
serialize shared manifest/build/Git ownership. Completed implementation requires
independent review and fresh integrated verification before acceptance.

## Phase 0: baseline and design

- [x] Read objective, current instructions, current branch/HEAD and existing diff.
- [x] Audit Config/Service/Instance, Admission/Accounting, ListenerSet, Exchange,
  H2 Limits/Connection/WorkerAccounting and H3 ownership/preflight paths.
- [x] Record static reservations and explicit legacy option semantics in design.
- [x] Fresh baseline: unit 265, component 181, protocol 137; 583 executed with
  zero failures/exclusions/skips. Elixir 1.18.5, OTP 28/ERTS 16.4.0.5,
  Python 3.13.15, Linux, `ELIXIR_ERL_OPTIONS='+S 2:2'`.
- [x] Check `origin/main` matches baseline and latest stable release is v0.13.1.
- [x] Materialize the requested design and this implementation plan.
- [x] Independent review of the written architecture and executable contracts.
  Initial review required persisted policies, deadline/dedup semantics,
  overlapping quota membership and executable safety-sampling rules; these are
  now specified in the design and accepted by the independent reviewer.

Baseline receipts/logs/hashes:
`docs/acceptance/evidence/adaptive-resource-budget/baseline/`.

## Phase 1: detection and shared ownership

### ARB-MEM: pure detection and calculations

Files: core `resource_budget/system_memory.ex`, `policy.ex`, native probe helper,
core OTP application declaration and focused tests/manifest entries.

- [x] Implement injected physical/cgroup/native detection and pure limits/state/
  projected admission calculations.
- [x] Capture initial missing-module RED 37/37, GREEN 37/0, namespace RED 39/2,
  GREEN 39/0; preserve initial test setup compile failure separately.
- [x] Independent review identifies v1 hidden hierarchy limit P1 and native
  subprocess lifetime P2; pure policy passes its specification review.
- [x] Repair v1 using the authoritative kernel hierarchical metric; validate
  missing/malformed/overflow/unlimited values and non-enforcing ancestors.
- [x] Replace unmanaged native command lifetime with supervised OTP memory API
  and bounded monitored probe ownership; test timeout/caller cancellation.
- [x] Re-review required fixes, fresh exact test counts, inventory, formatting
  and strict compile. Actual macOS/Windows execution remains separately reported.

Working evidence: `.audit/adaptive-resource-budget/memory/`; repair failures are
retained under `repair1/`. Initial repair validation exposed stale application
metadata and then an actual quoted-port-name test fixture mismatch. The second
repair's test-filter expression failed compilation, with no completed test
summary. Both unsuccessful Sol rounds are retained; bounded Astra recovery must
fix the compile error, preserve the reuse assertion and verify caller-crash
cleanup. Sol writes stopped before the handoff; no counter is reset.
The first Astra recovery then reproduced caller-death leakage, added a monitored
probe owner and two regressions, and passed 53 tests (35 detection, 9 policy,
9 native ownership), focused format/strict compile/inventory/whitespace checks.
Its receipt is `.audit/adaptive-resource-budget/memory/astra-recovery/receipt.json`.
Independent Sol re-review then accepted specification/code and reran 53/0,
format/strict compile/inventory checks. All eight slice source hashes match
before and after both receipts. Its evidence is
`.audit/adaptive-resource-budget/memory-final-review/receipt.json`.
The integrated foundation qualification then passed inventory, full formatter,
strict compile, **636 ordinary tests**, **12 package-staging tests**, and **7
clean package-consumer tests** plus manual/production/release isolation checks.
All commands exited 0 and all 626 input fingerprints remained unchanged.
Its receipt and byte-preserving logs are archived under
`../acceptance/evidence/adaptive-resource-budget/foundation/`.
Shared ownership and runtime protocol integration remain outstanding.
The qualified foundation is committed locally as
`bf2b2865944d85c18917d00854a5c503ce3b443d`; all 626 inputs were then compared
with both that commit and the worktree. This commit has not been pushed or
released. ARB-OWNER starts from that commit without changing the accepted MEM
files or wiring production Admission yet.

### ARB-CORE: state owners, configuration, common admission

Files: new ResourceBudget authority/ledger/sampler/public facade, Application,
Config, Instance, Service, Admission/Accounting, BackendOptions and core tests.
Do not concurrently edit memory files, protocol files or the canonical manifest.
Implement the independent authority/ledger/sampler facade as ARB-OWNER first,
then integrate its fixed interface into existing core as ARB-CORE. Both are new
implementation tasks with their own zeroed initial repair counters; this does
not resume or downgrade the accepted ARB-MEM recovery.

ARB-OWNER initially held the build/test and manifest lane while ARB-CONFIG
prepared disjoint pure configuration/constructor/activation tests. Its first
compile exposed a syntax error and unused alias, executing zero tests; preserve
that evidence and complete diagnosis/repair round 1 before reassignment. OWNER
may add validated controller locations to existing SystemMemory metadata for
safety sampling, without changing detection semantics or duplicating its
resolver. This additive integration feature requires the accepted 53 memory
regressions and leaves the completed MEM task's Sol 2/Astra 1 counters intact.
Its first completed Sol repair passed **110 tests** (42 owner, 15 safety, 53
memory regressions), formatting, strict compile, inventory and whitespace checks.
The candidate source hashes were independently matched and its receipts/raw
logs archived under `../acceptance/evidence/adaptive-resource-budget/owner-candidate/`.
This is passing candidate evidence, not final OWNER acceptance. Coordinator
review identified category-cap replacement, registration commit-deadline and
explicit refresh coalescing defects, all confirmed by read-only follow-up.
OWNER now holds the exclusive build/test/manifest lane for its second bounded
Sol repair; preserve the first receipt and keep accepted MEM counters unchanged.
That second round executed **120 tests with one failure**: all three product
repairs and 119 other cases passed, but the new safety-only refresh regression
used `receive_response(request, 0)` to probe two requests, abandoning both OTP
request aliases before the later reply assertions. The installed OTP source
confirms that `wait_response/2` preserves such pending requests. Sol stopped
writes and all commands after this failure; strict compile and inventory remain
NOT RUN for that round. Evidence stays under
`.audit/adaptive-resource-budget/owner/repair2/`. This is the second unsuccessful
Sol repair/acceptance round (the first candidate's review found three defects),
so the recorded `SOL_REPEATED_FAILURE` gate admits one bounded Astra recovery.
The required correction must preserve every positive reply/capacity assertion
and rerun all 120 cases plus remaining checks; no third Sol repair is authorized.
The first Astra recovery changed only the two zero-time observations to
`wait_response/2`, retaining the subsequent positive assertions. It passed all
120 cases, owned formatting, strict compile, inventory and whitespace checks.
Coordinator review accepted the narrowly scoped correction and the three
underlying product repairs. A fresh OWNER/MEM/CONFIG run then executed **147
tests with zero failures/exclusions/skips**. Recovery and combined receipts are
archived under `../acceptance/evidence/adaptive-resource-budget/owner-final/`.
This accepts the standalone OWNER and pure CONFIG checkpoint; production CORE
and protocol integration remain outstanding. Cumulative OWNER counters are
Sol 2/Astra 1 and MEM remains Sol 2/Astra 1.
CONFIG's initial
27-case RED executed 27/25 failures, followed by GREEN 27/0. Existing compatibility
checks passed **58 unit, 37 component and 12 H3 protocol tests**, with strict
compile, owned formatting, inventory and whitespace checks. An initial H3
12/4 failed invocation incorrectly resolved the virtualenv interpreter symlink;
the corrected invocation passed 12/0. Both remain archived under
`../acceptance/evidence/adaptive-resource-budget/config/`. Coordinator independent
specification/code review found no additional actionable CONFIG changes; all 11
source and six raw-log hashes match its receipt. A fresh combined run remains
required after OWNER repair before accepting this integration checkpoint.
That required combined verification has now passed 147/0 as recorded above.

The CORE preflight identified all byte/ownership mutations, bootstrap terminal
pairs and Service guardian receipt paths. Preserve the telemetry scope identity
separately from the actual Instance PID/budget reference. Explicit legacy
`max_active` counts ordinary leases, including writers/workers but excluding
separate cleanup records; explicit legacy `max_bytes` counts transport/cleanup
bytes and excludes existing WebSocket retention. Send start/finish only changes
metadata because callers already account its bytes. Preserve public queued
`Admission.update/4` late-execution compatibility; internal budget operations
use their own absolute deadlines. Backend/QUIC numeric safety controls stay
finite and independent from detected host capacity.

CONFIG's fixed integration contract is `service.budget_policy` and
`plan.resource_budget`, plus pure `Config.connection_capacity/1,2` and
`Config.lease_safety_limit/0`. Protocol/backend consumers retain numeric
`limits.max_bytes`; `limits.protocol_max_bytes` only carries an omitted-cap
provider profile through pure planning. A separate finite acceptor ceiling of
64 preserves fanout safety independently from the connection quota.

OWNER's lifecycle interface must cover registration drain/retirement even for
an empty instance or service failing before gate registration. Authenticated
bounded allocation pages let a live parent recover canonical tokens/revisions
after gate loss. Resource-owner DOWN alone remains insufficient terminal proof.
Default process names are scoped to the local BEAM node, so connected nodes do
not accidentally share one globally named default authority.

- [x] Implement supervised canonical ledger continuity, authority generations,
  per-instance scopes and aggregate VM coordination; fail closed after ledger
  loss and reconstruct after authority restart without forgetting live usage.
- [x] Add pure policy normalization and omission provenance. Preserve explicit
  legacy max_bytes/max_active semantics; add distinct connection/request/stream
  quotas and instance soft/hard configuration.
- [x] Integrate atomic acquire/resize/transfer/release into all Admission paths,
  including send, cleanup, spawn activation/cancellation and terminal pairs.
- [x] Preserve resource ownership on ambiguous timeout and idempotent retry;
  do not allocate after unconfirmed reservation.
- [x] Add accurate request-end/upgrade transitions and resource kind counters.
- [x] Separate finite backend/QUIC transport safety ceilings from memory policy.
- [x] Add capacity refresh, OOM/process safety sampling, rate-limited warning
  logs, telemetry and public `Gaoxy.resource_budget(instance)` inspection.
- [x] Controlled tests prove exact thresholds, projected admission under race,
  multi-instance sharing, explicit policies, release/recovery, owner failures,
  authority restart, ledger fencing, refresh shrink and stable capacity despite
  unrelated free-memory changes. No unit listeners or full runtime startup.
- [x] Independent specification/code review, required repairs and fresh checks.

## Phases 2–3: dynamic protocol accounting and overload

CORE recovery passed **241 tests with zero failures, exclusions or skips**.
Parent review accepted matching rejection reconciliation, deadline-bounded cleanup
pagination and independent stream-buffer terminal proofs. All 26 source/protected
hash entries and recorded logs matched; the manifest was subsequently updated for
15 new Gateway/JSON unit cases. A fresh combined run then passed **312/0**:
CORE 241, configuration 45, Phoenix pure 11 and outer compatibility 15. Strict
compile, scoped formatting, inventory and source whitespace checks passed. All
29 final source hashes and command logs matched the combined receipt. Evidence
is archived under `../acceptance/evidence/adaptive-resource-budget/core-final/`
and `entry/`; earlier failing CORE candidates remain in `core-candidate/`.

`finish_stream_resources/5` authenticates the live parent and stable worker
lease. Its proof, worker DOWN/EXIT and stream termination are separate; all six
event orders converge in controlled tests. Protocol integration must supply
the real buffer/output terminal boundary. Phoenix's two network cases remain
NOT RUN until H1 supplies connection membership metadata. H1/H2 owns the one
build lane while H3 prepares disjoint source changes. No protocol acceptance or
publication is inferred from the 312-case checkpoint.

Subsequent H1/H2 protocol integration reproduced seven intended missing-feature
regressions (three H1, four H2). Those are agreed TDD RED cases, not unexpected
repair failures. Both new files enter the protocol suite; the existing ordinary
two-H2-connection case is promoted from `existing_not_scheduled`. Historical
capacity/high-water specialist assertions remain preserved and unscheduled.

Integration also exposed a CORE cancellation gap: after a cancelled or
unobserved async spawn reply, the caller knows the spawn token but may never
learn the private worker lease. Stream membership termination alone correctly
retains output bytes, making the existing lease-addressed proof unreachable.
This remains the same CORE task, with Sol 2/Astra 1 inherited; final bounded
Astra recovery 2 must add authenticated token-addressed resource proof with a
bounded live-lease index, preserve real worker/guardian terminal requirements,
and verify H2/H3 cancellation orderings. H1/H2 production source is initially
frozen for its RED capture; H3 stops without edits. No third Astra round is
authorized. The prior 241/0 and 312/0 receipts retain their historical status.

Final CORE recovery 2 passed **249/0**, including all 40 CORE cases, strict
compile, scoped formatting, inventory and whitespace. Parent review accepted
`finish_spawn_resources/5`, bounded live-token resolution and cancellation retry
receipts; all 26 source/context/log hashes matched. No Budget, Reconciler or
Ledger changes were needed. CORE's Sol 2/Astra 2 repair budget is exhausted
successfully; protocol integration cannot rename or continue a CORE repair.
H1/H2 receives the build lane, with a fresh CORE 40-case run after parent review.
H3 resumes disjoint source work and coordinates compile-ready freezes. Evidence
is retained under `../acceptance/evidence/adaptive-resource-budget/core-final/recovery2/`.

The fresh post-review CORE run executed **40/0** before the HTTP test host
failed to compile its Phoenix Endpoint module: `gaoxy_http` intentionally does
not depend on Phoenix. The one native ListenerSet case remains in the app and
the actual two-Endpoint case now lives in `examples/phoenix_native`, preserving
all resource counters, shared-pool and zero-cleanup assertions. This is Phoenix
repair 1; no package dependency or lockfile change was needed. Both initially
executed and failed because H1 used invalid PID membership identifiers.

H1 repair 1 replaced PID membership with references; validation then found that
the listener startup token was shared across connections and the overload
Exchange omitted its HTTP limits (4 tests, 3 failures). Final Sol repair 2
creates one stable reference per accepted connection and supplies error-response
limits. It passed the three new H1 protocol cases and native ListenerSet case
**4/0**, followed by the real Phoenix example **1/0**. These focused results do
not accept the remaining H2 implementation or final integrated source. The H1H2
Sol repair counter remains 2; there is no third Sol repair allowance.

The first H1 repair validation also encountered partial H3 source with an invalid
default-argument escape and executed no tests. H3 owns that compile failure and
its targeted repair 1; all raw logs remain under `.audit/adaptive-resource-budget/`.
H3 now owns the serialized build lane while H2 prepares its initial coherent
implementation off-tree. These drafts are task-local files, not Git worktrees.
H3's actual peer, native byte metrics and final checks remain outstanding.

H3 repair 1 passed strict compilation, but focused validation executed 48 tests
with three failures; its new network case then failed on a missing control-stream
map entry. Diagnoses identified a zero-byte controlled terminal fixture, newly
linked worker cancellation escaping its owner, prematurely cleared ingress and
an absent-key control-stream drop. Repair 2 preserved the existing assertions,
gave the fixture positive retained credit, trapped worker exits, retained ingress
until its real terminal event and guarded absent control keys. Its fresh combined
validation executed **50 tests with one failure**. Both actual H3 protocol cases
passed concurrency/quota rejection, live siblings, worker crash, service drain,
zero accounting/cleanup and UDP rebind. The unchanged reply-CAS regression still
requires immediate `Operations` row removal on cancellation; canonical resource
ownership and retry receipts must independently retain their real lifetimes.

Sol stopped all H3 implementation writes and commands with cumulative Sol 2 /
Astra 0. `SOL_REPEATED_FAILURE` admits one bounded Astra recovery for that same
task; the direct implementation's initial syntax failure does not add a repair
round. Source, raw logs and assertions are preserved. No CORE changes are
authorized, and CORE's successfully exhausted Sol 2 / Astra 2 budget remains
unchanged. H1H2 owns the next coherent H2 apply/build lane; the recovery must
coordinate its compile-ready freeze and serialize validation.

H2's coherent initial implementation then passed strict compilation and **17/0**:
the three H1 cases, five new H2 cases, promoted two-TLS-connection case and eight
independently constructed accounting regressions. It reduces the fixed connection
allowance, measures retained state, prepays actual HPACK decoding and returns the
temporary decode credit, and preserves separate startup/cancellation/output
terminal bookkeeping. This passing candidate is not final acceptance.

The next broader active HTTP compatibility run executed **337 tests with 19
failures** (exit 2); no retained specialist paths were included. It found missing
new fields in controlled fixtures, old scalar-update message expectations,
retained/temporary metric mismatches and shutdown failures. The six poll-boundary
cases configure parser limits, not explicit `max_bytes`; they do not establish
an explicit-cap defect. All raw
assertions and failed evidence remain intact under
`.audit/adaptive-resource-budget/h1-h2/`. The same H1H2 task has already consumed
Sol repair rounds 1 and 2, so Sol stopped all writes and commands. Its bounded
Astra recovery is queued after H3; only one Astra recovery may be active. A
recovery must preserve explicit-cap and positive high-water/cleanup assertions,
diagnose the lifecycle failures, and rerun the full affected checks. Passing
17/0 does not supersede failing 337/19.

### Frozen H3 review and H1/H2 recovery handoff

H3's final frozen receipt is
`.audit/adaptive-resource-budget/h3/recovery1/receipt.json`, SHA256
`c0484ece93775b413ce294a8201e9e0cc065f4009a02b5d4345f8aa6ea732580`.
Independent review verified nine source, five context and thirteen log hashes.
The combined 96/0 run, compile, formatting, inventory and source whitespace
checks passed. One P1 remains: callback-worker DOWN/EXIT can refund the QUIC
connection's native-byte charge and connection membership before its separate
engine terminates. Exact public `QUIC.info(handle) == {:error, :closed}` can
prove terminal engine death, but the current ownership path does not retain
the charge until that proof. This is a local ownership gap, not a confirmed
upstream missing API. H3 and CORE remain at Sol 2/Astra 2; an explicit request
for two additional bounded recovery rounds is pending and is not approval.
No further H3/CORE implementation writes are authorized while pending.

H3 implementer and reviewer confirmed all commands terminal and writes stopped.
H1/H2's `.audit/adaptive-resource-budget/h1-h2/handoff.json` preserves fourteen
source hashes, twelve evidence hashes, the task diff and the 337/19 failures.
The parent verified those hashes before handoff. `SOL_REPEATED_FAILURE` admits
bounded Astra recovery with inherited Sol 2/Astra 0: repair the controlled
fixtures/traces, preserve exact retained/high-water assertions, and diagnose
the three actual shutdown wire regressions. Allowed writes remain H1/H2 and
their directly affected tests; CORE and H3 are frozen. Shared build validation
is serialized. No counter reset or third Sol repair is authorized.

Read-only runtime diagnosis then reproduced `Admission.update_until` returning
`{:error, :draining}` immediately before the infinite-stream success terminator
and both active-upload HTTP 500 responses. The selected stream case failed
(twelve other cases excluded); the full upload file executed 4/2. These are
diagnostic failures, not passing required gates. Existing scalar updates leave
temporary credit intact while retained buffers grow. Correct use of prepaid
completion credit needs truthful, reusable retained/temporary repartition;
Ledger's current growth and safety-debit semantics do not support that reuse
during drain. Merely removing the temporary-growth check is not an established
fix because the pressure-sample baseline must conserve the same credits.
CORE remains frozen, with the new compatibility evidence added to the pending
extra-round request. No inaccurate protocol accounting workaround is accepted.

H1/H2 Astra round 1 corrected the proxy trace/dead-gate contracts but exposed an
implicit 1 MiB cap in the controlled H2 idle fixture (27 cases / 6 failures).
Round 2 supplied the fixture's exact finite connection-reservation-derived cap;
the two test files then passed **27/0**. Recovery changed no production source.
Its Sol 2/Astra 2 budget is now exhausted; six Poll accounting assertions and
three shutdown regressions still depend on the frozen CORE completion-credit
repair. Independent narrow test review accepted the two files and verified all
sixteen source, five protected and twenty-three evidence hashes. The original
fourteen source hashes remain unchanged. The original broader compatibility
command then confirmed **337/9**, with exactly those nine remaining failures.
Parent post-review checks freshly passed the two controlled files **27/0**,
strict compile and owned formatting without source mutations. This passing
subset does not accept H1/H2 or permit another repair round. Frozen receipts
and raw logs are archived under `../acceptance/evidence/adaptive-resource-budget/h1h2-blocked/`.

The additional independent production trace found one H2 P2: when Admission
definitively rejects an expired startup before reserving or creating a worker,
no spawn token enters its live index. H2 nevertheless retains a spawn-addressed
retirement record. Its resource proof receives `:stale_generation`, while the
definitive-rejection predicate omits this pre-reserve deadline outcome. The row
persists, consumes a per-connection stream slot and retries every 10 ms until
connection closure. This finding is source-confirmed, not runtime-reproduced.
A regression must verify terminal retirement and subsequent service on the same
connection. A repair must distinguish definite pre-reserve rejection from any
ambiguous/later deadline outcome; timeout alone is never absence proof. H1/H2
implementation remains frozen at Sol 2/Astra 2 pending extra authorization.

Review also quantified the default H2 temporary connection envelope as
13,516,840 bytes (`4 * 65,536 + 8 * (100 * 16,384 + 18,437)`), down from
30,359,591 after removing the blanket 16,842,751-byte decoder allowance.
Runtime retained state is measured separately, idle decode credit is zero,
and the writer retains a separate 66,560-byte obligation. The remaining
envelope is fixed across TCP/TLS and supported SSL active-count profiles.
The review did not prove that eight maximum TLS100 delivery/copy envelopes are
necessary for every such profile. The controlled idle fixture only funds the
same arithmetic; it is not proof of real receive obligations. Record this as
an open requirement-to-evidence question for bounded H1/H2 recovery, preserving
decoder/read safety and existing positive byte/high-water assertions.

The final consolidated authorization request supersedes the two earlier pending
requests. It asks for at most two additional Astra repair/validation rounds
**per affected task** (CORE, H1/H2 and H3), including their necessary regressions
and independent review. Each currently retains Sol 2/Astra 2; no counters reset.
The request is pending, not authorization. All affected implementation writes
and build/test commands are stopped. The accepted Phoenix/test-only/doc scopes,
post-review 27/0 and 2/0, package staging 12/0 and built-consumer 7/0 plus
manual/production/release-isolation results are archived. Final full-suite,
mixed-protocol, versioning, push and release gates remain outstanding.

The frozen-source ordinary qualification subsequently covered every canonical
active file without modifying implementation. Unit passed **377/0**. Component
stopped at **224/3**; its unattempted suffix executed **66/5**. Protocol stopped
at **51/6**; its unattempted suffix executed **98/2**. Exact combined file
coverage is **118 files, 816 cases / 16 failures**, with zero exclusions/skips,
all commands terminal and all 679 source hashes unchanged. Suffix execution is
supplemental coverage; both original failed gates remain failed and final
`check-repairs.py all` still requires a fresh passing run after authorized repair.

Seven failures beyond the historical broader-HTTP nine are now observed:
helper finalization 16/3, staged activation 11/2, H3 WebSocket 2/1 and H2 stream
lifetime 2/1. Each file is unchanged from baseline, whose exact commands passed
16/0, 11/0, 2/0 and 2/0 respectively. Independent read-only diagnosis traces
staged activation to CORE registration after instance drain: preparation
returns too late for gate registration, preventing dispatcher startup and
bypassing activation's later cancellation check. This is separate from prepaid
completion-credit accounting. Preserve rollback, participant ordering, port
reuse, cancellation-result and drain-guard invariants during recovery. The
remaining helper/protocol branches require the recorded observations; do not
infer a common cause merely from an early close. Evidence and exact commands:
`../acceptance/evidence/adaptive-resource-budget/frozen-qualification/`.
These regressions stay with the existing CORE/H1H2/H3 tasks and do not reset
their exhausted Sol 2/Astra 2 counters or authorize implementation. No further
commit, version bump, push or release has occurred.

### ARB-PROTOCOL

Files: H1 Connection/Exchange; H2 Limits/Connection/WorkerAccounting/Writer;
H3 Options/Connection/Stream/QUICBridge; providers and directly affected tests.
Coordinate any core interface change with its sole owner before editing.

- [x] Reproduce ordinary concurrent default-budget regressions before repair.
- [x] H1 connection/request/body/send accounting grows and returns ownership;
  keep-alive ends request counts and retains only real carry state.
- [x] H1 safe overload returns valid bounded 503; unsafe partial framing closes
  without leaks or deadline changes.
- [x] H2 measured idle/retained state replaces the static 30 MB allowance;
  temporary HPACK peak is acquired before decode and released at its real
  lifetime. Preserve decoder/table/block/flow/frame bounds and compression state.
- [x] H2 stream, worker and writer ownership remain distinct and cancellation/
  startup retains existing terminal invariants. Ordinary worker overload refuses
  the affected stream while existing streams continue.
- [x] H3 separates QUIC, stream, transport-buffer and HTTP request resources;
  preserve pending operation cleanup, QPACK policy and finite transport ceilings.
- [x] H3 resource refusal is request/stream-local with 0x107 where safe;
  transport connection refusal releases handles and workers.
- [x] Independent connections, overlapping streams, concurrent uploads, SSE,
  response streaming, WebSocket upgrade, churn and cleanup have actual network
  evidence. Classify new tests and retain all historical specialist dispositions.
- [x] Independent review and fresh focused/integrated checks.

## Phase 4: Phoenix and ListenerSet

### ARB-PHOENIX

The promoted default-concurrency app regression uses a native Endpoint. A
separate actual Phoenix Endpoint regression must exercise adaptive defaults,
two independent TLS H2 connections and overlapping streams, public resource
counts, continued request service and confirmed zero cleanup. The existing
example's explicit-policy mixed HTTP/HTTPS case does not supply that evidence.
This remains ARB-PHOENIX with Sol 1/Astra 0; its disjoint example test source
may be prepared while H1/H2 recovers, but shared validation stays serialized.

The added actual Phoenix regression passed **2/0**, and the combined body,
SSE/lifetime, LiveView, WebSocket compatibility and configured-limit checks
passed **18/0**. Independent review accepted source/receipt/lockfile, six logs
and ninety-three context hashes. Parent then freshly reran the focused two
cases after review, passing **2/0** with no source mutations. This is scoped
acceptance; final mixed-H3 and integrated publication qualification remain open.
Evidence: `../acceptance/evidence/adaptive-resource-budget/phoenix-h2/`.

The additional adaptive-default mixed HTTP H1 / TLS H2 / QUIC H3 case first
executed3/1, with the H3 peer closing before SETTINGS; no cause was established.
Bounded public failure diagnostics preserve all original assertions and waits.
After installation/formatting, the parent freshly passed focused3/0 and combined
budget/body/stream/LiveView/WebSocket19/0 with stable source. Both the earlier
failure and new passing receipts remain recorded under
`../acceptance/evidence/adaptive-resource-budget/h1h2-time-quota/astra16/`.
Final integrated and publication qualification remain separate.

- [x] ListenerSet and Phoenix options carry shared instance policy through pure
  planning, preparation, deferred activation and inspection.
- [x] Remove default-masking hard-coded H2 budget overrides from Phoenix example;
  document intentional explicit configuration and migration semantics.
- [x] Validate mixed HTTP/HTTPS/H3 within one ListenerSet and multiple Endpoints/
  ListenerSets sharing the VM pool without multiplying capacity.
- [x] Exercise Phoenix LiveView WebSocket connections, ordinary requests, SSE,
  streaming responses and uploads with independent clients/peers.
- [x] Update README, public resource-budget/telemetry docs and examples; review.

## Phase 5: requirement-to-evidence audit

Every row needs current passing evidence or an explicit unresolved disposition;
unavailable native/load coverage must not be called passing.

| Required behavior | Evidence to obtain |
| --- | --- |
| Linux/macOS/Windows physical memory detection | Deterministic platform tests; real platform execution separately identified |
| Cgroup v1/v2, nested/hidden limits and malformed data | Injected exact-limit/permission/overflow tests; live Linux snapshot |
| 256 MiB fallback and 50% default | Pure exact numeric assertions and runtime inspection |
| 100% normal, 100–200% admit, >200% reject | Exact boundary and projected concurrent admission tests |
| Release and automatic recovery | Public snapshot plus release/refresh/re-admission tests |
| Independent H1 connections and keep-alive | Real network concurrent clients and zero cleanup counters |
| Independent H2 connections | Multiple overlapping normal Phoenix requests, not one connection |
| Multiple streams on one H2 connection | Synchronized overlapping peer streams and local overload controls |
| H3 request concurrency | Qualified independent QUIC/H3 peer with positive executed count |
| Phoenix LiveView/WS | Native Phoenix fixture, actual handshake/messages and release |
| SSE and streaming responses | Later chunks/notifications, completion and connection reuse |
| Concurrent request bodies | Overlapping uploads with bounded accounting and cleanup |
| Connection churn | Finite ordinary churn, observed terminal ownership and reuse |
| Multiple instances/ListenerSets | Aggregate shared usage and explicit instance/service limits |
| Explicit option compatibility | Legacy hard/transport/lease controls and documented new names |
| Crashes/cancellation/drain | Deterministic barriers, terminal pairs/guardians and fresh recovery |
| Warning/rejection observability | Telemetry state/reasons/counters and monotonic rate-limit checks |
| Strict protocol/OOM safety | Decoder/transport/single-allocation/process/pressure controls remain effective |
| Package and release consistency | Exact-source consumers, synchronized manifests and public artifact read-back |

Required commands include focused `scripts/check-tests.py`, inventory,
`mix format --check-formatted`, `mix compile --warnings-as-errors`, and final
`python3 scripts/check-repairs.py all` with exact nonzero counts. Packaging uses
`scripts/test-stage-hex-packages.py`, `scripts/test-consumers.py` and existing
source-consumer/standalone/Phoenix peer gates. Serialize shared build state.

## Phase 6: independent review and release

- [x] Independent architecture/specification/code review completed; actionable
  findings resolved and final integrated source freshly qualified.
- [x] All seven own version manifests and six staged public Hex distributions
  target0.14.0; current installation/release docs are aligned and historical
  acceptance evidence is preserved. Live six-Hex/tag/GitHub-release checks
  confirm the version unused before selecting the publication source.
- [x] Inspect and commit implementation conventionally on current branch:
  `4f39c9e49f6e7c2147bfaa3a8ca4ae7290506d28`.
- [x] Push implementation and confirm remote SHA. Its static/unit/package/
  portable workflows pass; E2E isolated-network fails with other E2E jobs green.
- [x] Diagnose and independently review fixture-only CORE15 repair, preserving
  original assertions and failure evidence; all89 original network gates pass.
- [x] Commit/push fixture15 as `e57fb086f5aa2093767832699907f3430f8334a6`;
  authenticate its four-input source bridge and archives. Four workflows pass;
  E2E network/component pass but recovery timing fails2/1 in protocol.
- [x] Diagnose equal-deadline ordering and independently review CORE16's single
  deterministic test barrier with all assertions/deadlines preserved.
- [ ] Freshly verify, commit/push fixture16, bind its exact source with one test
  input changed from e57fb086, and require all five source workflows to pass on
  the new SHA before publication.
- [ ] Dispatch existing `release.yml` with version, current branch and full
  expected SHA. Preserve all publication guards and actual job dispositions.
- [ ] Verify tag/source, GitHub assets/checksums, six Hex package versions/bytes,
  clean public consumers and downloaded standalone behavior.
- [ ] Archive commands, source fingerprints, environment, counts, exits and raw
  evidence; report commit SHA, push result, release identifiers and remaining
  unverified limits. Do not declare this goal complete with outstanding rows.

No production restart/deployment, operational data/certificates, public
management endpoint, Vault changes, browser gates, or specialist pressure/
abnormal slices are part of this work.
