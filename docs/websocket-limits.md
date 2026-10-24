# Persistent WebSocket connections and data capacity

The native WebSock engine uses no default frame-size, message-size,
wire-fragment-count, callback-batch-count, inactivity or absolute-lifetime
ceiling. The Gaoxy WebSockAdapter dispatch preserves omitted size options.
This behavior is implemented on the current development branch; the complete
H1/H2/H3 persistence contract remains blocked by
[hell#2](https://github.com/gsmlg-dev/hell/issues/2). See the
[current qualification](acceptance/internal-16-default-capacity.md).

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

`limits.max_bytes` constrains finite transport reservations: receive staging,
writer chunks, protocol control state, queues and windows. Consumed input and
completed output return credits for subsequent chunks and messages. This value
is neither a WebSocket payload ceiling nor a cumulative transfer allowance.

At upgrade, Admission classifies `transport_bytes` and `websocket_bytes`.
The latter measures retained messages, callback state, decoded input waiting for
dispatch and pending output. Generic service `max_bytes` and `max_state`, even
when explicitly configured, do not impose a ceiling on that retained WS data.
Status reports both categories, their sum as `retained_bytes`, and high-water
values. Transport capacity remains finite and reusable.

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
requests retain their existing finite request and operation deadlines. H2 still
needs Hell's public owner-side idle transition before quiet persistence can be
qualified. The separately configured message-level `Gaoxy.Proxy.WebSocket`
endpoint retains its own bridge policies; this change adds no opaque proxy API.
