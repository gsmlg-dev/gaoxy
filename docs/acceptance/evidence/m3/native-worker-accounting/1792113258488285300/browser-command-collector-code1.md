# Browser command collector actual CODE1

Task ID: browser_cohort_code/browser-command-collector-CODE1. Direct, independent source-only review. **DONE review; verdict FAIL.** One actionable shutdown finding. No runtime, tests, Git or network command ran. Root retains sole ownership of repository/runtime/evidence/Git; only the assigned /tmp Markdown and JSON reports were written.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Saved baseline `58307a7084298db309a93697b9102b2cc4c87eda` was not refreshed with Git.

## F1 — timeout cleanup does not join the runner's separately session-owned actors

Severity: material lifecycle/verification defect. Location: `browser-command-collector1.py:48-59,63-64,75-77`.

The collector launches runner6 in a new session, waits600 seconds, then sends TERM/KILL only to `process.pid` as a process-group ID. It considers only that runner group when recording owned_group_gone. However, runner6 `Actor.__init__` at lines235-236 starts each peer, native host and browser actor with its own `start_new_session=True`. Those groups are not members of the runner's group. Killing the runner with the default TERM action also bypasses its Python run_case finally at lines437-451, which normally calls each actor's dispose/join.

A concrete surviving actor is the raw peer: after runner termination closes its control stdin, runner6 lines93-103 raise in its control thread without setting stopping; the peer main thread continues the accept loop at lines107-115. No collector code signals or joins that separate peer group. Therefore a timeout may finish the collector and record runner joined/owned_group_gone while a command-owned peer still runs. This violates the requested finite actual joins and safe shutdown; it cannot be treated as complete owned-process cleanup.

Required correction: retain the hard deadline and FAIL result, but arrange bounded shutdown and actual joins for every separately owned actor/session before killing or completing the outer runner. A cooperative runner abort path or an authenticated child-group inventory can supply this; do not weaken the forced-cleanup failure predicate. Source review must verify the chosen path actually reaches each actor group and confirms termination. No implementation was performed by this reviewer.

## Other reviewed behavior

The PASS predicate requires no timeout, actual exit0, joined runner and absent runner group, stable before/after source hashes, qualification statusPASS, exactly2 executed/case rows, H2+H1 modes and both casePASS. It also checks all reported join rows for exit0/nonforced/reader_joined/owned_group_gone, then verifies the reported artifact hashes. A failed runner exit cannot become collector PASS through a qualification PASS alone. The qualification/log identities and source snapshots are recorded, and receipt/log/directory collision guards preserve old evidence. These guards do not repair F1, because they do not enumerate or control detached actor groups on timeout.

Frozen collector SHA256 before/after: `98ae90f1d6c388b4c14660313f683c57c93289ecb34437fe088ba7a0154ee523`. Supporting runner6 SHA256: `649b61d108ecb291f411d6029f41bfcd1d352e4bbff292b965b699b5393c5dc2` (matches prior reviewed tuple). Verification consisted of numbered source reads and Python SHA256 equality assertions, all exit0; no collector/runner/peer code was executed.

All own commands finished; no owned process remains running. Counters unchanged: group37/root48/stage7/Astra2of2 exhausted/nonaccepted diagnostic failures4. Added runtime attempts0, Sol repair rounds0, Astra recoveries0; astra_gate none. No new user decision or permission is needed. Root can make the bounded fixture/collector shutdown repair and request a source re-review. Prior bounded browser-cohort fixture CODE PASS is unchanged; this FAIL applies only to its new outer collector.
