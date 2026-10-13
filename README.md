# Gaoxy

An Elixir/OTP transport runtime, usable inside an application's supervision tree
or as a standalone release. Gaoxy composes Thousand Island for TCP/OTP TLS and
Abyss for UDP and optional generic QUIC. M0/M1 implements transport hosting,
service lifecycle, finite admission, telemetry and custom protocol handlers.
The M2 worktree adds native HTTP/1, WebSock and Plug/Phoenix integration with a
real browser fixture, [HTTP streaming reverse proxying](docs/http-proxy.md), and
message-level [WebSocket reverse proxying](docs/websocket-proxy.md).
HTTP Fetch 0.21.4 supplies H1 request-owned cleanup and preserves present empty
queries (`/upload?` remains `/upload?`), resolving the former
[#64](https://github.com/gsmlg-dev/http_fetch/issues/64) blocker.
**M2 local completion gates pass**: all 255 scoped tests and refreshed native
Phoenix/browser, reverse-proxy example and core-consumer checks pass.
See [M2 evidence](docs/acceptance/m2.md). Gaoxy hosted CI, push, merge, release
and deployment are not part of this local acceptance.

M3 implements opt-in native HTTP/2, authenticated forward HTTP/H1 CONNECT,
TCP/TLS relays, bounded UDP unicast associations, immutable route generations,
standalone HTTP configuration and supervised dedicated-H1 upstream groups.
See [native HTTP](docs/native-http.md), [gateway APIs](docs/gateway.md) and
[M3 acceptance](docs/acceptance/m3.md). The v0.2.0 gateway beta covers this
implemented subset. Upstream pools and upstream H2 are not implemented. Native
downstream [HTTP/3](docs/http3.md) is implemented in the M4 worktree.
[HTTP Fetch #101](https://github.com/gsmlg-dev/http_fetch/issues/101) is closed;
0.21.4 passes all 15 Fetch functional diagnostic rows, including request trailers.
Fetch H3 cleanup completion remains unsupported. The independently reviewed
[public Session design](docs/designs/m4-public-session-upstream.md) is selected
for upstream H3, with the reviewed
[consumer-affinity amendment](docs/designs/m4-public-session-consumer-affinity.md).
All prescribed M4 implementation checks pass:530 scoped tests/0 failures,
public Session50 checks, native/server/shared/browser47/59/19, standalone16,
and clean core/H1-H2/H3 consumers1/2/2. The complete H1/H2/H3-to-H3 matrix
passes66network+2policy checks in both its first execution and required fresh
repeat, with independent evidence reviews. Final independent M4 acceptance
passes. [v0.3.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.3.0) is published from source4931982:
the portable builder passes757 tests/0 failures, fresh offline core/H1/H2/H3
runtime and21-ELF inspection pass, and all three published downloads equal
the qualified bytes. Hosted CI remains BLOCKED_ENV with zero executed steps;
deployment and release-artifact E2E are NOT RUN. [M4 acceptance](docs/acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
binds exact source identities, counts and limits and preserves historical FAILs.
The released 0.21.3 M3 cohort passed compatibility486/0, public managed39/39,
H1 baseline20/0, B21, supplemental TLS5/5 and the public H2 supplement8/8.
Negative probes retain their genuine failures and expected outcomes.
[ADR007](docs/adr/007-m3-beta-and-m4.md) records the reviewed scope and authorizes
release plus M4 preparation. Existing native browser/RFC/600-second load evidence
retains its recorded earlier source identity.

**M0/M1 required transport foundation gates passed** on the recorded macOS and
isolated Linux baselines; the experimental optional QUIC wire gate also passed. See [execution evidence](docs/acceptance/m1.md) and
[task status and repair counters](docs/implementation-status.md).
Release execution and artifact verification are recorded separately in
[the v0.3.0 release receipt](docs/acceptance/release-0.3.0.md).
The next prepared existing task is [M3 Task4 H1 resource foundation](docs/plans/m3-h1-resource-foundation.md); implementation is NOT RUN.

## Development

Core declares Elixir 1.18+. Executed baselines are macOS x86_64 with Elixir
1.20.1/OTP29 and isolated Alpine Linux with Elixir1.19.5/OTP28. The pinned Abyss
artifact builds a Rust NIF, so Rust/Cargo are required even for ordinary UDP.
The locked Nix shell supplies Elixir1.18/OTP28, Rust/Cargo, Python, OpenSSL and
Expect; M3 executes that shell on Linux with Elixir1.18.5/OTP28.5.0.7.
Elixir **1.18.5** is the canonical formatter, matching the locked Nix package.
Use that version for `mix format` and its check; formatting runs in its own CI
job. Runtime compilation and tests retain both Elixir1.18.5/OTP28.5 and
Elixir1.20.1/OTP29.0.2, independently of formatting. There is no devenv
configuration in this repository.

Certificate fixtures require OpenSSL3.x. `OPENSSL_BIN` optionally selects one
executable path (including paths containing spaces); it is never evaluated as
shell code. CI provisions OpenSSL3 on Linux and Homebrew `openssl@3` on macOS,
records its version, and exports its absolute path. Generation uses an isolated
private temporary directory and an explicit CA/leaf profile, verifies server
purpose plus `localhost`/`127.0.0.1`, and removes signing keys/serial/request files.
The caller owns the resulting short-lived leaf key and public certificates;
never install this CA globally. TLS regressions also reject a different generated
CA and a wrong hostname while keeping peer verification enabled.

```sh
mix deps.get --check-locked
mix format --check-formatted
mix compile --warnings-as-errors
python3 scripts/check-tests.py
bash scripts/external-consumer.sh
```

The test wrapper fails on empty execution. Tests use generated short-lived
credentials and real sockets; independent TLS peers validate CA and hostname.
For the measured local macOS timing environment, an explicit process-scoped
`ELIXIR_ERL_OPTIONS='+S 2:2'` has passed the same checks/deadlines. Default VM
release startup stalled during code preload, and default TLS timing has been
intermittent; those failures remain recorded.

## Embedded services

For native HTTP/Plug/Phoenix, see [the server guide](docs/native-http.md) and
[runnable Phoenix fixture](examples/phoenix_native/README.md). The transport API
below remains independent of all HTTP dependencies.

```elixir
defmodule Echo do
  @behaviour Gaoxy.StreamHandler
  def init(_metadata, _options), do: {:ok, nil}
  def handle_data(bytes, state), do: {:send, bytes, state}
end

{:ok, runtime} = Gaoxy.start_link(services: [
  %{id: "echo", transport: :tcp, ip: {127, 0, 0, 1}, port: 0, handler: Echo}
])
Gaoxy.info(runtime, "echo")
Gaoxy.status(runtime, "echo")
Gaoxy.pause(runtime, "echo")
Gaoxy.resume(runtime, "echo")
Gaoxy.remove(runtime, "echo", 1_000)
Gaoxy.stop(runtime)
```

`Gaoxy.child_spec/1` embeds the runtime under supervision. `Gaoxy.add/2` validates
before activation. Service IDs and telemetry are instance-scoped;
`Gaoxy.handle/2` returns a generation-scoped handle usable in place of an ID.
Actual ephemeral ports are reported after binding. Startup failure rolls back
activated siblings, and explicit removal stays removed. TCP and UDP bindings
are separate; conflicting same-family ownership is rejected.

Streams preserve ordered bytes across arbitrary delivery boundaries. Their
callbacks return continue/send/close/error actions, with independent state,
output, callback and idle limits. TLS uses OTP `:ssl` explicitly. Selecting
unsupported `:ex_ssl` or mTLS fails without fallback.

Datagram handlers implement `handle_datagram(packet, options)` and return `:ok`,
`{:reply, bytes}`, `{:send, destination, bytes}` or `{:error, reason}`. A packet
preserves empty payloads, peer and actual local bind; unavailable destination
and interface fields stay `:unknown`. The callback receives no listener socket
or close capability. Addressed sends use the owned endpoint, enforce output/byte
bounds and never automatically retry. Scoped IPv6 destinations use an explicit
sockaddr. Multicast exposes `memberships/2`, `join/3`, `leave/3` with group/interface
pairs, finite limits and desired-state recovery after restart.

UDP pause retains the bind/memberships and stops admission; received paused
packets are dropped, while kernel-queued packets may survive withheld credit.
TCP/TLS pause unbinds new acceptance while admitted connections retain I/O;
resume rebinds and may change a port-zero endpoint. Removal uses one absolute
deadline and forces cleanup at expiry. Send telemetry distinguishes operation
submission and local/unknown outcomes; admission and local completion do not
prove peer delivery. Counters exclude arbitrary callback allocation and kernel
buffers.

## Standalone and mixed transports

Standalone version1 JSON resolves handlers through a fixed allowlist, without
evaluating code:

```json
{"version":1,"services":[{"id":"echo","transport":"tcp","handler":"stream_echo","ip":"127.0.0.1","port":4000}]}
```

```sh
mix gaoxy.validate config.json
MIX_ENV=prod mix release
GAOXY_CONFIG=config.json _build/prod/rel/gaoxy/bin/gaoxy start
```

Startup emits `GAOXY_READY` with actual bound endpoints.
[The mixed example](examples/mixed_transports/README.md) defines custom handlers
and starts TCP, TLS, unicast, broadcast and multicast simultaneously. Its
`MIXED_READY` record drives the dedicated example fixture.

Run privileged network gates only in a disposable isolated Linux environment:

```sh
python3 integration/network/fixture.py --allow-privileged --ipv6
GAOXY_UDP_BACKEND=socket python3 integration/network/fixture.py --allow-privileged --ipv6
MIX_ENV=prod mix release
python3 integration/network/release_gate.py --allow-privileged
python3 integration/network/example_gate.py --allow-privileged
```

They create fixture-owned namespaces/veths, use two independent peers and clean
up on failure. Do not use physical LAN broadcast or alter normal host routes.
The recorded s93 executions use Docker `--network none` with explicit namespace
capabilities. Linux IPv6 inet scoped egress passed; socket scoped egress is
explicitly unsupported and tested for absence of delivery.

## Optional QUIC

The standalone core dependency graph contains no QUIC engine. The umbrella
proxy package now transitively selects `elixir_quic` and `ex_ssl` 0.21.4 through
HTTP Fetch/WebSocket; native downstream H2 is explicit in `gaoxy_http`, and this
dependency selection does not enable upstream H2/H3. The separately locked
opt-in consumer now selects `elixir_quic` and `ex_ssl` ==0.21.4. M4's independent
public-host gate passed on0.21.4 with independent review; earlier0.21.3 evidence
retains its historical source identity. The final implementation ledger records accepted reuse after unchanged-host-input review.
Older 0.17.0 evidence remains historical:

```sh
cd integration/quic_consumer
mix deps.get --check-locked
mix compile --warnings-as-errors
python3 ../../scripts/check-tests.py
```

The consumer uses aioquic1.2.0/CPython3.12 via `uv`, generated credentials and a
custom ALPN. The experimental `Gaoxy.QUICHandler` and `Gaoxy.QUIC` facade use
only public `Abyss.QUIC` handles; the engine retains CID routing, cryptographic
state, flow control and generations. Facade reads/writes are at most16KiB and
also obey configured limits. Native operation references and unknown receipts
are preserved; a write receipt means admission. QUIC pause and full protocol
drain are unavailable; local host cleanup is reported explicitly. IPv6/wildcard
QUIC, DATAGRAM, migration, mTLS,0-RTT and WebTransport are unsupported. Native
H3 is an explicit optional application with [its own limits and gates](docs/http3.md).
The independent custom-ALPN wire gate passed. Test handlers can log
`invalid_operation` after peer-requested close because polling races the native
closing phase; clean/no-error fixture teardown is not established.

| Feature | Current implementation/evidence |
|---|---|
| TCP / OTP TLS | Real exchanges, fragmented input, failure/bound isolation and independently validating TLS |
| UDP unicast | Empty/nonempty/oversize, callback crash, sustained overload and admitted reply during drain |
| IPv4 broadcast/multicast | Isolated inet/socket ingress/egress, two peers, TTL/interface/loopback and membership restart wire |
| Lifecycle | Actual ports, pause/resume, deadline cleanup, generation/timer isolation and startup rollback |
| Core-only consumer / release | Cold optional-stack exclusion; production five-transport traffic/shutdown/rebind |
| IPv6 multicast | Linux inet accepted subset; socket scoped-send negative; macOS controls rejected |
| Generic QUIC | Experimental custom-ALPN streams accepted with independent aioquic; noisy fixture close handling remains |
| Custom TCP TLS | Explicitly unsupported; public ex_ssl server API missing |
| Native HTTP/Phoenix/proxies | Native HTTP/Phoenix, WebSocket and HTTP streaming implemented; M2 local gates PASS with HTTP Fetch 0.19.1: 255 scoped tests, native Phoenix/browser, routes, streaming and clean core consumer |
| Native H2 / gateway M3 | Native H2, forward/CONNECT, relays, generations and dedicated-H1 groups implemented; [current candidate gates and upstream blockers](docs/acceptance/m3.md) remain distinct |

[Capability limits](docs/capabilities.md), [dependency provenance](docs/dependency-audit.md),
[architecture](docs/architecture.md) and [ADRs](docs/adr/) define the boundaries.
GitHub CI had not executed at implementation acceptance; local/isolated results
are recorded separately from subsequent workflow runs.

Final M4 implementation acceptance: [independent review](docs/acceptance/evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json),
PASS with no unresolved findings. Portable qualification/publication stay separate.
