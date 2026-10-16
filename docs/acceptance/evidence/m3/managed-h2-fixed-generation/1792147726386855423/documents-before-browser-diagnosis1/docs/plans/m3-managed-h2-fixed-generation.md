# Managed H2 Fixed-Transport Generation Implementation Plan

> **For agentic workers:** Use subagent-driven-development/executing-plans under
> root's sole repository/runtime/Git ownership. Delegates write assigned `/tmp`
> proposals/reports only. Independent SPEC precedes CODE at readiness, browser
> fixture and final-stage checkpoints. Continue automatically under AGENTS.md.

**Goal:** Qualify checked fixed prepared-T Generation for explicit h2c/TLS-H2
with genuine native old/new requests, ownership, completion and retirement.

**Architecture:** Replace only the blanket H2 Generation denial with existing
pure canonical validation. Retain Store checked capture, native source T8,
one-use Session child delegation and original completion custody. No retained
constructor or dependency change; reopen source checkpoint if that changes.

**Tech Stack:** Elixir1.18.5/OTP28, Nix, HTTP0.21.10, real Python h2 peers,
native downstream H1/H2 and Chrome/CDP. See the matching design for contracts.

Status: Tasks0–5 implemented and initially verified. Readiness and browser-fixture
SPEC1 then CODE1 PASS; intended RED6/6, GREEN3 57/0, GREEN5/6 each83/0 and
browserGREEN1 four rows/eight viewed images. Final full-stage review, fresh gates
and local commit remain pending. Counters: group44/root60/Astra2of2 exhausted,
successor failedGREEN3/productionRepair0/fixtureRepair3/orchestrationRepair2.
Earlier kickoff/readiness counters and all failed evidence remain immutable.

## Files and ownership

Root owns writes to:

- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` guard only, unless evidenced repair.
- New `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs`: genuine
  Store/listener fixed-T fixtures, RED, four sockets and bounded failures.
- `apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs`: explicit
  replacement of blanket exclusion with canonical validation/sidecar contract.
- Matching design/plan/acceptance and immutable stage evidence under
  `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/`.
- Necessary factual sync in `implement-plan.md`, predecessor Task7 and
  `docs/plans/m3-upstream-transport.md`. Never rewrite historical evidence.

Delegates own only explicitly named `/tmp` drafts/reports. They are not alone
in the codebase and must not revert others' edits. No parallel runtime or
repository writers. Preserve both protected user prompts and sensitive trace
restriction from predecessor. No lock/deps/publication changes.

## Task 0: Source binding and readiness

- [x] Verify branch/HEAD/status and predecessor closure, create unique evidence
  root, record kickoff identities/counters, archive source/test maps with hashes.
- [x] Self-review matching design/plan against Task5 and maps; remove stale
  next-prerequisite claims only in current roadmap prose.
- [x] Freeze design/plan/source snapshot; independent complete readiness SPEC
  then CODE. Resolve actionable findings with a new bound candidate/report.
- [x] Record actual toolchain/Python h2/Chrome/node availability and protected
  hashes. Unavailable prerequisite is BLOCKED_ENV, never skipped acceptance.
- [x] Mark predecessor successor-preparation checkbox only after readiness PASS.

## Task 1: Behavioral RED before source change

- [x] Build genuine empty Store/instance/transport owner and native checked
  listener, using `F.peer(protocol,["--manual"])` and real preparation.
  Positive routes are direct ProxyHTTP, not a hook-bypassing wrapper.
- [x] Add separate tests per protocol for prepare, public compiled activate,
  raw Store activate; each expects success and cleans all actors on assertion
  failure. Bind source before/after and true exit/log. Expected six intentional
  behavioral failures: `:unsupported_generation_endpoint`, not fixture errors.

```elixir
routes = [%{target: {ProxyHTTP, %{upstream: source.origin,
  upstream_protocol: protocol, transport: transport}}}]
assert {:ok, prepared} = Generation.prepare(store, routes)
# Separate public/direct tests compile routes and expect {:ok, generation}.
```

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --only fixed_generation_red apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs
```

Selected/excluded counts are intentional only for RED; unfiltered final gates
are required. Archive all original existing test bodies before contract edits.

## Task 2: Minimal guard and explicit exclusion replacement

- [x] Implement exactly the guard in design, handling the validator's explicit
  `{:error,:invalid_config}` contract; retain fallback and other protocols.
- [x] Replace old shaped-handle blanket rejection test with pure canonical
  validation and invalid-config mutations; assert no owner effects on rejection.
  Invalid sidecars now expect `:invalid_endpoint_resources`; public/direct/start
  snapshots remain unchanged. Use genuine prepared T for positive activation.
- [x] Cover genuine initial `routes:` and `router:` paths for each protocol;
  live fake/stale/mismatched handles remain finite owner/identity errors.
- [x] Run unfiltered new/exclusion/shared fixture tests; record exact source,
  count, errors, exits and joins. Failure enters Sol diagnosis/repair.

## Task 3: Four real old/new socket cells

- [x] Implement exact wrapper forwarding `ProxyHTTP.init/resources/
  generation_validate`; dispatch and return barriers use original native PID,
  unique ref, remaining original absolute deadline and original Exchange/result.
- [x] Implement holder-owned preparation coordinator, genuine checked listener,
  original owner input/Gate precharge probe and independent B equation. Fixed
  path has one owner effect/T8; no manual source-pin acquisition/injection.
