# Test workflow separation acceptance

**Date:** 2026-10-22, Asia/Shanghai

**Status:** Local implementation and ordinary verification PASS; hosted CI and
macOS execution NOT RUN.

**Branch:** `codex/test-workflow-separation`

**Worktree:** `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/test-workflow-separation`

## Source and environment

The approved design starts from version 0.11.1 at
`09715de3f165db134e287e1ea5fd4e93b1325905`. Implementation started from a clean
`b4a7d2aaeda7d74e8c8f489ed0f0664f6766a127`, which adds only the approved design
and plan. Local runs below exercised that checkout plus the implementation
changes. `.audit/workflow-split/implementation-snapshot.json` records the changed
paths, file digests and deletions before committing; the final implementation
revision is `e127d393a296adfd31e17a188e6f0e40edd5255a`, tree
`bf91563e081445e400cc1809d40453c2eaca9298`. All 89 changed implementation paths
(including eight deletions) were checked against that committed tree and match
the verified snapshot. The following receipt/design-plan changes only document
the result.

Local implementation commits are `77799f37` (portable smoke), `fcfa4b62`
(released-server clients), and `e127d393` (atomic manifest, test, browser and
workflow migration).

Local source verification used Linux x86_64 6.18.48, Elixir 1.18.5 / OTP 28,
`ELIXIR_ERL_OPTIONS='+S 2:2'`, OpenSSL 3.6.3 and Python 3.13.15. The isolated
HTTP-client environment used Python 3.12.13, httpx 0.28.1, h2 4.3.0, aioquic
1.2.0 and websockets 15.0.1. `runtime-environment.json` and
`client-environment.json` record the actual tools. These local environments are
distinct from configured GitHub runner images.

Unless otherwise specified, evidence paths below are relative to
`.audit/workflow-split/` in this worktree. Logs and generated runtime files are
ignored local evidence, not committed source.

## Resulting boundaries

| Workflow | Ordinary responsibility |
| --- | --- |
| `ci.yml` | Linux formatting, inventory validation and strict compilation |
| `test.yml` | One literal `ubuntu-latest` job: 184 isolated app unit cases and 36 mocked Python unit cases |
| `e2e.yml` | Independent Linux `component`, `protocol` and `isolated-network` jobs on push/PR/manual; additional manual `release-clients` job when `version` is nonempty |
| `package.yml` | Linux package staging, isolated built/source consumers, optional QUIC consumer and source-built release smoke |
| `portable.yml` | The only Linux/macOS matrix; one native HTTP start, one GET `/health` requiring `200`/`ok`, normal stop |
| `release.yml` | Existing exact-publication-source qualification and publication guards; client/peer checks replace browser dependencies |

`test.yml` has no matrix, certificate setup, protocol peers, consumer builds or
real service requests. Unit modules use existing doubles, injected callbacks or
isolated owners; they open no real sockets/listeners and start no full runtime.
Useful real-network assertions moved to E2E rather than becoming mocked
substitutes. Source E2E jobs have no dependency on a release version or on one
another. The released-server job was wired only after its real suite and cleanup
passed qualification and independent review; no workflow was dispatched.

## Coverage conservation and ownership ledger

The previous five selections contained 407 unique app cases across 59 files.
The original cases are conserved as 184 unit and 223 component/protocol cases.
Nine already scheduled portable cases are now included in the canonical
manifest: certificate fixtures (3), TLS (1), datagram egress (3), backend telemetry
(1), and the extracted two-instance runtime network case (1). Final exact counts
are **184 unit + 123 component + 109 protocol = 416**.

Independent review compared all 385 literal test declarations in the old active
union with the split files: names and bodies are conserved after whitespace
normalization. Generated cases explain the difference between literal
declarations and the executed totals. The selected `runtime_test.exs:109` case
has its own named file; the rest of that historical file remains unscheduled.

`scripts/check-repairs.py` is the sole active path/count manifest. Its `all`
selector deduplicates the canonical union, retaining exact positive counts and
rejecting failures, exclusions and skips. Legacy `test_helpers`/`composition`
aliases were removed after all workflow callers migrated. The inventory covers
77 active files and 151 explicit retained files: 149 `existing_not_scheduled`
and two `specialist_deferred` pressure/slow-peer files. Newly discovered app
files cannot silently inherit a wildcard retention rule.

