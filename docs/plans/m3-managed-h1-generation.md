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

**Status:** Independent design/plan readiness PASS; implementation and runtime
acceptance **NOT RUN**. Every execution checkbox remains unchecked.
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
| Parent | This design/plan, future `docs/acceptance/m3-managed-h1-generation.md` and `docs/acceptance/evidence/m3/managed-h1-generation/`, all execution/review/commits |

Generic `apps/gaoxy_http/lib/gaoxy/http/generation.ex`, `resources.ex`, `router.ex`
are read-only dependencies unless a demonstrated necessary compatibility change
is explicitly assigned by the parent. Their tests remain affected checks. No
dependency private state or patches. All writers share the tree and preserve
others' edits. Independent peer/test design can proceed while transport work
runs; shared HTTP/Session production edits wait for predecessor/API freeze.

## Step 0: Readiness and focused failure reproduction

- [ ] Parent verifies preceding acceptance, records exact baseline/ownership and
  obtains independent design/readiness review. Confirm ordinary validation and
  new derivation distinguish natural closure from explicit retirement.
- [ ] Add a deterministic test in the new handoff file using the accepted
  transport fixture: prepare resource, baseline held by a coordinator, request
  pin held by native actor, release baseline/preparation and await admission
  closed. Demonstrate old ordinary `validate_endpoint/3` and pin acquisition
  reject while source pin/resource still exists. Preserve those assertions after
  implementation; this expected rejection is the motivating invariant.
- [ ] Add the corresponding RED expectation for the new API called by the native
  actor: derive guardian pin, have guardian checkout with **its own** pin, open a
  real request and bind original completion. Wrong-holder source checkout still
  rejects. Parent observes nonzero RED from missing delegation, not unrelated
  networking/environment failures.

## Step 1: Atomic bounded source-pin derivation

**Files:** transport writer scope. Tag cases `:handoff_auth`.

- [ ] Add a reusable local actor harness to the new test file. Native actor calls
  `Resources.pin_many([handle], self(), :request, D)` and reports pins to the test;
  test commands it to delegate, rather than issuing delegation from the test
  PID. Guardian actor calls checkout/finish itself. Each actor loop uses a finite
  receive timeout and test-owned monitor; no dependency-process introspection.
- [ ] Use this exact new call shape inside the native actor:

```elixir
identity = %{origin: origin, upstream_protocol: :http1, instance: instance}
operation = make_ref()
result = UpstreamTransports.delegate_request_pin(
  handle, source_pin, guardian, identity, operation, deadline)
send(test_owner, {:delegated, self(), operation, result})
```

  Actor startup receives `handle`, stored `origin`, instance, guardian, test owner
  and D from the fixture; `source_pin` comes from that actor's real acquisition.
- [ ] Test wrong holder even when caller is source acquirer (Generation-style
  acquisition), forged/expanded pin, wrong ref/owner/epoch, unknown handle,
  baseline/preparation source, derived-source chaining, wrong instance/authority,
  malformed root URI/H2/H3 and dead guardian. Identity rejection leaves source
  ledger unchanged and allocates zero tokens; later valid delegation succeeds.
- [ ] Parent records RED. Implement `delegate_request_pin/6` facade and one local
  owner transaction exactly as design: stored holder authentication, strict
  identity, lifetime checks, marker+pin serialized delta reservation, one-use
  source marker and monitored independent guardian pin. Keep public handle four
  keys/public pin eight keys; internal records own new deadline/marker fields.
- [ ] Add synchronous `retirement_requested` record state before any custodian
  retire initiation. Reject delegation and checkout once set; owner/instance
  retirement remains overriding. Natural closed admission with a live source
  and no retirement initiation remains eligible for this API only.
  Reserve its maximum control-payload bytes at resource creation; capacity must
  never prevent the transition into retirement or hide uncharged metadata.
