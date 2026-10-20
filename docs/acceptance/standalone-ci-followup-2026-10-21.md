# Standalone recovery and CI follow-up

Implemented, independently reviewed, integrated and published as
[v0.5.4](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.5.4) from
`d5e0a6c50fdaa5a3cfbff548069005029c41960e`. Both supported hosted profiles and
clean public package consumers pass. Final evidence below preserves the earlier
failed and unexecuted results at their original source identities.

Date: 2026-10-21, Asia/Shanghai. Scope and execution are defined in the
[task plan](../plans/standalone-ci-followup-2026-10-21.md). Kickoff and refreshed
main both identify `581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`; published v0.5.3
remains bound to `62a325fe5153c2438b3ea717cd7fdf4d82d7b871`.

This follow-up preserves the accepted R1–R4 implementation and coverage in the
[previous acceptance record](review-repairs-2026-10-20.md). Its historical
macOS compiler failure and optional-QUIC `:enoent` setup failure retain their
original status. The latter occurred before independent peer exchange.

## Recovery contract

Registry and generation stores survive the existing internal runtime/owner
restart. Successful CAS activation publishes both the resolved router and its
bounded declaration atomically. Recovery prepares new instance-local handles
from that declaration, preserving the latest accepted routes. Rejected or stale
candidates update neither router.

Only managed transport/group pin metadata becomes terminal after a local owner
monitor confirms its death. Independent custodians retain transport retirement
and receipt obligations, and group/probe/guardian holder monitors retain nested
cleanup. Live-owner errors remain retryable; the retired-generation activation
guard remains. See the [design](../designs/standalone-recovery-2026-10-21.md) and
[initial implementation evidence](evidence/standalone-followup/README.md).

The deterministic fixed/group regression accepts a distinguishable route,
rejects stale and expired candidates, recovers the supervised subtree, verifies accepted
traffic, reloads again, joins old custodians and verifies settled pins/current
resources. Expired preparation preserves the coordinator, runtime, owners,
accepted declaration and active pins, then reconciles preparation cleanup.
The test does not require a store PID or supervisor layout.

## Compiler and QUIC environment

Thirty external bitstring-size references are pinned (24 application, six
ordinary-test references); variables introduced within their own patterns remain
unchanged. Elixir 1.20 then exposes seven unreachable warning sites. Their
minimal corrections preserve reachable return/error paths; the
[compiler evidence](evidence/standalone-followup/compiler/notes.md) records each
binding and return-contract decision. Dependencies, supported profiles and
`--warnings-as-errors` remain unchanged. Canonical formatting uses Elixir 1.18;
the supplemental 1.20 formatter also disagrees with an unchanged baseline line.

The optional job creates `.venv` with Python 3.12 and installs the existing
`../http3/requirements.txt` from `integration/quic_consumer`, before compilation
and tests. Local verification uses Python 3.12.13 and aioquic 1.2.0 and executes
the actual validating peer, including the unchanged certificate/name/ALPN
rejections, finite deadlines and lifecycle assertions.

## Implementation evidence snapshot

This table retains the implementation checkpoint before final qualification and
publication. Its two NOT RUN rows describe that checkpoint; completed results
are appended below.

| Implementation gate | Actual result |
| --- | --- |
| Recovery baseline, fixed and group | FAIL as expected: 2 tests/2 failures; startup routes restored and next reload blocked |
| Initial recovery implementation | FAIL: declaration restored, but zero-time monitor receive raced DOWN delivery |
| Corrected recovery and existing scoped compatibility | PASS: 107 executed cases; separate final recovery rerun 2/0 |
| Compiler baseline, local Elixir 1.20.1/OTP 28 | FAIL: 15 external-size warnings; subsequent strict builds expose seven unreachable sites |
| Both local Elixir 1.18.5 and 1.20.1/OTP 28 | PASS each: forced strict compilation, 141 required unit tests, 172 focused tests |
| Fresh hosted compiler baseline, published `62a325fe` | FAIL as expected: macOS Elixir 1.20.1/OTP 29.0.2, 15 repository external-size warnings, strict compile exit 1 |
| Canonical Elixir 1.18 formatting | PASS |
| Clean optional consumer before Python provisioning | FAIL_SETUP: 4 tests/1 failure, `:enoent`; independent exchange NOT RUN |
| Provisioned optional consumer | PASS: 4 tests/0 failures, actual peer exchange and cleanup |
| Independent specification/code review | PASS: B/C and integration manifest; A's one P2 expired-activation finding resolved and independently re-reviewed |
| Review finding red/green | FAIL as expected: 2/2 coordinator crashes at exhausted activation timeout; repaired scoped run PASS: 17/0 |
| Integrated precommit repair gate | PASS: 160 executed, 0 failures, 0 exclusions/skips |
| Final committed-source and exact hosted profile qualification | NOT RUN yet |
| Publication and public consumers | NOT RUN yet |

