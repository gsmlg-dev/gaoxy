# Managed H2 Upstream Upload-Credit Control Implementation Plan

Status — 2026-10-18: **LOCAL QUALIFICATION PASS; final document review and local commit pending at this frozen precommit checkpoint.**

All eight fixed/group × native H1/H2 × upstream h2c/TLS-H2 credit-resume cases
completed in the initial unfiltered trace: 54 tests/0 failures. Complete frozen
source SPEC24/24→CODE20/20 and implementation SPEC18/18→CODE16/16 passed with
zero findings. Fresh defining/lifecycle/Generation scopes passed 54/0+142/0+176/0
(372 invocations, not unique tests). Strict compile, six-file format and active
Python/extracted-JavaScript syntax passed as static0. Python11 actual startup
methods, isolated Core1/0 and HTTP2/0, and browser2 current group rows/four
root-viewed OLD/NEW PNGs passed separately.

Evidence is `docs/acceptance/evidence/m3/managed-h2-upstream-credit/1792255123095252006`.
`final-nonbrowser-audit1.json` (SHA256 `2bb03cf8983c624571c33765bdb3d6242f8f76d0686fa3697ede4f8479d0fc0d`)
verifies all nine final command/log/exit/process receipts and stable402 source pins.
`browser-root-audit1.json` (SHA256 `082cf86923b0c5ba04ee58f6e97ad58185f514d2be8be2040e18865ae7b7cfed`)
verifies outer400/inner287 matching source subsets,54 artifacts,204 loaded records
(194 disk source/BEAM bindings and10 inline source/module-MD5 records),12 named
nonforced Actor joins, raw deletion, retirement/zeroing and listener rebind.
All top-level final commands exited0/nonforced with no remaining owned processes.
The32 genuine adopted nonbrowser waits are15 raw0 and17 raw10 (decoded−10/SIGUSR1);
the12 browser adopted waits are10 raw0 and2 raw10. Named Actors and peer fixtures
retain their own actual exit checks; adopted helpers are not described as all exit0.
Four final public trust paths are46-byte invalidation markers, not certificates.

Only the peer and streaming test sources changed; production, deps, F/G fixture
helpers and the original11 Python methods remain unchanged. Original eight prefix
cases and the complete assert_held body are preserved. HTTP Fetch remains0.21.10.
No runtime/fixture/Sol repair or artificial RED occurred. Current counter6 retains
root376/orchestration282/creditTool24, including one audit-tool draft correction
before execution; preparatory failedSPEC2/draftrepairs2 and exhausted Astra2/2
remain recorded. These tooling/draft counts are separate from runtime failures.

Historical entry documents are exact archives in `final-document-before-inventory1.json`.
`final-document-context-rebind1.json` resolves the reviewed proposal3 active16 inputs
as11 unchanged live inputs,2 original-source archives and3 document archives.
The source candidate's three entry-document hashes remain historical checkpoint
hashes; the current eight final documents are separately pinned in the final
document candidate. No runtime receipt is rewritten or inferred from document edits.

> **For agentic workers:** Use executing-plans or parent-managed subagent-driven-development task by task. Root alone owns repository/evidence/Git/runtime. Workers own explicit temporary proposals/reviews. Preserve other writers and serialize dependent operations. Implementation/runtime gates below are complete; final document review, local commit/custody and the separate follow-up remain pending at this checkpoint.

**Goal:** Eight real-network successful uploads prove actual zero upstream stream credit, original ownership while held, explicit credit release, exact bytes/trailers and complete cleanup.

**Architecture:** Add an opt-in one-byte receive-window mode and explicit release command to the existing independent peer. Extend the current streaming test module using its original ownership assertions and unchanged F/G fixtures. Do not modify production/deps or create an extra peer/parser/process.

**Tech Stack:** Current pinned Nix/Elixir/OTP, existing F/G real native sockets/HPAX, existing Python h2 venv and public hyper-h2 settings/window APIs. No new dependency.

