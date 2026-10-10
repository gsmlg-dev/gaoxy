# M3 Task 6: bounded UDP unicast associations

Date: 2026-10-10. Architecture only; implementation and runtime acceptance are
not established. Worktree: `.trees/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4`. Scope: the public Abyss dispatcher
adapter and persistent UDP unicast relay already required by M3. No broadcast,
multicast, QUIC passthrough, transaction-ID interpretation, or dependency changes.

## Decision and source evidence

Use one public Abyss dispatcher per Gaoxy listener, one application controller,
and one temporary worker/connected upstream socket per admitted downstream peer.
Keep the existing per-datagram `Gaoxy.DatagramBridge` unchanged. Choose explicit
queue admission in Gaoxy; the Abyss writer's bounds do not bound application
ingress mailboxes. Do not create a replacement UDP listener or access its socket.

Alternatives: extending the existing one-packet handler cannot receive arbitrary
later responses from the original listener port; exposing the shared socket
would violate ownership. The public dispatcher capability supports both without
a dependency workaround.

Installed `deps/abyss` HEAD and `mix.lock` both select
`gsmlg-dev/abyss@9b710e6480900e16e304f40e63623aff8c922e19` (manifest version
0.7.0). Audited files:

| Source | Observed contract and consequence |
| --- | --- |
| `deps/abyss/docs/dispatcher.md` | Public dispatcher, send capability, bounded writer admission/receipts, unknown outcomes; applications own ingress limits |
| `lib/abyss/datagram_dispatcher.ex`, `Abyss.DatagramDispatcher` | `init/2`, `handle_datagram/4`, optional `terminate/2`; no application `handle_info` or drain callback |
| Same file, `Abyss.Dispatcher.init/1` and `handle_call/3` | Init context supplies `local_info`, `generation`, `send`, `send_fun`; datagram context supplies `local` (dispatcher PID), `generation`, `send`, `send_fun`, `routes`, `state`, and available ancillary/local metadata |
| Same file, `register/5` | `{:new, keys, pid, state}` / `{:route, keys, pid, state}` register and monitor routes only. They do not forward the datagram |
| `lib/abyss/listener.ex` and `listener_starter.ex` | One active receive credit, one pending packet, and one synchronous dispatcher invocation; listener does not rearm while that invocation is pending |
| `Listener.complete_drain/1` | Dispatcher is killed and socket closed without waiting for application associations; host drain is not association drain |
| `apps/gaoxy/lib/gaoxy/service.ex` | UDP starts one Abyss listener; existing pause preserves bind; Service owns gate, generation and teardown |
| `apps/gaoxy/lib/gaoxy/lifecycle.ex` | Current UDP drain calls `Abyss.stop` immediately; adapter-specific sequencing is necessary |
| `apps/gaoxy/lib/gaoxy/admission.ex` | Leases belong to the acquiring PID, bytes include in-flight reservations, and release follows owner death; another PID cannot update that lease |

**No external dependency blocker identified for this design.** The missing core
adapter, lifecycle sequencing and input admission are Gaoxy work. Existing
HTTP Fetch issues #66/#67 do not block UDP. Runtime tests may expose a dependency
defect; route that precise failure under AGENTS.md rather than bypass its API.

## Core API and adapter boundary

Add `handler_mode: :datagram_dispatcher`, valid only with `transport: :udp` and
`mode: :unicast`. Default mode and legacy handler validation stay unchanged.
Introduce the following small Gaoxy behaviour, implemented by
`Gaoxy.Proxy.UDPRelay`; the implementation's owner is a GenServer:

```elixir
@callback validate_options(term()) :: {:ok, term()} | {:error, term()}
@callback validate_service(options :: term(), service_spec :: map()) ::
  {:ok, term()} | {:error, term()}
@callback prepare_service(options :: term(), service_spec :: map()) ::
  {:ok, term()} | {:error, term()}
# Optional runtime preflight, bounded by Service before binding.
@callback start_link(context :: map(), options :: term()) ::
  {:ok, pid()} | {:error, term()}
@callback offer(owner :: pid(), packet :: map()) ::
  {:ok, association_pid :: pid()} | {:error, term()}
@callback control(owner :: pid(), :pause | :resume, service_generation :: reference()) ::
  :ok | {:error, term()}
@callback drain(owner :: pid(), absolute_deadline :: integer()) ::
  :ok | {:error, term()}
```

