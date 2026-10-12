# Gaoxy Implementation Plan

**Reviewed execution update, 2026-10-11:** The former http_fetch#97 proof
requirement is dismissed and must not be revived or replaced by equivalent gates.
Preserve historical evidence and assertions. Release the verified native H1/H2
and dedicated-H1 gateway beta subset as v0.2.0, disclosing unimplemented upstream
pools and upstream H2. Integration, push, tagging and GitHub standalone release
are authorized. Prepare M4's design/plan. Vault, disabled release-artifact E2E,
deployment, production data, operational certificates and public management
restrictions remain. See [ADR007](docs/adr/007-m3-beta-and-m4.md).

**Date:** 2026-10-08  
**Status:** Architecture and execution plan; not an implementation or acceptance report  
**Initial execution scope (historical kickoff):** M0 + M1, the transport-runtime foundation
**Companion:** `codex-prompt.md`

**Current execution authorization (renewed 2026-10-12):** Execute M4 and continue through
the existing milestone plan after each stage passes its prescribed verification
and independent review. Automatically choose recommended designs, write stage
designs/plans, implement, repair, document, test, review, and commit locally;
routine per-action and per-stage approval is no longer required. Necessary
compatibility fixes and test/documentation updates are authorized beyond older
file lists. Historical M0/M1 stop rules below apply only to the kickoff.
Product scope and explicit Vault, E2E, publication/deployment, and production
data restrictions remain in force. See `AGENTS.md` for the continuing workflow.
The 2026-10-11 instruction to prepare M4's design/plan is superseded by this
explicit implementation start; retain that dated release disposition as history.
Full M4 acceptance includes the remaining upstream-H3 proxy matrix and explicit
standalone H3 opt-in, following their bounded written designs and verification.

**Conditional publication authorization, 2026-10-12:** After M4 completes its
required verification and independent review, integrate main, push to GitHub,
publish a new version and prepare the next planned stage. An incomplete/blocked
gate is not completion. Deployment, production data/certificates, Vault, public
management and disabled release-artifact E2E restrictions remain.

## 1. Product and success criteria

Gaoxy is an Elixir/OTP multi-protocol server runtime, native HTTP server, and programmable proxy gateway. It must support embedded use in an application's supervision tree and standalone use as a release, with the same service model and data paths.

The intended product supports UDP unicast, IPv4 broadcast, IPv4/IPv6 multicast, TCP, TLS over TCP, and QUIC applications. Above these transports it provides custom protocol services, HTTP/1.1, HTTP/2, HTTP/3, WebSocket, local Plug/Phoenix endpoints, HTTP reverse and forward proxies, and raw socket relays.

The first useful integrated application milestone is one Gaoxy instance serving a real Phoenix application, a local/remote HTTP route table, and independent TCP and UDP services. The first implementation milestone is smaller: establish a tested transport runtime on which that application can be built.

**Architecture decision:** combine Abyss and Thousand Island through supported adapters; do not merge their source trees. Gaoxy owns service orchestration, its public contracts, HTTP server behavior, proxy policy, and Phoenix integration. Abyss remains a UDP/QUIC hosting foundation. Protocol implementations such as DNS, DHCP, DoQ, HTTP/3, and QPACK do not belong in Abyss.

**Bandit replacement means native execution:** serving a Plug through Bandit under a Gaoxy supervisor is not completion of Gaoxy's HTTP server. Bandit can be a reference peer or explicitly labeled development fixture, but is not the default production HTTP backend in this plan.

## 2. Evidence baseline and mandatory dependency audit

The following observations come from source/documentation inspected on the date above. They are discovery inputs, not proof that a release, platform, or feature is production-ready. Re-read the selected revisions during M0.

