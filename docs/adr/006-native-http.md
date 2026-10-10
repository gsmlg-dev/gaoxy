# ADR 006: Native HTTP connection ownership

Gaoxy owns native HTTP/1 request/response execution. A trusted `handler_mode:
:native` TCP/TLS service selects a public Thousand Island handler while retaining
Gaoxy's listener, admission, registry, service and instance ownership. Default
stream handlers keep their existing callback contract. Core has no dependency
on HTTP, Plug, Phoenix or an upstream client.

`Gaoxy.HTTP.Connection` owns the connection and executes local Plug requests.
Public synchronous `ThousandIsland.Socket.recv/send` operations support bounded
Plug body reads and acknowledged chunk writes without a body broker process.
Pure `Gaoxy.HTTP.HTTP1` parsers retain only bounded framing state. The shared
request/exchange contract separates endpoint dispatch from wire ownership;
proxy endpoints belong in `gaoxy_proxy` and implement the HTTP endpoint contract.

Native admission distinguishes opening a connection from beginning another
request. The latter checks the admission mode atomically, so pipelined or
keep-alive requests cannot cross a drain barrier. Admitted callbacks retain their
original request deadline. Drain notifications carry the service's original
absolute deadline; idle connections close, requests finish with closure, and
WebSockets perform bounded shutdown. Existing forced cleanup remains the final
termination authority.

Header, body-read, write, request and upgraded-idle limits are explicit. Parser
tails, pending body pieces, frames and handoff bytes are charged before further
reads/writes. Kernel buffers and arbitrary application-owned data are outside
that metric and must not be claimed as measured. Unread request bodies force
connection closure rather than being mistaken for a new request. File responses
use bounded pieces. An SSE request has a configured finite lifetime rather than
silently inheriting the raw-stream five-second callback limit.

WebSock changes the same connection owner into an upgraded mode. The selected
WebSockAdapter 0.6.0 lacks native adapter registration. A minimal reviewed fork,
vendored from a recorded immutable upstream and local fork commit with its MIT
license and patch, adds legitimate `Gaoxy.PlugAdapter` dispatch. Replace this
fork when upstream supports that adapter or public registration; never impersonate
another server or rewrite fetched dependency modules.

Phoenix Endpoint-managed startup owns one Gaoxy instance and its configured
HTTP/HTTPS services. Gateway mounting requires an Endpoint with listener
ownership disabled. Bound port discovery uses public runtime information. The
fixture includes real browser/network checks and remains outside production's
dependency graph.

Routes use first-declared matching precedence, immutable compiled entries,
normalized hosts, case-sensitive methods, and exact or segment-prefix raw paths. Paths
retain their escaping; matching never repeatedly decodes input. Invalid
authorities and ambiguous framing are rejected before dispatch. Upstream
authority/SNI comes from fixed trusted HTTP/WebSocket endpoint configuration.
Forwarding fields from the client and all Connection-nominated fields are removed;
new forwarding metadata uses the actual downstream connection.

HTTP Fetch 0.19.0 resolves the earlier #27–#30, #38, #45 and #60 contracts. Native
message-level WebSocket proxying now preserves valid/empty Close details and
subprotocols, with independent ping/pong on each hop. It uses public acknowledged
send/delivery APIs and monitors the public socket PID for completed cleanup.
Guardians live outside the instance subtree; core cleanup attachments retain byte
reservations without allocating a second active lease. Service drain requires a
receipt and normal guardian DOWN and never kills the cleanup owner to infer success.

HTTP streaming uses a public RequestCompletion handle obtained immediately from
its original Promise. Cleanup receipts require completion confirmation, including
abort before establishment and during upload or response streaming. The adapter
uses public Task results and ACK stream events; it never inspects private client
state. Native body polling, finite per-window writes and header/trailer policy
connect both hops without collecting bodies. Explicit socket buffers and the
inspected OTP 28.5.0.5 receive contract supply the conservative reservation bound.

Full M2 raw-target acceptance remains blocked on #64: the upstream H1 serializer
loses a present empty query. Its regression stays enabled, without a local URI
rewrite. Per-request `stream_response: true` avoids a global streaming threshold.
Core consumers remain isolated from the proxy's published QUIC/TLS-engine
dependencies. Package presence establishes no H2/H3 capability. See
[the current dependency audit](../m2-dependency-audit.md).
