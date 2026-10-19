## v0.5.0 release status — 2026-10-20 (Asia/Shanghai)

Published [v0.5.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.5.0) from
`b0e1531b9d2ac682e4af19d4616ad4461e3ca6f2` with Hell 0.1.2 (`Hell` namespace,
`:hell` application) replacing Thousand Island. Accepted protocol and Phoenix
functionality is unchanged; published v0.4.0 source and binaries retain
Thousand Island. Fresh ordinary portable verification passed **210 executions /
0 failures / 144 excluded / 0 skipped**. Packaged H2/h2c/H3 WebSocket passed
**15/15 each** in builder and offline runtime; all **21 ELF objects** passed
dependency checks. Three freshly downloaded release assets match the qualified
bytes and hashes. New hosted CI remains **NOT RUN**. See the
[release notes](releases/0.5.0.md) for platform support and retained limits,
and [release acceptance](acceptance/release-0.5.0.md) for exact evidence.
Historical results below retain their recorded source identities and outcomes.

## v0.4.0 release status — 2026-10-19

Accepted source supports native H3 HTTP and RFC 9220 WebSocket through the optional embedded H3 service with explicit listener `extended_connect` opt-in. Standalone JSON can select an H3 HTTP service and fixed H3 origin, but cannot activate WebSocket endpoints or configure managed H1/H2 handles/groups/probes. External Phoenix H3 uses `server: false` and exact `websocket_paths`. Browser acceptance uses controlled QUIC-first selection; automatic H3 selection with TCP available remains unqualified. The recorded rejected-Origin 403 used H1 TLS and does not establish an H3-specific Origin-rejection result.