- [ ] Parent GREEN with full foundation and fixed identity regressions. Freeze
  API/error contracts before dispatch implementation. Mismatch uses existing
  `:transport_endpoint_mismatch`; malformed identity uses
  `:invalid_transport_endpoint`; pin/auth/capacity/lifetime errors retain existing
  applicable shapes. Used-source conflict returns `:invalid_resource_pin`.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs --only handoff_auth
```

## Step 2: One-use accounting, deadlines and death races

**Files:** transport writer scope. Tag cases `:handoff_lifecycle`.

- [ ] Add exact existing `max_pins` and `max_owned_payload_bytes` boundary cases:
  full source-marker plus child-pin delta fits once, next byte/slot rejects without
  partial mutation. Count markers in aggregate owned payload; no opaque scope or
  completion serialization. Reject oversized input before contacting owner.
- [ ] Test identical operation idempotence while child is live, different guardian
  or operation denial, replay after child release denial, and source+child final
  release restores all metadata. Source release before child leaves independent
  guardian ownership intact. Derived pin cannot derive again.
- [ ] Test D expired and D greater than stored source D, owner suspended until
  after admission D, late reply cancellation, native death before reply, guardian
  death before/after grant, queued cancel/release ordering and repeated cancel.
  All receives are finite; cancellation uses original operation and same caller.
- [ ] Test explicit owner retirement, instance death and resource retirement
  initiation before custodian acknowledgement. No derived pin/token/Fetch may
  be admitted in that window. Do not weaken ordinary closed-admission errors.
- [ ] Parent RED then minimal implementation adjustments; GREEN after preserving
  all assertions. Repeat 100 create/derive/release cycles on a held baseline and
  assert live ledger size/serialized payload returns exactly to the initial
  baseline; no permanent consumed-ref/operation map remains.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs --only handoff_lifecycle
```

## Step 3: Captured outer holds and activated Session handoff

**Files:** dispatch writer scope. Add tag `:generation_handoff` to focused cases
in `upstream_transport_generation_test.exs`.

- [ ] Create an observed endpoint wrapper modeled on
  `UpstreamGroupProxyTest.Observed`: resources delegates purely to HTTP or
  GroupEndpoint; call reports native PID and waits up to 3,000 ms for `:dispatch`
  before invoking the real endpoint. Install this wrapper behind Generation on
  the transport's own Gaoxy instance. This is the pre-Session snapshot barrier.
- [ ] Add RED asserting fixed and managed group routes reuse all snapshot pins;
  outer pin counts do not increase. Partial/fake captured sets must fail before
  token allocation, without mixing fresh handles from the current generation.
- [ ] Add held/denied Service cleanup activation test: zero guardian pins,
  transport tokens and upstream requests before activation even with old native
  pins present. A Session presenting another holder's genuine source pin directly
  to delegate/check out still fails.
- [ ] Implement one private native/Session handoff reference, the once-only
  pre-ready pump event and Session awaiting-pin state. Native chooses its own
  captured pin and invokes delegate with minimum D. Session remains responsive
  to owner/service monitors/cancellation/timers while waiting; matching result is
  stored then checked out by guardian `self()` exactly once.
- [ ] Add forged PID-with-wrong-reference, wrong selected handle, duplicate event,
  duplicate/late response, native drain-shortened D, Session timeout/death and
  native death cases. No unknown grant escapes guardian monitoring; native can
  cancel an undelivered grant as acquirer, then releases only its own outer pins.
- [ ] Preserve direct fixed/probe ordinary validation paths and all default
  dedicated assertions. Group local handoff denial before Fetch finishes selection
  as cancelled; no health penalty. Original completion still binds both tokens
  before upload readiness.