The repair manifest adds the two new recovery cases to its ordinary protocol
suite: existing 158 cases are retained, executed total 160; unit remains 141.
Enabled ordinary CI and source-bound publication already execute this manifest.
Final committed-source counts remain a separate gate.

Raw commands, runtime versions, source identities, exits, counts and log hashes
remain under `.audit/standalone-followup/` in the task worktrees. Exported
receipts preserve source hashes and baseline failures. Nine selected existing
owner cases report 55 total/46 excluded; that selection is distinct from the
complete manifest, which rejects exclusions/skips. Early fixture/cache setup
failures are retained separately from product regression evidence. The initial
compiler driver overwrote some intermediate logs; its preservation receipt
explicitly records those as NOT RETAINED rather than claiming available bytes.

The [version preflight](evidence/standalone-followup/version-selection.json)
finds unchanged remote main, no `v0.5.4` remote tag and HTTP 404 for all five
`0.5.4` Hex release endpoints. Publication must repeat this check.
The [initial review](evidence/standalone-followup/reviews/recovery.md) retains
its REQUEST_CHANGES disposition; the
[follow-up](evidence/standalone-followup/reviews/recovery-followup.md) resolves
the P2 using the real coordinator deadline regression. A and B each used two Sol
repair rounds and no Astra rounds; historical counters are unchanged.

## Final candidate, CI and publication

The frozen source is `d5e0a6c50fdaa5a3cfbff548069005029c41960e`; root and all
five own app versions were committed as 0.5.4 before qualification. Local runtime:
Linux x86_64/NixOS, Elixir 1.18.5, OTP 28.5.0.5/ERTS 16.4.0.5,
`ELIXIR_ERL_OPTIONS='+S 4:4'`, Python 3.12.13, Rust 1.95.0, OpenSSL 3.6.3 and
uv 0.11.21. Dependencies and the lock cohort remain unchanged.

| Final gate | Actual result |
| --- | --- |
| Fresh committed-source qualification | PASS: 31 commands across checks, standalone, QUIC and build; every exit 0 |
| Ordinary repair manifest | PASS: 160 executed, 0 failures/exclusions/skips locally, in native CI and on the release checkout |
| Standalone configuration, activation, rollback, lifecycle and recovery | PASS: 120 tests, 0 failures (87 HTTP + 33 server) |
| Strict compile and unit CI, Linux 1.18.5/OTP 28.5 | PASS: strict build and 141 unit tests, no failures/exclusions/skips |
| Strict compile and unit CI, macOS 1.20.1/OTP 29.0.2 | PASS: strict build and 141 unit tests, no failures/exclusions/skips |
| Repaired optional QUIC consumer | PASS: 4 tests locally and in clean hosted CI; actual validating peer exchange |
| Portable ordinary contracts | PASS: 8 tests; separate fragmented-TCP selector executes 1 with 7 intentional exclusions |
| Production release, five package builds and core/gateway/H3 smokes | PASS; gateway has 2 exchanges, H3 has 3 named checks |
| Packaged native H2/h2c/H3 WebSockets | PASS: 15 checks per protocol, 45 total |
| Hosted CI | PASS: all 3 workflows and 10 jobs, including both portable profiles |
| Source-bound release and public artifacts | PASS: actual release job, exact tag, 7 assets, 6 checksum entries and 5 Hex packages |
| Clean public core/HTTP/Phoenix consumers | PASS: 1/3/5 tests, 0 failures; all 16 commands exit 0 |

The [local receipt](evidence/standalone-followup/final/local-qualification.json)
has SHA256 `d6c8cf32ba14b2e0d7db4843a3566ffb10ff6596ced20950e6bade83e3f8d10a`.
It records exact commands, source/archive/lock identities, counts, exits and log
hashes. Source-consumer core 1, HTTP 3, Phoenix 5 and browser 15 local results are
retained at their actual earlier source `ba89895887ac8509a091c1444b1699f6b7cd5631`.
The [equivalence receipt](evidence/standalone-followup/final/candidate2-equivalence.json)
and independent audit verify that only one unrelated unit fixture changed;
all product, dependency, configuration and consumer/browser fixture bytes match.
These retained local runs are not described as reruns at the final SHA.

