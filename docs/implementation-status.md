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

## Current M2 retry and next milestones

Native HTTP/1, WebSock, Plug/Phoenix, the browser fixture, local/remote routing,
HTTP streaming and message-level WebSocket reverse proxying are implemented on
`codex/m2-native`. The earlier 0.19.0 run recorded passing independent
local/remote, raw gzip, duplicate-cookie, upload/download, SSE, redirect and
shutdown checks for the runnable reverse-proxy example. Those checks were not
rerun for the current narrow 304 repair.

**M2 remains incomplete:** published HTTP Fetch 0.19.0 drops a present empty
query (`/upload?` becomes `/upload`). Bug
[#64](https://github.com/gsmlg-dev/http_fetch/issues/64) is filed with type Bug,
label `internal request`, and severity blocker. The enabled regression fails;
there is no private API, dependency patch, URI rewrite or skipped-test workaround.
Only that raw-target task is stopped pending a released fix and dependency update.

The seven selected Fetch/Core/Runtime/WebSocket/QUIC/TLS packages are 0.19.0,
release commit `09b1686fb2ce529a17287d97801107c53b1ac57c`. #60 is resolved:
a public RequestCompletion handle confirms cleanup before establishment, during
upload, and after response headers. HTTP and WebSocket guardians survive native
owner/instance force-stop, retain admission reservations, and confirm public
upstream cleanup before receipt and normal DOWN. Caller expiry retains
`cleanup_pending`. No request is replayed and HTTPS verification stays enabled.

The scoped retry also repairs downstream per-write deadlines, polling copy
credit, and client-supplied forwarding trailers. The current completion audit
at source `e1fa21edc5cfdbfda887c5d7a505659444efc1c0` additionally preserves explicit
304 representation-length metadata through buffered, file and streamed responses
without adding a body or inventing an absent length. A proxy regression covers
that metadata before a pipelined successor.

The final scoped run records **66 core / 0 failures + 116 HTTP / 0 failures +
73 proxy / 1 failure = 255 tests, 254 pass**, seed `302084`, `--max-cases 1`,
exit 2. Only the enabled #64 empty-query regression fails; the formatter exits 0.
The 304 regressions have separate red/green logs. See
[the completion evidence](acceptance/evidence/m2/completion-audit-0.19.0/command-results.json)
and [M2 acceptance](acceptance/m2.md). Earlier Phoenix/browser/example/core-consumer
results remain historical and were not rerun for this change; their bundles stay
intact. The upstream check at **2026-10-10T07:01:15Z** still records #64 **OPEN**
and GitHub/Hex latest **0.19.0**, so full M2 remains incomplete pending a released
fix and dependency update.

HTTP capacity is source-qualified on OTP 28.5.0.5 with explicit socket buffers and stable
qualified host settings; it is not a total BEAM memory limit.

Standalone core-only dependency isolation is separate from the umbrella graph,
which includes `elixir_quic`/`ex_ssl`; no H2/H3 support is implied. No push, merge,
release, deployment or hosted M2 run is part of this local retry.

M3: HTTP/2 and complete gateway/relay policies. M4: independently verified HTTP/3.
Optional ex_ssl TCP hosting needs the public server contract in
[the upstream follow-up](dependency-followups.md); no automatic provider fallback.
