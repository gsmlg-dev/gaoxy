# M3 H1 qualification model implementation plan

> For agentic workers: use executing-plans for bounded execution. The parent
> assigns independent Sol specification/code review and serializes every
> formatter, Mix/VM and peer run. Continuing authorization replaces routine
> approval. Do not implement until independent review of this plan passes.

**Goal:** Implement a small immutable lease/ownership model and self-contained
ExUnit contract tests, then specify a separate public-API fixture that can prove
the modeled premises without changing production or the existing24/39 driver.

**Architecture:** A fixture-only state machine with four generation slots,
32 attempt slots per generation, fixed root/stream/control credit records and
fresh local reference tokens. It stores current bounded state only. The first
slice starts no scope/process, performs no I/O and evaluates no byte budget;
later fixture execution and complete P0–P6 qualification are separate gates.

**Tech stack:** Existing Elixir1.18.5/OTP28.5.0.7/ERTS16.4.0.6 and ExUnit.
Slice A is source-independent and imports no HTTP package. The architecture's
historical source context is the seven-package HTTP0.21.1 cohort at tag
`bdf849adf119039ed679d24d5fbb0a321f5e578a`; it is not a binding for a later
qualified cohort. No new dependency.

**Checkout at planning:** `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`,
branch `codex/m3-gateway`, baseline `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
Parent/peer patch work is concurrent; only this new plan is owned by the
planning assignment. Recheck HEAD, diff and ownership at execution; do not
overwrite or stage any concurrent change.

The parent subsequently committed the patch delivery as
`81b01bd3334fe4c90a739e1eebdee8bd29bf94f8` and reported published0.21.2 as
the next qualification candidate. That candidate is not source/API reviewed,
installed, rebound or qualified by this planning assignment. The pure symbolic
model contract does not change with a package patch. Slice B must bind its
actual independently qualified installed source/runtime profile, re-review
affected premises and preserve the0.21.1 ledger as historical evidence.

**Design dependencies:** The approved
[frontier memo](../designs/m3-upstream-0.21.1-accounting-frontier.md), SHA-256
`c01608f23972df371f1664e6a9a40b8598a6e28a129f16f78d23bc3444c00184`, and
[independent specification review](../designs/m3-upstream-0.21.1-accounting-frontier-review.md),
SHA-256 `b04852b8ba570e18a26219b6fc1773cdcb56b361b75b7ce1a224016d72ae9497`.
The [original envelope](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
defines measured roots/exclusions. The parent synchronizes master gate text
in a separate reviewed design/plan delivery after the patch-cohort commit.

## Ownership, dependencies and claim boundaries

Slice A, after independent plan review, owns only new executable files:

- `integration/http_fetch_contract/managed_h1_lease_model.exs`: module
  `Gaoxy.Qualification.ManagedH1LeaseModel`; immutable model only.
- `integration/http_fetch_contract/managed_h1_lease_model_test.exs`: self-contained
  ExUnit tests and explicit runner; loads the model with `Code.require_file/2`.

The parent owns new execution/hash/review receipts in
`docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/h1-model/`,
and checklist updates to this plan. One Sol implementation writer owns both
executable additions; independent reviewers have read-only access to them.
The writer is not alone and must preserve all other changes. No application
module/test, manifest/lock, dependency source, shared status document, existing
probe/helper/peer, HTTP adapter, lifecycle registry or production API is owned.

G4 is an **internal qualification test profile**, within the existing64
participant cap, not a new public default/configuration. Four slots model
simultaneous preparing, ready, retiring and uncertain generations; every one
remains charged. A fifth reservation is immediately rejected. The model assigns
one symbolic reservation unit to every occupied generation, including empty/
failed ones; this checks conservation, not a configured transport-byte gate.

A successful transition or all green tests proves only the finite model's
specified invariants. It does not prove real producer bounds, payload backing,
upstream preparation occupancy, native object sizes, a retained-byte total,
production conformance, Task4 activation or M3 completion. Confirmation/release
events below are **modeled premises** the real fixture/source ledger must later
justify. They are never caller-supplied numerical certificates.

## Slice A: exact local API and bounded grammar

Expose only these fixture-local functions; no callback/evaluator, configuration
tree, payload-taking command, byte value, proof-constant input or activation API:

```elixir
new(now)                         # {:ok, state} | {:error, :invalid_time}
step(state, event)                # {:ok, new_state, receipt}
                                  # | {:error, fixed_reason_atom, unchanged_state}
