# Deadline witness independent review

Status: PASS for the scoped enhanced diagnostic. This is not a product repair or a resolution of prior hosted FAIL results.

Task: `http_composition/deadline-witness-review`, direct read-only assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway`; baseline `fd39888412ac5092d63d8ccbba4f1ad51b10c7cc`. Reviewed source `apps/gaoxy_http/test/plug_body_test.exs`, SHA256 `3273b8a8b41a589d14c9edd7425d2ad5826343c2421eff990dd8a9a94dce4531`. Reviewer wrote only this report for this assignment, ran no Mix and changed no source/workflow/CI state. Concurrent edits and pre-existing `deps` symlink preserved.

## Findings and resolved observations

No remaining actionable findings.

- All92 lines beginning with an assertion/refutation macro are identical to baseline, using anchored regex `^\s*(?:assert|refute)(?:_[a-z_]+)?\b`. This includes68 `assert ` / `refute ` statement lines and24 other assertion-macro lines (15 `assert_receive`,8 `refute_received`,1 `assert_raise`). Original timed expressions, strict100/250ms limits and30ms request deadlines remain unchanged. Three request markers additionally arm the witness against each original exchange deadline. Timing markers bracket slightly more diagnostic work than the original millisecond timer; the original elapsed assertion remains authoritative.
- `:call` tracing applies only to each tagged test process. The local `:gen.do_call/4` pattern emits call arguments, returns and exceptions; collector output retains timeout plus the controlled H2 read/Continue operation, discards other request arguments as `:fixture_call`, and discards return values. Current fixtures contain fixed synthetic requests, no operational secrets or user data. The transient raw trace message does contain call arguments, so this remains a test-only diagnostic rather than a general production privacy guarantee.
- Exact local output shows direct H2call timeout25ms and Continue timeout30ms, with `{:exit, :timeout}` exception events. This verifies that the diagnostic can expose the actual gen timeout and distinguish an operation from fixture calls. Neither `:gen` nor Lifecycle is newly preloaded by the probe: the former already services fixture calls, and the exchange fixture invokes Lifecycle.deadline before measurement.
- `trace_pattern` is VM-wide, while process call tracing is caller-scoped. Cleanup disables the pattern. No other repository test installs a gen.do_call pattern; scoped CI invokes this single file with max_cases1 in its own Mix VM. Approval covers that isolated diagnostic execution, not arbitrary coexisting tracing tools.
- The initial Process.info(caller) witness query was removed. Final source performs no caller query, caller message send, priority change, suspend/resume or other direct caller wake at the deadline. The witness target is the independent collector; the caller already has passive scheduling/call trace observation.
- Initial report/timer race was made explicit: output reports `:observed` or `:not_observed_before_report`. A pending timer can arrive after collector reporting; trace_delivered flushes traces, not timer messages. Missing witness evidence cannot silently be treated as a punctual timer. The256-event cap and dropped count remain; both must be checked before relying on witness absence.
- Delivery and report waits remain within finite try/after cleanup. Cleanup disables the pattern, kills the monitored collector and waits finitely for DOWN. A pending one-shot timer targets a dead collector after cleanup and cannot retain a live owned worker. No new long-lived diagnostic process or unbounded polling is added.

## Interpretation limits

`late_ms` measures when the collector processes the timer message relative to the original deadline. It includes timer service, mailbox dispatch and collector scheduling delay. A late witness alongside a late caller supports a shared timing problem but does not isolate OS preemption, BEAM scheduling, timer delivery or collector backlog. A prompt witness alongside a late caller narrows the delay to the caller/call path but does not by itself prove that its timeout was already runnable.

Runqueue lengths are sampled at witness handling, nonatomically across queues; low values do not rule out earlier CPU contention, GC or OS descheduling. Logical processor availability and online scheduler counts describe configuration, not spare capacity. Call tracing also adds observer overhead. Prior failed evidence must remain FAIL, and absent witness evidence must remain NOT OBSERVED.

## Validation evidence

Independently checked matching final receipt `.audit/unified-deadline-witness-local-final-v2.json` and full log `.audit/unified-deadline-witness-local-final-v2.log`:

```text
env ELIXIR_ERL_OPTIONS=+S 2:2 flock .audit/mix.lock python3 scripts/check-tests.py apps/gaoxy_http/test/plug_body_test.exs --seed 0 --max-cases 1
exit0;28 tests,0 failures
3 trace reports;3 observed witnesses;all dropped0
all witness late_ms1;logical_processors48;schedulers2
```

Receipt SHA256 matches reviewed source. Validation belongs to the parent's completed run; reviewer did not execute Mix or touch the parent's sessions. Independent reviewer checks: scoped diff/status, matching source SHA256,anchored92-line assertion-macro comparison (including68 plain assert/refute statements), receipt/log inspection, fixture/code-loading provenance and repository trace-pattern search. Hosted enhanced diagnostic is NOT RUN at review time.

All owned reviewer commands completed; no active process remains. Sol repair increment0; parent owns cumulative prior counters, no Astra counter received. No escalation gate or additional design decision required for this bounded diagnostic.
