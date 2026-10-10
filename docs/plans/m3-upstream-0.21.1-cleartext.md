# M3 0.21.1 cleartext regression contract

This supplements the [patch qualification plan](m3-upstream-0.21.1-qualification.md).
The source review confirms the published patch still lacks OTP28 TLS tracking
fix95. Qualify applicable H1/h2c public resource properties separately, leaving
the TLS/full39-case gate BLOCKED. No Gaoxy managed integration or memory-budget
activation is authorized by this fixture change.

## Minimal fixture design

Keep the existing default full driver and its39-case assertion. Add one explicit
`--cleartext` CLI selection that runs the existing H1/h2c cases and asserts
exactly24 completed cases. Reject other arguments. Share the existing driver
body through a private helper; expose no arbitrary protocol-list selection.
All peer, deadline, no-replay, wire-byte, completion, retirement and joined
cleanup assertions remain in force. Report the selected profile and TLS95
block explicitly; a24-case pass does not become a39-case pass.

Installed0.21.0's H2 zero-pending-queue capacity error was historically
`:pending_capacity`. Published0.21.1 implements the documented
`{:transport_scope_capacity, :connections}` reason. After capturing the old
fixture's mismatch against the new installed cohort, replace its hard expected
value with the canonical tuple and require an exact MATCH. Remove only the
obsolete local WORKAROUND and diagnostic MISMATCH wording. Keep historical
receipts intact; other cleanup uncertainty assertions remain unchanged.

The initial expected-red run captured the canonical tuple but failed its
cleanup gate: the early obsolete match aborted a still-held draining request,
whose original completion correctly remained unconfirmed. Preserve that failed
receipt. For repair1, move the unchanged exact capacity match after the finite
held-request completion, wire checks, replacement and both retirement checks,
immediately before the case report. This lets the expected mismatch occur with
all original completions settled normally; every existing assertion remains.
Independently review this ordering delta before rerunning. An expected primary
mismatch with any cleanup failure never passes the red gate.

## Execution

1. Independent specification review of this design and the concrete fixture
   delta before any network run. Parent alone runs Mix/VM/peers.
2. Add only the explicit profile driver while retaining the historical capacity
   expectation. Freeze inputs and run the cleartext driver against installed
   0.21.1; require the expected canonical-value mismatch and joined cleanup.
3. Correct only that obsolete expectation/report; review the delta, format,
   freeze inputs and rerun to24/24 with24 joined cleanups and canonical MATCH.
4. Record source hashes, command, exits, counts, cleanup and protocol coverage.
   Failed/unexecuted TLS, held preparing/connecting saturation, complete86
   adversarial-backlog qualification and memory-ledger gates stay separate.
5. Independent final review and fresh scoped checks before local commit.

Fixture ownership: `integration/http_fetch_contract/managed_transport_probe.exs`
and its README's current invocation/status paragraph only. Parent owns package
pins, cohort-facts/tests, runtime commands and evidence. No dependency patch,
private pool access, weakened assertion or new product feature is permitted.
