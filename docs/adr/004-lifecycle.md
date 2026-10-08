# ADR 004: Backend-specific pause and one drain deadline

Expose UDP admission-only pause and TCP/TLS unbind/rebind pause explicitly.
Retain admitted I/O until one absolute deadline, then force cleanup. Port-zero
TCP/TLS resume can change its port. Generation-scoped identities, watchdog tokens
and monitors reject stale work. Explicitly removed dynamic children stay stopped.
QUIC local-host cleanup will not be labeled full protocol drain.
