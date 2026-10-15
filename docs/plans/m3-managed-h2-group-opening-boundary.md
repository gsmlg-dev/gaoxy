# Managed H2 Group Opening Boundary Implementation Plan — version2

> Root owns all repository/index/runtime/evidence writes. Source-only authors/reviewers receive explicit file ownership and preserve others' work. Independent SPEC2 must pass and accepted source-foundation local commit must exist before implementation. Continuing authorization supplies routine development approval, never activation/accounting acceptance.

**Goal:** Implement exact Selected→sanitized group options→original handle/URL/upload carrier transitions and error drops behind literal accounting-not-ready denial.

**Architecture:** Boundary exports prepare/4 and activation/0 only. Three pure Session helpers drive real group-specific callbacks; preparation and bind use internal continuations, with upload PID|nil in {:group_bind,upload}. Legacy/fixed projector fields remain unchanged.

**Tech stack:** Existing Elixir/OTP, exact HTTP0.21.10 cohort, accepted group-source Envelope APIs; no new process/dependency.

## Entry, custody and files

- [x] Record actual accepted source-foundation commit, source identity, preserved diff/untracked inventory and predecessor counters. Preliminary test counts are not entry. Preserve SPEC1 FAIL and version1 frozen hashes in root evidence destination from `/tmp/gaoxy-h2-group-boundary-evidence-path.txt`; this version does not amend historical acceptance.
- [x] Freeze design2/plan2/decision2 hashes and obtain independent SPEC2 for all BP-SPEC01–04/OBS07 requirements before code/test authoring. No third Astra; no review-counter reset.
- [x] Assign independent pure author `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_boundary.ex` and `apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs`; Session author owns `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex` and `apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs` after API freeze. Root integrates all edits and runs commands. No owner/Probe/Options/HTTP admission/reservation/fixed projector/dependency change.

## Task1: Tests-first pure boundary

