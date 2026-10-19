# M5 WebSocket over HTTP/2 and HTTP/3 implementation plan

> **For agentic workers:** Use `subagent-driven-development` (recommended) or
> `executing-plans` task by task, with independent specification and code review.

**Status, 2026-10-19: IN PROGRESS; execution authorized after plan review.**
The user requested implementation of this reviewed plan. Work is isolated on
`codex/m5-websocket-over-h2-h3`, starting at `4c6f089`. Gate results are recorded in
[M5 acceptance](../acceptance/m5-websocket-over-h2-h3.md); unexecuted gates remain
NOT RUN. This authorization adds no publication/deployment permission.

**Goal:** Support native Phoenix/WebSock connections over HTTP/2 (RFC 8441) and
HTTP/3 (RFC 9220), while preserving HTTP/1.1 WebSocket behavior.

**Architecture:** [M5 design](../designs/m5-websocket-over-h2-h3.md). Reuse the
existing WebSocket parser and callback engine. An existing H2/H3 request worker
continues as its WebSocket stream runtime; the existing connection owner retains
all transport I/O and flow-control authority. Extended CONNECT is explicitly
enabled per listener only after that transport's implementation gate passes.

**Tech stack:** Elixir 1.18 / OTP 28 in the locked Nix environment, Plug 1.20.3,
WebSock 0.5.3, the reviewed vendored WebSockAdapter, locked QUIC/HTTP cohort
0.21.10, independent Python h2/aioquic/wsproto peers and Chromium/Playwright.

## Scope, baseline and execution rules

The inspected source baseline is local `main@43363c2be851de4b2c999232f9116993bf20647a`.
M5 is a newly proposed milestone following M0–M4; it does not retroactively define
M6–M8 or change the accepted M3 disposition. The published v0.3.0 artifact has a
different source identity and is not evidence for this implementation.

Included: server-side extended CONNECT negotiation, ordinary WebSocket frames,
WebSock callbacks including unsolicited application messages, per-stream
admission/lifetime, native Plug/Phoenix integration, normal independent-peer and
browser acceptance, and H1 compatibility. Outbound WebSocket proxy transports
over H2/H3, compression, generic CONNECT tunnels, WebTransport/DATAGRAM and other
unimplemented H3 features are outside this stage, as is standalone JSON
activation of WebSocket endpoints. Existing H1 proxy behavior is
preserved. No private dependency actors or changes under `deps/` are permitted.

Normal protocol validation belongs in deterministic unit tests; network gates
exercise valid handshakes, normal messages and orderly Close/END_STREAM/FIN.
Fault-injected disconnects, malformed-network campaigns, slow peers, blocked
writes, overload, sustained load and combined stress profiles remain assigned to
a dedicated specialist environment. They are not M5 completion gates here.
Preserve old assertions and FAIL/BLOCKED/NOT RUN evidence; do not resume the
excluded H1 disconnect slice or recreate HTTP Fetch issue 97 requirements.

Use a new worktree at execution time:

```sh
git worktree add -b codex/m5-websocket-over-h2-h3 .trees/m5-websocket-over-h2-h3 main
```

Record the actual execution HEAD, dirty diff digest and lock hashes before each
gate. Do not reuse a build or dependency directory from a different cohort
without verifying it. Root `mix.lock` selects 0.21.10, whereas the current Phoenix
fixture lock still selects 0.21.4. Resolve that known fixture mismatch in Task 0;
do not treat historical fixture success as a new-cohort run.

All commands below run at the execution worktree root unless stated otherwise.
Use `nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2'` before the shown
Python/Mix commands. `scripts/check-tests.py` requires nonzero executed tests.
New file paths and APIs below are proposed implementation work, not existing
capabilities. Run only the named stage suites and justified compatibility checks.
Do not fix unrelated failures. Keep cumulative Sol/Astra repair counters in the
execution record; architecture work is not an Astra recovery round and does not
reset the exhausted historical recovery allowance.

## Protocol defaults included in M5

