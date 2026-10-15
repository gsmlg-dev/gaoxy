# Managed H2 group accounting and activation — implementation plan 1

Status: IN PROGRESS. Controlled F remains ENABLED_PENDING_ACCEPTANCE. Startup50/0, live110/0 and repaired Session46/0 have passed. Native TLS41/2 and browser zero-completed FAIL are retained; both diagnosed TLS compatibility fixes are adopted after independent source reviews, awaiting fresh runtime. Ledger8 retains20 failed GREEN attempts/23 ordered root repair events; Astra2/2 exhausted. Final FULL review, prescribed fresh gates, browser and local commit remain pending.
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

The actual pump source schema is13 keys, with session/monitor both nil before
start and both genuine after start. Apply the source-count erratum to the frozen
interface; no new role, cap or fabricated future authority is introduced.

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

Gate0 actual closure: independent readiness SPEC49/49 PASS, root-authenticated in `design-readiness-authentication1.json`; original107 sources,16 evidence and7 frozen review documents matched. All six phase sums and selected arithmetic were independently reproduced. A-D implementation and focused gates now pass. Final preactivation review is pending; public-success/live/browser acceptance remains NOT RUN until controlled F. Whole control envelopes must fit their slot before effects; preserve already owed genuine cleanup/DOWN events.

## Preactivation checkpoint — 2026-10-16

A68/0, B24/0, Session13/0, preflight9/0, transitions11/0, whole-pin6/0,
control-forms16/0, actual-cancel2/0, Probe13/0, Probe-controls21/0,
startup46/0, legacy pure454/0 and compatibility603/0 passed fresh scoped runs.
Formatting and forced strict compile exit0; all test gates joined with stable
sources and zero skips, exclusions or unexpected warnings. The preopen
nil-token regression has authenticated RED200/2 then unchanged-test GREEN200/0;
open/bind token guards preserve queued-terminal and local timeout precedence.
A reference token is necessary locally; genuine Service/G/T authority is still
established only by the real production flow.

The staged Session-control suite remains overall FAIL46/6:40 passed and six
postactivation cases stop at the unchanged literal. The separate live suite
remains authenticated intended RED106/68 with fixed38 passing; it is not a
passing acceptance gate. Before F, final SPEC/CODE review must bind the exact
source/evidence manifest. After F, all six and68 success cases and the required
browser/compatibility/isolation gates must execute and pass.

Counter custody is in `counter-ledger1.json` under this stage evidence:12 failed
GREEN attempts are retained, with every inherited and stream-local historical
counter snapshot plus ordered root repair receipts. Those snapshots are not
reset or summed as though they were one global counter. Astra2/2 is exhausted.
Negative TLS/browser cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE.

## Controlled F integration

`preactivation-review-authentication1.json` binds SPEC35/35, CODE no findings,
126 sources and16 fresh gates. The internal literal is now :ok only after
that gate. Pure foreign-transport refusal, actual invalid checkout/no owner or
transport mutation, and nil-Service-token no-open/no-bind contracts replace
old literal assertions. All queued-terminal and original identity assertions
remain. Collector28 records enabled-pending-acceptance, never accepted live
activation. Real live/browser/full independent review and fresh gates remain
required before local acceptance or commit.

## Postactivation repair checkpoint — 2026-10-16

Actual enabled runs were106 tests/19 failures and then110/10, exit2,
joined/stable with zero skips/exclusions. The second includes four added E4
handoff/partial-native-write tests. Neither run passed; Session46 was NOT RUN
because of fail-fast. The guardian-only diagnostic ran48/2, exit2, with its
expected-exit2 wrapper exiting0; that wrapper result is not GREEN acceptance.

The first live failures led to the original-handle terminal Session repair and
exact initial health HEAD upload_end consumption. Independent SPEC/CODE then
reviewed post-bind queued cancellation before ready, exact earlier POST empty
DATA/DELETE upload attribution, and the handoff test's raw capacity-to-finite
invalid_resource_pin/502 contract. The guardian test now asserts the legitimate
intermediate source pin and exact pump/lease call queued behind its held Gate;
it resumes Gate before requiring the unchanged final pins1 predicate. Service
stays held and missing cleanup receipt still requires exact failed shutdown.
The gate dependency does not identify whether that update came from a connection
poll or response rendering. Fresh runtime is required for all adopted repairs.

