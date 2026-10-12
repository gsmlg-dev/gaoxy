# M4 upstream HTTP/3 and standalone implementation plan

**Execution update, 2026-10-13:** Use the reviewed
[public Session plan](m4-public-session-upstream.md) for UP0/UP1. It replaces the
Fetch-specific adapter below with an explicit dedicated endpoint lifecycle.
#101 is closed and cohort 0.21.4 is installed; Fetch functional diagnostics pass,
while Fetch cleanup remains unsupported. UP2, standalone and final acceptance
scope stay required. Apply the reviewed
[consumer-affinity task delta](m4-public-session-consumer-affinity.md) as well;
the original dated plan and failed receipts remain history.

For Sol implementation workers: execute the independently reviewed
[design](../designs/m4-upstream-standalone.md) under continuing authorization,
using the executing-plans workflow. Implementation depends on G2 acceptance;
this plan's existence does not satisfy it. Coordinator owns sequencing and final
acceptance. Separate upstream qualification from independently executable standalone
work; G3 downstream/browser remains a distinct required gate.

**Goal:** explicitly select upstream H3 through supported APIs and run data-only
standalone H3 services without changing existing default protocols.

**Architecture:** protocol-specific upstream adapter, shared HTTP Session and
policy; allowlisted standalone handler backed by existing H3 and Generation APIs.
No new external dependency, pool, protocol fallback or public management endpoint.

**Stack:** existing Elixir/OTP umbrella, HTTP Fetch cohort 0.21.3, native QUIC,
independent aioquic 1.2.0 peer, existing Python/Nix test runners.

## Work ownership and execution rules

| Owner | Files/responsibility |
| --- | --- |
| Client implementer | `apps/gaoxy_proxy/lib/gaoxy/proxy/http3_fetch_client.ex` (new), `upstream_client.ex`, `http.ex`, `http/session.ex`, narrow H1 compatibility changes in `http_fetch_client.ex`, H3 rejection in `upstream_groups/options.ex`; new `apps/gaoxy_proxy/test/http3_fetch_client_test.exs`, `http3_proxy_test.exs`, affected proxy tests. |
| Standalone implementer | `apps/gaoxy_server/mix.exs`, `lib/gaoxy/server/{config,supervisor,route_config,static_endpoint}.ex`; new `test/http3_config_test.exs`, `test/http3_generation_test.exs`; affected existing standalone tests. |
| Independent peer implementer | New `integration/http3/upstream/{origin.py,probe.exs,fixture.exs,run.py,README.md}` and `integration/http3/standalone/{fixture.exs,run.py,README.md}`; reuse existing pinned peer environment/certificate helpers without changing root harness during G2/G3 runs. |
| Coordinator | Shared dependency refresh only if required upstream fixes are published; all acceptance/status/capability/usage/audit docs and evidence, independent review, scoped final checks and commits. |

The parent owns any shared `HTTP.Headers` proxy changes required by G3; coordinate
before editing `apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex`. Workers are not
alone: preserve others' files and edits. No Mix commands concurrently; request
the lease before compile/format/tests/live runs. Freeze all hashed libraries,
locks and relevant fixtures during each live gate. Do not write `deps/`.