| Previous command or owner | Final owner |
| --- | --- |
| CI's three mocked Python regression scripts | `test.yml`, alongside the new inventory-checker regressions |
| `check-repairs.py unit`, `test_helpers`, `protocol`, `composition` and eleven inline app files | Canonical `unit` in test; `component`/`protocol` in E2E |
| Old portable certificate/TLS/datagram/backend telemetry and `runtime_test.exs:109` checks | Canonical E2E component/protocol manifests |
| `test-consumers.py`, formerly repeated in test and portable | Package, once in ordinary CI |
| `test-stage-hex-packages.py` | Package |
| `external-consumer.sh`, `gateway-consumer.sh`, `h3-gateway-consumer.sh` | Package |
| Existing `http-consumer.sh` / `h3-consumer.sh` publication checks | Remain release-only |
| Phoenix example's Mix tests | E2E component, now with the nonempty runner |
| `reverse_proxy/run.py`, `h2_rfc/run.py`, Phoenix `gate.py` / `unified.py` | E2E protocol |
| Four `network/fixture.py` variants, `release_gate.py`, `example_gate.py` | E2E isolated-network |
| `quic_consumer` locked dependency/compile/test gate | Package optional-quic |
| Source `mix release` + `release-smoke.py` | Package; exact-source publication qualification remains separate |
| Cross-platform compile and broad runtime selections | Replaced by the minimal portable consumer smoke |
| Disabled sustained-load command and retained exceptional matrices | Remain deferred; no specialist cases executed |
| Disabled released-server placeholder | Qualified 11-check harness, manual nonempty-version gate |

Repeated qualification in `release.yml` is intentional: it checks the exact
publication source. Ordinary workflows no longer repeat the unit or package
consumer suites in E2E or portable.

## Browser retirement

Eight browser automation/fixture files were deleted, including the three
previously unscheduled managed-H2 browser entrypoints. Active requirements,
dependency-version lookups, workflow installs and screenshot artifact paths no
longer require Playwright or Chromium. Executable entrypoints have no remaining
`playwright`, `chromium`, `browser.py`, `browser.mjs` or browser-fixture reference.

Retired assertions are DOM rendering, LiveView mount/click/upload/reconnect,
JavaScript Channel/EventSource execution, browser Origin/CDP behavior,
page-console errors and screenshots. They are scope retirements, not passing
replacement tests. Historical acceptance reports remain unchanged.

Direct clients preserve server-facing status/headers/body, verified TLS, static
responses, SSE bytes, uploads/streams, WebSocket/Channel frames, negotiated H2/H3,
reload/source restoration and bounded shutdown. Retained specialist matrix
entrypoints use the existing aioquic peer in place of browser branches; those
matrices were not executed during this migration.

## Observed local verification

Each PASS row below has exit 0; counts describe that command's actual cases or
gates and must not be added to infer a single unique product-suite count.

| Command / gate | Observed result | Evidence |
| --- | --- | --- |
| `check-repairs.py unit` | PASS 184, no skipped/excluded cases | `unit-verified.log` |
| `check-repairs.py component` | PASS 123, no skipped/excluded cases | `component-final2.log` |
| `check-repairs.py protocol` | PASS 109, no skipped/excluded cases | `protocol-verified.log` |
| Four script unit regression commands in test.yml | PASS 8 + 9 + 5 + 14 = 36 | Final verification terminal output |
| `check-test-inventory.py` | PASS 77 active / 151 retained files; 184/123/109 cases | Final verification terminal output |
| `test-stage-hex-packages.py` | PASS 10 | `packages.log` |
| `MIX_ENV=test test-consumers.py` | PASS base 3, H3 2, HTTPFetch 2; manual and production isolation assertions pass | `consumers.log` |
| Three source-consumer shell commands | PASS 1 each | `core-consumer.log`, `gateway-consumer.log`, `h3-gateway-consumer.log` |
| Phoenix example `check-tests.py` | PASS 22 | `phoenix-component-final.log` |
| Browser-free Phoenix `gate.py` | PASS 10; source restored, process exit 0 | `phoenix/manifest.json`, `phoenix/results.json` |
| Browser-free Phoenix `unified.py` | PASS 8; source restored, process exit 0 | `unified/report.json` |
| Selected H2 RFC gate | PASS 40; selected cases, not full conformance | `h2-rfc/results.json` |
| Reverse-proxy example | PASS 6 | `reverse-proxy/example-results.json` |
| Four namespace variants: inet/socket, IPv4/IPv4+IPv6 | PASS 13 + 21 + 13 + 20 = 67 | `runtime-network-*.result.json` |
| Five-transport production release / custom example | PASS 11 each | `runtime-network-release.result.json`, `runtime-network-example.result.json` |
| Optional QUIC consumer locked deps / strict compile / tests | PASS; lock unchanged; 4 tests | `runtime-quic-consumer-*.result.json`, `runtime-summary.json` |
| Strict DEV compile | PASS | `runtime-dev-compile.result.json` |
| `MIX_ENV=prod mix release gaoxy --overwrite` + `release-smoke.py` | PASS TCP/TLS/UDP traffic, admission-barrier shutdown, VM exit and UDP reuse | `release-build.log`, `source-release-smoke.log` |
| `portable-smoke.py` on local Linux | PASS exactly one request, stopped=true, exit 0 | `../portable-smoke/result.json` |
| Downloaded 0.11.1 runtime with independent clients | PASS 11; actual server version 0.11.1, server exit 0 | `released-clients-final/result.json` |
| Root formatter and explicit new fixture formatter checks | PASS | `format.log`, `format-new-fixtures.log` |
| Six-workflow actionlint and `git diff --check` | PASS | Final verification terminal output |

