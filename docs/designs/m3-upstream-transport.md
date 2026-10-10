# M3 upstream transport ownership and qualification

Date: 2026-10-10. Architecture decision, not runtime acceptance. Gaoxy baseline
`d92d3691e073fbf33195b567af7be10cea6132fc`, branch `codex/m3-gateway`, worktree
`.trees/m3-gateway`. Read together with `m3-gateway.md`,
`m3-upstream-groups.md`, and `../plans/m3-upstream-transport.md`.

## Decision and present gate

Current external gate, 2026-10-11: #86–#89 are now CLOSED in the
[remote receipt](../acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-refresh3.json).
GitHub/Hex0.21.1 is published while the installed cohort remains0.21.0;
containing-source, installation and renewed qualification are required.
New [Bug95](../dependency-requests/http-fetch-otp28-tls-tracking.md)
blocks actual OTP28 TLS-process tracking/release. Finite public retirement
observations cannot certify unregistered receiver/sender termination. Do not
patch dependencies, use private resource tracking or lift activation gates.

Use the public HTTP Fetch request/stream/completion contract behind the existing
`Gaoxy.Proxy.UpstreamClient` adapter. Reusable transports must additionally have
an explicitly owned, bounded transport resource with confirmed retirement.
Keep immutable route pins and request guardians; a request completion receipt
and a transport retirement receipt prove different things.

Installed coordinated HTTP packages are now **0.21.0**, actual tag commit
`9813c126dc8b48055b9ee941c693fc27fa691489`. The
[release provenance](../acceptance/evidence/m3/upstream-transport/upstream-0.21/release-provenance.json)
verifies all seven archives, checksums and #78/#79 fix ancestry. The
[installed provenance](../acceptance/evidence/m3/upstream-transport/upstream-0.21/installed-provenance.json)
matches all 196 shipped files and 175 runtime Git blobs. The upgrade's
[compatibility gate](../acceptance/evidence/m3/upstream-transport/upstream-0.21/compatibility.json)
passes strict format/compile and 460 tests, seed21102026; this does not qualify
managed transport activation.

