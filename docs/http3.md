# Native HTTP/3

Select the optional `gaoxy_http3` application explicitly. It serves the existing
Endpoint/Exchange/Response and Plug APIs over native QUIC; H1/H2 consumers keep
their existing dependency closure. [M4 acceptance](acceptance/m4.md) records
local qualification and the remaining upstream Session integration.

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

The allowlist supports static and existing fixed H1 reverse-proxy targets.
Route reload uses `Gaoxy.Server.reload_routes("h3", path, timeout)` locally:
the listener stays bound, in-flight requests retain their selected generation,
and invalid configuration preserves the current routes. All configured stream
snapshots are included in the service byte budget. Unknown keys/protocols and
nonfunctional upstream-H3 options are rejected; data configuration evaluates no
code and creates no atoms or public management endpoint.

## Verification and limits

The local matrix uses independent aioquic 1.2.0 peers and Chromium
152.0.7977.64/Playwright 1.56.0. The Phoenix example's `h3_gateway.exs` disables
duplicate Endpoint listeners before application startup. Browser trust is a
process-local fixture SPKI pin, with explicit QUIC and IPv4 localhost mappings;
CDP `h3` and unique server request markers qualify the existing page and static
resource. This is ordinary HTTP page acceptance; H3 WebSocket is unsupported.

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
[public Session plan](plans/m4-public-session-upstream.md) is undergoing direct
qualification before Gaoxy integration. The H3 upstream adapter and
H1/H2/H3-to-H3 origin matrix remain unimplemented; full M4 completion and
publication require those remaining gates. Dynamic QPACK, push, extended CONNECT, WebTransport,
DATAGRAM, 0-RTT, migration, mTLS, IPv6/wildcard bindings and graceful H3 GOAWAY
drain remain unsupported. Stop qualifies bounded local host cleanup.
