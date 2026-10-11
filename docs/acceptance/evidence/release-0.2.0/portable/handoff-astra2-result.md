# Astra recovery 2 completed handoff

Task: release-0.2.0-portable / portable_build_astra1 (second assignment).
Status: DONE for bounded recovery; parent owns final independent acceptance and publication.
Mode: implementation. Gate: SOL_REPEATED_FAILURE, two actual prior Sol exit124 outcomes.
Received counters Sol2/failed2/Astra1/failed1; final cumulative Sol2/failed2/Astra2/failed1.
Sol repair3 was NOT RUN; no counter reset/increment. No third Astra recovery is authorized.
Exclusive portable scope was explicitly reauthorized; no other writer changed it during this round.

## Repository and preservation

Worktree /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway, HEAD/frozen source
32ec599790ccddb477345a765681f74852e5ffc0. Only .audit/release-0.2.0-portable changed.
Parent's pre-existing AGENTS.md, acceptance documentation and hosted-run.json edits remain untouched.
No application source/tests/dependencies or published assets changed. No commit, push, publication,
deployment, account, quota, certificate issuance or public management action was performed.

Before execution, all prior Astra1 manifest hashes verified. Every old evidence file, helper and
previous handoff was copied byte-for-byte into runtime-attempt-astra1/; its manifest is
runtime-attempt-astra1-manifest.json. The old live fresh-runtime directory is also preserved at
evidence/fresh-runtime-astra1-original/. Failed attempts remain FAIL in their immutable receipts.

## Evidence-led root cause and repair

One exact same-image offline diagnostic reproduced exit1 in1.303713s under60s total bound.
Evidence: evidence/astra2-diagnostic/{receipt.json,container.stderr.log,container-inspect-final.json}.
Actual stderr: /tools/runtime.py:39, TypeError: TarFile.extractall() got an unexpected keyword argument 'filter'.
Debian runtime Python3.11.2 lacks that extraction API; this was the qualification helper's startup
failure, not demonstrated application failure. Original helper also deleted the exited container
before collecting logs, hiding the error during Astra1.

Changed only context/runtime.py and context/run_runtime.py; evidence/astra2-recipe.diff is exact.
Runtime extraction now validates the entire archive inventory before writing: regular files/directories
only, no absolute/escaping paths, no links/devices/FIFOs; integer UID/GID/mode normalization supported
by Python3.11.2 precedes compatible extractall(members=...). All original runtime assertion ASTs remain.
The host runner captures container logs/final inspection before removal even on failed startup and
records failure unless qualification and cleanup succeed. Original checksum/source/version/image/network,
all-ELF/missing-library/Nix/traffic/shutdown/rebind checks and60s inner smoke deadlines remain.

Parent authorized one focused additional <=60s interpreter regression probe, not another recovery.
Actual same-image Python3.11.2 probe PASS2.797720s, exit0: extracted1322 actual regular files byte-identical;
rejected absolute, parent escape, symbolic link, hard link, FIFO and character device entries with
zero outside writes and no prefix extraction; verified safe ownership/mode normalization.
Probe used the exact AST extraction block from candidate runtime.py and did not invoke runtime smokes.
Evidence: evidence/astra2-compatibility-probe/ with script, command receipt, stdout/stderr, inspections.

## Required final qualification

Single full original600s run: python3 <scope>/context/qualify_runtime.py <scope>.
Started2026-10-11T13:36:52.670534Z; finished13:37:09.705093Z; elapsed17.034694s; exit0 PASS.
Runtime image build4.827788s exit0; fresh qualification12.098340s exit0. Qualified builder layers cached;
only runtime helper COPY rebuilt. Dockerfile/build.py/finalize.py/qualify_runtime.py remain byte-identical.
Image sha256:c9e083000fa22e471c33cec5fe4e829c55678cebd7c58f58ddec3f432430b313.
Container3cbb8b11bf5991fe3194f969c98c1403f3405eeab672d7608e72a428a1163dc6:
live Running=true, NetworkMode=none, expected image, artifact mount read-only; final exit0 and removed.

PASS: checksum exact two entries; source/version identity;21 ELF objects inspected with readelf/ldd,
missing libraries0 and /nix/store references0; real packaged TCP/TLS/UDP core3 and nativeH1/H2 gateway2
exchanges; original admitted-stream shutdown/finite VM exit/listener cleanup/port reuse assertions.
launch.json/runtime-result.json/runtime-qualification-stages.json all PASS. All runtime check exits0.
Raw logs, image inspection, live/final container inspections and ELF outputs are under evidence/.

Earlier qualified builder remains PASS671.883776s: format, strict compile,486 tests/0 failures and
no skips/exclusions, release packaging, core3/gateway2;2396 source files unchanged, all13 checks exit0.
No builder gate was rerun or weakened in Astra2. Archive/build-info/SHA256SUMS bytes are unchanged:
gaoxy-0.2.0-linux-x86_64.tar.gz SHA2568e3eeb8c91f4a7cf9e5ccb2307f8623451e7872500a42a07cbc5c3d35b99aa16
build-info.json SHA2567f883b22d34370adbe61327ad0b4a5d1b636a52e74f8a5ec4e9165360acca586
Clean source.tar SHA25644418e6dd6190af9b69826f08675310157eb6987831f3b1d6596fa2e37faa86d.

## Final handoff

All diagnostic/probe/qualification commands completed; owned containers removed, confirmed with
docker ps -a filtered to owned prefix. No unrelated process stopped. Astra stops all writes after
this report/manifest. evidence/astra2-shutdown.json records command-session outcomes and counters;
evidence/astra2-evidence-manifest.json seals current evidence, artifacts, helper files and snapshots.

Independent reviewer was notified of stable recipe and successful actual results; parent owns its
final review disposition and publication. No unresolved implementation blocker remains from this
bounded recovery. Qualified support is Debian bookworm/glibc Linux amd64 only; other platforms,
hostedCI, publication, deployment and disabled release-artifact E2E are separate evidence/authorization.
All unrelated historical H1/TLS/model/H2/smoke counters remain untouched.