- [x] Write complete pure boundary file tests for prepare/4 + activation/0, no side effects/adapters/AST. Record intended missing-function RED with exact source/runtime/exit/counts using root command below.
- [x] Implement cases with both protocols: exact seven options keys/five effective limits; original raw origin+escaped/leading//target+empty query; upload reduced to min endpoint/member chunk only after original compact Neutral validation; exact Selected/context/checked shapes; matching selected T membership and policy protocol/normalized authority; source-root<=H.max_url_bytes and8192; exact invalid/overflow/deadline cases.
- [x] Test duplicate/invalid T rejection and preservation of arbitrary unique supplied order. Both unique permutations are accepted when otherwise coherent. Do not assert pure out-of-order authentication, add authority input, or sort. Alias mismatch tests compare already present exact H/T values only.
- [x] Implement Boundary.prepare/4 exactly from design2 and one-clause `activation/0 => {:error,:accounting_not_ready}`. Context exact keys group/instance/limits/deadline/opening_deadline/now; no hidden clock. Return options/effective limits only; no config/member/Neutral sidecar. Boundary does not create runtime permission or reserve.
- [x] Root reruns complete new file and accepted pure source/envelope tests; nonzero executed, zero failures/skips/exclusions required.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```

## Task2: Freeze and test production helper decisions

- [x] Write Session pure tests before helpers, using exact algebra:
```elixir
prepare_group_open(state, selected, now)
# {:ok, staged, :group_open} | {:error, finite_reason, dropped}
drop_group_opening(state)
# exact non-group identity no-op; H2-group sanitized state
group_open_result(state, result, now)
# {:ok, bind_state, {:group_bind, upload}} | {:error, finite_reason, dropped}
```
`now` signed64 is the third argument of BOTH three-argument helpers. No timer/Process/supervisor/owner/client calls; production result helper may call supported pure ManagedH2Client.completion(handle) for shape/identity only.
- [x] Add tests: exact staged tuple/config/clears; H aliases config.group/selector/selection equal; T aliases member.config/awaiting.handle/transport_selection/pins equal; raw root respects advertised max; one member/config root in awaiting `%{handle:T,member:selected}`, no duplicate config; exact non-group/fixed/H1/H3 drop identity; idempotent group drop and preservation of original handles/tokens/pins/service/managed_path.
- [x] Add aged-anchor cases with smaller member limits. Assert deadline=min(old,started_at+effective.max_lifetime), opening=min(oldOpening,deadline,activated_at+effective.opening_timeout), monotonic handoff clamp, signed64 additions/subtractions and deadline+1000 headroom; no now-based renewed lifetime. Pure helper leaves timer refs unchanged.
- [x] Result cases: actual-shaped public original handle accepted through completion facade, strict original identity in request/original_request, upload nil/PID carrier independent of handle.stream=nil, invalid upload/handle fail closed, no extra handle key; options/K dropped and URL only retained. Late successful result installs real original handle before deadline/cancel failure then drops payloads; never loses completion or claims refund.
- [x] Test cleanup-unconfirmed raw atom and tuple produce finite explicit discriminator before generic normalization; unknown inner diagnostics become :cleanup_unconfirmed, malformed success=>{:cleanup_unconfirmed,:invalid_response}. Test ordinary error finite_reason, no arbitrary diagnostic retention; prepare/gate/local errors remain distinct by phase. No AST/source-text tests or detached transfer APIs.
- [x] Root captures intended helper-missing RED, then complete pure GREEN after Task3 integration:
```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```

## Task3: Actual H2-only Selected threading and timing

- [x] In group select success preserve exact owner three-key Selected/token; H2-specific direct helpers receive member, legacy helpers keep config. Before generic fallback recognize invalid H2 intent and fail finite; never reconstruct id/max_inflight or use dedicated fallback for H2.
- [x] H2 handoff stores only `%{handle:T,member:selected}` in awaiting_transport. Identity notification remains unchanged bounded ref/handle/origin/protocol/instance/deadline. Resume validates exact matching H/T aliases/ref/pin and a signed finite response deadline, clamps existing total/opening budgets without extension, and clears awaiting before checkout; member remains single local/returned root. The existing pump response carries its total deadline, not the selected opening notification deadline. H2 checkout returns `{:ok,state,selected}`; choose protocol/client from selected.config, preserve its raw URI and reject checked mismatch rather than old state.client rewrite.
- [x] Implement private pure effective-limit/original-anchor arithmetic shared by handoff preparation and prepare_group_open. Validate signed anchors and+1000 headroom before constructing Boundary context. Do not call side-effecting generic apply_limits from group pure path.
- [x] Actual handoff callback applies the validated reduced deadlines/timers once before wait. Actual prepare callback applies timers once if changed/not installed, retains already identical handoff timer refs. Direct path applies once after successful staged preparation. No duplicate generic apply_limits plus custom reset; timer deadlines never extend. This placement is independent CODE review, not an AST test.
- [x] Implement prepare_group_open/drop helpers with exact design2 results. Group staged state keeps only tagged options Q/K and finite controls/limits; selector/awaiting/handoff/managed_transport cleared; stable client H2/managed_path true, group/transport cleanup tokens/pins unchanged. Malformed group limits become failure-only `%{limits:nil}`, never retain arbitrary values; legacy drop is exact identity.
- [x] Return actual `{:noreply,staged,{:continue,:group_open}}`. No new top-level Session field; fixed projector unchanged. Options/owner prepare rejection remains independently in source, not changed by this package.

## Task4: Guarded open/result/bind and every error path

- [x] `handle_continue(:group_open,staged)` checks exact state/cancel/consumed and fresh remaining absolute deadlines; recomputes only remaining intervals, never anchored budgets. Literal activation denies before any new group client.open. Denial drops options/K then local fail/settle :unavailable with passive-health neutral/cancelled; no caller flag/test bypass.
- [x] Include future success branch behind immutable gate. Call ManagedH2Client.open exactly once; pass result and now to group_open_result. Helper validates completion/handle and upload PID|nil, preserves original public handle unchanged, returns sanitized bind state and `{:group_bind,upload}`. Do not use handle.stream or insert private upload key. Success after expiry retains real original handle for cleanup and returns finite deadline error.
- [x] Return `{:noreply,bind_state,{:continue,{:group_bind,upload}}}` only on helper success. Bind callback validates carrier and binds same original completion transport-first then group; only then notify `{:ready,upload,effective_limits,deadline}` so pump uses selected reduced chunk/write limits. No replay, no alternate selection.
- [x] Classify raw cleanup-unconfirmed before generic finite_reason. Preserve explicit finite `{:cleanup_unconfirmed,flat_atom}` result discriminator. Handle it before ordinary errors: transport_selection=nil=>notify+stop with dropped cleanup state/hold; otherwise fail/settle with original controls and owner-held completion. Never normalize discriminator into upstream_failure or release hold early.
- [x] Preparation/validation/pin/checkout/gate/cancel/deadline errors drop then local fail/settle with neutral health. Ordinary attempted open errors follow current upstream_fail finite mapping. Bind transport failure does not bind group; bind group failure preserves both ledgers. Both drop URL/options/K, retain original request/completion/tokens/pins. Completion pending/failure keeps hold; no fake completion/refund. Accepted headers and all terminal paths clear residual URL.
- [x] Queued cancel/expired/monitored-DOWN pre-open behavior remains mandatory before future gate removal; handle_continue runs ahead of mailbox. Document this dependency, never claim race acceptance from pure state tests. Fixed release helper/generic H1/H3/fixed routes unchanged.

## Task5: Independent reviews, fresh scoped gates, local commit

- [x] After complete initial GREEN, an independent FULL IMPLEMENTATION SPEC reviewer verifies all adopted requirements, the four corrections and exact enum/context/timing/result contracts; design-readiness SPEC2 alone does not satisfy this gate. Independent CODE reviewer later checks actual Selected direct/handoff/root uniqueness; H/T coherence; old-state.client rewrite exclusion; literal gate dominance/internal callbacks/no flag bypass; timer placement once/no extension; upload carrier to ready; cleanup discriminator before generic normalization; original completion and legacy dispatch. Review source directly, not brittle AST unit tests.
- [x] Root runs task-owned scoped format, forced strict compile and complete pure files with no skip/exclusion/filter:
```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs apps/gaoxy_proxy/test/managed_h2_group_source_test.exs apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_preparation_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```
- [x] Root runs required existing scoped fixed lifecycle/write/release/control and H1 transport proxy/probe compatibility files from current manifest. Record exact source/environment/nonzero counts/exits and all failures, do not infer predecessor network/browser acceptance from pure tests. Resolve actionable in-scope regressions without weakening assertions, no third Astra.
- [x] Update source-linked root inventory and preserve future startup/probe/recovery source/overlap/capability obligations. 9Q/8C/4K and2MiB remain unproved; no new reserve, no activation. No detached constructor/validator added before actual owner/Probe consumers.
- [x] All acceptance gates are complete; root stages task-owned four files plus adopted scoped evidence/docs and executes the final local commit `feat(proxy): stage managed H2 group opening boundaries`. Record accounting ACCOUNTING_NOT_READY, live groups/Probe/network/browser NOT RUN, Options rejection unchanged. No push/release/deploy.

## Automatic next dependency

After this bounded package passes, implement actual protocol-aware Probe/owner boundary and exact normal/recovery transfer wiring under another written bounded design while Options stays H1-only. Only then measure complete source-linked request/probe/recovery bundles, bind canonical Elixir/OTP startup source, qualify accounting/reserve and implement admission before separately reviewed gate removal and prescribed real network/browser/lifecycle acceptance. No publication, production, certificates, Vault, public management or disabled E2E changes. All listed commands are root execution instructions and NOT RUN by this design author; no persistent commands started.

## Root adoption checkpoint

Source predecessor is committed at `060f92641ae12345b7121e220549222418a40b0e`, after complete independent SPEC2/CODE1 and fresh format/forced compile/107 tests0failures0skips0exclusions. Its documentation closure passed independent SPEC1/CODE1 and fresh byte/source audits, and is committed at `73ddf628dcd8ef037b78d9a28bcfb84bda170df4`. Boundary design readiness SPEC2 passed with zero unresolved findings on candidate `cee3d3788d986f2b5e4022ce44914b8f4902a0c8d8bc0e32b9812a0ba5849c82`. The frozen readiness inputs, original author drafts and failedSPEC1 remain immutable. `implementation-entry1.json` records both entry gates, ownership, source inventory and the selected compatibility files.

The first readiness-manifest attempt exited1 after copying the author files/adopting docs because it assumed the wrong Resources path. No manifest, review release or implementation occurred. The actual module is `apps/gaoxy_http/lib/gaoxy/http/resources.ex`; custody/manifest failure1 is separate from design failedSPEC1 and implementation0/repairSol0. The corrected manifest binds the actual path and all adopted docs; no assertion or gate is waived.

## Historical root initial verification checkpoint

Implementation tasks1–4 are integrated behind the unchanged literal denial; checklist checks describe implemented behavior pending complete independent SPEC/CODE. RepairSol1 fixed the strict compiler inference through a constant public apply; repairSol2 fixed optional-field classification for legacy minimal H1/H3 states. Both failures and all original assertions are retained. Initial postrepair2 format/forced strict compile, seven-file pure153/0 and complete36-file compatibility603/0 pass with zero skips/exclusions and stable source. All41 existing test files are unchanged. Full implementation SPEC then CODE and fresh gates/local commit remain required. Boundary counters: implementation1/repairSol2/strictCompileFailure1/compatibilityFailure1/pure unsuccessfulGREEN0; intendedRED46 separate; manifest custodyfailure2; manifest custodyfailure2 retained; inherited counters and Astra2/2 exhausted unchanged.

## Final verification checkpoint

Complete implementation SPEC1 then CODE1 PASS (22 checks each, zero findings), followed by fresh format/forced compile/seven-file153/0 and complete36-file603/0, zero skips/exclusions, stable reviewed code. postreview-fresh-gates1.json authenticates exact receipts/logs. The checklist records completed acceptance and the prepared final root Git operation; actual commit/tree and raw byte audit are separately authenticated after Git succeeds. No push/release/deploy; next bounded Probe/owner design may enter only after the actual local commit and formal adopted-source design readiness.
