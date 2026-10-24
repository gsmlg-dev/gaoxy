# Persistent WebSocket connections and unrestricted data transfer plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` or `executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Keep healthy WebSocket connections open without implicit inactivity/lifetime or data-size cutoffs, using finite reusable transport capacity and preserving explicit application ownership.

**Architecture:** Classify WS retained messages/state/output separately from finite transport reservations, and measure those retained bytes without a generic service ceiling. Incremental internal framing and credit recycling permit larger and repeated transfers. Callback computation, bounded sends, close and drain have separate operation owners; none supplies a deadline for a whole progressing transfer.

**Tech Stack:** Elixir/OTP, native Gaoxy H1/H2/H3, Plug/WebSock/Phoenix, vendored WebSockAdapter, independent protocol peers.

---

Date: 2026-10-24, Asia/Shanghai. Research source baseline:
`e435c05b08d7cbdb0e3c02ee585f23ddc8b9316f`; previous documentation commit:
`58e3e43eef3a57e8a49d32e4b03d2515294cf240`, branch `main`.
Execution baseline: `76d76ef2c93e25dc46b8d96ee4b06e7fa349b617`, branch `main`.
Status updated 2026-10-25: **implemented slices and scoped H1/Phoenix/H3 checks
pass; H2 connection-owner persistence is BLOCKED; final combined acceptance and
publication remain incomplete**. Checked items record established implementation
and scoped evidence, not completion of the entire product contract. Final local
canonical gates and the complete Phoenix fixture have passed; H2 persistence
still requires the upstream fix and fresh qualification.
See [research and product contract](../designs/internal-16-caddy-default-alignment.md).

The user's clarification makes size, inactivity and lifetime one completion
contract. Separate implementation commits do not make the latter optional.
General HTTP timeout/body defaults remain separate. Actual transport loss,
protocol errors, application-requested close and service shutdown remain normal
lifecycle events; this is not a promise that a physical connection never fails.

## Scope and ownership

Work on `main`, preserve unrelated files and use small reviewed conventional
commits. If isolation becomes necessary, put worktrees under `.trees/`.
The coordinator owns integration, inventory/count updates, docs and final gates.
Sol workers may own disjoint framing and accounting files in parallel; dependent
handoffs, edits and final integration are sequential. Do not revert others' work.

| Owner | Work | Dependency |
| --- | --- | --- |
| Framing worker | Task 1: pure incremental frame/message processing | Existing interfaces; independent of accounting work |
| Accounting worker | Task 2: classified leases, callback/output transition and cleanup | Product contract |
| Integration worker/coordinator | Task 3: native lifetime/idle and protocol-owner handoff | Tasks 1–2 |
| Adapter/Phoenix worker | Task 4: dispatch and supported endpoint configuration | Product contract; integration waits for Task 3 |
| Independent reviewers | Specification, source/ownership and protocol acceptance | Completed slices |

Do not add the previously proposed `max_websocket_bytes`, `max_websocket_state`,
legacy source metadata, combined WS budget or activation-policy machinery.
Generic `max_bytes`/`max_state` do not constrain WS messages or application state,
even when an operator supplied them for service resources. Existing deliberately
chosen WS application policies remain a separate opt-in compatibility path.
Do not mistake framework injection for an explicit application decision.