The owner capacity deadline repair passed24/0. Its original24/1 expiry cause
remains UNPROVED. Browser harness source review passed but all three actual
Chrome cases remain NOT RUN. Historical negative TLS/browser cleanup stays
UNCONFIRMED_WITH_RETAINED_FAILURE. No missing Service is treated as zero.

Append-only counter-ledger3.json now records15 failed GREEN attempts and16
ordered root repair events. All inherited/local counters and metadata failures
remain preserved without a guessed global sum; Astra2/2 stays exhausted.
Collector31 retains the same600-second finite deadline/nonzero-test/no-skip
policy. Next: fresh format/strict compile, live110/Session46, browser3 and all
prescribed compatibility/isolation gates, complete independent FULL SPEC/CODE,
fresh acceptance, source/index byte audit and task-owned local commit.


## Full-review and runtime checkpoint — 2026-10-16

Fresh format and strict forced compile passed, then the complete enabled live
gate ran110 tests/2 failures (exit2, joined/stable, zero skips/exclusions).
Session46 remained NOT RUN after fail-fast. FULL independent SPEC/CODE review1
authenticated175 sources and required an OTP debug-state repair, four genuine
successful startup/full-attachment overlap regressions and recovery teardown
cleanup. Independent bounded SPEC/CODE review2 source-passed the adopted
repairs; it is not runtime acceptance. The complete startup gate now expects50
executed tests, including four new protocol/downstream positive cells.

The first actual Chrome command joined exit1, source stable, FAIL with zero
completed cases. Positive native TLS/h2 navigation returned503; the real peer
saw only the successful health HEAD. Source diagnosis identifies unsupported
full OTP TLS metadata in the new group pump validator; exact runtime attribution
and compatibility repair remain pending. All navigation, original-completion,
G/T/Service byte and cleanup assertions remain required. Do not count unstarted
negative scenarios as executed or passing. Historical negative TLS/browser
cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE.

The historical browser HOST receipt identifies actual loaded BEAM from OTP
28.5.0.7. Fresh command collectors resolve an erl executable from28.5.0.5; that
PATH identity alone is not proof of their actual loaded VM. Preserve both facts
and use actual loaded-process identity for new runtime claims.

Append-only counter-ledger4 records17 failed GREEN command attempts (the prior15,
new live110/2 and browser zero-completed failure) and19 ordered adopted root
repair events. Source-draft/reviewer metadata assertion failures are separate,
retained, and not runtime passes. All inherited/local snapshots remain verbatim;
Astra2/2 is exhausted. Next: fresh startup/live/Session and prescribed scoped
gates, actual TLS diagnostic/repair and browser3, independent review closure,
fresh acceptance and a local conventional commit.


## Bounded native TLS ownership compatibility repair

The canonical actual-pump trace in native-tls-startup-diagnostic2 records the
original invalid_group_accounting result, then :ok for the identical source
with only ssl:nil. The original native owner retains the identical full SSL
value and gate. There are38 real metadata entries, including nonzero session
data and OTP callback values; arbitrary scalar-whitelist widening is rejected.
This is a diagnostic of the retained browser failure, not browser acceptance.
Its loaded VM is OTP28.5.0.7. The first diagnostic collector failed to unwrap
the public {socket,state} callback tuple and incorrectly forced inner exit0;
both the qualification FAIL and collector failure remain immutable.

Recommended design: keep full SSL metadata on the existing native H2 connection
owner/connection lease; stop copying it into each native H2 Exchange. Preserve
normal endpoint/Plug full SSL metadata through the existing authenticated
Transport.operation(:ssl_data) path, gated by real caller worker, stream ID,
original token and authoritative stream deadline. The Exchange getter returns
nil for unavailable/unauthorized/expired reads. A foreign process with a copied
Exchange no longer receives metadata; other native operations already require
the actual stream worker. H1 direct Socket access, H3 stored metadata, peer
certificate/secure data, accountant grammar and every byte cap remain unchanged.
No new process, authority, payload discount or native-memory proof is added.

