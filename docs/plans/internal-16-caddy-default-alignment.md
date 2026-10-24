# Caddy-informed WebSocket defaults implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Remove Gaoxy's implicit WebSocket payload ceilings, preserve explicit limits and finite transport resources, and separate subsequent lifecycle/HTTP policy changes.

**Architecture:** Core Admission separates transport reservations from retained WS messages/state/output. Pure configuration normalization preserves explicit legacy limit provenance through H1/H2/H3 and repeated validation. Incremental internal framing bounds transport staging while keeping the complete-message WebSock callback API.

**Tech Stack:** Elixir/OTP, native Gaoxy H1/H2/H3, Plug/WebSock/Phoenix, vendored WebSockAdapter, Python independent protocol peers.

---

Date: 2026-10-24, Asia/Shanghai. Source baseline:
`e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f` on `main`.
Status: **proposed implementation plan; no implementation or runtime qualification
has been performed in this research task**. All checkboxes below describe future
work. Research and source references are in
[the design](../designs/internal-16-caddy-default-alignment.md).

The concrete trigger is [#16](https://github.com/gsmlg-dev/gaoxy/issues/16): a
default 300 KiB server reply and a 313,781-byte initial LiveView render close
1011. Raising the service budget is a reported downstream mitigation, not the
target behavior. Caddy v2.11.7's 32 KiB copy buffer is not a message ceiling;
its opaque proxy also does not have Gaoxy's complete-message callback memory
cost. The plan aligns policy ownership and documents that distinction.

## Execution boundaries and ownership

Work on `main` under the user's branch instruction, preserving unrelated files.
The coordinator owns integration, inventory/count updates, docs and final
verification. Use Sol workers for implementation/tests and independent review.
Parallel writers must own disjoint files and must not revert others' edits.
If isolation is needed later, any new worktree belongs under `.trees/`.

| Owner | Responsibility | Dependency |
| --- | --- | --- |
| Configuration worker | Task 1: core normalization, activation and H1/H2/H3 option assembly | Baseline/reproduction |
| Accounting worker | Task 2: pure accounting and Admission transitions/status | Task 1 interfaces |
| Framing worker | Task 3: frame/message chunking and pure regressions | Independent of Tasks 1–2; final integration waits for both |
| Coordinator or integration worker | Task 4: common engine, protocol handoff, vendor dispatch and default acceptance | Tasks 1–3 |
| Lifecycle worker | Tasks 5 and 6, sequentially | Task 4 gate |
| Independent reviewers | Specification, accounting/implementation and protocol-source review | Each completed slice |

The accounting/framing foundation is not a partial release of uncapped defaults.
Keep existing live engine behavior until Task 4 switches the complete path.
Commit only coherent, reviewed changes with their relevant passing tests;
integration-dependent edits may be one reviewable commit. Use conventional
messages without generated-by or AI coauthor trailers.

Only Task 4's payload/accounting acceptance is required to resolve #16's
reported size behavior. Tasks 5–6 are separate lifecycle decisions. General
HTTP alignment is the follow-up design in Task 7. This research task neither
implements these tasks nor initiates another release. Historical slow-peer,
pressure, blocked-upload and soak slices retain their existing specialist
dispositions and are not reopened.

## Task 0: Preserve the current failure and define acceptance

**Files:**
- Create: `apps/gaoxy_http/test/websocket_default_capacity_network_test.exs`.
- Create: `examples/phoenix_native/test/websocket_default_capacity_test.exs`.
- Modify: `scripts/check-repairs.py`, `scripts/test-inventory.json`.
- Create during execution: `docs/acceptance/internal-16-default-capacity.md`.

- [ ] Record HEAD, dirty paths, BEAM/Elixir/peer versions, environment and
  exact commands in the execution record before changes. Preserve the original
  issue report separately from a fresh local reproduction.
- [ ] Add a default H1 WebSock fixture with **no** frame/message/service budget
  override. Its `init/1` emits `{:push, {:binary, payload}, state}` with
  `payload = :binary.copy(<<0x61>>, 300 * 1024)`. Require the peer to receive the
  exact complete payload and then exchange ping/pong. Original source should
  fail by closing 1011 rather than delivering that reply; record the actual
  observed result, not a predicted RED as if executed.
- [ ] Add a real LiveView fixture that mounts with enough assigned content for
  a serialized initial join reply of at least 313,781 bytes. Reuse the signed
  session/CSRF, native WebSocket join and JSON helpers from
  `websocket_phoenix_compatibility_test.exs`. Omit WS frame/message limits and
  listener `max_bytes`/`max_state`; do not reuse that test's raised budgets.
  Assert the measured encoded size, successful `phx_reply`, full expected
  rendered content, a subsequent Phoenix heartbeat reply and normal cleanup.
- [ ] Keep the new app network file in `protocol`, never `unit`. Add its exact
  positive executed count to the sole active manifest. The Phoenix fixture
  runs under the existing nonempty fixture gate in `e2e.yml`.

Focused commands from the repository root, after dependency preparation:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 scripts/check-tests.py apps/gaoxy_http/test/websocket_default_capacity_network_test.exs --seed 0 --max-cases 1
```

From `examples/phoenix_native`:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 ../../scripts/check-tests.py test/websocket_default_capacity_test.exs --seed 0 --max-cases 1
```

Save the unchanged failing assertions and logs. Neither raising a fixture budget
nor accepting any close code in place of the payload constitutes GREEN.

## Task 1: Normalize policy and preserve explicit configuration

**Files:**
- Modify: `apps/gaoxy/lib/gaoxy/config.ex`, `apps/gaoxy/lib/gaoxy/activation.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http.ex`.
- Modify: `apps/gaoxy_http3/lib/gaoxy/http/http3/options.ex`.
- Create: `apps/gaoxy/test/websocket_retention_config_test.exs`.
- Modify: `apps/gaoxy/test/activation_config_test.exs`.
- Modify: `apps/gaoxy_http/test/websocket_configured_limits_test.exs` when the
  associated default change is enabled in Task 4.

- [ ] Write socket-free configuration tests first. Cover raw core/H1/H2/H3
  defaults, explicit values equal to each default, second normalization,
  unknown keys, invalid infinity use and malformed/stale provenance.
- [ ] Add these public service limit defaults; all existing numeric limits
  retain positive-integer validation:

```elixir
%{max_websocket_bytes: :infinity, max_websocket_state: :infinity}
```

- [ ] Implement these pure core contracts, retaining the current public
  `Config.service/1` and `Gaoxy.start_link/1` signatures:

```elixir
Gaoxy.Config.normalize_limits(raw_limits, defaults, sources \\ nil)
# {:ok, %{limits: limits, limit_sources: sources}} | {:error, reason}
Gaoxy.Config.put_limits(normalized_spec, overrides)
# {:ok, normalized_spec} | {:error, reason}
Gaoxy.Config.retention_policy(normalized_spec)
# %{max_retained_bytes: limit, max_retained_state: limit, max_total_bytes: limit}
```

`normalize_limits/3` merges core defaults, supplied protocol defaults, then raw
input. On first normalization, raw key presence determines whether `max_bytes`
and `max_state` are explicit. Preserve complete internal metadata on subsequent
normalization, validating the recorded value against the actual legacy value:

```elixir
%{
  max_bytes: {:default, 268_435_456},
  max_state: {:explicit, 65_536}
}
```

Invalid metadata fails validation. `put_limits/2` validates intentional updates
and marks overridden legacy keys explicit, even if the number is unchanged.
Use it at owned callsites that intentionally change normalized legacy limits.
Do not expose `limit_sources` as an HTTP/HTTP3 keyword option.

- [ ] Replace H2's `Map.put_new` default insertion and H3's private limit merge
  with the core helper. Carry `limits` and `limit_sources` together through
  Config revalidation and ETS. Preserve numeric reservation checks and backend
  option normalization. Core must not import an HTTP application.
- [ ] Derive effective retained policy exactly as follows:

```text
max_retained_bytes = limits.max_websocket_bytes
max_retained_state = min_limit(limits.max_websocket_state,
                              explicit legacy max_state or infinity)
max_total_bytes = explicit legacy max_bytes or infinity
```

- [ ] Make limit operations explicit. Use this comparison shape rather than
  integer/atom ordering in activation and capacity validation:

```elixir
def limit_within?(:infinity, :infinity), do: true
def limit_within?(n, :infinity) when is_integer(n) and n > 0, do: true
def limit_within?(:infinity, n) when is_integer(n) and n > 0, do: false
def limit_within?(n, cap) when is_integer(n) and n > 0 and is_integer(cap) and cap > 0,
  do: n <= cap
def limit_within?(_, _), do: false
```

Define `min_limit(:infinity, n) = n`, `min_limit(n, :infinity) = n`, and integer
minimum for validated finite policies. Byte counters may be zero; policy limits
must be positive or infinity, so do not confuse limit validation with counters.

- [ ] Update activation plan matching to compare both numeric/new limits and
  effective retention policy. Test finite-to-infinite rejection with equal
  legacy numeric maps but changed provenance; allow legitimate tightening.
- [ ] Run the new pure config file and activation config file with
  `scripts/check-tests.py`, seed 0, max-cases 1. Classify the new file as unit,
  with exact executed count. Verify ordinary core/UDP defaults and QUIC's
  existing numeric capacity inputs remain unchanged.

## Task 2: Add classified admission without losing lease ownership

**Files:**
- Create: `apps/gaoxy/lib/gaoxy/admission/accounting.ex`.
- Modify: `apps/gaoxy/lib/gaoxy/admission.ex`, `apps/gaoxy/lib/gaoxy/service.ex`.
- Modify as needed for documented status fields: `apps/gaoxy/lib/gaoxy/telemetry.ex`.
- Audit; modify only if ordinary lease representation changes:
  `apps/gaoxy_http/lib/gaoxy/http/http2/worker_accounting.ex` and
  `apps/gaoxy_http/test/http2_worker_accounting_test.exs`.
- Create: `apps/gaoxy/test/websocket_accounting_test.exs` (pure unit).
- Create: `apps/gaoxy/test/websocket_admission_test.exs` (controlled component).

- [ ] Write a pure capacity/transition table and controlled gate tests first.
  The accounting vector has nonnegative integer `transport_bytes`,
  `websocket_bytes` and `state_bytes`; the last is a subset of retained WS
  bytes used for the initial per-connection state check, not a third additive
  category. Ordinary scalar leases remain `{transport_bytes: n, websocket_bytes: 0}`.
- [ ] Centralize the following capacity predicate in the pure accounting module;
  all aggregate quantities are computed after subtracting the old lease vector
  and adding its replacement:

```text
transport_bytes <= finite limits.max_bytes
AND (max_retained_bytes is infinity OR websocket_bytes <= max_retained_bytes)
AND (max_total_bytes is infinity OR transport_bytes + websocket_bytes <= max_total_bytes)
```

Validate counter types/nonnegativity before arithmetic. Initial WS application
state must also satisfy `max_retained_state` before the handshake succeeds.

- [ ] Service initializes Admission with `{limits, retention_policy, scope}`.
  Keep the old scalar upgrade path working until Task 4 integration; add the
  classified owned upgrade contract:

```elixir
Gaoxy.Admission.upgrade(gate, lease, accounting, deadline)
# {:ok, retention_policy} | {:error, reason} for classified WS upgrade
```

- [ ] Upgrade the existing lease atomically. Retain request-active/drain checks,
  owner identity, generation, monitor and send-operation ownership. Require
  classified retain/update/callback calls for a classified WS lease; reject
  scalar replacement that would silently discard retained WS memory.
- [ ] Review every acquisition, begin/retain/update, adjust, send, cleanup and
  terminal transition against the centralized predicate. Scalar operations by
  connection/stream owners update only their owned transport reservations.
  Send reservation adds finite staging bytes without counting the entire
  retained callback payload a second time. Late/unknown outcomes retain their
  existing terminal semantics.
- [ ] Extend status and high-water telemetry with transport and retained WS
  categories. Preserve total `bytes` as their sum, not a promise of total VM
  memory. Document that only explicit legacy aggregate policy bounds total
  bytes by `max_bytes` after a default WS upgrade.
- [ ] Audit H2 `WorkerAccounting.caps/6` and its modeled lease/overlap sizes.
  If generic accounting adds fields to ordinary leases, update the estimator
  and its independent test constructors together. Include a controlled
  component check against a realized ordinary Admission lease so a stale
  hand-built schema cannot make both the estimator and its unit test pass.
  If ordinary lease shape is preserved, record why no estimator change is
  needed. Do not alter unrelated H2 memory policy.
- [ ] Component regressions prove unauthorized/stale upgrades fail, admission
  rejection leaves the old lease intact, multiple WS leases share one retained
  budget, explicit total policy applies across ordinary and WS work, and close,
  owner death and finite drain restore both counters exactly once. Use controlled
  messages/monitors, no real sockets in this file.
- [ ] Run both new files through `scripts/check-tests.py`; classify the pure
  file as unit and the real Admission collaboration as component. Preserve
  raw/UDP scalar semantics. This task does not enable new live engine defaults.

## Task 3: Build incremental framing and bounded output traversal

**Files:**
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/frame.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/message.ex`.
- Create: `apps/gaoxy_http/test/websocket_incremental_frame_test.exs` (unit).

- [ ] Write pure decoder cases that divide a masked frame at every header/mask
  boundary and several non-multiple-of-four payload offsets. Include split
  UTF-8 sequences, 64-bit lengths, invalid control frames, invalid fragment
  order, interleaved ping/pong and explicit finite limits.
- [ ] Add internal incremental decode/encode interfaces to the existing frame
  module. Preserve existing `decode/2` and `encode/3` contracts for consumers;
  switch the engine to incremental interfaces only in Task 4:

```text
decoder(options) -> decoder state
consume(decoder, bounded_input) -> {:ok, events, next_decoder} | {:error, code, reason}
encoder(opcode, iodata, fin) -> {:ok, cursor} | {:error, code, reason}
next_chunk(cursor, positive_quantum) -> {:ok, chunk, next_cursor} | :done
```

Events describe data-frame start `(opcode, fin, declared_length)`, payload
pieces, frame end, or a complete bounded control frame. Payload pieces are
retained as message data. A cursor never creates a complete header-plus-payload
binary and never returns a chunk over its quantum. Validate text/iodata before
transmitting a frame; preserve the 125-byte control-frame and 63-bit length rules.

- [ ] Track mask position across reads. Frame limits check declared frame
  length; message limits check accumulated message bytes. A transport chunk
  is not a WebSocket fragment. Count actual wire fragments independently and
  avoid storing an empty payload list entry for every empty fragment.
- [ ] Make frame/message/fragment policy comparisons infinity-aware. Assembling
  a complete application message remains necessary; account flattening overlap
  rather than claiming the message itself is bounded by staging size.
- [ ] Add pure output tests using nested iodata larger than 256 KiB. Assert
  reconstructed wire bytes exactly match the retained legacy encoder for
  valid fixtures, chunk sizes never exceed the quantum, and header/UTF-8/control
  validation rejects malformed output before any chunk is sent.
- [ ] Run and classify the new unit file. Do not activate previously retained
  legacy network files just because their names resemble these cases; preserve
  their inventory dispositions. No listener or protocol peer belongs here.

## Task 4: Integrate the new default payload policy across H1/H2/H3

**Files:**
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/stream.ex` (common H2/H3
  demand/receive loop and WS start handoff).
- Modify handoff/accounting only: `apps/gaoxy_http/lib/gaoxy/http/connection.ex`,
  `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`,
  `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex`.
- Modify handoff/accounting only: `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/stream.ex`.
- Modify if queue credit transfer requires it:
  `apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/transport.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/operations.ex`.
- Modify: `vendor/websock_adapter/lib/websock_adapter.ex`,
  `vendor/websock_adapter/test/gaoxy_dispatch_test.exs`,
  `vendor/websock_adapter/gaoxy.patch`, `vendor/websock_adapter/SOURCE.json`,
  `vendor/websock_adapter/GAOXY.md`.
- Modify tests: `apps/gaoxy_http/test/websocket_configured_limits_test.exs`,
  `apps/gaoxy_http/test/websocket_stream_test.exs`,
  `apps/gaoxy_http/test/websocket_configured_limits_network_test.exs`,
  `apps/gaoxy_http/test/http2_websocket_network_test.exs`,
  `apps/gaoxy_http3/test/websocket_network_test.exs`,
  `examples/phoenix_native/test/websocket_configured_limits_test.exs`.
- Complete the two default regressions introduced by Task 0.

- [ ] Change omitted native frame/message/fragment defaults to infinity and
  remove the `/4` clamp. Preserve finite frame-to-message inheritance, explicitly
  supplied infinity and independent finite message policy. Keep idle/lifetime
  defaults unchanged until their separate slices.
- [ ] Use the classified Admission upgrade and returned effective state policy.
  Remove the need for H2/H3 copies of just `max_bytes`/`max_state`; common WS
  start takes its owned exchange and gets policy atomically from Admission.
- [ ] Connect incremental input/output. Charge the entire unsent callback batch
  while it is retained, plus transient copies; check message limits independently
  for each text/binary tuple. Retain `max_push_frames` and control-frame bounds.
- [ ] Ensure H2/H3 stream and connection owners release/transfer each bounded
  transport credit exactly once as payload enters message retention. Keep
  protocol flow-control/writer limits numeric and finite. Unchanged sibling
  streams and ordinary HTTP requests must still operate after WS cleanup.
- [ ] Change adapter default injection before dispatch, preserving other adapters:

```elixir
opts =
  if adapter == Gaoxy.PlugAdapter,
    do: opts,
    else: Keyword.put_new(opts, :max_frame_size, 10_000_000)
```

Do not remove an explicitly supplied `10_000_000`. Update adapter option docs,
the isolated dispatch regression, canonical patch and all snapshot hashes.
Use the reconstruction procedure and isolated command in `GAOXY.md`; a hash-only
update is insufficient. Do not edit `deps/`.

- [ ] Replace assertions for superseded default 256 KiB and `/4` behavior with
  the approved contracts, retaining their old evidence. Explicit budget tests
  must still prove rejection by actual accounted capacity; removing the heuristic
  clamp need not preserve its old synthetic boundary or close reason. Preserve
  frame/message RFC limit close-code assertions and normal-close assertions.

Required acceptance matrix, with exact payload equality and positive counts:

| Case | Assertion |
| --- | --- |
| Default H1 300 KiB server reply | Complete reply, ping/pong, normal close; no budget override |
| Default actual LiveView initial render ≥313,781 bytes | Join/render complete, Phoenix heartbeat replies, transport/channel cleanup |
| Default native/adapter input and output | 300 KiB and 2 MiB messages succeed without payload/service overrides |
| Former adapter/H3 clamp thresholds | Adapter payload >10,000,000 bytes and H3 payload >4 MiB succeed under omitted payload policy |
| Fragment count | 129 legal fragments succeed by default; explicitly selected 128 rejects with 1009 |
| Explicit independent limits | Declared oversized frame and fragmented oversized message reject at selected byte boundary |
| Callback batch | Two individually valid messages whose sum exceeds a finite message limit succeed; oversized individual message fails |
| State/retained/legacy aggregate | New state and shared retained ceilings reject; explicit legacy values, including values equal to defaults, still constrain |
| Memory categories | Measured staging/credits stay within finite configured bounds while retained message counters grow; terminal counters return to baseline |
| Protocol siblings | H2/H3 WS completion/failure preserves healthy sibling stream and subsequent ordinary HTTP request |

Do not allocate a >256 MiB network message merely to cross H2's old aggregate
budget. Prove category separation using controlled component fixtures with a
small default-sourced transport budget, plus bounded protocol cases above the
former payload thresholds. These are ordinary finite regressions, not pressure
or sustained-load qualification. No single size test proves an infinite capacity.

- [ ] Run scoped unit/component/protocol files, the Phoenix default and explicit
  suites, and the isolated vendor/reconstruction checks. Obtain independent
  specification and code review, resolve actionable findings, then run the
  fresh final gates below. Record any external block with its actual status;
  do not suppress a missing protocol run or substitute source inspection.

## Task 5: Separate native inactivity policy

**Files:**
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket.ex` and its idle receive
  owners in `apps/gaoxy_http/lib/gaoxy/http/connection.ex` and
  `apps/gaoxy_http/lib/gaoxy/http/websocket/stream.ex`.
- Create: `apps/gaoxy_http/test/websocket_lifecycle_config_test.exs` (unit).
- Extend: `apps/gaoxy_http/test/websocket_stream_test.exs` (component),
  Task 0 protocol/Phoenix files for real-peer policy coverage.

- [ ] Add RED cases for omitted native timeout, explicit finite/infinite timeout,
  invalid values and a Phoenix-supplied `60_000`. Numeric equality never detects
  omission. The adapter must preserve the options it actually receives.
- [ ] Set native omitted `timeout` to infinity and accept that sentinel on this
  field. Skip idle timer creation when infinite; preserve finite inactivity
  expiration and the existing event/reset ownership. Callback and send operation
  deadlines stay finite. Do not change HTTP keepalive or lifetime in this task.
  H1 can use Hell's supported `{:persistent, :infinity}` handler timeout; the
  common multiplexed receive loop must handle infinite waits explicitly.
- [ ] Verify quiet native WS remains owned until explicit close/drain, finite
  inactivity expires, active callbacks still time out and Phoenix's effective
  finite value survives normalization. Use controlled short finite settings and
  timer ownership assertions; do not introduce a 60-second unit sleep.
- [ ] Review and qualify this slice separately. Document it as a Gaoxy native
  policy choice, not identical Caddy H2/H3 idle behavior.

## Task 6: Remove the implicit absolute lifetime separately

**Files:**
- Modify: `apps/gaoxy/lib/gaoxy/admission.ex`, `apps/gaoxy/lib/gaoxy/lifecycle.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/stream.ex`.
- Modify lifetime handoff only:
  `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`,
  `apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/transport.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/operations.ex`.
- Extend: `apps/gaoxy_http/test/websocket_lifecycle_config_test.exs`,
  `apps/gaoxy/test/websocket_admission_test.exs`,
  `apps/gaoxy_http/test/websocket_stream_test.exs` and focused H2/H3 protocol files.

- [ ] Add RED coverage for an owned live HTTP request upgraded to infinite WS
  lifetime, expired request rejection, finite lifetime that callbacks cannot
  renew, and cleanup of infinite WS leases on finite service drain.
- [ ] Default `max_lifetime` to infinity and accept it at the admission upgrade
  boundary. Extend `Lifecycle.deadline/1` explicitly:

```elixir
def deadline(:infinity), do: :infinity
def deadline(timeout), do: now() + timeout
```

Preserve current `remaining/1` semantics. Do not add an infinity duration to
`now()` or pass infinity to `Process.send_after/3`. Set lifetime token/timer to
nil when unbounded; finite upgrade cancels the previous request timer and arms
one new absolute deadline. Ignore stale previous tokens.

- [ ] Keep callback/close/send/drain caps finite, selecting a finite operation
  deadline even with infinite lifetime. Include the H2/H3 protocol owner and
  operation-table lifetime transition rather than only the common WS struct.
  Do not enable general H3 infinite request timeouts in this task.
- [ ] Verify close during/after finite expiry, owner death, finite callback
  timeout and drain release all reservations without renewing finite lifetime.
  Run focused tests and independent review before integrating this slice.

## Task 7: Write the separate HTTP defaults design

**File:** Create `docs/designs/caddy-http-timeout-alignment.md`.

- [ ] Map Gaoxy's current 30s whole-request timeout, 5s header/read/write values
  and route streaming policy to their actual H1/H2/H3 operation owners. Use
  the pinned Caddy facts in the research document, including v2.11.7's fixes
  for SSE and handler-lifecycle regressions introduced in v2.11.6. This is a
  new design task, not an instruction
  to change those constants while fixing #16.
- [ ] Propose distinct 60s header completion, active read-progress and active
  write/flush deadlines; no default hard transfer lifetime; and 5m next-request
  idle. Define compatibility for explicit current settings and explain H3's
  currently unsupported infinite request timeout. Require quiet SSE intervals,
  request-body EOF followed by long response, and H2 sibling isolation cases.
- [ ] Keep current 32 KiB headers and 8 MiB body ceiling until their separate
  compatibility/admission decisions are documented. Preserve supported transport
  capabilities; do not add pools, upstream H2, proxy bypasses, browser gates or
  revive excluded HTTP Fetch/specialist qualification requirements.
- [ ] Obtain architecture/specification review and produce a scoped execution
  plan before starting the general HTTP runtime change.

## Fresh gates, documentation and eventual publication boundary

Run only after implementation, not as documentation-only research verification.
Use the repository's pinned peer dependencies and environment; independent
network tests belong in Linux E2E. Unit tests must not open sockets or launch
protocol peers. `portable.yml` remains only start, health 200/ok and stop.

From the repository root:

```sh
python3 scripts/check-test-inventory.py
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 scripts/check-repairs.py unit
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 scripts/check-repairs.py component
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 scripts/check-repairs.py protocol
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix format --check-formatted
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix compile --warnings-as-errors
python3 scripts/test-stage-hex-packages.py
python3 scripts/test-consumers.py
```

From `examples/phoenix_native`, use its existing locked dependency preparation
and `python3 ../../scripts/check-tests.py` for its nonempty fixture gate. Run
vendor dispatch and reconstruction independently as described in `GAOXY.md`.
Update exact manifest counts to the actual implemented cases; require no skipped
or excluded required cases. Once relevant gates pass, do not repeat the same
runs without a new change/failure/concern.

- [ ] Update `README.md`, affected package option docs, the fixture README and
  `CHANGELOG.md` with the effective defaults, explicit-limit example, changed
  status invariants and complete-message memory exposure. Record the approved
  change to #6's old default/clamp policy without rewriting historical evidence.
- [ ] Record exact source identity, commands, executed counts, exits and
  independent review. Keep READ, PASS, FAIL, BLOCKED and NOT RUN distinct.
  Report unrelated failures without silently repairing outside this scope.
- [ ] For a later release, recheck the current user instruction and use the
  existing guarded exact-source publication workflow, synchronized package
  versions, clean consumers and public artifact read-back. A plan or local
  green test is not publication proof. No release is started by this document.
- [ ] Close #16 only after the size-default acceptance, published-consumer
  verification when released, and the requesting application's acceptance are
  established. Any missing downstream validation remains explicit. Rerun the
  open internal-request query after closeout; do not infer an empty queue from
  the earlier #15 release.

No deployment, production data, operational certificates, Vault changes,
public-management endpoint changes or enabling of the released-server E2E gate
is included.
