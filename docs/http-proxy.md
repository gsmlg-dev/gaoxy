# Native HTTP reverse proxy

`Gaoxy.Proxy.HTTP` streams HTTP/1 requests to one configured HTTP or verified
HTTPS authority. It implements the native endpoint contract and can share a
listener with local Plug/Phoenix and WebSocket proxy routes:

This M2 candidate is **not fully accepted**: published HTTP Fetch 0.19.0 drops
a present empty query, so `/upload?` reaches the origin as `/upload`.
[#64](https://github.com/gsmlg-dev/http_fetch/issues/64) blocks that wire-identity
gate; its failing regression remains enabled. No local workaround is applied.

```elixir
{:ok, gateway} = Gaoxy.HTTP.start_link(
  endpoint: {Gaoxy.HTTP.Router, [
    %{path: "/local", target: {Gaoxy.HTTP.PlugEndpoint, {MyPlug, []}}},
    %{path: :any, target: {Gaoxy.Proxy.HTTP, %{
      upstream: "https://origin.example",
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 5_000,
      max_lifetime: 30_000,
      max_chunk_bytes: 65_536
    }}}
  ]},
  limits: %{max_bytes: 134_217_728}
)
```

Start `:gaoxy_proxy` and its dependencies in the owning application. The
[runnable example](../examples/reverse_proxy/README.md) and
[independent peer harness](../integration/reverse_proxy/run.py) exercise this
route table over real sockets.

## Routing and wire policy

The first matching route wins. Local Plug calls execute directly. Upstream
authority, Host and TLS SNI come from configuration; the incoming raw escaped
path and nonempty query are preserved. The empty-query exception above remains
an upstream blocker. Configured
userinfo, path/query, fragment and unknown options are rejected. For a private
CA, use `cacertfile: "/path/to/ca.pem"`. Certificate and hostname verification
remain enabled, with OTP `:ssl` selected explicitly.

Supported methods are GET, HEAD, POST, PUT, PATCH, DELETE and OPTIONS. Supported
origin/absolute targets retain ordinary HTTP semantics; CONNECT and other target
forms receive 501. GET and DELETE entities are forwarded. Redirects are returned
unchanged. There is no automatic retry, replay, protocol or TLS-provider fallback.
Each request owns a new H1 connection; pooling and upstream groups belong to M3.

Ordered duplicate fields survive. Hop-by-hop fields and every Connection-nominated
field are removed. Incoming Forwarded, X-Real-IP and X-Forwarded-* are discarded;
X-Forwarded-For, -Host and -Proto are regenerated from the downstream connection
and parsed request. There is no trusted forwarding-chain configuration. Expect
is handled locally. Transfer framing is regenerated for the downstream hop.
Content-Encoding and compressed payload bytes are preserved without decoding.
The same forwarding distrust policy covers request trailer declarations and
actual trailers, preventing identity fields from being restored after the head.

Declared, permitted trailers retain order and duplicates under the native
trailer count/byte limits. Undeclared or forbidden trailers fail; nominated
hop-by-hop request trailers and declarations are removed. The pinned upstream
parser rejects actual Connection-nominated response trailers before delivery.
Trailer promises incompatible with HTTP/1.0,
HEAD/bodyless or fixed-length responses fail before response commitment.
An error after commitment closes the connection without a successful terminal
chunk or a second response.

## Streaming, deadlines and cleanup

One bounded downstream upload piece waits for local upstream write completion
before the next read. Upstream responses use one acknowledged delivery window;
Gaoxy acknowledges only after the downstream write completes. This is local
transport completion, not peer application receipt. Early final responses stop
upload, return immediately and close a downstream connection with unread input.
SSE events stream before EOF; idle downstream disconnects cancel the upstream.

All limits are positive finite integers, and `max_chunk_bytes` cannot exceed
65,536. The lifetime deadline is the minimum of `max_lifetime` and the native
request's original deadline. Opening, idle and write deadlines do not renew that
lifetime. Long SSE sessions need larger limits in both the endpoint and native
`http_limits.request_timeout`.

A temporary guardian outside the instance's forced-stop subtree monitors the
connection, admission gate, service and instance. Before opening an upstream,
it attaches a capacity reservation to the existing native lease. It owns the
original Fetch Promise and immediately obtains its public RequestCompletion
handle. Normal completion and abort both wait for confirmed request-owned
transport, helper, stream and producer cleanup before the guardian sends an
authenticated receipt and exits normally. Native connection death cannot refund
that reservation. An expired caller deadline returns
`{:error, {:deadline_exceeded, :cleanup_pending}}` while cleanup continues;
unconfirmed cleanup fails the service closed.

## Qualified capacity

The pinned Fetch/Core/Runtime 0.19.0 client uses explicit 8,192-byte receive
buffers, direct H1, no connection reuse, raw response streaming and ACK delivery.
The source-qualified OTP 28.5.0.5 host uses the default `:inet` backend and
`:ssl.internal_active_n` in 1..100. Keep those startup settings stable.
Incompatible host settings are rejected without mutating global configuration.
The [source audit](acceptance/evidence/m2/http-fetch-0.19.0/otp-receive-bound.md)
derives a conservative maximum SSL delivery of 837,637 bytes plus a 65,536-byte
HTTP framing carry.

Each active request reserves eight such receive/carry windows, eight configured
upload windows, and twice the opening field footprint: roughly 8 MiB at the
defaults. Native retained bytes are charged separately. The core's default
1 MiB service budget rejects these proxy sessions; set an explicit budget for
the required concurrency. This is a capacity allowance for retained payloads
and copies. It excludes kernel/OTP internal buffers, process metadata and
arbitrary trusted application allocations; it does not measure total BEAM memory.

HTTP/2, HTTP/3, forward proxy/CONNECT, pools, load balancing, health checks and
configuration reload remain later milestones. Message-level WebSocket forwarding
uses the separate [WebSocket endpoint](websocket-proxy.md).
