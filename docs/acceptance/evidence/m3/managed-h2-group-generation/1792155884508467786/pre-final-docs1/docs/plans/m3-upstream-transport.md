# M3 upstream transport implementation plan

> For agentic workers: use subagent-driven-development or executing-plans for
> bounded task execution. Sol implements and independently reviews. Continuing
> authorization in `AGENTS.md` replaces routine approval pauses. The Astra
> architecture assignment does not authorize Astra implementation or commits.

**Historical goal:** Qualify HTTP Fetch managed transports and integrate owned
H1 reuse/upstream H2. This is a deferred adapter design. ADR007 dismisses the
former control-proof requirement and supersedes its release/M4 gates. Remaining
numerical requirements below are historical design inputs, not requirements to
re-raise for this release. Use the v0.2.0 release plan for current execution.

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
`951ec75dadcebd8218f30d3ecdf99da142d4a463`. Historical0.21.0 tag is
`9813c126dc8b48055b9ee941c693fc27fa691489`, verified against all installed
archives/runtime blobs from local baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.

## Execution boundaries

Tasks0–2 were completed on 0.20 and their evidence remains historical.
All seven coordinated HTTP packages are installed at **0.21.3**, tag
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Both direct pins are
`== 0.21.3`; seven lock entries changed and 17 unrelated entries are preserved.
Independent source/artifact review verifies 196 shipped files and 175 runtime
sources, including the containing parser/cancellation fixes #98/#100.
Strict compilation and compatibility **486/0** pass. The unchanged public
managed driver passes **39/39** with 39 joined cleanups and canonical capacity
MATCH; these finite resource properties do not certify memory bounds.

Actual supplemental TLS95 qualification passes **five cases/five cleanups,
exit0**. The isolated0.21.1 negative control executes both inventory cases with
exact H1 observed1/expected3 and H2 observed2/expected4 mismatches, two cleanups
and real exit1. Source/build/tool/native environment freezes and original
loaded/disk comparisons pass; every original loaded row remains unchanged and
new rows are independently validated. Identity regression23/0 and independent
SPEC/CODE review pass. The earlier90-second native-profile timeout executed zero
cases and remains preserved; the unchanged profile later passed within its
original deadline. TLS tooling counters are Sol4/unsuccessful2/Astra2; no third
Astra recovery is authorized.

H1 functional baseline B01–B20 passes **20/0**, no skips/exclusions and all owned
joins, after the reviewed B05 backing/B17 late-cleanup amendments. Model22/0,
ledger-refusal2/0 and loaded-identity1/0 pass. The final grouped source passes
canonical format, baseline20 and separately admitted B21 without the grouping
warning. B21 observes two ClientHellos, rejects the third request at C2, retains
both genuine cleanup_unconfirmed completions and original retirement, joins15/15
owned actors and refunds no native control credit. Eight invalid gate probes
plus the existing relative-path probe reject with zero registered tests.
H1 counters are Sol3/unsuccessful2/Astra1; all original deadlines remain fixed.

The public H2 parser/cancellation supplement passes **8/8** (TLS4/h2c4), with
zero skips/failures, eight joined peer shutdowns and real exit0. Exact parser
invalid_headers_transition/RST1 and abort/deadline aborted/request_timeout/RST8
oracles pass. Manual original completion confirms after reader consumption;
follow completion stays explicitly unsupported. Frozen source/native/loaded
before-after identities pass. H2 counters are Sol1/unsuccessful0/Astra0.
Five separately frozen acquisition-failure probes meet their expected negative
oracles. Both prerepair controls omit cancellation/recovery and record reset0;
repaired manual/follow controls publicly cancel, recover the first response and
record reset8. The lost-alias control preserves its real Task.await timeout,
public abort and no second await, with explicit BLOCKED_HANDOFF. All five retain
real VM exit1: four FAIL and one BLOCKED_HANDOFF, adding zero normal-suite cases.
Wrapper post-identity/outcome and loaded-after identity are NOT RUN for these
negatives because System.halt(1) bypasses them. Parent input freezes and actual
owned process/peer joins are separately verified. Fresh native profiles compare
exactly: 254 file hashes, 113 ELF paths and 483 unique NAR identities. Independent
H1/H2 specification, code and evidence review passes with no findings.

