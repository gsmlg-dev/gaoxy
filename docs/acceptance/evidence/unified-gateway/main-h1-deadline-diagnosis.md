# Attempt 2 H1 Continue deadline diagnosis

Task: unified-main-h1-deadline-diagnosis — DONE, direct read-only Sol investigation.
Source/worktree: 2539b3c400231c079eda7ad60f1c343101227eca in /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway.
Compared baseline: 656dbf5bb84564adc6a4d68247c0ad2fe52c2625; PR head: 2078ee8e18d7238a77ddfb043d21385bfb400439.
Owned outputs: this report and corresponding JSON only. No source/test/workflow/dependency changes or root Mix commands.

## Established failure and limits

Unit run39627273984 attempt2, macos-15-intel / Elixir1.20.1 / OTP29.0.2 / +S 2:2, failed the existing H1 test at plug_body_test.exs:321. The expected {:error,:timeout} assertion at line333 passed. The elapsed assertion at line334 observed562ms against unchanged <250ms. Result:27/28 passed; required-file wrapper exited1. Raw evidence: .audit/unified-main-unit-failure-attempt2.log.

This is distinct from attempt1's H2 elapsed104<100 failure. The H2 case passed during attempt2. Both failures remain FAIL.

The failure happened before line335, which requires {:native_read_result,{:error,:timeout,%{expect_sent:true}}}, and before the post-resume retained-byte/send-token assertions at lines340-341. Therefore this failed execution does not establish whether the Continue-specific native path was entered, nor whether its final cleanup assertions passed. The after block still resumes the gate. Do not infer unexecuted assertions as passing.

## Fixture seam inside the measured interval

The H1 test starts its30ms absolute request deadline before calling PlugAdapter, and measures the whole call. Its GateDelayTransport fixture performs two synchronous coordination operations inside that interval:

- Admission.status(gate): plain GenServer.call with default5000ms timeout (admission.ex:69).
- :sys.suspend(gate): system call with its default timeout, no request-deadline argument (test lines28-29).

The fixture sends :native_gate_suspended only after those calls, then delegates to native Exchange.read_body_step with transport:nil. Neither coordination call is bounded by the30ms request deadline. A delay in either fixture call or caller scheduling can consume the elapsed envelope before native Continue processing. This is a concrete measurement ambiguity, not evidence that either call actually consumed the562ms on attempt2; no per-phase timestamps or scheduler trace were captured.

Unlike the H2 case, suspension occurs inside the measured Plug read, after PlugAdapter's initial body reservation. This placement deliberately ensures the adapter has charged its body buffer before the native operation encounters a suspended gate.

## Production H1 path and cleanup

1. PlugAdapter.read_req_body/2 computes body demand and checks the hard deadline. reserve_body/2 calls Exchange.update_body_retention/2, using Admission.update/4 with only the remaining original deadline. Then Exchange dispatches to GateDelayTransport. The fixture's status/suspend work described above runs next.
2. On return to native Exchange.read_body_step/4, an already-expired original deadline immediately returns {:error,:timeout,exchange}. In that early path expect_sent remains false. Attempt2's assertion order does not distinguish it from the intended Continue-specific timeout path.
3. If the original deadline still has time, maybe_continue/1 sets expect_sent:true and send_continue/1 attempts the informational head. Before writing, send_continue/2 first calls update_body_retention/2 to charge the pending bytes. Because the fixture suspended the gate, that call waits for at most Lifecycle.remaining(original_deadline), then converts timeout into {:error,:timeout}. There is no new relative30ms allowance.
4. This intended suspended-gate failure occurs before Admission.start_send_until/5, socket option setup or any wire send. If registration were reached through another schedule, start_send_until/5 also uses the original absolute deadline and its timeout cleanup uses finish_send_async/4.
5. send_continue/2 restores native retention. Once the deadline expires, update_body_retention returns timeout without blocking; defer_body_retention queues cleanup with send_request and receive_response(...,0).
6. PlugAdapter.body_error/2 clears adapter_body_bytes through release_body/1. Its expired-deadline update also queues deferred retention cleanup, then returns the original timeout. Updates from the caller remain ordered at the gate. After :sys.resume, the test's status request would observe that cleanup ordering, but those post-resume assertions were not reached on attempt2.

All production blocking admission updates in this path use remaining(original_deadline). The inspected source contains no562ms allowance or reset explaining the measurement. A BEAM timeout remains subject to runnable-process/timer dispatch; the surrounding fixture also has waits outside the30ms budget. The current evidence cannot apportion562ms among them.

## Source and environment evidence

