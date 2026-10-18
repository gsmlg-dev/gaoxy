# Native-H1 pressure DIAGNOSIS5

DONE: read-only diagnosis; no repair implemented or runtime executed. Recommend direct bounded ETS telemetry storage, with no additional process.

Fresh3 proves a controller mailbox breach of 67 at turn18. Current callbacks send one telemetry packet per scoped event to that controller, while subsequent selective waits leave these packets queued. The bounded failure history shows queued telemetry through EOF release, but does not establish the composition of all 67 messages. The historical count66 actor remains UNKNOWN. Fresh2 PASS52/0 and Fresh3 FAIL52/3 retain their actual outcomes; the two TLS failures belong to the separate assignment.

Draining every selective wait would require changing client, peer, observer, fixture and join/barrier paths while preserving their original absolute deadlines. It still leaves mailbox burst races. Direct synchronous ETS writes remove this mechanism with a narrower test-only change.

## Required recommendation contract

1. Use a separate unnamed ETS set owned by the test controller, public only for synchronous telemetry callback writes and sampler reads; preserve the observer table and its size-zero join assertion. Create the event store before handler attachment. Pass its table ID plus the unchanged exact scope filter in handler config. Add no process.

2. For each matching callback capture exactly the existing event, at_us generation timestamp, bytes, operation and outcome fields. Atomically reserve a monotonically increasing slot with a single counter saturating at 129. Slots 1..128 receive one immutable event row each; never overwrite, evict, destructively read or reuse accepted slots. There are at most 128 event rows plus one scalar control row.

3. Counter 129 is sticky overflow and means at least 129 matching events occurred; it is not an exact total. An over-cap callback records this explicit failure state and returns without allocating another event row. Overflow must fail the test and be visible in bounded failure diagnostics, even if no later event accessor runs. It cannot be classified as a permitted drop, accepted truncation or a passing sample.

4. Enforce overflow in every existing sampler turn, each event accessor and the mandatory final validation before a success receipt. Keep the actual Process.info(actor, :message_queue_len) <=64 assertion for every actor including the controller unchanged. Do not signal telemetry events or overflow to the controller with mailbox messages. Do not rely on raising inside telemetry callbacks: handler exceptions may detach the handler instead of failing the test.

5. Reservation precedes event-row insertion; readers must treat missing reserved rows as in flight, not fabricate events or assume count equals committed rows. Read immutable committed rows in existing reverse event order and validate the sticky counter before and after the snapshot. A desired event not yet committed stays pending under the existing finite deadline. Exact scope events in this workload originate synchronously from the one Admission Gate, which completes callback storage before subsequent Gate progress; preserve the existing start/outcome barriers and unique event+operation assertions.

6. A partial concurrent snapshot cannot authorize final success. After the existing normal emitting-owner/Gate/fixture joins establish quiescence, detach the handler, recheck counter <=128, and require exactly one row for every reserved slot 1..count. Then form the existing receipt using the complete history and delete the event table only after the last diagnostic/read need. Handler detach alone does not prove an already-running callback has returned.

7. On failure preserve the original exception and existing bounded cleanup. Diagnostics use a nonraising bounded store snapshot and expose overflow/incomplete state while retaining original bounded stack/packet chronology. Detach before destruction and retain the table through bounded emitting-owner cleanup. Explicit deletion requires emitter quiescence. If cleanup cannot establish it, retain the original failed status and cleanup failure; do not report success or broaden deadlines to obtain a join. Controller exit eventually owns ETS reclamation.

8. Keep the 32-packet failure-only drain for existing nontelemetry packets, bounded 64-entry combined diagnostic output, generation timestamps and clipping indicators. Combine the stored events with these packets without duplicating events. Do not change the 128-event cap, raw mailbox64 cap, 2s/10s deadlines, body/hash/buffer assertions, head/O+B contract, stack/backlog limits, EOF barriers, resources or normal joins.

## Evidence and custody

All six pinned evidence hashes and the frozen current test hash were rechecked. Both diagnostic run source manifests equal candidate8, and fresh3 receipt/log/pressure-record consistency checks passed. No runtime, compiler, formatter, AST/parser, browser or Git action was performed. No repository file changed.

Counter32 remains runtime failures5, Sol repairs4, diagnostic rounds4, Astra2of2 exhausted; no repair increment or counter edit. This assignment had two corrected read-only command failures and one unexpected manifest-output expansion; root was informed. All commands finished; no background processes started.

Root retains source/runtime/evidence/Git custody. Implementation, independent source review and fresh runtime verification remain required. These two exclusive /tmp reports are sealed by their final SHA256 handoff and will not be edited afterward.
