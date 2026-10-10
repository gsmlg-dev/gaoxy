# Implementation status

> Historical M1 snapshot. M1.1 revalidation and the current hardening verdict are
> recorded in [M1.1 acceptance](m1-1-hardening-acceptance.md); this historical PASS is not evidence for the changed candidate.

**M0/M1 required transport foundation: PASS.** This is the pre-publication
acceptance snapshot: no commit, remote creation, push, publication or deployment
had occurred during implementation acceptance. Subsequent source publication
is separately authorized by the user. The supplied `implement-plan.md` remains the scope and
acceptance authority; M2/M3/M4 were not implemented in this historical snapshot. This is foundation
acceptance on recorded environments, not a beta/security/conformance claim.

| Work package | Delivered and verified | Limits / remaining scope |
|---|---|---|
| M0 dependency audit/lock | Exact source refs, Hex checksums, public contracts, licenses and baseline documented; strict compile PASS | Nix shell derivation evaluated; actual shell/NixOS runtime NOT RUN |
| Application boundaries | Four umbrella applications; HTTP/proxy empty without placeholders; cold external core-only consumer PASS | No Plug/Phoenix/Bandit/http_fetch/QUIC dependency, code path or startup in ordinary consumer |
| Validation/runtime | Pure immutable plan; instance-scoped identities; dynamic services, actual ports, failure rollback and registrations | Trusted embedded handlers; no code evaluation from standalone JSON |
| TCP/OTP TLS | Fragmented real traffic; independent validating TLS/ALPN/trust negatives; init/crash/close/state/output isolation | ex_ssl TCP server explicitly unsupported; default local VM/TLS timing failures preserved |
| UDP modes | Unicast/empty/oversize; addressed output; isolated IPv4 broadcast/multicast and supported Linux IPv6 | Socket scoped IPv6 send unsupported; unavailable destination/interface metadata stays unknown |
| Lifecycle/admission/telemetry | Pause, admitted UDP/TLS drain replies, deadline cleanup, stale messages/generations, membership restart wire, bounded overload and correlated unknown sends | Byte ledger excludes arbitrary callback allocations and all BEAM/kernel memory |
| Example/standalone | Actual custom-handler five-transport example11 and production release11 checks PASS with two independent peers; shutdown/rebind verified | Namespace-only fixtures; no LAN broadcast/host route changes |
| Optional QUIC | Public Abyss.QUIC/Quic/SSL.QUIC bridge; locked independent aioquic custom-ALPN stream/FIN/reset/stop/flow-control/close-isolation gate PASS | Experimental accepted subset on macOS; noisy test-handler close-phase logs retained; no pause/full protocol drain/IPv6/wildcard/DATAGRAM/mTLS/migration/0-RTT/H3 |
| Documentation/CI | Architecture, ADRs, dependency audit/follow-up, capabilities, commands and raw execution records | GitHub CI configured, NOT RUN at acceptance; source publication does not establish CI results |

## Current acceptance evidence

- `astra-quic-round2-core-tests.log`: current-source23 core+1 server PASS, exit0.
  `astra-quic-round2-core-compile.log` and `-format-check.log`: strict/global PASS.
- `linux-quic-round1-foundation.log`: copied-source24 tests, strict dev compile,
  inet21/socket20 network gates and production release11 PASS. The combined
  command exits1 in the subsequent initial example tuple match; failure remains.
- `mixed-example-repair1-linux.log`: actual example11 checks PASS, exit0 after
  correcting only endpoint reporting. All real traffic/shutdown assertions stay.
- `external-consumer-final.log`: cold consumer1 PASS, exit0, seed250638.
- `astra-quic-round2-consumer-test.log`: optional independent peer1 PASS, exit0,
  seed757928;344064-byte echo,86016-byte survivor, exact reset/stop, flow-control
  block/progress, admission refs, certificate/ALPN rejection and facade bounds.
- `astra-quic-teardown-diagnostic.log`: unchanged-source diagnostic PASS1, exit0.
  Peer close precedes fixture read errors by5/6/14/9ms; no clean-teardown claim.

Linux acceptance used a pinned Alpine3.23.3/Elixir1.19.5/OTP28 fixture on s93,
Docker `--network none` plus explicit NET_ADMIN/SYS_ADMIN and container-local
IPv6 sysctls. Its source snapshot/hashes are `linux-quic-round1-source.json`.
The final QUIC-only record-capacity correction2*→3*max_active is independently
exercised by the optional consumer on macOS/Elixir1.20.1/OTP29. Ordinary paths and
manifest/lock optionality are unchanged by that correction. See
[the complete execution record](acceptance/m1.md) for commands, versions and
historical failures.

## Task routing and cumulative repair counters

