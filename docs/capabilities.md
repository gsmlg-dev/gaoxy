# Configured support and acceptance evidence

## Current M5 source capability — 2026-10-19

**M5 COMPLETE LOCALLY within its ordinary verification scope.** Native downstream
H2/H3 WebSock and Phoenix integration passed the G0–G5 runtime checks. The
[M5 acceptance ledger](acceptance/m5-websocket-over-h2-h3.md) is authoritative for
source identities, commands, gate outcomes and the final independent closeout
review. This current-source acceptance does not qualify the historical published
v0.3.0 artifact.

| Capability | Current source behavior | Acceptance boundary |
| --- | --- | --- |
| Embedded HTTPS defaults | H2 then H1 ALPN; H1 negotiation/no-ALPN fallback; explicit H1-only retained | G2 ordinary defaults/H2/h2c gate PASS; plain TCP stays H1 unless explicit prior-knowledge h2c |
| H2/H3 WebSocket | Native RFC 8441/9220 extended CONNECT, shared frame/WebSock engine on each stream worker; connection owner retains I/O | Per-listener `extended_connect: false` default; independent H2, h2c and H3 peers each passed 15/15 ordinary cases |
| Phoenix sockets | Exact Endpoint `websocket_paths` list; temporary GET view with immutable CONNECT Exchange, Origin/session/CSRF/auth and early validation preserved | H2, H3 and H1 browser profiles each passed 12/12; Channels/PubSub, LiveView click/upload, normal Close and cleanup verified |
| External H3 Phoenix | Separate optional H3 service, explicit wrapper/path list and `extended_connect: true`; Endpoint supervisor with `server: false` | Duplicate-listener guard retained; no automatic H3 switch |
| WebSocket proxy transports | Existing H1 upstream path retained | H2/H3 upstream WebSocket proxying and downstream bridge acceptance absent; compression and generic CONNECT tunnels outside M5 |
| Specialist qualification | Existing historical outcomes preserved | Abnormal disconnect, slow-peer, pressure and sustained-load validation deferred to dedicated environment |

Successful H2/H3 browser sockets have marker-correlated native CONNECT/version/
stream receipts. Browser profiles prime startup trust through ordinary HTTPS
navigation before the application flow; clients choose actual WebSocket
transports. An H2 page does not guarantee H2 WebSockets, including after future
certificate updates. H3 uses controlled QUIC-first selection; automatic H3 selection
with TCP available is not qualified. The H3 profile's rejected-Origin check
returned 403 over H1 TLS and establishes no H3-specific Origin rejection result.

Standalone JSON keeps explicit H1 defaults and does not activate WebSocket
endpoints. No publication, deployment, production or broad platform acceptance
follows from M5 source support. Earlier milestone snapshots below retain their
original source-bound scope and limitations.

## Historical milestone snapshots

> Historical M1 snapshot. M1.1 revalidation and the current hardening verdict are
> recorded in [M1.1 acceptance](m1-1-hardening-acceptance.md); this historical PASS is not evidence for the changed candidate.

The M1 required foundation matrix passed on the recorded environments.
Configured support remains an adapter contract, with its acceptance scope and
platform/backend limits shown separately.

