# Service-stop race diagnosis1

DONE — source diagnosis/proposal only. Root owns implementation and runtime.

Worktree `.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `8131af39a846c292a022ccbfd32c53376cd57887` (parent-confirmed; no Git). Actual scoped-final4 receipt SHA256 `522a233ae76ed567aa6f46832e22972cf11ae58ef993bdf8f3a7c6344630147a`; log SHA256 `9a5bbddbed97c86038c0b1d86453d091d356379cfe172fef929d72e3a4465cfa`.475 tests/1failure/exit2: HTTP260/1, proxy215/0, zero skips/exclusions/compiler-test warnings, stable/nonforced/clean. Nix dirty-tree notice remains. Sole worker906 expected`:killed`, actual`{:shutdown,:local_closed}`; later ports/rebind checks were not reached.

## Diagnosis

Fixture has two valid competing terminal paths, but asserts one without ordering them. Retained authentic success leaves owner unaware of worker PID. After genuine service drain, RST sends asynchronous Gate cancel and deletes last stream; empty draining owner queues h2_close. Owner shutdown/local_closed may propagate through existing worker link before Gate executes its kill. Actual final4 worker reason matches this source-supported race. No ownership/accounting leak or production close defect is shown; no scheduler event trace was captured in final4.

## Concrete source anchors

- `apps/gaoxy_http/test/http2_worker_startup_test.exs:709-769`: Authentic success retained/consumed; owner stream3 still worker:nil/startup present, while Gate has actual running worker.
- `apps/gaoxy_http/test/http2_worker_startup_test.exs:773-814,929-963`: Actual Gate running phase/lease and waiting Stream.run links+monitors; exact service drain message observed before RST.
- `apps/gaoxy_http/test/http2_worker_startup_test.exs:824-907,1030-1035`: Real stop; client RST after drain. All-zero/completed/stop:ok/owner reasons precede sole worker reason906 failure. Later port/rebind assertions not reached.
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:283-285,1230-1241,1333-1384`: RST discard sends async cancel_spawn; receive_response(cancel,0) does not await cancellation. stream.worker:nil prevents direct kill; deletes stream and clears starting.
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:109-116,851-875,965-968,1150-1163`: Data parsing schedules; draining+empty streams/output queues genuine h2_close; processing it stops owner shutdown/local_closed.
- `apps/gaoxy/lib/gaoxy/admission.ex:171-181,352-359,640-645`: Drain notifies real leases; actual cancel validates owner/parent/token then Process.exit(worker,:kill).
- `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex:7-14,67-79`: Worker linked to owner, waiting real dispatch. Owner abnormal shutdown propagates link before Gate kill if close wins.
- `apps/gaoxy/lib/gaoxy/admission/worker_bootstrap.ex:5-15`: Actual admitted bootstrap also links owner before applying Stream.
- `apps/gaoxy/lib/gaoxy/lifecycle.ex:136-166`: Real drain waits actual Gate leases/cleanup zero then backend normal shutdown; no single worker-reason requirement.
- `apps/gaoxy/lib/gaoxy/service.ex:270-282,516-543`: Admission drain barrier before finite lifecycle coordinator.
- `apps/gaoxy_http/test/http2_worker_startup_test.exs:577-653`: Working nearby retained-success cancellation keeps owner non-draining/alive with streams5/7 and resumes Gate before exact oldworker:killed.
- `apps/gaoxy_http/test/http2_worker_startup_test.exs:659-705`: Separate actual owner-death case does not pin worker reason; validates distinct linked-owner terminal path.
- `apps/gaoxy/test/admitted_spawn_test.exs:966-1022`: Existing finite genuine :sys debug terminal barrier; {:in,{:"$gen_call",...}} and {:noreply,state} event shapes. Startup709-754 already uses owner {:noreply,{socket,state}} hook.

## Smallest bounded fixture fix

1. Limit repair to service_stop_case(:dispatch_wait) and finite test helper/cleanup. Before reset establish a SECOND dedicated Process.monitor(worker); retain original monitors map untouched for exact final service_stop_joins assertions.
2. After actual assert_native_draining_dispatch_wait!, before send_reset, install one-shot :sys owner debug hook. Match genuine post-RST {:noreply,{socket,%{phase: :http2,draining:true,starting:nil,streams:streams}=state}} with stream3 removed/expected final streams empty. Signal tokenized ready with exact state and hold original owner continuation before next mailbox input. Do not consume/replay/inject genuine h2_close or cancel request; state remains unchanged.
3. Send original TCP RST once; wait for ready and dedicated exact worker DOWN:killed while Gate runs freely. Explicitly release owner only after that evidence; retain original final worker monitor for existing reason906:killed. Use ORIGINAL finite drain deadline (and request deadline/remaining @wait bounds as applicable), no increased timeout or renewed waits. No sleeps/retries/alternate reasons/direct actor kill.
4. After release, genuine queued h2_close proceeds. Preserve owner shutdown/local_closed, writer normal, empty Gate killed, server/Service/backend normal, completed telemetry, stop:ok, no endpoint dispatch, Gate/owner zeros, port closure and exact listener rebind. pending_activation:killed and endpoint_blocked:normal remain unchanged.
5. Register cleanup before reset: on_exit/after always send matching owner release FIRST; remove hook only after unblocked/if alive under finite timeout. Demonitor+flush only dedicated extra monitor. Keep original Gate release/resume cleanup. Never issue synchronous sys get/remove against owner while held. Hook must bound receive by original finite deadline and release/fail explicitly on expiration; fallback teardown is never acceptance.

## Validation and review

- Actual scoped-final4 FAIL475/1 is the observed failing reproduction. Root explicitly selected the deterministic post-RST barrier; do not require speculative repeated reruns or additional diagnostics before this fixture edit.
- If root elects a separate causal diagnostic, force competing schedule by holding the authentic Gate {:in,{:"$gen_call",{owner,_},{:cancel_spawn,parent,token}}} before actual cancellation callback, then real RST/owner close. Record real reasons and release Gate in after. This is optional diagnostic, not acceptance, and must not replace actual failure evidence.
- Freeze minimal test-only diff; independent bounded SPEC/CODE review must check exact cut/token/state, dedicated pre-reset monitor, original finite deadline, unconditional release/remove, and unchanged reason/zero/join/rebind assertions. No production constructor gate needed if only fixture synchronization changes.
- Root focused startup three-stage/whole startup and stale-start compatibility checks must execute nonzero tests and preserve exact assertions, then fresh affected final union/static/browser/consumer gates with explicit candidate rebind. Prior candidate307ea590 reviews remain historical; new test bytes need additive rebind/re-review. Passing focused test is not stage acceptance.
- No production edit, alternate reason acceptance, timeout increase/retry, manual worker kill or fake cancellation/state/receipt is indicated. Source/disk/index/local-commit and wider stage acceptance remain pending.

Root concurrently applied/formats the test-only barrier. Historical receipt source hash for startup test is `9d8ed544c79c45b8313f8187d68d281ab9f302460f7f9ef70e4e04ce36b28c68`; report-time root-edited hash is `c6e835ea1b5ce084db60a3b84920965ff4cc2660082f3f47490ce21a72179c40`. These are distinct; pre-edit line anchors must not be presented as post-edit verification. Other source bindings are in JSON.

Read-only command errors preserved: mistaken `apps/gaoxy/test/admission_test.exs` rg exit2, recovered via rg --files/exact admitted_spawn reads; first report script exited1 on source hash assertion because root concurrently edited startup test, before any reports were written. Parent confirmed normal callback-name rg no-match exit1 is informational. All remaining commands exited0; worker runtime tests0/source repair rounds0. All commands finished, no own background sessions.

Latest parent counters group54/root119/orchestration47/stagefailed9/production2/fixture10/stageorchestration40/invalidRED1/validRED1/Astra2of2; concurrent-edit report assertion exit1 separately reported, totals parent-owned. No reset/new Astra. Only assigned two /tmp reports written; no repository/Git/runtime/network mutations. Forbidden raw trace/NetLogs/keys unread. Decisions needed:none.
