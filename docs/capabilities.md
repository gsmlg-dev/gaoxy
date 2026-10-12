# Configured support and acceptance evidence

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

## M4 HTTP/3 worktree

The optional native `gaoxy_http3` application implements the bounded IPv4/QUICv1/
ALPNh3 profile, shared endpoints/Plug, native framing and zero-dynamic QPACK.
Independent G0/G1/G2 gates passed; the downstream G3 network/browser matrix
passes19checks with independent review. [M4 acceptance](acceptance/m4.md) records
exact candidate/evidence identities and pending gates. This worktree is not yet
a published M4 release.

Current coordinated cohort is0.21.4, with274affected tests/0failures after
independent review. Prior live/browser/consumer rows below retain their0.21.3
source identities pending the required final refresh. HTTP Fetch#101 is closed;
all15Fetch functional diagnostics pass, but cleanup completion is unsupported.
The reviewed [public Session plan](plans/m4-public-session-upstream.md) is selected;
its direct qualification and Gaoxy integration are still incomplete.

| Capability | Executed local evidence | Boundary |
| --- | --- | --- |
| H3 endpoints/Plug | Independent shared-facade tests and59live checks | Original finite stream/operation/Admission ownership; no H3 WebSocket |
| H3 downstream to fixed H1 origin | 11 real proxy cases: escaped/empty query, identities, ordered request/response trailers, progressive upload/download, early final/reset/siblings | Dedicated H1 only; no reusable pool, automatic protocol selection or replay |
| Phoenix H3 browser | Chromium152.0.7977.64/Playwright1.56.0 exact document/static CDPh3 and matching server markers | Process-local fixture trust/IPv4 mapping; ordinary HTTP page, no WebSocket claim; automatic favicon500 retained |
| Standalone H3 configuration | Explicit JSON, strict fields/budgets and58 scoped tests; real startup/progressive proxy/reload/rollback/stop passed11 checks and a fresh repeat | Static/fixed H1-origin routes; H3-origin row blocked; no public management |
| Upstream H3 | 0.21.4 Fetch15/15 functional PASS; selected Session architecture reviewed | Fetch cleanup UNSUPPORTED/overall exit2; Session runtime qualification pending; Gaoxy upstream adapter/matrix unimplemented |
| Fresh consumer isolation | Clean core1/0, H1/H2 2/0 and H3 2/0, all exit0 and independently reviewed | Core/H1H2 exclude QUIC/client runtime; explicit H3 consumer includes its declared cohort; omitted peer hash supplied by independent pre/post observations |

Dynamic QPACK, push, extended CONNECT, WebTransport, DATAGRAM,0-RTT,resumption,
migration,mTLS,IPv6/wildcard bindings and graceful H3 GOAWAY drain remain
unsupported. [Public usage](http3.md) documents embedded and standalone opt-in.
Final affected tests passed274/0, exact-file format and strict builds passed;
fresh shared/downstream gates passed59/19 checks. Full M4 acceptance awaits
required upstream qualification; hosted
CI, release, deployment and production acceptance remain separate.

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
