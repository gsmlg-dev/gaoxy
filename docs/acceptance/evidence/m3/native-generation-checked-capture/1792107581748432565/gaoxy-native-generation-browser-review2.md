# Browser idle keep-alive termination repair review

Task `checked_browser_source_review`, direct independent source-only follow-up. Verdict: **PASS** for the bounded runner2 repair; no actionable findings. Browser acceptance remains **FAIL / NOT REVERIFIED** until root executes the repaired candidate successfully.

Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; observed baseline `e189894882bb6a530f2c38538be4efaf384be261`. Existing repository changes and failed artifacts were preserved. Only this report and its matching JSON were written. No application, runtime, browser, test, build, formatter, network actor or Git mutation was executed.

Reviewed evidence directory: `docs/acceptance/evidence/m3/native-generation-checked-capture/1792107581748432565/`.

| Reviewed file | SHA256 |
| --- | --- |
| `gaoxy-native-generation-checked-browser-runner1.py` | `8e9762c2f5b7f0c8131ae94d8c988c6fd44ac8690e5b32d15118896d730e1bb5` |
| `gaoxy-native-generation-checked-browser-runner2.py` | `929c5a16f20900d61b73ea3ca719f553440f5f317e214d004bb46f83992b3c90` |
| `browser-green1/peer.log` | `60d466f25202ab8b9a37bac0477a2994f5c239d11bbe74d9ff51bb37ca16d0ae` |
| `browser-green1-diagnosis1.json` | `0dfee937840a8f06337be2f8c79aef1826997a3a9fba0d8fc6c6e7bca4690828` |

The adopted evidence runner1 differs from the original reviewed `/tmp` proposal only in the expected HOST sibling-file binding. The runner1-to-runner2 diff contains only the stated receive/reset handling, completed-response count, partial-request EOF assertion and counter metadata.

`browser-green1/peer.log` identifies `ConnectionResetError` at the old idle `conn.recv` site, after the two expected HEAD/GET request rows. The preserved browser log records the real HTTP1 document, exact visible title/text/location and clean Chrome join. The preserved host log records original owner receipts/Admission charge, request-pin cleanup, zero native lease state and resource shutdown, then SIGTERM when the failed peer prevented the final host exit command. These subchecks support the fixture diagnosis; they do not turn the failed complete qualification into acceptance.

At runner2 lines46-54 the exception is caught only around `recv`. A reset is accepted only when `pending == b''` and a previous `sendall` completed. The counter increments only after successful `sendall` at lines70-72. A reset with any partial request, a reset before a completed response, a reset during response send, and other socket exceptions still reach the unchanged error accumulator and fail the unchanged `assert not errors` at line97. EOF inside a partial request now also fails explicitly at lines55-56. The exact HEAD/GET rows, real browser body/DOM assertions, source checks, finite joins, forced-cleanup rejection and overall PASS conditions remain unchanged.

An idle TCP connection may end through reset after its completed exchange; this smoke does not prescribe FIN-only keep-alive retirement. The narrow terminal handling therefore corrects a fixture transport assumption while retaining the meaningful document, accounting and lifecycle acceptance. It introduces no application or charged-constructor change and needs no reopened constructor gate on this diff.

Validation by reviewer: bounded source/log/diagnosis reads, exact `diff -u`, `sha256sum`, and baseline read only; all commands completed. No processes launched or left running. Syntax/runtime execution was NOT RUN by reviewer. Root must retain the original failed qualification and execute the repaired exact candidate for fresh browser acceptance.

Counters preserved from parent: current failedGREEN6 (5 ExUnit + 1 browser), aborted1, production1, fixture5; cumulative group30/root34; Astra2/2 exhausted. This independent review adds zero repair or recovery rounds. Decisions needed: none.
