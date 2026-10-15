# Managed H2 group accounting and activation — implementation plan 1

Status: ADOPTED, independent design review pending; all implementation/runtime acceptance NOT RUN.
Root owns adoption, repository/runtime/evidence/index/Git and coordinates source-only authors/reviewers.
Design: [accounting/activation](../designs/m3-managed-h2-group-accounting-activation.md).
Base: resource-foundation worktree, committed queued-terminal guard `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`, tree `a26656f16425d35ccc08584ee0486abb296a3c39`. Its prescribed gates, independent reviews and local commit passed.

## Gate 0 — source freeze and independent plan review

Root records committed guard SHA, cumulative Sol/Astra counters, clean owned
scope and unrelated edits. Refresh affected source hashes; preserve all guard
assertions/evidence. Adopt concrete design into repository stage design/plan
documents and append explicit capability status: managed-H2 groups still disabled.
Have a separate Sol independently review source-role completeness, proposed
finite caps, arithmetic, original-capability identity and ownership mapping.
Resolve actionable findings without weakening assertions. No third Astra.

The proposed phase maximum is7,033,906; request/full normal H2 probe reserve is
16,478,862;32 cleanup reservations527,323,584;4 probes65,915,448. Startup uses
the existing Admission.adjust_bytes lease API for5,963,776 extra bytes before
allocation/start. Startup+attach temporary overlap22,442,638 per request excludes
ordinary lease payload;32-way overlap718,164,416 also excludes that payload.
These are proposed enforced
cap arithmetic, not measured/runtime acceptance. Run an executable independent
arithmetic check and source-table tests before claiming the contract verified.

## Ownership and dependency schedule

Root owns all actual repository writes until explicitly assigning disjoint
writers; everyone is not alone and preserves others' edits. These are exclusive responsibilities for root integration; authors write only assigned /tmp drafts unless explicitly reassigned. They are not alone and must preserve others’ edits.

| Task | Exclusive production/test responsibility | Dependency |
| --- | --- | --- |
| A — accountant | new managed_h2_group_accounting.ex and focused accountant tests; contract/phase caps, exact original validators, owner record projections, checked opaque shells | gate0 |
| B — profile/owner | upstream_groups/options.ex, upstream_groups.ex; Options/group/probe owner admission tests; H2 group handle/prepare/probe record/charges | A interfaces frozen |
| C — HTTP/Session | group_endpoint.ex, http.ex, http/session.ex; group Session/public proxy/client/reserve/no-effect/lifecycle tests | A plus B profile shape frozen |
| D — Probe | upstream_groups/probe.ex and probe boundary/argument/runtime tests | A plus B provisional admission schema frozen |
| E — fixtures/gates | shared real peer/browser fixtures and matrix tests; runtime commands/evidence remain root-owned | fixtures/tests first; live execution after F controlled gate change |
| F — activation/docs | managed_h2_group_boundary.ex controlled literal-gate change; stronger activation contracts, stage docs/capabilities | A-D production integration and preactivation gates/review; then E live gates, FULL SPEC/CODE and fresh acceptance |

Do not let B/D both edit upstream_groups.ex. B owns all owner callbacks; D sends
required callback-contract changes to B. C alone owns Session and its tests.
Shared fixture edits serialize through E. Root alone stages/commits. Pure A
tests may run alongside disjoint source-only author/reviewer work; builds/runtime
commands serialize with root's build/evidence ownership. Never share `_build`
writers without the root's agreed separate environment.

## Task A — tests-first finite accountant

RED: production API missing/denies intended valid real roots; table bytes, exact
schemas and cap/refusal invariants are asserted independently of implementation.
Create finite real C/Q/K/H/pin constructors from supported public validators;
do not use synthetic oversized garbage as the only admission test.

Implement contract and pure source projectors with bounded traversal before
external_size. Assert every allowed actual state field, including nil/staged
alternatives and finite control family, is either fully charged or assigned to
a named unchanged fixed role/opaque shell. Preserve original equality and no
unknown-map-key acceptance. Measure complete containing values once per role.

GREEN tests cover:

* all six phase sums, independent max/formula, fixed base unchanged; no optional
  argument discount; full same probe charge;32 and4 totals;
* real maximal C/Q/K and32 Ts; logical/backing-heavy binaries, bad proper-list
  tails/counts, expanded structs/maps, invalid signed times and PID/ref shell
  cap rejection; known opaque interiors never serialized;
* exact boundary N/L/X/R/O, pre/post staged S, P/source pins/handoff; identity
  mismatch before measure; compact original target/query handling;
* complete captured pins and public I wrapper including per-owner batching;
  cap and one-over tests for public admission/control/config budget where
  values are representable; do not require unattainable exact ETF size for a
  structurally impossible role; role-over-cap cases still retain exact shape;
