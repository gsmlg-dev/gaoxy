# Group reload complete TEST SOURCE SPEC review

FAIL — F1 active health readiness conflict; F2 missing final zero evidence ledger. Review DONE; direct assignment. No runtime executed.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; HEAD `e4a7660baa61a792f4245f511b190a0fcfcbf920`. Candidate SHA `3135c166ed5946c23be1f340b6d130ad7e00740f857f7d4e12cd19a0da0baca1`; test SHA `923e1661767ed9bb22932438e564c805671c53161ce9dcb240f1d9d99ea09d3e` (181309 bytes,4955 lines). All409union pins,402actual-command pins and3document pins freshly match. All appended lines3178–4955 read, plus relevant reused helpers/public source. Baseline diff matches exactly3compiled-metadata changes plus appended1777lines.

## Actionable finding F1

High severity. `reload_cycle/6` line3598 dispatches three genuine OLD requests before line3605 calls `reload_candidate/3`; that calls unchanged `healthy/3` at3449. Its final predicate1534 requires OWNER-wide `request_tokens:0/helpers:0`. OLD3 remain pending until after NEW health/CAS, so they keep three actual transport tokens and make NEW readiness impossible. All four active cells are affected from replacement1. This is a source-derived control-flow contradiction; no runtime FAIL is claimed.

Parent confirmed F1 and selected the smallest repair: prepare/healthy NEW before dispatching OLD[0,1,0], retain original helper assertions, then keep OLD3 pending through preCAS rollback/CAS. Idle still proves old idle before NEW preparation. Update/rebind the written active order and source pins; no counts/caps/clocks/assertion changes. Reviewer made no edits.

## Complete bounded checks

**S01 — PASS.** Exact candidate3135c166/test923e1661 hashes, test181309bytes/4955lines, all409 union pins and all402 actual-command-with-enum pins match current disk. Three written document hashes match candidate. HEAD freshly e4a7660baa61a792f4245f511b190a0fcfcbf920.

**S02 — PASS.** Compared HEAD baseline with current test via exact line opcodes: only sender/receiver/result compiled metadata and appended3178..4954 changed. All full appended lines3178..4955 read in six contiguous bounded slices. No production/shared fixture/dependency changes.

**S03 — PASS.** Eight generated protocol x downstream x active/idle tests retain same environment, two owner epochs, Store, listener address, gate/service/embedding identity. Initial0 plus22replacement CAS; warmup2 defines firststeady; exact20 vectors3..22 asserted twice; final23G/46distinctT counts derived from actual ledgers.

**S04 — PASS.** Six manual peers .1/.2/.3 per lane on fixed distinct PA/PB; actual bind tuple and per-lane port assertions; one six-public-CA ordered immutable copied DER union plus distinct real leaf identities. Full source/policy/manifest/trust classes validated before Gaoxy/resources and per candidate; no cross-lane equality requirement/padding/normalization.

**S05 — FAIL.** F1: active dispatch-before-NEW-health conflicts with inherited healthy owner-wide token-zero assertion. All four active profiles cannot reach their intended CAS under this source candidate. Remaining schedule semantics are reviewed structurally only.

**S06 — PASS_STRUCTURE_ONLY.** Real seedGET[0,1] and activeOLDGET[0,1,0] use fixed-width targets, current health connection mapping, matching upload_end0, original G/T source batches, derived child/tokens/completion and native accounting. LastA source retains unselectedB; all source/token/completion/effect assertions retained. Counts46HEAD/active112GET/idle46GET and epoch8/8/7 budgets match selected schedule.

**S07 — PASS_STRUCTURE_ONLY.** Cycle3 preCAS rollback uses actual fresh.compiled and public prepare with caller self at Gmax2; observer correlates actual pin_many input, {:ok,pin} result, actual cancellation input and processed no-pin state. Exact T/G maps/bytes/monitor sets and Store state compared, with no peer effects and final positive exact totals.