| Capability | Adapter state | Current acceptance | Limits |
|---|---|---|---|
| TCP streams | supported | Real fragmented exchange and pause/resume passed in runtime suite | One root handler; finite callbacks/state/output; no half-close claim |
| OTP TLS streams | supported | Independent Python/OpenSSL TLS exchange, ALPN and trust negatives PASS | TLS 1.3 default; optional explicit TLS 1.2; mTLS rejected |
| UDP unicast | supported | Empty/ordinary/oversize/crash, admitted reply during drain, overload cases executed | Drop-new; local submission is not delivery |
| IPv4 broadcast | supported | Isolated ingress/egress from two independent peers PASS on inet/socket | Explicit fixture only; no guessed subnet broadcast; endpoint source port preserved |
| IPv4 multicast | supported | Membership/rollback/pause and outgoing interface/TTL/loopback/empty output PASS on inet/socket; desired-state restart wire PASS | Group/interface identity retained; stale handles reject |
| IPv6 multicast | platform-dependent | Isolated inet scoped ingress/egress/hops/loopback PASS; socket ingress and scoped-send negative PASS; macOS controls rejected | Explicit group/interface/scope; socket backend scoped send unsupported |
| IPv6 broadcast | unsupported | Pure rejection PASS | No IPv6 broadcast exists |
| Pause | supported with backend-specific semantics | Real TCP/UDP and independent TLS admitted traffic/pause/resume PASS | UDP keeps bind; TCP/TLS rebinds and ephemeral port can change; QUIC pause unsupported |
| Drain | ordinary local transport contract | Admitted UDP/TLS replies, forced cleanup and stale timer/generation messages PASS | One deadline; QUIC local host cleanup only, stronger drain rejected |
| Destination/interface metadata | preserve available input; no fabricated fields | PASS unknown-field/no-invented-destination assertions; ancillary-positive peer NOT RUN | Legacy backend supplies no destination/interface; wildcard bind is not packet destination |
| Custom TCP TLS / ex_ssl | unsupported | Public facade audit + explicit selection rejection | Public server contract absent; no OTP fallback |
| Generic QUIC | experimental opt-in | PASS independent aioquic custom-ALPN stream/FIN/reset/stop/flow-control/close-isolation; bounds and native receipts | Public `Abyss.QUIC` / `Quic`; at most16KiB; macOS accepted subset; fixture can log read errors after peer close; no pause/full protocol drain |
| QUIC DATAGRAM/mTLS/migration/0-RTT | unsupported | No acceptance claimed | Host limitations preserved |
| Historical H2/H3 and remaining proxy/relay protocols | Not implemented at the M1 snapshot | NOT RUN / BLOCKED then; current M3 below | Historical foundation evidence only |

## Native M2 local acceptance

The following is local Linux evidence for the native M2 worktree, separate from
the historical transport baseline above. **M2 local completion gates PASS**
with Fetch 0.19.1: 255 scoped tests, 2 fixture tests, 13 browser/peer checks,
6 example checks and 1 fresh core-consumer test. See the
[requirement record](acceptance/m2.md); hosted CI and publication are not claimed.

| Capability | Implementation and evidence | Limits |
|---|---|---|
| Native H1 / Plug | Real TCP, validating TLS, bounded reads/writes, pipeline/framing/error/lifecycle regressions PASS | Selected H1 profile; finite requests; no H2 ALPN |
| WebSocket / WebSock | Native wire, controls/fragments/UTF-8/close/drain and independent client PASS | No compression; bounded lifetime/state/frame/message/mailbox checks |
| Phoenix Endpoint | HTTP/HTTPS one-instance ownership and actual port lookup PASS | Endpoint-managed or explicitly gateway-managed; no Bandit backend |
| Phoenix browser | Page, static, LiveView click/upload, Channels, SSE, reconnect, development reload and shutdown PASS | Chromium/Linux fixture; no production deployment or broad conformance claim |
| Local routes | Immutable first-match host/method/raw-path routes, real pipeline PASS | No forwarding-header trust or configuration reload generation switch |
| HTTP Fetch dependency contracts | Published 0.19.1: thirteen streaming/WS and five request-completion contracts PASS; public string/URI empty-query probe PASS; #27–#30/#38/#45/#60/#64 closed | Includes GET/DELETE bodies, per-request streaming, raw bytes/trailers, early responses and WebSocket close semantics; separate from full HTTP proxy acceptance |
| WebSocket reverse proxy / remote routes | Real native routes, text/binary/subprotocol/close and shutdown tests PASS | Fixed upstream authority; per-hop ping/pong; no compression or exact fragmentation forwarding; finite reservations and explicit verified WSS |
| HTTP streaming reverse proxy | Implemented; scoped wire/TLS/lifecycle tests PASS with HTTP Fetch 0.19.1 | Verified HTTPS, bounded upload/download, SSE, early responses, raw compression, trailers and external cleanup; present empty queries survive and their regression passes |
| Hosted M2 CI | Configured, NOT RUN on this unpublished candidate | Historical payment/spending restriction is recorded separately; current hosted state not rechecked |

