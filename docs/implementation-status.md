## v0.4.0 release status — 2026-10-19

M3/M5 implementation and ordinary source acceptance are complete. The reviewed repair restores the native numeric limit map for ordinary H2/H3 Exchanges while retaining existing WebSocket metadata only on actual WebSocket requests; strict managed-group accounting remains unchanged. Fresh ordinary portable and offline qualification passed for the published source. Earlier snapshots below retain their original status.

Published [v0.4.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.4.0) from `ebd2b12a997750109ffd3fc7db4f3eda223ab79b`. Fresh ordinary portable verification: **200 executed / 0 failures / 90 excluded**; packaged H2/h2c/H3 WebSocket **15/15 each** in builder and offline runtime. All **21 ELF objects** passed dependency checks; three freshly downloaded assets match the qualified bytes and hashes. [Release acceptance](acceptance/release-0.4.0.md) records source, artifact and publication evidence. New hosted CI remains NOT RUN.

Earlier snapshots retain their capture-time scope and actual failed, blocked and unexecuted results. Specialist qualification remains with its dedicated environment; deployment and production acceptance remain NOT RUN.

## Current stage: M5 WebSocket over HTTP/2 and HTTP/3 — 2026-10-19

**M5: COMPLETE LOCALLY within its ordinary verification scope.** Native
server-side RFC 8441/9220 WebSock and Phoenix integration passed G0–G5 runtime
checks. The [authoritative acceptance ledger](acceptance/m5-websocket-over-h2-h3.md)
records source-bound results and the final independent closeout review. See the
[design](designs/m5-websocket-over-h2-h3.md) and
[implementation plan](plans/m5-websocket-over-h2-h3.md).

Embedded HTTP/Phoenix HTTPS now defaults to H2 then H1, retaining H1 fallback
and sufficient omitted H2 budgets. Plain TCP remains H1 unless explicit
prior-knowledge h2c is selected; Upgrade and mixed-cleartext detection remain
unsupported. `extended_connect` defaults to false independently of protocol
selection. Phoenix uses an explicit exact `websocket_paths` list and temporary
GET view while preserving immutable CONNECT Exchange metadata and native
Origin/session/CSRF/authentication/early-validation policy. External H3 mounts
use a separate optional service, explicit wrapper and Endpoint `server: false`.

Independent H2, h2c and H3 peers each passed 15/15 ordinary cases. H2, H3 and
H1 Phoenix browser profiles each passed 12/12, with actual protocol/CONNECT
receipts for successful multiplexed sockets, normal Close and cleanup. Browser
profiles use ordinary HTTPS navigation before the application flow to complete
startup trust preparation. Clients choose actual WebSocket transports; an H2
page does not guarantee H2 WebSockets, including after future certificate
updates. H3 used
controlled QUIC-first selection; automatic H3 selection with TCP available is
not qualified. The rejected-Origin check in that profile returned H1 TLS 403,
with no H3-specific negative claim. Scoped compatibility passed 136 tests/0
failures; separately named H1/proxy/WSS/contract and isolated consumer checks
passed with their own counts in the ledger.

Outbound H2/H3 WebSocket proxy transports
and compression are outside M5. Specialist abnormal/disconnect, slow-peer,
pressure and sustained-load qualification stays deferred to a dedicated
environment. M5 is local development only: no merge, push, release, publication
or deployment follows. Accepted M3/M4 and their historical evidence remain as
recorded below.

## Current M3 acceptance and local merge — 2026-10-19

**M3: ACCEPTED COMPLETE** within the user's existing product-functionality and
ordinary-verification scope. Local implementation through
`88799ae316e7195ae42656b228edfea2aaa115ed` includes the H1 resource foundation,
managed H1/H2 fixed/group upstreams and probes, resource-accounted checked
Generations/reloads and the implemented streaming compatibility. The
[M3 completion ledger](acceptance/m3-completion.md) links the actual stage counts,
source identities and remaining limitations. Earlier prepared-only Task4 and
whole-M3 OPEN statements below are historical snapshots superseded by this
current acceptance; unsupported or unimplemented capabilities remain so.

