# Internal request #16: Caddy defaults research and alignment design

Date: 2026-10-24 (Asia/Shanghai).
Status: research completed; recommended design for review; implementation not started.

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

This is configuration and runtime-boundary research, with a proposed alignment
plan. It does not establish a new release, deployment or runtime acceptance.
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

The common native engine currently has idle timeout 60s, callback timeout 5s,
close-handshake timeout 1s, absolute lifetime 24h, frame/message limits 256 KiB,
fragment count 128, mailbox count 128 and output-frame count 32 per callback
([source](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http/lib/gaoxy/http/websocket.ex#L24-L34)).
All are validated as positive integers. Startup clamps both selected payload
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

The output path compares the sum of a callback's frame payloads with
`max_message_size`, then maps `:output_limit` to close 1011. It does not simply
apply independent per-frame/per-message wire limits
([source](https://github.com/gsmlg-dev/gaoxy/blob/e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f/apps/gaoxy_http/lib/gaoxy/http/websocket.ex#L405-L459)).
That explains the issue's server-output symptom and identifies a separate
batch-policy ambiguity.

### Configuration changes alone are insufficient

Gaoxy's decoder currently assembles full frames and full messages; output
encoding also constructs a complete wire binary before chunked sends.
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

## Recommended alignment

### Decision and alternatives

Adopt Caddy's separation of transferable payload size, finite transfer buffers,
and optional lifetime policy. Preserve Gaoxy's whole-message WebSock contract.
Implement the WebSocket payload/accounting change first; schedule idle and
absolute lifetime independently. General HTTP defaults are a separate design
slice, not an incidental change in #16.

| Alternative | Effect | Decision |
| --- | --- | --- |
| Raise 256 KiB or the service budget | Can clear the reported 300 KiB symptom | Reject as the final fix: another arbitrary ceiling remains |
| Remove payload limits but keep the default whole-message admission ceiling | Retains today's aggregate-memory guarantee | Reject as the final fix: large default messages still fail |
| Separate finite transport accounting from optional WS retained-memory admission | Removes implicit payload ceilings and preserves explicit limits | Recommended; requires an accounting change rather than a constants-only patch |

A finite default aggregate ceiling over complete messages cannot also promise
no default payload ceiling. The recommended behavior deliberately makes WS
retained memory an application/operator policy. It must be described as such,
including the increased default exposure to large messages and application
state. This is a compatibility decision about defaults, not evidence that the
current implementation already handles arbitrarily large messages.

### Proposed WebSocket behavior

| Option or resource | Current native default | Proposed behavior |
| --- | --- | --- |
| `max_frame_size` | 256 KiB, also clamped by service budget | `:infinity`; explicit positive bytes remain authoritative |
| `max_message_size` | 256 KiB, also clamped | `:infinity`; when only a finite frame limit is supplied, inherit it for compatibility with #6 |
| `max_fragments` | 128 | `:infinity`; explicit positive counts still reject excessive fragmentation |
| Retained WS payload/state admission | Implicit service byte ceiling | Optional service-wide budget, default `:infinity`; continue measuring actual accounted bytes |
| WS application state | Implicit core `max_state` | Optional state ceiling; preserve an explicitly configured legacy `max_state` |
| Native `timeout` | 60s | Separate idle slice: omitted native option becomes `:infinity`; received application values remain authoritative |
| `max_lifetime` | 24h | Separate lifetime slice: omitted option becomes `:infinity`; explicit finite lifetime remains absolute |
| Callback / close deadlines | 5s / 1s | Retain finite defaults |
| Mailbox / output-frame count | 128 / 32 | Retain finite defaults; these bound queued work and a callback batch, not one message's byte size |
| Transport read/write staging, H2/QUIC windows and queues | Finite | Retain finite capacities independent of cumulative message bytes |

Use `:infinity` explicitly only on the selected policy fields. Reject zero,
negative, `nil`, booleans, floats and unsupported sentinel values. Do not rely
on Erlang's ordering between integers and atoms to implement an unlimited
comparison. Mandatory RFC 6455 checks remain: masking, reserved bits, opcode,
minimal/valid 63-bit lengths, UTF-8, fragmentation order, and the 125-byte
control-frame ceiling.

Each WebSock text/binary output tuple is one message in the existing API.
Validate its frame/message policy independently; do not sum two valid messages
and reject their callback batch as one oversized message. Keep the separate
finite `max_push_frames` check. No automatic output fragmentation or public
streaming callback API is introduced by this plan.

Remove the vendored adapter's injected 10,000,000-byte frame default only for
`Gaoxy.PlugAdapter` dispatch, before the omission information is lost. Preserve
an explicit limit with that exact value and preserve other adapters' defaults.
Refresh the canonical vendor patch, snapshot hashes and reconstruction evidence
together. Do not modify fetched `deps/`.

Phoenix supplies its own transport `timeout` (currently 60s). Honor it just as
any other received value. Native omission can select infinity without changing
Phoenix policy. Never identify provenance by equality with 60,000 or 10,000,000.
Selecting infinity for native WS inactivity is a Gaoxy product choice informed
by Caddy's H1 upgraded-stream behavior; it is not a claim that Caddy has identical
H1/H2/H3 inactivity defaults.

### Admission and memory ownership

Account three quantities separately, with integer counters:

- `transport_bytes`: ordinary HTTP/raw reservations, protocol control state,
  WS staging buffers and outstanding send/read credits. Keep the existing
  finite `limits.max_bytes` enforcement for this category.
- `websocket_bytes`: accumulated application messages, application state,
  pending callback output and transient message-sized copies. Its new explicit
  service-wide ceiling is optional and shared by upgraded connections.
- `bytes`: the sum of both categories. Keep it visible as total accounted
  application retention, not total BEAM/kernel/native memory. Preserve an
  explicitly configured legacy `limits.max_bytes` as an additional aggregate
  ceiling over this sum.

Do not count a retained output payload again for each transmitted chunk, or
return transport credit while a queue still retains it. Count unavoidable
message flattening/copy overlap while both representations are live. For H2/H3,
connection/stream queue ownership must transfer credit exactly once; moving a
payload into message retention permits renewed finite transport credit, rather
than accumulating all consumed bytes against a flow-control window.

Upgrade must atomically reclassify the existing owned lease, retaining its
generation checks, monitor, request eligibility, send-operation tracking and
drain behavior. Ordinary scalar Admission callers continue to mean transport
accounting. Only an upgraded WS lease can use classified updates. Apply the
same capacity predicate in acquisition, upgrade, retain/update, callback entry,
send reservation and cleanup transitions; do not leave one scalar path able to
erase or bypass retained WS accounting. Release both categories on the actual
owner/cleanup terminal transition.

Capture explicit legacy `max_bytes` and `max_state` choices before any H1/H2/H3
default insertion. Persist that provenance through service normalization and
revalidation; H2's 256 MiB or H3's 16 MiB defaults must not become user policy
merely because they appear in a normalized map. A value explicitly equal to
the default is still explicit. Explicit new and legacy limits compose by the
stricter applicable ceiling; an unlimited new field cannot relax a finite
legacy aggregate/state policy.

Keep QUIC windows/writer capacity, HTTP request admission, UDP packet/output
rules, relay arithmetic and route-snapshot limits finite with their existing
meanings. Never pass `:infinity` into those existing `max_bytes` consumers.
Update status/telemetry contracts alongside the accounting change: after a
default WS upgrade, `bytes <= max_bytes` is no longer a total-retention invariant;
`transport_bytes <= max_bytes` remains one. Counters remain measured even with
unlimited WS enforcement.

### Configuration interface and provenance

Add two core-validated service limit keys; both accept positive integers or
`:infinity`:

```elixir
limits: %{
  max_websocket_bytes: :infinity,
  max_websocket_state: :infinity
}
```

`max_websocket_bytes` applies to service-wide `websocket_bytes`.
`max_websocket_state` applies to each WS application's `:erlang.external_size/1`;
that state also contributes to the service-wide retained count. Existing
`max_bytes` and `max_state` still accept only positive integers.

Core-owned normalized specifications carry internal provenance for only the two
legacy keys, recording both the source and the value it describes:

```elixir
limit_sources: %{
  max_bytes: {:default, 268_435_456},
  max_state: {:explicit, 65_536}
}
```

This is internal metadata, not another HTTP keyword option. The embedded
configuration is trusted; provenance prevents normalization mistakes rather
than providing an authentication boundary. Recommended pure core interfaces:

```elixir
Gaoxy.Config.normalize_limits(raw_limits, defaults, sources \\ nil)
# {:ok, %{limits: limits, limit_sources: sources}} | {:error, reason}

Gaoxy.Config.put_limits(normalized_spec, overrides)
# {:ok, updated_spec} | {:error, reason}

Gaoxy.Config.retention_policy(normalized_spec)
# %{max_retained_bytes: limit, max_retained_state: limit, max_total_bytes: limit}
```

On first normalization, raw-key presence determines explicitness. Merge core
defaults, protocol defaults and raw input in that order. With existing metadata,
require complete valid source entries and matching legacy values, then preserve
them. Reject malformed/stale metadata; never silently re-infer or repair it.
`put_limits/2` marks intentional legacy overrides explicit, even for an equal
number. Repeated `Config.service/1` validation must be idempotent.

H2 supplies its numeric defaults to `normalize_limits/3` instead of injecting
them into the raw map. H3 replaces its private defaults merge with the same
helper. Carry the resulting metadata through `Config.service/1`, the second
validation in `Gaoxy.start_link/1`, ETS and service initialization. The effective
policy is:

- `max_retained_bytes = limits.max_websocket_bytes`;
- `max_retained_state = min_limit(limits.max_websocket_state,
  explicit_legacy_max_state_or_infinity)`;
- `max_total_bytes = explicit_legacy_max_bytes_or_infinity`.

Initialize Admission with `{limits, retention_policy, scope}`. Its atomic
`upgrade(gate, lease, accounting, deadline)` returns `{:ok, retention_policy}`
after checking initial state and capacity. The accounting argument includes
initial state size, so the state check happens before handshake success.
Subsequent classified updates enforce aggregate capacity at the same gate.
The WS engine therefore no longer needs copied service-limit maps from the H2
or H3 connection owner; it receives effective state policy from its owned gate.
Core does not call or depend on an HTTP module.

`Gaoxy.Activation.match_plan/2` also needs explicit infinity-aware limit
comparison and comparison of effective retention policy. A final specification
may tighten the plan, including default-to-explicit legacy policy, but cannot
change an explicit finite aggregate ceiling to unlimited merely by changing
provenance with the same numeric limit. Do not compare source maps for exact
equality: that would incorrectly reject legitimate tightening.

### Bounded transport work with whole-message callbacks

Change internal frame parsing to consume bounded chunks incrementally, retain
partial header/masking state, and continue the masking offset across chunk
boundaries. Store accumulated payload as message memory. Enforce a configured
frame limit when its declared length is known, and a configured message limit
as data arrives. Track actual wire-fragment boundaries separately from internal
read chunks; the latter must not consume `max_fragments`.

Preserve interleaved ping/pong/close handling between wire fragments. Avoid
building a retained list entry for every empty fragment; count finite fragment
policy independently. Message assembly still produces a complete payload for
`handle_in/2`, including any temporary flattening overlap in optional admission.

For output, construct a small frame header and traverse existing iodata using
a finite chunk cursor. Avoid first flattening payload and then constructing a
second complete header-plus-payload binary. Each actual send remains bounded
by the existing transport write quantum and its finite operation deadline.
The callback's retained batch must be accounted while later messages are waiting
to send, even though the message-size policy applies to each independently.
Admission observes application state/output at callback handoff; it cannot
prevent a callback from allocating memory before returning. The optional
accounted-retention policy is therefore not a hard process/VM allocation limit.

This bounds transport work and avoids unnecessary full-wire duplication.
It does **not** make native callback memory O(buffer): memory remains O(message
size + application state + retained callback output), and the VM can run out
of memory under an unlimited policy. Do not add disk spooling, an opaque proxy
mode, dependency patches or a new public callback contract to solve #16.

### Idle and lifetime ownership

Keep the existing finite defaults during the accounting foundation. Enable the
new payload defaults only after the complete framing/admission path is ready.
Then handle these independent lifecycle slices:

1. Native inactivity: accept `timeout: :infinity` and omit idle timer creation;
   preserve supplied finite values, including Phoenix's value. Do not turn an
   omitted timeout into an unbounded callback or send.
2. Absolute lifetime: extend upgrade validation to allow `:infinity`, create no
   lifetime timer in that case, and cap finite callbacks by the lifetime when
   present. Upgrade from a still-live finite HTTP request to the new WS lifetime
   in one owned transition. Repeated callbacks cannot renew finite lifetime.
3. Close, callback, send and service drain retain finite deadlines, even when
   both inactivity and lifetime are infinite. A forced drain/reconfiguration
   must still release resources. Caddy's `stream_close_delay` is not a reason
   to alter Gaoxy's shutdown protocol in this change.

### Later HTTP alignment decision

The useful Caddy target is distinct policy ownership: header completion,
active body read, active write/flush, optional whole-transfer deadline, and
next-request keepalive. Do not copy a single 60s value into all these fields.
The subsequent HTTP design should propose 60s header/read-progress/write-progress
defaults, no hard whole-transfer timeout and 5m next-request idle, with explicit
compatibility for current finite settings. Preserve quiet SSE gaps and clear
body-read deadline ownership on EOF and handler completion. Specify H1/H2/H3
scope separately; H3 currently rejects an infinite general request timeout.

Do not lower Gaoxy's 32 KiB header ceiling merely to match Caddy's 16 KiB, or
remove its 8 MiB body limit as part of #16. Body retention/admission and Plug
parser policy need their own decision and acceptance. Current finite values
remain effective until that separate design is complete. Existing read/write
chunks need only remain bounded; choosing 32 KiB solely because Caddy uses it
would not improve the native whole-message contract.

Upstream pool retention, TCP probes and dial/header waits are a separate
transport owner again. This plan does not add missing pooling/upstream-H2
capabilities or reopen historical gateway/HTTP Fetch proof requirements.

## Verification disposition

| Evidence | Disposition |
| --- | --- |
| Live release/tag metadata, official docs, pinned Caddy source | READ and compared |
| Current Gaoxy source and existing test contracts | READ and compared |
| Independent research of Caddy server defaults and Gaoxy option flow | Completed |
| Independent Caddy source/semantics review | Completed; H2/H3 idle and copy-buffer wording clarified |
| Architecture and implementation-plan review | Completed; shared WS driver and H2 lease-size estimator audit included; no remaining reported findings |
| Caddy runtime or comparative benchmark | NOT RUN |
| Fresh Gaoxy network reproduction | NOT RUN |
| Product implementation and its regressions | NOT STARTED |

Raw research downloads are retained under ignored
`.audit/research-caddy-2026-10-24/`; source links above make the findings
reviewable without that local directory. They are research evidence rather
than a new product acceptance record.
