# Pre-capture native terminal telemetry SPEC1

Task: `native_worker_constructor_spec/browser_terminal_telemetry_spec1`

**DONE — public telemetry is suitable for safe pre-capture connection PID/span and error/exception evidence, with explicit coverage limits.** It does not always contain an exact process exit reason or remote/local closure distinction. This is source-only investigation; no diagnostic/browser/runtime/test/Git/network command was run.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Git baseline was not inspected because assignment forbids Git; reviewed sources are SHA256-bound below. Parent-reported Diagnostic3 failure remains FAIL: selected1 then early EOF before host capture, source direction absent. This review did not read the saved result or any raw trace archive and makes no new runtime claim. Cause remains **UNKNOWN**, including whether Chrome abandoned the socket.

## Emitting PID and phase are available before capture

`Gaoxy.HTTP.Connection` uses `ThousandIsland.Handler` (`connection.ex:3`). The generated handler receives `:thousand_island_ready` in the actual native connection GenServer, calls transport peername, and emits connection:start inside that process (`handler.ex:360–389`). Span creation is **before TLS handshake**, which then returns either handshake error or emits connection:ready; Gaoxy's `handle_connection` runs later through a continuation (`handler.ex:391–398,441–450`). Thus start/ready can identify this connection before native-accounting instrumentation, and ready means transport/TLS setup completed, not that Gaoxy H2 startup or any request capture completed. Start contains remote address/port plus span/parent references and handler. ready contains only handler/span metadata and monotonic timing. Correlate ready by span and emitting PID rather than assuming remote fields are repeated.

Public `:telemetry.attach_many/4` callback runs synchronously in the event-dispatching process: documented at `deps/telemetry/src/telemetry.erl:69–72` and implemented by direct callback call at197–202. Therefore **callback `self()` is the actual emitting connection PID** for these start/ready/stop/exception sites. Capture it inside callback before sending a projected event to a recorder; `self()` in the recorder would be the recorder PID. TI constructs a span reference at start and preserves that reference across lifecycle events (`telemetry.ex:391–429,434–476`). Connection metadata has no built-in PID field, so add `emitter_pid: self()` as diagnostic evidence. No private client process, socket state, sys-state query, or dependency patch is needed.

## Exact minimal event whitelist

Attach only these four public events, with callback guard `metadata.handler == Gaoxy.HTTP.Connection`:

- `[:thousand_island, :connection, :start]`
- `[:thousand_island, :connection, :ready]`
- `[:thousand_island, :connection, :stop]`
- `[:thousand_island, :connection, :exception]`

Register a unique owned handler before starting the native service/browser and assert attach returns `:ok`. Use an exported callback function capture with minimal fixture config containing only recorder PID/case ID. Callback must be small, total and nonblocking: construct a new bounded whitelist projection and send it to an owned recorder. Do not write files, inspect raw metadata, query processes/sockets, wait for recorder acknowledgments, or change connection behavior in the synchronous callback. Record before/after handler lifetime and detach only after actor shutdown plus finite recorder drain/join. Enforce a small event/count bound and fail on recording loss/overflow; no missing terminal event becomes success. A recorder may monitor a received start PID, but an asynchronous late monitor can get `:noproc` after death; it cannot recover the original reason.

Do **not** attach broad all-events or listener events. Listener start metadata includes `transport_options`, potentially TLS key/cert material (`listener.ex:33–39`). Data-bearing `async_recv`, recv/send/send_error/sendfile events can contain full request/response bytes and must remain excluded. No `Map.take` followed by arbitrary `inspect` of error/reason/stacktrace is safe.

## Safe bounded projection

Create a fresh map; copy only fields after exact type/shape checks:

- Event suffix from the fixed whitelist; diagnostic case ID; callback `self()` PID; own observation monotonic time; `telemetry_span_context` and, when present, `parent_telemetry_span_context`, only reference identities. Store scalar PID/reference text or recorder-generated IDs, never serialize referenced process state.
- `handler` only the expected constant module.
- On start and terminal events, remote IPv4/IPv6 tuple validated as loopback and numeric remote_port0..65535. This is the relay backend's local endpoint, **not Chrome's frontend endpoint**. Add that backend ephemeral endpoint to the relay's scalar selected event if cross-process correlation is needed; do not infer socket identity from timing alone. Exact native backend listener ready port remains separate fixture config.
- Measurements: copy only integer `monotonic_time`, `system_time`, `duration`, `send_oct`, `send_cnt`, `recv_oct`, `recv_cnt` when present; counters/duration nonnegative, monotonic time may legitimately be negative and remains native units. Missing optional socket stats stay missing, not zero. Preserve an explicit field-presence indicator.
- stop: separate `error_present = Map.has_key?(metadata,:error)` from safe projected error class. Never map missing error to `:normal`, `:peer_closed` or nil/error interchangeably.
- exception: allow `kind` only from `[:error,:throw,:exit]`. Project reason with the same bounded classifier below. Omit raw stacktrace; at most record stacktrace_present and a bounded **arity-only** MFA projection (validate `{module,function,arity,location}` with atom module/function and integer arity; if args list replaces arity, never log/traverse args, emit omitted-frame marker). No Exception.message/format or source paths/line contents are needed.