Historical entry snapshot — 2026-10-18: predecessor prefix closed at local commit `29d4fe7ba640b90dcc0502e8cfaec5fbe4b6af40`. Final document SPEC18/18→CODE21/21, exact195task blobs and402command-source pins passed. Custody is `docs/acceptance/evidence/m3/managed-h2-upstream-credit/1792255123095252006/prefix-postcommit-custody1.json`. Credit preparatory SPEC19/19→CODE20/20 passed with zero findings. Credit implementation/runtime are NOT RUN. Current entry counters are `docs/acceptance/evidence/m3/managed-h2-upstream-credit/1792255123095252006/counter1.json`: root359/orchestration265/creditTool8; preparatory failedSPEC2/draftrepairs2, credit runtime/fixture/Sol0 and exhausted Astra2/2 are retained. The preparation baseline below remains historical; the actual entry/source rebind is recorded by stage-entry1.json.

Document-context binding: root `docs/acceptance/evidence/m3/managed-h2-response-prefix/1792251316888813330/credit-preparation-document-rebind1.json` (SHA256 `e656e2724d3e6fdf6d52390afb247511796a47e9ef6e42ddd1e3fdcaf548d659`) preserves original16 inputs as13 unchanged live inputs plus3 exact archived original docs, and separately pins the current3 canonical docs at the prefix final candidate. Proposal3 records both inventories; it does not claim16 original live inputs unchanged. Actual successor HEAD/source context is captured in stage-entry1.json after the verified prefix local commit/custody; the16 accepted preparatory input bytes remain unchanged at entry.

## Task0: Draft review, real predecessor closure and exact entry

Files at actual entry: `docs/designs/m3-managed-h2-upstream-credit.md`, `docs/plans/m3-managed-h2-upstream-credit.md`, `docs/acceptance/m3-managed-h2-upstream-credit.md`, dedicated `docs/acceptance/evidence/m3/managed-h2-upstream-credit/` and the two source paths named below.

- [x] Independently review the complete preparatory design/plan/acceptance against current source: SPEC then CODE. Resolve actionable findings without weakening the barrier/assertions.
- [x] Wait for actual prefix final gates, document reviews, local conventional commit and committed-byte custody; do not mark these from the parent-reported first46/0 result. Capture exact new HEAD/branch, prefix immutable closure receipts, active source inventory and counters at actual entry.
- [x] Re-read/re-pin all task sources; require accepted predecessor bytes or adapt the written proposal before implementation. Freeze original source/command inventory and finite collector names/budgets. Never blindly reuse old401/source counts or guess a browser runner path.
- [x] Promote reviewed drafts only after actual entry. Keep prior evidence, unrelated edits, publication/deployment restrictions, Vault/account/public management/E2E restrictions and exhausted counters unchanged.

## Task1: Implement the opt-in peer protocol seam

Modify ONLY `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`. No modification to installed h2 code. The code blocks below preserve the reviewed implementation specification, now realized in the current source. Preserve the rest of each surrounding function byte-for-byte except necessary formatting.

- [x] Extend the existing constructor and argument wiring with a default-off boolean, preserving positional compatibility:

```python
# Peer.__init__ signature and assignment:
def __init__(self, protocol, manual, alpn, max_streams=None,
             bind_address="127.0.0.1", listen_port=0, hold_upload_credit=False):
    self.protocol, self.manual, self.alpn = protocol, manual, alpn
    self.hold_upload_credit = hold_upload_credit

# main(), beside existing --manual argument:
parser.add_argument("--hold-upload-credit", action="store_true")

# Replace only current main() Peer(...) constructor call:
peer = Peer(args.protocol, args.manual, args.alpn, args.max_streams,
            args.bind_address, args.listen_port, args.hold_upload_credit)
```

The constructor snippet edits only the shown signature/assignments and leaves all following constructor lines intact. Add `credit_holds=set(), credit_released=set()` to the existing per-client dict in accept. No additional worker or timer is introduced.

