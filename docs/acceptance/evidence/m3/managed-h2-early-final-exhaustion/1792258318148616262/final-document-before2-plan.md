# Managed H2 Early Final at Exhaustion Implementation Plan

> **For agentic workers:** Use parent-managed subagent-driven-development task by task. Root alone owns repository/evidence/Git and all builds/tests/browser. Workers own assigned temporary proposals/reviews and preserve concurrent writers. Continuing authorization selects this recommended approach without routine approval questions.

**Goal:** Qualify eight exact early-final responses and terminal resets after genuine upstream stream-credit exhaustion with authentic original ownership and complete bounded cleanup.

**Architecture:** Reuse the accepted independent peer's default-off hold mode and existing manual respond command. Add a mode-scoped snapshot to its existing actual reset event and eight cases to the existing streaming module. F/G, production/deps and all clocks/caps remain unchanged.

**Tech Stack:** Locked HTTP Fetch0.21.10, existing Elixir/OTP/Nix environment, native H1/H2 sockets/HPAX, Python public hyper-h2 APIs and accepted finite custody/browser tools.

Status — 2026-10-18: ENTRY DESIGN/PLAN. Preparatory SPEC28→CODE30 PASS with no findings; implementation and all runtime, browser, source review, commit and custody gates remain NOT RUN at this entry.

## Task0: Actual entry, immutable tools and input binding

- [ ] Root verifies actual baseline `ceb3c0c953d930768023da85875a95672876ce39` / branch `codex/m3-h1-resource-foundation` in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, E9 `credit-postcommit-custody1.json` SHA256 `b0cbfd38d55812f805b828330868d38456d50697bdee580fee6b29d91ad16fee`, actual174/402/565 counts and root's `credit-closure-document-overlay1.json` SHA256 `a613dd193985cacb72d50399dfd13e5c89d1470a5b4f087a6b726b92708c6f68`. Re-pin the exact active inputs listed by this proposal; overlay supersedes historical pending prose. No broad untracked enumeration or protected E4 access.
- [ ] Complete preparatory independent SPEC then CODE against the complete three documents and exact source-contract report. Retain all findings/repairs/counters. Promote only reviewed bytes to `docs/designs/m3-managed-h2-early-final-exhaustion.md`, `docs/plans/m3-managed-h2-early-final-exhaustion.md`, `docs/acceptance/m3-managed-h2-early-final-exhaustion.md` and E9. Root records exact entry source/document/tool hashes and counters.
- [ ] Copy/rebind all nine accepted active E8 tools using the exact root-owned entry code below. This changes only evidence-path context; no helper logic, deadlines or assertions change. Hash source and materialized bytes individually into immutable `tool-materialization1.json`; write only absent destination files. Review materialized full sources and regenerate command/source/BEAM binding before launch. E8 command inventory is read as a historical binding, never treated as current runtime evidence.

```python
import hashlib
import json
from pathlib import Path

root = Path("/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation")
old_rel = "docs/acceptance/evidence/m3/managed-h2-upstream-credit/1792255123095252006"
new_rel = "docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262"
old, new = root / old_rel, root / new_rel
names = (
    "command-collector1.py", "browser-command-collector1.py",
    "group-identity-rotation-browser-runner1.py",
    "group-identity-rotation-browser-host1.exs",
    "group-identity-rotation-browser-cohort1.exs",
    "fixed-identity-rotation-browser-runner1.py",
    "fixed-identity-rotation-browser-host1.exs",
    "fixed-identity-rotation-browser-cohort1.exs", "syntax-check1.py",
)
rows = []
for name in names:
    source, destination = old / name, new / name
    original = source.read_bytes()
    materialized = original.replace(old_rel.encode(), new_rel.encode())
    with destination.open("xb") as output:
        output.write(materialized)
    rows.append({"source": str(source.relative_to(root)),
                 "destination": str(destination.relative_to(root)),
                 "source_sha256": hashlib.sha256(original).hexdigest(),
                 "destination_sha256": hashlib.sha256(materialized).hexdigest(),
                 "context_rebound": materialized != original})
record = {"kind": "EARLY_FINAL_TOOL_MATERIALIZATION1", "files": rows,
          "count": len(rows), "budgets_changed": False, "runtime": "NOT RUN"}
with (new / "tool-materialization1.json").open("x") as output:
    json.dump(record, output, indent=2, sort_keys=True)
    output.write("\n")
```

