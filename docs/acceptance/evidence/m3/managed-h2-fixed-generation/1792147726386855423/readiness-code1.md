# Fixed-H2 Generation readiness CODE1

Task `/root/fixed_h2_generation_readiness_code1` — **DONE; verdict PASS**. Direct independent source-feasibility review after archived readiness SPEC1 PASS. No actionable findings.

Repository/worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline `aa272c3dca700a9275a00bd23920d09bbd4748a1`.
Candidate `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/readiness-candidate1.json`, SHA256 `03aed2ba43d08ed7020ca3da400aa3e140ae78c3f976112f7e35b929e8b4e4ce`.

This verdict approves the bounded proposed guard and implementation plan as source-feasible. It does not approve a completed implementation or claim runtime acceptance. The intentional current blanket denial remains at `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:242-246` and is the source cause of the planned behavioral RED. The complete design/plan, acceptance, archived readiness SPEC1 Markdown/JSON, investigation maps, current diff and relevant production/test/browser source were inspected.

Root exclusively owns repository/runtime/evidence/Git. My only writes are `/tmp/gaoxy-fixed-h2-generation-readiness-code1.md` and `.json`. Pre-existing parent changes are the roadmap modification plus untracked fixed-generation design/plan/acceptance/evidence. Those were preserved byte-for-byte under the frozen manifest.

## C1: Exact pure validator and proposed guard — PASS

The proposed code at design:30-38 is directly compatible with the existing validate_config/1 return contract. The validator accepts exactly the eight-key HTTP struct, ManagedH2Client, nil direct trust/address overrides, exact four-field T4, bounded limits and canonical compact root URI, with explicit protocol/scheme and ETF ceilings. Every validation rejection returns {:error,:invalid_config}; mapping that exact result to the existing unsupported error preserves the compiled boundary. No live owner preflight, new process or API is required.

Evidence: `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:141-145,158-160,237-246; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex:80-105,312-342,463-510; docs/designs/m3-managed-h2-fixed-generation.md:26-56`.

## C2: Pure T4 schema versus authenticated live identity — PASS

T4 has provider/owner/owner_epoch/resource only. Pure validation cannot authenticate liveness, protocol, authority or instance, and the plan does not claim it can. Fake/stale handles fail owner record/baseline acquisition; a genuine mismatched handle may legitimately acquire baseline and source pins, then immutable protocol/authority/instance binding refuses delegation before deriving a child or checkout/Fetch. Relabelled non-H2 structs are outside this change's validator contract. Groups remain separately unqualified with no new group denial.

Evidence: `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:335-377,889-907,1365-1377,1379-1420,1472-1473; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex:330-342; docs/designs/m3-managed-h2-fixed-generation.md:41-56,194-198`.

## C3: Compiled boundary and sidecar ordering — PASS

Generation.prepare compiles and applies compiled_bound; public activation applies it before the Store call; raw Store activation rechecks it before baseline pin_many; both initial routes/router startup paths activate through that same boundary. compiled_bound checks endpoint validation before exact sidecar consistency, then bounds the complete Router. Router compares the validated resource union to endpoint-declared resources. Thus after the guard change malformed H2 config retains unsupported, while canonical H2 with missing/extra/substituted sidecar reaches invalid_endpoint_resources before baseline acquisition. Accepted positive activation must contact a genuine owner.

Evidence: `apps/gaoxy_http/lib/gaoxy/http/generation.ex:14-29,75-92,517-533,638-645,685-724; apps/gaoxy_http/lib/gaoxy/http/router.ex:17-38,43-85,111-123; apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs:8-59`.

## C4: Genuine Store capture and post-CAS old delegation — PASS

Checked Generation reserves B and updates the original Gate lease before Store/provider request-pin effects. Store serializes current-router capture, authenticates holder==caller and obtains real pins through pin_many_checked. The original operation is recorded before the effect and checked correlation preserves full handles and holder. Router receives those pins in the original Exchange. CAS replaces baseline/router and queues old baseline release. With preparation pins gone, close_unpinned closes ordinary admission but retains the active resource while source pin/token holds exist. Fresh pin_many requires open admission; authenticated delegation and checkout intentionally require active/unretired resource rather than open admission. This permits the planned old request without re-fetching the router or outer reacquisition.

Evidence: `apps/gaoxy_http/lib/gaoxy/http/generation.ex:133-165,200-229,269-281,308-345,443-451,517-529,572-580,608-612; apps/gaoxy_http/lib/gaoxy/http/resources.ex:76-118,234-245; apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:335-425,889-907,1010-1099,1117-1137; apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:277-321,572-607,936-998`.

