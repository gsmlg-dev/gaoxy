# Independent release preparation review

Reviewer: Sol (`websocket_limits`), 2026-10-22. Checkout: `main`, baseline
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`; reviewed the uncommitted release
preparation diff while preserving concurrent implementation changes.

Verdict: **PASS for all seven issue implementations and qualified release
source; no unresolved findings**. This review covers #3/#7 streaming lifetime,
#5 verified client certificates, #6/#9 WebSocket/LiveView capacity, #8 Phoenix
transport options and #10 supervised shutdown. Publication, hosted workflows,
public-package consumers and downstream application acceptance remain separate.

Reviewed:

- Six own Mix manifests consistently select `0.9.0`. Package staging retains
  the existing five-distribution cohort, rewrites internal dependencies to the
  exact cohort version, and supplies the adapter distribution version without
  modifying its vendored upstream source version/provenance. Dependency lock
  files and `vendor/websock_adapter/SOURCE.json` are unchanged.
- Root/application installation guides and Phoenix migration examples select
  matching `gaoxy_http` and `gaoxy_websock_adapter` versions, preserving the
  `:websock_adapter` application identity and explicit override requirement.
- Current TLS, streaming and WebSocket documentation agrees with the implemented
  public options and explicitly preserves unsupported HTTP/3 streaming policy.
- Unit, Foundation and publication workflows provision the independent Python
  H2 peer before the new scoped configuration/streaming regressions. Publication
  also executes actual Phoenix certificate/channel/streaming tests before its
  pre-existing package publication steps. Existing disabled specialist and
  release-artifact E2E boundaries remain unchanged.
- All three root CI gates now explicitly include eleven issue-specific files:
  core/Phoenix certificate configuration, configured/application WebSocket
  options, H1/H2/contract/Generation streaming, H3 lifetime boundary and both
  HTTP/H3 supervised-shutdown suites. Publication selects all four actual
  Phoenix issue test files, including LiveView compatibility. Each filename
  exists in the candidate. Nonempty-test enforcement remains in place.
- Release notes describe all seven requests and scoped limits; the release plan
  requires exact source identity, staged archives, hosted verification, public
  payload comparison and clean consumers. The acceptance record distinguishes
  final source qualification from pending commit/hosted/publication gates and
  preserves earlier failed or unexecuted attempts with their actual status.

Final qualification evidence inspected:

| Gate | Actual result |
|---|---|
| Root issue gate | Core 4 + HTTP 39 + H3 3 = 46 tests, 0 failures, exit 0 |
| Actual Phoenix issue gate | 17 tests, 0 failures, exit 0 |
| Ordinary compatibility | 265 executed, 0 failures/excluded/skipped, exit 0 |
| Formatter, strict production compile, release assembly | Exit 0 for each |
| Packaging regressions and actual five archives | 9 regressions pass; receipt PASS with all packages 0.9.0, exact runtime/source payloads and staged file membership |
| Unified browser/peer acceptance | Eight PASS checks; process exit 0 and temporary source restored |
| Sequential standalone smokes | TCP/TLS/UDP 3 transports; Gateway 7 exchanges; H3 3 checks, all PASS/exit 0 |
| Actual Nix actionlint and whitespace | Exit 0 |
| Five final source consumers | Core 1 + HTTP 4 + H3 2 + Gateway 1 + H3 Gateway 1 = 9 tests, 0 failures; all exits 0 |

Evidence is under `.audit/release-0.9.0/`, including
`internal-final-{root,phoenix}.log`, `ordinary-final.log`,
`package-receipt.json`, `unified-phoenix/report.json`, the three release-smoke
logs and consumer logs. The 557-file source manifest independently matches all
current file SHA256 values: no mismatches. Its recorded sorted-JSON fingerprint
is `83787ae55fa912c87d19b7c252117bd4144c5e64e67fcbc83a64b5fe152f2be5`.

Independent reviews resolved the extended Generation cleanup, exact H2 Exchange
accounting and child-spec initialization findings without weakening original
assertions. The #10 source repair independently reran HTTP 5 + H3 2 tests, all
passing; its review retains the initial failure evidence. #8/#9 received a
separate fresh 25-test root and 11-test Phoenix review by the TLS worker.

Read-only checks: final task diff, full relevant workflow steps, actual
`scripts/check-tests.py` nonempty-test enforcement, staging version/dependency
rewrite logic, dependency/provenance diff, manifest hashes and actual evidence
results. No extra Mix gate or external mutation was run for this final release
review. Commit/push, required hosted workflows, publication and public artifact
verification remain the release owner's required work.