Root must validate accepted E8 originals against pinned hashes before this code, rather than accepting arbitrary current tool bytes. No source-count constant is reused: the accepted command collector recomputes its task-source manifest; the browser outer collector recomputes its own source set and inner runner source/BEAM bindings. Root explicitly freezes this actual context in `source-candidate1.json` and new `command-inventory1.json`, with first/final/browser names below. Repeated invocations require new immutable numeric suffixes, retaining earlier failures. Source candidates and audit tools themselves receive independent SPEC→CODE before execution.

## Source-attested terminal contract

Read `/tmp/gaoxy-early-final-contract-investigation1.json` SHA256 `08d17e5eacf325bfcfeec77ac0ec9f53e7e0d9fa836e2355dc3c473e679642e4` and its Markdown companion SHA256 `6ddc04d1b68c943a5b1de9380471fa64bb521168df215c826c6dd603bf028d9b` before source review. The JSON pins all16 exact source inputs. The supported chain is runtime owner final-header stop at `deps/http_runtime/lib/http/http2/connection_owner.ex:1636-1650`, SocketClient response completion at `deps/http_fetch/lib/http/socket_client.ex:1304-1325`, public release_stream and close_unfinished_upload at owner488-526/1653-1665, pure cancel_headers at `deps/http_core/lib/http/http2/connection.ex:289-292`, half_closed_remote transition at stream_state337-348, and numeric code8 serializer at owner676-677. Native response forwarding/early-writer-stop is `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:789-895,998-1055`. Original public completion/cleanup remains separate from peer receipt/physical close; Session1341-1435 and unchanged fixture helpers establish those stages. This is pinned source support only; combined runtime is NOT RUN.

## Task1: Minimal peer terminal snapshot

Modify only `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`. Replace the whole existing StreamReset branch with this exact branch; keep surrounding event branches unchanged. No new peer flag/target, process, parser, command, settings, acknowledgement or release is added.

```python
elif isinstance(event, h2.events.StreamReset):
    client["pending"].pop(event.stream_id, None)
    reset_values = {}
    if (self.hold_upload_credit and
            client["targets"].get(event.stream_id) == "/hold/upload-credit" and
            event.stream_id in client["credit_holds"]):
        upload = bytes(client["uploads"][event.stream_id])
        reset_values["upload_credit"] = {
            "total_bytes": len(upload),
            "body64": base64.b64encode(upload).decode("ascii"),
            "sha256": hashlib.sha256(upload).hexdigest(),
            "credit_released": event.stream_id in client["credit_released"],
            "response_started": event.stream_id in client["responses"],
        }
    self.emit("reset", connection=number, stream=event.stream_id,
              code=int(event.error_code), **reset_values)
```

The snapshot reads existing actual peer state under its existing RLock after a real hyper-h2 StreamReset. Mode-off event shape and behavior remain exactly unchanged. Existing hold guards still fail on trailers/StreamEnded before credit release. Snapshot fields are facts, not a synthetic success flag. The `code == 8` assertion belongs to the test, not fixture event rewriting.

## Task2: Eight native combined early-final cases

Modify only `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`. Insert the complete block below immediately before the existing `defp fixture` declaration. Preserve the original eight response-prefix cases, eight positive-credit cases, all helper bodies and their defaults byte-for-byte.

