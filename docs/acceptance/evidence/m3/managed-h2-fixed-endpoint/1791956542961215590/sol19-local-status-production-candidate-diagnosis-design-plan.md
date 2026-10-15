# fixed_h2_local_status_sol19_production — fresh frozen candidate

Direct bounded assignment. DONE for candidate derivation and static handoff; production repair acceptance NOT RUN. Source release, formatting, all Mix/compile/network/peer/browser/evidence and commits remain Root-owned. No repository/dependency/evidence writes or runtimes started; all worker commands finished. No public API/dependency/Session schema/H2 semantic change.

Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
HEAD baseline: 31f23eb2d915ba715a1016f254b90d9805f18a1a
Production before SHA256: fd77c71e781454084e5dbec5de456a51d434567f0b29d86b7cd478d19d959c52
Current formatted TESTONLY SHA256: e451fe402e55b08e288593818e9c14de7a232658cd42c4c5a4d5d2fcef0fa780
Candidate HTTP.ex SHA256: 1dfe2b052de4cbcb3fa6eae4288f728e0c14da147825180b677be91d8a43d36e
Patch SHA256: 7bbe9583b598c5c24c5898d25139580ce0a4411e56311bd702c4c422e36797bf

## Genuine RED and cause

Root RED2 receipt: docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/sol19-local-status-red2-1792007163419366469.json
Causal diagnosis: docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/sol19-local-status-red2-causal-diagnosis.json
Actual log: docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/sol19-local-status-red2-1792007163419366469.log
All identities and hashes are in manifest.json. RED2 actually executed38 tests/8 failures, exit2, stable source, zero skips/exclusions. The2 malformed-chunk400,2 native-body413 and4 native-trailer431 cases passed authentic independent upstream target/pseudoheaders and original completion identity/pending/token/pin/helper/reserve barriers, then each reached the exact closed wire comparison at canonical test line726 and observed502. This is genuine defect RED; RED1's earlier header fixture failure remains historical.

Source cause remains: HTTP.read_upload passes native Exchange request_error triples to local_fail; generic fail normalizes managed reasons before status selection; Session.finite_reason drops that triple to :upstream_failure, selecting502. Preserving unrestricted raw tuples would weaken finite control and allow upstream reasons to masquerade as native request statuses.

## Fresh bounded implementation

Derived from current canonical source only after genuine RED2; discarded draft production files were neither read nor reused.

1. Add one local_fail clause restricted to client ManagedH2Client and statuses400/413/431. The anonymous raw-reason field is immediately discarded. Pass existing finite atom :invalid_request and the allowlisted integer into shared private fail/3.
2. Keep generic fail/2's original managed finite_reason call and unchanged mapping for nonmanaged request_error statuses, timeout504, request_timeout504, unavailable503 and fallback502. It computes status from normalized reason and delegates to private fail/3. An upstream request_error tuple entering fail/2 therefore still normalizes to :upstream_failure and502; a malicious native status outside the allowlist falls through generic fail/2.
3. Shared fail/3 retains identical Session.cancel, Process.demonitor(:flush), response==:unset and total_expired checks, error_response invocation and post-head finite reason/close:true return. Status mapping now precedes the shared cleanup instead of occurring inside its response-unset branch; mapping is a pure case and introduces no IO/state or retention.

The managed local path passes only the finite :invalid_request atom and one of3 finite status integers. No raw local reason is retained or passed to Session/error_response. All generic fail/2 callers and ordinary local failures retain existing behavior. ManagedH2Client.finish_body collapses upstream failures to finite :upstream_trailer_limit; response/policy helpers do not manufacture native request_error triples. Upstream messages continue through dispatch/error -> fail/2.

After a committed final head the native upload read path is stopped by upload_stopped:true; no invented post-head local parser trigger was added. The shared fail/3 branch still emits no second head and returns close:true. NativeH2 body-limit reset(CANCEL), limits, reservation, deadlines and public flow remain unchanged. TESTONLY assertions are untouched.

## Plan and Root-only verification

1. Complete ongoing independent SPEC review, then independent CODE review of this exact fresh candidate SHA/patch. Resolve actionable findings before release.
2. Root compares both before hashes, releases this single production file and formats it under the qualified environment. Only then does fixedSol19 count as released.
3. Root executes the same full38 endpoint tests with zero exclusions. Require400/413/431 wire assertions plus original cleanup/guardian/token/pin/service/physical joins to pass.
4. Root retains fresh adjacent shared-fixture cleanup/committed-head tests and all required stage manifest/matrix/browser gates. Upstream122's original pre-head cancellation compatibility blocker and assertion remain unchanged.

Same genuine RED2 command (Root already ran it; worker did not):

`nix develop --command env ERL_FLAGS=+S 2:2 MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --seed 0 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`

Fresh GREEN must execute that same complete endpoint file. For adjacent cleanup/committed-head compatibility, include endpoint file defining the shared real fixture along with managed_h2_fixed_write_lifecycle_test.exs and managed_h2_fixed_lifecycle_test.exs. No full-stage gate is replaced by this scoped command.

## Actual verification/status/counters

PASS: Python/difflib static construction from canonical hashes; reverting the2 replaced source regions reconstructs canonical source byte-for-byte; RED2 receipt/causal case count/status audit; read-only current source/test hash comparison. NOT RUN: candidate Elixir parsing/format/compile/Mix/GREEN, peer/network/browser and independent candidate review. No runtime pass or stage acceptance claimed. Syntax and behavior await Root validation. All worker commands finished and no worker session remains.

Counters unchanged before Root release: fixedSol18/unsuccessfulGREEN14; localstatusREDfailed2/fixturecorrection1; collectorSol17/unsuccessfulGREEN12; matrixfailed11/browserfailed5/R32diagfailed5; Astra2/2 exhausted. No production release/repair round consumed by this handoff. astra_gate none. No new product decision or permission needed. Repository-owned files and all historical artifacts remain intact.
