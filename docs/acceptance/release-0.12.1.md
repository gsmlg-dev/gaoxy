# Gaoxy 0.12.1 release acceptance

Date: 2026-10-22, Asia/Shanghai. Publication source:
`c94d71d438fae77c6d8a88b2d5f9782d45807177` on `main`.
**PASS:** exact-source hosted qualification, publication and independent
public-artifact verification. Earlier local migration checks and failed
preparation attempts retain their original source identities and results.

## Change and source identity

Native H2 now uses the documented `HTTP.HTTP2.HPACK` codec from a direct
`http_core ~> 0.21 and >= 0.21.16` dependency. Gaoxy retains server lifecycle,
decoder state and header bounds, with zero-capacity response encoding. HPAX is
removed from the root and Phoenix locks. The resolved HTTP/TLS/QUIC cohort is
0.21.16; `elixir_quic_http3`, `http_fetch` and `http_web_socket` use `~> 0.21`.
All six Hex distributions and the standalone application target 0.12.1. The
staged `gaoxy_test` H3 extension remains optional.

See the [implementation plan](../plans/public-hpack.md) and
[release notes](../releases/0.12.1.md). Local migration commands ran against the
uncommitted migration on HEAD `4ed1a506f87cd56d1908e6fffbd57e57e03bb6b1`,
subsequently committed as `fcb92582212f9c461429aa4c0de306dbca2c2ea2`.
All 43 saved migration fingerprints match that commit. At the publication SHA,
39 match unchanged and four manifests differ only by the 0.12.1 version bump.
The RFC report's 155 fingerprints likewise have 148 unchanged files and seven
version-only manifests. This [source bridge](evidence/public-hpack-0.12.1/publication-source-bridge.json)
links earlier local evidence to the release source; it is not a fresh execution
on the publication commit.

The previous candidate, `dd70d7667d5cc3aa631cce9444efeda5d3d5e5c2`,
contains the version preparation. The publication source adds only the
independently reviewed portable consumer strict-compilation setup budget
increase from 300 to 600 seconds. Locked dependency resolution, mandatory
dependencies, independent compilation, `--warnings-as-errors`, the 30-second
runtime budget and exact health/normal-stop assertions are unchanged. This
script change is recorded separately in the source bridge; it is outside the
earlier 43-file and 155-file fingerprint sets.

## Preserved local migration results

Environment recorded by the plan: Linux 6.18.48 x86_64, Elixir 1.18.5,
OTP 28 / ERTS 16.4.0.5, Python 3.13.15 and two BEAM schedulers. Independent
peers: h2 4.3.0, hpack 4.1.0, hyperframe 6.1.0 and aioquic 1.2.0.
PASS rows below are preserved completed runs, with exit 0 recorded in the plan.

| Check | Recorded result | Evidence under `evidence/public-hpack-0.12.1/` |
| --- | --- | --- |
| `mix deps.get --check-locked`; strict compile | PASS; no umbrella optional warning | `local/resolve.log.gz`, `local/compile.log.gz` |
| `python3 scripts/check-repairs.py unit` | PASS; 198 cases across 37 files, zero failures/excluded/skipped; includes five codec cases | `local/unit.log.gz` |
| Scoped ordinary mixed HTTP, defaults, H2 WebSocket/lifetime and proxy rejection tests | PASS; 14 cases, zero failures/excluded/skipped | `local/protocol.log.gz` |
| Three planned decoder-state/renderer location selectors | PASS; five executed, zero failures/skipped; 31 other cases excluded by location selection | `local/selected-state-rendering.log.gz` |
| Independent selected H2 RFC harness | PASS; 40 checks, clean runtime stop and port rebound; selected h2c coverage | `rfc/results.json`, `rfc/gateway.log.gz`, `local/rfc.log.gz` |
| `python3 scripts/test-stage-hex-packages.py` | PASS; 12 tests, all six package metadata contracts | `local/packages.log.gz` |
| Built-package consumers | PASS; base 3, H3 2, HTTPFetch 2; manual, production and release-isolation receipts each one | `local/consumers.log.gz` |
| Fresh source core and HTTP consumers | PASS; core one, HTTP four cases | `local/source-consumers.log.gz` |
| Dependency graph | PASS; HTTP requires `http_core`, excludes HPAX; clean core still excludes HTTP/QUIC | `local/graph.log.gz`, consumer logs |
| Phoenix example locked resolution and strict test compilation, H3 enabled | PASS | `local/phoenix-resolve.log.gz`, `local/phoenix-compile.log.gz` |
| Scoped formatter, diff whitespace and test inventory | PASS recorded in plan; unit 198/component 137/protocol 122, 83 active and 149 retained files | Plan and committed manifest/inventory; no separate local log preserved |
| Independent specification and code-quality reviews | No actionable findings recorded in plan | Plan; separate review transcripts are not included |

