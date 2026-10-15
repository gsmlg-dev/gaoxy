# Native pre-snapshot accounting foundation implementation plan 1

> **For agentic workers:** Use executing-plans or subagent-driven-development under the parent Sol coordinator. Parent owns delegation, repository writes, runtime/build/format/evidence/Git. Test-first writes precede production adoption; independent SPEC then CODE follow actual GREEN. No routine human approval is pending under continuing authorization.

**Goal:** Offer a real preadmitted managed-provider Generation capture path without changing generic legacy providers or activating H2 Generation endpoints.

**Architecture:** A small optional accounting-module interface in gaoxy_http delegates pure finite managed capture planning/validation to gaoxy_proxy. An internal checked acquisition path tracks genuine provider operations. Accounted capture charges the complete named source-role allowance before Store access and retains it in Exchange.route_bytes. Native worker transfer and H2 activation are separate following slices.

**Tech stack:** Existing Elixir/OTP, ExUnit, Admission, Generation/Resources and public UpstreamGroups/UpstreamTransports. No dependency, process type, private actor inspection or upstream modification.

**Status:** SOURCE-ONLY PROPOSED; every implementation/runtime checkbox below is NOT RUN. Read paired `/tmp/gaoxy-native-generation-accounting-design1.md` for exact source findings, options, boundaries and source hashes. Parent must rebind after the current resource-consistency commit. This draft is a concrete preparation deliverable, not evidence that any proposed API exists.

## Task 0 — bind and independently check the smallest contract

- [ ] After resource-consistency closure, record actual R branch/HEAD/status/diff and prior acceptance. Verify the14 design source hashes; explain any approved drift. Preserve codex-prompt.md and every unrelated file. Record ownership and inherited failedGREEN24/rootEvents27/Astra2/2.
- [ ] Parent adopts the recommended bounded managed profile and records its independent readiness review. Verify optional `Generation.init({:accounted,store,module})` is purposefully limited to selecting the request accounting implementation; no current endpoint form, Store public API or generic provider schema changes. No new user approval stop.
- [ ] Assign production files below to one writer; test proposals may be written in `/tmp` by a disjoint writer. No concurrent repository/runtime writer. Reviewers are source-only and cannot mutate/build.
- [ ] Before implementation, turn the design's role table into an executable pure worksheet with exact ETF constructor syntax, formula and subtotal tests. Let M be Store bound; P/H=65,536 are existing selected managed capture/manifest caps, k<=64 is this static manifest's provider-batch count. Derive each full envelope from its actual tuple/list/map shape, including repeated generation and original operation provenance. Future local refs use reviewed nodeETF+27 reasoning and managed scalar constraints; do not manufacture ref/PID samples as maximum proof.
- [ ] Freeze fixed/group/startup constants and existing protocol exclusions. Record grep/hash guards for managed_h2_reservation.ex, ManagedH2GroupAccounting.contract(), HTTP.generation_validate and native protocol reservation modules. No +constant patch is allowed as a substitute for worksheet adoption.

## Files and responsibilities

| File | Responsibility |
| --- | --- |
| Create `apps/gaoxy_http/lib/gaoxy/http/generation/request_accounting.ex` | Internal pure behavior/closed plan checks and source-role helpers needed by Generation; no proxy references. |
| Modify `apps/gaoxy_http/lib/gaoxy/http/generation.ex` | Optional accounted init/call branch; preadmission before Store; distinct checked Store request; preserve legacy clauses. |
| Modify `apps/gaoxy_http/lib/gaoxy/http/resources.ex` | Internal checked pin acquisition using original operation provenance; existing pin_many/4 semantics unchanged. |
| Create `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex` | Selected managed G/T capture contract and executable reservation worksheet; reuse existing validate(:captured_pins,...), no constant changes. |
| Create `apps/gaoxy_http/test/generation_request_accounting_test.exs` | Public Admission/Store/checked-provider behavior, generic legacy compatibility, native capture barriers where the core test dependencies permit. |
| Create `apps/gaoxy_proxy/test/managed_generation_accounting_test.exs` | Pure managed worksheet/schema/caps and real G/T integration/native capture smoke. |
| Parent-owned docs/evidence | Exact executed source, commands/counts/exits/joins, verdicts/reviews and local custody. |

Exchange fields need not change: route_bytes already participates in every retained_bytes update. Do not modify Exchange only to introduce a redundant counter. HTTP core must not depend on gaoxy_proxy. No edits to HTTP H2 exclusion, fixed/group reserves, owners, Session/Probe, native H1/H2 worker machinery or standalone configuration in this first slice unless a specific acceptance finding requires a separately reviewed scope update.

## Task 1 — useful failing pure contract and preadmission tests