- Entire plug_body_test.exs blob is91dee3dd7072e2e0a620beec413f375109156b4e at baseline656dbf5b, PR2078ee8e and main2539b3c4.
- PlugAdapter, Admission and Lifecycle are byte-identical baseline-to-main. Exchange's only change is adding discovery:nil to its struct; H1 read, Continue, retention and cleanup functions are unchanged.
- PR2078ee8e and main2539b3c4 share entire Git tree74e3b6688f3e5648fdf23c87d96aa4d4f95f9c51. Integration was a normal merge.
- Baseline macOS Unit39557078592/job119082725013 passed all28 plug-body tests (3.3s). PR2078 macOS Unit39624808585/job119307220228 passed all28 (3.4s). These hosted results were read and verified during the preceding H2 diagnosis.
- Parent's fresh local full-file evidence .audit/unified-main-local-deadline.log is28 tests /0 failures, seed0/max_cases1,2.1s. This is local evidence, not a macOS hosted substitute.
- Attempt2's first cold compilation occupied about378s between the first REPAIR_COMMAND and first suite output. mixed_connection_lifecycle took5.7s, versus3.0s in attempt1; plug_body took5.2s versus3.5s. These show a slower execution, but do not prove CPU steal, scheduler starvation, timer failure or any particular cause.
- The tests already use max_cases1. Changing that value cannot further serialize this suite. No CPU scheduling, per-phase wall times, process reductions, gate latency or scheduler heartbeat was recorded.
- The http_fetch compile warning in attempt2 is a separate dependency warning; the executed job failed on the H1 elapsed assertion. No new upstream defect is established by this investigation.

## Minimal evidence-based next action

Do not launch a blind third identical job or weaken either elapsed cap,30ms deadline, expect_sent assertion, cleanup assertion or executed-test requirement.

The smallest useful next execution is one bounded diagnostic run on the same macOS/Elixir/OTP configuration, preserving the exact original file and assertions, with an audit-only wrapper/trace recording:

- Monotonic call/return timestamps for initial adapter reservation, fixture Admission.status, fixture :sys.suspend, native Exchange entry, native retention timeout, deferred release and Plug return.
- The original deadline and remaining budget at those boundaries, whether expect_sent became true, gate resume and final retention/send-token observations even when the earlier elapsed assertion fails (record separately; do not count these as original test assertions).
- Low-volume caller scheduling events or an independent monotonic heartbeat to detect scheduling gaps overlapping the562ms-style measurement, plus host/toolchain/source identity. Trace overhead must be disclosed; this diagnostic run is not replacement acceptance evidence.

Use that result to select a repair or environment action. If the delay is in fixture coordination, correct the test setup/synchronization without removing any cap, moving the request deadline later or narrowing what the original elapsed assertion measures; validate that native expect_sent and cleanup behavior remain exercised. If the caller is demonstrably descheduled, obtain a healthy same-platform execution environment and run the unmodified required job once after that evidenced environment change. If the native path itself violates its remaining-deadline bound while scheduled, repair the specific production operation with a deterministic regression and rerun the original full required gate.

No concrete source or CI patch is justified yet. The required merged-main macOS gate remains FAIL/unresolved; neither earlier successes nor local28/0 resolve it. If the same-platform diagnostic cannot be arranged within the current environment, report that environment limitation explicitly and continue only other unblocked qualification work. Existing continuing authorization covers this bounded diagnosis; no routine approval pause is implied.

## Execution status

Read-only source/log inspection and Git identity comparisons completed. Only the two assigned audit reports were written. No third rerun, root Mix, tracked edit or repair attempted. Sol repair increment0; no Astra gate invoked. Public Hex consumers remain prepared pending parent publication signal.

## Parent diagnostic proposal assessment

Parent proposed test-only instrumentation of the existing three suspended-owner/delayed-gate cases, preserving all28 tests, assertions, deadline values and elapsed thresholds. A bounded tracer records only each test caller's :running/:monotonic_timestamp events; GateDelayTransport records status/suspend/native phase timestamps; on_exit emits a compact report. Assessment: appropriate diagnostic next execution, provided the tracer has finite lifetime/event storage, explicit dropped-event accounting and delivery/flush before reporting. No global call patterns or module warming are needed.

An out-to-in scheduling interval includes intentional blocked GenServer/timer waits. Label it an off-scheduler interval and correlate with phase timestamps; do not report it alone as proof that a runnable caller was starved. This is diagnostic instrumentation, not a production repair or acceptance replacement. Parent owns implementation; its diff and actual output have not yet been reviewed here.
