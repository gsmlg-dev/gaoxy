# Managed H2 Positive Response Prefix Implementation Plan

> **For agentic workers:** Use executing-plans or parent-managed subagent-driven-development task by task. Root alone writes repository/evidence/Git and runs tests/build/browser. Independent workers own explicit read-only review outputs. Root serializes dependent changes; nobody reverts others. All boxes remain unchecked until actual evidence.

**Goal:** Eight real-network fixed/group × nativeH1/H2 × h2c/TLS cases observe exact positive response bytes before upstream suffix/trailer/END_STREAM release, then complete with original ownership and cleanup.

**Architecture:** Reuse existing manual independent peer commands and fixed/group fixtures. Add an optional progress callback to the existing fixture decoder and keep the deterministic release inside the exact-prefix callback. Add a focused new test file, not a production parser or process.

**Tech Stack:** Current pinned Nix Elixir/OTP, existing Gaoxy HTTP/HTTP2 fixture, HPAX, existing h2 Python peer/venv, real native downstream sockets. No dependencies added.

## Task0: Actual entry and draft adoption

Files: this draft; canonical proposed design `docs/designs/m3-managed-h2-response-prefix.md`, plan `docs/plans/m3-managed-h2-response-prefix.md`, acceptance `docs/acceptance/m3-managed-h2-response-prefix.md` and dedicated evidence directory `docs/acceptance/evidence/m3/managed-h2-response-prefix/` only after root entry.

- [ ] Verify actual current group reload closure, independent final document reviews and real local committed-byte custody; record exact resulting HEAD/branch/source. Do not assume the earlier e4a7660b baseline is the new stage's committed entry.
- [ ] Preserve root's unrelated files and all previous evidence. Promote drafts only when their independent SPEC then CODE reviews pass. Keep original failed runs and exhausted Astra2/2/cumulative Sol counters.
- [ ] Freeze task-owned files and actual command inventory before execution. The new streaming test path does not exist yet; create it, do not search for or substitute a guessed existing test.

## Task1: Add the smallest decoder observation seam

Modify only `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` fixture module, at current response360/h1_response394/h1_chunks436/h2_response483. Do not edit unrelated test assertions or Python peer. Existing response/2-/4 calls retain nil observer defaults.

- [ ] Add the optional fifth argument and pass it into the existing parsers:

```elixir
def response(f, socket, method \\ "GET", id \\ 1, progress \\ nil) do
  if f.downstream == :http2 do
    h2_response(socket, id,
      %{status: nil, headers: [], body: "", trailers: [], inform: []},
      "", HPAX.new(4_096), progress)
  else
    h1_response(socket, method, [], progress)
  end
end

defp observed_body(nil, _body, _ended), do: :ok

defp observed_body(progress, body, ended),
  do: progress.(%{body: body, ended: ended})
```

- [ ] Append `progress` to private h1_response/h1_chunks/h2_response signatures and every existing recursive call. Leave all original branches/HPAX/framing/trailer/receive/assertion code intact.
- [ ] In H1 positive-chunk branch, after the existing exact recv and before recursion, replace only `h1_chunks(socket, acc <> bytes)` with:

```elixir
next = acc <> bytes
observed_body(progress, next, false)
h1_chunks(socket, next, progress)
```

  Pass progress from h1_response to h1_chunks and through informational-response recursion. The zero chunk/trailer and Content-Length/HEAD/empty paths stay as before.
- [ ] In existing H2 DATA branch, after `result = %{result | body: result.body <> payload}`, and before existing terminal/recursive branch, add:

```elixir
if byte_size(payload) > 0,
  do: observed_body(progress, result.body, Bitwise.band(flags, 1) == 1)
```

  Existing nonempty DATA flow-credit ACKs remain before this point. Pass progress through every existing recursive branch. Do not modify HEADERS/CONTINUATION/SETTINGS/reset handling or insert callback calls at headers/EOF.
- [ ] Self-review exact default-no-callback equivalence and callback-after-real-read ordering. No callback result changes the response map. Do not generalize a production progress API or add processes.

## Task2: Implement exact eight-case transaction