* H2 complete config/control record charge includes compiled plus runtime
  member configs; stable self-accounting-field convention; finite dynamic
  health/recovery fields and exact add/subtract delta without drift. H2 group
  config charge is initial complete record ETF (excluding only self bytes)
  plus131,072 bounded mutable-control growth reserve. Threshold-saturating H2
  counters and signed64 checked/due times retain health behavior and bounds.

Source review maps actual public supervisor source constructors and init input/
state to A/W/S. Do not add22 startup-catalog charges or make private runtime/
stack/diagnostic proof a prerequisite. Confirm proposed caps fit actual maximal
valid source constructors; if a valid intended constructor cannot fit, revise
cap/arithmetic explicitly before owner/HTTP integration.

## Task B — tests-first H2 Options, prepare and owner ledgers

RED public API tests: valid homogeneous H2 currently refused; mixed protocol
refused; real raw root/protocol/instance validation; H1 existing inputs unchanged.
Assert generated exact8 H/resources validate and correct max_url_bytes. Include
struct recompile roundtrip; IDs/health path compact without H1 narrowing.

Implement owner complete H2 config projection/actual byte admission against
existing config limit; internal16,777,216 H2 control ledger and per-record caps.
Install original complete pin/token/probe/recovery record charges before their
effects. Retained counters/health state updates stay within their stable group
record charge and control-ledger deltas update atomically. Return no
handle/pin/token/child when denied. Preserve actual original caller/guardian auth.

RED public probe tests: failed capacity creates no child/open; provisional
full16,478,862 charge precedes start; successful claim requires genuine PID and
owner/group/token; start failure refunds exact provisional entry; no double
refund for late DOWN/finished/recovered; uncertain cleanup retains charge.
Wrong guardian cannot bind/finish. Nil prebind completion remains fail closed.
G recovery success and T-held token coexist without cross-ledger early refund.

Probe launch candidates may construct bounded A before admission; no child/open
until byte/count reservation succeeds. Record full entry bytes at admission;
never recompute a guessed reserve during removal. Test fairness/probe cursor
and health transitions through genuine owner records, not private-state stubs.

## Tasks C/D — tests-first public routing, startup and staged ownership

C RED: GroupEndpoint with managed_h2 H selects ManagedH2Client in both pump and
Session from the outset. Public successful request uses compact neutral6 and
full group reserve, preserves absent/empty query and absolute-target behavior.
Denied startup reserve produces no child/selection/open/bind. Use existing
authenticated Admission.adjust_bytes to reserve startup5,963,776 on the real
request lease BEFORE neutral copy/startup allocation. Validate A/W/init S, keep
preactivation token nil, cancel and join child on Service attach denial; refund
startup only after the args-owning helper returns. Keep startup charged during
the full cleanup attachment and possible immediate activation, then refund in
the outer caller after source-role transfer. Test intermediate exact lease/
cleanup totals and no early refund for ambiguous cleanup. Do not just assert an
internal reserve callback value. Service/Admission needs no new public API.

C/D implement original-role validators at design insertion points: initial
source/pins/P/A/W, init S, selected L/state S, pin response I, checked K/state S,
boundary N/L/X/R/O and sanitized S, then O/U/S at open/result/bind. Every failed
post-checkout transition preserves genuine cleanup and held ledger visibility.
Retain queued cancel/deadline/DOWN guard before open and bind. Preserve the
original supported handle capture even for invalid/late success.

D RED: genuine normal H2 health Probe enters actual claim/pin/checkout/prepare/
open/bind flow after B admission and validates every initial/staged S; HEAD has
empty fields/no upload body, effective limits and absolute finite deadline.
Recovery child uses original opaque completion and charged finite shell only;
it cannot impersonate the guardian or enable a group request.

Test early local invalid controls, queued terminals and bind failures for no
upstream side effects or genuine confirmed cleanup as appropriate. Assert full
ledgers/counts, original handle/completion identity and sibling availability.
Avoid tests mirroring a pure helper while missing production call-site routing.

## Task E — real peers, browser, compatibility

Root runs scoped suites only, with finite deadlines and barrier-based lifecycle
synchronization. Reuse actual accepted fixed peer infrastructure as appropriate;
extend surgically for groups rather than substituting fake success clients.

Required live coverage:

1. Real independent h2c and TLS H2 upstream peers; initial health Probe causes
   healthy selection, HEAD reaches peer, unhealthy threshold blocks selection,
   recovery re-enables selection; retirement drains with no stale admission.
2. Existing required four-cell native downstream H1/H2 matrix to each managed group protocol;
   H1->TLS-H2, H1->h2c, H2->TLS-H2, H2->h2c. Preserve affected existing H3
   Session/FramedResponse and standalone compatibility; no new H3 group wire
   capability claim is made by this package. Cover methods/target/query/field
   semantics, selected root identity, bounded upload,
   response DATA/trailers, effective selected limits and no replay.
