# Gaoxy v0.5.2 release acceptance

Date: 2026-10-20, Asia/Shanghai. Preparation is directly on `main` in
`gsmlg-dev/gaoxy`; the local checkout path is unchanged. The user authorizes
the next patch release, including commit, push and public Hex publication.
The [plan](../plans/release-0.5.2-hex.md) defines this packaging-only scope.
**GitHub release and all five public Hex packages are PUBLISHED.** The user
made the repository public and requested another attempt. Hosted run
`39404989025` succeeded, including publication, public-byte verification,
tagging and the GitHub release. Download verification and all seven clean
public-Hex consumer tests passed. The earlier failed attempt remains below.

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
| Hosted release execution | PASS: run `39404989025` at `d9fb3a5e`; packaging 7/0, strict compile, standalone core across 3 transports and 2 gateway H1/H2 exchanges, publication and release all succeeded |
| Public Hex publication | PASS: five 0.5.2 release records return 200; dependencies and adapter alias verified; every public tarball matches its GitHub asset and API checksum |
| GitHub release and downloaded assets | PASS: stable release, tag points to `d9fb3a5e`, exactly seven fresh asset downloads, all seven API digests and all six SHA256SUMS entries verified independently |
| Clean public-Hex consumers | PASS: core 1, HTTP 2, Phoenix 4; 7 tests, 0 failures, original assertions unchanged; three strict compiles and public Hex.SCM/cohort/isolation checks passed |
| Specialist suites and deployment | NOT RUN; outside this release |

Published release source: `d9fb3a5edee0c7e1dc1d141c7ce04db788b92fdf`, committed
and pushed directly on `main`, with its remote SHA verified through Git and
the GitHub API. This differs from the original qualified source `ff06d13b`
only in documentation and evidence; independent retry readiness confirmed
unchanged package inputs, runtime, vendor and dependency-lock bytes.
Local checks used Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5,
`ELIXIR_ERL_OPTIONS='+S 2:2'` and `MIX_ENV=prod`. Hosted execution used the
workflow's Elixir 1.18.5 / OTP 28.5 on Ubuntu.

Five package builds and seven packaging regressions, source hashes, parsed
metadata and independent source/artifact reviews are preserved in
[preflight evidence](evidence/release-0.5.2/preflight/manifest.json). Full local
tarballs remain under `.audit/release-0.5.2/packaging/` and the downloaded hosted
artifact under `.audit/release-0.5.2/hosted/artifacts/`.

## Historical attempt while private

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

At this attempt the repository was private, its organization was on GitHub Free,
and there were no repository-level Actions secrets. `HEX_API_KEY` existed as an
organization secret, but GitHub's documented policy says: "Organization-level secrets and
variables are not accessible by private repositories for GitHub Free."
See [GitHub's secrets documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).
A repository secret was requested as a possible resolution. No billing or
visibility change was made by the agent, and no key value was extracted.
Those blocked results and five capture-time 404 responses remain historical.

## Public retry and publication

The user changed the repository to public and requested a retry. A fresh API
read confirmed public visibility and the organization secret's availability.
[Run 39404989025](https://github.com/gsmlg-dev/gaoxy/actions/runs/39404989025)
at `d9fb3a5e` completed successfully on 2026-10-20 at 10:04:29 UTC. The secret
remained inside the publish step; the organization secret worked after the
visibility change. No new workflow or runtime repair was required.

The five distributions `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`,
`gaoxy_http3` and `gaoxy_proxy` are now available from public Hex at 0.5.2.
The adapter retains OTP app `websock_adapter`; exact internal dependencies,
MIT licenses and repository metadata match the qualified packages. Fresh
public downloads match the five GitHub source tarballs byte for byte, and all
five tarball hashes also match the previous hosted qualified packages.

[GitHub v0.5.2](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.5.2) has the
five Hex source tarballs, the Linux x86_64 standalone archive and `SHA256SUMS`.
Independent verification checked all seven asset digests and all six checksum
entries. The lightweight tag points to `d9fb3a5e`; later documentation closeout
can advance `main` without changing that source or any published artifact.
The Ubuntu build does not extend the separate Debian/bookworm qualification.
[Retry evidence](evidence/release-0.5.2/retry-public/manifest.json) preserves
public visibility, the successful run, source/tag identities, release and Hex
metadata, commands and lossless logs. The
[independent publication receipt](evidence/release-0.5.2/retry-public/publication/publication-download-review.json)
binds downloaded bytes and the package metadata comparisons.

## Clean public-Hex consumers

Run `run-1792490858095153634` used fresh dependency/build directories and an
isolated Hex home/cache, without mirrors or inherited Hex authentication.
It resolved actual public packages and retained the accepted upstream cohort.
All dependencies used Hex.SCM; the documented `websock_adapter` override
resolved to `gaoxy_websock_adapter` 0.5.2. Preparation and execution source
were both `d9fb3a5e`, using Elixir 1.18.5 / OTP 28.5.0.5 / Hex 2.4.2.

The original fifteen fixture files and both source lock files were preserved.
Core's one test exercised TCP/UDP and optional-app isolation; HTTP's two tests
checked isolation and native H1/H2 exchanges; Phoenix's four tests exercised
listener ownership and real code-reload/WebSocket composition. All seven
executed with zero failures, after strict compilation of each fresh consumer.

The first consumer attempt stopped before any tests because the disposable
harness combined Elixir warning output with its generated lock-file text.
One audit-only repair separated stdout and stderr, preserved the failed run
and original harness, and reran all original checks in a new directory. No
product, fixture, dependency-cohort or assertion change was needed. This
harness failure is preserved separately from the successful consumer run.
[Consumer completion](evidence/release-0.5.2/retry-public/consumers/completion.json),
the passed and failed command logs, exact harness versions and stream-repair
receipt are retained in the retry evidence manifest.

The package-only publishing path, dependency order, public-byte verification
and retained standalone smoke gates are unchanged from the reviewed v0.5.1
workflow. Historical v0.5.1 hosted billing failure and unpublished Hex status
retain their actual results. This new attempt uses the transferred repository
and an unused version; it does not retry or rewrite the old release.
