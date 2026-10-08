# Codex Kickoff Prompt — Gaoxy

You are implementing **Gaoxy**, an Elixir/OTP multi-protocol server runtime and gateway.

Read the companion `implement-plan.md` completely before changing code. If it is under `docs/`, use that copy. This prompt also contains the essential decisions so you can begin when the companion is provided as an attachment.

**Execute the work. Do not merely produce another architecture proposal, a skeleton, or a list of future tasks.** Your initial assignment is **M0 + M1: audit the dependencies, bootstrap the project, and deliver a working, tested transport-runtime foundation**. Implement native HTTP/Phoenix and full proxies in later milestones, not as incomplete additions to this kickoff.

## 1. Product direction and fixed architecture

Gaoxy will combine:

- Custom TCP/TLS and UDP unicast/broadcast/multicast services, plus generic QUIC applications.
- A native HTTP/1.1, HTTP/2, HTTP/3 and WebSocket server with Plug/Phoenix integration.
- Local Plug/Phoenix routing and remote HTTP reverse proxying, HTTP forward proxy/CONNECT, and raw TCP/TLS/UDP relays.
- Embedded OTP use and a standalone release sharing exactly the same runtime.

Compose **Thousand Island for TCP/TLS** and **Abyss for UDP/QUIC hosting**. Do not merge their source trees or make Abyss an HTTP server. Gaoxy owns its service model, lifecycle translation, protocol/application adapters, HTTP server, and proxy behavior.

Use the verified QUIC/TLS package identities. Inspected upstream documentation places `elixir_quic` (`Quic`), `ex_ssl` (`SSL`), and related HTTP packages inside the `gsmlg-dev/http_fetch` umbrella. `Abyss.QUIC` is the documented host integration. Verify the selected current revisions: do not assume the historical repository name `ex_quic` is still the dependency name or invent a `QUIC` module alias.

Bandit is a reference implementation/test fixture, not Gaoxy's hidden production HTTP backend. A future native Phoenix gate must work without a Bandit runtime dependency. Do not implement HTTP by forwarding local Plug requests through loopback networking.

## 2. Inspect safely and establish the dependency baseline

First inspect the working directory, Git status, existing files, repository instructions, and any existing Gaoxy implementation. Preserve uncommitted work. If this is an empty intended Gaoxy directory, initialize it in place. If the current directory is an unrelated populated repository, create a separate `gaoxy/` workspace rather than overwriting it. Do not create a remote repository, push, publish, or deploy.

Read these sources and relevant implementation/tests, using locally available checkouts or accessible upstream sources:

- `gsmlg-dev/abyss`: `mix.exs`, public startup/lifecycle APIs, `docs/udp-broadcast-multicast.md`, `docs/dispatcher.md`, `docs/quic-service.md`, relevant acceptance records and tests.
- `mtrudel/thousand_island`: public listener/handler/socket APIs and `ThousandIsland.Transport`.
- `gsmlg-dev/http_fetch`: package layout, `docs/ex-ssl-consumer-contract.md`, `docs/ex-quic-consumer-contract.md`, and applicable public TLS/QUIC APIs.
- For architectural preparation only: pinned Plug/Phoenix contracts, `phoenixframework/websock_adapter`, and any public role-neutral HTTP codecs proposed for later reuse.

The current Abyss UDP documentation describes actual multicast transports and membership APIs. Do not repeat an old assumption that all broadcast/multicast support is missing. Conversely, do not treat its documentation or existing test count as Gaoxy acceptance.

Create `docs/dependency-audit.md`. Record actual repository commit, package/application/module identities, resolved version/artifact, supported public contract, chosen OS/OTP/Elixir baseline, license, optional-dependency behavior, tests actually run, and gaps. Distinguish client support from server support and an engine feature from a feature exposed by its host.

Use a reproducible lockfile. Prefer reviewed compatible packages; use explicit pinned source dependencies where necessary. Do not edit `deps/`, depend on moving branches without a recorded resolution, or silently select a different implementation when one fails.

Do not spend the entire task auditing. Once the TCP/UDP contracts are understood, begin implementation. Isolate custom-TLS or QUIC gaps so they do not prevent ordinary transports from being delivered.

## 3. Establish application boundaries

Create or preserve the umbrella boundaries:

- `apps/gaoxy`: runtime, configuration, service/listener identity, capabilities, supervision, lifecycle, admission, telemetry, transport bridges.
- `apps/gaoxy_http`: future native HTTP/WebSocket/Plug/Phoenix implementation; depends on `gaoxy`.
- `apps/gaoxy_proxy`: future proxy policies, upstream integration and relays; depends on `gaoxy` and `gaoxy_http`.
- `apps/gaoxy_server`: standalone configuration/release entrypoint, using the same runtime.

Core TCP/UDP consumers must not require Plug, Phoenix, Bandit, http_fetch, or QUIC to be installed or started. Test this with a small **external consumer project**, not just the umbrella. Avoid compile-time references that accidentally make optional engines mandatory. Do not disable required runtime application startup with `runtime: false` to hide dependency problems.

