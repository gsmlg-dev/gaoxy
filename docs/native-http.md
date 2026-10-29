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
Cleartext H2 requires explicit `h2c: :prior_knowledge`. Select
`protocols: [:http2]` for H2-only TCP or `protocols: [:http2, :http1]` to serve
H1 and prior-knowledge H2 on one TCP listener. Plain TCP remains H1-only with
h2c disabled by default. HTTP/1 `Upgrade: h2c` is unsupported; there is no
`:auto` setting. The HTTP facade retains a finite 256 MiB numeric H2 transport
profile when `max_bytes` is omitted; this profile does not become an explicit
administrator admission cap. Omission selects adaptive shared memory admission.
Explicit service caps remain undoubled. A default H2 declaration needs no
resource override:

```elixir
{:ok, server} = Gaoxy.HTTP.start_link(
  plug: {MyPlug, []},
  protocols: [:http2], h2c: :prior_knowledge
)
```

For a shared cleartext listener, the same native handler accepts both protocols:

```elixir
Gaoxy.HTTP.start_link(
  plug: {MyPlug, []},
  transport: :tcp,
  protocols: [:http2, :http1],
  h2c: :prior_knowledge
)
```

Standalone JSON uses `"protocols": ["http2", "http1"]` and
`"h2c": "prior_knowledge"` on its existing `"transport": "tcp"` HTTP service.
Phoenix accepts the Elixir options in its existing `http: [...]` list. Each
entry point uses one listener and the same endpoint/router and native engines.
Protocol ordering, unknown-value rejection, host validation and H2 budgets
remain enforced. H2 over TCP without explicit prior knowledge, h2c over TLS,
and H1-only with h2c enabled are invalid.

Detection compares the complete 24-byte H2 preface incrementally. An incomplete
matching prefix remains undecided, the first mismatch selects H1 immediately,
and the complete match selects H2. Selection lasts for the connection; parser
errors never trigger fallback. At most 23 undecided bytes are retained, with
all received bytes replayed exactly once into the selected engine. The detector
creates no H2 decoder/writer or H2 output before selection.

Before input, existing idle handling applies. First input starts one fixed
detection deadline using the minimum of `http_limits.header_timeout`,
`http_limits.request_timeout`, and `h2_limits.frame_timeout`. Additional matching
bytes do not extend it. The first H1 header/request deadlines retain that
original start; later keep-alive requests retain their existing budgets. H2
receives the remaining startup allowance from first input and completes startup
only when the client acknowledges server SETTINGS. Its separate partial-frame
timer retains its existing semantics. An undecided connection closes promptly
on drain, using the same connection-owner admission lease through handoff.

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

Decoder expansion must have safe credit before HPACK allocation. Finite table,
header-block, carry, OTP SSL delivery/copy, flow-control and writer bounds remain
independent of adaptive admission. Numeric preflight validates the configured
protocol profile; those values do not allocate a separate host-memory allowance
per connection or listener. Dynamic H2 retention/decode-credit integration and
its ordinary qualification are in progress. The accounted resource model does
not bound whole-BEAM heap/GC or arbitrary trusted endpoint allocations.

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
per enabled scheme. Endpoint-level `resource_budget` configures one normalized
instance policy shared by all those listeners; multiple Endpoints also share
the VM pool. `MyEndpoint.server_info(:http)` returns its actual address
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
wait. A finite absolute request deadline also caps the whole operation, and
progress never resets it. Native H1/H2 listeners can explicitly select
`http_limits: %{request_timeout: :infinity}` to remove that total deadline for
uploads and file responses. Read-triggered `100 Continue` output retains finite
write/coordination limits and the configured write chunk cap; a failed Continue
is never replayed. This is separate from the native API's finite
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

## Shared resource admission

Adaptive defaults use 50% of effective physical memory, respecting cgroup
limits, as soft and twice soft as hard. Detection fallback is 256 MiB soft and
512 MiB hard. One authority coordinates instances/listeners in the same BEAM VM.
Normal usage is at or below soft; above soft through hard remains admissible
with rate-limited warnings. Projected growth above hard is rejected; admitted
work retains committed completion credits, and admission recovers after release.
Independent decoder, transport, process and OOM safety checks still apply.

Top-level ListenerSet/Phoenix `resource_budget` accepts both nil thresholds for
adaptive policy or positive finite `soft_limit <= hard_limit` overrides. Explicit
hard values are never doubled. Use `Gaoxy.resource_budget(instance)` for public
monitoring; adaptive runtime integration and qualification are in progress.

Service `limits.max_connections`, `max_requests` and `max_streams` default to
16,384, 65,536 and 65,536 respectively. Explicit legacy `max_active` caps aggregate
ordinary leases, including writers/workers, excluding cleanup and nonlegacy
post-worker stream retention. Explicit legacy `max_bytes` caps aggregate
transport/cleanup bytes excluding WS retention; shared memory accounting includes
WS retention. Omitted historical 64-lease and 1/256/16 MiB H1/H2/H3 profile values
are not administrator admission limits. Protocol-specific limits remain finite;
backend acceptor fanout retains a separate ceiling of 64.

## HTTP profile and limits

The initial profile supports HTTP/1.1 and explicit HTTP/1.0 persistence, raw
origin/absolute/authority/asterisk target parsing, fixed and chunked bodies,
trailers in the endpoint exchange, keep-alive, and ordered pipelining. Ambiguous
framing, duplicate Content-Length, unsupported transfer encodings and malformed
authorities are rejected before dispatch. The original escaped path/query is
preserved. Unread bodies force closure. Ordinary, prepared, chunked, fixed-length
streaming, file, HEAD/bodyless and informational Plug responses are supported.

