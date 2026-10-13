# M3 Managed H1 Fixed-Endpoint Implementation Plan

> For agentic workers: use executing-plans or parent-managed
> subagent-driven-development task by task. Sol implements and independently
> reviews. Continuing authorization replaces routine approval pauses; the parent
> releases executable freezes and serializes Mix/build/live commands.

**Goal:** Activate one explicitly prepared managed-H1 fixed reverse-proxy
endpoint while preserving dedicated H1 defaults and public completion ownership.

**Architecture:** Pure endpoint config holds only an optional existing transport
handle. A bounded read-only owner check validates its authoritative authority and
instance before Session allocates a token. Native dispatch and activated Session
hold separate request pins; Session binds original completion before upload and
finishes its token only after public cleanup.

**Tech stack:** Existing Elixir/OTP umbrella, ExUnit, installed HTTP
Fetch/http_runtime 0.21.4 public ManagedTransport/RequestCompletion APIs, local
raw TCP/OTP TLS peers and existing fixture script. No added dependencies.

**Status:** **DONE — local fixed-endpoint acceptance PASS**. Foundation and
fixed-endpoint prerequisites, independent SPEC then CODE, real TCP/verified TLS
and fresh178/0, strict compile and canonical formatcheck pass. Historical
failed rounds and the resolved SPEC gap remain preserved. Local commit follows
this verified document closure; groups/probes and Generation remain separate.
Read [the design](../designs/m3-managed-h1-fixed-endpoint.md).

Preparation source: `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`,
`a2296e2ca9f24b8fd0480b06a6728fc15d190520`. This identifies inspected Step 6
source; the parent records the actual implementation baseline at kickoff after
the foundation gates, rather than assuming a future SHA. Step 6 repair 1 was
rejected after 74/0 GREEN; repair 2 was accepted after 75/0, SPEC/CODE and fresh
75/0 verification. Inherit UP2 **20 live / 8 production / 3 harness** and
**Astra recovery 2/2 exhausted**. Do not reset counters or initiate a third
Astra recovery. Record new Sol repair rounds and immutable failing evidence.

## Scope and ownership

