# Gaoxy v0.5.2 release acceptance

Date: 2026-10-20, Asia/Shanghai. Preparation is directly on `main` in
`gsmlg-dev/gaoxy`; the local checkout path is unchanged. The user authorizes
the next patch release, including commit, push and public Hex publication.
The [plan](../plans/release-0.5.2-hex.md) defines this packaging-only scope.
**Publication is BLOCKED_ENV: the hosted job received an empty `HEX_API_KEY`.**
Builds and ordinary release smoke checks passed; no Hex upload, tag or GitHub
release was created. The built assets are retained as an Actions artifact.

## Preflight

Starting source: `7500d1151c455a486005d340ea36ceff07d9a76c`. Changes update
six own versions and current README installation references to 0.5.2, with
release documentation. No runtime, dependency-lock, vendor or test changes.

| Gate | Actual result |
| --- | --- |
| Packaging regressions | PASS: `python3 scripts/test-stage-hex-packages.py`, 7 tests, 0 failures, exit 0 |
| Five real Hex builds | PASS: version 0.5.2, exact package/app names, MIT licenses, dependency metadata and new repository URLs verified |
| Runtime custody | PASS: all 106 packaged runtime files match source; independent comparison to v0.5.1 packages confirms unchanged runtime payloads and adapter attribution |
| Formatting, strict production compile and workflow lint | PASS: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `git diff --check`, actionlint 1.7.12; all exit 0 |
| Independent specification and code review | PASS: release plan, notes, source changes, workflow and package evidence; no remaining actionable findings |
| Hosted build and smoke gates | PASS: packaging regressions, format, strict compile, standalone release, native H1/H2 smoke, five package builds and artifact upload all executed successfully |
| Hosted release execution | BLOCKED_ENV: run `39386137306` failed at the publish step because its `HEX_API_KEY` was empty; the guard exited 1 before any upload |
| Public Hex publication | BLOCKED_ENV / NOT PUBLISHED: all five 0.5.2 release endpoints still return 404 after the failed attempt |
| GitHub release and downloaded assets | NOT PUBLISHED: tag and release steps were skipped; the seven Actions artifact files were downloaded and all six checksum entries passed |
| Clean public-Hex consumers | NOT RUN; publication is blocked; the unchanged core 1 / HTTP 2 / Phoenix 4 test fixtures are prepared for execution |
| Specialist suites and deployment | NOT RUN; outside this release |

Qualified release source: `ff06d13bfed97744e47b452d10fc17c2bfba5fff`, committed
and pushed directly on `main`, with its remote SHA verified through Git and
the GitHub API. Local checks used Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5,
`ELIXIR_ERL_OPTIONS='+S 2:2'` and `MIX_ENV=prod`. Hosted execution used the
workflow's Elixir 1.18.5 / OTP 28.5 on Ubuntu.

Five package builds and seven packaging regressions, source hashes, parsed
metadata and independent source/artifact reviews are preserved in
[preflight evidence](evidence/release-0.5.2/preflight/manifest.json). Full local
tarballs remain under `.audit/release-0.5.2/packaging/` and the downloaded hosted
artifact under `.audit/release-0.5.2/hosted/artifacts/`.

## Hosted attempt and required external change

[Run 39386137306](https://github.com/gsmlg-dev/gaoxy/actions/runs/39386137306)
actually executed and built the seven files in artifact `12247032946`,
`gaoxy-0.5.2-linux-x86_64`. It reached the publication step, where
`${HEX_API_KEY:?Set the HEX_API_KEY Actions secret to publish packages}` failed.
This is separate from the previous organization's billing no-start.
[Hosted evidence](evidence/release-0.5.2/hosted/manifest.json) preserves the
actual run, step results, logs, registry checks and independent failure review.
Independent artifact review confirmed seven packaging tests with zero failures,
core smoke across three transports and two gateway H1/H2 exchanges. The five
hosted Hex packages have identical unpacked files and equivalent parsed metadata
to local preflight. Raw tarballs differ because hosted Hex 2.5.3 and local Hex
2.4.2 serialize metadata differently. The downloaded hosted files match all six
uploaded checksum entries; their hashes and download-provenance limits are in
[the artifact receipt](evidence/release-0.5.2/hosted/hosted-artifact-review.json).

The repository is private, its organization is on GitHub Free, and it has no
repository-level Actions secrets. `HEX_API_KEY` exists as an organization
secret, but GitHub's documented policy says: "Organization-level secrets and
variables are not accessible by private repositories for GitHub Free."
See [GitHub's secrets documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).
Add `HEX_API_KEY` as a repository secret in
[the new repository's Actions settings](https://github.com/gsmlg-dev/gaoxy/settings/secrets/actions),
then dispatch the release again for 0.5.2. No existing tag needs changing.
The key value must remain in GitHub; no billing or repository visibility change
was made. Public consumer execution and final publication verification remain
blocked until that external configuration is available.

The package-only publishing path, dependency order, public-byte verification
and retained standalone smoke gates are unchanged from the reviewed v0.5.1
workflow. Historical v0.5.1 hosted billing failure and unpublished Hex status
retain their actual results. This new attempt uses the transferred repository
and an unused version; it does not retry or rewrite the old release.
