# Adaptive resource budget

Status: implemented and published as0.14.0; source and public runtime qualified.
Baseline: `a6a35438c0a153cd53c87c6a55c19a70a11fb75a` on `main`.
The approved objective is adaptive memory accounting and soft admission across
core, native H1/H2/H3, ListenerSet and Phoenix, followed by coordinated release.
This document records the implemented contract. Source, publication and
downloaded-runtime evidence are recorded separately in
[the acceptance record](../acceptance/adaptive-resource-budget.md).

## Completion-credit recovery contract — 2026-10-29

Preserve the existing scalar Admission update contract, which retains temporary
credit. Protocol integration must explicitly request repartition of an admitted
allocation when retained bytes consume prepaid temporary credit or completion
releases retained bytes for reuse. The new operation must preserve the existing
deadline, revision, operation-identity and retry guarantees; it cannot increase
the funded total, quota membership, pending-process count or explicit transport
category allowance. Ordinary replacement retains its growth checks.

Repartition must keep retained/temporary accounting truthful, including across
capacity/safety refresh and completion-credit replenishment. Subsequent new
admission still evaluates `temporary + max(retained - retained_baseline, 0)`;
reclassification must not conceal debit or bypass a new allocation guard. Drain
permits completion within previously funded obligations while fencing new work.
The explicit repartition API and protocol migration are qualified by the final
900-case source gate and independent review recorded in the acceptance record.

Connection completion separates reusable credit from outstanding receive/copy
obligations. Let `F` be the original funded floor including initial retained
state, `R` the current measured retained state and backing ownership, `P` the
unspendable receive/copy floor and `D` the current decoder peak. Target usage is
`max(F, R + P) + D`; temporary ownership remains at least `P + D`. Repartition
may materialize only previously funded completion credit. Any additional total
or decoder obligation still needs checked admission, including during drain.
The protocol must justify the reusable portion from actual overlapping
lifetimes, measure backing through retirement and qualify transport-specific
delivery bounds before reducing them. This does not permit arbitrary growth
or spending the next receive's credit to complete the current callback.

Raw TCP/TLS StreamHandler connections fund `F = 2 * D + 4 * max_state +
3 * max_output` before initialization, where `D = 100 * B + 18_437` and `B` is the
effective public socket buffer. Raw service defaults are 2,048 for
`buffer`/`recbuf`, with explicit transport settings taking precedence. Keep the
whole delivery backing through callback chunking and at least one `D` receive
obligation through callback/output completion. Explicit service byte caps must
fund this floor without a multiplier; smaller caps reject admission. This
preserves ordered raw I/O after the admission barrier without extending the
original drain deadline or changing HTTP/UDP/QUIC profiles.

Before adopting init or returned callback state, retain the historical
`external_size <= max_state` check, detach binary backing with ordinary
uncompressed ETF encoding/decoding, and require exact term identity (`===`).
Encoding/decode failure or identity mismatch fails closed; original returned
state remains available for terminal cleanup. This internal normalization stays
within the same VM and does not change distribution identity. The failed local
ETF closure diagnostic is not the selected codec. Four state obligations fund
old/new/encoded/decoded overlap. Output becomes a detached binary before send;
three output obligations cover source, flattened and independent copies.
Those commitments cover bridge ownership, not arbitrary transient allocation
inside a user callback or NIF. Keep the original callback/drain watchdogs and
actual terminal release proofs throughout normalization and cleanup.

## Baseline and problem

Each service currently owns a separate Admission gate. Core defaults to 1 MiB,
H2-enabled HTTP substitutes 256 MiB, and H3 substitutes 16 MiB. `max_active`
defaults to 64 and counts connection, writer and worker leases together.
ListenerSet already creates one instance for its listeners; there is no shared
instance or VM memory ledger.

Default H2 reserves 30,359,591 bytes per connection, 66,560 for a writer and at
least 196,608 per stream worker. Its maximum HPACK decoding reservation is
142,680,064 bytes; preflight requires 173,302,823 bytes before generation data.
Runtime decoding uses the compressed block size but retains its high-water
charge until connection exit. These are ownership problems, not a reason to
raise the old numeric default.

H1 already grows parser/Exchange/body/send accounting dynamically, but lacks an
explicit request-end counter transition on keep-alive. H3 accounts connection
application state and workers, while service memory also configures QUIC
transport windows/buffers. Those safety limits must be separated.

