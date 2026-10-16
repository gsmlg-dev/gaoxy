# Checked native Generation runtime design readiness1

**DONE — FAIL_NEEDS_REVISION for design1/plan1.** Two concrete source/ordering findings must be corrected before Admission activation. They are design-readiness findings, not runtime failedGREEN events, a user approval stop or an Astra recovery request. Do not overwrite the reviewed design1 artifacts.

R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`. The design author baseline48a71a70 is superseded for implementation by verified pure predecessor94d47d11fbd9040bd49e15829e8405d82fd0618d. I independently rehashed all77 exact commit blobs against actual-feature custody (zero mismatches). The9 selected production identities match current source and predecessor commit.

## Findings

### F1 — high — Runtime cancel_control64 omits the supported T post-check cancellation followed by checked Store rollback of the same current operation.

Location: `/tmp/gaoxy-native-generation-checked-capture-design1.md:107`.

T.pin_many/5 receives genuine {:ok,pin}, then on expired deadline/dead holder calls cancel(owner,operation) at124 before returning pending. The design requires Store to cancel every started original ledger entry after this error. With k prior/current started batches the public T path sends one additional cancel plus k Store rollback controls, all potentially outstanding: k+1<=65. No arbitrary callback failure or fabricated receipt is involved.

**Required revision:** New runtime profile must pay65 full cancellation control roots, or explicitly change a supported checked public protocol that proves fewer sends without altering legacy semantics. Recommended minimum: retain existing public T behavior and pay65; cap4124 implies subtotal268060 instead of263936, delta4124 before other runtime-profile changes. Keep old worksheet64 and literal assertions as historical conditional arithmetic, explicitly never qualified for current runtime. Add deterministic genuine T post-check-failure plus checked Store rollback coverage; duplicate operation identity is idempotence, not proof the second message costs zero.

**Closure criterion:** Revision2 names65 current runtime controls, retains all original operation/authority correlation, and puts exact source-bound numeric rederivation plus this source path into the same-stage pre-Admission gate.

### F2 — medium — The plan lacks an explicit independently passed actual-constructor gate before Task4 first charges Admission.

Location: `/tmp/gaoxy-native-generation-checked-capture-plan1.md:66`.

Task1 GREEN is called an internal checkpoint and automatically proceeds. Task3 subsequently implements actual Resources/Store wrappers and ledger. Task4 activates the real charge. Independent frozen source/evidence SPEC/CODE review appears only in Task6, after activation tests. Design84/88 requires independent profile/source binding before charging but does not assign a hard ordered gate over the actual Task1–3 constructor sources. Handwritten arithmetic expectations alone cannot bind future implementation wrappers.

**Required revision:** In this SAME runtime stage, after compact numeric and actual checked acquisition/public API constructor code exists, freeze the relevant candidate, compute concrete M65536/default and boundary numeric totals/subtotals, bind every actual wrapper/finite error/control/timeout, obtain independent constructor SPEC/CODE review and passing nonzero scoped evidence, then allow Task4 to use B in Admission. Unactivated code/test preparations may proceed by dependency. Preserve final whole-stage native/C5/consumer SPEC/CODE/fresh verification as separate acceptance checks. This is neither a third pure worksheet stage nor a human approval stop.

**Closure criterion:** Revision2 makes Task4 Admission activation depend on explicit constructor gate PASS, including F1 control65 and any actual new wrappers (for example {:ok,plan} or internal numeric success tuples if implemented).

## Remaining design review

The selected design is otherwise precise enough for test-first implementation: optional HTTP-owned behavior preserves core isolation; explicit opt-in has no legacy fallback; complete original provenance is created before provider effects; exact request/epoch/handle/order/operation/T-holder correlation is required; actual operand preflight precedes capture cons/append. Unknown selected providers fail before invocation.

The compact reservation stays numeric-only and returns the exact five-tuple; no worksheet roles/report map enter the pre-Admission path. Actual M remains any positive integer and default1048576; new source constructors require numeric rederivation without changing historical worksheet meaning. The new constructor gate must account actual wrappers even if they were not fully enumerable before implementation.

Additive Admission.update/4 and public G/T.release/2 are necessary same-repository compatibility APIs. Old arities/guards/defaults remain. One Dc=D+1000 bounds all synchronous cleanup dispatch/waits; signed64 absolute/relative premises are explicit. Route bytes stay charged through ordinary request teardown. Narrow Router catch plus total cleanup preserves exact original result/class/value/stack and avoids duplicate release. Only requester emits one bounded empty-scope cleanup event, and observer failure cannot mask primary.

Actual public G/T constructors, genuine G-H1 >Q receipt/cancellation and native H1/downstream-H2 captures are required stage endpoints. Test doubles may prove malformed inputs/exception precedence but cannot replace those receipts. Readiness does not require future runtime results now. Keep upstream-H2 Generation exclusion, native-worker transfer deferral, fixed reservations, legacy tests and real core/HTTP-only consumers.

## Dependency decision

Proceed autonomously with source rebind, independent RED proposals, numeric/public API and unactivated acquisition preparation while revision2 closes the exact findings. Do not use the proposed runtime B in Admission until the same-stage actual-constructor independent gate passes. Then execute Task4 and subsequent native/C5/consumer acceptance through final independent SPEC/CODE/fresh verification/local conventional commit. No third toy pure stage or routine human approval is needed.

## Exact custody

* `/tmp/gaoxy-native-generation-checked-capture-design1.md` SHA256 `a4fafb8a60728a9c503cf28888056e2b12b7458c2b3ca4dd2d06529cea0d36ac`
* `/tmp/gaoxy-native-generation-checked-capture-plan1.md` SHA256 `065b93ac7b00e72d898d1c6821629b97bd445238f4086c534f759e254d702d94`
* `/tmp/gaoxy-native-generation-checked-capture-decision1.json` SHA256 `84d588e22a62970e1505d90a5eb6a1bcbdc19405381b7cfe3b993af84d3d9bd5`

Actual predecessor receipt SHA256 `68fa6dda78ea55fbe113cb11b2bd50cc497c5a8c3d85816b74e13da87bdc5f90`. JSON records all read production/fixture/script hashes and predecessor review/fresh-gate receipt hashes. Full source-role runtime B remains NOT_RUN/UNQUALIFIED at this review. Old worksheet24/0 math is not relabeled runtime acceptance or failure.

All own read-only commands completed; no runtime/mix/Nix/test/build/formatter/Git mutation/network/background command was launched. No repository changes. Only assigned readiness1 MD/JSON written; others’ edits preserved. Reviewer repairs0; worksheet failedGREEN1/test-contract repair1/production repairs0, inherited group24/root27 and Astra2/2 remain unchanged. No product decision, external permission or Astra gate.