snapshot(state)                   # fixed scalar summary, qualification: :unqualified
invariants(state)                 # :ok | {:error, fixed_reason_atom}
```

The time domain is integer `0..9_223_372_036_854_775_807`. Time is supplied by
the test/fixture, never read by the model. `advance` cannot move backward.
New deadlines satisfy `now < D <= now + 86_400_000` within that domain and are
immutable once stored. The future fixture translates its one monotonic origin
into this domain and advances before observing an outcome; no wait or retry
restarts an opening, request or retirement success deadline.

Use opaque tokens with fixed shapes:

```elixir
generation = {:generation, slot_0_to_3, fresh_reference}
attempt = {:attempt, generation, slot_0_to_31, fresh_reference}
root = {:root, generation_or_attempt, fixed_role_atom, fresh_reference}
chunk = {:chunk, attempt, direction, fresh_reference} # direction: :upload | :response
control = {:control, generation_or_attempt, fixed_operation_atom, fresh_reference}
```

Only successful allocation events issue tokens, using local `make_ref/0`;
events never accept replacement identities. Fresh reference construction is
the sole nondeterministic value allocation: model logic has no clock reads,
processes, mailboxes, atomics, ETS, ports, HTTP calls or mutable external state.
This avoids a growing epoch integer/tombstone history while preventing identity
reuse. All other decisions are deterministic functions of state/event. Do not
add a caller-provided reference generator/function. Unknown/released tokens
return `:stale` without change; a live repeated already-applied event returns
`:duplicate`, except the non-mutating late-confirmation premise on an already
unconfirmed attempt described below. Reusing a slot always issues a fresh token, so old events cannot
modify its newer occupant. A stale reply cannot turn an old deadline result
into success.

Represent state with four fixed generation positions; each occupied position
has exactly32 attempt positions. Empty positions contain no former token,
payload, receipt history or completed-request record. Fixed record fields:

| Record | Fields and finite domain |
| --- | --- |
| Model | Current time; four generation positions. No event log, total-request counter or completed-ID set. |
| Generation | Token; phase `preparing/ready/retiring/cleanup_hold`; opening deadline; retirement deadline initially nil; opening outcome `pending/ready/failed/timed_out`; retirement outcome `not_started/pending/ok/timed_out/unconfirmed`; scope evidence `not_started/opened/not_opened/retired/unconfirmed`; sticky lost-proof flag; fixed roots/controls;32 attempt positions. |
| Attempt | Token; phase `reserved/preparing/launched/releasing/cleanup_hold`; deadline; outcome `pending/ok/rejected/failed/timed_out`; launched flag; completion evidence `none/not_launched/confirmed/unconfirmed`; sticky lost-proof flag; fixed roots, two chunk credits, two stream-finished flags and fixed controls. |
| Root credit | Empty or one current root token. This models one root *family*, not one actual object or a byte bound. |
| Chunk credit | Empty or current chunk token plus `held/released` phase. Released retains its identity until matching ACK; at most one per direction. |
| Control operation | `unused`, or one immutable token plus result `pending/ok/failed/cleanup_pending/cleanup_unconfirmed` and separate helper-release/frontier-release flags. Completed operation records stay fixed until their owner is removed; the same operation is never reissued. |

Generation root roles are `policy_source/policy_prepared/custodian/scope/
shared_controls`. Attempt root roles are `source/prepared/upstream/helpers/
parser_batch/terminal/upload_source/response_consumer`. Generation operations
are `open/retire/abort`; attempt operations are `initial_wait/abort_wait`.
No caller extends these enums. `shared_controls` represents the still-open
P5 family: retaining one symbolic root cannot certify that its real contents
are bounded. Root construction/copy multiplicities remain full-ledger work.

Model results contain only `:applied/:duplicate/:stale/:busy/:cached`, or a
new/current token. Invalid event types, arities, roles, time and phases return
fixed reason atoms without echoing the event or retaining diagnostics.

Use fixed errors `invalid_event/invalid_token/invalid_time/invalid_deadline/
invalid_phase/invalid_role/invalid_operation/conflicting_result/ownership_pending/
lost_proof`. Check owner identity before live-state rules; on live release,
lost_proof takes precedence, then ownership_pending, then invalid_phase for a
missing terminal/public outcome. Thus the example release assertion below is
unambiguous. Busy is a bounded rejection receipt, not an invalid event.

The exact snapshot is a fixed map with `qualification: :unqualified`,
`generation_slots: 4`, `occupied_generations`, `attempt_slots_per_generation: 32`,
`occupied_attempts` as a four-integer tuple, `held_roots`, `held_chunks`,
`issued_controls` and `outstanding_controls`. Count current records only.
Invariants enforce exact tuple widths/role keys, current-token ownership,
immutable operation identities and valid phase/outcome/evidence combinations;
occupied generations≤4, each attempt count≤32, held roots≤1044, chunk credits≤256
and issued/outstanding controls≤268. These are symbolic group/slot ceilings,
not numbers of actual BEAM objects, helpers, messages or retained bytes.

## Slice A: transition/event table

All allocated generation/attempt phases occupy their slot. Root/chunk/control
release clears ownership credits only; it cannot refund the owning slot.
Every event first validates its exact shape and owner token. Invalid events
leave state unchanged; released/stale tokens are harmless no-ops. `invariants`
must hold before and after every accepted transition in tests.

| Event | Preconditions and bounded change |
| --- | --- |
| `{:advance, now}` | Valid nondecreasing time. Independently expire each pending opening outcome at its stored opening D, each pending retirement outcome at its stored retirement D, and each pending attempt at request D, regardless of presentation phase. Latch only that outcome as `timed_out` and enter `cleanup_hold`; preserve the other outcome/deadline and closed admission, retaining all slots/credits. A completed opening does not expire merely because its D passed. One expired deadline must not suppress another still-pending deadline. |
| `{:reserve_generation, D}` | Valid new deadline and an empty G4 slot. Allocate preparing generation before policy/custodian/resource capture; return token. At G4 return `:busy` with unchanged state, no identity or root allocation. |
| `{:scope_opened, g}` | Corresponding open operation has result `ok` and custodian/scope roots are held; record opened scope even if late/retiring. A pending opening outcome before opening D becomes `ready`; only a still-preparing generation also changes phase to ready. Retiring/held generations preserve phase and closed admission. Late open never changes a timeout to success. Custodian/scope ownership remains explicitly charged. |
| `{:generation_failed, g, :not_opened}` | Opening never succeeded and no scope root is held; modeled known pre-open failure. Set a pending opening outcome to failed and record not-opened evidence, preserving a latched `timed_out` outcome and every retirement outcome/deadline. All owned preparation/helper roots must still be released before slot refund. A generic open error is insufficient to assert this event in the later fixture. |
| `{:retire_generation, g, D}` | First call latches retirement D and closes generation admission immediately, including during preparation. Set retiring/pending without removing attempts. Repeats join cached state and never replace D. Preserve opening timeout/failure and lost-proof flags. |
| `{:scope_retired, g}` | Generation retirement has begun, scope was opened and a retire/abort control has result ok from modeled successful await_retired. Record confirmed public retirement. If retirement outcome is pending and now < its D, latch `ok`; after D preserve `timed_out`. Never overwrite unconfirmed/lost-proof evidence. It clears no roots, helpers, controls or attempt slots. |
| `{:generation_unconfirmed, g}` | Sticky lost-proof flag; scope evidence unconfirmed; cleanup_hold. Never infer a confirmed retirement or free slot from zero current attempts. |
| `{:release_generation, g}` | No attempt slots, roots or outstanding control credits; no lost-proof flag; scope evidence retired, or known not_opened with no successful open. Remove only this generation. Ready/opened without public retirement cannot release. |
| `{:acquire_attempt, g, D}` | Generation ready and not retiring; valid D; empty attempt position. Allocate one of32 leases before any source retain/capture or preparation. Slot33 returns busy without allocating a token/root/control. |
| `{:prepare_attempt, a}` | Reserved lease and held source root. Transition to preparing; no extra lease. No preparation/capture can precede acquire. |
| `{:launch_attempt, a}` | Preparing, pending and unexpired, generation still ready. Set launched flag/phase; upstream/helper roots remain separately tracked. Launch denied once generation admission closes. |
| `{:reject_attempt, a}` | Reserved/preparing, never launched. Latch rejected and not_launched; enter releasing. Owned source/prepared/helper roots and issued controls remain charged. |
| `{:attempt_result, a, result}` | Launched flag true; result exactly ok or failed. Ok additionally requires response stream finished. A first result before D latches result/releasing. Repeated matching result is duplicate; a conflicting or late result is conflicting_result with unchanged state. This is a data outcome, not cleanup proof. |
| `{:request_completed, a}` | Launched attempt; record modeled confirmed RequestCompletion. An already confirmed marker returns duplicate. An unconfirmed marker accepts this distinct modeled premise as applied with identical state, including on repetition: the fixed model does not store a confirmation history alongside sticky uncertainty. Do not overwrite terminal outcome or unconfirmed evidence. This receipt never means cleanup succeeded; it clears no roots/controls and does not acknowledge old shared pool/native controls. |
| `{:attempt_unconfirmed, a}` | Sticky lost-proof flag/completion unconfirmed; cleanup_hold. Never refund this attempt based on other scalar counts. |
| `{:owner_down, owner}` | Live generation or attempt. Sticky lost-proof flag and cleanup_hold; request pending outcome becomes failed, existing timeout/result remains. No implicit release of owned roots/controls. Recovery from lost evidence is outside this first slice. |
| `{:retain_root, owner, role}` | Live matching owner; fixed role. Source/helper retain is allowed for reserved attempts; other attempt roles require preparation or later. Empty role issues root token; a held role returns its current token without another credit. No payload is accepted. |
| `{:release_root, root}` | Only matching current root identity clears that credit. Old root release after same-role reuse is stale. Actual source/helper release is a later fixture/source premise. |
| `{:offer_chunk, a, direction}` | Launched/pending/unexpired; direction exactly upload or response, not finished, with empty credit. Upload requires upload_source root; response requires response_consumer root. Issue one chunk token. A second offer while held or released-but-unACKed is rejected. No bytes/iodata accepted. |
| `{:release_chunk, chunk}` | Matching held chunk becomes released; current identity remains until ACK. Duplicate release cannot affect a later chunk. First slice chooses local release, with no transfer to an external retained-response owner. |
| `{:ack_chunk, chunk}` | Only matching released chunk becomes empty. ACK while held is ownership_pending. Stale ACK cannot release a newer chunk. Finish/trailer/error overlap uses the terminal root; the model does not invent a uniform response chunk-size bound. |
| `{:finish_stream, a, direction}` | Launched flag true, matching direction has empty chunk credit and terminal root is held. Set that fixed finished flag once; repeats are duplicate, further offers are invalid_phase. No trailers/error payload is accepted. Error paths may terminate without successful finish, but retain the same terminal root until explicit release. |
| `{:begin_control, owner, operation}` | Fixed operation for owner kind. Open only while preparing; retire/abort only after retirement starts; initial_wait/abort_wait only on launched attempts. First issue consumes its fixed operation credit. Repeats return the same token/cached result, including after helper exit; no additional calls/waiters/abort are emitted. |
| `{:control_result, control, result}` | Matching token and fixed result enum. Record first result; matching duplicate is idempotent, conflicting result is invalid. cleanup_unconfirmed also sets owner lost-proof/hold; cleanup_pending retains credits. An ok reply is not helper or frontier release. |
| `{:control_helper_released, control}` | Matching issued control; independently mark helper/source release. Do not infer target-side call/timer/signal release. |
| `{:control_frontier_released, control}` | Matching issued control; independently mark modeled included operation-control frontier release. This requires a later proved barrier/induction; helper death, timeout or reply alone cannot justify it. |
| `{:release_attempt, a}` | Terminal outcome; all roots/chunks empty; every issued control has both release flags and a terminal result; no lost-proof flag; completion confirmed if launched, otherwise not_launched. Remove only the matching attempt, never its generation. Public request completion alone cannot release a generation or its shared_controls root. |

An issued control's terminal result is any listed result except the initial
pending marker. A cleanup_pending result still needs independently established
completion and both release flags before its owner can be refunded. Retire and
abort control operations each encompass at most one public initiation plus one
finite await_retired; initial_wait is one request await, and abort_wait is at
most one abort_and_await. Their real helper/transient cost remains ledger work.

A generation's open result may arrive after retirement/timeout; control result
and scope_opened must preserve accounting even then. A request's late confirmed
cleanup may permit release after timeout when every explicit criterion holds,
but the request result remains timed_out. Sticky lost-proof/unconfirmed/owner-DOWN
slots cannot be reclaimed in Slice A; saturation is an acceptable fail-closed
outcome, not a reason for forced refund or rotation.

## Tasks A0–A4: implementation and decisive model acceptance

### A0: Freeze ownership and review the specification

- [ ] Parent releases the new-file writer after its separate patch delivery;
  verify worktree/HEAD and current diff, preserving all existing edits. Record
  the actual execution baseline rather than assuming the planning baseline.
- [ ] Independent Sol review checks this API, every table edge, fixed profile,
  identity issuance, F1–F8 coverage and the explicit non-byte claim. Resolve
  findings only within the assigned plan; parent owns master gate text.
- [ ] Assign one Sol writer the two new executable files. Reviewers read only;
  parent owns all serialized execution and receipts. Carry task-specific Sol
  counters across repair handoffs; expected TDD red is not a failed repair.

### A1: Write the self-contained runner and behavioral red tests

- [ ] Create the test file with the exact runner structure below, defining
  `Gaoxy.Qualification.ManagedH1LeaseModelTest` between load and run. No app
  `test_helper`, existing probe library or HTTP application startup is imported.

```elixir
ExUnit.start(autorun: false)
ExUnit.configure(seed: 21_112_026, max_cases: 1)
Code.require_file("managed_h1_lease_model.exs", __DIR__)

