# Issue 13: inactivity-only storage requests

The existing finite request deadline includes upload reads and send_file.
Response-only stream_timeout cannot extend an upload. Support an explicit
`http_limits: %{request_timeout: :infinity}` on native H1/H2 listeners while
retaining the 30-second finite default. Header acquisition and each socket
read/write remain finite; read windows, admission, cancellation and shutdown
remain bounded. File responses inherit the selected request lifetime.

H1 constructs an infinite request deadline while retaining its independent
header timer. Admission accepts infinity for begin_request, using its existing
infinite-stream timer representation. H2 retains the finite admitted-worker
startup and constructor accounting; only the activated, dispatched worker
transitions its own lease and transport request to infinity before application
dispatch. It cannot use this transition on a finite listener. Read/write owner
operations remain finite. Account the changed deadline representation.

HTTP3 retains its finite-lifetime boundary and explicitly rejects the new
option before initializing the endpoint. No HTTP3 runtime extension is implied.

Verification: first reproduce rejection with unit and actual H1/H2 listener
tests. Then prove progressing bounded uploads and file responses, idle read
and partial-header expiry, finite-request behavior, peer cancellation, H2
sibling isolation and blocked-write expiry. Classify unit tests without
sockets and real-peer cases in the protocol manifest. Obtain independent
review and fresh verification before release. Preserve all original failures.

Independent review also checked the configuration boundary. Reject direct and
ListenerSet-wrapped Generation targets before endpoint initialization, and
reject managed gateway declarations before runtime preparation. Ordinary
prepared Plug targets, including Phoenix, remain supported. An actual H1
`100 Continue` regression exposed an admission call using the infinite request
deadline; its send coordination now derives the existing finite write deadline.
The original boundary and continue failures are retained in release evidence.

Final focused verification on the reviewed working tree, based at
`0b3f97fc08549649b4b367e3a85a8526e162f53f`: 26 tests, 0 failures. The fresh
canonical ordinary gate then passed 452 tests, with 0 failures, exclusions or
skips. Independent specification/code review passed. See
[release acceptance](../acceptance/release-0.12.0.md) for commands, environment,
evidence and separate publication status.
