# Gaoxy standalone server

`gaoxy_server` runs Gaoxy services from a version-1 JSON configuration. It is
the application behind the standalone `gaoxy` release, with allowlisted echo,
HTTP and HTTP/3 handlers, static responses and fixed reverse-proxy routes.

Use this application when you want a server configured by data. For a Phoenix
application, install `gaoxy_http` instead and follow the
[Phoenix and Bandit migration guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/phoenix.md).
`gaoxy_server` is built from this repository and is not published to Hex.

## Build and run

From the repository root, with Elixir 1.18+, Rust/Cargo and a native compiler
toolchain installed:

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
exist before validation/startup. TCP H2 is prior-knowledge h2c: use
`"protocols": ["http2"]` with `"h2c": "prior_knowledge"`. It uses a dedicated
listener, without HTTP/1 Upgrade or mixed cleartext detection.

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
`static` and `reverse_proxy` are the registered target types. Fixed reverse
proxies use upstream HTTP/1 by default. Upstream HTTP/3 additionally requires
`"upstream_protocol": "http3"`, an HTTPS `upstream` and a `cacertfile` for
certificate verification.

Standalone JSON exposes neither arbitrary Plug/Phoenix modules nor WebSocket
activation, managed upstream groups, forward/CONNECT policies or stream/UDP
relay endpoints. Those services use the embedded Elixir APIs.

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
Listener, address and TLS changes require a restart. This API provides no
public management listener.

Configuration files must be regular files no larger than 1 MiB. Unknown keys,
unregistered targets and invalid protocols are rejected; configuration does
not evaluate code or create atoms from input.

## Further reading

- [Gateway and route generations](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/gateway.md)
- [Mixed transport example](https://github.com/gsmlg-dev/gaoxy/blob/main/examples/mixed_transports/README.md)
- [HTTP package](https://github.com/gsmlg-dev/gaoxy/blob/main/apps/gaoxy_http/README.md)
- [Proxy package](https://github.com/gsmlg-dev/gaoxy/blob/main/apps/gaoxy_proxy/README.md)

MIT.
