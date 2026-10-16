# Browser command collector actual CODE2

Task ID: browser_cohort_code/browser-command-collector-CODE2. Direct independent source-only bounded correction review. **Review complete; verdict FAIL.** Collector2 addresses original detached-session ownership on its reached cleanup path, but a material timeout race still bypasses that cleanup.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; saved baseline `58307a7084298db309a93697b9102b2cc4c87eda` (Git refresh prohibited). Root owns all repository/runtime/evidence/Git actions. No repository/evidence edits, fixture execution, tests, Git or network command ran. Only these two assigned /tmp reports were written.

## F2 — a disappearing runner group bypasses descendant cleanup

Location: `browser-command-collector2.py:98-108`, especially unguarded `os.killpg` at102 and106. Severity: material shutdown defect.

`process.wait(timeout=600)` can raise TimeoutExpired immediately before the runner and its group exit. `os.killpg(process.pid, SIGTERM)` then raises ProcessLookupError. The analogous race exists between the ten-second wait timeout and SIGKILL. Neither call catches that ordinary already-gone condition, and `cleanup_descendants()` is not in a finally block. Thus the collector exits before line108 instead of cleaning and reaping adopted detached peer/host/browser sessions. Those sessions are outside the runner group, so its disappearance does not establish that descendants are gone. No actual receipt is written on this path.

Required targeted correction: after successful process launch, ensure finite descendant cleanup runs in a finally covering all wait/signal outcomes, and tolerate an already-gone runner group while still collecting the runner's actual status. Preserve timeout/forcing as FAIL and incomplete reaping as failure. Do not convert missing cleanup into PASS or extend runtime deadlines. Root's separate detached-grandchild regression should also cover the already-exited-group timeout branch. No code change was made by this reviewer.

## Source-reviewed correction and retained guards

- PR_SET_CHILD_SUBREAPER is set before launch and checks its return. The cleanup scan begins at this collector's /proc children rather than a global process-name/user scan. Repeated discovery covers independently sessioned descendants after runner death; waitpid records actual adopted-child reap statuses. The cleanup path tolerates descendants disappearing between discovery and signaling. The new function has a finite15-second budget with TERM then KILL, and checks for remaining descendants. This is source evidence, not a Linux runtime regression result.
- Ordinary runner exit now also enters descendant cleanup. Existing descendants mark forced and therefore reject PASS; remaining descendants also reject PASS. The original outer FAIL-on-timeout/nonzero-exit, two exact H2/H1 PASS cases, source stability, reported normal actor/group/reader joins and artifact-hash checks remain unchanged. Source comparison against collector1 and AST parsing found only the intended additions.
- Signal targets are derived from descendant process groups, and the collector rejects its own group. This review found no global/unrelated-process scan. The F2 exception path must be closed before claiming bounded command-owned shutdown.

Collector SHA256 before/after: `3b59697e5494a1b9a15d7c042d0a8e76bbc038d0eec7d3d9e7566dd2a5ebd76a`. Verification: numbered collector source read, supporting runner detached-session/cleanup reads, source-only unified diff versus collector1, Python ast.parse and SHA256 equality checks; all commands exit0. No code under review executed. Root's planned real detached-grandchild regression is NOT RUN by this reviewer.

All own commands finished; no owned process remains running. Counters received unchanged: group38/root49/stage8/Astra2of2 exhausted/nonaccepted diagnostic failures4. Added runtime attempts0, Sol repair rounds0, Astra recoveries0; astra_gate none. Root reports GREEN3 FAIL on late pre-admission peername MatchError with owned groups gone; that runtime cause and fixture repair are outside this collector-only review. No new user decision or external permission is needed for the targeted collector repair. Prior cohort-fixture CODE PASS remains separate.