- [ ] Test-owned module implements `capture_plan/3` and `validate_capture/1` with observable **pure** planning and deterministic accepted pins; test-owned provider exposes public pin/cancel/release/status and init/dispatch markers. Public receipts exercise both existing five- and six-key generic forms through legacy paths. Do not use :sys state injection.
- [ ] Build genuine Exchange/Admission lease owned by the endpoint task and genuine active Store. Use current Exchange.retained_bytes as base. First public accounted init/call tests call proposed APIs via apply only until implemented, then use normal calls.
- [ ] Demand useful RED for: accounted form currently unsupported; insufficient capacity currently cannot stop this new capture contract before provider request; capture allowance currently missing from returned route_bytes. Missing-function/unsupported-form RED establishes missing API only; include behavioral refusal/assertion RED after the minimal form exists before declaring the production behavior complete.
- [ ] In a provider barrier after actual pin request, require public Admission.status.retained_bytes covers base+B. Parent controls a `{:continue,operation}` message, with monitor and finite deadline. For capacity base+B-1 require exact byte_limit, original Exchange, unchanged baseline/current Router and zero request-provider events. For exact base+B permit one real operation.
- [ ] Test returned Exchange retains B through a subsequent public body/output operation; require Exchange.retained_bytes and Admission.status agree. Do not accept a temporary adjust_bytes delta that the next update removes.
- [ ] Independently derive whole-envelope ETF arithmetic from real maximal supported constructors and exact source syntax. Validate missing/extra keys and all stated cap boundaries. Neither samples nor an expression equal to the implementation itself are independent maximum evidence.

Run planned focused RED with a new finite collector, not a preceding slice collector:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_request_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs
```

Parent records actual test count/failure text/exit/source stability. A compiler/fixture error is not the required behavior RED. Agreed RED does not consume a repair round.

## Task 2 — pure plan and optional accounted endpoint branch

- [ ] Add the internal three-operation behavior exactly described in the design: capture_plan(max_config_bytes,existing_pins,context), validate_resources(handles), validate_capture(pins). Require closed finite plan data and positive bytes; do not accept a module reply granting zero/unbounded capture or performing runtime authority checks.
- [ ] Implement the managed module by reusing the existing exact G/T capture validator. Reject malformed/unknown provider captures; preserve every accepted pin and supplied order. Keep legacy five/six-key APIs separate and working.
- [ ] Implement source-derived worksheet B as the explicit sum of named roles (request/provider envelopes, three accepted acquisition-list roots, original provenance list, two full snapshot replies, three combined-capture roots and current release/cancel control). Publish machine-readable role caps/multiplicities/owners/releases for independent review. Do not substitute guessed wrapper headroom or claim simultaneous physical copies.
- [ ] Add accounted init input without changing init(store). It reads existing Store limits once, retains the optional module identity, and prepares no resource snapshot. Legacy initialized map remains unchanged.
- [ ] Accounted call invokes pure planning from original Store/holder/deadline scalars and existing captures. Add B to route_bytes, then Admission.update using the existing Exchange.retained_bytes. Only success enters the checked Store request. On refusal return original Exchange and reason. On later failure keep the conservative charged allowance until normal request teardown.
- [ ] Preserve deadline and holder authentication. Do not probe snapshots, traverse dynamic Stores, call provider status, or replay any endpoint init to construct the plan.

## Task 3 — checked acquisition and actual rollback

- [ ] Add checked Resources acquisition as an internal opt-in entry point. Before each provider call create/store only authentic {provider,owner,operation} provenance. Existing generic Resources.pin_many/4 remains source-compatible and follows its existing contract.
- [ ] Reject a current manifest with providers outside the managed implementation through validate_resources before invoking any provider. On each supported {:ok,pin}, correlate its provider/owner/operation and exact handles with the original acquisition batch, then check the complete next aggregate accepted pin list through the supplied pure validator before progressing. Each accepted list remains<=P; known bounded old+new inputs permit finite composition. Invalid raw callback outputs are rejected after return, explicitly outside arbitrary ingress proof.
- [ ] On provider error/exception/invalid or oversized receipt, cancel current and prior operations using original provenance. Never read cancellation authority from the rejected pin. Preserve baseline/current router and dispatch zero target calls. Normalize errors to the finite capture errors specified by the design without embedding raw diagnostic terms.
- [ ] In Store's distinct checked request, preserve holder==caller and existing deadline semantics; no baseline/preparation behavior changes. Successful reply remains original {:ok,generation,router,pins}, with genuine original receipt identity.
- [ ] Caller checks combined new+existing captures before Router dispatch and retains all of them. The normal after block releases only the newly acquired authentic request pins once. If combined validation refuses, cancel/release through valid original custody as appropriate and preserve uncertainty rather than declaring zero.
- [ ] Tests cover failed first and later batch, wrong returned provider/owner/operation fields, invalid shape, at/over ETF limit, callback raise/throw/exit and delayed reply past deadline. Observe public provider status and actual cancellation identities, not a fabricated cleanup receipt.
- [ ] Tests cover no-resource Router, separate dynamic Stores, nested valid captures, request-holder death, Store unavailability and generic five/six-key legacy success. Keep existing raw manifest64/65 and ETF65,536 semantics unchanged. No global64 distinct handles or33 groups constraint.

## Task 4 — native capture smoke and preservation gates

- [ ] Run a real native H1 listener and a real native downstream-H2 listener through the accounted Generation endpoint into a test-owned target that barriers **after capture**. Assert original capture identity, preobserved public Admission charge, later body/output retention and finite owned joins/peer EOF. Use h2c for deterministic core smoke if TLS adds no coverage to this pure capture seam; real TLS qualification remains later. No mocked production transport/client.
- [ ] At a provider barrier **before snapshot return**, activate a separate bounded generation via public API only if the fixture can do so without blocking the same Store callback; otherwise barrier at target after capture and compare original held snapshot with a fresh request. Do not deadlock Store by queueing activation behind its blocked pin callback and calling it completed.
- [ ] Native worker startup/dispatch boundary tests belong to the next plan. Capture smoke proves this Generation branch, not pre-worker endpoint transfer. Existing http2 capacity/stale-start tests remain required preservation evidence because this branch runs inside existing workers.
- [ ] Assert fixed/group/startup constants exactly unchanged and managed_h2_generation_exclusion_test still passes. Do not enable any fixed H2 Generation endpoint to obtain the smoke result.

Planned scoped gates (all NOT RUN):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_request_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/generation_loader_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_endpoint_validation_test.exs apps/gaoxy_http/test/generation_resource_consistency_test.exs apps/gaoxy_http/test/router_test.exs apps/gaoxy_http/test/native_proxy_seams_test.exs apps/gaoxy_http/test/http2_capacity_test.exs apps/gaoxy_http/test/http2_stale_start_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_http/lib/gaoxy/http/generation/request_accounting.ex apps/gaoxy_http/lib/gaoxy/http/generation.ex apps/gaoxy_http/lib/gaoxy/http/resources.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex apps/gaoxy_http/test/generation_request_accounting_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs
```

