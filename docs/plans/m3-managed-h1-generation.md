# M3 managed H1 Generation implementation plan

> **For agentic workers:** Use the available `subagent-driven-development` or
> `executing-plans` skill task by task under the Sol coordinator. Parent assigns
> disjoint writers and owns serialized runtime/build/format commands and commits.

**Goal:** Retain authentic old managed-H1 request rights across atomic generation
replacement while fresh requests use the new immutable resources.

**Architecture:** Reuse the native Generation snapshot's outer pins. After Service
activation, its native holder authorizes a bounded one-use derivation into a
Session-owned transport pin; only Session performs guardian-authenticated
checkout. Configuration retirement closes ordinary admission immediately.

**Tech stack:** Existing OTP resource ledgers/Generation, ExUnit, public HTTP
Fetch/runtime 0.21.4 H1 APIs, local independent TCP/verified TLS peers.

**Status:** PASS from accepted groups documentation successor
`29068aa8575d4dfd47d04200d9019bdc27d2d193`. Complete independent SPEC/CODE and
fresh post-review341/0, scoped format and strict compile pass. Task-owned source,
tests, documentation and evidence are included in the local conventional commit.
[Design](../designs/m3-managed-h1-generation.md) is normative. The original
readiness receipt preserves its earlier unfinished-predecessor snapshot;
execution still requires accepted groups/probes and a recorded fresh kickoff.

## Prerequisites, ownership and source identity

Implement after full accepted [groups/probes](m3-managed-h1-groups.md), following
fixed endpoint acceptance. Inspected foundation HEAD
`5b73f5a951d506f194d090a0083183a79d577d6e` on
`codex/m3-h1-resource-foundation` in `.trees/m3-h1-resource-foundation` is the
design observation baseline, not the eventual execution SHA. Preserve concurrent
fixed-endpoint source/tests/docs/evidence. Parent records actual accepted group
source, tree/cohort hashes, diff/untracked inventory, readiness review and writers.

Carry cumulative unsuccessful UP2 20/8/3, foundation Step 7 5, fixed initial 1
and identity repair 1 PASS at handoff; update from later parent receipts. Astra
2/2 remains exhausted; design adds zero recovery rounds. No third recovery,
publication/deployment, production/Vault/public management, H2/H3/standalone,
capability changes or disabled-E2E execution. Preserve seven-package 0.21.4,
explicit DER H1 and peer ALPN exactly null. #97 is excluded, not a hidden gate.
During preparation the parent reported fixed package attempt 2, 114 tests /
16 failures; this is unfinished prerequisite evidence, not a gate passed here.

| Owner | Exact implementation scope |
| --- | --- |
| Sol transport writer | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`; new `apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs` |
| Sol dispatch writer, after API freeze | `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`, `apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex`; new `apps/gaoxy_proxy/test/upstream_transport_generation_test.exs` |
| Sol candidate-failure test writer | New `apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs`; production and existing tests read-only |
| Parent | This design/plan, future `docs/acceptance/m3-managed-h1-generation.md` and `docs/acceptance/evidence/m3/managed-h1-generation/`, all execution/review/commits |

Generic `apps/gaoxy_http/lib/gaoxy/http/generation.ex`, `resources.ex`, `router.ex`
are read-only dependencies unless a demonstrated necessary compatibility change
is explicitly assigned by the parent. Their tests remain affected checks. No
dependency private state or patches. All writers share the tree and preserve
others' edits. Independent peer/test design can proceed while transport work
runs; shared HTTP/Session production edits wait for predecessor/API freeze.

### Parallel test-fixture clarification — 2026-10-14

The dispatch writer may build only its new Generation test file and initial
pre-Session RED fixtures while the transport writer develops its disjoint tests
and owner API. These fixtures use existing public Generation/resource contracts
and do not edit HTTP/Session/GroupEndpoint or assume a passing delegation API.
Shared dispatch production edits still wait for transport GREEN and API freeze.
Parent serializes every runtime command and first freezes both writers. This
clarifies independent test work; required tests, assertions and acceptance gates
remain unchanged.

## Step 0: Readiness and focused failure reproduction

- [x] Parent verifies preceding acceptance, records exact baseline/ownership and
  obtains independent design/readiness review. Confirm ordinary validation and
  new derivation distinguish natural closure from explicit retirement.
- [x] Add a deterministic test in the new handoff file using the accepted
  transport fixture: prepare resource, baseline held by a coordinator, request
  pin held by native actor, release baseline/preparation and await admission
  closed. Demonstrate old ordinary `validate_endpoint/3` and pin acquisition
  reject while source pin/resource still exists. Preserve those assertions after
  implementation; this expected rejection is the motivating invariant.
- [x] Add the corresponding RED expectation for the new API called by the native
  actor: derive guardian pin, have guardian checkout with **its own** pin, open a
  real request and bind original completion. Wrong-holder source checkout still
  rejects. Parent observes nonzero RED from missing delegation, not unrelated
  networking/environment failures.

## Step 1: Atomic bounded source-pin derivation

**Files:** transport writer scope. Tag cases `:handoff_auth`.

- [x] Add a reusable local actor harness to the new test file. Native actor calls
  `Resources.pin_many([handle], self(), :request, D)` and reports pins to the test;
  test commands it to delegate, rather than issuing delegation from the test
  PID. Guardian actor calls checkout/finish itself. Each actor loop uses a finite
  receive timeout and test-owned monitor; no dependency-process introspection.
- [x] Use this exact new call shape inside the native actor:

```elixir
identity = %{origin: origin, upstream_protocol: :http1, instance: instance}
operation = make_ref()
result = UpstreamTransports.delegate_request_pin(
  handle, source_pin, guardian, identity, operation, deadline)
