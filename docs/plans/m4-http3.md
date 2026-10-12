# M4 native HTTP/3 implementation plan

> For Sol execution: use `executing-plans` or `subagent-driven-development`
> task by task under AGENTS.md. Give parallel writers disjoint ownership;
> serialize dependent host/protocol/Plug integration. Astra owns architecture,
> not initial implementation or routine review.

**Goal:** qualify a bounded native H3 server over the selected public QUIC host,
then integrate shared HTTP endpoints and prove the downstream proxy/browser rows.

**Architecture:** [M4 design](../designs/m4-http3.md). Optional `gaoxy_http3`
application owns server state and reuses public Frame/Varint/Settings/Control/Qpack
APIs. Gaoxy's existing QUIC bridge remains the attached I/O owner boundary.

**Stack:** Elixir 1.18 / locked OTP 28 Nix shell, selected Abyss Git revision,
HTTP cohort 0.21.3, independent Python aioquic, local Chromium/Playwright.

**Execution start, 2026-10-12:** baseline `78de9d0f3bba5a4662717359438eb3d0853a79b4`,
branch `codex/m4-http3`, worktree `.trees/m4-http3`. Gates remain NOT RUN until
source-bound execution evidence is recorded. No routine user approval is required between
passing gates. Preserve unrelated edits, Vault freeze, disabled release-artifact
E2E, production exclusions and existing repair counters.

## Execution conventions

All commands run from the worktree root unless a directory is stated. Enter
`nix develop`, then set `MIX_ENV=test` and `ERL_FLAGS='+S 2:2'`. Run scoped suites
through `python scripts/check-tests.py <explicit files>`; it fails on zero
executed tests. Every new regression first produces its intended red result,
then passes after the smallest implementation. Record red as expected only when
agreed in advance, never after an unexpected regression.

Commit small completed slices locally after fresh tests and independent Sol
specification/code review. Stage exact owned paths, never `git add .`. Existing
release authorization is coordinated separately; this plan performs no push,
release, deployment or workflow enablement. An actual dependency defect follows
AGENTS.md upstream issue routing, with a concrete reproduction. Do not inspect,
pursue or recreate dismissed issue 97 requirements.

Evidence directory: `docs/acceptance/evidence/m4/<gate>/`. Store command,
source SHA and dirty diff digest, root/consumer lock hashes, dependency versions,
runtime/peer versions, exit, nonzero test count, case-by-case result and bounded
resource/cleanup observations. Redact keys. Fixture CA/certificates are local
test material, never production credentials. A missing tool is BLOCKED_ENV,
not a false PASS or weakened requirement.

## Task 0 — public-host requalification (G0)

Owner: one Sol host/fixture worker. Files:

- Modify `integration/quic_consumer/mix.exs`, `mix.lock`, `test/quic_test.exs`
  within that directory, and `integration/quic_consumer/peer.py` only as needed
  for the selected version/public contract.
- Create `integration/http3/requirements.txt`, `integration/http3/README.md`.
- Record `docs/acceptance/evidence/m4/host/` and new `docs/acceptance/m4.md`.
- Necessary proven compatibility fixes may touch `apps/gaoxy/lib/gaoxy/quic.ex`,
  `quic_bridge.ex`, `service.ex` and matching scoped tests. Do not patch deps.

- [x] Verify root lock and installed public APIs from the design. Update the
  independent generic QUIC consumer's exact `elixir_quic`/`ex_ssl` pins from
  0.17.0 to 0.21.3 and regenerate only its dependency lock. Preserve root cohort.
- [x] Pin `aioquic==1.2.0` as the initial independent peer in the new requirements
  file; use a task-local virtual environment and record its resolved environment.
  Reuse fixture-generation conventions from `scripts/generate-fixtures.sh`.
- [x] Add host regressions: `h3` ALPN and verified CA/hostname; peer/local uni and
  bidi streams; fragmented data; FIN/reset/stop; definitely blocked writes and
  eventual progress; connection close isolation; explicit stop/restart cleanup.
  Assert operation admission separately from received peer bytes.
