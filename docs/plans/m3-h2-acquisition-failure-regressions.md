# M3 H2 acquired-request failure regressions

This bounded test-tooling task builds five negative snapshots from the pinned
H2 repair1 fixture and its preserved prerepair source. It changes no normal
fixture, peer, dependency or eight-case qualification plan. Parent owns
independent review, manifests with common runtime inputs, dedicated VM execution
and actual result interpretation. Runtime is **NOT RUN** during snapshot build.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`; parent-supplied baseline
`85c2284a035e0b4ecbf577279eee01142702b5a3`. Other writers are present. Ownership is
only `.audit/m3-h2-failure-regression-builder.py`, this plan and exclusively
created outputs beneath `.audit/m3-transport/h2-failure-regressions/`.

## Exact pinned inputs and edits

| Input | SHA256 |
| --- | --- |
| Repair1 driver | `89cd7237a5864d86e9ffbd7f5f323a275ec9cad1d36cd4f03fc8881842cccbef` |
| Preserved prerepair driver | `83a947b179ce40e3f2b1e511fe3dd8f4995cd4fcff1743bb2b540d9141b43c62` |
| Normal peer | `b1bcff8b19eba8c7bccb315ecd3ee66be860816128e76b2a15b5a36e0968f170` |
| Approved normal qualification plan | `25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270` |

Each source snapshot selects exactly one existing H2C case in `@cases`, retaining
the original final `length(results) == 8` and `shutdowns == 8` predicates. Every
negative invocation therefore genuinely exits nonzero; an exit1 alone does not
prove the injected failure occurred. Inspect the exact case and operation oracles.

Immediately after local original Promise/completion capture and the original
`deadline = state().oracle_deadline`, insert a public peer barrier: accept on
connection1, request on connection1 with end_streamtrue/upload_bytes0 and a
positive stream ID. The unchanged peer independently validates GET `/target`
and its existing request grammar. Record `negative_acquired_request_barrier`.
For acquired variants, raise `NEGATIVE_PRIMARY_AFTER_ACQUISITION` there before
the first await. No public response stream has been exposed at that point.

The repair1 source saves the original Promise and completion before this barrier;
its acquisition and cleanup blocks stay untouched. Prerepair snapshots preserve
the original local Promise and saved completion exactly as originally implemented;
they do not retrofit repair1's Promise ledger or cancellation rule.

The lost-alias variant inserts the same barrier without a raise, then executes
the unchanged original first response await. Its same-directory negative peer
copy deletes only the single existing status200 `self.conn.send_headers(...)`
line at original165. Request parsing, event/control grammar, settings exchange,
caps, timers, reset handling, stop and joins stay unchanged. No response header
can resolve the Promise, so the real first `Task.await` reaches its original2s
cap. No fake timeout, sleep, private process access or extra operation is added.

The builder asserts unique edit anchors and exactly eight original registrations,
reverses the selection/injection to reconstruct each complete original source
byte for byte, reverses the one-line peer deletion and parses Python ASTs. It
preserves original sources plus its own source copy, per-snapshot exact unified
diffs and SHA256 identities. Output directory creation and every output file use
exclusive creation; rerunning over existing evidence fails without overwriting it.

## Probes and required actual oracles

| Snapshot | Existing case | Expected evidence |
| --- | --- | --- |
| repair1-acquired-manual | H2C98_LATE | Original injected primary failure; `failure_abort_and_await` on exact original completion, terminal completionok or explicit cleanup block; any late exposed stream registered/drained/joined. |
| repair1-acquired-follow | H2C100_ABORT | Original injected primary failure; `failure_abort` through exact owned controller even with no stream, then only the unused first Promise await during cleanup; exposed stream joined or explicit ownership block. No unsupported completion used as cleanup proof. |
| repair1-lost-alias-follow | H2C100_ABORT | Real first response await timeout, promise_awaitfailed; public `failure_abort`; no `failure_response`/second Promise await; case/summaryBLOCKED_HANDOFF for unresolved original response ownership; dedicated VM ends. |
| prerepair-acquired-manual | H2C98_LATE | Same injected acquisition/barrier failure, original prerepair cleanup has no stream and performs no failure cancellation or response recovery. This is the red absence of repair1's cleanup operation. |
| prerepair-acquired-follow | H2C100_ABORT | Same injected failure and exact original cleanup; owned controller/peer shutdown occurs but request cancellation/recovery remains absent. |

Require the recorded acquisition barrier and exact injected primary marker for
both repaired acquired cases and both prerepair reds. Require actual `response`
operation timeout and promise_awaitfailed for lost-alias; the outer primary error
must preserve that first failure rather than a count or environment error.
Require child exit1 for all five. Acquired repaired cases remainFAIL even if
cleanup succeeds; if cleanup producesBLOCKED_HANDOFF, preserve and report it
separately rather than claiming clean failure. Prerepair cases are expectedFAIL,
and their absence of cancellation must be demonstrated against the repaired
operation record, not inferred from exit1. No red result counts as eight-casePASS.

Original deadlines stay fixed: oracleD10s, cleanupC15s, request6s, connect2s and
first-response-await cap2s. Existing ready45s/startup cleanup60s, operation caps,
peer commands3/events128/line4096 remain intact. Cleanup uses remaining originalC;
never restart an await budget or retry a failed Promise alias. Private workers,
shared upstream pools and native reclamation remain unqualified.

## Build and parent execution

Run the builder from the worktree with Python only. It executes no VM, peer,
network, Git or dependency command:

```sh
python .audit/m3-h2-failure-regression-builder.py
```

Each probe directory contains `h2_functional_supplement.exs` and its peer with
the exact expected basename because the driver resolves its peer through
`__DIR__`. `manifest.json` describes edits/oracles and hashes.
`input-bindings.json` is a plain JSON object mapping absolute regular-file paths
to SHA256, suitable for merging into `HTTP_FETCH_TLS95_INPUTS`. It includes the
builder, this plan, pinned originals, snapshot peers/drivers, diffs and descriptive
manifest. Parent supplies the existing common172+source, wrapper, BEAM/native
bindings and pins interpreter/environment; do not use the small local manifest
as complete runtime provenance.

After independent SPEC/CODE review, parent runs each snapshot in its own dedicated
VM using the existing TLS95 identity wrapper and fixed600s collector. Set
`HTTP_FETCH_TLS95_DRIVER` to that snapshot's absolute driver, set
`HTTP_FETCH_TLS95_INPUTS` to the new merged absolute manifest and supply a new
absolute `--evidence` directory. Preserve actual argv/exit, primary/cleanup cases,
source-before/after and native before/after collector freezes. The unchanged
driver calls `System.halt(1)` after writing its negative summary, so wrapper
post-identity and wrapper outcome are **NOT RUN** for these negatives; retain
the wrapper's before-identity and do not claim a loaded-before/after comparison
that the dedicated VM could not emit. Confirm parent-owned process-group termination and
no surviving peer; lost-aliasBLOCKED_HANDOFF explicitly requires dedicatedVM
end. A timeout/environment/identity error is not the expected negative oracle.

H2 Sol1/unsuccessful0/Astra0, H1 Sol3/unsuccessful2/Astra1 and TLS
Sol4/unsuccessful2/Astra2 remain unchanged. This separate tooling task increments
no fixture repair counter and authorizes no third TLS Astra round. No local
commit, publication, deployment, normal qualification count change or production
acceptance claim is part of this task.
