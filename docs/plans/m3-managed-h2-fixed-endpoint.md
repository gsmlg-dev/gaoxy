# M3 managed H2 fixed-endpoint implementation plan

> **For agentic workers:** Use subagent-driven-development for the disjoint
> ownership below, or executing-plans for dependent tasks. Steps use checkboxes.
> Parent alone executes runtime/Mix/format/build/peers/evidence/commits, with ALL
> writers frozen. Continuing authorization selects this approach automatically.

**Goal:** Activate fixed managed TLS-H2/h2c upstreams for native H1/H2 downstreams
with enforced finite payload envelopes and original-completion cleanup.

**Architecture:** Add ManagedH2Client at the existing UpstreamClient boundary,
a pure envelope, and an additive activation ledger. Reuse owner/Custodian and
Service/Session/pump lifecycle; retain dedicated/managed H1 clients and accepted
pure preparation. No H2 group/probe/Generation/standalone/load activation here.

**Tech stack:** Elixir/OTP, Gaoxy native H1/H2, pinned HTTP0.21.4 public
Fetch/Stream/Promise/RequestCompletion/ManagedTransport, OTP SSL, independent
Python h2 peer and scoped ExUnit tests in the qualified Nix environment.

Status: **PREPARED; EXECUTION NOT RUN**. The normative
[design](../designs/m3-managed-h2-fixed-endpoint.md) fixes APIs, exact schemas,
slot multiplicities and9,444,956 proposed bytes/request (8,920,668 proxy payload
+524,288 bounded public downstream renderer). The
[acceptance contract](../acceptance/m3-managed-h2-fixed-endpoint.md) lists required
outcomes. Preparation has complete independent SPEC/CODE PASS, fresh format/
strict compile97/0 and fresh public63/0, with zero skips and stable source.
Accepted preparation commit is `c871e3d9ee87cf802acf764d7d7622e0a7b611d6`.
Parent captures source/evidence inventory at kickoff in
`docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/`.
All execution checkboxes remain
unchecked. No publication/deployment or E2E/Vault scope is granted.

## Ownership and serialization