`validate_options/1` is pure, strict and idempotent on normalized output.
`validate_service/2` is also pure and idempotent; Config invokes it once the
core limits and dispatcher writer limits are normalized, before binding. This
minimal integration callback derives reservations and rejects a budget that
cannot hold the infrastructure, one worker and one maximum ingress packet.
Core defaults remain unchanged. Maximum-size UDP relay tests explicitly use a
4 MiB service budget; the default 1 MiB budget can require a smaller packet or
writer window and does not promise admission of even one maximum-size worker.
The optional `prepare_service/2` runtime callback is a separate prebind step:
Service bounds it by the callback deadline. UDP queries public
`:inet.getifaddrs/0` once, retains at most 64 IPv4 interface/netmask pairs, and
rejects query failure and known local directed-broadcast binds/upstreams.
The pure directed-broadcast helper is tested with /30 and /25 vectors; an
address ending in `.255` is not automatically a broadcast. Preflight repeats
for a new service generation. It performs no OS network mutation.
Core checks these exports before binding. `offer/2` executes in the one Abyss
dispatcher caller, but uses the control-only reservation/payload protocol below;
it must not send the whole packet in a bare GenServer.call. `drain/2` returns
`:ok` only when workers and receipts are settled. It does not terminate the
controller or free the shared-writer reservation while the host remains alive.

New internal `Gaoxy.DatagramDispatcherBridge` implements the exact Abyss ABI:

```elixir
init(abyss_context, gaoxy: service_context)
# Calls spec.handler.start_link(merged_context, spec.handler_options).
# Returns {:ok, %{owner: pid, module: module, context: bounded_context}}.
handle_datagram(remote, bytes, received_at, abyss_context)
# Calls module.offer(owner, packet).
# Success: {:new | :route, [peer_key], association_pid, bridge_state}
# Rejection: {:drop, reason, bridge_state}
terminate(reason, bridge_state)
# Best-effort owner notification; owner also monitors the dispatcher.
```

The merged context contains the existing Gaoxy `spec`, `gate`, `scope`,
`service`, `instance`, plus `dispatcher: self()`, Abyss generation,
`local_info`, and the unmodified send capability. Preserve two distinct
generations: service generation and Abyss writer generation. The packet contains
`peer`, `data`, `received_at`, concrete `local`, both generations, and bounded
available ancillary metadata. Do not promise original destination/interface
metadata not supplied by the provider. No packet keys become atoms dynamically.
The trusted bridge also supplies the configured handoff budget in each packet;
the caller's one deadline includes the control lookup, reservation and payload
submission. Permits store an absolute expiration clipped to that deadline,
which is checked on submission independently of timer delivery order.

Actual Abyss options are:

```elixir
datagram_dispatcher: {Gaoxy.DatagramDispatcherBridge, gaoxy: context},
dispatcher_max_queue: writer_max_items,
dispatcher_max_queue_bytes: writer_max_bytes,
num_listeners: 1,
max_packet_size: spec.limits.max_packet
```

Retain existing transport, listener, timeout and telemetry options. The unused
legacy `handler_module: Gaoxy.DatagramBridge` remains valid if Abyss requires it;
dispatch selects the new path. Keep internal dispatcher configuration separate
from raw `spec.udp` socket options. Use a strict core `dispatcher` options map
with `max_queue`, `max_bytes` and finite `handoff_timeout`; do not forward arbitrary
dependency options or permit external module names.

During bridge init, send a generation/token-tagged owner-ready message to Service
after controller initialization. The startup token is created by Service and
passed through context. After `Abyss.start_link` returns, Service consumes that
exact bounded handshake, monitors the owner, and only then marks the service
ready. Do not synchronously call Service from a callback during Service.init.
Failure/timeout rolls back owner and host. Ignore stale handshakes from prior
starts; never attach a controller to a new service generation.
Bridge owner startup runs under a finite callback deadline with inherited
service ancestry. Its temporary startup helper transfers the owner to the
dispatcher monitor and Service's explicit root before exiting. Startup failure
consumes the exact tagged readiness message to clean any initialized owner.
Include the registered controller as an explicit root in Service's owned-resource
census and forced teardown, alongside the backend. A dead dispatcher can break
the link path from the backend before cleanup takes its snapshot; do not rely
on traversing that path to rediscover the controller. Monitor readiness and owner
death independently, without following arbitrary application links.

## Ownership and fixed limits

- Abyss owns the bound downstream UDP socket and its independent writer.
- Controller owns association admission/queues, a per-service worker supervisor,
  and service-wide metadata/reservations. It never performs socket I/O or waits
  for a datagram receipt in its receive loop.
- Each temporary association worker owns one connected OTP UDP upstream socket,
  its own Gaoxy lease, rate/response credits, timers and at most one downstream
  send receipt. One worker failure closes only its socket/association.
