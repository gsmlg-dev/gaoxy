# Native HTTP and Phoenix

`gaoxy_http` owns the HTTP/1 parser, opt-in native HTTP/2 engine, Plug adapter and
WebSock connection lifecycle.
Thousand Island and Gaoxy retain socket/listener supervision, admission and
shutdown. No Bandit application is installed or started. Core consumers do not
depend on Plug, WebSock, Phoenix or an upstream HTTP client.

```elixir
{:ok, server} = Gaoxy.HTTP.start_link(plug: {MyPlug, []}, port: 0)
{:ok, {_ip, port}} = Gaoxy.info(server, :http).local
Gaoxy.stop(server)
```

Use `Gaoxy.HTTP.child_spec/1` under a supervisor, or obtain `{:ok, spec}` from
`Gaoxy.HTTP.service_spec/1` and include it among an instance's services. Options
are `:id`, `:ip`, `:port`, `:transport` (`:tcp` or `:tls`), `:tls`, `:limits`,
`:http_limits`, `:protocols`, `:h2c`, `:h2_limits`, and exactly one of `:plug` or
`:endpoint`. HTTP/1 remains the default. TLS uses the existing Gaoxy certificate
policy and advertises the explicitly configured protocols.

## Native HTTP/2

TLS enables H2 with `protocols: [:http2, :http1]` (ALPN `h2`, `http/1.1`) or
`[:http2]`. Cleartext requires `protocols: [:http2], h2c: :prior_knowledge`;
HTTP/1 upgrade to h2c is unsupported. Supply an explicit resource budget:

```elixir
{:ok, server} = Gaoxy.HTTP.start_link(
  plug: {MyPlug, []},
  protocols: [:http2], h2c: :prior_knowledge,
  limits: %{max_bytes: 536_870_912, max_active: 128}
)
```

For embedding in a mixed runtime, construct HTTP specifications with
`Gaoxy.HTTP.service_spec/1`. It validates protocol, host profile and minimum
byte budget before binding. Manually constructed native handler specifications
do not receive that constructor validation; the H2 connection still checks the
host and budget before advertising SETTINGS or starting codec/stream work.

The qualified native H2 host uses OTP 28 with the `:inet` TCP backend. TLS
additionally requires integer `:ssl, :internal_active_n` in `1..100`, TLS 1.3
or the accepted TLS 1.2 forward-secret AEAD suites. Unsupported profiles are
rejected. TI uses active-once delivery with fixed 16 KiB socket buffers; a larger
endpoint body-read credit does not enlarge them.

`h2_limits` defaults are `max_streams: 32`, `max_frame: 16_384`,
`max_header_block: 16_384`, `table_size: 4_096`, `receive_window: 65_535`,
`frame_timeout: 5_000`, `control_turn: 32`, and `control_rate: 256`.
Maximum streams are 128, control frames per parsing turn 128, and control rate
4096 per second. Frame sizes are 16,384–65,535 bytes; header block/table ceilings
are 65,536 bytes. The ingress buffer must hold the maximum frame plus its header.
Positive finite limits and service admission apply independently.

Before decoding, the connection reserves conservative HPACK expansion, fixed
control/state allowance, the initial connection receive window, configurable
carry copies and bounded OTP SSL delivery copies. Stream and writer leases are
additional. Default minimum capacity for one connection, stream and writer is
173,302,823 bytes and three active slots; larger header/table/carry settings
raise it. This bounds the specified retained payload/copy profile, excluding
whole-BEAM heap/GC, kernel/OTP socket memory and trusted endpoint allocations.

Streams have independent workers, deadlines and reset cleanup. Flow control
credits follow body consumption and acknowledged writes. Shared Exchange and
Response operations preserve ordinary responses, informational headers, files,
trailers, HEAD/bodyless semantics and ordered duplicate fields across H1/H2.
Selected independent TCP/TLS, malformed-frame and browser evidence is in
[M3 acceptance](acceptance/m3.md). Server push, H2 WebSocket extended CONNECT,
H2 CONNECT tunnels and H3 are unsupported in this milestone slice.

