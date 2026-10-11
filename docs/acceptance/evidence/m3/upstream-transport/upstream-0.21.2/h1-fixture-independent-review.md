# Independent H1 fixture review

Task `m3_h1_fixture_review`; direct Sol review in `.trees/m3-gateway` on
`codex/m3-gateway`. Historical comparison baseline is
`b2ac78b518f459ec2c95b7823226640413f2ca95`. Parent subsequently reports accepted
model-only local delivery at `85c2284a035e0b4ecbf577279eee01142702b5a3`;
the current loose branch ref independently matches that delivery. Assignment
is static review only; source and runtime repair are parent-owned.

## SPEC — PASS

Static source review accepts the amended concrete specification. B09's held
response chunk rejects a second offer as `:ownership_pending`, independently
of reservation `:busy`. B11's 4096 hexadecimal f digits declare a positive
16384-bit chunk size: all three remaining bytes `z\r\n` are data, because the
parser has not reached the chunk terminator. Independent SHA256 is
`ae7c791a527d756a15cdb11de8c13feefd266a81ea9671d3e65f1e7da00e2e5e`.
No delivery segmentation requirement or finite deadline was relaxed.

Baseline registers exactly B01–B20, no skips/exclusions, serial execution,
original-handle registration before waits, finite declared actors/operations,
fixed primary/cleanup/shutdown deadlines and required owned joins. Local
preparation and fixture-held barriers retain their stated observation limits.
B13 consumes the independently reviewed repaired model rather than inventing
no-launch or native release evidence. B21 remains deferred and fails closed
before actor/peer/test allocation; this review grants no TLS gate.

Public Fetch/Promise/Completion/Stream/ManagedTransport contracts are compatible
with the specified sequence. Effective header count/charge checks, trailer
validation and raw chunk framing remain bound to the selected 0.21.2 sources.
Numerical accounting is `ACCOUNTING_BLOCKED_INPUT`; N8/Feature #97, activation,
production Task4–8, managed soaks and M3/M4 progression stay blocked.

The preserved first test-only RED executed zero cases and exited1 on absent
fixture-module Code.LoadError. It is absence evidence, not functional acceptance.
The original spec/inventory/reviews stay historical. The initial SPEC phase
plan is preserved as `h1-fixture-plan-oracle-amended-before-artifact-binding.md`
(SHA256 `21a5348de27b8009697f1d3d285f4681682d0f601ec55b01a8406e0cf02a7eec`).
The later bounded artifact-export amendment also passes SPEC: the existing
controller exports at most128 attempt/four generation rows, one row at a time,
at most4096 bytes each, without another actor/control/native refund. The final
canonical plan SHA256 is
`01acb850d85b90c2409092d7bf25c5400ad2e519d233858d9194dbce211e6720`.
All208 current baseline inventory inputs match; the old rebind requirement is
resolved by that inventory, without relabeling historical receipts.

## CODE QUALITY — FAIL

Implementation SPEC compliance also FAILS on the common cleanup contract.
The concrete plan's SPEC PASS is separate from that implementation verdict.
Parent confirmed there is no narrower accepted B17 cleanup contract and that
baseline execution is not admitted by this review.

Reviewed the full3503-line fixture,253-line test file and493-line Python peer
after SPEC. Canonical hashes:

- `managed_h1_accounting_fixture.exs`:
  `a79e6726f7185b4cbd85b8561eac03988184b1c92dfc0dacff6c210c4880ea88`
- `managed_h1_accounting_fixture_test.exs`:
  `68d0af0bfc6914fe204be7de6370371c412d264ee1cde2d0a931574b34a2e3ee`
- `managed_h1_accounting_peer.py`:
  `e997a5fcd0d7391cf56ba278e5dccf3d61b5e68fbb2bae4cbedf1c69f75e0fb2`

### F1 — B17 can pass without confirmed scope retirement (high)

