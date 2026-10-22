# v0.11.0 publication evidence — 2026-10-22

Release/tag source: `638906cce7546028db2e8f5ecc8076957e889c09`.
This evidence is recorded by a later documentation-only HEAD; the tag is unchanged.
See [receipt.json](receipt.json) for commands, counts, source identities and raw
source hashes, and the [acceptance record](../../../backend-options.md) for disposition.

| Evidence | Scope |
| --- | --- |
| [static-final.json](static-final.json), [unit-final.json](unit-final.json), [foundation-final.json](foundation-final.json) | Ten successful exact-source prerequisite jobs |
| [release-final.json](release-final.json), [release-final.log.gz](release-final.log.gz) | Successful hosted prepublication checks, 353-case ordinary gate, standalone smoke, six Hex publications and fresh public consumers |
| [published-release.json](published-release.json) | GitHub release metadata and eight asset digests |
| [publication-readback.json](publication-readback.json), [published-SHA256SUMS](published-SHA256SUMS) | Independent asset/Hex byte, checksum and version readback; seven checksum entries |
| [hosted-browser-report.json](hosted-browser-report.json) | H1/H2/H3 peers, H2/H3 Chromium endpoints/WebSockets/reload, shutdown |
| [public-consumers.log.gz](public-consumers.log.gz) | Fresh local public Hex-only 7 tests plus manual/production/release isolation |
| [unit-failed.log.gz](unit-failed.log.gz) | Original Linux H2 fixture failure and macOS Rebar download BLOCKED_ENV |
| [h2-consumer-ordering-probe.exs](h2-consumer-ordering-probe.exs), [h2-consumer-ordering-probe-final.log.gz](h2-consumer-ordering-probe-final.log.gz) | Deterministic real-H2 negative reproduction and positive verification-before-close probe |
| [h2-consumer-ordering-probe.log.gz](h2-consumer-ordering-probe.log.gz) | Initial probe's cleanup-field assertion mistake, preserved without rewriting |
| [h2-consumers-repeated.py](h2-consumers-repeated.py), [h2-consumers-repeated.log.gz](h2-consumers-repeated.log.gz) | Original packaged workflow with base consumer repeated ten times: 34 tests total plus manual/production/release checks |
| [checks.json](checks.json), [format.log.gz](format.log.gz), [staging.log.gz](staging.log.gz), [backend-tests.log.gz](backend-tests.log.gz), [strict-compile.log.gz](strict-compile.log.gz) | Earlier canonical release preparation at the original feature-source/diff identity, retained separately from final-source checks |
| [SHA256SUMS](SHA256SUMS) | Checksums of every file in this evidence directory except this manifest |

Raw logs use deterministic gzip headers (mtime 0, no source filename). Decompressed
bytes match the source hashes in receipt.json. Images, package archives and Linux
binaries are omitted. `published-SHA256SUMS` describes the published artifacts;
`SHA256SUMS` describes this evidence directory. The Linux binary was not executed
locally on macOS. Earlier failures, unavailable checks and unsupported feature
boundaries retain their status; no deployment or sustained-load result is implied.