The first candidate's [unit run](https://github.com/gsmlg-dev/gaoxy/actions/runs/39470756873)
remains FAIL: the existing trailer fixture passed 20 of 21 cases on macOS, then
the gate stopped before the remaining 13 unit cases. A length-zero TCP receive
returned the header and body chunk before the separate trailer write. The
controlled loopback diagnostic established a fixture read-boundary assumption,
not a missing renderer trailer. The correction reads the exact expected length
and asserts full wire equality within the original 100 ms timeout. Repeated
finish, trailer order, the 5 ms extra-byte check and all 21 cases remain intact.
The [fixture review](evidence/standalone-followup/reviews/native-proxy-seams.md)
and [initial CI receipt](evidence/standalone-followup/final/hosted-initial.json)
preserve the failure and repair. This fixture slice used one Sol repair round;
A and B remain two Sol rounds each, with no Astra rounds.

Final [static](https://github.com/gsmlg-dev/gaoxy/actions/runs/39473581131),
[unit](https://github.com/gsmlg-dev/gaoxy/actions/runs/39473581106) and
[Foundation](https://github.com/gsmlg-dev/gaoxy/actions/runs/39473581344) runs
all pass at the frozen source. The [hosted receipt](evidence/standalone-followup/final/hosted-ci.json)
and full logs distinguish successful strict builds from successful unit tests.
The specialist sustained-load step remains deliberately skipped.

The [immediate publication preflight](evidence/standalone-followup/final/publication-preflight.json)
at 18:35:26 UTC rechecked remote main, absent tag/release and HTTP 404 for all five
Hex versions. [Release run 39476108334](https://github.com/gsmlg-dev/gaoxy/actions/runs/39476108334)
passed and published v0.5.4 at 2026-10-20 18:38:07 UTC. The tag resolves to the
frozen source; the workflow generated no source commit. The
[release execution receipt](evidence/standalone-followup/final/release-execution.json)
links its full log, SHA256 `bdcb15e5d9462ee94d8b7d09960ab18cee37510b617b29a8340c37c56f1962ab`,
including exact source and 160-test repair success.

The [publication audit](evidence/standalone-followup/final/publication.json)
verifies fresh downloads, every asset API digest/size/state, six SHA256SUMS
entries and all five public Hex records. GitHub and public Hex package archives
match byte for byte. Raw local/hosted archives differ; payload bytes, file modes,
normalized parsed metadata and staged source match. The application artifact is
the established Linux x86_64 release, without production qualification.

The [public-consumer receipt](evidence/standalone-followup/final/public-consumers.json)
is bound to the frozen source at preparation and execution. It records isolated
public Hex home/cache/dependency/build directories, no repository authentication
or mirrors, actual Hex.SCM packages and the accepted upstream lock cohort.
Core 1, HTTP 3 and Phoenix 5 tests pass, including large JSON/form bodies.
Its SHA256 is `9dd9ad50086859daad8fbd2a21be02d8fe6df1bd33d8f0ce36e4cc27533bef4e`.

Independent lifecycle, compiler/QUIC, integration, fixture and final local
evidence reviews pass. The [final local audit](evidence/standalone-followup/reviews/final-candidate2-local-evidence.md)
and [CI/publication audit](evidence/standalone-followup/reviews/final-publication.md)
retain exact source, command and artifact checks. The separate
[public-consumer audit](evidence/standalone-followup/reviews/final-public-consumers.md)
also passes with no actionable findings.
Raw logs remain under `.audit/standalone-followup/` in the integration worktree
`.trees/standalone-ci-followup/`, including `final-candidate2/`,
`hosted-candidate2/final/`, `publication/` and the public-consumer run named in its
receipt. Historical logs and initial review dispositions remain unchanged.
This documentation closeout may advance main while the release tag stays fixed.

## Limits

Exceptional/disconnect/slow-peer/pressure/sustained-load/soak/combined suites are
NOT RUN by scope. `http_fetch#97` stays dismissed. No protocol expansion,
H2/H3 WebSocket proxy bridge, deployment, production data/certificate change,
Vault/public management change or release-artifact E2E enablement is included.