Plan: independently review the producer/getter and actual-network regressions;
run the genuine regression on the old producer as intended RED; integrate the
reviewed two-file producer/getter repair; format, strict compile, and execute
nonzero accounting/native TLS/startup/live/Session tests. Real TLS/h2 cases must
retain full nonzero metadata/API/Plug/owner equality, malformed/oversized/backing
rejections, exact original completion/full16,478,862 cleanup and actual joins.
Exercise the new authoritative deadline branch with an original worker call
queued before expiry, an extended local deadline and real watchdog workerDOWN
while only the native owner is suspended; never disable the Admission watchdog.
Then run prescribed native H2, H1/H3/standalone/core-only compatibility and the
unchanged three isolated Chrome cases, resolve independent review findings,
run fresh acceptance and commit locally. The current proposal's local-expiry
case alone does not cover the authoritative owner-deadline branch.


## Joined runtime checkpoint — 2026-10-16

Fresh startup50/0 (receipt fresh-startup-reservation-1792097143408941299.json)
and enabled live110/0 (fresh-group-live-1792097246968131925.json) are actual
joined/stable exit0 with zero skips/exclusions. Session control ran46/4, exit2,
joined/stable; failures remain open. Source diagnosis identifies an undeclared
response trailer in two streaming fixtures and a nonfatal exit signal sent to
a trap-exit native owner in two owner-DOWN fixtures; runtime attribution and
reviewed repair remain pending. Exact trailer/body, original diagnostic DOWN,
original completion and complete cleanup/peer joins remain required.

Counter-ledger6.json preserves19 failed GREEN attempts,20 adopted root repair
events and all predecessor snapshots. The first native-TLS diagnostic collector
failure is retained separately and is not another GREEN attempt. Proposal2
adds actual original-worker queued ssl_data deadline/watchdog coverage and the
role-specific native peer_closed join, with production/accounting proposal bytes
unchanged from proposal1; source review does not substitute for executed RED,
GREEN or unchanged canonical browser cases. Astra2/2 remains exhausted.


## Final source candidate preparation — 2026-10-16

Session fixture repair is independently source-reviewed and actually GREEN46/0
(fresh-session-control-1792098341265691639.json), joined/stable exit0 with zero
skips/exclusions. Its exact diagnostic DOWN, trailer/body, completion and cleanup
assertions are preserved; native H2 provides the genuine non-trapping worker.

TLS ownership proposal2 passed independent SPEC/CODE2 and intended RED41/3
(native-tls-red1-1792097811580202931.json). After the reviewed owner/getter
repair, actual GREEN failed41/2; the real queued owner-deadline/watchdog test
passed. The unchanged-test exception diagnostic41/2 exposed two exact RuntimeError
get_ssl_data-not-supported messages with Gaoxy.PlugAdapter unloaded. Production
Exchange.plug_conn now ensures its own adapter is loaded before constructing
the public Plug.Conn, following independent SPEC/CODE review. The ordinary
PlugEndpoint has the same first-use path. No test-only adapter preload, weaker
metadata grammar, fake response, or assertion/time-limit change is adopted.
The original TLS test source is SHA601d497749e5daee3c4dc43d6351ddcc70abe5bda17f888be49eee5cd2be4ea3.

Counter-ledger8.json preserves20 failed GREEN attempts and23 ordered adopted
root repair events, every inherited counter, both diagnostic failures/expected
diagnostic exits and Astra2/2 exhausted. Diagnostic wrappers are not GREEN.
Collector34 preserves the600-second deadline and real exits/nonzero test/zero
skip policy, adding source bindings for the native worker, Plug adapter boundary
and supported dependency callbacks. Final-required-gates2.txt specifies25 command
gates, plus the unchanged separate three-case Chrome suite. Current source still
requires final FULL review and fresh runtime; controlled :ok alone is no acceptance.
Negative TLS/browser cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE.
