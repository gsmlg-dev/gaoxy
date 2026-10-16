# Fixed-T managed upstream-H2 Generation: read-only test map 1

Task `/root/fixed_h2_generation_test_map1`; **DONE (source investigation only)**; direct assignment. R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, inspected baseline `aa272c3dca700a9275a00bd23920d09bbd4748a1`, initial status clean. Root owns source/runtime/evidence/Git. Only this report and matching JSON are owned outputs. No test/build/runtime/browser/network/formatter or Git mutation was run. All read commands finished, no child process was left running. Investigation cutoff counters: group41/root54/Astra2of2; parent subsequently recorded root55 for a premature read of this not-yet-written report (no runtime/source change), new-stage failedGREEN0. This investigation adds zero Sol repair rounds or runtime failures. Predecessor completion is parent-provided/current documented context, not newly executed acceptance here. Historical memory was used only for orientation; all recommendations below come from this checkout.

## Recommended minimal scope and RED

Implement one new `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs` using the existing independent fixed-H2 peer. Keep fixed `:http2` (TLS/ALPN) and `:h2c` distinct. No GroupEndpoint, group owner, probe or synthetic source pin. Rotation/20 reloads/full streaming matrix/standalone/load/H3 accounting remain later slices. Preserve current budgets and assertions; do not infer that this profile finishes M3.

**First behavioral RED:** two parameterized cases, one per upstream protocol. Start a genuine empty Generation Store, transport owner and real native HTTP listener whose endpoint is the production *checked* Generation endpoint. Prepare a real transport from a real manual Python H2 peer and call `Generation.prepare(store, direct_proxy_routes, timeout)` expecting success. Today the existing `ProxyHTTP.generation_validate/1` returns `{:error, :unsupported_generation_endpoint}` (http.ex:242-244), so this must fail exactly there before a request is delegated. No missing function, dummy owner, wrapper bypass or fixture compile failure counts as RED. Listener/owner/Store/peer must still join in failing-test cleanup; preserve the actual failing assertion/exit/source. This setup proves the intended public route is exercised, though the failing run cannot itself establish old/new protocol behavior.

**Separate activation RED:** compile a direct ProxyHTTP router using that actual prepared T handle; attempt public activate and raw Store `{:activate, current, compiled, deadline}` with expected `{:ok, generation}`, in separate cases/Stores so one failing assertion does not mask the other. Also cover initial `routes:` and `router:` start paths as acceptance after the guard changes. Do not rely solely on a wrapper's optional hook. Current denial and Store compiled-bound ordering are source-proven, not an executed RED in this report.

After source changes, four bounded socket old/new cases (`downstream :http1/:http2` x `upstream :h2c/:http2`) reuse one implementation. This is one CAS and one held old request per case, not the full streaming/reload matrix.

## Exact checked capture path and minimal new helper contracts

Production listener configuration must be:

```elixir
Gaoxy.HTTP.service_spec(
  id: :http,
  endpoint: {Generation, {store, accounting: ManagedGenerationAccounting}},
  protocols: [downstream],
  h2c: if(downstream == :http2, do: :prior_knowledge, else: :disabled),
  limits: %{max_bytes: 536_870_912},
  http_limits: %{request_timeout: 15_000}
)
```

Real listener accepts -> native connection/request worker -> `Generation.call/2` (generation.ex:133-147) derives context from original native self/gate/lease/deadline, reserves B and updates real Admission *before* checked Store provider effects -> checked snapshot -> `checked_router/5` (308-321) appends genuine receipts into `Exchange.resource_pins` -> Router -> test wrapper `call/2`. Hold here. The Store has already replied, and is free to process CAS. The wrapper must not hold the Store or transport owner's callback at this old-snapshot barrier. Before release there must be no Session, delegation, checkout, original Fetch request or upstream accept/request for this fixed route.

Minimal test-local wrapper, with exact initialized config and no reinitialization at dispatch:

```elixir
CapturedFixed.init({options, parent, label})
# ProxyHTTP.init(options) -> {:ok, {proxy_config, parent, label}}
CapturedFixed.resources({config, _, _})
# ProxyHTTP.resources(config)
CapturedFixed.generation_validate({config, _, _})
# ProxyHTTP.generation_validate(config), unchanged result
CapturedFixed.call(exchange, {config, parent, label})
# send(parent, {:fixed_generation_capture, self(), ref, label, exchange})
# wait finite min(test_deadline, exchange.deadline) for {:dispatch, ref}
# result = ProxyHTTP.call(exchange, config)
# optionally send {:fixed_generation_return, self(), ref, label, result}
# and wait {:return, ref} BEFORE returning result to checked Generation cleanup
```