Fresh baseline verification executed unit 265, component 181 and protocol 137:
583 tests, zero failures/exclusions/skips, all exits 0. Commands, environment,
source and byte-preserving logs are in
`../acceptance/evidence/adaptive-resource-budget/baseline/`.

## Ownership and coordination

Use one supervised `Gaoxy.ResourceBudget.Authority` for the BEAM. Its ledger is
partitioned by instance, service and allocation, with connection/request/stream
identities retained where resources have those owners. Each `Gaoxy.Instance`
registers one instance budget scope; all its services use that scope. All
ListenerSet HTTP/HTTPS/H3 listeners consequently use the same instance policy.
Multiple instances additionally share the same VM capacity pool: starting
another Endpoint does not create another independent 50% allowance.

This boundary matches Gaoxy's embedded multi-instance API. It does not arbitrate
independent Erlang VMs or unrelated operating-system processes. Operators running
independent VMs must explicitly partition their instance budgets, preferably
with container limits. Do not describe VM-local coordination as an OS-wide
memory allocator or introduce an implicit machine daemon.

An allocation records retained bytes, committed temporary obligations, kind,
owner, service, instance, operation identity and terminal lifecycle state.
Kinds distinguish connections, ordinary requests, H2/H3 streams, writers,
transport buffers and cleanup guardians. Temporary and retained ownership must
not count the same bytes twice when ownership transfers.

Recommended internal operations are:

```elixir
register_instance(instance_pid, policy)
reserve(instance, service, owner, kind, accounting, operation_id, deadline)
replace(token, accounting, operation_id, deadline)
transfer(token, new_owner, operation_id, deadline)
release(token, terminal_receipt)
snapshot(instance)
refresh(detection_snapshot)
```

The authority checks shared, instance and service policy and commits each
allocation atomically. Gates must not perform a separate check and uncoordinated
increment. Admission has finite deadlines and no waiting-for-capacity queue.
There is no platform probing, I/O or unbounded calculation in its call handler.

Canonical state includes instance/service registrations, normalized policies,
explicit/omitted-option provenance, lifecycle mode and generation, as well as
allocations. Recover registrations before reopening admission; an unknown
policy is unavailable, never a reason to substitute defaults. Drain fences new
admission before transport teardown. Retire a registration only after all its
allocations, pending mutations and cleanup obligations are reconciled. Unexpected
owner loss retains its orphaned scope until the same terminal proof is obtained.

Use registered gate generations with monotonically increasing operation
sequences and allocation revisions. A mutation fingerprint includes scope,
token/revision, operation, arguments and owner. Identical retry returns the
committed receipt, even after its deadline; conflicting reuse fails. No fresh
mutation may commit after its absolute monotonic deadline, including a request
that expired in a mailbox. The canonical store enforces this at commit.
Keep bounded recent receipts plus a persistent per-generation sequence
watermark: an older evicted operation is expired, never a fresh reservation.
Closed allocation tokens cannot reopen. This bounds deduplication memory while
making timeout reconciliation fail safe.

## Ledger durability and owner failure

A supervised ledger store owns the canonical allocation rows separately from
the authority. The store accepts mutations only from the current authority
generation. A row is committed before acknowledgment; aggregate counters can be
reconstructed from canonical rows after an authority crash. Admission remains
closed until reconstruction and owner monitoring complete.

A timed-out reservation remains owned until reconciled by its stable operation
identity. Allocation is permitted only after a confirmed reservation. Retry or
release cannot duplicate a committed operation or subtract bytes twice.

Loss of ledger contents is a different failure from an authority restart. Fence
the lost generation and reject new admission; never initialize an empty ledger
around live resources. A VM-lifetime generation/fence must survive restarting
the authority/store, or an equivalent supervised continuity mechanism must
prove ownership. Reopening requires verified reconciliation/cleanup; VM restart
is an acceptable recovery boundary for unrecoverable ledger loss. Inspection
must report unavailable/fenced state rather than fabricated zero usage.

Preserve existing worker bootstrap and DOWN/EXIT terminal-pair semantics. Owner
DOWN is not evidence that an asynchronous writer, socket or guardian finished.
Transfer such obligations to their actual cleanup owner and release at its
confirmed terminal event. Orphaned obligations remain charged until reconciled.

### Native QUIC connection cleanup

The native engine can outlive its attached callback process. The connection's
native byte charge and actual connection membership therefore require an
independent authenticated cleanup owner. Callback DOWN/EXIT, an accepted close,
an unavailable inspection or a timeout is not native terminal proof.

