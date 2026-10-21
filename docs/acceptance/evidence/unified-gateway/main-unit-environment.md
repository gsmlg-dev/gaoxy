# Merged-main macOS Unit environment diagnosis

Task: unified-listeners-embedded-gateway/core_lifecycle/unit-environment.
Assignment: direct, read-only. Status: DONE for diagnosis; required macOS Unit remains FAIL.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway`.
Inspected baseline: `2539b3c400231c079eda7ad60f1c343101227eca`.
Companion JSON contains exact job metadata, command intervals, selected original log lines and complete-log SHA256 digests. No source/workflow/test changes or CI mutations were made.

## Established observations

| Run / attempt / macOS job | Actual result | First file wall seconds, including compilation | Mixed lifecycle wall / ExUnit seconds | Plug body wall / ExUnit seconds |
| --- | --- | --- | --- | --- |
| 39557078592 / 2 / 119082725013, baseline 656dbf5 | PASS, 180 executed, no failures/exclusions/skips | 283.141 | 4.441 / 2.6 | 5.439 / 3.3, 28 passed |
| 39624808585 / 1 / 119307220228, PR | PASS, 180 executed, no failures/exclusions/skips | 352.777 | 4.759 / 2.7 | 5.758 / 3.4, 28 passed |
| 39627273984 / 1 / 119315656981, main | FAIL | 275.889 | 5.336 / 3.0 | 5.502 / 3.5, 27/28 passed |
| 39627273984 / 2 / 119320798682, main | FAIL | 378.709 | 13.437 / 5.7 | 13.880 / 5.2, 27/28 passed |

Baseline success above is explicitly attempt 2; this report does not infer its first-attempt result. Both main attempts stopped at the fifth file; neither executed the remaining required unit files.

The PR workflow reports head `2078ee8e18d7238a77ddfb043d21385bfb400439`, while its actual `REPAIR_SOURCE` is synthetic merge `31dc1c3713f557e6b1f49791c63b2ae0eeda2b1c`. GitHub's commit API confirms that synthetic commit, PR head, and current main all have tree `74e3b6688f3e5648fdf23c87d96aa4d4f95f9c51`. File content therefore does not distinguish the successful PR from main's failures.

All four jobs use runner 2.338.0, image `macos-15` version `20260824.0482.1`, provisioner `20260819.586`, Elixir 1.20.1, OTP 29.0.2, and the same restored cache key `mix-macOS-X64-1.20.1-29.0.2-7b3cbfc3834e34a4d6d8ca0b6363bdd60a1e56499cfc12e05d58fb85355961fd`. Both main logs identify macOS 15.7.9. There is no observed image/cache-key change explaining the failures.

Attempt 1 failed `read-triggered H2 Continue cannot outwait the hard deadline at a suspended owner`: elapsed 104ms, required `< 100`, test line 361. Attempt 2 failed `read-triggered H1 Continue cannot wait past the deadline at a delayed gate`: elapsed 562ms, required `< 250`, test line 334. Both first assert the operation returned `{:error, :timeout}`; the elapsed-time assertions fail. The configured request deadline in each fixture is 30ms. The assertions, test file, workflow, and executed unit list predate this implementation and are unchanged from the baseline. The only baseline-to-main change in `check-repairs.py` adds a separately selected composition suite.

Attempt 2 shows broad slowdown before the failing file: the configuration file takes 7.907 wall seconds with ExUnit reporting 0.4 seconds, versus about 1.95–2.14 wall seconds and 0.3 ExUnit seconds in the other runs. This supports investigation of runner/VM overhead; it does not prove that host scheduling caused either failed assertion. Attempt 1's suite timings are close to successful runs. Cold compilation is also present in successful runs, so it is insufficient as the sole explanation.

## Runner, compilation, and lazy loading

`.github/workflows/test.yml:17` sets `ELIXIR_ERL_OPTIONS: '+S 2:2'` for every step. This caps normal BEAM schedulers at two; it does not serialize all runtime processes or eliminate host scheduling delays. `scripts/check-repairs.py:97` passes seed 0 and max-cases 1 for each file. Files run sequentially, each in a fresh Mix/BEAM process. Thus concurrent ExUnit case modules are already bounded to one; reducing max-cases further cannot help.

`scripts/check-tests.py:7` captures the entire Mix output before printing it, and `scripts/check-repairs.py:99` captures that wrapper again. Consequently the displayed GitHub timestamp of `Running ExUnit`, compiler warnings, or the failed assertion is largely an output flush timestamp. The outer command-start-to-result intervals in the table are reliable wall intervals, but the logs cannot locate a 100–562ms stall inside a test.

The workflow has no explicit test-environment compile step; the first Mix test compiles dependencies and umbrella apps. Compilation completes before that file's ExUnit execution. Later files still start fresh VMs and load modules on demand. `apps/gaoxy_http/test/test_helper.exs` only calls `ExUnit.start()`. There is no explicit fixture preloading of production modules. This leaves lazy loading as a hypothesis, but existing logs do not identify module loading inside either failed timed window. A separate `MIX_ENV=test mix compile` step can separate build timings and avoid build activity in the first test command; it cannot preload code in a later fresh BEAM process and is not an established fix for these deadlines.

## Recommended bounded next action

Do not perform a third unchanged rerun. Preserve the exact assertions, seed 0, max-cases 1, macOS Intel platform, and toolchain. Run a diagnostic version of the existing required invocation that records the following in the same VM around the existing failing cases:

- Monotonic per-test start/finish and operation timestamps, with timer oversleep samples outside the measured assertion window.
- Normal schedulers configured/online, run queue, scheduler wall time, GC events, and code-server load activity across the timed windows.
- Host logical CPU count, load and memory pressure, to relate the forced two-scheduler cap to actual available resources.
- Explicit command start/end durations or streaming subprocess output, so buffered GitHub timestamps are not mistaken for event timing.

The separate `http_composition` assignment owns the operation/transport trace. This environment report does not duplicate that investigation or attribute the H1 delay to a particular transport call.

The concrete CI adjustment candidate is to remove the forced macOS `+S 2:2` cap for one controlled comparison **if** host CPU and same-VM run-queue evidence show spare cores alongside saturated schedulers. Let OTP select the available normal schedulers; retain the full 180-case exact gate and every deadline assertion. This is a testable hypothesis, not a proven repair. The fact that baseline and PR pass under the same cap means the cap alone is not sufficient to explain the failure.

If code-server events instead cross the timed window, the smaller targeted candidate is to ensure-load only the implicated production modules during fixture initialization before starting the timer. Keep all timed operation assertions unchanged. If neither condition is evidenced, retain the failure and follow the transport trace rather than making speculative scheduler or warm-up changes. No candidate described here has been applied or validated.

## Evidence and shutdown

Read-only commands used `env GODEBUG=http2client=0 gh run view`, `gh run list`, `gh api`, scoped `git diff/show/status`, and Python log parsing. An initial aggregate query incorrectly treated the successful baseline job as attempt 1, failed before writing, and was corrected to attempt 2. Final collection and JSON validation completed successfully. The pre-existing untracked `deps` entry is preserved.

Only `.audit/unified-main-unit-environment.md` and `.json` were written. No root Mix, local tests, CI rerun/cancel/mutation, source edit, commit, push, or publication. All owned commands have completed. Sol repair increment 0; Astra increment 0; parent counters unchanged. Remaining risk: the exact cause of the deadline excess is unproven, and macOS Unit acceptance remains failed.