- [x] Replace the existing `if self.max_streams is not None` local-settings block in serve, before unchanged initiate_connection:

```python
initial_values = dict(conn.local_settings.items()) if self.hold_upload_credit else {}
if self.max_streams is not None:
    initial_values[h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS] = self.max_streams
if self.hold_upload_credit:
    initial_values[h2.settings.SettingCodes.INITIAL_WINDOW_SIZE] = 1
if initial_values:
    conn.local_settings = h2.settings.Settings(client=False, initial_values=initial_values)
```

Hold mode copies all current public settings before overriding only INITIAL_WINDOW_SIZE and any explicitly supplied max-streams value. This retains the installed connection defaults MAX_CONCURRENT_STREAMS100 and MAX_HEADER_LIST_SIZE65536 when max-streams is absent; an explicit max-streams value replaces only that copied value. With hold mode off, start from the original empty dict: no max-streams leaves the original H2Connection settings untouched, while explicit max-streams recreates Settings exactly as the existing peer already does. Do not independently alter that pre-existing max-streams behavior. Public Settings is a MutableMapping whose items expose current values; constructing new Settings with initial_values installs those values immediately before initiate_connection, unlike assigning pending values through its setter. The connection-level receive window remains its normal positive value; INITIAL_WINDOW_SIZE controls streams. Health HEAD has no DATA. The new mode is used only together with --manual in the eight tests.

- [x] Replace the existing unconditional DATA acknowledge line, AFTER existing upload append/bound/hash event, with this complete branch:

```python
held_target = (self.hold_upload_credit and
               client["targets"][event.stream_id] == "/hold/upload-credit")
if held_target and event.stream_id not in client["credit_released"]:
    if (event.stream_id in client["credit_holds"] or len(upload) != 1 or
            event.flow_controlled_length != 1 or event.stream_ended is not None or
            conn.remote_flow_control_window(event.stream_id) != 0 or
            conn.inbound_flow_control_window <= 0):
        raise RuntimeError("fixture upload did not reach exact stream-credit hold")
    client["credit_holds"].add(event.stream_id)
    self.emit("upload_credit_held", connection=number, stream=event.stream_id,
              total_bytes=len(upload), held_bytes=event.flow_controlled_length,
              stream_window=conn.remote_flow_control_window(event.stream_id),
              connection_window=conn.inbound_flow_control_window,
              sha256=hashlib.sha256(upload).hexdigest())
else:
    conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
```

This uses actual DATA flow length and real public peer window observations. It never invents a Gaoxy charge. An empty/padded/wrong-sized first DATA fails the narrowly defined fixture contract visibly. Default mode executes the exact old acknowledge path.

- [x] At the start of the existing TrailersReceived branch insert the following guard, leaving the existing upload_trailers emit unchanged:

```python
if (self.hold_upload_credit and
        client["targets"][event.stream_id] == "/hold/upload-credit" and
        event.stream_id not in client["credit_released"]):
    raise RuntimeError("fixture upload trailers preceded credit release")
```

- [x] Replace only the existing upload_end emit at the beginning of StreamEnded with:

```python
upload_values = dict(total_bytes=len(client["uploads"].get(event.stream_id, b"")))
if (self.hold_upload_credit and
        client["targets"][event.stream_id] == "/hold/upload-credit"):
    if event.stream_id not in client["credit_released"]:
        raise RuntimeError("fixture upload end preceded credit release")
    upload_values["body64"] = base64.b64encode(
        client["uploads"].get(event.stream_id, b"")).decode("ascii")
self.emit("upload_end", connection=number, stream=event.stream_id, **upload_values)
```

Keep the existing automatic-response conditional following that emit intact. Only the new opt-in target gains body64; the actual test body is two bytes and all original event/body bounds remain enforced.

- [x] Replace only the current two-line settings_ack emit in SettingsAcknowledged with:

```python
settings_values = dict(max_streams=conn.local_settings.max_concurrent_streams)
if self.hold_upload_credit:
    settings_values["initial_window"] = conn.local_settings.initial_window_size
self.emit("settings_ack", connection=number, **settings_values)
```

