# Merged-main macOS H2 Continue deadline diagnosis

Task: unified-main-deadline-diagnosis — DONE (read-only direct Sol investigation).
Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway
Current source: 2539b3c400231c079eda7ad60f1c343101227eca
Compared baseline: 656dbf5bb84564adc6a4d68247c0ad2fe52c2625
Compared PR head: 2078ee8e18d7238a77ddfb043d21385bfb400439
Owned output: this report only. No source, tests, workflows, locks or dependencies changed; no root Mix command executed.

## Finding

An unchanged-job rerun is justified as a diagnostic. The failed assertion is an existing short elapsed-time check, and the same complete source tree passed the same hosted macOS job immediately before the normal merge. There is no evidence that this task changed the suspended-owner Continue deadline path. Preserve the original main failure as FAIL; a rerun is fresh evidence, not a replacement for its history.

The original result is a real failure: Unit run39627273984 on main2539b3c4, macos-15-intel / Elixir1.20.1 / OTP29.0.2. Raw evidence is .audit/unified-main-unit-failure.log. plug_body_test.exs:344 returned the expected {:error, :timeout}, then line361 measured104ms against the unchanged strict <100ms assertion. The file executed28 tests,27 passed. Its execution exited2 and the required-file wrapper exited1.

This supports a scheduler/timer-dispatch or local gate-latency explanation for the elapsed measurement, but the log has no per-phase scheduling trace. It does not prove the exact instant the30ms timer expired or identify which runnable process was delayed. Do not claim the timer fired exactly on time, label the failure expected, or infer a new product defect from104ms alone.

## Exact path

1. Test creates a fake ReadOwner GenServer (handle_call replies :ok) and a real Admission gate through its local fixture. It does not start ListenerSet, a Gaoxy instance, Gateway, listeners or network transports. It builds an Exchange with buffered one-byte body, expect_continue:true, HTTP2.Transport and deadline=Lifecycle.deadline(30), then synchronously suspends only ReadOwner.
2. The measured interval begins after owner suspension. PlugAdapter.read_req_body/2 chooses default requested timeout15000, capped by HTTP read_timeout. Its read_body/6 checks the existing hard deadline, reserves body bytes with Exchange.update_body_retention/2, then delegates through Exchange.read_body_step/4 to HTTP2.Transport.read_body_step/3.
3. If the original deadline is already exhausted at an earlier check, the same timeout can return before the owner call; the failed-job log does not trace the selected subpath. Otherwise HTTP2.Transport.maybe_continue/1 sets expect_sent:true and calls operation(exchange,:read_continue). The specialized clause at http2/transport.ex:58-68 wraps {:head,100,[],false} with write_operation/2. The effective deadline is min(exchange.deadline, now+write_timeout), so it cannot extend the original30ms budget. GenServer.call uses Lifecycle.remaining(deadline), with no added grace. The suspended owner cannot reply; the timeout exit becomes {:error,:timeout}.
4. The generic operation clause's remaining+100ms at transport.ex:87 is not selected for :read_continue. The specialized clause has precedence and is unchanged.
5. On timeout, PlugAdapter.body_error/2 releases body retention. Exchange.update_body_retention/2 immediately rejects an expired deadline; deferred cleanup uses send_request followed by receive_response(...,0), so it does not introduce a fresh blocking cleanup allowance. The caller then observes {:error,:timeout} and performs the elapsed-time assertion. Process scheduling before/after these operations is included in the104ms measurement.
6. Lifecycle.deadline/1 and remaining/1 use System.monotonic_time(:millisecond); remaining is max(0,D-now). There is no new relative timeout reset in the traced path.

The test's100ms wall-clock envelope contains the30ms nominal timeout plus all caller/gate work and runtime scheduling before the final measurement. Deadline correctness and this complete elapsed measurement are related but not identical observations.

## Source identity evidence

`git rev-parse COMMIT:path` and scoped `git diff` show:

- Entire plug_body_test.exs blob is91dee3dd7072e2e0a620beec413f375109156b4e at baseline656dbf5b, PR2078ee8e and main2539b3c4.
- HTTP2.Transport blob is6da2d51b7524fc3e08c4b325764453d04d24d1f6 at baseline and main.
- PlugAdapter blob isc7ba2fbfed7f2330e2a00ed262d62df0eb2677f9 at baseline and main.
- Lifecycle blob is60e130d140404e85758e3651dd7cdec1dfce7b2b at baseline and main.
- Admission blob is1bd23988319455ac352ae14434d9b5564cd88b1d at baseline and main.
- Exchange's only baseline-to-main change is adding the discovery:nil struct field; read dispatch, retention, deadlines and cleanup are unchanged.
- mix.lock and scripts/check-tests.py are unchanged across baseline-to-main.
- PR2078ee8e and merged main2539b3c4 have identical entire Git tree74e3b6688f3e5648fdf23c87d96aa4d4f95f9c51; `git diff --quiet 2078ee8e 2539b3c4` exits0.
- The test and its strict assertions already exist in d86d5a1ff361b7db903a015dec36718b36ff0e0a (2026-10-20, fix(plug): aggregate request bodies within native budgets), before the assigned task baseline.

## Real hosted comparison

Read via GODEBUG=http2client=0 gh run list/view; no rerun initiated by this investigation.

- Baseline656dbf5b: Unit run39557078592, macOS job119082725013 SUCCESS. Exact plug_body_test command used seed0/max_cases1; output at2026-10-21T06:59:15Z was Result:28 passed (3.3s). https://github.com/gsmlg-dev/gaoxy/actions/runs/39557078592/job/119082725013
- PR2078ee8e: Unit run39624808585, macOS job119307220228 SUCCESS. Same command, seed0/max_cases1, same Elixir/OTP/OS matrix; at2026-10-21T15:29:00Z output was Result:28 passed (3.4s). https://github.com/gsmlg-dev/gaoxy/actions/runs/39624808585/job/119307220228
- Main2539b3c4: Unit run39627273984 FAIL at2026-10-21T15:43:07Z; Result:27/28 passed, elapsed104<100 failure (3.5s). The main tree is byte-identical to the successful PR tree, not merely functionally similar.

The successful PR and failing main executions establish variability for identical source on the same named hosted platform/toolchain. They do not independently prove which scheduler or host event caused the104ms observation.

## Disposition

Recommend one unchanged failed-job rerun with all existing assertions, matrix and timeout values intact. If it fails again, preserve both runs and collect phase/scheduler evidence through further bounded diagnosis rather than repeatedly retrying to obtain green. No test weakening, skipping, workflow changes or production repair is justified by the current evidence alone.

Commands used: read-only git show/diff/rev-parse/log, rg/sed/nl source/log inspection, and read-only gh run list/view with GODEBUG=http2client=0. All commands completed. Sol repair rounds increment0; no Astra gate or escalation. Parent owns any hosted rerun decision. Public Hex consumers remain PREPARED_NOT_RUN pending parent publication signal.
