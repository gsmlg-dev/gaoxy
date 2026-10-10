# M3: native HTTP/2 and gateway beta

Date: 2026-10-10. Architecture decision for implementation; no implementation or
acceptance claim. Baseline: `71f1b02032b440c5626263bd48aa4f622260e70a`,
`codex/m3-gateway`. Requirements: `implement-plan.md` §§3–4, 6.1, 7, and M3.
The continuing authorization in `AGENTS.md` permits choosing this recommendation.
Production, publication, Vault, and release-artifact E2E restrictions remain.

## Decision and alternatives

| Approach | Benefit | Cost / decision |
| --- | --- | --- |
| Native connection state machine, synchronous endpoint workers, public HPAX codec | Preserves Plug and proxy contracts; Gaoxy owns admission and lifecycle; independently testable | Selected. Requires Gaoxy frame/state/flow-control implementation and explicit codec expansion bounds |
| Reuse HTTP Fetch's H2 connection or internal frame/HPACK modules | Existing protocol machinery | Rejected for this version: client ownership and private `@moduledoc false` modules are not a supported server API |
| Run Bandit behind the existing endpoint API | Mature interoperability | Rejected: contradicts native execution and dependency isolation requirements; reference peer only |

Keep H1 execution intact while extracting protocol-neutral operations. Implement
H2 server independently of upstream H2. H2 downstream → direct H1 upstream is a
valid, separately tested matrix entry. Do not describe upstream groups as pools.

