# Adaptive resource budget implementation

Baseline: `a6a35438c0a153cd53c87c6a55c19a70a11fb75a`, current branch `main`.
Design: [adaptive resource budget](../designs/adaptive-resource-budget.md).
Goal scope includes implementation, ordinary verification, independent review,
documentation, commit, push and coordinated release. No branch/worktree creation
or production deployment is authorized. Preserve unrelated work and immutable
historical specialist evidence. Unchecked items are outstanding, not implied
complete by a narrower passing test.

## Task routing and cumulative repair record

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
| ARB-CORE | Sol/unassigned | Not started | 0 | 0 | None |
| ARB-PROTOCOL | Sol/unassigned | Not started | 0 | 0 | None |
| ARB-PHOENIX | Sol/unassigned | Not started | 0 | 0 | None |
| ARB-QUALIFY | Sol/unassigned | Not started | 0 | 0 | None |
| ARB-RELEASE | Coordinator/unassigned | Not started | 0 | 0 | None |

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

- [ ] Implement supervised canonical ledger continuity, authority generations,
  per-instance scopes and aggregate VM coordination; fail closed after ledger
  loss and reconstruct after authority restart without forgetting live usage.
- [ ] Add pure policy normalization and omission provenance. Preserve explicit
  legacy max_bytes/max_active semantics; add distinct connection/request/stream
  quotas and instance soft/hard configuration.
- [ ] Integrate atomic acquire/resize/transfer/release into all Admission paths,
  including send, cleanup, spawn activation/cancellation and terminal pairs.
- [ ] Preserve resource ownership on ambiguous timeout and idempotent retry;
  do not allocate after unconfirmed reservation.
- [ ] Add accurate request-end/upgrade transitions and resource kind counters.
- [ ] Separate finite backend/QUIC transport safety ceilings from memory policy.
- [ ] Add capacity refresh, OOM/process safety sampling, rate-limited warning
  logs, telemetry and public `Gaoxy.resource_budget(instance)` inspection.
- [ ] Controlled tests prove exact thresholds, projected admission under race,
  multi-instance sharing, explicit policies, release/recovery, owner failures,
  authority restart, ledger fencing, refresh shrink and stable capacity despite
  unrelated free-memory changes. No unit listeners or full runtime startup.
- [ ] Independent specification/code review, required repairs and fresh checks.

## Phases 2–3: dynamic protocol accounting and overload

### ARB-PROTOCOL

Files: H1 Connection/Exchange; H2 Limits/Connection/WorkerAccounting/Writer;
H3 Options/Connection/Stream/QUICBridge; providers and directly affected tests.
Coordinate any core interface change with its sole owner before editing.

- [ ] Reproduce ordinary concurrent default-budget regressions before repair.
- [ ] H1 connection/request/body/send accounting grows and returns ownership;
  keep-alive ends request counts and retains only real carry state.
- [ ] H1 safe overload returns valid bounded 503; unsafe partial framing closes
  without leaks or deadline changes.
- [ ] H2 measured idle/retained state replaces the static 30 MB allowance;
  temporary HPACK peak is acquired before decode and released at its real
  lifetime. Preserve decoder/table/block/flow/frame bounds and compression state.
- [ ] H2 stream, worker and writer ownership remain distinct and cancellation/
  startup retains existing terminal invariants. Ordinary worker overload refuses
  the affected stream while existing streams continue.
- [ ] H3 separates QUIC, stream, transport-buffer and HTTP request resources;
  preserve pending operation cleanup, QPACK policy and finite transport ceilings.
- [ ] H3 resource refusal is request/stream-local with 0x107 where safe;
  transport connection refusal releases handles and workers.
- [ ] Independent connections, overlapping streams, concurrent uploads, SSE,
  response streaming, WebSocket upgrade, churn and cleanup have actual network
  evidence. Classify new tests and retain all historical specialist dispositions.
- [ ] Independent review and fresh focused/integrated checks.

## Phase 4: Phoenix and ListenerSet

### ARB-PHOENIX

- [ ] ListenerSet and Phoenix options carry shared instance policy through pure
  planning, preparation, deferred activation and inspection.
- [ ] Remove default-masking hard-coded H2 budget overrides from Phoenix example;
  document intentional explicit configuration and migration semantics.
- [ ] Validate mixed HTTP/HTTPS/H3 within one ListenerSet and multiple Endpoints/
  ListenerSets sharing the VM pool without multiplying capacity.
- [ ] Exercise Phoenix LiveView WebSocket connections, ordinary requests, SSE,
  streaming responses and uploads with independent clients/peers.
- [ ] Update README, public resource-budget/telemetry docs and examples; review.

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

- [ ] Independent architecture/specification/code review completed; actionable
  findings resolved and final integrated source freshly qualified.
- [ ] All own version manifests and six published Hex distributions target the
  same next version; update current installation/release docs without rewriting
  historical acceptance evidence. Provisional minor target: 0.14.0, recheck
  remote state before choosing publication source.
- [ ] Inspect final task-owned diff and commit conventionally on current branch.
- [ ] Push verified commit and confirm remote SHA; retain exact-source CI statuses.
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