The optional second barrier distinguishes opaque request completion from original snapshot-pin retirement. Keep the original Exchange and result unchanged. No manual `Resources.pin_many`, `resource_pins` edit, manufactured completion or fallback acquisition. Failure paths unblock both barriers using their exact refs and restore/remove any test hooks. Existing `upstream_transport_generation_test.exs:14-38` SnapshotEndpoint and `managed_generation_checked_capture_test.exs:993-1010` CapturedEndpoint are patterns only: **both omit generation_validate**, so using them unchanged for H2 would bypass the denial (Store optional callback path, generation.ex:708-716). Existing lifecycle CapturedPinEndpoint (lifecycle_test:10-23) manually pins and is unsuitable for this acceptance.

Suggested root-implemented fixture helpers (new, not currently exported APIs):

```elixir
fixed_generation_fixture(protocol, downstream, peer_options \\ ["--manual"])
# -> %{instance:, owner:, store:, downstream:, protocol:, listener_address:, peers:}
prepared_candidate(f, peer, ready, label)
# -> %{source:, transport:, preparation:, routes:, router:, coordinator:,
#      coordinator_monitor:, custodian:, custodian_monitor:, label:}
activate_candidate(f, candidate, expected_generation)
# coordinator performs CAS; releases its own preparation only after result;
# -> {:ok, candidate_with_generation} | {:error, finite_reason}
capture_fixed(f, candidate, label)
# -> %{native:, barrier:, exchange:, pin: genuine_T8, gate:, lease:}
assert_bound_fixed(f, candidate, captured)
# -> %{session:, session_monitor:, child_pin:, transport_token:, completion:}
release_dispatch(captured) # send(native, {:dispatch, ref})
release_return(captured)   # send(native, {:return, ref})
join_fixed_resource(f, candidate) # exact record removal + original custodian normal DOWN
finish_fixed_generation(f, candidates, peer_expected_counts)
# real Gate0, cleanup0, transport all-zero, exact actors/peer exits + listener rebind
```

Use the H1 coordinator model, `upstream_transport_generation_test.exs:2323-2423`, including holder-correct preparation release and authentic coordinator DOWN. The current H1 fixed candidate options omit `upstream_protocol`, identity is hardcoded `:http1` (2525-2526), and service uses legacy unchecked Generation (2446-2454); do not copy those limitations. New options include `upstream_protocol: protocol`, and `source.protocol` must match. Source mapping is `%{protocol: p, origin: scheme <> "://localhost:" <> ready["port"], connect_address: {127,0,0,1}, trust: p==:http2 && F.certificates(ready["ca"]) || nil}` (fixed endpoint fixture:209-217).

At capture assert one genuine T8, exact keys/handles/provider/owner_epoch/operation/ref/kind/holder; owner ledger `hold.public === pin`, `hold.acquirer === store`, `pin.holder === native`, `pin.kind === :request`, `pin.handles === [candidate.transport]`. Copy authenticity checks at H1 capture:2457-2485 and checked correlate:1541-1554. Record `.gate`, `.lease`, `.deadline`, `.route_bytes`, `.transport` from actual Exchange. Upstream fixed path is T-only: do not carry the predecessor group test's hardcoded two owner effects/two pins. Retain independent B calculation and exact real-Gate precharge checks from checked-capture:1479-1555, adapting to **one** real owner. Observe Store-to-owner input with the existing :sys hook pattern:1385-1435; briefly pause at that provider input solely to inspect the charged Gate, release it before the final endpoint capture so Store is free. The one-effect change is fixture expectation, not reduced charge or relaxed accounting. Downstream H2 retains original95-row W accounting/cohort semantics.

## Deterministic old/new and retirement sequence