- Workers are children of the controller's DynamicSupervisor, with bounded
  startup and no automatic association restart. They monitor the controller and
  dispatcher. Controller monitors dispatcher, worker supervisor and workers;
  termination cannot leave sockets alive because the dispatcher disappeared.
- All these children inherit the service ancestry so existing bounded forced
  cleanup can identify them without inspecting private Abyss process state.

Initial relay limits are explicit and validated:

| Resource | Initial limit |
| --- | ---: |
| Associations, including starting/closing | 256, further limited by service `max_active` |
| Ingress queued/reserved per association | 8 datagrams / 65,536 bytes |
| One packet | 65,507 bytes, also bounded by service packet/output limits |
| Worker upstream receive credit | One full datagram |
| Worker downstream receipt | One submitted datagram |
| Shared downstream writer | 32 items / 262,144 bytes |
| Idle / absolute association lifetime | 30 s / 300 s |
| Reservation lifetime / total handoff deadline | 100 ms / 50 ms |
| Socket send and receipt settlement deadline | 1 s, clipped to association/service deadline |
| Drain response grace | 200 ms of inactivity, clipped to service deadline |
| Per-association egress rate | 64 datagrams/s and 65,536 charged bytes/s |
| Default return/input ratio | 1 packet and 1 charged byte per received input packet/byte |

Count an empty datagram as one item and one charged byte for admission/rate/
ratio limits while retaining its zero-byte wire payload. Ratios may be explicitly
configured to finite positive values (cap 16); burst credits are finite and
earned from ingress, never granted merely by creating a new association.
The maximum aggregate egress rate is bounded by admitted associations times the
configured per-association rate; publish this sizing rule.

The controller acquires one infrastructure lease before the host can receive.
It reserves fixed ingress-copy allowance (at least four maximum packets),
shared-writer queued/in-flight allowance including copies, bounded route/result
metadata, and its dynamic reserved/queued application bytes. Each worker acquires
its own lease before opening a socket, reserving its fixed receive/transmit/
handoff windows and state. Controller counters count queued bytes until worker
acknowledgment, overlapping the worker's fixed reservation conservatively.
Do not refund a submitted downstream datagram's host reservation when its caller
dies: the controller's fixed shared-writer reserve lasts until host teardown.

Expose a pure reservation calculation in the relay options validator, derive
the supported association maximum from `max_active`/`max_bytes`, and reject
configurations unable to admit the controller plus one worker and one maximum
datagram. Keep core defaults unchanged. The 256 association setting is an upper
bound, not a promise that the default 1 MiB service budget can admit 256 workers.
Document payload/copy bounds separately from process/OTP/kernel memory.

## Admission before mailbox payloads

The native ingress chain already retains at most one pending datagram between
listener, starter and dispatcher. Gaoxy's fixed ingress reservation covers those
copies; do not claim the existing per-packet legacy Admission path runs here.

`UDPRelay.offer/2` performs these steps within one absolute handoff deadline:

1. Validate source, packet length and generation in the caller before queueing.
   Send `reserve(owner, operation_ref, peer_key, byte_count, generations)` with
   **no payload**. There is one authorized dispatcher producer, so at most one
   such control operation is outstanding per service.
2. Controller checks ready/paused/draining state, association count, per-peer
   item/byte limits and aggregate Gaoxy byte admission. It increments counters
   before replying with a one-use permit and association PID. For a new peer it
   allocates a starting slot and starts a bounded worker; worker init returns
   promptly and performs lease/socket setup in handle_continue. Queue the first
   packet under that starting slot; do not require UDP clients to resend it.
3. Caller sends the binary only with that permit. Controller validates sender,
   exact byte count, generation and unused permit before accepting it. Expired,
   duplicate and mismatched submissions are dropped, never refunded twice.
   Reservation timeout sends ordered cancellation using the caller-created
   operation_ref. Late reserve replies cannot leak capacity indefinitely.
4. Controller sends one packet to a ready worker at a time. The worker reports
   readiness only after service admission, socket initialization and reservation
   succeed; fixed worker windows cover the mailbox handoff. Worker acknowledgment
   releases the controller packet reservation and permits the next packet.

Use bounded permit records, a producer monitor and tokenized timers. A failed
start drops that association's queued packets and releases its counters after
worker termination is known. The controller remains responsive to other peers.
No unbounded casts, one task per packet, or polling snapshots of another
process's queue. Trusted embedded callbacks must follow this native contract;
hostile local BEAM processes are outside network admission guarantees.

## Association data path and send results