Keep the existing control event immediately afterwards. Default event shape stays unchanged.

- [x] Add one explicit command branch before the existing settings branch, inside the existing lock:

```python
elif op == "release_upload_credit":
    if (not self.hold_upload_credit or value.get("credit_bytes") != 1 or
            client["targets"].get(stream) != "/hold/upload-credit" or
            stream not in client["credit_holds"] or
            stream in client["credit_released"] or
            conn.remote_flow_control_window(stream) != 0 or
            conn.inbound_flow_control_window <= 0):
        raise RuntimeError("fixture upload-credit release outside exact hold")
    conn.increment_flow_control_window(1, stream)
    conn.increment_flow_control_window(1)
    client["credit_released"].add(stream)
```

Keep the existing shared self.flush and all write-half-close/control handling. Immediately before the existing final command emit construct `credit_values`, then add its expansion to that emit:

```python
credit_values = {"credit_bytes": 1} if op == "release_upload_credit" else {}
self.emit("command", op=op, connection=value["connection"], stream=stream,
          command_id=value.get("command_id"), code=value.get("code"),
          last_stream=value.get("last_stream"), max_streams=value.get("max_streams"),
          **credit_values)
```

The ACK follows the actual shared socket sendall. A duplicate release is FAIL. This is the entire new control surface; no invented unimplemented helper is assumed.

## Task2: Add the exact eight native-wire transactions

Modify ONLY `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`. Retain its `Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)`, aliases, capture_log convention and all eight original response-prefix cases. F is loaded by the same Mix invocation; do not require the endpoint test file from another test. No new timeout/tag/filter/skip.

- [x] Replace the existing private fixture/3 clauses with this backwards-compatible argument seam:

```elixir
defp fixture(mount, upstream, downstream, peer_options \\ ["--manual"])
defp fixture(:fixed, upstream, downstream, peer_options),
  do: F.fixture(upstream, downstream, peer_options)
defp fixture(:group, upstream, downstream, peer_options),
  do: G.fixture(upstream, downstream, peer_options)
```

Replace only the `capture_holds/4` definition head and its submitted_url assertion; every other original ownership assertion and `assert_held/5` body remains intact:

New definition head:

```elixir
defp capture_holds(mount, f, guardian, completion, target \\ "/hold/response-prefix") do
```

New submitted_url assertion inside its unchanged full body:

```elixir
assert state.submitted_url === f.origin <> target
```

These two lines are surgical edits to the full current helper. Preserve nonempty pin checks, authentic public pin ledger equality, T/G refs, completion/request/selected-handle identities and group inflight/reserve/exact-controls assertions unchanged.

- [x] Add this complete private header-opening helper:

```elixir
defp hold_upload(mount, f, target) do
  socket = F.connect(f)
  fields = [{"trailer", "x-check"}] ++
    if(f.downstream == :http1, do: [{"transfer-encoding", "chunked"}], else: [])
  :ok = F.send_request(f, socket, "POST", target, fields, false)
  seen = F.event(f.peer, "request")
  assert seen["target"] === target
  assert [":method", "POST"] in seen["headers"]
  assert seen["ended"] === false

  F.eventually(fn ->
    Enum.any?(:sys.get_state(f.owner).tokens, fn {_, held} ->
      match?(%HTTP.RequestCompletion{}, held.completion) and
        :sys.get_state(held.guardian).submitted_url === f.origin <> target
    end)
  end)

  if mount == :group, do: F.eventually(fn -> G.held_selection(f, target) != nil end)
  [{_, held}] = Map.to_list(:sys.get_state(f.owner).tokens)
  {socket, seen, held.guardian, held.completion}
end
```

- [x] Add this complete test block at module level, separate from the existing prefix describe blocks:

```elixir
for mount <- [:fixed, :group] do
  describe "#{mount} managed H2 upload credit" do
    if mount == :group do
      setup do
        assert :ok === boundary(:activation)
        :ok
      end
    end

    for downstream <- [:http1, :http2], upstream <- [:h2c, :http2] do
      @credit_mount mount
      @credit_downstream downstream
      @credit_upstream upstream
      test "#{downstream} -> #{upstream} holds exhausted upload credit then resumes exact body and ordered trailers" do
        body = <<0, 255>>
        prefix = <<0>>
        trailers = [{"x-check", "first"}, {"x-check", "second"}]
        f = fixture(@credit_mount, @credit_upstream, @credit_downstream,
          ["--manual", "--hold-upload-credit"])
        {socket, seen, guardian, completion} =
          hold_upload(@credit_mount, f, "/hold/upload-credit")
        connection = seen["connection"]
        stream = seen["stream"]
        held = capture_holds(@credit_mount, f, guardian, completion, "/hold/upload-credit")

        assert %{"connection" => ^connection, "initial_window" => 1} =
          F.event(f.peer, "settings_ack")
        if @credit_upstream == :http2,
          do: assert(%{"connection" => ^connection, "alpn" => "h2", "sni" => "localhost"} =
            F.event(f.peer, "tls"))

        if @credit_downstream == :http1 do
          :ok = :gen_tcp.send(socket,
            ["2\r\n", body, "\r\n0\r\nX-Check: first\r\nX-Check: second\r\n\r\n"])
        else
          :ok = F.send_body(f, socket, body, false)
          {block, _} = HPAX.encode(:never_store, trailers, HPAX.new(4_096))
          :ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
        end

        assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 1} =
          F.upload_through(f.peer, seen, prefix)
        prefix_hash = Base.encode16(:crypto.hash(:sha256, prefix), case: :lower)
        assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 1,
                 "held_bytes" => 1, "stream_window" => 0,
                 "connection_window" => connection_window, "sha256" => ^prefix_hash} =
          F.event(f.peer, "upload_credit_held")
        assert connection_window > 0
        assert_held(@credit_mount, f, held, guardian, completion)

        assert %{"op" => "release_upload_credit", "connection" => ^connection,
                 "stream" => ^stream, "credit_bytes" => 1} =
          F.command(f.peer, seen, "release_upload_credit", %{"credit_bytes" => 1})
        assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 2} =
          F.upload_through(f.peer, seen, body, 1)
        assert %{"connection" => ^connection, "stream" => ^stream,
                 "fields" => [["x-check", "first"], ["x-check", "second"]]} =
          F.event(f.peer, "upload_trailers")
        body64 = Base.encode64(body)
        assert %{"connection" => ^connection, "stream" => ^stream,
                 "total_bytes" => 2, "body64" => ^body64} = F.event(f.peer, "upload_end")

        assert %{"op" => "respond", "connection" => ^connection, "stream" => ^stream} =
          F.command(f.peer, seen, "respond", %{
            "status" => 200, "body64" => body64,
            "fields" => [["content-type", "application/octet-stream"], ["trailer", "x-check"]],
            "trailers" => [["x-check", "first"], ["x-check", "second"]], "ended" => true
          })
        result = F.response(f, socket, "POST")
        assert result.status === 200
        assert result.body === body
        assert result.trailers === trailers
        assert {"content-type", "application/octet-stream"} in result.headers
        if @credit_downstream == :http1,
          do: assert({"transfer-encoding", "chunked"} in result.headers)
        :ok = :gen_tcp.close(socket)
        clean(@credit_mount, f)
        assert :ok = HTTP.RequestCompletion.await(completion, 0)
        close(@credit_mount, f)
      end
    end
  end
end
```

- [x] Self-review the complete proposed sources: all original prefix assertions/default helper behavior unchanged; actual same-connection ACK precedes body; the full native body/trailers submission precedes held observation; barrier is real public peer zero-stream/positive-connection state; release follows original pending ownership reads; exact suffix/trailers/EOF precede success response. Check all eight new names and mode-off byte/behavior equivalence. Freeze exact sources and recomputed source/BEAM/command map. Complete independent source SPEC then CODE before any runtime.