Empty future applications may establish package boundaries, but must have no dummy public implementations, claimed capabilities, unnecessary dependencies, or success-returning placeholders. The HTTP application will define its endpoint extension contract; it must never depend back on `gaoxy_proxy`.

Add a minimal reproducible development setup appropriate for Linux/NixOS and macOS. Preserve existing Nix/devenv conventions where present. Do not add machine-specific paths or an elaborate environment framework unrelated to the milestone.

## 4. Implement the real foundation

### A. Configuration, identity, and supervision

Implement pure validation that produces an immutable runtime plan. Separate transport-specific options and reject unknown/unsupported requested behavior. Do not create atoms from untrusted input.

Define instance-scoped service IDs, listener specifications, handler configuration, requested capabilities, and finite resource limits. Support multiple instances and repeated handler modules without telemetry/registry collisions.

Expose a minimal coherent public API for embedded startup, validated service addition/removal, listener information, status, capabilities, and lifecycle operations. Proposed names are `Gaoxy.start_link/1` and `Gaoxy.child_spec/1`; design the remaining small API after reading the backends, and document it.

Validate initial configuration before opening sockets; roll back partial startup. Report the actual bound port when zero is requested. Reject conflicting socket ownership. TCP and UDP are distinct bindings; do not implicitly share sockets across unrelated protocols.

Each listener has one root protocol handler. Later HTTP routing can mount many services on one HTTP listener. Do not add speculative protocol sniffing, arbitrary TLS/HTTP multiplexing, or raw-UDP/QUIC demultiplexing now.

### B. Transport-specific handlers

Define small separate behaviours for datagrams, byte streams, and optional QUIC connection/stream events. Do not flatten these into a universal `handle_data` socket model.

Keep state transformations and policy decisions functional. Processes own I/O, timers, and supervision. Keep application callbacks outside shared listener/writer processes. Do not add a global GenServer to the packet/request path.

For datagrams, preserve one message per packet, including zero bytes. For streams, preserve bytes across arbitrary delivery boundaries. QUIC retains connection/stream hierarchy and directional FIN/reset/stop semantics.

### C. TCP and TLS

Implement a real Thousand Island bridge, exercised by real external sockets. Include connection initialization, fragmented reads, output, close/error handling, bounds, ownership, and lifecycle translation.

Use OTP `:ssl` as the **explicit foundation/reference TLS-over-TCP provider**. Keep the provider selection extensible. Independently audit `ex_ssl` server-side listen/accept/handshake, ownership, active/passive I/O, send/recv, shutdown, metadata, ALPN and required Thousand Island callbacks before enabling it. Existing outbound HTTPS tests are not server evidence.

An explicitly selected unsupported custom TLS provider returns a clear error; it must not fall back to OTP `:ssl`. Unsupported mTLS/options must fail explicitly. QUIC has its own TLS integration and must not inherit an unrelated TCP provider selector.

Use generated fixture credentials and independently validating clients. No real user secrets or certificate issuance.

### D. UDP unicast, broadcast, and multicast

Implement the real modes through Abyss's supported public APIs. Broadcast and multicast are first-phase requirements, not README-only promises.

Abyss owns the shared socket. Give Gaoxy handlers only the send capability/operations they need. Closing or crashing a handler must not close another handler's listener. Do not assume `{:continue, state}` in a legacy per-datagram handler creates persistent peer routing.

Expose endpoint membership list/join/leave operations, keyed by group and interface. Cover duplicate joins, absent leaves, membership bounds, startup rollback, and desired-state recovery after restart. Use supported host operations rather than private process messages.

Separate IPv4 broadcast, IPv4 multicast, and IPv6 multicast. Reject IPv6 broadcast. Preserve scope and interface requirements. Do not guess subnet broadcast addresses or substitute arbitrary addresses for missing metadata.

Preserve actual peer/destination/interface metadata when supplied. A wildcard bind address is not a received packet destination. Return unknown fields or explicit unsupported capability errors rather than inventing values.

Reuse backend bounds and add only missing application-level admission. The persistent dispatcher is not automatically valid in broadcast mode. A writer's admission receipt is not delivery, and a timed-out submitted operation may have happened. Preserve uncertain outcomes without automatic retransmission.

Implement real IPv4 exchanges and a runnable isolated network fixture. Add Linux IPv6 multicast/scope coverage on supported configurations. Unsupported backend/platform combinations must be visible, tested negative paths.

### E. Lifecycle, admission, and telemetry

Track lifecycle states and readiness accurately. Define pause semantics per backend: admission-only versus unbind/rebind, queued-packet behavior, retained socket/membership behavior, and ephemeral-port changes. Do not implement pause through `:sys.suspend` or assume similarly named backend functions are equivalent.

Use one absolute deadline for drain/removal. Preserve admitted workers' required I/O until completion or the deadline, then clean up. For QUIC, distinguish local host cleanup from full protocol drain; stopping all reception can prevent existing connections from progressing. Reject an unavailable stronger guarantee instead of pretending to provide it.

Implement generation-safe handles/reservations, monitors, stale-message rejection, and idempotent teardown. An explicitly removed child must remain stopped rather than restarting because of an inappropriate child-spec policy.

