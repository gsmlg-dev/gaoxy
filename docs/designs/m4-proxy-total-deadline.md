# M4 proxy total-deadline notification ordering

The unchanged UP2 repair3 execution passes18 network and two policy rows before
`h1-total_timeout` fails. Its response retains the exact200 prefix and closes
without successful completion at1501ms, but the endpoint returns `:timeout` and
its public error-event receipt is empty. Preserve the original
`receipt.errors == [":request_timeout"]`, original1500ms total deadline,
1400..2500ms elapsed bound and H2/H3 reset/no-success-FIN assertions.

HTTP.progress currently independently reaches the total deadline and invokes
ordinary cancellation. HTTP.Session marks that cast cancelled and consumed;
its subsequently processed total-expired message is then suppressed. This is
an ordering race between the endpoint and the existing guardian deadline, not
an upstream API gap. Eight unsuccessful live executions and three unsuccessful
production repairs remain immutable; no third Astra recovery is authorized.

For a selected H3 origin whose total deadline has expired, request expiry from
the existing guardian rather than cancelling it before its notification. The
guardian checks its own deadline and selected client, emits the existing bounded
error event once and enters its existing cleanup path. Its H3 total reason is
`:request_timeout`; ordinary H1 remains `:timeout`. Prior failure, cancellation
or consumed completion must not emit another error. Idle-only expiry preserves
the current timeout/cancellation path.

The endpoint selectively awaits only the matching guardian error or DOWN under
the existing original-deadline-plus-cleanup-headroom bound, then returns its
error. Before dispatching any queued nonterminal or successful event, the selected
H3 owner checks its total deadline. Owner-local read, poll or response-write
timeouts at that deadline enter the same expiry wait; a received guardian error
fails directly without recursively requesting expiry. No success event, response
body or new socket operation may be dispatched after the request deadline. This
ordered notification wait is cleanup work; it
does not restart or extend the deadline used for request/response I/O. Guardian
absence or a missed cleanup bound remains visible as an error; it is never a
PASS substitute. Keep the ordinary cancel API and all unrelated client behavior.
No new process, dependency modification, retry or unbounded wait is needed.

Deterministic unit tests explicitly order the guardian's expiry-cast and timer
callbacks against a controlled expired deadline, with token:nil and no allocated
request. Each ordering must emit exactly one actual H3 error notification while
preserving the deadline. H1 and not-yet-expired H3 controls retain :timeout;
already failed/cancelled/consumed callbacks remain idempotent. These unit tests
prove callback ordering, not a running guardian's resource cleanup. The existing
real guardian timer test and complete66+2 UP2 network matrix independently verify
finite cleanup, exact bytes, terminal behavior and original deadlines. Record
actual RED before the production change, independently review and fresh-repeat
the complete matrix.