send(test_owner, {:delegated, self(), operation, result})
```

  Actor startup receives `handle`, stored `origin`, instance, guardian, test owner
  and D from the fixture; `source_pin` comes from that actor's real acquisition.
- [x] Test wrong holder even when caller is source acquirer (Generation-style
  acquisition), forged/expanded pin, wrong ref/owner/epoch, unknown handle,
  baseline/preparation source, derived-source chaining, wrong instance/authority,
  malformed root URI/H2/H3 and dead guardian. Identity rejection leaves source
  ledger unchanged and allocates zero tokens; later valid delegation succeeds.
- [x] Parent records RED. Implement `delegate_request_pin/6` facade and one local
  owner transaction exactly as design: stored holder authentication, strict
  identity, lifetime checks, marker+pin serialized delta reservation, one-use
  source marker and monitored independent guardian pin. Keep public handle four
  keys/public pin eight keys; internal records own new deadline/marker fields.
- [x] Add synchronous `retirement_requested` record state before any custodian
  retire initiation. Reject delegation and checkout once set; owner/instance
  retirement remains overriding. Natural closed admission with a live source
  and no retirement initiation remains eligible for this API only.
  Reserve its maximum control-payload bytes at resource creation; capacity must
  never prevent the transition into retirement or hide uncharged metadata.
- [x] Parent GREEN with full foundation and fixed identity regressions. Freeze
  API/error contracts before dispatch implementation. Mismatch uses existing
  `:transport_endpoint_mismatch`; malformed identity uses
  `:invalid_transport_endpoint`; pin/auth/capacity/lifetime errors retain existing
  applicable shapes. Used-source conflict returns `:invalid_resource_pin`.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs --only handoff_auth
```

## Step 2: One-use accounting, deadlines and death races

**Files:** transport writer scope. Tag cases `:handoff_lifecycle`.

- [x] Add exact existing `max_pins` and `max_owned_payload_bytes` boundary cases:
  full source-marker plus child-pin delta fits once, next byte/slot rejects without
  partial mutation. Count markers in aggregate owned payload; no opaque scope or
  completion serialization. Reject oversized input before contacting owner.
- [x] Test identical operation idempotence while child is live, different guardian
  or operation denial, replay after child release denial, and source+child final
  release restores all metadata. Source release before child leaves independent
  guardian ownership intact. Derived pin cannot derive again.
- [x] Test D expired and D greater than stored source D, owner suspended until
  after admission D, late reply cancellation, native death before reply, guardian
  death before/after grant, queued cancel/release ordering and repeated cancel.
  All receives are finite; cancellation uses original operation and same caller.
- [x] Test explicit owner retirement, instance death and resource retirement
  initiation before custodian acknowledgement. No derived pin/token/Fetch may
  be admitted in that window. Do not weaken ordinary closed-admission errors.
- [x] Parent RED then minimal implementation adjustments; GREEN after preserving
  all assertions. Repeat 100 create/derive/release cycles on a held baseline and
  assert live ledger size/serialized payload returns exactly to the initial
  baseline; no permanent consumed-ref/operation map remains.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs --only handoff_lifecycle
