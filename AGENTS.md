# Gaoxy agent instructions

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

## Continuing development authorization — renewed 2026-10-12 for M4

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
stop. Automatically design and execute any remaining bounded M4 slices after
their preceding gates pass. This grants no new publication or deployment
authorization beyond the already completed v0.2.0 exception.

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
