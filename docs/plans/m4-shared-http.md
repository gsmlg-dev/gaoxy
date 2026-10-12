# M4 shared HTTP/3 integration implementation plan

> For agentic workers: use subagent-driven-development or executing-plans with
> independent specification and code review. This supplements Task 3/G2 of
> `m4-http3.md`; execute runtime changes only after G1 passes its prescribed gates.

**Goal:** serve the existing endpoint/Plug facade over H3 with bounded streaming
and confirmed worker, ETS, Admission and resource cleanup.

**Architecture:** [shared integration design](../designs/m4-shared-http.md).
Connection alone owns QUIC operations; one ETS slot carries each endpoint task's
operation; existing Admission enforces the original request deadline. A shared
framed response implementation preserves H2/H3 response semantics.

**Stack:** locked Elixir 1.18.5 / OTP 28, HTTP/QUIC cohort 0.21.3, aioquic 1.2.0.

All commands run in the worktree through `nix develop` with `MIX_ENV=test` and
`ERL_FLAGS='+S 2:2'`. Use `scripts/check-tests.py` to reject zero executed tests.
Retain red/failure logs and cumulative repair counters. Serialize Mix and live
peer execution. Root owns local commits; no publication or deployment.

## 1. Bounded endpoint operation slots — root

Create `apps/gaoxy_http3/lib/gaoxy/http/http3/operations.ex` and
`apps/gaoxy_http3/test/operations_test.exs`.

- [x] Write a missing-module red regression for registration, valid worker
  submission, exactly one claim, reply acknowledgement and row removal. The
  task uses a dispatched barrier; the owner never relies on sleeping for readiness.
  Use this interface, with every request retaining its original absolute D:

  ```elixir
  table = Operations.new()
  key = make_ref()
  token = make_ref()
  deadline = Gaoxy.Lifecycle.deadline(500)
  :ok = Operations.register(table, key, token, deadline)
  # The supervised task initially waits on a token-bound start barrier:
  :ok = Operations.bind(table, key, token, worker)
  send(worker, {:h3_start, self(), key, token})
  # In the admitted worker:
  :ok = Operations.ready(table, key, token, lease)
  # The owner verifies readiness, activates and dispatches that worker:
  :ok = Operations.activate(table, key, token, worker)
  # The worker submits, owner claims once, then replies:
  {:ok, ref} = Operations.submit(table, key, token, {{:data, "piece", false}, deadline})
  {:ok, ^worker, ^ref, {:data, "piece", false}, ^deadline} =
    Operations.claim(table, key, token)
  :ok = Operations.reply(table, key, token, ref, :ok)
  # Worker acknowledges only that completed reference before another operation:
  :ok = Operations.ack(table, key, token, ref)
  ```

- [x] Test another worker/stale token, a second operation while occupied, duplicate
  claim/reply, expired D, cancellation before/after claim, late reply after timeout,
  bounded DATA/header operations, and deleted-table/owner loss. Include readiness
  before binding, a mismatched returned PID and failed task start. Timeout retains
  a terminal reference for caller expiry or uncertain destructive outcomes and
  never makes that request's slot reusable for output. Distinguish this from an
  owner-confirmed no-progress read/poll `:pending`: completed/acknowledged slots
  may be reused. A read reply race retains consumed bytes in the owner ingress
  state or terminates the request visibly, never returns retryable `:pending`
  while losing data. Add repeated pending/read/output and expiry-race regressions.
- [x] Implement an unnamed ETS set with token/PID/state compare-and-replace and
  one row per owner-registered request. No per-operation process/timer, GenServer
  call to the callback owner or unbounded body message to that owner.
- [x] Run `python scripts/check-tests.py apps/gaoxy_http3/test/operations_test.exs`;
  record expected red and nonzero green evidence under `evidence/m4/shared/slots/`.

## 2. Shared response seam and Transport — root

Create `apps/gaoxy_http/lib/gaoxy/http/framed_response.ex`,
`apps/gaoxy_http3/lib/gaoxy/http/http3/{response,transport}.ex` and
`apps/gaoxy_http3/test/transport_test.exs`. Modify only the existing
`apps/gaoxy_http/lib/gaoxy/http/http2/response.ex` compatibility wrapper.

- [x] Write red facade cases using a real slot owner/Admission fixture: complete
  response, streamed fixed/chunked response, trailers, informational HEADERS,
  file range, HEAD/204/205/304, invalid fixed length and owner/operation timeout.
  Assert the captured semantic operations and finite Admission reservations, not
  an implementation-shaped return value alone.
- [x] Move H2 Response semantics unchanged into `FramedResponse`; call
  `exchange.transport.operation(exchange, operation)` for the owner operation.
  Keep H2 Response and H3 Response as explicit delegating wrappers, and reuse
  the existing pure header validation. Preserve H1's separate wire backend.
- [x] Implement H3 Transport's operation wait through Operations and token/ref
  replies with a monitored owner. Implement `read_body_step/3`, `poll_connection/2`,
  `body_complete?/1`, `abort/2` and the six response facade functions with current
  return shapes. Read/output memory updates use the admitted worker's lease.
  `expect_continue` sends a single informational response before the first read.
- [x] Compute fixed D_io at read/poll entry, before any Continue, as
  `min(exchange.deadline, Lifecycle.deadline(wait))` and publish `{:until, D_io}`.
  Its confirmation D_op is
  `min(exchange.deadline, D_io + exchange.limits.write_timeout)`. Output uses
  `min(exchange.deadline, Lifecycle.deadline(write_timeout))`. Preserve both
  deadlines through claim and progress, and preserve the original deadline of
  each unknown host reference. Verify
  owner-confirmed read/poll no-progress is `:pending`, caller/output expiry is
  terminal timeout including a completed-but-unacknowledged reply race,
  and zero-wait probes cannot leave a destructive operation executing later.
