# M5 native WebSocket over HTTP/2 and HTTP/3

Date: 2026-10-19. Status: **REVIEWED DESIGN; M5 COMPLETE LOCALLY within ordinary verification scope**.
[M5 acceptance](../acceptance/m5-websocket-over-h2-h3.md) records G0–G5 runtime
results, source identities and the final independent closeout review.
Architecture gate: `PROJECT_ARCHITECTURE`, architecture mode. Baseline:
`main@43363c2be851de4b2c999232f9116993bf20647a`. M5 is a newly proposed stage,
not a recovered historical M5–M8 roadmap. See the [implementation plan](../plans/m5-websocket-over-h2-h3.md).

## Goal and accepted boundary

Serve RFC 6455 WebSocket sessions on individual native H2/H3 streams using
RFC 8441 and RFC 9220 extended CONNECT. Native Plug endpoints and Phoenix
LiveView/Channels must use the same WebSock callbacks as existing H1 sessions.
Ordinary requests and multiple WebSockets can share a connection. The feature
must preserve existing H1 WebSocket and H1 upstream proxy compatibility.

This stage covers server-side sessions. Outbound H2/H3 WebSocket proxy support,
compression, WebTransport, DATAGRAM, generalized CONNECT tunnelling, QUIC
migration, and unrelated H3 capabilities are separate work. Do not interpret an
extended CONNECT authority as permission to open a TCP connection to that host.
The existing `Gaoxy.Proxy.WebSocket` H1 path remains its own acceptance surface;
this design does not claim an H2/H3-downstream-to-H1-upstream bridge.

M3's accepted scope and historical evidence remain intact. Dedicated abnormal,
disconnect fault-injection, blocked-writer, slow-peer, pressure and sustained-load
qualification are outside this stage's ordinary acceptance environment. Protocol
unit checks and normal finite network/browser scenarios remain required. No
publication, deployment, production credentials/data, Vault, public-management,
or disabled release-artifact E2E permission is added by this document.

## Preimplementation source findings and alternatives

The following findings describe the recorded preimplementation baseline, not
the current M5 source capability. All module paths are relative to the repository root.