1. Start old and new *separate* independent manual peers; each has its own ready identity, port and collector PID. Prepare/activate old, release preparation through its holder; assert Store exact generation/router and only its baseline pin. Start listener and send `/old%2Fpath?raw=%2F` over real socket. Capture the real native T8 at wrapper before ProxyHTTP.call. Validate actual Admission charge and original Store operation as above; assert no delegate/checkout/token/accept/request.
2. Prepare new and CAS against old generation through real Generation. Verify new router/generation exactly; release candidate preparation. Wait old baseline/preparation absent and old record admission closed, but old T8 still genuine and custodian alive (H1 await_closed:2488-2501). `validate_endpoint` with a fresh uncaptured right refuses `:resource_admission_closed`; existing old captured right remains. Do not call owner-wide retire merely to inspect retirement: it explicitly overrides rights and would change the scenario.
3. Release old dispatch. Independently collect old `accept`, `request`, and TLS event where relevant. Assert target and `:authority` exactly, old peer+connection+stream identity; correlate with old transport/resource. The identity is `(peer identity/collector, connection, stream)`: both peer processes may legitimately call their first connection `1`, so `old["connection"] != new["connection"]` alone is wrong.
4. Inspect authentic owner token and Session after bind using H1 bound_request:2530-2571 and fixed lifecycle:119-153: one original native T8 remains, exactly one distinct Session child T8 for same old transport, child holder Session, child owner-ledger acquirer native; original completion is `state.client.completion(state.original_request)` and exactly owner token completion. Require pending public `HTTP.RequestCompletion.await(completion,0)` while manual peer withholds response; taskDOWN or response body EOF alone cannot substitute. No repeated outer acquisition. Use public completion methods only, never private dependency process state.
5. Start new native request `/new%2Fpath?`; capture real new T8, release and observe *new* peer identity/authority/connection, no old resource use. Respond new first and await exact new completion and Session normal DOWN; old remains pending. Inspect resource-relative pin/token sets rather than copying static fixture pins==3 wholesale while two generations coexist.
6. Complete old via `F.command(old_peer, old_request, "respond", %{...})`; exact binary response and ordered fields stay meaningful. Hold old at second wrapper return barrier before Generation checked_cleanup. Await original old completion :ok and Session normal DOWN, token/child released; original old native T8 still present and old resource/custodian not retired. Release return barrier; Generation releases its own original snapshot receipt under its original absolute cleanup deadline. Only then assert old record absent, original custodian normal DOWN and exact old connection physical EOF/reset. If completion and native pin release happen together without this independent hold, the test has not proved both lifetimes separately.
7. Close downstream sockets normally and join H2 workers, connection and Writer using genuine monitor/trace evidence. While H2 socket remains open, connection/Writer leases are legitimate; only after close require real Gate active0/bytes0/cleanup_pending0/cleanup_failed nil. Stop Store -> all T status fields0 -> normal custodians/owner/instance/service joins -> peer joined forced0/live0/failedfalse/request totals exact -> real listener address rebind succeeds. Capture actual address before stop; after normal stop `:gen_tcp.listen(port, [:binary,active: false,ip: ip,reuseaddr: true])` and close that test socket. Existing fixed close helper does not itself prove rebind: this is a small additional scoped assertion.

## Additional bounded fixed-profile regressions

Each should use real prepared H2 resources and both protocols; H2 listener/accounting compatibility is additionally covered by the four primary socket cases and browser gates. Reuse deterministic barriers, not arbitrary sleeps.

- **Stale CAS:** H1 source:233-263. New prepared rejected candidate CAS against stale generation returns exact `:stale_generation`, active router/baseline/charge unchanged, rejected preparation released/custodian joined, rejected peer final accepts0/requests0, current request still succeeds at active exact peer. Do not require a fixed-H2 preparation to emit a probe: there are none.
- **Preparation failure/abandonment:** H1 generation:267-296; failure_test:14-60. Invalid route after actual fresh preparation plus shared active preparation releases only candidate holds; active resource/baseline unchanged; new peer zero effects. Add actual coordinator death before activation. A T-owner max_resources failure may reuse max_resources2/admitted-prefix checks; no group capacity test is needed for T-only scope. Preserve exact error and source identity.
- **Partial baseline rollback:** failure_test:95-174 supplies a genuine two-owner ordering/barrier pattern. If testing multi-route partial baseline acquisition, keep each endpoint fixed H2, exact first operation cancellation/pin refunds and failed second resource, unchanged Store and active request. Do not relabel the unchanged H1 case as H2 qualification. One fixed-T route alone has no multi-owner prefix, so this extension is optional unless the final design promises multi-route acquisition here.
- **Store death:** H1 generation:300-341. Capture old before dispatch, normally stop Store, old baseline closes while native old right survives. A fresh real listener request fails finitely with no capture/delegation/checkout/Fetch; then old dispatch still reaches exact old H2 peer and completes; last old pin/completion finally retires resource. Do not assert new successful activation after Store death.
- **Cancellation before delegation / late grant:** lifecycle_test:868-898 and H1 generation:708-853. Delay exact `delegate_request_pin` input for Store-derived T8; cancel Session/native using genuine actors; unblock same original operation; require revoke/no checkout/no Fetch/peer final accepts0/requests0 and no surviving child/token. The static fixture's manually acquired CapturedPinEndpoint is not the new acceptance source.
- **Completion/cleanup late failure:** release_order:109-165 supplies exact finish -> child-pin release -> Service receipt -> Session normal DOWN barriers; lifecycle:119-153 proves consumed != completed. Adapt to CAS-closed old resource, one real original completion, pending until peer response/abort, no early token/pin/cleanup-budget refund. H1 generation:1092-1168 supplies failed short stop + late completion with sticky failure receipt; preserve `{:error,{:deadline_exceeded,:cleanup_pending}}` after late independent success, rather than converting an earlier failed stop to PASS. Test a bounded fixed-H2 version, without widening into new custody machinery.
- **Denied effects:** genuine sidecar mismatch over H2 compiled config must refuse prepare/public/direct/start paths before *baseline* owner input, Store snapshot unchanged. Request-side missing/forged/wrong-holder T8 refuses before checkout/Fetch using genuine Store capture as source. Use ordered :sys/debug barriers plus final peer counts; F.no_event/2's zero-time mailbox check alone is not proof of no future/remote effects.

