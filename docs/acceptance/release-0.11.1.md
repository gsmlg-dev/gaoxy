# Gaoxy 0.11.1 acceptance

Date: 2026-10-22, Asia/Shanghai. Baseline `main`:
`6201d4270a5805993359868973f0fb019c1c1fe0`. The user requests all eligible
`internal request` fixes directly on `main` and the next patch release.
Only [#11](https://github.com/gsmlg-dev/gaoxy/issues/11) was eligible; no open
matching fix PR existed. See the [release plan](../plans/release-0.11.1.md).

## Implemented contract

HTTP/1 polling treats `max_buffer_bytes` as inclusive. At exact fullness it
reserves the existing conservative copy/probe resource floor before a one-byte
socket observation. Idle input returns `:pending`; peer closure remains visible;
an actual excess byte returns `:buffer_limit` without concatenating it. That
error is terminal: retain the returned connection and abort it. Aggregate
admission can still deny the reservation before any byte is consumed.
Request/I/O/shutdown limits and H2 transport dispatch are preserved.

The self-contained six-case public Plug/TCP suite covers delayed and initially
coalesced pipeline input. Exact 65,536-byte complete requests produce both
keep-alive responses. Public resource accounting synchronizes the full-buffer
observation and proves initial buffering in the coalesced cases. Excess input
and full-buffer peer closure have finite deadlines; focused Exchange tests
check the unchanged retained pipeline and bounded pre-read admission.

All own root/application manifests and current installation examples advance
to `0.11.1`. The six Hex distributions remain coordinated; dependency pins and
vendored upstream source/provenance are unchanged. The ordinary repair gate
adds six public-network cases and two focused boundary cases, **353 → 361**;
it preserves all pre-existing cases.

## Verification status

The baseline reproduction executed six tests: **2 passed, 4 failed**, including
the reported exact 65,536-byte rejection. This intentional red evidence remains
preserved separately from green checks. Final-source local, hosted and public
verification results will be recorded below; publication is not yet claimed.

Independent Sol specification/code review checks inclusive capacity, one-byte
observation, admission, deadline and transport isolation. Review requested
explicit coalesced-input/full-buffer synchronization and proof that initial
reads actually retained pipeline bytes; the fixtures include those assertions.
No specialist pressure, load or historical blocked-upload qualification is
included. Deployment, production data/certificates, Vault, public management
and disabled release-artifact E2E remain outside scope.

## Fresh local source checks

macOS arm64, canonical Elixir 1.18.5 / OTP 29, OpenSSL 3 selected explicitly;
independent Python 3.12.15, h2 4.3.0 and aioquic 1.2.0. Final focused tests use
seed 318229; the ordinary gate uses seed 0 and max cases 1.

| Check | Result |
| --- | --- |
| Focused Exchange/public Plug/TCP boundary tests | PASS: 38 tests, 0 failures, exit 0 |
| Canonical full formatting; strict production compile | PASS: both exit 0 |
| Package staging/build/metadata/payload regressions | PASS: 10 tests, exit 0 |
| Repair-gate execution accounting | PASS: 6 tests, exit 0 |
| Ordinary helper and unit groups | PASS: 69 + 182 cases, from the fresh all-gate run |
| Ordinary protocol group | FAIL: 32/33 passed across the fresh run and its final three-case continuation; Linux-specific alternate-loopback TLS case fails locally |
| Ordinary composition group | PASS: 77 cases, exit 0 |
| Independent specification/code review | PASS: [review report](evidence/issue-11/review.md) |

The complete local all-gate command remains **FAIL**, not 361/361 PASS. The
unchanged TLS test expects `127.0.0.2` to reach a wildcard listener as on Linux;
it does not reach its TLS-attempt barrier on this Mac. A separate VM loading
baseline Exchange reproduces the same failure (3 cases, 1 failure, exit 2).
No test or network configuration was changed. Linux hosted qualification must
pass the complete 361-case gate before publication.

The first all-gate attempt stopped at a 15-second H3 fixture barrier. Its cause
did not reproduce: the unchanged original 13-case file and the fresh all-gate
run passed it. The temporary isolated diagnostic passed 3 cases with unchanged
assertions; fixture certificate verification passed. The initial failure is
retained without claiming an established root cause.

Initial packaging used a Hex archive compiled for newer Elixir and failed
with `Enum.__in__/2` undefined under canonical 1.18.5. Installing a compatible
Hex archive in a task-local Mix directory restored all 10 packaging checks;
the original shared Hex 2.5.1 archive was restored. No product dependency or
lock changed. Built-package consumer, browser and standalone qualification
remain assigned to the existing hosted gates at this point.

Implementation Sol/Astra repair rounds: **0/0**. Evidence includes original
red/failed attempts and baseline probes; no assertion was weakened or excluded.