- [x] Run `python scripts/check-tests.py apps/gaoxy_http3/test/operations_test.exs
  apps/gaoxy_http3/test/transport_test.exs apps/gaoxy_http/test/http_contract_test.exs
  apps/gaoxy_http/test/native_proxy_seams_test.exs
  apps/gaoxy_http/test/http2_facade_test.exs
  apps/gaoxy_http/test/http2_network_test.exs`. Keep H2 native-response evidence in
  scope because its response implementation is extracted.

## 3. Endpoint task and callback integration — Sol connection worker

Create `apps/gaoxy_http3/lib/gaoxy/http/http3/stream.ex` and
`apps/gaoxy_http3/test/{plug,lifecycle_race}_test.exs`; modify Connection and its
scoped tests. Preserve the qualified minimal fixture profile while integrating
production endpoint execution.

- [x] Write an initial red real H3 Plug request before implementing production
  dispatch. The public service accepts the unchanged endpoint or Plug tuple;
  arbitrary endpoint code must execute in the admitted task, never the callback.
- [x] Owner registers the slot and starts a task under `Gaoxy.HTTP.Tasks`.
  Stream immediately monitors the owner and waits for a token-bound start
  barrier; the owner binds exactly the returned task PID before releasing that
  barrier. A failed start deletes the row. Do not link the worker to its owner.
  Stream verifies the bound identity, acquires its own Admission lease, arms
  `Admission.begin_request(gate, lease, reserve, D)`, then publishes readiness.
  The owner verifies readiness and dispatches a correctly initialized Exchange.
  Task completion/failure goes through ETS; owner polls identity/liveness.
- [x] Construct the H3 Exchange using the parser's Request and real public
  metadata. Feed bounded ingress DATA and ordered trailers to credited reads;
  keep original header/request/output deadlines and control progress. Claimed
  output completes only after its whole bounded frame and terminal FIN are
  definitely admitted. Unknown operations retain refs and fence destructive I/O.
- [x] Test failed task start, worker crash, cooperative owner death, peer reset,
  cancellation before/after claim, stale token and late response. Remove owned
  rows/workers without releasing unresolved output for retry or harming siblings.
- [x] Add the deterministic busy-Plug test with a monitored resource provider.
  Plug sends `{:plug_busy, worker, ref}` after dispatch and waits for a release
  token that the test never sends; it has no DOWN clause. Kill only the callback
  owner after this barrier. Keep Admission alive. By original D plus
  `Gaoxy.Lifecycle.cleanup_headroom()` assert observed worker DOWN, deleted ETS,
  released request lease/bytes and released monitored resource pins. Observe
  another connection and another listener completing requests within the bound.
  Missing receipt is a failure with `termination_unconfirmed`, never a PASS.
- [x] Run `python scripts/check-tests.py apps/gaoxy_http3/test/connection_test.exs
  apps/gaoxy_http3/test/lifecycle_test.exs apps/gaoxy_http3/test/plug_test.exs
  apps/gaoxy_http3/test/lifecycle_race_test.exs`. Root grants the serialized Mix lease.

## 4. Independent shared network gate — peer worker

Modify only `integration/http3/{fixture.exs,peer.py,run.py,README.md}` and create
new immutable evidence under `docs/acceptance/evidence/m4/shared/`.

- [x] Add `--gate shared` using the production endpoint/Plug mapping. Before
  implementation, record its intended nonzero failure on an ordinary H3 request.
- [x] Independently decode GET/HEAD, streamed POST and response, ordered request
  and response trailers, file ranges, informational/100-continue, 204/304,
  early response with unread body, simultaneous unrelated streams and cancellation.
  Preserve G1's exact error/scope/sibling/no-late-DATA contract.
- [x] Use a slow/tiny-window peer to require definitely blocked output followed
  by exact eventual progress; record application slots/queue byte observations
  and Admission returning to baseline separately from host/engine limits.
- [x] Execute `python integration/http3/run.py --gate shared --evidence
  docs/acceptance/evidence/m4/shared`. All hashes must be unchanged throughout the
  run; owned processes must exit and sockets/leases must have finite cleanup.

## 5. Independent review and fresh verification — root coordinates

- [x] Complete independent specification review against both M4 designs and
  Task 3, then code/evidence review. Resolve actionable findings with unchanged
  assertions and preserved failure evidence.
- [x] Repeat affected scoped suites and shared network gate after review. Format
  only authored changed Elixir files and compile with `--warnings-as-errors`.
  Do not normalize historical `.log`/`.diff` evidence whitespace.
- [x] Update acceptance/status and checklist with actual counts, source identity,
  exits, PASS/FAIL/BLOCKED/NOT RUN, cleanup observations and cumulative counters.
  Commit only explicitly owned completed paths locally.
- [ ] Continue Task 4 and the separately designed required upstream-H3/standalone
  slices automatically. G2 is not full M4 acceptance.

**G2 verified, 2026-10-12:** post-review scoped H3 111/0 plus H1/H2 compatibility
50/0, exact-file format and strict compile passed. Shared live gate executed
59/59 PASS with unchanged source hashes and all six owned children exit0.
Independent source/runtime reviews resolve all findings; failed runs remain
immutable. See the [execution record](../acceptance/m4.md). G2 is not full M4.