Create `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`. Require only `support/managed_h2_group_fixture.exs`; defining F is loaded by the frozen command. Use ExUnit.Case async:false, existing capture_log convention, HTTP RequestCompletion, F and G aliases and timeout5000. Generate explicit names across mount [:fixed,:group], downstream [:http1,:http2], upstream [:h2c,:http2]; no tags/filters/skips/timeout override. Use the same authenticated group boundary activation check as existing group endpoint tests for group rows.

- [ ] Define private dispatch helpers `fixture/3`, `hold/3`, `clean/2`, `close/2` that directly call F or G; keep both branch bodies explicit. `F.response` can read either fixture's socket, so no G.response delegate change is needed.

```elixir
defp fixture(:fixed, upstream, downstream), do: F.fixture(upstream, downstream, ["--manual"])
defp fixture(:group, upstream, downstream), do: G.fixture(upstream, downstream, ["--manual"])
defp hold(:fixed, f, target), do: F.hold(f, target)
defp hold(:group, f, target), do: G.hold(f, target)
defp clean(:fixed, f), do: F.clean(f)
defp clean(:group, f), do: G.clean(f)
defp close(:fixed, f), do: F.close(f)
defp close(:group, f), do: G.close(f)
```
- [ ] Define private `capture_holds/4` using actual T state token singleton and guardian state. Capture T ref, selected public handle, guardian/completion and original transport pin list. For group capture actual G ref and selection too. Assert `state.client.completion(state.original_request) === completion`, original `transport_selection`, submitted URL, and request-pin holder/kind exactly as existing fixed endpoint884-929/group endpoint82-133. Never inspect native Fetch processes or serialize RequestCompletion internals.
- [ ] Define `assert_held/5` to re-read the exact captured refs and verify original guardian/completion/selection and required request pins remain; assert public completion pending. Group additionally uses current G token/inflight1 and unchanged G.assert_cleanup(f,1)/G.assert_exact_controls checks. Compare required immutable identities, not the entire evolving owner/token map. At tail completion use existing full clean/close checks rather than invented synthetic zero receipts.
- [ ] Use this exact payload and release schedule in every case (the private helper names above have the specified responsibilities):

```elixir
prefix = <<0, "managed-h2-prefix", 255>>
suffix = <<128, "|suffix", 0>>
trailers = [["x-check", "first"], ["x-check", "second"]]
f = fixture(mount, upstream, downstream)
{socket, seen, guardian, completion} = hold(mount, f, "/hold/response-prefix")
assert seen["target"] === "/hold/response-prefix"
assert [":method", "GET"] in seen["headers"]
connection = seen["connection"]
stream = seen["stream"]
assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 0} =
         F.event(f.peer, "upload_end")
held = capture_holds(mount, f, guardian, completion)
tag = make_ref()

F.command(f.peer, seen, "respond", %{
  "status" => 200,
  "fields" => [["content-type", "application/octet-stream"], ["trailer", "x-check"]],
  "body64" => Base.encode64(prefix), "ended" => false
})

progress = fn %{body: body, ended: ended} ->
  if byte_size(body) <= byte_size(prefix) do
    assert body === binary_part(prefix, 0, byte_size(body))
    refute ended
    if body === prefix do
      assert_held(mount, f, held, guardian, completion)
      send(self(), {:response_prefix_observed, tag, body})
      F.command(f.peer, seen, "data", %{
        "body64" => Base.encode64(suffix), "trailers" => trailers, "ended" => true
      })
    end
  end
end

result = F.response(f, socket, "GET", 1, progress)
assert result.status === 200
assert result.body === prefix <> suffix
assert result.trailers === [{"x-check", "first"}, {"x-check", "second"}]
assert {"content-type", "application/octet-stream"} in result.headers
assert_receive {:response_prefix_observed, ^tag, ^prefix}, 0
refute_receive {:response_prefix_observed, ^tag, _}, 0
:ok = :gen_tcp.close(socket)
clean(mount, f)
assert :ok = HTTP.RequestCompletion.await(completion, 0)
close(mount, f)
```