| Area | Observed boundary | Implementation consequence |
|---|---|---|
| Abyss ordinary UDP | Current documentation describes separate broadcast/multicast transports, runtime membership APIs, admission limits, shared-socket ownership, and pause/drain behavior. [R1] | Reuse and test these APIs. Do not assume broadcast/multicast still need to be invented. Preserve platform/backend restrictions. |
| Abyss persistent dispatcher | The documented dispatcher is opt-in and unavailable in broadcast mode; writer admission and local completion are different, with explicit unknown outcomes. [R2] | Do not configure the dispatcher indiscriminately for all datagram modes or retry an uncertain send. |
| Abyss QUIC hosting | The documented public host is `Abyss.QUIC`, with application handlers and opaque connection/stream handles. Its supported host subset has explicit limitations. [R3] | Use the host, not an endpoint-private adapter or a duplicate CID registry. Verify lifecycle and capability support separately. |
| Current QUIC/TLS package ownership | The HTTP Fetch umbrella lists `ex_ssl`, `elixir_quic`, `http_core`, `http_runtime`, and `elixir_quic_http3`; public facades include `SSL`, `Quic`, and `QuicHttp3`. [R4, R5] | Historical repository names such as `ex_quic` do not establish the package or module name to depend on now. Record the authoritative source and resolved artifacts. |
| TCP TLS client evidence | The existing TLS consumer contract primarily validates clients. It does not establish Thousand Island server-side transport compatibility. [R6] | Audit listen/accept/handshake and ownership separately before enabling an `ex_ssl` server adapter. |
| Thousand Island | Its documented `Transport` behaviour supports custom transport implementations. [R7] | Use a formal adapter and contract tests; do not patch dependency internals. |
| Plug and WebSock | Plug defines a server adapter contract; inspected WebSockAdapter code explicitly dispatches supported adapter modules. [R8, R9] | Native HTTP must implement the Plug contract. Phoenix WebSocket support requires a real WebSockAdapter integration path. |

Abyss documentation currently distinguishes the QUIC host's supported subset from broader engine capabilities. The HTTP umbrella may report a capability that the Abyss host does not expose. Neither report alone establishes Gaoxy support. [R3, R5]

Create `docs/dependency-audit.md` with the repository, commit, package name, OTP application, public namespace, selected version, source/artifact provenance, platform requirements, license, relevant APIs, tests run, and remaining gaps. Distinguish a Git commit from a file blob SHA. Commit a reproducible lockfile; use explicit source overrides only for development or dependency repair.

Inspect server/client roles before reusing `http_core`, `http_runtime`, or `elixir_quic_http3`. A client session owner is not a server runtime. Reuse public role-neutral codecs or server-capable engines when the contract is verified; avoid copying mature protocol machinery merely to create a new namespace. Conversely, do not depend on private client state to avoid implementing a proper server boundary.

Choose and record a tested Elixir/OTP baseline from the actual dependency intersection. Target Linux/NixOS deployment and macOS development. A dependency's declared minimum version is not a tested Gaoxy support claim.

## 3. Repository and application boundaries

Use one umbrella repository with the following logical applications:

| Application | Owns | Allowed internal dependencies |
|---|---|---|
| `gaoxy` | Service/listener specifications, runtime supervision, lifecycle, capabilities, admission, telemetry, transport/handler bridges | None of the other Gaoxy applications |
| `gaoxy_http` | Native HTTP server, WebSocket, Plug adapter, Phoenix adapter, HTTP route/endpoint contracts | `gaoxy` |
| `gaoxy_http3` (M4, optional) | Native HTTP/3 server over the public QUIC host and role-neutral H3/QPACK codecs | `gaoxy`, `gaoxy_http` |
| `gaoxy_proxy` | HTTP upstream client integration, reverse/forward proxy policies, stream/datagram relays, upstream pools | `gaoxy`, `gaoxy_http` |
| `gaoxy_server` | Standalone release, data-only configuration loader, validation commands, later management interface | Applications above, as needed; explicit H3 opt-in |

`gaoxy_http` defines an extensible HTTP endpoint/action contract. A proxy endpoint implements it in `gaoxy_proxy`; the HTTP application must not depend back on the proxy application.

The core must remain usable without Plug, Phoenix, Bandit, `http_fetch`, or a QUIC engine being installed or started. Optional transport support must not force unrelated applications into ordinary TCP/UDP consumers. Verify this in an external consumer project, not only inside the umbrella. If optional dependencies or compile-time behaviour references undermine isolation, add a thin optional integration package rather than weakening the boundary.

Suggested repository organization:

```text
apps/gaoxy/
apps/gaoxy_http/
apps/gaoxy_proxy/
apps/gaoxy_server/
docs/architecture.md
docs/dependency-audit.md
docs/capabilities.md
docs/implementation-status.md
docs/adr/
docs/acceptance/
examples/mixed_transports/
examples/phoenix_native/          # M2
examples/reverse_proxy/           # M2/M3
integration/network/
```

