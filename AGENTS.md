# Gaoxy agent instructions

## Current adaptive-budget extension — 2026-10-30

The user extends the existing time quota by **24 hours**, moving the fixed
deadline from 2026-10-30 10:09:44 to **2026-10-31 10:09:44 Asia/Shanghai**
(UTC **2026-10-31 02:09:44**). The original start remains 2026-10-29 22:09:44
Asia/Shanghai, for a total allowance of 36 hours. Resume the unfinished adaptive
resource-budget goal and its already-authorized implementation, verification,
independent review, commit, push and coordinated release within this window.
Failure counts remain historical and impose no numerical stop during it.
Preserve the earlier expiry/model-capacity evidence and cumulative repair
counters. Already-escalated recovery stays on Astra, with at most one active
Astra worker and serialized shared builds. All existing scope, ownership,
assertion, dependency-blocker and publication guards remain effective. Stop
new work at the extended deadline or once the full objective is verified and
delivered. No branch/worktree or deployment permission is added.

## Initial adaptive-budget time quota — 2026-10-29

The user replaces failure-count limits for the active adaptive resource-budget
goal with a twelve-hour execution window, from **2026-10-29 22:09:44** through
**2026-10-30 10:09:44 Asia/Shanghai** (UTC 2026-10-29 14:09:44 through
2026-10-30 02:09:44). Continue implementation, diagnosis, repair, verification,
independent review and the already-authorized delivery within that window.
Repeated failures do not exhaust this allowance. Existing Sol/Astra counts and
failed evidence remain historical records; do not reset or erase them.

This explicit additional repair authorization supersedes the numerical repair
ceilings and pending-approval stops below for this goal during the window.
Already-escalated CORE, H1/H2 and H3 recovery stays on Astra, with at most one
active Astra worker and serialized shared builds. Preserve scope, assertions,
ownership, independent review, dependency-blocker rules and publication guards.
Stop new work when the window expires or the full objective is verified and
delivered; report actual completion and remaining blockers. No branch/worktree,
production deployment or operational-data permission is added.

## Current automated testing boundaries — 2026-10-22

These boundaries supersede historical browser-verification requirements below.

- `test.yml` has one `ubuntu-latest` unit job, without an OS or BEAM matrix.
  Service interactions use mocks or controlled doubles. Unit tests must not open
  real listeners/sockets, request even localhost services, launch protocol peers
  or start a complete multi-component runtime.
- `e2e.yml` owns Linux component integration, real network/protocol tests and
  independent HTTP-client acceptance. Source jobs run on push/PR/manual without
  requiring a published version. Released-server checks have a separate manual,
  nonempty-version gate after their actual harness is qualified.
- `portable.yml` alone owns cross-platform execution. Keep its smoke to one
  native HTTP start, GET `/health` requiring 200 and `ok`, and successful stop.
- `package.yml` owns package staging, clean consumers, dependency isolation and
  source-built release smoke. Release qualification repeats required checks on
  the exact publication source and retains its separate publication guards.
- Use HTTP clients and protocol peers; do not add browser automation, Playwright,
  Chromium installation, UI assertions or screenshots to server test gates.
- `scripts/check-repairs.py` is the sole active app-file/count manifest with
  `unit`, `component` and `protocol` suites. Classify every new app test file;
  explicitly retain unscheduled/specialist paths in `scripts/test-inventory.json`.
  Keep unit module declarations consistent and review their real dependencies.
- Preserve ordinary assertions and exact, positive executed counts. Deferred
  specialist cases and immutable historical evidence retain their disposition.

## Current M3 acceptance and local merge scope — 2026-10-19

The user accepts M3 as **COMPLETE within the implemented product functionality
and ordinary verification scope** and authorizes merging the existing local
implementation into local `main`. This current decision supersedes older
`WholeTask6/Task5/M3 OPEN` dispositions and automatic progression instructions
for exceptional, slow-peer, pressure, sustained-load and combined qualification
slices. Stop executing or extending those slices in this work; transfer their
remaining validation to a dedicated specialist test environment. Their failed,
blocked and unexecuted results retain their actual status and are no longer
blockers for this local merge. Preserve all historical evidence and assertions;
this acceptance does not implement any absent capability or certify those tests.

