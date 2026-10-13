# v0.3.0 portable artifact qualification

This refines the already authorized [release plan](../plans/release-0.3.0.md).
Implementation acceptance still precedes the build and publication. Preparation
of this design does not certify artifact bytes.

Reuse the reviewed v0.2.0 Debian bookworm/glibc x86_64 builder and isolated,
network-disabled runtime recipe in a new directory. This retains the qualified
toolchain, staged build, safe extraction and ELF checks. Reusing an old binary
would not exercise M4; a hosted automatic publisher would publish before the
required packaged checks. A fresh local build is the selected route.

Each build receives `source-identity.json`, recording the final Git commit,
source archive SHA256 and root lock SHA256. The recipe verifies those bytes
before compiling and verifies every archived source file remains unchanged.
All five application versions must be 0.3.0. Actual nonzero ExUnit counts from
the five scoped application directories are recorded, with no exclusions or
skips; no historical test count is reused.

The identity also lists every changed Elixir source/test path in the committed
candidate compared with the recorded pre-M4 main commit. Validate each path
against the source archive and run explicit formatting on that exact list,
including HTTP/3 and integration files outside the canonical formatter inputs.

In addition to existing TCP/TLS/UDP and native H1/H2 gateway smoke, run
`scripts/h3-release-smoke.py` against the packaged `bin/gaoxy`. The script uses
the actual standalone configuration/startup path, public ready-file output,
disposable P-256 fixture credentials and an independent aioquic origin. It
checks a native H3 static response, native H1-to-H3 and H3-to-H3 proxy exchanges,
ordered duplicate request/response trailers, exact bytes/hash/FIN and one origin
request per exchange. It obtains a final origin snapshot, stops all children
within finite bounds, and checks all known listener/origin ports can be rebound.
It does not invoke Mix or use development application beams in the runtime.

The runtime image contains only the independently required peer/smoke fixtures
and their Python environment beside the exported release. It runs with Docker
network mode `none`; loopback protocol exchanges remain real network tests.
Every packaged ELF object's dynamic linkage is inspected for missing libraries
and Nix paths. Archive inventory, application metadata, source identities and
both asset checksums are reviewed independently before tag/release publication.
The final remote/download verification remains the release plan's separate gate.

Runtime image preparation, Docker inspection, qualification and owned-container
cleanup share a 600-second absolute deadline. The parent records a unique
container name before launch and reserves 40 seconds for fallback diagnostics
and cleanup. The child receives that name and a deadline capped at 300 seconds,
including 30 seconds reserved for cleanup. Every Docker call has a finite bound.
On child failure or timeout, the parent captures diagnostics and removes only
that named container. Forced cleanup retains FAIL. PASS requires actual child
exit 0, successful diagnostic capture and removal, and observed container absence.
