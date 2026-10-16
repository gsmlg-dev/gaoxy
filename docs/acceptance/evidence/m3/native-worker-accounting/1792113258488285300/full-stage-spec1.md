# Full-stage native worker specification review1

**FAIL — three actionable gaps in prescribed lifecycle acceptance.** Static tracing found no separate production specification defect. This is a completed read-only review, not a test execution or stage-completion claim.

Task `native_worker_full_spec1`; direct independent assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `58307a7084298db309a93697b9102b2cc4c87eda`. Candidate `full-stage-candidate1.json` SHA256 `9ee11ab2c847c90ef64ce8c4766d116563380ee24a1c368d9e967d1c70766982`. Root owns repository/runtime/evidence/Git; reviewer wrote only the two assigned `/tmp` reports.

## Findings

### F1 [P1] missing_prescribed_lifecycle_race_acceptance

Requirement: `docs/plans/m3-native-worker-startup-accounting.md:40,90-91; Task1 and Task3`. Evidence: `apps/gaoxy/test/admitted_spawn_test.exs:228,245,444,471; apps/gaoxy_http/test/http2_worker_startup_test.exs:320; apps/gaoxy_http/test/http2_stale_start_test.exs:19`.

No deterministic barrier covers original-owner death after activation before native success processing, or after success before dispatch. No authenticated cancel is tested after activation before response processing. The only delayed old async native receipt is an error; no late canceled genuine success is exercised. Existing alias-retirement cancel is issued before release_barrier, so it is pre-activation.

Required repair: Add test-owned barriers on these exact cuts using genuine Gate-produced success, authenticated cancellation and real worker monitors. Prove zero endpoint dispatch on winning death/reset/cancel, current/queued identity preservation, exact current W+B retained until genuine child DOWN+EXIT, sibling preservation and final single refund. Include late-success/stale/repeated cancellation handling as prescribed; preserve existing tests.

### F2 [P1] missing_activation_revalidation_acceptance

Requirement: `docs/plans/m3-native-worker-startup-accounting.md:94`. Evidence: `apps/gaoxy/test/admitted_spawn_test.exs:135,149,301; apps/gaoxy/lib/gaoxy/admission.ex:490-508`.

Paused/draining and expired-deadline tests reject before spawn; the watchdog test starts after endpoint entry. No test commits a real charged child, then changes Gate to paused/draining or lets original D expire before its activation callback. These distinct next-callback revalidation branches are marked checked without runtime proof.

Required repair: Hold an actually committed pre-activation child, apply pause/drain or expire original D, then release the authentic continuation. Require finite refusal, zero target/endpoint entry, genuine child DOWN+EXIT and retained ordinary charge until that pair, with exact once refund and no orphan.

### F3 [P1] missing_native_service_shutdown_acceptance

Requirement: `docs/plans/m3-native-worker-startup-accounting.md:94`. Evidence: `apps/gaoxy/test/admitted_spawn_test.exs:335,360; apps/gaoxy_http/test/http2_worker_startup_test.exs:536`.

Isolated Gate-stop tests establish core termination, and the native queued-close case establishes peer-close before child admission. Native/browser Gaoxy.stop calls occur after request cleanup/global zero. No real service stop while a newly admitted worker is pending/waiting for dispatch or blocked inside endpoint asserts the required worker, native connection, writer and listener joins.

Required repair: Add scoped real native service-stop cases at the pending/bootstrap and active endpoint cuts with finite genuine actor monitors, listener closure and actual zero/confirmed cleanup. A fixture on_exit cleanup or isolated Gate stop is insufficient for this explicit service acceptance item.

## Entire-stage coverage

- **Task0: PASS** — Current path/HEAD/branch/status, frozen manifest and protected files; retained predecessor closure and source-bound public primitives.
- **Task1: FAIL_MISSING_REQUIRED_TEST_CUTS** — Actual pre-admission W calculation, generic scalar API, public atomic link+monitor spawn, postcommit activation, authenticated native success and complete dispatch implemented. F1 identifies missing late-success/race acceptance.
- **Task2: PASS_REBOUND** — Exact unchanged95-role constructors,12 reports, signed/ETF widths, full initialized valid public default/large endpoint, P+A+J and W equation; prior SPEC2 then CODE1 then fresh9/0 checkpoint precedes W execution.
- **Task3: FAIL** — Real W-1/exactW/active limit, ownership, pre-activation barriers, owner normal/abnormal endpoint death, Gate kill/normal stop, actual OTP parent closure, reverse child failure, authentic paired DOWN/EXIT current W+B and duplicate normal terminal behavior covered. F1-F3 remain required.
- **Task4: PASS_EXISTING_INITIAL_GATES_WITH_F1_RACE_GAP** — Raw native H2 full endpoint/exchange and exact capacity, original canceled3/current5/queued7 failure regression, Gate-paused PING/RST parse+resume wireACK, Gate-running stalled endpoint responsiveness, returned-trailer exact admission success/refusal, read/poll/response/error N retention, Generation G7/T8 capture/custody and independent TCP+TLS h2 source/evidence.
- **Task5: PASS_INITIAL_BROWSER_AT_RECORDED_CUTOFF** — Reviewed host6/cohort3/runner8/collector3 direct Chrome TLS/H2 and H1 source contract: exact target95/W+B/G7/T8, all-ever acquisition attribution, same-callback public status+lease snapshots before original effects, strict live target before close, actual normal native/Session/worker joins, complete peer framing/full send, final Gate0, authentic Actor0 versus separate internal child statuses. Historical failures remain FAIL and GREEN2 cause UNKNOWN.
- **Task6: PASS_INITIAL_AT_RECORDED_CUTOFF** — Recorded core68/0 native94/0 preservation230/0+161/0 core1/0 HTTP2/0 consumers, strict initial compile/format. Fresh final union/compile/format/browser/consumers remain planned after reviews.
- **Task7: OPEN_CORRECTLY_NOT_CLAIMED_COMPLETE** — This FULL SPEC1 is FAIL. Independent full CODE, fresh final union/strict checks/both browser modes/both isolated consumers, final docs/committed-blob custody/local conventional commit remain OPEN. No publication/deployment/fullM3 claim.