- [x] Run the consumer in its own directory: `mix deps.get --check-locked`,
  `mix compile --warnings-as-errors`, `mix test --warnings-as-errors`.
  This run is separate from umbrella tests; assert nonzero executed cases.
- [x] Verify read items expose numeric stream IDs as documented while handles
  remain opaque; record event ordering, metadata and callback deadlines.
- [x] Validate `Gaoxy.QUIC.operation_status/2` usage for any controlled uncertain
  operation probe. No exact VM/native accounting or unexposed receipt requirement
  is added. Fail visibly on blind retry or duplicated peer bytes.
- [x] Independent Sol review of source/API compatibility and network evidence.

**G0 verified, 2026-10-12:** independent consumer 4/0 and nine peer cases;
independent review and post-review fresh repeat passed. The conditional controlled
uncertain-operation probe was NOT RUN; no uncertain receipt was observed. See
[execution record](../acceptance/m4.md).

**G0 pass:** actual 0.21.3 host exchange, critical directional operations and
bounded cleanup work through public Gaoxy/Abyss APIs. Old 0.17.0 success is not
credited. A host defect blocks only dependent live H3 work; pure protocol tests
can proceed. No private host or engine calls are a permitted workaround.

## Task 1 — optional package and pure server protocol

Owner: protocol worker. Parallel with G0's independent fixture work. Files:

- Create `apps/gaoxy_http3/mix.exs`, `lib/gaoxy/http/http3.ex` and
  `lib/gaoxy/http/http3/{options,protocol,headers}.ex` beneath that app.
- Create its `test/test_helper.exs`, `test/options_test.exs`,
  `test/protocol_test.exs`, `test/headers_test.exs`, `test/qpack_test.exs`.

- [x] Declare `:gaoxy_http3`, shared umbrella paths, `{:gaoxy_http, in_umbrella:
  true}` and `{:elixir_quic_http3, "== 0.21.3"}`. Keep root cohort unchanged.
- [x] Write option failures before activation: missing credentials, wildcard or
  IPv6, wrong ALPN, mixed H1/H2/H3 protocol lists, unknown options, nonzero local
  dynamic capacity and inconsistent byte/stream limits. Verify no socket binds.
- [x] Implement `HTTP3.service_spec/1` with exactly one endpoint or Plug tuple,
  `transport: :quic`, `handler: HTTP3.Connection`, `quic: %{alpn: ["h3"]}` and
  the existing `tls: %{certfile: path, keyfile: path}` contract. Initialize endpoint
  once. H1/H2 APIs keep their behavior; H3 is explicitly selected through this API.
- [x] Define the pure interface `Protocol.new(limits)`,
  `Protocol.open(state, stream_key, :bidi | :uni)`,
  `Protocol.feed(state, stream_key, bytes)`, `Protocol.fin(state, stream_key)`.
  Successful transitions return `{:ok, next, actions}`; failures return
  `{:error, :stream | :connection, code, reason, next}`. Actions describe fields,
  DATA, trailers, settings, discard, and completion without doing I/O.
- [x] Use public dependency codecs. Test every split point in type/frame varints
  and representative HEADERS/DATA; length limits apply before accumulating data.
  Stream DATA incrementally; discard unknown frames without buffering their body.
- [x] Test control SETTINGS-first/duplicates/reserved IDs, missing/duplicate
  critical streams, closure, push-ID rules, unknown types, and exact scoped error
  codes from the design. Permit requests arriving before control SETTINGS on a
  different QUIC stream.
- [x] Test static/literal/Huffman headers using independent known wire vectors,
  zero-capacity QPACK streams, dynamic-reference/instruction rejection, decoded
  field size/count, malformed pseudo-fields/content-length and trailer ordering.
  Include empty query delimiters and HEAD/bodyless semantics.
- [x] Accept/ignore legal decoder Stream Cancellation with zero dynamic
  capacity; test fragmented prefix-6 integers, QUIC stream-ID bounds, malformed
  cancellation and sibling continuation. Retain QPACK_DECODER_STREAM_ERROR for
  Section Acknowledgement/Insert Count Increment without dynamic references.
