# Validated backend options

## Scope and dependency contracts

Expose backend tuning through embedded service maps, native HTTP/HTTP3,
ListenerSet and Phoenix. Preserve defaults and the existing `gaoxy_test` work.
No dependency changes, standalone JSON expansion, worktrees or publication.

Inspected baseline: `946e850472e9c6e95c3f8914a65b58531c852287`;
Hell 0.1.2 pinned at `59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`,
Abyss 0.9.0 and elixir_quic 0.21.14.

| Backend | Public API and effective tuning | Constraints |
|---|---|---|
| TCP/TLS | `Hell.start_link/1`: `num_acceptors`, `transport_options` | `num_connections` is per acceptor. TCP ignores handshake timeout. |
| UDP | `Abyss.start_link/1`: `udp_buffer_size`, `transport_options` | Listener forces receive/send buffers from `udp_buffer_size`, and fixes the application socket buffer at 65,536. Multiple listeners are not effective for every binding/mode. |
| QUIC | `Abyss.QUIC.start_link/1`: `poll_interval`, `event_batch` | The backend opens its UDP socket with fixed options; no public socket tuning entry point exists. |

Sources: Hell's `lib/hell.ex` and transport modules; Abyss's
`lib/abyss/listener.ex`, `listener_pool.ex`, `transport/udp/core.ex` and
`quic/service.ex` in the pinned dependencies. Inspecting accepted parameter
names alone is insufficient: several UDP socket values are overwritten.

## Configuration and ownership

Use keyword lists `hell_options` for TCP/TLS and `abyss_options` for UDP/QUIC.
A pure core normalizer validates the backend, option keys, duplicates and values
before startup. Forward only validated values through explicit construction;
never merge arbitrary user configuration into backend-owned arguments.

Expose a small supported subset: Hell acceptor count and ordinary socket
tuning; UDP buffer size and IPv4 TTL/TOS; QUIC polling and event batching.
Reject unsupported keys, transport-inapplicable keys and ownership overrides.
Retain `ip`, `port`, `tls`, `limits`, handlers, transport modules, process
options, listener topology and QUIC stream/engine budgets under Gaoxy control.
Resource and deadline aliases are deliberately rejected: callers use the
existing canonical fields rather than configuring two separate budgets.

Normalize QUIC's duplicate `poll_interval` surface into `quic.poll_interval`.
Matching explicit values are accepted; conflicting explicit values fail.
Keep backend options fixed across deferred activation. No options means the
same backend defaults and generated options as before this change.

HTTP has a narrower socket subset than generic core streams: reject `recbuf`
and `buffer`, because H1 and H2 protocol initialization deliberately replaces
them. Keep receive-buffer ownership in the existing HTTP limits/profile.
Reject duplicate top-level HTTP keyword entries before endpoint initialization,
matching the other entry points. These boundaries were confirmed during
independent review against the actual HTTP connection initialization code.

For Hell, permit at most `limits.max_active` acceptors and assign
`div(limits.max_active, num_acceptors)` connections per acceptor. This preserves
an aggregate backend ceiling at or below the existing budget, including
connections before application admission. A remainder is unused. The default
single acceptor retains the existing capacity. Gaoxy admission remains in force.

## Verification

Test invalid shapes/duplicates, backend mismatches, forbidden overrides,
conflicts, defaults and activation immutability. Start real TCP/TLS/UDP/QUIC
services and inspect effective settings/behavior. Exercise direct HTTP,
ListenerSet and Phoenix paths; retain finite cleanup and resource assertions.
Use installed OpenSSL 3 for the existing network fixture contract. Complete
scoped regressions, format checks, strict compilation and independent review.
