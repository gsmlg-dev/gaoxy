# Gaoxy v0.5.1 Hex packaging acceptance

Date: 2026-10-20, Asia/Shanghai. Release preparation is on `main`, as requested.
GitHub release and Hex publication are pending the actual workflow outcome.
The [plan](../plans/release-0.5.1-hex.md) defines this packaging-only scope.

| Gate | Actual result |
| --- | --- |
| Packaging regressions | PASS: seven tests, including five real Hex builds, exact dependency metadata, source/archive byte preservation, rejection cases and an actual publish dry run |
| Clean signed-registry consumers | PASS: core 1, HTTP 2, Phoenix 4 tests; 7 total, 0 failures, no skips/exclusions; fresh strict compilation and all dependencies resolved with Hex.SCM |
| Final five package builds | PASS: 0.5.1 package metadata and manifests match consumer-qualified inputs; only the four own package READMEs changed afterward |
| Runtime payloads | PASS: all 106 package runtime files match source; adapter licensing/provenance preserved |
| Canonical formatting and strict production compilation | PASS: Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5, `ELIXIR_ERL_OPTIONS='+S 2:2'`, `MIX_ENV=prod` |
| Workflow lint | PASS: actionlint 1.7.12 |
| Package-only publish dry run | PASS after fetching production dependencies; regression also proves the original unfetched-dependency failure, no compilation and no upload requests |
| Independent review | PASS: specification, staging, publish regression, workflow, consumer evidence and final artifact equivalence; no remaining actionable findings |
| Hosted release execution | NOT RUN for the final source; preceding CI runs at `f9e155cb` were BLOCKED_ENV with zero executed steps |
| Hex publication | NOT PUBLISHED: all five public 0.5.1 release endpoints returned 404 during preparation |
| GitHub publication/download verification | PENDING |
| New standalone binary, specialist suites and deployment | NOT RUN here; outside the local package fallback |

The five distributions are `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`,
`gaoxy_http3` and `gaoxy_proxy`. All have version 0.5.1. Gaoxy uses MIT;
the adapter distribution retains upstream WebSockAdapter 0.6.0 MIT attribution,
patch and provenance, with OTP application name `websock_adapter`.
Hell 0.1.2 and Abyss 0.7.0 published runtime sources match their accepted Git
pins. Runtime libraries, the vendored adapter and the root lock remain unchanged
from v0.5.0. No new protocol capabilities are claimed.

Consumer run `run-1792474727892739476` uses a disposable signed local Hex
registry, isolated cache/dependency/build directories and the original existing
core, HTTP and Phoenix assertions. It verifies the documented
`websock_adapter` to `gaoxy_websock_adapter` alias without path/Git overrides.
The registry process shut down normally. One harness import-shadowing error was
repaired before the successful run; no product repair or assertion change was
needed. This verifies packaging and ordinary consumer behavior, not availability
on the public Hex registry.

Final package run `release-0.5.1-final-1792475186943961119` preserves every
consumer-qualified manifest, metadata record and runtime payload. The adapter
tarball is byte-identical; the four own tarballs differ only in README content.
The final independent review binds these two evidence sets before publication.
The [preflight evidence manifest](evidence/release-0.5.1/preflight/manifest.json)
retains 38 selected receipts, logs and the consumer harness, with verified
lossless log compression. It excludes package archives, dependency checkouts and
private registry keys. The [fresh checks](evidence/release-0.5.1/preflight/checks/result.json)
record commands, environment, source hashes, times and exit codes; seven
packaging regressions passed again after independent review. Original
unfetched-publish failure evidence remains separately archived.

The workflow builds all five packages before uploading any package, fetches
production dependencies for each staged project in dependency order, and
compares public downloads with the prebuilt tarballs before tagging. An active
release is not cancelled by another dispatch. `HEX_API_KEY` remains the
configured organization Actions secret; no secret extraction or account-setting
changes are part of this work.

If the new hosted run also cannot start, the GitHub fallback contains only five
locally qualified source tarballs, `SHA256SUMS` and `build-info.json`, with notes
explicitly identifying Hex as unpublished/BLOCKED_ENV and the absence of a new
standalone archive. Existing v0.5.0 Debian/bookworm binary qualification remains
unchanged. Specialist abnormal/disconnect, slow-peer, pressure, load and soak
qualification, production operations/data/certificates, Vault, public management
and the disabled release-artifact E2E remain excluded.
