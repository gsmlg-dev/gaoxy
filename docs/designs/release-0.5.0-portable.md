# v0.5.0 ordinary portable release qualification

Date: 2026-10-20, Asia/Shanghai. The user explicitly authorizes committing,
pushing and publishing the next minor GitHub release after v0.4.0. Release
v0.5.0 packages the accepted Hell migration; it adds no new product capability.

Use an isolated `.trees/release-0.5.0` checkout on `codex/release-0.5.0`.
Update the umbrella and five own application versions to 0.5.0. Preserve the
Hell 0.1.2 Git pin `59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`, root lock
SHA256 `9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`,
all other dependencies, existing worktrees and unrelated files. The initial
main checkout is tracked-clean and the previously preserved unrelated prompt
is absent at this request; record that state without recreating it.

Copy the eight reviewed v0.4.0 portable recipes into the new v0.5.0 evidence
directory, preserving every historical recipe byte. Retain the pinned
Debian/glibc Linux amd64 toolchain, staged build, source archive identity,
all-file unchanged-byte custody, safe inventory, five own application version
checks and two-entry checksums. The changed Elixir file list comes from
`v0.4.0..candidate`; exclude only immutable `docs/acceptance/evidence/` snapshots
from the current formatter, keeping them in source custody.

Keep the existing ordinary suites and their assertions: M5 138, M3 unit 38,
M3 network 24 with 90 excluded. Add the migration's exact accepted native
ordinary selectors: 10 executions, 54 excluded, distributed as core 4, HTTP 4
and proxy 2. The total is 210 executions with zero failures, 144 exclusions and
zero skips, counted across invocations. Keep independent legacy and M5 peer
environments separately pinned and the M3 fixture path pointing at the M5
environment. Do not execute abnormal/disconnect, slow-peer, pressure, load or
soak qualification, or change assertions to manufacture acceptance.

Extend only the copied recipes to assert that the package includes exactly
one Hell 0.1.2 application, the Gaoxy application declares `:hell`, and the
old Thousand Island application is absent. A packaged public `bin/gaoxy eval`
must start Gaoxy, observe the running Hell application and its expected version,
and confirm that the old application is absent. Bind the Hell provenance to
source/lock metadata. Perform these checks in the builder and fresh offline
runtime; package finalization independently checks the archive metadata.

Keep core TCP/TLS/UDP, gateway H1/H2 and three H3 smoke exchanges. Run all
15-case packaged WebSocket profiles for H2, h2c and H3 in the builder and in a
new network-disabled runtime, using only release application beams. Retain
nonzero ELF inspection, no missing or Nix-linked dependencies, readonly
artifact input, finite normal child exits and owned-container removal/absence.
The existing 600-second parent and 300-second child bounds remain intact.

Independent specification and code reviews precede the committed source
freeze. Build a new artifact from that exact Git archive. Review actual
source, package, runtime and notes before publication. Retain failed attempts
with their real statuses; necessary repairs enter diagnosis and fresh affected
qualification. Inherited Astra recovery remains exhausted at 2/2.

Push reviewed main, verify its remote SHA, create an annotated v0.5.0 tag at
the qualified source and verify the peeled remote tag. Publish exactly
`gaoxy-0.5.0-linux-x86_64.tar.gz`, `build-info.json` and `SHA256SUMS` using
`gh release create --verify-tag --notes-file`. Download all assets into a new
directory and compare their bytes, hashes, metadata and inventory to the
qualified originals. Review publication evidence independently. A documentation
closeout may follow the frozen source in a separate reviewed commit.

Every commit uses `[skip ci]` because automatic jobs include the excluded
specialist suites. Do not dispatch release.yml or enable release-artifact E2E;
new hosted CI remains NOT RUN. No account/settings changes, Hex/OCI publishing,
deployment, production data/certificates, Vault or public management changes
are part of this release. Existing embedded/JSON and browser protocol-selection
boundaries remain as recorded in the implementation acceptances.
