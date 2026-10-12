# Implementation status

## M4 dependency resume — 2026-10-13

HTTP Fetch #101 is closed and the compatible coordinated **0.21.4** cohort is
installed. Dependency pins, root/QUIC-consumer/Phoenix locks and the bounded
core fixture readiness repair are locally committed as `b43a8eb`.
[Independent review](acceptance/evidence/m4/dependency-resume/run-1791824981886130828/review-core-cohort.json)
passed, followed by [274 affected tests / 0 failures](acceptance/evidence/m4/dependency-resume/run-1791824981886130828/cohort-scoped-post-review.json).
The original 274/1 startup-fixture failure and failed Phoenix dependency command
remain preserved alongside their diagnostics and corrected executions.

The [real Fetch retry](acceptance/evidence/m4/upstream-contract/run-1791825893238138190/result.json)
passed **15 functional rows**, including four ordered request-trailer variants,
strict TLS negatives and four cancellation stages. Its overall exit is **2**:
Fetch H3 cleanup completion remains **UNSUPPORTED**, so this is not full UP0 PASS.
[Independent functional review](acceptance/evidence/m4/upstream-contract/review-fetch-functional-1791826076183654653.json)
passed within that stated boundary.

The selected upstream mechanism is now the caller-owned public Session and
dedicated endpoint, defined by the [design](designs/m4-public-session-upstream.md)
and [plan](plans/m4-public-session-upstream.md).
[Specification/SDK review](acceptance/evidence/m4/upstream-contract/session-design-spec-review.json)
passed; direct Session qualification is in progress. UP1 production activation,
UP2 matrix, standalone H3-origin and final updated-cohort runtime/consumer/browser
verification remain incomplete. M4 is not ready for main/push/release.
Continuing authorization and all existing operational restrictions remain intact.

The first Session gate failed compilation before executing network rows. Sol
repair1 fixed compilation and executed nine labelled boundary-double rows, then
the first real poll failed `:not_consumer`. The
[diagnosis](acceptance/evidence/m4/upstream-contract/session-consumer-affinity-diagnosis-1791827196294978658.json)
identifies the SDK's fixed-consumer requirement. The bounded
[architecture amendment](designs/m4-public-session-consumer-affinity.md) and
[task delta](plans/m4-public-session-consumer-affinity.md) now passed
[independent review](acceptance/evidence/m4/upstream-contract/session-consumer-affinity-spec-review-1791828021439137088.json):
a stable caller uses its own consumer identity and explicitly monitors guardian
loss, including normal exit. Qualification is being amended; neither prior run
is credited as Session PASS. The new qualifier chain
retains Sol1 unsuccessful/Astra recovery0; project architecture adds no recovery
round and does not reset historical counters.

## Historical M4 checkpoint — 2026-10-12

M4 runs in `.trees/m4-http3` on `codex/m4-http3`, from main78de9d0. Continuing
development and conditional completed-M4 publication authorization are recorded
in AGENTS.md and implement-plan.md. Native H3 host/profile/protocol/shared facade
(G0–G2) passed independent review and local gates. Fresh G2/G3 shared and
downstream proxy/real Phoenix browser gates pass59/19 checks. Clean core1/0,
H1/H2 2/0 and H3 2/0 passed independent review; final affected tests passed274/0,
exact-file format and strict umbrella/Phoenix H3 builds. Standalone ST1 strict
JSON/generation passed58/0; ST2 static/H1-origin startup, streaming, reload,
rollback and shutdown passed11 checks and a post-review repeat. Its H3-origin
row remains blocked. [M4 acceptance](acceptance/m4.md) preserves exact identities,
failed history and the consumer peer-identity supplement.