During M1, create compile-clean application boundaries but implement only the real foundation. Empty future applications must not export working-looking placeholders or appear as supported capabilities. Keep example applications outside the production dependency graph. Preserve existing repository conventions if a Gaoxy checkout already exists.

## 4. Runtime model and public contracts

### 4.1 Separate transport semantics

Define three handler families, not one universal socket abstraction:

| Family | Unit of application work | Required distinctions |
|---|---|---|
| Datagram | One complete UDP datagram | Peer versus destination metadata; empty payload versus no message; local admission versus delivery; optional application association |
| Stream | An ordered byte stream over TCP/TLS | Arbitrary read fragmentation; write backpressure; EOF; directional shutdown where the provider supports it |
| QUIC | A connection containing directional streams | Connection versus stream state; stream open/readable/writable; FIN/reset/stop; engine flow control and uncertain operations |

Gaoxy-created module names such as `Gaoxy.DatagramHandler`, `Gaoxy.StreamHandler`, `Gaoxy.QUICHandler`, `Gaoxy.PlugAdapter`, and `Gaoxy.PhoenixAdapter` are **proposed new interfaces**, not existing dependency APIs. Finalize minimal callback contracts after the dependency audit and prove each with a small application.

Keep configuration validation, routing decisions, admission accounting, and protocol state transitions pure where practical. OTP processes own I/O, timers, supervision, and mutable resources. Do not introduce a process for every pure operation or a global request dispatcher.

### 4.2 Instance, service, and listener identities

An instance owns a set of named services. A listener owns a concrete bound endpoint and one root protocol dispatcher. An application protocol can route multiple logical services on that listener; HTTP host/path routing is the primary example.

Use stable service IDs scoped to the instance. Support multiple Gaoxy instances and the same handler module in multiple services. Avoid atom creation from configuration or network input. Permit runtime names through explicit OTP-compatible naming rather than forcing a global singleton.

A service specification records its ID, listener reference/specification, transport family, handler and options, limits, metadata requirements, and requested capabilities. A listener specification records address family, address, port, backend/provider, TLS/ALPN settings where relevant, and transport-specific options.

Do not equate a numeric port with a unique socket: TCP and UDP can have separate bindings. Reject conflicting ownership within the same transport/address space. Do not implicitly share a UDP socket between raw datagrams and QUIC or a TCP socket between arbitrary byte protocols and HTTP. Future protocol demultiplexing requires an explicit, bounded dispatcher. First-phase QUIC uses one application handler per host unless the selected public host proves otherwise.

### 4.3 Lifecycle and observability

Provide public operations for instance startup, validated service addition, removal/drain, service status, listener information, and capability discovery. Include pause/resume only with explicit backend semantics. Use `child_spec/1` and `start_link/1` for embedded use.

Represent lifecycle states such as `starting`, `ready`, `paused`, `draining`, `stopped`, and `failed`. A service is ready only after actual binding and required setup succeed. Distinguish requested port zero from the actual bound port.

Startup validates the whole initial plan before opening sockets. Prepare resources with rollback: failure must not leave orphan sockets, memberships, workers, or registry entries. Dynamic operations must return explicit errors and preserve unrelated running services.

Pause is not OS process suspension. Expose whether a backend can stop new admission while retaining its bind or must unbind. State what happens to queued datagrams and port-zero listeners on resume. Do not promise stable ephemeral endpoints after a backend rebind.

Drain uses one absolute deadline, not a fresh timeout at each cleanup step. Preserve existing work's required I/O while refusing new work when the backend supports this. QUIC shutdown that stops all ingress is not equivalent to a full protocol-level drain: ACKs and existing streams may still require reception. Report a narrower contract or request an upstream enhancement rather than claiming equivalence. A call timeout alone is not proof that a service has stopped.

Failure isolation is per service/listener and per connection/handler where applicable. A failed shared writer or QUIC endpoint may require that listener to fail closed. A failed UDP handler must never close the shared socket. Shutdown, restart, and late messages must not resurrect an intentionally removed service.

### 4.4 Effective capability reporting

Compute usable capabilities from the intersection of provider, host adapter, Gaoxy adapter, selected options, OS/backend, and completed acceptance evidence. Report configured capability separately from validation status.

