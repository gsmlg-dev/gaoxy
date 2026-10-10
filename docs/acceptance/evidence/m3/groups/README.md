# Task 5 dedicated HTTP/1 group implementation checkpoint

Worker `/root/upstream_cleanup`, direct assignment, worktree `.trees/m3-gateway`,
branch `codex/m3-gateway`, baseline `22b76e8051ddaf09e36797cb781b9b119870a9d4`
plus preserved shared M3 changes. No worker commits/publication/dependency patches.

Status: focused implementation checkpoint PASS; post-publication release
deadline repair and narrow independent re-review PASS. The separate final
independent Task 5 review remains OPEN. This is not final Task 5,
full M3, hosted CI or production acceptance.

## Actual verification

All commands ran in `nix develop`, `MIX_ENV=test`, `ERL_FLAGS='+S 2:2'`, from the
worktree root, with the parent granting exclusive umbrella Mix windows. Tests
used `--warnings-as-errors --max-cases 1` unless the recorded focused red differed.

| Evidence | Actual outcome |
| --- | --- |
| `initial-red.log` | Expected missing implementation: HTTP 2/2 and proxy 3/3 failures, seed 869135, exit 2 |
| `initial-compile.log` | FAIL: own Router `compile/1` clauses separated by a helper, strict warning, exit 1 |
| `repair1-compile.log` | PASS after clause grouping, exit 0 |
| `initial-green.log` | HTTP 14 and proxy 3, all zero failures, seed 910194, exit 0 |
| `retired-bound-red.log` | Expected new contract red: 1 executed/1 failure, 5 excluded, seed 866013, exit 2 |
| `handle-identity-red.log` | Expected new capability red: 1 executed/1 failure, 5 excluded, seed 93061, exit 2 |
| `expanded-compile.log` | PASS strict compilation of current source, exit 0 |
| `expanded-initial.log` | FAIL: HTTP 21/0, proxy 59/3, seed 311044, exit 2; three new fixture defects |
| `expanded-fixture1.log` | PASS: HTTP 21/0, proxy 59/0, seed 709212, exit 0 |
| `expanded-source.sha256` | Frozen worker-owned source/tests for the passing expanded checkpoint |
| `activation-release-deadline-red.log` | Expected receipt-contract red: 1/1 failure, seed 1281, exit 2 |
| `activation-release-repair1.log` | FAIL overall: HTTP 22/1, proxy 20/1, server 18/0, seed 618354, exit 2; new receipt regression passes, two immediate-release fixture assumptions fail |
| `activation-release-fixture1-rfc.log` | PASS Generation/group/server scope: HTTP 22/0, proxy 20/0, server 18/0, seed 806307, parent session 23961 exit 0; historical RFC tool checkpoint is not final RFC acceptance |
| `generation-release-rereview.md` | PASS narrow independent specification/quality re-review; current source hashes and unchanged counters recorded |

Expanded HTTP scope: Generation resources (6), trusted loader (3), existing
Generation compatibility (12). Expanded proxy scope: group owner/proxy/probe/TLS
(20), existing HTTP runtime/wire/TLS and Forward compatibility (39). No umbrella
suite or unrelated module fixes were performed.

The three expanded initial failures were fixture defects: the opening-timeout
peer waited for a response command rather than observing its already-closed
socket, and both TLS tests named nonexistent `server.pem`/`server-key.pem` rather
than generator `cert.pem`/`key.pem`. Corrections retained all closure, identity,
trust and no-replay assertions. A helper now exits normally when its listener is
closed during test teardown. Existing deliberately killed-instance callback
logging remains visible in the passing compatibility evidence.

Counters: cumulative Sol repair/validation rounds 2, both successful (compiler
clause-order correction, then fixture correction); unexpected production
behavioral repair rounds 0; Astra rounds 0. Agreed TDD red tests are not unexpected
implementation failures. All worker commands finished before source/test freeze
and Mix release to parent.

## Qualified checkpoint behavior

- Strict/idempotent origin-only member configuration, owner record/config/pin
  capacity, isolated owners, authenticated pins/tokens and exact immutable
  handle identity (including the worst-case URL reservation bound).
- Real HEAD health establishes unknown eligibility; three failures remove a
  member and two successes restore it. Freshness, one held probe, separate slot
  and byte budgets, instance cancellation and opening timeout execute on peers.
- A suspended probe guardian retains its byte/slot allowance after the response
  until it confirms the real public completion result.
- Static/nested Router resource deduplication and malformed/oversized sidecars;
  mutable Generation pinning; compiled-router/name startup without Endpoint.init
  repetition; failed/late candidate acquisition leaves the current router.
- Old snapshot paused before checkout survives reload and retirement, then hits
  its exact old peer while a new request hits the exact new peer. Request-holder
  death does not free a live guardian token; unbound guardian death fails closed.
- Shared HTTP pump produces saturated 503, manual redirect and one-attempt
  connection failure. Suspended public response stream keeps real completion
  pending through downstream reset/guardian death; completion-only recovery
  refunds the group slot after public proof. Group opening/idle/total expiry and
  existing shared-pump write deadlines pass.
- Real TLS HEAD and request preserve localhost SNI/Host while dialing numeric
  127.0.0.2. A switched upstream certificate rejects against immutable client CA
  without fallback or retry. No upstream pooling/H2 qualification is claimed.
- `Generation.prepare_with/3` uses the existing single preparation worker,
  closure/loaded-input bounds, absolute deadline, busy slot and caller monitoring.

## Resolved parent receipt finding

Parent production repair 1 records retired pins and returns the committed
activation receipt before old-provider release. Reconciliation releases one pin
per dispatch and rotates uncertain releases with a 100 ms delay. Pending retired
pins still reject another activation with `:resource_release_pending`, keeping
the published router and sidecar bounded. A controlled held-provider regression
proves the 50 ms activation receipt is delivered before old release completes.
Parent fixture contract update 1 changes two immediate metadata assertions to
their existing finite one-second `eventually` helper, preserving exact zero-pin
and `:retiring` assertions. The whole first repair validation remains FAIL;
the second scoped command passes. `generation-release-rereview.md` closes this
narrow finding after independent specification and quality review. Worker
cumulative rounds remain 2, behavioral repairs 0, Astra 0; no third worker repair
was attempted. `expanded-source.sha256` is the earlier checkpoint, not the
current parent-repaired Generation source.

The accompanying historical 39-case RFC tool checkpoint has a later-discovered
incorrect PRIORITY-length expectation; final RFC acceptance depends on the
parent's corrected 40-case rerun and is outside this narrow re-review.

Read-only timeout follow-up confirms huge common group limits are clipped to the
Exchange request deadline before Session timers. The normal HTTP request bound is
30,000 ms. Making the HTTP request timeout itself huge first reaches the existing
Admission timer, before endpoint activation; no group-specific timer failure was
demonstrated or assigned. No speculative group timeout repair was performed.

HTTP Fetch 0.19.1 public completion APIs remain the implementation boundary.
`gsmlg-dev/http_fetch#66` blocks pooling and #67 blocks upstream H2 upload trailers;
existing upstream TODO callsites remain. Parent owns independent review, any
bounded follow-up handoff, standalone schema wiring, final acceptance and commits.
