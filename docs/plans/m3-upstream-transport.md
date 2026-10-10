# M3 upstream transport implementation plan

> For agentic workers: use subagent-driven-development or executing-plans for
> bounded task execution. Sol implements and independently reviews. Continuing
> authorization in `AGENTS.md` replaces routine approval pauses. The Astra
> architecture assignment does not authorize Astra implementation or commits.

**Goal:** Qualify installed HTTP Fetch 0.21 managed transport contracts, then
activate bounded owned H1 reuse and upstream H2 after their independent public
runtime and complete retained-state prerequisites pass.

**Architecture:** Preserve the existing HTTP pump, Session guardian, group
selection and generic generation-resource pins. Add an explicitly supervised
transport resource around a public managed upstream facade; request cleanup
releases request holds and a separate retirement receipt releases transport
capacity. See [`../designs/m3-upstream-transport.md`](../designs/m3-upstream-transport.md).

**Tech stack:** Existing Elixir 1.18.5 / OTP 28 environment, HTTP Fetch coordinated
0.21 packages, native Gaoxy H1/H2, independent raw TCP/Python `h2` peers already
used by the repository. No new production dependency.

**Baseline:** `d92d3691e073fbf33195b567af7be10cea6132fc`,
`codex/m3-gateway`, `.trees/m3-gateway`. Parent owns the dependency update and
its evidence. Historical0.20 tag is
`951ec75dadcebd8218f30d3ecdf99da142d4a463`. Current0.21 tag is
`9813c126dc8b48055b9ee941c693fc27fa691489`, verified against all installed
archives/runtime blobs from local baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.

## Execution boundaries

Tasks0–2 were completed on0.20 and their evidence remains historical. The seven
packages are now installed at0.21.0. Release38067971805 completed successfully;
all196 shipped-file hashes and175 runtime Git blobs match, with #78/#79 fixes
in the actual tag ancestry. Their containing-artifact prerequisite is resolved.
Task3 now runs public functional probes after independent fixture review and a
new complete source freeze. Runtime edits in Tasks4–8 still require Task3's
protocol-specific functional and complete accounting gates. A missing bound
cannot be supplied by private transport calls or an arbitrary allowance.

