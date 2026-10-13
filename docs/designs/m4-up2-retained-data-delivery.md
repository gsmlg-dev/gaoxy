# M4 UP2 bounded delivery of retained DATA

Repair11 proposal after repair10 full FAIL52. The immutable
[result](../acceptance/evidence/m4/upstream-matrix/matrix-1791853528647261927/result.json)
records 50 network and two policy checks, unchanged292 source hashes, selected
1ms downstream host polling, and full origin1MiB/hash/one FIN/response FIN.
Downstream received662281 bytes in648 DATA events from1878.508ms to4986.39ms,
without FIN at the original5s deadline. Origin and fixture stop normally; the
failed request owner is killed and its guardian terminates normally. Counters
are19 unsuccessful live executions/7 failed production repairs/3 failed harness
repairs. No third Astra recovery is authorized.

The public poll trace ends with eight DATA events and a writable event, followed
by ticks without another public command. Source inspection shows that each
retained public DATA event becomes a separate downstream Response.chunk and
matching ACK roundtrip, even when several small events already occupy the bounded
queue. The delivery path splits a large event at16KiB but never combines adjacent
small events. The trace supports investigating repeated delivery overhead; it
does not measure the native write/ACK roundtrip or prove the entire residual cost.

Drain only consecutive DATA bytes already retained in the queue into one delivery
of at most the existing16KiB ceiling. Preserve exact order, split the last event
at the ceiling, and stop before trailers or end. Return any partial available
batch immediately; never poll or wait to fill it. Empty DATA may join the same
batch, but the finite existing256-event queue bounds traversal. Decrement
event_bytes by exactly the delivered byte count; retain one matching delivery
reference and the existing paused control polls and ACK/timer scheduling.

This changes downstream chunk boundaries, not HTTP response bytes or streaming
completion. It adds no queue, buffering threshold, dependency/private API, native
wakeup, process or option. Keep the256KiB retained-event budget,256-event limit,
max_read_batches1, opening/total/write/cleanup deadlines, request identity, FIN,
ordered duplicate trailers,16KiB DATA ceiling and every68-row acceptance oracle.
Default10ms and explicitly selected1ms host profiles remain distinct.

Deterministic public-driver tests must show exact bytes across several retained
DATA events, a split at16KiB with exact remainder/accounting, no overlapping
delivery before the matching ACK, stale/duplicate ACK no-ops, trailer/end order,
and immediate delivery of a partial already available batch. Preserve existing
single-event splitting and all independent network assertions. Actual complete
matrix, independent evidence review and a fresh complete repeat determine whether
this bounded change resolves the acceptance failure.