```

## Step 3: Captured outer holds and activated Session handoff

**Files:** dispatch writer scope. Add tag `:generation_handoff` to focused cases
in `upstream_transport_generation_test.exs`.

- [x] Create an observed endpoint wrapper modeled on
  `UpstreamGroupProxyTest.Observed`: resources delegates purely to HTTP or
  GroupEndpoint; call reports native PID and waits up to 3,000 ms for `:dispatch`
  before invoking the real endpoint. Install this wrapper behind Generation on
  the transport's own Gaoxy instance. This is the pre-Session snapshot barrier.
- [x] Add RED asserting fixed and managed group routes reuse all snapshot pins;
  outer pin counts do not increase. Partial/fake captured sets must fail before
  token allocation, without mixing fresh handles from the current generation.
- [x] Add held/denied Service cleanup activation test: zero guardian pins,
  transport tokens and upstream requests before activation even with old native
  pins present. A Session presenting another holder's genuine source pin directly
  to delegate/check out still fails.
- [x] Implement one private native/Session handoff reference, the once-only
  pre-ready pump event and Session awaiting-pin state. Native chooses its own
  captured pin and invokes delegate with minimum D. Session remains responsive
  to owner/service monitors/cancellation/timers while waiting; matching result is
  stored then checked out by guardian `self()` exactly once.
- [x] Add forged PID-with-wrong-reference, wrong selected handle, duplicate event,
  duplicate/late response, native drain-shortened D, Session timeout/death and
  native death cases. No unknown grant escapes guardian monitoring; native can
  cancel an undelivered grant as acquirer, then releases only its own outer pins.
- [x] Preserve direct fixed/probe ordinary validation paths and all default
  dedicated assertions. Group local handoff denial before Fetch finishes selection
  as cancelled; no health penalty. Original completion still binds both tokens
  before upload readiness.
- [x] Parent GREEN with handoff suite and fixed/group proxy compatibility.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs --only generation_handoff
```

## Step 4: Atomic peer identity and candidate failure matrix

**Files:** new generation test file and disjoint new `upstream_transport_generation_failure_test.exs`. Tag cases `:generation_peers`.

- [x] Fixture candidate coordinator prepares transports/groups while remaining
  alive, holds returned preparation pins, builds route lists, invokes pure
  `Generation.prepare`, then CAS activation. Coordinator releases its pins after
  result; store baseline must exist first on success. Do not prepare resources
  inside the terminated `prepare_with` loader worker.
- [x] Execute this ordering for both fixed and group routes:

```elixir
assert_receive {:captured_snapshot, old_native}, 3_000
assert {:ok, old_generation, _} = Generation.snapshot(store)
assert {:ok, candidate} = Generation.prepare(store, new_routes)
assert {:ok, new_generation} = Generation.activate(store, old_generation, candidate)
refute old_generation == new_generation
# Fixture uses bounded polling of Gaoxy-owned status to observe old baseline
# removal and ordinary closed admission before permitting old dispatch.
assert :ok = await_old_configuration_closed(old_transport, 3_000)
send(old_native, :dispatch)
```

  Define `await_old_configuration_closed/2` in this file to poll aggregate status
  and a read-only ordinary validation error under an absolute deadline; return
  an error on timeout, never unconditional `:ok`. No baseline still present when
  the old request begins Session/handoff. Capture native's actual old resource
  handle in the wrapper so the helper does not consult the new configuration.
- [x] Independent peer logs must show held request on old peer and fresh request
  on new peer, exact raw targets/body/trailers, no alternate connection/replay,
  original completion and zero duplicate outer pins. After old cleanup require
  physical EOF and old resource/helper/creator joins.
- [x] TLS fixture binds same port on two loopback IPs, serves the same authority
  with two independently generated local CA/leaf chains, and records chain/SNI/
  null ALPN/peer label. Prepare old/new explicit DER and numeric pin together;
  assert each generation uses only its intended peer. Wrong DER and wrong host
  fail without fallback; no file trust read during request/probe execution.
- [x] Add stale CAS, invalid route, candidate transport/group capacity failure,
  partial baseline rollback, coordinator death before activation and lost
  activation reply. Current snapshot/baseline remains correct; rejected candidate
  resources retire without harming shared active handles. Old group starts no
  new probe claims after retirement; already claimed probes join conservatively.
- [x] Parent executes nonzero real TCP and TLS cases; a source-only assertion is
  not peer identity acceptance.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs --only generation_peers