The proxy package selects HTTP Fetch/WebSocket and transitively includes
`elixir_quic`/`ex_ssl` 0.19.1. Standalone core-only isolation remains a separate
gate; the umbrella graph is not engine-free. These dependencies imply no upstream
H2/H3 support. The explicit native H2 engine belongs to `gaoxy_http`. The
per-request streaming option removes the global threshold constraint.
WebSocket persistent reservations survive native updates and connection death;
see [their accounting scope](websocket-proxy.md).

## Current M3 implemented scope

The v0.2.0 gateway beta covers native H1/H2, policy-controlled gateway services,
route generations and dedicated-H1 upstream groups. Its recorded HTTP Fetch0.21.3
qualification passed compatibility486/0, public managed39/39, H1 baseline20/0, B21,
supplemental TLS5/5 and the public H2 supplement8/8. Negative-oracle receipts keep
their actual failure exits. See [M3 acceptance](acceptance/m3.md) and
[ADR007](adr/007-m3-beta-and-m4.md). Upstream pools and upstream H2 are not
implemented; deferred fixtures do not block this release or M4 preparation.
Hosted execution, publication and deployment retain separate evidence.

| Capability | Current implementation | Qualification boundary |
| --- | --- | --- |
| Native H2/Plug/Phoenix | Explicit TLS ALPN or prior-knowledge h2c; bounded decoder, stream/writer ownership, flow control/trailers/reset/drain | Qualified OTP28/:inet resource profile; no h2c upgrade, push, H2 CONNECT/extended-CONNECT or H3 |
| Forward HTTP/H1 CONNECT | Required authentication and destination rules, all-answer validation, numeric pinned dial and finite opaque tunnel | Explicit rules; no open proxy, interception, SNI/PROXY/SOCKS |
| TCP/TLS stream relay | Credited independent duplex writers, finite cleanup, verified upstream TLS and opaque passthrough | TCP half-close; TLS directional shutdown unsupported |
| UDP association relay | Source/destination policy, unicast per-peer associations, empty payloads, finite rate/credit/capacity and idle expiry | CIDRs do not authenticate; no broadcast/multicast relay; no retry of uncertain output |
| Route/standalone generations | Bounded preparation/CAS, old request/resource pins, stable listener reload and strict version1 JSON | Only static/fixed reverse-proxy JSON targets; local API; no public management listener |
| Upstream groups | Supervised health and bounded deterministic selections with confirmed public cleanup | Dedicated H1 per request; effective member deadlines and bounded concurrency/ownership gates PASS; no group soak claim |
| H1 reuse/upstream H2 | Public dependency contracts tested; production Gaoxy adapters not implemented | Outside v0.2.0 scope; current dedicated H1 remains enabled |

The historical0.19.1 local candidate passes460 scoped tests,40 independent selected RFC checks,
15 browser/peer checks and6 reverse-example checks. The qualified600-second
profile covers local echo and a fixed dedicated-H1 proxy; all199 recorded source
hashes identify that candidate. Separate independent specification and quality reviews
pass. These historical gates do not establish the deferred upstream features or
production acceptance; current release verification has its own receipt.

## M4 HTTP/3 published qualified subset

