# M3 no-launch timeout repair independent review

Task `m3_h1_no_launch_independent_review`: **SPEC FAIL**. **CODE QUALITY NOT RUN** because the specification gate failed. One actionable P1 finding remains. This is a completed independent review, not model acceptance or M3 completion.

Direct review of `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway` (worktree HEAD read directly), parent-supplied baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`. No Git, VM, Mix, formatter, network, peer or dependency execution. The only written files are this report and its JSON companion.

**SPEC-01 (P1): preserve the valid held state after owner death follows accepted no-launch evidence.** The new `valid_completion?/1` clause at `integration/http_fetch_contract/managed_h1_lease_model.exs:930` admits timed-out `not_launched` only in `releasing` with no lost proof. Existing `owner_down` at line416 is defined for any live attempt, preserves the terminal completion/outcome, and sets `lost_proof=true, phase=cleanup_hold`. The event contract at `docs/plans/m3-h1-qualification-model.md:188` explicitly retains existing timeout/result and forbids implicit release.

Reachable source trace, with a ready generation and an unlaunched reserved or preparing attempt whose source/helper roots remain held:

1. Advance to original D=10: `timed_out/cleanup_hold/none`, no lost proof.
2. Explicit `reject_attempt`: `timed_out/releasing/not_launched`; no roots, chunks or controls released.
3. `owner_down`: `timed_out/cleanup_hold/not_launched`, sticky lost proof true; all owned fields retained.
4. `Model.invariants/1` rejects this state with `{:error, :invalid_event}` by static predicate evaluation. The lost-proof phase clause at line907 accepts cleanup_hold, but completion validation at lines930–936 excludes it. `valid_attempt?/4` requires both.

Duplicate rejection remains inert and the existing release guard still rejects lost proof, so this finding does not demonstrate a refund bypass. It demonstrates that a lawful existing event on the new terminal state violates the fixture's invariant; every test helper checks invariants before/after events. The original `rejected/not_launched` completion permitted owner death, making this inconsistency specific to the new timed-out branch. The added four negative cases at test line207 cover loss before rejection, leaving this ordering untested.

Required targeted repair: let accepted no-launch evidence remain sticky when later owner death creates the cleanup hold, while keeping the new rejection admission guards and all normal release/expiry/nonce/control predicates unchanged. Extend the existing named test for both reserved and preparing attempts with expiry -> explicit rejection -> owner_down. Assert invariant success, retained timed_out outcome/original deadline/not_launched completion, lost proof/cleanup_hold, unchanged roots/chunks/controls and slot charge. Assert duplicate owner_down/rejection inert; matched root release remains lawful; even after every root clears, release returns lost_proof without refund. Parent should retain a deterministic RED before repair and GREEN after repair, with exact22 tests and scoped formatting. No weaker assertions or broader admission are needed.

Other reviewed contract checks: the first acceptance branch requires never launched, timed_out/cleanup_hold, no lost proof and every control unused; it changes only completion/phase. Positive tests compare the full attempt and accounting snapshot, keep the original deadline, require matched root releases and check same-slot/fresh-nonce stale events. Launched owners with pending controls and uncertain owners are denied. Source diffs leave expiry, release_attempt, owner identity and control/frontier helpers unchanged. The original22 named tests, all original test lines and runner suffix remain unchanged. Repair1 correctly distinguishes owner_down none/failed or none/timed_out from attempt_unconfirmed unconfirmed/timed_out; it does not weaken the original assertions.

Preserved parent evidence, independently read and hashed: deterministic RED22/1/exit1 at the missing timeout branch; initial formatting check exit1; canonical formatter exit0 changing one indentation; initial GREEN22/1/exit1 at an incorrect new owner_down expectation; repair1 GREEN22/0/exit0, skipped0/excluded0, seed21112026, no owned peer after. The repair1 before/after1128-entry manifests are identical, and current model/test hashes match them. The model-plan file is absent from those manifests; its current hash matches the final snapshot and handoff. No claim is made that the entire historical inventory matches today's workspace; unrelated parent documents changed after that run. Runtime for the reported SPEC-01 trace is **NOT RUN** by this reviewer. Final check-formatted and fresh post-review execution remain parent-owned.

Current reviewed source SHA256:

| Input | SHA256 |
| --- | --- |
| `integration/http_fetch_contract/managed_h1_lease_model.exs` | `09fcf257386b3d1fde541058f69fb8842b66f3ff36990f924e44c18589296435` |
| `integration/http_fetch_contract/managed_h1_lease_model_test.exs` | `fcab79c63fc8c4f69f07aa6a727a7226bdb603ba69e0c2bc8ccb9edfe48acfd4` |
| `docs/plans/m3-h1-qualification-model.md` | `a5c1a309d6331fe99813bf9ad3af53473027e5928bc5b3386e93e6b1745afca9` |

Exact current receipt and contract hashes are recorded in `h1-no-launch-independent-review.json`; the passing test log hash is `8ab3fec177f66fc73ae39b985f61f7cc079c0d32eda3ab949772f4f242afe68b`.

Model counters received: Sol1 / unsuccessful0 / Astra0 / receivedAstra0; reviewer performed no repair. Separate retained TLS chain remains Sol2 / unsuccessful2 / Astra2, EXHAUSTED/BLOCKED and untouched. H1 numerical accounting still depends on upstream Feature97; activation remains disabled. These model-only findings do not close byte qualification, Slice B runtime, TLS or M3 acceptance.

All own static commands finished synchronously, no background job was started, implementation/source hashes remain unchanged, and review-artifact ownership is released. No new product decision is needed; parent assigns bounded repair2 and the subsequent specification/code-quality reviews.
