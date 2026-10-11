# Gaoxy v0.2.0 release receipt

Date: 2026-10-11. Status: PUBLISHED AND VERIFIED.

Release: [Gaoxy v0.2.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.2.0).
The tag and published artifact source are `32ec599790ccddb477345a765681f74852e5ffc0`.

[ADR007](../adr/007-m3-beta-and-m4.md) defines the reviewed gateway beta subset.
[Execution plan](../plans/release-0.2.0.md) records authorized steps. All five
versions are synchronized to 0.2.0. Historical protocol/browser/load receipts
retain their original candidate identities.

| Verification | Current result |
| --- | --- |
| Canonical format / strict compilation | PASS, exit0, Elixir1.18.5 / OTP28.5.0.7 |
| Scoped compatibility regression | PASS, 486 tests / 0 failures, exit0 |
| Local production core and gateway artifact smoke | PASS, 3 core transports + 2 H1/H2 proxy exchanges; finite exit and rebind |
| Independent release and M4 design review | PASS, no active findings; M4 implementation NOT RUN |
| Independent portable qualification review | PASS, specification/code/evidence; no active findings |
| Main integration / remote SHA | PASS, fast-forward main and remote32ec599790ccddb477345a765681f74852e5ffc0 |
| Hosted build | BLOCKED_ENV: fresh run38137347576 executed no steps |
| Initial portable regression (unpatched OTP28.5) | FAIL, 486 tests / 2 hostname-alert assertion failures; preserved |
| Portable Sol repairs 1 and 2 | FAIL, actual exit124 for each outer guardian; no completed compatibility result or artifact |
| Portable Astra recovery 1 | Builder PASS, exit0, 486/0 plus core3/gateway2; fresh runtime FAIL, exit1 |
| Additional Sol repair request | NOT RUN; worker repair limit retains Sol2/unsuccessful2 |
| Portable Astra recovery 2 | PASS, fresh runtime exit0 in17.035s; 21 ELF objects, core3/gateway2 |
| Release candidate platform qualification | PASS, isolated Debian bookworm/glibc Linux x86_64, Elixir1.18.5 / OTP28.5.0.5 |
| Tag / release assets | PUBLISHED, source32ec599; archive, SHA256SUMS and build-info.json uploaded |
| Fresh download / SHA256 verification | PASS, all3 assets byte-identical to qualified originals, checksums/source/5 tagged versions/archive inventory verified |
| Production deployment / release-artifact E2E | NOT RUN; not authorized |

Local Nix smoke establishes behavior on the recorded Nix host; it is not a
generic portable Linux artifact. The published build needs its own platform
provenance and pre-publication smoke.

[Local verification](evidence/release-0.2.0/local-verification.json) records exact
commands, source/log hashes and counts. [Smoke receipt](evidence/release-0.2.0/smoke-results.json)
preserves the initial `invalid_http_protocols` fixture failure (exit1, zero
exchanges) and its repaired execution (exit0, two exchanges). The repair uses
separate supported H1/H2 cleartext listeners; traffic assertions remain intact.
Release-smoke counters: Sol1, unsuccessful0, Astra0. Existing transport counters
remain unchanged.

[Independent review](evidence/release-0.2.0/independent-review.md) and its
[machine receipt](evidence/release-0.2.0/independent-review.json) cover the release
changes and M4 architecture. The owner-loss design finding is resolved; M4
implementation is not claimed.

Raw execution logs are stored as lossless gzip archives. The local verification
receipt includes compressed and decompressed SHA256 values; no log whitespace
or failure output was normalized.

[Fresh hosted outcome](evidence/release-0.2.0/hosted-run.json) is preserved separately.
The local fallback uses a clean source archive and isolated Debian
build/runtime containers; its complete qualification passed before publication.

