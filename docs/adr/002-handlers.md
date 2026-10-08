# ADR 002: Preserve transport-specific semantics

Streams and datagrams have separate behaviours. Stream state spans arbitrary
deliveries; an empty datagram is still a packet. Optional QUIC will preserve
connections, directional streams and engine events, rather than adapting them
to UDP payload callbacks. Callbacks execute in isolated admitted workers.
