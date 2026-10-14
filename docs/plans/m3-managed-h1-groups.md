# M3 managed H1 groups and probes implementation plan

> **For agentic workers:** Use the available `subagent-driven-development` or
> `executing-plans` skill task by task under the Sol coordinator. The parent
> assigns disjoint files and alone runs runtime/build/format commands and commits.

**Goal:** Activate explicit prepared H1 member transports for group requests and
health probes, preserving independent cleanup ownership and dedicated defaults.

**Architecture:** Pure bounded transport sidecars declare the group's resources.
The preparation caller acquires dependency pins; owners never call each other.
Session and Probe use separate group and transport tokens bound to one original
public completion.

**Tech stack:** Existing Elixir/OTP umbrella, ExUnit, HTTP Fetch/runtime 0.21.4
public managed H1 APIs, local raw TCP/OTP TLS peers, qualified Nix environment.

**Status:** Local implementation/runtime acceptance **PASS**, from fixed-endpoint successor `2e5f6767587abadb6fcdc63491cfa082a9106c42`: complete independent SPEC then CODE PASS, fresh168/0 with no exclusions/skips, strict compile and formatcheck PASS. Local implementation commit `5ea088a9e3fe2646a056b2078f31a34f7adb6049` is verified; historical failures remain recorded below. [Design](../designs/m3-managed-h1-groups.md) is the
normative contract. The original readiness receipt preserves its earlier
unfinished-predecessor snapshot; the parent records a fresh kickoff only after
fixed-endpoint local closure. Required live and final acceptance boxes remain unchecked at kickoff.

## Prerequisites, counters and file ownership

Inspected foundation HEAD `5b73f5a951d506f194d090a0083183a79d577d6e` in
`.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`.
Fixed-endpoint source/tests/documents are concurrently modified predecessor work.
Start only after its full scoped tests, independent SPEC/CODE review and fresh
acceptance pass. Parent records the actual successor commit/tree and releases
ownership. Do not reset/stash/revert concurrent or unrelated files.

Carry UP2 unsuccessful 20 live/8 production/3 harness; foundation Step 7
unsuccessful 5; fixed initial unsuccessful 1 and identity repair 1 PASS at handoff.
Preserve later Sol repair receipts. Astra 2/2 exhausted; architecture adds zero
recovery rounds. Continuing authorization covers ordinary Sol repairs and local
commits, not another Astra round, publication or deployment. Preserve exact null
TLS ALPN, original assertions, explicit DER H1 policy and seven-package 0.21.4
cohort; #97 and native-memory certification are not gates.
Subsequent parent update during preparation: fixed package attempt 2 recorded
114 tests / 16 failures. This plan does not qualify that unfinished predecessor.

| Owner at execution kickoff | Exact scope and responsibility |
| --- | --- |
| Sol group writer | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex`, `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex`, `apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex`; new `apps/gaoxy_proxy/test/upstream_group_transport_test.exs`; only the two predecessor guard contract tests in `apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs` |
| Sol Session writer, after group contract freezes | `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`; new `apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs` |
| Sol probe writer, after group contract freezes | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex`; new `apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs` |
| Parent | These design/plan documents, future `docs/acceptance/m3-managed-h1-groups.md` and `docs/acceptance/evidence/m3/managed-h1-groups/`; all execution/reviews/local commits |

Session and Probe work can proceed independently after shared owner interfaces
freeze. All writers are sharing the checkout and must preserve others' edits.
If HTTP dispatch needs a compatibility change, parent assigns
`apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` exclusively to the Session writer;
no simultaneous endpoint writer. Transport foundation, generic Resources,
Generation and Router require no executable changes in this package. No private
dependency code, standalone/H2/H3/capability edits or disabled E2E.

### Execution dependency clarification — 2026-10-14

The current group owner publishes a prepared group and immediately sends itself
`:kick_probes`; members are initially due at `Lifecycle.now()`. Existing
`Probe.init/1` is network-free, but its open continuation currently constructs
dedicated options without `config.transport`. Therefore the first live managed
preparation GREEN must wait for the planned managed Probe path. Pure option
support alone is not a runnable managed integration.

1. Execute Step 1 pure RED/GREEN.
2. The group writer adds Step 2 facade/resource support and the Step 4 owner
   `claim_probe` and neutral local-rejection handlers, then freezes interfaces.
3. The Probe writer executes its planned managed RED/GREEN before the parent's
   first live preparation GREEN. Session work may proceed independently in its
   disjoint files after the same interface freeze.
