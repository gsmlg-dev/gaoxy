# Dependency audit

## M4 upstream H3 qualification — 2026-10-12

The root dependency cohort remains **0.21.3**; `mix.lock` is unchanged
(SHA256 `16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25`).
Installed `http_fetch` and `elixir_quic_http3` package manifests both identify
`gsmlg-dev/http_fetch` as their source. No dependency source was patched.

The public Fetch/Promise/Stream/AbortController diagnostic against two independent
aioquic 1.2.0 origins executed **7 rows: 5 PASS, 2 BLOCKED**. The
[captured run](acceptance/evidence/m4/upstream-contract/run-1791811050964927834/result.json)
and [independent review](acceptance/evidence/m4/upstream-contract/review-up0.json)
confirm ordinary progressive upload, streamed downloads with ordered repeated
response trailers on two separately certified authorities, and cancellation
before headers and during an unacknowledged response chunk. The cancellation
rows observed public process termination and independent origin RESET events.
Both owned children exited 0 and both origin UDP ports rebound. Credentials
were disposable P-256 CA/leaf fixtures with peer and hostname verification.

The two required request-trailer rows remain blocked: public
`HTTP.Stream.finish/2` returns `:ok`, then the Promise returns
`{:error, :request_trailers_unsupported}`. The independent origin received
exactly `abc` or zero DATA bytes, with no trailing fields or request FIN.
[gsmlg-dev/http_fetch#101](https://github.com/gsmlg-dev/http_fetch/issues/101)
is **OPEN**, type **Feature**, label **internal request**, severity **blocker**
for upstream-H3 request-trailer support. The
[request record](dependency-requests/http-fetch-h3-request-trailers.md)
links the reproduction and preserved historical failures. The only current
harness delta from its captured execution is the issue's TODO comment;
executable source and all other 179 captured source hashes match that historical
run. A [fresh diagnostic repeat](acceptance/evidence/m4/upstream-contract/run-1791815367697333596/result.json)
again returned exit2,5PASS/2BLOCKED, with all180 source hashes matching before,
after and the checkout; [fresh independent review](acceptance/evidence/m4/upstream-contract/review-up0-fresh.json)
passed. The [current state check](acceptance/evidence/m4/upstream-contract/dependency-state-1791814663418733829.json)
confirmed #101 OPEN and Hex latest0.21.3.

This is a functional dependency block, not full UP0 acceptance. Wrong-CA,
wrong-hostname, absent-trust and `connect_address` negative probes, plus
blocked-upload and owner-loss cancellation, remain **NOT RUN**. The production
H3 upstream adapter (UP1) and upstream proxy matrix (UP2) remain **unimplemented**;
they require a compatible published fix, dependency update and their prescribed
qualification. No trailer-dropping workaround is enabled. Independent downstream
H3 and standalone work can continue. The reviewed exclusion of `http_fetch#97`
continues to apply; it supplies no M4 requirement or blocker.

## Current M3 cohort — 2026-10-11

The proxy directly pins Fetch/WebSocket to `== 0.21.3`; all seven coordinated
HTTP packages resolve to0.21.3. Verified tag is
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Independent
[installed verification](acceptance/evidence/m3/upstream-transport/upstream-0.21.3/installed-cohort-verification.md)
checks all seven archives,196 shipped files and175 runtime sources;17 unrelated
lock entries are preserved. Compatibility486/0, finite managed39/39, H1
baseline20/0, B21, public H2 supplement8/8 and actual TLS supplemental5/5 pass.
Five acquisition-failure probes meet their expected negative oracles; independent
H1/H2 specification, code and evidence review passes.
The locked Nix shell uses Linux, Elixir1.18.5/OTP28.5.0.7/ERTS16.4.0.6/SSL11.6.0.6.
[M3 acceptance](acceptance/m3.md) and [ADR007](adr/007-m3-beta-and-m4.md) record
the reviewed gateway beta subset. The former control-proof request is excluded
from acceptance. Production uses dedicated H1; reusable H1/upstream H2 adapters
are unimplemented. Numerical fixtures retain their historical status.

## Historical foundation audit — 2026-10-08

Repository inspection found an unborn `main` branch and three untracked user
documents. The original kickoff and implementation plan are retained. No sibling
checkout was modified. `.audit/` contains ignored, detached source checkouts for
inspection; production dependencies are fetched normally by Mix and never edited.

| Dependency | Repository / inspected commit | Selected artifact | OTP application / namespace | License |
|---|---|---|---|---|
| Thousand Island | `mtrudel/thousand_island` / `6146e1bfdd1a85c5c16c3c92ad98ff5f11066820` | Exact Git ref; declares 1.5.0 | `thousand_island` / `ThousandIsland` | MIT |
| Abyss | `gsmlg-dev/abyss` / `9b710e6480900e16e304f40e63623aff8c922e19` | Exact Git ref; declares 0.7.0 | `abyss` / `Abyss`, `Abyss.QUIC` | MIT |
| Telemetry | Hex `telemetry` | 1.4.2; checksums in `mix.lock` | `telemetry` / `:telemetry` | Apache-2.0 |
| Reference TCP TLS | Erlang/OTP, locally 29 / ERTS 17.0.2 | OTP runtime `ssl` | `ssl` / `:ssl` | Apache-2.0 |
| Custom TLS (TCP audit / optional QUIC consumer) | `gsmlg-dev/http_fetch` / `a02af288d8729c3bdcae4d3de8dc2751c2b04e37`, `apps/ex_ssl` | Hex 0.17.0 in separately locked QUIC consumer; absent from ordinary core | `ex_ssl` / `SSL`, `SSL.QUIC` | Apache-2.0 |
| QUIC (optional consumer) | Same HTTP umbrella commit, `apps/elixir_quic` | Hex 0.17.0 in separately locked QUIC consumer; absent from ordinary core | `elixir_quic` / `Quic` | MIT |
| HTTP packages (audit only) | Same commit, `apps/http_core`, `apps/http_runtime`, `apps/elixir_quic_http3` | Source 0.17.0, no Gaoxy runtime dependency | `http_core`, `http_runtime`, `elixir_quic_http3` / `HTTP.*`, `HTTP.Runtime.*`, `QuicHttp3` | Package manifests say MIT; imported-file notices also apply |
| Plug (future contract only) | `elixir-plug/plug` / `9fa11c8ebedbe68531eba25d8f81b9282e0514da` | v1.20.3, not installed | `plug` / `Plug.Conn.Adapter` | Apache-2.0 |
| Phoenix (future contract only) | `phoenixframework/phoenix` / `bd1801833b4fd7ceb02497cc7ba2d05e9bd391c8` | v1.8.15, not installed | `phoenix` / `Phoenix.Endpoint` | MIT |
| WebSockAdapter (future contract only) | `phoenixframework/websock_adapter` / `80901f46c8864cb8bd5231c32b7171b9d0e330ce` | Inspected source only, not installed | `websock_adapter` / `WebSockAdapter` | MIT |

These are repository commits, not file blob identities. Later contract-only
versions are preparation baselines, not dependencies or compatibility claims.

## Runtime baseline and transitive dependencies

Actual local host: macOS Darwin 24.6.0 x86_64, Elixir 1.20.1, Erlang/OTP 29,
ERTS 17.0.2. Core declares Elixir `~> 1.18`. The portable development shell pins
Nixpkgs and selects Elixir 1.18 / OTP 28; execution of that combination remains
unverified until its gate is run. Linux isolated acceptance ran on s93 with Alpine 3.23.3, Elixir 1.19.5 and
OTP 28; NixOS and the actual Nix shell runtime remain unrun. The image is pinned
by digest in `integration/network/Dockerfile`.

The lock resolves Abyss transitive dependencies `telemetry_metrics` 1.2.0,
`rustler` 0.38.0 and `jason` 1.4.5. Abyss currently compiles its DHCP Rust NIF even
for ordinary UDP consumers, so Rust/Cargo are build prerequisites. Rustler's
upstream `runtime: false` is a build-tool declaration; Gaoxy does not disable
required runtime application startup. Abyss also declares ExDoc without an
environment restriction: ExDoc 0.40.4, Earmark 1.4.46, Makeup 1.2.3,
Makeup Elixir 1.0.1, Makeup Erlang 1.1.0 and NimbleParsec 1.4.2 are locked build
dependencies. These costs are visible; no dependency options or sources were
patched to hide them.

## Verified public contracts and consequences

Thousand Island provides listener startup/info, connection ownership, active-once
byte delivery and formal `ThousandIsland.Transport` callbacks. Pause closes the
accept socket, existing connections retain I/O, and resume rebinds; port zero can
change. The published Hex 1.5.0 artifact lacked `handshake_timeout` and caused a
real startup failure. The explicitly recorded Git revision has finite handshake
timeouts and read-deadline fixes; the chosen revision is never a moving branch.

Abyss `start_link`, `suspend`, `resume`, `stop`, `join`, `leave`, `memberships`,
`Listener.listener_info` and `Listener.status` supply ordinary datagram hosting.
One socket with `active: :once`, one outstanding starter and server-wide admission
bound packets ahead of callbacks. Unicast port zero uses one endpoint. Broadcast
and multicast are real transports; Gaoxy selects their public modules. Handlers
do not own the socket. The legacy callback always closes after its one packet;
Gaoxy does not mistake continuation for persistent peer routing. Pause retains
the socket and discards packets actually received while paused; kernel-queued
packets can survive withheld credit. Drain allows admitted workers to send.

Membership group/interface pairs are canonicalized and desired state is restored
after a listener restart. Backend maximum is 64; Gaoxy exposes a lower configurable
bound. IPv6 broadcast is invalid. IPv6 multicast controls require Linux and an
explicit interface/index. Scoped sockaddr sends on OTP's socket backend are
explicitly unsupported. No destination or interface is inferred from wildcard
binds or membership lists; actual ancillary fields are preserved separately.

`docs/dispatcher.md` distinguishes admission references, local send completion
and `{:unknown, ref}`. That dispatcher is unavailable in broadcast mode, so
Gaoxy does not enable it there. Current ordinary echo sends execute in admitted
workers with no writer queue. Generation-scoped operation references now precede ordinary sends; timeout,
owner loss and forced cleanup retain unknown outcomes. Real blocked TCP and
10ms forced cleanup were accepted on macOS/Linux; this is local operation
evidence and does not reconcile UDP peer delivery.

`SSL` has client connect, ownership, send/recv, active-once, metadata, ALPN and
close; it has no public TCP server listen/accept/handshake/shutdown facade at the
inspected revision. QUIC's `SSL.QUIC` server TLS API is separate and cannot fill
those TCP callbacks. `:ex_ssl` selection fails explicitly and never falls back.
See `dependency-followups.md` for the smallest server contract package.

The verified optional host is `Abyss.QUIC`; its engine is `Quic`, application
`:elixir_quic`, sourced from the HTTP umbrella and depending on `ex_ssl` 0.17.0.
Engine-owned CIDs and opaque connection/stream generations must remain intact.
Host support is a bounded certificate-based 1-RTT stream subset, not DATAGRAM,
mTLS, migration, 0-RTT, HTTP/3 or WebTransport acceptance. Its stop shuts ingress
before worker cleanup and cannot promise full protocol drain. Gaoxy's optional
bridge and separately locked consumer are implemented; independent wire
acceptance passed after two Sol and two bounded Astra repair rounds. Fixture
close-phase read errors remain documented; no clean teardown is claimed.
Missing engines continue to return an explicit unsupported capability error. No historical `QUIC` alias or `ex_quic` runtime dependency is invented.

## Evidence

Gaoxy checks actually run and their failures are recorded in `acceptance/m1.md`.
Upstream UDP/QUIC acceptance documents were read for contract scope; their test
counts are not credited to Gaoxy. No upstream test suite was executed in this run.
The external consumer gate separately checks both resolved dependencies and
started applications. HTTP/Plug/Phoenix remain absent from core and future empty
applications export no placeholder engines.

The optional consumer lock resolves Hex `elixir_quic` ==0.17.0 and `ex_ssl`
==0.17.0 (published 2026-10-06). Audited public host/engine/TLS source files
match the inspected umbrella revision; see
`acceptance/evidence/quic-hex-source-comparison.json`. Strict consumer compilation
passed on the macOS baseline. The independent peer is aioquic 1.2.0 on CPython
3.12.12/OpenSSL 3.5.4, with generated CA and hostname validation. Compile and
wire results are recorded independently in the acceptance report.