Current runtime defaults are H1. M5 changes the embedded HTTP/Phoenix HTTPS
default to `protocols: [:http2, :http1]`, ordered ALPN `h2`, `http/1.1`, with H1
negotiation/no-ALPN fallback and explicit H1-only configuration retained. Plain
HTTP stays H1 by default; explicit `protocols: [:http2], h2c: :prior_knowledge`
selects the existing h2c mode. No H1 Upgrade or mixed-cleartext detection is added.
H3 remains an optional separate service. Upstream protocol selections and
standalone JSON's explicit H1 selection are unchanged. Protocol preference does
not enable `extended_connect`, which retains its separate listener opt-in.

Make the default decision in the transport-aware HTTP facade, with Phoenix
delegating omitted protocols. For HTTP services selecting H2, use 256 MiB
`limits.max_bytes` only when omitted; current default H2 reservations need
173,302,823 bytes. Preserve explicit budgets, core/H1 defaults, all reservation
and host/security checks, and rejection when the selected budget is insufficient.
Task 2 owns this bounded compatibility change and its ordinary verification.
Its configuration-only subtask 2a depends on G0 and can proceed alongside Task 1:
it touches no shared WebSocket runtime files. The extended-CONNECT subtask 2b
still waits for G1. Serialize root build commands and hold G2 acceptance until
both subtasks and their required peer/review gates pass.

## Tasks and dependency order

| Task | Deliverable | Depends on | Parallel work |
| --- | --- | --- | --- |
| 0 | Dependency/fixture and peer compatibility audit | Accepted design | Peer scaffolding can accompany the audit |
| 1 | Shared handshake and WebSocket stream contract | 0 | Pure peer vectors can be prepared separately |
| 2a | HTTPS H2 defaults and explicit h2c compatibility | 0 | Separate HTTP/Phoenix configuration files alongside Task 1 |
| 2b | Native H2 WebSocket | 1 and 2a | Independent H2 peer writer owns only integration files |
| 3 | Native H3 WebSocket | 1; review the shared contract after 2 | Pure H3 fields/settings may be prepared during 2 |
| 4 | Phoenix/WebSock integration and browser proof | 2 for H2, 3 for H3 | H2 browser work can precede H3 completion |
| 5 | Final compatibility, review and capability documentation | 2–4 | Independent specification and code reviewers |

Serialize edits to shared WebSocket, Request, Exchange and Plug adapter files.
Give each writer explicit file ownership; never revert another writer's edits.
Complete H2 end to end before reusing its accepted stream contract for H3.

## Task 0 — establish the source and public API cohort

**Owner:** Sol dependency/fixture investigator; no production transport changes.

**Files:**

- Inspect `mix.lock`, `apps/gaoxy_http/mix.exs`, `apps/gaoxy_http3/mix.exs`,
  `vendor/websock_adapter/{mix.exs,GAOXY.md,SOURCE.json}` and the selected installed
  public QUIC/H3 APIs.
- Modify `examples/phoenix_native/mix.lock` only for necessary alignment.
- Create `integration/websocket_multiplexed/{requirements.txt,README.md}` and
  `docs/acceptance/m5-websocket-over-h2-h3.md`.

- [x] Record actual source/lock identity, runtime versions and clean worktree
  status, preserving unrelated user files.
- [x] Verify the public H3 Settings/Control APIs encode and accept setting 8
  with values 0/1; verify the public host supplies stream DATA and FIN operations.
  Existing support is not inferred from the package version alone.
- [x] Align only the necessary Phoenix fixture QUIC/HTTP lock entries with
  0.21.10, selecting `PHOENIX_NATIVE_H3=1` during dependency resolution. Record
  every changed lock entry; then run locked dependency resolution and strict
  compilation for root and fixture. No broad dependency refresh.
- [x] Pin the independent peers initially to `h2==4.3.0`, `hpack==4.1.0`,
  `hyperframe==6.1.0`, `aioquic==1.2.0`, `wsproto==1.2.0` and
  `playwright==1.56.0`. Verify these versions expose the public extended CONNECT
  and frame APIs needed by the fixtures before adopting them.
- [x] Prepare a task-local Python environment; the inspected reusable venv has
  h2 but lacks aioquic, Playwright, websockets and wsproto. Record the resolved
  environment instead of assuming historical tools are still installed.
- [x] Record the selected Chromium executable/version and supported configuration
  for H2/H3 WebSocket negotiation. This is an environment/API audit; actual
  negotiation against the new Gaoxy implementation belongs to G4. Missing
  browser support is BLOCKED_ENV for that row, not a Gaoxy failure or success.
