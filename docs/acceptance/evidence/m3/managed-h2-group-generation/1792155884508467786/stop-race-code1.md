# Bounded stop-race CODE/rebind review

**DONE — PASS_BOUNDED_STOP_RACE_CODE_REBIND_READY_FOR_FRESH_GATES.** No actionable findings. This is readiness to execute fresh verification, not runtime or stage acceptance.

Task `/root/group_generation_full_code1`; direct delegated reports-only review after SPEC PASS. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `8131af39a846c292a022ccbfd32c53376cd57887`. Root owns all repository/evidence/Git writes and runtime. Existing root changes were preserved.

## Exact binding

- `proposal`: `fcac05e9ca337ce112f4765ab7aa3bf0588151c35b5dd8cf47b40c9e0a2a0181`
- `candidate1`: `307ea59084be7051a5fa19eceb72524ccd02ee73ed483adabc89d100c5726b1c`
- `candidate2`: `b8ecf718e2ca840cc3099f6efc54583785e93ad20bee1ab6462a1b802a5935de`
- `inventory6`: `e5f06f571e9067b5fd2104db63a8bc8021531071dc92775f224f60d7ba3a93d6`
- `spec1`: `03274564dc349a61ae555c2474bddd9504053417eb5d10552e05cc4ca6ab8ec7`
- `failed_final4_receipt`: `522a233ae76ed567aa6f46832e22972cf11ae58ef993bdf8f3a7c6344630147a`
- `failed_final4_log`: `9a5bbddbed97c86038c0b1d86453d091d356379cfe172fef929d72e3a4465cfa`
- `full_stage_code1_md`: `c1eb7ad3e5825de8ce1f1089548398c06566708aa3f27c170eceb79fc478ce8c`
- `full_stage_code1_json`: `76bfab577ecfb32c27fbfb61ffb816e038d9f268e8747812935c28fe91a8a977`
- `changed_test_before`: `9d8ed544c79c45b8313f8187d68d281ab9f302460f7f9ef70e4e04ce36b28c68`
- `changed_test_after`: `c6e835ea1b5ce084db60a3b84920965ff4cc2660082f3f47490ce21a72179c40`

Independently verified candidate2's **402 source / 9 documents / 458 evidence / 2 protected** hashes with no mismatches. Candidate1 differs only in `apps/gaoxy_http/test/http2_worker_startup_test.exs`; all nine docs, 424 old evidence and two protected entries are unchanged, with 34 evidence additions. Removing the helper and restoring its single call reconstructs the exact old SHA. This explicitly rebinds the prior full-stage CODE to the sole test delta; it does not repeat or expand that full review.

## Code review

**Authentic precondition and cancellation.** Existing retain_native_success3 consumes the genuine startup alias reply in the owner hook, leaving stream3 worker/lease/monitor nil and startup pending while Gate has the original running worker. Existing assertions prove actual worker links and monitors to owner/Gate, exact real drain notification, and no dispatch. Client send_reset sends the real RST after drain. HTTP2 discard sends asynchronous Admission.cancel_spawn with the original token/parent lease, retires aliases locally, cancels startup timer, removes stream3 and clears starting.

**Race and bounded synchronization.** HTTP2 data calls schedule; empty draining state queues h2_close, whose later callback stops owner with shutdown/local_closed. The original worker is linked to owner, so owner termination may precede Gate cancel_operation directly killing the same worker. This is source-supported race diagnosis, not a captured scheduler trace or a production defect claim. New helper monitors worker and installs owner hook before RST. The predicate requires genuine http2/draining/starting:nil/no stream3 state. It holds the owner before its next mailbox loop until observer sees exact original-worker DOWN killed.

**Actual OTP event contract.** ThousandIsland.Handler TCP/SSL data path invokes Gaoxy.HTTP.Connection.handle_data then converts continue into noreply with {socket,state}. Installed OTP gen_server handle_common_reply emits sys:handle_debug({noreply,NState}) before loop. sys handle_debug removes FuncId hook on done and catches/drops exit errors. Inspected both installed OTP28.5.0.2 stdlib7.3 and PATH-resolved OTP28.5.0.5 stdlib7.3.0.1 source read-only, without starting BEAM; runtime identity under nix was not newly executed.