Before application-handler initialization, create a Service-authenticated native
reservation pinned to that Service, including the original opaque handle
identity, measured native bytes, one connection membership and funded guardian
bookkeeping/process credit. Callback loss cannot release this pending record.
Start the supervised guardian inertly, then use one canonical split mutation to
move native ownership and the same connection membership to its cleanup record,
leaving callback-only ownership on the callback record. The split preserves
aggregate byte categories, quota membership, process credits and operation/
revision/generation fencing; it cannot duplicate charge or expose a refund gap.
Ambiguous reservation/split or failed guardian registration retains or fences
the pending ownership. Existing scalar/request cleanup contracts remain intact.

Subsequent measured native growth requires authenticated bounded accounting.
Callback ownership and native ownership retire independently. Native release
requires the original handle's exact public `QUIC.info` result
`{:error, :closed}`, the existing authenticated Service cleanup receipt and
normal guardian terminal evidence. Neither `{:error, :timeout}` nor a broadly
matched closed-like error substitutes for that proof. Probes run outside
Admission/Service critical handlers; an outer deadline does not shorten the
public API's internal five-second call timeout. Healthy persistent connections
do not inherit the initial callback deadline as a connection lifetime. Cleanup
once triggered retains one bounded original lifecycle/drain deadline, with
unconfirmed ownership reported and retained rather than fabricated as zero.

Deterministic ordinary coverage must exercise callback loss during initial
registration, split/rollback ambiguity, duplicate/stale/authentication cases,
guardian loss and both orders of callback/native terminal evidence. This is the
required recovery contract; implementation and passing acceptance remain
separately recorded in the plan and acceptance evidence.

## Capacity detection

`Gaoxy.ResourceBudget.SystemMemory.detect/1` returns a structured snapshot:
`capacity`, `physical_bytes`, `cgroup_limit_bytes`, `source`, `fallback?`,
`reasons` and `metadata`. `select/3` and all policy calculations are pure.
Tests inject platform, file reads and the native facility result.

Linux reads physical `MemTotal`, membership and mount metadata, and applicable
memory-controller limits. Resolve mounted roots, escaped paths and nested
controllers without traversal outside their mount. V2 walks ancestor
`memory.max` limits; `max` is unlimited, and a missing root controller file is
normal. Unreadable or malformed applicable finite data cannot silently disable
a limit. V1 uses the current group's own limit and the kernel's
`memory.stat` `hierarchical_memory_limit`, including enforcing parents hidden
above the mount. Do not blindly apply non-enforcing ancestor limits when
hierarchical accounting is disabled. Validate unlimited sentinels explicitly.

For macOS/Windows use the public OTP `:memsup` physical
`:system_total_memory` facility. The built-in `:os_mon` application supervises
its reusable native helper. A bounded monitored probe worker isolates a slow
call; do not spawn a new unmanaged OS command for each refresh. This OTP
application is justified by native ownership and platform APIs; no new Hex or
separately built native dependency is required. Injected tests are not evidence
of executing macOS/Windows native paths.

Accept only finite capacities in `2..9_223_372_036_854_775_807` bytes. Compute
`soft_limit = div(capacity, 2)` and `hard_limit = 2 * soft_limit`, dividing
before multiplying. Unknown/unreliable detection yields soft 268,435,456 and
hard 536,870,912 bytes. An odd capacity rounds down; hard never exceeds it.
Current free memory never determines capacity.

Refresh through a separate worker at a bounded, modest interval; coalesce
explicit refreshes and allow at most one in-flight probe. Install a complete
snapshot and thresholds atomically. A shrink may put existing usage over hard;
it does not revoke admitted work. Detection failures and fallback are visible.

## Three states and projected admission

| Usage | State | New resource admission |
| --- | --- | --- |
| `usage <= soft_limit` | `:normal` | Admit within independent safety/admin limits |
| `soft_limit < usage <= hard_limit` | `:warning` | Continue admitting; rate-limit warnings |
| `usage > hard_limit` | `:over_limit` | Reject new admission; retain existing ownership |

Check projected usage before committing growth: a single allocation cannot
jump across hard. Exactly 100% is normal; exactly 200% remains warning; one
byte beyond 200% is rejected. Actual new zero-byte work is rejected while
already over hard. Releases and existing ownership transfers remain possible,
without underflow, even if usage remains over hard. No hysteresis initially:
recovery is immediate when usage returns within the threshold.