## Exclusion test contract replacement

`managed_h2_generation_exclusion_test.exs:8-30` currently intentionally denies all fixed H2 with a syntactically shaped handle whose owner is the test process. Retain pure config/client/static compile coverage, but replace blanket unsupported validation/prepare/activate assertions **explicitly** with positive tests for genuine prepared T handles, same Store/CAS invariants and real listener behavior above. Fake handles cannot become positive fixtures.

`:33-59` forges Router.resources=[] while the ProxyHTTP config declares a transport. Replace the blanket `:unsupported_generation_endpoint` expected reason with `:invalid_endpoint_resources`, retaining public and raw direct Store calls, unchanged current router/generation and no baseline acquisition. Also run initial router/routes paths. The generic consistency suite already tests missing/extra/substituted/old_epoch across all five paths (resource_consistency:135-155,446-452); add fixed-H2 concrete binding rather than weakening this contract. Legitimate activation *must* contact a real owner to acquire baseline, so do not carry over the old no-owner-contact requirement to accepted valid routes.

`:62-70` H1 accepted prepare/activate/start behavior remains. Preserve generic hook-denied endpoints, hook invalid-return/raise/throw/exit and optional legacy behavior (`generation_endpoint_validation_test.exs:29-160`), resource-sidecar grammar/caps/epoch checks, fixed-H2 scheme/dedicated/missing-managed-handle/H3 rejection (fixed_endpoint_test:1041-1081), transport protocol/authority/instance mismatches (`upstream_transport_h2_identity_test.exs:70-220`), and H1/groups existing accepted tests. This task makes no group Generation acceptance or new group denial claim.

## Reusable callable peer/socket helpers and limitations

All locations in `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` unless stated:

- `F.peer(protocol, options \\ [])` :10-49 -> `{collector_pid, ready_map}`; maps :http2 to Python `--protocol tls`, other tested mode :h2c -> `h2c`; uses staged-start and only returns after prepared then ready. Hardcoded interpreter `/tmp/gaoxy-m3-h2-soak-venv/bin/python` (:24) is a real external environment prerequisite. This report does not verify it exists or has pinned packages.
- `F.certificates(path)` :309-311 reads CA into DER; transport source owns captured trust. TLS ready includes cert/key/CA and independent package/source identity. Peer source TLS :217-228 reports ALPN h2 and SNI; require both on new successful TLS profile.
- `F.event(peer, name)` :134-163 (5s finite), `F.no_event(peer,name)` :165-167, `F.command(peer, request, op, extra \\ %{})` :121-132. `request` includes connection/stream/target/headers/ended from real Python h2 events (peer.py:257-265). `--manual` suppresses automatic response. respond accepts status/fields/body64/trailers/ended; data/inform/reset/goaway/settings exist (peer.py:371-403).
- `F.connect(f)` :313-324 uses `f.instance` and `f.downstream`, sends real H2 preface+SETTINGS for downstream H2. `F.send_request(f,socket,method,target,fields \\ [],ended \\ true,id \\ 1)` :326-352 uses actual HPAX/frames or H1 wire. `F.send_body(f,socket,bytes,ended,id \\ 1)` :354-358; `F.response(f,socket,method \\ "GET",id \\ 1)` :360-371 parses actual wire. Generation fixture can provide this small map shape without using F.fixture.
- `F.eventually(predicate, expires \\ nil)` :629-645 is finite state polling; pair with causal message barriers for lifecycle transitions. `F.physical_termination(peer)` :581-606 consumes eof/reset. Peer stop event joined counts forced/live/failed (peer.py:406-429). Monitor collectors + require actual Python exit0, not only event receipts.
- **Not drop-in:** `F.fixture(protocol, downstream \\ :http1, peer_options \\ [], overrides \\ %{})` :209-307 manually creates static baseline and installs ProxyHTTP directly. `F.hold/2`, `F.clean/1`, `F.close/1` :541-627 assume this static one-resource/one-baseline embedding. Reuse source patterns, not these assumptions. F is defined in a test file, not test_helper; any scoped Mix invocation using it must also include managed_h2_fixed_endpoint_test.exs. Do not silently require that file from multiple tests and duplicate its test definitions.