4. Complete all Step 2 rollback/deadline tests and Step 3–5 gates, followed by
   unfiltered final verification. Keep production scheduling and every assertion;
   do not add a scheduling switch, hide dedicated fallback or publish a partial
   integration. This changes execution dependencies, not the product contract.

## Step 0: Readiness and finite test embedding

- [x] Parent records actual path/branch/HEAD/tree, clean task boundary, untracked
  inventory, predecessor acceptance, cohort/source hashes, counters and writers.
- [x] Independent reviewer checks the design's sidecar, caller-owned dependency
  pins, retirement claim, original completion and failure classification. Resolve
  findings before releasing executable work; readiness is not runtime acceptance.
- [x] In each new test file create a local finite fixture modeled on accepted
  `upstream_transport_proxy_test.exs`: one real `Gaoxy.start_link()` instance,
  explicit transport owner with finite limits and group owner for that same
  instance, loopback peer and preparation pins. Install services using
  `Gaoxy.HTTP.service_spec/1` then `Gaoxy.add/2`, not a second instance.
- [x] Fixture teardown stops Gaoxy before sibling owners, awaits public resource
  retirement/peer EOF and joins owned actors; preserve non-success on deadline.
  Preparation/helper assertions use message barriers with 3,000 ms finite bounds,
  not arbitrary sleeps. Runtime-free config tests may use structural fake handles.

## Step 1: Pure member round trip and sidecar

**Files:** group writer's four files. Tests tagged `:group_transport_pure` in the
new `upstream_group_transport_test.exs`.

- [x] Write failing pure round-trip tests with this complete test body:

```elixir
@tag :group_transport_pure
test "managed transport survives both group option forms without owner calls" do
  transport = %{provider: Gaoxy.Proxy.UpstreamTransports, owner: self(),
                owner_epoch: make_ref(), resource: make_ref()}
  input = %{id: "api", members: [
    %{id: "one", upstream: "http://peer.test", transport: transport},
    %{id: "two", upstream: "http://peer.test", transport: transport}
  ]}
  assert {:ok, compiled} = Gaoxy.Proxy.UpstreamGroups.compile(input)
  assert Enum.all?(compiled.members, &(&1.config.transport == transport))
  assert {:ok, ^compiled} = Gaoxy.Proxy.UpstreamGroups.compile(compiled)
  refute_received {_, {_, _}, _}
end
```

- [x] Add exact seven-field managed/six-field dedicated handle tests, dedup order,
  unknown/expanded/stale handle, H2/H3, CA-file/address overrides, 32/33 members,
  full resource 64/65 and 65,536-byte limits across Router routes. A nonresponsive
  owner never makes pure `init/resources` wait. Group resource sidecars cannot
  contain policy/CA/scopes. Forgeries may pass structural validation but must fail
  exact owner record matching before selection/pinning.
- [x] Locate the predecessor's two explicit `config.transport == nil` Options
  guards and their rejection tests in `upstream_transport_proxy_test.exs`
  (reported at lines 107/117 before formatting: raw member and tampered compiled
  Options, each first asserting valid managed HTTP init). Replace those tests with managed round-trip
  preservation cases covering raw input and compiled structs. Remove both guards
  only as part of this complete integration; no guard-only intermediate release
  or silent transport erasure is acceptable. Preserve dedicated assertions.
- [x] Parent records nonzero RED with the Step 1 command below, then writer
  preserves `transport` in Options struct recompilation, adds bounded sidecar
  construction/validation and pure `UpstreamGroups.resources/1` as designed.
- [x] Parent reruns Step 1 plus existing group unit/member-limit tests; require
  zero failures and dedicated option behavior unchanged.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_group_transport_test.exs --only group_transport_pure
```

## Step 2: Managed preparation and rollback

**Files:** group writer scope. Tag these cases `:group_transport_prepare`.

- [x] Add real preparation tests for one/shared/multiple transport owners,
  cross-instance/wrong-authority transport, dead preparer, expired D and group
  capacity denial after transport preparation pins have succeeded. Assert no
  group/token publication and acquired-pin counts return to the previous value.
- [x] Add a candidate spanning two owners with second provider denial. Verify
  partial pin rollback and unchanged existing configuration; then prepare a
  valid candidate successfully to prove no poisoned owner state.
- [x] Add deterministic facade timeout/late owner reply and caller DOWN tests.
  Assert same-caller cancellation, no orphan group/preparation pin and no
  successful result after D. Keep reservations charged while cleanup is pending.
- [x] Parent records RED. Implement `instance(owner, D)` read-only identity,
  managed caller==preparer validation, per-member authority validation and
  caller-side transport pin acquisition; group handler derives sidecar locally.
  On errors cancel only this group's operation and this attempt's transport pins.
- [x] Test complete configuration acquisition explicitly:

```elixir
assert {:ok, group, preparation} =
  UpstreamGroups.prepare(groups, compiled, self(), deadline)