| Writer | Exclusive implementation/test ownership |
| --- | --- |
| A: envelope/client/accounting | New `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`, new `managed_h2_client.ex`; additive `managed_h2_reservation.ex`; new `apps/gaoxy_proxy/test/managed_h2_envelope_test.exs`, `managed_h2_client_test.exs`, `managed_h2_activation_reservation_test.exs` |
| B: owner protocol dispatch and Generation exclusion | `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex`, `upstream_transports.ex`; `apps/gaoxy_http/lib/gaoxy/http/endpoint.ex`, `generation.ex`; `apps/gaoxy_proxy/test/upstream_transports_options_test.exs`, new `upstream_transport_h2_identity_test.exs`, new `managed_h2_generation_exclusion_test.exs`. B adds optional Endpoint hook/Store invocation; C later adds Proxy.HTTP hook implementation. |
| C: fixed endpoint integration, AFTER A/B API freeze | `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, `http/session.ex`, `http/headers.ex`; new `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`, `managed_h2_fixed_lifecycle_test.exs`; necessary narrow contract updates in `upstream_transport_proxy_test.exs` and `http_headers_test.exs` |
| Parent | New `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`, new `integration/http_fetch_contract/managed_h2_fixed_qualification.py`; `apps/gaoxy_http/lib/gaoxy/http/http1/response.ex`, `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`; new `apps/gaoxy_http/test/managed_proxy_renderer_test.exs`; these three successor documents, evidence; all runtime/build/format/commits |

All writers are NOT ALONE and must preserve others' edits. Parent may reassign
test-only ownership explicitly; no shared writer. Preparation production/tests,
Custodian, transport backends, historical supplement/collector and63 public
assertions are read-only. Generation changes are only the optional exclusion
hook; the two public renderers change only for bounded guards/admission.
Any other demonstrated compatibility need requires
parent assignment and narrow regression, not opportunistic cleanup. C starts
only after A/B proposed APIs and protocol identities are frozen. Independent
pure tasks A/B can proceed in parallel; RED, implementation release, runtime,
review, repairs and commits are serialized by parent.

Carry every inherited repair/rejection/harness counter from preparation's actual
kickoff receipt. PROJECT_ARCHITECTURE uses zero recovery; Astra recovery2/2
remains exhausted. Do not reset counters or weaken assertions after a failure.
Parent records new Sol repair/validation attempts and diagnoses separately.

## Task 1: Verify predecessor and freeze interface contract

- [ ] Parent reads accepted preparation SPEC/CODE, final97/0 and public63/0
  receipts, local commit receipt and exact source/lock/cohort hashes. Record
  `pwd`, `git branch --show-current`, `git rev-parse HEAD`, `git status --short`
  and task-owned vs pre-existing inventory in the actual worktree.
- [ ] Record accepted H1 fixed/group/Generation compatibility sources and the
  existing historical worksheet output; capture all63 public case identities.
- [ ] Independent document SPEC readiness checks exact source-field retention,
  protocol identity, thirteen-field Response, opaque projection unit, slot
  ownership/release, sixteen controls and all four network cells. Resolve
  findings in documentation; no runtime acceptance is inferred.
- [ ] Freeze additive helper/client/evaluator signatures from the design.
  Parent assigns ownership above, confirms no overlapping process/writer, and
  releases A/B tests-only work. Keep production unedited until observed RED.

## Task 2: Pure envelope and activation accounting (A)

**Files:** New envelope and envelope/activation-reservation tests; additive
reservation only. Historical `worksheet/0` and its tests stay unchanged.

- [ ] Write executable RED tests with these complete fixture constructors in
  the new envelope test module (`use ExUnit.Case, async: true`):

```elixir
defp config(protocol \\ :http2) do
  %Gaoxy.Proxy.HTTP{
    uri: URI.parse(if(protocol == :http2, do: "https://upstream.test", else: "http://upstream.test")),
    cacertfile: nil, connect_address: nil,
    transport: %{provider: Gaoxy.Proxy.UpstreamTransports, owner: self(),
      owner_epoch: make_ref(), resource: make_ref()},
    upstream_protocol: protocol, client: Gaoxy.Proxy.ManagedH2Client,
    limits: %{max_chunk_bytes: 65_536, opening_timeout: 5_000,
      idle_timeout: 60_000, write_timeout: 5_000, max_lifetime: 30_000}
  }
end

defp source do
  %{url: "https://upstream.test/a%2Fb?", target: "/a%2Fb?", method: :post,
    fields: [{"content-length", "3"}, {"x-trace", "first"}, {"x-trace", "second"}],
    body_mode: {:length, 3}, max_upload_bytes: 65_536,
    request_limits: %{max_headers: 256, max_header_bytes: 65_536,
      max_trailers: 128, max_trailer_bytes: 65_536}}
end

test "pre-Session envelope retains raw Content-Length and raw empty query" do
  assert {:ok, envelope} = apply(Gaoxy.Proxy.ManagedH2Envelope, :prepare, [config(), source()])
  assert map_size(envelope) == 8
  assert envelope.target == "/a%2Fb?"
  assert envelope.fields == source().fields
  assert envelope.body_mode == {:length, 3}
  assert envelope.protocol == :http2
  assert :ok == apply(Gaoxy.Proxy.ManagedH2Envelope, :validate_request, [envelope])
end

test "backing and extra schema are rejected before copying" do
  backing = :binary.copy("x", 65_537)
  small = binary_part(backing, 0, 100)
  assert :binary.referenced_byte_size(small) > 65_536
  assert {:error, _} = apply(Gaoxy.Proxy.ManagedH2Envelope, :prepare,
    [config(), %{source() | fields: [{"x", small}]}])
  assert {:error, _} = apply(Gaoxy.Proxy.ManagedH2Envelope, :prepare,
    [config(), Map.put(source(), :exchange, :forbidden)])
