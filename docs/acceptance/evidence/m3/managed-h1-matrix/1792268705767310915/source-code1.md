# Managed-H1 matrix independent source code review

**FINDINGS_SOURCE_CODE1** — source review finished; F1/F2 require targeted repair before candidate runtime. Runtime remains **NOT RUN**.

Direct non-author review of `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, root-verified entry `1426657e65d726629d618dcf03880df718375dd1`. Candidate2 SHA256 `71aa146f0572f1ca54f33d7428e35313c21223183b4a5be4f1ea50179a3a409d`; inventory2 SHA256 `db447d788e4440aa29593b8085df5a002093f12b05277485d80eceaab91f5a25`.

## F1 — P1: Leave cleanup headroom outside the attached-driver watchdog

`apps/gaoxy_proxy/test/upstream_transport_h1_matrix_test.exs:8`; `apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs:454-483,560-572`.

The ExUnit watchdog kills the test at40s. The attached receive loop allows35s, followed by a separately authored10s cleanup envelope. On a stalled driver, TERM can consume5s before KILL/join; the outer timeout can kill the fixture owner at that escalation point, before it finishes group/fixture/Port cleanup. Bounded dispatch can also extend beyond the receive deadline. This can strand owned resources during the failure path.

Keep the prescribed5s barriers/20s cases/10s startup and shutdown unchanged. Provide enough outer watchdog headroom for the operation plus full mandatory cleanup, including bounded dispatch, or align the inner watchdog to leave that cleanup headroom. Preserve all protocol assertions.

## F2 — P1: Make browser ownership and failure cleanup unconditional

`integration/upstream_transport/browser.py:63-76,220-223,294-306,327-343`.

Actor launches Popen before its exclusive log open and reader-thread starts; actors are registered only after the constructor returns. A post-spawn setup exception or SIGALRM during this handoff leaves the owned process group outside the finally registry. A failed host constructor also leaves host=None. Further, the global alarm is disabled only after cleanup. If it interrupts dispose while waiting after TERM, the caller records the exception and proceeds without completing that actor's KILL/join path.

Make partial construction retain or clean its ownership, shield the spawn-to-registry handoff, and disable the outer alarm before the bounded exception-isolated sweep. Preserve forced/errors/unjoined outcomes as failures. Reuse existing actors/groups; no new architecture or identity proof is requested. These are demonstrated source failure paths, not observed runtime leaks.

## Other source checks and separate gates

The explicit16 registry shares its actual choreography between ExUnit attached mode and the standalone adapter. Temporal upload/response barriers precede suffix release; exact binary bytes/digests, ordered duplicate fields/safe declared trailers, raw gzip, bodyless cases, persistent H1 HEAD→204→GET, actual upstream accepted-connection reuse, original completion/binding and final accounting remain asserted. The client diff is confined to optional prefix observation and preserves default/server modes. The separate browser source implements group native-H1/H2→TLS-H1 with two pages per row, actual TLS/readiness/CDP/body/protocol receipts and separate root image inspection.

All8 owned,8 document,11 installed and401 supplied safe source identities match candidate2. Three Python AST parses and node --check browser.mjs passed, exit0. Full exact owned/document pins are in the JSON companion. These syntax/identity results do not pass a runtime gate. SPEC2 remains a separate retained PASS; CODE1 has findings. First matrix runtime, fresh verification, integration, browser and root image inspection all remain NOT RUN.

No repository edits, Git, Mix, build, tests, browser or candidate imports/runtime occurred. One combined owned-source display was truncated; bounded ranges were reread. No full inventory map, protected/private file, key or raw trace was printed/read. All commands finished exit0, with no background processes launched.

New review repair rounds0; parent-reported targeted Sol repair1 unchanged; inherited Astra2/2 exhausted unchanged. Earlier cumulative Sol total was not supplied and is not reset. No product decision is needed. Whole Task6/Task5/M3 remain OPEN.
