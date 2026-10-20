# Standalone recovery and CI follow-up

Date: 2026-10-21, Asia/Shanghai. The user authorizes implementation, independent
review, integration, push and the next unused patch release. Refreshed main is
`581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`, unchanged from the reviewed baseline.
Published v0.5.3 and all earlier acceptance evidence remain immutable. Work is
isolated under `.trees/` on `codex/` branches; unrelated user files are preserved.

## Execution and acceptance

- [ ] A: record a short recovery design before editing production code. Reproduce
  the subsequent-reload failure through real standalone supervision, for fixed
  and grouped managed upstreams. Preserve the latest accepted declarative routes,
  reconstruct local handles, and settle obsolete ownership through accounted
  lifecycle termination. Retain live-owner cleanup failures and activation guards.
  Verify recovery traffic, another reload, settled retirements and usable resources.
- [ ] B: reproduce Elixir 1.20 strict compilation, inspect each match binding and
  pin only externally bound size variables. Preserve the dependency cohort,
  `--warnings-as-errors`, supported profiles and existing tests.
- [ ] C: provision a clean Python environment with the existing pinned QUIC peer
  requirements at the consumer's actual path. Verify actual independent peer
  launch and all optional consumer tests with certificate checks and deadlines.
- [ ] Integrate A/B/C, add the recovery regression to the ordinary repair and
  prepublication gate, and update exact counts from executed tests. Run
  `python3 scripts/check-repairs.py all`, relevant standalone activation/rollback/
  lifecycle tests, strict compile and unit gates on Linux 1.18.5/OTP 28.5 and
  macOS 1.20.1/OTP 29.0.2, plus the repaired optional QUIC job.
- [ ] Obtain independent specification and code review, resolve findings, select
  the next unused patch, commit versions, and qualify the final source freshly.
- [ ] Integrate and push using the established workflow, await required checks,
  then dispatch publication with the full `expected_sha`. Verify tag, actual
  release job, GitHub artifacts, all public packages and clean public consumers.
- [ ] Append a concise acceptance record with source identities, versions,
  commands, executed counts, exits, log paths and explicit PASS/FAIL/BLOCKED/
  NOT RUN states; retain pre-fix failures as failures.

Implementation and routine review use gpt-6.1-sol/high. Independent writers own
separate worktrees; shared builds/dependencies and final integration serialize.
No protocol expansion, milestone reopening, specialist campaign, issue 97 proof,
deployment, production data/certificates, Vault/public management changes or
release-artifact E2E enablement is included.