Use statuses such as `supported`, `experimental`, `unsupported`, and `not_tested`, with a reason and evidence reference. Distinguish QUIC streams from unreliable QUIC DATAGRAM, generic QUIC from HTTP/3, TLS from mTLS, IPv4 from IPv6 multicast, and local drain from network-protocol drain.

Reject explicitly requested but unsupported behavior before activation where possible. No automatic fallback from QUIC to UDP/TCP, HTTP/3 to HTTP/2, or `ex_ssl` to OTP `:ssl`. Unsupported configuration must not be silently discarded.

### 4.5 Resource and error contracts

Every untrusted input path needs finite admission, retained-item and retained-byte limits, and relevant deadlines. Count in-flight work and pending handoffs, not only entries already processed by a queue owner. A bounded GenServer state does not bound its mailbox if callers can cast payloads without admission.

For streams, use read credit and bounded pending writes. For UDP, define drop/reject policy; receiver throttling is local overload control, not network backpressure. For QUIC, consume transport credit deliberately and preserve the backend's operation-reference semantics. Distinguish definitely rejected, admitted, locally completed, uncertain, and peer-delivered outcomes wherever the underlying contract makes that distinction. Never retry a potentially completed operation blindly.

Generation-tag all owned handles, reservations, and operation receipts. Use monitors and idempotent teardown so late completions cannot refund a newer generation or affect another service. Ensure callbacks run outside shared receiving/writing processes, and bound callback work without spawning an unbounded task stream.

Telemetry must be instance/service scoped, with bounded-cardinality metrics. Include lifecycle, admission rejection, active work, retained bytes, send outcomes, timeout, and drain results. Do not label metrics by arbitrary peer IPs, URLs, or stream IDs. Redact credentials and payloads. Describe which memory/kernel buffers a measurement does not cover.

## 5. Transport implementation requirements

### 5.1 TCP and TLS through Thousand Island

Implement a Gaoxy handler bridge and lifecycle adapter using supported Thousand Island APIs. Verify socket ownership transfer, connection startup errors, read/write behavior, timeouts, bounded callback work, and cleanup. Differentiate TCP EOF/half-close from TLS close behavior rather than forcing identical promises.

Use OTP `:ssl` as the foundation's explicit reference/default TLS-over-TCP provider. Provide an `ex_ssl` selection only after its server-side contract passes. This is a bootstrapping decision, not a removal of the custom TLS goal; QUIC has its own required TLS integration.

The custom TLS audit must cover listen, accept, handshake, controlling process, active/passive delivery, send/recv, shutdown, peer/local data, ALPN, certificate configuration, validation failures, and all callbacks required by the selected Thousand Island version. Client test success is insufficient. Unsupported options or mTLS requests must fail explicitly. An explicitly selected provider never falls back to another provider. [R6, R7]

Use generated test certificates and independent validating clients. No real deployment private keys, disabled verification as a workaround, or automatic public certificate issuance.

### 5.2 UDP through Abyss

Map unicast, broadcast, and multicast to their actual public transports and host contracts. Keep shared socket ownership in Abyss. Build a capability-scoped Gaoxy send interface instead of handing user handlers unrestricted listener-close operations.

Support complete datagrams including empty payloads. Preserve actual peer and ancillary information. A wildcard socket address is not the packet's destination; unknown destination/interface metadata must remain unknown. A feature that requires unavailable metadata must be rejected or limited to concrete bindings. [R1, R10]

Expose membership management as explicit operations on an endpoint: list, join, and leave group/interface pairs. Preserve desired state across restart only when the underlying operation succeeds. Test duplicate operations, interface failures, family mismatches, bind rollback, and finite membership limits.

IPv4 broadcast and multicast are separate configuration modes. IPv6 broadcast is invalid. Treat membership selection, outgoing interface selection, and IPv6 scope as different properties. Do not guess subnet broadcast addresses, fake scope IDs, deduplicate payloads, or rely on `reuseport` to provide correct multicast fan-out.

Test configured hop/TTL and loopback behavior using a prepared network fixture. Preserve backend limitations, including explicit unsupported results for unverified IPv6 or strict-group-filter options. Runtime membership success is not evidence of wire-level interface isolation. [R1]

M1 must include real IPv4 unicast, broadcast, and multicast paths. Linux IPv6 multicast is a separate explicit gate. A missing runner capability is `NOT RUN`, not a passed test or a justification to remove the feature from the roadmap.