| Existing seam | Observed constraint |
| --- | --- |
| `apps/gaoxy_http/lib/gaoxy/http/websocket.ex` | Owns WebSock callbacks, bounded state, timers and RFC 6455 parsing, but directly sends an H1 101 response and socket bytes. `Admission.upgrade/4` establishes a separate finite WebSocket lifetime. |
| `http/websocket/{frame,message,handshake}.ex` under the same directory | Frame/message parsing is reusable. Handshake requires H1 GET, Key and Upgrade headers. |
| `http/http2/{headers,stream,connection,transport}.ex` | Headers exclude `:protocol`; worker returns 501 for all CONNECT; ordinary finalization ends the stream. Owner tracks request deadline and HTTP body total. |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/{headers,protocol,stream,connection,operations,transport}.ex` | Same CONNECT rejection. Pure protocol counts HTTP-body bytes; connection and Operations ledger separately enforce the request deadline. QUIC I/O belongs to the attached connection owner. |
| `apps/gaoxy_http/lib/gaoxy/plug_adapter.ex` | H2/H3 upgrades return `:not_supported`. `Exchange.plug_conn/1` faithfully preserves request method and version. |
| `vendor/websock_adapter/lib/websock_adapter/upgrade_validation.ex` | H2 CONNECT + version-13 validation exists; H3 is rejected by the protocol switch. |

Three approaches were considered:

1. Run each WebSock application inside the H2/H3 connection owner. This avoids
   a worker but couples callback execution and application messages to every
   stream; H3's host callback interface does not expose arbitrary application
   mailbox messages. Rejected.
2. Implement independent H1/H2/H3 WebSocket engines. This isolates adapters but
   duplicates frame, callback, close, and limit behavior. Rejected.
3. **Recommended:** retain the current stream-worker PID after its Plug call;
   run a shared WebSocket engine there, with transport-specific bounded stream
   operations. Existing owners keep all connection I/O and scheduling authority.
   This adds a small mailbox driver and stream transition while reusing the
   existing callback implementation and preserving optional QUIC isolation.

H1 keeps its existing connection-driven callback lifecycle. Refactor only the
handshake/output seams needed for reuse; do not relocate H1 ownership as part of
M5. `gaoxy_http3 -> gaoxy_http -> gaoxy` remains the dependency direction.

## Server protocol defaults and h2c

The user's default-policy clarification is implemented in the current M5 HTTP
and Phoenix facades. G2 verifies these defaults:

| Listener | Current default or explicit selection |
| --- | --- |
| HTTPS, including Phoenix HTTPS | Default `protocols: [:http2, :http1]`, advertising ordered ALPN `h2`, `http/1.1`. Prefer H2; retain H1 negotiation and no-ALPN fallback. |
| Plain HTTP | Keep H1 by default. Explicit `protocols: [:http2], h2c: :prior_knowledge` selects the existing cleartext H2 mode. |
| Explicit H1-only | Preserve `protocols: [:http1]`, including HTTPS. |
| HTTP/3 | Remains a separate optional service; no automatic protocol switch. |

h2c support covers prior knowledge, including the new H2 WebSocket stream path.
H1-to-h2c Upgrade and automatic mixed H1/h2c detection remain unsupported. These
server defaults do not change upstream transport selection. H2 selection and
`extended_connect` enablement are separate: the latter retains its explicit
per-listener opt-in.

Choose transport-dependent defaults in `Gaoxy.HTTP`, before normalizing options;
the lower-level normalizer has no transport context. Phoenix must delegate an
omitted protocol choice rather than override HTTPS with H1. Retain existing TLS
version/security and H2 host validation, and standalone JSON's explicit H1
protocol selection.

H2 defaults must also start with a sufficient service budget. The current H2
defaults require at least 173,302,823 bytes, exceeding the core default 1 MiB.
For an HTTP-facade service selecting H2, default `limits.max_bytes` to 256 MiB
(268,435,456 bytes) only when that field is omitted. Keep core/H1 defaults,
caller-supplied values and reservation formulas intact. Explicitly insufficient
budgets, or larger custom reservations exceeding the chosen budget, still fail
validation. This is an accounting limit, not an eager memory allocation.

## Wire contract

References: [RFC 8441 §§3–5](https://www.rfc-editor.org/rfc/rfc8441.html),
[RFC 9220 §3](https://www.rfc-editor.org/rfc/rfc9220.html), and RFC 6455 framing.
The official RFC text was inspected for this design.

- Add explicit listener option `extended_connect: false` (boolean default).
  H2 and H3 listeners opt in separately. Thread it through strict service,
  and Phoenix-listener configuration validation to the actual owner. M5 covers
  embedded service APIs and Phoenix integration; standalone JSON activation is
  outside this stage and retains its current strict configuration contract.
  H3 remains a separate optional service; this does not add `http3:` to
  `Gaoxy.PhoenixAdapter`.
- With support enabled, advertise `SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`
  (identifier `0x08`) in that protocol's initial SETTINGS. With it disabled,
  omit the setting, retain ordinary behavior and reject `:protocol` requests.
  Do not advertise a partially implemented stream path. A setting cannot later
  change from 1 to 0 on a connection. Values outside 0/1 are protocol errors.
  Receiving the client's setting is not the server's authorization to accept
  extended CONNECT; server enablement is local.
- Accept `:method = CONNECT`, `:protocol = websocket`, and required
  `:scheme`, `:path`, `:authority` with normal path, authority and TLS validation.
  Reject duplicate/misordered pseudoheaders and `:protocol` on other methods.
  A syntactically valid unsupported protocol receives 501; ordinary CONNECT
  keeps its existing 501 behavior. Extended CONNECT routes by local path.
- Require `sec-websocket-version: 13`; preserve cookies, Origin, authentication
  and subprotocol offers for the application. The successful response is
  **200**, with the stream left open. Do not emit 101, Connection, Upgrade,
  Content-Length, Transfer-Encoding, or Sec-WebSocket-Accept. Do not perform the
  H1 Sec-WebSocket-Key/Accept exchange. Preserve valid application response
  headers and validate any selected subprotocol against the offer.
- RFC 6455 bytes travel in H2/H3 DATA payloads. Frames may cross DATA boundaries;
  multiple frames may occupy one DATA payload. Masking, UTF-8, control frames,
  fragmentation and message limits remain RFC 6455 rules. Client masking remains
  mandatory. No compression extension is negotiated.
- A failed application handshake remains an ordinary HTTP response, with normal
  end-of-response semantics. An accepted tunnel does not use HTTP body
  Content-Length, cumulative body limits, trailing headers, or `Response.finish`
  to determine WebSocket message completion.

## Metadata and shared engine APIs

The following APIs and fields are implemented in the current M5 source. Their
source-bound verification and limitations are recorded in the acceptance ledger.

| Module/file | Responsibility |
| --- | --- |
| `Gaoxy.HTTP.Request` (`http/request.ex`) | Add `protocol: nil` or a validated binary from `:protocol`. Keep wire method `CONNECT`, version and target path intact. Mark valid extended-CONNECT payload as `body: :tunnel`. |
| New `Gaoxy.HTTP.WebSocket.ExtendedHandshake` (`http/websocket/extended_handshake.ex`) | Pure `headers(request, response_headers)` returning `{:ok, fields}` or a typed handshake error. Validate CONNECT, websocket protocol, version, and shared response/subprotocol rules; emit only legal regular response fields. |
| `Gaoxy.HTTP.WebSocket` | Preserve `prepare/2`, `response_headers/2`, `start/2`, callback and close semantics. Select H1 or extended handshake by validated metadata. Add `data(bytes, ws)` for stream delivery; retain existing H1 `data(bytes, socket, ws)`. Delegate stream output through `exchange.transport`. |
| New `Gaoxy.HTTP.WebSocket.Stream` (`http/websocket/stream.ex`) | `run(exchange, service_limits)` becomes the mailbox driver on the already admitted H2/H3 worker; no extra application process or socket owner. Calls shared engine start/data/info/terminate. |
| H2/H3 `Transport` | Add the four operations below, preserving existing HTTP operation entry points. H3 implementation stays in `gaoxy_http3`. |

Transport operation contract:

```elixir
websocket_open(exchange, headers, lifetime_deadline) # {:ok, updated_exchange} | {:error, reason}
websocket_demand(exchange, credit, ref)             # :ok | {:error, reason}
websocket_send(exchange, bytes)                    # :ok | {:error, reason}
websocket_finish(exchange)                         # :ok | {:error, reason}
```

`websocket_open` validates stream/token/worker and handshake state, adopts the
new lifetime consistently, then writes status 200 without END_STREAM/FIN.
`websocket_demand` registers one bounded receive credit and returns promptly;
the owner later sends `{:gaoxy_websocket_data, token, ref, bytes, ended}`.
Only the registered worker may issue these operations; tokens and fresh refs
prevent a previous delivery or another stream from spending the credit.
`websocket_send` writes bounded DATA under the stream and connection windows;
its acknowledgment means that write completed, not merely entered a queue.
`websocket_finish` queues normal END_STREAM/FIN after prior DATA, without
closing the shared connection. Existing transport abort machinery handles
terminal cleanup when graceful completion is no longer possible.

Before an upgraded response, `Exchange.read_body*` rejects `:tunnel` with a
specific unsupported-body error; a generic Plug parser must not consume
WebSocket bytes. Pass metadata to the application without synthesizing H1
Upgrade headers or changing the entire request to GET.

## Stream ownership and lifetime

The owner-controlled transition is:

```text
request headers -> endpoint handshake -> opening -> websocket -> closing -> done
                         |
                         +-> ordinary HTTP rejection -> done