- [x] Run downstream H1/H2 x upstream h2c/TLS-H2. Hold old after Store reply,
  activate new CAS, prove old closed admission/baseline gone/source alive;
  release old and assert exact old peer, then new exact replacement peer.
- [x] Validate exact native source/Session child pin owner records, one-use
  operation, original public completion pending while peer holds, and original
  completion identity at Session and owner token. No private Fetch state.
- [x] Finish new before old; hold old return after completion/Session DOWN and
  child/token release. Require old source and custodian still alive, then
  release native return and join actual old retirement/physical EOF or reset.
- [x] Close sockets, observe genuine native worker/connection/Writer joins;
  assert real Gate0/cleanup0, stop Store, owner all-zero, normal custody/instance
  joins, exact peer totals/forced0/live0/failedfalse/exit0, listener rebind.

Wire APIs: `F.connect(f)`, `F.send_request(f,socket,"GET",target,[],true,1)`,
`F.event(peer,"request")`, `F.command(peer,request,"respond",%{"body64"=>
Base.encode64(body)})`, `F.response(f,socket)`. Test-map1 records exact signatures
and causal sequence. Include the defining fixed-endpoint test file in Mix.

## Task 4: Fixed-profile failures and authority

- [x] Per protocol, stale CAS leaves current snapshot/baseline unchanged;
  rejected candidate preparation release joins custodian/peer zero effects.
- [x] Invalid candidate route after real preparation and actual coordinator
  death/abandonment release candidate only; active request still succeeds.
- [x] Store death after genuine capture closes baseline; fresh request fails
  finitely before delegate/checkout/Fetch; old captured right still completes.
- [x] Delay exact original delegation input, cancel actual actor, then unblock;
  same operation is revoked, no checkout/Fetch, no child/token/peer effect.
- [x] Genuine protocol/authority/instance mismatch fails binding before checkout
  and Fetch; nonempty capture with no matching selected T4, forged ref and
  wrong-holder source remain refused. Preserve empty-list standalone semantics
  (no Generation provenance marker); actual Store receipts are never deleted.
- [x] Bounded short-stop/late original completion case retains failed cleanup
  receipt and charged custody until actual cleanup; late success cannot rewrite
  the earlier failure. Reuse existing release-order and failure contracts.
- [x] Fresh scoped failures GREEN with final peer totals and actual joins. Do
  not silently expand singleton scope into multi-owner/group qualification.

## Task 5: Reviewed browser adaptation and actual four-row gate

- [x] Root creates fixed Store host and two-navigation runner in evidence;
  copy/hash-bind predecessor Cohort unchanged. Reuse Actor/CDP actual terminal,
  all-child custody, process-group/reader joins and browser cleanup unchanged.
- [x] Adapt only host fixed-T preparation/CAS/one-effect/one-pin expectations
  and explicit old/new CDP navigation commands, visible labelled pages, target
  matching and four upstream/downstream row inventory. Add listener rebind.
- [x] Independently review frozen complete fixture SPEC then CODE before run;
  root records checkpoint and exact command/source/loaded identity inventory.
- [x] Execute four rows with actual Chrome TLS+h2 for downstream H2. Require
  visible old/new DOM/title/URL/status/protocol/screenshots/console silence,
  real checked old/new capture/custody/retirement, complete cohort/native95/W+B,
  request_clean/live-before-close/explicitclose, actual joins/Gate0/rebind.
- [x] Root views screenshots. Preserve each failure, diagnose exact causal
  phase, repair without weakening assertions, review changed fixture before
  rerun. New evidence files use new names; originals are immutable.

## Task 6: Final complete review and fresh scoped verification

- [ ] Freeze candidate including all changed source/tests/browser/docs and
  actual evidence hashes; independent full-stage SPEC then independent CODE.
  Resolve findings additively, rebind/re-review affected candidate.
- [ ] After both pass, run the following exact unfiltered union (three commands
  permitted, no duplicates); record actual tests/failures/skips/exclusions,
  warnings, true exit, source before/after, command and environment.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs apps/gaoxy_proxy/test/managed_generation_accounting_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_endpoint_validation_test.exs apps/gaoxy_http/test/generation_resource_consistency_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/http2_worker_startup_test.exs apps/gaoxy_http/test/http2_stale_start_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/external-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/http-consumer.sh
```

- [ ] Include changed evidence .exs in exact format and Python syntax check;
  broaden scoped existing tests only for an evidenced additional repair seam.
- [ ] Run fresh post-review browser four rows with unique run/receipt names.
  Fresh source identities must equal reviewed candidate; no borrowed old pass.

## Task 7: Acceptance, custody, local commit and successor

- [ ] Write matching acceptance with commands/counts/exits/source/evidence,
  original failures/counters, exact accepted singleton profile and open gates.
- [ ] Factual current-status sync in design/plan/implement-plan/upstream Task5.
  Independent document and exact-byte/index custody audit; preserve archive
  bytes and both unrelated user prompts. No private key/raw sensitive trace.
- [ ] Stage only task-owned files and record actual disk/index/blob identities;
  local conventional feature commit, then verify actual commit/tree/captured
  bytes and clean task tree. Root owns Git; no push/publication/deployment.
- [ ] After closure, prepare next bounded existing M3 requirement with written
  design/plan/review automatically; no claim that full Task5 or M3 is complete.