The H3 gate is resolved: [http_fetch#143](https://github.com/gsmlg-dev/http_fetch/issues/143)
and [abyss#6](https://github.com/gsmlg-dev/abyss/issues/6) are **CLOSED**; released
Abyss **0.10.0** and the HTTPFetch/QUIC **0.21.17** cohort are installed in both
locks. Actual H3 independent-peer qualification passed **2 tests, 0 failures**,
including exact **5 MiB** transfer and **900 ms** quiet with **300 ms** peer idle.

H2 connection-owner persistence is **BLOCKED** by the still-**OPEN** Feature
[hell#2](https://github.com/gsmlg-dev/hell/issues/2). There is no local workaround;
resume the idle transition/restoration slice only after a released fix is
installed. H2 size/stream results do not complete its quiet persistence. Size
and persistence remain one contract: **no release or #16 closure** until that
contract and final gates pass. Historical specialist slow-peer, pressure,
blocked-upload and soak evidence keeps its existing disposition.

Scoped evidence is consolidated in
[the acceptance record](../acceptance/internal-16-default-capacity.md). Native
default capacity passed **5 tests, 0 failures**; actual LiveView default capacity
**1 test, 0 failures**; Phoenix configured-policy/compatibility **12 tests, 0
failures**; callback completion is now **22 tests, 0 failures** after preserved
**22-test/2-failure** RED. A canonical protocol execution passed **130 tests, 0
failures**. These
results are included in the final local gate run: unit **254/0**, component
**167/0**, protocol **130/0**, full Phoenix **24/0**, clean package consumers
**7/0** plus production isolation/consumer release. Inventory, format and strict
compile exit 0. H2 connection-owner persistence remains blocked.

## Task 0: Record the current failure and final contract

**Files:**
- Create: `apps/gaoxy_http/test/websocket_default_capacity_network_test.exs`.
- Create: `examples/phoenix_native/test/websocket_default_capacity_test.exs`.
- Create during execution: `docs/acceptance/internal-16-default-capacity.md`.
- Modify inventory/counts: `scripts/check-repairs.py`, `scripts/test-inventory.json`.

- [x] Record source identity, dirty paths, runtime/peer versions, exact commands,
  executed counts and original failures before source edits. Native and Phoenix
  1011 RED logs are preserved under `.audit/internal-16/`; final evidence
  consolidation remains part of Task 5.
- [x] Add a default H1 handler whose init returns
  `{:push, {:binary, :binary.copy(<<0x61>>, 300 * 1024)}, state}`. With no frame,
  message or raised service-budget option, require exact complete bytes followed
  by ping/pong and normal close. Preserve the actual original 1011 failure.
- [x] Add actual LiveView initial-render acceptance with serialized join reply
  at least 313,781 bytes, full rendered content and subsequent Phoenix heartbeat.
  Reuse supported signed session/CSRF and wire helpers from the existing
  compatibility fixture, but do not copy its raised frame/service budgets.
  The lifecycle setup uses the documented infinity timeout in Task 4; this is
  explicit integration configuration and is not a zero-config Phoenix claim.
- [ ] Add controlled assertions for no default idle/lifetime close timers and
  reusable transport credits; do not substitute waiting 24 hours or pressure
  testing for ownership assertions. Preserve RED evidence without weakening
  payload, normal-close or cleanup assertions. **Partial:** common engine and
  H1/H3 ownership checks are established; H2 owner idle suppression/restoration
  remains blocked by hell#2, so this combined item stays open.

Run focused root cases with:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 scripts/check-tests.py apps/gaoxy_http/test/websocket_default_capacity_network_test.exs --seed 0 --max-cases 1
```

From `examples/phoenix_native`:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 ../../scripts/check-tests.py test/websocket_default_capacity_test.exs --seed 0 --max-cases 1
```

The root network file belongs to `protocol`; Phoenix real-peer tests belong to
the existing E2E fixture gate. Every required execution must have a positive
count; record an expected-but-unexecuted failure as NOT RUN, never RED/PASS.

## Task 1: Incremental framing and reusable data capacity

**Files:**
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/frame.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/message.ex`.
- Create: `apps/gaoxy_http/test/websocket_incremental_frame_test.exs` (unit).

- [x] Write pure cases splitting headers, masking keys, payload and UTF-8 across
  reads; include actual fragmentation, empty fragments, interleaved controls,
  valid 63-bit lengths and mandatory RFC rejection behavior.
- [x] Add bounded internal interfaces while retaining existing `decode/2` and
  `encode/3` compatibility contracts:

```text
decoder(options) -> decoder state
consume(decoder, bounded_input) -> {:ok, events, next_decoder} | {:error, code, reason}
encoder(opcode, iodata, fin) -> {:ok, cursor} | {:error, code, reason}
next_chunk(cursor, positive_quantum) -> {:ok, chunk, next_cursor} | :done
```

Events describe a data-frame start, payload pieces, frame end, or a complete
bounded control frame. Preserve mask offsets across reads. Internal chunks do
not consume a wire-fragment count. Retain accumulated payload as message memory,
not transport staging; avoid a list entry for each empty fragment.

- [x] Traverse output iodata with a bounded chunk cursor and small frame header;
  avoid flattening a second full wire binary. Validate text/control output
  before sending, preserving mandatory protocol rules. Account unavoidable
  whole-message flattening overlap when it occurs.
- [x] Make omitted frame/message/fragment policies infinite. Keep deliberately
  selected existing application limits separate, with their existing rejection
  assertions. Do not derive policy from a service byte budget.
- [x] Pure tests require exact reconstructed bytes and chunk size at most the
  quantum for nested iodata above 256 KiB. Run this new unit file through
  `scripts/check-tests.py`; classify it with its exact count. No sockets or
  complete runtime collaboration belongs in unit tests.

## Task 2: Classify admission and separate callback execution from output

**Files:**
- Create: `apps/gaoxy/lib/gaoxy/admission/accounting.ex` (pure accounting).
- Modify: `apps/gaoxy/lib/gaoxy/admission.ex`, `apps/gaoxy/lib/gaoxy/service.ex`.
- Modify status documentation/emission as needed: `apps/gaoxy/lib/gaoxy/telemetry.ex`.
- Audit if ordinary lease schema changes:
  `apps/gaoxy_http/lib/gaoxy/http/http2/worker_accounting.ex` and
  `apps/gaoxy_http/test/http2_worker_accounting_test.exs`.
- Create: `apps/gaoxy/test/websocket_accounting_test.exs` (unit).
- Create: `apps/gaoxy/test/websocket_admission_test.exs` (component).

- [x] Define nonnegative integer `transport_bytes` and `websocket_bytes` for each
  classified lease. Ordinary scalar leases still mean transport reservations.
  Account WS payload/state/output as observed retention, with no new enforcement
  ceiling and no implicit legacy aggregate/state cap.
- [x] Centralize transport capacity validation after replacing an owned lease:

```text
new_transport = service_transport - old_lease_transport + replacement_transport
0 <= new_transport <= finite limits.max_bytes
new_websocket = service_websocket - old_lease_websocket + replacement_websocket
new_websocket is a nonnegative integer; it is observed without a size ceiling
bytes = new_transport + new_websocket
```

- [x] Upgrade the existing lease atomically to classified WS ownership. Keep
  generation, owner/monitor, drain eligibility and outstanding-send tracking.
  Classified lease updates cannot discard retained WS ownership through scalar
  replacement. Preserve ordinary raw/UDP/HTTP admission semantics.
- [x] Add one owned callback-result transition, used immediately when a handler
  returns and before any synchronous output send:

```text
end_websocket_callback(gate, lease, accounting)
  validates owner/generation and retained result
  cancels the callback-execution watchdog and invalidates its token
  installs state + complete pending output retention atomically
  preserves the independent connection/application lifetime policy
  returns :ok or an ordinary owned-transition error
```

This transition is an internal Admission interface, not a new WebSock callback.
The existing handler callback is still computation-bounded. Neither that timer
nor its start timestamp can cover the subsequent progressing output batch.

- [x] Update acquisition, callback entry/result, retain/update, send and cleanup
  paths consistently. Send reservations cover the bounded staging operation,
  without counting an already-retained payload once per chunk. Release credits
  only when their actual queue/owner releases bytes; release terminal categories
  exactly once on close, owner death or finite drain.
- [x] Expose transport, retained and total counters/high-water values honestly.
  `transport_bytes <= max_bytes` remains the transport invariant; total WS
  retention may exceed that number. This is not a VM-memory bound.
- [x] Audit H2's hand-built lease-size estimator and independent fixtures if
  ordinary leases gain fields. Include a controlled component comparison with
  a realized ordinary lease so stale copies cannot validate each other. If
  ordinary shape is unchanged, record why the estimator needs no change.
  The ordinary lease retains its original ten keys; classified fields exist only
  after WS upgrade, so the ordinary estimator requires no schema update.
- [x] Controlled cases prove stale/unauthorized transitions fail, rejected
  transport reservation preserves the old lease, repeated credit reuse works,
  explicit generic service budgets do not cap WS retained data/state, and cleanup
  restores counters. Run pure tests as unit and real Admission collaboration
  as component, both with exact positive executed counts.

## Task 3: Integrate persistent native ownership and operation deadlines

**Files:**
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/websocket/stream.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/connection.ex`.
- Modify: `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`,
  `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex`,
  `apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex`.
- Modify: `apps/gaoxy/lib/gaoxy/lifecycle.ex`.
- H3 handoff, only after the upstream gate resolves:
  `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/stream.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/transport.ex`,
  `apps/gaoxy_http3/lib/gaoxy/http/http3/operations.ex`.
- Create: `apps/gaoxy_http/test/websocket_lifecycle_config_test.exs` (unit).
- Extend: `apps/gaoxy_http/test/websocket_stream_test.exs` (component).

- [x] Switch the engine to incremental framing and classified ownership. Remove
  the `/4` clamp and generic `max_state` inheritance. Eliminate copied service
  byte/state maps from H2/H3 WS start handoff. Omitted payload/fragment options
  are infinite and do not become a callback-batch sum ceiling.
- [x] Default `timeout` and `max_lifetime` to infinity. Handle infinity explicitly
  in deadline calculations, timer creation and receive waits, without relying
  on atom/integer ordering. Extend the existing helper without changing its
  finite-value behavior:

```elixir
def deadline(:infinity), do: :infinity
def deadline(timeout), do: now() + timeout
```

- [x] Upgrade only a live owned HTTP request. Cancel its old watchdog, invalidate
  stale request/callback tokens and create no default WS lifetime timer. Keep a
  deliberately finite application policy distinct; callbacks cannot renew it.
- [ ] On H1 upgrade use Hell's supported `{:persistent, :infinity}` for the
  unrestricted path. For H2, also suppress the inherited connection-owner read
  idle while WS streams require persistence; an infinite common WS receive loop
  alone is insufficient. Restore ordinary owner policy appropriately after the
  last WS stream ends, preserving sibling streams and finite partial-frame/I/O
  operations. Do not change all ordinary HTTP connections to infinite idle.
  **Partial:** H1 uses the supported persistent transition. H2 upgrade/removal
  TODOs identify hell#2; its owner transition and restoration are not implemented.
- [x] Invoke the owned callback-result transition immediately after handler
  return. Release unsent batch retention progressively while traversing output.
  Replace default output-frame-count/mailbox-close shortcuts with bounded work
  turns/demand/backpressure where they would reject healthy valid transfer.
  Supported owned queues stay finite; do not claim arbitrary external process
  messages can be backpressured by the WS transport.
- [x] Give each actual bounded send a fresh finite operation deadline. A quiet
  connection has no pending send. A progressing multi-chunk message may take
  longer in total than a single callback/send timeout; a genuinely stalled
  outstanding operation can fail. Close and service drain remain finite.
- [x] Add controlled tests where aggregate output duration exceeds a short
  callback/send timeout while every chunk completes within its operation bound.
  Separately prove a nonreturning handler and a stalled operation fail, and
  stale timers cannot kill the completed-callback/new-lifetime owner. Callback
  completion, including terminate/exception paths, now passes **22 tests, 0
  failures** after the preserved armed-timer **22-test/2-failure** RED.
- [ ] Complete H1/H2/H3 persistence qualification. **Partial:** H1 and H3 scoped
  qualification pass, including H3's released supported idle configuration,
  dependency updates and finite peer keepalive. H2 owner persistence remains
  blocked by hell#2. No dependency patch, private-state workaround or enormous
  duration is an infinity implementation.

## Task 4: Remove adapter defaults and configure supported Phoenix persistence

**Files:**
- Modify: `vendor/websock_adapter/lib/websock_adapter.ex`.
- Modify: `vendor/websock_adapter/test/gaoxy_dispatch_test.exs`.
- Modify together: `vendor/websock_adapter/gaoxy.patch`,
  `vendor/websock_adapter/SOURCE.json`, `vendor/websock_adapter/GAOXY.md`.
- Modify: `examples/phoenix_native/lib/phoenix_native/endpoint.ex` and dedicated
  default-capacity test endpoint declarations.
- Modify: `examples/phoenix_native/README.md` and current option documentation.
- Extend: native/Phoenix configured-limit and compatibility regressions.

- [x] Skip injected `max_frame_size: 10_000_000` only for Gaoxy dispatch, preserving
  omission and explicit application values, and preserving other adapter backends:

```elixir
opts =
  if adapter == Gaoxy.PlugAdapter,
    do: opts,
    else: Keyword.put_new(opts, :max_frame_size, 10_000_000)
```

- [x] Regenerate the canonical vendor patch and snapshot hashes and prove
  reconstruction from the documented upstream snapshot. Run the isolated
  dispatch command in `GAOXY.md`; never edit fetched `deps/`.
- [x] Use Phoenix's public socket configuration for persistent integration:

```elixir
socket("/socket", PhoenixNative.UserSocket,
  websocket: [timeout: :infinity],
  longpoll: false
)
```

Apply `timeout: :infinity` to the `/live` declaration while preserving its
session `connect_info`. Add it to dedicated persistent test declarations too.
Phoenix 1.8.16 injects finite timeout before the supported upgrade boundary;
its generated `__sockets__/0` is hidden metadata. Do not read it to infer intent,
remove values by comparing with 60_000, or describe this explicit integration
setting as zero-configuration support for all existing Phoenix applications.
A deliberately finite application declaration remains a separate opt-in policy.

- [x] Preserve Phoenix heartbeat/authentication/close behavior. Do not add WS
  frame/message/service budget overrides to make the default-capacity fixture
  pass. Update inherited-limit tests to the new transport/accounting contract
  while preserving historical evidence and explicit application rejection cases.

## Task 5: Fresh acceptance and documentation

**Tests and inventory:**
- New files above, each classified in the sole app manifest.
- Existing `apps/gaoxy_http/test/websocket_configured_limits_test.exs`,
  `websocket_application_options_test.exs`, `websocket_stream_test.exs`,
  `websocket_configured_limits_network_test.exs`, `http2_websocket_network_test.exs`.
- Existing `apps/gaoxy_http3/test/websocket_network_test.exs` after its gate.
- Existing `examples/phoenix_native/test/websocket_configured_limits_test.exs`,
  `websocket_phoenix_compatibility_test.exs`, plus the new default-capacity file.

- [x] Require exact complete bytes for 300 KiB and 2 MiB native input/output,
  adapter payload above 10,000,000 bytes and H3 payload above its old 4 MiB
  threshold when H3 is qualified. LiveView initial render and heartbeat must pass.
- [x] Prove 129 legal wire fragments work without a default fragment ceiling.
  Multiple valid callback messages and work turns cannot create a batch-byte or
  default frame-count cutoff. Keep mandatory RFC/control-frame assertions.
- [x] Reuse small finite staging/credits over many bounded ordinary transfers so
  cumulative bytes substantially exceed capacity. Observe capacity remaining
  bounded, credit replenishment, ping/pong and normal close. Prove category
  isolation in controlled fixtures instead of allocating >256 MiB as a stress
  substitute. A tested size is evidence, not proof of physical infinite capacity.
- [ ] Verify no default inactivity/lifetime timers at all relevant owners;
  finite application policy, real disconnect and finite drain still terminate.
  H2/H3 siblings and a subsequent ordinary request remain healthy after cleanup.
  **Partial:** scoped implemented-path lifecycle checks pass. H3 restores finite
  ordinary idle; H2 cannot complete this requirement before hell#2 is resolved.
- [x] Measure retained messages/output/state and terminal restoration without
  enforcing a generic size ceiling. Preserve whole-message memory exposure:
  O(message + state + pending output), not O(staging) for total process memory.
- [x] Obtain independent specification/code/ownership review; fix findings, then
  run fresh required gates for the implemented scope. Independent reviews of
  framing, accounting, adapter and H2/H3 ownership paths report no remaining
  findings; H3 upstream and actual-peer gates pass. H2 remains BLOCKED by hell#2,
  despite passing final canonical gates and full Phoenix execution. Size-only
  acceptance is not complete product acceptance.

Root verification commands after implementation and pinned peer preparation:

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

Run the nonempty Phoenix fixture gate from its directory and the isolated vendor
checks independently. Units open no sockets; Linux E2E owns component/protocol/
real clients; portable smoke remains native start, health 200/ok and stop. No
browser gates. Record source, commands, exact positive counts, exits and review.
Do not count excluded/skipped required cases or rerun unchanged green gates
without a new concern. Preserve unrelated failures and specialist dispositions.

- [x] Update README/package docs, fixture docs and acceptance with
  persistent ownership, explicit application policy, the Phoenix integration
  setting, finite reusable buffers, observed memory and upstream gates.
  No project CHANGELOG exists; the acceptance record documents this unpublished
  change. Preserve the vendored upstream changelog as historical content.
- [x] Keep general HTTP timeout/body work in a separate design. Do not incidentally
  change 32 KiB headers, 8 MiB body policy, general H3 request lifetime or proxy
  pools/protocol capabilities while implementing this WS contract.
- [ ] Any later release uses current authorization and exact-source publication,
  clean consumers and artifact read-back. This research task starts no release.
  Report #16's actual size acceptance separately; close matching issues only
  after their requested behavior and downstream evidence are established.
  **INCOMPLETE:** no release or #16 closure while H2 persistence and complete
  contract acceptance remain incomplete.

No deployment, production data/certificates, Vault/public-management change or
enabling of the released-server E2E gate is included.
