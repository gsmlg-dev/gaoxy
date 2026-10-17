Task h2_identity_denial_impl_repair1 — DONE: read-only diagnosis and bounded repair proposal only.

Direct repair assignment. Repository/worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation. HEAD verified8f6b884524d81d8defa7c5081230b8ab635e8107. Root owns existing fixed-test/peer changes and evidence files. This worker changed ONLY /tmp/gaoxy-h2-identity-denial-repair1.md and .json. No code/repository/evidence/Git changes, no runtime/build/test/fixture/browser/network commands, no private keys/raw NetLogs/forbidden trace reads. All own commands finished. No new tooling/source lookup errors in this assignment.

Verdict and exact repair

The failed assertion was introduced by my prior proposal. It used a nil sentinel for a production boolean field. Replace only this combined assertion in rotation_denial_finish_unconfirmed/9:

    assert retained.helpers == %{} and retained.opening == nil

with two independent exact assertions:

    assert retained.helpers === %{}
    assert retained.opening === false

The helpers assertion remains exact and unchanged in intent. opening===false enforces the actual constructor/transition contract and rejects true, nil and every other value; this is a fixture expectation correction, not a relaxed cleanup assertion. No production repair is justified. Preserve all preceding/following negative assertions, deadlines, capacity limits, public errors and sticky original/scope/owner receipts.

Source evidence

apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:
- 815-836: allocate creates the resource record with opening:true, transport_confirmed:false, custodian_down:false and helpers:%{}.
- 545: successful managed scope opening sets opening:false.
- 555-563: unsuccessful scope opening sets opening:false while retaining failed allocation uncertainty.
- 589: real custodian retirement confirmation sets opening:false.
- 1484-1503: update_custodian sets opening:false for real retirement/failure notifications; a retained failed record is never rewritten to nil.
- 1355-1358: public helper count sums map_size(entry.helpers) plus1 if opening is true, plus token abort-helper presence. The denial's preceding eventual resources1/pins0/request_tokens1/helpers0/reserved_connections2/failed_resources1/lifecycle:retiring assertion already passed in all3 failures. Thus no opening work is pending; the constructor-defined settled value is false.
- 1524-1527: settle_entry explicitly pattern matches opening:false; nil is not a supported settled constructor.

Runtime evidence read, not rerun

E4 is the existing evidence directory docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696. fixed-green1.json records FAIL, actual_exit2,86tests/3failures, skipped0/excluded0/warnings[], source_stable:true, forced:false, process_joined:true and process_group_remaining:[]. Log names all3 identity-rotation denials (wrong_host_trusted_ca, new_ca_old_ip, old_ca_new_ip), each failing exactly the combined helpers/opening assertion at current test line2456. Each reached the explicit cleanup_unconfirmed branch and passed original sticky receipt, real Service/Gate joins, scope failed receipt and retained-owner settlement checks that precede line2456. Those facts do not make the test or full cleanup gate pass: later receipt repeats/disposal/history assertions were NOT reached. Keep the historical FAIL immutable. The :ok terminal branch remains unexecuted by these3 actual negatives.

Bounded adjacent contract check

No NEXT obvious boolean-versus-nil mistake found in the subsequent denial assertions or the nearby optional fields:
- Resource transport_confirmed/custodian_down are booleans (allocate832-833; retirement589), so not transport_confirmed and confirmed==false are type-consistent.
- Request token guardian_down is a boolean and abort_helper is nil-or-helper tuple (token_hold1212-1220; abort helper installation1306ff), so guardian_down and abort_helper==nil are distinct correct contracts.
- Custodian confirmed/failed are booleans initializedfalse (custodian48-49), fail flips failedtrue (303-307), confirmation flips confirmedtrue (294-298). retire_helper/retry_helper are optional nil-or-helper tuples (36-40,188-191, joins), so their nil assertions are correct.
- Custodian initial_mode/mode are initially nil, then mode atoms; the failed path checks initial_mode:graceful/mode:abort and control_calls2 after both helpers settle. The existing eventual already passed that exact phase before the failure; preserve it.
- Admission lease cleanup and Service cleanup_failed use nil absence values, while receipt is boolean (admission129/207,321/345,583; service77,116/133). Keep these nil/false assertions unchanged.
- retained.payload_bytes and hold.payload_bytes are positive integer serialization charges; their >0 tests preserve the full charged ledger. No field-role redesign or broader fix proposed.

These are source-backed checks, not proof that subsequent runtime assertions pass. A fresh re-reviewed run must execute them. No claim of a new regression or production defect follows from the unexecuted suffix.

Persisting the actual terminal outcome safely

Root's planned terminal JSON receipt is appropriate only AFTER the selected branch has completed all actual original/Session/native/Service/Gate/creator/owner joins, peer exact totals, rebind and branch history checks. Emit the case name, SHA256 of the actual original public RequestCompletion term, exact terminal-result literal, and whether failed-test-actor disposal was performed by the completed sticky branch. Compute the digest from the original completion captured at bind; do not print the raw completion, tracker/ref, certificate/key paths, credentials, headers or state. The actual literal must remain :ok or {:error,:cleanup_unconfirmed}; failed disposal truth must remain true for the sticky branch and false for confirmed success. This receipt supplements the existing assertions; it must not substitute for them, treat unconfirmed as confirmed, or emit a success-looking receipt before branch completion.

Counters and acceptance boundary

Inherited root cutoff155/group_failedGREEN55/orchestration82/tooling22; first fixed runtime failedGREEN1, proposed fixtureRepair1/Sol repair round1, production0, Astra2/2 exhausted. This worker performed source diagnosis only, zero repair edits and zero validation executions; root owns application/independent review and the pending first repair-and-validation round. No counters reset, no Astra request, no third recovery round. No additional approval/product decision needed. Status of post-repair parsing/format/tests/protocol matrix, terminal JSON receipts, full cleanup suffix and independent review: NOT RUN by this worker. All observed cleanup_unconfirmed history remains failed/retained; do not infer successful capacity restoration from failed-actor disposal.
