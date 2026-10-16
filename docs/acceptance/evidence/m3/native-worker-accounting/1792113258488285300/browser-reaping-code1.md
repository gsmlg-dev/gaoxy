# Browser child-reaping CODE review 1

**PASS — bounded CODE review; no actionable findings.** Task `browser_cohort_code/browser_reaping_code1` is DONE as a direct independent read-only assignment. This is not browser acceptance.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; saved baseline `58307a7084298db309a93697b9102b2cc4c87eda`. All twelve frozen candidate SHA256 identities match before and after review; the full manifest is in the companion JSON. Only these two `/tmp` reports were written.

Runner8 enables checked Linux child-subreaper ownership before starting Actors. Its reaper enumerates direct owned children and calls exact-PID nonblocking `waitpid`, adding no signals. Live registered primary Actor PIDs remain excluded, preserving each Popen's poll/wait ownership; registration occurs before the reader starts. Reaping runs on the main thread. Synchronous helper subprocesses complete before reaper calls.

The finite natural adopted-child drain lets already-exited Chrome internals be joined before the existing group-disappearance check. Primary Actor exit 0, nonforced shutdown, joined reader and absent owned group remain required. Final remaining adopted children make qualification FAIL. Internal descendant raw wait statuses and converted exits are recorded separately from primary Actor exits. This does not require every Chromium internal subprocess to exit 0 or misreport its status as a primary normal exit.

Static AST extraction confirms the complete BROWSER literal is identical in runner7 and runner8. The changed fixture retains native/protocol/browser assertions. Production, host6, cohort3, collector3, scoped collector4 and the previously reviewed 95-checkpoint source identities are unchanged.

The saved real OS regression is correctly bound to both runner hashes and its script hash. It records runner7 EXPECTED_RED with the original owned-group assertion failing after primary exit 0; explicit test cleanup then actually waits the adopted child to exit 0. Runner8 records primary exit 0, forced false, joined reader, absent group, exact adopted-child wait status 0 and no adopted children remaining. This infrastructure evidence was inspected, not rerun; it does not execute Gaoxy or Chrome.

Verification: source/diff/contract inspection PASS; AST identity PASS (exit 0); receipt source/script hash binding PASS (exit 0); twelve final hashes PASS (exit 0). An earlier optional source lookup exited 2 solely because `/usr/lib/python3.13` was absent; installed-source paths were found. No test, runtime, browser, Git or network commands were run by this reviewer.

Historical browserGREEN4 remains FAIL, H1 NOT_RUN; its seven outer-collected internal statuses remain six exit 0 and one signal 10. BrowserGREEN2's underlying cause remains UNKNOWN. NativeGREEN5's existing PASS 94/0 is separate evidence and was not rerun.

Fresh complete H2/H1 browser qualification remains required. No decisions are needed. Counters remain group40/root52/stage10/Astra2of2 exhausted, nonaccepted diagnostics4; review adds zero repair/runtime rounds. All reviewer commands have finished; no fixture process was launched.