resources = UpstreamGroups.resources(group)
assert {:ok, baseline} = Resources.pin_many(resources, self(), :baseline, deadline)
assert :ok = Resources.release(preparation)
assert Enum.sort(resources) == Enum.sort([group | Enum.uniq(member_transports)])
```

  Here the fixture from Step 0 defines live `groups`, `compiled`, member transport
  handles and deadline; keep `baseline` until test teardown. Also release the
  original transport preparation pins once the group candidate has acquired its
  own dependency pins. Do not use `[group]` as the managed baseline resource set.
- [x] Parent GREEN; freeze group preparation/resource interface for Session and
  Probe writers. Owner handlers contain no calls to transport providers.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_group_transport_test.exs --only group_transport_prepare
```

## Step 3: Managed selected-member Session

**Files:** Session writer scope; GroupEndpoint outer holds remain group writer
owned until handoff. Use real peers in the new proxy test file.

- [x] Write RED for complete group+member outer resources, one selected member's
  Session-owned transport pin, no preactivation transport token/Fetch and no
  alternate-member replay. Two sequential requests to one member reuse one TCP
  connection; member/group limits remain enforced.
- [x] Add wrong authority/instance and transport-capacity rejection after group
  selection: no Fetch, group inflight returns to baseline, health unchanged,
  subsequent valid request succeeds. Local rejection finishes group `:cancelled`.
- [x] Implement managed selection after Service activation: persist group token,
  validate immutable transport, acquire own request pin, checkout once, open with
  returned policy and bind identical original completion to both tokens before
  ready/upload. Preserve raw URI/query, duplicate fields and trailer assertions.
- [x] Add pending completion/ACK, owner death, guardian death and open/bind error
  tests. No completion means uncertain transport token, not a fake refund.
  Confirmed cleanup finishes transport/pin then group then Service; failures stay
  visible. Verify original completion equality using Gaoxy-owned state/public
  completion values, not opaque dependency internals.
- [x] Parent GREEN with fixed endpoint and dedicated group proxy compatibility.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_proxy_test.exs
```

## Step 4: Managed Probe guardian and retirement claim

**Files:** Probe writer scope; parent briefly assigns required group-owner claim
and outcome handlers back to group writer, serialized against any shared edits.

- [x] Write RED holding a spawned probe before `claim_probe`: release the last
  group baseline, verify retiring state, then release the barrier. Claim must
  reject with no transport token or HEAD. A previously admitted probe is canceled
  and joined; do not assert impossible zero bytes after earlier admission.
- [x] Add HEAD original-completion binding to both owners, same immutable
  address/trust policy, one request pin held by Probe itself, cancellation and
  probe-owner/guardian death tests. No owner→owner calls or Probe.init network
  calls may be required; a held transport call must not block group status.
- [x] Implement `claim_probe(owner, token, D)` with authentic caller PID, active
  group, ready owner, unclaimed live token and deadline; return stored instance.
  Probe continuation claims first, validates/pins/checks out managed transport,
  binds original completion and retains its independent cleanup state.
- [x] Preserve dedicated health tests and add managed capacity-denial neutrality:
  HEAD never opened, next due scheduled, checked/success/failure/health unchanged.
  Real HEAD non-2xx/TLS/timeout failures still change health at existing thresholds;
  recovered healthy status still requires existing successes.
- [x] Parent GREEN; finite cleanup deadline must retain both probe and transport
  accounting on pending/unconfirmed public completion. Finish transport and pin
  before group probe completion; no dedicated fallback.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_group_probe_test.exs
```

## Step 5: Real verified TLS and combined lifecycle

- [x] Reuse accepted local fixture generation from
  `scripts/generate-fixtures.sh`; convert CA certificates to DER during resource
  preparation. Run managed group request and HEAD probe tests over verified OTP
  TLS with numeric dial pin, unchanged authority/SNI and peer ALPN exactly null.
- [x] Assert wrong trust/hostname rejects without fallback, no replay, immutable
  trust across requests/probes, shared transport dedup and separate original
  completion tokens. Preserve raw TCP/TLS forwarding assertions from the fixed
  package and dedicated group tests.
- [x] Hold active request/probe cleanup, stop Gaoxy under finite D, and observe
  pending before release; then public cleanup, physical peer EOF, helper/creator
  joins and zero final owner counts. A short failed stop remains a failed result
  even if a separately observed later cleanup succeeds.
