# Standalone recovery and CI follow-up

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

## Evidence

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

## Limits

Exceptional/disconnect/slow-peer/pressure/sustained-load/soak/combined suites are
NOT RUN by scope. `http_fetch#97` stays dismissed. No protocol expansion,
H2/H3 WebSocket proxy bridge, deployment, production data/certificate change,
Vault/public management change or release-artifact E2E enablement is included.
