# Managed-H1 matrix source specification re-review

**PASS_SOURCE_SPEC2** — F1/F2 resolved in source; no new actionable source finding.

Reviewed the exact three-file repair delta against retained SPEC1, then the resulting deadline/cleanup paths. Candidate2 SHA256: `71aa146f0572f1ca54f33d7428e35313c21223183b4a5be4f1ea50179a3a409d`. Command inventory2 SHA256: `db447d788e4440aa29593b8085df5a002093f12b05277485d80eceaab91f5a25`.

F1: `run.py:310-322,478-484` now caps fixture work at the remaining absolute case budget and checks the deadline after final accepted wire/TLS identity, before separately bounded shutdown.

F2: `run.py:146-167,207-235,542-569` now owns clients outside partial case construction, protects the child-creation handoff from SIGALRM, disables the timer before cleanup, attempts each unjoined client independently under one shutdown deadline and records forced/errors before results. `managed_h1_matrix_fixture.exs:447-605` validates the driver-owned process group against the actual Port OS PID, requires truthful joined/result ordering and zero live/forced/errors, checks normal group absence and isolates bounded failure cleanups.

The original16-case/protocol/byte/trailer/health/identity assertions remain intact. Five unchanged source files retain their SPEC1 hashes. All8 owned source,8 documents,11 installed pins and401 explicitly supplied source identities match candidate2. Three Python AST checks passed. Full actual input hashes are in the JSON companion.

All nine proposed command gates remain **NOT RUN**. Static review cannot establish runtime cleanup, protocol or browser acceptance. The parent formatter receipt records exit0; this review ran no Git, Mix, build, tests, browser or runtime. No repository changes or new repair rounds. All review commands finished exit0. No SPEC2 tooling incident; the SPEC1 display incident remains preserved. WholeTask6/Task5/M3 remain OPEN.