Key one association by `{service_generation, writer_generation, peer_ip,
peer_port}`. The controller owns the authoritative registry, including starting
and closing states. Abyss routes register the returned worker for automatic
route cleanup only; do not maintain conflicting routing policies in two places.
Worker DOWN removes only the matching PID/token. A late old DOWN cannot remove
the replacement for a reused peer tuple.

Configure one validated literal unicast upstream address/port for this first
slice; no per-packet destination, DNS lookup in dispatcher callbacks, transparent
multicast routing or HTTP authentication reuse. Worker opens
`:gen_udp.open(0, [:binary, active: false, ...])`, connects to that exact address,
sets a receive buffer large enough for one maximum datagram, then uses one
`active: :once` receive credit. It rearms only after its previous returned
datagram is processed/dropped and downstream admission permits progress.
Validate received address/port against the pinned upstream even on a connected
socket. Reject oversize packets; never silently forward a truncated payload.

An input packet causes one upstream datagram send preserving its boundaries and
empty payload. Use the supported OTP UDP API inside that association worker,
with a finite watchdog and no retries on uncertain completion. A blocked worker
cannot make the controller or other associations wait for its I/O. Its fixed
windows and one in-flight permit prevent growth while it is blocked.

For accepted return packets, enforce source, response credit and rate limits
before calling the public capability API:

```elixir
Abyss.Dispatcher.send(capability, downstream_peer, bytes, timeout)
# {:ok, send_ref} is admission, not completion.
Abyss.Dispatcher.Writer.await(capability.writer, capability, send_ref, timeout)
# {:ok, monotonic_microseconds} | {:error, reason} | {:unknown, send_ref}
```

`Writer.await/4` is explicitly documented in `deps/abyss/docs/dispatcher.md`.
Reading the supplied capability's writer field for this call is part of that
documented usage; no private writer/admission messages or state inspection.
`send_receipt/4` is also public but composes multiple waits. To honor an absolute
deadline, account for both reservation/submission waits inside `send/4` (each
uses its timeout), then recompute remaining time for receipt waits. Poll receipt
in finite intervals so worker processes drain, owner DOWN and expiry messages.
No per-packet receipt task is needed.

Classify `:queue_limit`, `:queue_bytes_limit`, stale capability and reservation
timeout as documented rejection; a submitted-call/receipt timeout is unknown,
not cancellation. Stop new work on that association and await the same reference
within the original finite settlement deadline. Never resubmit. Expired/evicted
`:unknown_send` cannot prove non-delivery. If uncertainty cannot be resolved,
report it and fail the relay service closed through the coordinator's bounded
host teardown; do not release/reuse uncertain capacity and continue indefinitely.
The host's completion-result cache is bounded; keep one outstanding receipt per
worker, bound waiters, and do not rely on cached results beyond the documented
five-second lifetime. A successful local socket receipt does not prove peer
delivery.

## Policy, expiry, pause and shutdown

Relay startup requires a nonempty ingress CIDR allowlist, fixed upstream literal,
explicit destination policy and finite rate/association limits. Require a
concrete unicast bind for this initial relay slice. Reject unspecified,
multicast, limited broadcast, known local directed-broadcast destinations and
scope-ambiguous link-local addresses. Normalize mapped IPv6 before rules.
Private/loopback/metadata/management targets require explicit narrow destination
exceptions; deny rules win. Source CIDR policy is a network access restriction,
not proof of UDP sender identity. Do not describe raw UDP as authenticated or
reflection-proof; earned response credits and rate caps bound its amplification.
Reuse pure address normalization/CIDR helpers where available without coupling
core to the HTTP proxy's principal/authentication contract.

Unexpected upstream sources, non-allowlisted ingress, expired generations,
oversize packets and exhausted queues/rate/ratio credits are dropped and counted.
They create no association and earn no additional response credit. Unknown
responses cannot extend idle time; only admitted, valid traffic does. Idle timer
messages include association generation and timer token, and an absolute
max-lifetime timer prevents perpetual resource retention.

Expiry first marks the association closing, revokes unused permits, and stops
new receives/sends; it settles already submitted operations under their existing
deadline, closes only its upstream socket, and waits for worker DOWN before
reuse. A datagram already admitted to the shared writer may complete after idle
expiry; that is permitted in-flight completion, not a new send. The capability
API provides no per-datagram cancellation guarantee. Do not promise that all
on-wire sends cease exactly at an association's expiry instant.
Unknown output marks the controller failed, rejects offers/control/drain, and
notifies Service while retaining its infrastructure lease until host teardown.
It cannot revive itself by changing from failed back to draining.