**No dependency cycle or manufactured success.** Gate handle_call verifies original owner/parent lease/token then cancel_operation calls Process.exit(worker,kill) directly; it requires no owner callback. Worker waiting in Stream.run also requires no owner callback to die. Observer releases owner after exact dedicated-monitor DOWN killed, so there is no owner-Gate-test wait cycle. The helper never kills worker, fabricates a receipt or accepts another reason. Its dedicated monitor does not consume the original final monitor receipt. Gate still settles actual DOWN plus EXIT; original later zero/completed/joins remain required.

**Finite cleanup and unchanged acceptance.** New deadline is min(Lifecycle.deadline(existing @wait3000), original drain_deadline), reused for install/cut/DOWN/callback wait; no increase/reset. try/after sends token-scoped release even on failed assertions. on_exit sends release before bounded sys.remove100 when owner alive; dead owner/exit is tolerated only during cleanup. Returning done removes hook. Callback timeout is caught/dropped by sys but cannot satisfy missing cut or exact DOWN assertions. Even late install timeout cannot leave an enduring barrier because its callback deadline is finite. Existing seeded/client/stopper cleanup remains. Exact worker killed, owner local_closed, other original joins, Service zero, no leases/spawns/cleanups/bytes, completed/stop ok, no endpoint dispatch, all actor/port disappearance and exact listener rebind are byte-identical. No retries, skipped checks, alternate reason, production/accounting/cap/grammar/dependency change.

## Evidence and future gates

`scoped-final4` remains **FAIL: 475 tests / 1 failure / exit2**, HTTP260/1 and proxy215/0. Independently read original worker expected `:killed`, actual `{:shutdown, :local_closed}` at helper906. Zero compiler/test warnings, skips or exclusions; one Nix dirty-tree notice. Source stable; process joined; nonforced; no remaining descendants; adopted wait statuses literally `[10,0]`. Later port/rebind checks were not reached in this failed run. Previous missing-fixture errors/warnings remain historical and absent in final4.

Inventory6 preserves all three ordered batch argv versus inventory5, with fresh names `scoped-final5/6/7`, **9+7+17=33 entries /32 distinct existing files**, strict flags and600-second collector deadlines. All three rerun fresh. Format appends only the changed startup file. Compile/two consumers/syntax/final browser argv remain unchanged. Complete startup-file diagnostic `stop-race-green1` is prescribed before final union, after SPEC then CODE, and cannot replace any gate. Diagnostic, fresh batches, five remaining gates and final browser receipts were absent: **all NOT RUN**. Root owns four final browser rows/eight image views.

Prior nonblocking editorial N1 stays pending for final current docs: actual `/new-slice/` plus100 tildes is111 bytes; preserve frozen110-byte historical text/reports. No production/accounting/cap/grammar/dependency change; native95/P/N/W/B and retained lifetimes unchanged.

## Verification, counters and handoff

Read-only source/JSON/hash/map/log/argv/path inspections and reconstruction passed. No tests, builds, browser, network, BEAM or parent-process operations. Two own inspection errors were recovered: receipt-relative log path (exit1), then nonexistent `devenv.nix` included in `rg` (exit2). Both were reported to root; no runtime/mutation effect. Root confirms live **group54/root123/orchestration51/stagefailed9/production2/fixture11/stageorchestration44/invalidRED1/validRED1/Astra2of2**. Frozen proposal/candidate root120/orchestration48/stageorchestration41 remain immutable. Own Sol repair rounds0; no Astra escalation or third recovery.

Only these two `/tmp` reports were written. All own commands finished synchronously; no sessions or actors remain from reviewer; parent processes untouched. No decisions needed. Root next archives reports additively, executes diagnostic then exact inventory6 fresh gates/browser, and completes Task6 docs/custody/localcommit only on actual acceptance evidence. Broader Task5/M3 limits, historical FAIL/UNKNOWN and all operational/publication restrictions remain.