defmodule Gaoxy.Qualification.ManagedH1LeaseModelTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Qualification.ManagedH1LeaseModel, as: Model

  # Define the 22 named behavioral tests in the acceptance table below.
end

summary = ExUnit.run()
IO.inspect(summary, label: "H1_MODEL_EXUNIT_SUMMARY")

if summary.total == 22 and summary.total > 0 and summary.failures == 0 and
     summary.skipped == 0 and summary.excluded == 0 do
  System.halt(0)
else
  System.halt(1)
end
```

- [ ] Implement test helpers as finite valid traces through these events. A
  helper preparing a ready generation must retain custodian/scope roots,
  begin open, supply modeled ok result, separately release its helper/frontier,
  then scope_opened. An attempt helper acquires before retaining source and
  prepare/launch. No helper patches state maps or supplies proof constants.
- [ ] Parent records the expected red run using the command below. Missing
  module/API caused by the absent implementation is valid red; a syntax,
  environment or zero-test successful run is not valid behavioral evidence.

Example meaningful assertions, using the API receipts above:

```elixir
assert {:ok, state, generation} = Model.step(state, {:reserve_generation, 100})
assert {:ok, state, root} = Model.step(state, {:retain_root, generation, :policy_source})
assert {:error, :ownership_pending, ^state} = Model.step(state, {:release_generation, generation})
assert {:ok, state, :applied} = Model.step(state, {:release_root, root})
assert {:ok, state, :stale} = Model.step(state, {:release_root, root})
assert :ok = Model.invariants(state)
assert %{qualification: :unqualified} = Model.snapshot(state)
```

### A2: Implement fixed state, admission and terminal conservation

- [ ] Create the model module with the specified four functions; private
  helpers validate fixed shapes, locate current tokens and replace one tuple
  position. Fixed atom reasons only; no diagnostic event capture or history.
- [ ] Implement generation/attempt allocation, deadlines and phase/outcome
  tables. Allocation failures do not issue identity or consume a credit.
- [ ] Implement root/chunk/control ticket identity checks and fixed operation
  coalescing. Verify stale releases against a newly occupied same slot/role.
- [ ] Implement the explicit request/generation release predicates and
  invariant/snapshot scalar summaries. Snapshot counts follow bounded current
  positions; they contain no payload, completed-ID list, growing statistics or
  byte/activation-success value.
- [ ] Parent runs scoped model tests; diagnose failures against the table,
  keeping required assertions and the original absolute deadlines.

### A3: Complete the meaningful acceptance cases

Each row below is exactly one ExUnit test. Use finite sequences/permutations
and assert `invariants == :ok` at every accepted step. Rejected steps must
return the same state; stale/duplicate steps must conserve every credit.

| Test name | Required observation |
| --- | --- |
| `generation reservation precedes roots` | Root/control events without a live generation are stale; owned roots block early generation refund. |
| `four generation phases reject fifth` | Simultaneously hold preparing, ready, retiring and unconfirmed slots; fifth is busy with identical state. |
| `thirty two leases precede preparation` | Fill32 reserved/preparing attempts;33rd busy creates no root/control/token; no preparation without a lease. |
| `prelaunch rejection keeps captured roots charged` | Rejection-before-Promise is terminal but cannot release until all source/prepared/helper roots are cleared. |
| `closed generation denies acquisition and launch` | Retirement before acquire or between prepare/launch closes both operations without refund. |
| `stale generation cannot release replacement` | Release known-not-opened generation, reoccupy its slot, deliver old scope/retire/release messages; new state unchanged. |
| `stale attempt cannot release replacement` | Complete/release one attempt, reoccupy its slot, replay old result/completion/release; new lease remains. |
| `root release matches allocation identity` | Release/re-retain one role, replay old root token; new role remains held. |
| `upload credit requires release before ack` | One outstanding offer; held ACK rejected; source/next-read family remains charged until explicit release. |
| `response credit rejects stale ack` | Release/ACK then offer new chunk; old release/ACK cannot clear it; consumer root holds ownership separately. |
| `terminal root blocks request refund` | Successful response finish is one-shot, denies later chunks and precedes ok result. Data terminal/completion does not discard parser/terminal/consumer roots or trailers/errors. |
| `public completion is not local cleanup` | Confirmed RequestCompletion alone cannot refund source/helper/control credits. |
| `control retries join one operation` | Repeated begin before/after result returns current ticket/cached result; no growing waiter or operation count. |
| `control reply is not release frontier` | ok/helper release independently leave frontier charged; inverse ordering leaves helper charged. |
| `stale control cannot affect reused owner` | Reoccupy attempt and generation positions and replay old control result/release; current credits unchanged. |
| `request timeout preserves original result` | Advance to D with held credit; late ok cannot become success; late confirmed full cleanup can release while timed_out remains latched until removal. |
| `opening timeout does not reopen admission` | Late successful open is recorded for cleanup after D but never ready/success. Retire during preparation before opening D, then advance to opening D; the opening outcome still times out with admission closed. A known not-opened failure after that timeout cannot replace it. Timely open while retiring records opening completion without reopening admission. |
| `retirement deadline never restarts` | Repeated retire with later D preserves first D; late retirement cannot turn timed_out into successful outcome. Exercise preparation-time retirement with opening D before, after and equal to retirement D; advancing through both must independently latch both pending timeouts even after the first enters cleanup_hold. All deadlines, slots, roots and controls remain unchanged except the specified outcomes/phase. |
| `owner death and unconfirmed stay charged` | Inject each for attempt/generation; clear all other modeled credits and confirm public cleanup; sticky lost proof still prevents refund. |
| `request release is not generation release` | Request release leaves opened generation/shared_controls/custodian charged; generation release needs separate public retirement and root/control release. |
| `invalid events preserve bounded state` | Reject payload-bearing maps/lists/binaries/functions/PIDs, unknown enums, malformed tokens, backward/out-of-range time, deadline reset and conflicting results; fixed errors contain no input. |
| `long turnover retains only current slots` | Run2048 complete modeled acquire/release cycles with root/chunk reuse and a held sibling; recursively check bounded state shape/current-token inventory at checkpoints. No cumulative counter/list/map or historical nonce remains; then prove the held sibling still blocks its slot. |

For release-order races, test all permutations of public completion, root
release and the two control release flags: no prefix lacking a premise can
refund. These finite model checks corroborate the transition rules; they do
not constitute the dependency's arbitrary-history/native P5 induction.

### A4: Independent code review, fresh tests and local delivery

- [ ] Independent Sol specification/code review checks the exact new-file
  delta, event table, identity reuse, bounded state and test strength. Resolve
  findings under the cumulative repair policy; no production/source expansion.
- [ ] Parent freezes every new executable input and plan/design identities,
  runs formatter check and the fresh scoped runner sequentially, and rehashes
  after each command. Record22 executed tests,0 failures/skips/exclusions,
  actual seed, command/environment, exit and summary. Required checks must
  genuinely pass; no umbrella0-tests receipt may substitute.
- [ ] Parent independently reviews the fresh receipts, then stages only the
  reviewed model/test and owned evidence/plan paths and commits locally with
  `test(proxy): model managed h1 qualification leases`. Preserve all other
  files; no push, publication, deployment or milestone advancement follows.
- [ ] Stop Slice A when these outputs pass. Report model PASS separately from
  accounting/fixture/production UNQUALIFIED and the exact remaining premises.

## Exact scoped commands and new-input freeze

Only the parent executes these commands, sequentially, after A0. Existing
compiled dependencies are not used by this model; `--no-compile --no-start`
prevents an incidental umbrella build or application startup. Do not run
umbrella `mix test` with the integration path: that may execute zero tests.

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix format --check-formatted integration/http_fetch_contract/managed_h1_lease_model.exs integration/http_fetch_contract/managed_h1_lease_model_test.exs'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --no-start integration/http_fetch_contract/managed_h1_lease_model_test.exs'
```