- [ ] `fixture(:fixed,...)` and `fixture(:group,...)` MUST pass ["--manual"]. No automatic response, second request, suffix producer or external release timer may run. Group fixture's own real health HEAD is separate from the single application GET and existing close counts include it.
- [ ] Require H1 transfer-encoding chunked and actual H2 nonterminal DATA before release. Existing parser returns the terminal response only after suffix and ordered trailers. The observer accepts any positive-fragment segmentation; it runs only for nonempty fragments, making exact prefix observation/release occur once without process-dictionary or Agent state.
- [ ] On an assertion failure preserve the original fixture on_exit cleanup and peer deadlines; do not add early final success, reset-as-success, retry/replay or a silently passing callback. Test-local observation message is evidence of parser control flow, not a manufactured public completion.
- [ ] Freeze complete source, the new exact input map and self-review. Independent full source SPEC then CODE must pass before first runtime. Original peer/control paths remain byte-identical.

## Task3: First genuine positive qualification and compatibility

Root runs only after accepted source freeze, through the existing accepted finite custody collector with new immutable names and600s outer deadline. These are exact payloads; record actual totals and eight actual new test results rather than predicting entire-suite counts. New file must exist at launch. Do not filter defining F or bypass pre-F group boundary checks.

- [ ] First full scope:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [ ] Fresh response/lifecycle compatibility:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [ ] Fresh shared-helper Generation compatibility, retaining current fixed/group reload assertions:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [ ] This qualifies existing production behavior; no artificial RED is needed. A genuine timeout, EOF/trailer mismatch, ownership loss or cleanup failure is FAIL and enters bounded diagnosis with all assertions/clocks unchanged. Any missing dependency capability follows upstream blocker policy; do not patch deps or invent local product behavior.

## Task4: Independent implementation review and fresh acceptance gates

- [ ] Bind original full command/log/source/process receipts and all eight case identities/actual outcomes; independent implementation SPEC then CODE. Distinguish source attestations from actual socket/data checks.
- [ ] Fresh strict compile and exact changed-source format:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [ ] Run the accepted fresh scoped payloads after implementation review. Recompute all active source/BEAM bindings; the old401 map cannot simply be reused after adding a file or changing F. No broad repository tests/autofixes.
- [ ] Preserve prescribed standalone isolation checks via unchanged `scripts/external-consumer.sh` and `scripts/http-consumer.sh` under the same Nix/env/unbuffer wrapper and600s collector budget. Actual clean consumers are distinct from this eight-case claim. Preserve any real external fetch blocker; approved local object transport is separate conditional environment evidence, never a production repair.
- [ ] Existing unchanged peer is independently exercised by all8cases. If stage inventory requires the existing peer-startup gate, use exact current `nix develop --command /tmp/gaoxy-m3-h2-soak-venv/bin/python -B apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py -v` and audit its original11methods separately from ExUnit. Syntax validation only for active copied Python/JavaScript tools; no Python source change is planned.
- [ ] Preserve the required fresh browser verification using the accepted current group browser runner/cohort/collector, rebound to exact next-stage source/command pins and new immutable names before launch. Retain two nativeH1/H2→TLS-H2 rows and root's four OLD/NEW image opens, nonforced custody and safe raw-data deletion. Copy/review exact accepted active tool bytes; do not guess a new browser path or count browser rows as temporal prefix tests. No new browser implementation is needed for this test-only slice.
- [ ] Actual nonzero ExUnit counts, zero failure/skip/exclusion/product warnings, genuine original deadlines/caps, stable source/BEAM bindings, complete reader/actor/group joins and unsanitized raw adopted waits are required. Python/browser/static/consumer counts remain separate; static0 is not a passing test count.

## Task5: Factual closure and next separate gap

- [ ] Write factual acceptance/design/plan and narrow parent-status update from actual immutable receipts; independent document SPEC then CODE, fresh changed-file checks and disk/index/blob audit. Local conventional commit only after required gates, stage only task-owned paths and prove actual committed-byte custody. No publication/deployment follows.
- [ ] Keep Task6/full8cell upstreamH1/H2 matrix, credit exhaustion, unsent-trailer cancellation/earlyfinal, downstreamRST+live sibling, multiowner/selectedA, standalone, both>=600sloads/H3 and wholeTask5/M3 visibly open.
- [ ] Automatically prepare the next separate deterministic upstream-credit control slice after this bounded stage actually closes. Preserve cumulative repair counters and Astra2/2 exhaustion. No current-stage execution or completion is authorized merely by checking in this draft.
