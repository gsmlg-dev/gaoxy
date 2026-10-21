# Gaoxy Proxy

`gaoxy_proxy` provides streaming HTTP and WebSocket reverse-proxy endpoints for
Gaoxy's HTTP listeners, plus policy-controlled forward proxy and CONNECT support.

## Install

Add to `mix.exs`, then run `mix deps.get`:

```elixir
defp deps do
  [
    {:gaoxy_proxy, "~> 0.5.3"}
  ]
end
```

Use Elixir 1.18 or newer. Mix starts the proxy application's supervisors and its
dependencies with your application. Core Abyss 0.9.0 excludes its former DHCP
NIF and Rustler build; Gaoxy does not depend on `abyss_raw`.

## Fixed HTTP reverse proxy

With an HTTP origin running at `127.0.0.1:9000`, add this listener to your
application's supervision tree:

```elixir
children = [
  {Gaoxy.HTTP,
   id: :gateway,
   ip: {127, 0, 0, 1},
   port: 4000,
   endpoint: {Gaoxy.Proxy.HTTP, %{upstream: "http://127.0.0.1:9000"}},
   limits: %{max_bytes: 134_217_728}}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Requests to `http://127.0.0.1:4000/` now reach the configured origin. Upstream
authority comes from configuration; the incoming escaped path and query are
preserved. The upstream URL must contain only an HTTP/HTTPS authority: no
userinfo, non-root path, query or fragment. HTTPS verifies the certificate and
hostname; use `cacertfile: "/path/to/ca.pem"` for a private CA.

Uploads and raw responses stream, redirects return to the client, and failed
requests are not automatically retried or replayed. Incoming forwarding headers
are discarded and regenerated from the downstream connection.

The explicit byte budget matters: an HTTP request reserves roughly 8 MiB at the
default limits, plus separately charged native retained bytes. The core default
1 MiB budget rejects these sessions. Choose capacity for your concurrency; this
reservation is not a measurement of total VM or kernel memory.

HTTP endpoint defaults are `opening_timeout: 5_000`, `idle_timeout: 60_000`,
`write_timeout: 5_000`, `max_lifetime: 30_000` and `max_chunk_bytes: 65_536`
(milliseconds for timeouts). Longer streams also need a sufficient listener
`http_limits.request_timeout`.

## Upstream protocol selection

The default is `upstream_protocol: :http1`, with a dedicated connection per
request. Managed H1 reuse and H2/h2c require explicit supervised
`Gaoxy.Proxy.UpstreamTransports` handles; selecting `:http2` or `:h2c` alone is
rejected. See the
[gateway guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/gateway.md)
for managed transports, groups and health probes.

For a fixed H3 origin, explicitly configure
`upstream_protocol: :http3`, an `https://` upstream and an existing
`cacertfile`. H3 uses a dedicated request session and a maximum 16,384-byte
upload chunk. There is no automatic protocol fallback. Downstream protocol
selection is independent: H1/H2 use `Gaoxy.HTTP`; H3 uses the separate
`gaoxy_http3` package and `Gaoxy.HTTP.HTTP3`.

## Optional WebSocket route

Replace the listener's `endpoint` with a first-match router to send `/socket`
and its child paths to a WebSocket origin, with ordinary HTTP sent elsewhere:

```elixir
endpoint: {Gaoxy.HTTP.Router, [
  %{path: {:prefix, "/socket"},
    target: {Gaoxy.Proxy.WebSocket, %{upstream: "ws://127.0.0.1:9001"}}},
  %{path: :any,
    target: {Gaoxy.Proxy.HTTP, %{upstream: "http://127.0.0.1:9000"}}}
]}
```

Keep the explicit service byte budget. A WebSocket session reserves 4 MiB plus
eight message windows and its opening fields. The default message size is
65,536 bytes and the default fragment limit is 128. The configured `ws`/`wss`
authority follows the same URL restrictions; `wss` verifies the peer, with an
optional `cacertfile` for private CAs. Paths, queries and offered subprotocols
are preserved; ping/pong run separately on each hop. Upstream WebSockets use
HTTP/1 upgrades. Compression, redirects and automatic replay are disabled.

## Forward proxy and CONNECT

`Gaoxy.Proxy.ForwardHTTP` requires explicit authentication and destination
policy, including address validation when resolving and connecting. Configure
those policies before exposing a forward listener. CONNECT opens a raw tunnel;
it is separate from the fixed reverse-proxy endpoints above. See the
[gateway guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/gateway.md)
for the policy interfaces and authenticated examples.

See the [HTTP proxy guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/http-proxy.md)
and [WebSocket proxy guide](https://github.com/gsmlg-dev/gaoxy/blob/main/docs/websocket-proxy.md)
for forwarding semantics, resource limits and lifecycle details.