Committed completion/read/write credits remain available to their admitted
request. Pressure alone does not cancel it; new obligations still need
admission. Finite protocol/decoder/single-allocation/process guards and sampled
cgroup OOM headroom remain independent constraints. A separate pressure sample
may reject dangerous growth; it must not shrink physical capacity merely
because unrelated applications temporarily consume memory.

The initial capacity refresh interval is 60 seconds. Safety sampling runs at
most once per second while instances are active; its maximum accepted age is
3 seconds. Obtain the initial sample before making a budget scope ready, outside
the admission server. Use physical available memory (kernel `MemAvailable` or
the supported native facility's available/free physical metric), together with
applicable finite cgroup current/high/max observations. Select the smallest
observable effective headroom and retain the sample's accounted-usage baseline.
Reserve `max(16 MiB, div(effective_capacity, 20))` as unallocated safety headroom.
Serialize projected growth against that sample: growth above its accounted
baseline cannot spend the same remaining headroom twice. Confirmed releases
reduce outstanding growth; resampling replaces the complete baseline atomically.

Required finite-controller safety data that is missing, malformed, stale or
cannot establish headroom produces `:safety_sample_unavailable` for new growth;
insufficient headroom produces `:system_memory_pressure`. Zero-byte new work
still respects over-limit/fenced state and process quotas. Releases and already
committed completion credits remain usable. Detection fallback still supplies
the documented 256/512 MiB policy; inspection separately reports whether safety
data permits growth. Missing safety data must not be presented as zero pressure.
Use the live, inexpensive BEAM process-count/limit BIFs before spawning, reserving
at least `max(128, div(process_limit, 20))` process slots. Report insufficient
capacity as `:process_capacity`; actual backend/OS allocation failure remains a
different reason. Tests inject pressure/time/process observations and race
multiple reservations against the same sample.

Distinguish resource policy (`:memory_hard_limit` and quota reasons), explicit
administrator limits, protocol/single-allocation safety, unavailable budget
authority, and actual OS/backend exhaustion in telemetry and inspection.

## Configuration and compatibility

- An omitted `max_bytes` selects adaptive shared memory policy. Preserve that
  provenance through repeated normalization, planning and deferred activation.
- An explicit legacy `limits.max_bytes` remains an undoubled hard **service
  transport** ceiling. Its existing WebSocket retention semantics remain;
  shared memory accounting additionally includes retained WebSocket resources.
- An explicit legacy `max_active` retains its aggregate lease ceiling. Its
  omission no longer introduces the old implicit 64-lease bottleneck.
- Add independent finite `max_connections`, `max_requests` and `max_streams`
  controls. Writers/guardians do not consume connection/request quotas. Keep a
  separate finite process/lease safety guard.
- Instance `resource_budget` accepts explicit `soft_limit` and `hard_limit`,
  validating their relationship. Never silently double an explicit hard value.
  An instance override still participates in shared capacity/OOM protection.
- Backend connection capacity follows the connection quota. QUIC windows,
  buffers and writer bounds remain finite protocol/transport values and do not
  expand to the detected host memory size.

Normalization and budget calculation remain pure. Public examples should use
adaptive defaults without hard-coded H2 budget overrides; show explicit policy
only where it is an intentional administrator choice.

The normalized service retains a positive numeric `limits` view for protocol
arithmetic and carries its aggregate admission policy separately as
`budget_policy`. Presence is captured before constructor defaults and survives
normalization and deferred activation. An omitted legacy cap therefore projects
to `nil` in the policy even when its numeric transport profile is populated.
`limits.protocol_max_bytes` can carry a finite provider transport default through
ListenerSet planning without turning it into an administrator aggregate cap.
Initial independent service quota defaults are 16,384 connections, 65,536
requests and 65,536 streams. The separate ordinary-lease safety ceiling is
262,144. Backend acceptor fanout keeps its finite safety ceiling of 64, also
bounded by the effective connection capacity so every acceptor has a nonzero
connection allowance. These values do not size QUIC flow-control windows or
queues from host memory.

Quota membership overlaps: every admitted HTTP request consumes request quota;
an H2/H3 request stream additionally consumes the relevant stream quota. One
request cannot bypass the request quota by having a stream kind. Connections
count until their transport/cleanup terminal boundary; ordinary requests count
until completion/cancellation; protocol streams count until their protocol
terminal boundary. WebSocket upgrade ends ordinary-request ownership but retains
connection and, for H2/H3, stream ownership. Pending output/cleanup may retain
memory after a request/stream counter ends. Writer and guardian records consume
memory and the independent lease/process guard, not application request or
connection quota. Ownership transfer must preserve counters without duplication.

CORE uses a same-token stream-retention transition after an H2/H3 worker's
confirmed DOWN/EXIT pair. It atomically removes ordinary request membership,
transfers remaining protocol ownership to the authenticated connection parent,
and ends the legacy worker lease slot. The retained stream still consumes its
stream quota and the independent allocation safety guard until the parent
confirms protocol completion. This is a distinct nonlegacy retention kind,
never a second ordinary allocation or a cleanup guardian. Removing request or
stream membership does not release memory still owned by output or cleanup.

An authenticated parent separately confirms that a worker lease's output and
buffer resources are terminal with `finish_stream_resources/5`. This hook uses
the stable worker lease identity, so it remains usable after stream membership
ends. It does not refund a live worker. Once both worker terminal signals are
confirmed, memory can end while a zero-byte row retains an open stream quota;
the row retires after stream completion as well. Reordering these events must
converge to the same final ownership. Plain `end_stream/5` retains its independent
quota-only semantics, including positive bytes lacking memory-terminal proof.

For an abandoned asynchronous spawn reply, the parent may know its spawn token
without knowing the worker lease. `finish_spawn_resources/5` accepts that token
with the same authenticated resource-proof semantics. An O(1) index lives only
as long as the stream lease. Cancellation is a separate signal and never proves
output/native/guardian completion. Recent retries use the existing bounded
receipt cache; an unknown token is not evidence that an ambiguous reservation
never committed. Retain the original reply/outcome handling and deadline.

## Dynamic protocol accounting

Acquire connection ownership at establishment, account retained state/buffers as
they grow, and release only after termination/cleanup. Track protocol streams
separately from request workers and open connections. Body, response, send and
streaming obligations follow the process/resource that actually owns them.

H1 ends ordinary request ownership on completion, retaining only keep-alive
carry. An overload at a safe request boundary returns a bounded valid 503;
unsafe partial framing closes with normal cleanup. Test independent connections,
uploads, SSE, WebSocket upgrade and keep-alive reuse.

H2 replaces its fixed idle allowance with measured retained state and current
bounded obligations. Reserve decoder expansion before untrusted HPACK decode;
retain strict block, decoded-field, table, frame, flow-control and writer bounds.
Release temporary decoding ownership after its actual lifetime rather than
retaining a high-water value forever. Preserve admitted worker startup and
writer ownership. Refuse the affected new stream where compression/framing
state permits; if decoder safety cannot preserve compression synchronization,
document and test the required connection-level failure. Other admitted streams
must continue during ordinary new-worker overload.

H3 distinguishes QUIC connection/transport state, protocol streams and HTTP
request workers. Preserve QPACK policy, finite buffers/flow control and pending
operation ownership during cancellation, reset and drain. Resource refusal uses
protocol-correct request rejection (`H3_REQUEST_REJECTED`, 0x107) when possible.
New connection refusal must close sockets/transport handles and workers.

## Monitoring and verification

Expose `Gaoxy.resource_budget(instance)` with effective capacity/provenance,
soft/hard thresholds, retained/temporary usage, active connections/requests/
H2/H3 streams, state and rejection counters/reasons. Consumers must not inspect
private GenServer state. Emit Gaoxy telemetry for snapshots, state transitions,
rejections and detection fallback. Warning logs include instance/service,
usage, thresholds and pressure reason, with a finite monotonic rate limit.

Verification follows current AGENTS boundaries: isolated units without sockets
or complete runtimes; component/protocol real-network peers on Linux; minimal
portable smoke in `portable.yml`; package/source-consumer/release qualification
in their existing workflows. No browsers or specialist pressure-suite expansion.
Classify every new app test with exact positive executed counts.

Required qualification covers detection/fallback/boundaries/recovery, independent
H1/H2 connections and concurrent H2 streams, H3 requests, Phoenix LiveView/WS,
SSE/streaming/uploads, churn, multiple ListenerSets/instances, explicit options,
owner crashes/cancellation/drain, warning telemetry and rejection reasons.
Complete independent architecture/specification/code review, repair findings,
then qualify the integrated publication source. Commit on the current branch,
push, use the coordinated release workflow, and verify public artifacts and all
six same-version Hex distributions. Production deployment/data stay excluded.