**Reviewed disposition, 2026-10-11:** The user dismissed the former control-proof
request as excessive. It is excluded from Gaoxy acceptance and must not be
pursued, replaced with equivalent requirements, or used to block release or M4.
Numerical fixtures and their failed/unqualified receipts remain historical;
this decision does not turn them into passing tests. Production uses dedicated
H1 connections. Reusable H1 and upstream H2 adapters are not implemented and
are outside the v0.2.0 gateway beta release. See [ADR007](../adr/007-m3-beta-and-m4.md).
Old managed-integration requirements below describe the deferred variant,
rather than prerequisites for this release or M4.

Use the [0.21.3 qualification plan](m3-upstream-0.21.3-qualification.md),
[complete H1 plan](m3-h1-complete-0.21.2-accounting.md) and
[functional fixture specification](m3-h1-qualification-fixture.md).

Runtime edits in Tasks4–8 still require Task3's
protocol-specific functional and complete accounting gates. A missing bound
cannot be supplied by private transport calls or an arbitrary allowance.

Managed H2 accounting remains **UNQUALIFIED**: containing source fixes
[Bug #86](https://github.com/gsmlg-dev/http_fetch/issues/86)'s reported paths,
but complete adversarial-backlog and retained-byte qualification remain open.
H1 functional investigation proceeds independently with C2/R32/P0,
`buffer/recbuf/sndbuf=8192`, nil/PID uploads, ACKed binary chunks≤65536,
raw streamed responses and manual redirects. The historical261,199,114-byte
component subtotal has uncertified delivery/copy assumptions and incomplete
policy, backing, structure and metadata coverage. The
[controlled H1 architecture](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
replaces it with named P0–P6 obligations. The H2 52,207,632-byte component
subtotal is likewise not a reservation. Neither enables transport activation.
All old formulas, copy/construction facts, loaded identities and source reviews
below are historical0.21.0 evidence. New normalization and recursive policy
copies require source-specific accounting updates; complete P0–P6, held
preparing/connecting saturation and Task4/M4 remain unqualified.

The parent serializes all shared `http_fetch_client.ex`, `http/session.ex`,
`http.ex`, `upstream_groups.ex`, package/lock and acceptance-document edits. An
independent worker can own protocol fixtures/tests while another implements the
transport owner after the gate passes. Do not run concurrent Mix builds or
shared-port fixtures. The v0.2.0 integration/push/GitHub release is separately authorized. Deployment,
Vault/public management, operational certificates, production data and
release-artifact E2E enabling remain restricted.

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
  `installed-provenance.json` and the source/API receipt. This records the
  historical0.21.0 checkpoint, when#86 remained unresolved; it does not approve
  Task3 or replace the0.21.1 qualification above.
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
- [x] Independently qualify actual OTP28 TLS-process tracking and release:
  containing fix [#95](../dependency-requests/http-fetch-otp28-tls-tracking.md)
  is installed in0.21.3. Actual supplemental qualification passes five cases
  and five joined cleanups with frozen before/after loaded/native identities;
  see [current acceptance](../acceptance/m3.md). This finite process-tracking
  evidence does not establish the native lifetime/accounting frontier.
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

Historical0.21.0 functional execution receipt: `upstream-0.21/managed-probes-recovery1.json`,
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
mappings remain unwired. Independently reviewed conditional native Binary and
ordinary-message/fragment formulas add bounded representation components;
the actual emulator ABI is still unqualified. A read-only34-module identity
checkpoint pins currently loaded code and disk/native artifacts, without
establishing source reproduction or scope-lifetime enforcement. Remaining local
source-proof work includes other helper/native costs, policy/host-CA overlap,
loaded code/profile enforcement, root/copy
multiplicities and control-release frontiers. These component results leave every
full P0–P6 activation obligation and the Task3 prerequisite checkboxes open.
The new bounded policy/CA trace derives warm-snapshot and explicit-DER
constructor components; cold/reload work, immutable snapshot enforcement and
simultaneous copy/release proofs remain open. Neither that trace nor the
point-in-time artifact checkpoint closes full P3 or the process-integration gate.

### Qualification-only H1 model and fixture

The reviewed [accounting frontier](../designs/m3-upstream-0.21.1-accounting-frontier.md)
permits the [pure lease model](m3-h1-qualification-model.md) and a separately
specified public-API fixture before the numeric expression is complete. Require
independent specification/code review, actual nonzero scoped execution and
frozen inputs for each delivery. The model must execute all22 named cases,
including release-order permutations, independent deadlines and2048 turnovers.
Slice B requires its own reviewed plan and real public/peer barriers; model
events cannot supply missing runtime release evidence.

These are Task3 qualification fixtures. They add no production interface,
byte evaluator or activation budget. Task4 production edits remain gated by
complete applicable P0–P6 accounting and qualified lifetimes; production
conformance and existing managed soaks remain required before activation/M3.

## Task 3a: Pure compact H1 preparation (unblocked)

Follow the [compact preparation design](../designs/m3-managed-h1-preparation.md)
and [scoped execution plan](m3-managed-h1-preparation.md). This slice may proceed
before complete runtime accounting: bounded canonical policy/request data,
separate source backing/owned constructor manifests and named partial facts.
It opens no scope, starts no process, performs no I/O and wires no adapter.
Its activation API stays explicitly unqualified while P0–P6 remain open.
Needed upstream input/backing requests#87/#88 are excluded by the narrow grammar;
their0.21.1 source fixes do not complete local P0–P6 proof work or the full H2
adversarial-backlog gate.

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

**Accepted foundation — 2026-10-13:** The bounded
[H1 resource foundation](m3-h1-resource-foundation.md) passes final independent
SPEC/CODE review and fresh scoped/protocol gates under renewed continuing
authorization. See [exact acceptance](../acceptance/m3-h1-resource-foundation.md). Its verified public APIs and independent specification review
replace historical conditional/native-control proof prerequisites; the dismissed
http_fetch#97 and P0–P6 certification are not foundation or activation gates.
Historical source/accounting failures remain unchanged. Foundation uses explicit
bounded DER trust; file trust/default capture belongs to a later package. Older
file lists and routine phase approval stops do not restrict necessary repairs.
Production activation starts after foundation verification and review pass.


Create: `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`,
`apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`,
`apps/gaoxy_proxy/test/upstream_transports_test.exs`,
`apps/gaoxy/test/lifecycle_participant_test.exs`.
Modify: `apps/gaoxy/lib/gaoxy.ex`, `apps/gaoxy/lib/gaoxy/instance.ex`,
`apps/gaoxy/lib/gaoxy/lifecycle.ex`, and necessary proxy supervision helpers.
These core edits implement the generic stop hook; no HTTP dependency enters core.

- [x] Write red tests for strict options, immutable protocol/authority/pin/TLS
  matching, finite limits, duplicate/unknown fields, stale epochs and bounded
  handles. This bounded package captures explicit DER trust during preparation;
  immutable file/default trust capture remains a separate later slice as stated
  above. No arbitrary SSL callbacks or new client-certificate/Vault features.
- [x] Implement the design's `prepare/4`, `checkout/4`, `bind_completion/3`,
  `finish/2`, `retire/2`, `await_retirement/2`, `status/1`, and existing provider
  callbacks `pin_many/5`, `release/1`, `cancel/2`. Callers use unchanged public
  `Resources.pin_many/4` and `Resources.release/1`; there is no facade cancel.
  The proxy facade alone calls the newly verified upstream API; expose no sockets
  or client owners.
- [x] Add `Gaoxy.register_lifecycle_participant/2` and the instance-owned bounded
  registry before any transport resource allocation. Test caller identity,
  duplicate registration, maximum 64 entries, stopping rejection and owner
  death with a controllable generic participant. Failed entries stay accounted;
  no dependency/provider modules or opaque HTTP values appear in core state.
- [x] Extend `Instance.operation` and the termination helper to fan out service
  drains and `:gaoxy_lifecycle_drain` messages under the original deadline,
  joining authenticated `:gaoxy_lifecycle_result` receipts. The instance server
  remains responsive and participants report directly to the coordinator.
  Preserve service-only result shapes; enforce the design's pending deadline
  error and aggregate resource failure/uncertainty without converting DOWN to
  success. Supervisor termination reuses the combined helper and never replaces
  a failed resource result with service-only success.
- [x] Implement owner retirement as the public managed-resource close-and-await
  operation. It immediately closes new preparation/pin/probe admission, permits
  already-admitted request pins until D, retires otherwise idle transports
  without waiting for baseline pins, and forces resource-local cancellation at
  D. Repeated waits use the same receipt and cannot extend D. After successful
  retirement the inert owner remains alive until instance DOWN so the shutdown
  coordinator can join its cached result reliably.
- [x] Test registration-before-allocation, unexpected instance DOWN, coordinator
  death and transport owner death. Unexpected DOWN uses the known deadline or
  finite emergency cleanup budget; it never retroactively supplies a successful
  instance-stop receipt. Explicit config-owner shutdown calls `Gaoxy.stop/2`
  before stopping the enclosing supervisor and participant siblings.
- [x] Reserve worst-case transport capacity before resource creation; reject
  admission with no queue before effects. Include prepared/retiring/failed
  records in finite resource/pin/token/byte limits. Caller-created operation
  refs and holder monitors cancel late metadata acquisitions idempotently.
- [x] Write deterministic tests for caller death, open-to-bind uncertainty,
  pending/unconfirmed retirement, repeated finish/release and cross-instance
  isolation. Public retirement confirmation is necessary before refunding
  connection capacity. No ledger restart that forgets old live transports.
- [x] Create each upstream scope from its persistent custodian, never from an
  exiting preparation worker. Bound custodians by admitted transport records;
  preparation timeout rejects publication while retaining uncertain allocation
  holds and retires late scopes. Test creator DOWN through the public contract.
- [x] Bound scope retirement initiation and abort-escalation helpers, preserving
  D around fixed 5,000-ms upstream calls. Test short-D pending initiation,
  graceful-to-abort escalation, repeated public receipt recovery, late confirmed
  capacity release and unchanged failed stop results. Snapshot retirement errors
  and helper DOWN do not substitute for public cleanup confirmation.

Run `mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy/test/lifecycle_participant_test.exs`
in the canonical environment; capture red then green with exact counts.

## Task 5: Endpoint, Session, group and generation integration (conditional)


**Current bounded activation — 2026-10-16:** Task4 foundation, fixed H1,
managed H1 groups/probes and H1 Generation are locally accepted at their recorded
commits. Fixed managed H2 completed independent review, full58 853/0, public63/63,
real-peer135/135 and isolated Chrome3/3 with HTTP0.21.10 (feature bbbc50dc628d4d82fde7377b5bcff68bb35e1867,
evidence5516ea1b398d7970e861cabdb2c2c3075be7eeae). The bounded managed-H2
[group accounting/activation](m3-managed-h2-group-accounting-activation.md) now
passes complete FULL SPEC3/CODE3 plus exact fixture rebind review,25 original-source
command gates/1,752 test invocations and fresh Chrome/CDP3/3. Final document/Git custody must pass before a local commit; the resulting
stage closure receipt records the actual commit. The actual native
H1/H2 downstream to h2c/TLS-H2 group subset is qualified; this is not H2 Generation
or standalone-profile activation. Historical negative TLS/browser cleanup remains
UNCONFIRMED_WITH_RETAINED_FAILURE. Fixed9,444,956/group16,478,862/startup5,963,776
are unchanged; cumulative24 failed GREEN attempts/27 ordered root events and
Astra2/2 remain retained. Complete Task5/M3, H2 Generation, standalone integration,
reload/rotation and sustained load retain their separate gates.

Current bounded successor: compiled Router route/resource-sidecar consistency,
native checked Generation capture and native downstream-H2 worker accounting
are completed locally at their recorded commits. The
[fixed prepared-T upstream-H2 Generation](m3-managed-h2-fixed-generation.md)
slice is DONE LOCALLY at feature `bd740b0d4fd53fc680e95fb9430aa9ad914a747b`. The canonical
validation guard and genuine fixed-T old/new/failure tests passed full-stage
SPEC1→CODE1, document SPEC2→CODE/custody and fresh19-file537/0, strict compile/
format/syntax, core consumer1/0, HTTP consumer2/0, reviewed diagnostic4 browser
four rows/eight viewed images and actual committed-byte custody. Historical
browser-final2 FAIL/UNKNOWN stays preserved; no production close repair claimed.
NetLog projections remain incomplete. Group45/root66/stage failedGREEN4;
fixture3/production0/orchestration7/Astra2/2 exhausted; final document SPEC1 FAIL
and factual repair preserved. Bounded [group Generation](m3-managed-h2-group-generation.md) readiness
passed SPEC2→CODE1; collector3 initial91-test verification passed pre-repair2 source. Raw-source repair2 now has expected RED2 and fresh93/0 GREEN; browser-green3 remains FAIL after first-row navigation/request-clean/Chromeclose, with versioned fixture normal-stop repair now through bounded SPEC1→CODE1 and syntax. Initial browser-green4 passes four rows/8 root-viewed screenshots/24 actor exit0/nonforced joins; full-stage review/final gates and composite Task5 remain incomplete. Continuing
authorization advances verified/reviewed slices without routine approval stops.

Modify: `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, `http/session.ex`,
`http_fetch_client.ex`, `group_endpoint.ex`, `upstream_groups.ex`,
`upstream_groups/options.ex`, `upstream_groups/probe.ex`.
Create tests: `apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs`,
`apps/gaoxy_proxy/test/upstream_transport_generation_test.exs`.
Existing generic HTTP Resources/Generation interfaces should suffice.

- [x] Add pure `HTTP.resources/1` and optional prepared transport validation;
  retain the existing dedicated H1 default. Return group plus deduplicated
  member transport handles, preserving the 64-handle sidecar bound. Bound
  candidate preparation pins and roll back only the candidate on failure.
- [ ] Acquire fixed-endpoint request pins outside Generation; for Generation,
  use the snapshot pins already acquired atomically. Session selects once,
  checks out transport once after cleanup activation, opens once and binds
  completion before enabling upload. Keep independent group and transport
  tokens and hold both until public request cleanup.
- [x] Integrate probes with the same immutable transport identity and existing
  finite probe budget. Acquire holds outside group/transport owners; no owner
  call cycle or new probes on retiring generations. Preserve health semantics.
- [x] Change adapter options only through the verified public managed facade;
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

## Historical architecture self-review and handoff

Requirements map: public API/deadline identity and source bounds -> Tasks 1–3;
capacity/ownership/trust and generic instance stop hook -> Task 4;
generations/groups/guardian completion ->
Task 5; trailers/matrix/slow peers -> Task 6; retirement/failure isolation ->
Task 7; managed H1/H2 sustained load -> Task 7b;
independent review/compatibility/evidence -> Task 8.

The architecture worker wrote only the two assigned documents and performed
source/document checks. Runtime checks are NOT RUN by that worker. No recovery
repair budget was used. At that architecture checkpoint, Sol could execute Tasks 0–2; Tasks 3–8
remained gated by upstream #78, resolution of demonstrated bounds defects, and
containing-release qualification. The current disposition below supersedes that
installed-source and blocker state. No additional product decision is needed to run the ready-now
probes or route their findings.

Architecture refinement 1 addresses independent SPEC findings S1–S3: the
generic registered participant joins idle/shared retirement before instance-stop
success (Tasks 4/7), two new >=600-second managed transport profiles qualify
sustained lifetime/churn (Task 7b), and resource facade/provider arities remain
distinct. Document self-review is not the pending independent re-review and
does not qualify runtime behavior.

## Current execution checkpoint — 2026-10-11

Installed0.21.3 provenance/source review, compatibility486/0 and finite managed
driver39/39 with canonical MATCH and39 joined cleanups pass. Supplemental
TLS95 passes5/5, H1 baseline20/0 and separately admitted B21 pass, and the public
H2 parser/cancellation supplement passes8/8 (TLS4/h2c4), with eight joined peers
and exit0. Five acquisition-failure probes meet their expected negative oracles;
independent H1/H2 specification, code and evidence review passes. See
[current acceptance](../acceptance/m3.md) for exact receipts.
ADR007 excludes the dismissed control-proof gate from acceptance. Numerical
fixtures remain historical and reusable adapters are unimplemented; neither
blocks the reviewed v0.2.0 subset or M4 preparation.
The previous 0.21.1 cleartext24/24 and 0.21.0 functional/source receipts retain
their exact historical scopes and failures.
The older handoff and local delivery
`d8e3a26` preserve their historical qualification/TLS boundary.