3. Capacity test holds C2/R32/P0 with real peers and barriers, verifies32 actual
   held requests, group and T caps, full Service bytes; one-over denial produces
   no extra peer request. Configure sufficient Service budget explicitly for
   the new527,323,584 cleanup total plus ordinary lease payload and observed/
   bounded startup overlap (up to718,164,416 cleanup+startup across32 requests),
   instead of weakening R32/count assertions. Distinguish cleanup sum from
   total Service high-water; preserve actual max-bytes checks.
4. Cancel/deadline/queued terminal before open and bind, handoff failure,
   guardian/service/gate loss, real connection/stream failure, partial/timeout
   writes and cleanup uncertainty; original completion confirmed where expected,
   held ledgers visible where not; unaffected sibling progresses.
5. Local real browser through a supported local downstream route to managed-H2
   group, with observed network result and actual peer receipt. Run the stage's
   required browser matrix inherited from fixed H2: positive /probe navigation,
   streamed /stream and /early bodies with h2 network/peer receipts, plus exact
   negative CA/name h2/502/Content-Length0/loadingFailed and browser error-page
   semantics. Preserve UNCONFIRMED_WITH_RETAINED_FAILURE for negative cleanup
   when applicable, with the actual group reserve/held-token timeline and failed
   joins; never relabel a missing Service as zero. Use only local test certificate
   trust scope. Separate browser receipt from raw protocol receipts.

Compatibility gate includes existing scoped group H1, fixed H2 and H3 proxy/
standalone tests required by this goal, existing lifecycle guards and core-only
consumer isolation. Do not run unrelated repository-wide suites by default.
List unrelated failures visibly; parent decides scope rather than silently
fixing or relabeling them. No release-artifact E2E enablement or hosted quota work.

## Task F — stronger activation contracts, independent review, fresh gates

Locate all old literal `accounting_not_ready` assertions, including group
boundary and new preopen-control tests. Until final activation keep them passing.
At activation replace them with stronger tests of actual public invalid/capacity/
unauthorized no-effect denial and actual accepted forwarded request/probe flow.
Keep the same queued-terminal/no-open/no-bind and capability-identity assertions.
Assert fixed-endpoint contract remains9,444,956 and H1/H3 behavior unchanged.

The controlled final integration gate change precedes real live gates so those
gates can execute without a test-only bypass. It is not accepted activation or
a local acceptance commit until complete live/browser, FULL independent review
and fresh gates pass. It is not an API claiming standalone profile authority. Real
Service cleanup activation token, live resource pins, owner/instance validation,
selected group/T admission and finite phase checks must all be in the actual
production path before open. Keep activation internal and deterministic.

Independent Sol SPEC review: each product/checklist clause to actual source,
role/phase coverage and ledger/refund release points. Independent Sol CODE
review: schema/authority/control safety, effects ordering, cleanup/capacity and
test validity. Resolve findings, retain counters/historical evidence, then root
runs fresh full prescribed scoped tests plus live/browser/compatibility gates.
Record exact source/hashes/environment/commands/counts/exits and PASS/FAIL/
BLOCKED/NOT RUN distinctly. No claim based on this unexecuted design alone.

After every prescribed gate/review passes, update stage acceptance and capability
docs, local conventional commit(s) of owned scope only, then continue next
authorized product stage. No push/publication/deployment in this package.

## Failure and shutdown protocol

Unexpected implementation/test failures enter diagnosis and targeted repair;
preserve assertions and evidence. Continue inherited counters across handoffs;
no counter reset/new third Astra. No dismissed http_fetch#97 or equivalent
replacement requirement. Report genuine external blockers as BLOCKED_ENV, missing
required product/architecture decision as BLOCKED_DESIGN; do not invent either
because a local test failed. Every own command must finish/stop safely before
handoff; never touch others' processes/worktree/index or stash/reset their edits.

## Selected source-preflight corrections

The actual verified guard commit/tree and corrected design are now bound by the stage kickoff receipt. Source preflight changes are incorporated; optional wider caps are not selected. Preserve existing aggregate
HTTP captures<=64 entries/65,536 bytes, unrelated/nested captures and real G7/T8
public pin schemas.33 applies only to the selected group's own dependency set.
Keep original proposed role caps and arithmetic; no optional capture widening.

Tests must use actual Session args10 with all matching G provider pins, normal
Probe args7/state23 and recovery args4/state5. Include real64-resource and nested
Generation captures, maximal original P/A/S branches and complete32-member
group/control update variants. Reserve conservative provisional owner charges
before timer/monitor/child effects, install actual identities, reconcile exact
charges and test rollback/duplicates. Keep probe.bytes distinct from new exact
self-accounting control_bytes. Pass genuine key/index into probe launch.

Validate W through actual A plus the supported source-derived wrapper bound;
future internal monitor/call refs are not available for pre-call inspection.
Init must not call the synchronously blocked owner. Preactivation gates cover
constructors/schema/capacity-denial/no-effect and production source review;
genuine public-success tests stay authenticated RED until the controlled
literal gate change, then all success/live/browser/review/fresh gates must pass.