- [x] Permit ordinary CONNECT with a matching Host and reject mismatches or
  duplicates. Distinguish invalid length syntax (H3_MESSAGE_ERROR) from a valid
  declared body above its ceiling (H3_EXCESSIVE_LOAD).
- [x] Map codec `:invalid_fields` to stream H3_MESSAGE_ERROR and `:field_limit`
  to resource H3_EXCESSIVE_LOAD; only malformed compression closes the
  connection with QPACK_DECOMPRESSION_FAILED. Test content-length against
  aggregate DATA bytes at FIN, including underflow and overflow.
- [x] Run `python scripts/check-tests.py apps/gaoxy_http3/test/options_test.exs
  apps/gaoxy_http3/test/protocol_test.exs apps/gaoxy_http3/test/headers_test.exs
  apps/gaoxy_http3/test/qpack_test.exs` (one command, paths separated by spaces).

**Task 1 pure/options verified, 2026-10-12:** 60 tests/0 failures after
independent review, with exact-file format and strict compile. Task 2 adds the
real Connection-backed public service specification (3/0), H3 upgrade guard
(2/0), and the independently reviewed read-credit budget correction (Options
9/0). Post-review affected verification passes 78/0; production dispatch is G2.

**Exit:** pure transitions and strict options pass. This is not live H3 acceptance.

## Task 2 — minimal live server and independent peer (G1)

Depends on G0 and Task 1. Owner: connection worker; independent peer worker owns
only integration fixture/peer files. Files:

- Create `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex`,
  `apps/gaoxy_http3/test/connection_test.exs`, `test/lifecycle_test.exs`.
- Create `integration/http3/{fixture.exs,peer.py,run.py}`.
- Extend `docs/acceptance/m4.md` and `docs/acceptance/evidence/m4/minimal/`.

- [x] Implement bounded QUIC callbacks and public `Control.new(:server, ...)`,
  `local_payload/1`, `receive_peer/3`. Keep the type prefix on the first control
  feed. Track local send/open state in Gaoxy, never by changing Control internals.
- [x] Store opaque stream handles; derive IDs only from public read results.
  Perform fair, finite work on `:tick`/`:writable`; reserve control progress.
  Implement deadline-bound pending operations and uncertain-reference resolution.
- [x] Use a fixture-only endpoint action for GET `/ok` and streaming POST `/echo`;
  no new public application endpoint contract. The production shared endpoint
  mapping arrives in Task 3. No blocking Plug execution inside callbacks.
- [x] Build a runner with `--gate minimal --evidence <path>`; it starts an ephemeral
  loopback fixture, reports bound port/readiness, runs aioquic cases, tears down
  its own children and returns nonzero if any case fails or none execute.
- [x] Peer cases: GET/HEAD, POST fragmented payload and FIN, two concurrent requests,
  static/Huffman fields, trailers, control/QPACK stream setup, invalid ordering,
  duplicate SETTINGS/critical stream, critical reset/FIN, header limits, request
  reset/STOP_SENDING isolation, tiny receive windows with eventual progress, and
  listener shutdown with another listener still exchanging bytes.
- [x] For each malformed case, independently assert error code and connection vs
  stream scope. For resets, assert sibling completion and no late response bytes.
  For shutdown, assert bounded local cleanup, not unsupported graceful drain.
- [x] Run `python scripts/check-tests.py apps/gaoxy_http3/test/connection_test.exs
  apps/gaoxy_http3/test/lifecycle_test.exs`, then
  `python integration/http3/run.py --gate minimal --evidence docs/acceptance/evidence/m4/minimal`.
- [x] Independent Sol review, resolve findings and rerun affected cases.

**G1 verified, 2026-10-12:** independent whole-source review and resolution
review passed; post-review fresh 78/0 affected tests and 47 live checks passed.
Retained failures, concrete FIN-callback diagnostic and bounded Astra1 recovery
remain in the acceptance evidence. Connection Sol2/failed2/Astra1/failed0;
Options Sol4/failed1/Astra0. Automatically execute the independently reviewed
[shared integration supplement](m4-shared-http.md) for Task 3 next.

