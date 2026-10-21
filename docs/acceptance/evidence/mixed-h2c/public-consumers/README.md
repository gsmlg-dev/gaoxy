# Public Hex consumers for Gaoxy0.7.0

PASS: core1 + HTTP4 + Phoenix5 =10 executed tests,0 failures, no exclusions/skips.
All37 recorded commands exited0. Exact published source is
`14287f30b83ccec207ffc944867413043cb8f360`; successful release run is
`39555029237`. `result.json` is the exact completed consumer receipt and binds
`publication-receipt.json`, which independently verified published source,
release assets and public Hex package payloads. This archive adds no reruns.

The core consumer exercises TCP/UDP without optional applications. HTTP verifies
native H1/H2, body parsing and an audit-only mixed-listener case. That case uses
the tracked independent Python-h2 peer while both original sockets remain open
on one identical port. It asserts actual HTTP/1.1 and HTTP/2 response headers and
content; deciding H1 body/pipeline and H2 preface/SETTINGS/HEADERS/DATA bytes;
five exact-once endpoint deliveries; and lease cleanup. Phoenix exercises five
real Endpoint/body/ownership cases.

The harness checked all resolved dependencies use public Hex SCM and isolated
dependency/build/Hex-cache directories; own packages resolve exactly0.7.0;
accepted upstream lock entries stay exact; and no forbidden optional core/HTTP
applications appear. Nineteen original fixture/lock files were bound to immutable
Git objects from the published source before execution and hash-checked again
afterward. Independent peer versions were h2=4.3.0, hpack=4.2.0 and
hyperframe=6.1.0. Existing quoted-keyword warnings from accepted lockfiles remain
in the complete logs; all strict compile/test commands succeeded.

`consumers/` contains the actual executed manifests, source/tests/config and final
resolved locks. `prepared-initial-locks/` contains their exact pre-resolution
locks. `fixture-source/` contains original committed inputs; `fixture-inputs.json.gz`
is their exact preparation binding. Command stdout/stderr and copied helper
files use gzip with mtime0 to preserve all bytes, including empty streams,
trailing whitespace and ANSI output. `execution-initial.log.gz` is the outer log.
`manifest.json` hashes every archive payload and its original/decompressed bytes;
it excludes itself, whose SHA256 is supplied in the accompanying task report.
Dependency trees, compiled output, Hex/cache state and secrets are excluded.
All audit originals remain in place.

## Reproduction placement

These are byte-exact audit helper copies, not repository runtime/test changes.
Restore `tools/verify.py.gz` to `.audit/mixed-h2c/consumers/verify.py` and
`tools/mixed_public_test.exs.gz` alongside it. Restore `tools/verify-publication.py.gz`
to `.audit/mixed-h2c/publication/verify-publication.py`. Restore the fixture tree
under `.audit/mixed-h2c/consumers/fixture-source/`, removing only the final `.gz`
suffix while decompressing. Place `fixture-inputs.json` alongside that directory.
The original receipts retain absolute paths for the recorded worktree; adapt a
new input binding for a different checkout rather than changing this evidence.

The executed disposable project tree was
`.audit/mixed-h2c/consumers/run-1792561859466896362/`. Archived resolved projects
reconstruct that execution, but do not reuse its PASS receipt as an executable
PREPARED run. To repeat verification, use the restored harness's `--prepare` mode
to create a new run and then `--execute` with the exact source/run and matching
PASS publication receipt. Preserve this completed evidence. The external
`.audit/h2peer/bin/python` must provide the pinned versions above; the recorded
Nix unbuffer executable must exist or a newly reviewed harness must name its
replacement. No publication or deployment commands are involved in these checks.
