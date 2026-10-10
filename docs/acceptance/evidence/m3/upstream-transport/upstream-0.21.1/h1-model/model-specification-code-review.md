# M3 H1 model independent specification, code and evidence review

Task `m3_h1_model_review`, direct independent sequential Sol assignment. **DONE: specification PASS, then code-quality PASS, then saved-execution evidence PASS**, for the source-independent pure Slice A model only. No actionable finding remains. Fresh post-review verification and local delivery are parent-owned pending gates; this report does not complete them.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, baseline `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`. Branch/HEAD are supplied by the parent; this reviewer independently checked the path and ran no Git command. The two executable additions and untracked plans/evidence were pre-existing at review and preserved. Only this report and its JSON companion are owned. Continuing authorization in `AGENTS.md` applies; no routine approval wait is added.

## Specification review — PASS

The current plan, approved frontier memo, initial independent plan review including its A1 correction, and frontier review were inspected before code-quality judgment. The current plan explicitly states the sticky late-confirmation exception. This review accepts that narrow premise: `:applied` does not certify confirmed cleanup, successful outcome, or refund. Keeping uncertainty without a second historical marker respects the fixed no-history grammar. The initial A1 plan repair remains separately recorded and is implemented by outcome-based deadline expiry.

## Code quality and semantic review — PASS

All transition branches, owner lookup/update paths, release predicates, validators, snapshots and test helpers were read. Helpers use public model events rather than patching state. The table below records the substantive checks; the verdict is not inferred from green test count alone.

| Area | Independent assessment |
| --- | --- |
| admission | PASS: Four generation slots and 32 attempt slots per generation allocate before root capture; valid full-capacity rejection returns busy with identical state. Closed generation admission rejects both acquire and first launch. |
| identity | PASS: Fresh references issued only on allocation; exact current owner/root/chunk/control equality rejects old events after same-slot or same-role reuse. No historical token set or epoch is stored. |
| streams | PASS: One chunk per direction; release preserves identity until matching ACK. Held ACK and overlapping offer fail. Consumer/source/terminal/parser roots remain separate. Finish is one-shot and successful data result requires response finish. |
| controls | PASS: Each fixed operation issues once and repeats join token/cached result. Reply, helper release, and frontier release are independent. Pending result or either missing flag retains ownership; cleanup_pending cannot substitute for confirmed completion. |
| deadlines | PASS: Advance independently examines every pending opening, retirement, and request outcome through cleanup_hold. Both deadline orders and equality are tested; late known failure preserves opening timeout and retirement state. Late open/retirement/cleanup does not overwrite a timed-out result or reopen admission. |
| uncertainty | PASS: Owner DOWN, explicit unconfirmed, and cleanup_unconfirmed retain sticky lost proof. Later modeled public confirmation does not clear that flag or permit release. Confirmed request marker repeats duplicate; unconfirmed marker receives applied with unchanged state, including repeats, without added history. |
| release | PASS: Lost proof precedes ownership_pending, then missing terminal/public evidence. Attempt release cannot refund generation. Generation release requires no attempts/roots/outstanding controls and retired or known-not-opened evidence without a successful open. |
| bounded_shape | PASS: Fixed tuples/maps/enums and bounded time domain; no payload, I/O, HTTP, process, callback, historical nonce, event log, cumulative counter, numeric byte budget, or activation API. Snapshot keys are exact and qualification always unqualified. Ceilings derive as 4*5+4*32*8=1044 roots, 4*32*2=256 chunks, 4*3+4*32*2=268 controls. |

## Test strength and saved receipts — PASS

All22 named tests match the22 required plan rows. Separate recursive permutation loops execute all24 request-release orders and all24 generation-release orders. Every incomplete prefix is rejected with unchanged state; final release requires all four premises. The recursion removes one distinct premise at each level, so each loop visits exactly4!=24 orders without duplication.

The turnover test executes2048 complete modeled cycles beside a held sibling. Every accepted helper step checks invariants before/after; rejected and stale/duplicate helpers pin the entire original state. Every128 cycles, the test checks exact record keys, fixed tuple/map sizes, scalar domains, unchanged recursive node count, absence of recent released attempt/root/chunk/control tokens, and continued presence of the sibling. It then fills31 other slots and verifies busy, proving the sibling stayed charged. `Map.to_list` fixes struct traversal while retaining all those assertions.

Coverage is behavioral rather than exhaustive reachability checking. In particular, repeated late confirmation on sticky-unconfirmed completion is established directly by the identical-state branch in current code; the suite exercises its first late premise but has no dedicated repeated identical-state assertion for that branch. This is a coverage limit, not an observed violation of the specified rule. Finite turnover cannot establish a real upstream P5 induction.