- [x] Audit the vendored WebSockAdapter: H2 validation exists, H3 version
  validation does not. Its upstream is `phoenixframework/websock_adapter`.
  Plan the explicit reviewed vendor change in Task 4; never set
  `early_validate_upgrade: false` as the integration solution.
- [x] Record that `HTTP.WebSocket` browser-mode H2 support is separate from its
  H1-only acknowledged proxy contract; neither that client nor an invented H3
  client is required to implement native downstream server streams.
- [x] For an actual required dependency defect, follow AGENTS.md provenance,
  issue/type/label/callsite routing. Stop only the affected blocked task; do not
  invent a dependency blocker from a feature Gaoxy itself owns.

Existing scoped baseline command:

```sh
python scripts/check-tests.py apps/gaoxy_http/test/websocket_frame_test.exs apps/gaoxy_http/test/websocket_handshake_test.exs apps/gaoxy_http/test/phoenix_adapter_test.exs apps/gaoxy_http/test/http3_upgrade_test.exs apps/gaoxy_http3/test/options_test.exs apps/gaoxy_http3/test/headers_test.exs
```

**G0 exit:** selected dependencies/public peer APIs are recorded, both source
consumers compile, and the ordinary baseline executes nonzero tests without
failures. All commands/results remain NOT RUN in this planning document.

## Task 1 — shared extended handshake and stream runtime contract

**Owner:** Sol shared WebSocket writer.

**Files:**

- Modify `apps/gaoxy_http/lib/gaoxy/http/{request,exchange,websocket}.ex`.
- Create `apps/gaoxy_http/lib/gaoxy/http/websocket/{extended_handshake,stream}.ex`.
- Reuse `apps/gaoxy_http/lib/gaoxy/http/websocket/{frame,message,handshake}.ex`;
  keep H1 handshake behavior intact.
- Create `apps/gaoxy_http/test/{websocket_extended_handshake,websocket_stream}_test.exs`.

- [x] Add `Request.protocol` as `nil | binary`; retain the actual wire method
  `CONNECT`. Mark a validated extended CONNECT payload as `body: :tunnel`.
  Arbitrary `:protocol` values do not become atoms or generic outbound tunnels.
- [x] Write the new pure handshake tests first. Require `websocket`, the
  appropriate scheme/authority/path, version 13, valid offered subprotocol and
  ordinary response headers. A successful response is 200 without H1 upgrade
  headers or Sec-WebSocket-Accept; ordinary H1 tests retain their 101 semantics.
- [x] Keep masking, UTF-8, fragmentation and ping/pong rules in the existing
  Frame/Message engine. Reuse WebSock callback and option validation, including
  its explicit no-compression contract.
- [x] Introduce `WebSocket.Stream.run/2` in the existing request worker PID.
  That worker receives stream DATA and application/PubSub messages; it does not
  become the connection socket owner or create a duplicate global scheduler.
- [x] Add transport-neutral `WebSocket.data/2` while retaining the H1 `data/3`
  entry point. Define the shared transport operations from the design:
  `websocket_open/3`, `websocket_demand/3`, `websocket_send/2` and
  `websocket_finish/1` on the H2/H3 transports.
- [x] Make one inbound demand outstanding per worker/token/ref. Reserve finite
  input/output/callback-state capacity before delivery; release or transfer each
  reservation once. Test these state transitions with deterministic local
  messages, without socket-pressure or disconnect injection.
- [x] Specify the lifetime transition: the admitted WS absolute deadline
  replaces the HTTP request deadline exactly once in worker, connection owner,
  admission lease and H3 operation state. Per-write/callback/close deadlines
  remain finite. Owner authorization happens before emitting 200.
- [x] Unit-test the transition across the original request deadline with a
  deterministic clock/state boundary; active WS operations use the admitted WS
  deadline. Do not add a slow-peer or long-running network workload to prove it.
- [x] Ensure a long-lived stream is not constrained by cumulative ordinary
  HTTP request-body bytes. Ingress bounds still limit buffered WS data; frame,
  message and lifetime limits continue to apply. Preserve ordinary body readers.

Representative new test contract:

