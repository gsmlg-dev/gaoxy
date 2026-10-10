# M3 0.21.1 accounting frontier specification review

Date: 2026-10-11 Asia/Shanghai. Task `m3_frontier_spec_review`, direct
independent Sol specification review of an Astra **architecture** assignment.
This is not recovery, fixture acceptance or activation approval.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
Ownership is only this new report. Sixteen tracked paths already had edits,
and the new 0.21.1 evidence directory, cleartext plan and architecture memo
were pre-existing. Parent/peer edits are preserved. The current diff was read
before this report was written.

## Verdict

**PASS for the bounded qualification-only architectural refinement.** No
blocking specification finding requires changing the memo. It is the smallest
valid refinement of the existing gate: add a pure ownership model and an
isolated public-API fixture, then qualify their complete numerical/lifetime
contract before production integration. This is within standing M3 authorization
in `AGENTS.md`; it adds evidence needed for established product requirements,
not a product feature, API change, dependency patch or permission expansion.

The reviewed [memo](m3-upstream-0.21.1-accounting-frontier.md) has SHA-256
`c01608f23972df371f1664e6a9a40b8598a6e28a129f16f78d23bc3444c00184`.
All seventeen input hashes declared by the architect match this checkout.

This PASS permits the parent to write and independently review the concrete
supplemental model/fixture plan. It does not approve an unwritten implementation
specification. Functional fixture development may start under that reviewed
plan while numerical rows remain open; no such run may claim accounting
qualification. **Task4 production edits remain gated on the applicable complete
reviewed expression and qualified lifetime contract. Activation additionally
requires actual production conformance and all prescribed runtime gates.**
Task4/M4 activation, complete P0–P6, TLS qualification and M3 completion remain
UNQUALIFIED/BLOCKED as applicable.

## Why the refinement preserves the existing contract

