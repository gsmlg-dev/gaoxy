# Repair2 no-launch timeout independent review

Task `m3_h1_no_launch_repair2_independent_review`: **SPEC PASS**, followed by **CODE QUALITY PASS**. No actionable findings remain for the reviewed model repair. **SPEC-01 is resolved**. This accepts the bounded B13 model prerequisite; Slice B runtime, numerical qualification, TLS and M3 acceptance remain separate.

Direct rereview in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, parent-supplied baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`. No implementation edits or Git/VM/Mix/formatter/network/dependency execution. The original FAIL review reports remain unchanged and are bound by their hashes in the JSON companion.

Specification review: `valid_completion?/1` at model line930 now accepts only an unlaunched timed-out owner with accepted not_launched evidence and every control unused, in either releasing/no lost proof or cleanup_hold/lost proof. The second state is exactly the result of existing owner_down after accepted rejection. Safe rejection admission at line359 remains unchanged; lost-proof release refusal at line573 remains first; expiry, owner identity, control/native frontier and nonce helpers are unchanged. Duplicate rejection never clears uncertainty or owned fields. The existing owner_down contract already requires retention of terminal outcome/evidence, so the model-plan event row needs no repair2 change.

The regression at test lines150–165 covers both reserved and preparing attempts: original-deadline expiry -> explicit rejection -> owner_down. It asserts full held attempt equality, invariant success, accounting equality, sticky completion/outcome/deadline, inert duplicate owner_down/rejection, lawful matched root release and refusal to refund even after every root clears. The original positive release/reuse trace follows from the independent immutable state branch and remains intact. Prior negative launched/issued-control/lost-proof traces and fresh-nonce stale-event assertions remain. Static diff confirms zero original test lines removed, exact22 original test names, unchanged helpers and runner suffix.

Code-quality review ran after SPEC PASS. Repair2 changes only the existing completion predicate and adds18 test lines. The explicit phase/lost-proof pair matches the existing state transition without introducing an API, dependency, abstraction or process. Full-state assertions and the reproduced failure establish the missing ordering rather than merely mirroring a condition. The whole repair remains confined to the existing rejection transition, two validators, one named test and one event-contract row. No assertion was weakened, test skipped or unrelated implementation changed.

Preserved parent receipts were read and independently hashed: repair2 RED22/1/exit1 fails precisely at post-owner_down Model.invariants with invalid_event; canonical formatting exit0 and changed_files empty; GREEN22/0/exit0, skipped0/excluded0, seed21112026, no owned peers afterward. The GREEN/format1129-entry before/after inventories are identical and include all three reviewed sources. Their hashes match the current selected sources below. The RED1128-entry inventory omits the model-plan file. No current full inventory comparison is claimed: subsequent parent compile/build and unrelated document work may change other files. Reviewer runtime is NOT RUN; these are exact preserved parent execution receipts, with argv/environment/log and manifest hashes in the JSON companion.

| Reviewed source | SHA256 |
| --- | --- |
| `integration/http_fetch_contract/managed_h1_lease_model.exs` | `a9a6b96b275735a0744847805f0723c20c256dbfbcad576a458963228609f865` |
| `integration/http_fetch_contract/managed_h1_lease_model_test.exs` | `50d8aa12cf1b2243e1cc792fc830a942b34de7d69dda47e43a5c72c6c1c89efa` |
| `docs/plans/m3-h1-qualification-model.md` | `a5c1a309d6331fe99813bf9ad3af53473027e5928bc5b3386e93e6b1745afca9` |

GREEN log SHA256: `d0f2b327e8c62f61635778631bf537d39d60a1c43ee169449986b6ff13885f78`. Exact receipt, manifest, previous-review, contract and handoff hashes are recorded in `h1-no-launch-repair2-independent-review.json`.

Effective cumulative model counters: Sol2 / unsuccessful1 / Astra0 / receivedAstra0. The counter audit correctly counts the earlier independent SPEC FAIL despite its passing tests; the agreed repair2 RED is not an unsuccessful repair. Reviewer made no repairs. The separate TLS chain remains Sol2 / unsuccessful2 / Astra2, EXHAUSTED/BLOCKED and untouched. Feature97 still blocks H1 numerical qualification and activation remains disabled.

Fresh parent post-review scoped checks and the separate fixture acceptance gates remain. No product decision or scope expansion is needed for this repair. All reviewer commands finished synchronously, no background job started, reviewed sources and prior FAIL reports remain unchanged, and review-artifact ownership is released.