The caller-owned facade requested in #78 and fragment cap requested in #79
are present in these installed artifacts. H2 activation remains **BLOCKED** on
[Bug #86](https://github.com/gsmlg-dev/http_fetch/issues/86): valid peer-driven
decoded-head events and asynchronous SETTINGS capacity updates lack a hard
aggregate outstanding-event bound. Two independent source reviews confirm the
gap; no runtime leak or memory-exhaustion claim is made. H1 functional
qualification proceeds separately with an explicitly narrow policy, while its
complete retained-byte reservation remains unqualified. Neither the H2
52,207,632-byte subtotal nor H1 261,199,114-byte subtotal is an activation budget.
The [controlled H1 architecture](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
replaces uncertified delivery/copy assumptions with named P0–P6 obligations.
The [pure preparation design](m3-managed-h1-preparation.md) and
[scoped plan](../plans/m3-managed-h1-preparation.md) can implement bounded compact
inputs and constructor facts before process integration. They cannot return
an activation budget or open managed resources while those proofs remain open.
Independent conditional source follow-ups now cover request/wire constructors,
the33-entry FetchOptions HAMT structural envelope and control-turnover/TLS
evidence; see [current acceptance](../acceptance/m3.md) for their separate
reviews and identities. They close no complete P0–P6 obligation. Helper/native
layout costs, policy/host-CA overlap, loaded-code/profile enforcement and
simultaneous root/copy/control release remain required before Task4 integration.
Subsequent conditional native Binary/message/fragment formulas pass independent
source review, and a34-module checkpoint establishes point-in-time BEAM/native
identity. Actual native ABI, other object classes and lifetime enforcement stay
open. Published0.21.1 now requires the separate
[patch qualification plan](../plans/m3-upstream-0.21.1-qualification.md);95 is
still open and the installed0.21.0 proof cohort is unchanged.
The bounded policy/CA trace establishes warm snapshot sharing and explicit-DER
option constructor components. Cold cache loading/replacement and immutable
snapshot enforcement remain required; the global exclusion cannot absorb owned
copies after mutation. Full P3 and simultaneous policy-copy lifetimes stay open.

The historical 0.20 public probes passed16/16 on complete202-file maps, and its
finite empty-CONTINUATION diagnostic was INCONCLUSIVE. Preserve that evidence
unchanged. Installed0.21 finite public capacity, deadline, isolation, retirement
and256/257-frame regressions now pass39/39 with39 joined cleanups and425 stable
hashes in `managed-probes-recovery1.json`. Canonical H2 connection-capacity
errors remain MISMATCH under needed#89. This result closes no retained-byte,
Gaoxy integration, version-matrix or managed-soak gate.

### Installed-source checkpoint, 2026-10-11 Asia/Shanghai

Upstream closed #79 through PR80, merge
`ed7a8e23fb969b1337703d8ea5d12f774e5a5edb`, and #78 through PR81, merge
`a75ec3c34446a1877366a0e52055743d28eabcc9`. Independent Sol inspection of
PR81 head `11f1642cf6408219d4813772bda1055e605bbdc4` finds the requested
public facade. The
[independent source/API and architecture receipt](../acceptance/evidence/m3/upstream-transport/source-api-review.md)
preserves that preparatory checkpoint. Release38067971805 completed successfully
at workflow head `0833de2c4bbe7567cc19eed4a86a69005d2058f6`; all four critical
audited facade/policy/scope/H2-owner blobs match the installed0.21 release.
Package provenance is qualified; Gaoxy managed runtime acceptance remains pending.

The public source contract is:

| Operation | Exact result / integration constraint |
| --- | --- |
| `HTTP.ManagedTransport.open(options)` | `{:ok, scope}` or error; opaque scope monitors its creator |
| `HTTP.fetch(url, transport_scope: scope, ...)` | Original Promise/completion; raw acknowledged streaming, manual/error redirects, frozen matching origin/policy |
| `HTTP.ManagedTransport.snapshot(scope, timeout_ms)` | `{:ok, aggregate_snapshot}` or error; finite timeout, redacted aggregate counts and limits |
| `HTTP.ManagedTransport.retire(scope, mode: :graceful)` | `{:ok, receipt}` or error; also `:abort`; repeated calls share the durable receipt, graceful can escalate to abort |
| `HTTP.ManagedTransport.await_retired(receipt, timeout_ms)` | `:ok`, `{:error, :cleanup_pending}` or `{:error, :cleanup_unconfirmed}`; success also requires coordinator termination |

Scope limits are `max_requests` 1..2048, `max_connections` 1..256,
`max_pending` exactly 0 and `idle_timeout` 1..60000 milliseconds. Preparation
and unread responses hold request slots. Connecting, TLS and protocol-owner
resources retain connection capacity until all tracked resources terminate.
Per-request budgets are excluded from managed reuse identity. These findings
still require public network and retained-state qualification on installed
containing artifacts.

`open/1` requires `origin`, literal `connect_address` and explicit `http_version`.
Optional keys are `tls_backend`, `ssl`, `socket_opts`, `max_requests`,
`max_connections`, `max_pending`, `idle_timeout`, `http2_profile`; unknown and
duplicate keys reject. Only OTP `:ssl` and `:native_v1` are supported. Gaoxy's
prepared policy remains narrower than any unrelated optional upstream feature.

PR80 caps header blocks at 256 total frames, including initial HEADERS and
final END_HEADERS. Frame257 fails before retention/HPACK decode; empty payload
fragments are omitted and the 65,536 compressed-byte limit remains. The
`:header_block_too_fragmented` error closes the connection. Affected pooled
request cleanup may conservatively return `:cleanup_unconfirmed`; the regression
must preserve that outcome and prove an independent connection progresses.

The containing-artifact gate for #78/#79 is satisfied by the published0.21
cohort. Use those portable Hex manifests and exact lock checksums; no dependency
patch or locally staged replacement release is needed. Public fixtures and the
numeric accounting worksheet are separate gates.

| Approach | Tradeoff | Decision |
| --- | --- | --- |
| Public managed transport resource, used by Fetch and retired through a public receipt | Requires upstream lifecycle support; gives bounded ownership and preserves the existing streaming adapter | Selected |
| Unique generation scopes on the existing global pools, followed by an idle-timeout sleep | Easy reuse isolation, but no instance ownership, configurable global admission, or confirmed retirement; idle transport state outlives request reservations | Rejected |
| Gaoxy-managed sockets using low-level H2 owners/pool keys, or a second HTTP client | Reimplements client lifecycle and binds Gaoxy to internals or changes dependencies | Rejected |

No registered process name, `:sys` state inspection, private pool call, global
application-environment mutation, timeout sleep, or `GenServer.stop/1` on a
shared pool is a substitute for the public facade. Disabling reuse can prove
request semantics but cannot satisfy the reusable-transport gate.

## Request API and historical global-pool evidence

These request APIs, already qualified on0.20, remain in installed0.21. The
managed operations above add caller-owned scope selection and retirement.
The later proposed Gaoxy interfaces remain design interfaces.

| Public contract | Use / limitation |
| --- | --- |
| `HTTP.fetch(url, options)` | Explicit `http_version: :http1`, `:http2` for TLS H2, or `:h2c` for prior knowledge; manual/error redirects, direct TCP or OTP TLS |
| `HTTP.Promise.completion(original_promise)` | Capture before awaiting headers; chained promises are unsuitable |
| `HTTP.RequestCompletion.await(completion, timeout)` | `:ok`, `{:error, :cleanup_pending}`, `{:error, :cleanup_unconfirmed}`, or unsupported error; finite nonnegative timeout |
| `HTTP.RequestCompletion.abort_and_await(completion, timeout)` | Cancels only this request and waits under the same finite timeout; healthy pooled siblings remain live |
| `HTTP.Stream.start_link(0)`, `chunk(stream, binary, timeout)`, `finish(stream, trailers)` | Unknown-length streamed upload; finish validates ordered duplicate permitted trailers, at most 128 fields / 65,536 serialized bytes |
| Acknowledged response messages | Existing `{:read_chunk, consumer, :ack}`, `{:stream_chunk, stream, bytes, ref}`, `{:stream_chunk_ack, ref}`, `{:stream_trailers, stream, fields}`, terminal/error messages remain the adapter surface |
| `http1_reuse`, `http1_scope`, `http1_pool_size`, `http1_idle_timeout` | Idle size 1..16 per route/policy; 1..60,000 ms retention; global 256 idle sockets. Neither active-connection admission nor a caller-owned pool handle |
| `http2_reuse`, `http2_scope`, `http2_profile` | Reuse defaults true. Scope is an atom/string isolation value, not an ownership or retirement handle |
| `connect_address` | Validated literal IP dial; preserves URL authority/SNI/certificate hostname; no DNS fallback or replay; part of reuse identity |

The historical0.20 audit found that
`deps/http_fetch/lib/http/request_completion.ex` explicitly separates pooled
request cleanup from shared connection lifetime. At that checkpoint, `FetchOptions` had no pool
handle or retirement option. `deps/http_fetch/lib/http/socket_client.ex`
`maybe_reused_http2_owner/4` and `register_http2_owner/7` select
`:http_fetch_http2_pool`. `deps/http_runtime/lib/http_runtime.ex` starts that
global pool with its name. Public `HTTP.HTTP2.Pool.start_link/1` can create a
pool with capacity settings, but Fetch cannot select it. Its owner-specific
`mark_draining/3` requires internal connection identities and does not retire a
scope. `HTTP.HTTP1.Pool` is `@moduledoc false` and globally registered.

H2 pool defaults are two connections per key, 20 total connections, 100 keys,
100 streams per connection, 100 pending reservations per key, and 30 seconds
idle retention. These are source observations, not Gaoxy-owned limits or an
endorsed API for changing the shared pool.

`HTTP.HTTP2.PoolKey.build/4` isolates scheme/authority/protocol, numeric pin,
TLS options/backend, profile, scope, socket options and connection policy. TLS
file identity includes contents and metadata, not only a pathname. It also
includes `connect_timeout`; socket identity includes `send_timeout`. The current
Gaoxy adapter supplies remaining request budgets in these fields, so requests
to the same origin can acquire different keys. Do not round or extend deadlines
to manufacture reuse. The installed managed contract separates immutable
transport policy from decreasing request deadlines. Qualification must prove
both reuse with unequal remaining budgets and real deadline expiry without
mutating a healthy sibling.

## Required upstream managed-resource contract

This section states required capabilities. The installed facade supplies the
operations above, but complete accounting and runtime qualification remain
prerequisites before dependent Gaoxy runtime edits.

1. Create a transport resource under an explicit owner, returning an opaque
   identity usable in Fetch. Bound resource count, connection attempts, active
   and idle connections, H2 streams, pending requests and retained bytes. All
   bounds include connecting, draining and retiring resources. Prefer no queue
   for Gaoxy; reject saturation before request bytes and never fall back to a
   global pool. Support H1 reuse and H2 under the same ownership principles.
2. Bind immutable protocol, authority/dial identity, TLS trust/credentials,
   wire/socket policy and isolation identity. Never reuse across incompatible
   policy or transport generations. Explicit H2 must fail when ALPN does not
   negotiate H2; no silent H1 fallback. Per-request remaining time does not
   create a new transport identity or mutate siblings' socket policy.
3. Stop admission and retire the complete resource through an opaque receipt.
   Normal retirement waits for admitted requests, closes idle connections,
   prevents later checkin from resurrecting the resource, and confirms all
   owned connectors/sockets/streams are released. Forced retirement cancels
   that resource's requests within one caller deadline. It never affects
   another resource, service or generation. Pending/unconfirmed outcomes remain
   observable; process death alone is not success.
4. Keep request completion as the sole request-reservation release barrier.
   Cancellation during dial, queueing, upload/trailer write and response
   delivery must resolve ownership without replay and preserve healthy H2
   siblings. Completion can be awaited from a guardian other than the caller.
5. Expose bounded, redacted usage/limits or a documented conservative accounting
   contract sufficient to reserve capacity before allocation. Document payload,
   header/HPACK, queue, copied delivery, control-message and idle-connection
   coverage and exclusions. Missing proof is not a zero-byte contribution.

Upstream implementation details are its maintainers' decision. Gaoxy must not
locally implement these missing transport operations. If separate bound or
deadline-identity defects are demonstrated, route them with focused evidence;
do not claim a vulnerability from an unverified accounting concern.

## Gaoxy boundaries and proposed interfaces

Keep core `gaoxy` independent of HTTP Fetch and preserve `gaoxy_http`'s generic
`Resources` contract. Introduce `Gaoxy.Proxy.UpstreamTransports` only after the
public prerequisite is released and qualified. It owns mutable transport
metadata/admission, not an HTTP protocol implementation. It implements the
existing resource-provider callbacks and delegates physical transport lifetime
to the public managed API.

Proposed Gaoxy interfaces (implementation names are settled here):

```elixir
UpstreamTransports.start_link(instance: instance_pid, limits: limits)
UpstreamTransports.prepare(owner, options, preparer_pid, absolute_deadline)
# {:ok, transport_handle, preparation_pins} | {:error, reason}
UpstreamTransports.checkout(handle, request_pins, guardian_pid, absolute_deadline)
# {:ok, immutable_client_policy, transport_token} | {:error, reason}
UpstreamTransports.bind_completion(handle, token, completion)
UpstreamTransports.finish(handle, token)
UpstreamTransports.retire(owner, absolute_deadline)
# {:ok, retirement_receipt} | {:error, reason}; idempotent, deadline never extended
UpstreamTransports.await_retirement(retirement_receipt, absolute_deadline)
# :ok | {:error, :cleanup_pending | :cleanup_unconfirmed | reason}
UpstreamTransports.status(handle)
# Bounded redacted counts/lifecycle/limits; never sockets or credential material.
# Facade: Resources.pin_many/4 and Resources.release/1.
# Provider callbacks: pin_many/5, release/1 and cancel/2.
```

A handle contains `provider`, owner PID/epoch and an opaque generation identity;
it contains no connection PID/socket or dynamically created atom. Validate all
handles and caller identities. Start an owner explicitly under the instance's
supervising application; `Endpoint.init/1` remains pure and accepts only prepared
resources. No hidden global owner or new process started during route compile.

`Proxy.HTTP` accepts an optional prepared `transport` in its immutable config
and returns it from `resources/1`. Existing configurations remain dedicated H1.
A reusable config's upstream authority, numeric pin, TLS policy and protocol
must match the prepared transport; conflicting duplicate configuration rejects
before activation. The prepared policy is authoritative after validation.
Fixed endpoints outside Generation require an explicit baseline holder and
obtain a request pin around dispatch, as GroupEndpoint already does.

Group member configs may reference prepared transports. `GroupEndpoint.resources/1`
returns the group handle and the deduplicated transport handles for its bounded
member vector, via metadata recorded in the immutable prepared group handle.
Thus Generation pins all reachable resources atomically through existing
provider batches; keep the existing maximum of 64 sidecar handles. Do not add
unbounded recursive provider calls inside either owner. Group preparation must
hold candidate transport preparation pins until router activation or rollback.

After existing service cleanup activation, Session performs its group selection
once, then checks out the selected transport as the guardian PID, then opens
one Fetch request. Bind that completion to every held group/transport token
before notifying the upload pump. A failed transport checkout releases the
group selection only when no request was opened; it does not select a different
member or retry. `UpstreamClient` retains existing callbacks; `open/1` receives
the selected immutable public client policy as additional internal metadata.

Probes use the same selected transport policy and retain a request/transport
hold through confirmed completion, within the existing separate probe budget.
They cannot borrow an unpinned transport during retirement. A group generation
with a transport requires candidate transport pins before scheduling probes;
request and probe holds are acquired outside the group owner to avoid a
cross-owner blocking cycle. Unknown/unhealthy selection and health thresholds
otherwise keep their existing semantics.

## Generations, cancellation and retirement

The ownership chain is instance -> bounded transport record -> managed upstream
resource, with independent metadata pins and request tokens. Existing
Generation CAS, one retired sidecar, provider-operation cancellation and
holder monitors stay unchanged. A route activation never performs network I/O
in `Generation.Store`.

When baseline/preparation pins disappear, mark the transport `retiring` and stop
new pins/probes. Old request pins may still check out their captured resource;
do not close it before those pins and already-selected requests settle. Begin
upstream physical retirement only after all request pins, request tokens and
probe holds clear. Retain the transport record, slots and connection byte
reservation until the public retirement receipt confirms completion. A new
generation receives a distinct resource even when its origin matches.

Instance shutdown prevents new admission immediately and uses the existing
absolute drain deadline. Allow admitted work while time remains, then request
scope-local cancellation/retirement. A graceful drain can finish early only
after request cleanup and transport retirement are both confirmed. Retiring or
failed resources still count toward finite capacity. Never restart a blank
ledger over potentially live old transports.

### Concrete instance-stop hook

The current `Gaoxy.stop/2` drains only services; an external owner's reaction
to instance DOWN is too late to contribute to its success receipt. Add a small
generic lifecycle-participant registry owned by `Gaoxy.Instance`. Core stores
only PID, monitor, registration reference, epoch and bounded outcome metadata;
it has no HTTP Fetch dependency, transport types, provider callbacks or socket
access. This is a required conditional core integration, not existing behavior.

Proposed Gaoxy registration API:

```elixir
Gaoxy.register_lifecycle_participant(instance, timeout)
# Called by the participant itself before allocating any external resource.
# {:ok, registration_handle} | {:error, reason}
```

The instance authenticates the calling PID, allows one registration per PID,
caps registrations (including failed entries) at 64, monitors each participant
and rejects registration once stopping begins. Registration is instance-lifetime;
there is no silent unregister or replacement after participant death. The
transport owner registers during startup before preparing managed resources.
An unconfirmed registration must never be followed by resource allocation.
Use temporary children; a restarted owner cannot replace a failed registration
and erase its cleanup uncertainty. Endpoints still receive prepared handles.

The merged facade monitors the process calling `open/1` as scope creator;
creator DOWN initiates abort retirement. Each admitted transport record therefore
has one bounded persistent proxy custodian, created only after the ledger's core
registration and capacity reservation. The custodian calls `open/1` and remains
alive through retirement; short-lived preparation workers must not create scopes.
Opening also uses a fixed 5,000-ms handle call with no caller deadline. If
preparation expires before its result, reject publication, retain the allocation
reservation and retire any late-created scope. Caller death or a lost result is
not cleanup proof.

`Gaoxy.stop(instance, timeout)` remains the user/configuration-owner entrypoint
and computes the one absolute deadline D. `Instance.operation` snapshots both
services and participants after closing instance configuration admission. Its
bounded coordinator starts service drains and sends each registered participant
`{:gaoxy_lifecycle_drain, registration, operation, coordinator, D}` in the same
dispatch phase, then joins both result sets concurrently. A participant verifies
the registration and operation, starts the same idempotent operation exposed by
`UpstreamTransports.retire/2`, and returns
`{:gaoxy_lifecycle_result, registration, operation, self(), result}` to that
coordinator. Only matching registered identities and the active operation count.
No callback/network wait runs in the instance server, and participants never
need a call back into the instance to complete shutdown.

Transport retirement closes new preparation, pin and probe admission. Already
admitted snapshot pins and requests may finish until D; ordinary idle resources
with no request pins/tokens retire immediately even if a configuration baseline
pin remains. Shutdown invalidates those baseline/preparation pins as admission
capabilities instead of waiting for a still-live Generation store to release
them. At D, cancel remaining requests and request resource-local forced
retirement through the qualified public upstream contract. The transport owner
awaits every upstream retirement receipt; its Gaoxy receipt returns `:ok` only
after all connectors, active/idle transports and cleanup-held reservations have
confirmed retirement. A request/service cleanup token is not required for an
idle resource to participate in this barrier. Repeated retire/await calls join
the same bounded operation; a later deadline cannot extend D.

The stop coordinator reports `:ok` only when services and all participants
confirm cleanup. Pending at D yields the existing
`{:error, {:deadline_exceeded, :cleanup_pending}}`; lost proof/participant DOWN
without a prior success receipt yields a resource-tagged `:cleanup_unconfirmed`.
For confirmed participant failures, aggregate bounded service/resource errors
as `{:error, {:shutdown, service_errors, resource_errors}}`; preserve existing
service-only return shapes when no participant is registered. A participant
success receipt confirms its resource retirement, not remote delivery. A
coordinator crash is a cleanup error. No timer expiry, owner DOWN or instance
DOWN converts missing proof into success.

`Instance.terminate/2` must use the same combined service/participant shutdown
helper: reuse D for an explicit stop, or choose its existing bounded shutdown
deadline for supervisor-triggered termination. Preserve already-confirmed
results and never overwrite a pending/failed result with service-only success.
Existing cleanup headroom may finish forced cleanup after D, but it cannot
extend the public success budget. In ordinary embedding, the configuration
owner calls `Gaoxy.stop/2` while participant siblings are still alive, then
stops its enclosing supervisor. A raw supervisor stop is not a public Gaoxy
cleanup receipt; forced kill paths can only report uncertainty.

Public `retire/2` itself has a fixed 5,000-ms control call and no caller timeout.
Run initiation in monitored, bounded proxy helpers, without blocking the core
participant, transport ledger or custodian. Limit each scope to one initiation
and, when needed, one abort-escalation helper; keep unsettled helpers represented
in admission/accounting. Close local admission before starting them. Receipt
waits use `max(D - now, 0)`; a helper outliving D cannot extend the stop success
budget. If initiation loses its result, reconcile with bounded repeated public
`retire/2` calls to recover the same receipt. Never construct or inspect receipt
fields. Late confirmed retirement may refund retained capacity, but cannot
retroactively change a timed-out stop result to success. A retired-scope snapshot
error alone does not prove cleanup.

The externally supervised transport owner remains alive through its retirement
operation even if the instance exits. On unexpected instance DOWN it refuses
all new work and starts forced retirement using the already-known D, or a
configured finite emergency deadline if no stop operation was received. This
fallback is cleanup work, never retroactive evidence that `Gaoxy.stop/2` passed.
Bounded guardian recovery still uses public request completion. Owner death
before all receipts confirm leaves the registry/receipt failed and capacity
unconfirmed; no empty-ledger restart is allowed. After confirmed retirement the
owner remains inert and can return its cached receipt until instance DOWN,
then terminates normally. This avoids racing participant DOWN against the
coordinator's success receipt; existing awaiters retain the terminal result.
Unrelated instances and participants are unaffected.

Implementation files: `apps/gaoxy/lib/gaoxy.ex`, `gaoxy/instance.ex`,
`gaoxy/lifecycle.ex`, the new proxy transport owner and its supervising setup.
Core tests use a controlled generic participant; real public transport tests
must additionally hold idle retirement at a barrier and prove `Gaoxy.stop/2`
cannot report success before that receipt, including deadline and owner-death
cases. No change to `Resources` facade/provider arities is needed.

Session normal finish awaits public request completion. Downstream RST, owner
death, timeout and upstream error call request-local abort-and-await. Only
`:ok` releases group/transport request slots and the service cleanup token.
`:cleanup_pending` retains them; lost proof retains capacity and marks the
resource failed. A guardian dying after completion binding can be recovered by
the existing bounded public-completion recovery pattern. Death between opening
and binding remains fail-closed, not a reason to infer closure or reopen.
Request abort never invokes resource retirement while healthy siblings run.

## Immutable TLS and destination policy

Use OTP TLS with hostname verification and trust enabled. Preserve original URL
Host/authority and SNI while dialing only the already-validated numeric address.
Forward proxy policy still validates destinations at connection time; this
slice adds reuse only to fixed/prepared reverse-proxy targets. Dynamic forward
destinations remain dedicated until they have a separately bounded identity
and pin-lifetime design.

Freeze trust material at transport preparation, within the existing finite
configuration budget, and pass supported in-memory `ssl: [cacerts: ...]` values
instead of rereading mutable `cacertfile` paths at each checkout. Read/validate
the file with an enforced byte limit before PEM decode; bound both source and
decoded material and clear transient copies from retained configuration.
For default trust, capture the supported OTP CA set under the same bound.
The old generation therefore keeps its original trust, and a new generation
gets a new resource/identity after rotation. File-content hashing in the client
is useful isolation but does not itself freeze a configuration generation or
eliminate a file-read-to-dial race.

No new client-certificate, Vault or operational-certificate feature is added.
If such credentials are introduced later, their immutable content identity and
secret ownership must join the same transport key; paths, raw secrets and
authorization headers must never become telemetry labels or scope strings.
Shared TLS/name/pin rejection is a terminal attempt with no fallback/replay.

## Streaming and trailer semantics

Use explicit upstream protocols; `:auto` is outside the completion contract.
Preserve raw entity bytes with `decode_body: false`, `stream_response: true`,
`request_mode: :proxy`, `redirect: :manual`, and `tls_backend: :ssl`. Preserve
one credited upload piece and one downstream-consumption acknowledgment chain;
never collect an arbitrary body to obtain reuse.

H1 upload trailers require unknown-length chunked upload plus declared names.
H2 uses `Stream.finish/2` and terminal HEADERS/CONTINUATION after DATA; ordered
duplicates remain separate. Gaoxy's existing stricter allowed-trailer policy
continues across both versions: undeclared/forbidden fields fail rather than
silently changing the established security policy. Matrix fixtures must declare
their allowed names even though upstream H2 does not require declarations.
The protocol engine translates framing; never forward H1 chunk delimiters or
`transfer-encoding` onto H2. Head/status/HEAD/bodyless/content-length rules remain.

Test request and response trailers separately and together, empty bodies,
duplicate ordinary fields, raw compressed payloads and informational responses.
An early final response abandons the unfinished upload and unsent trailers;
healthy siblings must continue. A partial shared-connection write can legitimately
fail all its streams; tests distinguish this connection failure from a clean
request-local cancellation, for which sibling survival is required.

## Conservative retained-byte accounting

Current `HTTPFetchClient.reservation/3` is H1-specific: eight windows of the
qualified OTP/TCP maximum delivery plus 65,536-byte framing carry, eight upload
chunks and duplicated request metadata. Preserve its host assumptions and
exclusions; do not relabel that expression as an H2/shared-pool bound.

Installed0.21 source provides useful finite inputs: H2 synchronous writer batch
1,048,576 bytes, which is not an aggregate send/control queue limit;
receive DATA budget at least 1,048,576 bytes with the default profile;
65,536-byte compressed header block; HPACK 65,536 decoded bytes and 256 fields
with a default 4,096-byte dynamic table; upload bridge 65,536 bytes with 16,384
byte pieces. Informational accumulation and response trailers have independent
limits. These do not alone establish a complete mailbox/copy/idle bound.

Reserve a conservative maximum for the full configured managed-resource
capacity **before creation**, including connecting and idle connections; add
per-request metadata/upload/delivery allowance before Fetch. A suitable ledger
decomposition is:

```text
transport = config_and_secret_bytes
          + max_connections * (receive_credit + framing_and_headers
              + hpack_tables_and_decode_transient + bounded_write_overlap
              + delivery_copy_overlap + bounded_control_metadata)
          + max_pending * bounded_pending_metadata
request   = upload_bridge_and_source + delivered_response_and_copy_overlap
          + headers_and_trailers + guardian_and_request_metadata
```

Count overlapping copies until their acknowledgment; double-counting shared
allowances is acceptable for a conservative first profile, undercounting is
not. Reserve all possible member transport/request requirements before group
selection, without allocating example payloads. Probe reservations remain
separate and finite. Transport bytes survive the last request's cleanup until
confirmed retirement. The instance owner exposes its separate reserved total;
service cleanup continues to expose request-held bytes. Do not present either
as a total BEAM/RSS/kernel measurement.

The historical empty-CONTINUATION metadata defect (#79) is fixed by the installed
256-frame cap and empty-fragment omission. The current H2 gap is #86: decoded
response-head events are accumulated and sent without recipient admission/ACK,
and valid SETTINGS produce asynchronous pool capacity casts without a hard
outstanding-update cap or coalescing. DATA credit, per-block limits, active-once
receive and the synchronous writer batch do not bound those retained events.
See the
[source-derived worksheet](../acceptance/evidence/m3/upstream-transport/retained-bounds-source.md)
and [independent bounds review](../acceptance/evidence/m3/upstream-transport/upstream-0.21/independent-bounds-review.md).
H1 excludes those H2 paths and the buffered-iodata input under its frozen
nil/PID upload contract, but still requires policy/copy/structure, process,
ETS, monitor/timer/control metadata and exact managed OTP delivery accounting.

The implementation gate requires a source-derived numeric worksheet for the
exact release/profile and a corresponding finite public lifecycle/bounds
contract. Control-frame floods, zero-length fragmented headers and message
queue growth require focused adversarial checks; DATA flow control alone is
insufficient evidence. No final H2 reservation constant is approved by this
document because its complete retained-state bound remains unresolved. Missing
terms cannot be zeroed or replaced by an arbitrary multiplier.

## Acceptance and compatibility

Qualify all four downstream/upstream H1/H2 combinations; TLS H2 and prior-
knowledge h2c are separately named results. Use Python `h2`/raw TCP peers
independent of Gaoxy and HTTP Fetch, recording accepted connection identities,
stream IDs, request count, DATA progress and exact trailer order. One H1 TCP
accept must serve two sequential requests. Two simultaneous H2 streams must
share one upstream connection; cancel one while the peer holds it at a barrier,
then finish and open another sibling on that same connection.

Additional gates: unequal request deadlines still reuse; overload sends no
request and cannot create unbounded waiters; stale H1 socket and H2 GOAWAY cause
no request replay; old snapshot paused before checkout survives reload; same
origin with changed trust/pin reaches only the intended peer; CA replacement at
the same path changes only the new prepared generation; retired idle sockets
close with public retirement confirmation; independent scopes and live siblings
survive another scope's force retirement; downstream slow/reset and stalled
upload/trailer writes retain reservations until cleanup. Run repeated generation
updates with active/idle transports and finite limits, proving counts plateau
and return to their baseline after confirmed retirement.

Require a fresh managed-resource soak of **at least 600 seconds per profile**:
one actual H1-reuse profile and one multiplexed TLS-H2 upstream profile. Existing
fixed dedicated-H1 soak evidence keeps its original scope and cannot satisfy
either profile. A shorter smoke remains UNQUALIFIED. Freeze the candidate,
numeric accounting worksheet and capacities before starting. Each profile uses
32 concurrent downstream H2 streams, exact 131,072-byte request/response bodies,
slow consumers withholding selected response credit for 200 ms, progress-based
periodic resets, and at least 20 successful generation reloads during continuous
offered load. Include active, idle and retiring transport generations; force a
bounded retirement hold at least twice to exercise admission under churn.

Before execution, publish a finite profile manifest: service active limit 128;
maximum four retained transport-generation records; owner connection cap eight;
H1 at most two active-plus-idle connections per generation, and H2 at most two
connections per generation with 32 streams each; zero queued transport
requests. H1 overload is expected under 32 offered streams and must be counted
as admission rejection with zero upstream request bytes. Set
service-request and transport-byte ceilings from the approved worksheet and
record their exact integers, rejecting a profile that cannot admit its intended
concurrency. These byte values depend on the missing public contract and must
be fixed before, never adjusted during, the run. Sample at least once/second;
RSS <= startup +512 MiB, total processes <= startup +512, and every sampled
Gaoxy-owned participant/guardian/worker mailbox <=2,048 messages. Record all
public upstream usage bounds separately; these sampled ceilings do not prove
unsampled peaks or replace the source-derived hard bounds.

Record offered/completed/expected-reset/capacity-rejection/unexpected-error
counts, exact bytes/trailers, latency distribution, peer connection IDs and H2
stream IDs, every request/transport reservation sample and every retirement
receipt. Both profiles require observed connection reuse; H2 additionally
requires concurrent streams on one connection. Zero unexpected errors, byte
mismatches or bound violations are allowed; expected overload/reset outcomes
must match the predeclared schedule. Under one 15-second teardown budget, stop
offered load, call the combined `Gaoxy.stop/2` with its remaining budget and
join public retirement, zero owned request/transport reservations, captured
owned process DOWN, peer-observed socket closure and fixture shutdown. An
unconfirmed or nonzero-owned-resource teardown fails the profile.

Existing fixed H1 endpoints, groups, forward proxy and core-only consumers must
continue to work. Standalone's current JSON allowlist stays unchanged in this
slice; managed handles are explicitly supervised embedded configuration. No
dependency addition, push, release, deployment, Vault change, public management
endpoint or release-artifact E2E enabling is authorized here.

## Design verification and handoff

Source/document inspection completed; clean starting baseline verified. Parent
dependency edits and audit evidence were observed and preserved. No compilation,
fixture, browser, network, or Mix command was run by the architecture worker.
Runtime validation is **NOT RUN**; managed transport activation is **BLOCKED**
on the upstream contract. This document does not supersede or rewrite historical
0.19 evidence. The Sol coordinator owns issue routing, contract probes, subsequent
implementation, independent review and final acceptance. No recovery repair
round was consumed.
