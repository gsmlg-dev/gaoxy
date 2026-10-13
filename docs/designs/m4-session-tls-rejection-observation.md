# M4 Session TLS rejection observation

Coordinator repair3's immutable run run-1791835529186878739 failed42/50.
The original five-second 1 MiB request/response and all four ordered request
trailer cases now pass, including confirmed local teardown. Wrong CA fails
because public Session.ready returns {:error, :closed}; the stable caller
currently discards the public quic_closed notification carrying the actual
authentication reason. Generic closure alone cannot pass the existing TLS gate.

Use that supported consumer notification for evidence. This supersedes only
discarding closed hints in the consumer-affinity observation contract; ready
hints remain disposable and the caller still performs only guardian-selected
operations. No private dependency state/owner query, automatic poll, replay,
transport change or weaker TLS assertion is selected.

The stable caller relays public closed reasons with its owned caller PID and
the request-id/generation to its guardian. Retain one bounded reason (64 KiB
maximum serialized size), drain finite hint batches before commands and after
the public call, capture closed notifications while idle, and retain existing
exact guardian-monitor/deadline checks.
The guardian accepts only its matching caller/id/generation, stores the reason
as diagnostics and returns it with the existing correlated traced result/identity.
The returned public Session result remains unchanged; no closure notification
substitutes for endpoint stop or task termination.

For the two real TLS-negative rows, collect both the actual failed public
operation and actual public closed cause before teardown. Preserve the existing
unknown_ca/path_validation_failed and certificate_unknown/hostname_mismatch
assertions against that observed proof. Require an error public result as well.
Preserve independent zero-origin-request comparison and confirmed teardown.
Missing, generic or unexpected cause still fails; do not manufacture a cause
from requested input, error text, fixture identity or timeout.

All50 rows, original deadlines/windows, payload/trailer/FIN, queue and cleanup
assertions remain mandatory. Counters are Sol2failed2/Astra2failed2 and three
unsuccessful coordinator repairs; this is separately recorded coordinator4,
with no third Astra. Follow [the task delta](../plans/m4-session-tls-rejection-observation.md).
