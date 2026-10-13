# M4 caller-owned public Session upstream

The caller/consumer ownership paragraphs below preserve the original design.
They are superseded by the reviewed [consumer-affinity amendment](m4-public-session-consumer-affinity.md)
and [in-flight cleanup amendment](m4-up2-inflight-cleanup-abort.md). The active
implementation uses a stable same-caller Session with `consumer: self()`; the
[final implementation ledger](../acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
binds current verification.

Architecture candidate for independent Sol specification review, 2026-10-13.
Task `/root/m4_session_design`; `astra_gate: PROJECT_ARCHITECTURE`;
`mode: architecture`. This document supersedes the **selected upstream client**
parts of [the upstream design](m4-upstream-standalone.md) and its resume queue.
It preserves their product scope, shared HTTP policy, standalone integration and
acceptance matrix. It is not an implementation or runtime acceptance receipt.

## Decision and evidence

Use `Gaoxy.Proxy.HTTP3SessionClient`, backed by caller-owned public
`QuicHttp3.Session`, for explicitly configured fixed HTTPS/H3 reverse origins.
Create one dedicated public `QuicHttp3.Transport.Quic.Endpoint` descriptor per
request, retain it before connecting, and explicitly stop that endpoint at the
end. There is no pool, reuse, protocol discovery, fallback, redirect following or
application replay. H1 remains the default and keeps `HTTPFetchClient`.

Inspected worktree: `.trees/m4-http3`, branch `codex/m4-http3`, HEAD
`ed6ac187f052063fe2c0695c1343cb2980214b62`. Installed coordinated cohort: 0.21.4;
root lock SHA256 `aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
The [independent source audit](../acceptance/evidence/m4/upstream-contract/source-audit-0.21.4-1791825360661362396.json)
records containing release/provenance and source hashes. These findings were
checked against installed source for this design:

| Public surface | Design consequence |
| --- | --- |
| `Session.send_trailers/4`, `session.ex:147` | Ordered duplicate trailing HEADERS and FIN now have a supported operation; zero-DATA requests must remain open until trailers are known. |
| `Session.resume/1`, `suspend_blocked/1`, `resume/2` | Preserve advanced state and operation identity. Unknown admission is reconciled, never replayed. A definitely blocked upload can be suspended while response/control polling proceeds. |
| `Session.poll/3`, `session.ex:243` | Caller controls polling, paused request refs and read batches. Returned events still require a bounded application queue. |
| Session module documentation, lines 8–9 | Native queries and DNS retain transport wall-clock bounds. Admission timeout alone cannot keep the cleanup guardian responsive. |
| `Transport.Quic.client/1`, `connect/3`, `stop_endpoint/1` | A verified public descriptor exists before connect; borrowed connections require an explicit endpoint stop. |
| `Transport.Quic.cleanup/1`, lines 249–251 | Cleanup of a borrowed endpoint is a no-op. Session close/abort success alone cannot release Gaoxy's cleanup token. |
| `Transport.Quic.connect/3`, lines 90–95 | On failure the dependency ignores its internal cleanup return. Retaining the explicit descriptor avoids losing Gaoxy's independent cleanup boundary. |
| `Quic.Endpoint.terminate/2`, lines 637–640 | Normal endpoint termination closes owned IO and sends descendant shutdown. Endpoint normal DOWN and independent UDP rebind qualify this public transport boundary, not all native/VM allocations. |

Alternatives considered:

1. **Selected: direct Session with an explicit dedicated endpoint.** Supports
   trailers and retains cleanup ownership through partial connection failures;
   requires a bounded resumable-operation scheduler.
2. Public Fetch with AbortController/Stream. Keep existing functional diagnostics
   and immutable receipts, but its H3 completion boundary remains unsupported.
   Visible stream/task termination is insufficient to enable this adapter.
3. Automatically owned Session endpoint. Smaller happy path, but a connect
   failure can discard the endpoint cleanup outcome. Do not select it for the
   Service completion contract.

No `http_fetch#97`, equivalent native ledger, same-H1-API requirement or private
Fetch ownership inspection is introduced. Source support enables qualification;
UP0-Session must pass before UP1 activation.

## Ownership and process boundary

Keep scheduling and request lifecycle state in the existing
`Gaoxy.Proxy.HTTP.Session` guardian through stateful adapter callbacks. The
downstream endpoint continues to own Exchange reads and Response writes. Do not
add a second permanent request GenServer.

The H3 adapter launches at most **one temporary operation task** at a time for a
public Session call. The task returns the entire advanced Session result to the
guardian and exits; it does not choose the next operation. This task is justified
by blocking native/DNS calls and fault isolation. The guardian remains responsive
to original deadline timers, Service cancellation and monitored owner loss. On
cancellation, at most one additional temporary endpoint-stop task may run while
an old operation is outstanding. No new supervisor, pool or long-lived scheduler
is required. Tasks are linked to the guardian, monitored and correlated by fresh generation/ref;
late results cannot revive a cancelled request.

Bootstrap runs in the operation task: public `Transport.Quic.client/1` creates
the dedicated endpoint linked to that task with `acceptor: guardian_pid`.
The public acceptor option makes the guardian its monitored lifetime owner;
link adoption alone does not transfer that role. Before connect, send the descriptor
to the guardian and wait for explicit adoption. The guardian monitors and links
the descriptor PID, records it in its handle, then acknowledges adoption. Only
then may the creator unlink its endpoint and finish. Connect is a subsequent
operation with `endpoint: descriptor` and `consumer: guardian_pid`. The guardian
traps and handles its endpoint link exits without changing Service token rules.
At every handoff at least one Gaoxy owner remains linked to the endpoint.
After creator normal exit, the adopted endpoint must remain alive and usable;
qualify this ownership handoff with an explicit deterministic barrier.

If cancellation arrives before adoption, the creator stops its endpoint and
reports its stop/DOWN result, or the guardian adopts solely to stop it. A crashed
or deadline-killed bootstrap with no descriptor/confirmed cleanup is
`cleanup_unconfirmed`; it must not become the ordinary allocation-free open
error case. No connect is allowed before adoption, and no normal task exit may
leave an unadopted live endpoint. Deterministic bootstrap/adoption race tests are
required. Guardian abnormal death keeps Service accounting uncertain; links aid
containment but are not forged completion receipts.

The Session value is used only by one task at a time. Between calls it belongs
to the guardian handle; during a call the stored old value is not eligible for
reuse. A task crash may lose the advanced value: terminate this request through
the retained endpoint, never reconstruct or retry from the old value. Other
requests have separate endpoints, tasks, IDs and cleanup tokens.

## Selected callback contract

Keep existing `UpstreamClient` operations, adding declared
`host_supported?/0` and `reservation_bytes/3`. `HTTP` and its guardian select only
the allowlisted module derived from `upstream_protocol`. User module injection
is rejected, including forged/precompiled configuration structs.

`open/1` returns promptly with `{:ok, handle, upload}` after creating the owned
bootstrap task; readiness is asynchronous. The H3 handle is an adapter-owned map:

```elixir
%{
  kind: :http3_session, id: request_id, owner: guardian_pid,
  promise: nil, stream: {:http3_session, request_id}, resolved: false,
  endpoint: nil, endpoint_monitor: nil, endpoint_down: nil,
  session: nil, request_ref: nil, phase: :bootstrap,
  operation: nil, continuation: nil, upload_waiter: nil,
  delivery: nil, events: [], tick: nil,
  deadline: total_deadline, opening_deadline: opening_deadline,
  write_timeout: write_timeout, cleanup_deadline: nil,
  cleanup: :not_started, terminal: false
}
```

Identifiers are fresh references, deadlines absolute monotonic milliseconds.
`operation` contains the task PID/monitor, generation, operation kind and original
operation deadline; it is not a dependency transport handle. Further private
adapter fields may hold bounded request inputs and task results. Session internals
may not be mined for connection/stream handles or used to encode wire frames.

`upload` is `{:http3_session_upload, guardian_pid, request_id, total_deadline,
write_timeout}` for **every H3 request**, including zero bytes. This ensures
`finish_body/2` owns the one terminal action. H3 opens `Session.request/4` with
`:stream`; it never prematurely uses the empty-binary body form, which FINs
initial HEADERS. The existing endpoint already calls finish after body complete.
Allow one early upload call to wait through bootstrap; it cannot be acknowledged
before its actual Session operation completes.

* `poll_headers/1` and `event/2` keep `{event, updated_handle}`. H3 adapter events
  include task results, adoption, public transport wakeups, upload commands and
  its single deduplicated `{:h3_tick, id}` timer. Its own tick continues after
  headers; H1 keeps its existing header-poll behavior. A task result must be
  paired with task termination before another operation starts.
* Headers/chunk/trailer/end/error events retain the existing guardian event
  shapes. H3's non-nil `stream` marker means the guardian never synthesizes end
  on headers. Actual Session `:done` emits end exactly once. `promise` is unused
  by the guardian and remains nil for H3. H1 handle interpretation stays inside
  its existing adapter.
* `subscribe/1` remains `:ok`: direct Session polling already owns delivery.
  `acknowledge/2` may return `{:ok, updated_handle}` for H3 or legacy `:ok` for
  H1. Normalize both in the guardian; stale ACKs cannot clear a current delivery.
* `write_body/3` sends a correlated bounded command to the guardian and waits
  for a reply; `finish_body/2` does likewise with its upload token's deadline and
  write timeout. `event/2` records at most one waiter, schedules the public
  operation and replies only on completed admission or terminal failure. Reject
  overlap. A caller timeout sends cancellation and never resends bytes. Before
  admitting any received command recheck its absolute deadline, so late messages
  cannot start a timed-out upload.
* Extend `cleanup/2` results with `{:pending, updated_handle}`,
  `{:ok, updated_handle}` and `{:error, reason, updated_handle}` while preserving
  legacy H1 results. The guardian stores advanced handles before scheduling or
  stopping. It supplies the existing cleanup deadline through a required
  `begin_cleanup(handle, cancelled?, absolute_deadline) :: {:ok, handle}` callback
  for H3; this is optional for legacy H1. It only records state/starts owned tasks,
  never blocks on transport. Invoke once on entry, then poll `cleanup/2`. This avoids
  extending deadlines on each cleanup poll.
* H3 `completion/1` returns `{:http3_session, guardian_pid, request_id}` and
  `await_completion/2` returns `{:error, :unsupported_group_completion}`. No
  groups consume this token: GroupEndpoint, group options (including structs),
  probes and ForwardHTTP explicitly remain H1. Service completion is the
  guardian's responsibility, independent of H1 group completion APIs.

The `HTTP` endpoint must use the selected module for reservation, write and
finish, as well as the guardian. `:ready` still means the endpoint can offer one
bounded upload command; it does not claim TLS or response-header readiness.
Pass original absolute total/opening deadlines in open options. H1 continues
using its current relative timeout options.

## Scheduler, streaming and semantics

Phases: bootstrap → connect → ready/open → request → streaming → cleanup →
terminal. Send canonical pseudo-fields `:method`, `:scheme` = `https`,
`:authority` from fixed URI (including required port/IPv6 syntax), and `:path`
from escaped origin form, followed by policy-filtered ordered ordinary fields.
Do not forward a second Host field. Preserve empty query, duplicates, compression
bytes, HEAD/204/304 handling and existing trailer policy. Informational Session
events do not cancel the opening timer or become a final head. Public ready/open
must establish authenticated ALPN `h3` before request admission.

For every mutating result retain the returned Session first. Accepted request
returns `{:ok, session, request_ref}`; poll returns `{:ok, session, events}`;
other successful operations generally return `{:ok, session}`; close uniquely
returns `:ok`. Failure tuples are `{:blocked, session, reason}`,
`{:unknown, session, operation_ref}` and `{:error, session, reason}`.

* On unknown, only `resume/1` may reconcile the same operation. No new request,
  DATA, trailer, connect or fresh operation is issued. Indeterminate/error or
  exhausted original budget enters cleanup; unknown does not mean unsent.
* On definite blocked upload, use `suspend_blocked/1`, retaining **one** opaque
  continuation. Poll response/control with that suspended work absent, then use
  `resume/2` on the returned latest Session. Do not reconstruct DATA or restart
  its deadline. Do not suspend unknown operations. Other definitely blocked
  operations use `resume/1`; `open` returning `:not_ready` without a pending
  operation is retried only after a new ready check within the same deadline.
* An early final head stops accepting new upload commands immediately, replies
  to a waiting writer with terminal upload-stop, and uses public `reset_send/2`
  once safe. Discard suspended work via the public reset/cancellation path,
  never resume it. If unknown upload admission prevents response polling, its
  existing write deadline terminates the request honestly; no replay is allowed.
* Default/max H3 upload chunk: 16,384 bytes. One upload call/continuation and one
  unacknowledged downstream delivery at a time. FIN exactly once: no trailers
  calls `send_data(session, ref, <<>>, true, opts)`; nonempty trailers call
  `send_trailers/4` after all DATA admission. Zero-DATA trailers follow the same
  rule. No finish success is exposed before its resumable operation completes.
* Poll with `max = 16`, `max_read_batches: 1`, finite remaining timeout and
  `paused: MapSet.new([request_ref])` while delivery is unacknowledged. This
  permits bounded control processing without new request-body reads. The public
  parser may emit several events in one batch: keep wire order in a queue capped
  at 262,144 payload/field bytes and 256 events. Exceeding either bound is a
  visible request failure. Drain queued events before another unpaused read;
  deliver at most 16,384 data bytes per ACK (split returned data if necessary).
  Do not emit trailers/end ahead of the last DATA acknowledgment.
* Validate fields and trailers with existing Exchange/header limits before
  forwarding; dependencies' 128-field/65,536-byte caps are additional ceilings.
  Bound informational and control-only event counts as part of the same queue.

Use public Session limits `max_frame: 16_384`, `max_fields: 128`,
`max_encoded_headers: 65_536`, `max_header_bytes: 65_536`,
`max_retained_bytes: 262_144`. Transport streams use manual delivery and explicit
`max_data: 262_144`, `max_buffer: 262_144`, `max_ready_bytes: 262_144`,
`max_stream_data_bidi_local: 65_536`, `max_stream_data_uni: 65_536`,
`max_streams_bidi: 1`, `max_streams_uni: 3`, `max_stream_records: 16`.
The dependency derives `max_local_stream_records` as 12; do not pass an ignored
override. UP0 must verify this option combination
against the real peer, including all required H3 control streams. The same
options go to endpoint creation and connect so descriptor verification matches.

Reserve `8 * 262_144 + 8 * max_chunk_bytes +
2 * :erlang.external_size({headers, ""}) + 2 * url_bytes` before bootstrap,
as in the prior design. Account the one task's bounded Session copy and event
queue within this conservative allowance; validate those bounds explicitly.
It excludes native/VM/kernel accounting. Do not shrink it to pass small budgets.

## TLS and deadlines

Config accepts H3 only for a fixed HTTPS authority and a regular explicit CA
file. `client/1` uses `acceptor: guardian_pid`, `host: uri.host`, `tls: [cacertfile: path,
verify: :verify_peer]`, ALPN `h3`, and the fixed stream limits; connect uses that
same URI host, port and equivalent options plus the descriptor and consumer.
No user TLS backend, socket opts, SNI override, verify-none, connect-address
override or arbitrary transport module is accepted. DNS names validate that
hostname; literal IPs require their IP SAN. Raw public Transport connect might
accept options that Fetch rejects, so Gaoxy must enforce its own address-pin
rejection before allocation. Wrong CA/hostname tests require actual TLS
authentication rejection, not any error/timeout.

Never recompute the total/opening deadline from task start. Each operation budget
is the minimum remaining applicable absolute deadline and configured write
timeout; continuation resumption retains its original deadline. Opening ends at
the first valid final response head. The guardian enforces wall-clock deadlines
even while a public call blocks: mark terminal, reject late results and begin
endpoint teardown. Native call completion itself is not promised by the request
deadline. Cleanup has the existing separately bounded Service/guardian grace:
use the earlier of supplied Service cleanup deadline and `total_deadline + 1_000`,
never turn it into a new full request lifetime. Record timeout and cleanup results
separately. Cancellation need not wait until the request deadline to begin stop.

## Cleanup invariant and failure table

Service reservation is released only after this request is consumed/cancelled,
all owned operation/bootstrap/stop tasks have terminated, and its dedicated
endpoint has confirmed **normal** DOWN following public `stop_endpoint/1`
success. A prior observed normal DOWN can also establish already-closed endpoint
state. Stop returning `:ok` after `:noproc` without the corresponding monitored
normal termination is insufficient. UDP rebind belongs to independent acceptance
with a known owned loopback port; production does not acquire/rebind ports on
every request. No private endpoint socket/state query is used.

When possible attempt `Session.close/1` after normal consumption, or `abort/1`
after cancellation/error. Preserve close/abort's full outcome. Because this
endpoint is dedicated, public endpoint stop remains the authoritative local
cleanup boundary even if Session abort reports unresolved shared connect or a
prior request has indeterminate admission. This never changes that request's
outcome to success or claims remote receipt. Start endpoint stop without waiting
for a stuck operation; the stop task is outside that operation. After endpoint
DOWN, terminate any remaining **owned** operation task and observe its DOWN.
Never kill dependency processes to manufacture a normal cleanup receipt.

| Branch | Required disposition |
| --- | --- |
| Pure configuration/session-construction rejection before bootstrap | No allocated endpoint/tasks; ordinary open failure may complete cleanup. |
| Bootstrap failure/cancellation before descriptor adoption | Keep creator ownership; accept only explicit no-allocation failure or its confirmed stop/DOWN. Lost result/crash remains uncertain. |
| Connect error, timeout, unknown or TLS failure after adoption | Keep descriptor even when no Session connection exists; stop endpoint, observe DOWN/tasks, preserve original failure. |
| Normal final response/consumption | Close when possible, stop endpoint, observe termination; then complete Service token. |
| Pending head, blocked upload, unacknowledged response, owner/service/gate loss | Mark terminal immediately, fail waiter once, abort if safely available and stop endpoint concurrently with stuck call; observe endpoint/tasks. |
| Session close/abort blocked/unknown/error | Preserve advanced value/result and request uncertainty; explicit dedicated endpoint teardown can still confirm local resource cleanup. |
| Endpoint stop error, abnormal DOWN, missing DOWN, stop/adoption race or cleanup deadline exhausted | Fail cleanup explicitly and retain Service accounting uncertainty. Never call complete_cleanup. Stop owned tasks safely; late results cannot release the token. |

One confirmed local teardown does not prove the peer observed cancellation.
UP0 independently checks ordinary cancellation at the four required lifecycle
stages and sibling survival. No normal supported path may be activated with a
permanent `cleanup_unconfirmed` implementation; failures remain meaningful.

## Qualification, compatibility and handoff

The [implementation plan](../plans/m4-public-session-upstream.md) specifies
UP0-Session → UP1 → UP2 → standalone H3-origin. Preserve the current Fetch
diagnostic route and receipts; a separate Session gate qualifies this selected
transport. Run two distinct certificate/authority origins, zero/three-byte ordered
trailers with/without valid declaration, bounded upload/download, TLS negatives,
early final responses, timeout/owner-loss/cancellation, normal endpoint DOWN,
owned UDP rebind and sibling survival. Unknown/reconciliation and adoption-race
branches also need deterministic supported boundary doubles; they do not replace
real network proof. Keep actual blocked/failed rows visible.

Core-only consumers must remain free of HTTP/QUIC activation; H1/H2-only consumers
retain their existing closure. H3 uses the already installed coordinated
dependency closure; this assignment authorizes no new package. Preserve H1
reservation/default chunk/TLS behavior, group probes, forward authorization,
CONNECT and existing G3/shared compatibility. Standalone selects H3 through the
existing data-only allowlist; no arbitrary module/config execution or public
management endpoint is added.

Publication follows AGENTS' conditional M4 authorization only after all M4 gates
and independent reviews pass. Deployment, operational certificates, production
data, Vault and disabled release-artifact E2E restrictions remain in force.

Design is complete for Sol review; implementation/runtime checks are NOT RUN by
this assignment. No new product decision is required. Any demonstrated public
API gap is routed under the existing upstream policy instead of adding a private
API workaround. Historical counters in `checkpoint-2026-10-12.json` carry forward;
this architecture consumes zero Astra recovery rounds and resets none.

## Qualified implementation seam — 2026-10-13

UP0 passed all50 rows and independent review, followed by an identical-source
fresh50-row repeat. The documented notification and abort/stop ordering amendments
apply to UP1. For deterministic public-boundary tests, the adapter may expose
`@doc false open(options, driver)` with an arity-three whole-public-call driver.
Production `open/1` always uses fixed supported module/function calls; no config
or compiled struct may inject a driver or transport. This seam provides no
production option and no dependency private-state access. The guardian passes
Exchange field/trailer limits plus original absolute deadlines/max upload allowance.
