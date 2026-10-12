# M4 shared HTTP/3 endpoint integration

This bounded supplement implements Task 3/G2 of the existing M4 design. G1 must
pass independent review and fresh verification before this slice changes runtime
code. The continuing authorization covers design, implementation and local
commits; publication and deployment remain separate.

## Selected approach

Keep the QUIC callback as the sole I/O owner, with one connection-owned ETS
operation slot per admitted request. Endpoint tasks use the existing
`Gaoxy.HTTP.Tasks` supervisor and Exchange facade. Extract the current H2
response implementation into a shared framed-response module, replacing its
hardcoded transport call with `exchange.transport.operation/2`. H2 and H3 retain
their backend modules as delegating compatibility wrappers. The shared module
reuses existing pure header validation and has no dependency on QUIC.

Copying the complete H2 response implementation would duplicate streaming,
file, content-length and bodyless rules. Sending GenServer calls to the QUIC
callback owner cannot work because the public host does not dispatch those
messages. Both alternatives are rejected. This slice introduces no scheduler,
registry, extra admission timer or new endpoint API.

## Rendezvous and endpoint task

`Operations.new/0` creates an unnamed public ETS set owned by the connection
callback process. Only the owner creates and removes request rows, bounded by the
existing eight active request contexts. A row contains its opaque stream key,
generation token, worker identity, original deadline and one operation state.
The owner registers a row before starting its task. The task immediately monitors
the owner and waits for a token-bound start message. After `start_child/2` returns,
the owner binds exactly that returned PID to the row, then sends the start
message. Failed start removes the row and cancels the request; owner death before
binding ends the monitored startup wait. The worker verifies that identity,
acquires its own Admission lease and arms `begin_request/4` with the original
deadline D, then atomically publishes readiness and the lease in that row. The
owner polls this readiness, verifies identity/liveness, and sends a token-bound
dispatch message to the worker. The task is not linked to the callback owner.
No endpoint runs before these steps complete.

`Operations.submit/4` atomically replaces an idle row with one bounded operation
and a fresh reference. The owner claims that reference at most once. A row stays
occupied through blocked reads/writes and uncertain host operations. Replies go
to the endpoint worker by token/reference; endpoint operations never send body
chunks into the callback owner's mailbox. Operation states are idle, submitted,
claimed, completed or cancelled. Completed replies are acknowledged before the
slot becomes idle. A caller timeout or uncertain destructive outcome changes the
same reference to a terminal tombstone, so a late claim or reply cannot start or
repeat output. An owner-confirmed read/poll no-progress result is instead a
completed `:pending` operation; acknowledgement permits later reads/output.
If caller expiry races a claimed read, the owner retains already consumed bytes
in the bounded ingress state before attempting its reply. A lost reply claim
terminates the request visibly; it never returns retryable `:pending` after
discarding bytes. Stale tokens, another
worker, an expired D and a deleted table return a closed/timeout result without
publishing another operation. Each operation retains an absolute D_op, bounded
by original D and the configured write timeout or requested read/poll wait. The
same D_op is used by submission, claim, endpoint waiting, owner progress and
uncertain-reference resolution; it is never renewed on a tick. Read/poll
owner-confirmed no-progress preserves their `:pending` result, while caller or
output expiry is a terminal timeout. Zero wait is an immediate probe and must not publish a
destructive operation that can execute after the caller has returned.

Transport state records `{owner, table, stream_key, token}`. A worker monitors
the owner while awaiting dispatch or an operation reply. Missing ETS and owner
DOWN end cooperative waits. A Plug busy outside Transport remains bounded by
Admission's existing request timer at D. No monitor message, requested kill or
endpoint `after` block substitutes for an observed cleanup receipt.

The worker publishes completion in ETS; callbacks poll completion and worker
liveness because unrelated DOWN messages are not application events. Failed
start, crash, cancellation and completion remove the slot and stop only the
associated worker. Pending host-operation references retain their original
deadline until resolved; cancellation cannot blindly replay or forget them.

## Request and response mapping

After validated HEADERS, Connection constructs Exchange with the H3 Request,
HTTPS, actual public peer/local metadata, nil unavailable TLS/certificate data,
HTTP limits and the admitted worker lease. The request deadline starts when the
peer stream opens and is never renewed by dispatch, reads or cancellation.

The existing parser's DATA/trailer/FIN actions populate a bounded ingress buffer
and ordered trailer list. Available application credit controls each QUIC read;
queued input plus retained parser work must fit the existing reservation. A read
operation returns the existing `{:ok | :more, bytes, ended, trailers}` shape;
finite no-progress waits return `:pending`. Requests before peer SETTINGS remain
legal. CONNECT returns 501 and H3 upgrades return `:not_supported`.

Owner operations are `{:read, credit, wait}`, `{:poll, wait}`, `{:abort, reason}`,
`{:head, status, fields, ended}`, `{:data, binary, ended}` and
`{:trailers, fields}`. Data operations are at most 16 KiB; header/trailer fields
are validated against configured limits before QPACK encoding. One output
operation remains claimed until its entire bounded HEADERS/DATA/trailers/FIN is
definitely admitted or fails. Admission is not described as peer delivery.
Informational HEADERS precede a single final response. Bodyless responses and
file/chunked/fixed-length responses retain the existing facade semantics. Early
responses preserve unread-body isolation and bounded cancellation.

## Acceptance and ownership

Root owns Operations, Transport, Response, the shared framed-response extraction
and their scoped tests. A Sol connection worker owns Connection, Stream and
deterministic lifecycle tests. The independent peer author owns only the shared
fixture/runner/peer extensions. Serialize Mix and live runs; freeze hashed source
during each live run. Writers preserve one another's files.

G2 requires meaningful slot-race regressions, H1/H2 compatibility, independent
H3 ordinary/streaming/file/trailer/informational/bodyless/early-response/slow-peer
checks and fresh independent specification/code review. The busy-Plug regression
uses an explicit dispatch barrier, kills only the callback owner, never releases
the Plug, and keeps Admission alive. By D plus the 1,000 ms cleanup headroom it
must observe worker DOWN, deleted ETS, released lease/bytes and monitored request
pins; another connection and another listener must still complete requests.
Missing confirmation is `termination_unconfirmed`. G2 alone does not complete
the downstream/browser or required upstream-H3/standalone matrix.
