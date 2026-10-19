# v0.4.0 formatter repair1 SPEC review

PASS; no actionable findings.

Baseline `4dd24f2ca28c6376c95daeb10dc3464b7d5dbcb2`. The preserved first build failed changed-file formatting on 91 immutable historical evidence paths and zero current source paths. Canonical formatting passed; strict compilation, tests, packaging and runtime were NOT RUN.

The approved repair retains all 5,160 changed-path identities, formats all 171 non-evidence paths, and partitions only the exact `docs/acceptance/evidence/` prefix (4,989 paths). Every archived regular file still receives unchanged-byte custody checks. No historical source, ordinary test/assertion/count, toolchain pin or runtime behavior changes. Four failure archives round-trip byte-identically with matching raw/compressed hashes.

CODE review awaits writer handoff. Static docs/log/hash inspection only; no tests, build, browser or network. All reviewer commands finished. Ordinary release formatter-scope repair1; reviewer Sol repairs0, inherited Astra2/2 unchanged.
