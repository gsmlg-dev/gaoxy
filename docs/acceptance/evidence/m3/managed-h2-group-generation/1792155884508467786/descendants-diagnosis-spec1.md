# Descendant collector bounded diagnostic SPEC/proposal

Status: DONE — direct read-only diagnostic specification/proposal; no implementation or runtime acceptance. Root exclusively owns repository/evidence/Git/runtime and concurrent work. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; predecessor baseline received `8131af39a846c292a022ccbfd32c53376cd57887`, not queried with Git. Only this report and its JSON companion were written. Test fixture internals were not inspected for this task.

## Finding and immutable disposition

**The current evidence cannot distinguish an actual live descendant leak from an immediate census/reap race. Keep scoped-initial2 FAIL and both PID identities UNKNOWN.** The collector has an observable ordering/metadata gap, not an evidenced harmless-helper classification or proven production leak.

`docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial2.json:28-58` records command PID127922, actual exit0, nonforced command, no wait_error, command joined/group absent,91 tests/0 failures/0 skips/0 exclusions/0 warnings and stable sources. Descendant cleanup records initial[155438,157671], reaped157671/raw wait_status10 and155438/raw wait_status0, remaining[]. Overall verdict is FAIL (`:4`). No PID executable, argv, state, starttime, ancestry edge, PGID, signal attempt/result or per-event timestamp is present. These PIDs have already been reaped; do not inspect a now-reused `/proc/<pid>` and attribute it to this run. Neither process can be called Erlang/helper/peer/Chrome or leaked by identity from this receipt.

Raw status0 establishes wait-observed exit0, not whether the process was already dead at the initial census, exited during cleanup, or handled a signal and exited0. Raw status10 is a signal-termination wait status (signal number10 on the recorded Linux platform), not exit code10; it does not establish executable or sender. The cleanup code attempts TERM/KILL (15/9 on this platform), not signal10. It therefore cannot directly explain that termination status as its own signal10 call; a more complex causal chain is also unproved. Do not use the historically familiar adopted signal10 outcome as identity evidence for these PIDs.

## Source-backed diagnosis

All exact paths in this section are under the above worktree.

- `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector1.py:91-104` enables Linux child subreaping, starts the real command in its own session, then waits for that immediate command only. `:121-130` always runs descendant cleanup and reconciles an actual wait result if necessary. Reaping the immediate command does not establish that all adopted descendants have exited or been waited.
- `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector1.py:35-49` obtains a non-atomic recursive census from `/proc/<parent>/task/<parent>/children`, rooted at the collector, so independently sessioned descendants are included by ancestry rather than only the original command PGID. Linux can retain an exited but unreaped child in this list; a nonempty census alone is not live-process evidence. The function records only PID numbers, not the edges/read timestamps or identity snapshots. Its explicit main-task traversal should not be advertised as a complete original-creator or all-thread ancestry history.
- **Ordering:** `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector1.py:51-75` takes `initial=children()`, then in every loop obtains another census, looks up PGID and attempts group TERM/KILL **before its first `waitpid(-1,WNOHANG)`**. It has no reap-ready-first phase or natural-exit observation interval. Thus a zombie already ready for wait, or a child completing between command wait/census/getpgid/signal, may enter `initial` and the signal loop.
- **Meaning of forced:** `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector1.py:74` returns `forced=bool(initial)`. It does not say a signal syscall was actually attempted or succeeded. `ProcessLookupError` is swallowed at `:62-63`; no outcome is retained. Conversely, a child appearing only after an empty initial census could enter a later signal pass yet leave forcedfalse. Therefore the current field is a sticky initial-census predicate, not an accurate signal log. Both edge cases are source possibilities; neither is established as this run's cause.
- It resolves group ID from the then-current PID and asserts it differs from the collector PGID at `:58-61`, but records no identity/starttime guard, ancestry edge, group membership or syscall race. Several same-PGID descendants can trigger repeated group signals; the receipt does not disclose such attempts. Syscall success would still mean accepted signal request, not proof of a particular process's delivered signal or death cause.
- `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector1.py:64-76` retains only final raw waits and remaining PID set, with a15-second cleanup deadline, first3 seconds TERM then KILL,20ms loop sleep. It lacks phase timestamps, so the receipt cannot establish whether initial PIDs were Z, naturally terminating, or still live when a signal was issued.
- `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector1.py:147-151` correctly keeps a green receipt FAIL when descendant forcedtrue, regardless of command exit/test success. Do not change these predicates for the diagnostic.
- The browser collector has the same census/cleanup ordering/forced predicate at `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-collector1.py:27-68`, the same subreaper/command-join/finally contract at `:91-129`, and requires no forced/remaining descendants plus command/group/source/real qualification/Actor joins at `:133-146`. The same observational helper must be reviewed for both copies; do not fix one and claim both covered.
- Existing mocked collector regressions only exercise main-command timeout/signal races/final wait reconciliation while mocking descendant cleanup entirely: `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/collector-regression1-source.py:32-67`. Their actual recorded3/0 receipt is `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/collector-regression1.json`; they do not test descendant census-before-reap or identify these two PIDs.

