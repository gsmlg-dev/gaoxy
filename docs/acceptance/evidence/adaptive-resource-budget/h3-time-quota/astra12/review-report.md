# ARB-H3-REVIEW — final frozen candidate

DONE for independent source/spec review and verification of existing terminal
receipts. **PASS within the frozen H3/native cleanup and ordinary test scope:**
original native-lifetime P1 and interim deadline P2 are resolved. No remaining
actionable source finding was established. This is not whole-goal, release,
deployment or product acceptance beyond the reviewed scope.

Direct Sol review, reviewer Sol0/Astra0; received implementation Sol2/Astra12.
Repository `/home/gao/Workspace/gsmlg-opt/gaoxy`, existing `main`, baseline
`bc8a5ef5199293ada3b432c2e2741070d3b2d115` plus preserved dirty integration.
Only `native-final-review/` was written. No source/test/manifest/dependency/Git
mutation or build/test/BEAM/runtime/network command was performed by reviewer.
All commands are terminal; no task runtime was created or left running.

## Frozen identity

Canonical task patch SHA256:
`978410bef5c8cb1ae4cce1e6f8a6ac9df0b28cb259265f25ff7b747761aee8ba`.

Review used `recovery3/candidate-task.patch`, captured `before/` snapshots and
current source, not the broad Git diff containing earlier accepted CORE/H1/H2
work. Reconstructing the delta from the thirteen captured-before/current files
produced the exact canonical patch. All680 candidate full-input hashes matched
live source before and after review: thirteen task-changed inputs and667 protected
inputs. The four final format/compile/H3/CORE-helper receipts independently
record those same680 hashes, with no changes during execution. Per-path hashes
and reviewed source snapshots are retained in this directory.

## Closure and ownership contract

**Native P1 resolved.** `QUICBridge.init:15` creates a typed connection and asks
Service to reserve native ownership before handler initialization. Service
retains the original opaque handle in the prepared guardian state and
Admission authenticates the registered Service. `Ledger.reserve_native:592`
creates a Service-pinned guardian allocation containing measured native bytes,
bookkeeping bytes, one actual connection membership and one pending process
credit. Callback death cannot release this allocation.

`Admission.split_native:695` binds the guardian's terminal observer before the
canonical mutation. `Ledger.split_native:616` changes owner/revision on the same
native token, preserves byte categories and the one connection membership,
consumes the funded process credit, and creates an empty callback transport row
in the same canonical transaction. Ordinary lease, byte, connection and Safety
bounds retain their existing checks. Guardian rows do not consume an ordinary
legacy lease slot or invent request/connection memberships.

Native and callback lifetimes retire independently. Authenticated native
replacement uses the normal sequence/revision/generation/deadline fencing;
its late commit merges only byte/accounting fields into the **current** cleanup
record (`Admission.update_native:792`), preserving concurrently observed receipt
and guardian terminal flags. Ambiguous mutations retain their canonical
operation identity and pending obligation through reconciliation. Failed split
or dead registration leaves the pending native reservation charged.

`QUICCleanup:56` only probes while activated with a triggered finite cleanup
deadline. Healthy persistent connections have no inherited init lifetime.
Closed notifications and callback DOWN trigger inspection, not a refund. The
probe uses the stored connection/original public handle; only exact
`{:error, :closed}` enters `Service.complete_cleanup`. Timeout/unavailable/
malformed/wrapped-closed results cannot substitute. Public info's fixed5s call
remains outside Admission/Service critical handlers and is not falsely described
as shortened by the outer deadline. Repeated triggers keep the earliest guardian
deadline. Service authenticates the registered guardian; Admission authenticates
Service. Adaptive `settle_cleanup` requires receipt plus normal guardian DOWN.
Guardian/Service loss without proof retains/fences canonical ownership; the
existing Reconciler requires exact-token guardian proof. Callback DOWN/EXIT can
only retire the independent callback row.

**Interim P2 resolved.** `Connection.settle_local_workers:145` first revokes
Operations capabilities and uses one shared maximum50ms deadline. Each worker
wait is additionally capped by `terminal_deadline(entry)`, which retains an
existing cancellation deadline. Iterating workers cannot renew that shared
window. `begin_native_cleanup` authenticates a marked native callback lease,
allows ready/draining only, and admits at most its existing paid callback bytes;
ordinary leases and growth remain rejected. The already established forced
fail/peer-closed `clear -> kill` semantics remain intact; no general graceful
peer drain is claimed or required.

## Bounded H3 progress and terminal proof

`progress:173` now spends the existing configured round-robin budget even when
there are fewer streams than turns. `turns:333` still exits on zero turns,
empty queue or the original per-callback absolute turn deadline. Options bound
turns to32 and control/output quanta to16KiB; existing buffers, credits and flow
control are unchanged. The finite repeated turns do not add an unbounded retry
loop. Unknown native operations retain their reference and original deadline;
subsequent turns poll status, not resubmit. Definite blocked operations remain
bounded; rejected/unexpected results retain existing failure/cancellation paths.

