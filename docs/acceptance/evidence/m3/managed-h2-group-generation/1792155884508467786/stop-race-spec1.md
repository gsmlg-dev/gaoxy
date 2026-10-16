# Bounded stop-race SPEC source rebind

Task `/root/group_generation_full_spec1` / `gaoxy-group-generation-stop-race-spec1`. **DONE — PASS_BOUNDED_STOP_RACE_SPEC_REBIND_READY_FOR_CODE**.

No actionable findings. The fixture-only synchronization holds the real native post-RST callback until Gate cancellation kills the original worker. It preserves exact original terminal assertions and finite deadlines. This report rebinds only the explicit test delta; it is not a new full-stage acceptance or runtime pass.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation` confirmed by pwd. Branch `codex/m3-h1-resource-foundation`, baseline `8131af39a846c292a022ccbfd32c53376cd57887` from parent/frozen manifests; no Git operation run. Root remains sole repository/evidence/Git/runtime writer/operator.

## Exact bound hashes

- proposal: `fcac05e9ca337ce112f4765ab7aa3bf0588151c35b5dd8cf47b40c9e0a2a0181`.
- candidate2: `b8ecf718e2ca840cc3099f6efc54583785e93ad20bee1ab6462a1b802a5935de`.
- inventory6: `e5f06f571e9067b5fd2104db63a8bc8021531071dc92775f224f60d7ba3a93d6`.
- failed_final4_receipt: `522a233ae76ed567aa6f46832e22972cf11ae58ef993bdf8f3a7c6344630147a`.
- failed_final4_log: `9a5bbddbed97c86038c0b1d86453d091d356379cfe172fef929d72e3a4465cfa`.
- test_before: `9d8ed544c79c45b8313f8187d68d281ab9f302460f7f9ef70e4e04ce36b28c68`.
- test_after: `c6e835ea1b5ce084db60a3b84920965ff4cc2660082f3f47490ce21a72179c40`.

Candidate2 source402/documents9/evidence458/protected2 hashes all match. Compared with candidate1: sole source change is http2_worker_startup_test.exs, all9 docs/all424 prior evidence/all2 protected unchanged,34 evidence additions. Reconstructing the old file by removing the new helper and restoring exactly one call yields the precise before hash. No prior assertion, production/accounting operand/cap/grammar/dependency or runtime code changes.

## Failure and cancellation trace

Underlying log independently confirms one service_stop dispatch_wait failure at original helper906: expected reasons[worker] :killed, actual {:shutdown,:local_closed}. All12 previous missing-fixture errors and6 warnings absent. Log hash equals receipt; receipt equals repair-proposal hash. No failed receipt reclassified.

Actual final4 remains FAIL475/1/exit2 (HTTP260/1,proxy215/0), zero compiler/test warnings/skips/exclusions; source stable/process joined/nonforced/no residue. Previous missing-fixture errors/warnings resolved but final4 is not a pass.

### Retained genuine startup success

Existing retain_native_success3 consumes original alias reply inside native debug callback but leaves stream3 worker/lease/monitor nil and startup pending. Gate phase actually running with original worker/lease; assert_running_dispatch_wait! confirms worker links/monitors to owner/Gate and no dispatch. Service drain notification is retained at real worker wait; no fake startup/public receipt.

### Real RST cancellation

send_reset sends actual type3 CANCEL frame over client socket. ThousandIsland Handler handles TCP/SSL data→Gaoxy.HTTP.Connection.handle_data→HTTP2.Connection.data/parse→receive_frame type3→discard. discard calls cancel_start for original startup, which sends Admission.cancel_spawn via gen_server.send_request, retires aliases locally, cancels startup timer and removes stream3/starting; it does not synchronously wait for Gate.

### Competing valid terminals

Gate handle_call authenticates original owner/parent_lease/token; cancel_operation directly Process.exit(worker,:kill), marks cancelled and settles only after actual DOWN plus EXIT. Concurrent native schedule detects draining+streams empty and queues :h2_close; next info returns stop {:shutdown,:local_closed}. WorkerBootstrap/Stream links original owner, so native owner exit may reach worker first. That explains the original exact-reason race without production defect claim.

### Valid genuine callback boundary

Helper creates dedicated Process.monitor(worker) before RST and installs owner sys hook before sending actual frame. ThousandIsland handle_continuation transforms {:continue,state} to {:noreply,{socket,state}}; installed OTP gen_server source emits {noreply,NState} via sys:handle_debug before next loop. Predicate requires phase http2/draining true/starting nil/no stream3; this is real post-removal state, not a synthesized notification.

### No wait cycle or alternate kill

Native owner waits only for token-scoped release in its post-RST callback. Gate cancellation directly kills the linked worker and needs no owner callback. Test observer waits exact dedicated original-worker DOWN :killed, then sends release. It never kills worker itself or substitutes another reason/receipt. Original final worker monitor stays separate and still must observe exact :killed; all other original joins/zero/completed/rebind assertions remain.

### Finite cleanup and hook disposal

Deadline is min(original drain_deadline, Lifecycle.deadline(existing @wait3000)), reused for installation/cut/DOWN/callback wait; no reset/extension. try/after sends release on success or failed assertions; registered on_exit also sends release and bounded sys.remove100 if owner alive. Successful callback returns :done, which sys removes automatically. sys catches callback timeout exit and drops hook; observer still requires cut and exact DOWN within deadline, so timeout cannot become pass. Original seeded/client/stopper on_exit and final actor joins remain. No enduring block or fake completion introduced.

## Inventory and required runtime

All existing paths/order/strict --warnings-as-errors and --max-cases1 flags unchanged; no skips/exclusions/filters. Existing fixture-defining file remains in batches1/3.

Fresh final5/final6/final7 preserve exact inventory5 argv in9+7+17 files,33 entries/32 distinct, all exist. Collector names updated. All three batches rerun for changed source; no prior batch pass borrowed. Format adds precisely the changed startup test. Compile/core consumer/HTTP consumer/syntax and final browser argv remain unchanged. All future paths unused at inspection.

Complete startup test file diagnostic with same strict flags, distinct stop-race-green1 name, only after bounded SPEC→CODE; NOT RUN. Does not replace any full batch/final gate.

browser_initial remains old pre-execution snapshot; actual initial browser-green4 PASS4/8 separately recorded. Neither replaces fresh finalbrowser.

## Review conduct, counters and shutdown

Candidate2 all402source/9docs/458evidence/2protected hashes match. Candidate1 maps unchanged except sole exact source delta and34 additive evidence entries. Reconstructed exact old test hash matches. Actual failed log/receipt verified. Inventory union/argv/format/future-name checks pass.

One rg regex used unescaped { and printed regex parse error; enclosing multi-command shell later exit0. Corrected immediately with rg -F; no mutation/runtime effect. Explicitly reported to root, which advanced live root121/orchestration49/stageorchestration42. All other inspections completed successfully.

Frozen proposal/candidate2 counters remain `{"group_failed_green": 54, "root_failure_events": 120, "orchestration": 48, "stage_failed_green": 9, "stage_production_repair": 2, "stage_fixture_repair": 11, "stage_orchestration_repair": 41, "stage_invalid_red": 1, "stage_valid_red": 1, "astra_used": 2, "astra_limit": 2}`. Parent-confirmed live counters after own inspection error: `{"group_failed_green": 54, "root_failure_events": 121, "orchestration": 49, "stage_failed_green": 9, "stage_production_repair": 2, "stage_fixture_repair": 11, "stage_orchestration_repair": 42, "stage_invalid_red": 1, "stage_valid_red": 1, "astra_used": 2, "astra_limit": 2}`. Own Sol repair rounds0; received Astra2/2 exhausted; no escalation gate.

pwd; rg/rg --files; bounded sed; Python JSON/hash/log/difflib/argv/path inspections. Read only installed gen_server/sys source and public dependency adapter source to verify event contract. No Git/runtime/build/browser/network invocation.

All own commands finished synchronously; no runtime/session actors launched; parent processes untouched. Only the two assigned `/tmp` report files were written. No raw private trace, NetLogs or keys read.

Archive reports additively; bounded CODE against exact unchanged candidate2/proposal/inventory6, then complete startup diagnostic, fresh all3 batches, remaining5 gates/freshbrowser4/root8views and Task6 custody/localcommit.

Decisions needed: none. All new diagnostic/runtime/final gates remain NOT RUN; history and pending editorial N1 remain preserved.
