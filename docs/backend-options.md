# Backend service tuning

Embedded services accept validated keyword lists for their actual backend:
`hell_options` on TCP/TLS and `abyss_options` on UDP/QUIC. Unknown keys,
duplicates, invalid values and nonempty options for another backend fail
before a listener starts. These are supported subsets of the pinned backend
APIs; arbitrary Hell, Abyss or OTP options are not accepted.

| Transport | Entry | Supported options |
|---|---|---|
| Core TCP / OTP TLS | `hell_options` | `num_acceptors`; `transport_options: [backlog: ..., nodelay: ..., keepalive: ..., recbuf: ..., sndbuf: ..., buffer: ..., tos: ...]` |
| HTTP / HTTPS, including ListenerSet and Phoenix | `hell_options` | Same subset, excluding `recbuf` and `buffer`, which the HTTP protocol owns |
| UDP, all existing modes | `abyss_options` | `udp_buffer_size`; `transport_options: [tos: ..., ttl: ...]` |
| QUIC / HTTP3 | `abyss_options` | `event_batch`, `poll_interval` |

TCP/TLS buffer sizes and backlog, and UDP `udp_buffer_size`, accept integers in
`1..2_147_483_647`. `nodelay` and `keepalive` are booleans. TOS and TTL accept
integers in `0..255` on IPv4 only. OS support and kernel buffer limits still
apply: requested buffer sizes may be rounded or clamped. An OS rejection is a
startup error, without fallback to a different configuration.

HTTP rejects backend `recbuf` and `buffer` before endpoint initialization.
For H1, the protocol derives these receive buffers from
`http_limits.max_buffer_bytes`; H2 and mixed-protocol listeners use the existing
qualified receive-buffer profile. This prevents listener tuning from being
accepted and then silently overwritten when a connection starts. Core stream
services retain both options.

`num_acceptors` accepts `1..min(64, connection_capacity)`. The independent
64-acceptor safety ceiling does not limit the connection quota to 64.
`connection_capacity` is `limits.max_connections` (16,384 when omitted),
intersected with an explicitly configured legacy `max_active` cap. An omitted
`max_active` does not impose the old 64-lease admission cap.

Each acceptor receives `div(connection_capacity, num_acceptors)` backend
connection slots; a remainder is unused and every acceptor has nonzero capacity.
For example, 4 acceptors with `max_connections: 64` each get 16 slots, while 3
acceptors each get 21. Request and stream quotas are separate. Shared memory
admission and explicit service transport/ordinary-lease caps remain in force.

UDP `udp_buffer_size` sets both receive and send socket buffers. Its backend
default is retained when omitted. Separate UDP `recbuf`, `sndbuf` and `buffer`
options are rejected: Abyss 0.9.0 overwrites them internally. Its application
socket buffer remains fixed at 65,536 bytes. Listener count is reserved because
Abyss forces a single listener for some bindings and modes.

QUIC `event_batch` accepts `1..128`; the backend default is 32. `poll_interval`
accepts `1..1000` milliseconds and defaults to the existing 10 ms. It is
normalized into the core service's `quic.poll_interval`. An explicitly supplied
canonical value must match; a conflict is an error. Abyss.QUIC 0.9.0 has no
public UDP socket tuning API, so QUIC rejects `transport_options`,
`udp_buffer_size`, acceptor and listener counts. QUIC stream/engine/writer
options are reserved to preserve Gaoxy's resource controls.

## Relationships with existing fields

Continue to configure binding with `ip` and `port`, TLS policy and credentials
with `tls` (or the existing HTTPS listener keys), and resource/deadline controls
with `limits`. Backend entries cannot override handlers, handler options,
transport modules, process/supervisor options, socket family, active mode,
packet framing, port sharing, credentials, ALPN or listener topology.

Backend resource/deadline aliases such as `num_connections`, `max_connections`,
`read_timeout`, `handshake_timeout`, `send_timeout` and `shutdown_timeout` are
rejected inside backend options. Use `limits.max_connections`, `limits.idle_timeout`,
`limits.callback_timeout` and `limits.drain_timeout` respectively. A duplicate
binding or TLS field is rejected even if equal. The only accepted duplicate
surface is QUIC `poll_interval`, which uses the conflict rule above.

Instance memory policy belongs in top-level `resource_budget` on a ListenerSet
or Phoenix Endpoint, not in backend options or each physical listener. Omission
uses one shared VM pool with a soft limit at 50% of effective physical/cgroup
capacity and hard at twice soft; detection fallback is 256/512 MiB. Explicit
instance thresholds are ordered and undoubled. An explicit service `max_bytes`
remains a transport/cleanup hard cap excluding WebSocket retention, which shared
memory accounting includes. Explicit `max_active` caps ordinary leases including
writers/workers, excluding cleanup and nonlegacy post-worker stream retention.
Finite socket/QUIC bounds never grow to match detected host memory.

Omitting both entries preserves existing defaults. Backend options are fixed
parts of a deferred service plan and cannot change during activation.
This API does not add corresponding fields to standalone JSON configuration.

## Embedded examples

For a core TCP service:

```elixir
%{
  id: :echo,
  transport: :tcp,
  handler: MyApp.Echo,
  ip: {127, 0, 0, 1},
  port: 4001,
  limits: %{max_connections: 64},
  hell_options: [
    num_acceptors: 4,
    transport_options: [backlog: 2048, nodelay: true, keepalive: true]
  ]
}
```

For a UDP service, add
`abyss_options: [udp_buffer_size: 262_144, transport_options: [ttl: 32]]`
to its service map. For core QUIC, use
`abyss_options: [event_batch: 16, poll_interval: 5]` alongside the existing
QUIC credentials and ALPN configuration.

Direct HTTP and HTTP3 listeners use the same keyword entries:

```elixir
{Gaoxy.HTTP,
 plug: {MyApp.Plug, []},
 hell_options: [num_acceptors: 4, transport_options: [backlog: 2048]]}

{Gaoxy.HTTP.HTTP3,
 plug: {MyApp.Plug, []},
 tls: %{certfile: "/run/tls/cert.pem", keyfile: "/run/tls/key.pem"},
 abyss_options: [event_batch: 16, poll_interval: 5]}
```

For ListenerSet and Phoenix, put `hell_options` inside each `http` or `https`
listener and `abyss_options` inside the `http3` listener. They are per-listener
configuration, not options on the logical ListenerSet or Endpoint itself.
See the [Bandit migration example](phoenix.md#backend-tuning-migration).