For HEAD, a validated supplied `content-length` describes the representation
and is preserved even when the application sends an empty body. Without one,
the response body determines the length; no body is sent. Status rules retain
precedence: 204 omits the length, 205 uses zero, and 304 retains a supplied
representation length. Malformed or duplicate lengths remain errors; ordinary
GET response framing remains based on the actual body.

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
| `request_timeout` | 30,000 ms; native H1/H2 also accept `:infinity` |
| `stream_timeout` | `:request`; also `:infinity` or positive response-lifetime milliseconds |
| `read_timeout`, `write_timeout` | 5,000 ms per underlying body read / socket write |

`request_timeout` also accepts `:infinity` for native H1/H2 requests;
other limits except `stream_timeout` are positive finite integers. This covers
uploads and ordinary file responses without a stream transition. Header, read
and write timeouts, admission budgets, cancellation and shutdown remain finite.
Trusted application work without I/O needs its own execution/idle policy.
HTTP/3 and Generation targets, including managed gateway targets, reject
infinite requests with `:unsupported_request_timeout`, whether direct or wrapped.
Ordinary native/Plug targets, including ListenerSet and Endpoint-owned Phoenix,
support the H1/H2 opt-in.

HTTP/1 and HTTP/2 SSE routes can select `Gaoxy.HTTP.put_stream_timeout(conn, :infinity)`
before `send_chunked/2`, or a listener default with
`http_limits: %{stream_timeout: :infinity}`. The `:request` stream default
preserves the configured request lifetime, which can be infinite on a supported
listener that explicitly opts in. The transition requires a completed request
body and retains finite header, read, write, admission and shutdown controls.
See [streaming responses](streaming-responses.md) for polling and cancellation;
HTTP/3 does not support the opt-in. Partial headers and body metadata cannot
renew their original deadline. Slow writes retain a finite transport timeout.
`max_header_bytes` also bounds informational and final response heads;
`max_headers` limits parsed request headers.
Shared memory admission, explicit service caps and finite output limits still
apply: configured HTTP ceilings are not promises of admission under resource
pressure. Output iodata
and files are traversed in bounded pieces, without creating a full-body binary.

The ledger charges retained request headers/trailers, parser/body tails, selected
output windows, and separately observed WebSocket messages and callback state. Native receive buffers
and decoding have bounded transient copies; kernel/OTP transport buffers and
arbitrary allocations or retained body data inside trusted application code are
outside the ledger. This is not a bound on total BEAM memory. Explicit transport
caps and shared safety policy may reject work below a protocol-specific maximum.

## WebSock

Use `WebSockAdapter.upgrade(conn, MyWebSock, initial_state, options)`. The H1
connection process or H2/H3 stream worker implements callbacks, automatic pong,
incremental fragmented-message assembly, UTF-8 validation, and close handshakes. Handshake response headers,
including a selected offered subprotocol, survive the Plug pipeline. Compression
extensions are not negotiated; `compress: true` and disabling UTF-8 validation
are rejected. The vendored dependency includes native Gaoxy dispatch and
immutable H2/H3 metadata early validation, with
[provenance and a removal plan](../vendor/websock_adapter/GAOXY.md).

Options default to `timeout: :infinity`, `max_lifetime: :infinity`,
`max_frame_size: :infinity`, `max_message_size: :infinity`,
`max_fragments: :infinity`, `max_mailbox: :infinity` and
`max_push_frames: :infinity`. Callback computation defaults to 5 seconds and
close to 1 second. A deliberately configured frame ceiling supplies an omitted
message ceiling; an explicit message ceiling stays independent. Generic service
byte/state caps do not cap retained WS data or state; shared memory accounting
includes that retention. Transfer staging,
protocol windows and queues remain finite and reusable; retained WS messages,
state and output are reported separately. See [capacity](websocket-limits.md).

Upgrade replaces the original HTTP request deadline. Its optional application
lifetime cannot be renewed by callbacks. The callback-result handoff cancels its
execution watchdog before output; bounded sends get fresh finite deadlines.
Phoenix requires `websocket: [timeout: :infinity]` through its supported socket
configuration. H1 persistence and released H3 idle/keepalive APIs are integrated;
Hell 0.1.3 resolves the upstream gate in
[hell#2](https://github.com/gsmlg-dev/hell/issues/2) with public
`Hell.Handler.set_read_timeout/2`. H2 suspends connection idle while a WebSocket
owns a stream and restores the original idle interval after the last one ends.
Finite partial-frame and explicit application deadlines remain effective.
Normal Close ends only that
WebSocket stream, leaving ordinary siblings independent. Specialist abnormal
disconnect, slow-peer, pressure and load qualification remains deferred.
H1 drain uses its existing absolute deadline and sends
1001. The exact Phoenix `{:shutdown, :disconnected}` stop reason sends 1000
and normal WebSock termination; restart sends 1012. Arbitrary stop reasons retain
1011/error behavior, and explicit close-code results remain authoritative.
Forced watchdog termination cannot run
application cleanup callbacks.

Gaoxy uses active-once transport delivery. Third-party processes can send
arbitrary messages to a WebSock owner; an explicit mailbox policy is optional.
The transport cannot backpressure arbitrary external senders or promise an
absolute bound on their traffic. Keep application/PubSub producers bounded.

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

## Supervised shutdown

Use `{Gaoxy.HTTP, options}` as an OTP supervisor child. Its child spec inherits
the validated Gaoxy instance budget: configured `limits.drain_timeout` plus the
runtime's cleanup headroom. The HTTP/3 wrapper preserves the same budget.
Overriding the child spec's `shutdown` with a shorter value can kill the instance
before admitted requests drain and owned sockets finish cleanup. The default
5000ms drain therefore uses a 7000ms supervisor shutdown allowance.