Further exceptional/disconnect, slow-peer, pressure, sustained-load and combined
qualification belongs in a dedicated specialist test environment and is outside
this local integration. Its FAIL/BLOCKED/NOT RUN outcomes stay visible and no
longer block the merge. Stop automatic execution of those slices. The sole-H1
blocked-upload disconnect probe established only a fixture setup failure before
request creation; the test-only require fix has not been rerun. No product defect
or repair acceptance is claimed, and that slice is excluded from this integration.

**Fresh ordinary candidate and main verification: PASS (62 executed tests each, 0 failures). Local main merge: PASS** by fast-forward to `743297a`; the final documentation-only closeout follows. The
current authorization permits local integration only, with no new push, release
or deployment permission. The already published v0.3.0 source/artifacts below
remain distinct from the new local implementation. Existing production-data,
certificate, Vault, public-management and disabled release-artifact E2E
restrictions remain intact.

## Historical status records — preserved below

# Implementation status

## M4 final implementation verification — 2026-10-13

All prescribed implementation executions PASS on the final repair12 source:
530 scoped tests/0 failures, strict umbrella/Phoenix H3 builds, public Session50
(17 network+2 policy+31 boundary doubles), G1/G2/G3 47/59/19, standalone16, and
clean core/H1-H2/H3 consumers1/2/2 with zero failures. Reviewed G0 4/0+9peer rows
are reused after independent unchanged-host-input verification. UP2 first and
required fresh complete repeat both pass66network+2policy with independent
evidence reviews. The [final ledger](acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
links each immutable command/source/count/exit receipt.

The six local source versions are0.3.0. Fresh candidate verification passes530/0,
34 explicit formatting paths and strict umbrella/Phoenix/production compilation
as recorded in the final ledger. Receipts remain precommit hash-bound.
Whole-candidate SPEC/CODE preparation passes. Final independent acceptance of
all evidence and synchronized documentation PASS. Portable build and packaged
offline runtime now PASS at immutable source4931982:757 tests/0 failures,
core3/gateway2/H3three exchanges and21 ELF with no missing/Nix dependencies.
v0.3.0 is published; all three fresh downloads match qualified bytes. Hosted CI
remains BLOCKED_ENV (3 runs/10 jobs, zero executed steps); deployment/E2E NOT RUN.
The selected H3 tiny-window1ms
profile completes4985ms first/4567ms fresh within original5s; no default10ms
throughput-margin claim follows. Session lifecycle evidence is distinct from
Fetch H3's unsupported cleanup diagnostic.

The installed0.21.4 cohort retains the needed supported8KiB frame selection and
16KiB application ceiling; [the latest audit](acceptance/evidence/m4/upstream-contract/latest-http-fetch-main-update-audit-1791855535947755021.json)
records #105 closed in main but no installed containing fix. All historical
failed runs and uncertain causal findings remain in [M4 acceptance](acceptance/m4.md).
UP2 counters remain20 unsuccessful live/8 failed production/3 failed harness;
historical19/7/3,18/6/3,17/5/3 and exhausted Astra2 are preserved.

[v0.3.0 release qualification](acceptance/release-0.3.0.md) records completed
source, artifact/runtime and remote-download gates. The tag/artifact stay at
4931982; final main documentation follows as a separate commit. Next existing M3 Task4
[design](designs/m3-h1-resource-foundation.md)/[plan](plans/m3-h1-resource-foundation.md)
are prepared only; implementation NOT RUN. Continuing authorization remains,
with unchanged Vault, E2E, publication/deployment and production restrictions.

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

Final M4 implementation acceptance: [independent review](acceptance/evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json),
PASS with no unresolved findings. Portable qualification/publication stay separate.
