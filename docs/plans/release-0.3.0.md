# Gaoxy v0.3.0 release execution plan

> For agentic workers: use `subagent-driven-development` or `executing-plans`.
> The coordinator owns publication and assigns independent Sol review. Serialize
> all Mix and live commands; preserve frozen sources and historical receipts.

**Goal:** publish the verified M4 standalone release under the user's conditional
main/push/release authorization, then prepare the remaining established work.

**Architecture:** retain the existing standalone application and portable Linux
x86_64 release profile. The release includes native downstream H1/H2/H3 and fixed
HTTPS/H3 reverse origins using the qualified public Session adapter. Upstream
pools and upstream H2 retain their actual capability status. Every published
artifact must be bound to the final release commit and qualified independently
of development-host evidence.

**Tech stack:** existing Elixir/OTP umbrella, locked HTTP/QUIC cohort, independent
aioquic/H2 peers, Git and GitHub CLI, existing isolated portable build/runtime
recipe. M4 implementation acceptance, portable qualification and publication PASS.
Immutable tag/artifact source is `4931982cff7b07c8e9f42a5e4561d22854d418bd`; final main documentation follows
separately. [Actual publication/download receipt](../acceptance/evidence/release-0.3.0/publication-1791863800600551728/publication-verification.json)
binds all three assets to qualified bytes. Hosted CI remains BLOCKED_ENV with
zero executed steps; deployment/E2E are NOT RUN. This checklist links execution
evidence without substituting for it.

## 1. Establish release eligibility

- [x] Complete the prescribed gates in [the M4 plan](m4-http3.md),
  [public Session plan](m4-public-session-upstream.md) and
  [consumer-affinity amendment](m4-public-session-consumer-affinity.md): UP0,
  UP1, UP2, standalone H3-origin, affected native server/browser and clean
  consumer checks. Require executed nonzero counts, actual exit codes, immutable
  source identities, independent review and fresh affected verification.
- [x] Update `docs/acceptance/m4.md`, current capabilities and usage to the
  final verified implementation. Preserve Fetch cleanup limitations, historical
  failures and the separate statuses of hosted CI, local tests and deployment.
- [x] Obtain independent final specification, code and evidence review. Resolve
  actionable findings and repeat affected checks before declaring M4 complete.

## 2. Prepare the concrete release candidate

- [x] Confirm `v0.3.0` does not exist using `git ls-remote --tags origin
  refs/tags/v0.3.0` and `gh release view v0.3.0 --repo gsmlg-opt/gaoxy`. Record
  absence or inspect an existing release before any mutation; never replace a
  published tag.
- [x] Synchronize the version to `0.3.0` in `mix.exs` and the five
  `apps/*/mix.exs` declarations. Preserve dependency pins/locks and confirm all
  six declarations agree. Write `docs/releases/0.3.0.md` around the final
  verified capabilities, tested platform and concrete limitations.
- [x] Write `docs/acceptance/release-0.3.0.md` and unique evidence under
  `docs/acceptance/evidence/release-0.3.0/`. Keep publication pending until
  remote verification completes. Record actual toolchain, source/lock hashes,
  commands, test counts and process shutdown.
- [x] Run exact changed-file formatting and `mix compile --warnings-as-errors`
  inside the locked Nix environment; rerun the final M4 compatibility targets
  affected by the version change. Build `MIX_ENV=prod mix release gaoxy` and run
  `scripts/release-smoke.py` and `scripts/gateway-release-smoke.py` with their
  existing finite shutdown/rebind assertions. These checks qualify the local
  candidate, not a portable downloadable artifact.
- [x] Independently review candidate source, release notes, plan and local evidence.
- [x] Commit only task-owned paths with conventional messages.

## 3. Qualify and publish exact bytes

- [x] Fetch origin and inspect divergence. Confirm the completed release branch
  can be integrated without losing remote or user work. Preserve the root
  untracked `gaoxy-m1.1-fix-prompt.md` byte-for-byte; stage explicit paths only.
