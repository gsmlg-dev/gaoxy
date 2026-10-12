# M4 native HTTP/3 architecture

Date: 2026-10-11. Status: **IN PROGRESS; Options/pure protocol passed,
live HTTP/3 gates pending**. Current results are in [M4 execution](../acceptance/m4.md).
Execution authorized 2026-10-12 on `codex/m4-http3` from `78de9d0`; the original
architecture baseline below is retained as history. Remaining upstream-H3 and
standalone slices are required M4 work and will be designed and executed under
continuing authorization after the relevant server gates pass.
Architecture assignment: `PROJECT_ARCHITECTURE`, architecture mode. Inspected
baseline: `codex/m3-gateway`, `32408c8054ba485f2a15c0fd244ae4b8d1615c5e`.
The initial worktree was clean. This document and
[the execution plan](../plans/m4-http3.md) are the only architecture deliverables.

## Intent and limits

Implement the M4 HTTP/3 milestone in [implement-plan.md](../../implement-plan.md)
above the supported Abyss QUIC host, with Gaoxy-owned HTTP server state. The
first independently accepted slice is an ordinary H3 server with control,
malformed-input, flow-control, reset, and bounded-shutdown coverage. It precedes
Plug integration and the proxy/browser matrix; it does not by itself complete M4.

Existing native H1/H2 and dedicated H1 proxy capability remains the baseline.
Production reusable upstream pooling and upstream H2 adapters are unimplemented.
HTTP Fetch issue 97 is not a prerequisite, investigation task, or blocker for
this work. Do not recreate its dismissed requirements under another name.
Historical evidence remains intact; report actual enabled transports separately.

Initial profile: concrete IPv4 address, certificate-authenticated QUIC v1,
ALPN `h3`, explicit local fixture certificate/key, 1-RTT, static/literal QPACK,
zero advertised dynamic table capacity and zero blocked streams. No server push,
WebTransport, unreliable DATAGRAM, extended CONNECT, H3 WebSocket, 0-RTT,
resumption, migration, mTLS, wildcard binding, or IPv6 claim. Ordinary CONNECT
receives an explicit 501 in this profile. No protocol fallback.

Vault remains frozen. The release-artifact `.github/workflows/e2e.yml` remains
disabled. Production deployment/data/certificates and public management remain
excluded. Local independent peers and browser tests are required. Continuing
AGENTS.md authorization covers recommended choices and automatic progression
once scoped verification and independent Sol review pass; routine approval
requests are unnecessary.

## Selected public APIs: source findings, not runtime qualification

The root lock selects Abyss Git `9b710e6480900e16e304f40e63623aff8c922e19` and the
seven-package HTTP cohort 0.21.3 (`http_fetch`, `http_runtime`, `http_core`,
`elixir_quic_http3`, `elixir_quic`, `ex_ssl`, `http_web_socket`). Preserve the
cohort. [Dependency audit](../dependency-audit.md) and its installed-cohort
verification establish artifact provenance. Historical generic QUIC acceptance
used a separate 0.17.0 consumer; it does not qualify this combination.