| File | Responsibility at execution kickoff |
| --- | --- |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` | Bounded read-only `validate_endpoint/3`; preserve ledger/authentication/retirement |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` | Pure optional transport config, resources and outer fixed dispatch pins |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex` | Activation order, guardian pins/checkout, completion bind and finish |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` | Managed request construction; preserve dedicated branch/callback shapes |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex` | Necessary rejection of unsupported managed members; preserve dedicated groups |
| `apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs` | New owner identity, real TCP/TLS endpoint and lifecycle regressions |
| `docs/designs/m3-managed-h1-fixed-endpoint.md` | This package's written design |
| `docs/plans/m3-managed-h1-fixed-endpoint.md` | This package's executable checklist |
| `docs/acceptance/m3-managed-h1-fixed-endpoint.md` | Parent-owned future acceptance record |
| `docs/acceptance/evidence/m3/managed-h1-fixed-endpoint/` | Parent-owned future exact-source receipts/logs |

Historical preparation owned only the two documents. The verified kickoff now
assigns disjoint executable writers; the earlier freeze is released only for
the files in the kickoff table below.
One source writer owns HTTP/Session/adapter together because their ordered
contracts depend on each other; independent identity/test preparation and reviews
can proceed in parallel with explicit ownership and frozen handoffs. Nobody
reverts another writer's changes. Parent alone runs Mix/live commands and commits.

Existing `http_proxy_runtime_test.exs`, `http_proxy_wire_test.exs`,
`http_proxy_tls_test.exs`, `http_fetch_completion_test.exs` are scoped affected
checks; preserve all their assertions. Add cases in the new file. A required
compatibility edit to an existing file needs explicit parent ownership, not a
test weakening. Generic Resources/Router/Generation, Groups/probes/H2/H3,
standalone/config/capability declarations and foundation Custodian remain out of
this package. Do not advertise deferred Generation integration.

## Step 0: Gate, identity and independent design review

- [x] Parent verifies every full foundation gate and records its acceptance
  receipts; preserve historical failures and Step 6 repair dispositions.
- [x] Record actual execution path/branch/HEAD/tree, cohort/lock hashes,
  diff/untracked inventory, accepted foundation source equivalence, owner limits,
  inherited counters and exclusive writers. Preserve unrelated files.
- [x] Independent SPEC review this design/plan, including cross-instance identity,
  two different pin holders, no-token mismatch, unbound uncertainty and lifetime
  ordering; resolve findings before executable edits.
- [x] Release only assigned source/test scope. Keep publication/deployment,
  production/Vault/public-management and disabled-E2E restrictions intact.

## Step 1: Test scaffolding and read-only identity compatibility

**Files:** create `apps/gaoxy_proxy/test/upstream_transport_identity_test.exs`;
modify only `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` for this step.

- [x] Add a bounded test embedding fixture: `Gaoxy.start_link`, explicit
  `UpstreamTransports.start_link(instance: instance, limits: limits)`, preparation
  source `%{origin: origin, connect_address: numeric_ip, trust: explicit_der_or_nil}`,
  preparation pin, and a baseline pin owned by a live test holder. Acquire
  baseline before releasing preparation. Cleanup calls `Gaoxy.stop` and awaits
  retirement/actor joins before stopping sibling owner/baseline holder. Never
  rely on teardown kill to count as cleanup success.
- [x] Add the listener to this existing instance with supported APIs after
  preparation; do not call `Gaoxy.HTTP.start_link` to create another instance:

```elixir
{:ok, spec} = Gaoxy.HTTP.service_spec(
  endpoint: {Gaoxy.Proxy.HTTP, %{upstream: origin, transport: handle}},
  limits: %{max_bytes: 16_777_216}
)
{:ok, _service_handle} = Gaoxy.add(instance, spec)
```

  The fixture owns finite local peers, instance, baseline and owner. Service-add
  failure drops candidate pins then joins resource retirement; successful
  teardown calls `Gaoxy.stop` before sibling shutdown. These APIs already exist;
  no service-start/core interface expansion is required.
- [x] Write identity RED cases using this exact intended API:

```elixir
identity = %{origin: origin, upstream_protocol: :http1, instance: instance}
before = UpstreamTransports.status(owner)
assert :ok = UpstreamTransports.validate_endpoint(handle, identity, deadline)
assert {:error, :transport_endpoint_mismatch} =
         UpstreamTransports.validate_endpoint(handle, %{identity | origin: other_origin}, deadline)
assert {:error, :transport_endpoint_mismatch} =
         UpstreamTransports.validate_endpoint(handle, %{identity | instance: other_instance}, deadline)
assert before == UpstreamTransports.status(owner)
```

- [x] Add malformed/expanded/stale handle, unknown identity key, H2/H3, oversized
  origin, authority credentials/path/query, expired deadline, unavailable/retiring
  resource and normalized case/default-port cases. Require zero token/helper
  additions and an unchanged valid resource after mismatch.
- [x] Parent observes nonzero RED attributable to missing API, preserving all
  old assertions. Implement `validate_endpoint/3` as bounded facade and owner
  handler, validating exact three-key identity and exact four-key handle before
  call, then current record/admission/instance and normalized stored authority.
  Return boolean success/error with identical state; allocate no pin/token/helper
  and return no policy or trust. Preserve existing deadline/resource errors.
- [x] Parent runs the new tests plus resource/options/preparation regressions;
  record counts/exits/source hashes. Do not claim success from a zero-test run.

## Step 2: Pure explicit endpoint opt-in and outer dispatch holds

**Files:** `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, new test file.

- [x] Write pure-init RED tests for a four-key handle with `upstream` and H1,
  config struct round trip and `resources/1`. Reject malformed handle, unknown
  key, H2/H3 and non-nil endpoint CA-file/numeric-address overrides. Assert
  no process/owner calls during pure validation, including a structurally valid
  handle whose owner cannot answer; actual liveness is checked at request time.

```elixir
assert {:ok, config} = ProxyHTTP.init(%{upstream: origin, transport: handle})
assert [^handle] = ProxyHTTP.resources(config)
assert {:ok, ^config} = ProxyHTTP.init(config)
assert {:ok, dedicated} = ProxyHTTP.init(%{upstream: origin})
assert [] = ProxyHTTP.resources(dedicated)
assert {:error, :invalid_http_proxy_options} =
         ProxyHTTP.init(%{upstream: origin, transport: handle, upstream_protocol: :http3})
```

