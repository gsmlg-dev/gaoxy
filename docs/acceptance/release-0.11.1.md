# Gaoxy 0.11.1 acceptance

Date: 2026-10-22, Asia/Shanghai. Baseline `main`:
`6201d4270a5805993359868973f0fb019c1c1fe0`. The user requests all eligible
`internal request` fixes directly on `main` and the next patch release.
The initial query found only [#11](https://github.com/gsmlg-dev/gaoxy/issues/11);
no open matching fix PR existed. See the [release plan](../plans/release-0.11.1.md).

**Published / PASS:** [v0.11.1](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.11.1)
and all six coordinated Hex packages were published from source/tag
`09715de3f165db134e287e1ea5fd4e93b1325905`. All ten prerequisite jobs, the
release workflow, independent artifact readback and fresh public-package
regressions passed. Historical local/hosted failures below retain their status.

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
preserved separately from green checks. The local-stage observations below
preceded publication; final hosted and public results follow them.

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

## Hosted qualification and publication

The fix commit is `0a0ff602`; the coordinated release-source commit is
`09715de3f165db134e287e1ea5fd4e93b1325905`. Both were committed directly on
`main` and pushed without creating a worktree or PR. The later publication
record is documentation only and does not move the release tag.

| Exact-source hosted check | Result |
| --- | --- |
| [Static/build 39721732189](https://github.com/gsmlg-dev/gaoxy/actions/runs/39721732189) | PASS: format and Linux/macOS builds, 3 jobs |
| [Unit 39721732157](https://github.com/gsmlg-dev/gaoxy/actions/runs/39721732157) | PASS: Linux/macOS, 2 jobs; macOS passed unchanged on attempt 2 |
| [Foundation 39721732170](https://github.com/gsmlg-dev/gaoxy/actions/runs/39721732170) | PASS: native HTTP, portable Linux/macOS, optional QUIC and isolated network, 5 jobs |
| [Release 39726187686](https://github.com/gsmlg-dev/gaoxy/actions/runs/39726187686) | PASS: exact source/version; packaging; five isolated source consumers; ordinary 361/0; built-package consumers/isolation; browser; strict compile; standalone; publication; fresh Hex-only consumers |

All ten prerequisite jobs passed before dispatch with `version=0.11.1`,
`git_ref=main` and the full `expected_sha`. Browser evidence records eight
successful checks using Chromium 155: independent H1/H2/H3, H2/H3 browser and
WebSocket paths, code reload/restore and endpoint shutdown. Phoenix's additional
client-certificate, capacity and streaming suite passed 17 tests. Standalone
core/Gateway/H3 smoke checks passed on the Linux runner.

The first macOS unit attempt remains **FAIL**: the unchanged suspended-H2
body-read test took 121 ms against its `< 100` assertion. Its trace records a
29 ms owner wait followed by a timer witness 91 ms late. The relevant test and
H2 transport files are unchanged from baseline. The failed job was rerun with
the same source, seed, assertions and deadlines; all required cases and its
subsequent package consumers passed. No product repair or assertion relaxation
was made. Original metadata/logs are retained alongside the successful result.

The workflow published six Hex distributions (`gaoxy_websock_adapter`, `gaoxy`,
`gaoxy_http`, `gaoxy_http3`, `gaoxy_proxy`, `gaoxy_test`), compared their public
bytes, created `v0.11.1` at the expected source, and published the GitHub release
at **2026-10-22T05:16:33Z**.

## Independent public verification

| Check | Result |
| --- | --- |
| Downloaded GitHub assets | PASS: 8 asset digests and all 7 `SHA256SUMS` entries |
| All six actual public Hex archives | PASS: exact API/archive versions and checksums; byte equality with GitHub assets |
| Published HTTP implementation | PASS: archive and clean installed Exchange bytes equal the independently reviewed release source |
| Release tag/source | PASS: local and remote tag resolve to `09715de3f165db134e287e1ea5fd4e93b1325905` |
| Fresh general public Hex-only consumers | PASS: base 3 + H3 2 + HTTPFetch 2 = 7 tests, plus manual mode, production dependency isolation and assembled-release isolation |
| Fresh issue-specific public Hex-only install | PASS: unchanged six-case public Plug/TCP file, seed 0, max cases 1; dependency resolution and strict compilation also exit 0 |
| Downloaded standalone metadata | PASS: release version 0.11.1; `gaoxy_test` and `ex_unit` absent. Linux binary NOT RUN locally on macOS; hosted Linux runtime smoke passed |

Readback executes 44 explicit artifact/source checks. Public tests use canonical
Elixir 1.18.5 / OTP 29 and the same independent peer environment documented
above, without local source dependency overrides. See the
[evidence index](evidence/issue-11/INDEX.md) and structured receipts.

The `fixes #11` commit closed the issue when pushed to `main`. After publication
and public verification it received `internal request fixed` and a
[publication/contract comment](https://github.com/gsmlg-dev/gaoxy/issues/11#issuecomment-6333371223).

The final live issue query found new requests
[#12](https://github.com/gsmlg-dev/gaoxy/issues/12),
[#13](https://github.com/gsmlg-dev/gaoxy/issues/13) and
[#14](https://github.com/gsmlg-dev/gaoxy/issues/14), created during this run at
04:40:11Z, 04:41:11Z and 04:49:25Z respectively, after the initial fix/release
source had already been pushed. They remain open and are outside this initial
issue batch and immutable 0.11.1 publication. This record does not claim that
the current open issue list is empty.