Source receipts in JSON contain full exact paths and hashes.

## Preserved joins/acceptance contract

Current group plan requires terminal actor/process-group/adopted-child custody, fixture review before browser execution and fresh actual command exits/nonzero counts with original failures immutable (`docs/plans/m3-managed-h2-group-generation.md:63-73,87-96`). Independent Actor exit/readers/group joins and adopted-child waits are separate roles: predecessor acceptance explicitly reports16 owned Actors exit0/nonforced/readers joined/groups absent, separately22 adopted waits18 exit0/four signal10 (`docs/acceptance/m3-managed-h2-fixed-generation.md:32,37`). The predecessor's failed browser final2 retained forced Actors and all adopted waits as FAIL despite eventual group absence (`:35`). That historical role-specific evidence does not classify current UNKNOWN PIDs or license excluding them.

For the next observation preserve:

1. Existing original command wait/timeout/TERM/KILL/finally behavior; actual exit and wait_error reconciliation.
2. Existing descendant census,15-second absolute cleanup deadline, current TERM/KILL selection,20ms polling, original forced/initial/reaped/remaining fields and every current PASS/FAIL predicate.
3. Actual child waits and process-group disappearance. `/proc` absence alone is not a wait receipt; signal success is not a join. No PID ignore list, executable-based exemption, forcedtrue reset, proc-state shortcut, stale-source acceptance or amended historical FAIL.
4. Current stage remains incomplete even if future observation explains a collector race. No browser/protocol/production gate is inferred from mocked diagnostics or91/0 test output.

## Smallest observational proposal (recommended first)

**Add bounded metadata/events around the existing operations only. Do not reorder waits/signals, add a grace delay, change force flags/verdicts, signal extra targets, or inspect test/Fetch internals.** Root chooses/freeze-reviews the actual diagnostic collector source and unique immutable receipt names before any use. No such collector has been implemented here.

Add one versioned diagnostic field alongside the unchanged cleanup record (or an immutable hash-bound sidecar if volume warrants it). Reuse the same small snapshot/event helper logic in command and browser collectors without introducing a new general process supervisor. All observations use owned descendants only; no host-wide process dump, environment, private keys, raw NetLogs or forbidden raw terminal trace.

### Identity snapshot before every existing signal attempt

For each candidate PID in the existing `children()` result record:

- Sequence number, monotonic nanoseconds and phase (`initial_census`, `pre_getpgid`, `pre_signal`, `post_signal`, `pre_wait`, `wait_result`, `post_wait_census`, `deadline_or_empty_return`). Record collector PID/PGID and immediate command PID separately once.
- Discovery ancestry as actual `(observed_parent,child)` edges with each read time; also current stat PPID. Mark an adopted direct collector child as **current adopted ancestry**, never pretend its original creator can be reconstructed after reparenting. Preserve missing/racing parent/child reads explicitly.
- `/proc/PID/stat`: PID, comm, state, PPID, process group, session and starttime ticks; record source/errors. Parse comm with its parentheses safely rather than splitting the entire line on spaces. Stat field22 is starttime; fields3/4/5/6 are state/PPID/PGRP/session. Use `(PID,starttime)` as observed identity, with boot ID once if available. An unreadable/gone stat is UNKNOWN, not evidence of live/clean/unowned.
- Bounded `/proc/PID/cmdline` as NUL-delimited argv (cap and `truncated` flag); empty is recorded as empty, not guessed from a previous PID. Preserve executable/argv0 and useful command identity; redact secret-valued arguments if present, retain a hash and explicit redaction metadata. Do not read `/proc/PID/environ`, opened files, stack traces or credential files. Optional status is limited to identity/state fields already requested; no dump of arbitrary process state.
- Read stat again after cmdline and immediately before signal; record whether starttime/PPID/PGID stayed consistent and all ESRCH/ENOENT/EACCES races. Record actual `os.getpgid(pid)` result/error alongside stat PGRP, and observed owned group members from the census. This diagnoses reuse/group races; it is not an atomic PID/group pin or permission to signal a mismatched replacement.

Instrumentation must not silently change which existing signals execute. A detected identity mismatch is explicit `diagnostic_incomplete/identity_changed`; root must not call that observation a safe-target proof. A real safety repair to signaling would be a separately reviewed behavior change, not bundled into the observational pass.

### Record every existing signal and actual join

Immediately before the existing `os.killpg`, record intent `{candidate_identity, observed_parent_chain, pgid, signal_number, signal_name, chosen_cleanup_deadline, current_time}`. After the syscall record `returned_success`, `ProcessLookupError/ESRCH`, other exact errno or failure; retain repeated calls even when multiple candidate PIDs share one PGID. Do not count ESRCH as a delivered signal. Also instrument the existing immediate-command timeout killpg loop so command force attempts and descendant attempts cannot be confused.

Record each `waitpid(-1,WNOHANG)` call and result in order: returned PID/raw status, pid0 (`not_ready`), or ECHILD. Decode WIFEXITED/exit code, WIFSIGNALED/signal number and WCOREDUMP where available while preserving the original raw status. Associate a wait with the previously captured identity only when the observations support it; otherwise mark unknown. Capture the owned census after the wait and before return, with actual return reason (`empty` versus deadline), and actual remaining group/census checks. Never replace the existing wait operation with a snapshot/poll claim.

