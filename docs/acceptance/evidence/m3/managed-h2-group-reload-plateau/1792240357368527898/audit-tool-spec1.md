# Group reload audit tool SPEC1

**FAIL_AUDIT_TOOL_SPEC.** Complete independent review of all 551 lines (37481 bytes) of frozen `runtime-audit-proposal2.py.txt` against candidate2's actual emitted schema found two actionable false-positive conditions. This is a completed static review, not runtime acceptance. No proposal, tests, build or browser were executed.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; supplied and previously verified baseline HEAD: `e4a7660baa61a792f4245f511b190a0fcfcbf920`.

## AT1 — high: collector map excludes the enum in the compared candidate map

Proposal lines458-460 require the candidate's complete402-entry map; lines473-474 compare the receipt's source_before directly with that map. Candidate2 line291 explicitly includes E6 `chromium-netlog-event-enums1.json`. Actual frozen `command-collector1.py` source_manifest lines23-32 includes apps/config/scripts/integration, root files and E6 `.py`/`.exs`; it does not include that sibling enum JSON. The genuine first receipt is therefore expected to contain401 entries and fail `command.exact_frozen_input_map` even if the command succeeds and every source remains unchanged. Parent identified this mismatch; reviewer independently confirmed it.

Repair the audit operand: derive the exact collector map by excluding only the explicitly named E6 enum from the pinned candidate map. Compare receipt before/after maps exactly with that map, preserve the separate frozen enum pin/report, and retain every other operand. Do not alter the collector or immutable candidate; do not use a subset check.

## AT2 — medium: unsupported combined peer setup deadline

Proposal line183 requires `observed_setup_to_ready_ms` between0 and25000. Actual group-source lines3312-3335 wrap the entire `F.peer` call; line4923 emits that interval. Defining fixture `managed_h2_fixed_endpoint_test.exs` lines43-47 waits for `prepared` with25000ms, then for `ready` with the original5000ms default (`@timeout`, line6; event default, line134). A combined setup above25000ms can still satisfy both original waits and the original total test deadline. The audit introduces a tighter requirement than the source contract and can reject valid evidence.

Remove this unsupported aggregate upper cap; retain a nonnegative integer observation check and the unchanged source assertions. Do not change the runtime deadlines or invent another aggregate cap. The metric covers both waits.

## Complete-review coverage

The remaining reviewed contract aligns with candidate2 at the static schema level:

- Explicit safe bounded inputs, duplicate/nonfinite rejection, pinned candidate2/test identity and separate source attestations.
- Eight contexts/200 ordered events; complete ten-field plateau; all20 measured vectors3..22 equal the actual cycle2 vector with no field dropping or normalization.
- Persistent SUT identities;23 generation inventories/46 transports per context; seed[0,1], held[0,1,0]; health stream1, seed stream3, heldA/B stream5 and finalA stream7.
- Original typed opaque completions and separate retirement kind; resource/group/child/connection/completion links; actual physical close and retirement accounting.
- Active rollback3 original T/G tokens, idle0; NEW readiness before held dispatch, rollback before CAS. Capacity original paired2000ms holds, resources4/reserved8, NEW-only Store/group and exact no-delta transport ledger.
- Actual final_zero complete T/G/service/gate schema; empty records/pins/tokens/probes and independent byte sums. Both live owners intentionally retain their original instance monitor correlated with the setup SUT tuple.
- Epoch8/8/7 peer counts, exact request budgets, actual nonforced joined command/descendants/peers and preserved decoded raw wait statuses, including signal statuses.
- Aggregate184 generations/368 transports/368 HEAD/368 seedGET/264 heldGET/632 GET/1000 requests/176 replacement CAS/368 retirements and physical closes/48 peer joins.
- Original completion awaits, normal monitor waits, processed cancellation, ETF measurements and absence of unexpected effects remain source attestations. This review adds no equivalent replacement proof for the dismissed upstream request.

## Input identities and evidence limits

E6 prefix: `docs/acceptance/evidence/m3/managed-h2-group-reload-plateau/1792240357368527898`.

| Input | SHA256 |
| --- | --- |
| runtime-audit-proposal2.py.txt | 0272af8cd50906284adeec33e381408b3c6f61f5933309372d86ef3800faec4e |
| runtime-audit-proposal2.json | c19356c86e27ff52db4e5103734f52e2eaf7678ff55f0a1b0bc7f6d6248dab03 |
| runtime-audit-proposal2.md | c19f19d8740bf0ba6d3f898310aa44d0d07d5b769216ff28a31ce9d785ce65a3 |
| source-candidate2.json | 75e790fdb8fee8b17279a807cb8a826a2ad1596b0f1b7fc9250287347b85a19f |
| managed_h2_group_generation_test.exs | 144ff05c2de10f600c9776565711f1072e08e8487b914c5c42250118230ff535 |
| managed_h2_fixed_endpoint_test.exs | e89adb9c7cefa1c64385e9a90962ece819d7dfb492807b42e7b77644f042c33a |
| command-collector1.py | b648c6d47a8f80515db1c2150101577ad16e8c27ff2780f361f449d8e76f1af0 |

All listed pins were freshly checked. Parent's syntax receipt records exit0/PASS_SYNTAX_ONLY and runtime NOT RUN. Reviewer executed0 tests; no proposal/runtime/build/browser execution, repository write, source edit, Git mutation, broad inventory, forbidden artifact read or process launch occurred. Only the two assigned `/tmp` reports were written. All own commands completed without errors or output truncation.

Received counter13: root262/orchestration171/groupTool17; SOURCE failed SPEC1/local Sol fixture repair1/runtime0; Astra2/2 exhausted. Reviewer added0 tooling errors and0 repair rounds; parent owns any audit-tool review/repair counter update. No user product decision is needed. Preserve this immutable FAIL and frozen proposal2, repair only the audit, then obtain fresh independent review before qualification or execution.
