# Gaoxy 0.12.2 release acceptance

Date: 2026-10-22, Asia/Shanghai. Publication source:
`55ed97d2b05ba2a8dd7c911472833e71dd6b87f7` on `main`.
**PASS:** local and exact-source hosted qualification, publication,
independent public-artifact verification and fresh public issue regressions.
The original RED and first failed artifact-transfer attempt retain their
actual results separately.

## Change and source identity

[#15](https://github.com/gsmlg-dev/gaoxy/issues/15) reports a cancelled HTTP/1
upload closing during socket identity lookup. The constructor now returns
identity errors. Its sole production caller treats `:closed`, `:einval` and
`:enotconn` as normal closure before endpoint dispatch, and preserves unexpected
errors. Existing monitored-owner admission cleanup, successful metadata and
finite/infinite deadlines remain intact. Dependency pins and vendor provenance
are unchanged. All six distributions and the standalone application target
0.12.2. See the [plan](../plans/issue-15-peer-close.md) and
[release notes](../releases/0.12.2.md).

Evidence below is under [peer-close-0.12.2](evidence/peer-close-0.12.2/).
Local runs used the uncommitted tree based at
`0e1f76b5a4a604cd6436f3d592ae7fb1fa36a1f0`. All **464 source fingerprints**
match the publication source exactly; `source-bridge.json` records that
comparison without rewriting the original log identities.

## Local verification and review

Environment: Linux x86_64, Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5, two BEAM
schedulers, Python 3.13.15; pinned protocol interpreter Python 3.12.13 with
h2 4.3.0 and aioquic 1.2.0. Commands, durations, exits and source fingerprints
are in `local-verification.json`; raw logs are byte-preserving gzip copies
with hashes in `local-evidence-manifest.json`.

| Check | Result |
| --- | --- |
| Controlled RED, before repair | **FAIL as expected:** 7 tests, 5 failures, exit 2, including the reported `MatchError` on `:enotconn` |
| Same controlled assertions after repair | **PASS:** 7 tests, 0 failures; peer/local closure, unexpected error, deadlines, metadata and admission cleanup |
| Synchronized TCP cases | **PASS:** 2 tests, 0 failures; actual `:enotconn` before constructor dispatch, normal owner close, cleanup, healthy sibling and follow-up |
| Canonical ordinary gate | **PASS:** 466 executed, 0 failures/excluded/skipped |
| Package staging | **PASS:** 12 tests |
| Formatting, strict test compilation, whitespace, inventory | **PASS**, exit 0; unit 198, component 144, protocol 124, 85 active and 149 retained files |
| Independent specification/code reviews | No remaining actionable findings; `reviews.json` retains the resolved TCP fragmentation assumption |

The initial RED stack reports 0.12.0 in existing BEAM metadata. Both affected
source files are identical between that release source and the pre-fix HEAD;
`red-source-identity.json` preserves the comparison. The original failure stays
failed. The protocol fixture now accepts a valid received body prefix rather
than assuming TCP coalescing. Final local runs observed submitted/received body
lengths 0/0 and 3/3, each with real peer identity failure before barrier release.

## Exact-source hosted workflows

All five workflows passed on the publication source: **10 required jobs
executed successfully**. The separate manual released-server job was skipped
as designed. `source-ci-receipt.json`, `source-ci-counts.json` and
`source-ci-raw.tar.gz` retain the source identities, metadata, logs and counts.

| Workflow | Run | Result |
| --- | --- | --- |
| Static checks and build | [39801796629](https://github.com/gsmlg-dev/gaoxy/actions/runs/39801796629) | PASS: format/inventory and build |
| Unit tests | [39801796992](https://github.com/gsmlg-dev/gaoxy/actions/runs/39801796992) | PASS: 198 app cases and script checks |
| Integration and end-to-end | [39801796801](https://github.com/gsmlg-dev/gaoxy/actions/runs/39801796801) | PASS: 144 component, 124 protocol, isolated network and clients |
| Portable HTTP smoke | [39801797113](https://github.com/gsmlg-dev/gaoxy/actions/runs/39801797113) | PASS: Linux and macOS start, one GET `/health` 200 `ok`, normal stop |
| Package and consumers | [39801796659](https://github.com/gsmlg-dev/gaoxy/actions/runs/39801796659) | PASS: package/consumer and optional-QUIC jobs |

## Publication and public verification

The guarded [release run 39803249750](https://github.com/gsmlg-dev/gaoxy/actions/runs/39803249750)
completed successfully with version 0.12.2, ref main and the full expected SHA.
[Gaoxy v0.12.2](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.12.2) is a
stable, non-draft release. `release-run.json`, `release.log.gz` and
`release-qualification.json` preserve the completed hosted execution.

| Release gate | Result |
| --- | --- |
| Isolated core, HTTP, H3 and gateway source consumers | PASS: 9 cases |
| Ordinary correctness on exact publication source | PASS: 466 executed, 0 failures/excluded/skipped |
| Built-package test consumers and production isolation | PASS: 7 cases plus manual/production/release checks |
| Unified Phoenix independent clients and peers | PASS: 8 checks, source restored and process exit 0 |
| Selected Phoenix certificate/message/stream regressions | PASS: 18 cases |
| Format, strict compile and standalone smokes | PASS: core, H1/H2 gateway and H3 |
| Six Hex builds/publications and public byte comparisons | PASS |
| Hosted fresh Hex-only consumers after publication | PASS: 7 cases plus production/release isolation |
| Tag and GitHub release | PASS: application archive, 6 package tarballs and SHA256SUMS |

Independent read-back of the public release also **PASS**, exit 0:

- All **8 assets**, their declared sizes/digests and **7 payload checksums**
  match the actual downloaded bytes.
- All **6 public Hex releases** are unretired. Their checksums and archive
  bytes match the GitHub package assets.
- All **135 packaged Elixir source files** match the exact publication commit:
  core 22, HTTP 45, H3 10, proxy 42, test helper 12 and adapter 4.
- The selected standalone release and its five own applications report 0.12.2;
  all seven HTTP/TLS/QUIC runtime dependencies match the source lock at 0.21.16.
  Required direct dependencies and HPAX absence checks pass.
- The remote tag was checked before and after verification and still resolves
  to the full publication SHA. A later evidence-only main commit does not move it.

`public-artifacts-receipt.json`, `github-release.json` and six `hex-*.json`
files retain the independent metadata and comparisons. Downloaded binary
payloads remain in the ignored audit directory.

The **first artifact read-back attempt failed**, exit 1: `gh release download`
exceeded 180 seconds with a partial standalone archive, before checksum/source
validation. Its receipt and command log remain in
`public-artifacts-timeout-receipt.json` and `public-artifacts-timeout.log`.
A bounded HTTP range request resumed the download from 21,364,032 to
29,405,179 bytes in 46.437 seconds, exit 0, matching the declared SHA-256.
`resume-download.json` retains the command, initial/final sizes and hashes.
The reviewed verifier's new explicit `--downloaded-assets` input copies only
the eight expected asset names into a fresh output directory. Current remote
metadata, every digest/size/checksum, all six live Hex byte/source comparisons,
runtime checks and the final tag recheck still execute. The subsequent full
verification passes; it does not turn the original timeout into a pass.
All 12 offline verifier checks pass after this helper change. The original
and final verifier, check logs and independent review are preserved.

A separate **fresh Hex-only 0.12.2 consumer passes all 9 issue regressions**,
zero failures/excluded/skipped, exit 0. It resolves exact Hex core/HTTP/adapter
versions without source-path overrides, strictly compiles, compares both
changed published modules with the commit, and executes the exact test files
copied from that commit. Both real TCP cases again observe `:enotconn`, with
submitted/received body lengths 0/0 and 3/3, normal owner termination, cleanup,
healthy sibling and fresh requests. `public-peer-close-receipt.json`, its four
compressed logs, Mix manifest and lock retain this execution.

The archived verification scripts ran from `.audit/release-0.12.2/` in the
project root. Restore them to that location to rerun their recorded commands.
Their offline harness checks are separate from the completed public executions.

## Issue closeout

After publication and independent verification, issue #15 was labeled
`internal request fixed`, [evidence-commented](https://github.com/gsmlg-dev/gaoxy/issues/15#issuecomment-6344741930)
and closed as completed. Fresh GitHub MCP search and paginated REST discovery
both return **0 open issues** labeled `internal request`. `issue-audit.json`,
`issue-final.json`, comments and both discovery responses retain this read-back.

Historical specialist pressure, slow-peer, blocked-upload/disconnect and
sustained-load evidence retains its actual deferred/failed/unexecuted
disposition. This ordinary issue regression adds no specialist, deployment,
production-data/certificate, Vault or public-management acceptance. The
released-server client suite retains its separate gate.