```elixir
request = %Gaoxy.HTTP.Request{
  method: "CONNECT", version: :"HTTP/2", protocol: "websocket",
  scheme: :https, host: "example.test", port: 443,
  target: "/socket?vsn=2.0.0", target_form: :origin,
  path: "/socket", query_string: "vsn=2.0.0", body: :tunnel,
  headers: [{"sec-websocket-version", "13"}, {"sec-websocket-protocol", "chat"}]
}
assert {:ok, [{"sec-websocket-protocol", "chat"}]} =
  Gaoxy.HTTP.WebSocket.ExtendedHandshake.headers(request, [{"sec-websocket-protocol", "chat"}])
```

Run the new tests first to record their intended RED, then implement and run:

```sh
python scripts/check-tests.py apps/gaoxy_http/test/websocket_extended_handshake_test.exs apps/gaoxy_http/test/websocket_stream_test.exs apps/gaoxy_http/test/websocket_frame_test.exs apps/gaoxy_http/test/websocket_handshake_test.exs
```

**G1 exit:** shared behavior passes scoped tests and independent review. Actual
H2/H3 acceptance is still NOT RUN. Do not advertise setting 8 in this task.

## Task 2 — H2 defaults, extended CONNECT and normal peer acceptance

**Owner:** Sol H2 writer; separate peer writer owns only the new H2 fixture files.

**Files:**

- Modify `apps/gaoxy_http/lib/gaoxy/http.ex`,
  `apps/gaoxy_http/lib/gaoxy/phoenix_adapter.ex` and
  `apps/gaoxy_http/lib/gaoxy/http/{options,plug_endpoint}.ex`.
- Modify `apps/gaoxy_http/lib/gaoxy/plug_adapter.ex` and
  `apps/gaoxy_http/lib/gaoxy/http/http2/{headers,settings,connection,stream,transport,writer}.ex`.
- Create `apps/gaoxy_http/test/{http2_websocket,http2_websocket_network}_test.exs`.
- Create `apps/gaoxy_http/test/http_protocol_defaults_test.exs` for configuration
  and ordinary real-network default negotiation; modify only the existing ALPN
  contract in `http_contract_test.exs` and budget contract in
  `http2_network_test.exs` as described below.
- Update `apps/gaoxy_http/test/{http2_protocol,http3_upgrade}_test.exs` only for
  explicitly changed contracts, retaining refusal for disabled/invalid upgrades.
- Create `integration/websocket_multiplexed/{fixture.exs,h2_peer.py,run.py}`.

- [x] Choose omitted HTTPS protocols as `[:http2, :http1]` in `Gaoxy.HTTP` using
  transport context; keep plain HTTP's H1 default. Have Phoenix forward explicit
  protocol choices and delegate omission to the facade. Retain strict ALPN
  consistency, explicit H1/H2 selections and prior-knowledge h2c validation.
- [x] Default omitted `limits.max_bytes` to 268,435,456 only for services selecting
  H2 through the HTTP facade. Preserve all supplied limit fields, explicit low
  budgets and validation of custom reservations. Do not change core defaults,
  reservation formulas, TLS version/security or H2 host requirements.
- [x] Record new default behavior in focused tests: bare HTTPS/Phoenix HTTPS
  configuration starts, ordered ALPN prefers H2, H1-only and no-ALPN clients
  receive H1, explicit H1 override works, and explicit h2c serves ordinary H2.
  Verify omitted H2 budgets and preservation of explicit budgets with pure
  configuration cases. No pressure or fault-injected network cases are added.
- [x] Preserve existing rejection assertions by making their preconditions
  explicit: add `protocols: [:http1]` to the H1-only ALPN contract and an explicit
  1 MiB limit to the insufficient-H2-budget contract. Execute those named cases
  individually; do not run the mixed `http2_network_test.exs` file wholesale.
- [x] Add strict boolean `extended_connect: false` to service normalization and
  Phoenix HTTP/HTTPS option forwarding. H1 behavior remains available; setting
  8 is emitted as 1 only on an H2 connection explicitly enabled for this feature.
- [x] Validate setting 8 values and retain RFC 8441's server/client direction
  semantics. Accept valid extended CONNECT fields only under local activation.
  Preserve ordinary CONNECT handling and ordinary HTTP request parsing.