### 5.3 QUIC through the verified Abyss host

Use `Abyss.QUIC` and its public handler/facade after M0 verifies the selected artifact. The engine remains the single authority for connection IDs, cryptographic state, recovery, flow control, and stream records. Gaoxy owns only application/service state. [R3, R5, R14]

The initial integration is a bounded, explicitly experimental generic stream service with an application-specific ALPN and independent peer test. Preserve opaque handles, stream direction, FIN/reset/stop, admission failure, uncertain outcomes, and connection-close isolation. One failed connection cannot close the listener.

Do not advertise DATAGRAM, mTLS, migration, 0-RTT, HTTP/3, or WebTransport merely because an engine exposes related methods. Full connection migration and CID-aware passthrough need their own work. Do not bypass private host seams to enable a feature the public host does not support.

Ordinary core consumers must work without QUIC dependencies. An explicit QUIC configuration with no usable engine must return a meaningful startup error.

## 6. Native HTTP, Plug, and Phoenix work

### 6.1 HTTP server implementation strategy

During M0, write a short reuse ADR covering existing public codecs, any role-neutral `http_core` components, and Bandit reference tests/implementation. Gaoxy must own its server lifecycle and public adapter even when a verified lower-level library supplies codecs. Any reused source needs license/provenance records and retained notices. Never copy Bandit modules wholesale or rely on its private transports without an explicit architectural decision.

Use a shared HTTP request/response abstraction over independent H1, H2, and H3 wire engines. Keep application dispatch separate from protocol connection ownership. Do not route requests through loopback HTTP to call a local Plug.

H1 work includes incremental framing, request-target forms, bounded headers/body reads, keep-alive, chunked handling, bodyless responses, informational responses, connection closure, and a strict policy for ambiguous framing. Test fragmentation and request-smuggling cases before enabling proxy use. [R11]

H2 work includes SETTINGS, frame limits, HPACK state, stream lifecycle, connection/stream windows, cancellation, GOAWAY, and fair bounded multiplexing. Test h2 over TLS separately from any supported h2c mode. H2 server success does not establish WebSocket extended-CONNECT support. [R12]

H3 requires its own application/control streams, SETTINGS, error handling, QPACK profile, and shutdown behavior above QUIC. Audit `QuicHttp3` for a supported server role before reuse. A static/literal QPACK profile can be an explicitly documented initial subset; never advertise unsupported dynamic capacity. Basic QUIC stream exchange is not H3 acceptance. [R5, R13]

### 6.2 Plug adapter

Implement all mandatory callbacks of the pinned Plug version and the useful optional callbacks, with contract-correct unsupported results. Cover request body reads, ordinary/chunked/file responses, HTTP version, peer/local/TLS information, informational responses, and upgrades. Verify already-sent and error paths. A successful Plug call returning bytes is not sufficient adapter coverage. [R8]

### 6.3 Phoenix and WebSock compatibility

Implement `Gaoxy.PhoenixAdapter` against the pinned Phoenix Endpoint contract: child specs, HTTP/HTTPS configuration, bound server information, code reload integration, and shutdown ownership. Support an Endpoint-managed embedded listener first. Gateway-managed mounting of an Endpoint must have explicit ownership and must not start a duplicate listener.

Implement the WebSock server lifecycle and resolve WebSockAdapter's dispatch integration. Prefer an upstream-supported registration or adapter addition. If unavailable, use a minimal reviewed fork pinned by commit, with a patch and removal plan. Do not redefine `WebSockAdapter`, impersonate `Bandit.Adapter`, or mutate fetched dependencies. [R9]

Native Phoenix acceptance requires browser/network tests of a regular page, LiveView interaction, Channels, upload, static content, streaming/SSE, development reload, reconnect, and graceful shutdown. Plug.ConnTest and LiveView unit tests alone do not exercise the real server. H1 WebSocket support is the initial requirement; H2/H3 WebSocket upgrades have separate capability gates.

## 7. Routing, proxy, and standalone work

### 7.1 Local/remote HTTP routing

Compile host/path/method matching into a deterministic immutable route generation. A route targets a local Plug/Endpoint or a proxy endpoint through the same HTTP extension contract. Document precedence, header mutation order, authority/SNI policy, and request-target normalization. Enforce explicit routing policy rather than trusting client-supplied forwarding headers.

