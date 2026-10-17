# Managed-H1 matrix source specification re-review3

**PASS_SOURCE_SPEC3** — CODE1 F1/F2 resolved in source; no new actionable source finding. Prior SPEC1 findings remain resolved and retained.

Candidate3 SHA256: `155ac1415a4d11be7cc74083856b5e915a251b701aa5c0f69d5769653dde2c2a`. Inventory3 SHA256: `762cbaffb85f968c9b719af1d24b995da9b31a681a8602d47c274bef66ba243c`.

F1: the test watchdog is90s, giving35s receive +40s composed dispatch +10s cleanup +5s framework headroom. Prescribed5s/20s/10s phase bounds remain unchanged. Exact reverse reconstruction preserves every candidate2 test byte except the watchdog and two comments.

F2: browser partial Actor ownership precedes log/spawn setup; SIGALRM is masked through process/thread ownership handoff. The outer alarm is disabled before the exception-isolated sweep. Disposal now checks the owned group even after leader exit/normal close, bounds TERM/KILL/reap/thread cleanup and preserves forced/errors/unjoined FAIL outcomes. All32 browser require-call ASTs and page/row acceptance oracles remain unchanged.

All8 owned/8 document/11 installed/401 explicitly supplied safe source identities match; only the two assigned source files changed from candidate2. Three Python AST parses passed. Full actual input hashes/history are in the JSON companion. Parent formatting exit0 is retained, not rerun.

All nine runtime command gates remain **NOT RUN**. No Git, Mix, build, tests, browser, imports/runtime or repository edits occurred. All review commands finished exit0; no new incident, process or repair round. Astra2/2 and earlier counters remain unchanged. WholeTask6/Task5/M3 remain OPEN.