The second command must print `H1_MODEL_EXUNIT_SUMMARY` with total22 and
failures/skipped/excluded0 and exit0. Missing script/module, interrupted run,
excluded tests or total0 fails the gate. Retain red/failure receipts separately
from final green; a wrapper must preserve the real command exit.

Before each red, repair or final execution, parent writes a distinct numbered
receipt with SHA-256 of **both** new executable paths. There is no unlisted
helper, peer, imported test helper or external script in Slice A. Include this
plan, memo/review, `AGENTS.md`, command and baseline as review inputs. After
execution rehash the same paths and demand equality. No placeholder numeric
hash may stand in for a not-yet-created file. A minimal freeze command is:

```sh
python - <<'PY'
from pathlib import Path
import hashlib, json
paths = [
    "integration/http_fetch_contract/managed_h1_lease_model.exs",
    "integration/http_fetch_contract/managed_h1_lease_model_test.exs",
]
print(json.dumps({p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
                  for p in paths}, indent=2, sort_keys=True))
PY
```

Store actual output in the numbered source-before/source-after receipts,
alongside command/exit/summary logs. An input missing or changing during a run
blocks that receipt; settle ownership and rerun, never claim identity from the
filename alone. Fresh model source identities remain separate from the parent
patch driver's429-input freeze and the full native/build/profile certificate.

