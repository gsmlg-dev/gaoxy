# Gaoxy 0.9.0 release acceptance

Date: 2026-10-22, Asia/Shanghai. Work starts directly on `main` at
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`. The user requests all eligible open
`internal request` fixes and publication of the next version. The initial three
requests were supplemented by four newly opened requests during execution.

Status: **Published as v0.9.0; local, hosted and public qualification PASS
under the recorded environments. All seven requests are closed.** See the
[release plan](../plans/release-0.9.0.md).

## Implemented requests

| Request | Result and scope | Evidence |
|---|---|---|
| #3/#7: active SSE lifetime | Public listener/route stream policy supports `:request`, positive milliseconds and `:infinity` on H1/H2, after request-body EOF. Header/body acquisition, individual I/O, admission and shutdown remain finite. H2 policy is stream-local; H3 rejects the opt-in explicitly. | H1 10, independent H2 2, public contract 3, Generation cleanup 9, H3 boundary 1, real Phoenix 2; independent review PASS |
| #5: verified client certificates | Optional/required client presence with trusted-CA verification, trusted DER propagation to actual Phoenix HTTP/WebSocket peer data, untrusted-client rejection and forged-header isolation under TLS 1.2/1.3. | Core configuration 4, Phoenix configuration 2, real TLS 4; nearby author regressions 27; independent review PASS |
| #6/#9: WebSocket and LiveView capacity | Omitted message ceiling follows configured frame ceiling. Explicit message limits, fragmented totals and service-budget clamps remain authoritative. Actual escaped 300 KiB LiveView form input survives rendering, retained application state, HTTP reload and WebSocket rejoin. | Configured limits 6, actual Phoenix channel 6; LiveView 4 including frame/aggregate rejection; independent review PASS |
| #8: valid Phoenix transport options | Accept Phoenix-owned `log` and `code_reloader` options while keeping wire-engine validation strict. | Direct options 2 and actual H1 upgrade/channel exchange 1; independent review PASS |
| #10: supervised shutdown allowance | HTTP/H3 wrappers share the pure validated core-limit shutdown budget. User initialization remains deferred until startup. Actual supervised active H1 uploads drain and release owned runtime/socket resources with default 5000 ms and configured 5500 ms drain limits. | HTTP 5, H3 budget/initialization contract 2; nearby author regressions 18; independent review PASS |

The final combined issue gate executes **46 root tests and 17 real Phoenix
tests**, with zero failures, exclusions or skips. The HTTP/3 shutdown evidence
is a budget/initialization contract; actual supervised active-upload evidence
uses H1. Manifold, SecretHub, Sigma, Backplane and other requesting applications
still own their downstream migration/production acceptance.

## Final source qualification

Environment: Linux x86_64, Elixir/Mix 1.18.5, Nix OTP 28.5.0.7
(ERTS 16.4.0.6), `ELIXIR_ERL_OPTIONS='+S 2:2'`. Python drivers use 3.13.15;
independent peers use Python 3.12.13, h2 4.3.0 and aioquic 1.2.0.
Browser qualification uses Playwright 1.56.0 and installed Chromium.

Source manifest: `source-files.json.gz` in the evidence directory; its sorted
JSON content fingerprint is
`83787ae55fa912c87d19b7c252117bd4144c5e64e67fcbc83a64b5fe152f2be5`.
It records runtime, tests, workflows, fixtures, manifests and dependency locks
on the uncommitted candidate. No source file changed during final verification;
the unified browser test restored its temporary source edit.

| Gate | Command/evidence | Result |
|---|---|---|
| Issue-specific root regressions | Eleven files selected explicitly by `scripts/check-tests.py`, seed 0, max cases 1 | PASS: 46/0, exit 0 |
| Real Phoenix issue regressions | Four issue files in `examples/phoenix_native`, same wrapper/seed | PASS: 17/0, exit 0 |
| Ordinary compatibility | `python3 scripts/check-repairs.py all` | PASS: exactly 265/0, zero excluded/skipped, exit 0 |
| Canonical format and strict production compile | `mix format --check-formatted`; `MIX_ENV=prod mix compile --warnings-as-errors` | PASS: both exit 0 |
| Standalone assembly | `MIX_ENV=prod mix release gaoxy --overwrite` | PASS: exit 0 |
| Packaging-tool regressions | `python3 scripts/test-stage-hex-packages.py` | PASS: 9/0, exit 0 |
| Five actual Hex archives | Staging, `mix hex.build`, independent metadata/payload inspection | PASS: all 0.9.0; exact runtime/source payloads, Hex-only dependency metadata, unchanged vendor provenance, MIT licenses; exit 0 |
| Five isolated source consumers | Existing core, HTTP, H3, Gateway and H3 Gateway scripts | PASS: 9/0 across five isolated source consumers, exits 0 |
| Unified Endpoint browser/peer acceptance | `integration/phoenix_native/unified.py` | PASS: 8 checks, H1/H2/H3, Channels/LiveView, reload/restore and shutdown; exit 0 |
| Local standalone runtime | Sequential core, Gateway and H3 smoke scripts | PASS: 3 transports + 7 exchanges + 3 H3 checks; exits 0 |
| Workflow lint and whitespace | `nix shell nixpkgs#actionlint --command actionlint ...`; `git diff --check` | PASS: exits 0 |
| Independent specification/code and final release-source review | Reports in `evidence/internal-requests/` | PASS: no unresolved findings |

