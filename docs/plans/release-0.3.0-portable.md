# v0.3.0 portable qualification implementation plan

> For agentic workers: use `subagent-driven-development` or `executing-plans`.
> The coordinator owns recipe preparation and execution; independent Sol reviews
> the design, code and actual receipts. All Mix/live work remains serialized.

**Goal:** qualify fresh v0.3.0 bytes, including packaged H3 listener/origin paths,
before the authorized publication.

**Architecture:** [portable design](../designs/release-0.3.0-portable.md); retain
the reviewed v0.2.0 builder/runtime profile in a new recipe directory with an
explicit immutable source-identity input.

**Tech stack:** existing pinned Docker bases/toolchain, Elixir/OTP, Python with
aioquic1.2.0/hyper-h2, Git and GitHub CLI.

- [x] Add `scripts/h3-release-smoke.py` with `--release <absolute bin/gaoxy>`
  and `--evidence <directory>`. Generate temporary P-256 credentials; start the
  existing independent `integration/http3/upstream/origin.py` with two separate
  identities. Start the actual release with data-only H1/H3 services and fixed
  H3 proxy routes. Use its ready file, never a sleep-based readiness assumption.
- [x] Check exactly three exchanges: native H3 static bytes; H1 POST with three
  DATA bytes and ordered duplicate trailers to the H3 origin; H3 POST with zero
  DATA bytes and ordered duplicate trailers to that origin. Require exact
  response bytes/trailers, independent request fields/hash/one FIN and one
  request per proxy path. Observe native `h3` ALPN. Stop children, assert zero
  exits and rebind every known TCP/UDP port. Retain failure logs and result JSON.
- [x] Copy `docs/acceptance/evidence/release-0.2.0/portable/recipe/` to
  `docs/acceptance/evidence/release-0.3.0/portable/recipe/`. Keep old bytes intact.
  Read version/source/lock identities from a checked `source-identity.json`.
  Add `gaoxy_http3` to scoped application tests and version/inventory checks;
  record actual test counts. Install the existing pinned H3 peer requirements.
  Copy only required Python fixtures into the runtime image and run packaged
  H3 smoke alongside existing core/gateway smoke.
- [x] Independently review design/recipe/smoke source. Before building, complete
  M4 gates, update six version declarations and release documentation, verify
  source checks, independently review and commit the release candidate. Record
  `git rev-parse HEAD`, create `git archive --format=tar HEAD`, then generate the
  source-identity JSON from that exact commit/archive/lock.
- [x] Execute staged portable builder and export artifacts. Run safe metadata
  and checksum finalization, then `python3 qualify_runtime.py <build directory>`
  for the fresh offline image. Require all stage exits0, nonzero tests without
  exclusions/skips, unchanged source hashes, three H3 checks, ELF inspection,
  exact five versions and safe archive inventory. Failures enter bounded
  diagnosis/repair with cumulative counters preserved.
  Keep image preparation, all Docker control calls and cleanup within 600
  seconds. Persist a parent-generated unique name before child launch; pass
  the child an absolute deadline capped at 300 seconds including its cleanup
  reserve. Retain failed/time-out command receipts and diagnostic logs before
  removal. Exercise inspection timeout, partial creation, child timeout and
  failed removal; require parent fallback cleanup of only the owned name and
  keep forced cleanup FAIL. PASS requires child exit 0 and observed removal.
- [x] Independently review actual artifact/runtime evidence and repeat affected
  checks after changes. Only then continue immutable tag/release publication and
  fresh asset downloads in the parent release plan.

Recipe/source and deterministic Docker-boundary preparation are independently
reviewed; [preparation review](../acceptance/evidence/release-0.3.0/review-portable-r1-exact-commit-coordinator-preparation-1791857437995376501.json)
does not qualify artifact bytes. The local assembled release passes its three
[H3 checks](../acceptance/evidence/release-0.3.0/local-h3-package-1791857824012345678/result.json).
Initial portable builder FAIL at exact82-file formatting; [failure diagnosis](../acceptance/evidence/release-0.3.0/portable-build1-failure-1791859105860499026/diagnosis.json)
remains immutable. Formatting-only repair of the current0.3.0 TLS helper has
[AST/exact82-file proof](../acceptance/evidence/release-0.3.0/portable-probe-format-proof-1791859263416674340.json).
Build2 at49cb7ab passed757/0 and exported its artifact; runtime1 remained FAIL
because both host coordinators rejected Docker29's lowercase absence message
after child exit0 and normal removal. [Preserved diagnosis](../acceptance/evidence/release-0.3.0/portable-build2-runtime1-failure-1791861327712037431/diagnosis.json)
and [independent failure review](../acceptance/evidence/release-0.3.0/review-original-portable-runtime1-failure-1791861403971008922.json)
retain the original result. The current host-runner repair accepts known
absence prefixes case-insensitively only with a nonzero exit and exact owned
name. All deadlines, normal-removal requirements and forced-cleanup FAIL remain.
[The initial40 regressions](../acceptance/evidence/release-0.3.0/docker-absence-boundary-green-1791861478003615836.json)
PASS but omitted differently cased owned names. Independent review identified
that global IGNORECASE also affected the owned name; the corrected implementation
limits case-insensitivity to the diagnostic prefix. [Current42 regressions](../acceptance/evidence/release-0.3.0/docker-absence-boundary-green-1791861658805631265.json)
PASS, including case-sensitive-name rejection. The [controlled RED](../acceptance/evidence/release-0.3.0/docker-absence-exact-name-controlled-red-1791861725492154292/result.json)
reproduces the first-repair defect; the earlier yielded RED attempt remains FAIL
and is not proof. These are harness checks, not artifact acceptance.

The final committed source4931982 archive, build3, finalization and offline
runtime2 now PASS:757 tests/0 failures/zero skipped or excluded, 83 changed
Elixir paths, strict compile, unchanged4207 regular files, safe1420 package entries,
five apps0.3.0, core3/gateway2/H3three checks, all21 ELF with no missing/Nix
dependencies, child exit0/normal rm0/exact owned-name absence. The final42-case
post-review boundary repeat and26 independent pure vectors also PASS.
[Final artifact/runtime/notes review](../acceptance/evidence/release-0.3.0/review-actual-portable-artifact-runtime-1791863376221811603.json)
has no findings and preceded immutable tag/release publication. The raw
[manifest](../acceptance/evidence/release-0.3.0/portable-final-1791863003049561405/manifest.json)
keeps its historical capture-time PENDING_FINAL_REVIEW; the later review closes
that snapshot without mutating it.
[Actual publication and fresh downloads](../acceptance/evidence/release-0.3.0/publication-1791863800600551728/publication-verification.json)
PASS for these exact bytes. See [release acceptance](../acceptance/release-0.3.0.md)
for identities, durations, failures, commands and limits.