Diagnostic collection must be finite and nonthrowing through cleanup. Freeze explicit byte/event/identity caps for the actual small fixture cohort before execution; record counts, truncation and read errors. On diagnostic saturation stop adding detail but continue the unchanged real signal/wait/cleanup path; mark diagnostic evidence INCOMPLETE rather than silently dropping it or promoting the underlying verdict. Use existing cleanup absolute deadline, not a fresh success deadline per metadata call. Avoid extra subprocesses for metadata; read bounded `/proc` files directly. Metadata necessarily perturbs timing slightly, so even an observed next-run race cannot retroactively establish the old run's unknown identities/ordering.

### Questions this observation can answer

| New recorded facts | Supported conclusion | Still not supported |
|---|---|---|
| Initial stat Z, unchanged PID/starttime, no successful/attempted live-target signal, actual ready wait | That particular observed descendant was already waitable/exited at the sampled phase; existing forced flag was initial-census based. | Historical scoped-initial2 harmlessness or a passing receipt under unchanged rules. |
| Initial/live stat, same identity until TERM/KILL attempt, actual syscall and later wait | Collector really attempted that owned group cleanup while a member was sampled live; exact resulting wait can be recorded. | Delivered signal causality from syscall success alone; production ownership root cause without actor evidence. |
| Identity gone or changed between census/getpgid/signal | A real observation race/identity gap occurred at that phase. | Which historical PID/executable it replaced; guaranteed safe original signal target. |
| Same live identity persists to15-second deadline/remaining set | An owned descendant remains at the collector boundary and the run fails. | Attribution to a particular fixture component without captured identity/ancestry. |

## Optional natural reap-before-force contract — not recommended for the first observation

A future minimal correction could drain already-ready adopted children with nonblocking `waitpid` **before** any cleanup signal, then recensus; this is semantically justified because an already-exited child needs an actual wait, not a force signal. A further bounded natural-wait phase would require a documented actor-exit/join obligation and finite remaining budget, not an arbitrary sleep until tests turn green. It must stay inside the existing15-second overall collector cleanup budget and never restart command/service/protocol deadlines.

Neither change is authorized or applied by this report. With the existing `forced=bool(initial)` unchanged, merely moving waits would still yield FAIL for a nonempty initial census; do not quietly redefine forced to obtain a pass. If root later selects a revised contract, independent SPEC/CODE must explicitly distinguish `initial descendants`, `naturally reaped`, `actual force attempts`, `signal syscall outcomes`, `remaining` and `Actor role joins`; every true force/timeout/unjoined/unknown-owned actor remains failed. Unknown signal10 children cannot be grandfathered into an allowed helper class. Retain original scoped-initial1/2 FAIL receipts/counters and require a fresh source-bound real command after review. This is a bounded collector-contract decision, not a waiver of protocol/actor cleanup.

## Proposed deterministic diagnostic checks (NOT RUN)

No implementation/test execution occurred. If root implements the observation, add focused mocked checks that preserve the existing final verdict/cleanup behavior:

- Exited/Z child in initial census, status0 ready; snapshot is captured before unchanged signal attempt and real wait0 is recorded; forcedtrue remains FAIL.
- Live child sampled, getpgid or killpg races ESRCH; exact failed syscall outcome and later wait are retained; no inferred delivered signal/clean pass.
- Two candidate PIDs share one PGID; record both existing attempts without changing schedule or suppressing duplicates.
- Child appears after initially empty census; attempt is logged although legacy forced remainsfalse; new diagnostics expose the semantic gap without changing the verdict expression.
- Natural exit0 and signal10 waits remain distinct raw/decoded results, with UNKNOWN identity when no stable snapshot existed.
- Parent disappears/adoption/starttime changes; preserve observed ancestry edges/errors and never transfer a prior identity to a new PID.
- Main-command wait raises/timeout signal races; finally cleanup still executes and actual exit reconciliation from the existing3 mocked cases remains intact.
- Snapshot read failure/truncation/event-cap saturation cannot skip real cleanup or manufacture identity/join evidence; diagnostic INCOMPLETE is explicit.

These are collector-only deterministic checks, not another runtime acceptance gate or permission to run a child here. Root must separately freeze/review the resulting source and any fresh actual invocation. Do not explore or repair fixture actor internals on this assignment; the other reviewer owns that attribution.

## Counters, verification and shutdown

Received cumulative group failedGREEN47/root86/orchestration24; stage failedGREEN2/productionRepair1/fixtureRepair2/orchestrationRepair17; Astra2/2 exhausted. This report consumes zero Sol repair-and-validation rounds and zero Astra rounds; no agents spawned. Tests/runtime/build/Git/network/browser/peer operations by this agent:0/NOT RUN. Only bounded file reads/searches and these report writes completed synchronously. No repository/evidence changes and no owned runtime/background command left running. Remaining decision: root selects an observational source change and its reviewed execution inventory; current cause and PID identities stay UNKNOWN until new evidence supports a narrower statement.