end
```

  Add exact/over URL, target, field count/bytes/backing, effective limits, body
  unsigned64 and signed64 time/deadline cases, all improper tuple/list/map/forged
  struct variants, source/canonical equality and bounded complete sizes. Exact
  boundary tests must be feasible composed inputs, never invented successes.
- [ ] Write RED for exact URI/config/handle/five limits, nil trust/address,
  same authority different protocol, exact four-key trailer policy, token128
  before dedup and129 rejection, allowed128/dropped265/payload65,642/policy67,689.
- [ ] Write RED for exact Response/Headers/Promise/Task schemas, each boolean/
  type/body/stream variant; final status200/599 and199/600 rejection; metadata
  URL provenance; informational128/aggregate2,048 and overhead65,536 boundaries;
  trailer129 rejection before cache; field backing and extra-key forgery.
- [ ] Write arithmetic RED, with direct assertions independent of implementation:

```elixir
test "activation ledger sums complete bounded slots without changing worksheet" do
  b = fn bytes -> bytes + 6 end
  f = fn count, bytes -> bytes + 12 * count + 7 end
  n = fn count, bytes -> bytes + 5 * count + 7 end
  scratch = 3*f.(256, 65_536) + 2*n.(393, 65_642) + 2*b.(65_536)
  assert scratch == 472_157
  proxy = 5*205_337 + 5*147_456 + 2*1_183_744 + 2*67_689 +
    n.(128, 65_536) + 4*f.(256, 65_536) + 4*f.(128, 65_536) +
    3*b.(1_048_576) + 2*b.(65_536) + b.(16_384) + 213_965 + scratch + 65_536
  assert proxy == 8_920_668
  assert 2*81_920 + b.(65_536) + 4_096 == 233_478
  assert 131_072 + b.(65_536) + 2*73_728 + 4_096 == 348_166
  expected = proxy + 524_288
  assert expected == 9_444_956
  assert expected * 32 == 302_238_592
  assert Gaoxy.Proxy.ManagedH2Reservation.worksheet().named_subtotal_per_request == 2_918_508
  assert apply(Gaoxy.Proxy.ManagedH2Reservation, :reservation_bytes, [[], 1, 1]) == expected
  assert_raise ArgumentError, fn ->
    apply(Gaoxy.Proxy.ManagedH2Reservation, :reservation_bytes, [[], 65_537, 1])
  end
