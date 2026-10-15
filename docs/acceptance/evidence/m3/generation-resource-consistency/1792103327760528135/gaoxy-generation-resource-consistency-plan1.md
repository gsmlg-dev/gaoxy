# Generation resource consistency implementation plan 1

> **For agentic workers:** Use the available executing-plans or subagent-driven-development skill under the Sol coordinator. Parent owns delegation and serialized runtime/build/format/Git commands. Do not begin implementation from this preparation handoff while the preceding group/browser gates remain frozen.

**Goal:** Reject a Generation candidate whose declared resource sidecar differs from its already compiled routes, including static nested Router targets, before any new baseline pin.

**Architecture:** Reuse Router's optional resources callback and bounded collection/normalization; add a pure internal recursive validator and call it from Store.compiled_bound. Compare exact normalized membership, preserve input ordering/dedup compatibility and generic provider APIs, and publish no rewritten Router.

**Tech stack:** Existing Elixir/OTP, Gaoxy.HTTP.Router/Generation/Resources, ExUnit and test-owned generic resource owners. No new dependencies or network fixture.

**Status:** PREPARATION_ONLY, no implementation/verification performed. Normative design `/tmp/gaoxy-generation-resource-consistency-design1.md`.

## Custody and kickoff gate

R `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; preparation HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Existing Router/Generation/Resources/test scope was clean at inspection; all other tracked/untracked changes belong to prior work. You are not alone: preserve every other writer's edits, do not reset/stash/revert, and freeze all writers before parent runtime commands.

Latest parent checkpoint during preparation: browser4 FAIL1/completed0 at real stale_group Tuple JSON emission after request_clean/clean. Proposed HOST encoding repair independently source-reviewed, not executed by this author. Carry23 failedGREEN/25 ordered root events before that adoption, Astra2/2 exhausted; read later exact ledger at kickoff. No counter reset/third recovery and no inference that current group stage passed.

- [ ] Parent finishes preceding group's exact canonical browser and required independent closure, records actual accepted source/commit and releases this next bounded slice.
- [ ] Parent records actual branch/HEAD, complete task/unrelated diff, relevant source/cohort hashes, latest counters, ownership and required scoped commands. Re-read design/current sources; stop only on real ownership/handoff mismatch or new external/product block.
- [ ] Promote design/plan into task-owned repository docs with truthful PENDING status if that is the chosen documentation convention; do not relabel this source-only handoff acceptance.

## Ownership and smallest file set

| Owner | Files/responsibility |
|---|---|
| Sol production writer | `apps/gaoxy_http/lib/gaoxy/http/router.ex`: internal validator/private collection mode; `apps/gaoxy_http/lib/gaoxy/http/generation.ex`: one compiled_bound insertion. No Resources/Endpoint API change. |
| Sol test writer, disjoint if parent delegates | New `apps/gaoxy_http/test/generation_resource_consistency_test.exs`: focused real Store API and pure compatibility cases with test-owned generic provider/endpoint fixtures. Existing test files read-only unless a demonstrated necessary contract update is explicitly assigned. |
| Independent Sol reviewer | Design/spec then exact production/test diff; no source writes. Review generic-provider/sidecar-order compatibility and publication bypass closure. |
| Parent | Scope/evidence/docs, serial runtime/formatter/build/checks and local conventional commit. |

Do not modify proxy HTTP/Session/G/T owners, dependencies, native reservation constants, Resource provider callbacks, standalone configuration, generation_validate protocol semantics, browser sources or preceding evidence for this slice.

## Task 1 — deterministic publication regression (tests before production)

- [ ] Add a local endpoint with init marker count, resources returning configured handles, and normal call behavior. Add a legacy endpoint with no optional resources/generation_validate callbacks and variants whose resources callback returns invalid values or raises/throws/exits.
- [ ] Add a small bounded generic test provider using public pin_many/release/cancel callbacks and public test-only event/hold status. Keep five/six-key public pins without G/T-only metadata. Observe actual baseline/request refs, kinds and owner operations; no production-private APIs.
- [ ] Build an active old Router/Store with one old baseline and acquire one authentic request snapshot pin as the test PID. Capture current public generation/router and provider event/hold status before each refusal.
- [ ] Compile a correct candidate, then forge sidecars individually: missing[], extra valid different handle, substituted resource, mismatched owner_epoch. Keep each malformed sidecar valid under Resources.validate so RED demonstrates missing consistency, not invalid metadata.
- [ ] For public activate and direct Store activate, require exact `{:error,:invalid_endpoint_resources}`. Require unchanged current generation/router and exact provider holds/events, with no candidate acquisition. Release original old request pins once as their real holder and verify the fixture confirms release.
- [ ] Add a nested forgery where outer sidecar agrees with an incorrect inner sidecar, but the inner route resources require another handle; use2 static nesting levels to prevent checking only direct children.
- [ ] Parent runs the new focused file to obtain nonzero expected RED from current missing consistency. Record exact count/exit/failure assertions; an agreed RED is not an unexpected repair round. Diagnose fixture/compile errors instead of treating them as useful RED.

## Task 2 — minimal pure resource walk

- [ ] Add `@doc false Router.validate_resource_sidecar/1` returning only :ok or invalid_endpoint_resources. Validate the supplied manifest with unchanged Resources.validate.
- [ ] Reuse collect_resources through an additional private validation mode; preserve Router.compile's original default call behavior. In validation mode, recurse into exact static Router targets before reading their declared sidecars.
- [ ] Ordinary endpoints retain optional resources(config) semantics; missing callback contributes[]. Make module availability/resource callback errors finite. Dynamic Generation remains a missing-resources-callback leaf; never query or traverse its Store.
- [ ] Compare normalized declared and recollected handles using exact MapSet.equal? membership; do not require canonical sidecar order, reject supported duplicates, or rewrite the Router. Preserve raw-list64 and ETF65,536 bounds as Resources currently applies them.
- [ ] Keep malformed-route/nested traversal failures inside existing finite resource error normalization. Do not introduce host/path/method grammar redesign or require nested static Router.generation to be a ref when current static dispatch does not.
- [ ] Add the single Store.compiled_bound call after existing generation_bound and before final compiled size acceptance. Retain current root/input/sidecar/generation callback/error precedence.
- [ ] Parent runs the focused file and reads actual GREEN/failures. Diagnose and repair actual regressions without weakened assertions or broad unrelated edits; retain cumulative counters and existing exhausted Astra limit.

## Task 3 — complete API matrix and compatibility

- [ ] Public prepare: wrap each forged Router as a static `{Router,forged}` target in input routes; expect resource error after compilation/compiled_bound. Do not invent a prepare(%Router{}) API. Recheck old current snapshot/provider status.
- [ ] Initial compiled router: start_link(router:forged) returns resource error and no candidate provider holds/operations. Initial routes wrapping forged static Router also refuse. Existing startup-error Store shutdown remains finite.
- [ ] Parameterize valid top-level/nested candidates across missing/extra/substituted/stale errors for public activate, direct Store activate and startup paths, while retaining representative deepest nested cases through prepare.
- [ ] Accept a correct sidecar reordered and duplicated within raw64; assert the exact supplied Router is published, sidecar order unchanged, and provider baseline acquisition uses normalized deduplicated handles. Existing Router.compile output still has stable first-occurrence ordering.
- [ ] Preserve local64 semantics:64 distinct resource handles pass if ETF permits;65 raw entries fail even if duplicates.70 routes sharing one handle compile/validate to one union entry. Multiple static routers dedup as before; do not impose a global limit on separate dynamic Generation captures.
- [ ] Callback malformed list/nonlist and raise/throw/exit become finite invalid_endpoint_resources; optional legacy callbacks still pass. Existing generation_validate tests retain their exact denied/invalid-return errors and invocation behavior.
- [ ] Correct static nested `%Router{}` empty form remains supported; malformed static Router target fails. Dynamic Generation init+resource union remains[], no current-store snapshot or new owner effect during validation.
- [ ] Prove no additional endpoint.init during public/direct activation or initial compiled-router use using original marker identities/counts. Compilation of input routes initializes normally once. Validation may call resources again by contract and does not call provider custody APIs.
- [ ] Document that matching unavailable handles remain provider acquisition errors: resource consistency is exact route/sidecar membership, not owner freshness/status. No generic pin-shape change is authorized.

## Task 4 — scoped verification and independent review

Parent freezes writers first; commands are the planned test gate, NOT execution evidence. Use actual project toolchain/cohort at kickoff, with finite command ownership and nonzero tests. Scoped examples consistent with the current project workflow:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_resource_consistency_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/generation_loader_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_endpoint_validation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs
```

