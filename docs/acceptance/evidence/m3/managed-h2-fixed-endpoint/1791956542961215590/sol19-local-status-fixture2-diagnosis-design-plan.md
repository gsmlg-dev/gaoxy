# fixed_h2_local_status_sol19_fixture2 — frozen TESTONLY handoff

Direct assignment; DONE for artifact preparation/static inspection only. Genuine defect RED and repair acceptance NOT RUN. Root alone owns formatting, source release, Mix/build/network/peer/browser/evidence. No repository/dependency/runtime/upstream/commit writes performed. All commands finished; no worker process remains.

Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
HEAD baseline: 31f23eb2d915ba715a1016f254b90d9805f18a1a
Released TESTONLY before SHA256: 218f417d03b7daf36f67582330b8a16533882439ccfe2b8837a1f3f2798aa392
Production source remains original SHA256: fd77c71e781454084e5dbec5de456a51d434567f0b29d86b7cd478d19d959c52
Corrected TESTONLY candidate SHA256: 8d8acb68e28bd79c82a8c09fb318ec4d602ec2a4e1bed7bda9efa66e27746f55
Patch SHA256: 9c8d3802e684c0178773f52ab302cb7de60432b2fc5778d0a8a3a6588db20a6f

## Evidence and exact fixture error

Root RED1 actually executed38 tests/8 failures, exit2, source stable, zero skips. The immutable log is docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/sol19-local-status-red1-1792006913602299860.log, SHA256 ceb1ead34b7cf20f0904df4351a51d3bd518269c5229d0c5eda80b1dff71edfd. Worker read-only log audit counted8 occurrences of the same `Assertion with in failed` at line690, expecting trailer:x-check in observed headers. All failed BEFORE any malformed body was sent and therefore provide no genuine defect RED.

My original fixture assertion wrongly expected an H1 Trailer declaration to appear in the independent peer's sanitized H2 request. Actual TLS-H2/h2c request pseudoheaders contain methodPOST, correct origin scheme/authority and exact target; regular headers contain forwarded values/user-agent/content-type, without Trailer or Transfer-Encoding. These hop-by-hop headers correctly do not belong on the real H2 request. Gaoxy.Headers request policy records the permitted trailer names separately; absence from observed H2 request headers must not be confused with loss of native trailer policy. The downstream test requests retain their declaration, enabling authentic native count/byte limit violations later.

## Minimal correction and bounded plan

Replace only the invalid positive Trailer forwarding assertion with an exact comparison of the observed four pseudoheaders (POST, correct TLS-H2/h2c scheme, localhost plus real peer port, exact target) and an explicit refutation of both Trailer and Transfer-Encoding fields. Keep existing observed target/connection checks. All other source bytes remain unchanged; the8 original status cases, malformed bytes, public HTTPOptions bounds, manual withheld-head mode, pending original identity/receipt/token/pin/reservation assertions,5000ms deadlines, exact closed response comparisons, no-upload/replay assertions and original completion/guardian/service/physical joins remain intact.

1. Root reviews and releases this TESTONLY replacement against exact canonical218f417d... before SHA; perform root-owned formatting.
2. Root executes the same complete endpoint test file, with all38 cases retained, and records genuine RED2.
3. Require all8 new tests to reach the exact response assertion and observe current502 rather than prescribed400/413/431. A preceding fixture/config/cleanup assertion failure remains fixture failure and must be diagnosed before production derivation.
4. Derive fresh production only after genuine RED; no production draft/candidate exists in this handoff. Retain the original prose-only local_fail bounded-status approach and original post-head stop-upload/no-second-head contract.

Root command from qualified worktree environment:

`unbuffer mix test apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs --warnings-as-errors --max-cases 1 --seed 0`

The endpoint file includes the real shared fixture. Expected genuine RED2:8 exact response mismatches, actual empty closed502 wire versus expected400/413/431. Expected shape:38 executed tests with zero exclusions; this expectation is not an executed result. Root later retains adjacent shared-fixture cleanup/committed-head coverage and complete stage manifest unchanged.

## Counters and limitations

RED1 is preserved as fixture contract failure. local-status red_failed1/fixturecorrection1 are separate from production repairs. fixedSol18/unsuccessfulGREEN14, collectorSol17/unsuccessfulGREEN12, matrixfailed11/browserfailed5/R32diagfailed5 and Astra2/2 remain unchanged. No production release/repair round consumed; astra_gate none. Upstream122 and its original cancellation assertion are untouched.

Actual PASS: Python/difflib static artifact construction; reversing only this replacement reconstructs canonical before text byte-for-byte; read-only SHA/log audit. NOT RUN: formatting, compilation, genuine RED2, GREEN, peer/network/browser, independent review. No external permission or product decision needed. Preserve all prior frozen artifacts and historical RED1 evidence.
