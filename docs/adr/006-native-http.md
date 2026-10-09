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
authority/SNI and forwarding-header policy remain part of the blocked proxy work.

The first upstream audit found missing required public HTTP Fetch H1 contracts
in 0.17.1 (#27–#30). All four issues are closed; the published 0.17.2 contract
regressions pass. Proxy integration remains blocked on #45 (GET/DELETE request
body loss) and the valid-close-code subset of #38. Message-level WebSocket
proxying does not require exact fragmentation or ping/pong forwarding, but must
preserve valid close codes. No private socket access or local workaround is
accepted. Native HTTP/Plug/WebSock/Phoenix and pure routing are independently
verified; full M2 remains incomplete.

The global client streaming threshold can be an explicit static startup
constraint: `streaming_threshold: 0`, checked when the future proxy initializes
and never changed per request. This makes per-request streaming issue #37
nonblocking under the documented host constraint. `gaoxy_proxy` selects the
published Fetch/WebSocket packages and their QUIC/TLS-engine dependencies;
standalone core consumers retain their isolation. Package presence establishes
no H2/H3 capability. See [the current dependency audit](../m2-dependency-audit.md).