### 7.2 HTTP reverse proxy

Use a narrow upstream-client behaviour. Evaluate the public `http_fetch` streaming API first, including demand, cancellation, trailers, connection reuse, TLS verification, and uncertain operations. Add missing primitives at the appropriate upstream boundary, not by reaching into private connection processes.

Maintain bounded streaming both directions; never collect arbitrary request/response bodies. Cover early upstream responses during upload, downstream disconnect, slow peers, SSE, WebSocket tunneling, duplicate response headers, compression transparency, hop-by-hop header removal, and trailers. Do not forward transfer framing unchanged between different HTTP versions.

Add upstream groups, verified HTTPS, load balancing, health checks, timeouts, and explicit replay rules. Default to no automatic request replay. Retry only when the failure point, method/policy, body replayability, and response commitment make it safe. Do not automatically follow redirects for reverse proxy requests.

### 7.3 Forward proxy and socket relays

Separate HTTP forward proxy/CONNECT from reverse-proxy configuration. Require explicit authentication/access policy and destination allow rules. Validate resolved destinations at connection time, including IPv6 and mapped forms; control loopback, private, link-local, metadata-service, and management endpoints. Do not ship an open proxy.

TCP relay requires bounded duplex transfer and tested half-close. TLS termination, verified upstream TLS, and opaque TLS passthrough are distinct modes. Optional SNI inspection needs bounded parsing and must not claim visibility where unavailable. PROXY protocol acceptance is limited to explicitly trusted listeners/peers.

UDP relay retains datagram boundaries, bounds associations and bytes, expires state, validates return sources, and separates association policy from protocol-specific transaction IDs. Broadcast/multicast relaying is opt-in with explicit ingress/egress scope and loop/amplification controls; it is not a generic transparent multicast router.

QUIC passthrough requires defined CID/affinity behavior and migration limitations. QUIC termination plus upstream reconnection is an application proxy with independent connection state. HTTP/3-to-HTTP/2 translation occurs at HTTP semantics, not by forwarding stream IDs. SOCKS5 is an optional later protocol, not another name for raw TCP proxying.

### 7.4 Standalone release and configuration

The release instantiates the same runtime as embedded consumers. Begin with a versioned, data-only configuration format and a validation command. Resolve named handler types through an allowlist/registry; no atom creation or code evaluation from external configuration. Keep trusted embedded Elixir specifications distinct from external data.

Configuration updates validate, prepare, and then activate a new generation. Routes may switch atomically while in-flight requests retain the old generation. Same-port listener replacement is not automatically transactional: preserve stable socket owners, use supported handoff, or document a controlled disruption. Roll back failed preparation.

Use explicit certificate provisioning first; add atomic certificate rotation and SNI selection when tested. ACME/automatic HTTPS is a later feature, not implied by the phrase “Caddy-like.” Management HTTP is disabled by default and requires an explicit trusted/authenticated exposure model when added. M1 does not need a UI or public admin listener.

## 8. Work packages and milestone gates

| Milestone | Work packages | Completion gate |
|---|---|---|
| **M0: Audit and bootstrap** | Repository inspection, dependency lock/provenance, capability map, architecture ADRs, umbrella/dev/CI setup | Reproducible compilation; source-backed backend contracts; actionable gaps; no false support claims |
| **M1: Runtime foundation** | Instance/service model, TCP/TLS bridge, UDP modes/memberships, lifecycle/admission/telemetry, mixed-service example, release smoke; optional verified custom-TLS/QUIC slice | Actual network exchanges, multi-instance isolation, failure/overload/cleanup tests, external core consumer, explicit platform evidence |
| **M2: Native application server** | H1, WebSocket/WebSock, Plug/Phoenix adapters, native Phoenix fixture, local/remote routing, minimal streaming reverse proxy | Browser-tested native Phoenix plus local/proxy route selection and streaming; no Bandit runtime dependency |
| **M3: HTTP/2 and gateway beta** | H2, upstream pools, complete proxy controls, CONNECT, TCP/TLS/UDP relays, configuration generations, operational hardening | Interoperability, security, cancellation/slow-peer, relay semantics, reload and sustained-load gates |
| **M4: HTTP/3** | Verified QUIC host contract, server-side H3 engine/QPACK profile, Plug mapping, H3 upstream/downstream proxy matrix | Independent H3 peers, malformed control streams, flow control, stream reset, shutdown and browser acceptance |

