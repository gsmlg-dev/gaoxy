# M3 H1 qualification model independent specification review

Task `m3_qualification_plan_spec/A`, direct independent Sol review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`.
Only this new review report is owned for Task A. Concurrent untracked plans,
architecture reports and 0.21.2 receipts were present and are preserved.

**Final verdict: PASS for Slice A specification only**, after independent
re-review of the parent's repair1, SHA-256
`f8e0a0ff445d002d40c399b0493a9fe5e54288e95ae421eb3b3f610090ddc3a5`.
The initial finding and original input identity below remain historical.

## Initial verdict: one actionable finding

**FINDING A1 — opening and retirement deadline expiry must be independent of
the generation's presentation phase.** Do not release Slice A implementation
until the narrow correction below is independently re-reviewed.

Reviewed plan SHA-256:
`b6aead9c7401b2840c23c2bd71cbd7e29e89368c3b926591d752fa2725f51a2b`.
The architecture memo and its independent review match the plan's declared
identities, respectively
`c01608f23972df371f1664e6a9a40b8598a6e28a129f16f78d23bc3444c00184` and
`b04852b8ba570e18a26219b6fc1773cdcb56b361b75b7ce1a224016d72ae9497`.

The event table's `advance` row expires only preparing generations at opening D
and retiring generations at retirement D. Yet `retire_generation` is explicitly
legal during preparation and immediately changes the phase to retiring. With
opening D=10 and retirement D=20, retiring at time 1 then advancing to 10 no
longer meets the opening-expiry phase guard. A late `scope_opened` cannot make
that generation ready, but the opening outcome remains pending rather than
the required latched timeout. Similarly, entering cleanup_hold can prevent a
pending retirement from expiring under the literal phase-based rule. This
conflicts with independent immutable absolute deadlines and leaves the promised
phase/outcome invariants under-specified. It does not establish a real runtime
leak or an upstream bug.

Minimal correction, confined to the plan:

- Evaluate opening expiry whenever opening outcome is pending and its stored
  D has arrived, and retirement expiry whenever retirement outcome is pending
  and its stored D has arrived, irrespective of generation phase. Preserve the
  other outcome/deadline, all charged ownership and closed admission.
- Late known-not-opened failure may record not_opened evidence for cleanup,
  but `generation_failed` must preserve an already latched opening timed_out
  instead of replacing it with failed. Late opening/retirement observations
  must likewise preserve timed_out and sticky lost-proof evidence.
- Extend the existing named opening/retirement deadline tests with retirement
  before opening D, both orders of the two deadlines and late known failure.
  Retain exactly 22 tests; no new product behavior or extra test count is needed.

## Checks that pass at specification level

The remaining contract matches the approved qualification-only refinement.
Four generation slots and 32 attempt slots each conserve positive symbolic
reservations through preparing, rejecting, retiring and uncertain states. An
acquire loser allocates no token, root or control. Release requires separate
terminal/public evidence and retained-owner release; request completion does
not refund generation or shared dependency controls. Owner DOWN and lost proof
are sticky and fail closed. Recovery/forced rotation is excluded.

Fresh reference tokens plus exact current owner/slot matching protect reused
generation, attempt, root, chunk and control identities without historical
epochs or tombstones. Released chunk identity persists only until matching ACK;
one credit per direction enforces release-before-ACK. Operation identities and
cached results occupy fixed fields, with no growing waiter/history inventory.

The stated symbolic ceilings are internally consistent:
roots `4*5 + 4*32*8 = 1044`, chunks `4*32*2 = 256`, controls
`4*3 + 4*32*2 = 268`. Snapshot counters count current records, have fixed keys,
and cannot certify actual BEAM objects, payload backing or retained bytes.
Finite time/domain/deadline ranges and fixed enums prevent growing numerical
or dynamically extended state. No caller proof constants, callbacks, private
API, production registration or activation-success result are introduced.

The 22 named behavioral tests cover slot/identity reuse, roots and streams,
prelaunch rejection, closed admission, coalesced controls, independent release
premises, timeout and sticky uncertainty, invalid inputs and 2048-cycle bounded
turnover. Release-order permutations are required. The explicit ExUnit runner
uses `autorun: false`, invokes `ExUnit.run()` once and requires exactly 22
executed tests, zero failures/skips/exclusions and a nonzero test count before
exit0. A missing implementation is permitted expected RED; an environment or
zero-test receipt cannot pass. Commands, source-before/after hashes and final
review are parent-owned and serialized. All executable/model checks are
**NOT RUN by this reviewer**.

Slice B remains a separately specified/reviewed public-API fixture. A future
model PASS permits only the source-independent pure model/test slice. It cannot
close source/build/API premises, actual lifecycle or byte accounting, P0–P6,
Task4 production conformance/activation, TLS/H2, managed soaks or M3 completion.

## Verification and handoff

Read-only inspection used `pwd`, scoped git status/branch/HEAD/diff, `rg`,
`cat`, `sed`, `nl` and SHA-256. All three prescribed Task A input hashes match.
The existing fixture/manifests were not modified. No Mix, VM, model/test/peer,
network, dependency mutation, process launch, commit or child agent was run.
All own commands finished synchronously. Only the assigned report is written.

Task status: **DONE — finite specification finding A1; implementation gate
not passed**. Sol implementation repair rounds0, unsuccessful0; received Astra
counter0, consumed0; `astra_gate: none`. Parent owns the narrow plan correction,
then independent re-review. No new product decision is required.

## Repair1 independent re-review

The parent's amended plan matches the announced hash above. The new `advance`
rule independently checks each pending outcome against its immutable deadline,
including when another deadline has already moved the generation into
cleanup_hold. `generation_failed` preserves timed_out and the separate
retirement state. A timely open during retirement completes the opening outcome
without reopening admission; a late open cannot replace timeout. Both named
deadline tests now require retirement during preparation, both deadline orders,
equal deadlines, late known-not-opened failure and timely opening while
retiring. The acceptance table still has exactly22 named tests, and the fixed
runner/ownership/non-byte boundaries are unchanged.

A1 is **resolved at specification level**; no remaining blocking specification
finding. Final task status **DONE — PASS for the first source-independent pure
model/test slice only**. Parent plan repair rounds1, unsuccessful0; model
implementation repair rounds0; Astra0. This re-review used static source reads
and hashes only. Actual model/fixture/lifecycle/byte qualification remains
**NOT RUN/UNQUALIFIED**, as applicable. All own commands are finished.
