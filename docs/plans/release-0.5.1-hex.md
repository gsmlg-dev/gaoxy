# v0.5.1 Hex packaging and GitHub release plan

Date: 2026-10-20, Asia/Shanghai. The user authorizes committing, pushing and
GitHub release after adding Hex publishing, and confirms the workflow secret.
`HEX_API_KEY` is an organization secret available to this repository. Its value
stays in GitHub Actions. The user selected MIT for Gaoxy's public packages.

## Design and scope

Release 0.5.1 changes packaging and documentation, preserving accepted runtime
source, locked dependencies, vendored adapter provenance and historical
evidence. The user requires working directly on `main`, without a worktree or
new branch. The parent owns Git integration and publication; independent agents own bounded implementation
and review. No specialist abnormal/disconnect, slow-peer, pressure, load or soak
tests, production operations, deployment, Vault, public management or disabled
release-artifact E2E changes are authorized by this release.

Hex rejects the current Git, path and umbrella dependency declarations. Adding
Hex flags to local declarations changes dependency resolution; overriding all
umbrella apps at the root also introduces repeated dependency warnings. Instead,
a reproducible staging script reads each existing project and copies its runtime
files unchanged into standalone package directories with generated manifests.
Only the manifest and distribution metadata differ from the development tree.
No environment flag or source-tree path is needed by an installed package.

All five packages use the release version: `gaoxy_websock_adapter` (application
`websock_adapter`), `gaoxy`, `gaoxy_http`, `gaoxy_http3`, and `gaoxy_proxy`.
The fork retains its upstream MIT license, source and patch attribution; its
release version identifies the Gaoxy distribution of upstream 0.6.0. Own
packages carry the license explicitly selected by the user. Core package
requirements select Hell 0.1.2 and Abyss 0.7.0, whose published runtime sources
were compared to the accepted Git pins without differences. Reject changed or
unknown Git/path dependencies instead of guessing replacements. Internal and
fork dependencies use exact release requirements. Phoenix consumers explicitly
override `websock_adapter` with `hex: :gaoxy_websock_adapter`.

The workflow builds every staged package before the first upload, then publishes
the fork and libraries in dependency order, fetching each project's production
dependencies after its prerequisites are published. Hex checks dependencies
even for package-only publishing. Running workflows are not cancelled by a
second dispatch because publication can leave a partially uploaded release.
The workflow preserves standalone build/smoke
gates and pushes the release tag only after successful publication. Package-only
publication avoids adding an undocumented HexDocs toolchain. Package artifacts
and checksums are retained with the GitHub release to bind uploaded content.

## Execution

- [x] Verify current refs, workflow source, latest v0.5.0 release and secret
  availability; push the already reviewed workflow commit `f9e155cb`.
- [x] Document the design and scoped plan; transfer in-progress changes onto
  `main` and remove the temporary worktree/branch as explicitly requested.
- [x] Independently review this specification before implementation.
- [x] Implement `scripts/stage-hex-packages.exs` and scoped regression tests:
  standalone manifest buildability, complete byte-identical runtime payloads,
  exact dependency metadata, preserved adapter attribution, and fail-closed
  handling of unknown source dependencies. Observe an initial failing test.
- [x] Add the selected root license, update six own version declarations to
  0.5.1, integrate staging/build/publish into `.github/workflows/release.yml`,
  and replace obsolete readiness warnings with actual installation guidance.
- [x] Run scoped script tests, canonical formatting, workflow lint, all five
  real Hex builds and archive/metadata verification. Record source identities,
  counts, commands and failures separately from successful results.
- [x] Verify the built packages in clean core (one test), HTTP (two tests) and
  Phoenix (four tests) consumers using an isolated local signed Hex registry.
  Require real version/package-name resolution without path overrides; preserve
  exact runtime assertions and finite bounds.
- [x] Complete independent code/evidence review, resolve findings, rerun
  affected checks, and commit only task-owned files with a conventional subject.
- [ ] Integrate locally, push and verify remote main. Dispatch the release
  workflow for 0.5.1 on the verified release branch; inspect its actual outcome.
  A hosted no-start remains BLOCKED_ENV and does not authorize account changes.
- [ ] Verify published Hex versions/dependencies and downloaded package tarballs
  against the preflight bytes/checksums, plus clean registry consumers and
  GitHub tag/release source and downloaded asset bytes/checksums. Publication
  rebuilds tarballs, so freeze staging content and preserve/report any mismatch.
  Publish only after prerequisite checks pass; preserve
  partial or blocked outcomes without claiming release completion.

If hosted execution is unavailable, continue qualifying locally reproducible
package artifacts. After independent local package/consumer qualification,
the separately authorized GitHub release may publish exactly the five Hex
source tarballs, SHA256SUMS and build-info.json. Its notes must explicitly say
Hex publication is BLOCKED_ENV and no new standalone binary was built; keep
the v0.5.0 Debian/bookworm archive and qualification unchanged. Do not claim a
package is available on Hex without verifying the registry. Preserve this
distinction in the release acceptance and final report. An Ubuntu runner result
alone does not inherit the existing Debian portability claim. A missing secret
value on the local machine does not authorize extracting it from GitHub. Keep
GitHub release, Hex publication, hosted execution and production acceptance
as separate results.