These are evidence gates, not calendar estimates. QUIC host integration can progress alongside native HTTP; H3 depends on both relevant boundaries. A custom TLS gap must not block ordinary TCP/UDP work, and a general runtime gap must not be hidden by advancing to more protocols.

### M1 execution order

1. Inspect the working tree and relevant instructions. Create `gaoxy` in the intended location without overwriting existing work. Record the source/release matrix before selecting dependencies.
2. Bootstrap the umbrella and reproducible development environment. Keep Nix/devenv support small and avoid machine-specific paths. Establish the unit/loopback test path and an external core-consumer fixture.
3. Implement pure configuration validation, instance-scoped identity, service supervision, status, capability records, and startup rollback. Test invalid specifications without opening sockets.
4. Implement real TCP and reference TLS services through Thousand Island, including failure isolation and lifecycle translation.
5. Implement real UDP unicast, IPv4 broadcast/multicast, membership operations, and admission through Abyss. Add platform-specific IPv6 coverage without hiding unsupported paths.
6. Add shared generation-safe lifecycle, bounded resource accounting, and telemetry; prove that slow handlers or blocked sends cannot monopolize unrelated services.
7. Audit and, when independently testable, implement opt-in `ex_ssl` server and generic QUIC adapters. Otherwise record precise upstream blockers and capability errors; do not build a substitute protocol stack.
8. Deliver a mixed-transport example, standalone release smoke, network fixture, documentation, and truthful acceptance report. Stop at M1 rather than adding partial HTTP stubs.

## 9. Test design and completion criteria

### 9.1 Evidence classes

Use `PASS`, `FAIL`, `NOT RUN`, and `BLOCKED` for execution records. Separate unit/fake-backend tests, loopback network tests, independent peer tests, isolated multi-interface tests, and load/soak tests. A skipped or empty suite cannot satisfy a required gate. Preserve test counts, commands, versions, exit codes, and logs.

A Linux network-namespace/veth fixture should contain broadcast/multicast tests and clean up its own resources with a trap. Require explicit opt-in privileges and unique names. Never change the host's ordinary routes, firewall, DHCP service, or physical-interface broadcast traffic. macOS tests should report unsupported backend features honestly rather than emulate passing results.

### 9.2 Foundation acceptance matrix

| Gate | Required evidence |
|---|---|
| CORE-01 | Two runtime instances with overlapping service IDs and identical handler modules operate independently |
| CORE-02 | Invalid configuration/bind/initialization failure leaves no leaked listener, child, membership, or registration |
| CORE-03 | Real listener info exposes actual ephemeral ports; documented pause/resume behavior matches each backend |
| CORE-04 | Explicit removal stays removed; crash restarts and stale generation/timer messages are handled correctly |
| TCP-01 | Independent client sends fragmented input and receives correct output through the Gaoxy bridge |
| TLS-01 | Validating independent TLS client succeeds; invalid credentials/policy fail without provider fallback |
| UDP-01 | Unicast retains datagram boundaries, empty payloads, and oversize rejection behavior |
| UDP-02 | IPv4 broadcast exchanges on an isolated interface; multiple senders and an unrelated service remain isolated |
| UDP-03 | IPv4 multicast join/leave/rejoin, multiple groups/interfaces, TTL/loopback, and membership limits are tested |
| UDP-04 | Linux IPv6 group/scope/hop behavior passes its dedicated gate, or is explicitly BLOCKED/NOT RUN; IPv6 broadcast is rejected |
| LIFE-01 | An admitted UDP worker can reply without owning/closing the listener; pause/drain and deadline cleanup are real |
| LOAD-01 | Sustained overload keeps application-retained work within stated limits; rejection does not spawn unbounded tasks |
| LOAD-02 | Blocked writes and slow/crashing callbacks do not block unrelated services; uncertain outcomes are not retried |
| PKG-01 | External core-only consumer compiles/runs without Phoenix, Plug, Bandit, http_fetch, or QUIC activation |
| REL-01 | Standalone mixed-transport release starts, reports readiness, exchanges traffic, and stops cleanly |
| OPT-TLS | Optional custom TLS server contract is independently tested, or remains explicitly unsupported/experimental |
| OPT-QUIC | Optional custom-ALPN QUIC stream exchange and close isolation are independently tested, with host limitations recorded |