The [product plan](../../implement-plan.md), resource contract §4.5 and M3
milestone, requires admission before payload handoff, finite retained items and
bytes, generation-safe outcomes, bounded streaming and lifecycle acceptance.
The [transport plan](../plans/m3-upstream-transport.md), Task3, requires complete
accounting before Task4 production changes. The
[old H1 architecture](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
P0/P4/P5 explicitly relies on enforcement and implementation lifetimes that
pure constructor worksheets cannot establish. That is a genuine prerequisite
cycle, rather than evidence that the byte gate can be removed.

The memo breaks only that cycle by allowing a disposable qualification
implementation. It keeps the same measured roots/exclusions and C2/R32/P0
profile, existing compact grammar, nil/PID uploads, manual redirects, raw
responses and pinned destinations/socket options. It separately names fixture
enforcement and production conformance. It includes future adapter/guardian/
manager overhead in the pre-Task4 expression, requiring re-review for extra
roles. No production manager, lifecycle registration API, routing switch or
activation-success result is authorized by this slice.

| Required property | Review assessment |
| --- | --- |
| Bounded producers and all-attempt admission | PASS: lease before managed capture/mailbox/Fetch/upload; fixed producers and immediate gate; rejected/preparing/uncertain work remains charged. Upstream R alone is insufficient. |
| No stale or unknown refund | PASS: attempt reference plus generation; duplicate/stale replies cannot refund a newer lease; timeout, owner death and unconfirmed cleanup retain capacity. |
| Lifetime rather than current-count bounds | PASS: P5 requires emission/release induction over arbitrary turnover, including old pool/native controls. Finite maps, fairness, timer cancellation and sampled plateaus are explicitly insufficient. |
| Complete numerical ledger | PASS as a deliverable requirement: each included object/copy edge has shape, multiplicity, owner, release and enforcement. Unknown constants remain open; no component subtotal or guessed multiplier is a reservation. |
| Aggregate generations | PASS: reserve preparing/published/retiring/failed generations before allocation; positive per-generation reservations, finite counts and charged infrastructure; 64 participants does not replace the generation ledger. |
| Independent review and exact identity | PASS: rebind changed callers/copies, verify actual ABI/build selection, independently recompute the complete arithmetic and review source-bound fresh fixture execution. |
| Supported APIs | PASS: private Policy/pool/resource access is excluded; static source reading is allowed; absent supported profile premises remain named gaps. |
| Later acceptance | PASS: separate TLS/H2 contracts, real adapter conformance, independent peers/browser requirements and both managed soak profiles of at least600 seconds remain required. |

## Installed-source cross-check

The [source/API review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md)
and [installed-cohort review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md)
bind tag `bdf849adf119039ed679d24d5fbb0a321f5e578a`. This reviewer independently
rehashed all196 installed shipped files against the published source freeze and
all203 dependency paths in the installed receipt. Both checks passed. Archive
download/tag-network collection, compilation and loaded identity were not
repeated here.

Static reads of actual installed code confirm the memo's material premises:

- `Policy.freeze/1` copies origin leaves and recursively reconstructs accepted
  binary/list/tuple policy values after validation. `freeze_ssl(http, [])` has
  no CA lookup; the HTTPS branch still eagerly evaluates the CA default.
- Request normalization copies URL/header values and then constructs effective
  H1 headers before the final256-field/65,536-byte check. Pure Gaoxy
  canonicalization cannot guarantee Fetch admission near these limits.
- `HTTP.fetch/2` creates a completion tracker and task even after managed
  preparation fails. A gate covering only successful upstream ingress misses
  these allocations. The outer attempt lease is necessary.
- `RequestCompletion.await/2` proves tracked request cleanup, not elimination
  of old pool controls. `abort_and_await/2` sends an abort on each invocation;
  bounded coalesced local producers are a real premise, not an upstream API
  guarantee. Stream ACK likewise needs a release-before-ACK consumer contract.
- Public `open/1` binds the creator; public retirement initiation has a fixed
  call timeout. A persistent custodian, bounded helpers and the original
  absolute success deadline remain necessary. Scope internals are not an
  inspection surface.
- Installed `track_tls/2` still matches only the old three-element TLS tuple.
  The frozen latest status observes95 CLOSED while0.21.1 lacks the containing
  fix. Issue closure cannot release the TLS qualification block.
- `ManagedH1Accounting.activation_status/0` still returns all P0–P6 unqualified.

The parent's reported486/0 compatibility result and evolving cleartext RED/
green work are not reviewed or reinterpreted by this assignment. No current
fixture/final receipt was awaited, consumed or certified. Historical delivery
and control worksheets are checked as conditional inputs, not promoted to
complete0.21.1 proofs.

## Concrete requirements for the next model/fixture plan

These are actionable details to resolve in the supplemental specification,
not architecture blockers or requests for new user permission.

| ID | Detail the plan must make executable | Decisive check |
| --- | --- | --- |
| F1: lease machine | Enumerate every event, precondition, next state, retained owner and permitted effect; separate request outcome from cleanup outcome. Specify direct rejection, launch failure, owner/helper DOWN, abort, late completion, stale generation and duplicate release. State exactly which public completion and local owner-release facts permit refund. No local event may invent acknowledgment of old dependency controls. | Model conservation for all edges/interleavings; stale tokens leave newer reservations unchanged; unknown cleanup never yields a free slot or success. |
| F2: admission boundary | Fix the producer count and payload ownership boundary, including acquire losers. Busy rejection must carry bounded identity/result only, create no waiter/task/managed payload capture, and never call Fetch. Payload-free validation traversal must itself have finite work/source bounds. The rejected33rd acquire is outside the managed lease boundary; admitted requests later rejected during preparation keep their lease. | Hold all32 leases during preparation; concurrent losers produce zero launches and no growing helper/mailbox population; backing-heavy source is rejected before transfer. |
| F3: stream ownership | Name source, canonical, upstream, captured and in-flight representations. Fix read credit, next-read overlap, chunk backing limits, response transfer destination/reservation and one bounded finish/trailer/error sequence. Do not substitute logical chunk size or synchronous ACK for backing/release proof. | Held upload/source ACK and blocked response consumer; one-byte fanout and terminal overlap; logical and referenced backing recorded separately. |
| F4: control lifetimes | Declare the exact finite completion/cleanup-headroom waits, open/retire/abort operations, snapshot schedule and bounded external cleanup callers. Joining cached cleanup must not create unlimited waiters. Define emitted/released potentials for each old inventory class, including timed-out calls, native timer/deferred monitor objects and snapshot copies. | Repeated external cleanup coalesces without new upstream abort/wait calls; proof covers arbitrary turnover. Explicitly report any unresolved native frontier; a finite plateau cannot close it. |
| F5: generation accounting | Fix finite preparation/generation counts and role inventories. Charge manager, custodians, helpers, failed/uncertain slots and every preparing generation before creation; define positive reservation and rollback/release evidence. A runtime model may use symbolic budgets for conservation tests, clearly labeled nonnumeric. | Concurrent generation preparation/retirement and failure conserve the aggregate budget; unknown teardown cannot reclaim it; zero-cost empty-scope admission is impossible. |
| F6: API and test oracle | List only documented Fetch/Promise/RequestCompletion/Stream and ManagedTransport calls. Derive effective-field boundary expectations from supported public constructors. Name owned-fixture barriers separately from peer observations; a local pre-Fetch hold does not certify private upstream preparation. Fix finite deadlines and joined peer/helper shutdown. | Both metadata gates at exact boundary and overflow, duplicate/empty-query behavior, C2 connecting where publicly controllable, A/B retirement isolation. Unsupported holds remain explicit coverage gaps. |
| F7: certificate and composition | Produce a finite P0–P6 row list with every exact input, numeric/formula term, enforcement predicate, copy/overlap and release rule. Include actual runtime ABI/build choice, fixed socket/backend paths and future production roles. Specify which certificates are reusable and invalidate all affected dependents on mismatch. | Independent recomputation of the complete total and complete root inventory; reject missing/mismatched inputs, startup identity mismatch and guessed unknown terms. No byte claim before every applicable row closes. |
| F8: delivery sequence | Enumerate owned new files, scoped tests, source freezes, serialized execution commands and independent specification/code/evidence review. Separate functional model/fixture PASS, accounting profile qualification and later production conformance/activation receipts. Identify the exact minimal gate-text edits the parent will make. | Current24/39 driver and production interfaces remain unchanged; Task4 stays gated until complete fixture qualification; activation remains gated through production checks and existing soaks. |

In particular, F4 must produce either a proved finite timer/signal frontier,
a legal repeatable growth counterexample, or the exact missing source/build/API
premise. An unresolved worksheet is not itself an upstream defect. Route a
demonstrated dependency defect/missing public contract through the existing
upstream process; never add a private flush, quota, periodic reset or numeric
allowance to make it disappear.

## Verification and handoff

Read-only commands: `pwd`, scoped `git status/branch/rev-parse/diff`, `rg`,
`cat`, `sed`, and Python SHA-256/JSON/static-document checks. Python verified
the assigned memo hash, its17 declared hashes,196 published/installed shipped
matches and203 installed dependency identities. Static report validation
checks links, fences, whitespace, recorded hashes and `git diff --check` scoped
to this report. The input table below binds the bytes reviewed.

One initial hash diagnostic treated published paths as package-relative, but
they are audit-relative; it exited1 without writing. The corrected prefix
mapping passed196/196 and203/203. Two initial `rg` targets used the wrong
package/file location for Fetch/Promise; `rg --files` found the actual paths.
These are read-only diagnostic corrections, not implementation repair rounds.

No Mix, VM, test/probe, network, dependency/product/current-status mutation,
commit, child agent or background command was launched. Runtime/model/fixture
checks listed above are **NOT RUN** here. All own commands finished
synchronously. Only this report was created; it is excluded from the parent's
pending patch-cohort commit and belongs to the separate reviewed design/plan
delivery.

Task status: **DONE — specification review PASS**. Cumulative Sol repair
rounds0, unsuccessful rounds0; received Astra recovery counter not applicable,
architecture assignment; recovery rounds consumed0. `astra_gate`: none.
Remaining risks are the finite unresolved proof/build/API premises and
unexecuted fixture/production gates. No new product decision is required.
The parent owns the concrete supplemental plan and any narrow gate-text edits,
implementation scheduling and later qualification; this report edits none of
those documents and establishes no numerical reservation.

## Inspected input identities

Paths are worktree-relative; SHA-256 values refer to this review's static inputs.

| Input | SHA-256 |
| --- | --- |
| `AGENTS.md` | `c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed` |
| `implement-plan.md` | `60f112e0f9c48fd52d4ac27b87303b5970a97b3b1a90bcbf952ac862adf3eb49` |
| `docs/designs/m3-upstream-0.21.1-accounting-frontier.md` | `c01608f23972df371f1664e6a9a40b8598a6e28a129f16f78d23bc3444c00184` |
| `docs/designs/m3-upstream-transport.md` | `c68924ac74b59ddab236129ce54583f0fd92931aec53260841aa53c9178fc521` |
| `docs/plans/m3-upstream-transport.md` | `76bfe7906f675aaeb72a9a72fbd03264c7963b856a88df1aa3c5b523b54ff1a4` |
| `docs/plans/m3-upstream-0.21.1-qualification.md` | `365b8786b65f662cb29ea32b01c47521d0afef7b25da7f8559294d381e22a606` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md` | `6ac9a051172e761717da3be3861566740724ff5507601314ea332e1a36bebe81` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-review.md` | `3257a66c8c5423e081f20eba43f2e71d9077454cbedf94a0588c84e151667368` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-delivery-proof.md` | `1fcb1d4300a36984ef28795edfc91cf61d9a5c916720f1b373e29a8695cde2a9` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-control-turnover-proof.md` | `613cf2ed23571f36eb527727b8d574b745fa6cc075b3e8b59e1c42fa7b565604` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md` | `79e9830c2a67574f07bac053de30a91fad6616d7beb980df7f4a1ae33172403a` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.json` | `e9cfb8619626d31d858c40799a4bf77c61f40d9c0570eddea97d93c64f0886c8` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md` | `e9225b55172f2d71e86d78f3022c67e07c8734f2d0bdcbde8d9172eb9a0734d5` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.json` | `ae1479dbaa9d08412d19c0e94226c0647ba1c801e43d57188039753feb0cda26` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/upstream-status-refresh4.json` | `3130f0e972d73ad03650a3dd75f48d512f3fa38e1211bcb19ca26623e781cf77` |
| `deps/http_runtime/lib/http/managed_transport/policy.ex` | `248f6091799727d6c43589585c8eacfc4d72b92ee6b3663298899468e1f1ad14` |
| `deps/http_runtime/lib/http/managed_transport.ex` | `8b00fbfdb570a2605da7bc90d122ab75d41208c928c61a1144c304e587971d8a` |
| `deps/http_core/lib/http/request_lifecycle.ex` | `81a3b158e33b7291422c009fb47170574b3bf6b7d9ad4023619ca84147fcf01f` |
| `deps/http_fetch/lib/http.ex` | `b86d8cc723cbab453e04dee8cf2a8bd99ca5a08d638c07a1d677ef501a495f7b` |
| `deps/http_fetch/lib/http/request_completion.ex` | `2579b9bbae473603227bcf0edc9509adb8c070927d44fb4e141e7d11160bcb9f` |
| `deps/http_fetch/lib/http/stream.ex` | `552c5951d30c21ce864a77c1a61dc5e8bcda038559040028e4f3282074325d05` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex` | `114dfce56ad02ee65b588caec861ad7c6b46097b06690cb5af5ed8504beadf56` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex` | `81b990206b77a83d8c19aa97d451a752b4b9ec3e0cc0859f2a1a8b282079aff1` |
