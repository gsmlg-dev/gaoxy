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

Accepted embedded source implements managed H1 reuse, managed H2/h2c fixed/group upstreams, probes and Generation/resource ownership through public HTTPFetch 0.21.10 APIs. Managed H2/h2c requires explicit transport handles. Standalone JSON origins remain `http1` (default) or `http3`; JSON exposes no managed handles/groups/probes or WebSocket activation. JSON downstream HTTP services default to H1 and permit explicit H2/h2c or a separate H3 service. Native downstream WebSocket support does not add upstream H2/H3 WebSocket proxy transports.

Published [v0.4.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.4.0) from `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Fresh ordinary portable verification: **200 executed / 0 failures / 90 excluded**; packaged H2/h2c/H3 WebSocket **15/15 each** in builder and offline runtime. All **21 ELF objects** passed dependency checks; three freshly downloaded assets match the qualified bytes and hashes. [Release acceptance](acceptance/release-0.4.0.md) records source, artifact and publication evidence. New hosted CI remains NOT RUN.

Earlier snapshots retain their capture-time scope and actual failed, blocked and unexecuted results. Specialist qualification remains with its dedicated environment; deployment and production acceptance remain NOT RUN.

# Native HTTP reverse proxy

`Gaoxy.Proxy.HTTP` streams native HTTP/1 or HTTP/2 requests to one configured HTTP or verified
HTTPS authority. It implements the native endpoint contract and can share a
listener with local Plug/Phoenix and WebSocket proxy routes:

The selected HTTP Fetch 0.19.1 preserves present empty queries: `/upload?`
reaches the origin unchanged. The historical
[#64](https://github.com/gsmlg-dev/http_fetch/issues/64) blocker is resolved;
its regression and the public Fetch probe now pass without a local workaround.
See [M2 acceptance](acceptance/m2.md) and [the M3 record](acceptance/m3.md) for
their scoped local verdicts.

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
path and query, including a present empty query, are preserved. Configured
userinfo, path/query, fragment and unknown options are rejected. For a private
CA, use `cacertfile: "/path/to/ca.pem"`. Certificate and hostname verification
remain enabled, with OTP `:ssl` selected explicitly.

Supported methods are GET, HEAD, POST, PUT, PATCH, DELETE and OPTIONS. Supported
origin/absolute targets retain ordinary HTTP semantics; CONNECT and other target
forms receive 501. GET and DELETE entities are forwarded. Redirects are returned
unchanged. There is no automatic retry, replay, protocol or TLS-provider fallback.
Each request owns a new H1 connection. M3 adds supervised upstream groups,
health probes and generation-pinned selection through `Gaoxy.Proxy.GroupEndpoint`;
see [the gateway guide](gateway.md). Groups do not imply connection reuse.
Installed HTTP Fetch0.21 provides public request cleanup, upload trailers and
managed scope retirement. Reusable H1 and upstream H2 remain disabled pending
[managed qualification](plans/m3-upstream-transport.md): complete H1 accounting
and runtime gates, and the H2 header/control bound in
[#86](https://github.com/gsmlg-dev/http_fetch/issues/86).

Ordered duplicate fields survive. Hop-by-hop fields and every Connection-nominated
field are removed. Incoming Forwarded, X-Real-IP and X-Forwarded-* are discarded;
X-Forwarded-For, -Host and -Proto are regenerated from the downstream connection
and parsed request. There is no trusted forwarding-chain configuration. Expect
is handled locally. Transfer framing is regenerated for the downstream hop.
For H2/H3 requests, split Cookie values are combined in encounter order with
`; ` before the upstream serializer. H1 request duplicates keep their existing
behavior; unrelated repeated fields and response Set-Cookie remain separate.
Input preflight and final transformed header count/byte limits both apply.
Content-Encoding and compressed payload bytes are preserved without decoding.
A 304 response preserves a supplied representation Content-Length without sending
a body or adding a length when the upstream omitted it.
The same forwarding distrust policy covers request trailer declarations and
actual trailers, preventing identity fields from being restored after the head.

Declared, permitted trailers retain order and duplicates under the native
trailer count/byte limits. Undeclared or forbidden trailers fail; nominated
hop-by-hop request trailers and declarations are removed. The pinned upstream
parser rejects actual Connection-nominated response trailers before delivery.
Trailer promises incompatible with HTTP/1.0 or HEAD/bodyless responses fail
before commitment. H1 trailers require chunked framing; H2 trailers use a
terminal header block. Proxy responses that declare trailers together with
Content-Length are currently rejected before commitment for H1, H2 and H3
downstreams, even when that combination could be represented by the downstream
protocol. This patch preserves that restriction.
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

The pinned Fetch/Core/Runtime 0.19.1 client uses explicit 8,192-byte receive
buffers, direct H1, no connection reuse, raw response streaming and ACK delivery.
The source-qualified OTP 28.5.0.5 host uses the default `:inet` backend and
`:ssl.internal_active_n` in 1..100. Keep those startup settings stable.
Incompatible host settings are rejected without mutating global configuration.
The [OTP source audit](acceptance/evidence/m2/http-fetch-0.19.0/otp-receive-bound.md),
with the [0.19.1 contract comparison](acceptance/evidence/m2/http-fetch-0.19.1/contract-diff.md),
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
