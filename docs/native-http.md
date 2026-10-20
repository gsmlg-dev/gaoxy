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

Current source uses Hell for TCP/OTP TLS after the v0.4.0 release. The published
v0.4.0 source and binaries retain Thousand Island; the release evidence below
keeps that identity. See the [current dependency audit](dependency-audit.md).

## v0.4.0 release status — 2026-10-19

Embedded HTTP/Phoenix HTTPS defaults to H2-first ALPN with H1 negotiation/no-ALPN fallback. Plain TCP defaults to H1; cleartext H2 requires explicit `protocols: [:http2], h2c: :prior_knowledge`, without HTTP/1 Upgrade or mixed detection. Native H2/H3 WebSocket requires listener `extended_connect` opt-in, plus exact `websocket_paths` for Phoenix. External Phoenix H3 uses a separate optional service with `server: false`. Standalone JSON defaults HTTP services to H1 and accepts explicit H2/h2c or a separate H3 HTTP service, but cannot activate WebSocket endpoints. Clients select the actual WebSocket transport; an H2 page alone does not establish H2 WebSocket negotiation.

Published [v0.4.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.4.0) from `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Fresh ordinary portable verification: **200 executed / 0 failures / 90 excluded**; packaged H2/h2c/H3 WebSocket **15/15 each** in builder and offline runtime. All **21 ELF objects** passed dependency checks; three freshly downloaded assets match the qualified bytes and hashes. [Release acceptance](acceptance/release-0.4.0.md) records source, artifact and publication evidence. New hosted CI remains NOT RUN.

Earlier snapshots retain their capture-time scope and actual failed, blocked and unexecuted results. Specialist qualification remains with its dedicated environment; deployment and production acceptance remain NOT RUN.

# Native HTTP and Phoenix

`gaoxy_http` owns the HTTP/1 parser, native HTTP/2 engine, Plug adapter and
WebSock connection lifecycle.
Hell and Gaoxy retain socket/listener supervision, admission and
shutdown. M5 is **COMPLETE LOCALLY within its ordinary verification scope**;
the authoritative [M5 acceptance record](acceptance/m5-websocket-over-h2-h3.md)
records G0–G5 runtime results and the final independent closeout review.
No Bandit application is installed or started. Core consumers do not
depend on Plug, WebSock, Phoenix or an upstream HTTP client.

```elixir
{:ok, server} = Gaoxy.HTTP.start_link(plug: {MyPlug, []}, port: 0)
{:ok, {_ip, port}} = Gaoxy.info(server, :http).local
Gaoxy.stop(server)
```

Use `Gaoxy.HTTP.child_spec/1` under a supervisor, or obtain `{:ok, spec}` from
`Gaoxy.HTTP.service_spec/1` and include it among an instance's services. Options
are `:id`, `:ip`, `:port`, `:transport` (`:tcp` or `:tls`), `:tls`, `:limits`,
`:http_limits`, `:protocols`, `:h2c`, `:h2_limits`, `:extended_connect`, and exactly
one of `:plug` or `:endpoint`. Embedded HTTPS defaults to
`protocols: [:http2, :http1]` with ordered ALPN `h2`, `http/1.1`, retaining H1
negotiation and no-ALPN fallback. Plain TCP defaults to H1. Explicit
`protocols: [:http1]` retains H1-only HTTPS. TLS certificate/security checks
remain in force. Standalone JSON keeps its explicit H1 selection.

## Native HTTP/2

TLS prefers H2 by default; select `protocols: [:http2]` for H2-only TLS.
Cleartext requires `protocols: [:http2], h2c: :prior_knowledge`; HTTP/1 upgrade
and mixed-cleartext detection are unsupported. The HTTP facade supplies
`limits.max_bytes: 268_435_456` (256 MiB) when H2 is selected and that field is
omitted. Explicit budgets remain unchanged and must cover the reservation
profile. An explicit configuration can use:

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
rejected. Hell uses active-once delivery with fixed 16 KiB socket buffers; a larger
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
[M3 acceptance](acceptance/m3.md). Native downstream H2 WebSocket extended
CONNECT is implemented with independent ordinary H2/h2c peer gates in
[M5 acceptance](acceptance/m5-websocket-over-h2-h3.md). Server push and generic
H2 CONNECT tunnels remain unsupported; optional H3 uses its
[separate service](http3.md).

For Phoenix, configure `adapter: Gaoxy.PhoenixAdapter` with `http: [...]` and/or
`https: [...]`. The Endpoint supervisor owns one Gaoxy instance with one service
per enabled scheme. `MyEndpoint.server_info(:http)` returns its actual address
and port. The HTTPS options accept `:certfile`, `:keyfile`, `:versions` and `:alpn`
alongside `:ip`, `:port`, `:limits`, `:http_limits`, `:protocols`, `:h2c`,
`:h2_limits` and `:extended_connect`. Omitted HTTPS protocols use the HTTP
facade defaults. Integer and decimal-string
ports are accepted. Development uses Phoenix's `SyncCodeReloadPlug`; the project
must configure `listeners: [Phoenix.CodeReloader]` as required by Phoenix 1.8.

An Endpoint mounted in a separate gateway must have `server: false` and still
run its ordinary Endpoint supervisor. Mount `{MyEndpoint, []}` as a local Plug.
A conflicting Endpoint listener, including Phoenix's global `serve_endpoints`
setting, is rejected. The adapter's internal `:endpoint_managed` option is
reserved for Endpoint-owned startup. See the runnable
[fixture](../examples/phoenix_native/README.md).

## Plug request-body reads

`Plug.Conn.read_body/2` aggregates native pieces into one logical result.
`:length` defaults to 8,000,000 bytes per Plug call; `:read_length` defaults to
1,000,000 bytes of demand per native read, capped by `max_read_chunk` and the
remaining logical allowance. Native Exchange callers still receive bounded
pieces. `max_body_bytes` independently limits the cumulative whole request;
calling Plug repeatedly cannot reset it. Plug parser length limits still apply.

`:ok` means native completion is known. Reaching the logical allowance while
completion is unknown returns `:more` with the current Exchange. For example,
an exact chunked-data boundary can require another call to consume terminal
framing and trailers. The reader does not consume an extra body byte to prove
completion or consume a following H1 request. Pending waits and errors retain
existing status mapping; a zero-progress result fails without a busy loop.

Plug's `:read_timeout` defaults to 15,000 ms per underlying socket read. The
server's explicit `http_limits.read_timeout` (5,000 ms by default) caps each
wait, and the original absolute request deadline caps the whole operation.
Progress never resets that deadline. Read-triggered `100 Continue` output
also respects that deadline and the configured write chunk cap, and a failed
Continue is never replayed. This is separate from the native API's finite
per-step wait.

Admission reserves accumulated detached chunks and the temporary final binary
copy before allocation. On completion, ownership transfers to Plug/application
code and the adapter reservation is released; native buffer/header/trailer
retention remains charged. Failures drop accumulator ownership and restore the
native reservation. If the gate cannot acknowledge before the deadline, ordered
cleanup restores that reservation when the gate resumes or lease cleanup ends
ownership.
The service byte budget must cover the aggregate and its copy; a native piece
cap alone does not bound a Plug result. Application-owned request bodies remain
outside the native retained-payload ledger after transfer.

## Native H2/H3 WebSocket and Phoenix opt-in

`extended_connect: false` is the listener default, independent of H2 protocol
selection. Set `extended_connect: true` explicitly for each H2 or H3 listener
serving WebSock streams. This enables RFC 8441/9220 downstream WebSocket only;
it does not enable generic tunnels or H2/H3 WebSocket proxy bridges. Native local
WebSock endpoints support H1/H2/H3. `Gaoxy.Proxy.WebSocket` accepts H1 upgrades
and returns a protocol-valid empty 400 for H2/H3 before creating an upstream
session. Standalone JSON can activate this existing H1 proxy endpoint; see the
[standalone guide](../apps/gaoxy_server/README.md).

For managed Phoenix, configure Endpoint-level exact paths and listener opt-in:

```elixir
config :my_app, MyApp.Endpoint,
  adapter: Gaoxy.PhoenixAdapter,
  websocket_paths: ["/live/websocket", "/socket/websocket"],
  https: [port: 443, certfile: "/path/to/cert.pem", keyfile: "/path/to/key.pem",
          extended_connect: true]
