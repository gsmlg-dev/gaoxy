# Native WebSocket reverse proxy

`Gaoxy.Proxy.WebSocket` is an HTTP endpoint for one configured upstream authority.
Incoming proxy upgrades use HTTP/1.1 and the configured upstream uses H1 `ws`
or verified `wss`. Unsupported H2/H3 requests, including valid opt-in extended
CONNECT, receive an empty protocol-valid 400 before an upstream session or
connection is created. This endpoint does not implement an H2/H3-to-H1 bridge.
Native local WebSock/Phoenix endpoints separately support H2/H3 extended CONNECT
with explicit listener opt-in; see [native HTTP](native-http.md).

It can share a native listener with local Plug/Phoenix routes:

```elixir
{:ok, instance} = Gaoxy.HTTP.start_link(
  endpoint: {Gaoxy.HTTP.Router, [
    %{path: {:prefix, "/socket"}, target: {Gaoxy.Proxy.WebSocket, %{
      upstream: "wss://upstream.example:443",
      max_message_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 5_000,
      close_timeout: 1_000,
      max_lifetime: 86_400_000
    }}},
    %{path: :any, target: {Gaoxy.HTTP.PlugEndpoint, {MyApp.Router, []}}}
  ]},
  limits: %{max_bytes: 16_777_216}
)
```

The owning application must start `:gaoxy_proxy` and its dependencies. The endpoint
accepts only `ws://authority` or `wss://authority`; userinfo, configured path/query,
fragments and unknown options are rejected. Incoming raw paths/queries, including
a present empty query, are preserved. Authority and TLS SNI come from configuration.
For a private CA, set `cacertfile: "/path/to/ca.pem"`; peer certificate and hostname
verification remain enabled. No option disables verification or selects fallback.

Ordered duplicate request fields survive after removing hop-by-hop fields,
`Proxy-Connection`, every Connection nomination, and untrusted forwarding fields.
The proxy regenerates Host and the upgrade handshake. It derives X-Forwarded-For,
-Host and -Proto from the downstream connection/request; there is no trusted-proxy
chain configuration. Offered subprotocols are sent upstream and only the negotiated
protocol is returned downstream. Upstream opening must succeed before downstream
101. Opening failures return 502/504; reservation/admission failure returns 503.

Text and binary messages use a finite window in each direction. Upstream delivery
is acknowledged only after the native downstream write completes. Downstream input
waits for its upstream send acknowledgment before admitting another message or Close.
This means local transport completion, not peer application receipt. No uncertain
write is replayed. Fragmented data is reassembled; exact fragment boundaries are not
preserved. Ping/Pong run independently on each hop. Compression is not negotiated.
Valid and empty Close details are preserved; abnormal/non-wire codes use a valid
1011 failure Close instead of emitting reserved codes on the wire.

The default message limit is 65,536 bytes and fragment limit is 128. All configured
limits/timeouts must be positive finite integers. Each upstream client has one
acknowledged delivery window and one pending application send. Native framing,
callback and mailbox limits also apply.

Before connecting, a session reserves 4 MiB plus eight maximum message windows and
twice its opening field footprint against the service byte limit. The conservative
fixed allowance covers the pinned 0.19.1 client's bounded raw receive queue, opening
headers and copies; update this audit when changing the client. Native retained
bytes are charged separately. Omitted service caps use adaptive shared memory
admission. An explicit `max_bytes` remains a hard transport/cleanup cap and must
cover the desired concurrency; explicit `max_active` still caps ordinary leases.
See the [resource budget guide](resource-budget.md) for shared policy and quotas.
Reservations are capacities, not measurements of actual memory; the ledger
excludes kernel/OTP socket buffers, process metadata and arbitrary trusted
application allocations.

A temporary guardian under the proxy application's session supervisor monitors the
connection, admission gate, service and instance. Admission attaches it to the
existing lease, without consuming a second active slot. Native byte updates and
connection death cannot release its reservation. It requests upstream cancellation
and waits for the documented public WebSocket PID's DOWN before sending an
authenticated cleanup receipt and exiting normally. Service shutdown requires both
receipt and guardian DOWN. An expired caller deadline returns
`{:error, {:deadline_exceeded, :cleanup_pending}}`; cleanup continues independently.
Unexpected guardian death fails the service closed.

Ordinary HTTP request/response bodies and SSE use the separate
[HTTP endpoint](http-proxy.md); CONNECT remains outside M2. HTTP Fetch 0.19.1
includes the request-cleanup contract introduced by #60 and resolves the former
HTTP empty-query blocker [#64](https://github.com/gsmlg-dev/http_fetch/issues/64). WebSocket wire/TLS/lifecycle
evidence is recorded separately in [M2 acceptance](acceptance/m2.md).
