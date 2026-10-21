# Gaoxy 0.9.0 release plan

Date: 2026-10-22, Asia/Shanghai. The user requests all eligible open internal
requests on `main` and the next release. Baseline:
`32933790457bcfa3533e40dc2ae4d51ad91aa86d` (latest release `0.8.0`).
Develop directly on `main`; preserve unrelated work and historical evidence.

1. Implement and independently review issues #3/#7 (explicit streaming lifetime),
   #5 (verified TLS client certificates), #6/#9 (configured WebSocket/LiveView
   message capacity), #8 (Phoenix-owned transport options), and #10 (supervised
   HTTP shutdown budget). Preserve red evidence, execute scoped real-network regressions,
   and resolve actionable review findings without weakening assertions.
2. Synchronize the root and five own application manifests to `0.9.0`, update
   current installation and configuration guides, and write release notes.
   Preserve dependency locks and vendored upstream source versions/provenance;
   staging supplies the adapter distribution's coordinated package version.
3. Run canonical formatting, strict compilation, packaging regressions, actual
   five-package staging/build/metadata inspection, ordinary compatibility,
   standalone release smokes, and the new internal-request publication gates.
   Complete independent source/artifact review and fresh verification.
4. Commit and push the qualified source. Verify remote `main` identity and
   required static/build, unit and Foundation integration results on that SHA.
   Preserve any failed or unexecuted results with their actual status.
5. Dispatch the existing release workflow with `version=0.9.0`, `git_ref=main`
   and the full committed `expected_sha`. The workflow validates source/version
   identity, ordinary and issue-specific tests, isolated consumers, unified
   browser acceptance and standalone smokes before publishing five Hex packages.
   It compares public package bytes, then creates the tag and GitHub release.
6. Independently download and verify release assets, checksums, actual Hex
   metadata/payloads and exact tag/source identity. Run clean public-Hex consumers
   and issue-specific public-package probes; execute the downloaded standalone
   artifact. Record public verification and close the fixed GitHub issues only
   after the requested compatible packages are available.

Do not precreate the tag or publish the umbrella directly. Keep credentials in
the existing release mechanism. Deployment, production data/certificates, Vault,
public management, specialist pressure/load qualification and the disabled
release-artifact E2E workflow remain outside scope. This release adds no new
architecture or distribution portability claim.