## Slice B: separate isolated public-API qualification fixture

Slice B depends on Slice A's reviewed local delivery and a separate concrete
fixture execution plan with independent specification review. Its eventual
writer owns only proposed new paths:

- `integration/http_fetch_contract/managed_h1_accounting_fixture.exs`
- `integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs`
- `integration/http_fetch_contract/managed_h1_accounting_peer.py`
- `docs/plans/m3-h1-qualification-fixture.md`

Parent owns separate evidence/source freezes and all VM/peer runs. Source-ledger
work may proceed in parallel on disjoint new evidence files; dependent runs,
shared formatting and exact-cohort execution remain serialized. Never import
or change the current24/39 contract driver to supply this fixture's controls.

The fixture plan must bind fixed bounded producers/cleanup callers, compact
sources before transfer,32 outer attempt leases, G4 generation pre-reservation,
one persistent custodian per scope and fixed open/retire/abort/await helpers.
It must enforce one outstanding nonempty upload chunk≤65,536 bytes with charged
backing/next-read overlap, release-before-response-ACK, one terminal sequence,
fixed-purpose snapshot counts and coalesced cleanup without unbounded waiters.
It may use existing pure preparation modules and public Fetch/Promise/
RequestCompletion/Stream and ManagedTransport open/snapshot/retire/await APIs.
No private Policy/pool call, scope-field resource inspection or TLS workaround.

