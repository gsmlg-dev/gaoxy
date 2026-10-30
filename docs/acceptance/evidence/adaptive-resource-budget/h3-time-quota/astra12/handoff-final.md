# ARB-H3 scoped recovery handoff

DONE for the implementation candidate and assigned verification. This is not
final independent review, integrated acceptance, publication or deployment.

- Mode: implementation/recovery; Astra gate: SOL_REPEATED_FAILURE.
- Evidence: inherited H3 Sol2/Astra2 failures and independent native-lifetime P1
  in `h3/recovery1/receipt.json`; fresh `native-lifetime-red` executed3/1 with
  actual budget usage0 after callback death instead of at least150 native bytes.
- Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy`, current `main` at
  `bc8a5ef5199293ada3b432c2e2741070d3b2d115`, preserving pre-existing dirty integration.
- Cumulative counters: H3 Sol2/Astra12. The fixed authorization remains
  2026-10-29T14:09:44Z through 2026-10-30T02:09:44Z; it was not restarted.
- All commands are terminal. Source writes are stopped. The parent may take
  the shared build lane and source ownership after this handoff.

## Changes and causal evidence

`QUICBridge`, `Service`, `Admission`, `ResourceBudget.Ledger`, and the small new
`QUICCleanup` module implement the approved typed native cleanup seam. A native
reservation starts pinned to Service with one actual connection membership and
funded guardian bookkeeping/process credit. One canonical split transfers the
same native obligation to a guardian while creating callback-only ownership.
The split checks max_active and all canonical growth fences. Generic request
cleanup and generic guardian membership contracts are unchanged.

Native bytes, callback bytes and their terminal boundaries are independent.
Dynamic native updates authenticate the callback lease and preserve concurrently
received guardian receipt/DOWN flags across late canonical commits. Only the
original opaque handle's exact public `QUIC.info` result `{:error, :closed}` plus
Service receipt and normal guardian termination can refund native ownership.
Unknown proof retains/fences it. Healthy connections do not inherit init expiry.
Public probes run outside Service/Admission; their underlying5s timeout remains.
No Authority, reconciler, policy, memory, sampler, dependency or H1/H2 changes.

The original helper SSE failure was separately reproduced16/1. Ordered call
trace shows session cancellation, Response.finish, immediate local host stop,
and Bridge.terminate's rejected callback admission during drain. The typed
`begin_native_cleanup` now permits only already-paid native callback state in
ready/draining mode. H3 normal terminate revokes operation capabilities and
allows cooperative workers to leave before existing forced cleanup. Its shared
window is capped at50ms and each entry's original terminal/cancellation deadline.
Existing error/peer-close paths remain forced; no peer graceful drain is added.

The original persistent WebSocket failure was reproduced2/1 with continuing
public native/queue progress. The owner processed only one round of a small
stream queue per host poll, leaving its existing32-turn budget unused. It now
spends that round-robin budget with the same100ms scheduling bound, existing
quanta and buffers. A further actual `:deadline_expired` failure exposed native
calls submitted near the end of a turn. Calls now yield unless the remaining
turn can cover their bounded allowance. The allowance is at most half the
configured callback window and50ms; normalized1/2/40ms windows have positive
progress paths. Original operation/request deadlines are never renewed; unknown
native references are still polled, never replayed.

H3 now requests the authenticated pre-reservation phase receipt. Only the exact
spawn token on the original OTP alias can establish absence. A stale cancellation
reply alone cannot do so. The old controlled cancellation assertion was tightened
accordingly. Two short-read fixtures gained a deterministic finish barrier so
additional owner turns cannot confuse a dummy worker's early exit with a real
endpoint failure; exact data/FIN and normal-DOWN assertions remain.

## Final verification on identical680-source fingerprints

| Receipt label | Actual result |
| --- | --- |
| `final-h3-compatibility` | PASS99/0; exact original18-file selection, no exclusions/skips |
| `final-core-helper` | PASS134/0; Admission60 + Owner58 + helper16, no exclusions/skips |
| `final-strict-compile` | PASS `mix compile --force --warnings-as-errors` |
| `final-owned-format` | PASS all13 task-owned source/test files |
| `final-whitespace` | PASS `git diff --check` |

Total final executed tests:233 across disjoint selections. The persistent peer
retains5MiB+300KiB+300KiB,30s per transfer,900ms quiet against300ms peer idle,
65536/16384 receive windows, exact bytes, ping, HTTP siblings, Close and no-reset
assertions. All those assertions passed both final integrated H3 runs.

`receipt-final.json` contains exact commands, environment, times, counts, exits,
log hashes, owned/protected fingerprints and parent-pending work. `task-final.patch`
is relative to captured pre-recovery bytes, not broad Git HEAD (which contains
accepted predecessor edits). It changes13 files, adds only `quic_cleanup.ex`,
and preserves667 other captured source fingerprints. Patch SHA256:
`978410bef5c8cb1ae4cce1e6f8a6ac9df0b28cb259265f25ff7b747761aee8ba`.

Expected changed-file manifest counts: quic_context3, resource_budget_admission60,
resource_budget_owner58, HTTP3 connection13, resource_budget_h3 8. No new test
files. Relative to the parent's prior377/307/154 inventory, this slice adds1 unit
and14 component cases; inventory update/validation is parent-owned, not claimed run.

## Critical boundary coverage

- `quic_context_test`: actual Service/Bridge path with controlled public observer;
  callback death retains native bytes/quota; timeout, closed-like error, accepted
  close-like result, malformed metrics and unavailable result do not refund;
  exact closed then authentic receipt/normal DOWN converges to zero.
- `resource_budget_admission_test`: callback death before split; native terminal
  before callback death; unauthorized/duplicate/expired attempts; explicit
  max_active split denial; guardian loss; API timeout then late reserve after
  callback death; ambiguous split then late commit; dead guardian before
  registration; native update late commit preserves receipt/normal DOWN; paid
  terminal callback during drain rejects new growth and ordinary leases.
- `resource_budget_owner_test`: canonical typed reserve/split identity and quota
  conservation, dedup, stale revisions, expiry and foreign actors; Service death
  during pending native initialization remains pinned as guardian ownership.
- `resource_budget_h3_test`: original alias survives polls; stale cancellation
  cannot establish absence; exact versus mismatched phase token; existing native
  metric and admitted worker lifetime assertions.
- `connection_test`: original buffered-read/FIN assertions plus normalized
  minimum/small callback-window progress, yield and original-deadline checks.
- Original real QUIC protocol suites independently verify normal public network
  behavior, worker crash isolation, active service removal, cleanup and port reuse.

Controlled observer/canonical tests are not proof of killing a real native
engine. System/process allocation exhaustion was not injected (excluded pressure
work); dead-before-registration and fail-closed source handling cover the bounded
registration-loss contract. No production private engine PID was extracted.

## Historical failures and remaining parent work

Every failed/diagnostic receipt and log remains in this directory. No assertions
were weakened or failed evidence overwritten. `helper-sse-order-trace` executed
zero tests because Mix does not support --require; the subsequent `mix run`
wrapper recorded the actual16/1 trace. Intermediate fixture failures, scheduling
expiry,98/2 controlled-fixture run and all original failures retain their statuses.

Parent owns final independent review (including the repaired P2 deadline cap),
manifest/inventory edits, installation/qualification of its finite connection
churn draft, fresh integrated qualification and authorized delivery. No commit,
push, release, package publication, production operation or new worktree occurred.
No unresolved upstream dependency blocker was established. Exhausted historical
Sol counters are not reset; continued repairs remain governed by the existing
explicit time-window authorization and parent ownership routing.
