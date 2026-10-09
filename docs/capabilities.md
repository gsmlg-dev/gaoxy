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
| H2/H3 and proxy/relay protocols | future or upstream-blocked milestones | NOT RUN / BLOCKED | No implementation or acceptance claimed |

## Native M2 candidate

The following is local Linux evidence for the native M2 worktree, separate from
the historical transport baseline above. Full M2 is **incomplete**; see its
[requirement record](acceptance/m2.md).

| Capability | Implementation and evidence | Limits |
|---|---|---|
| Native H1 / Plug | Real TCP, validating TLS, bounded reads/writes, pipeline/framing/error/lifecycle regressions PASS | Selected H1 profile; finite requests; no H2 ALPN |
| WebSocket / WebSock | Native wire, controls/fragments/UTF-8/close/drain and independent client PASS | No compression; bounded lifetime/state/frame/message/mailbox checks |
| Phoenix Endpoint | HTTP/HTTPS one-instance ownership and actual port lookup PASS | Endpoint-managed or explicitly gateway-managed; no Bandit backend |
| Phoenix browser | Page, static, LiveView click/upload, Channels, SSE, reconnect, development reload and shutdown PASS | Chromium/Linux fixture; no production deployment or broad conformance claim |
| Local routes | Immutable first-match host/method/raw-path routes, real pipeline PASS | No forwarding-header trust or configuration reload generation switch |
| HTTP Fetch dependency contracts | Published 0.17.2: five public-API contract tests PASS on 2026-10-10; original #27–#30 closed | Raw gzip/duplicate headers, trailers, early response and WebSocket ownership validated; this is not proxy acceptance |
| Reverse proxy / remote routes | BLOCKED on HTTP Fetch #45 and valid-close-code support in #38 | GET/DELETE bodies disappear; valid WebSocket close codes reject; no endpoint or remote-route acceptance |
| Hosted M2 CI | Configured, NOT RUN on this unpublished candidate | Account payment/spending restriction also blocks current main jobs |

The proxy package now selects HTTP Fetch/WebSocket and transitively includes
`elixir_quic`/`ex_ssl` 0.17.2. Standalone core-only isolation remains a separate
gate; the umbrella graph is not engine-free. No H2/H3 support follows from these
dependencies. A future proxy may use explicit static startup
`streaming_threshold: 0`; per-request streaming #37 is nonblocking under that
constraint, without global mutation per request.

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
