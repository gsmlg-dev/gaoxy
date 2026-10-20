# Gaoxy v0.5.2 release acceptance

Date: 2026-10-20, Asia/Shanghai. Preparation is directly on `main` in
`gsmlg-dev/gaoxy`; the local checkout path is unchanged. The user authorizes
the next patch release, including commit, push and public Hex publication.
The [plan](../plans/release-0.5.2-hex.md) defines this packaging-only scope.

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
| Hosted release execution | NOT RUN yet |
| Public Hex publication | NOT PUBLISHED at preflight: all five 0.5.2 release endpoints return 404 |
| GitHub release and downloaded assets | NOT PUBLISHED at preflight: no v0.5.2 tag or release |
| Clean public-Hex consumers | NOT RUN yet; requires publication |
| Specialist suites and deployment | NOT RUN; outside this release |

Five package builds and seven packaging regressions are recorded in
`.audit/release-0.5.2/packaging/`, including command logs, source hashes,
tarballs and parsed metadata. Independent runtime and package comparisons are
in `.audit/release-0.5.2/review/`. These ignored work directories are local
preflight evidence; publication closeout will record durable remote identities
and the actual hosted and public registry outcomes.

The package-only publishing path, dependency order, public-byte verification
and retained standalone smoke gates are unchanged from the reviewed v0.5.1
workflow. Historical v0.5.1 hosted billing failure and unpublished Hex status
retain their actual results. This new attempt uses the transferred repository
and an unused version; it does not retry or rewrite the old release.
