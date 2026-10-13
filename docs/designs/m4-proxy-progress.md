# M4 proxy ingress and response progress repair

The existing UP2 matrix remains required: 66 independent network rows and two
policy rows, each with its original five-second peer deadline, 1 MiB tiny-window
payload, exact byte/hash/FIN checks, error classes and cleanup assertions.
Five unsuccessful executions precede this repair; four were diagnostic runs.
UP2 production repair count is initially zero. UP0 Sol2/Astra2 and all other
cumulative counters remain unchanged; no third Astra recovery is authorized.

## Evidence and selected correction

The installed public HTTP/QUIC cohort is 0.21.4 and upstream #101 is closed.
The immutable diagnostic2/3 receipts show H1 ingress gaps and one-byte socket
framing waits dominating the five-second failure. Chunk-framing reads spent about
four seconds waiting for ingress; the peer queued the complete body in 3.192 ms.
The controlled
[diagnostic4 run](../acceptance/evidence/m4/upstream-matrix/matrix-1791844051404728174/result.json)
changed only socket receive capacity to the already validated 65,536-byte
max_buffer_bytes. All 64 credited 16 KiB writes, exact 1,048,576-byte origin hash
and one request FIN completed in about 1.26 seconds. The row still failed on
response consumption: 613 post-upload passive socket waits consumed 3.48 seconds.
That diagnostic run is FAIL and cannot satisfy acceptance.

Use max_buffer_bytes for the native H1 socket's recbuf and buffer capacity.
Keep max_read_chunk, explicit read credit, parser buffer/admission enforcement,
and all timeout options unchanged. Socket receive capacity and application read
credit are separate bounds; this does not claim total native-memory accounting.

For post-upload/response progress, check the downstream connection without
waiting, then wait in a receive that upstream events, guardian DOWN and drain
messages can immediately wake. An idle receive waits at most the existing five
milliseconds and remaining original total/idle deadline. Do not recur through
poll0 without an idle receive. Reads during upload retain their current finite
wait and write synchronization. H1/H2 support closure-aware poll0; H3 poll0 must
also retain the existing owner/stream fencing and closure semantics before this
change is applied to it. No deadline extension, upload replay, alternate error
classification or private dependency state inspection is part of this repair.

The native H1 real-TLS regression and the unchanged independent UP2 tiny row
cover ingress and combined upload/download. Existing proxy disconnect, early
response and lifecycle regressions cover wakeup/closure compatibility. Remove
the fixture's receive-capacity behavior flag before acceptance; retain diagnostic
receipts and bounded scalar observations. A separate framed-error regression
will cover any confirmed false successful FIN; do not silently bundle it here.

Follow [the execution delta](../plans/m4-proxy-progress.md).

## Repair2: acknowledged response wakeup

[Repair1 actual execution](../acceptance/evidence/m4/upstream-matrix/matrix-1791844975825535259/result.json)
remains FAIL after6 network+2 policy rows. Upload is complete and all post-body
zero-wait socket reads together take only83,798 microseconds. Yet680 public DATA
events do not finish the response before the unchanged deadline. Production
HTTP3SessionClient.advance arms a five-millisecond tick while a delivery awaits
ACK. Matching acknowledge requests tick0, but tick leaves an existing timer
unchanged; every small response delivery can therefore inherit that idle delay.

On a matching ACK only, cancel the existing idle tick and schedule the existing
zero-delay owner tick if cancellation succeeds or no timer exists. If cancellation
returns false, retain its reference: the fired tick is already queued to wake the
owner, so a replacement would create an unnecessary duplicate tick. Stale/duplicate ACK remains a no-op, polling during an
unacknowledged delivery remains paused, and queue/event bounds, one operation,
one delivery, max_read_batches1, original deadlines and no-replay stay intact.
The timer remains bounded to one pending timer. Do not globally replace idle
ticks with immediate ticks or introduce a busy loop. A deterministic regression
uses a controlled future idle timer and checks prompt owner wakeup after the
matching ACK, while a stale ACK cannot cancel or wake it. A zero-delay timer
receipt and requeued message deterministically exercise the already-fired branch
without a sleep or replacement timer. This is production
repair2 after repair1 failed; cumulative unsuccessful live executions are6.

## Repair3: idle native TLS closure progress

[Repair2 actual execution](../acceptance/evidence/m4/upstream-matrix/matrix-1791846161118796420/result.json)
passes15 network and two policy rows, including the unchanged1MiB case, then
fails waiting for cancellation of `h1-downstream_cancel`. The cancelled owner
has observed200 and the exact `progress-` prefix, but finishes only after a kill;
the independent origin observes its connection close during fixture shutdown.
There are now seven unsuccessful live executions and two unsuccessful production
repair rounds. Existing native disconnect tests covered TCP, not abrupt TLS
closure. The earlier assumption that H1 poll0 qualified TLS closure is disproved.

The current locked OTP28.5.0.7 passive TLS implementation defers an abrupt
transport close until a receive has a waiting caller. A zero receive timeout can
clear that caller before the queued transport close is processed. Use a finite
positive one-millisecond native TLS poll only after the existing bounded mailbox
wait expires. Immediate progress turns retain poll0, so response deliveries do
not each pay a positive socket wait. TCP and H2/H3 retain their zero-wait path.
Clamp the poll to the remaining original total/idle deadline. Preserve read
credit, retained-byte admission, public socket APIs and Exchange.poll0 semantics;
do not use active socket mode, private SSL state or a new process.

A real native TLS streaming-proxy regression must first observe the exact
response prefix, abruptly close the independent client's actual transport, then
require actual upstream EOF and guardian/admission cleanup before the original
request lifetime. Record actual RED before applying the production correction.
Full unchanged UP2 and all later gates remain required; this preparation is not
a live PASS or M4 completion claim.
