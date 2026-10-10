# M3 local pre-Fetch timeout evidence repair

The Slice B B13 trace found a compatibility gap in the fixture-only lease
model: an unlaunched attempt that expires retains `completion: :none`, and
`reject_attempt` cannot subsequently supply the required no-launch evidence.
The timeout itself must continue to retain its slot and all owned roots.

Use the existing explicit `reject_attempt` event to acknowledge a known local
no-launch terminal result after expiry. Accept it only for an unlaunched,
timed-out attempt in `cleanup_hold`, with no lost proof and no issued controls.
Record `completion: :not_launched` and enter `releasing`; preserve the original
`outcome: :timed_out`, deadline, roots, chunks and control fields. Repeating
that evidence is a duplicate. Ordinary pending prelaunch rejection keeps its
existing behavior. Launched and uncertain attempts cannot gain no-launch
evidence. No timeout, result, helper death or public completion emits native
control-frontier evidence.

Normal `release_attempt` still requires all roots/chunks released, every
issued control's independent release predicates and no lost proof. Slot reuse
uses a fresh nonce; old result/root/release evidence cannot affect the new
occupant. This changes no production activation or numerical qualification.

1. Independently review this repair contract alongside the Slice B B13
   specification before implementation. Model repair counters start at Sol0 /
   unsuccessful0 / Astra0, separate from the retained TLS tooling chain.
2. Extend the existing named prelaunch-rejection test with reserved and
   preparing attempts expiring at their original deadline. Assert that timeout
   alone cannot refund, roots remain charged after explicit rejection, and
   matched root release permits same-slot fresh-nonce reuse. Assert late old
   success/completion/root/rejection/release events leave the replacement
   unchanged. Keep the original pending-rejection assertions and the exact
   22-test runner contract. Cover launched and lost-proof negative paths.
3. Parent runs the test-only source under the existing isolated Nix test
   environment, preserving a deterministic RED caused by the missing
   post-timeout rejection. Then make the minimum model change and synchronize
   the existing model plan's event row. Do not alter dependency sources.
4. Parent runs canonical formatting and the complete scoped 22-test model
   runner with before/after hashes, exact seed, exit and counts. Independent
   specification then code-quality review must pass; preserve every failure
   and rerun affected checks after any repair.

Owned implementation files are `integration/http_fetch_contract/managed_h1_lease_model.exs`,
its test file and the corresponding event contract in
`docs/plans/m3-h1-qualification-model.md`. Parent owns runtime execution,
evidence freezes and local commits. Current proposal is NOT RUN and requires
independent review; the historical committed 22/0 model receipt stays intact.

## Verified implementation checkpoint — 2026-10-11

The completed repair preserves the event contract above. Deterministic original
RED22/1 and repair2 owner-down RED22/1 are retained. Initial GREEN's incorrect
new owner_down expectation and the first independent SPEC-01 failure are also
retained. Repair1 distinguishes exact owner_down/attempt_unconfirmed outcomes;
repair2 only permits sticky not_launched evidence after later owner_down creates
a lost-proof cleanup hold. No rejection admission, normal release, expiry,
original deadline, nonce or control-frontier predicate is widened.

Repair2 canonical format and scoped22/0 pass (zero skips/exclusions, seed21112026,
exit0,1129 unchanged selected inputs, no peer), followed by independent SPEC
then CODE QUALITY PASS. See
[the exact independent report](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-no-launch-repair2-independent-review.md).
Effective counters are Sol2/unsuccessful1/Astra0; the failed independent repair1
gate counts unsuccessful even though its scoped tests passed. Fresh parent
post-review verification and local delivery follow. M3/P0–P6 remain incomplete.
