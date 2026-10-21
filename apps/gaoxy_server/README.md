# Gaoxy standalone server

`gaoxy_server` runs Gaoxy services from a version-1 JSON configuration. It is
the application behind the standalone `gaoxy` release, with allowlisted echo,
HTTP/HTTP3 and relay handlers, static responses, HTTP/WebSocket reverse proxies,
and managed upstream groups with health probes.

Use this application when you want a server configured by data. For a Phoenix
application, install `gaoxy_http` instead and follow the
[Phoenix and Bandit migration guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md).
`gaoxy_server` is built from this repository and is not published to Hex.

## Build and run

From the repository root, with Elixir 1.18+ and Erlang/OTP crypto and public-key
support installed:

```sh
mix deps.get --check-locked
MIX_ENV=prod mix release gaoxy
```

The repository's `nix develop` shell provides the build tools. Alternatively,
use a platform-compatible standalone artifact from the
[GitHub releases](https://github.com/gsmlg-dev/gaoxy/releases).

Create `config.json`:

```json
{
  "version": 1,
  "services": [{
    "id": "web",
    "handler": "http",
    "transport": "tcp",
    "ip": "127.0.0.1",
    "port": 4000,
    "limits": {"max_bytes": 8388608},
    "routes": {
      "version": 1,
      "routes": [{
        "path": "/",
        "target": {"type": "static", "status": 200, "body": "Hello from Gaoxy"}
      }]
    }
  }]
}
```

Validate without opening a listener, then start the release:

```sh
mix gaoxy.validate config.json
GAOXY_CONFIG="$PWD/config.json" _build/prod/rel/gaoxy/bin/gaoxy start
```

In another terminal, run `curl http://127.0.0.1:4000/`. Startup prints
`GAOXY_READY` with actual bound addresses and ports. A configured `port: 0`
selects an available port. Set `GAOXY_READY_FILE` to also write the readiness
JSON to a local file. Without `GAOXY_CONFIG`, the application starts without
service listeners.

## Service configuration

Every service has an `id`, `transport` and allowlisted `handler`. Common
settings include `ip`, `port`, `limits` and `tls`. IPs are address strings;
`ip` defaults to `127.0.0.1` and `port` to zero. Use a deliberate interface
address when exposing a service outside the local host.

| Handler | Transport | Purpose |
| --- | --- | --- |
| `stream_echo` | `tcp` or `tls` | Echo an ordered byte stream |
| `datagram_echo` | `udp` | Echo complete datagrams |
| `http` | `tcp` or `tls` | Native HTTP routes |
| `http3` | `quic` | Native HTTP/3 routes with certificates |
| `stream_relay` | `tcp` or `tls` | Bounded relay to a fixed numeric TCP/TLS destination |
| `udp_relay` | `udp` | Unicast associations with explicit ingress/destination policy |

For example, add a UDP service beside the HTTP service:

```json
{
  "id": "udp-echo",
  "handler": "datagram_echo",
  "transport": "udp",
  "ip": "127.0.0.1",
  "port": 4001,
  "limits": {"max_active": 128, "max_packet": 8192}
}
```

`limits` sets finite service budgets such as `max_active`, `max_bytes`,
`max_output`, `max_state`, `callback_timeout`, `idle_timeout` and
`drain_timeout`. HTTP also accepts `http_limits` and `h2_limits`; HTTP/3
accepts `http_limits` and `h3_limits`. Their values are JSON objects with
allowlisted keys. Keep enough byte budget for protocol buffers and immutable
route snapshots; undersized configurations fail validation.

## TLS and HTTP protocols

Standalone `http` services default to `protocols: ["http1"]`, including over
TLS. For HTTPS with H2 and H1 fallback, set:

```json
{
  "transport": "tls",
  "protocols": ["http2", "http1"],
  "tls": {
    "certfile": "/absolute/path/to/cert.pem",
    "keyfile": "/absolute/path/to/key.pem"
  },
  "limits": {"max_bytes": 268435456}
}
```

These are replacement fields for the `web` service above. Certificates must
exist before validation/startup. For H1 and prior-knowledge H2 on the same
cleartext listener, replace those service fields with:

```json
{
  "transport": "tcp",
  "protocols": ["http2", "http1"],
  "h2c": "prior_knowledge"
}
```

Routes and the native handler are shared on that one listener. To retain a
dedicated H2-only listener, use `"protocols": ["http2"]` with the same explicit
prior-knowledge setting. Plain TCP defaults to H1-only and h2c disabled.
HTTP/1 `Upgrade: h2c` is unsupported; prior-knowledge clients send the full H2
preface directly. There is no `"auto"` setting.

Mixed detection keeps the existing idle timeout before first input. Its fixed
deadline starts at the first byte and uses the minimum of
`http_limits.header_timeout`, `http_limits.request_timeout`, and
`h2_limits.frame_timeout`. More prefix bytes never extend it. The first H1
header/request budgets and H2 startup allowance retain that original time;
H2 startup requires acknowledgment of server SETTINGS, with its separate
partial-frame timer preserved.

HTTP/3 uses a separate `handler: "http3"`, `transport: "quic"`,
`protocols: ["http3"]` service. See the
[HTTP/3 standalone example](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/http3.md#standalone-data-configuration)
for the complete certificate and resource configuration.

## Reverse-proxy routes

Replace the `routes.routes` list with a fixed upstream route:

```json
[
  {
    "prefix": "/",
    "target": {
      "type": "reverse_proxy",
      "upstream": "http://127.0.0.1:8080"
    }
  }
]
```

Routes can match `host`, `methods` and either exact `path` or `prefix`.
`static`, `reverse_proxy`, `websocket` and `upstream_group` are the registered
target types. Fixed reverse proxies use a dedicated upstream HTTP/1 connection
by default. Upstream HTTP/3 additionally requires
`"upstream_protocol": "http3"`, an HTTPS `upstream` and a `cacertfile` for
certificate verification.

### Managed fixed upstreams

Use `"managed": true` for reusable H1 upstreams. The `http2` and `h2c` selections
also use managed transports. Downstream protocol selection is independent.

| `upstream_protocol` | Origin | Trust |
| --- | --- | --- |
| `http1` with `managed: true` | `http://` or `https://` | HTTPS requires a CA PEM file |
| `h2c` | `http://` | Cleartext prior-knowledge H2; omit `cacertfile` |
| `http2` | `https://` | Verified TLS H2; requires a CA PEM file |

For example, this route pins a named TLS origin to an explicit connection IP:

```json
{
  "prefix": "/",
  "target": {
    "type": "reverse_proxy",
    "managed": true,
    "upstream_protocol": "http2",
    "upstream": "https://api.internal:8443",
    "connect_address": "10.0.0.20",
    "cacertfile": "/absolute/path/to/upstream-ca.pem",
    "max_chunk_bytes": 16384,
    "opening_timeout": 2000,
    "idle_timeout": 10000,
    "write_timeout": 2000,
    "max_lifetime": 30000
  }
}
```

Named managed origins require a numeric `connect_address`; numeric origins can
infer it from the URL. The origin hostname remains the HTTP authority and TLS
certificate identity. For managed HTTPS, `cacertfile` must be a regular PEM file
containing CA certificates, read during configuration preparation. Cleartext
managed origins require no trust file. There is no unverified TLS mode.

For h2c, change the origin to `http://api.internal:8080`, select `"h2c"`, and
remove `cacertfile`. For reusable H1, select `"http1"` and keep `managed: true`.
Omitting managed H1 selection retains the existing dedicated H1 behavior;
`http3` retains its existing dedicated configuration path.

### Upstream groups and health probes

Groups are inline route targets. All members must use the same upstream
protocol (`http1`, `http2` or `h2c`); each member is managed and has a unique ID.
This example uses two h2c origins with bounded group and member concurrency:

```json
{
  "prefix": "/",
  "target": {
    "type": "upstream_group",
    "id": "api",
    "max_inflight": 8,
    "opening_timeout": 2000,
    "max_lifetime": 30000,
    "health": {
      "path": "/health",
      "interval": 1000,
      "timeout": 500,
      "stale_after": 5000,
      "failure_threshold": 3,
      "recovery_threshold": 2,
      "jitter": 100
    },
    "members": [
      {"id": "one", "upstream": "http://api-one.internal:8080", "connect_address": "10.0.0.21", "upstream_protocol": "h2c", "max_inflight": 4},
      {"id": "two", "upstream": "http://api-two.internal:8080", "connect_address": "10.0.0.22", "upstream_protocol": "h2c", "max_inflight": 4}
    ]
  }
}
```

Health settings have finite defaults when omitted. Probes and request outcomes
update the existing runtime health policy. A group accepts at most 32 members;
group/member `max_inflight` values are integers from 1 to 1024. TLS group members
use the same explicit address and CA PEM rules as fixed managed upstreams.

### WebSocket routes

Route HTTP/1.1 upgrades to a fixed `ws` or verified `wss` origin:

```json
{
  "path": "/ws",
  "target": {
    "type": "websocket",
    "upstream": "ws://127.0.0.1:9001",
    "max_message_bytes": 65536,
    "max_fragments": 128,
    "opening_timeout": 2000,
    "idle_timeout": 60000,
    "write_timeout": 2000,
    "close_timeout": 1000,
    "max_lifetime": 300000
  }
}
```

`cacertfile` can supply custom CA trust for `wss`. Each session reserves 4 MiB
plus eight message windows and request fields before dialing upstream; size the
service byte budget accordingly. This target rejects ordinary HTTP and H2/H3
WebSocket CONNECT requests with 400. It provides HTTP/1.1 WebSocket proxying.

## TCP/TLS and UDP relays

Relay services use `handler_options` instead of routes. Add this service object
to the top-level `services` list for fixed TCP forwarding:

```json
{
  "id": "tcp-relay",
  "handler": "stream_relay",
  "transport": "tcp",
  "ip": "127.0.0.1",
  "port": 5000,
  "limits": {"max_bytes": 16777216},
  "handler_options": {
    "upstream": {"address": "127.0.0.1", "port": 9000},
    "mode": "tcp",
    "max_chunk_bytes": 16384,
    "connect_timeout": 2000,
    "idle_timeout": 30000,
    "write_timeout": 2000,
    "max_lifetime": 300000
  }
}
```

Stream modes are `tcp`, `tls_termination`, `tls_upstream` and `tls_passthrough`.
For termination, use `transport: "tls"`, service-level `tls.certfile`/`tls.keyfile`
and `mode: "tls_termination"`; the upstream remains TCP. For verified upstream
TLS, retain a TCP listener, select `mode: "tls_upstream"`, and add
`"upstream_tls": {"server_name": "upstream.internal", "cacertfile": "/absolute/path/to/ca.pem"}`
inside `handler_options`. Passthrough uses a TCP listener and forwards opaque
bytes. Destinations are literal IPv4/IPv6 addresses, without DNS or SNI routing.

UDP relays require both ingress CIDRs and destination policy:

```json
{
  "id": "udp-relay",
  "handler": "udp_relay",
  "transport": "udp",
  "ip": "127.0.0.1",
  "port": 5001,
  "limits": {"max_bytes": 4194304},
  "handler_options": {
    "upstream": {"address": "127.0.0.1", "port": 9002},
    "ingress": ["127.0.0.0/8"],
    "destination": {"allow": ["127.0.0.1/32"], "allow_reserved": true},
    "limits": {
      "max_associations": 16,
      "queue_items": 8,
      "queue_bytes": 65536,
      "max_packet": 8192,
      "idle_timeout": 30000,
      "lifetime": 300000,
      "rate_packets": 64,
      "rate_bytes": 65536,
      "packet_ratio": 1,
      "byte_ratio": 1
    }
  }
}
```

The destination must match an allow CIDR and no deny CIDR. Reserved destinations
require `allow_reserved: true` and narrowly scoped allow ranges. The bind must be
a concrete unicast address in the upstream's address family. Ingress CIDRs
restrict sources; UDP does not authenticate senders. Queue, rate and reply-ratio
limits remain enforced by the existing relay runtime.

Standalone JSON does not accept arbitrary Plug/Phoenix modules or forward-proxy
authentication/CONNECT policy definitions; those use the embedded APIs.

## Reload routes locally

Create a separate `routes.json` containing the route object only:

```json
{
  "version": 1,
  "routes": [{"target": {"type": "static", "body": "Updated response"}}]
}
```

Call the local API in the running release:

```sh
_build/prod/rel/gaoxy/bin/gaoxy rpc \
  'Gaoxy.Server.reload_routes("web", "/absolute/path/to/routes.json", 5000)'
```

Reload validates a complete candidate before activation. In-flight requests
retain their selected routes, and invalid input preserves the active routes.
Managed transport/group resources are prepared before the candidate activates;
their generation pins remain attached to in-flight requests during retirement.
Inline upstream addresses, trust and health policy can change through route
reload. Relay services, listener/address/TLS settings and service limits require
a restart. This API provides no public management listener.

Internal managed-owner/runtime recovery preserves the latest successfully
accepted declarative routes, including route reloads, and reconstructs fresh
instance-local upstream handles before restoring listeners. Obsolete owner
incarnations cannot leave generation pins blocking later reloads. Transport
custodians retain their independent cleanup duties, and cleanup failures from
live owners remain visible and retryable.

Configuration files must be regular files no larger than 1 MiB. Unknown keys,
unregistered targets and invalid protocols are rejected; configuration does
not evaluate code or create atoms from input.

## Further reading

- [Gateway and route generations](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/gateway.md)
- [Mixed transport example](https://github.com/gsmlg-dev/gaoxy/blob/main/examples/mixed_transports/README.md)
- [HTTP package](https://github.com/gsmlg-dev/gaoxy/blob/main/apps/gaoxy_http/README.md)
- [Proxy package](https://github.com/gsmlg-dev/gaoxy/blob/main/apps/gaoxy_proxy/README.md)

MIT.
