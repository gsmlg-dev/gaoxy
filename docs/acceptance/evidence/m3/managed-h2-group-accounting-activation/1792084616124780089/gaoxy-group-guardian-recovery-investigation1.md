# Guardian-death source investigation 1

DONE_SOURCE_INVESTIGATION_CAUSE_UNPROVED. Direct bounded read-only investigation in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, baseline HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Root owns current source freeze and runtime83067.

Prior failure14 at test line56 occurred after original RequestCompletion.await(completion,@timeout) returned :ok. It proves only that the compound Gtokens-empty/Ttokens0/helpers0/pins1 predicate did not succeed within G.eventually default5s. Log supplies no G/T raw predicate snapshot and no recovery exception for this case.

Group owner handles actual guardian monitor DOWN by clearing token monitor, preserving stored completion/charge and spawning a separate Probe recovery with exact original completion. Recovery public abort-and-await polls every5ms until its deadline; matching recovered success removes/refunds original G selection. Refused startup/reconcile, error recovery or recovery DOWN can mark group failed while retaining selection; none is evidenced by the prior failure log.

T owner handles guardian monitor DOWN independently by spawning abort helper over same original completion with5s deadline. Original token is retained until helper result plus helper DOWN join, then a fresh await(original,0) confirms cleanup before removal. Polling may retain unresolved token within original cleanup deadline. Helpers field includes both resource helpers/opening and token abort helpers.

T pin records are independent of request tokens: derived request pin is guardian-held and is removed on its own holder monitor DOWN; captured source pin is pump-held and released from GroupEndpoint try/after or holder DOWN; baseline remains embedding-held. Therefore completion:ok alone does not identify token/helper/pin predicate satisfaction.

Killed guardian cannot execute new terminalguard; test held state has pending live request before Process.exit(:kill), and G Probe/T helper paths are outside Session generic events. HTTP pump observes Session DOWN and returns bounded error response then releases captured pins through endpoint after. No direct source path makes terminalguard a repair for this killed-guardian failure; scheduling changes are not causal evidence.

Service and Admission gate are intentionally still blocked at the predicate. Diagnostic must never query these actors. The existing barrier5s timeout is unchanged; the investigation does not extend it, release it early or waive missing Service receipt/shutdown assertions.

Conditional diagnostic: `/tmp/gaoxy-group-guardian-recovery-diagnostic1.patch`, SHA `bed26f744cd25052c3efa22395616230a9bf3326f624d08173f62e87b8a290ee`, target source `ef24421bbae699d1f5c868eb7a29d34d1aededca8b3a0d501a7bd879fd72190d`. Apply only if fresh live110 reproduces this exact predicate failure and after root review/compile. The original G.eventually predicate and5s timeout are unchanged; failure-only rescue takes two100ms G/T state observations, prints exact token/helper/pin aggregation and capped original-identity/recovery/pin-holder metadata, then re-raises the original assertion/stacktrace. It does not query blocked Service/gate or serialize opaque completion/Promise. These are postfailure non-atomic snapshots, not proof of historical state.

Runtime, format and compile NOT RUN;0 tests executed. Current live110/Session46 result pending/root-owned. Only `/tmp` diagnostic/report files were written; all own commands finished; root processes untouched. Local Sol repair0; cumulative root counters preserved; Astra2/2 exhausted. No repair proposed, escalation or product decision.