```

## Step 5: Store death, late cleanup and reload plateau

**Files:** new generation test file. Tag cases `:generation_lifecycle`.

- [x] Hold native snapshot before Session, terminate Generation store, observe
  baseline loss and new snapshot failure, then let admitted old request derive
  and complete while instance/transport owner remains alive. Explicit owner/instance
  retirement instead rejects the same attempt; test both orders.
- [x] Hold original completion/ACK, cancel downstream or kill native/guardian,
  and assert token/resource reservations remain until confirmed public cleanup.
  Stop under shorter D must retain immutable non-success, with a separately
  recorded late cleanup/peer EOF observation. Never refund on client consumption.
- [x] Run two warmup reloads then 20 identical-topology sequential reloads, both
  fixed and group, observing real requests/probes. Join retired resources before
  each steady-state sample. Assert resource/pin/token/helper counts and Gaoxy-owned
  serialized payload/group bytes plateau exactly against the first steady sample;
  final stop returns all owner counters to zero and all peer/owned actors join.
- [x] Parent GREEN with generic Generation/Router resource and release-deadline
  compatibility. Do not broaden to unrelated tests or total-native-memory claims.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs --only generation_lifecycle
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/generation_loader_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/router_test.exs apps/gaoxy_http/test/router_network_test.exs
```

## Step 6: Independent SPEC then CODE and fresh acceptance

- [x] Freeze source and independently review complete SPEC against actual tests
  and peer evidence, then CODE against holder authentication, operation replay,
  exact capacity charging, retirement linearization, native/Session handshake,
  candidate rollback and no owner history. Resolve findings with preserved
  assertions/counters; Astra recovery budget is unchanged and exhausted.
- [x] Parent executes fresh canonical scoped format/strict compile plus the full
  unfiltered new suites and affected predecessor checks below, then Step 5's
  generic compatibility command. Record nonzero tests and actual exit codes.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/test/upstream_group_probe_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_group_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_probe_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs
```

- [x] Parent acceptance records source/environment/cohort/hash, command/count/exit,
  independent readiness/SPEC/CODE results, peer EOF/actor shutdown and counters.
  Keep PASS/FAIL/BLOCKED/NOT RUN explicit. A dependency defect follows upstream
  issue/blocker policy; unrelated failures remain visible without silent repair.
- [x] Parent stages task-owned accepted files and makes local conventional commit
  `feat(proxy): preserve managed H1 request ownership across generations`.
  No push/release/deploy. This accepts the bounded H1 Generation slice; H2 and
  standalone remain later designs, and no full M3 claim follows automatically.

## Preparation checks

This assignment ran only source/document inspection and document diff checks.
All implementation, runtime/format/compile commands, peer qualification and
independent review above are **NOT RUN** at preparation handoff.

## Execution kickoff — 2026-10-14

Groups/probes predecessor `5ea088a9e3fe2646a056b2078f31a34f7adb6049` and documentation successor `29068aa8575d4dfd47d04200d9019bdc27d2d193` are accepted; fresh168/0 and complete independent SPEC/CODE plus closure pass. The [kickoff](../acceptance/evidence/m3/managed-h1-generation/1791939932624888477/kickoff.json) and [fresh readiness](../acceptance/evidence/m3/managed-h1-generation/1791939932624888477/generation-fresh-readiness-review.json) capture actual source/tree/cohort and disjoint ownership. Source remains unchanged at readiness; no implementation/runtime acceptance is inferred. Transport writer begins tests-only RED; HTTP/Session/GroupEndpoint implementation waits for accepted transport API freeze. Parent alone runs commands and commits; all writers freeze first. Generation counters start0; inherited groupsGREEN2/production0/harness3/diagnoses2/SPEC0, fixed3/1/SPEC1, Foundation5 and UP2 20/8/3 persist; Astra recovery2/2 remains exhausted.


## Owner Steps0–2 verification — 2026-10-14

Complete unfiltered owner/predecessor repair executes core36/0 + proxy220/0, zero exclusions/skips, exit0 and stable source. All31 handoff cases and the deterministic peer preheader-EOF regression execute. Two unsuccessful GREENs are preserved as harness failures; production failures0, Astra2/2 unchanged. Independent bounded SPEC then CODE and transport API freeze are pending before releasing dispatch production. Steps3–6 remain incomplete.


## Bounded owner reviews and dispatch contracts — 2026-10-14

Independent Steps0–2 SPEC then CODE pass with no findings; fresh owner format/strict compile/unfiltered tests still precede API freeze. Full18-case dispatch RED executed18/15, including four new test-contract mistakes (dead-store500 and denied-TLS immutable cleanup failure) that must be corrected while retaining denial, uncertainty charges and fixture joins. Preserve failed TLS verification's original/public retirement non-success and charged records; test actor dismantling cannot substitute for public confirmation. Successful old/new and reload cases retain exact zero final counters. Generation counters GREEN2/production0/harness3/intentional diagnoses1/SPEC0, Astra2/2 unchanged.


## Dispatch release and disjoint candidate tests — 2026-10-14

Independent owner SPEC/CODE and fresh256/0, format/strict compile pass; exact API freeze recorded. Refined18-case RED has15 feature failures and0 test-contract errors; production release now covers native private-ref handshake and nonblocking activated Session await. Candidate failure cases are owned separately in `upstream_transport_generation_failure_test.exs` to allow parallel disjoint work. This necessary test-file split does not remove any Step4 requirement; final scoped format and unfiltered tests include both Generation files. All writers freeze before any parent runtime command.


## Candidate batch and additional dispatch coverage — 2026-10-14

All6 candidate-failure cases now execute6/0, exit0, no exclusions/skips and
stable source after the recorded tests-only four-limit fixture correction.
Independent bounded candidate SPEC then CODE pass. The lost-result boundary is
the embedding result held after successful Store reply/CAS, not an actual Store
reply timeout; generic activation deadline/provider rollback remains required.
Initial18 dispatch/peer cases plus31 owner cases pass within the separately
preserved55/6 fixture failure. Dispatcher now owns a tests-only adversarial and
late-cleanup batch; production stays frozen until parent observed RED/coverage.
Generation cumulative unsuccessful GREEN4/production0/harness5/diagnoses1/SPEC0,
Astra recovery2/2 unchanged. Complete Steps3–6 and fullstage acceptance remain
pending.

## Complete review repair — 2026-10-14

Complete unfiltered pre-review gates execute339/0 with no exclusions/skips,
stable172 source hashes, scoped format and strict compile. Independent complete
SPEC passes after four additive fixed/group TCP/TLS streaming replacement cases.
The initial SPEC rejection1 and all failed attempts remain preserved.

Independent complete CODE rejects one P2 deadline defect: handoff revocation
queues cancellation, then synchronous `Resources.release/1` starts a fresh
1,000ms owner deadline after D. The dispatch writer owns additive fixed/group
owner-barrier RED cases and the subsequent minimal nonblocking repair. Parent
must observe RED before releasing production edits. Existing implementation-
specific synchronous-release expectations may be replaced by strict same-caller/
operation cancellation, authentic grant removal and public zero-ledger cleanup
evidence; ownership, deadline, health, EOF, joins and immutable failure assertions
remain required. Complete SPEC/CODE re-review and fresh unfiltered gates follow.
Current counters GREEN4/production0/harness5/diagnoses1/SPEC1/CODE1;
Astra recovery2/2 stays exhausted.


## Final acceptance — 2026-10-14

The initial complete SPEC rejection is resolved by four additive streaming
replacement cases. The initial complete CODE rejection is resolved by two
held-owner real-drain regressions and nonblocking original-operation revocation.
ExpectedRED2/2 confirms the production deadline defect before the repair. The
first repair gate stops only at format (zero tests), is preserved, and is resolved
by parent formatting. No assertion or prescribed verification is removed.

Complete independent [SPEC](../acceptance/evidence/m3/managed-h1-generation/1791939932624888477/generation-complete-spec-after-code-repair.json)
then [CODE](../acceptance/evidence/m3/managed-h1-generation/1791939932624888477/generation-complete-code-after-deadline-repair.json)
pass with no unresolved finding. [Fresh post-review gates](../acceptance/evidence/m3/managed-h1-generation/1791939932624888477/generation-complete-post-review-fresh-gates-1791951191479727724.json)
pass format, strict compile and core36/proxy278/generic27 =341 executed/0 failures,
exclusions or skips, exit0 and172 stable source hashes. Parent reads the entire
raw log; intentional killed-actor/TLS diagnostics remain preserved. Current
counters GREEN4/productionGREENfail0/harness5/diagnoses1/SPEC1/CODE1, separately
confirmed CODE production finding1 and format rejection1; Astra recovery2/2.

All Steps0–6 are accepted in this local change. Continue automatically to
[managed H2 preparation](m3-managed-h2-preparation.md); its earlier independent
readiness is static and does not establish runtime acceptance. This commit does
not complete full M3 or authorize publication/deployment.