For Phoenix, configure `adapter: Gaoxy.PhoenixAdapter` with `http: [...]` and/or
`https: [...]`. The Endpoint supervisor owns one Gaoxy instance with one service
per enabled scheme. `MyEndpoint.server_info(:http)` returns its actual address
and port. The HTTPS options accept `:certfile`, `:keyfile`, `:versions` and `:alpn`
alongside `:ip`, `:port`, `:limits`, `:http_limits`, `:protocols`, `:h2c` and
`:h2_limits`. Integer and decimal-string
ports are accepted. Development uses Phoenix's `SyncCodeReloadPlug`; the project
must configure `listeners: [Phoenix.CodeReloader]` as required by Phoenix 1.8.

An Endpoint mounted in a separate gateway must have `server: false` and still
run its ordinary Endpoint supervisor. Mount `{MyEndpoint, []}` as a local Plug.
A conflicting Endpoint listener, including Phoenix's global `serve_endpoints`
setting, is rejected. The adapter's internal `:endpoint_managed` option is
reserved for Endpoint-owned startup. See the runnable
[fixture](../examples/phoenix_native/README.md).

## HTTP profile and limits

The initial profile supports HTTP/1.1 and explicit HTTP/1.0 persistence, raw
origin/absolute/authority/asterisk target parsing, fixed and chunked bodies,
trailers in the endpoint exchange, keep-alive, and ordered pipelining. Ambiguous
framing, duplicate Content-Length, unsupported transfer encodings and malformed
authorities are rejected before dispatch. The original escaped path/query is
preserved. Unread bodies force closure. Ordinary, prepared, chunked, fixed-length
streaming, file, HEAD/bodyless and informational Plug responses are supported.
Protocol push is unsupported. Authenticated H1 CONNECT is available through the
separate [gateway endpoint](gateway.md), with explicit destination policy.

`http_limits` defaults:

| Setting | Default |
|---|---:|
| `max_request_line` | 8,192 bytes |
| `max_header_bytes`, `max_headers` | 32,768 bytes, 100 fields |
| `max_body_bytes` | 8,388,608 bytes |
| `max_chunk_line` | 1,024 bytes |
| `max_trailer_bytes`, `max_trailers` | 8,192 bytes, 32 fields |
| `max_read_chunk`, `max_buffer_bytes` | 16,384 bytes, 65,536 bytes |
| `header_timeout` | 5,000 ms from the first request byte |
| `request_timeout` | 30,000 ms for the whole request/response |
| `read_timeout`, `write_timeout` | 5,000 ms per body-read call / socket write |

Limits are positive finite integers. SSE/long requests need an explicit larger
`request_timeout`. Partial headers and body metadata cannot renew their original
deadline. Slow writes have a finite transport timeout and request watchdog.
`max_header_bytes` also bounds informational and final response heads;
`max_headers` limits parsed request headers.
The service's global active/byte/output limits still apply: configured HTTP
ceilings are not promises of admission under resource pressure. Output iodata
and files are traversed in bounded pieces, without creating a full-body binary.

The ledger charges retained request headers/trailers, parser/body tails, selected
output windows, WebSocket fragments and callback state. Native receive buffers
and decoding have bounded transient copies; kernel/OTP transport buffers and
arbitrary allocations or retained body data inside trusted application code are
outside the ledger. This is not a bound on total BEAM memory. Low global byte
budgets may reject work below a protocol-specific maximum, especially TLS records.

## WebSock

Use `WebSockAdapter.upgrade(conn, MyWebSock, initial_state, options)`. The same
connection process implements callbacks, automatic pong, bounded fragmented
messages, UTF-8 validation, and close handshakes. Handshake response headers,
including a selected offered subprotocol, survive the Plug pipeline. Compression
extensions are not negotiated; `compress: true` and disabling UTF-8 validation
are rejected. The dependency's minimal reviewed dispatch fork has
[commit provenance and a removal plan](../vendor/websock_adapter/GAOXY.md).

