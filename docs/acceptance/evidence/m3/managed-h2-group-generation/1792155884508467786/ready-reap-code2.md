# Collector3 independent ready-reap CODE2

Task: gaoxy-group-generation-ready-reap-code2. **DONE — CODE2 PASS; no actionable findings.** This is source review only.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
Branch: `codex/m3-h1-resource-foundation`
Baseline: `8131af39a846c292a022ccbfd32c53376cd57887`

Root confirmed independent SPEC2 PASS before this verdict. Archived SPEC2 JSON SHA256 is `a7cdf065f4fcff9f8cfeb3ef222aa5473a3c3c8258f314ca2a11b6497d5bd78f`; it records no findings and12 stable inputs. SPEC and CODE verdicts remain distinct.

## C1 resolution

Collector3 fixes the unchecked productive-ready loop identified in collector2 CODE1. Both cleanup functions consult the original absolute15-second deadline **before every nonblocking waitpid**, in before_force and after_force phases. They record phase-specific reap_deadline_exhausted and conservatively propagate it to forced=true. A later empty census cannot clear exhaustion or turn an incomplete drain into PASS. No deadline is reset or extended.

Exact wait statuses, initial/post-reap/final censuses, actual signal-attempt outcomes and the wait-before-force ordering remain. Pending live residue, getpgid lookup races and empty-initial/later-pending cases stay conservatively forced. TERM-first3seconds/KILL-after and20ms polling remain in the force path. No process-name/PID/status exemption, grace/retry or ignored child was added.

Collector2 and its CODE1 FAIL are preserved. Proposal2's older root95 counters remain historical.

## Unchanged acceptance

The collector2→3 diffs change only cleanup_descendants. AST-extracted main and children function source are byte-identical for both pairs; the two collector3 cleanup functions are byte-identical.

Popen/finally/actual-exit reconciliation and command timeout/wait-error/nonzero/source-stability gates are unchanged. Green nonzero executed tests, zero failures/warnings/skips/exclusions remain required. Browser four-row qualification, source/artifact hashes and actual Actor exit0/nonforced/reader/group checks remain unchanged. Protocol peer/bound/completion, Service/Gate, original G/T/source lifetime and cleanup assertions receive no changes.

## 17 mocked cases reviewed, not run

Regression3 retains the3 original command timeout/wait/join regressions and10 ready/live/lookup/late/deadline cases, then adds4 productive-ready deadline cases: before_force and after_force for each collector.

In the new before_force case, one exact wait receipt precedes the deadline; the next wait is prevented. It records before_force and after_force exhaustion, actual KILL attempt, forced=true and remaining child. In after_force, the initial scan returns0, TERM occurs, one after_force receipt is retained and the next deadline check prevents further wait while preserving exhaustion/forced/remaining. Finite clock/wait sequences make omitted deadline checks observable as a test error rather than an indefinite mock run.

Existing case clock expectations are adapted to the added checks; original failure assertions remain. **Reviewer tests executed:0.** No target imports/execution, mocks, scoped tests, Mix/build, network/browser or process actions were performed. Root must execute the17 mocks and prescribed subsequent scoped/browser/consumer gates.

## Binding and validation

Seven assigned source/proposal inputs were hashed before/after without drift. All6 hashes embedded in proposal2 match their current files, including historical SPEC1/CODE1 bindings. AST syntax/source extraction and metadata/hash checks exited0; diff commands exited1 for expected source changes. HEAD remains the stated baseline.

- command-collector3.py SHA256: `aeff8b310f5f0a296ed79d915d9f8beb4f57b2e2d782a857de85779c298d27ee`
- browser-command-collector3.py SHA256: `008687f0d21470e8fcb4fcf6cca3f46b86b9e3cec394ead06a14106899f9a0c5`
- collector-regression3-source.py SHA256: `6491d7524ced362c5ce93d4b8b089c8bb51013fe822b394d742ba2d014a31a9c`
- proposal2 SHA256: `c34b34978b8c388af7cc718422888006ea28eb83371471e65c6eeda9f4c3f704`

Full hashes/checks are in the companion JSON. Only the two assigned /tmp reports were written. Repository/evidence/Git/runtime stayed root-owned; concurrent edits were preserved. All own commands finished synchronously with no running session.

Latest parent counters retained: group failedGREEN50/root96/orchestration29; stage failedGREEN5/production1/fixture6/orchestration22. Own Sol repair rounds0; Astra2/2 exhausted, no reset/escalation. No user decision is needed.

**CODE2 PASS does not establish mocked, scoped, browser, protocol, milestone or production acceptance.** Those gates remain unexecuted by this reviewer, and all historical failures remain visible.