| Source / public API | Finding and M4 use |
| --- | --- |
| `deps/abyss/lib/abyss/quic.ex`, `Abyss.QUIC.start_link/1`, `local/1`, `stop/2` | Public host and lifecycle. One UDP socket/endpoint; application sees opaque capabilities. |
| `deps/abyss/lib/abyss/quic/handler.ex`, `init/3`, `handle_event/2`, optional `terminate/2` | Attached owner receives `:tick`, `:writable`, ready/open/readable/stopped/closed events. Callbacks share a finite batch deadline. Arbitrary application messages are not callback events. |
| `apps/gaoxy/lib/gaoxy/quic.ex`, `Gaoxy.QUIC` | Existing wrapper for open/read/send/reset/stop/close/status. Only attached owner can reserve application I/O. Maximum operation payload is 16 KiB, further bounded by service limits. |
| `deps/elixir_quic/lib/quic.ex`, `Quic` | Engine owns TLS, CIDs, streams, transport credit, loss recovery, packetization, operation references. `capabilities/0` reports streams and `http3: false`; Gaoxy supplies H3. |
| `deps/elixir_quic_http3/lib/quic_http3/session.ex`, `Session.open/1` | Explicit `Control.new(:client, ...)`, request/upload/response APIs; not a server runtime. Do not instantiate or modify its state for a server. |
| `quic_http3/control.ex`, `Control.new(:server, settings)` | Supported server role in a transport-neutral control state machine. `local_payload/1` returns type prefix plus SETTINGS without needing a numeric stream ID. `receive_peer/3` accepts an opaque stream key and includes type-prefix parsing. |
| `quic_http3/{frame,varint,settings}.ex` | Public delegating facades over `HTTP.H3.*`; reuse encode/decode/validate rather than duplicate wire codecs. `Frame.decode/1` requires complete payload; outer framing must enforce bounds first. |
| `quic_http3/qpack.ex`, `Qpack.encode_header_block/2`, `decode_header_block/2` | Static references, literals and Huffman decoding supported; decoding takes `max_fields`. No negotiated dynamic-table header decoding. Add decoded byte limits and HTTP semantics at Gaoxy boundary. |
| `quic_http3/stream.ex`, `Stream.decode_type/1` | Public unidirectional type parser. Do not extract IDs from opaque host handles. Numeric IDs returned in documented read items may be recorded for protocol checks. |

`Control` checks SETTINGS-first, duplicate SETTINGS/control streams, invalid
settings, forbidden frame types, and monotonic received GOAWAY. It is not a
complete server: Gaoxy must own stream lifecycle/critical closure, request frame
ordering, HTTP fields, push-ID constraints, limits and H3 error mapping. In
particular, its server path does not interpret MAX_PUSH_ID/CANCEL_PUSH semantics.
Use the public codec around that bounded server logic, not private Control or
Session helpers. `Control.local_payload/1` does not mark local-open state;
Gaoxy tracks one local control handle and its send state itself.

Abyss stop stops ingress before worker cleanup. It cannot prove graceful
protocol drain, because existing streams require incoming ACKs and credit.
Gaoxy's existing QUIC configuration also rejects wildcard and non-IPv4 binds.
These are explicit compatibility limits, not reasons to bypass the host.

## Recommended boundaries and alternatives

Add optional umbrella application **`gaoxy_http3`** with namespace
`Gaoxy.HTTP.HTTP3`. It depends on `gaoxy_http` and directly pins the already
selected `elixir_quic_http3 == 0.21.3`; runtime dependencies remain enabled.
No reverse dependency from core or `gaoxy_http` is added. This is an execution
plan dependency declaration, not a dependency mutation made by this document.
A consumer choosing H3 opts into QUIC/TLS. A core-only or H1/H2-only consumer
must not gain QUIC merely by installing its chosen Gaoxy package.

Alternatives considered:

1. Put H3 and a required QUIC dependency into `gaoxy_http`: fewer package files,
   but forces optional transport costs on H1/H2 consumers. Rejected.
2. Adapt `QuicHttp3.Session` into a server: less new state superficially, but
   assumes a client runtime contract and private state. Rejected.
3. Optional application using Gaoxy's host bridge and public codecs: preserves
   ownership and isolation; requires a small server state machine and explicit
   worker rendezvous. Recommended.

Proposed modules and ownership:

| Module | Owned data and interface |
| --- | --- |
| `Gaoxy.HTTP.HTTP3` | `start_link/1`, `child_spec/1`, `service_spec/1`; maps an H3-only service to existing `Gaoxy.Config` / `Gaoxy.QUICBridge`. |
| `HTTP3.Options` | Strict endpoint/Plug/limits validation, `h3` ALPN, concrete IPv4, fixture credentials; rejects incompatible options before binding. |
| `HTTP3.Connection` | `Gaoxy.QUICHandler` implementation; sole application QUIC I/O owner; stream map, local control send, peer critical-stream identities, deadlines, pending operation refs. |
| `HTTP3.Protocol` | Pure, bounded incremental frame/type and request state transitions; returns actions and scoped H3 errors; public dependency codecs perform wire conversion. |
| `HTTP3.Headers` | HTTP request/trailer/response field validation, QPACK profile and Request conversion; no HPACK dependency or H2 stream state. |
| `HTTP3.Operations` | Connection-owned bounded ETS rendezvous for endpoint operations, generation/request tokens, cancellation and replies. No socket ownership. |
| `HTTP3.Stream` | One monitored, admitted endpoint task per accepted request; owns its Exchange, application execution, request lease and absolute deadline. |
| `HTTP3.Transport`, `HTTP3.Response` | Existing Exchange/Response contracts mapped to H3 HEADERS/DATA/trailers/FIN via Operations. |

