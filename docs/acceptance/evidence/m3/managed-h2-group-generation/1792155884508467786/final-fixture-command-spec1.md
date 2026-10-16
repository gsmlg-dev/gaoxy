# Bounded final fixture command SPEC review

Task `/root/group_generation_full_spec1` / `gaoxy-group-generation-final-fixture-command-spec1`. **DONE — PASS_BOUNDED_FINAL_FIXTURE_COMMAND_SPEC_READY_FOR_CODE**.

No actionable findings. The one-file command addition preserves all required verification and supplies the missing test-only fixture to the independent third Mix VM. This is a bounded gate repair/rebind, not a new full-stage verdict, fresh-runtime pass or stage acceptance.

Direct delegated reports-only assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation` independently confirmed; parent-provided branch `codex/m3-h1-resource-foundation`, baseline `8131af39a846c292a022ccbfd32c53376cd57887` unchanged. No Git command was run.

## Bound inputs

- proposal: `final-fixture-command-repair1.json` SHA256 `a3a591a65740e64e215ebd605541a384e944236b431b6f9b41e84227f82ddbd4`.
- inventory5: `final-gate-command-inventory5.json` SHA256 `1302ae4b986ea963d7282f344057fbe5c9cd099111019c0a5d30650213d3955a`.
- failure_classification: `scoped-final3-classification.json` SHA256 `6bf36307c8192ecab05830f7cd551b8391270216db2046c99e7f961ca29b60f7`.
- original_full_candidate: `full-stage-candidate1.json` SHA256 `307ea59084be7051a5fa19eceb72524ccd02ee73ed483adabc89d100c5726b1c`.

All12 proposal-bound inputs match. Full original frozen candidate402 source/9 documents/424 evidence/2 protected maps match, zero mismatches. No raw NetLogs/private keys/forbidden private trace inspected.

## Diagnosis and complete failed evidence

Independent third Mix VM omitted the only file defining Gaoxy.Proxy.ManagedH2FixedFixture. Module definitions loaded by the first separate Mix process do not persist into the third. Proxy test_helper only calls ExUnit.start(); no fixture require/compile or test-source elixirc path supplies this module.

- Only definition found under apps/scripts: apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs:1. Public helpers peer/2,event/2,eventually/1,no_event/2,command/4,certificates/1 exist in that module.
- managed_h2_group_accounting_owner_activation_test.exs:14 aliases it as F; fixture/3 first calls F.peer(protocol,["--manual"]) at291.
- Original inventory4 third argv omits defining file; inventory4 first argv includes it. Each executed receipt has a distinct standalone nix develop→mix test command.

Actual scoped-final3:437 tests/12 failures/exit2; gaoxy_http260/0 and gaoxy_proxy177/12. All12 underlying failure blocks independently confirm `UndefinedFunctionError` for `ManagedH2FixedFixture.peer/2` at activation fixture291. All six compiler/test warning entries reference missing fixture helpers: event/2, eventually/1, no_event/2, command/4, peer/2, certificates/1. The separate Nix dirty-tree warning remains in the raw log and is not silently counted as a compiler warning. Source stable, process joined/nonforced/no residue; adopted ready wait_status10 is distinct from actor exit or collector forcing, and signal_attempts is empty.

## Proposed command and retained passes

inventory5 scoped-final4 argv is byte-for-byte old scoped-final3 argv plus existing managed_h2_fixed_endpoint_test.exs; fresh collector name4. No original16 path removed/reordered or option changed.

All32 distinct paths retained;33 path entries across9+7+17, only defining fixed_endpoint_test.exs repeated. Every path exists. No filter, skip, suppression, assertion/cap/deadline/source/collector change. Full defining tests run again in the repaired batch. All five later command/collector argv and final browser object remain unchanged; future receipt/run names are unused.

- scoped-final1: {"name": "scoped-final1", "tests": 239, "failures": 0, "skipped": 0, "excluded": 0, "warnings": 0, "exit": 0, "receipt_sha256": "19482766c76e1b42bdc8b78aacb275be805b904bcada0ab9e4e72b008bd35545", "original_and_inventory5_argv_equal": true, "receipt_command_equal": true, "log_hash_equal": true, "source_entries_current": 402, "source_before_after_equal": true, "process_joined": true, "forced": false, "wait_error": null, "process_group_remaining": [], "adopted_wait_statuses": [10, 10, 0], "collector_signal_attempts": [], "remaining": []}.
- scoped-final2: {"name": "scoped-final2", "tests": 170, "failures": 0, "skipped": 0, "excluded": 0, "warnings": 0, "exit": 0, "receipt_sha256": "65a7f5e233666d61ccedbfe9cd1964683288be8db60f87e5de999b40716f345b", "original_and_inventory5_argv_equal": true, "receipt_command_equal": true, "log_hash_equal": true, "source_entries_current": 402, "source_before_after_equal": true, "process_joined": true, "forced": false, "wait_error": null, "process_group_remaining": [], "adopted_wait_statuses": [10, 0], "collector_signal_attempts": [], "remaining": []}.

Both retained commands exactly match inventory4,inventory5 and their actual receipt command; current402 source hashes, before=after and log hashes verified. Their complete passed receipts remain qualified for unchanged commands/source. No new concern requires rerun.

browser_initial NOT RUN field remains the immutable historical pre-execution snapshot. Actual separately recorded initial-green4 PASS4/8 is unchanged; new repair.sequence does not rerun initial browser and does not borrow it for fresh final browser.

## Remaining sequence and custody

- Bounded CODE review against unchanged proposal/inventory5
- Root executes complete17-file scoped-final4; requires nonzero actual tests and zero failures/skips/exclusions/compiler-test warnings, exit0/source stability/real clean custody
- Then still-unrun strict-compile1,format-final1,consumer-core1,consumer-http1,syntax-final1
- Fresh browser-final1 all4 rows with root8 screenshot views and full source/loaded identity/custody/zero/rebind checks
- Task6 current documents, exact disk/index/blob custody audit and authorized local commit; keep110→111 editorial N1 pending final docs

scoped-final3 remains FAIL437/12/exit2 with six warnings, all prior failures/UNKNOWN and inherited inventory snapshots unchanged. final1/2 retained only for exact unchanged source/argv; not reclassified or rerun. No new full-stage pass/stage acceptance inferred.

Cumulative counters unchanged from handoff: `{"group_failed_green": 53, "root_failure_events": 113, "orchestration": 42, "stage_failed_green": 8, "stage_production_repair": 2, "stage_fixture_repair": 10, "stage_orchestration_repair": 35, "stage_invalid_red": 1, "stage_valid_red": 1, "astra_used": 2, "astra_limit": 2}`. Own inspection failures0; own Sol repair rounds0; Astra2/2 exhausted, no astra_gate/escalation.

All own inspection commands exited0; no own failures. Proposal12 and full candidate402source/9docs/424evidence/2protected all match. No source/assertion/document change introduced. Full final1/2 receipt command, log hash,402 current source hashes and before/after equality checked. Underlying final3 log all12 blocks/6 undefined warnings independently verified.

pwd, rg/rg --files, bounded sed reads, Python JSON/log/hash/argv/path checks; no Git/runtime/build/browser/network operations. All own commands finished synchronously; no runtime sessions launched, no parent processes touched. Only the two assigned `/tmp` reports were written. All repository/source/history remains parent-owned and unchanged.

Decisions needed: none. Proceed to bounded CODE; actual repaired execution remains NOT RUN.