- [x] Parent records RED. Add `transport: nil` to the config, bounded H1-only
  managed option validation and `resources/1`; retain current dedicated/H3 option
  rules. Init never invokes the read-only owner check or performs DNS/file reads
  on the managed branch.
- [x] Fixed managed `call/2` wraps dispatch in native-owned
  `Resources.pin_many([handle], self(), :request, exchange.deadline)` and `after
  Resources.release(pins)`. Pass captured identity and transport into Session;
  unavailable pin returns 503 before Fetch. Preserve dedicated/group paths;
  this wrapper does not consume Generation snapshot pins.
- [x] Parent runs pure and existing runtime configuration tests; maintain a
  synchronous barrier showing outer pin exists throughout active dispatch.

## Step 3: Activated Session, managed Fetch and original completion

**Files:** `http/session.ex`, `http_fetch_client.ex`, `http.ex`, new test file.
Paths are under `apps/gaoxy_proxy/lib/gaoxy/proxy/` as listed in the scope table.

- [x] Write held-activation RED tests with real loopback peers. Service byte
  denial, cancellation before activation, deadline expiry, mismatched origin or
  cross-instance handle must open no Fetch and allocate no transport token.
  Assert invalid requests leave a prepared resource usable for the next valid
  request. Use finite message barriers, not sleeps or private dependency state.
- [x] Write upload RED proving real peer receives first bytes before downstream
  EOF. Observe Session readiness and authenticated binding with the exact
  original completion before enabling upload. Wrong-holder outer pins alone
  cannot authenticate a Session checkout; owner authentication stays unchanged.
- [x] Parent freezes/observes RED. Add separate Session fields:

```elixir
transport_pins: [],
transport_selection: nil, # {handle, transport_token}, distinct from group selection
managed_transport: nil   # exact client policy returned by checkout, never caller input
```

- [x] Within existing cleanup activation after host/deadline checks, execute
  the following once, using `min(state.deadline, state.opening_deadline)`:

```elixir
:ok = UpstreamTransports.validate_endpoint(handle, identity, opening_deadline)
{:ok, guardian_pins} = Resources.pin_many([handle], self(), :request, opening_deadline)
{:ok, client_policy, transport_token} =
  UpstreamTransports.checkout(handle, guardian_pins, self(), opening_deadline)
```

  These lines describe success ordering; implement explicit `with`/case error
  paths that release acquired guardian pins when checkout fails, without
  allocating a token or calling Fetch again. Cancellation/retirement races must
  fail before open. Store holds immediately after acquisition so actor death
  remains monitored. Do not hand native-owner pins to transport checkout.
- [x] Build managed URL from validated prepared origin and unchanged path/query.
  Adapter validates compact bounded request fields/body through existing
  preparation helpers and constructs Fetch options from checkout's fixed profile,
  opaque scope and request-specific fields/timeouts. Omit dedicated SSL/socket/
  address overrides; keep dedicated construction unchanged. Do not inspect opaque
  scope fields or add public passthrough/dependencies.
- [x] Preserve `{:ok, request_handle, upload}` and original completion. Store
  request then call `UpstreamTransports.bind_completion(handle, transport_token,
  client.completion(request_handle))` before existing ready notification. Preserve
  group-selection binding independently; no group transport activation here.
- [x] Parent GREEN includes upload ordering, identity/no-token cases and existing
  public completion tests. Record actual binding identity and peer bytes.

## Step 4: Cleanup accounting and conservative failure joins

**Files:** `http/session.ex`, new test file.

- [x] Write RED for held response and outstanding ACK: public cleanup pending
  retains guardian pin/token and Service reservation; client consumption alone
  is insufficient. Release barriers and require public completion `:ok` before
  transport token finish, guardian-pin release and Service cleanup success.
- [x] Add finish/release ordering to existing `cleanup_complete/1`:

```elixir
# Execute only after original public request cleanup confirms :ok.
:ok = UpstreamTransports.finish(handle, transport_token)
:ok = Resources.release(guardian_pins)
# Existing group selection finish remains independent.
# Then call existing Gaoxy.Service.complete_cleanup(service, service_token).
```

  Handle failures explicitly, preserving conservative accounting and reporting
  cleanup failure. Pending completion keeps the fields/holds. Release pins on
  pre-checkout rejection; never finish an unallocated token. Existing finite
  cleanup continuation and actor monitors remain the failure mechanism.