- [x] Parent executes all new tests plus scoped existing compatibility below.
  Do not infer TLS/probe success from a stub or zero-test command.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs apps/gaoxy_proxy/test/upstream_group_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_probe_test.exs apps/gaoxy_proxy/test/upstream_group_tls_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs
```

## Step 6: Independent review, fresh checks and local handoff

- [x] Freeze source, record hashes and independently review SPEC then CODE.
  Reviewers trace group preparation rollback, full resource declaration,
  independent token/pin ownership, claim/retirement order, health neutrality,
  pending completion and actual TLS/EOF evidence. Resolve actionable findings;
  preserve every failed receipt and cumulative counters.
- [x] Parent runs fresh scoped format, strict compilation and the complete Step 5
  command after final fixes. Add `http.ex` to formatting only if assigned/changed.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
```

- [x] Record actual commands/environment/cohort/tree, nonzero counts, exits,
  reviews, peer/actor shutdown and exact evidence paths under parent acceptance.
  Distinguish PASS/FAIL/BLOCKED/NOT RUN. Unrelated failures remain visible without
  silent fixes; dependency defects follow upstream issue/blocker routing.
- [x] Parent stages only task-owned accepted files and commits locally with
  `feat(proxy): support managed H1 group members and probes`. No push/release.
  Proceed to Generation's readiness/kickoff automatically after this acceptance;
  do not describe this package as Generation/full Task 5/M3 completion.

## Historical preparation checks

Only source/document inspection and document diff checks belonged to the design
assignment. At that handoff the commands above were future execution commands;
tests, format, compile, network qualification and independent reviews were
**NOT RUN**. The execution checkpoints below supersede that preparation status.

## Execution kickoff — 2026-10-14

Accepted fixed predecessor `2bf0883cea1dce1a031016700bb012fb3faac8b5`, documentation successor `2e5f6767587abadb6fcdc63491cfa082a9106c42`; task checkout clean at boundary. Independent readiness and dependency-clarification review PASS. [Kickoff receipt](../acceptance/evidence/m3/managed-h1-groups/1791934732834992397/kickoff.json) records source/tree/cohort and ownership. Current inherited fixed counters are implementation3, harness1 and SPEC rejection1; earlier preparation counters above remain historical. Groups counters start at zero; Astra remains2/2.

### Pure configuration execution checkpoint

Expected RED11/11 executed failures, exit2 (26 exclusions); pure GREEN11/0, exit0 (26 exclusions); existing dedicated group/member-limit units10/0, exit0 with no exclusions. Source-stable receipts and independent bounded SPEC then CODE PASS are recorded in the [acceptance](../acceptance/m3-managed-h1-groups.md). Owner-authenticated sidecar construction and forged/stale handle rejection remain Step2; live preparation/Probe/Session acceptance is not inferred.

### Preparation and initial Probe execution checkpoint

Preparation expected RED12/12 and initial Probe expected RED4/4 preceded their
production integration. Combined unfiltered preparation/Probe/dedicated units
GREEN40/0, exit0, no skips/exclusions and stable source, completes Step2 and the
initial Probe path. Independent bounded owner/facade static SPEC then CODE PASS
has no findings; full Probe/lifecycle and stage review remain pending. The
initial Session RED5/4 contains three missing-integration failures and one
pre-Session fixture failure from concurrent probes competing for one token.
The fixture repair uses supported `max_probes: 1`, preserving actual HEADs and
all readiness/count/deadline assertions; rerun RED before Session production.
Groups counters are implementation0/harness1/SPEC rejection0. All receipts and
limitations are recorded in the acceptance; no stage acceptance is inferred.

### Final local verification — 2026-10-14

Complete independent SPEC then CODE PASS without findings, followed by fresh
unfiltered168/0, zero skips/exclusions, strict compile and scoped formatcheck
PASS. All nine executable hashes match both reviews and before/after runtime
snapshots. The [local acceptance receipt](../acceptance/evidence/m3/managed-h1-groups/1791934732834992397/groups-local-acceptance.json)
links exact commands/logs and unchanged cumulative counters. Local commit and
Generation kickoff follow document closure; this does not accept Generation or
full M3. Original168/5 and both intentional diagnostic failures remain FAIL.

Local commit `5ea088a9e3fe2646a056b2078f31a34f7adb6049` completes this package. The [commit receipt](../acceptance/evidence/m3/managed-h1-groups/1791934732834992397/groups-local-commit.json) verifies committed executable bytes against fresh acceptance. Generation readiness/kickoff follows automatically; no publication occurred.