Logs are byte-preserving gzip copies with zero timestamp and no embedded
filename. Original paths, uncompressed hashes and stored hashes are in the
[evidence manifest](evidence/public-hpack-0.12.1/evidence-manifest.json).
The [original migration fingerprints](evidence/public-hpack-0.12.1/source-sha256.json)
and RFC JSON are preserved without rewriting their recorded source identities.

## Historical failures retained

The codec red run recorded five cases with three expected option-mapping
failures; the final unit run passes all five. The package metadata red run
failed one test while HPAX remained in the package requirements; its original
failure is preserved in `local/package-red.log.gz`, followed by the passing
12-test package run. An initial stale test build referenced HPAX and ran zero
tests; the plan records forced strict recompilation followed by the passing
runs above. Separate raw codec-red and stale-build logs were not available in
the assigned local evidence set. These histories are not counted as passes.

Both macOS portable attempts on the previous candidate
`dd70d7667d5cc3aa631cce9444efeda5d3d5e5c2` failed at the strict-compilation
300-second setup deadline, with zero HTTP requests. Attempt 1 reached Gaoxy
compilation; attempt 2 completed Gaoxy and reached Plug compilation. These
remain **FAIL**; neither establishes an HTTP smoke result. The compile-only
600-second repair does not turn either failure into a pass. Both raw attempts
are preserved in `source-ci-prerepair-raw.tar.gz`, including metadata, logs and
the two portable consumer artifacts. The archive's SHA-256 is
`ddcfa30eab0e7cdd4454cd7775c3a16255ba7a4cd3600c9d4ac94c23342a2f4b`.

## Exact-source hosted workflows

All five source workflows passed on the full publication SHA above: 10
required jobs executed successfully. The separate manual released-server
client job was skipped as designed. Raw run/job metadata and logs are retained
in `source-ci-raw.tar.gz`; `source-ci-receipt.json` and `source-ci-counts.json`
retain conclusions, source identities and executed-count markers.