- [x] Route a valid WebSocket CONNECT to its local endpoint, never dial its
  authority. Well-formed unsupported extended protocols get 501. Wire methods,
  origin/session headers and request targets remain available for policy.
- [x] Map the upgrade marker to a 200 HEADERS without END_STREAM. Continue the
  same stream worker in `WebSocket.Stream.run/2`; do not run ordinary
  `Response.finish/1` or send `h2_stream_done` while the WebSocket is live.
- [x] Carry RFC 6455 bytes inside H2 DATA independently of DATA boundaries.
  Keep H2 window accounting/connection ownership in the existing owner and
  writer. Apply the shared demand and finite write contract.
- [x] Complete normal WebSocket Close exchange, then END_STREAM, and ordinary
  stream/lease release while an unrelated HTTP request on the same connection
  succeeds. Define reset cleanup in code/unit contracts without adding a
  fault-injected network reset gate.
- [x] Add a direct ordinary Plug/WebSock path before enabling Phoenix browser
  acceptance; remove the unconditional Plug H2 refusal only for this validated
  enabled path. Invalid and disabled upgrades keep explicit rejection.
- [x] Peer cases: TLS/H2 and prior-knowledge h2c negotiation, 200 handshake,
  text/binary messages, split DATA boundaries, ping/pong, selected subprotocol,
  server-initiated message while idle, orderly Close, and HTTP sibling service.
- [x] Require two simultaneous WebSocket streams plus an ordinary HTTP sibling
  on one connection, with stream-labelled messages, independent application
  pushes and orderly closure. This is normal multiplexing, without cancellation
  injection, deliberate exhausted credit or a concurrency/load ramp.
- [x] Include one bounded normal lifetime case per H2/h2c profile: fixture HTTP
  request timeout 1 second, WS lifetime 10 seconds, total case deadline 5 seconds.
  After the original request deadline passes, exchange a normal message/pong,
  then Close normally. The fixture records the original and upgraded deadlines;
  no slow-consumption, artificial write block or sustained traffic is involved.
- [x] The new runner enumerates required case names for each selected protocol,
  fails on zero executed or missing cases, and writes command/source/cohort,
  negotiated protocol, each case result and exit to its evidence directory.

```sh
python scripts/check-tests.py apps/gaoxy_http/test/http_protocol_defaults_test.exs apps/gaoxy_http/test/phoenix_adapter_test.exs
python scripts/check-tests.py apps/gaoxy_http/test/http_contract_test.exs:215 apps/gaoxy_http/test/http2_network_test.exs:330
python scripts/check-tests.py apps/gaoxy_http/test/http2_websocket_test.exs apps/gaoxy_http/test/http2_websocket_network_test.exs apps/gaoxy_http/test/http2_protocol_test.exs apps/gaoxy_http/test/http3_upgrade_test.exs
python integration/websocket_multiplexed/run.py --protocol h2 --evidence .audit/m5/h2
python integration/websocket_multiplexed/run.py --protocol h2c --evidence .audit/m5/h2c
```

Reconfirm line selectors against the named tests before execution if edits move
their lines. The existing cases are "HTTP-only TLS rejects advertisement of an
unimplemented protocol" and "prior knowledge is explicit and rejects the
insufficient core byte budget"; update their descriptions to match the explicit
preconditions while retaining the rejection assertions.

**G2 exit:** default HTTPS H2 negotiation, H1 compatibility, budget contracts,
H2/h2c independent peer rows and scoped tests pass. Actual enabled and disabled
behavior is documented, and independent specification/code review passes.
Commit only the completed owned slice locally.

## Task 3 — HTTP/3 extended CONNECT and normal peer acceptance

**Owner:** Sol H3 writer; separate peer writer owns only `h3_peer.py`.

**Files:**

- Modify `apps/gaoxy_http3/lib/gaoxy/http/http3/{options,protocol,headers,connection,operations,stream,transport,response}.ex`.
- Create `apps/gaoxy_http3/test/{websocket,websocket_network}_test.exs`.
- Update `apps/gaoxy_http3/test/{options,headers,protocol,operations}_test.exs`
  for the deliberate new enabled path and retained disabled contracts.
- Create `integration/websocket_multiplexed/h3_peer.py`; extend its existing
  `fixture.exs` and `run.py` with H3 selection.