## C5: One-use handoff and original completion custody — PASS

HTTP retains one source-pin handoff, marks it used before delegation, and revokes the original operation on deadline/Session/downstream failure. Owner authenticates exact stored public source pin, native holder, request kind/non-derived source, selected handle, immutable identity, distinct live guardian and original admission deadline. A resource grants one child, with same guardian/operation idempotence only. Session starts inactive until real Service cleanup activation, validates its exact child T8, checks out once, opens through the public managed facade and binds the original Promise completion before ready. Cleanup uses original_request; confirmed public completion precedes owner finish, child release, Service receipt and Session normal DOWN. HTTP awaits that DOWN; checked Generation releases its source only after endpoint returns. The return barrier can therefore prove source lifetime independently of original completion.

Evidence: `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:635-674,936-998,1051-1055,1112-1129; apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:46-82,140-158,235-265,1202-1223,1346-1418,1626-1637,1683-1739; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:55-83,177-205,294-309; apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:347-377,427-456,1010-1099,1260-1269`.

## C6: Existing constructors and lifetime/accounting reuse — PASS

The only proposed production edit is transient pure configuration validation; no retained constructor, multiplicity, lifetime or public interface changes. Existing fixed endpoint already contains the source handoff/one child/original completion. Checked accounting accepts protocol-neutral exact T4/T8 and genuine correlation. Native H2 accounting measures the actual complete initialized endpoint, request and Exchange operands, so the new wrapper must be measured rather than assigned guessed headroom. Preserve native95 and P/N/W, H/Q65536, fixed9444956, group16478862 and startup5963776. The plan correctly reopens independent constructor SPEC then CODE if an actual repair introduces a charged operand/lifetime; this readiness change itself requires no new constructor checkpoint. No physical-memory claim follows.

Evidence: `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:572-607,635-674; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex:62-73,385-428,460-473; apps/gaoxy_http/lib/gaoxy/http/http2/worker_accounting.ex:63-91,99-117; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex:17-48; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex:75-89; docs/designs/m3-managed-h2-fixed-endpoint.md:880-915; docs/designs/m3-managed-h2-fixed-generation.md:88-102`.

## C7: Fixture, finite deadline and join feasibility — PASS

The plan identifies required new test-local wrapper and genuine Store fixture, rather than treating existing fixtures as ready. Both old H1 SnapshotEndpoint and checked CapturedEndpoint omit generation_validate and cannot be copied unchanged; the planned wrapper forwards init/resources/generation_validate and original Exchange/result. Existing F.peer/connect/send_request/response/manual command APIs supply actual socket peers; static F.fixture/clean/close carry one-baseline assumptions and are source patterns only. Holder-owned coordinators, bounded native dispatch/return barriers after Store reply, release of the owner-input probe before CAS, exact peer+connection+stream identity, normal custodian/native/owner joins, final peer counts/exit0 and listener rebind are feasible without new production APIs. Existing failure/handoff patterns support stale CAS, candidate abandonment, Store death, original-operation cancellation, genuine mismatches and sticky late cleanup. New fixtures must implement those cleanup obligations, including intentional RED failure paths.

Evidence: `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs:10-163,209-371,541-647; apps/gaoxy_proxy/test/upstream_transport_generation_test.exs:14-38,267-341,1092-1172,2323-2423,2446-2454; apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs:993-1010,1385-1435,1479-1555; apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs:109-165; apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs:278-315,378-389; docs/plans/m3-managed-h2-fixed-generation.md:53-150`.

## C8: Browser adaptation is bounded proposed work — PASS

The predecessor browser host prepares an H1 group, executes at file top level, and its runner navigates once; neither can be executed unchanged as fixed-H2 Generation proof. The plan explicitly requires a new frozen host/runner adaptation and independent fixture SPEC then CODE. Unchanged copied/hash-bound Cohort and current Actor/CDP custody provide real cohort cuts, all-actor terminals, process-group/reader joins and explicit browser cleanup. Two commands/navigations and fixed one-effect/one-source expectations are test fixture changes; complete native95/W+B, old/new genuine capture/CAS/retirement, visible exact documents, TLS/h2 versus clear H1 rows, close-after-request-clean, profile removal/Gate0/rebind remain required. No unknown production capability is assumed.