```

1. Header validation identifies an extended CONNECT before dispatch. The
   request remains subject to ordinary header/handshake deadlines. Any received
   tunnel DATA is held under the existing bounded stream ingress reservation;
   it cannot trigger WebSock callbacks before the successful handshake.
2. The endpoint returns the existing prepared `{:websocket, ...}` response.
   H2/H3 workers branch to `WebSocket.Stream.run/2` instead of `Response.finish`
   and early worker-completion notification. They retain the same PID and lease,
   so application/PubSub messages and ownership monitors remain meaningful.
3. Shared `start/2` validates options and reserves state. Its stream path uses
   the existing `Admission.upgrade/4` transition, with a finite absolute
   WebSocket deadline based on `max_lifetime` (existing default 24 hours).
   The connection's stream record, Exchange, Admission lease and H3 Operations
   ledger must all adopt that same deadline once. Implement an owner-validated
   ledger transition for H3; merely changing Exchange.deadline is insufficient.
4. Complete admission and owner validation before making 200 observable. Only
   after the handshake write succeeds call WebSock `init/1`. A failed opening
   cleans up its own stream/lease; do not initialize an application or retain a
   half-committed tunnel. H3 tracks the opening operation separately from its
   new lifetime so an uncertain write is not submitted twice.
5. The worker receives bounded transport messages, WebSock application messages,
   lifetime/close timers and drain signals. It invokes existing `handle_in/2`,
   `handle_info/2`, optional `handle_control/2` and `terminate/2` semantics.
   Application push must work while no client bytes arrive; a blocking body-read
   loop that starves application messages does not meet the contract.
6. Existing finite idle, callback, write and close timeouts apply within the
   absolute lifetime. Neither traffic nor callbacks renew `max_lifetime`.
   Owner expiration checks use the WebSocket lifetime after opening, not the
   former 30-second request deadline. Existing drain deadlines may shorten it.
7. Normal close exchanges an RFC 6455 Close frame and finishes the stream's send
   direction. Peer END_STREAM/FIN is an EOF event for this session, not the entire
   connection. Normal close receipt, callback termination and worker completion
   occur once. The owner releases stream state, reservations and membership
   according to existing cleanup ownership. Stream exceptions use the protocol
   mapping (H3 `H3_REQUEST_CANCELLED`); no new graceful H3 GOAWAY claim is made.

## Flow control and accounting invariants

- H2 `Connection` and its `Writer` retain wire authority. H3 `Connection` alone
  calls `Gaoxy.QUIC`; workers never borrow its opaque QUIC handles for I/O.
- After opening, stream state distinguishes tunnel DATA from HTTP body DATA.
  Remove cumulative HTTP-body-byte checks only for the accepted tunnel mode;
  retain stream windows, ingress caps, frame/message limits and output bounds.
- At most one input credit is registered per session. The owner reserves the
  transfer before sending it; delivery bytes and parser carry remain charged
  until the worker consumes them. The next demand acknowledges consumption of
  the preceding reference. `websocket_demand(exchange, 0, delivered_ref)` is the
  final acknowledgment of exactly that delivery without granting fresh credit.
  Positive credit uses a new ref and consumes the one preceding delivery for
  the verified worker. No automatic credit refill on mere enqueue.
- H2 replenishes stream and connection receive windows consistently with
  consumed bytes, including correct padding accounting. H3 continues bounded
  public QUIC reads; its HTTP3.Protocol emits credited tunnel DATA without
  growing a lifetime body accumulator or changing DATA frame validation.
- Keep per-stream writes bounded, honor peer credit and existing shared-writer
  scheduling, and retain finite write deadlines. A WebSocket owns no additional
  unbounded output queue. Admission accounts parser carry, assembled messages,
  callback state, in-flight delivery and output according to existing limits.
- H3 Operations gets a separate bounded demand slot. It must not hold the
  existing single request-operation slot while waiting for incoming data:
  otherwise an idle session cannot send an application push. Existing
  token/worker/operation acknowledgments continue to guard output and finish.

## Plug, Phoenix and dependency compatibility

`Gaoxy.PlugAdapter.upgrade/3` delegates to shared preparation only for a validated,
enabled WebSocket tunnel. `PlugEndpoint` already propagates prepared upgrade
response headers; keep this path and reject unsupported upgrade kinds.
The vendored WebSockAdapter needs explicit H3 validation equivalent to its H2
CONNECT/version-13 validation, while Gaoxy validates the pseudoheaders.
Preserve early validation; do not globally disable it. Record the small vendor
compatibility change and upstream provenance during implementation.

The selected Phoenix 1.8.15 source has a GET-only
`Phoenix.Transports.WebSocket.call/2` clause and Endpoint hardcodes that transport
for `socket` routes. The existing vendored validator, conversely, expects
CONNECT for H2. Therefore simply removing Gaoxy's upgrade rejection cannot
enable Phoenix. Choose a narrow compatibility bridge:

- New `Gaoxy.PhoenixWebSocket` in
  `apps/gaoxy_http/lib/gaoxy/phoenix_websocket.ex` implements Plug with
  `init({endpoint, websocket_paths})`. Endpoint-level `websocket_paths` defaults
  to `[]` and explicitly lists exact existing socket URLs such as
  `/live/websocket` and `/socket/websocket`; no wildcard or inferred route.
- `Gaoxy.PhoenixAdapter` wraps the Endpoint with this bridge, preserving its
  existing `Phoenix.Endpoint.SyncCodeReloadPlug` composition when configured.
  Only a native enabled and validated H2/H3 websocket extended CONNECT on an
  exact listed socket path gets a temporary `Plug.Conn.method = "GET"` while
  invoking the Phoenix endpoint. The immutable adapter Exchange request remains
  CONNECT with its actual protocol/version. Restore the Conn method on return.
  Ordinary Plug requests and unlisted paths are passed through unchanged.
- Add a Gaoxy-only branch to vendored early validation which reads the immutable
  Exchange request through map matching, without a compile-time Gaoxy struct
  dependency. Validate CONNECT, websocket protocol and version 13; Gaoxy's own
  upgrade path additionally requires native enabled stream state. The apparent
  Phoenix GET cannot authorize an upgrade on an ordinary request. All other
  adapters retain their existing validation.
- This reuses Phoenix's complete socket handshake, including Origin, session,
  CSRF, subprotocol, auth-token, connect callback and error handling. Do not
  fork its transport, invoke private session/config helpers, synthesize H1
  headers, change HTTP-version reporting or disable early validation.
- An explicit H3 mount uses
  `{Gaoxy.PhoenixWebSocket, {Endpoint, ["/live/websocket", "/socket/websocket"]}}`
  as its Plug, with `extended_connect: true` and externally mounted Endpoint
  `server: false`. Its paths must match real Endpoint socket declarations;
  installation validation includes each listed route's actual handshake.
  Merely switching the server adapter does not enable this compatibility mode.
- Preserve duplicate-listener enforcement through the wrapper. Extend the
  external two-element `PlugEndpoint.init/1` path to recognize the wrapper and
  apply its existing `Phoenix.Endpoint.server?/2` check to the original Endpoint.
  An externally mounted wrapped Endpoint with `server: true` is rejected before
  activation. `PhoenixAdapter` uses the existing outer three-element
  `{module, options, :endpoint_managed}` form, so its wrapped `server: true`
  Endpoint remains valid. This needs no extra wrapper init mode or user option.
  Test external true rejection, external false acceptance and internally managed
  true acceptance, including the code-reload composition.

Validate unlisted paths stay CONNECT, ordinary GET remains unchanged, the
allowlisted socket retains wire metadata, and rejected Phoenix handshakes retain
their original policy response. Align the independent Phoenix fixture's
dependency cohort with the root cohort before recording fresh consumer/browser
evidence. The small WebSockAdapter changes are source-vendor compatibility work
with explicit provenance, not permission to patch `deps/` or disable validation.

Existing public H3 settings/control/frame APIs support the planned server path;
no downstream dependency blocker has been established. `HTTP.WebSocket` supports
H2 client browser mode, but its acknowledgment-based proxy mode remains H1 and
its API has no H3 selector. Use independent H2/H3 peers for server acceptance;
do not turn those outbound proxy boundaries into an M5 server prerequisite.

## Delivery sequence and acceptance

Implement shared metadata/handshake/engine seams first, then H2, then H3, then
Phoenix and external-consumer/browser integration. Enable each listener path
only after its coherent settings, stream and lifetime implementation exists.
The implementation plan supplies concrete files, scoped commands and review
boundaries. Required results:

1. Ordinary TLS peers establish H2 preference under omitted HTTPS protocols,
   H1 negotiation/no-ALPN fallback and explicit H1 override. Verify Phoenix
   defaults, explicit h2c selection and sufficient omitted-budget behavior;
   pure checks retain explicit low-budget and unsupported-host rejection.
   Pure scoped checks also establish SETTINGS, pseudoheaders, 200 response fields,
   subprotocol selection, frame fragmentation/masking and ordinary close state
   transitions. Existing ordinary CONNECT rejection and disabled mode remain
   explicit; malformed cases are bounded unit inputs, not a fault campaign.
2. Independent real H2, h2c and H3 clients receive advertised enablement, establish
   status-200 WebSockets, exchange text/binary/ping/pong, receive an unsolicited
   application push, and close normally. Two simultaneous WebSocket streams and
   an ordinary HTTP sibling share the same connection, with correctly addressed
   messages and independent orderly closure. Unit/state tests cover coordinated
   deadline transition; one bounded normal peer case continues messaging after
   the original HTTP request deadline (fixture request timeout 1 second,
   WebSocket lifetime 10 seconds, case deadline 5 seconds). This is a functional
   lifetime check without fault injection, a slow peer, pressure or sustained load.
3. Phoenix Channels and LiveView click/upload work through native WS-on-H2 and
   WS-on-H3. Capture actual WebSocket stream/connection identity and protocol
   alongside browser behavior using a unique URL marker and bounded native
   server fixture receipt; an H2/H3 page alone is insufficient. H1 fallback
   may remain available, but must be reported as H1 and cannot pass these gates.
4. Record browser/version/flags and independent-peer versions. If a selected
   browser cannot negotiate a target protocol with supported configuration,
   record browser **BLOCKED_ENV**, continue independent-peer work and qualify an
   available capable browser if possible. Do not relabel a peer test as browser
   acceptance. No packet-capture campaign is required. Keep fixture-only
   protocol receipts bounded and free of secrets.
5. Scoped H1 WebSocket, current proxy, HTTP, consumer and package-isolation
   compatibility checks pass; installing only core or H1/H2 does not pull in
   optional QUIC. Independent specification/code review precedes final fresh
   verification and capability-document updates.

Current M5 G0–G5 ordinary runtime checks passed. Independent H2, h2c and H3
peers each passed 15/15; Phoenix H2, H3 and H1 browser profiles each passed 12/12.
Successful H2/H3 sockets have marker-correlated native CONNECT/version/stream
receipts. Browser profiles complete startup trust preparation with an ordinary
HTTPS navigation before the application flow. Clients choose actual WebSocket
transports; an H2 page does not guarantee H2 WebSockets, including after future
certificate updates. The H3 browser fixture initially exposed QUIC only, then enabled
same-port H1 TLS after both successful H3 sockets were established for the
opaque-origin 403 check. That rejection is H1 evidence, not an H3-specific
negative claim; automatic H3 selection with TCP available is unqualified.
Scoped compatibility passed 136 tests/0 failures, with separately recorded H1,
proxy, WSS, contract and isolated consumer checks. The acceptance ledger retains
all failed, blocked and unexecuted historical attempts and the final independent
closeout review. No specialist fault/load, publication, merge or deployment
acceptance follows. Historical Sol/Astra counters remain inherited; architecture
design consumes no recovery round and Astra recovery remains exhausted at 2/2.