Published [v0.4.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.4.0) from `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Fresh ordinary portable verification: **200 executed / 0 failures / 90 excluded**; packaged H2/h2c/H3 WebSocket **15/15 each** in builder and offline runtime. All **21 ELF objects** passed dependency checks; three freshly downloaded assets match the qualified bytes and hashes. [Release acceptance](acceptance/release-0.4.0.md) records source, artifact and publication evidence. New hosted CI remains NOT RUN.

Earlier snapshots retain their capture-time scope and actual failed, blocked and unexecuted results. Specialist qualification remains with its dedicated environment; deployment and production acceptance remain NOT RUN.

# Native HTTP/3

Select the optional `gaoxy_http3` application explicitly. It serves the existing
Endpoint/Exchange/Response and Plug APIs over native QUIC; H1/H2 consumers keep
their existing dependency closure. [M4 acceptance](acceptance/m4.md) records
passing M4 implementation gates and completed independent acceptance. M5
WebSocket support is **COMPLETE LOCALLY within its ordinary verification scope**;
[M5 acceptance](acceptance/m5-websocket-over-h2-h3.md) records current runtime and
independent closeout review evidence separately from the M4 HTTP evidence.

## Embedded service

```elixir
{:ok, spec} = Gaoxy.HTTP.HTTP3.service_spec(
  id: :h3,
  ip: {127, 0, 0, 1},
  port: 0,
  plug: {MyApp.Endpoint, []},
  tls: %{certfile: "/path/to/cert.pem", keyfile: "/path/to/key.pem"}
)
{:ok, runtime} = Gaoxy.start_link(services: [spec])
{:ok, {_, port}} = Gaoxy.info(runtime, :h3).local
```

An Endpoint can instead be selected with `endpoint: {module, options}`. Configure
a concrete IPv4 address, QUIC v1 and ALPN `h3`; activation rejects other profiles
and missing credentials. Finite connection, stream, parser, body, output and
worker reservations are checked before activation. Application responses use
the shared HTTP facade, including streaming DATA, repeated ordered trailers and
bounded request reads. Local write admission does not prove peer delivery.

The existing fixed reverse proxy can serve an H3 downstream with an H1 origin:
use `endpoint: {Gaoxy.Proxy.HTTP, %{upstream: "http://127.0.0.1:9000"}}` and a
service budget such as `limits: %{max_bytes: 134_217_728}`. Each upstream request
uses a dedicated H1 connection and its conservative cleanup reservation. H2/H3
declared request trailers translate to H1 chunked framing, including zero DATA;
the original downstream Content-Length is still validated. Authentication and
destination policies retain their existing requirements. There is no automatic
protocol fallback or reusable upstream pool.

For a fixed H3 origin, explicitly select
`%{upstream: "https://origin.example:443", upstream_protocol: :http3,
cacertfile: "/path/to/ca.pem"}`. HTTPS and an explicit regular CA file are
required. The caller-owned public Session client retains one dedicated endpoint
per request through confirmed cleanup. Upload chunks are at most16KiB; all
requests have an explicit terminal FIN, including zero-DATA trailers. Configure
a sufficient service byte budget. Protocol discovery, dial overrides, arbitrary
client modules and H3 upstream groups are rejected. The independent H1/H2/H3-to-H3 matrix passes66network+2policy checks
in both the first execution and required fresh repeat, with independent reviews.
The [final ledger](acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
records the exact source identity and workload limits.

## Native WebSocket and external Phoenix mount

Native downstream RFC 9220 WebSock streams are implemented in the current
M5 source. Listener `extended_connect` defaults to `false`; opt in explicitly.
Each admitted request worker runs the shared WebSock frame/callback engine while
the existing QUIC connection owner retains I/O and flow-control authority.
Successful CONNECT returns 200, with WebSocket frames in H3 DATA and normal
Close followed by stream FIN. The admitted finite WebSocket lifetime replaces
the original HTTP request deadline. Native Exchange metadata retains CONNECT,
HTTP/3 and `protocol: "websocket"` throughout.

For Phoenix, run its Endpoint supervisor with `server: false` and explicitly
mount the compatibility wrapper on a separate H3 service:

```elixir
{:ok, spec} = Gaoxy.HTTP.HTTP3.service_spec(
  id: :h3,
  ip: {127, 0, 0, 1},
  port: 0,
  plug: {Gaoxy.PhoenixWebSocket,
         {MyApp.Endpoint, ["/live/websocket", "/socket/websocket"]}},
  extended_connect: true,
  tls: %{certfile: "/path/to/cert.pem", keyfile: "/path/to/key.pem"}
)
```

The exact path list must match declared Phoenix sockets. The wrapper presents
GET only while invoking the Endpoint for a validated native WebSocket request;
Origin/session/CSRF/authentication and early upgrade validation remain enabled.
The external duplicate-listener guard still rejects an Endpoint serving its own
listener. H3 remains optional and separate from HTTPS H2/H1 negotiation; no
automatic H3 fallback is introduced. See [native Phoenix usage](native-http.md)
and the [authoritative M5 gate ledger](acceptance/m5-websocket-over-h2-h3.md).
The ordinary Phoenix H3 browser profile passed 12/12 checks. Successful sockets
were correlated with native H3 CONNECT streams, normal Close 1000 and zero
resources after cleanup. The fixture initially exposed QUIC only, then enabled
same-port native H1 TLS for the opaque-origin rejection check after both H3
sockets were established. That negative check is an H1 403 result, not an
H3-specific Origin rejection claim. Browser profiles use ordinary HTTPS
navigation before the application flow to complete startup trust preparation;
the client still chooses each WebSocket transport. An H2 page does not guarantee
H2 WebSockets, including after future certificate updates. This qualifies
controlled H3 browser use; automatic H3 selection with TCP available is not
established.
Outbound H2/H3 WebSocket proxy transports, other extended-CONNECT protocols,
compression and standalone JSON WebSocket activation are outside this stage.
Specialist fault, slow-peer, pressure and sustained-load qualification is deferred.

## Standalone data configuration

`GAOXY_CONFIG` accepts this explicit version-1 service; credential paths must
refer to existing files. Ordinary `handler: "http"` services retain H1 defaults.

```json
{
  "version": 1,
  "services": [{
    "id": "h3",
    "handler": "http3",
    "transport": "quic",
    "protocols": ["http3"],
    "ip": "127.0.0.1",
    "port": 0,
    "tls": {"certfile": "/path/to/cert.pem", "keyfile": "/path/to/key.pem"},
    "limits": {"max_bytes": 33554432},
    "routes": {"version": 1, "routes": [{
      "target": {"type": "static", "body": "hello"}
    }]}
  }]
}
```

The allowlist supports static and fixed reverse-proxy targets. A reverse-proxy
target accepts `"upstream_protocol": "http1"` (the default) or `"http3"`;
H3 also requires an HTTPS `"upstream"` and `"cacertfile"`. Other values and
client/dial/TLS override fields are rejected before activation.
Route reload uses `Gaoxy.Server.reload_routes("h3", path, timeout)` locally:
the listener stays bound, in-flight requests retain their selected generation,
and invalid configuration preserves the current routes. All configured stream
snapshots are included in the service byte budget. Unknown keys/protocols and
invalid upstream-H3 options are rejected; data configuration evaluates no
code and creates no atoms or public management endpoint.

## Historical M4 verification and current limits

The evidence below retains its M4 checkpoint scope. The later
[v0.3.0 release acceptance](acceptance/release-0.3.0.md) separately records
portable qualification and publication; its source differs from current M5.
Current M5 ordinary H3 peer and Phoenix browser checks passed; the
[M5 ledger](acceptance/m5-websocket-over-h2-h3.md) records exact counts, browser
selection limits and the final independent closeout review.

The local matrix uses independent aioquic 1.2.0 peers and Chromium
152.0.7977.64/Playwright 1.56.0. The Phoenix example's `h3_gateway.exs` disables
duplicate Endpoint listeners before application startup. Browser trust is a
process-local fixture SPKI pin, with explicit QUIC and IPv4 localhost mappings;
CDP `h3` and unique server request markers qualify the existing page and static
resource. This historical M4 evidence qualifies ordinary HTTP pages only.
Current M5 WebSocket browser acceptance requires marker-correlated native
CONNECT/HTTP-version/stream receipts; a page CDP protocol cannot qualify it.

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
  integration/http3/matrix.py --evidence docs/acceptance/evidence/m4/matrix
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
  integration/http3/standalone/run.py --evidence docs/acceptance/evidence/m4/standalone
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' bash scripts/h3-consumer.sh
```