The required upstream-H3 contract is **BLOCKED DEPENDENCY** on
[HTTP Fetch #101](dependency-requests/http-fetch-h3-request-trailers.md): five
ordinary public API rows pass, but both request-trailer rows return the public
unsupported error and no origin trailers/FIN. UP1/UP2 are unimplemented; no
trailer-dropping workaround is allowed. The root0.21.3 cohort/lock is unchanged.
M4 is incomplete; no merge, push, version bump or release has occurred.
The [remaining task queue](plans/m4-upstream-resume.md) continues the existing
product scope after the compatible published upstream fix. Deployment, Vault,
production data/certificates, public management and disabled release-artifact
E2E restrictions remain intact. Historical records below retain their own scope.

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
implied by the historical M2 record. Current release/M4 progression follows ADR007.
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

Current transport checkpoint (2026-10-11):

All seven coordinated HTTP packages are installed at **0.21.3**, tag
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Both direct pins are
`== 0.21.3`; seven lock entries changed and 17 unrelated entries are preserved.
Independent source/artifact review verifies 196 shipped files and 175 runtime
sources, including the containing parser/cancellation fixes #98/#100.
Strict compilation and compatibility **486/0** pass. The unchanged public
managed driver passes **39/39** with 39 joined cleanups and canonical capacity
MATCH; these finite resource properties do not certify memory bounds.

Actual supplemental TLS95 qualification passes **five cases/five cleanups,
exit0**. The isolated0.21.1 negative control executes both inventory cases with
exact H1 observed1/expected3 and H2 observed2/expected4 mismatches, two cleanups
and real exit1. Source/build/tool/native environment freezes and original
loaded/disk comparisons pass; every original loaded row remains unchanged and
new rows are independently validated. Identity regression23/0 and independent
SPEC/CODE review pass. The earlier90-second native-profile timeout executed zero
cases and remains preserved; the unchanged profile later passed within its
original deadline. TLS tooling counters are Sol4/unsuccessful2/Astra2; no third
Astra recovery is authorized.

H1 functional baseline B01–B20 passes **20/0**, no skips/exclusions and all owned
joins, after the reviewed B05 backing/B17 late-cleanup amendments. Model22/0,
ledger-refusal2/0 and loaded-identity1/0 pass. The final grouped source passes
canonical format, baseline20 and separately admitted B21 without the grouping
warning. B21 observes two ClientHellos, rejects the third request at C2, retains
both genuine cleanup_unconfirmed completions and original retirement, joins15/15
owned actors and refunds no native control credit. Eight invalid gate probes
plus the existing relative-path probe reject with zero registered tests.
H1 counters are Sol3/unsuccessful2/Astra1; all original deadlines remain fixed.

The public H2 parser/cancellation supplement passes **8/8** (TLS4/h2c4), with
zero skips/failures, eight joined peer shutdowns and real exit0. Exact parser
invalid_headers_transition/RST1 and abort/deadline aborted/request_timeout/RST8
oracles pass. Manual original completion confirms after reader consumption;
follow completion stays explicitly unsupported. Frozen source/native/loaded
before-after identities pass. H2 counters are Sol1/unsuccessful0/Astra0.
Five separately frozen acquisition-failure probes meet their expected negative
oracles. Both prerepair controls omit cancellation/recovery and record reset0;
repaired manual/follow controls publicly cancel, recover the first response and
record reset8. The lost-alias control preserves its real Task.await timeout,
public abort and no second await, with explicit BLOCKED_HANDOFF. All five retain
real VM exit1: four FAIL and one BLOCKED_HANDOFF, adding zero normal-suite cases.
Wrapper post-identity/outcome and loaded-after identity are NOT RUN for these
negatives because System.halt(1) bypasses them. Parent input freezes and actual
owned process/peer joins are separately verified. Fresh native profiles compare
exactly: 254 file hashes, 113 ELF paths and 483 unique NAR identities. Independent
H1/H2 specification, code and evidence review passes with no findings.

**Reviewed disposition, 2026-10-11:** The user dismissed the former control-proof
request as excessive. It is excluded from Gaoxy acceptance and must not be
pursued, replaced with equivalent requirements, or used to block release or M4.
Numerical fixtures and their failed/unqualified receipts remain historical;
this decision does not turn them into passing tests. Production uses dedicated
H1 connections. Reusable H1 and upstream H2 adapters are not implemented and
are outside the v0.2.0 gateway beta release. See [ADR007](adr/007-m3-beta-and-m4.md).
Old managed-integration requirements below describe the deferred variant,
rather than prerequisites for this release or M4.

See [current acceptance](acceptance/m3.md) and
[TLS supplemental receipt](acceptance/evidence/m3/upstream-transport/upstream-0.21.3/tls95-supplemental-analysis.json).

The following paragraphs preserve historical 0.21.0 observations and failures;
their installed/remote state is superseded by the current checkpoint above.
Coordinated HTTP Fetch0.21.0 was then installed; actual release tag
`9813c126dc8b48055b9ee941c693fc27fa691489` contains #78 managed scopes and
#79 fragment caps, in addition to #66/#67 request cleanup/trailers. All196
shipped files and175 runtime blobs match the verified artifacts. Strict
format/compile and460 scoped upgrade-compatibility tests pass at seed21102026
with228 unchanged source hashes. These are separate from historical load,
Phoenix/browser and0.20 request probes.

**At the historical 0.21.0 checkpoint, full M3 was BLOCKED** on H2 header/control event bound
[Bug #86](https://github.com/gsmlg-dev/http_fetch/issues/86), complete H1
retained-state accounting and managed runtime/integration qualification.
Task3's initial and diagnostic-only frozen public runs FAIL after11 cases;
the diagnostic confirms H2 force-retired request uncertainty while independent
B is live before cleanup. Historical repair1 FAILs after24 cases; repair2's
preflight FAILs on formatting. Bounded Astra recovery1 and fresh independent
review/strict verification now pass39/39 public cases,39 joined cleanups,
425 stable source hashes and no remaining peer; focused preflight passes18/0.
TLS H2 and h2c capacity error shape remains separately MISMATCH in needed#89.
Tasks4–8 remain gated. The pure compact-input and constructor-accounting slice
now passes independent specification/code-quality reviews and fresh26/0 tests
of reviewed formatted source, with429 stable hashes. It creates no scope and
always refuses activation; H1/H2 component subtotals are not complete
reservations. Source-backed needed issues#87/#88
are separate from H2 blocker#86 and are not measured leaks.
Exact OTP-source delivery/credit/decode, parser-root and general term-layout
lemmas pass independent source review in their conditional scope. Effective
profile enforcement, full policy/request/control lifetime accounting and
P0-P6 composition remain open. No complete activation proof is established.

Earlier remote checkpoints record #86–#89 CLOSED while published/installed
artifacts remained0.21.0; closure alone does not qualify those fixes. New
[Bug95](dependency-requests/http-fetch-otp28-tls-tracking.md) blocks managed
OTP28 TLS resource tracking. A real verified TLS connection returns the new
eight-element socket, skipped by installed `track_tls/2`; final diagnostic
exits0 with joined peer and429 stable source hashes. Its initial missing-ALPN
peer failure is preserved. No retirement race or runtime leak was measured.
Generated String/source provenance passes separate independent review in its
conditional scope; P3/P4/composition and loaded-code/profile enforcement remain
open. The reviewed pure implementation is committed locally as `56fd518`.
Conditional request/wire construction and33-entry HAMT structure now pass
separate independent reviews. The HAMT structural envelope is8,984 bytes per
complete occurrence plus children; constructor/native work, simultaneous roots
and release enforcement remain open. Control-turnover/TLS evidence and current
delivery status pass their bounded independent review, committed as `d8e3a26`.
Conditional native Binary/message/fragment formulas now pass independent source
review; actual ABI and multiplicities remain open. A read-only VM checkpoint
records34 matching loaded/disk code-MD5s, BEAM/native whole-file identities,
FetchOptions33 and429 unchanged sources. It establishes no future hot-code or
profile enforcement, source reproduction or complete native-layout proof.
The bounded policy/host-CA trace records unchanged warm snapshot lookup and
explicit-DER keyword transformations. Cold loading, cache mutation, immutable
snapshot enforcement and simultaneous copy lifetimes remain unqualified; its
constructor counts are conditional components rather than a complete P3 peak.
The historical read-only remote recheck recorded GitHub/Hex0.21.1, closed86–89 and
open95, while installed artifacts remain0.21.0. The
[patch qualification plan](plans/m3-upstream-0.21.1-qualification.md) preserves
old evidence and requires independent containing-source review and fresh gates.
These source and identity results do not complete P0–P6 or M3.
Follow the [transport plan](plans/m3-upstream-transport.md) and
[current acceptance](acceptance/m3.md) for actual receipts and limits.

Historical0.20 public request probes passed16/16 with202 unchanged hashes;
its finite empty-CONTINUATION diagnostic was INCONCLUSIVE. #78/#79 issue
closure is now confirmed in installed artifacts, but neither historical
request evidence nor upgrade compatibility proves managed lifecycle/bounds.
Production adapters remain dedicated H1. The reviewed scope in ADR007 permits
release/M4 preparation; the release receipt separately records remote publication.
No production deployment or production acceptance is implied.