## Browser proposal: preserve genuine Store and complete cohort, bounded adaptation

Do not rerun static `managed_h2_fixed_browser.py` and call it Generation proof: its HOST installs a static profile. Do not call predecessor browser host unchanged: host6 run/4 prepares an H1 group and compiles its own Captured target (:428-473). It executes at file top level (:1579-1583), so requiring it as a library is not safe. There is **no drop-in fixed-H2 Generation browser host** in the inspected sources.

Recommended bounded new evidence host/runner: use the new tested fixed Store wrapper/route, two manual Python H2 peers, one CAS and one old/new document per case. Keep four table rows (Chrome TLS/downstream h2 and clear downstream http/1.1, each to :h2c and :http2); these do not claim full streaming matrix. Old navigation pauses at genuine capture; host receives explicit CAS command and proves old closed/new baseline; old request returns visible labelled HTML after dispatch; request_clean confirms original completion/custody. A second navigation must use the new Store generation and distinct peer identity. This needs a small reviewed multi-navigation CDP command adaptation; runner8's BROWSER currently navigates only `/checked` once, so reuse is a source pattern, not unmodified executable acceptance. Keep socket tests as the detailed adversarial suite; browser need not duplicate every failure case.

Reusable exact artifacts from predecessor E=`docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300` (preserve immutable originals):

- `native-worker-browser-runner8.py`: `Actor(command,log,prefix='')` (:253 onward) with finite event/send/join semantics, process-group and reader/adopted-child custody; BROWSER source :128-228 asserts CDP actual `response.protocol` and status, TLS, exact visible DOM/URL/title/text, console silence, screenshot, explicit close command, Chrome exit0 and profile removal. `run_case(mode,evidence,certificates,spki,cases,joins)` :352-450 demonstrates ordering and exact custody comparison. Adapt source binding/inventory and fixed one owner effect/T8; do not inherit raw-H1 peer or group HEAD expectations (:413-416).
- `native-worker-browser-cohort3.exs`: `NativeWorkerBrowserCohort.install(gate,%{service: service,mode: :h1|:h2})` :13-37, `native_start(observer,pid,ancestry)` :39-43, `snapshot(observer,gate)` :47-62, `facts(observer)` :66, `stop(observer,gate)` :69-72. These support complete atomic Gate cuts and genuine native start/terminal attribution. Reuse an unchanged copied/hash-bound module with its existing finite scope; no new custom cohort algorithm is justified. `facts` is failure prefix, not completeness proof.
- host6 source :514-594 supplies listener ancestry/observer installation; :643-654 independent B; :675-798 capture+native95 checks; :822-875 request-clean and live-before-close guard; :923-980 final Gate cut/native/observer joins/all-zero transport/instance stop. Remove G-specific actors/expectations only as explicit fixed-T fixture contract. Preserve cohort accounting for every actual connection/Writer/worker; do not cap or pick a convenient Chrome socket.
- `managed_h2_fixed_qualification.py`: `Process(command,log,prefix='')` :1116-1176 is callable but weaker than latest Actor process-group custody; `request_event(peer,target)` :1248-1249 and `peer_command(peer,request,operation,**values)` :1252-1262 provide exact command_id/connection/stream correlation and can be reused independently. `fixture(...)` :1234-1245 starts a static host, so not the new Store gate.