- [x] Test deterministic open-to-bind failure/guardian death. If original
  completion is absent, finish remains cleanup unconfirmed and resource
  retirement does not refund unresolved request ownership. If completion exists,
  use public abort/join and retain uncertainty when its bind/join fails. Join
  owned upload actors; never synthesize a successful completion or weaken the
  foundation's unbound-token contract.
- [x] Test native-owner kill before headers, guardian kill with a bound request,
  idle-SSE downstream disconnect, stop while active and shortened caller wait.
  Require public cleanup/peer closure/actor joins and correct immutable stop
  outcome. A stopped/invalid owner cannot be converted into successful cleanup.
- [x] Parent GREEN records completion/token/guardian accounting separately from
  physical connection reservations. Preserve finite deadlines and original
  assertions through diagnosis/repair.

## Step 5: Real TCP and verified-TLS fixed-endpoint matrix

**Files:** new test file; existing fixture script is reused unchanged.

- [x] Add raw peer helper accepting exactly one connection and processing two
  sequential request heads/bodies on that connection. Include finite second-
  connection detection and report exact requests/bytes plus final EOF. Do not
  reuse the dedicated-default two-connection helper as a managed reuse oracle.
- [x] Run this same managed endpoint contract over TCP and verified OTP TLS:
  sequential reuse, binary request/response bytes, raw escaped and empty-query
  targets, duplicate fields, declared ordered request/response trailers,
  incremental upload before EOF, early final response and manual redirect.
  Keep framing/header policy assertions exact and retain no-replay observations.
- [x] TLS fixtures use `scripts/generate-fixtures.sh`, as
  `http_proxy_tls_test.exs` already does. Convert its CA PEM to explicit
  `:Certificate` DER entries during preparation, never inside endpoint init or
  per-request Fetch. Assert numeric routing preserves authority/SNI, wrong CA
  and wrong hostname reject without plaintext fallback, replay or credential
  forwarding. No default trust/client certificates/Vault behavior is added.
- [x] For wrong-CA/hostname setup rejection, apply the independently reviewed
  documented uncertainty contract: capture the original completion before ready,
  assert repeated public completion/retirement `cleanup_unconfirmed`, retired
  scope, exact Session reason and absent Service receipt. Preserve the
  token1/resource1/physical2/helper0 ledger and baseline1 before global retirement;
  require baseline0/failed-resource1 afterward. Queue stop behind the finite
  Service DOWN barrier; assert its exact Service/participant failure and immutable
  retirement result. Join the peer/helpers and explicitly dismantle test-owned
  failed actors only after recording uncertainty. Do not reuse the successful
  cleanup oracle or claim teardown confirmed cleanup.
- [x] After completed requests assert zero tokens and released request pins,
  while the baseline, resource and reserved physical capacity remain. Stop
  Gaoxy before sibling teardown; await peer EOF, real creator/helper joins,
  successful owner retirement and all owner counters restored to zero.
- [x] Parent runs new tests and scoped dedicated runtime/wire/TLS/completion
  regressions. Dedicated default's two upstream connections/EOF assertions
  remain unchanged. Broader checks run only for a demonstrated affected seam.

## Step 6: Review, fresh verification and local closure

- [x] Freeze source; independent SPEC review checks this design's full contract
  and exact TCP/TLS evidence. Resolve findings while preserving failing receipts.
- [x] Independent CODE review checks control flow, option branches, pin holders,
  token/Service-token separation, bound-completion identity, no replay and all
  error paths. Resolve findings; record cumulative repair counters.
- [x] Parent runs fresh canonical scoped formatting, strict compilation and all
  affected checks after review. Command templates below use the current qualified
  environment; record actual commands/tools/cohort at kickoff rather than
  claiming these commands already ran:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/managed_h1_preparation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/http_proxy_runtime_test.exs apps/gaoxy_proxy/test/http_proxy_wire_test.exs apps/gaoxy_proxy/test/http_proxy_tls_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs
```

  Expected: nonzero executed tests, zero failures, successful format/strict
  compile, real peer/actor joins and source-stable receipts. An unrelated failure
  stays visible; do not silently repair outside scope. A dependency defect uses
  repo upstream issue routing and blocker policy. No private API/deps patch or
  automatic workaround can replace a missing required public contract.
- [x] Parent records acceptance with exact source/environment/hashes, counts,
  exits, review identities and owned shutdown. Distinguish PASS, FAIL, BLOCKED,
  NOT RUN and hosted/publication/deployment states. No source-only acceptance
  replaces the prescribed real endpoint/TLS runs.
- [x] Stage only task-owned files and make a local conventional commit after
  accepted fresh checks. No AI trailers. Do not push/publish/deploy or change
  disabled E2E. Report this fixed-endpoint slice DONE; remaining Task 5 groups,
  probes/Generation and other protocol packages remain separate and unexecuted.

## Preparation verification

The initial preparation snapshot had all execution items unchecked. It ran source
inspection and document diff checks only. Tests/compile/format/live acceptance,
independent document review and implementation review are **NOT RUN**. Parent
receipts provide their eventual actual outcomes; no foundation or Task 5
acceptance is inferred from these documents.

## Preparation review and current prerequisite disposition

The [independent document review](../acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/next-task5-document-review.json)
passed design SPEC and plan readiness against the exact preparation hashes. The
historical preparation above records its initial unreviewed snapshot; this
receipt records the subsequent review. Implementation and network acceptance
remain **NOT RUN**. Full foundation is **DONE** after restoring the original exact null contract,
independent final review and fresh all-eight verification. [http_fetch#107](https://github.com/gsmlg-dev/http_fetch/issues/107) is optional and no prerequisite. Do not release executable Task 5 ownership until foundation's
prescribed TLS/profile and final review gates pass. Continuing authorization
remains active; no approval pause or product-scope expansion is introduced.

## Verified execution kickoff — 2026-10-13

Actual baseline: `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, clean local Foundation commit
`5b73f5a951d506f194d090a0083183a79d577d6e`. The
[kickoff receipt](../acceptance/evidence/m3/managed-h1-fixed-endpoint/1791891933896/kickoff.json)
records actual tree/source/cohort hashes, clean diff/untracked inventory,
accepted prerequisite reviews, counters and explicit ownership. This release
includes no publication authorization. Parent alone owns Mix/build/format/live
and commits. Written design/plan and independent readiness pass before edits.

| Writer | Exclusive files |
| --- | --- |
| Identity worker | `upstream_transports.ex`; new `upstream_transport_identity_test.exs` |
| Endpoint worker | `http.ex`, `http/session.ex`, `http_fetch_client.ex`; new `upstream_transport_proxy_test.exs` |
| Parent | Design/plan/acceptance/evidence; runtime commands and commits |

The identity test file is separated solely to permit disjoint ownership; all
prescribed identity/pure/network/lifecycle assertions remain required. Add it to
the scoped test/format commands. Both writers first provide runnable RED tests;
parent records actual nonzero RED before their production edits. Inherit five
Foundation Step7 unsuccessful attempts and20/8/3 UP2; Astra2/2 exhausted.
No group/probe/Generation/H2/H3/standalone activation is released here.

## Identity and endpoint execution checkpoint

Identity expected RED executed 12/12 missing-API failures. The initial GREEN
executed 89/11, exit 2, and remains immutable. Malformed raw authority `:abc`
was silently parsed with default port 80; test starters were monitored beyond
`unlink`. Repair 1 preserves all assertions, checks the raw authority and keeps
the embedding starter alive through public stop and actual actor joins. Fresh
89/0, exit 0, source-stable verification and independent SPEC then CODE review
pass; full-slice post-review verification remains pending. See the
[acceptance record](../acceptance/m3-managed-h1-fixed-endpoint.md).

Endpoint expected RED executed 22/22, then expanded 25/25 after adding stale
identity and both uncertain-open/bind branches; exit 2 and stable source, with
no unexpected harness cleanup failure. Production implementation is released
to the endpoint writer. Counts record actual execution rather than claiming
all deep branches reached past the currently absent config entry. New fixed
package unsuccessful repairs: **1**; all inherited counters remain unchanged.