end
```

  Add per-component multiplicity/formula/owner/release-point assertions; prove
  full preparation return fits201,753 Request+3,456 accounting+128 wrappers,
  exact manifest schemas fit3,072 and discard immediately, missing later
  evaluator inputs keep the full ceiling, opaque capability
  projections are typed markers, and private completion/scope interiors never
  reach serialization. Validate schemas/backing before external_size; no
  zero-charged unknown value, complete+projection double charge or sixth copy.
- [ ] Freeze A tests; parent runs the exact scoped RED command below and records
  nonzero executed tests and actual missing-API/assertion failures. It releases
  A production only after that observation.
- [ ] Implement the pure design APIs with bounded recursive traversals and copy
  after preflight; return finite errors. Keep raw envelope Content-Length/source
  fields, use actual-PID preparation only at the later opening gate. Add the
  exact closed `activation_contract/0`, evaluator/manifests and conservative
  validating facade. No process, socket or private capability serialization.
- [ ] Freeze A; parent GREEN runs same files plus historical preparation/
  worksheet tests. Arithmetic and all malformed/exact/over/backing cases pass.

## Task 3: Protocol-bound owner and Options (B, parallel with Task 2)

**Files:** Options/owner and owner tests from ownership table.

- [ ] Write RED for TLS-H2/h2c policy/request dispatch using accepted source
  schemas; no I/O in preparation, exact owner complete accounting and finite
  limits remain required. Verify H1 dispatch unchanged.
- [ ] Write RED for validation AND delegation identity
  `{protocol,scheme,host,port,instance}`. Same HTTP origin H1 vs h2c, TLS-H2 vs
  H1, stale epoch, wrong resource/instance, malformed raw port, forged/excess
  keys and owner death reject before scope admission/Fetch. Authentic captured
  source pin delegates exactly once; wrong holder/operation and late results
  retain the accepted failure/cancellation contract.
- [ ] Write RED for checkout returning exact H2 fetch options, `:http2`/`:h2c`,
  SSL/native_v1/reuse true, manual/raw/stream options and original opaque scope;
  no override path. Assert C2/R32/P0 from accepted preparation.
- [ ] Write RED for optional Endpoint.generation_validate/1 called from
  Store.compiled_bound/2 on preparation and activation, default :ok for old
  endpoints; fixed H2 static Router.compile allowed but Store prepare/activate/
  forged prepared router reject unsupported_generation_endpoint. H1 Generation
  remains accepted. B adds generic hook/Store validation with no proxy dependency;
  C adds Proxy.HTTP rejection after API freeze.
- [ ] Freeze B; parent runs unfiltered new identity + Options RED. Then add only
  pure protocol dispatch, identity comparison and protocol-specific fetch
  options in existing owner; keep owner token/pin/Custodian architecture.
- [ ] Freeze B; parent GREEN includes H1 Options/owner/identity/handoff and
  preparation compatibility. A/B APIs freeze before C production/test release.

## Task 4: Public adapter (A after Task 2 and owner API freeze)

**Files:** New client/client tests. Use public Fetch/Stream/Promise/completion.

- [ ] Write RED for handle schema and original completion, Response projection
  drop, native event validation, raw compression, bodyless behavior, normalized
  bounded task/stream errors, and all client event return forms. Nil/body stream
  and task DOWN cannot fabricate completion.
- [ ] Freeze open/1 exactly as the design's seven-key
  `%{request, managed_transport, timeout, opening_timeout, write_timeout,
  deadline, opening_deadline}` map; nested request is eight keys, checked client
  three keys. No headers/body aliases or overrides. For poll_headers/1 and
  event/2 use `{four_key_handle, submitted_url}` context; return updated exact
  four-key handle. All other callbacks receive the handle unchanged. Session
  retains one compact URL in its existing request slot, until first validated
  head or cleanup; the transient tuple has <=128 wrapper bytes and no URL copy.
  Current/original handles never store URL/Response. H1/H3 keep their old args.
- [ ] Assert cleanup returns only :ok or {:error, finite_reason}; no
  begin_cleanup/3 is added. Pin/task/end/consumption cannot synthesize completion.
- [ ] Write RED for16,385,65,536,1,048,576-byte DATA success;1,048,577 and small
  slice with >1MiB backing rejection. Upload65,536 success;65,537/backing over
  rejection. Trailer128 success/native-valid129 rejection. Assert failure never
  sends public ACK. Test adapter tests without unbounded mocked native interiors.
- [ ] Freeze; parent observes RED. Implement existing behaviour callbacks:
  validate exact opening schemas and checked policy, create owned upload only
  after admitted checkout, prepare actual PID source, Fetch with owner options,
  obtain original completion, return exact handle/upload. Public cleanup uses
  RequestCompletion await/abort-and-await at finite nonblocking polls.
- [ ] Match public Response/Task results by authenticated refs, preflight before
  copying, extract only bounded head and stream, drop all extra metadata. Bound
  native DATA/trailer events; keep original completion even as current handle
  becomes resolved. No raw exception retention or private process inspection.
- [ ] Freeze; parent runs client/envelope/accounting GREEN and existing public
  completion regressions. Confirm any required pinned public option from public
  source/contracts; missing upstream capability routes an issue and blockers.

## Task 5: Pre-Session integration and finite controls (C)

**Files:** HTTP/Session/Headers and integration/lifecycle/Headers tests.

- [ ] Write RED for pure raw+compiled config initialization, supported handle
  protocols and resources(), unsupported dedicated H2/group H2/H3 combinations,
  exact URI/limits/override rejection. Update old fixed-H1 tests only where
  their blanket non-H1 rejection overlaps newly authorized managed H2; retain
  every H1, managed-H3, dedicated-H2 and malformed-input assertion.
- [ ] Write RED observing Session startup arguments before child creation:
  exactly eight request keys, no Exchange/policy/arbitrary limits/path/query/
  manifest; raw compact Content-Length survives nil-body preflight. Test length
  first/middle/last with supplied/generated Content-Type and both protocols;
  actual-PID preparation rejects invalid effective heads before Fetch bytes.
- [ ] Write RED for activation->authenticated checkout->upload creation->Fetch
  ->original completion bind->ready ordering, no pre-admission producer/bytes,
  exact captured-pin/handoff identities and cleanup on each pre-bind rejection.
- [ ] Write RED for request/selector/awaiting/opening payload release after bind,
  one poll timer, <=4 existing actor monitors, nil group, finite control fields,
  no retained full Response, repeated terminal/error messages and no new queues.
  Verify one scalar/control shell is charged once and dedicated payload charges
  survive handoffs. Check signed64 arithmetic before timer creation.
- [ ] Retain managed_path:true after clearing managed_transport payload; assert
  settle still awaits original completion and complete_service checks receipt,
  while submitted_url remains one separately charged request-slot binary until
  head/cleanup. Test both first-response polling and task-message delivery with
  tuple context, plus mismatched Response URL and repeated cleanup.
- [ ] Write RED for bounded Headers token preflight before split/dedup/join,
  allowed/dropped policy schemas and safe declarations; preserve forbidden/
  untrusted filtering and ordered duplicate trailer policy. Verify declaration
  names stay in Exchange.response_trailers/FramedResponse through downstream
  completion/cleanup. Renderer allowance owns encoded head; source request slot owns URL/
  target assembly without an extra simultaneous representation.
- [ ] Freeze C; parent observes RED. Implement minimal dispatch/integration
  branches using the A/B APIs. Before start_child, construct validated compact
  envelope and request reserve; retain raw source fields. Bind original
  completion before ready and clear opening payloads afterward. Keep H1/H3
  branches and exact negative uncertainty behavior through narrow guards.
- [ ] Use one tracked poll timer, cleared when firing; do not schedule a second
  poll during pending cleanup. Apply exact event/control normalization and
  logical/backing checks before Session caches and pump handoffs. Existing
  full downstream write path controls ACK; frame size remains16KiB.
- [ ] Freeze C; parent GREEN includes new pure/integration/lifecycle tests and
  affected H1/H3 compatibility, with no skip/exclusion/relaxed assertion.

## Task 6: Independent fixed-endpoint network matrix (parent)

Before peer execution, parent owns a tests-first public renderer repair:

- [ ] Write/observe RED in managed_proxy_renderer_test.exs for H1 nested
  rendered iodata and H2 public HPAX return/block/frame queue limits. Enforce
  finite proper iodata byte/binary leaves, <=8,192 nodes/depth16, backing/logical
  <=65,536 before serialization/conversion/send. H1 complete head<=81,920;
  H2 returned iodata<=131,072, compact block<=65,536, at most four16KiB header
  frames per block, full frame-list/queue projection<=73,728 and at most two
  request-owned final/trailer projections. Reject duplicate terminal emissions.
- [ ] After RED, add minimal guards in HTTP1.Response/H2Connection and qualify
  full-write return/queue release. Use existing Service attach_cleanup seam,
  not a new owner: reserve9,444,956 including renderer524,288. Remove the
  formerly proposed B(65,536) encoded-head proxy scratch charge to avoid double
  count. H1 sum233,478 and H2 sum348,166 fit524,288; assert all subcaps and
  complete projections rather than rely on observed normal size. Preserve
  per-stream and shared control ordering and existing backend native boundaries.
- [ ] Freeze; parent GREEN includes renderer tests and affected H1/H2 response,
  stream flow-control, frame/write and H3 FramedResponse compatibility. Preserve
  failed/blocked receipts and fresh independent review; no native/private proof.

**Files:** New peer and collector plus new fixed endpoint tests. Keep existing
63 public assertions/collector and old0.21.3 supplement/evidence byte-identical.

- [ ] Add a real Python h2 peer over TLS or TCP, with finite line-delimited JSON
  commands/events, bound socket deadlines, protocol counters and explicit joins.
  Control commands are `release_head`, `release_data`, `release_upload_eof`,
  `reset_stream`, `goaway`, `close`; events identify accepted connection, exact
  ALPN, authority/path, ordered fields/trailers, upload bytes before EOF, stream
  ID, DATA delivery, reset/GOAWAY, peer EOF and stopped child. Never simulate
  Fetch or use Gaoxy as both upstream peer and acceptance oracle.
- [ ] Add four unfiltered matrix cohorts with explicit protocol selectors:
  downstreamH1/TLS-H2, H1/h2c, downstreamH2/TLS-H2, H2/h2c. Use native Gaoxy H2
  downstream via an independent Python h2 client, not a hidden production
  server adapter. Make each case assert exact request/response bytes and finite
  public cleanup rather than HTTP status alone.
- [ ] Cover exact h2/no fallback and wrong CA/name; numeric address preserves
  authority/SNI. Test sequential reuse plus simultaneous streams, two connection
  capacity,32 active request limit/zero pending, refused33rd request/no replay,
  reset/GOAWAY failure with healthy sibling progression. Coordinate saturation
  via observed peer stream IDs/barriers; do not infer refusal from a timeout.
- [ ] Cover escaped target/present empty query, ordered duplicate heads and
  trailers, pre-EOF upload, valid early final stopping producer, manual redirect,
  encoded compression and unchanged CL, HEAD/204/205/304. Record exact original
  completion and final cleanup per cell.
- [ ] Cover exact/over response heads, trailer129, informational limits and
  declarations. Native-valid inputs above adapter limits must actually reach
  the adapter where feasible; malformed/native-rejected cases remain distinct.
  Unit injections independently cover unrepresentable/forged/backing cases.
- [ ] Collector captures source/build/lock before and after; loaded BEAM/native
  identity in each actual VM; toolchain/Python h2 and separate CLI/Python OpenSSL
  versions; exact command/exit/counts, each public result, zero exclusions/skips,
  EOF and joined peer helpers. A counted case must execute its assertions;
  marker-only output is insufficient. Preserve63 actual public cases separately.
- [ ] Run separate local browser acceptance with Chrome DevTools skill: native
  Gaoxy TLS/h2 downstream and test fixed TLS-H2 peer; navigate /probe, fetch
  streamed /stream and /early, verify network protocol h2 and exact visible/
  fetched bytes, plus bounded wrong-name/CA upstream error without replay.
  Record network/console/screenshots or trace and public cleanup/peer joins.
  Use test-only certificate SPKI trust scope where needed; no operational cert,
  global trust or public management. Browser unavailability is BLOCKED_ENV,
  not a Python-peer or unit-test substitute.

## Task 7: Deterministic backpressure, failure and release order (C/parent)

- [ ] Write/observe RED for a real controlled downstream-write barrier: send a
  valid >16KiB DATA event, withhold the full write, observe no public ACK and
  no next DATA. Release write, observe one ACK then next DATA. Fail after a
  partial piece and assert cancellation/no ACK/no retry/replay/second response.
  Use barrier messages and bounded polling, never arbitrary sleeps.
- [ ] Cover upload/producer death, downstream cancel, unread body, open/idle/
  write/total timeout, Session/transport owner/native actor/instance death, both
  pre-head and post-head failure semantics, repeated cleanup calls and late
  handoff after shortened deadline. Every owned helper must finish or retain
  an explicitly unconfirmed failure receipt.
- [ ] Hold original public completion pending with the deterministic public
  peer/consumer barrier; verify transport token1/request pin1/Service reserve
  remains. Consumption/task DOWN/terminal event alone never frees it. Release
  barrier and observe original completion ->owner finish->pins release->Service
  receipt->Session DOWN. Capture all identities; current handle substitution
  cannot replace the original completion.
- [ ] Verify one completed request releases its request holds while the healthy
  sibling/shared physical connection survives. Retire final owner scope with
  public receipt, physical peer EOF and all owned helper joins, recording owner
  physical vs request vs Service ledgers separately. Wrong CA/name uncertain
  completion is recorded as actual failure/unconfirmed, not a fabricated success.
- [ ] Freeze; parent GREEN runs lifecycle/peer matrix. Diagnose any regression,
  preserve RED/failed receipts and record repairs; never lower assertions.

## Task 8: Independent reviews and fresh scoped verification

- [ ] Freeze ALL source/docs/tests/collectors. Parent creates candidate manifest
  with exact hashes, baseline/diff and full gate coverage. Independent SPEC
  review first checks every design/acceptance item against executed evidence.
- [ ] Resolve SPEC findings, retain failures/counters, re-freeze and rerun
  affected checks. Independent CODE then checks exact envelope/owner identities,
  opaque accounting/copy multiplicities, preflight-before-serialization, original
  binding and every failure/ACK/cleanup release path. No automatic Astra review.
- [ ] Resolve actionable CODE findings; independent re-review as needed. Parent
  runs fresh post-review format, strict compile, all scoped checks and real peer
  qualification with all writers frozen and source stable. Do not reuse earlier
  green results as the final gate after a later source change.

Commands below are **future parent commands**, not executed by this document
writer. Run from the actual worktree after source freeze; keep each independent
runtime command serial and capture stdout/stderr, environment, hashes and exit.
First use the new tests for RED, then for GREEN; expected RED is nonzero tests
with the missing implementation/assertion failure, GREEN requires zero failures.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_client_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_client_test.exs apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/http_headers_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs apps/gaoxy_proxy/test/managed_h2_client_test.exs apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_preparation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs apps/gaoxy_proxy/test/http_headers_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/upstream_transports_test.exs apps/gaoxy_proxy/test/upstream_transport_identity_test.exs apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/upstream_group_transport_test.exs apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs apps/gaoxy_proxy/test/upstream_group_tls_test.exs apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs apps/gaoxy_proxy/test/http_fetch_contract_test.exs apps/gaoxy_proxy/test/http_proxy_runtime_test.exs apps/gaoxy_proxy/test/http_proxy_wire_test.exs apps/gaoxy_proxy/test/http_proxy_tls_test.exs apps/gaoxy_proxy/test/http3_session_client_test.exs apps/gaoxy_proxy/test/http3_guardian_test.exs apps/gaoxy_proxy/test/http3_proxy_test.exs apps/gaoxy_http3/test/proxy_test.exs apps/gaoxy_http3/test/headers_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test python integration/http_fetch_contract/h2_0214_qualification.py --evidence "$GAOXY_H2_FIXED_PUBLIC_EVIDENCE"
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test python integration/http_fetch_contract/managed_h2_fixed_qualification.py --evidence "$GAOXY_H2_FIXED_MATRIX_EVIDENCE"
```