Decisive functional fixture cases: exact256-field/65,536-byte initial/effective
metadata boundaries and rejection after copies;32 held preparations/33rd
rejection with no managed capture; publicly controllable C2 connecting; unread
response/held upload/one-byte fanout; stale tokens and late outcomes; helper/
owner death; preparing/connecting/unread retirement; A/B isolation; confirmed,
pending and unconfirmed cleanup; bounded turnover and original deadlines.
The new plan must list deterministic barriers, expected public/peer events,
finite deadlines, owned-process joins and every executable source hash. A local
pre-Fetch barrier proves only the local gate; if public APIs cannot hold private
upstream preparation deterministically, record that exact coverage gap.

Do not map a public request-completion reply, helper DOWN, timer cancellation,
snapshot zero or sampled plateau to control_frontier_released unless its exact
source/barrier argument is proved. Private upstream controls may have no direct
observable release event; their P5 induction belongs to the source ledger and
must remain open until established. Model events do not manufacture that proof.
TLS95 qualification depends on a containing published release being source/API
reviewed, installed and independently qualified. The historical0.21.1 context
lacks that fix; a later published candidate alone does not close the gate.
Cleartext H1 is the first fixture profile. H2 is a separate contract, not
certified by this plan.

Functional fixture execution may expose defects before the numeric expression
is complete, with **no byte claim**. Accounting qualification requires the
reviewed full P0–P6 inventory/expression, exact native ABI/build/socket/profile
certificates, real enforcement of all fixture premises and independent review
of fresh source-bound runs. Unknown terms remain unknown; no observed maximum,
arbitrary allowance, reuse quota or periodic rotation can replace them.

