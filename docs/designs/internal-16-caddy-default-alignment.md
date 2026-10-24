# Internal request #16: Caddy defaults research and alignment design

Date: 2026-10-24 (Asia/Shanghai).
Status: implementation and scoped H1/Phoenix/H3 qualification completed; H2 persistence blocked; final combined acceptance and publication incomplete.
Execution update: 2026-10-25 (Asia/Shanghai).

## Baselines and scope

This document addresses [Gaoxy #16](https://github.com/gsmlg-dev/gaoxy/issues/16),
reported by Synapsis: a default HTTP/1 listener closes a 300 KiB WebSock reply,
and a 313,781-byte initial LiveView render, with close code 1011. The issue's
network reproduction used 0.12.1. This investigation inspected current 0.12.2
source; it did not rerun that network reproduction.

- Gaoxy baseline: `e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f`.
- Caddy current stable release, verified through GitHub release metadata:
  [v2.11.7](https://github.com/caddyserver/caddy/releases/tag/v2.11.7),
  published 2026-10-03.
- Caddy annotated tag object: `87c43dc4f54861ec7e54302cfb2ad3e34508b6dc`.
- Caddy tag's source commit: `72dd0fb067f6d7826c7f79907670ba4a713bfe37`.
- Official documentation was retrieved on 2026-10-24. Its pages are live
  documentation; the immutable source links below establish versioned behavior.

The Caddy research below preserves its original source baseline. The alignment
implementation and scoped runtime results are recorded separately below; they
do not establish complete H1/H2/H3 acceptance, a new release or deployment.
The existing #6 configuration repair and #15 peer-close repair keep their
historical scope and evidence.

## What Caddy actually does

### Upgraded WebSocket traffic

Caddy's reverse proxy upgrades the request and copies bytes in both directions.
It does not run an application WebSock callback or assemble data messages in
this path. The copier has no data-frame length or whole-message length check.
Its default copy buffer is 32 KiB per direction. Each copy operation allocates a
buffer once and passes it to `io.CopyBuffer`; Go's optional `ReaderFrom` or
`WriterTo` fast paths can bypass that buffer. This is distinct from the pool
used for ordinary HTTP response copying. Transport/TLS/HTTP2/HTTP3 and kernel memory
are additional allocations, so 64 KiB is not a bound on the entire connection.

Evidence:

- [Upgrade and H2/H3 adaptation](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/streaming.go#L60-L144).
- [Bidirectional copying and 32 KiB default](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/streaming.go#L673-L739).
- [Stream configuration fields](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/reverseproxy.go#L175-L200).
- [Caddyfile stream-buffer parsing](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/caddyfile.go#L653-L678).
- [Official streaming documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#streaming).

| Caddy setting or behavior | Effective default | Meaning |
| --- | --- | --- |
| WebSocket data-frame/message payload ceiling | None in the inspected proxy path | A buffer boundary is not a message boundary |
| `stream_buffer_size` | 32 KiB per direction | Reusable upgraded-stream copy buffer; configurable in JSON and Caddyfile |
| `stream_timeout` | No timeout | Optional absolute stream lifetime; 24h in the docs is an example, not a default |
| `stream_close_delay` | No delay | On configuration unload, registered streams are closed immediately unless a delay is selected |
| Full HTTP request/response prebuffering | Off | `request_buffers` and `response_buffers` are opt-in and are not WebSocket message-size limits |
| Normal response flush policy | No periodic flush by default | SSE, unknown-length streams and `Incremental: ?1` receive streaming treatment |

An explicit stream timeout creates a timer only when positive
([source](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/streaming.go#L206-L226)).
Configuration unload registers and closes both directions, with best-effort
WebSocket 1001 control frames; this is separate from ordinary application close
handling and from a native server's close-handshake timeout
([source](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/streaming.go#L436-L544)).

Do not conclude that every connection is immune from all timeouts. HTTP/1
hijacking, multiplexed request-body/response wrappers, upstream transport
timeouts and an explicit stream lifetime are different owners. Go 1.26's HTTP/1
hijack clears the previous connection deadline
([Go source](https://github.com/golang/go/blob/go1.26.0/src/net/http/server.go#L317-L325));
Caddy's streaming copier itself does not contain a `SetDeadline` call.
H2/H3 extended CONNECT does not hijack the connection: the copier retains the
request body and response writer. Their installed read-idle wrapper can still
bound an outstanding read waiting for client WebSocket data; write-idle bounds
an actual write/flush. The H1 deadline-clearing result therefore must not be
generalized to quiet H2/H3 WebSocket streams. See [wrapper installation](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/server.go#L588-L617),
[body retention](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/reverseproxy.go#L521-L526)
and the extended-CONNECT adaptation linked above. This is a source-level
finding; no comparative idle-timeout runtime test was executed.

### HTTP server defaults

These are provisioned at runtime for both JSON and Caddyfile configurations,
not just inserted by the Caddyfile adapter.

| Setting | Caddy v2.11.7 default | Important distinction |
| --- | --- | --- |
| Request header deadline | 1 minute | Deadline for completing headers |
| Whole request-body read timeout | Unset | Separate from read-idle protection |
| Active body-read idle timeout | 1 minute | Bounds a stalled read; no minimum data rate by default |
| Whole response write timeout | Unset | Does not impose a total SSE lifetime |
| Active write/flush idle timeout | 1 minute | Bounds an operation that stalls; quiet periods between successful writes are allowed |
| Maximum write chunk with idle writer | 64 KiB | A progress-accounting chunk, not a response limit |
| HTTP keepalive idle timeout | 5 minutes | Wait for the next HTTP request; not a WebSocket message timeout |
| Maximum request headers | 16 KiB | Finite protocol parsing protection remains |
| General request-body size cap | None | Positive `request_body max_size` is an explicit middleware limit; exceeding it yields 413 |

Sources: [server defaults](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/app.go#L400-L418),
[header default](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/app.go#L269-L273),
[server fields](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/server.go#L61-L111),
[request-body cap](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/requestbody/requestbody.go#L66-L85),
[official timeout documentation](https://caddyserver.com/docs/caddyfile/options#timeouts),
and [official body documentation](https://caddyserver.com/docs/caddyfile/directives/request_body).

Zero is not a universal spelling for disabled in Caddy: zero selects defaults
for header/idle settings, while no hard body/write timeout is represented by
zero. Negative idle durations disable those wrappers; nonpositive maximum
header sizes restore the finite default. Gaoxy should adopt explicit option
semantics rather than copy these mixed numeric sentinels.

### Why the idle implementation matters

Caddy 2.11.6 introduced new idle defaults. The v2.11.7 release notes explicitly
record fixes for an H2 crash after handler return, POST/SSE responses cut off
after body completion, and quiet H2 streams incorrectly reset after one minute.

The fixed implementation:

1. Computes deadlines around active I/O and caps them by an explicitly selected
   hard deadline.
2. Clears a completed request-body reader's deadline and stops modifying the
   controller after handler completion.
3. For HTTP/2, clears write-idle deadlines between successful operations, while
   preserving any hard deadline.
4. Splits large writes into bounded operations, so the idle timer measures
   progress through writes rather than a whole large response.

Sources: [release notes](https://github.com/caddyserver/caddy/releases/tag/v2.11.7),
[deadline calculation](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/idletimeout.go#L33-L71),
[reader ownership](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/idletimeout.go#L100-L168),
and [write-idle semantics](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/idletimeout.go#L171-L332).
The upstream regression tests were inspected, not executed.

### Reverse-proxy transport defaults

| Setting | Effective default |
| --- | --- |
| Upstream dial timeout | 3 seconds |
| Upstream response-header timeout | Unset |
| Upstream read/write timeout | Unset |
| HTTP transport read/write buffers | 4 KiB each |
| Maximum upstream response headers | 10 MiB |
| Idle upstream keepalive retention | 2 minutes |
| Idle upstream pool | 32 per host; no aggregate count limit |
| TCP keepalive probe interval | 30 seconds |

Sources: [transport provisioning](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/httptransport.go#L206-L230),
[transport fields](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/httptransport.go#L100-L129),
[pool application](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/modules/caddyhttp/reverseproxy/httptransport.go#L473-L492),
and [official transport documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#the-http-transport).
Read/write timeout wrappers apply to TCP connections, not independently to H2
streams. Pool idle retention, TCP probes and downstream HTTP keepalive are
different settings. An upstream dial timeout is not disabled by a negative
duration.

Caddy also configures Go CPU/memory behavior against container/system resources
in its CLI startup path
([source](https://github.com/caddyserver/caddy/blob/72dd0fb067f6d7826c7f79907670ba4a713bfe37/cmd/main.go#L474-L500)).
That is not a hard per-message or per-listener byte admission limit, and a Go
runtime memory target is not an interchangeable BEAM configuration value.

## Gaoxy comparison

At the research baseline, the common native engine had idle timeout 60s, callback
timeout 5s, close-handshake timeout 1s, absolute lifetime 24h, frame/message limits 256 KiB,
fragment count 128, mailbox count 128 and output-frame count 32 per callback
([source](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http/lib/gaoxy/http/websocket.ex#L24-L34)).
All were validated as positive integers. Startup clamped both selected payload
limits to one quarter of the service byte budget
([source](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http/lib/gaoxy/http/websocket.ex#L77-L108)).

| Entry point with omitted payload options | Service byte default | Effective frame/message ceiling |
| --- | --- | --- |
| Native upgrade, H1-only service | 1 MiB | 256 KiB |
| Adapter/Phoenix, H1-only service | 1 MiB | 256 KiB |
| Native upgrade, H2-enabled service | 256 MiB | 256 KiB |
| Adapter/Phoenix, H2-enabled service | 256 MiB | 10,000,000 bytes |
| Native upgrade, H3 service | 16 MiB | 256 KiB |
| Adapter/Phoenix, H3 service | 16 MiB | 4 MiB |

These ceilings assume sufficient free aggregate admission capacity. An
H2-enabled mixed listener gives its H1 requests the H2-enabled service budget;
therefore enabling a protocol changes otherwise equivalent H1 message capacity.

Sources: [core limits](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy/lib/gaoxy/config.ex#L3-L13),
[H2 service defaults](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http/lib/gaoxy/http.ex#L131-L137),
[H3 service defaults](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http3/lib/gaoxy/http/http3/options.ex#L27-L36),
and [adapter default injection](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/vendor/websock_adapter/lib/websock_adapter.ex#L63-L76).

The baseline output path compared the sum of a callback's frame payloads with
`max_message_size`, then mapped `:output_limit` to close 1011. It did not simply
apply independent per-frame/per-message wire limits
([source](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http/lib/gaoxy/http/websocket.ex#L405-L459)).
That explains the issue's server-output symptom and identifies a separate
batch-policy ambiguity.

### Configuration changes alone are insufficient

At the research baseline, Gaoxy's decoder assembled full frames and full messages;
output encoding also constructed a complete wire binary before chunked sends.
Chunking the final socket write does not make that allocation independent of
message size. Native WebSock delivers a complete message to its callback, so
application-message memory remains proportional to payload size even after
transport staging is bounded.

The finite admission budget accounts for buffered bytes, partial messages,
application state and output reservations. Removing the two `/4` clamps leaves
that aggregate ceiling, the native defaults and the adapter's 10 MB default.
It would not establish Caddy-equivalent default capacity.

Conversely, changing the existing service `max_bytes` to infinity is unsafe:
the same value feeds QUIC writer capacity and flow-control windows
([service source](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy/lib/gaoxy/service.ex#L919-L946)),
H2/H3 minimum reservation checks, route-snapshot budgets and UDP-relay slot
arithmetic. Buffer/window capacities must remain finite and independently
meaningful.

Phoenix itself supplies a 60s WebSocket timeout before Gaoxy receives options.
That application-owned default must not be erased by guessing whether a value
equal to 60,000 was explicitly typed by a user. Similarly, an explicit
10,000,000-byte frame limit must not be guessed to be an adapter default solely
because of its number.

Gaoxy HTTP defaults also differ: 32 KiB request headers, 8 MiB body cap, 30s
request timeout and 5s header/read/write timeouts, with 16 KiB reads and a
64 KiB staging buffer. These need a separate HTTP timeout/body policy slice;
the #16 repair must not silently redefine them.

## Confirmed WebSocket product contract

On 2026-10-24 the user clarified the product direction: WebSocket exists to
keep a connection open and transfer data; the implementation must not impose
connection-time or data-size ceilings. In this context the connection wording
is understood as connection lifetime/inactivity, not a promise that physical
network connections can never fail.

This decision supersedes the earlier proposal to ship the payload fix while
leaving default idle/lifetime changes for optional later work. The following
are one completion contract for native and Phoenix paths over H1/H2/H3:

- A healthy upgraded connection has no implementation-selected maximum age and
  is not closed merely because it has been quiet for a fixed interval.
- Default operation has no arbitrary single-frame, whole-message, wire-fragment,
  callback-batch-byte or cumulative-transfer ceiling. Mandatory RFC wire-format
  and protocol-validity rules remain in force.
- Finite transfer capacity is reusable: stop requesting input or wait for output
  capacity, return credit when its owner consumes/releases it, then continue.
  A buffer/window size is not a maximum transferable payload or lifetime total.
- Generic service `max_bytes` and `max_state`, whether omitted or explicitly
  configured for service resources, do not become WS message/application-state
  ceilings. Preserve their finite ordinary HTTP/raw/UDP and transport meanings.
- Application-requested close, explicit application policy, protocol errors,
  actual transport failure and service shutdown remain valid lifecycle events.
  A framework-injected default does not establish an explicit application policy.

No new `max_websocket_bytes` or `max_websocket_state` configuration is planned.
The previous optional-budget/provenance/aggregate-ceiling proposal is withdrawn:
it is unnecessary for this contract and could recreate a hidden size limit.
Existing deliberate application WS policies are a separate compatibility path;
none is implicitly enabled or used as the acceptance mode for this product goal.

### Decisions and defaults

| Resource or policy | Required behavior |
| --- | --- |
| Native frame/message sizes | Omitted limits select `:infinity`; no clamp derived from service bytes |
| Wire fragment count | No default count ceiling; internal read chunks are not wire fragments |
| Retained WS messages/state/output | Measure ownership and bytes; no generic service-cap rejection |
| Idle and absolute lifetime | No implementation-selected cutoff after upgrade; no corresponding default close timers |
| Phoenix and vendored adapter defaults | No injected frame or idle limit may silently bound the default WS path |
| Callback output batch | Process incrementally; no default batch-byte/count ceiling acting as a transfer limit |
| Transport staging, H2/QUIC windows and writer queues | Finite, recycled through demand/credit/backpressure |
| Callback computation, an individual send, close and drain | Finite fault/lifecycle bounds; never a deadline covering an entire progressing message or connection |
| Application heartbeat/authentication/close policy | Application ownership, separate from server transport defaults |

This is Gaoxy's product contract, informed by Caddy research. It does not claim
Caddy has identical H1/H2/H3 inactivity behavior: the research above preserves
its outstanding-body-read idle boundary for multiplexed WebSockets.

### Admission and memory ownership

Separate classified integer accounting at WS upgrade:

- `transport_bytes` covers finite staging, protocol control reservations and
  outstanding read/send credits, alongside ordinary scalar admission.
- `websocket_bytes` measures accumulated message payload, application state,
  unsent callback output and accounted message-sized temporary copies.
- `bytes` reports the sum as accounted retention, not total VM/kernel/native
  allocation. After upgrade, only transport accounting is constrained by the
  generic finite service transport budget; total retained WS bytes may exceed it.

Ordinary scalar Admission callers keep their current meanings. Upgrade
atomically reclassifies the existing owned lease, preserving its generation,
monitor, request eligibility, send-operation tracking and drain behavior.
Classified updates cannot be replaced by scalar updates that erase retained
ownership. Check finite transport capacity consistently across acquisition,
upgrade, updates, sends and cleanup; retained WS counts remain measured without
an added admission ceiling. Release both categories at actual terminal ownership
transitions, not at an optimistic early acknowledgement.

Do not count an already retained output payload again for each transmitted
chunk. Do not release a credit while an H2/H3/native queue still owns its bytes.
Moving consumed input into message retention returns transport capacity so
larger messages and many successive messages can continue. Completed transfer
bytes are not permanently deducted from a listener budget.

The previous configuration-provenance machinery is not needed: explicit
`max_bytes` no longer means an additional combined WS ceiling. Core limit keys,
QUIC window arithmetic, UDP relay calculations and ordinary state policies stay
finite. Do not pass infinity into those existing arithmetic consumers. Audit
H2's manually constructed lease-size estimator if the ordinary lease schema
changes; a stale estimator and stale unit fixture must not agree on an old shape.

### Incremental data path

Consume frames through bounded input chunks while retaining partial headers,
mask position and actual wire-frame boundaries. Accumulated payload belongs to
message retention. Preserve masking, UTF-8, valid 63-bit lengths, fragmentation
order and control-frame rules. Count internal chunks separately from wire
fragments; avoid accumulating metadata for empty fragments.

Keep complete-message WebSock callbacks. For output, construct a small frame
header and traverse the callback's iodata with a bounded chunk cursor instead
of constructing a second whole header-plus-payload binary. Account the whole
unsent batch while it is retained, then release it progressively. Existing
`max_push_frames` and mailbox-close behavior require review: work-turn/queue
bounds must regulate scheduling or demand, rather than close an otherwise
healthy connection because valid work is larger than one turn.

Finite staging does not imply constant total memory. Native callback retention
remains O(message + application state + pending output), and callback code can
allocate before handing its result back to Admission. These are physical/API
properties, not an excuse to introduce an implicit protocol payload ceiling.
This plan adds no public streaming callback API, disk spooling or opaque proxy
mode.

### Lifetime, inactivity and operation ownership

Idle and absolute-lifetime changes are required acceptance, even if implemented
in separate commits after the accounting foundation:

1. Upgrade a still-live HTTP request atomically into WS ownership with no default
   absolute deadline; cancel old request timers and ignore stale timer tokens.
   No 24h timer is created. Expired/unowned requests still cannot upgrade.
2. Default healthy WS inactivity creates no close timer. Audit H1's supported
   persistent timeout, the shared H2/H3 receive loop and underlying connection
   idle owners. Wrapper-injected finite defaults must not reintroduce eviction.
3. Phoenix's synthesized 60s timeout cannot automatically be treated as an
   explicit application decision. The inspected Phoenix 1.8.16 upgrade API
   receives already-merged options; generated `Endpoint.__sockets__/0` is
   `@doc false`, not a supported provenance interface. Use the documented
   `websocket: [timeout: :infinity]` socket declaration in the supported Gaoxy
   integration and fixtures, preserving a deliberately finite application
   declaration. Never guess intent from equality with 60,000 or couple to
   private metadata. This is explicit integration configuration, not proof
   of zero-configuration compatibility for every existing Phoenix application.
4. End the callback-computation watchdog when the handler returns, while
   atomically taking ownership of returned state/output. The baseline
   `begin_callback -> result -> push -> send -> retain` path kept the 5s timer
   across the whole batch; the implementation now ends it before output. A large
   message making progress must not be cut off by that callback deadline.
5. Sends use finite operation/progress bounds on bounded chunks. Capacity waits
   and credit handoffs are owned and finite where necessary; a deadline must
   not count the total age of a progressing message. Protocol fault handling,
   actual disconnect, application close and finite service drain still clean up.

Do not change Phoenix's own application heartbeat or authorization logic merely
to suppress a server transport timer. No finite callback/send/close/drain setting
is copied into an idle timeout or whole-message/connection lifetime.

### Resolved H3 dependency gate and remaining H2 blocker

The original H3 investigation found that `elixir_quic` 0.21.16 and Abyss 0.9.0
required finite local idle values. The routed Feature requests
[gsmlg-dev/http_fetch#143](https://github.com/gsmlg-dev/http_fetch/issues/143) and
[gsmlg-dev/abyss#6](https://github.com/gsmlg-dev/abyss/issues/6) are now **CLOSED**.
Released Abyss **0.10.0** and the HTTPFetch/QUIC **0.21.17** cohort are installed
in the root and Phoenix fixture locks. H3 now uses the supported disabled local
idle policy and public PING API, without dependency patches or a large finite
duration standing in for infinity.

Only the H3 host selects disabled QUIC local idle. The H3 owner restores finite
ordinary empty-connection idle after request cleanup. Active WebSockets use
ready metadata's peer idle policy to schedule finite PING operations; uncertain
admissions retain their original reference and deadline for polling. Keepalive
admission does not prove peer receipt, and actual transport failure remains a
valid termination. A focused independent-peer run passed **2 tests, 0 failures**:
exact **5 MiB** transfer and **900 ms** quiet persistence against a peer with a
**300 ms** advertised idle timeout. The canonical protocol run also passed
**130 tests, 0 failures**; final local gates are recorded below.

H2 persistence is now **BLOCKED** by the still-**OPEN** Feature request
[gsmlg-dev/hell#2](https://github.com/gsmlg-dev/hell/issues/2): a supported
connection-owner idle transition while WebSocket streams require persistence,
with ordinary idle restoration after the last owner ends. H2's infinite common
WS receive loop alone does not suppress Hell's inherited connection idle timer.
TODO markers remain at the H2 upgrade and removal callsites. Do not patch Hell,
use private state, globally disable ordinary H2 idle, or add a local workaround.
Resume this slice only after the upstream fix is released and installed.

Size and persistence remain one H1/H2/H3 completion contract. Qualified H1,
Phoenix and H3 results do not complete the blocked H2 slice; **no release or #16
closure** follows from the current partial completion. Historical specialist
pressure, slow-peer and soak dispositions remain unchanged.

### Completion and later HTTP work

Size acceptance alone no longer completes this WS work. Require default native
and Phoenix data exchange, no default idle/lifetime timers, progress across many
reused transport credits, unchanged protocol siblings and complete cleanup.
Use bounded ordinary cases and controlled timers; preserve historical deferred
specialist pressure/slow-peer/soak evidence without reopening those slices.

General HTTP defaults remain a separate design: header completion, active body
read, active write/flush, optional hard whole-transfer deadline and next-request
keepalive must have distinct owners. Caddy's 60s active-I/O values and 5m
keepalive are research inputs. Do not change Gaoxy's 32 KiB headers, 8 MiB body
policy, or currently unsupported general H3 infinite request timeout as an
incidental WS repair. Upstream pool/dial/probe policy is separate again.

## Verification disposition

| Evidence | Disposition |
| --- | --- |
| Live release/tag metadata, official docs, pinned Caddy source | READ and compared |
| Current Gaoxy source and existing test contracts | READ and compared |
| Independent research of Caddy server defaults and Gaoxy option flow | Completed |
| Independent Caddy source/semantics review | Completed; H2/H3 idle and copy-buffer wording clarified |
| Original architecture/plan review | Completed before the user clarified the product contract |
| Revised persistent-transfer contract review | Two independent read-only reviews completed; no remaining reported findings |
| Caddy runtime or comparative benchmark | NOT RUN |
| Original native and Phoenix default-capacity regressions | RED preserved: both returned 1011 instead of required bytes |
| Native default-capacity qualification | PASS: 5 tests, 0 failures; 300 KiB, 2 MiB and 10,000,001-byte exact payloads, fragment/batch reuse, state isolation, normal close and quiet H1 |
| Actual LiveView default-capacity qualification | PASS: 1 test, 0 failures; complete 320 KiB render, serialized reply at least 313,781 bytes, heartbeat and close |
| Phoenix configured-policy and compatibility qualification | PASS: 12 tests, 0 failures |
| H3 independent-peer qualification | PASS: 2 tests, 0 failures; exact 5 MiB and 900 ms quiet with 300 ms peer idle |
| Callback completion regression | RED: 22 tests, 2 failures from armed terminate timers; repaired GREEN: 22 tests, 0 failures |
| Scoped implementation and independent source/ownership review | Completed for implemented slices; no outstanding reported findings in those slices |
| H2 connection-owner quiet persistence | BLOCKED: open hell#2; no local workaround |
| Final canonical gates | PASS: unit 254/0, component 167/0, protocol 130/0; inventory, format and strict compile exit 0 |
| Full Phoenix fixture and clean package consumers | PASS: Phoenix 24/0; consumers base 3/0, H3 2/0, HTTPFetch 2/0 plus production isolation/consumer release |
| Combined product acceptance, release and #16 closure | INCOMPLETE; size acceptance alone does not complete persistence |

Original failures are retained at `.audit/internal-16/native-baseline-red.log`
and `.audit/internal-16/phoenix-baseline-red.log`; the callback timer RED is at
`.audit/internal-16/callback-completion-red.log`. Commands, source identities,
counts and final local gate results are consolidated in
[the acceptance record](../acceptance/internal-16-default-capacity.md). These
results do not complete the blocked H2 persistence contract.

Raw research downloads are retained under ignored
`.audit/research-caddy-2026-10-24/`; source links above make the findings
reviewable without that local directory. They are research evidence rather
than a new product acceptance record.