- [x] Thread the same strict `extended_connect` activation through H3 options.
  Include H3 setting 0x08=1 in the public server Control settings only when
  enabled. Keep the existing zero-capacity QPACK and optional package boundary.
- [x] Accept `:protocol=websocket` with required extended CONNECT fields and
  preserve HTTP/3 request metadata. Separate WS DATA accounting from ordinary
  request-body totals/content-length and HTTP response-finalization rules.
- [x] Commit 200 HEADERS without FIN, then continue the same admitted worker
  using the shared runtime. Reserve/confirm all QUIC operations through the
  existing public host and Operations contract, with no private Session actor.
- [x] Update Operations and owner stream state to the admitted WS deadline in
  the same authorized transition. Old HTTP expiry/finish paths must not end a
  live WebSocket or leave stale operation state.
- [x] Carry RFC 6455 bytes inside H3 DATA, preserving per-stream fair progress
  and the existing finite operation chunks. No retry/replay of uncertain writes.
- [x] For orderly shutdown, send/receive WS Close before stream FIN and release
  the stream normally. Define reset/stop mapping to H3_REQUEST_CANCELLED in
  deterministic unit contracts; network fault injection remains deferred.
- [x] Run the H3 equivalents of G2's ordinary peer cases, with a verified local
  certificate: two live WebSocket streams and an HTTP sibling on the same QUIC
  connection, including the bounded post-request-deadline lifetime case.
  Do not import a client H3 session as a server implementation.

```sh
python scripts/check-tests.py apps/gaoxy_http3/test/websocket_test.exs apps/gaoxy_http3/test/websocket_network_test.exs apps/gaoxy_http3/test/headers_test.exs apps/gaoxy_http3/test/protocol_test.exs apps/gaoxy_http3/test/operations_test.exs
python integration/websocket_multiplexed/run.py --protocol h3 --evidence .audit/m5/h3
```

**G3 exit:** independent H3 WebSocket rows and affected tests pass with independent
review. H3 WebSocket browser/Phoenix acceptance remains a separate gate.

## Task 4 — native Phoenix, vendor compatibility and browser routing

**Owner:** Sol Phoenix writer. Start H2 work after G2; H3 rows require G3.

**Files:**

- Modify `vendor/websock_adapter/lib/websock_adapter/upgrade_validation.ex`,
  `vendor/websock_adapter/test/gaoxy_dispatch_test.exs`, and
  `vendor/websock_adapter/{GAOXY.md,SOURCE.json,gaoxy.patch}` as one reviewed
  provenance change; retain its upstream snapshot identity and license.
- Modify `apps/gaoxy_http/lib/gaoxy/http/plug_endpoint.ex` only for the necessary
  shared upgrade handoff and preservation of its duplicate-listener guard through
  the explicit Phoenix wrapper; create
  `apps/gaoxy_http/lib/gaoxy/phoenix_websocket.ex` for the Phoenix-only method
  compatibility wrapper and extend `apps/gaoxy_http/lib/gaoxy/phoenix_adapter.ex`
  for its explicit Endpoint configuration.
- Modify `examples/phoenix_native/config/config.exs`,
  `examples/phoenix_native/h3_gateway.exs`,
  `examples/phoenix_native/lib/phoenix_native/endpoint.ex` and
  `examples/phoenix_native/README.md` as required for feature activation/fixtures.
- Create `integration/websocket_multiplexed/browser.py`; extend its fixture and
  README. Add `apps/gaoxy_http/test/phoenix_websocket_test.exs`.

- [ ] Add Endpoint-level `websocket_paths: []`, a validated list of exact
  WebSocket request paths. `Gaoxy.PhoenixWebSocket` wraps the configured Endpoint
  (including its existing code-reload wrapper) on the Phoenix adapter path.
  External H3 mounts explicitly select the same wrapper with Endpoint
  `server: false`. Example paths are `/live/websocket` and `/socket/websocket`.
- [ ] Extend external `PlugEndpoint.init({Gaoxy.PhoenixWebSocket, {endpoint,
  paths}})` initialization to apply the existing duplicate-listener check to the
  original Endpoint. The Phoenix adapter retains its current outer
  `{module, options, :endpoint_managed}` startup form; no new wrapper mode is
  needed. Test external `server: true` rejection, external `false` acceptance
  and internal managed `true` acceptance, with code reload preserved.