For pause, Service closes Gaoxy admission, asks the controller to stop new
offers through `control/3`, then uses public `Abyss.suspend` while retaining the bind. Already
admitted packets and returns may complete under their existing bounds. Resume
reopens the host and controller only for the current service generation; Service
commits admission reopening last. A failed/late transition cannot revive drain.
`control/3` checks the exact service generation and controller lifecycle state;
`:resume` while draining/failed is an error. Invoke control operations in the
existing bounded Service control worker, not a new unbounded synchronous wait
inside Service. Its deadline and operation token remain authoritative.

Implement a dispatcher-specific service drain, retaining the existing ordinary
UDP path:

1. Close admission with the existing barrier and suspend Abyss ingress. Tell the
   controller to seal its permits using the same absolute service deadline.
2. Controller cancels unused reservations, flushes already accepted bounded
   queues, and seals each worker after its final delivery. Worker receipt of the
   gate's earlier drain message does not discard valid pre-barrier deliveries;
   controller's ordered seal identifies the last one. Keep upstream receive
   credit only for the finite response-grace period and already admitted writes.
3. Workers settle receipts, stop their sockets and report DOWN. Controller's
   drain reply waits for workers/queues/permits to empty. It retains its fixed
   host reservation and remains alive; `active == 0` is therefore not the
   application-drained predicate.
4. Call public `Abyss.stop(backend, remaining_deadline)` only after application
   drain succeeds. Confirm host/resource termination. Stop controller and
   confirm its lease release. Deadline failure uses existing bounded force
   cleanup, records unknown local sends, and cannot report successful drain.

This is local best-effort UDP drain, not proof of application transactions or
remote responses. Responses arriving after grace/deadline are dropped. Grace
and every cleanup wait share the absolute service deadline. Controller death,
writer death, admission death or a lost ownership invariant fails this service
closed; unrelated services remain available. Normal host stop may kill the
dispatcher without calling callback terminate, so monitors and Service-owned
cleanup are mandatory rather than relying on that callback alone.

There is no live UDP policy/upstream reload in Task 6. Stable-listener HTTP
generation changes do not mutate existing UDP associations. Explicit UDP
configuration replacement drains/restarts the service; old generations,
permits, timer messages and capability references cannot create new work.
Same-peer late upstream packets are excluded by connected per-association
sockets and lifetime checks; after OS ephemeral-port reuse, generic UDP cannot
distinguish an arbitrarily delayed same-source payload from a current one.
Do not claim transaction-level freshness without a protocol-specific identifier.

## Bounded implementation order and acceptance

| Slice | Owned changes | Required scoped evidence |
| --- | --- | --- |
| U1 core adapter | New core behaviour/bridge, `Config`, `Service` startup/control/drain integration; no proxy dependency | Invalid mode/options fail before bind; handshake rollback; exact Abyss callbacks; legacy UDP unchanged; no socket export |
| U2 controller and admission | Proxy UDP relay options/controller/temporary worker supervisor | First packet retained during startup, per-peer/global overload, control-only reservation before payload, timeout/cancel/producer-death permit cleanup, no double refunds |
| U3 network data path | Association worker and receipt state | Independent UDP peer; multiple clients and instances, original listener source port, ordered per-client datagrams including empty/max-size, upstream source rejection, rate/ratio policy |
| U4 lifecycle | Adapter drain and worker/controller failure paths | Idle/lifetime races, stale timer/worker DOWN, pause stable ephemeral bind, delayed reply within grace, no late restart after removal, blocked/unknown writer, all owned sockets/processes/reservations gone by deadline |
| U5 isolation and reporting | Scoped core consumer and capability/docs changes | External core consumer still excludes Plug/HTTP Fetch/HPAX/QUIC; legacy unicast and relevant lifecycle tests remain green; capability states match independently executed gates |

Proposed focused files: `apps/gaoxy/test/datagram_dispatcher_test.exs`,
`apps/gaoxy_proxy/test/udp_relay_test.exs`, and the existing affected lifecycle/
configuration tests. Use the repository's scoped test commands after those files
exist; do not treat proposed paths or fake transport tests as executed evidence.
Use a deterministic blocking writer fixture and explicit barriers for receipt
and expiry races, plus independent OTP/Python UDP peers for actual source-port
and datagram behavior. No host firewall/routes, privileged namespaces, broad
multicast traffic, dependency patching, or unrelated test repairs are needed.

Core consumer impact is a new opt-in mode and supported callback facade only.
No new dependency, default behavior change, open proxy, public management
endpoint or production configuration is introduced. Tests/compilation were
NOT RUN in this architecture-only assignment. The source audit establishes a
supported design path, not implementation correctness or UDP beta acceptance.