Recommended reason classifier is deny-by-default. Retain exact values only for a finite literal safe atom allowlist relevant to this path, e.g. `:timeout,:closed,:econnreset,:enotconn,:normal,:shutdown,:peer_closed,:local_closed,:unsupported_protocol,:inadequate_security,:overloaded,:draining`. For a known `{:tls_alert,{alert_atom,description}}` shape, retain only a finite allowlisted alert atom and `description_omitted:true` (or omit whole reason if alert not allowlisted); never description bytes. For known wrappers such as `{:shutdown,inner}` or `{:handshake,inner}`, preserve only the literal wrapper tag and recursively project inner with a hard small depth cap. For an exception struct, retain only allowlisted exception module/type if useful; omit all fields/message. Every unrecognized atom/tuple/map/list/binary/port/function receives a fixed omitted-type marker; optional tuple arity/byte length is scalar, but do not recurse arbitrary terms, hash raw terms, call inspect, or serialize unknown state. Unknown projection remains an observability limit and may require a later narrowly reviewed classifier extension, never a guessed cause.

A callback failure removes the telemetry handler and emits `[telemetry,handler,failure]` (`telemetry.erl:197–218`); it may also log callback failure details. Keep callback/config incapable of carrying raw TLS/state data. If a separate failure sentinel is used, attach **only** that event with a guard for this exact handler ID and project fixed event ID/kind/failure flag, omitting handler_config/reason/stacktrace. Recorder completeness/failure is required diagnostic validity, never permission to continue as PASS.

## Actual terminal shapes and ambiguity

| Native path | Public connection terminal evidence | Limit |
| --- | --- | --- |
| TLS handshake returns `{:error,reason}` | start, no ready, stop with metadata.error=raw reason | Error is unwrapped: stop metadata does not separately tag handshake phase. Preserve ready absence and source location; project reason safely. |
| Handle connection/data raises, throws or exits | exception with kind/reason/stacktrace and original start metadata | Event emitted before re-raise; stop suppressed by per-span marker, so do not require both. |
| Handler returns `{:error,:timeout,state}` or read timeout | stop error `:timeout` | Process reason is usually wrapped read_timeout; stop is not exact process DOWN. |
| Other returned/socket error | stop error actual reason (or projected known wrapper) | `:ssl_error`/`:tcp_error` reasons may be arbitrary. |
| Peer closed, local close, orderly shutdown | stop with **no error key** for all three | Cannot distinguish peer_closed/local_closed/shutdown; absence is not remote closure proof. |
| Direct `{:stop,:normal,...}` | stop error `:normal` in this implementation | Normal process exit is not absence of error metadata. |

Evidence: `handler.ex:416–429,455–508,543–562,630–638,678–691`; `telemetry.ex:434–476`. `do_socket_close` deliberately omits error for `[:shutdown,:local_closed,:peer_closed]`, and telemetry exception markers suppress subsequent stop. For exact benign process terminal reasons, retain existing authentic monitor/exit instrumentation where it is established; telemetry alone is insufficient. If pre-start exact exit reason is necessary, that requires separately reviewed public exit observation, not interpretation of an absent error key. Do not replace existing terminal assertions with telemetry.

Coverage gaps: peername failure occurs before start/span creation (`handler.ex:365–375,455–456`); child start/ownership-transfer failure occurs before handler ready; brutal kill/terminate-callback failure may bypass terminal telemetry. Missing start/stop/exception therefore stays **UNKNOWN**, not proof of healthy closure. Optional future acceptor spawn_error capture would identify a different emitter and use measurements.error in current source; do not confuse acceptor PID with connection PID or expand whitelist silently.

## Verification and ownership

Read-only scoped source/docs/tests were inspected; upstream tests were read, not run. One bounded search included absent `deps/thousand_island/guides`, yielding exit2 while other requested paths were searched; this is a search mismatch, not runtime/test failure. All commands completed. No source/evidence/repository edit, process launch, raw archive read, Git or network operation. Only this `/tmp` report was created. Dependency TI already documents these supported events; no upstream defect or feature gap is established.

Locked TI: `mtrudel/thousand_island` ref `6146e1bfdd1a85c5c16c3c92ad98ff5f11066820`; telemetry Hex1.4.2. Current counters preserved: group37/root47/stage7; Astra2of2 exhausted; diagnostic failures3 parent-reported; this review adds0 runtime attempts/failedGREEN/Sol repairs. All assertion strength remains unchanged. Current stage remains OPEN and early terminal cause **UNKNOWN**.

Reviewed SHA256 identities:

- `deps/thousand_island/lib/thousand_island/telemetry.ex`: `8e7736459dc13c902e95e9e7eb666245ef379c084a7eed6e2a28cd743ff5b483`
- `deps/thousand_island/lib/thousand_island/handler.ex`: `baa63be02492beb348e11412fd4a8524a288ecdb1010f6f2c08df2e02f202319`
- `deps/thousand_island/lib/thousand_island/socket.ex`: `0dba5adf77da5d40e88f8b99286270af4c8009d3d97c1c03eccb0f1d0ab9c21a`
- `deps/thousand_island/lib/thousand_island/listener.ex`: `7d7a0d66551a252b89790f5e4607d18e41a8697b9b8755cea9a61c5fb7cf30ca`
- `deps/telemetry/src/telemetry.erl`: `8bb2a1fa116def38f63a5b36b65fdc9af98022e6e378e047f38d49b584564278`
- `apps/gaoxy_http/lib/gaoxy/http/connection.ex`: `d74a1ea9b35e996db51da5b698390afd3cdc5c47eb2c499d35c3af69de46d3f2`
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`: `586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52`
- `mix.lock`: `c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6`