```elixir
  for mount <- [:fixed, :group] do
    describe "#{mount} managed H2 early final at exhausted upload credit" do
      if mount == :group do
        setup do
          assert :ok === boundary(:activation)
          :ok
        end
      end

      for downstream <- [:http1, :http2], upstream <- [:h2c, :http2] do
        @early_mount mount
        @early_downstream downstream
        @early_upstream upstream
        test "#{downstream} -> #{upstream} receives exact early final at exhausted upload credit before original terminal cleanup" do
          body = <<0, 255>>
          prefix = <<0>>
          trailers = [{"x-check", "first"}, {"x-check", "second"}]
          response_body = "early-final"

          f =
            fixture(@early_mount, @early_upstream, @early_downstream, [
              "--manual",
              "--hold-upload-credit"
            ])

          {socket, seen, guardian, completion} =
            hold_upload(@early_mount, f, "/hold/upload-credit")

          connection = seen["connection"]
          stream = seen["stream"]
          held = capture_holds(@early_mount, f, guardian, completion, "/hold/upload-credit")

          assert %{"connection" => ^connection, "initial_window" => 1} =
                   F.event(f.peer, "settings_ack")

          if @early_upstream == :http2,
            do:
              assert(
                %{"connection" => ^connection, "alpn" => "h2", "sni" => "localhost"} =
                  F.event(f.peer, "tls")
              )

          if @early_downstream == :http1 do
            :ok =
              :gen_tcp.send(
                socket,
                ["2\r\n", body, "\r\n0\r\nX-Check: first\r\nX-Check: second\r\n\r\n"]
              )
          else
            :ok = F.send_body(f, socket, body, false)
            {block, _} = HPAX.encode(:never_store, trailers, HPAX.new(4_096))
            :ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
          end

          assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 1} =
                   F.upload_through(f.peer, seen, prefix)

          prefix_hash = Base.encode16(:crypto.hash(:sha256, prefix), case: :lower)

          assert %{
                   "connection" => ^connection,
                   "stream" => ^stream,
                   "total_bytes" => 1,
                   "held_bytes" => 1,
                   "stream_window" => 0,
                   "connection_window" => connection_window,
                   "sha256" => ^prefix_hash
                 } = F.event(f.peer, "upload_credit_held")

          assert connection_window > 0
          assert_held(@early_mount, f, held, guardian, completion)

          assert %{"op" => "respond", "connection" => ^connection, "stream" => ^stream} =
                   F.command(f.peer, seen, "respond", %{
                     "status" => 413,
                     "fields" => [
                       ["content-type", "application/octet-stream"],
                       ["content-length", "11"]
                     ],
                     "body64" => Base.encode64(response_body),
                     "ended" => true
                   })

          result = F.response(f, socket, "POST")
          assert result.status === 413
          assert result.body === response_body
          assert result.trailers === []
          assert {"content-type", "application/octet-stream"} in result.headers
          assert {"content-length", "11"} in result.headers

          assert %{
                   "connection" => ^connection,
                   "stream" => ^stream,
                   "code" => 8,
                   "upload_credit" => %{
                     "total_bytes" => 1,
                     "body64" => "AA==",
                     "sha256" => ^prefix_hash,
                     "credit_released" => false,
                     "response_started" => true
                   }
                 } = F.event(f.peer, "reset")

          :ok = :gen_tcp.close(socket)
          clean(@early_mount, f)
          assert :ok = HTTP.RequestCompletion.await(completion, 0)
          close(@early_mount, f)
        end
      end
    end
  end
```

Full binary body+trailers are submitted to the native socket before the held observation; this does not claim the native pump has parsed them or that HTTP.Stream.finish has completed. Source-attested code8 comes from final-header upload-stop→response-finish/release_stream→close_unfinished_upload→cancel_headers→RST_STREAM CANCEL. Require both parsed exact response and peer reset before the test initiates socket close. The server may naturally close an incomplete downstream request after delivering the response; connection reuse/open-state is not required. Do not require post-response ownership to remain pending: original retained ownership is asserted at the genuine pre-response hold, then bounded cleanup is required. EOF cannot replace reset. Never broaden code8/status/body after a failure.

- [ ] Review complete candidate before runtime: original16 cases and helper source unchanged; full native submission precedes genuine held barrier; unchanged original ownership assertion precedes manual response; no upload release/ack; exact response and actual terminal snapshot precede test socket close; existing cleanup closes all resources. Freeze actual source+commands, complete independent source SPEC then CODE and resolve actionable findings without weakened contracts.

## Task3: First genuine eight-case qualification

Root alone executes each payload through the accepted materialized collector, never directly as an uncustodied substitute. In the following shell block `evidence` is the exact stage path; each collector writes immutable same-name .json/.log receipts, enforces600s and preserves actual exits/descendants/raw waits. No whole-suite count is predicted.