First full endpoint GREEN executed **114/16, exit 2**, source stable; strict
compile passed. Twelve ordinary accounting failures used an open native connection
lease. Close downstream after full response before retaining the complete
zero-accounting oracle; two downstream connections must still reuse exactly one
upstream peer connection. The two negative TLS cases additionally report public cleanup unconfirmed;
separate diagnosis must preserve that failure, with no assumed cleanup success.
The no-completion test asserts its live baseline pin
before global stop and retains zero pins after the actual stop transition.
Bind-owner death requires a finite Service drain barrier for the exact
missing-receipt failure instead of allowing the Service to disappear first.
No production assertion or deadline is weakened.

The new optional HTTP handle exposes a necessary compatibility seam: existing
group options can accept it and later discard it in the struct round trip.
The endpoint writer additionally owns `upstream_groups/options.ex` solely to
reject non-nil managed members in both raw and compiled branches until the
separate group package is qualified. Add two pure RED regressions first; record
their actual execution before the minimal rejection. This does not activate
managed groups. New fixed package unsuccessful attempts are now **2**, including
the identity initial failure; immutable receipts and all inherited counters stay.

## TLS diagnostic and contract clarification

Focused group compatibility GREEN executed **2/0**, exit 0, with 25 location
exclusions; final unfiltered verification remains required. The public TLS
diagnostic executed **2/2 failures**, exit 2, preserving both original
zero-accounting assertions and all source hashes. Both original completions and
scope retirement receipts repeatedly report `cleanup_unconfirmed`, and scope
snapshots report `transport_scope_retired`. The exact pre-retirement ledger is
resource1/baseline1/token1/physical2/helpers0. This matches the installed public
contract rather than a dependency bug. The design's strict failure assertions
replace the incompatible successful-cleanup expectation only after independent
SPEC review. No production cleanup workaround, third Astra recovery, or
successful request assertion change is authorized or needed. Diagnostic runs
collect evidence and are not acceptance or an additional repair attempt.

Repair 1 combined verification then executed **177/2**, exit 2, no exclusions,
stable source. Both failures remain in the post-global exact ledger check; all
preceding failure/stop oracles passed. Unsuccessful implementation attempts are
now **3**. A diagnostic helper syntax error caused a separate **one harness
failure**, exit 1, zero executed tests; repair its syntax and gather real phase
evidence before choosing a production repair. All failed receipts remain intact.

The repaired diagnostic executed **2/2 failures**, exit 2, source stable, and
confirmed the Gaoxy record regressed `:failed` to `:retiring` on the second
authenticated abort helper. Both helpers joined, while the custodian remained
failed and physical2/token1 were retained. The endpoint writer additionally owns
`upstream_transports.ex` solely to preserve failed lifecycle across this control
retry; identity-worker ownership is finished. Keep the real confirmation path,
all accounting and exact negative TLS assertions. Full affected GREEN and
independent SPEC/CODE remain required. See the root-cause receipt.

Repair 2 full affected GREEN passed **177/0**, exit 0, no exclusions, stable
source, plus format/strict compile. Independent SPEC review 1 rejects missing
native-owner death before headers (existing cases kill after headers or kill the
transport owner). Add the deterministic real-peer case while preserving all
existing cases and production source. SPEC rejection1 does not erase the green
runtime or the three failed implementation attempts; CODE/fresh acceptance wait
for this coverage repair and re-review.

## Final local execution disposition — 2026-10-14

**DONE.** All execution items passed independent SPEC then CODE review and fresh
canonical formatcheck, strict compile and178/0 affected tests, exit0, no
skips/exclusions, source stable. The [acceptance](../acceptance/m3-managed-h1-fixed-endpoint.md)
and immutable receipt inventory preserve all initial failures, diagnostic
harness failure and the resolved SPEC rejection. Counters remain unsuccessful
implementation3, diagnostic harness1, SPEC rejection1; inherited counters and
Astra2/2 unchanged. Stage only owned files for the authorized local commit.
Advance to the separately reviewed groups/probes plan, then Generation; no
publication/deployment or disabled E2E change is included.

Local implementation commit: `2bf0883cea1dce1a031016700bb012fb3faac8b5` (`feat(proxy): activate managed H1 fixed endpoints`). Source hashes match the final fresh178/0 receipt; see the [commit receipt](../acceptance/evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-local-commit.json).