Parent-reported future P2 inputs include the exact runtime derivation
`/nix/store/ckl72c9yq125214w0zdglh7cr5jycz9r-erlang-28.5.0.7.drv`, saved
read-only at `.audit/m3-otp-derivation-current.json` (new Nix schema:
`derivations` dictionary), and source
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`. Actual generated config.h/
target Makefile were absent in the prior proof. This plan does not verify those
artifacts or duplicate the old lemmas: recovering exact build inputs is a local
evidence task, not automatically an upstream blocker or part of Slice A.

Task4 production edits still require that applicable complete qualification.
Actual ingress/adapter/lifecycle/generation-manager conformance, held saturation,
trust/destination behavior, protocol matrix, independent peers/browser checks
and both at-least600-second managed H1/H2 soaks precede activation/M3 completion.
This model/fixture plan adds no production interface, dependency patch, M4,
publication, deployment or new operational permission.

## Planning verification and remaining work

Planning assignment task `m3_frontier_spec_review/model-plan`, direct Sol;
only this file created. Read current authorization/diff and the approved memo/
review; self-review checked F1–F8 coverage, table/API names, fixed state limits,
root/control stale identity, no-history handling, deadline/release separation,
exact ownership and the explicit22-test runner. Static checks validate local
links, fences, whitespace and frozen architecture/review hashes.

No model/fixture implementation, Mix/VM/test/peer/network command, dependency/
product/current-status edit or commit was run by the planning assignment.
All proposed executable checks are **NOT RUN**, and independent plan review
is the next prerequisite. Own commands finish synchronously; no own background
command remains. Sol repair rounds0, unsuccessful0; Astra recovery not applicable.
No new user decision is required; the parent owns review and execution scheduling.