```sh
evidence=docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262
python3 -B "$evidence/command-collector1.py" --name early-final-first1 --timeout 600 --kind green -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --trace --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [ ] Preserve unfiltered trace, verify all eight exact case names actually completed, source/command/log/process bindings and zero failure/skip/exclusion/product warnings. Accepted prior first54/0 is historical only. Any missing ACK/held/reset, wrong bytes/windows/code/status/ownership/cleanup, timeout/forced exit/live actor is FAIL. Preserve evidence/assertions/budgets and enter authorized bounded Sol diagnosis. No artificial RED, silent dependency workaround, third Astra recovery or ignored failing gate.
- [ ] Complete independent implementation SPEC then CODE against candidate and actual first receipts before fresh final gates. Root records actual review checks/findings and counters; no fabricated predicted PASS.

## Task4: Fresh final defining/lifecycle/Generation and compatibility

- [ ] Run these exact separate collector payloads after implementation review, with current source/BEAM/command bindings and unchanged budgets. Record actual nonzero executed counts; batches overlap and must not be summed as unique tests.

```sh
evidence=docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262
python3 -B "$evidence/command-collector1.py" --name early-final-final-defining1 --timeout 600 --kind green -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --trace --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
python3 -B "$evidence/command-collector1.py" --name early-final-final-lifecycle1 --timeout 600 --kind green -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
python3 -B "$evidence/command-collector1.py" --name early-final-final-generation1 --timeout 600 --kind green -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
```

- [ ] Fresh strict compile, six-file format for active test+copied browser Elixir, and accepted active Python/extracted-JavaScript syntax. Static collector receipts count0 tests.

```sh
evidence=docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262
python3 -B "$evidence/command-collector1.py" --name early-final-final-compile1 --timeout 600 --kind static -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --force --warnings-as-errors
python3 -B "$evidence/command-collector1.py" --name early-final-final-format1 --timeout 600 --kind static -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs "$evidence/fixed-identity-rotation-browser-host1.exs" "$evidence/fixed-identity-rotation-browser-cohort1.exs" "$evidence/group-identity-rotation-browser-host1.exs" "$evidence/group-identity-rotation-browser-cohort1.exs"
python3 -B "$evidence/command-collector1.py" --name early-final-final-syntax1 --timeout 600 --kind static -- python3 -B "$evidence/syntax-check1.py"
```

- [ ] Run unchanged11-method startup suite separately, actual11 methods with no failure/error/skip, and isolated consumers with actual Core1/HTTP2 counts. Startup is counted from real unittest methods/summary; generic static collector0 is not11. Preserve network/dependency blockers explicitly; only previously qualified local object transport may be separately recorded by root.

```sh
evidence=docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262
python3 -B "$evidence/command-collector1.py" --name early-final-final-python-startup1 --timeout 600 --kind static -- nix develop --command /tmp/gaoxy-m3-h2-soak-venv/bin/python -B apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py -v
python3 -B "$evidence/command-collector1.py" --name early-final-final-core-consumer1 --timeout 600 --kind green -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer bash scripts/external-consumer.sh
python3 -B "$evidence/command-collector1.py" --name early-final-final-http-consumer1 --timeout 600 --kind green -- nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer bash scripts/http-consumer.sh
```

- [ ] Execute the actual copied/rebound accepted group browser outer collector11argv below, not its inner runner5argv; validate current two nativeH1/H2→TLS-H2 group rows and root opens all four OLD/NEW PNGs. Recompute actual outer/inner source subsets, loaded source/BEAM/module-MD5 bindings and artifact hashes; preserve every named Actor/reader/peer join, raw deletion, invalidation, retirement/zeroing/rebind and genuine adopted waits. Do not read/copy raw NetLogs/private keys or call image counts runtime test counts. Browser is the current group boundary, not the eight temporal-exhaustion proofs.

```sh
python3 -B docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262/browser-command-collector1.py --endpoint group --name early-final-group-browser-green1 --receipt early-final-group-browser-command1 --runner group-identity-rotation-browser-runner1.py
```

- [ ] Root audits all immutable command .json/.log hashes, exact exits/nonforced/live0, finite deadlines, original raw adopted waits and fixture-specific accepted exit reasons. Zero static warnings/skips/exclusions; all eight new identities pass in fresh defining trace and original16 remain. Do not reinterpret historical SIGUSR1 adopted exits as all-exit0. Do not run broad suites/autofixes or fix unrelated failures.

## Task5: Factual local closure and actual successor custody

- [ ] Fill all three canonical docs from actual immutable receipts; preserve previous entry as historical, separate PASS/FAIL/BLOCKED/NOT RUN and static0/Python11/Core1/HTTP2/browser2 from overlapping ExUnit counts. Update only narrow parent-plan status; keep fullTask6/Task5/M3 and explicit other follow-ups open.
- [ ] Independent final document SPEC then CODE examines final docs, exact task inventory, receipt/source/tool/document rebindings and counters. Resolve findings and re-run only justified affected gates; source changes require fresh source/implementation review+runtime evidence.
- [ ] Root alone stages exact task-owned files and performs an authorized local conventional commit, then audits actual commit/parent/branch, disk/index/blob equality, source pins, actual task/union blob counts and safe shutdown in immutable successor custody. Do not guess commit SHA/count or present precommit pending prose as closure. No push/release/deploy follows.
- [ ] Prepare the next separately bounded remaining stage after actual closure. This slice does not add unsent-trailer cancellation, downstreamRST/live sibling, upstreamH1/full matrix, multi-owner/selectedA, standalone/two≥600s loads/H3 or fullTask6/Task5/M3 acceptance. Preserve no production-data/certificate/Vault/public-management/account changes, no disabled E2E activation and no http_fetch#97 revival.

## Inherited counters and safe execution

E9counter3 records root396/orchestration302/earlyTool7 (scope1 included), all inherited counters and exhausted Astra2/2. Preparation SPEC28 then CODE30 passed with no findings. Seven preparation tooling incidents are preserved separately; early-final runtime/fixture/Sol repairs remain0 at entry.
