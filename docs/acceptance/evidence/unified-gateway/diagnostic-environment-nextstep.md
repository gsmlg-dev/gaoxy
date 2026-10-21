# H2 CI timer-dispatch qualification: bounded next step

Status: DONE, read-only investigation/recommendation. Current Unit run remains FAIL; no product repair is established or proposed.

Task: `http_composition/h2-ci-environment-nextstep`, direct assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway`, baseline/current diagnostic commit `fd39888412ac5092d63d8ccbba4f1ad51b10c7cc`. Only this report and the separately assigned Unit capture artifacts were written. No source, workflow, Mix, scheduler setting, cache, rerun or publication changes.

## Current evidence and limits

Run39632124759, attempt1, macOS job119332862802 failed at `test/plug_body_test.exs:456`: elapsed105ms <100ms. Timeout result assertion passed. The file executed28 tests (27 passed); the suite executed67 (66 passed) and stopped with113 NOT RUN. Ubuntu executed180/180 successfully. All3 macOS trace collectors reported dropped0.

- Failed H2 Continue: request362→105510us, measured105148us; the dominant off-scheduler interval is `gen.do_call`386→105470us =105084us. The evidence does not show what timeout value reached that call, when its timeout became runnable, or whether the OS/VM delayed dispatch. The core worker owns call-path/OTP semantics investigation.
- Direct H2 passes at98584us, with96319us off-scheduler in `code_server.call`. This proves code-loading-related waiting occurred in that passing case; it does not explain the failed H2 Continue call.
- H1 passes at40697us. Fixture Admission.status8us and sys.suspend12us were fast this time. The historical562ms H1 failure remains unexplained.
- `elixir -v` confirms OTP29, ERTS17.0.2, `[smp:2:2] [ds:2:2:10]`; the workflow sets `ELIXIR_ERL_OPTIONS=+S 2:2`. These are actual configured schedulers, not a measurement of host CPUs or spare execution capacity.
- Runner: macOS15.7.9/24G830, Intel, image20260824.0482.1, westus; the cache restored successfully. No logical-CPU count, runqueue sample or independent timer dispatch measurement exists in the captured log. First-file cold compilation took several minutes, but compilation completed before these measured calls; that fact alone cannot explain the failed call.

Source evidence: `.audit/unified-diagnostic-unit.{metadata.json,raw.log,summary.json}` and `.audit/unified-diagnostic-unit.macos.raw.log`. Existing `scripts/check-tests.py` buffers each complete Mix subprocess output; log-line wall timestamps describe output release, not the original execution time of each trace event. Within-test monotonic microsecond deltas are the usable timing evidence.

## Recommended single controlled diagnostic

Keep the existing macOS image, OTP29.0.2, source behavior, `+S 2:2`, 30ms budgets, strict100/250ms assertions and test ordering. Do not change scheduler count or preload all application modules before this comparison: either would confound the current observation. Do not repeatedly rerun the unmodified CI job.

Add a small same-VM observer to the three already-tagged cases, with the following bounded measurements. This is a proposed diagnostic change for the parent, not executed work or an acceptance substitute.

1. Record `system_info(logical_processors)`, `logical_processors_available`, `logical_processors_online`, `schedulers`, `schedulers_online`, `dirty_cpu_schedulers`, `dirty_cpu_schedulers_online`, plus `statistics(run_queue_lengths_all)` and `statistics(run_queue)` before each case. Record unsupported/unknown values explicitly. Capture `sysctl -n hw.logicalcpu` and `hw.ncpu` once at job setup to distinguish host topology from VM scheduler configuration. Host logical CPUs alone do not establish effective capacity under sharing.
2. Before the measured request, prepare two independent processes and an unresponsive control target. One control performs a plain `receive after 30`; the other performs `GenServer.call(control_target, :probe, 30)` and records the timeout exit. The target must remain alive and deliberately never reply, so a process exit cannot masquerade as a timeout. Warm only the control helper itself before the trial; do not execute the application request as a warmup. Use ready/go handshakes rather than sleeps.
3. Broadcast go immediately before the original request-start marker. Each control records `go_sent`, `go_received`, `timeout_armed`, and `timeout_returned` using the same native `monotonic_time` clock. Record arm delay separately from timer duration. A control scheduled late must not report its arm delay as a long30ms timeout. Preserve the original request timer and elapsed assertion positions; do not wait for control reports inside the measured operation.
4. At control timeout completion, record timestamped `statistics(run_queue_lengths_all)` and `statistics(run_queue)`, plus a bounded `Process.info(test_pid, [:status, :current_function, :message_queue_len, :reductions])` snapshot. Run target queries in a separately monitored helper with a finite report deadline and kill it on collection expiry; do not let Process.info block either timer control. Record timestamps before and after any target query: a delayed query is not a punctual snapshot. Small runqueue samples do not rule out OS descheduling or GC, and the list is not an atomic whole-VM sample.
5. Return control reports through the existing collector/on_exit path after the original assertions. Keep each control and observer finite (for example, a200ms diagnostic collection window and1s cleanup deadline), monitor them, and terminate owned processes in cleanup on both success and test failure. Log missing/late reports explicitly. No high-frequency polling, scheduler binding, priority changes, global tracing or deadline retries.

A separate standalone BEAM preflight can establish that a host sometimes dispatches a30ms timer late, but it runs in a different VM and cannot distinguish this test process's load or this call's timeout accounting. It is weaker than the same-VM comparison and should not replace it. If only a preflight is feasible, label that limit explicitly.

## Predeclared interpretation

| Observation | What it supports | What it does not prove |
| --- | --- | --- |
| Both plain receive and control GenServer timeout return near105ms during the application call | Shared VM/host timer-dispatch delay affects code independent of Gaoxy | Exact timer implementation fault versus OS/VM scheduling; historical failures fixed |
| Both controls return near30ms; test process remains runnable until105ms | Delay specific to scheduling/progress of the test process | That all runtime accounting is correct; status samples can miss transitions |
| Controls return near30ms; test remains waiting substantially past its intended deadline | Investigate actual timeout argument, deadline conversion, nested call behavior and OTP timeout delivery | A product defect without the concrete call-path/timeout evidence |
| Only control GenServer.call is late; plain receive is prompt | Narrow investigation toward call timeout/alias/monitor path and process-local delay | A Gaoxy-specific failure |
| Observer itself arms late or cannot sample until after105ms | The measurement was scheduling constrained; retain those timestamps | That the application ran for105ms on CPU or that its timeout was incorrectly set |
| Application case passes with controls prompt | This controlled attempt did not reproduce the failure | Root cause, historical gate success or permission to relabel prior FAIL results |

If the same-VM control demonstrates a host/VM inability to honor the existing elapsed threshold, qualify an environment that meets the threshold and run the unchanged required suite there; preserve macOS failures separately. If controls are prompt while the request still waits late, combine the core worker's exact timeout evidence with these traces before a surgical repair. A changed environment requires fresh exact-count qualification; one green attempt is not a diagnosis.

## Verification and handoff

Read raw/final CI metadata, trace lines and failure; reviewed existing test runner buffering; verified public runqueue/system-info APIs against local OTP28 source (`lib/erts-16.4.0.5/src/erlang.erl`, runqueue documentation around8890-8950) as background. Proposed qualification is NOT RUN on OTP29/macOS; actual runtime API values and timing remain unknown. No source/Mix/CI command was run for this assignment. All owned commands completed; no active process remains. Sol repair increment0; prior counters remain parent-owned, no Astra counter received, no escalation gate invoked. Parent decision: implement/review one bounded same-VM diagnostic after combining the independent call-path investigation.
