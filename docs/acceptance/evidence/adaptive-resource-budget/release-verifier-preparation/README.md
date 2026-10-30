# Next-release public verification preparation

Prepared audit-only copies of the qualified 0.13.1 verifiers. Actual next-release
publication, public artifact verification and downloaded runtime qualification
are NOT RUN. Version0.14.0 is provisional; the parent selects the final unused
version and exact publication SHA only after implementation acceptance and
release guards pass. No latest-tag inference is used.

The scripts retain six Hex packages, eight GitHub assets, seven payload
checksums, asset digest/size checks, Actions ZIP digest and exact payload-byte
comparison, Hex retirement/checksum/public-byte checks, dependency pins, HPAX
absence, standalone release/application versions and original runtime smoke
contracts. Build attestation remains NOT VERIFIED (`false`). Asset equality is
not an attestation claim.

Both scripts require `--version` and full lowercase40-hex `--sha`. Public
verification checks all seven own source manifests at that commit; the vendored
adapter retains app `:websock_adapter` and its independent upstream source
version. The stager supplies the selected root version to its Hex package.
Sibling Hex dependency versions, application identities and staged optionality
are checked, including optional H3 in gaoxy_test. Existing qualified Hell git
mapping and exact dependency pins remain enforced; a future dependency-policy
change requires review rather than silently accepting new pins.

Packaged file sets and every byte under lib/ and priv/ are derived from the
requested commit, including non-Elixir files. Source counts are never fixed.
The historical fixture cohort contains139 files (136 Elixir files plus three
already-committed gaoxy_test priv fixtures); this is not a next-release expected
count. Missing/extra files, symlinks instead of regular source blobs, changed
bytes, wrong versions and renamed adapter applications fail closed.

The runtime copy requires a fresh PASS receipt from this reviewed artifact
verifier and an explicit reviewed verifier SHA256. It checks that digest before
import and against the artifact receipt, and rechecks helper/source/tag inputs
around execution. It safely extracts with Python's data filter into a unique
fresh directory and requires executable bin/gaoxy and nonempty
releases/VERSION/start.boot. All13 existing runtime checks use the extracted
executable: core3, gateway7, H3 3, in order. Original150/150/750-second outer
bounds, natural process-group cleanup, H3 child exit0 and port-rebind assertions
remain unchanged. H3 may perform its existing bounded locked Rust preparation
when later run; none ran during this preparation.

The host environment remains the earlier qualified process-local Nix library
configuration from .audit/release-0.9.0-public-runtime/receipt.json. Certificate
and hostname verification stay enabled with the system CA. This is a host
compatibility input, not the selected release identity. Both that receipt and
pinned peer Python prerequisites must still be available before future use.

## Future use after parent review and successful publication

Run from the repository root. These are future recipes, not performed actions.
Set gaoxy_release_version to the parent's final selected version and
gaoxy_publication_sha to its full verified40-hex commit. The following sample
version remains provisional:

```sh
gaoxy_release_version=0.14.0
gaoxy_publication_sha=FULL_VERIFIED_PUBLICATION_COMMIT_SHA
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  .audit/h2peer/bin/python -B \
  .audit/adaptive-resource-budget/release-verification/verify-public-artifacts.py \
  --version "$gaoxy_release_version" --sha "$gaoxy_publication_sha"
```

The verifier creates public-artifacts-* here and prints its receipt path. Its
optional --downloaded-assets PATH reuses files while retaining every remote
metadata/source/digest/Actions/Hex check. It never publishes or extracts/runs the
release. After this fresh verifier reports PASS, set gaoxy_artifact_receipt to
its absolute receipt path, confirm the independently reviewed helper digest
below, and only then run the downloaded-runtime qualification:

```sh
gaoxy_artifact_receipt=/ABSOLUTE/FRESH/public-artifacts-DIRECTORY/receipt.json
gaoxy_reviewed_verifier_sha256=bf699636e821473c2c32ea8f7a73a405b186432202bd70e327e9171e364e414a
.audit/h2peer/bin/python -B \
  .audit/adaptive-resource-budget/release-verification/downloaded-runtime.py \
  --version "$gaoxy_release_version" --sha "$gaoxy_publication_sha" \
  --artifact-verifier-sha256 "$gaoxy_reviewed_verifier_sha256" \
  --artifact-receipt "$gaoxy_artifact_receipt"
```

Do not replace the reviewed digest with an automatically computed current-file
hash during use; a changed helper needs renewed review. The separate published
Hex-only consumer gate remains the existing `scripts/test-consumers.py
--published --version VERSION` on the exact publication source. The release
workflow retains ownership of all publication guards and irreversible actions.
The source-built release-smoke default alone does not qualify downloaded bytes;
this runner substitutes the actual extracted executable for that core smoke.
No deployment or production acceptance follows from these checks.

## Executed preparation controls

```sh
python3 -B .audit/adaptive-resource-budget/release-verification/identity-controls.py
python3 -B .audit/adaptive-resource-budget/release-verification/offline-controls.py
python3 -B .audit/adaptive-resource-budget/release-verification/runtime-offline-controls.py
```

All pass:4 CLI controls,47 artifact controls and29 runtime guards; exits0.
The initial unchanged copies failed the two new explicit-input CLI controls,
then passed after adaptation. These expected RED checks are not runtime
failures. offline-controls.json and runtime-preparation.json retain the exact
positive counts, cases and helper hashes. Static compile parsing writes no
bytecode. Existing0.13.1 scripts/evidence remain untouched.

The artifact controls use preserved qualified0.13.1 package/archive bytes at
84c7ff76461ada8aebaa34c567c61206bc963d83, with synthetic provisional0.14.0
package metadata only. The historical standalone is inspected in memory;
synthetic runtime extraction fixtures are never executed. Controls reject
wrong source/priv-file bytes, missing/extra files, wrong source/package
versions and dependency/app/optionality, wrong Actions ZIP/payloads, corrupted
archives, duplicate checksums, unsafe paths/links, missing boot files, wrong
source/receipt/helper identities, false attestation claims and incomplete smoke
result evidence. No public query, Mix, Elixir, build, service, peer, listener,
artifact executable, fixture/certificate generation, Git mutation, package
publication or deployment ran. Parent independently reviews these copies before
use. Qualification of the final release remains NOT RUN.