**G1 pass:** real independently decoded H3 ordinary/control/malformed/reset/
flow-control/shutdown behavior. Publish only the bounded profile in local docs.
Automatically proceed to Task 3; do not describe M4 as complete.

## Task 3 — shared Exchange, Response and Plug (G2)

Owner: HTTP integration worker. Files:

- Create `apps/gaoxy_http3/lib/gaoxy/http/http3/{operations,stream,transport,response}.ex`.
- Create `apps/gaoxy_http3/test/{operations,transport,plug,lifecycle_race}_test.exs`.
- Integrate Connection and Options; narrowly modify shared Exchange/Plug helpers
  only where a real protocol-neutral seam is missing, with H1/H2 regressions.
- Extend `integration/http3/{fixture.exs,peer.py,run.py}` with `--gate shared`.

- [ ] Test and implement one bounded ETS operation slot per admitted worker,
  generation token checks, claim/reply reference, absolute deadline and tombstones
  preventing timeout/retry duplication. Poll from owner ticks; do not send
  GenServer operations to the Abyss worker or move I/O to endpoint processes.
- [ ] Before dispatch, have each worker acquire its own request lease and arm
  `Admission.begin_request(gate, lease, reserve, D)` with the original absolute
  request deadline. Monitor owner for cooperative Transport exit; owner polls
  worker liveness. A busy Plug cannot handle DOWN. Admission's existing deadline
  kill, followed by its worker-DOWN lease release, enforces that case independently
  of the connection owner. Do not renew D or add a second guard timer.
- [ ] Add a deterministic owner-killed-while-Plug-busy regression. The fixture
  Plug signals `{:plug_busy, worker, ref}` after dispatch, then waits only for a
  test release token outside Transport (no DOWN clause); the test never sends
  that token. After the readiness barrier, kill only its callback owner. Keep
  Admission alive and use a short configured request deadline recorded as D.
  Observe worker DOWN from Admission's enforced kill; by
  `D + Lifecycle.cleanup_headroom()` require deleted ETS, released request
  lease/bytes and monitored resource pins. Poll receipt conditions within this
  absolute bound, without sleeps used as readiness or success evidence. Incomplete
  receipt is `termination_unconfirmed`, not PASS. Prove another connection's
  request and another listener still complete successfully after the kill.
- [ ] Deterministically test failed start, worker crash, cooperative owner loss,
  cancellation before/after claim, stale generation and late response. Prove slot,
  request lease and generation resource release on every path, including forced
  death where endpoint `after` cleanup does not run. Keep existing service drain /
  forced-cleanup deadlines and test their separate confirmation path.
- [ ] Construct Exchange with `transport: HTTP3.Transport`, H3 request version,
  HTTPS, actual peer/local metadata and nil for unavailable certificate metadata.
  Implement the existing facade's return contracts, not an H3-specific Plug API.
- [ ] Reject H3 WebSocket upgrades explicitly in the shared Plug adapter and
  verify `:not_supported` without entering the H1 upgrade path; preserve H1/H2.
- [ ] Test request streaming/trailers, response streaming/file/trailers,
  informational responses/100-continue, HEAD/204/304, early response with unread
  request data, output deadlines and simultaneous unrelated streams.
- [ ] Verify limits with slow independent peers and application-body credit:
  record queue bytes/slots and Admission state returning to baseline. Separate
  engine/host ceilings from application state; report observations honestly.
- [ ] Run new scoped suites and existing `apps/gaoxy_http/test/http_contract_test.exs`,
  `native_proxy_seams_test.exs`, `http2_facade_test.exs` (fully qualify each path),
  followed by `python integration/http3/run.py --gate shared --evidence
  docs/acceptance/evidence/m4/shared`.
- [ ] Independent Sol review, targeted repairs, fresh verification.

**G2 pass:** existing endpoint/Plug API serves H3 with finite ownership and
stream isolation. No upstream pooling or H2 adapter is enabled by this task.

## Task 4 — downstream proxy and browser matrix (G3)

Owner: integration worker. Files:

- Create `apps/gaoxy_http3/test/proxy_test.exs` and
  `integration/http3/{proxy_peer.py,browser.py}`; extend fixture/runner/README.