M1's required portable/IPv4 foundation gates must pass before it is called complete. IPv6 and optional provider/QUIC gates have separate status; they may remain incomplete without erasing the delivered foundation, but the corresponding feature must not be advertised as accepted. Network prerequisites missing from the local environment require a runnable dedicated gate, not a fabricated PASS.

### 9.3 Later hardening

Add property/model tests for configuration, admission conservation, generation changes, parsing, and cancellation. Maintain malformed-input corpora and independent HTTP/WebSocket/QUIC peers. Run browser-based Phoenix tests, not only in-process tests. Benchmarks record environment, concurrency, payload distribution, throughput, tail latency, retained memory, and drops; do not invent equivalence to Bandit or Caddy from small local measurements.

No beta/release claim follows from compilation alone. No full protocol conformance or security-audit claim follows from selected happy-path peers.

## 10. Deliverables, guardrails, and handoff

Initial deliverables are working M0/M1 code, automated tests, a mixed-transport example, reproducible dependency/environment records, architecture/capability documentation, and `docs/acceptance/m1.md`. Write concise ADRs for composition rather than source merger, transport-specific handler families, TLS defaults, HTTP reuse, dependency isolation, and lifecycle semantics.

Do not patch `deps/`, use private dependency messages, duplicate CID registries, store payloads in unbounded mailboxes, create phantom capability implementations, or silently switch providers. Do not add DNS/DHCP/HTTP protocol implementations to Abyss.

If a shared-library fix is necessary, identify the repository, public contract, reproducer, regression test, and minimal change. Work in an explicitly available dependency checkout/worktree; otherwise deliver an unapplied patch or a focused follow-up specification. Do not edit unrelated repositories, publish packages, push commits, create remote repositories, deploy services, or issue certificates without separate authorization.

The Codex handoff must distinguish completed code from planned work, actual test results from configured CI, and portable gates from platform-specific gates. When blocked, preserve tested progress and identify the smallest next dependency action. Do not end the task by asking the user to choose architecture decisions already settled here.

## References

These references identify the inspected interfaces and protocol sources; refresh the selected dependency revisions during M0. Version numbers inside upstream documents may be historical examples rather than the version to adopt. Requirements elsewhere in this document are Gaoxy design requirements, not claims that the referenced libraries already implement them.

- **R1 — Abyss UDP broadcast/multicast contract:** `https://github.com/gsmlg-dev/abyss/blob/main/docs/udp-broadcast-multicast.md`
- **R2 — Abyss dispatcher/writer contract:** `https://github.com/gsmlg-dev/abyss/blob/main/docs/dispatcher.md`
- **R3 — Abyss general QUIC service:** `https://github.com/gsmlg-dev/abyss/blob/main/docs/quic-service.md`
- **R4 — HTTP Fetch umbrella package layout:** `https://github.com/gsmlg-dev/http_fetch/blob/main/mix.exs`
- **R5 — QUIC/HTTP package and consumer boundaries:** `https://github.com/gsmlg-dev/http_fetch/blob/main/docs/ex-quic-consumer-contract.md`
- **R6 — TLS consumer contract:** `https://github.com/gsmlg-dev/http_fetch/blob/main/docs/ex-ssl-consumer-contract.md`
- **R7 — Thousand Island transport behaviour:** `https://hexdocs.pm/thousand_island/ThousandIsland.Transport.html`
- **R8 — Plug server adapter contract:** `https://hexdocs.pm/plug/Plug.Conn.Adapter.html`
- **R9 — WebSockAdapter source:** `https://github.com/phoenixframework/websock_adapter/blob/main/lib/websock_adapter.ex`
- **R10 — OTP UDP API:** `https://www.erlang.org/doc/apps/kernel/gen_udp.html`
- **R11 — HTTP/1.1 framing and connection management:** `https://www.rfc-editor.org/rfc/rfc9112.html`
- **R12 — HTTP/2:** `https://www.rfc-editor.org/rfc/rfc9113.html`
- **R13 — HTTP/3:** `https://www.rfc-editor.org/rfc/rfc9114.html`
- **R14 — QUIC transport:** `https://www.rfc-editor.org/rfc/rfc9000.html`