New browser source/fixture needs independent SPEC then CODE review before execution, and fresh actual nonzero results after final production/code review. Record both upstream TLS+h2c evidence distinctly and root-view actual screenshots. No operational certificates: only existing generated ephemeral test fixtures. Browser close must be explicitly authorized after request_clean and live connection/Writer confirmation; then global Gate0 and real normal joins. Add exact listener rebind after stop. Do not lower target95/B/cohort assertions, accept missing actors/noproc-only joins, or equate forced disposal with success.

## Proposed exact scoped gates (all NOT RUN here)

Use existing toolchain shell `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1` and explicit filenames. Three groups avoid default full umbrella or repeating predecessor561 as a default:

1. New fixed profile + shared real fixture and directly affected managed-H2 lifecycle:
   `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs`
   `apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs`
   `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`
   `apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs`
   `apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs`.
2. Transport/H1/checked-native preservation:
   `apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs`
   `apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs`
   `apps/gaoxy_proxy/test/upstream_transport_generation_test.exs`
   `apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs`
   `apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs`
   `apps/gaoxy_proxy/test/managed_generation_accounting_test.exs`.
3. Generic Store boundary and native request-worker compatibility:
   `apps/gaoxy_http/test/generation_endpoint_validation_test.exs`
   `apps/gaoxy_http/test/generation_resource_consistency_test.exs`
   `apps/gaoxy_http/test/generation_resources_test.exs`
   `apps/gaoxy_http/test/generation_checked_capture_test.exs`
   `apps/gaoxy_http/test/generation_release_deadline_test.exs`
   `apps/gaoxy_http/test/generation_test.exs`
   `apps/gaoxy_http/test/http2_worker_startup_test.exs`
   `apps/gaoxy_http/test/http2_stale_start_test.exs`.

Run groups unfiltered; record actual counts/skips/exclusions/warnings/exits and source before/after. H1 Generation file includes already-accepted H1 twenty reloads; running it preserves H1 only, never claims new H2 reload evidence. If Session/transport/pump code changes during repair, add its exact related existing tests (e.g. `upstream_transports_test.exs`, `managed_h2_fixed_write_lifecycle_test.exs`, `managed_h2_fixed_control_bounds_test.exs`); do not assume this static list covers unplanned code edits. No full135-case external qualification default; reuse its peer helpers only unless actual changes demand its existing protocol cases.

Strict compile: `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors` (capture true result). Scoped format check uses exact changed .ex/.exs paths only; likely `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, new generation test and exclusion test, plus any actual new/changed evidence .exs. New Python source gets syntax-only compilation without writing repo pycache; this is not runtime acceptance. Both fresh isolated consumers: `nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/external-consumer.sh` and same `scripts/http-consumer.sh`; scripts copy only core/core+HTTP and run locked deps/strict compile/tests (:1-15). Preserve blocked network dependency route distinctly; root may use only already-authorized qualified fallback. No H3 consumer required by fixed upstream-H2 guard-only scope.

Browser gate is a **new reviewed** collector/host/runner under root's E2 evidence root, not a currently callable ready command. Proposed interface: `python3 -B <new-fixed-generation-browser-runner.py> --evidence-dir <new-unique-run-dir>` with exact frozen source set, bounded overall command, four explicit rows and real joins/exit0. Reusing old runner8 as executed would qualify the old H1 group only. Final review then fresh exact scoped union, browser and consumers; only then root closes checklist/commit. No publication or deployment inference.

## Open gaps / decisions for root's bounded design

- Actual constructor/accounting changes are owned by the production-source investigator/root. If fixed Generation exposes new charged operands/lifetimes, independent constructor checkpoint precedes runtime; this test map does not authorize assuming the old accounting is sufficient.
- New wrapper and optional return barrier, real Store fixed fixture, late-cleanup fixed variant and browser host/runner are proposed source work, not existing ready fixtures. Verify finite failure cleanup and no hidden validation bypass in independent source review.
- Hardcoded Python interpreter/pinned h2 requirements, Chrome/node/toolchain availability and fresh source/loaded binding are NOT VERIFIED here. Report BLOCKED_ENV if unavailable; no skip.
- Peer identity is collector+ready package/source/port+connection+stream. Existing fixed peer does not support same-authority numeric-IP/CA rotation; keep that explicit later slice, not a silent mock or guessed acceptance.
- No new user product decision is exposed by this test investigation. Root can select exact browser row count in written bounded design before review; four rows are the recommendation. No external permissions were used or requested.
