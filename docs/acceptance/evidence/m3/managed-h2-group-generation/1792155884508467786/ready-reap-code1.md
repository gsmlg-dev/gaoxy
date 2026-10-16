# Ready-reap collector2 independent CODE1

Task: gaoxy-group-generation-ready-reap-code1. **DONE — CODE review FAIL.** Independent SPEC1 remains separately **PASS**. This review neither changes that specification verdict nor claims runtime acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
Branch: `codex/m3-h1-resource-foundation`
Baseline: `8131af39a846c292a022ccbfd32c53376cd57887`

## Actionable finding C1 — P2

**The before-force ready drain can bypass the required absolute15-second cleanup deadline.**

`command-collector2.py:53–68` and `browser-command-collector2.py:45–60` start the deadline, then call `reap_ready('before_force')`. Its `while True` only stops when nonblocking waitpid returns0 or raises ChildProcessError; it never consults the deadline. The same helper is used after force (command:85, browser:77).

A remaining live adopted descendant can keep producing orphaned children that become immediately waitable. If every wait returns a completed child, the new before-force loop keeps draining after the shared deadline. It never reaches the pending census, force path or final immutable receipt. The existing force-loop deadline check cannot bound this earlier loop.

The original post-force wait loop also lacked a deadline check. Collector2 now places the unchecked loop before any forcing, while the selected design explicitly requires an absolute cleanup budget from entry. This finding is confined to that cleanup contract.

Preserve collector2 and repair a new version: consult the same absolute deadline on every reap pass, explicitly record exhaustion and make incomplete draining nonpassing. Keep safe cleanup/census bounded and preserve original actual wait receipts. Do not reset or extend the deadline, call a partial drain naturally clean, or weaken main/Actor gates.

Add deterministic mocks for both before-force and after-force drain exhaustion in each collector. Feed immediate wait receipts while monotonic time advances past the deadline; require bounded completion, explicit exhaustion/FAIL and an intact receipt. Existing deadline cases return waitpid0 immediately and test only the later force path. They cannot expose C1.

## What passes source review

Both version1→2 diffs change only cleanup_descendants. AST-extracted command main and browser main sources are byte-identical to version1; the two new cleanup function sources are byte-identical to each other.

The implementation genuinely calls waitpid(-1,WNOHANG) before signalling, records exact original wait statuses and phase, preserves initial/post-reap/final censuses, and records actual signal attempts. Pending presence after ready waits conservatively marks forced even on a getpgid race or empty-initial/later-pending case. No process-name exemption, proc-state shortcut, sleep grace or ignored actor was introduced. TERM-first3seconds/KILL-after and20ms condition polling remain in the force path.

Popen/finally/actual wait reconciliation, command timeout/nonzero/wait-error/source stability checks, green nonzero tests/failures/warnings/skips/exclusions, and browser four-row/qualification/artifact/Actor exit0/nonforced/readers/group checks are unchanged. Existing peer/bound/Service/Gate/source lifetime assertions receive no edits in these collector diffs.

## Regression and historical evidence

The source defines13 deterministic mocked tests:3 original command timeout/wait/join regressions and10 cleanup scenarios (2 collectors × ready/live/lookup/late/deadline). Ready checks require real mocked wait receipts for status0 and10 with no getpgid/signal calls; live/lookup/late stay forced, and force deadline retains residue. **Tests executed by reviewer:0.** Source syntax was parsed; no mocked suite, scoped test, browser, Mix, build, network or runtime process action was run.

scoped-diagnostic1 remains historically FAIL despite91 tests/0 failures/no warnings/exit0/stable source: cleanup really attempted force before obtaining statuses10 and0. Its diagnostic identity samples show both children already Z; completeness=false/errors12 remain. No retrospective PASS or inferred identity for earlier initial1/2 is introduced.

## Input and verification binding

Nine assigned inputs were hashed before/after with no drift. Full digests are in companion JSON. Key bindings:

- command-collector2.py: `33780fb0131ec06ff58dc29c6d4e8025be181ef0990b2b84a0306f7bd0fffb1f`
- browser-command-collector2.py: `f6019937b2c9dd6cf460e3ff5004331493412acd56b0daeeaaa485de2782ebd3`
- collector-regression2-source.py: `e88e6f2c3f21aeaf77964390a99bb08b641e3500777406b14ba089ab473581fa`
- proposal1: `69aff5dfa9a653fb88c583dd3eb2057ffc07c885ba29d84c8dfeaf259d73a268`
- scoped-diagnostic1: `a4f6b84e0bb6aacceadd6237cd93275e4f1b71525a4976c003bd4d3dbaa40ac8`
- Independent SPEC1 JSON: `c584920991abcdfb5ffa957c2b0fb148b6043cf65197d15a4df50c4055d2e32d`

Diff commands exited1 for expected differences; source AST extraction/parsing and metadata/digest checks exited0. All own commands completed synchronously; no own running command/session remains. Only the two assigned /tmp reports were written. Repository/evidence/Git/runtime remained root-owned and untouched; concurrent changes were preserved.

Inherited counters remain group failedGREEN50/root92/orchestration26; stage failedGREEN5/production1/fixture5/orchestration19. Own repair rounds0, Astra2/2 exhausted, no escalation/reset. Proposal/classification older counters remain historical.

No product/permission decision is needed. Parent confirmed a new collector3 repair with per-pass monotonic checks, explicit exhaustion failure input and new before/after-force deadline mocks. **Collector2 CODE is FAIL pending C1 repair/review; runtime and all stage acceptance remain NOT RUN/unchanged.**