- [ ] Record source identities, commands, exact test counts/exits, failures/skips/exclusions and process joins for the new file and existing core/managed-H1 Generation compatibility. Never use0 tests as PASS.
- [ ] Run scoped format check for exactly Router/Generation/new test and strict compile under the existing required toolchain. No repository-wide autofix or unrelated repair. Preserve baseline failures as distinct evidence.
- [ ] Independent SPEC review confirms every route/publication/error/compatibility case above and bounded scope. Independent CODE review checks recursion, actual optional callbacks, exact set comparison, no init/provider effects, no changed generation_validate behavior and refusal before baseline pin.
- [ ] Resolve actionable findings under existing counters, then run fresh relevant post-review verification and bind final source/docs/evidence hashes. Repeat only changed/affected checks; no unrequested sustained load or release-artifact E2E.
- [ ] Parent records PASS/FAIL/BLOCKED/NOT RUN separately. This pure slice has no new protocol/browser surface: it cannot substitute for the preceding group's pending canonical browser or claim managed-H2 Generation qualification. Later protocol slices retain real peer/browser gates.

## Task 5 — local closure and next prerequisite

- [ ] Complete truthful design/plan/acceptance docs and evidence index for this resource-only slice. State exact accepted behavior and unchanged reservation/publication boundaries.
- [ ] Verify task diff and clean task ownership, stage only Router/Generation/new test and task-owned docs/evidence, and create local conventional commit (suggested `fix(http): validate generation resource sidecars`). No push/publish/deploy or user-owned files.
- [ ] Only after prescribed checks and independent review pass, parent advances under continuing authorization to the separate native pre-snapshot accounting foundation. Fixed H2 gate removal/live Generation qualification remains a later bounded slice.

All preparation commands completed. Tests/build/formatter/runtime executed0 (NOT RUN). No new external permission or user product decision identified; current runtime ownership and acceptance belong to parent.