Evidence: `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300/native-worker-browser-cohort3.exs:13-72; docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300/native-worker-browser-runner8.py:128-228,253-341,352-458; docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300/native-worker-browser-host6.exs:428-473,643-698,822-875,923-985,1579-1583; docs/plans/m3-managed-h2-fixed-generation.md:134-150`.

## C9: Scoped gate coverage and security/compatibility — PASS

The 19-file final unfiltered union covers new profile/exclusion, fixed endpoint/lifecycle/release order, immutable identity/handoff/H1 preservation, checked capture/accounting, generic endpoint/sidecar/resources/Generation and H2 worker startup/stale-start seams. Eighteen files exist; the new fixed-generation test is intentionally future work. Six separate genuine behavioral RED cases avoid optional-hook bypass and distinguish denial from fixture/compile failures. Both core and HTTP isolated consumers and forced strict compile/changed-source format are prescribed; no full unrelated suite is introduced. Existing raw/manual/no-redirect/no-replay managed client uses immutable owner policy/scope with protocol and authority checks. No unprepared direct upstream H2, group qualification, trust/IP rotation, load/reload/H3 acceptance or publication is inferred.

Evidence: `docs/plans/m3-managed-h2-fixed-generation.md:53-88,152-187; apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs:70-225,261-337; apps/gaoxy_http/test/generation_endpoint_validation_test.exs:29-151; apps/gaoxy_http/test/generation_resource_consistency_test.exs:135-155,446-452; apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex:1379-1435; apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:177-205,245-309; scripts/external-consumer.sh:1-14; scripts/http-consumer.sh:1-15`.

## Verification and identity

- Before review: exact candidate SHA and HEAD matched; all 23 manifest identities matched (19 sources/documents plus four investigations).
- After review: same candidate SHA/HEAD and all 23 identities matched; all 34 distinct nested map source identities matched; both map-report SHA values matched. All 34 additional source identities in archived readiness SPEC1 matched, and its Markdown hash matched its JSON declaration.
- Archived SPEC1 JSON SHA256: `fec991516949566b08c6317113792b8a22dd0f28789bbf1efbda4c647c011433`; Markdown SHA256: `4ccb5d86ca4bd834d80072a168bfcb1b7e25ab0f450530773de1834ce797ae44`; verdict PASS inspected directly.
- Read-only command families: `pwd`, `git status --short`, `git rev-parse HEAD`, `git branch --show-current`, `git diff --stat`, scoped `git diff`, `rg`, `cat`, `nl`/`sed`; Python standard-library JSON/hashlib source/hash and gate-path inspection. Every command completed with exit0. No background process or runtime actor was started.
- The source/test-map proposal with catch-all validator rejection is historical investigation; the reviewed design and plan correctly use the exact explicit `{:error, :invalid_config}` contract.

Runtime, tests, build, browser, network and Git mutation: **NOT RUN** by assignment. No locks/deps, publication/deployment, operational certificates, disabled E2E or dismissed dependency proof were touched or pursued. Static source feasibility cannot establish actual protocol behavior, loaded-code identity or cleanup success; those remain prescribed execution gates.

Parent completed environment preflight independently during this review. I inspected `toolchain1.json` and `environment-preflight1.json`: preflight PASS, actual exit0, joined/unforced/no remaining process group, source stable and tests0; toolchain log SHA verified. Recorded Elixir1.18.5/OTP28/ERTS16.4.0.6, Node24.19.0, Chromium152, Nix unbuffer and Python h2 4.3.0/hpack4.1.0/hyperframe6.1.0 are prerequisite evidence only, not this reviewer executing runtime or stage tests.

## Counters, remaining work and decisions

Cumulative group failedGREEN41/root55; Astra recovery2/2 exhausted. Successor failedGREEN0/productionRepair0/fixtureRepair0. This review adds zero Sol repair rounds and zero failed GREEN; no escalation, astra_gate null. No third Astra round is proposed.

Remaining work is already planned: implement genuine RED fixtures, run/record intended RED and cleanup, apply the minimal guard and explicit test-contract replacement, execute socket/failure profiles, independently review the new browser fixture, complete final SPEC then CODE, and perform fresh exact scoped tests/consumers/browser/format/compile plus document/custody audit before any local commit. Any actual retained-constructor/lifetime repair must reopen the prescribed independent checkpoint. Group Generation and the other excluded slices remain separately unqualified. No new product/architecture decision or external permission is needed for this readiness verdict.

Historical memory was used only for scope orientation (MEMORY.md:234-236); all review claims are bound to the inspected checkout.
