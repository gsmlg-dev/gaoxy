# F2 browser cleanup repair2

**DONE — static-only assigned repair; all acceptance gates NOT RUN.**

Task: `managed_h1_matrix_browser_cleanup_repair`. Direct assignment; second targeted Sol repair. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; root-verified HEAD `1426657e65d726629d618dcf03880df718375dd1` (no Git commands run).

Only `integration/upstream_transport/browser.py` was edited. Frozen source bytes matched before editing.

Pre-edit SHA256: `3f752d60f5e75fd43920e019d6c8beee09107a7d279262435a9f954156ba71d5` (19097 bytes).
Post-edit SHA256: `f2920e140f7171a5ac31ee4b2034d9f4078928c0947fcdc71630a2a8bfd2b21c` (21480 bytes).

Actor process ownership was registered after fallible post-spawn setup; outer SIGALRM remained armed during cleanup; leader exit bypassed descendant group disposal.

Register partial actor before log/spawn, mask SIGALRM across Popen and reader-thread ownership handoff, cancel alarm before cleanup, and perform bounded TERM/KILL/reap/thread cleanup for the owned group regardless of leader exit, retaining errors/forced/unjoined FAIL receipts.

Static AST/hash command exited0. No candidate code was imported or executed. Checks:
- AST_PARSE: PASS
- START10_BARRIER5_CASE20_OUTER600_UNCHANGED: PASS
- ALL_REQUIRE_ASSERTIONS_UNCHANGED: PASS
- NORMAL_JOIN_UNCHANGED: PASS
- BROWSER_TWO_ROW_PAGE_RECEIPTS_UNCHANGED: PASS
- REGISTRY_PRECEDES_LOG_AND_SPAWN: PASS
- SPAWN_AND_THREAD_HANDOFF_MASK_RESTORED_IN_FINALLY: PASS
- OUTER_ALARM_DISABLED_BEFORE_CLEANUP: PASS
- GROUP_DISPOSAL_NOT_SKIPPED_FOR_CLOSED_OR_EXITED_LEADER: PASS
- FORCED_ERRORS_UNJOINED_REMAIN_FAILURE_FILTER: PASS

Independent source re-review, first16-case matrix, scoped tests, finite integration, actual browser two rows/four images and root visual inspection: **NOT RUN**. Parent performs these separately.

Targeted Sol repair2; earlier cumulative Sol total unknown and not reset; Astra2/2 exhausted unchanged. No further recovery attempted.

Incidents: none. No protected diagnostics, private key, raw trace, Git/status, Mix, tests or browser execution. All commands completed; no background or candidate-owned processes launched. Other writers' changes were preserved.

Ownership returned to parent. Remaining risk: static evidence does not prove runtime cleanup or acceptance; no product decision needed.