If a new native smoke is placed in a separate test file, add that exact file to the first command and source manifest before running. Core-only clean consumer/isolation check is required because this adds a cross-app callback seam; derive the existing exact command from current repository acceptance tooling and record it before execution. Do not invent a green consumer result or substitute source grep for the existing consumer gate.

## Task 5 — independent review, fresh verification and local closure

- [ ] Freeze all writers. Independent SPEC review checks actual accepted source-role bounds, generic compatibility, preadmission, rollback custody and deferred boundaries. Independent CODE review checks caller authentication, callback exception/timeout handling, finite traversal, exact complete wrappers, no forged maximum refs, core isolation and every release point.
- [ ] Resolve actionable findings with tests/assertions preserved; root records actual cumulative repair attempts and the existing exhausted Astra2/2. No third Astra recovery; do not silently reset counters or change models.
- [ ] After changes, rerun affected exact gates on fresh source. Collector owns finite600-second deadlines, actual joined command exits, nonzero tests, source before/after hashes, failures/warnings/skips/exclusions and evidence. PASS/FAIL/BLOCKED/NOT RUN stay distinct. Prior group1752 or consistency152 tests are not current execution.
- [ ] Parent writes design/plan/acceptance/evidence closure tied to actual source and reviewed plan; independently checks final docs. Stage only task-owned files, verify index/actual commit blobs, make local conventional commit (suggested `feat(http): preadmit accounted generation captures`). No push/publication/deployment.
- [ ] Advance automatically to a new source-grounded native worker transfer design after these gates pass. Later H2 Generation activation/matrix/CAS/rollback/Store death/CA-IP rotation20reload/standalone/two>=600-second load gates remain separate and incomplete. Never label this foundation complete M3.

## Review risks requiring explicit evidence, not user approval

* Optional accounting callback trust: only the selected managed implementation qualifies. Arbitrary provider transient output and arbitrary callback CPU are outside this accepted-payload contract.
* The conservative B must include complete repeated-generation receipt, original operation ledger and every owned role; reviewing only a hand-built projection is insufficient.
* A cancel message is not confirmed cleanup. A public status/owned join or retained uncertainty must substantiate every cleanup assertion.
* New optional initialized endpoint config must remain bounded by the existing Store compilation rules, preserve generic compatibility and keep dynamic Store traversal opaque.
* Existing ignored Resources.release outcomes do not become success evidence. Do not expand this slice into a general resource reclamation redesign; preserve a truthful failure if that blocks the new profile.