- [ ] For a validated enabled H2/H3 `CONNECT` with `protocol: "websocket"` at
  an allowlisted path only, present `conn.method = "GET"` while invoking the
  existing Phoenix Endpoint. Preserve `Exchange.request.method = "CONNECT"`,
  version, protocol and target throughout; restore `conn.method` on return.
  All other requests keep their actual methods. Preserve Phoenix's complete
  socket/session/Origin/CSRF/subprotocol/authentication pipeline.
- [ ] On `Gaoxy.PlugAdapter` only, make the vendored early validator read the
  preserved native request metadata for H2/H3 CONNECT validation even while
  Phoenix sees its compatible GET view. Other adapters retain their original
  validation. Avoid a compile-time dependency from the vendor back to Gaoxy,
  which would create a package cycle. The native Plug upgrade still validates
  the enabled stream/token; never disable early validation or pretend HTTP/1.
- [ ] Add focused tests for enabled allowlisted paths, unlisted paths retaining
  CONNECT, ordinary GET unchanged, returned method restored, accepted upgrade
  metadata and rejected application authentication/Origin preserving the same
  response. A configured path does not bypass Phoenix policy.
- [ ] Add H3 validation to the maintained vendor fork explicitly and regression
  test both H2 and H3 public upgrade calls. Update source hashes, exact patch,
  provenance narrative and removal instructions together. Do not describe the
  new fork as byte-identical to the old dispatch-only snapshot.
- [ ] Exercise default HTTPS H2 preference and explicitly enable extended
  CONNECT in the fixture. Select h2c explicitly where used. H3 remains a
  separately mounted service with Endpoint `server: false`; no duplicate
  Endpoint listener.
- [ ] Prove actual Phoenix Channels join/ping, a server PubSub push, LiveView
  mount/click/update and upload over each requested WS transport. Preserve an
  ordinary HTTP/1.1 browser WebSocket compatibility row.
- [ ] Correlate each browser WebSocket URL's unique marker with successful WS
  activity and server-side native HTTP version, wire CONNECT/:protocol metadata
  and stream identity. A page's CDP `h2`/`h3` response or JavaScript WebSocket
  event alone does not prove its WebSocket transport.
- [ ] Record browser feature settings and actual negotiated transport. H1
  fallback cannot pass an H2/H3 row. If the browser cannot perform that protocol,
  mark that row BLOCKED_ENV and continue independent-peer/unblocked rows.
  Do not claim full browser acceptance until a capable browser executes it.
- [ ] Use normal Close and bounded fixture shutdown; retain logs and ordinary
  screenshots. No packet-loss, abrupt-disconnect, slow-consumption or load gate.

```sh
python scripts/check-tests.py apps/gaoxy_http/test/phoenix_websocket_test.exs apps/gaoxy_http/test/phoenix_adapter_test.exs
elixir -pa _build/test/lib/plug/ebin -pa _build/test/lib/websock/ebin \
  -r vendor/websock_adapter/lib/websock_adapter/upgrade_error.ex \
  -r vendor/websock_adapter/lib/websock_adapter/upgrade_validation.ex \
  -r vendor/websock_adapter/lib/websock_adapter.ex \
  -r apps/gaoxy_http/test/test_helper.exs \
  vendor/websock_adapter/test/gaoxy_dispatch_test.exs
python integration/websocket_multiplexed/browser.py --protocol h2 --evidence .audit/m5/browser-h2
python integration/websocket_multiplexed/browser.py --protocol h3 --evidence .audit/m5/browser-h3
python integration/websocket_multiplexed/browser.py --protocol http1 --evidence .audit/m5/browser-http1
```

**G4 exit:** the native Phoenix paths and vendor regression pass; H2/H3 browser
claims have WS-specific protocol evidence. Preserve any blocked row as blocked.
The isolated vendor invocation runs after strict compilation creates the shown
Plug/WebSock beam paths. Require a nonzero ExUnit count and exit 0 in its receipt;
root application tests do not execute dependency test files automatically.

## Task 5 — fresh compatibility, documentation and independent acceptance