- [ ] Parent GREEN with handoff suite and fixed/group proxy compatibility.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs --only generation_handoff
```

## Step 4: Atomic peer identity and candidate failure matrix

**Files:** new generation test file. Tag cases `:generation_peers`.

- [ ] Fixture candidate coordinator prepares transports/groups while remaining
  alive, holds returned preparation pins, builds route lists, invokes pure
  `Generation.prepare`, then CAS activation. Coordinator releases its pins after
  result; store baseline must exist first on success. Do not prepare resources
  inside the terminated `prepare_with` loader worker.
- [ ] Execute this ordering for both fixed and group routes:

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
- [ ] Independent peer logs must show held request on old peer and fresh request
  on new peer, exact raw targets/body/trailers, no alternate connection/replay,
  original completion and zero duplicate outer pins. After old cleanup require
  physical EOF and old resource/helper/creator joins.
- [ ] TLS fixture binds same port on two loopback IPs, serves the same authority
  with two independently generated local CA/leaf chains, and records chain/SNI/
  null ALPN/peer label. Prepare old/new explicit DER and numeric pin together;
  assert each generation uses only its intended peer. Wrong DER and wrong host
  fail without fallback; no file trust read during request/probe execution.
- [ ] Add stale CAS, invalid route, candidate transport/group capacity failure,
  partial baseline rollback, coordinator death before activation and lost
  activation reply. Current snapshot/baseline remains correct; rejected candidate
  resources retire without harming shared active handles. Old group starts no
  new probe claims after retirement; already claimed probes join conservatively.
- [ ] Parent executes nonzero real TCP and TLS cases; a source-only assertion is
  not peer identity acceptance.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs --only generation_peers
```

## Step 5: Store death, late cleanup and reload plateau

**Files:** new generation test file. Tag cases `:generation_lifecycle`.

- [ ] Hold native snapshot before Session, terminate Generation store, observe
  baseline loss and new snapshot failure, then let admitted old request derive
  and complete while instance/transport owner remains alive. Explicit owner/instance
  retirement instead rejects the same attempt; test both orders.
- [ ] Hold original completion/ACK, cancel downstream or kill native/guardian,
  and assert token/resource reservations remain until confirmed public cleanup.
  Stop under shorter D must retain immutable non-success, with a separately
  recorded late cleanup/peer EOF observation. Never refund on client consumption.
- [ ] Run two warmup reloads then 20 identical-topology sequential reloads, both
  fixed and group, observing real requests/probes. Join retired resources before
  each steady-state sample. Assert resource/pin/token/helper counts and Gaoxy-owned
  serialized payload/group bytes plateau exactly against the first steady sample;
  final stop returns all owner counters to zero and all peer/owned actors join.
- [ ] Parent GREEN with generic Generation/Router resource and release-deadline
  compatibility. Do not broaden to unrelated tests or total-native-memory claims.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_generation_test.exs --only generation_lifecycle
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/generation_loader_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/router_test.exs apps/gaoxy_http/test/router_network_test.exs
```

## Step 6: Independent SPEC then CODE and fresh acceptance

- [ ] Freeze source and independently review complete SPEC against actual tests
  and peer evidence, then CODE against holder authentication, operation replay,
  exact capacity charging, retirement linearization, native/Session handshake,
  candidate rollback and no owner history. Resolve findings with preserved
  assertions/counters; Astra recovery budget is unchanged and exhausted.
- [ ] Parent executes fresh canonical scoped format/strict compile plus the full
  unfiltered new suites and affected predecessor checks below, then Step 5's
  generic compatibility command. Record nonzero tests and actual exit codes.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_group_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_probe_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs
```

- [ ] Parent acceptance records source/environment/cohort/hash, command/count/exit,
  independent readiness/SPEC/CODE results, peer EOF/actor shutdown and counters.
  Keep PASS/FAIL/BLOCKED/NOT RUN explicit. A dependency defect follows upstream
  issue/blocker policy; unrelated failures remain visible without silent repair.
- [ ] Parent stages task-owned accepted files and makes local conventional commit
  `feat(proxy): preserve managed H1 request ownership across generations`.
  No push/release/deploy. This accepts the bounded H1 Generation slice; H2 and
  standalone remain later designs, and no full M3 claim follows automatically.

## Preparation checks

This assignment ran only source/document inspection and document diff checks.
All implementation, runtime/format/compile commands, peer qualification and
independent review above are **NOT RUN** at preparation handoff.