**S08 — PASS_STRUCTURE_ONLY.** Generation2 installs both original custodian hold hooks before retirement; cycle3 waits both original IDs/refs/start times. Actual old2+new2 records4/pins2/reserved8/tokens0/helpers0, old charged/unconfirmed/notdown/closed proved. Fifth valid public T prepare exact refusal and full T/G/Store no-delta; both original continues unconditional in after; independent transaction and through-continue clocks<2000 retained.

**S09 — PASS_STRUCTURE_ONLY.** Per-T resource/custodian correlation avoids creator ordering assumptions. Actual retire_result receipt public await, helper original slot/monitor DOWNnormal, owner helper start/finish/capability confirmation and original charged record required; no-removal-before-confirmation guard retained. Physical close matched health/seed connection. join_resource solely consumes each original creator monitor; actual G key/pin/token/probe absence proved separately.

**S10 — PASS_STRUCTURE_ONLY.** NativeH2 original worker-death bounded polling precedes unchanged close_calls monitor joins/socket closure. Capacity continues/T receipt joins precede final active native wait. Final Store original monitor remains for finish; final T2/G retire first, exact zero maps/bytes/service/gate then persistent owner/instance/embedding normal joins and listener rebind. Peer epochs join after all8/8/7 physical closes, exact counts/forced0/live0/failedfalse/exit0/normalcollector and exact-IP/port rebind.

**S11 — PASS_STRUCTURE_ONLY.** Vector retains full scalar T status/limits, independent original payload/pin/token bytes and public idle snapshots; G config reserves/current full record bytes/control/probe independent sums/member full bytes/config/health/inflight/cursor; full Store router/baseline/list-record sizes/counts; complete source classes and ordered pair; service/gate byte/count zeros. No sampled planned byte is hashed or dropped. Existing supported opaque completion projection used only in G accounting.

**S12 — PASS_STRUCTURE_ONLY.** Before peers/resources, reload_inventory_fields freezes plateau/dynamic identity/time/counter families. Actual original identities, preparation/group pin deadlines, health checked/due/schedulinglag, highwater/rejected/effect counters are inventoried separately; absolute values retained inside full original serialized-byte calculations. Opaque receipts/completions correlated by original=== without traversing interiors.

**S13 — PASS_STRUCTURE_ONLY.** First frozen argv loads defining F and complete unfiltered group Generation suites with warnings-as-errors/max-cases1, no only/tag filter or timeout overrides. Existing60s/120s/180s/15s/5s/2s limits intact. Tool-adoption PASS_TOOL_SOURCE_ONLY receipt matches candidate73a2802b; no tool/runtime acceptance inferred. Actual timing/live byte equality remain unqualified.

## Evidence limits and tooling

No tests/build/syntax/browser/runtime, repository/evidence/source writes, Git mutation, broad status/directory inventory or prohibited E4/prompt/privatekey/rawNetLog access. Parent parsed/formatted exit0 is not test/runtime acceptance. Only assigned /tmp reports written. All commands finished; no running commands. One own report-only Python path-guard AssertionError exit1 omitted seven legitimate frozen E5 operands; no out-of-guard file was read before failure. Exact rejected names inspected, guard corrected,409/402audits passed. No output truncations or restriction deviations.

Received counters root255/orchestration165/tool93/group11/kickofffailedSPEC1. Added two source review findings and one report tooling error; no product/runtime failure or Sol edit/validation repair round. Astra2/2 exhausted unchanged. No missing product decision; parent owns authorized local Sol repair and renewed review.

## Actionable finding F2

Medium severity; evidence-ledger omission, not missing cleanup behavior. At3286 the result of `reload_zero/2` is discarded. That helper4454 asserts T status/maps/owned bytes0, G maps/config/control/probe bytes0 and service/gate zero, but returns only the service/gate result. Finished output3291 records totals/retirements/epochjoins/timing without original final T/G/service/gate numeric zero observations. Earlier measured vectors are currentG1/T2 and cannot serve as the final-zero inventory. Written complete original byte/count custody and final cleanup evidence require this bounded ledger. Return actual observed T/G/service/gate zero counts/independent sums, bind and emit in finished; preserve all assertions, actor joins and teardown order. No hardcoded replacement observations. Parent requested assessment after peer-accounting noted the omission; no runtime failure inferred.