The package cohort is `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`,
`gaoxy_http3`, and `gaoxy_proxy`. Six own application/umbrella manifests are
0.9.0; `gaoxy_server` ships inside the standalone application. Vendored upstream
metadata remains 0.6.0; staging gives its Gaoxy distribution version 0.9.0.
Dependency locks and vendor source/provenance remain unchanged.

## Preserved failed and unexecuted attempts

Expected red tests, unsuccessful fixtures and review findings retain their real
status in the archived audit evidence; none is relabeled passing.

- A combined streaming candidate failed its exact HTTP500 assertion under an
  unrelated 120 ms deadline (seed 58592). An unchanged isolated rerun passed.
  Only that new rejection test now uses 1000 ms; actual expiry cases keep 120 ms.
- Independent review reproduced an infinite H2 body-read owner wait. The owner
  wait is now finite, with its deterministic regression retained.
- Extended streaming exposed Generation capture cleanup after the original
  deadline plus one second. The repair gives confirmed transitioned streams a
  fresh finite cleanup allowance and preserves ordinary/acquisition deadlines.
- The first ordinary compatibility run found six exact worker-constructor
  accounting failures: the numeric H2 model omitted the new Exchange field and
  undercharged its initial map by 21 bytes. The model includes it; all original
  independently constructed complete-Exchange assertions remain unchanged and
  the fresh 265-case ordinary gate passes.
- The first #10 implementation invoked user initialization while constructing
  a child spec. Independent probes and two failing initialization regressions
  established the defect. One successful Sol repair uses the pure common budget
  helper; fresh default/non-default active drain and initialization tests pass.
- Early test fixtures had an HPAX tuple shape error, an incorrect assumption
  about WebSockAdapter's frame default, and a wrong resource snapshot owner.
  Their failed evidence remains preserved alongside the corrected fixtures.
- Parent environment attempts found missing pip, unavailable direct actionlint,
  and an unfetched optional H3 Phoenix dependency. No test was executed by the
  failed dependency attempt. The prepared environment and actual lint/test
  reruns pass. A temporary archive verifier initially expected the fixture's
  Apache license; actual source/package licenses are MIT, verified explicitly.
- Initial hosted macOS unit qualification at `044e1cd9` failed two existing
  deadline assertions: H1 elapsed 634 ms against 250 ms and H2 elapsed 157 ms
  against 100 ms. Scheduler witnesses recorded 604 ms and 127 ms lateness.
  The unchanged tests passed at the final candidate; the original FAIL remains
  archived and is not described as a product repair.
- The first downloaded standalone attempt on NixOS failed before VM startup
  because the host lacked `libtinfo.so.6`; linkage also identified absent zlib
  and C++ runtime libraries. Zero application checks executed. The failed
  receipt/logs remain preserved separately from the successful qualified run.

Specialist abnormal/disconnect/pressure/load suites retain their historical
statuses and remain assigned to their dedicated environment. Deployment,
production operations/data/certificates, Vault, public management and the disabled
release-artifact E2E workflow remain outside this acceptance.

## Publication and public verification

The qualified implementation was committed and pushed as
`044e1cd90ddf4cc1550df99411f2906209387f5f`. Hosted static/build and Ubuntu unit
gates passed. Foundation native HTTP exposed an incorrect new shutdown-test
premise: the documented single-service pending aggregate can win the caller
deadline race. Its failed result is preserved; a bounded real-H2 reproduction,
narrow test-contract correction, stronger instance-termination assertions,
independent review and fresh 46/0 issue gate are recorded in the
[repair evidence](evidence/internal-requests/hosted-h2-contract-repair.md).
Only two test files changed from the original 557-entry source manifest;
runtime and package payloads remain unchanged. The original qualification
fingerprint and evidence above retain their historical identity.