These are proposed Gaoxy modules, not claimed dependency APIs. Reuse existing
`Gaoxy.HTTP.Tasks` supervision and Admission; do not create a duplicate global
connection registry or transport scheduler. HTTP3.Headers may call existing
public pure HTTP validation helpers where semantics match; do not inherit
hardcoded `HTTP/2` metadata or copy entire H2 modules.

## Server invariants

### Setup and stream classification

Wait for readiness/negotiated `h3`, then open exactly one local `:uni` control
stream and send `Control.local_payload/1` with SETTINGS `{1,0}`, `{6,32768}`,
`{7,0}`. Keep it open. Read peer bidi streams as request streams; classify peer
uni streams incrementally (up to eight bytes for their type varint). Pass the
complete control prefix exactly once to `Control.receive_peer/3`.

Maintain unique peer control, QPACK encoder and QPACK decoder handles. QPACK
streams may be absent with static compression; if opened they become critical.
Opening local QPACK streams is unnecessary when no instructions are sent.
Accept legal zero-capacity encoder instructions, reject inserts/capacity above
zero. Accept and ignore legal decoder Stream Cancellation instructions even
with zero dynamic capacity: RFC 9204 section 2.2.2 permits omitting them, and
does not forbid sending them. Reject Section Acknowledgements and Insert Count
Increments because Gaoxy sends no dynamic references or inserts. Bound
cancellation identifiers to QUIC stream IDs and map malformed instructions to
QPACK_DECODER_STREAM_ERROR. Use public Qpack integer decoding for fragmented instruction
parsing. A peer advertising its own nonzero decoder capacity is legal; Gaoxy
still encodes statically. Dynamic references against Gaoxy's zero capacity fail.

Peer push streams are forbidden. Unknown uni stream types are discarded/stopped
with bounded state, as allowed by RFC 9114; they are not decoded as requests.
Unknown extension frames are ignored by length without allocating the declared
payload. Gate known control-frame lengths before calling Control; its internal
65,536-byte frame limit is a parser bound, not permission to accumulate unlimited
input or reject every large unknown extension. An unknown frame before the first
SETTINGS still violates SETTINGS-first; skipping extensions must preserve that
check. Bound discard time by the stream deadline and work quantum. HTTP/2-reserved frame types receive H3_FRAME_UNEXPECTED. A valid
MAX_PUSH_ID is accepted/monotonically tracked without sending pushes; malformed
payload, decreasing IDs and CANCEL_PUSH for an unissued push ID get the applicable
H3_FRAME_ERROR/H3_ID_ERROR. Do not reject ordinary clients just for allowing push.

### Requests, fields and errors

Request state is `initial_headers -> body -> optional_trailers -> receive_fin`.
HEADERS must precede DATA; DATA after trailers and repeated trailers fail. FIN
inside an incomplete frame fails. Field sections validate lowercase names,
pseudo-field order/uniqueness/required fields, authority/host agreement,
connection-specific field exclusions, TE=trailers, content-length and trailer
restrictions. Preserve escaped path and the distinction between `/x` and `/x?`.
Ordinary CONNECT permits a matching regular Host field; reject duplicates and
authority disagreement. Invalid content-length syntax is a message error;
a valid declared length above the configured body ceiling is excessive load.
Use `Request.version = :"HTTP/3"`, HTTPS and real peer/local addresses. Never
invent client certificate or TLS metadata absent from the public host.