Enforce finite active-work, queue-item, queue-byte and timeout limits. Count queued and in-flight work. Ensure payloads cannot accumulate unboundedly in the mailbox ahead of admission. Do not create a Task per rejected datagram, a retry-sleep queue, or an unrestricted per-packet worker path.

Emit instance/service-scoped lifecycle, active work, admission rejection, retained bytes, local send outcome, timeout and drain telemetry. Bound label cardinality and redact secrets. Do not call UDP throttling network backpressure or claim total memory bounds from partial counters.

### F. Optional QUIC and custom TLS

After the required transports work, implement a minimal generic QUIC bridge only through the verified public `Abyss.QUIC` host and handler/facade. Use an application-specific ALPN. Preserve engine-owned CID routing, opaque generations, flow control, operation references, and close isolation. No second QUIC engine or CID registry.

Demonstrate an independent peer stream exchange if dependencies and fixtures support it. Do not advertise QUIC DATAGRAM, mTLS, migration, 0-RTT, HTTP/3, or WebTransport without host-level and Gaoxy-level evidence.

When custom TLS or QUIC is blocked, preserve a clear capability error and write the smallest actionable dependency follow-up. Do not replace real tests with a fake implementation and label the feature complete.

## 5. Examples, standalone entrypoint, and tests

Deliver `examples/mixed_transports` showing simultaneous TCP, TLS, UDP unicast, broadcast, and multicast services with custom handlers. Use unprivileged ports and explicit fixture interfaces. The example must exercise the public Gaoxy API, not bypass it with direct backend startup.

Add a standalone startup/configuration smoke using the same runtime and a versioned data-only configuration format. Include validation before activation. Resolve handler names through an explicit allowlist; do not evaluate configuration strings as code. No public management server or UI is needed now.

At minimum automate:

1. Pure configuration and capability validation; startup rollback; actual port reporting; two-instance isolation.
2. Real TCP/TLS exchanges through Gaoxy, fragmented input, validating TLS failures, and independent service failure isolation.
3. Real UDP unicast including empty packets and oversize handling; isolated IPv4 broadcast; multicast membership and delivery tests; explicit IPv6 capability/scope cases.
4. Handler crash/slow-callback behavior, blocked sends, pause/resume, admitted reply during drain, forced cleanup, intentional stop, stale generations, and uncertain operation handling.
5. Sustained overload with finite retained work and no unbounded rejected-work task creation.
6. An external core-only consumer and mixed-transport release startup/traffic/shutdown.
7. Optional custom TLS/QUIC independent acceptance, separately labeled from fake-backend unit tests.

Network setup must use isolated fixtures, explicit privilege opt-in, and cleanup on failure. Do not alter normal host networking or broadcast on physical interfaces. Synchronize tests with readiness/events rather than unexplained sleeps.

Create test aliases/scripts and CI jobs that distinguish unit, loopback, isolated-network, external-consumer, and optional-provider suites. Required CI gates must fail on zero executed tests or unmet prerequisites rather than quietly skip everything. A local environment lacking privileges can report NOT RUN and provide the executable gate; it cannot claim that gate passed.

Run formatting, compilation with appropriate warning checks, unit/loopback tests, applicable network gates, and the external-consumer/release smoke. Use the actual available environment; record any command that could not run. Add static analysis when supported, without burying new warnings under blanket suppression.

## 6. Documentation and scope control

Deliver:

- `README.md` with working startup/example instructions and an honest feature matrix.
- `docs/architecture.md`, `docs/dependency-audit.md`, and concise ADRs for composition, handler families, provider defaults, optionality, and lifecycle.
- `docs/capabilities.md`, distinguishing support from acceptance evidence and OS/backend limitations.
- `docs/acceptance/m1.md` with commands, exact versions, peer identities, counts, exit results and gate status.
- `docs/implementation-status.md` mapping completed work and remaining M2/M3/M4 work.

Use PASS, FAIL, NOT RUN, and BLOCKED in execution records. Distinguish configured CI from executed tests. A source document claiming support, a compiling stub, and a mocked happy path are not network acceptance.

Do not implement partial H1/H2/H3 engines, proxy handlers, Phoenix adapter stubs, ACME, SOCKS5, WebTransport, UI, or a broad plugin marketplace during this kickoff. Record future boundaries without falsely exposing them as functionality. Native HTTP/Phoenix work must later include a real WebSockAdapter compatibility change; do not impersonate Bandit or monkey-patch dependency modules.

Fix dependency bugs only in an explicitly available source checkout/worktree with a focused regression. Otherwise provide an unapplied patch or precise follow-up specification. Do not modify unrelated repositories or publish/push changes.

## 7. Final handoff

When finished, report the working features, meaningful files changed, exact dependency baseline, tests actually executed, failed/not-run/blocked gates, and smallest next work package. State clearly whether M1's required foundation gates passed. Optional provider/IPv6/QUIC gaps must remain visible.

If something blocks part of the task, deliver the working tested portions and the concrete blocker. Do not stop after planning, ask the user to revisit settled decisions, or claim future milestones are complete.

**Start with repository inspection and dependency verification, then implement M0/M1.**