The sole-native-H1 blocked-upload disconnect slice has not established a product
defect: its executed case failed during fixture setup before request creation,
and the subsequent test-only `Code.require_file` fix has not been rerun. Do not
continue that slice or include it as part of this implementation. Keep its
source and evidence preserved separately from the accepted implementation.

Complete ordinary fresh merge verification and local integration under this
scope. This authorization adds no push, release, package/image publication or
deployment permission. Historical v0.3.0 publication is separate from the new
local M3 implementation. Existing production-data/certificate, Vault,
public-management and disabled release-artifact E2E restrictions remain intact.
See [M3 completion](docs/acceptance/m3-completion.md) for accepted functionality,
historical evidence and the fresh ordinary merge verification.

## Historical instructions — retained below

## Reviewed M3 disposition and release authorization — 2026-10-11

The user reviewed `gsmlg-dev/http_fetch#97` and excluded its requested proof as
excessively strict. Do not pursue or re-raise it, introduce equivalent replacement
requirements, or use it as a stage, release, or M4 blocker. Preserve assertions,
failures and immutable historical evidence; dismissal is a scope decision.

The user separately authorizes the necessary integration into main, push, tag
and GitHub standalone release after relevant verification and independent review.
Release v0.2.0 covers native H1/H2 and the dedicated-H1 gateway beta subset;
upstream connection pools and upstream H2 are not implemented. Prepare M4's
HTTP/3 design and plan under continuing authorization. This exception supersedes
older publication bans for this release only. Deployment, production data,
operational certificates, public management, Vault freezes and the disabled
release-artifact E2E workflow retain their existing restrictions.

Do not re-raise account spending/quota-increase requests for this work. If a
hosted job cannot start, preserve its unexecuted status and use a separately
qualified local release build without changing account or repository settings.

## Continuing development authorization — renewed 2026-10-13 for M3 H1 resources

The user granted continuing authorization on 2026-10-10 for the existing product
goals in `implement-plan.md`, beginning with M3. This authorization supersedes
older routine development approval and phase-stop rules, including historical
kickoff instructions limited to M0/M1 and old per-file scope lists.
The user renewed this authorization on 2026-10-11 and 2026-10-12, explicitly
starting M4 development: ordinary implementation or
test failures enter diagnosis and repair rather than a user-approval pause.
Cumulative Sol/Astra counters remain recorded; this renewal does not reset them
or authorize a third Astra recovery round. Necessary additional local Sol
repairs are authorized, with fresh independent review and unchanged assertions.
M4 authorization covers executing its HTTP/3 design and plan, including the
required downstream/upstream matrix and necessary standalone compatibility;
the earlier instruction to prepare M4's documents is not an implementation
stop. Automatically design and execute any remaining bounded slices after
their preceding gates pass. On 2026-10-13 the user explicitly started
`docs/plans/m3-h1-resource-foundation.md` and renewed this authorization for the
established product goals. The completed M4 acceptance/release preparation
freeze is released by the parent at the verified Task 4 kickoff; historical
documentation-only ownership does not restrict this execution. Advance to the
next planned stage after required verification and independent review, retaining
written designs and plans. This renewal grants no new publication or deployment
authorization; the completed v0.2.0/v0.3.0 exceptions remain historical.

- Choose the recommended design and execution approach automatically. Complete
  design, plans, implementation, necessary compatibility repairs, test-contract
  updates, documentation, tests, independent review, and local conventional
  commits without requesting individual `approve` responses.
- Keep a written design and implementation plan for each stage. Advance to the
  next planned stage after the prescribed verification and independent review
  pass, without waiting for another routine stage approval.
- Stay within the established product scope. A necessary compatibility repair
  may touch files outside an older file list; this is not a reason to stop.