Request errors reset/stop only that stream; connection protocol/compression
errors close only that connection. Establish a table tested against RFC 9114
and RFC 9204: duplicate uni critical stream -> H3_STREAM_CREATION_ERROR (0x103);
critical FIN/reset -> H3_CLOSED_CRITICAL_STREAM (0x104); forbidden ordering ->
H3_FRAME_UNEXPECTED (0x105); invalid/truncated frame -> H3_FRAME_ERROR (0x106);
invalid settings -> H3_SETTINGS_ERROR (0x109); missing initial SETTINGS ->
H3_MISSING_SETTINGS (0x10a); invalid HTTP message -> H3_MESSAGE_ERROR (0x10e,
stream); header decompression -> QPACK_DECOMPRESSION_FAILED (0x200); encoder
and decoder instruction errors -> 0x201 and 0x202. Resource rejection uses
H3_EXCESSIVE_LOAD (0x107); application cancellation uses H3_REQUEST_CANCELLED
(0x10c). Test exact error scope as well as the numeric code. Requests on another
stream may arrive before peer SETTINGS because streams are independently ordered;
do not make arrival ordering a connection error.
Duplicate SETTINGS is H3_FRAME_UNEXPECTED (0x105), as required by RFC 9114
section 7.2.4, rather than an invalid setting value (0x109).

### Credit, memory and uncertain operations

Start with eight concurrent requests per connection, 16 KiB operation chunks,
32 KiB compressed and decoded header bounds, 100 fields, 8 KiB/32 trailers,
64 KiB request ingress buffer, 64 KiB pending output per stream, and existing
8 MiB body/30 s request/5 s read-write deadlines. Use a 16 KiB control work
quantum and a finite per-tick action count (32), round-robin request progress,
and reserved control capacity. HEADERS are bounded before QPACK decode; decoded
field-section accounting includes 32 bytes per field as RFC 9114 defines.
Large DATA payloads are consumed incrementally, without buffering a whole frame.

Validate aggregate service reservations before activation: connection parser
state, eight admitted request states, each input/output/operation slot, decoded
fields and worker Exchange retention. Configure sufficient `max_state` and
`max_bytes` explicitly for the H3 fixture; the generic 64 KiB state default is
not silently sufficient for eight streams. Engine receive and host writer limits
remain separate finite ceilings. Do not relabel these local ceilings as an exact
bound on all VM/native memory. Reject inconsistent budgets, and verify actual
retained queues/lease release under small-window peers.

No request body is read from QUIC without available application credit. Blocked
writes retain one bounded chunk, progress on `:writable`/`:tick`, and shrink a
definitely blocked chunk if required by a small peer window. A write receipt
means admission. `{:unknown, ref}` freezes that operation; resolve with
`Gaoxy.QUIC.operation_status(connection, ref)` before further destructive reads,
opens, or retry of that write. Unresolvable outcomes terminate the affected
operation/connection by its deadline and remain reported as uncertain. Never
blindly replay. No receipt is described as peer delivery.

The engine's public operation `:deadline` option is a relative millisecond
duration. Convert each Gaoxy absolute deadline to remaining time before calling
the host; do not pass monotonic timestamps as durations. The fixed timeout of
`operation_status/2` is also subject to the existing callback watchdog.

### Plug rendezvous and cleanup

Abyss's worker handles its own messages and ignores unrelated messages; sending
it H2-style GenServer calls cannot implement endpoint I/O. The callback owner
creates one ETS rendezvous with a fixed slot per admitted request. A worker can
publish at most one bounded operation, using its generation token and an atomic
empty-slot replacement. The owner polls slots on `:tick`, claims each operation
once and replies by reference. The slot remains occupied through a pending read
or uncertain write; it cannot be reused by a timeout race. Finished responses
and stale tokens cannot write twice. No unbounded messages carrying body chunks
are sent to the host owner.

Endpoint tasks monitor the callback owner. Owner death removes ETS; a worker
waiting in Transport handles DOWN or the missing table cooperatively. A synchronous
Plug busy outside Transport cannot process DOWN, so monitoring alone does not
terminate it. Before endpoint dispatch, the worker must acquire its own Admission
lease and successfully call `Admission.begin_request(gate, lease, reserve, D)`,
where D is the request's original absolute deadline. The independent Admission
process enforces D by killing the lease-owning worker, then releases its lease and
bytes on the worker's DOWN (`admission.ex`, `begin_request/4` and the `:expired` /
`:DOWN` handlers). Owner loss never renews D. No additional shorter guard is needed
for this initial contract: a busy Plug may remain alive until D, normally at most
the configured 30-second request budget. Owners perform no blocking endpoint calls
inside host callbacks.

