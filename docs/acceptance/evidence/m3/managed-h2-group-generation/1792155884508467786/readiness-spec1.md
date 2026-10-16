# Managed-H2 group Generation readiness SPEC1

Status: **DONE**. Verdict: **FAIL**. Independent read-only SPEC review; runtime **NOT RUN** (0 tests).

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline `8131af39a846c292a022ccbfd32c53376cd57887`.

Frozen input: `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/readiness-candidate1.json`; SHA256 `e9a3ce30bd40dbc5946f44930834b0a8a3f77ac1e10403f4f36d2c968c6ab90f`. Fresh final verification matches all **321/321 manifest entries**, both protected files and current HEAD. The companion JSON contains exact hashes for all bound inputs and separately identifies content-inspected files and the extra public dependency source.

## Actionable findings

### SPEC1-F1 — P2: Disambiguate the unchanged downstream browser profiles

Locations: `docs/designs/m3-managed-h2-group-generation.md:49`; `docs/plans/m3-managed-h2-group-generation.md:66`.

Design says native TLS Chrome h2 or H1 and plan says Chrome TLS downstream h2 and H1. Bound predecessor fixed-generation-browser-host3.exs:744-765 enables TLS only for mode h2; mode h1 uses clear TCP.

The wording can require a TLS-H1 row that the specified retained fixture profile does not implement, or allow reviewers to interpret the intended four-row matrix differently.

Required repair: State TLS downstream HTTP/2 and clear downstream HTTP/1.1, each against upstream h2c and TLS-H2. Keep exactly four rows, A-only old/new browser navigations, and genuine B HEAD/custody; do not expand scope to TLS-H1.

### SPEC1-F2 — P2: Use the exact existing Service byte cap

Locations: `docs/plans/m3-managed-h2-group-generation.md:30`.

Plan calls the existing service cap 536MiB. The retained fixture apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs:1608 uses 536_870_912 bytes, exactly 512MiB; design:36 already states 536,870,912.

536MiB means 562,036,736 bytes and would silently increase the intended existing capacity budget by 25,165,824 bytes.

Required repair: Replace existing service536MiB with existing service536,870,912bytes (512MiB), consistent with design and bound fixture; preserve the actual cap.

## Feasibility and scope

The reviewed production seams support the bounded qualification proposed by the plan: genuine H8/two-member Store capture, G7 plus T8 receipts, authentic old captures after retirement, selected-only singleton T child, no Session G child, shared original completion binding, and full native source retention of unselected B. No production feasibility defect or upstream dependency defect was established. The full actual R/B/native95 W accounting must still be observed by runtime gates; arithmetic is not acceptance.

The proposed same-owner max_request_tokens1 case is global-token denial; selected-A R32 saturation with available B remains open. Shared-T dedup remains a distinct real-HEAD case. Browser scope stays four rows/two old-new A navigations each, with B HEAD/custody and socket proof of B/wraparound. Thirty unique planned test files, strict compilation, active formatting/AST/embedded-JS checks, both isolated consumers and fresh final browser/source rebind remain required.

Any new retained operand, multiplicity or lifetime repair reopens constructor SPEC then CODE before runtime. This review grants no publication/deployment or broader M3 acceptance.

## Evidence, counters and shutdown

All commands were read-only inspection/hash/git-identity commands and have completed. No tests, build, browser, network operation, runtime actor or background process was started; no repository or Git mutation was made. Only the two assigned `/tmp` report files were written. Toolchain1's version-only PASS executes zero tests and does not establish runtime acceptance.

Frozen candidate counters group45/root68/orchestration9/stage-orchestration2 are an intentional cutoff. Parent subsequently reported root69/orchestration10/stage-orchestration3 for an earlier corrected read-only path lookup. Two additional post-summary inspection helpers failed (dict slicing exit1; incorrect fixed-test path exit2) and were immediately corrected; parent was notified for append-only orchestration bookkeeping. None is a runtime failed GREEN, fixture repair or production repair. This review used zero Sol failure-repair rounds and no Astra recovery; Astra2/2 remains exhausted. Parent owns canonical counter rebind.

Correct both document findings, freeze the revised candidate and request bounded independent SPEC re-review before CODE/runtime. No user decision or external permission is needed for these repairs.