The optional native `gaoxy_http3` application implements concrete IPv4/QUICv1/
ALPNh3, shared endpoints/Plug and static/literal QPACK with zero dynamic capacity.
All prescribed implementation checks and final independent acceptance PASS on
the final repair12 source. v0.3.0 portable qualification, publication and fresh
download verification PASS from immutable source4931982. The builder runs757/0
tests and the offline runtime passes core/H1/H2/H3 plus all21 ELF checks.
[Release acceptance](acceptance/release-0.3.0.md) binds the actual bytes and reviews;
hosted CI remains BLOCKED_ENV with zero steps, deployment/E2E NOT RUN.
[The final gate ledger](acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
binds530/0 source checks, strict builds and every native/Session/browser/standalone/
consumer execution. UP2 first and fresh complete repeat both pass68/68 with
independent evidence reviews. Historical failures retain their original verdicts.

| Capability | Executed local evidence | Boundary |
| --- | --- | --- |
| H3 endpoints/Plug | G1 47/G2 59 checks; final source530/0 | Finite stream/operation/Admission ownership; no H3 WebSocket |
| Fixed H1/H3 origins | G3 19 checks; UP2 twice66network+2policy with independent reviews | Dedicated request endpoints; explicit HTTPS/CA for H3; no automatic fallback/pool/replay |
| Phoenix H3 browser | Final G3 actual Chromiumh3 and server request markers | Existing HTTP page/static resource; process-local fixture trust; favicon500 remains visible |
| Standalone H3 routes | Final16 real startup/progressive proxy/reload/rollback/stop checks | Data-only static/fixed H1/H3 routes; no public management |
| Public Session lifecycle | Final50 checks:17network+2policy+31boundary doubles | Dedicated endpoint with confirmed local cleanup; Fetch H3 cleanup diagnostic remains UNSUPPORTED |
| Core/H1-H2/H3 isolation | Final clean consumers1/2/2 tests,0 failures | Core/H1-H2 exclude optional QUIC/client applications; H3 explicitly selects its cohort |
| Generic QUIC host | Reviewed4/0+9peer rows, unchanged-input reuse | Separate host gate; does not establish H3 framing or broad platform support |

The tiny-window matrix selects public H3 host polling1ms and finite H2
control2048/s; defaults10ms/256controls/s remain. H3 completion4985ms first/
4567ms fresh meets the original5s bound without a throughput-margin or default
10ms burst claim. Installed0.21.4 uses supported8KiB public Session fragmentation
under the16KiB application ceiling; upstream main-only #105 is not installed.

Dynamic QPACK, push, extended CONNECT, H3 WebSocket, WebTransport, DATAGRAM,
0-RTT, resumption, migration, mTLS, IPv6/wildcard bindings and graceful H3 GOAWAY
drain remain unsupported. [Public usage](http3.md) describes explicit opt-in.
Portable build/runtime, hosted CI, publication, deployment and production
acceptance remain separate gates.

## Resource accounting scope

Gaoxy's ledger has finite active-work and retained-byte limits, zero queued
payload items/bytes, owner monitors and callback/send watchdogs. It sees only
control records; payloads never queue in its mailbox. Abyss's independent active
and start-reservation limits remain in force before the bridge. A backend start
reservation retains at most `max_packet`; a full UDP receive binary can transiently
occupy up to 65,536 bytes before oversize rejection. Stream callback state is
checked after each transformation using external representation size.

Counters do not bound all BEAM/kernel memory or arbitrary allocations inside
trusted user callbacks. Datagram throttling is local overload control, not
network backpressure. `send_started` assigns a generation-scoped operation before
I/O; `send` correlates the local result. Timeout, owner loss and forced cleanup
preserve `{:unknown, reason}` when completion was not observed, without retry.
Real blocked TCP and forced-drain gates pass on macOS and Linux. Receipts cannot
reconcile peer delivery or query completed ordinary-socket operations. Scoped
backend-drop forwarding uses Registry reads and bounded reasons; driver/kernel
queues and arbitrary callback allocations remain outside the byte ledger.