Cleanup confirmation has the finite deadline `D + Lifecycle.cleanup_headroom()`
(currently 1,000 ms). Its evidence receipt requires observed worker DOWN, deleted
connection ETS, released request lease/bytes and released request resource pins;
owner DOWN or a requested kill alone is insufficient. Use the existing monitored
resource-holder cleanup on forced worker death; do not rely on the Plug's `after`
block running after `:kill`. If confirmation is incomplete by that deadline,
report `termination_unconfirmed` with the remaining resources, not successful
cleanup. Service-wide shutdown retains its existing, potentially earlier drain /
forced-cleanup deadline and confirmation path. Independent tests observe these
receipts without requiring a surviving connection callback.

While alive, owner ticks inspect worker liveness/deadlines because DOWN messages
are not forwarded as application events. Cleanup is idempotent for normal finish,
reset, deadline, worker crash and host death. Worker admission, armed request timer
and slot creation must complete before dispatch; failed starts leave no live stream
worker or retained slot. Owner loss may end that connection's requests, but must
not kill workers belonging to another connection or listener.

Transport implements `read_body_step`, `poll_connection`, `body_complete?` and
`abort` plus all Response facade operations with existing return shapes.
`send_chunked` starts H3 streaming; it never emits H1 chunk delimiters. Support
informational responses, HEAD/bodyless semantics, file chunks, trailing HEADERS
and exactly one terminal FIN. Handle peer RESET_STREAM/STOP_SENDING directionally;
one canceled request must not terminate siblings or permit late output.

Service stop is **bounded local cleanup**, not graceful H3 GOAWAY drain. A peer
GOAWAY is parsed and respected for its defined push semantics; it does not mean
a server must stop accepting ordinary client requests. Do not claim a graceful
local GOAWAY handshake through an ingress-first host shutdown. A future separate
host capability may enable it. Shutdown tests require process/socket/lease cleanup
and sibling-listener survival; they do not require an unexposed graceful contract.

## Completion and compatibility

G0 requalifies the selected public host; G1 proves the independent minimal H3
server; G2 proves shared HTTP/Plug streaming semantics and lifecycle; G3 records
the proxy/browser matrix. Each requires independent Sol review before the next
slice; automatically proceed after passing. Detailed commands and file ownership
are in the plan. Architecture drafting ran no Mix/build/network/browser tests.

M4 downstream proxy acceptance includes H3 -> dedicated H1 using the existing
semantic proxy path, local Plug/Phoenix over H3, streaming/cancellation/trailers,
and sibling isolation. Matrix rows for downstream H1/H2 -> upstream H3 and
H3 -> upstream H3 remain **NOT IMPLEMENTED / NOT RUN** until a separate bounded
public-client adapter slice is designed and executed. H3 -> production upstream
H2 likewise remains unimplemented. These disclosure rows do not block G0-G2 or
M3 release, but partial delivery must not be labeled full M4 matrix completion.
An upstream client adapter is a later design boundary, not permission to turn
client Session into server state or enable production pooling here.

Browser proof must show a real local HTTPS request negotiated `h3` with a trusted
fixture CA/test profile and server evidence. A browser that fell back to H2 is
not an H3 pass. Missing browser QUIC support is BLOCKED_ENV for that gate.
Ordinary Phoenix HTTP behavior is covered; H3 WebSocket/LiveView socket upgrades
remain unsupported and any fallback connection is reported separately.

No release, publication or deployment is performed by this architecture task.
Historical repair counters are unchanged: H1 Sol 3/failed 2/Astra 1; TLS Sol
4/failed 2/Astra 2; model Sol 2/failed 1/Astra 0; H2 Sol 1/failed 0/Astra 0.
This architecture assignment consumes zero Astra repair rounds and creates no
additional recovery budget.