All commands below run from `.trees/m4-http3` with prefix:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2'
```

The Python integration runners are new deliverables, not commands already run.
Each must fail on zero executed checks, establish readiness through emitted
port/PID barriers, enforce a total deadline, and stop only children it created.
Keep failed runs intact in unique evidence subdirectories; no overwrite or relabel.

## Task 1 — public client qualification (UP0)

Owner: client and independent peer implementers, after G2. No production adapter
activation until lifecycle qualification resolves the design's source findings.

- [ ] Create aioquic origin endpoints for ordinary response, delayed headers,
  streaming echo, early final response, stalled response/upload, duplicate fields,
  ordered response trailers and request-trailer observation. Emit wire-observed
  authority, path, DATA length/hash, trailers, request count and cancellation.
  Use two loopback origins with distinct fixture certificate identities/ports.
- [ ] Probe only `HTTP.fetch`, Promise, Stream and AbortController public APIs.
  Fetch uses `http_version: :http3`, `http3_reuse: false`, HTTPS, explicit CA,
  manual redirects and raw streaming. Verify `response.http_version == :http3`.
  Validate correct CA/host succeeds, wrong CA/host fails, absent trust fails, and
  connect-address rejection occurs before any origin request.
- [ ] Include this minimal public cleanup result assertion in the probe, against
  the fixture URL and generated CA (variables supplied by runner):

  ```elixir
  import ExUnit.Assertions
  controller = HTTP.AbortController.new()
  promise = HTTP.fetch(url,
    http_version: :http3, http3_reuse: false, redirect: :manual,
    request_mode: :proxy, stream_response: true, decode_body: false, signal: controller,
    ssl: [cacertfile: ca, verify: :verify_peer], timeout: 1_000)
  result = HTTP.RequestCompletion.await(HTTP.Promise.completion(promise), 0)
  # Pinned 0.21.3 source predicts this; record actual result, do not call it PASS
  # for cleanup acceptance:
  assert result == {:error, {:unsupported_completion, :http_version}}
  :ok = HTTP.AbortController.abort(controller)
  ```

  The probe must additionally await/monitor its public task and any returned
  stream, stop its controller and upload producer, record independent cancellation
  and run inside a bounded child BEAM. The snippet alone is not a complete fixture
  or cleanup proof. It must not inspect controller state or private runtime owners.
- [ ] Evaluate public cancellation before headers, after headers while a chunk
  is unacknowledged, during a blocked upload and on downstream-owner loss. Record
  ordinary observable completion separately from the unsupported RequestCompletion
  result. Check whether a supported equivalent permits the existing Service cleanup
  token to be completed honestly; do not require the same API spelling as H1.
- [ ] Send a PID body in bounded chunks and `HTTP.Stream.finish(upload,
  [{"x-check", "one"}, {"x-check", "two"}])`. Observe the asynchronous
  `:request_trailers_unsupported` error and missing origin trailers on 0.21.3.
  Repeat with zero DATA. A local `finish/2` return of `:ok` is not acceptance.
  Minimal real public-API sequence inside the bounded probe, with `/echo`
  responding only after request FIN and runner-supplied `url`/`ca`:

  ```elixir
  import ExUnit.Assertions
  {:ok, upload} = HTTP.Stream.start_link(0)
  promise = HTTP.fetch(url <> "/echo",
    method: :post, body: upload, duplex: :half,
    headers: [{"trailer", "x-check"}],
    http_version: :http3, http3_reuse: false, redirect: :manual,
    request_mode: :proxy, stream_response: true, decode_body: false,
    ssl: [cacertfile: ca, verify: :verify_peer], timeout: 2_000)
  assert :ok = HTTP.Stream.chunk(upload, "abc", 1_000)
  assert :ok = HTTP.Stream.finish(upload, [{"x-check", "one"}, {"x-check", "two"}])
  result = HTTP.Promise.await(promise, 3_000)
  # Source-predicted result; retain the actual result/error and origin trace.
  assert result == {:error, :request_trailers_unsupported}
  ```

  The runner records public stream/task DOWN and stops its isolated BEAM even
  when the predicted error differs. Repeat omitting `chunk/3` for zero DATA.
  For the direct alternative, inspect `QuicHttp3.Session.__info__(:functions)`:
  `request/4` starts a new request, `send_data/5` only sends DATA/FIN and no public
  upload-trailer operation exists. Confirming the public export list is an API
  coverage check, not a second live protocol test. Do not write raw HEADERS via
  a private Session transport handle. An owned Session can offer public abort,
  but cannot remove this trailer blocker in the inspected cohort.
- [x] Run `python integration/http3/upstream/run.py --gate contract --evidence
  docs/acceptance/evidence/m4/upstream-contract` and record each supported,
  unsupported and failed row, exact source/lock hashes and child exit status.
- [x] For confirmed required gaps, inspect `deps/http_fetch/mix.exs` provenance
  (`gsmlg-dev/http_fetch`) and existing issues, then route focused Feature requests
  using `gh issue create --repo gsmlg-dev/http_fetch --type Feature --label
  'internal request' --title '[internal] ...' --body-file <prepared-file>`.
  Body includes requesting `gsmlg-opt/gaoxy`, actual branch, public reproduction,
  expected behavior and severity. Add the actual `# TODO(upstream): ...#N`
  marker to the task-owned probe/affected callsite. Never invent issue numbers.
- [x] If lifecycle or required trailers are blocked, stop only dependent client
  work; continue Task 4 and G3. Resume after the required public support is
  available and the pinned dependency is updated. The coordinator selects a
  supported equivalent lifecycle API if supplied; changes from this design get
  independent review. Do not revive #97 or replace it with native accounting.

**UP0 exit:** transport-appropriate public cleanup and required trailer behavior
qualified, or precise external blockers retained. Source audit alone is not a
runtime PASS. This architecture assignment ran none of these commands.

## Task 2 — explicit adapter and shared Session (UP1)

Depends on UP0 and G3's protocol-neutral proxy-header compatibility changes.

