# HTTP Fetch 0.17.2 revalidation

Recorded on 2026-10-10 (Asia/Shanghai; JSON timestamps use UTC) against local
executable commit `bcd5eb3540fb3a9d27862368362e89243a316a1f` on
`codex/m2-native`. This bundle supplements the unchanged 2026-10-09 native
evidence in the parent directory; it does not replace that historical snapshot.

Published Fetch/Core/Runtime/WebSocket and their three QUIC/TLS dependencies
are pinned to 0.17.2 in the root lock. The Fetch/Core/Runtime/WebSocket library
files match release tag commit `500fbb90ce4eeddbba16b9bb5da91f70f0764995`.
`package-verification.json`, the Hex metadata snapshots and
`package-source-hashes.json` record the exact artifact identities and comparison.
The source archive and dependency/build directories remain local audit inputs;
they are not vendored into this bundle.

| Check | Result | Evidence |
|---|---|---|
| Published dependency contracts | PASS: 5 tests | `contract-tests.log`; final suite includes the final reviewed helper |
| Scoped native/core/dependency suite | PASS: 45 core + 82 HTTP + 5 proxy contract tests, exit 0 | `final-tests.log`, seed 902300 |
| Standalone core consumer | PASS: strict compilation and 1 test, exit 0 | `core-consumer.log` |
| Changed-file formatting | PASS, exit 0 | `format-check.log` |
| Strict umbrella compilation | PASS, exit 0 | `compile.log` |
| GET/DELETE body preservation | FAIL, exit 1: bodies and Content-Length disappear; POST control passes | `method-body-probe.log`, upstream #45 |
| Valid WebSocket close codes | FAIL, exit 1: 1001/1008/1011 rejected; 1000 control passes | `websocket-close-probe.log`, upstream #38 |

The initial combined run failed one core configuration assertion because it
assumed the optional QUIC engine was absent. Fetch now installs that engine in
the umbrella graph. `dependency-graph-red.log` preserves that failure;
`config-green.log` records the focused correction (4 tests, exit 0). The test
keeps exact error assertions for both installed and absent engines. Runtime
code did not change. Core isolation is established only by the fresh standalone
consumer, not by the umbrella dependency graph.

`upstream-status.json` records #27–#30 CLOSED and #38/#45 OPEN. The two nonzero
probes are failed requirements, not successful proxy acceptance. Full M2 remains
BLOCKED; no proxy endpoint or local dependency workaround has been implemented.
The close probe's 1000 call after rejection is cleanup, not code translation.

`command-results.json` records commands, environments and collected exits.
Core-consumer Git transfer progress is omitted and trailing whitespace trimmed;
dependency resolution, compiler and test output remain. Raw output is retained
locally. `source-manifest.json` hashes 117 input files. Its executable commit
precedes the documentation/evidence commit. `evidence-index.json` hashes each
file in this subdirectory except itself.

Phoenix fixture/browser checks were not rerun: their source and independent lock
are unchanged. Their parent-bundle results remain historical. No hosted CI,
new generic QUIC wire acceptance, H2/H3 support, publication or deployment is
established by these checks. See [M2 acceptance](../../../m2.md).
