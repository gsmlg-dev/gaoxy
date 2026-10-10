# Transport-runtime architecture

Gaoxy composes Thousand Island for TCP/OTP TLS and Abyss for datagrams. Its
immutable validated plan precedes binding. Each instance owns a service supervisor
and specification table; Registry keys include an opaque instance identity and
service ID. Each service owns one backend, its admission/watchdog process and a
fresh generation. No instance process participates in packet or connection data
handling.

The service supervisor restarts abnormal failures. Explicit removal drains, confirms
owned-resource termination and stops the transient child normally, so intentional
stops do not restart. Normal parent shutdown dispatches concurrent service barriers
under one shared deadline before stopping that supervisor. Backend
startup failure closes already-started siblings. The instance monitors its
starter during preparation and links only after successful activation so bind
errors return as errors while parent death still cleans resources.

Stream callbacks receive ordered byte chunks, keep application state and return
continue/send/close/error actions. The connection owner performs I/O. Callback,
send and retained-state bounds are enforced independently of idle timeout.
Datagram callbacks receive one complete packet including zero bytes, preserve
actual peer/local/ancillary data, and return a bounded reply or addressed send.
IPv6 link-local/multicast sends require an explicit scope; the bridge rejects
family mismatches and multicast destinations outside multicast mode before I/O.
They receive no
shared listener socket or close operation. Callbacks execute outside shared
listener processes; backend admission precedes the Gaoxy watchdog ledger.

Generation references and owner monitors protect work accounting and teardown.
The control ledger receives counts and byte sizes, never payloads. Rejection
creates no task or retry queue. Stream receive credit and UDP active-once ingress
limit socket-to-process delivery. Current counters bound bridge-retained payloads
and stream state, not arbitrary callback allocations, all transient binaries or
kernel buffers. A packet temporarily occupies its full receive binary before
oversize rejection; a backend start reservation is separately bounded.

UDP pause retains the socket/memberships and stops admission. TCP/TLS pause
unbinds/rebinds acceptance while existing streams retain I/O. Drain establishes
one absolute deadline. Ordinary UDP backend stop owns admission cleanup;
stream drain waits for existing leases before backend shutdown. At expiry host
cleanup is forced and confirmed; a caller deadline reports uncertainty if that
confirmation is still pending. Registry owner loss triggers bounded reconciliation
of both lifecycle and telemetry keys, then fail-closed teardown on expiry. See
[ADR 004](adr/004-lifecycle.md) for results and outer shutdown budgets. No pause uses `:sys.suspend`. Optional QUIC cannot inherit
these guarantees because stopping its ingress prevents protocol progress.

`gaoxy_http` owns native HTTP/1 and WebSocket codecs, Plug/Phoenix adapters and the
HTTP endpoint extension contract; it depends on `gaoxy` but never on `gaoxy_proxy`.
Native TCP/TLS handlers preserve Service/Admission ownership and admit each new
request against the lifecycle barrier. WebSocket upgrade retains the connection
owner and establishes one bounded protocol lifetime. See
[ADR 006](adr/006-native-http.md) and [native HTTP limits](native-http.md).
`gaoxy_proxy` implements HTTP streaming and message-level WebSocket endpoints over that
contract. Its application supervises temporary session guardians outside the
per-instance forced-cleanup subtree. Service serializes attachment with drain;
Admission charges an independent reservation against the original connection
lease. Cleanup succeeds only after an authenticated receipt and normal guardian
DOWN, following public HTTP RequestCompletion confirmation or upstream WebSocket
PID termination. Gate, connection,
service and instance death independently trigger cancellation. Failed guardians
fail admission closed; deadline expiry retains cleanup-pending semantics.

`gaoxy_server` owns versioned JSON loading, a fixed handler allowlist and release
startup using the same runtime. Its `prep_stop` drains the embedded instance. No
management server is added. HTTP Fetch/WebSocket 0.19.0 fixes #27–#30, #38, #45
and #60. HTTP uploads and raw ACK responses stream with finite deadlines, fixed
authority, verified TLS and no replay. Native connection polling retains input
and detects idle downstream closure. The complete raw-target gate remains blocked
on #64 (a present empty query is lost). The proxy package transitively
installs QUIC/TLS engines while standalone core consumers retain isolation;
dependency presence implies no H2/H3 support. See [the dependency audit](m2-dependency-audit.md).

HTTP capacity is reserved before activation using explicit client socket buffers
and the inspected OTP 28.5.0.5 receive path; the qualified default `:inet` backend
and SSL active-N settings must remain stable. The reservation includes bounded
receive/parser/copy windows, not all BEAM or kernel memory. See
[HTTP proxy limits](http-proxy.md).

## Optional generic QUIC

The ordinary core dependency graph contains no QUIC/TLS engine. An opt-in
consumer explicitly installs locked `elixir_quic` and `ex_ssl` 0.17.0. Gaoxy
selects the public `Abyss.QUIC` host, retains engine-owned opaque connection and
stream generations, and adds a separate `Gaoxy.QUICHandler` callback family.
The facade wraps native handles with the service admission lease; reads and
writes are bounded to the configured packet/output limit and at most 16KiB.
Application state is checked separately from output bytes borrowed during I/O.
The same generated operation reference is passed to the engine and used in
Gaoxy send telemetry. A native accepted write is recorded as admitted, never
as locally completed or delivered; unknown outcomes are returned without retry.

QUIC TLS credentials use certificate DER chains and typed private-key DER,
decoded from the consumer's PEM files. TCP TLS provider selection is rejected
on this path. QUIC pause/resume and full protocol drain are unavailable: info
reports `pause: :unsupported` and `drain: :local_host_cleanup`; stronger requested
capabilities fail validation. IPv6 and wildcard QUIC binds, DATAGRAM, migration,
mTLS, 0-RTT, HTTP/3 and WebTransport remain unsupported. Acceptance status and
peer/version evidence belong in `acceptance/m1.md`, not in engine feature claims.
