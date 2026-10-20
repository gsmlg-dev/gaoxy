# Issue A review P2 — expired activation

Direct review repair, baseline 581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd,
worktree standalone-recovery. Cumulative Sol repair round 2, Astra 0.

The first independent review found that the new activate_declared/5 helper had
only a positive-timeout clause. RouteResources can finish compilation after its
shared absolute deadline and pass 0, crashing its coordinator rather than
rejecting an expired candidate as the previous activate/4 call did.

A gated endpoint now extends both existing fixed/group recovery cases. The real
RouteResources.activate caller reaches its unchanged 1000ms absolute deadline
while compilation waits. Only after observing that caller's deadline error does
the test release compilation and synchronize the same coordinator. No arbitrary
sleep or changed deadline/assertion is used. The pre-fix run deterministically
raises FunctionClauseError at activate_declared/5(...,0), 2 executed/2 failed,
exit 2 (red.log). This is runtime failure after real managed preparation, not a
fixture validation failure.

The production correction adds one fallback returning invalid_activation_timeout
for typed routers with invalid timeout, matching the prior API behavior. The
regression verifies no coordinator/runtime/owner replacement, unchanged accepted
declaration and baseline pins, retained expired preparation pins followed by
explicit reconciliation, and accepted traffic before the original recovery and
subsequent reload assertions continue.

Green: 13 HTTP tests plus 4 server tests, 17 executed/0 failed, exit 0. The focused
gate still contains 2 recovery cases, so no gate count change is required.
Strict compile, canonical formatting of both changed files, and diff-check all
exit 0. Exact commands/source hashes/log hashes are in receipt.json. Historical
round 1 and original defect evidence is untouched. All commands finished.

Only generation.ex and standalone_recovery_test.exs changed in this repair.
The export directory contains exact complete files; repair.patch is the delta
from their pre-P2 snapshot. No import, commit, dependency mutation, publication,
deployment or specialist testing was performed. Parent review/integration remains.