**Owner:** parent integrator; independent Sol reviewers do not review their own
implementation. Resolve actionable findings before the final fresh execution.

**Files:** update `docs/native-http.md`, `docs/http3.md`, `docs/capabilities.md`,
`docs/implementation-status.md`, `implement-plan.md`, this plan and
`docs/acceptance/m5-websocket-over-h2-h3.md`; keep historical records intact.

- [ ] Run all new M5 pure/normal-network suites plus the listed H1 handshake,
  frame, Phoenix configuration and altered H2/H3 contract tests. Enumerate the
  exact paths in the execution receipt; no unbounded umbrella test invocation.
- [ ] Execute the existing ordinary H1 WebSocket proxy `:proxy_policy` cases,
  the successful verified-WSS case and ordinary native H1 WebSock lifecycle
  cases using the selectors below. Do not run their mixed fault/pressure files
  wholesale. Reconfirm line selectors against the named tests at execution time;
  keep their assertions intact if preceding source lines have moved.
- [ ] Run strict compilation, exact changed-file formatting and `git diff --check`.
- [ ] Run `scripts/external-consumer.sh`, `scripts/http-consumer.sh` and
  `scripts/h3-consumer.sh` in the locked environment. Core and H1/H2 consumers
  must retain QUIC isolation; H3 must explicitly opt into the selected cohort.
  Inventory their cases first; keep any specialist network scenarios out of the
  ordinary gate rather than executing a mixed stress suite accidentally.
- [ ] Independent specification review checks RFC 8441/9220 semantics and scope;
  independent code review checks shared-engine reuse, per-stream ownership,
  validation, policy handoff, deadline/credit transitions and actual evidence.
- [ ] After review fixes, freshly execute only affected gates and final ordinary
  peer/browser rows. Record command, environment, source/lock identity, nonzero
  executed counts, exits and observed protocols. Do not add overlapping test
  invocations together as unique cases.
- [ ] Publish a local acceptance matrix with PASS/FAIL/BLOCKED/NOT RUN separated.
  Update capability descriptions only for executed, reviewed paths; identify
  specialist qualification as deferred and upstream H2/H3 WS proxy as absent.
  Update the HTTP/Phoenix default and h2c documentation only after G2 passes;
  distinguish H2-first HTTPS from explicit prior-knowledge h2c and WS opt-in.
- [ ] Make small local conventional commits of task-owned files. Keep unrelated
  files and historical evidence. No push, release/tag/image, deployment,
  operational certificates, Vault, public management or disabled release-artifact
  E2E activation follows from M5 planning or implementation.

Named ordinary H1 compatibility commands (baseline line locations):

```sh
python scripts/check-tests.py --only proxy_policy apps/gaoxy_proxy/test/websocket_proxy_test.exs
python scripts/check-tests.py apps/gaoxy_proxy/test/websocket_tls_test.exs:28
python scripts/check-tests.py apps/gaoxy_http/test/websocket_network_test.exs:51 apps/gaoxy_http/test/websocket_network_test.exs:65
```

The selected cases are path/subprotocol/binary/normal-Close proxying, preservation
of an empty query, successful verified WSS, native WebSock lifecycle, and normal
fragmentation with ping/pong. Record actual selected/excluded counts distinctly.

## Acceptance matrix and stopping point

| Gate | Required evidence | Current status |
| --- | --- | --- |
| G0 | Source/cohort/public API and fixture compatibility | PASS |
| G1 | Shared handshake/runtime unit contracts and H1 compatibility | PASS |
| G2 | HTTPS H2 defaults, H1 compatibility, budgets and native H2/h2c WebSocket exchanges | PASS |
| G3 | Native H3 independent normal WebSocket exchanges | PASS |
| G4 | Phoenix Channels/LiveView and actual H2/H3 WS browser transport | NOT RUN |
| G5 | Fresh scoped compatibility, consumer isolation, SPEC/CODE acceptance | NOT RUN |

M5 completes when G0–G5 pass within this stated scope. A blocked browser row is
not silently waived or passed; record completed protocol subsets separately.
Further specialist qualification is a separate environment/workstream and does
not reopen accepted M3/M4 or add a new stage gate. The planning review passed
before execution authorization. Complete the implementation and scoped gates,
preserving any genuine external blocker and continuing other unblocked tasks.