- Diagnose and repair failed tests. Never weaken assertions, skip required
  verification, or describe a failed, blocked, or unexecuted gate as passing.
- Default to parallel agents for independent work. Give each writer explicit
  ownership, preserve others' edits, and serialize dependent operations.
  Sol handles implementation, debugging, tests, and routine independent review.
  Astra may design architecture or take bounded recovery after two unsuccessful
  Sol repair rounds or an evidenced technical impasse. Preserve cumulative
  repair counters across handoffs; allow at most two Astra recovery rounds.
- Stop only for new external permissions, a product decision the user must
  make, or a genuine external blocker that cannot be resolved autonomously.
  Continue other unblocked work when only one task is blocked.

This authorization does not expand product scope or remove explicit Vault
freezes, E2E restrictions, publication/deployment restrictions, or production
data restrictions. The release-artifact E2E workflow remains disabled until its
design and real suite meet the existing gate. Required local independent-peer
and browser verification remains part of implementation acceptance. Do not
push, publish packages/releases/images, deploy, alter production data, issue
operational certificates, or enable a public management endpoint without the
separate authorization required by the product plan.

## Conditional M4 publication authorization — 2026-10-12

The user separately authorizes integration into main, push to GitHub and a new
version release after M4 actually completes its prescribed verification and
independent review, followed by preparation of the next planned stage. This
supersedes the local-only publication boundary for that completed release.
Incomplete or blocked M4 gates do not satisfy the condition. Deployment,
production data/certificates, Vault, public management and the disabled
release-artifact E2E retain their explicit restrictions.

## Workspace and implementation

- Put new worktrees in this project's `.trees/` directory; use `codex/` branches.
- Preserve unrelated changes and untracked user files. Stage only task-owned
  files. Omit generated-by and AI co-author trailers from commits.
- State assumptions, prefer the smallest solution, match existing style, and
  avoid unrelated cleanup or speculative features.
- Use pure modules for configuration and policy; introduce processes only for
  mutable runtime state, concurrency, or fault isolation.
- Gaoxy owns server lifecycle and adapters. Use supported dependency APIs; do
  not patch `deps/`, depend on private client processes, or hide Bandit as the
  production server. Core-only consumers must remain isolated.
- Do not ship an open proxy. Forward/CONNECT policies require explicit
  authentication, destination rules, and validation at connection time.

## Dependency issue routing

For a dependency bug or missing required feature sourced from gsmlgorg,
gsmlg-dev, duskmoon-dev, gsmlg-app, Gao-OS, gsmlg-opt, gsmlg-ci, gsmlg-games,
or gsmlg-com:

1. Identify the repository from package provenance.
2. Create an upstream issue with `gh issue create --type Bug` or `--type Feature`,
   label `internal request` (create the label if missing), and title
   `[internal] <concise description>`.
3. Include requesting `org/repo` and branch, need and rationale, minimal bug
   reproduction or feature expectations, and severity `blocker`, `needed`, or
   `nice-to-have`.
4. Add `# TODO(upstream): org/repo#<number>` at the affected callsite.
5. For a blocker, stop that task without a local workaround. Resume only after
   the upstream issue is resolved and the dependency is updated. For lesser
   severities, mark a temporary repair with
   `# WORKAROUND(upstream): org/repo#<number>`.

## Verification and acceptance

- Run relevant scoped tests and required stage gates; compatibility tests needed
  by the product goal are authorized. Diagnose failures instead of seeking a
  routine approval. Unrelated failures stay visible and are not silently fixed.
- Require nonzero executed tests. Record commands, environment, source identity,
  counts, exits, and evidence, with PASS, FAIL, BLOCKED, and NOT RUN distinct.
- Use real network/independent-peer tests for protocol acceptance and deterministic
  synchronization for lifecycle races. Keep assertions and finite deadlines.
- Complete independent specification and code review, resolve actionable findings,
  then run fresh verification before committing or advancing a milestone.
- Keep hosted CI, local evidence, publication, deployment, and production
  acceptance separate. Do not infer one from another.