Options default to `timeout: 60_000`, `callback_timeout: 5_000`,
`close_timeout: 1_000`, `max_lifetime: 86_400_000`,
`max_frame_size: 262_144`, `max_message_size: 262_144`, `max_fragments: 128`,
`max_mailbox: 128`, and `max_push_frames: 32`. Frame/message ceilings are also
clamped to one quarter of the service byte budget. The service `max_state`
limits callback state. Upgrade establishes one admitted protocol lifetime;
callbacks cannot renew it. Drain uses its existing absolute deadline and sends
1001; a WebSock restart stop sends 1012. Forced watchdog termination cannot run
application cleanup callbacks.

Gaoxy uses active-once transport delivery. Third-party processes can send
arbitrary messages to a WebSock owner; the adapter checks mailbox length and
closes an overloaded connection but cannot promise an absolute bound on such
external traffic. Keep application/PubSub producers bounded.

## Routing and proxy boundary

```elixir
routes = [
  %{host: "example.test", methods: ["GET"], path: {:prefix, "/api"},
    target: {Gaoxy.HTTP.PlugEndpoint, {ApiPlug, []}}},
  %{target: {Gaoxy.HTTP.PlugEndpoint, {WebsitePlug, []}}}
]
{:ok, server} = Gaoxy.HTTP.start_link(endpoint: {Gaoxy.HTTP.Router, routes})
```

Compilation yields an immutable generation. The first declared matching route
wins. Hosts normalize case; methods remain case-sensitive HTTP tokens; paths
match exactly or by complete prefix segments. There is no percent decoding,
forwarding-header trust, or header mutation during selection. Parsing and
authority/framing validation occur first; the selected endpoint then applies
its explicit policy. H1 absolute-target authority must agree with Host.

The endpoint contract also supports [HTTP streaming](http-proxy.md) and
[WebSocket reverse proxying](websocket-proxy.md), without making `gaoxy_http`
depend on `gaoxy_proxy`. HTTP Fetch 0.19.1 confirms request cleanup through its
public completion handle and preserves present empty queries. The historical
raw-target blocker [#64](https://github.com/gsmlg-dev/http_fetch/issues/64) is resolved.
Per-request `stream_response: true` avoids a global streaming threshold.
The native H2 engine belongs to `gaoxy_http`; upstream H2 and connection reuse
remain blocked by the public client contracts described in [M3 acceptance](acceptance/m3.md).

Native endpoints can call `Exchange.read_body_step(exchange, credit, wait_ms)`
with positive credit and finite nonnegative wait. It returns `{:more, bytes, next}`,
`{:ok, bytes, next}`, `{:pending, next}` or `{:error, reason, next}`. Preserve `next`
on every result; waiting does not renew the request deadline. The existing blocking
Plug body reader retains its API. `Exchange.poll_connection(exchange, wait_ms)`
reserves and reads one byte to detect idle closure, retaining any input for the
next body read or pipelined request; it returns `:pending`, `:more` or `:error`
with the next exchange. Native writes obey both the current absolute deadline
and finite write timeout, including each output window of a larger chunk.
`Gaoxy.HTTP.Response.finish(exchange, trailers)`
completes a stream once; nonempty trailers require a validated `Trailer`
declaration, retain ordered duplicates and obey count/byte limits. HTTP/1.0 and
fixed-length responses cannot send trailers. An endpoint error after commitment
closes the connection without a successful terminal chunk or second response.

The optional native WebSock callback `gaoxy_close({code_or_nil, reason}, state)`
returns `{:ok, state}` before the server echoes peer Close. Ordinary WebSock
termination remains `terminate(:remote, state)`. A native callback result
`{:gaoxy_push, messages, {recipient, ref}, state}` delivers
`{:gaoxy_websocket_written, ref, result}` after local writes finish; only `:ok`
permits an upstream delivery acknowledgment. `{nil, ""}` preserves an empty Close.