- Necessary semantic proxy changes only in `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`
  and matching scoped tests after inspecting current callsites.
- Update `docs/acceptance/m4.md` and `docs/acceptance/evidence/m4/matrix/`.

- [ ] Exercise H3 downstream -> local endpoint/Plug/Phoenix and H3 -> existing
  dedicated H1 origin with streaming upload/download, trailers, escaped and empty
  query, early origin response, cancellation and two concurrent requests.
- [ ] Preserve authentication/destination policy. No open forward proxy, CONNECT
  extension, automatic upstream protocol selection or reusable pool activation.
- [ ] Create a local trusted browser fixture profile with explicit H3 discovery
  (local Alt-Svc or a documented browser test-origin mapping). Use pinned installed
  Chromium/Playwright and record exact versions. Assert the network's negotiated
  protocol is `h3`, correlate server request evidence, and check the rendered
  Phoenix HTTP page. H2 fallback alone fails the H3 assertion.
- [ ] Run `python scripts/check-tests.py apps/gaoxy_http3/test/proxy_test.exs`,
  then `python integration/http3/run.py --gate matrix --evidence docs/acceptance/evidence/m4/matrix`.
- [ ] Record H1/H2 -> H3 origin, H3 -> H3 origin and H3 -> H2 origin rows as
  NOT IMPLEMENTED / NOT RUN until their separate upstream adapter slices exist.
  This is an explicit boundary, not a full-matrix PASS. H3 WebSocket is UNSUPPORTED.
- [ ] Run `scripts/external-consumer.sh` for core isolation and create/run an
  analogous clean H1/H2-only consumer selecting only `gaoxy_http`; assert its
  resolved/started apps exclude `elixir_quic`, `elixir_quic_http3`, `ex_ssl` and
  `http_fetch`. A separate H3 consumer must include its declared runtime cohort.
- [ ] Run all `apps/gaoxy_http3/test` cases through the nonzero-count wrapper;
  format-check exact changed Elixir files and compile with warnings-as-errors.
  Run affected core/H1/H2/proxy compatibility suites, not unrelated repository
  suites. Independently review code, evidence and advertised capability rows.
- [ ] Synchronize `docs/capabilities.md`, `docs/implementation-status.md`, the
  dependency audit and public H3 usage documentation with executed evidence.

**G3 pass:** only executed downstream/browser/isolation rows pass. If browser
support is unavailable, record BLOCKED_ENV and keep that gate incomplete.
The remaining upstream-H3 adapter/matrix work needs its own written bounded
architecture and implementation plan under continuing authorization; it must
not be silently omitted from a claim of full M4 completion.

## Task 5 — remaining M4 product coverage

After G2, design and independently review the public upstream-H3 client adapter
and explicit standalone H3 configuration. Execute those slices automatically
under the 2026-10-12 authorization. The client adapter must use public supported
client APIs, preserve authentication/destination policy and expose bounded
streaming/cancellation without enabling the unimplemented reusable H1/H2 pools.
Prove H1/H2 -> H3 and H3 -> H3 with independent origins, plus a standalone
data-only H3 service using local test credentials and bounded shutdown. Write
the exact file ownership, regressions and commands in their own plans before
implementation. These required rows remain NOT IMPLEMENTED / NOT RUN until
verified; G0-G3 do not substitute for full M4 acceptance. No release or deployment
is authorized by this task.

## Handoff / stopping rules

After a scoped gate passes and independent review resolves its findings, record
its source-bound evidence and continue automatically. Genuine dependency blockers
stop dependent work without a private workaround; continue independent tasks.
Unexpected unrelated failures are listed and left untouched. Historical counters
remain H1 Sol 3/failed 2/Astra 1; TLS Sol 4/failed 2/Astra 2; model Sol 2/failed
1/Astra 0; H2 Sol 1/failed 0/Astra 0. Architecture uses zero recovery rounds;
this document does not authorize a third Astra recovery.

Before any final result, record commands completed/stopped, precise diff ownership,
PASS/FAIL/BLOCKED/NOT RUN per gate and residual capability rows. Local tests do
not establish hosted CI, release artifacts, deployment or production acceptance.