## Frozen source and constructor authority

All245 source and409 evidence byte counts/SHA256 identities match before and after review; candidate SHA remains unchanged. Both protected user-file hashes match. The only production SHA deltas from constructor freeze2 are outer HTTP.Connection metadata close and HTTP2.Transport postread trailer accounting. Admission, generic WorkerBootstrap, native HTTP2.Connection, Stream, WorkerAccounting, Exchange, Limits and Generation constructors are unchanged. These two compatibility changes neither alter startup/control/dispatch constructors nor lifetimes/multiplicities; checkpoint1 remains bound.

All12 reports contain the current ordered95 roles (88 startup/7 dispatch), with1140 ordered name/family/count/owner/lifetime/subtotal checks and all12 whole equations checked. Earlier independent SPEC2 ETF/cap/fixed-point derivation is rebound to exact unchanged charged-source hashes; no runtime/pure ExUnit rerun is claimed. Valid public default A11198/J5794/N213600/W213728 and large valid initialized endpoint A11213/J399226/N607047/W607175 remain identical. Whole P+A+J=N and W=N+2head hold, including signed originalD and integer-width cases. Pure source-role allowance is not physical memory or an endpoint/config cap.

Actual implementation tracing follows W validation/reserved transition before public atomic spawn, complete ordinary child lease and private activation authority, next-callback owner/mode/D/child revalidation, original public async success correlation before complete X/endpoint construction, generic bootstrap/no optional core imports, normal-owner Gate cleanup and same current W+B custody through actual paired childDOWN+linkedEXIT. No private dependency API, Task startup wrapper, added dependency, extra guardian/resource class or Session custody migration appears.

Transport correction preserves pre-read admission, computes progressed trailers before checked final update, checks pending restoration and preserves primary operation error. Native metadata-close correction handles only unavailable pre-admission metadata with original context and preserves other error reasons. Real TCP/sockname/TLS after-ALPN regression source, immutable expectedRED13/3 and acceptedGREEN2 13/0 support it.

## Initial evidence and remaining gate distinction

Recorded initial gates are core68/0, native94/0 (independent Python h2 TCP and TLS/ALPN), preservation230/0+161/0, isolated consumers1/0+2/0, metadata-close13/0; these are archived root results and were not rerun by reviewer. BrowserGREEN5 initial PASS2/2 uses host6/cohort3/runner8/collector3. Static review preserves strict complete upstream framing/full sends,95/W+B/G7/T8/custody, complete all-ever cohort attribution and atomic same-callback status/state cuts at every original effect, live target before close authorization, genuine normal worker/Session/native closure and Gate0. Six fixture Actors0 stay separate from14 adopted internal waits (12 exit0/two signal10), none remaining. Historical browserGREEN1–4 and diagnostic1–4 stay FAIL, and GREEN2 initiating cause remains UNKNOWN.

Full-stage CODE, fresh final union/compile/format/both browsers/both consumers, final documentation and local committed-blob custody are intentionally OPEN. This FAIL must be resolved and re-frozen/re-reviewed before those final gates. No full-M3/upstream-H2 Generation/H3 accounting, publication or deployment acceptance follows.

## Verification, ownership and counters

Synchronous read-only git identity/status/diff, source/document reads, Python JSON/SHA256/row metadata/subtotal/equation checks completed. All commands exited0 and joined. No tests/runtime/browser/build/format/network, repository/Git mutation, background actor, suspension or trace was created. Forbidden sensitive raw TLS trace was never read. Only assigned `/tmp/gaoxy-native-worker-full-spec1.md` and `.json` were written.

Counters unchanged: group40/root52/stage10 failedGREEN, production3/completedfixture6, nonaccepteddiagnostic4, Astra2/2 exhausted. This source-only full-stageSPEC1 FAIL adds no runtime/repair round; record source review failure separately. No product decision or new permission is needed.