For exact command arguments, backend environment and cleanup, see
`runtime-summary.json` and the per-command result files. The namespace suite's
socket/IPv6 explicit unsupported scoped-send contract remains an asserted
negative capability result, not successful support. Final `ip netns list` is
empty; fixture sources were restored and owned commands finished.

### Released artifact identity

The final artifact run used `gaoxy-0.11.1-linux-x86_64.tar.gz`, source
`09715de3f165db134e287e1ea5fd4e93b1325905`, SHA256
`8c236bd96bc06acd5a83178abc5d6efe8b8a7d5a498e0ad4113c4d31f3a7b4d8`.
The archive checksum, layout and reported version were verified. HTTPFetch
0.21.14 came from that runtime; H3/credential helpers came from the exact release
revision. No server code was built from the checkout for this run.

The qualified harness SHA256 is
`a70cc541a3763d65766406463fe1bd066e6cc2e16ac8cc75efae55dcc43710ba`;
the fixture SHA256 is
`bd259fb8b5f7975b61f76abb4a1b96c842c0e8a9a07787a9a6b46767ac2a5aca`.
These bind the dirty-checkout run to the committed files. Local Nix execution
provided process-local `LD_LIBRARY_PATH` from ncurses, OpenSSL, zlib and
`gcc.cc.lib`; the workflow installs Ubuntu's `libtinfo6` prerequisite.

### Earlier failures retained separately

- New inventory regressions first failed before the checker existed; red/green
  logs and disposition-schema regressions are retained.
- Extraction-only unused helper/default warnings failed strict checks and were
  repaired without changing assertions; earlier unit/component logs remain.
- The first namespace attempt failed before assertions because the local DEV
  test-helper app had not been compiled. The workflow's existing compile
  prerequisite was then executed; all four fresh variants passed.
- The first optional consumer run exited 1 before ExUnit because a copied stale
  build cache referenced missing `thousand_island.app`. A fresh ignored
  `MIX_BUILD_PATH` compiled strictly and passed all four tests with the same lock.
- The first downloaded-runtime attempt exited 127 before client execution,
  missing `libtinfo.so.6` in the Nix environment. Its FAIL/setup result remains in
  `released-clients/`; the later fresh 11-check PASS is recorded separately.

## Independent review and rollout limits

Independent classification review passed specification and code-quality checks
for A–C, including mock isolation, conservation and retained dispositions.
Independent workflow/harness review passed D–F and the final released-client
wiring. Actionable warning/disposition and subprocess-cleanup findings were
resolved before fresh affected verification. The reviewer exercised real command
success, nonzero exit, timeout and interruption paths and confirmed child process
groups were reaped. No assertions were weakened.

The read-only required-status-check query returned HTTP 404, `Branch not
protected`; its JSON/error are retained as `required-checks.json` and `.err`.
Check identities change as follows; workflow display names also describe their
new responsibilities. No repository settings changed.

| Previous job identity | Final job identity |
| --- | --- |
| CI `build` OS/BEAM matrix | CI `build`, fixed Linux |
| Test `unit` OS/BEAM matrix | Test `unit`, fixed Linux |
| Portable `native_http` | E2E `component` / `protocol`; package `package` |
| Portable `portable`, broad runtime gate | Portable `portable`, minimal platform smoke; broader commands move to E2E/package |
| Portable `isolated-network` | E2E `isolated-network` |
| Portable `optional-quic` | Package `optional-quic` |
| Disabled E2E `e2e` placeholder | E2E `release-clients`, manual with nonempty version |

GitHub-hosted runs and macOS smoke are **NOT RUN**. Specialist pressure,
slow-peer, sustained-load and deferred disconnect qualification remain deferred;
historical failures/blocks remain unchanged. This local implementation does not
claim publication, deployment, production or new platform acceptance. No push,
release, workflow dispatch or remote settings mutation was performed.