The final release source and local/remote `v0.9.0` tag resolve to
**`ed3fbbfbe4016906b10a97711193d341f3d9ed4f`**. The refreshed source-manifest
fingerprint is
`d82c696ee30d855d79e9c0e8e2de8ecb17246d8c7ecaeddc8763172188f55bd2`.
The later documentation/evidence commit on `main` does not move that tag or
change the published payloads.

| Hosted gate at the release SHA | Result |
|---|---|
| [Static/build 39650998389](https://github.com/gsmlg-dev/gaoxy/actions/runs/39650998389) | PASS: format and Linux/macOS builds, 3 jobs |
| [Unit 39650998345](https://github.com/gsmlg-dev/gaoxy/actions/runs/39650998345) | PASS: Linux/macOS, 2 jobs |
| [Foundation 39650998362](https://github.com/gsmlg-dev/gaoxy/actions/runs/39650998362) | PASS: native HTTP, Linux/macOS portable, optional QUIC and isolated network, 5 jobs |
| [Release 39653398896](https://github.com/gsmlg-dev/gaoxy/actions/runs/39653398896) | PASS: exact-SHA/version validation, issue 46/0, five source consumers, ordinary 265/0, browser 8 checks, Phoenix 17/0, strict builds and standalone 13 checks before publication |

All ten prerequisite hosted jobs completed successfully before dispatch with
`version=0.9.0`, `git_ref=main` and that full `expected_sha`. The workflow
published the five Hex distributions, compared their public bytes, then created
the tag and [GitHub release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.9.0)
at `2026-10-21T18:41:04Z`. The release has seven uploaded assets: the Linux
x86_64 standalone archive, five Hex archives and `SHA256SUMS`.

Public Hex packages:
[gaoxy_websock_adapter](https://hex.pm/packages/gaoxy_websock_adapter/0.9.0),
[gaoxy](https://hex.pm/packages/gaoxy/0.9.0),
[gaoxy_http](https://hex.pm/packages/gaoxy_http/0.9.0),
[gaoxy_http3](https://hex.pm/packages/gaoxy_http3/0.9.0), and
[gaoxy_proxy](https://hex.pm/packages/gaoxy_proxy/0.9.0).

| Independent public verification | Result |
|---|---|
| Downloaded assets and actual public packages | PASS: 7 assets, 6 checksum entries, GitHub/Hex bytes equal, API checksums equal, exact staged/source files and 122 runtime payload files verified |
| Fresh isolated public-Hex consumers | PASS: core 2/0, HTTP 10/0, Gateway 2/0, H3 Gateway 4/0; total 18/0, unchanged source tests and upstream cohort, exact public-cache checksums |
| Fresh public-Hex Phoenix consumer | PASS: four issue files 17/0 plus dependency-isolation 1/0; total 18/0, zero excluded/skipped; dependency resolution, locked resolution, strict compile and tests all exit 0 |
| Downloaded standalone, sequential core/Gateway/H3 | PASS: 3 + 7 + 3 = 13 checks, all exit 0; unmodified public archive with explicitly supplied host library paths |

The downloaded standalone SHA-256 is
`640ebc50a365390fbb2897c1061fa40d14473ff06edc0cb822571c5ade764eed`.
The successful NixOS run supplies pinned Nix ncurses 6.6, zlib 1.3.2,
OpenSSL 3.6.5 and GCC 15.3 runtime libraries via `LD_LIBRARY_PATH`;
`nix develop` supplies `unbuffer`. The receipt records the exact store paths,
`NIX_LD_LIBRARY_PATH` and `ERL_FLAGS`. This is execution evidence under that
explicit environment, without an additional default-NixOS portability claim.

After these public checks, issues
[#3](https://github.com/gsmlg-dev/gaoxy/issues/3),
[#5](https://github.com/gsmlg-dev/gaoxy/issues/5),
[#6](https://github.com/gsmlg-dev/gaoxy/issues/6),
[#7](https://github.com/gsmlg-dev/gaoxy/issues/7),
[#8](https://github.com/gsmlg-dev/gaoxy/issues/8),
[#9](https://github.com/gsmlg-dev/gaoxy/issues/9) and
[#10](https://github.com/gsmlg-dev/gaoxy/issues/10)
were commented, labeled `internal request fixed` and closed. A final live,
paginated query found zero open `internal request` issues.

The [public qualification receipt](evidence/internal-requests/public-qualification.json)
indexes the four public receipts and the compact `public-audit.tar.gz` archive.
The archive preserves hosted summaries/logs, original failed attempts, public
consumer/runtime logs, exact runtime environment, verification-script hashes,
issue closure actions and final live remote audit. It excludes downloaded
binaries, dependency/build caches and private fixture keys. Initial local
qualification and hosted-H2 repair archives remain unchanged.