The original audited interfaces below are the0.19.1 design baseline. Installed
0.21.0 now contains request-completion, streamed H2 request trailers, managed
ownership/retirement (#78) and the fragment cap (#79). Full M3 remains blocked
on installed H2 header/control event bounds (#86), actual OTP28 TLS resource
tracking (#95), complete H1 accounting and
remaining managed runtime qualification. The
[current transport design](m3-upstream-transport.md) and
[plan](../plans/m3-upstream-transport.md) supersede P8's old release blockers.
Independent slices may reach acceptance and local commits without asserting
the entire milestone passed.

#86–#89 are now CLOSED upstream, while published/installed artifacts remain
0.21.0. A containing update and renewed qualification are still required;
issue closure alone does not change this design's activation gate.

## Audited seams and dependency decisions

- `Gaoxy.HTTP.Connection.respond/3` currently calls endpoints in its socket owner.
  `Exchange` owns H1 body framing and direct socket reads/writes.
- `PlugAdapter`, `HTTP.Router`, and `Proxy.HTTP` call `HTTP1.Response` directly.
  The proxy also reads `exchange.body.phase/trailers`; Plug reads socket TLS data.
  Changing only response aliases is insufficient.
- `Admission` binds each lease to the acquiring PID. `Service.attach_cleanup/6`
  requires that request owner and retains the guardian reservation until public
  cleanup confirmation. H2 must not reuse a connection lease from stream workers.
- Audited HTTP Fetch 0.19.1 source under the M2 source audit has public
  `HTTP.RequestCompletion.await/2` and `abort_and_await/2`, but its `new/1`
  explicitly rejects `http1_reuse` and non-H1 versions. Preserve the current
  guardian, no-replay behavior, and cleanup uncertainty. Pooling/H2-upstream
  resumes only after [gsmlg-dev/http_fetch#66](https://github.com/gsmlg-dev/http_fetch/issues/66)
  is resolved, the dependency is updated, and the new public contract passes
  Gaoxy tests. Link the issue in
  `docs/dependency-followups.md` and at the blocked client callsite.
- Upstream H2 has a separate trailer prerequisite: 0.19.1
  `HTTP.HTTP2.BodyBridge` stops streamed request trailers with
  `:request_trailers_unsupported` (`body_bridge.ex:147`), also documented by
  `HTTP.Stream.finish/2`. The separately routed Feature blocker requires public
  streaming request trailers emitted as terminal H2 HEADERS, preserving order
  and duplicates, cancellation, and demand. Issue #66 alone cannot satisfy this
  contract. Keep upstream H2 blocked until both issues are resolved, the
  dependency is updated, and both contracts pass. See
  `docs/dependency-requests/http-fetch-pooled-completion.md` for routed evidence.
- The same version publicly documents `HTTP.fetch/2` option `:connect_address`
  in `http.ex` and `FetchOptions`: a validated IP with the original URL authority
  and TLS hostname, requiring manual/error redirects. Use this for forward
  proxy dialing; no URL-to-IP rewriting or second DNS lookup.
- Select HPAX 1.1.0, Apache-2.0, as a direct dependency of `gaoxy_http` only.
  Source examined: `https://github.com/elixir-mint/hpax/tree/v1.1.0`.
  Public APIs: `new/1`, `decode/2`, `encode/2`, `resize/2`,
  `protocol_resize/2`. The latter is specifically for decoder limits, unlike
  encoder `resize/2`. Neither `decode/2` nor its return contract provides a
  decoded-byte/field limit. Artifact checksum, license, runtime compatibility,
  and expansion tests are implementation prerequisites, not established here.
- Abyss exposes `Abyss.DatagramDispatcher` and an opaque
  `Abyss.Dispatcher.SendCapability`; `send_receipt/4` separates admission from
  local completion. Add a validated Gaoxy dispatcher bridge for UDP relays.
  Never inspect Abyss listener state or export/close its shared socket.

No production Bandit, dependency source copying, private client calls, or
edits under `deps/`. Core `gaoxy` keeps no dependency on Plug, HPAX, proxy, or
HTTP Fetch. No new external dependency is added by this design document.

## Ownership and protocol-neutral interfaces

| Component | Owns | Must not own |
| --- | --- | --- |
| Existing service and admission gate (`gaoxy`) | Listener lifetime, aggregate leases/bytes, pause/drain, guardian completion | HTTP frames or routing |
| `HTTP.Connection` dispatcher (`gaoxy_http`) | One TI socket owner; chooses H1/H2 once | Endpoint work on the H2 receive loop |
| `HTTP.HTTP2.Connection` + pure Frame/Settings/Stream modules | Connection/stream wire state, HPACK tables, windows, scheduling, timers | Upstream resources |
| One H2 writer per connection | Serialized bounded socket sends and their outcomes | HPACK state, arbitrary producer casts, socket close authority |
| One supervised temporary worker per admitted H2 stream | Synchronous endpoint call, its own lease/deadline, Plug already-sent messages | Socket reads, another stream's state |
| `HTTP.Exchange`, `HTTP.Response`, internal `HTTP.Transport` behaviour | Semantic request I/O facade | H1 framing in consumers |
| Existing proxy Session guardian | Upstream demand/cancellation/completion and retained cleanup reservation | Downstream wire engine |
| Proxy groups/policies/relay modules | Selection, health, authenticated destinations, bounded relay state | Listener lifecycle duplication |
| Instance-scoped generation store | Atomic current immutable route/configuration snapshot | Retaining a registry of old snapshots or rebinding listeners |

The dispatcher delegates callbacks to the selected engine in the same socket
owner. Keep existing H1 internals behind its implementation; no H1 process
migration is required. H2 workers run under a task supervisor in `gaoxy_http`,
with temporary children, owner monitors, no automatic request restart, and
bounded spawn admission. The writer uses supported TI Socket/OTP send APIs
without taking receive ownership. Prove cross-process send behavior for TCP
and OTP TLS before enabling it. A blocked write cannot block frame reception.

Preserve `Endpoint.init/1` and `Endpoint.call(exchange, opts)` return shapes.
Introduce the following semantic surface (signatures are proposed Gaoxy APIs):

```elixir
Exchange.read_body_step(exchange, credit, wait_ms)
# {:ok | :more, binary, exchange} | {:pending, exchange}
# | {:error, reason, exchange}
Exchange.read_body(exchange, credit, timeout) # existing Plug-facing contract
Exchange.poll_connection(exchange, wait_ms) # existing result shapes; H2 stream liveness
Exchange.body_complete?(exchange) :: boolean()
Exchange.request_trailers(exchange) :: [{binary(), binary()}]
Exchange.peer_data(exchange) :: map()
Exchange.sock_data(exchange) :: map()
Exchange.ssl_data(exchange) :: list() | nil
Exchange.abort(exchange, reason) :: {:ok, exchange} | {:error, term()}

Response.send_resp(exchange, status, headers, iodata)
Response.send_file(exchange, status, headers, path, offset, length)
Response.send_chunked(exchange, status, headers)
Response.chunk(exchange, iodata)
Response.inform(exchange, status, headers)
Response.finish(exchange, trailers \\ [])
# Preserve the current corresponding HTTP1.Response return contracts.
```

The internal `HTTP.Transport` behaviour implements those I/O operations using
an Exchange containing `transport: module`, `transport_state: term`, immutable
peer/local/TLS metadata, request/limits/deadline, and semantic response state.
H2 transport state is an opaque `{connection_pid, stream_id, token}` plus local
body/response progress. H1 may retain existing private struct fields during
migration. Consumers stop accessing `socket`, framing `body`, or `buffer`.
`send_bytes/2` remains H1-internal; there is no raw H1 byte path for H2.

`Response.send_chunked/3` means begin a streaming response: H1 emits chunk
framing, H2 emits HEADERS then DATA. H2 never emits transfer-encoding or
connection headers. File sends read finite chunks under the same demand and
write limits. Preserve ordered duplicate ordinary headers/trailers, bodyless
status/HEAD rules, 304 content-length metadata, informational responses, exact
content-length validation, and one final response. Extract shared validation
only where both engines need the same rule.

The H2 owner is authoritative for commitment before scheduling any final head.
A worker crash or stale Exchange cannot cause a second response. The worker
keeps Plug's already-sent messages local; never use connection-wide mailbox
flushing to infer another stream's commitment. H1 `close: true` compatibility
maps to abandoning that H2 request/stream, not closing the shared connection.
An early response may complete then reset an unread request side as allowed by
RFC 9113; a failed committed response resets the stream. Other streams survive.

H2 Request uses `version: :"HTTP/2"`, the existing origin-form path/query and
body descriptors (`:none`, `{:length, n}`, or streaming body), and cached secure
metadata. A body descriptor is semantic; H2 DATA is never passed to H1 Body.
Map pseudoheaders once, validate duplicates/order/required values, lowercase
names, forbidden connection fields, `te: trailers`, authority/Host consistency,
scheme and content length. Pseudoheaders never appear in Plug request headers.
Trailers prohibit pseudoheaders and reuse the semantic forbidden-field policy.

Upgrade and push capabilities are explicit. M3 keeps H1 WebSocket support.
H2 WebSocket extended CONNECT and server push return unsupported; do not send
`SETTINGS_ENABLE_CONNECT_PROTOCOL` or PUSH_PROMISE. Ordinary CONNECT initially
uses H1 only; unsupported H2 CONNECT receives a stream-local response.

## H2 state machine, admission, and flow control

One connection owns both HPACK contexts in wire order. No per-stream HPACK
table and no parallel HEADERS encoding. Frame parsing is incremental with a
9-byte header, early advertised-length validation, and bounded carry. Validate
client preface, first SETTINGS, ACK lengths, stream identifiers/state, padding,
priority self-dependency, continuation exclusivity, WINDOW_UPDATE overflow/zero,
RST_STREAM, PING, GOAWAY, and unknown frame handling against RFC 9113. Ignore
unknown frames only where the protocol allows; do not ignore them during a
required CONTINUATION sequence. Compression failures are connection errors.
Map every violation to the RFC's stream or connection scope, not a universal
RST_STREAM. Decode rejected streams' header blocks to maintain compression
state, or close the connection if the decoding budget is unavailable.

Initial conservative profile (strictly validated, configurable finite limits):

| Limit | Default |
| --- | ---: |
| Concurrent endpoint streams per connection | 32 |
| Inbound max frame payload | 16,384 bytes |
| Compressed HEADERS/CONTINUATION block | 16,384 bytes |
| Decoded headers | Existing 32,768 bytes / 100 fields |
| HPACK decoder table | 4,096 bytes |
| Initial receive connection / stream window | 65,535 / 65,535 bytes |
| Pending body delivered to a worker | One piece, at most 16,384 bytes |
| Pending producer write per stream | One piece, at most 16,384 bytes |
| Writer frames in flight | One, at most 16,384 payload bytes |
| Partial preface/header block / SETTINGS ACK timeout | 5,000 ms |
| Control frames processed per event-loop turn | 32 |
| Control-frame rate budget | 256 per second per connection, burst 256 |
| Stream lifetime / I/O deadlines | Existing HTTP limits, absolute deadline |

Service `max_active` includes connection owner, writer, and stream workers;
report that meaning and the H2 stream count separately. Use connection-local
stream limits plus the existing service-wide admission limit. Before dispatch,
the worker acquires its own lease with `drain_notify: true` and begins the
request with the original absolute deadline. It reports admission success
before receiving request payload. Limit pending worker starts to one per
connection; do not create arbitrary processes before checking the local limit.
If admission fails, refuse the stream without executing application code.
Each proxy guardian attaches to this worker lease exactly as on H1.

Reserve bytes before data crosses a mailbox. Owner accounts ingress carry,
queued DATA, header blocks, stream records, HPACK and control output; worker
accounts delivered metadata/body and at most one pending write; writer owns a
separate lease for its bounded in-flight frame. Copy/handoff overlap is counted
until acknowledgment. Authenticated operation tokens, caller PID checks and
one outstanding read/write per worker bound producer messages. A GenServer
cast queue or a task limit alone is not byte admission.

HPAX expansion must be reserved **before** `decode/2`. For compressed length B
and maximum dynamic table T, use a conservative payload expansion bound such as
`B * (max(T, 128) + 2)`: at most B indexed/literal fields, table/static referenced
bytes bounded by T/128, and Huffman literal output below twice encoded length.
Add explicit term/list/copy overhead for the pinned implementation and platform;
do not present this as a total BEAM heap bound. Enforce finite B and T, reject
before decoding when reservation fails, and release the transient reservation
after header validation/accounting. Test repeated indexed fields, Huffman
expansion, malformed integer encodings, table churn, and CONTINUATION flooding.
Do not flatten/copy inflated headers before validating them. This conservative
profile may require a large configured service byte budget; report and validate
the minimum rather than silently increasing core defaults. Tightening the
reservation later requires evidence, not removing the pre-decode gate.

Make the budget executable through a pure internal
`HTTP.HTTP2.Limits.reservation(http_limits, h2_limits)` returning
`%{connection: bytes, stream: bytes, writer: bytes, decode: bytes}`. For the
pinned 64-bit runtime qualification, start with
`decode = 2 * B * (max(T, 128) + 2) + 512 * B + 2 * T`, accounting for payload
overlap and conservative per-field bookkeeping. P0 must substantiate or increase
that allowance for HPAX 1.1.0; it must not infer total process memory from it.
Reserve this decode capacity once in the connection owner before advertising
H2, alongside a 16 MiB conservative connection state/copy allowance. Separate
stream and writer reservations remain additive, and proxy guardians retain
their existing approximately 8 MiB/request reservation. Never independently
claim the same service budget for every stream. Decode capacity cannot be
borrowed by pending stream writes.

The initial H2 example/profile explicitly sets service `max_bytes: 536_870_912`
(512 MiB), `max_active: 128`, with 32 local stream slots/connection. These are
caller-supplied settings, not replacements for core defaults. Validation rejects
H2 configurations below the computed minimum for one connection, writer and
one admitted stream. Admission then limits actual connections/streams by the
single service total; advertising 32 concurrent streams is an upper bound, not
a promise to admit all of them when other connections consume capacity. A
512 MiB budget is not a 512 MiB RSS guarantee. Expose computed reservations and
refusals in listener/capability evidence, and include proxy reservations when
sizing the sustained-load fixture.

Keep the decoder table at the initial advertised size for this slice; no local
runtime table-size changes are needed. Apply peer HEADER_TABLE_SIZE to the
encoder with HPAX.resize/2, clamped to the local encoder bound; use `:never_store`
for sensitive fields and avoid indexing credentials. Any later local decoder
limit changes use HPAX.protocol_resize/2 with the SETTINGS acknowledgment rules.

Charge the full DATA payload, including padding, to wire windows. Return stream
credit only after consumption; return connection credit after consumption or
bounded discard on a canceled stream. Preserve a full initial connection window
reservation before advertising it, and never enlarge it without extra capacity.
Track queued and delivered-but-not-consumed bytes; body END_STREAM and validated
trailers finish the request. Returning a piece grants no extra automatic demand:
the next read or explicit consumer acknowledgment releases it. A poll is not
body demand and must not consume arbitrary input.

Outbound DATA requires both positive connection and stream windows. Decreases
from SETTINGS can make a stream send window negative. Queue bounded producer
pieces, retain deferred call references, and reply after local frame writes
complete, not on enqueue. Serve ready streams round-robin, one DATA frame per
turn, with bounded priority for control frames. A zero-window stream cannot
block another ready stream. Header blocks are emitted contiguously through
END_HEADERS; control frames cannot illegally interrupt them. No priority tree
is needed, but parse legacy priority fields correctly.

The owner continues reading while a write waits. All sends have finite deadlines
and `send_timeout_close`; an uncertain partial write closes the connection and
is never replayed. Worker cancellation removes pending operations and replies
to callers, then cancels its guardian. Late replies carry operation tokens and
cannot revive a reset stream. On worker crash, reset only that stream; on owner
or writer death, close the connection, stop all workers, and preserve guardian
cleanup tracking. Killing an endpoint is not confirmed upstream cleanup.

Drain freezes admission, sends GOAWAY(NO_ERROR) with the highest stream ID
actually accepted for processing, and continues reading/servicing admitted
streams until the single service deadline. New streams are refused, with HPACK
state preserved as above. Deadline expiration cancels remaining streams and
closes the socket; report uncertain cleanup honestly. Pause blocks new work
while preserving required control traffic and existing stream progress. No
automatic request replay after GOAWAY or a reset.

## Protocol selection and compatibility

Add validated HTTP `protocols: [:http1] | [:http2] | [:http2, :http1]`; preserve
the default `[:http1]` until explicit H2 configuration. On OTP TLS, derive and
validate ALPN from that list, read `Socket.negotiated_protocol/1` after handshake,
and dispatch exactly once. No ALPN selects H1 only if enabled; H2-only without
`h2` fails closed. Unknown negotiated protocols fail closed. Use an H2-compliant
TLS policy (TLS 1.2+ and qualified cipher policy); test invalid negotiated TLS
versions/ciphers without provider fallback. TLS credentials/rotation remain
under existing scope restrictions.

Cleartext H2 is separately opt-in `h2c: :prior_knowledge` on an H2-only TCP
listener, with bounded incremental preface matching and its own gate. Keep
ordinary cleartext H1 separate. HTTP/1 Upgrade-to-h2c is unsupported and rejected
explicitly; it is not inferred from prior-knowledge acceptance. No implicit
sniffing/demultiplexing of arbitrary protocols.

Update Plug/Phoenix HTTP option forwarding only as necessary to carry validated
protocol choices. Existing direct endpoints, router ordering, H1 persistence,
WebSock fork integration, streaming proxy, and browser behavior stay regression
gates. Migration changes public I/O calls, not the endpoint callback contract.

## Gateway slices independent of upstream transport reuse

### Upstream groups and policy

`Gaoxy.Proxy.UpstreamGroup` owns immutable member configuration and generation-
scoped health/selection state. Proposed API: `checkout(group, request_context,
deadline) -> {:ok, member, token} | {:error, :unavailable}` and
`report(group, token, outcome) -> :ok`. Tokens count in-flight selections; they
are released on confirmed session cleanup, including failure. Start with equal
round-robin over healthy members, bounded per-member concurrency, and no waiting
queue (503 on saturation). Do not silently select unhealthy members.

Bounded active probes use the same supported direct H1 client and cleanup
barrier. Use one in-flight probe/member, 5 s interval with jitter, 2 s timeout,
three failures to remove and two successes to restore; configurable finite
values. Passive transport failures remove a member after the same threshold;
ordinary HTTP statuses are not transport failures. Initialization is explicitly
unknown until a successful probe; stale probe results cannot mutate a new
generation. Request deadlines, verified HTTPS, raw response/compression policy,
hop-by-hop removal, trailers and manual redirects remain as in M2. Always choose
once; no automatic retry or replay in M3's initial policy. Pools and H2 upstream
are separately blocked, not simulated with local socket ownership.

### Forward HTTP and CONNECT

Use separate explicit endpoint/service configuration. Require an authentication
callback and nonempty destination policy before binding. For data-only config,
use registered named authenticators and secret references, never arbitrary
module names or plaintext credential logging. Missing/invalid credentials give
407, denied destinations 403; authorize before DNS/dial and before returning a
CONNECT 200. Strip Proxy-Authorization and hop-by-hop headers from upstream work.

Pure `DestinationPolicy.authorize(principal, authority, operation)` validates
method, port, hostname/IP policy. A bounded resolver obtains A/AAAA addresses;
normalize IPv4-mapped IPv6, reject malformed/zone-ambiguous addresses, and deny
loopback/private/link-local/unspecified/multicast/broadcast/metadata and configured
management endpoints unless an explicit narrow rule permits the destination.
Reject mixed allowed/denied DNS answer sets conservatively. Pin one validated
address for the dial; TLS verifies the original hostname with SNI intact.
Repeat validation for each new connection. No redirects, DNS rebinding gap,
environment proxy inheritance, or destination selected from forwarding headers.

Forward HTTP accepts strict absolute-form HTTP targets, rejects userinfo, and
requires target authority/Host consistency; HTTPS forward traffic initially
uses CONNECT. Invoke the existing HTTP endpoint/session using the dynamically
authorized URL and public `connect_address`. CONNECT accepts strict authority
form with explicit port, no request body/framing ambiguity, and no ordinary
route match fallback. Dial succeeds before the H1 200. Then transfer all already
read post-header bytes exactly once to the raw relay, retaining the listener
owner. This is a separate tunnel response state, not a WebSocket impersonation.
Do not mark successful tunnels replayable or log tunneled content.

### TCP/TLS relay

`Proxy.StreamRelay` is a native stream handler with explicit upstream destination
and a duplex state machine. Distinct configured modes: raw TCP; downstream OTP
TLS termination; verified upstream OTP TLS; opaque TLS passthrough over TCP.
No SNI sniffing, PROXY protocol acceptance, TLS MITM, or certificate issuance in
this slice. Explicit unsupported modes fail validation.

Use finite connect/idle/lifetime/drain deadlines, one read credit and one bounded
write per direction, and service/connection byte reservations before handoff.
Select TI's documented synchronous passive mode: the native owner enters a
duplex pump inside `handle_connection/2`, using `Socket.recv/3` for downstream
and supported OTP recv for its upstream socket, with `active: false` and TCP
`exit_on_close: false`. CONNECT enters the same pump from the current H1 callback
after flushing its already-buffered tunnel bytes. Do not return to TI's async
loop while either relay direction is live: `tcp_closed` invokes a terminal
callback and stops that handler, so async `handle_close/2` cannot implement this
contract. There is no upstream blocker for the supported synchronous path.

The pump alternates finite credited reads (at most 5 ms per empty-side poll),
checks absolute deadlines, and services writer replies, monitors, admission
drain and shutdown messages on every iteration. Skip reads on an EOF side or
when its write slot is occupied. One bounded writer per direction prevents a
blocked send from starving reverse traffic. The native owner retains receive
ownership of both sockets. TCP EOF drains queued bytes, then shuts down the
opposite write side while permitting reverse bytes until EOF/deadline. Return
`{:close, state}` only after both directions finish or bounded termination is
required. Test half-close independently in both directions with delayed reverse
data, including CONNECT post-header bytes. TLS close_notify semantics are
qualified separately and unsupported
directional shutdown is reported explicitly. Close both owned sockets on hard
failure; never close another connection or a listener.

### UDP unicast relay

Extend the core adapter with validated `handler_mode: :datagram_dispatcher`
using public Abyss dispatcher configuration. Its lifecycle remains owned by
Gaoxy.Service. Keep the original DatagramHandler behavior unchanged. Reject
broadcast/multicast relay configuration for this slice rather than silently
using unsupported persistent dispatch modes.

One association is keyed by listener identity/generation and downstream address
and port. It owns one connected upstream UDP socket to a pinned configured
destination, preserving each datagram including empty payloads. Return packets
must match the chosen upstream peer; use the opaque send capability to send to
the downstream peer from the original listener port. No protocol transaction-ID
parsing and no pooling associations across clients.

Bound associations (default 256), packets/bytes queued per association (8 /
65,536), datagram size (65,507), idle timeout (30 s), and service total bytes.
Reject configurations unable to reserve their enabled receive/write windows.
Acquire a byte/item reservation before mailbox handoff; drop newest on overload,
count drops, never retry unknown sends. Restrict ingress clients explicitly and
apply finite per-association egress byte/packet rate limits to bound amplification.
Monitor upstream socket/association and writer capability generations; expiry,
removal, and drain revoke sends and ignore late packets. Old generation
associations expire/drain; new packets after activation create new associations.

## Configuration generations and operational boundaries

Use an instance-scoped `Gaoxy.HTTP.Generation` endpoint/store with pure
compilation and a serialized snapshot/activate boundary. A generation contains
compiled routes, endpoint options and policies. Suggested public operations:

```elixir
Gaoxy.HTTP.Generation.snapshot(store)
# {:ok, generation_id, compiled_router}
Gaoxy.HTTP.Generation.activate(store, expected_generation, prepared_router)
# {:ok, new_generation_id} | {:error, :stale_generation | reason}
# Endpoint.call/2 snapshots once, then calls Router.call/2 outside the store.
```

Validate and compile the complete candidate outside the store, then compare and
swap the current generation atomically. Stale concurrent activation returns an
error; it never overwrites a newer configuration. A request snapshots once
before dispatch; H1 keep-alive's next request and each new H2 stream see the new
generation, admitted requests hold the old immutable Router value naturally.
The store retains only the current snapshot, not an old-generation registry.
Bound routes (default 1,024), compiled configuration bytes (default 1 MiB), and
concurrent preparation (one per store); request/service admission bounds retained
snapshot copies. Charge conservatively for cross-process snapshot handoffs.

Existing CONNECT/TCP tunnels and UDP associations retain their selected policy
for their bounded lifetime. Group runtime owners remain separate stable resources
identified in immutable snapshots, with their own instance lifecycle and limits.
Group configuration updates cannot silently alter an already selected member.
When removing/replacing such resources, the resource owner uses monitored
request/guardian holds and drains before termination. Cleanup holds last until
guardians finish, not merely until the endpoint returns. Do not place historical
Router values in that resource registry. Bound group owners, including prepared
and retiring owners, to 64 per instance and 16 MiB aggregate retained group
configuration; reserve before preparation. Reject replacement with
`:group_capacity` while retired owners still hold capacity, rather than growing
the registry or discarding cleanup holds. Existing absolute session/probe/drain
deadlines bound normal retirement; uncertain cleanup keeps its reservation and
uses the existing fail-closed service policy. Initial generation work may limit
activation to pure route/policy changes over already-prepared group owners;
report unsupported resource mutations explicitly until that lifecycle is tested.

Initial reload supports route/endpoint/policy changes and selection of prepared
group owners on an unchanged set of listener identities. Bind address/port,
transport/provider, TLS/ALPN, protocol
set and listener limits are immutable through this operation; return
`:listener_change_requires_restart` before mutation. This is an explicit stable
listener subset, not a claim of atomic same-port replacement. Failed validation
or preparation leaves current routes/listeners/resources intact and rolls back
only candidate resources. Listener add/remove remains the existing explicit
lifecycle API outside the atomic reload transaction.

Use registered stable process IDs/names for generation endpoints, without atom
creation from external input. Extend versioned JSON through strict
key/value/handler allowlists. Embedded trusted specs and external data remain
distinct. Include schema validation and
operator documentation; no new management endpoint. Expose bounded telemetry
for stream counts, flow stalls, refused streams, queued/reserved bytes, resets,
GOAWAY, reload generation, policy denials, group health, association expiry and
cleanup pending/unknown. Labels omit raw URLs, credentials and unbounded stream
or client IDs. Preserve existing service telemetry identifiers.

## Implementation slices and acceptance

Sol owns implementation, test design, independent review, and local commits.
Each slice gets its detailed plan and evidence before progressing dependents.
Files below indicate responsibility boundaries; necessary scoped integration
edits are allowed under the continuing authorization.

For parallel execution, give the H2 writer exclusive ownership of the HTTP
facades/engines and proxy compatibility callsites (P0–P3). A relay/policy writer
can own new proxy modules for P4 concurrently; serialize its H1 CONNECT tunnel
integration with the H2 writer through the coordinator. Parent-owned generation
work is P7. UDP/core adapter P5 follows separately to avoid core ownership
conflicts. Do not let independent workers edit the same HTTP connection module.

| Priority / slice | Ownership and dependencies | Required acceptance |
| --- | --- | --- |
| P0: codec/public-API qualification | `gaoxy_http` manifest + dependency audit; no dependency on proxy work | Pin HPAX artifact; published API/source/license check; expansion bound and malformed corpus; TCP/TLS cross-process send contract; fail unsupported inputs |
| P1: neutral Exchange/Response | `gaoxy_http` facade/H1/Plug/router; `gaoxy_proxy` callsites; after design | Existing H1 framing/bodyless/file/trailer/early-response tests and proxy guardian tests pass; meaningful dual-backend facade contract tests; no endpoint callback change |
| P2: H2 engine | `gaoxy_http/http/http2`, dispatcher/options/task supervision; depends P0/P1 | Independent peer H2 prior knowledge and TLS ALPN tested separately; concurrent stream bodies/responses; HPACK dynamic/Huffman; SETTINGS, windows, continuation and error scope; no Bandit production dependency |
| P3: H2 integration/lifecycle | H2 Plug/Phoenix/proxy mapping; after P2 | Independent slow/zero-window peers, reset/disconnect during upload and response, early upstream final, trailers, GOAWAY/drain, worker/writer crashes, stale replies; other streams and guardian accounting survive |
| P4: policy + forward/CONNECT + TCP/TLS relay | `gaoxy_proxy` policy/tunnel/relay + minimal H1 tunnel seam; policy and raw relay can start independently | Auth refusal, destination/DNS/mapped-IPv6/security matrix, pinned HTTPS verification, buffered tunnel bytes, duplex TCP half-close, TLS modes, stalled writes, finite cleanup |
| P5: UDP relay | Core dispatcher bridge + proxy UDP association; independent of H2 | Independent UDP peer; multiple clients, empty/max datagrams, return-source rejection, preserved source port, bounded overload, expiry/drain/reload and writer uncertainty |
| P6: groups/health | Proxy group state + existing direct H1 sessions; independent of H2 | Round-robin, saturation/no replay, health transitions, bounded probes, stale generation results, verified TLS, guardian cleanup; explicitly no transport reuse |
| P7: stable-listener generations | HTTP Generation snapshot endpoint + server config; after P1, integrate P4–P6 | Old admitted work/new request split, H2 streams across reload, preparation rollback, unchanged real bound port, concurrent/stale CAS, bounded preparation/snapshots, resource-holder crash, no atom growth |
| P8: reusable upstream transport | HTTP Fetch adapter;0.21 fixes #66/#67/#78/#79; activation gated by H2 #86, complete H1 accounting and managed qualification | H1 reuse and H2 upstream demand, cancellation and public request completion; H2 upload trailers; healthy shared resources survive cleanup; owned pool retirement/isolation/capacity/load, no private processes |
| P9: beta integration/soak | Scoped acceptance and docs; after all required slices | Fresh independent review, native browser regressions, external core consumer, sustained-load/slow-peer evidence, truthfully populated capability matrix; M3 cannot pass while P8 blocked |

Sustained-load gate: at least 10 minutes, mixed local and H1-proxied H2 requests
with 32 concurrent streams/connection, large bounded bodies, slow readers,
periodic resets and generation changes. Record peer/tool/runtime versions,
source SHA, command, offered/completed/error counts, latency distribution,
process/mailbox/reservation samples, and cleanup after stop. Assert configured
admission/byte limits throughout and zero owned workers/sockets/reservations
after the finite teardown deadline; set host-specific RSS tolerance before the
run rather than selecting it afterward. Include an independent RFC-focused
malformed-frame suite and an independent H2 client; same-codec round trips are
insufficient. No arbitrary sleeps as lifecycle proof.

Run scoped tests for each changed boundary plus required compatibility gates.
Retain nonzero counts and exits. Record PASS/FAIL/BLOCKED/NOT RUN distinctly for
TLS H2, h2c, H2→H1 proxy, H2 upstream, H1 reuse, forward/CONNECT, each TLS relay
mode, UDP, reload, browser, and load. H2/H3 WebSocket, H3, multicast/broadcast
relays, SNI inspection, PROXY protocol, automatic retries and atomic listener
replacement stay unsupported until their own design and evidence. Do not enable
the restricted release-artifact E2E workflow as a substitute for local gates.

## Design validation and remaining risks

This document was checked against the baseline public interfaces and M3 scope;
no implementation tests ran for this architecture-only assignment. The chosen
interfaces resolve socket ownership, synchronous application dispatch, lease
ownership, and generation retention without a new product decision. Risks to
qualify first are HPAX transient reservations, native writer/control-loop
behavior, TI half-close callbacks, and guardian retention across H2/reload.
Any unsupported dependency contract is routed upstream with evidence and blocks
only its dependent slice; no private-API workaround is authorized.