`operation_options:1348` derives a positive timeout from half the configured
callback window, capped50ms and floored1ms. Calls yield when remaining turn
headroom is insufficient, and already expired operation deadlines fail before
calling native APIs. The relative native deadline is derived from the existing
minimum of operation/turn absolute deadlines; neither is renewed by the helper.
Controlled normalization/usable/yield/expired assertions cover1/2/40ms callback
windows. These are deterministic helper coverage, not a claim of real-network
service qualification at a1ms callback budget.

H3 now requests authenticated `:phase_receipt` spawn results. Only the original
OTP response alias with its exact token and pre-reservation expiry can mark
`:not_reserved`. A stale cancellation error or wrong token cannot establish
absence or refund resources. Repeated retirement polls retain uncertain
ownership. Final alias disposal on stream deletion does not invent terminal
proof. Admission's pre-reservation phase receipt contract itself predates this
H3 delta and was preserved.

The two controlled short-read workers now wait on explicit `:finish` barriers.
Exact buffered DATA, FIN, trailers, cleared read operation and normal DOWN
assertions remain; this removes premature fixture teardown under multiple owner
turns rather than weakening product assertions.

## Actual existing verification

Reviewer checked receipt fields, raw-log SHA256, positive count lines, source
identity and terminal status; reviewer did not rerun these commands.

| Final receipt under recovery3 | Actual evidence |
| --- | --- |
| final-h3-compatibility.json | 3 CORE context +96 H3 =99 tests,0 failures, exit0 |
| final-core-helper.json | 118 Admission/OWNER +16 helper =134 tests,0 failures, exit0 |
| final-owned-format.json | Check-formatted on thirteen owned files, exit0 |
| final-strict-compile.json | `mix compile --force --warnings-as-errors`, exit0 |

All four report commands terminal, no skipped/excluded cases and no source
changes. Format/compile are checks, not positive-test evidence. Both test runs
match the entire680-input candidate and retain their actual scope.

The frozen H3 run includes the unchanged original WebSocket network file:5MiB
and300KiB payloads, original30s response bounds, exact echo/close assertions and
normal application termination. Earlier2/1 WS/helper/native failures remain
historical; the final same-source run includes those ordinary compatibility
checks. The earlier native-partial-init121/0 and minimum-window13/0 receipts were
also hashed; the final runs include their current cases. Earlier receipts with
context differences are recorded as such and not presented as whole-frozen
qualification.

Critical native coverage is explicit:

- Admission: callback death before split; native-first/callback-first terminal
  orders; foreign/duplicate/stale/expired mutations; max_active rollback;
  guardian kill; ambiguous reserve and split late commits; dead guardian before
  registration; late native update preserving receipt/DOWN; paid-only drain.
- OWNER: exact split token/revision/operation dedup and unchanged totals/quota;
  registered Service owner death leaves its pending guardian row charged and
  prevents orphaned split.
- Context: actual Service/Bridge/guardian composition with a controlled original-
  handle public observation seam; timeout, wrapped-closed, malformed and
  unavailable results retain charge; exact closed proof permits eventual zero.

The context case opens controlled real TCP and remains component coverage.
The OWNER Service-death test is controlled canonical ownership evidence, not
exhaustive real-Service failure injection at every instruction. Actual process
exhaustion/pressure injection and specialist slow-peer/load proof were not added
or required. No private native engine PID is inspected by the implementation or
new lifetime reproduction.

## Parent integration and limits

A transient reviewer classification concern was retracted after reading the
manifest suite header: `quic_context_test` is already component, not unit.
Pending measured manifest counts are parent-owned integration, not source defects.

Full `ConnectionTest` inspection found no real listener/socket/peer or complete
runtime: it uses pure codec/Options state, ETS, controlled workers, and one
isolated budget-less Admission instance. Its new ordinary headroom regression
can be promoted from `existing_not_scheduled` to unit with measured count13,
while preserving all tests. The inventory validator requires `@moduletag :unit`;
that annotation is absent in this frozen file. Parent owns that separate exact
annotation/manifest/inventory delta and its refreshed fingerprints/checks; this
review does not pretend the annotation leaves the source hash unchanged.

Remaining whole-goal work stays separate: churn draft installation/runtime,
manifest/inventory integration, final combined canonical/Phoenix/source-built/
package checks, parent fresh verification, release/publication/public read-back.
No native macOS/Windows or deployment proof is inferred. Later installation of a
new churn test plus manifest metadata does not alter these thirteen reviewed
source paths; any later edit to them needs an explicit delta review.

No new source repair, architecture decision, permission or escalation is needed
from this reviewer. Preserve the frozen source and proceed with the parent-owned
integration/verification gates. Reviewer writes and work stop at handoff.