The parent defines the two task-specific evidence paths before executing each
collector. The new fixed collector implements the exact `--evidence PATH` CLI;
it writes source identities, cell/case outcomes, counts and joins to
`qualification.json`, and exits0 only for complete matrix success. No expected
activation count is invented: report discovered executable test/case counts,
require >0 and all prescribed cases. The unchanged public gate requires63/0.
When a shared Session/Headers change affects another H3 lifecycle/header seam,
add that exact affected test to fresh scope with reason; do not silently broaden
to unrelated suite cleanup. Upstream defects follow repo issue routing and
blocker policy. `http_fetch#97` is never a gate. A hosted no-start stays
BLOCKED_ENV, without spending/settings requests.

Mandatory additional fresh checks for the two demonstrated compatibility seams
(and the exact production/test files owned there):

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_http/lib/gaoxy/http/endpoint.ex apps/gaoxy_http/lib/gaoxy/http/generation.ex apps/gaoxy_http/lib/gaoxy/http/http1/response.ex apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex apps/gaoxy_http/test/managed_proxy_renderer_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs apps/gaoxy_http/test/managed_proxy_renderer_test.exs apps/gaoxy_http/test/generation_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_release_deadline_test.exs apps/gaoxy_http/test/generation_loader_test.exs
```

Parent records the exact affected HTTP1/HTTP2 renderer/connection/flow-control
test paths in the kickoff manifest after inspecting the current inventory, and
runs them unfiltered; these seam tests do not replace required wire/TLS/browser
or the broad named proxy/H3 compatibility cohort above. New tests use tests-first
RED before guards; all required fresh format/compile/peer/browser gates follow
complete independent SPEC/CODE, with actual discovered counts, no guessed pass.

## Task 9: Local closure and next bounded stage

- [ ] Parent updates acceptance with actual predecessor/candidate source and
  environment, exact counts/exits/source stability, passing SPEC/CODE identities,
  actual cleanup uncertainty if any, owner/request reserve and final peer joins.
  Do not tick a required case that failed, was blocked or did not execute.
- [ ] Verify all parent commands stopped safely and no writer/runtime overlaps.
  Stage only task-owned files after full passing fresh gates, and make local
  conventional commit `feat(proxy): activate managed H2 fixed endpoints`; omit
  generated-by/co-author trailers. Record actual commit and preserved inventory.
- [ ] Report fixed-endpoint slice DONE only if every required acceptance item
  passes. Automatically prepare the next written managed-H2 groups/probes plan
  under continuing authorization; then execute it after its independent
  readiness. Keep later Generation, standalone and load claims separate.
  No push/release/deployment/E2E activation is inferred from this local commit.