| Workflow | Exact-source run | Result |
| --- | --- | --- |
| Static checks and build | [39761986012](https://github.com/gsmlg-dev/gaoxy/actions/runs/39761986012) | PASS: format/inventory and build |
| Unit tests | [39761986074](https://github.com/gsmlg-dev/gaoxy/actions/runs/39761986074) | PASS: 198 app cases plus script regressions |
| Integration and end-to-end tests | [39761986335](https://github.com/gsmlg-dev/gaoxy/actions/runs/39761986335) | PASS: 137 component, 122 protocol, isolated network and independent clients |
| Portable HTTP smoke | [39761986278](https://github.com/gsmlg-dev/gaoxy/actions/runs/39761986278) | PASS: Linux and macOS start, one `/health` response 200 `ok`, normal stop |
| Package and consumer qualification | [39761986185](https://github.com/gsmlg-dev/gaoxy/actions/runs/39761986185) | PASS: package/consumer and optional-QUIC jobs |

The fresh macOS artifact reports `PASS`, one request, successful stop and exit
0 at the exact publication SHA. `portable-macos-result.json` and its compressed
consumer log preserve this execution with the 600-second compile setup budget.
The runtime budget remains 30 seconds.

## Publication

The guarded [release run 39762919442](https://github.com/gsmlg-dev/gaoxy/actions/runs/39762919442)
was dispatched with version `0.12.1`, ref `main` and the full expected SHA.
**PASS:** qualification, publication and fresh public consumers completed.
[Gaoxy v0.12.1](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.12.1) is a
stable, non-draft release. Remote `main` and `v0.12.1` both resolved to the
publication SHA at read-back; an evidence-only closeout commit may advance
`main` without moving the release tag.

| Release gate | Result |
| --- | --- |
| Isolated core, HTTP, H3 and gateway source consumers | PASS: five consumers, nine ExUnit cases |
| Ordinary correctness on exact publication source | PASS: 457 executed, zero failures/excluded/skipped |
| Built-package test consumers and production isolation | PASS: seven cases plus manual/production checks; helper and ExUnit absent from production release |
| Unified Phoenix independent clients/peers | PASS: eight checks, H1/H2/H3, H2/H3 channels, reload/restore and shutdown |
| Selected Phoenix certificate/message/stream regressions | PASS: 18 cases |
| Format, strict compile and standalone smokes | PASS: core, H1/H2 gateway and H3 |
| Six Hex package builds/publications and public archive byte comparisons | PASS |
| Fresh Hex-only consumers after publication | PASS: seven cases plus production/release isolation, version 0.12.1 |
| Tag and stable GitHub release creation | PASS: application archive, six package tarballs, SHA256SUMS |

`release-run.json`, `release.log.gz` and `release-qualification.json` preserve
the hosted results and positive executed counts. The unified Phoenix report
and compressed server log are retained alongside them. The fresh public
consumer run is completed hosted public-package evidence.

## Independent public-artifact verification

Command:
`python3 -B .audit/release-0.12.1/verify-public-artifacts.py --sha c94d71d438fae77c6d8a88b2d5f9782d45807177`.
**PASS**, exit 0, using independent public downloads and metadata read-back.

- The stable GitHub release has exactly eight assets. Every declared asset
  size/digest and all seven payload checksums match the downloaded bytes.
- All six Hex 0.12.1 releases are unretired. Their checksums and tarball bytes
  match the GitHub package assets.
- All 135 packaged `lib/**/*.ex` files match `git show` at the exact publication
  SHA: core 22, HTTP 45, H3 10, proxy 42, test helper 12 and adapter four.
- The standalone release and five own runtime applications report 0.12.1.
  All seven HTTP/TLS/QUIC runtime dependencies report 0.21.16, matching the
  publication-source lock. HTTP and H3 runtime metadata retain their required
  direct dependencies.
- HPAX is absent from all package requirements, metadata and manifests, plus
  standalone runtime directories, release metadata and all 33 application
  metadata files. The public `gaoxy_http` package requires nonoptional
  `http_core ~> 0.21 and >= 0.21.16`.
- The remote release tag was checked twice and still resolves to the full
  publication SHA.

`public-artifacts-receipt.json`, the raw GitHub/six Hex metadata files and
`public-verification-command.json` preserve these results. The receipt's SHA-256
is `ee04510e1ce5ff69993f70ab376a71ed372e49a6bc10b872bd8e4bd659909377`.
The verifier and its 12 passing offline checks are also retained; those checks
qualify the harness and are separate from this completed public read-back.
Downloaded binary assets remain in the ignored audit directory.

Specialist pressure, slow-peer, disconnect and sustained-load qualification
retain their existing NOT RUN/deferred dispositions. This record adds no
specialist, production, deployment, certificate, Vault or public-management
acceptance claim. Released-server client checks retain their separate gate.