Strictly compile the umbrella and the explicit `PHOENIX_NATIVE_H3=1` example
before running the matrix. Its pinned aioquic and Playwright environments and
Chromium are required; missing prerequisites are BLOCKED_ENV. Each gate freezes
source hashes, retains finite deadlines and verifies owned teardown/port rebind.
The separate release-artifact E2E workflow stays disabled.

The [request-trailer dependency](dependency-requests/http-fetch-h3-request-trailers.md)
is resolved in installed0.21.4; all15Fetch functional diagnostics pass. Fetch H3
cleanup completion remains unsupported. The selected
[public Session plan](plans/m4-public-session-upstream.md) has passed direct
qualification and client/guardian integration with independent review and fresh
verification. Standalone H3-origin runtime passes16checks with independent review
and a fresh repeat. Both complete UP2 executions and all
prescribed final source/native/browser/standalone/Session/consumer checks PASS.
Final independent M4 acceptance PASS; portable build, offline packaged runtime
and publication are NOT RUN. UP2 explicitly selects1ms host polling for its
tiny-window workload; passing within5s establishes no default10ms throughput
margin. Dynamic QPACK, push, extended CONNECT protocols other than the
explicit M5 WebSocket opt-in, WebTransport,
DATAGRAM, 0-RTT, migration, mTLS, IPv6/wildcard bindings and graceful H3 GOAWAY
drain remain unsupported. Stop qualifies bounded local host cleanup.