All direct implementation was root Sol work, serially. The user explicitly
authorized Astra after two unsuccessful Sol repair rounds, with at most two
Astra repairs. Counters survived worker reuse and task handoffs; no new symptom,
thread or source change reset them. There was no free recovery implementation
round. Recovery never edited installed dependencies.

| Task ID | Initial / final owner | Sol repairs | Astra repairs / gate | Final state |
|---|---|---:|---|---|
| strict-build | root / root |1|0 / none|PASS|
| runtime-foundation | root / root after Astra handoff |2|1 / SOL_REPEATED_FAILURE|PASS; round2 not used|
| independent-tls | root / root |1|0 / none|PASS; generated CA Key Usage corrected|
| external-core-consumer | root / root |1|0 / none|PASS; compatible dependency-introspection harness|
| release-smoke | root / root |0|0 / none|PASS with explicit +S2:2; default local startup BLOCKED_ENV|
| datagram-egress | root / root |2|0 / none|PASS; scope/output bounds and worker-completion synchronization|
| isolated-network-egress | root / root |1|0 / none|PASS; old-kernel observer option preserves wire assertions|
| five-transport-release | root / root |0|0 / none|PASS11|
| send-operation-outcomes | root / root after Astra handoff |2|1 / SOL_REPEATED_FAILURE|PASS; round2 not used|
| backend-drop-forwarding | root / root |1|0 / none|PASS; suspended reason maps to paused|
| stream-isolation | root / root |0|0 / none|PASS|
| lifecycle-acceptance | root / root |1|0 / none|PASS3; UDP local-result fixture corrected|
| mixed-example-wire | root / root |1|0 / none|PASS11; UDP local-result reporting corrected|
| optional-quic | root / root after Astra handoff |2|2 / SOL_REPEATED_FAILURE|PASS experimental subset; budget exhausted, no third repair|

`sol_escalated=false` for these root-originated tasks. `astra_escalated=true`
only for runtime-foundation, send-operation-outcomes and optional-quic; all
others remain false. Each Astra admission used recorded failed Sol commands and
before-source hashes. Routine review and acceptance stayed with root Sol.

ROUTE task=runtime-foundation agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=send-operation-outcomes agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=optional-quic agent=astra_worker reason=SOL_REPEATED_FAILURE
ROUTE task=lifecycle-acceptance agent=root reason=required_lifecycle_acceptance_serial
ROUTE task=mixed-example-wire agent=root reason=execute_shipped_example_serial

## Recovery findings and ownership

Runtime recovery corrected the membership update to start at `state.spec`,
fixing real public absent-leave `KeyError :id`. Measured first admission198.55ms
explained the old100ms assertion; tests synchronize on actual events within the
existing2s readiness budget. Watchdog/drain deadlines stayed intact.

Send recovery proved fixed16MiB generation could take506–733ms inside a500ms
callback watchdog, causing death before send submission. Test-owned protected
ETS prepares bytes before activation; handler state retains only its reference.
Real `prim_inet.send/4` wait and a simultaneously live echo sibling are asserted.
The500ms watchdog,10ms forced drain, bounds and concurrency stayed intact.

QUIC Sol repairs decoded PEM to the public typed-DER contract and deferred
stream opening but still mishandled pre-established ticks. Astra round1 gated
progress on the public ready event, preserved mapped native blocked telemetry
and narrowed pause dispatch to supported hosts. Its first wire attempt still
failed. The engine reserves both peer stream quotas:2*max_active records left
zero local capacity. Root authorized the finite3*max_active derivation to keep
both peer quotas and add max_active local records. Astra round2 passed real
wire/native-reference acceptance without changing user-facing limits/deadlines.
Fixture polling after peer close can still log invalid_operation; this is
recorded rather than concealed or repaired through an unauthorized third round.

Stopped-writing/command-completion handoffs and before/after hashes are in
`acceptance/evidence/astra-{runtime,send,quic}*` records. No source writer remains
active after handoff. Shared workspace changes were preserved; no reset/stash or
destructive cleanup occurred. Agent Note scope was unavailable because
`.agents/current.md` is missing; no project was guessed and no note was written.

## Current M2 acceptance and next milestones

Native HTTP/1, WebSock, Plug/Phoenix, the browser fixture, local/remote routing,
HTTP streaming and message-level WebSocket reverse proxying are implemented on
`codex/m2-native`. **M2 local completion gates PASS** with published HTTP Fetch
0.19.1. The scoped suite passes **255 tests**:
**66 core + 116 HTTP + 73 proxy, 0 failures**, seed `754722`, `--max-cases 1`,
exit 0. Strict compilation and formatting exit 0. Fresh independent checks pass:
2 Phoenix fixture tests, 13 browser/peer checks, 6 reverse-proxy example checks
and 1 strict-compiled external core-consumer test. The method-body and
WebSocket-close probes pass all 6 and 4 cases. The browser reload check restores
the controller with identical before/after SHA256.

