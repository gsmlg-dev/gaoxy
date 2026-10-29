# Persistent WebSocket connections and data capacity

The native WebSock engine uses no default frame-size, message-size,
wire-fragment-count, callback-batch-count, inactivity or absolute-lifetime
ceiling. The Gaoxy WebSockAdapter dispatch preserves omitted size options.
Gaoxy 0.13.0 integrates H1/H2/H3 persistence using released transport APIs.
Hell 0.1.3 resolves [hell#2](https://github.com/gsmlg-dev/hell/issues/2) and
provides H2's public owner idle transition. See the
[qualification record](acceptance/internal-16-default-capacity.md) for executed
checks and publication evidence.

## Phoenix configuration

Phoenix applies a finite transport timeout before calling WebSockAdapter. Use
its supported socket configuration for persistent connections:

```elixir
socket "/socket", MyAppWeb.UserSocket,
  websocket: [timeout: :infinity],
  longpoll: false

socket "/live", Phoenix.LiveView.Socket,
  websocket: [timeout: :infinity, connect_info: [session: @session_options]],
  longpoll: false
```

Retain your actual session options and session plug. Origin, CSRF,
authentication, heartbeat and application close behavior remain application
policies. Existing Phoenix applications need this explicit integration setting;
Gaoxy cannot infer whether a finite timeout was inserted by Phoenix or selected
by the application. No frame or service-budget override is needed for the
ordinary large-render case.

## Reusable transport capacity and retained messages

An explicitly configured `limits.max_bytes` remains an undoubled aggregate
transport/cleanup hard cap. Finite protocol profiles constrain receive staging,
writer chunks, control state, queues and windows even when this administrator
cap is omitted. Consumed input and completed output return credits for subsequent
chunks and messages. Neither a transport profile nor this explicit cap is a
WebSocket payload ceiling or cumulative transfer allowance.

At upgrade, Admission classifies `transport_bytes` and `websocket_bytes`.
The latter measures retained messages, callback state, decoded input waiting for
dispatch and pending output. Generic service `max_bytes` and `max_state`, even
when explicitly configured, do not impose a ceiling on that retained WS data.
Shared memory accounting includes both categories, including WS retention.
Omitting `max_bytes` selects adaptive admission coordinated across listeners and
instances in the same BEAM VM: soft is 50% of effective physical/cgroup capacity,
hard is twice soft, with 256/512 MiB fallback. Usage through soft is normal;
above soft through hard warns while continuing admission, and projected growth
above hard is rejected. Explicit instance thresholds are not doubled. Committed
completion credits remain available to admitted work. Protocol, process and OOM
safety checks remain independent.

`Gaoxy.resource_budget(instance)` is the public monitoring contract for shared
usage, thresholds, counters and rejection reasons; adaptive runtime integration
and its ordinary verification remain in progress. Existing historical release
qualification above does not qualify this new policy.

WebSocket upgrade ends ordinary-request quota ownership, retaining connection
and H2/H3 stream ownership until their terminal boundaries. Explicit `max_active`
counts ordinary leases, including writers/workers, excluding cleanup and
nonlegacy post-worker stream retention. Separate service defaults are 16,384
connections, 65,536 requests and 65,536 streams; the old omitted 64-lease value
is not an administrator cap. Transport capacity remains finite and reusable.

The WebSock callback API still supplies a complete message. Its memory cost is
O(message + application state + pending output), with transient assembly copies;
finite staging does not bound total BEAM memory. Arbitrary external/PubSub
producers need their own bounded production policy.

## Deliberate application limits

A direct WebSock application can select finite policies:

```elixir
WebSockAdapter.upgrade(conn, MyWebSock, state,
  max_frame_size: 1024 * 1024,
  max_message_size: 64 * 1024,
  max_fragments: 128,
  timeout: 60_000,
  max_lifetime: 3_600_000
)
```

An explicitly selected frame limit also supplies an omitted message limit.
An explicit message limit is independent. Phoenix exposes `max_frame_size` on
its socket configuration; it does not accept Gaoxy's `max_message_size` option.
Configured incoming size violations still close with 1009. Mandatory masking,
UTF-8, fragmentation ordering, valid lengths and the RFC control-frame maximum
of 125 bytes always apply.

Callback computation defaults to 5 seconds and normal close to 1 second.
The callback watchdog ends when its retained result is installed, before any
output transmission. Each bounded send has its own finite operation deadline;
no callback or send deadline covers an entire progressing message or batch.
Application close, protocol failure, actual transport loss and finite service
drain remain valid termination events.

H1 uses the supported infinite Hell read timeout after default upgrade. H3
uses the released QUIC disabled local idle policy and bounded public PING
operations below a finite peer-negotiated idle period while WS ownership exists.
Empty ordinary H3 connections retain a finite owner idle policy; active ordinary
requests retain their existing finite request and operation deadlines. Hell
0.1.3 provides the public owner-side idle transition used by H2 to suspend
connection idle while WebSocket ownership exists and restore the original
ordinary idle interval after the final WebSocket closes. Finite partial-frame
assembly and explicit application lifetime deadlines remain effective. The separately configured
message-level `Gaoxy.Proxy.WebSocket` endpoint retains its own bridge policies;
this change adds no opaque proxy API.
