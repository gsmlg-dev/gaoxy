# Backend options implementation plan

1. Inspect pinned dependency APIs and effective consumption; record the support
   boundary in `docs/designs/backend-options.md` before implementation.
2. Add pure backend-option validation and explicit core forwarding, including
   acceptor budget division and fixed deferred-activation configuration.
   Verify with focused validation and real backend tests.
3. Thread role-appropriate options through HTTP, HTTP3, ListenerSet and Phoenix.
   Verify prebinding rejection and actual runtime propagation on these paths.
4. Document the support matrix, canonical configuration relationships and
   Bandit migration examples. Independently review specification and code,
   resolve actionable findings, then rerun focused tests, formatting and strict
   compilation. Record passed, failed, blocked and unrun checks separately.

## Execution record

- Baseline: main `946e850472e9c6e95c3f8914a65b58531c852287`; only the user's
  untracked `prompt.md` was present. No worktree, commits or publication.
- ROUTE task=backend-contracts agent=sol_worker reason=read-only pinned API inventory.
- ROUTE task=backend-options-core agent=sol_worker reason=core validation and backend forwarding.
- ROUTE task=backend-options-http agent=sol_worker reason=HTTP integration using fixed core interface.
- Both implementation tasks: initial/current worker Sol; no escalation.
  Core Sol repair rounds 0, Astra rounds 0. HTTP Sol repair round 1 fixed a test
  reader's assumption that headers/body arrive in one TCP read; unchanged
  response assertions and finite deadline passed on rerun. HTTP repair round 2
  handles independent-review findings: reject duplicate top-level entries and
  reject receive-buffer options owned by HTTP protocol initialization.
  HTTP Astra rounds 0. Independent writes are disjoint.
- Baseline selected portable checks: 17 passed. Eight H3 network cases failed
  during fixture setup because PATH selected OpenSSL 4.0.3; no request ran.
  Use `OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl` for fresh checks.
- Agent Note recall unavailable: `.agents/current.md` does not exist and no
  explicit project label was established. No note was written.
- Independent specification/code review completed; both HTTP findings resolved
  and re-reviewed. HTTP worker independently reviewed core with no findings.
- Final scoped verification: 183 passed, exit 0; strict development compilation
  and changed-file formatting passed. Browser smoke blocked by unavailable tab
  creation; broad core/format failures remain distinct baseline findings.
  Full commands, counts, failures and retained logs:
  `docs/acceptance/backend-options.md`. No unrelated fixes were made.