The seven selected Fetch/Core/Runtime/WebSocket/QUIC/TLS packages are 0.19.1;
other lock entries are unchanged. The release tag identifies
`c26a17712a02a03985a764b6b100ca840fcc4349`, published **2026-10-10T07:20:34Z**,
not the workflow main HEAD. #60 and #64 are resolved. Present empty queries now
survive both string and URI Fetch inputs and the real proxy wire path, with
confirmed public completion. The probe exits 0. No dependency patch, private
API, URI rewrite or skipped-test workaround was used.

HTTP and WebSocket guardians survive native owner/instance force-stop, retain
admission reservations and confirm public upstream cleanup before receipt and
normal DOWN. Caller expiry retains `cleanup_pending`. HTTPS verification stays
enabled; requests are not replayed and redirects are returned to the caller.
The scoped suite also covers repaired downstream per-write deadlines, polling
copy credit, client-supplied forwarding trailers and 304 representation-length
metadata without an invented body or absent length.

Current counts, commands, source/package verification and independent outcomes
are recorded in [M2 acceptance](acceptance/m2.md) and
[the 0.19.1 evidence](acceptance/evidence/m2/http-fetch-0.19.1/command-results.json).
Historical failed gates and the earlier 304 red/green audit remain intact.
HTTP capacity stays source-qualified on OTP 28.5.0.5 with explicit socket buffers
and stable qualified host settings; it is not a total BEAM memory limit.

Standalone core-only isolation remains separate from the umbrella graph, which
includes `elixir_quic`/`ex_ssl`. Gaoxy CI, push, merge, release and deployment are
**NOT RUN** for that candidate. No upstream H2/H3 or production acceptance is
implied by the M2 record. M4 requires complete M3 acceptance.
Optional ex_ssl TCP hosting needs the public server contract in
[the upstream follow-up](dependency-followups.md); no automatic provider fallback.

## Current M3 implementation and remaining gates

M3 runs in `.trees/m3-gateway` on `codex/m3-gateway`. Continuing authorization
is committed in `AGENTS.md`; designs/plans remain required while routine
development approvals are removed. The [acceptance matrix](acceptance/m3.md)
is authoritative for executed scope, pending gates, repairs and final source.

Native H2, shared HTTP operations, authenticated forward/H1 CONNECT, bounded
TCP/TLS/UDP unicast relay, route generations, standalone HTTP and supervised
dedicated-H1 groups are implemented. Historical0.19.1 S5 strict format/compile
and **460 scoped tests** pass: core90, HTTP196, proxy156, server18, zero failures
at seed49315. The 40 independent selected RFC cases and unchanged-source clean
core consumer1/0 pass. S1–S5 independent findings are resolved; separate full
specification and quality reviews pass. Phoenix fixture2/0, browser15/15 and
reverse example6/6 pass, including verified H2 and source restoration.

The frozen 600.000-second H2 echo/fixed-H1-proxy soak passes: 4064 offered,
3872 exact completions,192 expected progress resets,zero unexpected errors,
299 reloads. All600 sampled resource bounds pass; teardown7ms confirms6082
captured processes DOWN and zero reservations/tasks/guardians. All199 frozen
source hashes remain exact. Groups have bounded concurrency/health/ownership
qualification; the fixed-proxy soak does not imply a group/probe soak.

Coordinated HTTP Fetch0.20.0 is now installed; actual release tag
`951ec75dadcebd8218f30d3ecdf99da142d4a463` contains #66/#67. New strict
format/compile and460 scoped upgrade-compatibility tests pass at seed161790;
the unchanged Phoenix fixture passes2/0 at seed792852. These are separate from
the historical frozen load/browser evidence above.

**Full M3 remains BLOCKED** on public managed transports/confirmed retirement
[Feature #78](https://github.com/gsmlg-dev/http_fetch/issues/78) and remaining
H2 bounds/qualification. Positive public completion/trailer probes and a finite
empty-CONTINUATION diagnostic have executed under the
[new transport plan](plans/m3-upstream-transport.md): **16/16 public request
cases PASS**, including separately verified TLS H2 and h2c; diagnostic
**INCONCLUSIVE**, with confirmed public cleanup/peer shutdown. All 202 source
hashes match for both corrected runs, including the main probe omitted from the
original 201 maps. The source-confirmed missing fragment metadata cap is routed
as [Bug #79](https://github.com/gsmlg-dev/http_fetch/issues/79). No pooling/private-client
workaround is used. Tested work is delivered locally; M4 waits for complete
M3 public lifecycle, bounds and version-matrix qualification.
No remote publication or production acceptance is implied.
