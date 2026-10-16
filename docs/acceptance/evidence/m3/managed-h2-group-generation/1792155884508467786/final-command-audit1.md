# Final command evidence audit1

DONE — PASS for nine completed command gates only. No browser, stage or commit acceptance.

Worktree `.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `8131af39a846c292a022ccbfd32c53376cd57887` (parent/candidate bound; no Git). Candidate2 SHA256 `b8ecf718e2ca840cc3099f6efc54583785e93ad20bee1ab6462a1b802a5935de`; inventory6 `e5f06f571e9067b5fd2104db63a8bc8021531071dc92775f224f60d7ba3a93d6`; sequence3 result `42d398a1e7d8441d05ddfb75b16aca8dfdb0793ea3d1e2ae52035c98869eda80`.

| Completed gate | Executed tests | App counts | Actual/collector exit |
| --- | ---: | --- | --- |
| stop-race-green1 | 19 | gaoxy_http:19/0 | 0/0 PASS |
| scoped-final5 | 239 | gaoxy_proxy:239/0 | 0/0 PASS |
| scoped-final6 | 170 | gaoxy_proxy:170/0 | 0/0 PASS |
| scoped-final7 | 475 | gaoxy_http:260/0, gaoxy_proxy:215/0 | 0/0 PASS |
| strict-compile1 | 0 | static | 0/0 PASS |
| format-final1 | 0 | static | 0/0 PASS |
| consumer-core1 | 1 | core_consumer:1/0 | 0/0 PASS |
| consumer-http1 | 2 | http_consumer:2/0 | 0/0 PASS |
| syntax-final1 | 0 | static | 0/0 PASS |

Scoped batches239+170+475=884 test invocations across32 distinct paths/33 entries. Focused stop-race19 and consumers1+2 bring all-command total to906 invocations. These are executed invocations, not unique test-case counts; static gates execute0 tests. Failures/skips/exclusions/compiler-test warnings are0. Eight Nix-based logs retain dirty-tree notices; syntax log has none.

Exact argv matches all eight inventory6 commands plus focused stop-race repair diagnostic argv. Sequence start/result, original full-stage reviews and bounded stop-race SPEC/CODE bind candidate2 and inventory6. No repeated source review. Receipt/log/collector hashes and app-level ExUnit summaries agree. Receipt log basenames were resolved against evidence root; inventory/source paths against worktree. Inventory historical NOT RUN text is planning history, not current gate status.

All nine402-entry command manifests are stable before/after, identical across commands and match current source. Candidate2 browser manifest402 has401 common entries, all equal; its own browser collector key replaces the command collector key by design. Both exact collectors independently hash-match. Candidate source402/document9/evidence458/protected2 match current bytes; all nine pre-final-doc snapshots match originals/current documents. Syntax recorded Python input hashes/extracted JS hash and node exit0 match exact files; auditor executed no syntax or test.

Custody: all nine main commands joined exit0, no wait error/force/process-group residue. Every descendant was actually waited before force:30 adopted waits,11 literal status0 and19 literal status10. On Linux status10 means signal10/decoded exitcode-10, never exit0. No collector signal attempts, force, reap deadline exhaustion or descendant residue; signal origin is not established here. Per-command PID/literal wait data are preserved in JSON.

All458 frozen evidence files preserve historical scoped-final3 FAIL437/12 and scoped-final4 FAIL475/1, plus earlier invalid RED1/FAIL/UNKNOWN/sticky failures. Fresh command PASS does not reclassify history. Frozen old canonical docs remain unchanged at audit time; final editorial/doc work and Git index/blob/actual-commit custody are separate.

The audit hashed897 exact inputs before/after, then independently rehashed all897 unchanged. One report-generation check exited1 after valid JSON write: an integer-key wait-count dictionary round-trip compared unequal because JSON object keys become strings. Counts were independently rechecked; normalized JSON uses string count keys while each original wait_status stays an integer. This report-only error/recovery is explicit in JSON; no runtime/source edit. Other commands exited0; worker runtime tests0/source repairs0, no own background sessions.

Latest parent observation: group54/root125/orchestration53/stagefailed9/production2/fixture11/stageorchestration46/invalidRED1/validRED1/Astra2of2. Own later report serialization event separately reported; totals parent-owned. No reset/new Astra. Root separately handles completed browser and8 image views; this command audit neither inspects nor claims them. Forbidden raw private trace/NetLogs/keys unread. Decisions needed:none.