Managed H2 accounting is **BLOCKED** on
[Bug #86](https://github.com/gsmlg-dev/http_fetch/issues/86), an independently
source-confirmed aggregate header-event/SETTINGS-notification bound gap.
H1 functional investigation proceeds independently with C2/R32/P0,
`buffer/recbuf/sndbuf=8192`, nil/PID uploads, ACKed binary chunks≤65536,
raw streamed responses and manual redirects. The historical261,199,114-byte
component subtotal has uncertified delivery/copy assumptions and incomplete
policy, backing, structure and metadata coverage. The
[controlled H1 architecture](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
replaces it with named P0–P6 obligations. The H2 52,207,632-byte component
subtotal is likewise not a reservation. Neither enables transport activation.

The parent serializes all shared `http_fetch_client.ex`, `http/session.ex`,
`http.ex`, `upstream_groups.ex`, package/lock and acceptance-document edits. An
independent worker can own protocol fixtures/tests while another implements the
transport owner after the gate passes. Do not run concurrent Mix builds or
shared-port fixtures. No push, release, deployment, Vault/public-management
change, production-data operation or release-artifact E2E enabling.

Canonical shell for scoped Mix commands:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/http_fetch_completion_test.exs'
```

Record actual commands, tool versions, source hashes, nonzero counts, exits and
peer evidence under `docs/acceptance/evidence/m3/upstream-0.20/` for ready-now
work. Later managed-resource evidence gets a separate `upstream-transport/`
directory keyed to its containing version; preserve old evidence unchanged.

## Task 0: Freeze the installed-source checkpoint (ready now; parent owned)

Files: `apps/gaoxy_proxy/mix.exs`, `mix.lock`,
`docs/acceptance/evidence/m3/upstream-0.20/`, `docs/dependency-followups.md`.

- [x] Record all seven coordinated package versions/checksums and source hashes;
  distinguish the installed source from the upstream tag and earlier 0.19 logs.
- [x] Record the parent's strict compilation/formatting and 460-test compatibility
  checkpoint, including its existing command/log and seed 161790. Reuse this
  evidence for this unchanged candidate; do not claim the architecture worker
  ran it or repeat it solely to fill a checkbox.
- [x] Link Feature #78 in the current dependency status and add its required
  `# TODO(upstream): gsmlg-dev/http_fetch#78` at the disabled adapter callsite.
  Earlier #66/#67 are fixed-in-0.20; direct public request qualification passes16/16.
- [x] Keep all acceptance claims explicit: package compatibility can PASS while
  managed reuse/upstream H2 activation and full M3 remain BLOCKED.

## Task 1: Positive public completion and trailer probes (ready now)

Files: `integration/http_fetch_contract/pooled_completion_probe.exs`,
new `integration/http_fetch_contract/upstream_peer.py`,
`integration/http_fetch_contract/README.md`, ready-now evidence directory.
Parent assigns one writer; the historical negative option-gate logs stay intact.

- [x] Replace the probe's obsolete expected `unsupported_completion` assertions
  with a table of explicit H1 reuse, H2 TLS and h2c positive cases. The probe
  starts the required dependency applications in the supported way and shuts
  down its own local resources; no private/global-pool manipulation.
- [x] Use an independent loopback peer that reports accepted TCP connection IDs
  and, for H2, stream IDs. Start and stop it through a bounded readiness/control
  pipe. Use existing Python `h2` tooling; report missing fixture tools as an
  environment blocker, not a passing or skipped case.
- [x] H1: serve two sequential requests on one self-delimited connection; await
  each public completion and assert exactly one accept and two requests. Also
  cancel a stalled request and await completion without accepting a replay.
- [x] H2: open two streams on the same verified TLS connection; hold A after
  headers at a peer barrier while B remains live. Abort/await A, finish B, then
  send C on that same connection. Assert A's reset, exact B/C bodies and no
  replay. Repeat the named h2c profile separately.
- [x] Capture `Promise.completion/1` immediately, consume the acknowledged
  response stream without `read_all`/unbounded collection, and use another
  process for at least one repeated/concurrent completion wait.

Exact public operation pattern (the fixture supplies URL and finite policy):

```elixir
promise = HTTP.fetch(url,
  http_version: :h2c,
  http2_scope: "gaoxy-m3-public-contract",
  redirect: :manual,
  stream_response: true,
  decode_body: false,
  timeout: 5_000
)
completion = HTTP.Promise.completion(promise)
# At the independently observed peer barrier:
:ok = HTTP.RequestCompletion.abort_and_await(completion, 2_000)
:ok = HTTP.RequestCompletion.await(completion, 0)
```

- [x] Send upload DATA plus duplicate trailers using `Stream.start_link(0)`,
  `chunk/3` and `finish/2`; the H2 peer must observe ordered terminal HEADERS
  after all DATA, with END_STREAM. Exercise empty upload, split large trailer
  block, response trailers and response-body acknowledgment before terminal
  completion. H1 fixtures declare the trailer names and verify chunk framing.
- [x] At a peer-controlled flow-control barrier, issue an early final response
  and cancel an upload with unsent trailers. Verify producer termination,
  confirmed cleanup, no late trailer write and live H2 sibling progress. Do not
  treat partial connection-write failure as a stream-local cancellation case.
- [x] Verify a stale reused H1 socket and H2 GOAWAY cause no automatic replay;
  count received request IDs at the peer instead of asserting only an error.

Run after fixture implementation:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --no-start integration/http_fetch_contract/pooled_completion_probe.exs'
```

Expected: nonzero explicit cases, exit 0 only when all requested cases pass.
The probe orchestrates the peer and prints each protocol/result/count; it must
not depend on Gaoxy and HTTP Fetch both agreeing on a malformed wire exchange.
These tests qualify request APIs, not managed retirement or total memory bounds.

## Task 2: Reproduce the H2 empty-continuation bound (ready now)

Files: new `integration/http_fetch_contract/empty_continuation_probe.exs`,
the Task 1 peer, README and a new evidence log. Dependency issue/callsite routing
is parent owned. No Gaoxy production workaround.

- [x] Use only `HTTP.fetch/2` with explicit isolated h2c and finite request
  timeout. The independent peer opens a valid response HEADERS without
  END_HEADERS, then sends bounded batches of empty CONTINUATION on that stream.
  Every frame is correctly ordered; the test does not require malformed
  interleaving or server push.
- [x] Compare retained memory growth across peer-send receipts while
  the header payload sum remains zero. Use a disposable, otherwise idle runtime
  and public/VM-wide measurements; do not inspect private client process state.
  Correlate the observation with the source accumulator that appends fragments
  and checks only byte sum. Set a small finite batch ceiling and cleanup deadline.
- [x] Stop the experiment at its ceiling, abort the request through its public
  completion, and verify fixture/process shutdown. Never run an unbounded flood.
- [x] If reproduced, route a `Bug`, `internal request`, severity `blocker` in
  the package's actual upstream repository, including source/branch, exact
  reproduction and measured evidence. Add the issue TODO at the blocked H2
  adapter callsite and record it beside #78. If inconclusive, say so and retain
  the source concern as an unresolved qualification requirement.
  Recorded result: INCONCLUSIVE, not a passing bound gate. Independent source
  review confirms the missing metadata cap; Bug #79 is routed on that source
  basis, with the measured memory result/caveats kept explicit. Both required
  adapter TODOs and issue receipts are recorded; no dependency workaround.

Run:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --no-start integration/http_fetch_contract/empty_continuation_probe.exs'
```

Expected: a finite report stating reproduced/not-reproduced/inconclusive,
batch counts, memory samples and cleanup result. A successful diagnostic exit
is not a passing transport-bound gate. After an upstream fix, the regression
must instead prove a finite fragment/count rejection or equivalent hard bound,
with public request cleanup and appropriately scoped peer connection outcome.

**Ready-now execution receipts:** Task0 `source-provenance-gate.json`,
`baseline-gates.json` (460/0, seed161790), `phoenix-gates.json` (2/0, seed792852)
and `managed-transports-issue.json`; Task1 `public-probes-final.json`
(16/16 PASS, all peers stopped, 202 source hashes unchanged); Task2
`empty-continuation-final.json` (INCONCLUSIVE, finite 80k-frame diagnostic and
confirmed cleanup, 202 hashes unchanged), `empty-continuation-issue.json`.
The original201 maps omitted the main probe/shared helper; both probes were
rerun with corrected202 maps, preserving all original evidence and criteria.
See `source-coverage-correction.json`. All receipts are in
`docs/acceptance/evidence/m3/upstream-0.20/`. These completed execution
checkboxes do not qualify conditional transport activation or full M3.

## Task 3: Reopen the public managed-transport gate (conditional)

### Preparatory API checkpoint

Independent Sol source inspection of PR81 head
`11f1642cf6408219d4813772bda1055e605bbdc4`, merged as
`a75ec3c34446a1877366a0e52055743d28eabcc9`, identifies:

```elixir
HTTP.ManagedTransport.open(options) # {:ok, scope} | {:error, reason}
HTTP.fetch(url, transport_scope: scope, redirect: :manual,
  decode_body: false, stream_response: true)
HTTP.ManagedTransport.snapshot(scope, timeout_ms) # {:ok, aggregate} | error
HTTP.ManagedTransport.retire(scope, mode: :graceful) # {:ok, receipt} | error
# :abort escalates graceful retirement; repeated calls share the receipt.
HTTP.ManagedTransport.await_retired(receipt, timeout_ms)
# :ok | {:error, :cleanup_pending | :cleanup_unconfirmed}
```

`open/1` monitors its calling creator, and uses a fixed 5,000-ms handle call.
`retire/2` also uses a fixed 5,000-ms control call. Neither accepts a caller
deadline. Snapshot/receipt waits accept finite milliseconds. Use a persistent
scope custodian and bounded monitored initiation helpers; always preserve the
original Gaoxy absolute deadline. The audited finite limits are requests
1..2048, connections1..256, pending exactly0 and idle timeout1..60000 ms.
The [installed provenance](../acceptance/evidence/m3/upstream-transport/upstream-0.21/installed-provenance.json)
confirms the four audited critical blobs match. Complete numeric accounting
and runtime qualification remain separate gates below.

The [audited source receipt](../acceptance/evidence/m3/upstream-transport/source-api-review.md)
records the options and immutable blobs. `open/1` requires origin URL, literal
address tuple and explicit protocol; optional keys are TLS backend/policy,
socket options, finite request/connection/pending/idle limits and H2 profile.
No private fields of scopes or receipts are an integration surface.

Files: this plan's API checkpoint, the design's audited API table,
`apps/gaoxy_proxy/mix.exs`, `mix.lock`, new
`integration/http_fetch_contract/managed_transport_probe.exs`, later evidence.

- [x] Confirm #78/#79 are resolved in actual installed0.21 artifacts. Record
  archive/shipped-file/runtime-blob hashes and exact documented public signatures
  in `upstream-transport/upstream-0.21/release-provenance.json`,
  `installed-provenance.json` and the source/API receipt. #86 remains a separate
  unresolved H2 blocker; this checkbox does not approve Task3.
- [x] Prove Fetch accepts the opaque caller-owned resource and cannot silently
  use the global pool. Inspect finite ingress/connection ledgers covering
  preparation, connection setup and active/idle requests; independently exercise
  held active/unread capacity, idle reuse, draining connection occupancy and
  immediate rejection with a zero pending queue. Held connecting/preparing
  saturation is NOT RUN by the39-case fixture; source bounds do not imply that
  those runtime states were sampled.
- [x] Prove same-policy requests with unequal opening/total remaining deadlines
  reuse while preserving each request's absolute deadline. If timeout policy
  still changes the reuse key or sibling socket state, keep activation blocked.
- [x] Verify public retirement receipts close idle sockets, reject new work, survive
  late checkin, and returns pending/unconfirmed distinctly from confirmed
  completion. Scope A retirement must preserve scope B on the same origin.
- [ ] Independently qualify actual OTP28 TLS-process tracking and release:
  blocker [#95](../dependency-requests/http-fetch-otp28-tls-tracking.md).
  Installed `track_tls/2` silently skips the actual socket shape. Public receipt
  observations do not prove termination of unregistered receiver/sender processes.
- [ ] Build the design's numeric retained-byte worksheet from this exact source.
  Include transient HPACK/header decoding, fragment/control metadata, payload
  copies, pending requests, idle connections and unknown/unconfirmed holds.
  Run the fixed empty-continuation case and bounded slow-peer/control cases.
  Missing finite bounds keep H2 activation blocked.
- [ ] Qualify the narrow H1 accounting expression independently: explicit
  policy/preparation copy multiplicities, binary backing and header/trailer
  structural overlap, bounded process/ETS/monitor/timer/control-message counts
  and serialized-to-retained conversion, plus exact managed OTP delivery proof.
  Preserve unknown terms; a component subtotal is never a complete budget.
- [ ] Independent Sol specification review must approve these prerequisites
  before Task 4 runtime edits. This is technical qualification under existing
  authorization, not a routine user-approval step.
- [ ] Before activation, exercise held connection setup and preparation/admission
  turnover with the qualified scope boundary. Preserve finite slot limits and
  exact retirement outcomes; source-only coverage is not runtime acceptance.

Functional execution receipt: `upstream-0.21/managed-probes-recovery1.json`,
39/39 cases,39 successful joined cleanups, exit0,425 unchanged frozen source
hashes and no remaining owned peer. Independent specification/code-quality
delta review and strict preflight18/0 pass. Both verified TLS H2 and h2c retain
needed#89's separately recorded canonical capacity-error MISMATCH. Initial,
diagnostic and repair failures remain preserved. These functional checkboxes
do not satisfy complete accounting, integration, matrix or load requirements.
The exact-source `h1-delivery-proof.md` contributes conditional raw logical/
backing lemmas; full P1 and all P0–P6 activation obligations remain open.

Bounded source follow-ups now pass their separate independent reviews:
[request/wire construction](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-request-wire-independent-review.md),
[33-entry HAMT structure](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-map-layout-independent-review.md),
and [control-turnover/TLS evidence](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-turnover-and-delivery-review.md).
The HAMT envelope applies per completed occurrence plus children; the request
mapping remains unwired. Remaining local source-proof work includes helper/native
costs, policy/host-CA overlap, loaded code/profile enforcement, root/copy
multiplicities and control-release frontiers. These component results leave every
full P0–P6 activation obligation and the Task3 prerequisite checkboxes open.

## Task 3a: Pure compact H1 preparation (unblocked)

Follow the [compact preparation design](../designs/m3-managed-h1-preparation.md)
and [scoped execution plan](m3-managed-h1-preparation.md). This slice may proceed
before complete runtime accounting: bounded canonical policy/request data,
separate source backing/owned constructor manifests and named partial facts.
It opens no scope, starts no process, performs no I/O and wires no adapter.
Its activation API stays explicitly unqualified while P0–P6 remain open.
Needed upstream input/backing requests#87/#88 are excluded by the narrow grammar;
they do not complete the remaining local proof work or resolve H2 blocker#86.

- [x] Independent specification review of the written narrow design/plan:
  `upstream-0.21/h1-preparation-spec-review.md`, with no-start test commands,
  canonical policy grammar and opaque trust-payload wording corrected.
- [x] Scoped red/green tests and minimal pure implementation.
- [x] Independent specification/code-quality review and fresh formatter/scoped
  tests:26/0, exit0, seed21108026;429 unchanged source hashes. See the pure
  preparation plan and `upstream-0.21/h1-preparation-final.json`.
- [x] Record exact source/results and local commit `56fd518`; retain the
  activation gate. Task3a pure preparation is complete; Tasks4–8 remain gated.

## Task 4: Pure policy and bounded transport resource (conditional)

Create: `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`,
`apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`,
`apps/gaoxy_proxy/test/upstream_transports_test.exs`,
`apps/gaoxy/test/lifecycle_participant_test.exs`.
Modify: `apps/gaoxy/lib/gaoxy.ex`, `apps/gaoxy/lib/gaoxy/instance.ex`,
`apps/gaoxy/lib/gaoxy/lifecycle.ex`, and necessary proxy supervision helpers.
These core edits implement the generic stop hook; no HTTP dependency enters core.

- [ ] Write red tests for strict options, immutable protocol/authority/pin/TLS
  matching, finite limits, duplicate/unknown fields, stale epochs and bounded
  handles. Freeze CA contents with bounded read/decode; capture default trust
  without repeatedly reading mutable paths on checkout. No arbitrary SSL
  callbacks or new client-certificate/Vault features.
- [ ] Implement the design's `prepare/4`, `checkout/4`, `bind_completion/3`,
  `finish/2`, `retire/2`, `await_retirement/2`, `status/1`, and existing provider
  callbacks `pin_many/5`, `release/1`, `cancel/2`. Callers use unchanged public
  `Resources.pin_many/4` and `Resources.release/1`; there is no facade cancel.
  The proxy facade alone calls the newly verified upstream API; expose no sockets
  or client owners.
- [ ] Add `Gaoxy.register_lifecycle_participant/2` and the instance-owned bounded
  registry before any transport resource allocation. Test caller identity,
  duplicate registration, maximum 64 entries, stopping rejection and owner
  death with a controllable generic participant. Failed entries stay accounted;
  no dependency/provider modules or opaque HTTP values appear in core state.
- [ ] Extend `Instance.operation` and the termination helper to fan out service
  drains and `:gaoxy_lifecycle_drain` messages under the original deadline,
  joining authenticated `:gaoxy_lifecycle_result` receipts. The instance server
  remains responsive and participants report directly to the coordinator.
  Preserve service-only result shapes; enforce the design's pending deadline
  error and aggregate resource failure/uncertainty without converting DOWN to
  success. Supervisor termination reuses the combined helper and never replaces
  a failed resource result with service-only success.
- [ ] Implement owner retirement as the public managed-resource close-and-await
  operation. It immediately closes new preparation/pin/probe admission, permits
  already-admitted request pins until D, retires otherwise idle transports
  without waiting for baseline pins, and forces resource-local cancellation at
  D. Repeated waits use the same receipt and cannot extend D. After successful
  retirement the inert owner remains alive until instance DOWN so the shutdown
  coordinator can join its cached result reliably.
- [ ] Test registration-before-allocation, unexpected instance DOWN, coordinator
  death and transport owner death. Unexpected DOWN uses the known deadline or
  finite emergency cleanup budget; it never retroactively supplies a successful
  instance-stop receipt. Explicit config-owner shutdown calls `Gaoxy.stop/2`
  before stopping the enclosing supervisor and participant siblings.
- [ ] Reserve worst-case transport capacity before resource creation; reject
  admission with no queue before effects. Include prepared/retiring/failed
  records in finite resource/pin/token/byte limits. Caller-created operation
  refs and holder monitors cancel late metadata acquisitions idempotently.
- [ ] Write deterministic tests for caller death, open-to-bind uncertainty,
  pending/unconfirmed retirement, repeated finish/release and cross-instance
  isolation. Public retirement confirmation is necessary before refunding
  connection capacity. No ledger restart that forgets old live transports.
- [ ] Create each upstream scope from its persistent custodian, never from an
  exiting preparation worker. Bound custodians by admitted transport records;
  preparation timeout rejects publication while retaining uncertain allocation
  holds and retires late scopes. Test creator DOWN through the public contract.
- [ ] Bound scope retirement initiation and abort-escalation helpers, preserving
  D around fixed 5,000-ms upstream calls. Test short-D pending initiation,
  graceful-to-abort escalation, repeated public receipt recovery, late confirmed
  capacity release and unchanged failed stop results. Snapshot retirement errors
  and helper DOWN do not substitute for public cleanup confirmation.

Run `mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy/test/lifecycle_participant_test.exs`
in the canonical environment; capture red then green with exact counts.

## Task 5: Endpoint, Session, group and generation integration (conditional)

Modify: `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, `http/session.ex`,
`http_fetch_client.ex`, `group_endpoint.ex`, `upstream_groups.ex`,
`upstream_groups/options.ex`, `upstream_groups/probe.ex`.
Create tests: `apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs`,
`apps/gaoxy_proxy/test/upstream_transport_generation_test.exs`.
Existing generic HTTP Resources/Generation interfaces should suffice.

- [ ] Add pure `HTTP.resources/1` and optional prepared transport validation;
  retain the existing dedicated H1 default. Return group plus deduplicated
  member transport handles, preserving the 64-handle sidecar bound. Bound
  candidate preparation pins and roll back only the candidate on failure.
- [ ] Acquire fixed-endpoint request pins outside Generation; for Generation,
  use the snapshot pins already acquired atomically. Session selects once,
  checks out transport once after cleanup activation, opens once and binds
  completion before enabling upload. Keep independent group and transport
  tokens and hold both until public request cleanup.
- [ ] Integrate probes with the same immutable transport identity and existing
  finite probe budget. Acquire holds outside group/transport owners; no owner
  call cycle or new probes on retiring generations. Preserve health semantics.
- [ ] Change adapter options only through the verified public managed facade;
  explicit H1/H2/h2c, raw streamed response, no redirect/replay. Separate shared
  transport policy from request deadlines and choose the audited protocol
  reservation. Preserve the existing completion callback shapes.
- [ ] Pause an old request immediately after snapshot pinning, activate a new
  generation, then let old/new requests check out. Assert exact old/new peer
  identity and that retirement waits for the old pin plus request completion.
  Also cover stale CAS, preparation failure, store death and late cleanup.
- [ ] Rotate CA contents at the same path between preparations and change the
  numeric pin for the same authority. Assert captured old/new trust and routing,
  hostname rejection, no credential forwarding and no cross-generation reuse.
- [ ] Repeat bounded reloads with active and idle transports; prove plateau,
  capacity rejection while retirement is held, eventual public confirmation,
  peer-observed socket closure and restoration of accounting baselines.

Run the two new test files plus existing generation-resource and group tests
affected by the changed seams. Expected: real listener/network cases, nonzero
counts, no obsolete assertion weakened to accommodate reuse.

## Task 6: Independent streaming matrix and cancellation (conditional)

Create: `integration/upstream_transport/run.py`,
`integration/upstream_transport/fixture.exs`,
`integration/upstream_transport/README.md`,
`apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`.
Reuse the repository's existing Python `h2` environment and local TLS fixtures.

- [ ] Implement the matrix H1→H1, H1→H2, H2→H1 and H2→H2 with independent
  upstream/downstream peer roles. Name H2 TLS and h2c results separately; do not
  infer one from the other. Record accepted connections/streams and exact bytes.
- [ ] Verify request/response streaming before producer EOF, duplicate headers,
  allowed duplicate request/response trailers, empty bodies, declared-trailer
  policy, fixed content length, HEAD/bodyless responses and raw compression.
- [ ] Hold one upload at stream-window exhaustion, issue its early final
  response, cancel during unsent trailers, and reset downstream while another
  H2 stream progresses. The peer barrier must establish the intended phase.
  Verify no replay and confirmed cleanup before releasing held admission.
- [ ] Slow downstream response consumption and upstream reads independently.
  Observe finite request/transport reservation peaks, bounded queue growth and
  sibling progress; total/idle/write deadlines must expire independently.
- [ ] Prove H1 sequential reuse and actual H2 multiplexing on one upstream
  connection. Different TLS/pin/generation identities must use separate
  resources; a shared origin alone must never override policy.

The harness entry point is `python integration/upstream_transport/run.py` from
the qualified Python environment. It owns fixture readiness/shutdown with
finite deadlines and prints per-case PASS/FAIL counts. Run scoped streaming
tests in the canonical Mix environment; retain harness and unit evidence.

## Task 7: Lifecycle and admission failure qualification (conditional)

Create: `apps/gaoxy_proxy/test/upstream_transport_lifecycle_test.exs`.
Extend the independent Task 6 harness and later evidence only as needed.

- [ ] Saturate configured transport connections/streams and prove the next
  request rejects before upstream bytes without a hidden pending task queue.
- [ ] Retire idle resources, retire with a request held at a barrier, force
  expiry under one absolute deadline, and crash a guardian before/after binding.
  Record pending/unconfirmed results and retained capacity exactly.
- [ ] Keep unrelated H2 siblings/scopes live while one request cancels and one
  other resource retires. Shared connection transport failure is tested
  separately with the correctly broader connection outcome.
- [ ] Exercise instance stop and service drain without killing shared/global
  library processes. Only public resource receipts establish cleanup. Verify
  late release/checkin cannot recreate an old generation or refund a new one.
- [ ] With no active request and one retained idle connection, hold the public
  resource retirement at a deterministic barrier and call `Gaoxy.stop/2`.
  Assert no successful stop receipt before release; after release, require
  public retirement plus instance DOWN. Repeat with D expiring, an unconfirmed
  receipt and participant death, asserting their exact non-success results.
  Capture the same absolute D at service drain and participant retirement;
  headroom must never restart the success budget. A second live instance must
  continue exact peer traffic throughout.

Run `mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_lifecycle_test.exs`
plus the lifecycle portion of the independent harness. Expected: finite
deadlines, exact peer observations and no process/memory growth after repeated
confirmed cleanup.

### Task 7b: Managed transport sustained load (conditional)

Extend `integration/upstream_transport/run.py`, `fixture.exs`, and README;
write new evidence beneath `docs/acceptance/evidence/m3/upstream-transport/soak/`.
Keep the historical dedicated-H1 soak files and claims unchanged.

- [ ] Add separate `--profile h1-reuse` and `--profile h2-multiplexed` modes;
  require at least 600 seconds of continuous offered load per qualified mode.
  An explicit `--smoke` shorter run prints UNQUALIFIED, regardless of success.
- [ ] Freeze source/lock hashes and write a numeric manifest before execution:
  32 offered downstream H2 streams; exact 131,072-byte bodies; service active
  cap 128; four retained transport-generation records; eight total connections;
  two connections per generation, with 32 streams/connection for H2; zero
  pending requests. Fix exact request/transport-byte ceilings from Task 3's
  worksheet and check that admitted concurrency fits. Also fix RSS +512 MiB,
  process count +512, sampled owned mailboxes <=2,048, at least 1 Hz sampling.
  Never increase a ceiling during a run or infer a hard bound from sampling.
- [ ] Continuously alternate ordinary and slow consumers (200 ms selected
  response-credit withholding), reset after actual DATA progress, and perform
  at least 20 successful route-generation reloads. Keep active/idle/retiring
  resources represented and hold retirement at a barrier at least twice.
  Predeclare expected overload/reset schedules; H1 saturation at its two
  connections rejects additional attempts without upstream request bytes.
- [ ] Assert peer-observed H1 connection reuse and simultaneous H2 streams on
  one verified TLS upstream connection. Record accepted connection/stream IDs,
  exact bytes/trailers, offered/completed/reset/capacity-rejection/unexpected
  error counts, latency distribution, all request/transport reservation samples,
  active/idle/retiring counts and public retirement receipts. Fail unexpected
  errors, payload mismatches or any configured sample/admission violation.
- [ ] Stop load and complete combined `Gaoxy.stop/2`, public retirement,
  zero owned request/transport reservations, captured owned process DOWN,
  peer-observed socket closure and fixture termination in one 15-second
  teardown budget. Pending/unconfirmed receipts or retained owned resources
  fail the profile; no sleep-based idle-expiry claim.

Run in the already qualified Python environment after an exclusive source/build
freeze:

```sh
python integration/upstream_transport/run.py --profile h1-reuse --duration 600 --evidence docs/acceptance/evidence/m3/upstream-transport/soak/h1
python integration/upstream_transport/run.py --profile h2-multiplexed --duration 600 --evidence docs/acceptance/evidence/m3/upstream-transport/soak/h2
```

Expected: each actual offered interval >=600 seconds, nonzero reuse/reset/slow/
reload paths, zero unexpected failures and confirmed bounded teardown. These
two new profiles are required for managed-transport acceptance; earlier fixed
dedicated-H1 soak evidence cannot satisfy them.

## Task 8: Review, compatibility and milestone evidence (conditional)

Files: `docs/acceptance/m3.md`, `docs/plans/m3-gateway.md`, current capability
documentation, `docs/dependency-followups.md`, later evidence directory.

- [ ] Complete independent Sol specification review against every design
  section, then code review; repair actionable findings within inherited
  counters. Neither an architecture review nor positive public probes are
  implementation acceptance.
- [ ] Run strict compile/format, the scoped HTTP/proxy/generation/server
  compatibility suites touched by this implementation, external core-consumer
  isolation and the required independent-peer/native fixture checks. Use the
  existing stage commands and record actual counts. No unrelated autofix.
- [ ] For the new generic core hook, also run
  `mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/lifecycle_participant_test.exs apps/gaoxy/test/lifecycle_fault_test.exs apps/gaoxy/test/lifecycle_ownership_test.exs apps/gaoxy/test/lifecycle_acceptance_test.exs`
  in the canonical environment. Prove service-only shutdown compatibility and
  core-only dependency isolation alongside participant shutdown behavior.
- [ ] Re-run only checks affected by repairs, then record source/lock hashes,
  configured limits, retained-byte worksheet, protocol matrix and explicit
  measurement exclusions. Match every closed gate to evidence on the candidate.
- [ ] Update current status without rewriting historical 0.19/0.20 logs.
  Managed transport PASS requires all prerequisite, retirement, isolation,
  streaming, boundedness, both Task 7b >=600-second managed-resource profiles
  and independent-network gates. M3 completion also
  requires the remaining existing milestone checklist, under parent acceptance.
- [ ] Parent may create authorized local conventional commits after checks and
  review pass; stage only owned files and preserve unrelated edits. Publication
  and deployment remain outside this plan.

## Self-review and current handoff

Requirements map: public API/deadline identity and source bounds -> Tasks 1–3;
capacity/ownership/trust and generic instance stop hook -> Task 4;
generations/groups/guardian completion ->
Task 5; trailers/matrix/slow peers -> Task 6; retirement/failure isolation ->
Task 7; managed H1/H2 sustained load -> Task 7b;
independent review/compatibility/evidence -> Task 8.

The architecture worker wrote only the two assigned documents and performed
source/document checks. Runtime checks are NOT RUN by that worker. No recovery
repair budget was used. Sol can execute Tasks 0–2 now; Tasks 3–8 remain gated by
upstream #78, resolution of demonstrated bounds defects, and containing-release
qualification. No additional product decision is needed to run the ready-now
probes or route their findings.

Architecture refinement 1 addresses independent SPEC findings S1–S3: the
generic registered participant joins idle/shared retirement before instance-stop
success (Tasks 4/7), two new >=600-second managed transport profiles qualify
sustained lifetime/churn (Task 7b), and resource facade/provider arities remain
distinct. Document self-review is not the pending independent re-review and
does not qualify runtime behavior.

Current checkpoint, 2026-10-11: installed0.21 artifacts resolve #78/#79;
Task3's finite functional probes pass39/39 and pure Task3a passes26/0 with
independent implementation reviews. Conditional source lemmas pass their
separate independent review. Full P0-P6, held preparing/connecting saturation
and Tasks4–8 remain unqualified. The fresh remote receipt records #86–#89
CLOSED with latest published release still0.21.0; containing fixes and renewed
qualification remain required. New blocker#95 is OPEN for managed OTP28 TLS
tracking. A [fresh remote recheck](../acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-refresh2.json)
confirms the same issue/release states at2026-10-10T19:33:09Z. The older handoff
preserves its original prerelease boundary. Local delivery `d8e3a26` records the
reviewed qualification and TLS blocker; it does not lift Tasks4–8's gates.