`managed_h1_accounting_fixture.exs:2807` consumes its second reserved receipt
wait with zero timeout and accepts either `:ok` or `{:error,:cleanup_pending}`.
At line3258, cleanup explicitly accepts B17 with `row.retired=false` merely
because the original wait returned pending. Both waits and initiation slots
are already used, so cleanup takes no further public observation. If both
waits are pending, the exact public evidence confirms no scope retirement,
yet cleanup can return `ok:true` and the case can emit `PASS_FUNCTIONAL`.
Peer and fixture actor joins do not fill that missing public scope proof.

The common cleanup specification (lines666–668) requires reporting cleanup
failure when proof is absent. Preserve B17's original500ms deadline and
immutable initial pending outcome, but require its final available receipt
evidence to confirm retirement for successful cleanup; otherwise preserve
the pending result and fail the case. Do not add a retry/helper, replace D,
or claim a native frontier. This is a reachable acceptance hole established
from control flow, not an observed runtime failure.

### F2 — peer actor failure can destroy cleanup custody (high)

`Ledger.handle_call({:command,index})` at line372 raises for an actor that is
dead or still has a command in flight. A peer actor can die on the explicit
oversized/invalid peer-line checks (lines856/1479–1480), or retain an outstanding
command after a bounded reply timeout. Cleanup's peer-in-flight/release steps
are individually guarded, but release at line3004 unconditionally issues
another peer command. The ledger assertion then terminates the unlinked
ledger, and `cleanup_step` catches only that call's exit. The next unguarded
`:state` call at line3015 exits before per-attempt/per-scope cleanup and owned
actor stops/joins. `run/1` guards only the scenario; cleanup at line553 has no
outer `after`, and its ledger stop is only the normal path at line588.

Thus an unexpected peer actor fault, or an unsettled peer operation, can
abandon already registered originals and owned actors without a per-case
FAIL/cleanup record. Actors are created with `spawn_monitor`, not lifetime
links to the test controller, so its exit does not clean them up. This breaks
the specification's independent cleanup requirement. Keep the ledger alive
when a reserved command cannot be issued; record the fixed failure, retain
the existing operation, and continue cleanup of other rows. Ensure the
controller's final shutdown/evidence path handles cleanup exceptions without
new roles, private upstream stops, or budget renewal. A bounded deterministic
peer-fault/in-flight probe should verify this before runtime admission.

Other reviewed paths satisfy the stated static boundaries: exactly20 explicit
tests/scenarios; original handle registration before waits; fixed role and
operation slots; B09/B11 exact amended oracles; independent header ordering
matching `HTTP.Headers.set/3` append and `set_default/3` prepend; rolling body
hashing and one response credit; distinct public/helper/native evidence; bounded
JSONL exports; no native-frontier release. These observations do not supersede
the two failed acceptance paths.

Parent canonical formatter/check receipt actually exited0 with0 tests; its
1132-entry before/after maps differ only in the two permitted Elixir sources.
Parent Python receipt is AST-only and binds the peer hash above. The writer's
three pre-format snapshots and test-only RED source hashes match their receipts.
The formatter's source-after map now differs at two explicitly authorized
inputs: final artifact-export plan, and the parent-repaired ignored run
collector. The latter is outside the208 fixture inventory; parent reports a
separate independent SPEC/CODE PASS, and this report does not approve that
repair. The actual run must bind that helper separately. All remaining
1130 formatter-frozen identities match, including model/TLS selected inputs.

No runtime, VM, Mix, formatter, Git, network or dependency command was run by
this reviewer. Actual baseline cases remain0 / NOT RUN; B21 remains deferred.
SPEC PASS does not admit baseline execution while CODE QUALITY is FAIL.

Review counters Sol0/unsuccessful0/Astra0; model and TLS chains remain separate.
Separate retained model counters: Sol2/unsuccessful1/Astra0. Separate exhausted
TLS tooling counters: Sol2/unsuccessful2/Astra2; no TLS-chain repair or escalation
gate asserted. Only this report and its JSON companion were edited. All commands
completed synchronously; no reviewer job or process remains. Ownership is
released after the final report check. Parent decisions: arrange bounded
fixture repair/review before baseline20; separately satisfy collector review.
