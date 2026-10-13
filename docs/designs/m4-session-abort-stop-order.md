# M4 Session abort and endpoint-stop ordering

Coordinator repair4 run-1791836503490777437 records 47 PASS, one attempted FAIL
and two NOT RUN. Both actual TLS-negative causes and pending-header cancellation
pass. The unacknowledged-response endpoint, caller, creator, stopper and guardian
terminate normally and the UDP port rebinds, but its independent origin sees no
reset, stop-sending or close within the original five-second peer deadline.

The [public-source diagnosis](../acceptance/evidence/m4/upstream-contract/abort-stop-order-diagnosis-1791836799571418845.json)
finds that the probe starts endpoint stop before commanding idle Session.abort.
Endpoint termination releases local UDP and descendants without protocol close;
borrowed Session.abort instead invokes public close, which submits the closing
datagram before its admitted result. No upstream defect is established.

For an idle owned caller with retained Session, command abort first, then begin
endpoint stop on the correlated result or the existing at-most-100-ms fallback,
whichever arrives first. Cap this fallback by the original cleanup deadline.
This refines the cancellation ordering in the consumer-affinity design: guardian
remains responsive, performs no synchronous call and never waits for an unbounded
abort. The normal close branch already uses this bounded scheduling rule.
Outstanding operations, absent/lost callers and unresolved bootstrap still start
independent endpoint stop immediately; never queue abort behind an outstanding
call. Returned blocked/unknown Session work is caller-idle: public abort abandons
that work without replay before closing. Preserve advanced state and identity.

Local completion still requires public stop, monitored normal endpoint DOWN,
all owned task DOWNs and same-port rebind within the original grace. Lost-caller
DOWN during an abort starts stop immediately too. Record the actual stop trigger
from the executing guardian branch: released abort must stop on its public result,
while blocked abort must exercise the bounded fallback. Abort success
alone never completes cleanup. A blocked abort is terminated only after endpoint
DOWN, without manufacturing an abort acknowledgment. Preserve the peer receipt,
sibling-survival, zero-origin TLS, full byte/hash/trailer/FIN and all 50 assertions.
No request, wire or cleanup deadline increases.

Add deterministic released/blocked abort subcases inside the existing
caller_down_before_stop_result double row. Preserve original row names/kinds and
its original completion-order assertions. Carry Sol2failed2/Astra2failed2 and
coordinator4failed4 into coordinator repair5; no third Astra or counter reset.
Apply the same ordering to UP1 only after full UP0 review and fresh verification.