```

`websocket_paths` defaults to `[]`; entries must match real Endpoint socket
routes, with no wildcard, query or fragment. `Gaoxy.PhoenixWebSocket` presents
GET only during the Endpoint call for a validated, enabled native H2/H3
WebSocket CONNECT on a listed path, then restores the Conn method. The immutable
native Exchange keeps CONNECT, actual version and `protocol: "websocket"`.
Unlisted paths and ordinary requests retain their methods. Phoenix Origin,
session, CSRF, authentication and subprotocol policies, early WebSockAdapter
validation, and development code-reload composition remain in force.

External mounts use `plug: {Gaoxy.PhoenixWebSocket, {MyApp.Endpoint, paths}}`
with the Endpoint's ordinary supervisor running and `server: false`.
Duplicate-listener validation still applies through the wrapper. H3 requires
its separate optional service and its own `extended_connect: true` opt-in;
see [H3 usage](http3.md). Ordinary H2, H3 and H1 Phoenix browser profiles each
passed 12/12 checks, including Channels/PubSub, LiveView click/upload and normal
Close. Successful H2/H3 sockets have marker-correlated native CONNECT/version/
stream receipts. Browser profiles use ordinary HTTPS navigation to complete
startup trust preparation before the application flow. The client chooses each
WebSocket transport: an H2 page does not guarantee H2 WebSockets, including after
future certificate updates. H3 used a controlled QUIC-first fixture; this does not qualify
automatic H3 selection when TCP is available. Its rejected-Origin check used H1
TLS and is not an H3-specific rejection claim. Exact evidence and the final
independent closeout review are recorded in
[M5 acceptance](acceptance/m5-websocket-over-h2-h3.md).

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

Use `WebSockAdapter.upgrade(conn, MyWebSock, initial_state, options)`. The H1
connection process or H2/H3 stream worker implements callbacks, automatic pong,
bounded fragmented messages, UTF-8 validation, and close handshakes. Handshake response headers,
including a selected offered subprotocol, survive the Plug pipeline. Compression
extensions are not negotiated; `compress: true` and disabling UTF-8 validation
are rejected. The vendored dependency includes native Gaoxy dispatch and
immutable H2/H3 metadata early validation, with
[provenance and a removal plan](../vendor/websock_adapter/GAOXY.md).

Options default to `timeout: 60_000`, `callback_timeout: 5_000`,
`close_timeout: 1_000`, `max_lifetime: 86_400_000`,
`max_frame_size: 262_144`, `max_message_size: 262_144`, `max_fragments: 128`,
`max_mailbox: 128`, and `max_push_frames: 32`. Frame/message ceilings are also
clamped to one quarter of the service byte budget. The service `max_state`
limits callback state. Upgrade establishes one admitted protocol lifetime;
callbacks cannot renew it. For H2/H3 this lifetime replaces the original HTTP
request deadline in the stream worker and native owner; writes and callbacks
retain finite deadlines. Normal Close ends only that WebSocket stream, leaving
ordinary HTTP siblings and other WebSockets independent. Specialist abnormal
disconnect, slow-peer, pressure and load qualification remains deferred.
H1 drain uses its existing absolute deadline and sends
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
The native H2 engine belongs to `gaoxy_http`. Managed upstream H1/H2 and
connection reuse passed the ordinary scope in [M3 completion](acceptance/m3-completion.md);
the dedicated-H1 adapter retains its separate capability boundary.

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
