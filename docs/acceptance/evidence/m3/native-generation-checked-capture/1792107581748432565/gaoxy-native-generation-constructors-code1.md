# Task3.5 actual-source constructor CODE review

PASS — no actionable findings. Direct source-only constructor review; no runtime/native acceptance.

Repository: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation. Branch codex/m3-h1-resource-foundation; HEAD e189894882bb6a530f2c38538be4efaf384be261.
All17 SPEC candidate files match. Canonical source manifest SHA256 db8d069ee44f41db0abda52330e84cd83e78baa30d433049b2f1c31eed99d948. SPEC JSON SHA256 eb800cad89335440067e9c0cc34c55c48bd255707ad4917376e298de9469935a. Full per-file hashes and both complete53-row profiles are in the paired JSON.

Independent complete ETF derivation matches actual source scalar expressions over 106 fixed-point iterations, both required profiles and every SPEC width-boundary input. All53 literal diagnostic signatures agree. Retained0: M65536 gives B5350589; default M1048576 gives B11248829, both in2 iterations. Full plan envelope59, checked preflight maximum39, checked error triple62. G7/T8 bounds73862/75921; alias/from2074/4123.

- CODE-01 PASS: Complete future endpoint body is staged only as call_checked/2; Endpoint.call/2 has no checked activation path. Source: generation.ex:132-148,215-251.
- CODE-02 PASS: Before Admission, reservation calls scalar context validation and numeric fixed-point arithmetic only. No rows, report/list/bounds maps, diagnostic worksheet or apply argument list is reachable; complete compact success envelope is paid. Source: managed_generation_accounting.ex:385-408,498-578;generation.ex:218-293.
- CODE-03 PASS: All53 source roles, complete ETF caps/envelopes/counts/owners/lifetimes/subtotals match independent SPEC, actual scalar source and literal diagnostic ledger across integer widths. Source: managed_generation_accounting.ex:178-280,507-578,604-745.
- CODE-04 PASS: Original four-field ledger is consed before provider effect, retained through final readiness check and used for rollback of current+prior original operations. Failed receipt cannot redirect authority; no ledger is published. Source: resources.ex:76-117,234-246;generation.ex:446-454.
- CODE-05 PASS: Full G7/T8 schemas and exact provider/owner/operation/ordered original batch/every epoch/request-kind correlate; T original holder also correlates. Genuine complete receipts stay intact. Source: managed_generation_accounting.ex:62-72,410-473;managed_h2_group_accounting.ex:436-486;upstream_groups.ex:918-926;upstream_transports.ex:924-933.
- CODE-06 PASS: Actual pin/pins preflight precedes cons; actual new/existing capture-list preflight precedes append. No rejected aggregate candidate is constructed. Full preflight maximum39 and finite checked err3 maximum62 are paid. Source: managed_generation_accounting.ex:28-49,95-111;resources.ex:90-94,209-222;generation.ex:230-236,295-312.
- CODE-07 PASS: At most64 serial starts plus one genuine public T post-owner-reply failed-postcheck self-cancel yield65 controls; Store still cancels that original current operation. Runtime65x4124=268060; historical64x4124=263936 unchanged. Source: upstream_transports.ex:108-127,146-148;resources.ex:82-100,234-246.
- CODE-08 PASS: Store rejects holder mismatch before effects; Resources checks original D/live holder at entry, between batches and immediately on success publication path. Checked transport errors stay finite and conservatively uncertain. Source: generation.ex:165-194,446-454;resources.ex:76-117,142-176.
- CODE-09 PASS: Explicit Admission.update/4 uses min5000/remainingD while update/3 and handlers retain semantics. Original D bounds acquisition; Dc=D+1000 is shared for public G/T release/2, with positive-time checks and no further synchronous dispatch after expiry. Legacy release/1 unchanged. Source: admission.ex:20-25,243-280;generation.ex:272-293,336-349;resources.ex:120-133;upstream_groups.ex:347-371;upstream_transports.ex:108-148.
- CODE-10 PASS: Router catch is narrow; total cleanup cannot replace original class/value/stack or returned error. Re-raise uses original stack; success with failed release returns finite error with latest exchange. Source: generation.ex:311-349.
- CODE-11 PASS: Requester alone emits once on uncertainty using empty scope and finite exact metadata. Observer catches raise/throw/exit internally and cannot escape/reemit; no Store/Resources event. Source: generation.ex:239-246,336-372;telemetry.ex:3-5.
- CODE-12 PASS: Route reservation accumulates additively; no cleanup/cancel/Router return subtracts it. Existing Exchange retained-byte computation always includes route_bytes until ordinary lease teardown. Source: generation.ex:218-246,311-349;exchange.ex:367-374.
- CODE-13 PASS: Complete known descriptors include server/request/actual timeout; finite reason maximum widens to err3. Installed OTP uses improper alias/from/call/reply/DOWN constructors. Unknown raw diagnostics normalize without recursive retention; arbitrary raw diagnostic interiors remain outside certified scope. Source: gen.erl:251-279;gen_server.ex:1117-1131;managed_generation_accounting.ex:52-58,513-547,613-614.
- CODE-14 PASS: No core/HTTP proxy reference, new process, dependency patch or private runtime API is added. Old24 worksheet tests remain byte-identical, service/group/startup constants unchanged, upstream-H2 Generation exclusion retained. Source: admission.ex;generation/accounting.ex;resources.ex;generation.ex;managed_h2_group_accounting.ex:78-89;managed_h2_reservation.ex:17.

Complete reviewed table at M65536/retained0:

| # | Role | Owner | Lifetime | Count | Cap | Subtotal |
|---|---|---|---|---:|---:|---:|
| 1 | context | requester | request_end | 1 | 8213 | 8213 |
| 2 | plan | requester | request_end | 1 | 59 | 59 |
| 3 | admission_update_payload | requester | admission_return | 1 | 2063 | 2063 |
| 4 | admission_update_wire | admission | admission_return | 1 | 6198 | 6198 |
| 5 | admission_update_reply | requester | admission_return | 1 | 2116 | 2116 |
| 6 | snapshot_requester_payload | requester | snapshot_return | 1 | 2131 | 2131 |
| 7 | snapshot_call_wire | store | snapshot_return | 1 | 6266 | 6266 |
| 8 | snapshot_store_payload | store | snapshot_return | 1 | 2131 | 2131 |
| 9 | snapshot_store_from | store | snapshot_return | 1 | 4123 | 4123 |
| 10 | validated_manifest | store | snapshot_return | 1 | 65536 | 65536 |
| 11 | partition_map | store | acquisition_end | 1 | 199551 | 199551 |
| 12 | provider_handle_normalization | provider | provider_return | 3 | 65536 | 196608 |
| 13 | provider_request_payload | store | provider_return | 1 | 69676 | 69676 |
| 14 | provider_call_wire | provider | provider_return | 1 | 73811 | 73811 |
| 15 | provider_owner_payload | provider | provider_return | 1 | 69676 | 69676 |
| 16 | provider_owner_from | provider | provider_return | 1 | 4123 | 4123 |
| 17 | genuine_provider_pin | provider | receipt_validation | 1 | 75921 | 75921 |
| 18 | provider_result_payload | provider | provider_return | 1 | 75927 | 75927 |
| 19 | provider_reply_wire | store | receipt_validation | 1 | 78002 | 78002 |
| 20 | provider_store_received_result | store | receipt_validation | 1 | 75927 | 75927 |
| 21 | checked_acquisition_accumulator | store | snapshot_return | 3 | 65542 | 196626 |
| 22 | original_provenance | store | acquisition_end | 3 | 331456 | 994368 |
| 23 | store_snapshot_payload | store | snapshot_return | 1 | 196612 | 196612 |
| 24 | store_snapshot_wire | requester | snapshot_return | 1 | 198687 | 198687 |
| 25 | requester_snapshot_received | requester | request_end | 1 | 196612 | 196612 |
| 26 | caller_capture_inputs_and_output | requester | request_end | 3 | 65536 | 196608 |
| 27 | release_payload | requester | release_return | 1 | 65541 | 65541 |
| 28 | release_call_wire | provider | release_return | 1 | 69676 | 69676 |
| 29 | release_reply_wire | requester | release_return | 1 | 2116 | 2116 |
| 30 | cancel_control | provider | cancellation_uncertain | 65 | 4124 | 268060 |
| 31 | known_call_failure_descriptor | caller | call_return | 1 | 71829 | 71829 |
| 32 | known_monitor_down | caller | call_return | 1 | 4187 | 4187 |
| 33 | cleanup_observation | requester | emit_return | 2 | 6276 | 12552 |
| 34 | finite_failure_payload | requester | request_end | 1 | 62 | 62 |
| 35 | original_current_entry | store | acquisition_end | 1 | 69685 | 69685 |
| 36 | manifest_normalization | store | acquisition_end | 2 | 65536 | 131072 |
| 37 | manifest_validation_result | store | acquisition_end | 1 | 65542 | 65542 |
| 38 | acquisition_control | store | acquisition_end | 3 | 397001 | 1191003 |
| 39 | partition_scratch | store | acquisition_end | 2 | 199551 | 399102 |
| 40 | checked_config | requester | request_end | 1 | 2143 | 2143 |
| 41 | checked_preflight_result | caller | preflight_return | 2 | 39 | 78 |
| 42 | checked_acquisition_failure | store | acquisition_end | 2 | 62 | 124 |
| 43 | checked_release_status | requester | cleanup_end | 2 | 41 | 82 |
| 44 | cleanup_deadline | requester | cleanup_end | 1 | 12 | 12 |
| 45 | finite_control_status | caller | request_end | 2 | 22 | 44 |
| 46 | original_deadline | caller | request_end | 1 | 12 | 12 |
| 47 | numeric_m | requester | reservation_return | 2 | 6 | 12 |
| 48 | numeric_retained | requester | reservation_return | 2 | 3 | 6 |
| 49 | numeric_reservation | requester | reservation_return | 2 | 6 | 12 |
| 50 | numeric_retained_plus_reservation | requester | reservation_return | 2 | 6 | 12 |
| 51 | numeric_next | requester | reservation_return | 2 | 6 | 12 |
| 52 | numeric_iterations | requester | reservation_return | 2 | 3 | 6 |
| 53 | numeric_timing | requester | cleanup_end | 3 | 12 | 36 |

Total 5350589. At default M each of three snapshot caps increases1966080; total 11248829. Both full tables with formulas/source bindings are preserved in JSON.

Final independent Python audit exit0. Parent constructor-green4 receipt/log audit confirms49 executed,211 excluded,0 failures,0 counted warnings, exit0. Store-green1 confirms40 executed,0 failures, exit0. These are parent executions; fresh post-CODE gate remains required. Two initial reviewer parser errors were corrected without repository/runtime mutations.

No Elixir/Nix/mix/tests/build/formatter executed by reviewer. No runtime/background process started/touched. Only two assigned /tmp review files written. Root retains repository/runtime/build/test/evidence/Git custody.

Counters preserved: failedGREEN4 + aborted1; production repair1; fixture repairs3; root events32; Astra2/2 exhausted. Reviewer production repairs0, no escalation, no new decision.

Parent must run fresh exact constructor gate and issue receipt before connecting Admission. Final runtime/native/consumer/C5 acceptance remains open. Preserve upstream-H2 Generation exclusion and existing publication/deployment restrictions.
