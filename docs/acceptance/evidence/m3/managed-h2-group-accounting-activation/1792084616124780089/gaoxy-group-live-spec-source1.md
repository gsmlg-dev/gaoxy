# Controlled F and Task E independent SPEC source audit

**Verdict: F source PASS; Task E executable-source gaps (2).** Runtime and full-stage acceptance NOT RUN by this reviewer.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Parent baseline HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`, tree `a26656f16425d35ccc08584ee0486abb296a3c39`; no Git/index commands. Repository read-only; only these two /tmp reports written.

## Findings

- **SPEC-LIVE-001 (medium): Task E4 handoff failure.** No failed selected-group transport handoff case found in assigned live source set. Successful handoff, pure malformed-envelope rejection and fixed-endpoint late-cancelled handoff are distinct. Add or identify a real selected-group failed handoff test with no Fetch bytes, genuine G selection/pins and Service cleanup held until terminal resolution, exact cleanup/no-effect and actor joins.

- **SPEC-LIVE-002 (medium): Task E4 partial/timeout writes.** No partial downstream write followed by failure/timeout case found: H1 failed write closes before pump resumes; H2 zero-credit test permits no DATA. Whole-write success/failure and zero-credit timeout are covered. Add or identify a real native downstream write that commits a strict prefix of one delivery then fails/times out; assert no whole-delivery ACK or successful termination, original completion handling and G/T/Service ledger timeline.

## Executable mapping

| ID | Source result | Assertions/source |
| --- | --- | --- |
| F1 | PASS | `boundary.ex:68` — Internal deterministic activation is literal :ok; no test bypass. |
| F2 | PASS | `http/session.ex:432` — Comment describes fixed reviewed internal gate; no new runtime authority API. |
| F3 | PASS | `preopen_control_test.exs:198-219,306-324` — Nil token rejects open and bind with unavailable, exact dropped state, no ready or extra error; queued/local terminal precedence retained. |
| F4 | PASS | `boundary_test.exs:594-609` — Valid original preparation succeeds; foreign transport resource ref is refused with invalid_group_opening. |
| F5 | PASS | `accounting_owner_test.exs:137-146,644-649` — Genuine invalid public checkout leaves full G state, actual sorted monitors and T public status exactly unchanged. |
| E1 | PASS | `endpoint_test.exs:19-211` — Four native downstream H1/H2 × TLS-H2/h2c cells execute target/query/ordered fields/raw responses/upload/trailers/early response/stream reset; each holds original G/T capability. |
| E2 | PASS | `support/managed_h2_group_fixture.exs:125-145; endpoint_test.exs:365-416` — Actual initial HEAD health settlement, unhealthy rejection and actual healthy recovery; TLS peer receipt/ALPN/SNI assertions. |
| E3 | PASS | `endpoint_test.exs:418-438` — Authentic baseline retirement denies stale selection while admitted original drains, with actual G/T/Service retirement cleanup. |
| E4 | PASS | `endpoint_test.exs:217-271` — C2/R32/P0 holds 32 distinct real connection/stream pairs, G/T caps, exact 527323584 cleanup sum, sufficient explicit 1GiB budget and bounded actual Service highwater; 33rd has no peer request or ledger decrement. |
| E5 | PASS | `endpoint_test.exs:482-574` — Four actual HEAD Probes hold exact65915448 bytes; fifth cannot create peer request or change cursor/bytes until original real completion frees capacity. Probe ledger distinct from Service. |
| E6 | PASS | `endpoint_test.exs:275-301,335-363,440-479; preopen_control_test.exs:52-254` — Cancellation/opening deadline and queued terminals at preopen/prebind preserve no-open/no-bind semantics; real bind cancellation has original G/T completion and no producer bytes; healthy sibling progresses. |
| E7 | PASS | `lifecycle_test.exs:20-40; endpoint_test.exs:181-211` — Real GOAWAY is connection-level failure with no replay and later new connection; real stream reset preserves simultaneous healthy sibling. |
| E8 | PASS | `lifecycle_test.exs:43-120` — Real producer death, downstream disconnect and pump-owner death join original completion before ledger refund, including healthy sibling progress. |
| E9 | PASS | `lifecycle_test.exs:123-181,218-282` — Whole native DATA write success and failure govern ACK; native H2 zero-credit timeout sends RST_STREAM8 with no DATA/second response/success termination, confirms original and preserves only genuine connection/Writer leases. |
| E10 | PASS | `lifecycle_test.exs:179-216` — Idle and total deadlines terminate real committed responses, exact original completion joins, no replay; total case observes one real byte first. |
| E11 | PASS | `failure_test.exs:19-173` — Actual guardian/Service/gate loss retains real original ledgers, missing receipts/backend failures explicit, missing Service never counted zero; distinct replacement progresses. |
| E12 | PASS | `failure_test.exs:175-307` — Actual HPACK256/257 regular-field failures retain G/T/control holds and original unconfirmed completion across failed shutdown/retirement; explicit UNCONFIRMED_WITH_RETAINED_FAILURE persists after test-owned disposal. |
| E13 | PASS | `accounting_owner_activation_test.exs:19-556` — Actual Probe claim/bind/finish authorization and PID/ref provenance, real public checkout capacity no-effect, nil-prebind guardian-loss fail-closed holds, recovery original completion and exact once refunds, health saturation and byte-short no-child denial. |
| E14 | PASS | `session_control_test.exs:124-183,183-338` — Actual Service activation scalar checks precede checkout; genuine transport pin handoff, ready/DATA/delivery/ACK/trailers/release controls preserve originals. Public Service removal and real owner DOWN cleanup are executable. |
| E15 | PASS | `support/managed_h2_group_fixture.exs` — Shared fixture uses actual independent peers/Gaoxy/G/T/Service; exact reserve/control sums and bounded ledgers; real actor/peer joins and forced0/live0, not fabricated cleanup. |
| E16 | GAP | `plan Task E4; session_control_test.exs:183-268` — No failed selected-group transport handoff case found in assigned live source set. Successful handoff, pure malformed-envelope rejection and fixed-endpoint late-cancelled handoff are distinct. |
| E17 | GAP | `plan Task E4; lifecycle_test.exs:123-181,218-282` — No partial downstream write followed by failure/timeout case found: H1 failed write closes before pump resumes; H2 zero-credit test permits no DATA. Whole-write success/failure and zero-credit timeout are covered. |
| E18 | NOT_RUN | `Task E5, prior browser draft SPEC30/30` — Browser draft readiness separately reviewed; real browser acceptance and its fresh evidence are not certified by this source assignment. |
| E19 | NOT_RUN | `Task E compatibility and Task F fresh gates` — Runtime live suite, compatibility/core-only/standalone, FULL code review and final acceptance remain root-owned; no runtime gate executed by reviewer. |

## Authentication and boundaries

Controlled F prerequisite current SHA `5a64912316de17f0143c5384a97b0b3396b379e859c5158424dacbf4a86f3626` exactly matches its receipt. Four F hashes equal the explicitly preformatter activation receipt; owner-test current SHA `3be48a3ea58ff72716de80b9ee1b8fce9afb976b6192ac2411469ba2f111efd1` differs from preformatter `2868ed0f1006c7b55e3c192341cd318f5dee0fff424d79ac479805575152c7d5`. Its current genuine invalid-checkout/no-effect assertions were reviewed directly. Root confirmed the hash difference is temporary diagnostic IO instrumentation, independently located at lines392-406, rather than merely formatting. Root reports diagnostic24/0 with wrapper exit1 (expected2); attribution of the preserved original FAIL24/1 remains unproved. Root will separately repair the evidenced test-budget mismatch and strengthen exact64 original pin equality; this source report does not certify that later repair or runtime. Full SHA inventory is in the JSON report.

Prior A-D SPEC35/35 and browser draft SPEC30/30 reviews remain scoped prior results; they do not certify live execution. Browser matrix, scoped compatibility/core-only/standalone, fresh runtime gates and CODE review remain root-owned. Negative HPACK/TLS cleanup uncertainty is preserved; missing Service is never interpreted as zero. No private actor/mailbox-memory proof or dismissed http_fetch#97 proof is requested.

Reviewer Sol repair rounds0; inherited Astra2/2 exhausted. Counter ledger remains SHA `583673657a6ee2ed4f20f7e5feb88ce6f0c6e9cadd3437159ca3c074c8121249`, without reset or guessed aggregation. Read-only commands all joined; one no-match shell glob was resolved with exact paths. No own processes remain; root runtime39821 was untouched.

Root can resolve the two findings with an existing executable mapping or narrow additive tests. No new product decision is required.