- [x] Fast-forward or integrate the reviewed release candidate into `main`,
  run affected verification if integration changes source, push `main`, and
  verify `git ls-remote origin refs/heads/main` equals the intended commit.
- [x] Use the separately qualified local portable build as the authoritative
  publication route. The current `release.yml` publishes automatically before
  packaged H3, fresh portable runtime, ELF and immutable metadata checks; do not
  dispatch that publisher for this release. Record hosted CI independently;
  preserve any no-start result as `BLOCKED_ENV` without changing account or
  repository settings. Local M4 evidence never qualifies hosted artifact bytes.
- [x] For the required local portable build, copy the final corrected
  `docs/acceptance/evidence/release-0.2.0/portable/recipe/` into a new release
  evidence directory; preserve the old recipe. Bind the new build/runtime to
  the actual `0.3.0` source archive, replace old version/source constants, include
  `gaoxy_http3` and current scoped compatibility checks, and retain staged build
  layers and safe archive extraction. Record actual test counts rather than
  retaining the old `486` assertion. Test the fresh artifact on the selected
  Debian/glibc x86_64 profile with existing core/H1/H2 smoke plus independent
  local H3 listener/origin exchanges, finite shutdown and port rebind. Inspect
  all package ELF objects for missing libraries and Nix dependencies. Review
  this new recipe/evidence independently before publication. Freeze the source
  commit throughout build/runtime qualification, recheck checkout and remote
  identities afterward, and repeat affected qualification if sources change.
  Carry historical recovery counters forward; old successful artifacts never
  qualify new bytes.
- [x] Bind the archive, `build-info.json` and `SHA256SUMS` to the exact source
  commit. Verify both archive and build-info checksums, all application versions
  and archive inventory. With qualified bytes, push the immutable `v0.3.0` tag
  and create the GitHub release using `gh release create --verify-tag` and
  `--notes-file /tmp/gaoxy-0.3.0-reviewed-release-notes.md`. All packaged H3, portable runtime, ELF,
  metadata and independent-review gates must pass before tag/release publication.
- [x] Freshly download every published asset; verify bytes/checksums, source,
  application versions, archive inventory, remote tag and main. Save a unique
  publication receipt and independent completion review:
  [actual review](../acceptance/evidence/release-0.3.0/review-actual-publication-fresh-download-1791864019336220804.json).
  The coordinator then commits/pushes the resulting documentation/evidence,
  verifies remote main and fast-forwards the clean prepared Task4 branch.
  Record that final commit identity separately in the parent handoff receipt;
  do not put this documentation commit's SHA inside itself.

## 4. Prepare established remaining work

- [x] Reconcile `implement-plan.md` and capability records against completed
  milestones. The roadmap currently ends at M4: do not invent an M5 or advertise
  upstream pools/H2 from the H3 release. Prepare design/plan for the next existing
  incomplete work package and its exact verification boundaries under continuing
  development authorization.

The release excludes deployment, production data/certificates, Vault changes,
public management and enabling the disabled release-artifact E2E workflow.
Required local independent-peer/browser verification remains mandatory. Ordinary
implementation/test failures enter diagnosis and repair; stop only for the user's
specified external-permission, unavoidable product-decision or external-blocker
conditions. No routine approval is requested by this plan.

M4/source/local candidate closure: [independent review](../acceptance/evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json).
Portable preparation and actual artifact/runtime/notes have independent review:
[final review](../acceptance/evidence/release-0.3.0/review-actual-portable-artifact-runtime-1791863376221811603.json).
Build3/finalize/runtime2 and tag/publication/download all PASS. Independent
publication/download review PASS with no findings. Final documentation review
precedes its commit/push and the prepared branch's documentation-only FF;
the parent final handoff receipt records those identities. The reviewed release
notes bytes were copied unchanged to `docs/releases/0.3.0.md`. GitHub API reports
`immutable: false`; no immutable-release repository setting was enabled.
Earlier FAIL evidence remains immutable.