- [ ] Write configuration regressions for H1 default, explicit H3, unknown
  protocol, HTTP URL plus H3, missing CA, injected client module, address pinning
  with H3, oversized upload chunk and forged config struct. Add group rejection
  for map and precompiled struct H3 input; retain H1 group/forward tests.
- [ ] Implement fixed protocol-to-module selection in HTTP config and both
  endpoint/Session callsites. Specify the handle fields Session consumes. Extend
  UpstreamClient with host/reservation methods instead of calling H1 functions
  unconditionally. Keep GroupEndpoint explicitly H1 and its probes unchanged.
- [ ] Add HTTP3FetchClient with fixed Fetch options from the design, one upload
  producer and one response delivery at a time. Verify header event refuses a
  non-H3 response and oversized deliveries terminate visibly. Reuse public
  RequestCompletion only if qualified for the selected cohort; otherwise implement
  the reviewed supported H3 cleanup contract behind the same behavior.
- [ ] Add deterministic tests for no write replay after timeout, late/stale ACK,
  overlapping deliveries, headers/trailer limits, early response stopping upload,
  cleanup_pending retaining reservation, and no complete_cleanup on uncertainty.
  Use finite barriers and controlled public test doubles at UpstreamClient's
  boundary; protocol acceptance still requires independent network checks.
- [ ] Run `python scripts/check-tests.py
  apps/gaoxy_proxy/test/http3_fetch_client_test.exs
  apps/gaoxy_proxy/test/http3_proxy_test.exs
  apps/gaoxy_proxy/test/http_fetch_contract_test.exs
  apps/gaoxy_proxy/test/http_fetch_completion_test.exs
  apps/gaoxy_proxy/test/http_proxy_runtime_test.exs
  apps/gaoxy_proxy/test/http_proxy_wire_test.exs
  apps/gaoxy_proxy/test/http_proxy_tls_test.exs
  apps/gaoxy_proxy/test/http_headers_test.exs
  apps/gaoxy_proxy/test/forward_http_test.exs
  apps/gaoxy_proxy/test/upstream_groups_test.exs
  apps/gaoxy_proxy/test/upstream_group_proxy_test.exs
  apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs` as one command.
- [ ] Independent Sol specification/code review, fix findings, then fresh scoped
  tests and local conventional commit after source-bound evidence is recorded.

## Task 3 — independent upstream matrix (UP2)

- [ ] Start separate native H1, H2 and H3 Gaoxy listeners routing explicitly to
  the aioquic origins. Independent downstream clients speak their actual protocol;
  require origin H3 events. A Gaoxy server talking to itself is insufficient.
- [ ] Execute all three downstream rows for ordinary GET/HEAD, chunked or DATA
  upload/download, 1 MiB body with tiny receive windows, bodyless statuses,
  duplicate response fields, compressed bytes unchanged, escaped path/empty query,
  manual redirect/no replay, ordered request/response trailers including zero DATA,
  early final response, downstream cancellation, upstream reset and timeout.
- [ ] Use two configured upstream authorities in interleaved requests. Assert
  authority and TLS identity do not cross, one failed request does not cancel
  a sibling/other listener, and admission/cleanup returns to baseline within
  absolute deadlines. Show bounded queue/one-delivery behavior under stalled peers.
  Do not claim total native memory or reuse/pool support from this observation.
- [ ] Run `python integration/http3/upstream/run.py --gate matrix --evidence
  docs/acceptance/evidence/m4/upstream-matrix` with hashes before/after, exact
  nonzero count, protocol/certificate identities and all child exits.
- [ ] Independent Sol evidence review and a fresh affected rerun after any fix.
  Keep unsupported upstream H2, H3 forward/CONNECT/WebSocket rows explicit.

## Task 4 — standalone config and generations (ST1)

Depends only on G2 for static/H1 upstream routes. H3 route selection awaits UP1.

- [x] Write decode tests for the design's exact H3 JSON example and H1 defaults.
  Reject mixed/omitted H3 protocol selection, TCP/TLS/UDP with H3 handler, H3 with
  legacy http handler, wildcard/IPv6, unknown options/modules, H2 knobs, TLS
  provider/ALPN overrides, non-unicast mode and missing credentials. Verify
  invalid configuration creates no owners/listeners and no atoms from input.
- [x] Add only existing umbrella gaoxy_http3 to gaoxy_server dependencies. Decode
  H3 through HTTP3.service_spec with fixed ALPN. Leave core and gaoxy_http package
  dependencies untouched; keep lockfile unchanged unless UP0 requires an update.
