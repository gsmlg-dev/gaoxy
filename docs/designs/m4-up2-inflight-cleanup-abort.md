# M4 UP2 cleanup after an outstanding public operation

Repair12 after the repair11 fresh repeat FAIL39. The immutable
[result](../acceptance/evidence/m4/upstream-matrix/matrix-1791854457017245116/result.json)
and [independent diagnosis](../acceptance/evidence/m4/upstream-matrix/review-up2-repair11-repeat-cancellation-diagnosis-1791854815019271974.json)
record37 network+2 policy PASS, then missing independent origin cancellation for
h2-downstream_cancel. Its owner is killed and guardian stops normally; no peer
reset/STOP_SENDING/close is recorded for its origin connection. The exact public
operation at cancellation is UNKNOWN. The first full68 PASS remains historical
evidence; it does not replace the failed required repeat.

Gaoxy currently skips public Session.abort when cleanup starts during an
outstanding public call. It immediately stops the dedicated endpoint; a subsequent
correlated result also takes that local stop path. Public endpoint stop confirms
local teardown; the shared-endpoint Session.abort path sends a QUIC close. This
is a source-level ordering defect. Its linkage to this particular failed row is
plausible, not proved by the aggregate trace. Public Session.abort explicitly
abandons pending application work without replay and retains its identity.

When a live stable caller, Session and endpoint exist, arm the existing100ms
cleanup stop_due once, capped by the original absolute cleanup deadline. If idle,
issue abort (cancelled) or close (consumed) immediately as before. If a public call
is outstanding, wait for that exact correlated result within this same bound.
Retain its advanced Session and issue the one terminal public cleanup command
through the same caller. Ignore any application events in that result. Never
resume or resubmit application work, overlap calls, or create another caller.
Do not reset stop_due when the result or terminal command arrives.

Rearm the existing five-millisecond progress tick at cleanup entry. A retained
timer reference may already be cancelled, as the deterministic paused-ACK test
demonstrates; it must not prevent the original bounded fallback from running.
This changes no cleanup deadline or stop_due and adds no process.

Unknown-operation abandonment applies to cancelled=true Session.abort. Consumed
Session.close keeps its existing public pending-operation error/local-stop
outcome; it does not claim remote abandonment. Tests verify the exact advanced
public Session and opaque returned identity rather than reading private SDK state.

If the result arrives after fallback/endpoint stop/deadline, do not issue another
public command. Public abort/close result starts endpoint stop as before. A caller
loss or the unchanged100ms fallback starts local stop; a never-returning call
cannot delay teardown. All local endpoint/caller/stop-result/DOWN evidence remains
required before cleanup completion, and abnormal teardown remains a failure.

Deterministic complete-public-call barriers must cover held poll results with an
advanced Session, an unknown result retaining its abandoned identity, stale
generation/ref results, no late delivery/replay, result before/after fallback,
caller loss, and unchanged cleanup deadline/stop_due. Existing idle abort ordering
and deferred stop-result tests stay unchanged. Original network cancellation,
sibling survival,1MiB/hash/FIN/windows and5s deadlines remain required. No dependency
patch or issue97 requirement is introduced.

UP2 has20 failed live executions. Repair11's repeated full qualification failed,
so the unsuccessful production-round count becomes8; harness failures remain3.
This accounting does not attribute the cancellation race to DATA batching.
Historical19/7/3 and all earlier counters remain recorded. No third Astra round.
