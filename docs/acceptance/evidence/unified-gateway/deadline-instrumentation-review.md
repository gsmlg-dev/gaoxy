# Unified deadline instrumentation independent review

Status: PASS for diagnostic CI. This is not a product fix or a resolution of the historical macOS deadline failures.

## Scope and source

- Task: `http_composition/deadline-instrumentation-review`, direct read-only review assignment.
- Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway`.
- HEAD: `2539b3c400231c079eda7ad60f1c343101227eca`.
- Reviewed file: `apps/gaoxy_http/test/plug_body_test.exs`.
- Reviewed file SHA256: `8934ee16cdbec4eebab87388ab62e5f04e26a5cddbb1cee876c7286183df7052`.
- Diff: 95 insertions, zero deletions. Existing assertions, result ordering, 30 ms deadlines and elapsed limits remain unchanged. Other concurrent documentation/evidence edits and the pre-existing `deps` symlink were preserved.

## Findings

No actionable findings.

1. Tracing is restricted to the three tagged test processes. Trace events contain scheduling metadata and explicit phase labels; request payloads are not traced. Unmarked tests do not enable tracing.
2. The H1 fixture marks Admission.status, sys.suspend, and native read completion separately. Request markers bracket the original timed operations without relocating the original timer or elapsed assertions. Added trace messages introduce a small observer cost; diagnostics should be interpreted accordingly.
3. The collector matches the enabled trace events. Local OTP 28.5.0.5 source `lib/kernel-10.6.3.3/src/trace.erl:342-356` documents `running` as emitting `in` and `out`. The `in_exiting`, `out_exiting`, and `out_exited` variants require the separate `exiting` flag, which is not enabled. Current official OTP 29 trace documentation agrees: https://www.erlang.org/doc/apps/kernel/trace.html#process/4 . The initial exit-variant concern is therefore not a finding.
4. Event timestamps share the monotonic native clock, and sorting before relative conversion handles trace/stage message interleaving. The log reports raw events without claiming that an off-scheduler interval proves runnable starvation; an interval can include intentional blocking waits.
5. Stored events are capped at 256 and truncation is explicitly counted. This bounds stored history, not the mailbox independently. All three observed reports had dropped:0 and included both request markers; the H1 report also included every fixture phase. No observed diagnostic loss.
6. Delivery/report waits are inside a common try/after with finite deadlines. The tracer is monitored and killed in cleanup, including delivery/report failure paths. A collector that exits after replying is handled by its monitor. Tests that reach their deadline assertions have already emitted stage events, so the nonempty event history used for the origin is established on that path.

## Verification evidence

Reviewed the parent's completed receipt `.audit/unified-deadline-instrumented-local-final.json` and full associated log `.audit/unified-deadline-instrumented-local-final.log`:

```text
env ELIXIR_ERL_OPTIONS=+S 2:2 flock .audit/mix.lock python3 scripts/check-tests.py apps/gaoxy_http/test/plug_body_test.exs --seed 0 --max-cases 1
exit: 0
28 tests, 0 failures
3 DEADLINE_TRACE reports, all dropped: 0
```

The receipt's test source SHA256 equals the independently computed reviewed-file SHA256. The reviewer did not run Mix or modify source. Reviewer checks were `git status --short`, scoped `git diff`/`git diff --numstat`, source SHA256, receipt/log inspection, and local/official OTP trace documentation inspection. All reviewer commands have completed; no owned background process remains.

Cumulative Sol repair increment for this diagnostic review: 0. Parent owns prior cumulative counters; no Astra repair counter was received. No escalation gate or additional design decision is needed. Hosted diagnostic execution and historical macOS deadline cause remain pending with the parent.