The first portable build used OTP28.5 and executed all486 compatibility tests,
with two failures in the wrong-host TLS tests. Both connections were rejected;
the peer received `handshake_failure` where the tests expected
`bad_certificate`. The client diagnostic identified `hostname_check_failed`.
Upstream OTP source confirms the alert mapping differs in patched28.5 releases.
Independent security-path review found no fail-open behavior. The selected
repair aligns the isolated builder to OTP28.5.0.5, preserves all source/test
assertions and repeats the complete qualification. The initial failure remains
FAIL rather than being rewritten as a passing run.

The patched-profile Sol attempts reached their real outer limits: repair1 at
1800 seconds and repair2 at 539 seconds plus cancellation cleanup. Both exited
124. Strict production compilation completed in repair2; its compatibility run
did not finish, so packaging and fresh runtime checks remained NOT RUN. After
two unsuccessful Sol repairs, bounded Astra recovery1 splits dependency setup,
strict compilation and qualification into separate cacheable Docker layers.
The original commands, assertions and inner 600/300/60-second limits are retained.
The staged Astra1 builder completed in 671.884 seconds with exit0: all486
compatibility tests passed, core3/gateway2 smokes passed, and the archive contains
1405 entries with ERTS16.4.0.5. Both archive and build-info checksums are finalized.
The first fresh runtime image built successfully in 365.987 seconds, but its
offline container exited1 after 0.778 seconds. The wrapper failed its live
Running assertion and removed the container before saving stderr. Runtime
qualification remains a historical FAIL; its startup error was unknown at that
point because stderr had not been saved.
A requested additional Sol repair did not execute because the worker's developer
repair limit requires escalation after two unsuccessful Sol rounds. The second
and final bounded Astra recovery begins with a diagnostic run and preserved
failure receipts; no additional Sol round is counted.
An exact diagnostic reproduced the exit1 in 1.304 seconds and captured the
startup exception: Debian Python3.11.2 rejects the `filter` argument to
`TarFile.extractall`. The selected audit-runner repair validates archive member
types and containment before compatible extraction, preserves safe permissions,
and saves logs/final inspection before cleanup on every exit path. Release
archive and build-info bytes remain unchanged.

The actual Python3.11.2 compatibility probe extracted 1322 candidate files with
identical bytes and rejected absolute/escaping paths, links and special files
without prefix/outside writes. Final fresh qualification exited0 in17.035s
within its original600s limit. Live/final Docker inspection confirms the actual
image, `NetworkMode=none`, a read-only artifact mount, final exit0 and owned
container removal. All21 package ELF objects had no missing libraries or Nix
dependencies. Core TCP/TLS/UDP and native H1/H2 gateway smoke passed with the
original shutdown and rebind assertions.

[Portable evidence](evidence/release-0.2.0/portable/README.md) includes the pinned
recipe, complete build/runtime results, all failed-attempt snapshots and lossless
logs. Its manifest records both original and stored hashes. Published support
is limited to the tested Debian bookworm/glibc Linux x86_64 profile; other
profiles and bit-reproducible output remain unqualified.

Final portable counters are Sol2 / unsuccessful2 / Astra2 / unsuccessful1. Historical
transport and release-smoke counters are unchanged.

[Final portable review](evidence/release-0.2.0/astra2-final-review.md) accepts the
actual build, offline runtime and imported evidence. Earlier review reports
retain their original pending/failed outcomes.

[Fresh download verification](evidence/release-0.2.0/download-verification.json)
records the published release, exact three assets and hashes, remote lightweight
tag, all five tagged versions, ERTS16.4.0.5 and 1405 archive entries. The release
was published at 2026-10-11T13:45:28Z; all downloaded bytes match the qualified
originals. [Published notes](evidence/release-0.2.0/published-notes.md) disclose
platform limits and the gateway beta subset. The tag stays at32ec599; a later
documentation-only main commit records these publication receipts.

M4's independently reviewed design and plan are ready. Its implementation/runtime,
production deployment and the disabled release-artifact E2E workflow remain NOT RUN.