## Task3: First genuine qualification and compatibility

Root only, after entry and source reviews, through the existing accepted finite custody collector with new immutable names and unchanged600s outer deadline. No artificial RED. Each actual new case must execute, with trace preserving identity/outcome; do not predict whole-suite counts.

- [x] First qualification:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --trace --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [x] Fresh scoped request/response/lifecycle compatibility:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [x] Fresh fixed/group Generation/helper compatibility:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

Real missing ACK/held event, timeout, bad window/byte/trailer/ownership/cleanup is FAIL. Preserve receipts and unchanged assertions/clocks; bounded authorized Sol diagnosis retains counters. Listed-org dependency blockers follow upstream routing, never a deps patch. Unrelated outside-scope failures stay visible; do not fix them under this slice. No extra stage entry or unlimited recovery follows.

## Task4: Independent implementation review and fresh acceptance

- [x] Bind exact source/command/log/process receipts, actual eight case names/counts and nonforced joins. Complete implementation SPEC then CODE, resolving actionable findings. Freshly repeat all three scoped payloads after reviews; source freezing and substantive repairs require rebinding, not stale receipt reuse.
- [x] Fresh strict compile and changed Elixir source format:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [x] Syntax-check the active changed Python source without creating pycache; this is static validation, not an executed test count:

```sh
nix develop --command /tmp/gaoxy-m3-h2-soak-venv/bin/python -B -c 'import ast, pathlib; p=pathlib.Path("apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py"); ast.parse(p.read_text(), filename=str(p)); print("peer syntax PASS")'
```

- [x] Independently exercise the unchanged existing11-method real peer-startup suite; preserve all assertions and count its actual methods separately. The eight native cases exercise the new peer mode; startup regressions protect default startup/ownership paths.

```sh
nix develop --command /tmp/gaoxy-m3-h2-soak-venv/bin/python -B apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py -v
```

- [x] Run unchanged isolated consumer scripts, each through the same accepted600s finite collector and environment. Keep real dependency-fetch blockers explicit; an approved local object transport is separately qualified environment evidence, never a production repair.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer bash scripts/external-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer bash scripts/http-consumer.sh
```

- [x] At actual entry copy and hash the accepted prefix browser runner/cohort/collector and its exact command inventory into new immutable evidence names, then rebind all active source/BEAM/argv pins before launch. Run its unchanged fresh two nativeH1/H2→TLS-H2 group rows and four OLD/NEW image opens by root, original deadlines/caps/cohort joins/nonforced custody and safe raw-data deletion. Browser validates the current native/group boundary; it is not eight temporal credit tests. No new browser code or guessed historical tool path is authorized by this preparation.
- [x] Record actual nonzero ExUnit counts and all eight new outcomes, zero failure/skip/exclusion/product warnings; static0, Python11, isolated Core1/HTTP2 and browser2rows remain distinct scoped evidence. Preserve exact command exits, original adopted waits, all reader/actor/group/peer joins and active-source stability. No broad repository tests/autofixes.

## Task5: Factual local closure and separate follow-up

- [x] Fill acceptance from actual immutable receipts; update design/plan and narrow parent-plan status factually. Keep full Task6 and combined exhaustion→early-final/cancellation, downstreamRST+sibling/fullH1matrix/multi-owner/selectedA/load/H3 explicitly open. No stage completion can be inferred from this positive success test alone.
- [ ] Complete final document SPEC then CODE, changed-file checks and source/count inventory. Root stages only task-owned files for a local conventional commit after every required gate passes. Audit disk/index/blob bytes and exact committed-source/evidence custody against actual successor HEAD. Preserve unrelated files; no push/release/deployment follows.
- [ ] Prepare the next separate combined early-final-at-exhaustion design from this actual successful barrier only after closure, retaining independent reviews/counters and all product boundaries. No current plan silently expands into cancellation/unsent-trailer or live-sibling execution.