- [x] Write exact budget boundary tests: required H3 service bytes are connection
  + max_streams * (request + 2 * 1_048_576) + writer; one byte below fails.
  Test custom max_streams/HTTP limits, existing H3 max_state checks, and static
  framed header count/bytes at initial decode and reload (including :status).
- [x] Register Generation stores for both concrete HTTP handlers. Implement the
  runtime child start MFA after stores start; initialize H3 Generation through
  Generation.init/1 there and set initialized endpoint options before Gaoxy starts.
  Retain existing child restart/shutdown contracts and H1 startup behavior.
- [x] Test initial H3 route call, store crash/restart resolving a new PID,
  stable listener across successful route reload, old in-flight snapshot versus
  new requests, invalid reload rollback and bounded generation-pin cleanup on
  worker death. Do not change core QUIC handler normalization solely for this.
- [ ] After UP1, allowlist reverse_proxy upstream_protocol JSON strings and
  validate HTTPS/CA/limits via HTTP.init. Before UP1, retain rejection of the
  unsupported option; do not accept a nonfunctional H3 route.
- [x] Run `python scripts/check-tests.py
  apps/gaoxy_server/test/http3_config_test.exs
  apps/gaoxy_server/test/http3_generation_test.exs
  apps/gaoxy_server/test/config_test.exs
  apps/gaoxy_server/test/route_config_test.exs
  apps/gaoxy_server/test/standalone_generation_test.exs
  apps/gaoxy_server/test/standalone_independent_review_test.exs` as one command.
- [x] Independent Sol review and fresh affected verification before local commit.

## Task 5 — standalone live acceptance (ST2)

- [x] Runner generates disposable local credentials and data-only config with
  loopback H3 plus an existing H1 service. Run a bounded standalone child with
  the real Config.load/Supervisor path, not a directly started H3 endpoint.
  Readiness emits actual bound ports; use independent aioquic/H1 clients.
- [x] Require static request success and an H3 downstream streamed/proxy route
  to an independent dedicated H1 origin after G3 compatibility. Only the H3
  origin route depends on UP1; do not skip the existing H1 proxy row while UP1
  is blocked. Require local route reload on unchanged listener, invalid route rollback, concurrent
  request isolation, and another service remaining responsive during one failure.
- [x] Occupy a later service's port before starting a mixed configuration; verify
  startup rollback stops its earlier H3 listener and Generation owners and permits
  UDP rebind. Missing/unusable certificate fixtures must fail cleanly without
  persistent owners/listeners; preserve the actual error.
- [x] Stop through bounded Gaoxy lifecycle, observe standalone child/owned workers
  exited and UDP port rebind succeeds. Do not describe local stop as graceful H3
  GOAWAY drain; existing host drain limitations remain.
- [x] Run `python integration/http3/standalone/run.py --evidence
  docs/acceptance/evidence/m4/standalone` and require nonzero executed checks.
  Keep this independent local suite separate from disabled release-artifact E2E.

## Task 6 — source-bound acceptance and documentation

- [x] Under the Mix lease, format-check exact authored Elixir files and run
  `mix compile --warnings-as-errors`. Run fresh affected proxy/standalone/H3 tests
  through `scripts/check-tests.py`; do not broaden to unrelated suites by default.
- [x] Rerun existing clean core and H1/H2 consumers and the H3 consumer from the
  M4 parent plan. Confirm standalone dependency addition does not introduce QUIC
  into core-only/H1/H2-only consumer closures.
- [x] Independent review covers specification, implementation, evidence counts,
  source hashes, completed child shutdown and capabilities. Resolve actionable
  findings and rerun affected checks before acceptance.
- [x] Coordinator synchronizes `docs/acceptance/m4.md`, `docs/capabilities.md`,
  `docs/implementation-status.md`, current dependency audit, standalone usage and
  main M4 checklist. Report UP0/UP1/UP2/ST1/ST2 and G3 individually. No full M4
  claim while required upstream/browser/standalone rows remain blocked or unrun.
- [x] Make small local conventional commits containing only task-owned files.
  Push/tag/release are conditional on full M4 acceptance and separate user
  publication authorization recorded in AGENTS.md. Deployment, Vault and
  production actions remain excluded.

Received counters: Connection Sol3/unsuccessful2/Astra1/unsuccessful0; Options
Sol4/unsuccessful1/Astra0. This architecture task adds zero Astra repair rounds.
Keep cumulative counters through further reviews/repairs; it does not authorize
a third Astra recovery round. Initial planning contained no executed gates;
current UP0 block, accepted ST1/ST2 static/H1-origin subset and pending UP1/UP2
and standalone H3-origin states are recorded in
[acceptance](../acceptance/m4.md).