| Receipt | Actual result | Assessment |
| --- | --- |
| `model-red.json` | 22 executed,22 failures; skips/exclusions0; exit1 | Expected behavioral RED: all22 missing `new/1` API failures, not syntax/environment/zero-test success. |
| `model-format.json` | Scoped canonical format, exit0 | Formatting only; both source changes are recorded, no behavior claim. |
| `model-green-initial.json` | 22 executed,2 failures; skips/exclusions0; exit1 | Actual initial implementation failure retained. Struct Enumerable failure and late-confirmation receipt mismatch are visible in raw log. |
| `model-green-repair1.json` | Scoped format check followed by actual22/0; skips/exclusions0; exit0 | Successful repair1. `set -e` preserves formatter failure; explicit ExUnit runner rejects missing/zero/excluded/skipped tests. |

The reviewer independently parsed all raw ExUnit summaries, validated every recorded log SHA-256, compared the two input source-before/source-after maps for all three behavioral runs, verified the collector identity, and matched repair1 freezes to the current two executable files. No run timed out. The collector waits for its child process and records completion; no peer processes are recorded in these receipts. The reviewer did not launch a VM, runner, formatter, dependency command or network request. The exact original-to-repair textual deltas are parent-supplied; initial failure traces and repaired source were independently read, while prior source receipts archive hashes rather than prior source bytes.

## Identity bindings

| Reviewed input | SHA-256 |
| --- | --- |
| `AGENTS.md` | `c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed` |
| `docs/plans/m3-h1-qualification-model.md` | `cb3e10f0e62dc360d50b84a2bb85ff348fbd1a9c1d06b421c1f73a43e69bd171` |
| `docs/plans/m3-h1-qualification-model-review.md` | `bf38aa4889f1c146a262ee7859571477f622c5014d25d81d0c74e6cb7674620b` |
| `docs/designs/m3-upstream-0.21.1-accounting-frontier.md` | `c01608f23972df371f1664e6a9a40b8598a6e28a129f16f78d23bc3444c00184` |
| `docs/designs/m3-upstream-0.21.1-accounting-frontier-review.md` | `b04852b8ba570e18a26219b6fc1773cdcb56b361b75b7ce1a224016d72ae9497` |
| `integration/http_fetch_contract/managed_h1_lease_model.exs` | `0fd4f9fe81dc605ad6265635ddbfce1f4855245df05c73d0bcbe2cc03541dd6d` |
| `integration/http_fetch_contract/managed_h1_lease_model_test.exs` | `4399f426e993f8e87f8628b3b80c9aae97028c6d31419700b316f04f96d77b1f` |
| `.audit/m3-h1-model-collector.py` | `903388780db0a04d1763513ac92cc7001dea3a71cfdd2c259e7d5a374cd841e1` |

| Saved receipt | SHA-256 |
| --- | --- |
| `model-red.json` | `652a368cb4dce8da41cc625c412c2c45690aa228e063a9ca23425b0c5f525df1` |
| `model-format.json` | `ca8af8167d54243fa5e1701a0069967fa8d2138395689cb1cb756e9557dcaf64` |
| `model-green-initial.json` | `feac1549c8df7bd52b3c0bedb4b2fc7f25ab0e28d12a12102ca17929f05b0998` |
| `model-green-repair1.json` | `6a9bf5a0d6af6b7b4e02102c0e1ce37f562ffae5375842d587fc9f1eb6822ea1` |

The JSON companion binds receipt/log/source-freeze hashes, commands, environments, parsed summaries and detailed semantic assessments. Both repaired executable hashes are unchanged at review.

## Counters, limits and ownership release

Initial plan finding A1: repair1 resolved, unsuccessful0. Model: initial implementation failure1, cumulative Sol repair1 successful, unsuccessful repairs0. Expected TDD RED consumes no repair round. Reviewer repair rounds0; Astra recovery rounds0; `astra_gate: none`. The sticky confirmation premise is a distinct accepted modeled observation with unchanged uncertain state, not successful cleanup or refund.

All application/native/accounting P0–P6, real fixture, numerical reservation, production conformance/activation, TLS/H2/soaks and M3 completion remain UNQUALIFIED. This pure model imports no HTTP package and qualifies neither historical0.21.1 nor prospective0.21.2 behavior. Real control-frontier release, backing ownership, producers, build identities and byte terms still need their separate ledger/fixture evidence. No new product decision is needed.

Parent must next freeze these reviewed inputs, run fresh scoped formatter check and the actual22-test runner, confirm unchanged hashes, independently review receipts, complete the owned checklist and locally commit the reviewed delivery. No push/publication/deployment or production milestone follows. The current uncompleted checklist and planning-assignment historical text are not a fresh delivery receipt.

Own commands: `pwd`, `rg`, `cat`, `sed`, `wc`, and read-only Python SHA-256/JSON/static checks, followed by creation/validation of only these two reports. An `rg --files` search found no nested `AGENTS.md` under docs/integration and returned normal no-match exit1; no check was misreported. All commands finished synchronously, no background process or child agent was launched, and no executable/plan/status/dependency file was edited. Ownership of these two reports is now released to the parent.
