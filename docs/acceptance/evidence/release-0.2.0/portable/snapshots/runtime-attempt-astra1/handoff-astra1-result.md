# Astra recovery 1 handoff

Task: release-0.2.0-portable / portable_build_astra1.
Status: BLOCKED_IMPLEMENTATION; authorized one-round recovery finished unsuccessfully overall.
Mode: implementation. astra_gate: SOL_REPEATED_FAILURE.
Gate evidence: prior Sol repairs 1 and 2 both actual exit124, preserved raw logs and repair-history.json.
Ownership transferred explicitly from release_pipeline_audit before any mutation.

## Scope and baseline

Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway.
Baseline/frozen source: 32ec599790ccddb477345a765681f74852e5ffc0.
Clean source.tar SHA256: 44418e6dd6190af9b69826f08675310157eb6987831f3b1d6596fa2e37faa86d.
Only .audit/release-0.2.0-portable/ changed. Pre-existing parent edits to AGENTS.md,
docs/acceptance/release-0.2.0.md and hosted-run.json were not touched.
No tracked source/tests/dependencies changed; no publication, deployment, settings or account actions.

## Bounded repair and evidence

Confirmed timeout mechanism: original single RUN discarded dependency retrieval and compilation
when qualification had insufficient outer time. Split context/Dockerfile into prepare/compile/qualify
RUN layers and context/build.py into those corresponding phases, persisting check receipts.
Added per-check start/completion/elapsed/timeout provenance. All original run calls and arguments
(including original 600/300/60-second limits), test counts and assertions are retained.
All predecessor recipes/history were copied to evidence/pre-astra1 before editing;
pre-astra1-manifest.json records hashes. Historical original and Sol logs remain unchanged.

An initial read-only/preflight inventory assertion counted fixture mix files as release projects;
the check was narrowed to root/apps release project paths, verifying all five0.2.0 versions.
No source/artifact/test change arose from that inventory correction.

Builder command is recorded verbatim in evidence/astra1-builder.json:
timeout --kill-after=10 1790 docker buildx build --platform linux/amd64 --progress plain
--target artifact --output type=local,dest=<scope>/artifacts <scope>/context.
Maximum1800s includes10s kill allowance; no extension/retry.
Started2026-10-11T13:08:00.508406Z; finished13:19:12.392057Z;
elapsed671.8837758s; exit0 PASS.

Required build checks: PASS canonical format; PASS strict production compile; PASS486 tests/0 failures
(90+196+182+18, no skips/exclusions); PASS release; PASS core3 TCP/TLS/UDP and gateway2 nativeH1/H2
smokes with their finite termination/rebind assertions; PASS package; PASS2396 source files unchanged.
All13 recorded checks exit0 and log hashes verified. Toolchain/provenance is in build-info.json and
artifacts/evidence/toolchain.log: exact compiled Elixir1.18.5 / patched OTP28.5.0.5,
pinned builder/Rust/base digests. Broader platforms remain unqualified.

context/finalize.py artifacts exited0. SHA256SUMS contains exactly archive and build-info.json:
archive: 8e3eeb8c91f4a7cf9e5ccb2307f8623451e7872500a42a07cbc5c3d35b99aa16
build-info: 7f883b22d34370adbe61327ad0b4a5d1b636a52e74f8a5ec4e9165360acca586

## Failed fresh runtime: root cause UNKNOWN

Original unmodified context/qualify_runtime.py <scope> ran once with600s total bound.
Started2026-10-11T13:20:15.053222Z; finished13:26:29.053161Z;
elapsed374.0001148s; exit1 FAIL.
Runtime image build PASS365.9866612s:
sha256:b16ac807d862d7a882cbe02e448c97510b37ad7fa1a235a860d8dd0043bbbeb1.
Fresh container0cc89fbbeb6921f59a4dc52bd5ae16265304037eaa630da50edc0b361ea212ec
started13:26:26.444504033Z, exited1 at13:26:27.222112196Z (0.778s), noOOM.
Retained inspection proves NetworkMode=none, expected image, read-only artifact mount and writable
evidence mount. run_runtime.py asserted live Running before collecting logs; its finally removed
the already-exited container. Thus raw container stderr/container.log is absent. This is an evidence
capture gap, not proof of the underlying runtime root cause.
No runtime-result.json/elf-dependencies.json/runtime-checks.json exists: fresh checksum/ELF/smoke
acceptance NOT ESTABLISHED; core/gateway fresh smoke NOT RUN to completion. Do not publish yet.

Read-only postmortem: archive has no links; host tar data_filter found no rejected members.
Static readelf via memfd inspected21 ELF entries (without loading/executing them) and found NEEDED
names libc/libm/libtinfo/libstdc++/libgcc_s/ld-linux/libcrypto; this is NOT fresh runtime linkage proof.
Underlying startup cause remains UNKNOWN without stderr.

## Counters, shutdown and next ownership

Received portable Sol2/unsuccessful2/Astra0.
Cumulative portable Sol2/unsuccessful2/Astra1/unsuccessfulAstra1.
All unrelated historical counters remain unchanged; predecessor historical smoke Sol1/failed0 retained.
Builder session30121 finishedexit0; runtime session32907 finishedexit1. Owned runtime container
was removed by original wrapper; docker ps -a with owned prefix confirms none remain.
No other processes were stopped. No second Astra run or post-failure runtime execution occurred.

Parent has directed Sol release_pipeline_audit to take diagnosis next, starting with an exact,
finite60s networknone diagnostic runtime and preserving stderr before cleanup, then only an
evidenced bounded repair. This report does not allocate/reset repair budgets or authorize changes.
Successful builder remains valid scoped evidence; runtime qualification must pass independently.
Astra stops all scope mutations after this handoff. Parent owns final acceptance/publication.
