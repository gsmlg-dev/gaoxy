# Source repair2 CODE2 — fixture correction and rebind

Task `gaoxy-group-generation-source-repair2-code2`: **DONE — PASS bounded fixture correction/rebind only.** No actionable findings. Direct read-only review after SPEC3 PASS; no full-stage or runtime acceptance.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; parent-confirmed unchanged baseline `8131af39a846c292a022ccbfd32c53376cd57887`. Proposal3 SHA `f3a43673aefdd9efc3093b5cabc2f05944e2bd3652b770fac91053019aef2c57`.

## Minimal correction

Full current test equals immutable reviewed version2 with exactly one substitution: state.startups == %{} to state.starting == nil at649. No other test/helper/assertion text changed. Production HTTP remainsdd04efd4...11c31, with existing prepare_group_source and prior error-accounting normalization unchanged.

## Actual connection state lifecycle

Connection init50/53 creates streams:%{} and starting:nil. Stream construction501-508 stores startup per stream. start_next539-575 accepts scalar nil, then stores startup in streams[id] and sets starting:id. Successful dispatch1222-1225 clears scalar and per-stream startup. discard1375-1376 deletes stream and clears matching scalar; DOWN path1083-1089 does the same before reset/start_next. No startups map exists. Direct starting==nil is the correct required-key predicate, without default/optional fallback.

## Original wait and hard contracts retained

The enclosing actual-native disappearance wait643, streams==%{}649 and original Gate lease absence650-653 remain unchanged. All target110 equality/logical<backing<=65536, raw header witness/exact peer forwarding, same connection/Writer, genuine G7/T8, native95 P/N/W/B, real original completion, normal joins/allzero/rebind/deadlines/caps are byte-identical to version2. No production constructor/schema/cap/dependency change.

## RED1 remains invalid

Actual receipt is93 tests/2 failures/exit2, stable exact pre-repair HTTP76ec...98 and old testc9ec...ad0b, skipped0/excluded0/warnings[], process joined/nonforced/no wait error/no signal/residue/exhaustion. Log digest matches receipt; both failures are KeyError :startups at test649 before stream3. Collector INTENDED_RED_REQUIRES_ASSERTION_AUDIT is not accepted RED: classification remains FAIL_INVALID_REGRESSION. Restoration receipt/current HTTP prove exact candidate restored. My CODE1 missed this fixture-key error; its regression-suitability claim for that wait is superseded by actual RED1 evidence and this correction. Prior report remains immutable.

## Rebind and future gates

All28 declared proposal3 inputs plus proposal hash and SPEC3 pair match on final recheck:31 frozen identities/no drift. Original failed reports/snapshots/RED1 are unchanged. Bounded SPEC3->CODE2 now source-reviewed only. New stable-source expectedRED2 must demonstrate relevant boundary failure, audit actual assertions and finally restore exact reviewed HTTP/test identities; fresh unfiltered93 initial4, four browser rows/eight viewed images, full-stage SPEC->CODE and all final gates remain pending/NOT RUN by reviewer.

## Verification, ownership and counters

All read/hash/diff commands exited0;31 frozen inputs unchanged before/after, supplementary RED1 log hash matches receipt. Tests executed0. No runtime/test/build/browser/Git/network/agents/repository writes; only assigned /tmp reports written. All own commands completed synchronously, no session/background child.

Cumulative counters preserved from frozenproposal3: group51/root105/orchestration35; stagefailed6/production2/fixture9/stageorchestration28/invalidRED1; Astra2/2 exhausted. Own repair rounds0; no reset/escalation. No new decision required. Root owns RED2 assertion audit/exact restoration, fresh93 initial4/browser4x2 and full-stage review/final gates. Historical diagnostic1 field/predicate and green2 cause remain UNKNOWN.
