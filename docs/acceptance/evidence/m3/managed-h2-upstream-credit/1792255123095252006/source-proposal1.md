# Upstream upload-credit source proposal1

DONE: direct bounded source-proposal assignment only. Runtime acceptance is NOT RUN.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `29d4fe7ba640b90dcc0502e8cfaec5fbe4b6af40`; branch `codex/m3-h1-resource-foundation`.
Actual entry SHA256: `fe7de7cc021800628a1635f50fb778ccc73a03a42232cd925972a0e118295a27`.

Existing peer immediately acknowledges every DATA; accepted opt-in seam is needed to expose actual upstream stream-credit exhaustion and explicit positive resume.

No accepted-plan adaptation, source implementation error or new repair round. The original source files still match entry; no repository/evidence file was written.

## Complete proposal outputs

- `/tmp/gaoxy-upstream-credit-peer1.py`: SHA256 `86d704663d3f58a97656e403d2c320f314bc3703ff559013326e8036a820319e`, 50634 bytes, 965 lines; original 918 lines, +58/-11.
- `/tmp/gaoxy-upstream-credit-streaming1.exs`: SHA256 `145842dade53dfbd9eb868498de23f8699813db4582f1d1a1b36ce4a0d736e13`, 13011 bytes, 301 lines; original 192 lines, +113/-4.

## Static self-review

- PASS_SOURCE_ONLY `accepted_entry_and_source_hashes`: Actual entry hash, original two source hashes and all three canonical doc hashes match receipt.
- PASS_SOURCE_ONLY `accepted_blocks`: All 12 source replacement/helper/test blocks (plan block indices1..12) appear exactly after indentation; constructor/CLI/client-state wiring matches plan prose/block0. All20 canonical plan blocks hashed unchanged.
- PASS_SOURCE_ONLY `prefix_cases`: Original module header and entire eight-case response-prefix loop remain byte-identical.
- PASS_SOURCE_ONLY `ownership_helpers`: Entire assert_held/5 and module tail byte-identical; capture_holds body byte-identical after reverting only its accepted target assertion; other original hold/clean/close helpers byte-identical.
- PASS_SOURCE_ONLY `original_bounds_and_processes`: Original Commands, preparation/start, serve cleanup/automatic/respond/flush, stop/join, independent client and main lifecycle retained; process/timer/deadline/cap literal occurrence checks unchanged.
- PASS_SOURCE_ONLY `default_mode_source_review`: Default-off signature and CLI; mode-off no-max does not assign settings; mode-off max-streams installs the same original sole override; hold mode copies all public settings then overrides streamwindow1/optional explicit max-streams.
- PASS_SOURCE_ONLY `default_event_source_review`: Mode-off DATA uses original acknowledge call; upload_end remains event/connection/stream/total_bytes only; settings_ack remains event/connection/max_streams only; existing command event receives empty expansion; original TLS write-half-close ACK untouched.
- PASS_SOURCE_ONLY `credit_phase_order`: POST header request and ownership capture precede same-connection settings ACK; ACK precedes positive DATA; full body and duplicate ordered native trailers precede held event; original assert_held precedes release; actual cumulative second byte, ordered request trailers and body64 EOF precede success response.
- PASS_SOURCE_ONLY `credit_peer_contract`: Actual first DATA1 unended/flowlen1/zero public remote stream-window/positive public conn-window; exact target and original lock; reject premature trailers/EOF and missing/duplicate/wrong-ref release; stream and conn WINDOW_UPDATE1; shared flush precedes command ACK; normal acknowledgement after release.
- PASS_SOURCE_ONLY `exact_success_cleanup`: Exact binary body/status200/content-type/ordered duplicate response trailers and H1 chunked assertion retained; socket close then unchanged clean then original completion await0 ok then unchanged close.
- PASS_SOURCE_ONLY `matrix_names`: Eight generated expected names listed independently; native tests NOT RUN, no executed-count claim.
- PASS_SOURCE_ONLY `no_scope_expansion`: Only four assigned /tmp paths written; repository/evidence/deps/production/F/G/startup source not modified; no runtime/build/test/formatter, network, browser, commit or subdelegation.

## Eight new expected ExUnit names

These are source-generated identities, not executed results.

- `test fixed managed H2 upload credit http1 -> h2c holds exhausted upload credit then resumes exact body and ordered trailers`
- `test fixed managed H2 upload credit http1 -> http2 holds exhausted upload credit then resumes exact body and ordered trailers`
- `test fixed managed H2 upload credit http2 -> h2c holds exhausted upload credit then resumes exact body and ordered trailers`
- `test fixed managed H2 upload credit http2 -> http2 holds exhausted upload credit then resumes exact body and ordered trailers`
- `test group managed H2 upload credit http1 -> h2c holds exhausted upload credit then resumes exact body and ordered trailers`
- `test group managed H2 upload credit http1 -> http2 holds exhausted upload credit then resumes exact body and ordered trailers`
- `test group managed H2 upload credit http2 -> h2c holds exhausted upload credit then resumes exact body and ordered trailers`
- `test group managed H2 upload credit http2 -> http2 holds exhausted upload credit then resumes exact body and ordered trailers`

## Exact input inventory

- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` (original owned source): SHA256 `70475d2609de54cd9f74090b12d48bf4650bd7b530aa0a4d0b49993b056599c1`, 46749 bytes, 918 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs` (original owned source): SHA256 `684dc971c95c04ff69462ccab5cf0767b54d6016b4b7ca6a4ea568775e1b3887`, 7894 bytes, 192 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/designs/m3-managed-h2-upstream-credit.md` (accepted canonical specification): SHA256 `d5fbf3407be6f10746f3d72fb5436b359aa18e31e534bbbcc5d1cee579a71547`, 12690 bytes, 49 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/plans/m3-managed-h2-upstream-credit.md` (accepted canonical specification): SHA256 `85d42a3797ca74379358f6531c37a8cbc8739f080422bdf984d78a2619c8f0a8`, 24394 bytes, 353 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/m3-managed-h2-upstream-credit.md` (accepted canonical specification): SHA256 `b9a956158a57c0de2d66364bcada4d67c600a1e044e9c51e3173dd465e506a60`, 7199 bytes, 44 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-upstream-credit/1792255123095252006/stage-entry1.json` (actual entry receipt): SHA256 `fe7de7cc021800628a1635f50fb778ccc73a03a42232cd925972a0e118295a27`, 58297 bytes, 585 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` (unchanged F fixture source): SHA256 `2b53e3848a286147ff1b00ac10b5364238b070396d30cb729fcd12300f17dbc8`, 37573 bytes, 1095 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs` (unchanged G fixture source): SHA256 `4d5f70dcee198409fb481947ddfb24e9d65dc65b3b41c0a58e8f6627778b1c53`, 14221 bytes, 403 lines.
- `/tmp/gaoxy-m3-h2-soak-venv/lib/python3.13/site-packages/h2/connection.py` (installed public API source): SHA256 `001ac10ddb176742575dbc6b1c77471113d885f0ce0860b65e56269adc0f9419`, 86876 bytes, 2110 lines.
- `/tmp/gaoxy-m3-h2-soak-venv/lib/python3.13/site-packages/h2/settings.py` (installed public API source): SHA256 `8d10648219e222250642fd7ad90de6cd64139a2d05e395269b32078dbe0cbb55`, 12323 bytes, 331 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/AGENTS.md` (worktree instructions): SHA256 `73b78c7642c2a38061aa23a36d4ffc2014e97ba7129766fbdb0d10f7e5fde9d4`, 8359 bytes, 134 lines.
- `/home/gao/Workspace/gsmlg-opt/gaoxy/AGENTS.md` (project instructions): SHA256 `902a735746a9d05c45b5a3f54c35ad612b1de66af132a39ba26b1215cf90f0c7`, 7869 bytes, 128 lines.
- `/home/gao/.agents/skills/using-superpowers/SKILL.md` (skill instructions - subagent skip applies): SHA256 `316e29381219adf0cac62190c67aeabf427d6e6e5f2735541d502b3d339be7aa`, 5421 bytes, 117 lines.
- `/home/gao/.agents/skills/executing-plans/SKILL.md` (applied skill instructions): SHA256 `e2102f11631433939f162d383d769f8257d859d6639e0e14969cda3ef0a95eca`, 2469 bytes, 70 lines.

## Verification and counters

Read/diff/text-comparison/hash preparation completed. Diff exit1 denotes expected proposal differences; it is not a failed implementation check. No proposed Python/Elixir source was executed or parsed by a language runtime, no tests/build/formatter/browser/consumer ran, and no syntax/format/test pass is claimed. Root owns independent source SPEC then CODE before first genuine runtime.

Inherited root359/orchestration265/creditTool8, preparatory failedSPEC2/draftrepairs2, prefix0, credit runtime/fixture/Sol0, Astra2/2 exhausted. Worker source implementation errors0 and worker repair rounds0. Counters are retained, not reset.

All direct read/text transformation/hash/diff commands finished with no retained process; no runtime actors launched.

Remaining: root formats a separate copy, adopts and freezes active sources, arranges independent reviews and prescribed runtime/compatibility/static/consumer/browser gates. No external/product decision is needed; no stage or Task6 completion is claimed.

## Full surgical source diffs

```diff
--- apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py
+++ /tmp/gaoxy-upstream-credit-peer1.py
@@ -57,8 +57,9 @@
 
 class Peer:
     def __init__(self, protocol, manual, alpn, max_streams=None,
-                 bind_address="127.0.0.1", listen_port=0):
+                 bind_address="127.0.0.1", listen_port=0, hold_upload_credit=False):
         self.protocol, self.manual, self.alpn = protocol, manual, alpn
+        self.hold_upload_credit = hold_upload_credit
         self.max_streams = max_streams
         self.bind_address, self.listen_port = bind_address, listen_port
         self.lock = threading.RLock()
@@ -212,7 +213,8 @@
                         raw.close()
                         raise RuntimeError("fixture connection bound exceeded")
                     client = dict(socket=raw, h2=None, uploads={}, targets={}, pending={}, eof=False,
-                                  responses=set(), write_closed=False, tls_close_request=None)
+                                  responses=set(), write_closed=False, tls_close_request=None,
+                                  credit_holds=set(), credit_released=set())
                     self.clients[number] = client
                     worker = threading.Thread(target=self.serve, args=(number, client))
                     self.workers.append(worker)
@@ -245,9 +247,13 @@
             with self.lock:
                 conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
                     client_side=False, header_encoding="utf-8"))
+                initial_values = dict(conn.local_settings.items()) if self.hold_upload_credit else {}
                 if self.max_streams is not None:
-                    conn.local_settings = h2.settings.Settings(client=False, initial_values={
-                        h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS: self.max_streams})
+                    initial_values[h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS] = self.max_streams
+                if self.hold_upload_credit:
+                    initial_values[h2.settings.SettingCodes.INITIAL_WINDOW_SIZE] = 1
+                if initial_values:
+                    conn.local_settings = h2.settings.Settings(client=False, initial_values=initial_values)
                 conn.initiate_connection()
                 client["h2"] = conn
                 sock.sendall(conn.data_to_send())
@@ -306,13 +312,38 @@
                             self.emit("upload", connection=number, stream=event.stream_id,
                                       chunk_bytes=len(event.data), total_bytes=len(upload),
                                       sha256=hashlib.sha256(upload).hexdigest())
-                            conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
+                            held_target = (self.hold_upload_credit and
+                                           client["targets"][event.stream_id] == "/hold/upload-credit")
+                            if held_target and event.stream_id not in client["credit_released"]:
+                                if (event.stream_id in client["credit_holds"] or len(upload) != 1 or
+                                        event.flow_controlled_length != 1 or event.stream_ended is not None or
+                                        conn.remote_flow_control_window(event.stream_id) != 0 or
+                                        conn.inbound_flow_control_window <= 0):
+                                    raise RuntimeError("fixture upload did not reach exact stream-credit hold")
+                                client["credit_holds"].add(event.stream_id)
+                                self.emit("upload_credit_held", connection=number, stream=event.stream_id,
+                                          total_bytes=len(upload), held_bytes=event.flow_controlled_length,
+                                          stream_window=conn.remote_flow_control_window(event.stream_id),
+                                          connection_window=conn.inbound_flow_control_window,
+                                          sha256=hashlib.sha256(upload).hexdigest())
+                            else:
+                                conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                         elif isinstance(event, h2.events.TrailersReceived):
+                            if (self.hold_upload_credit and
+                                    client["targets"][event.stream_id] == "/hold/upload-credit" and
+                                    event.stream_id not in client["credit_released"]):
+                                raise RuntimeError("fixture upload trailers preceded credit release")
                             self.emit("upload_trailers", connection=number, stream=event.stream_id,
                                       fields=event.headers)
                         elif isinstance(event, h2.events.StreamEnded):
-                            self.emit("upload_end", connection=number, stream=event.stream_id,
-                                      total_bytes=len(client["uploads"].get(event.stream_id, b"")))
+                            upload_values = dict(total_bytes=len(client["uploads"].get(event.stream_id, b"")))
+                            if (self.hold_upload_credit and
+                                    client["targets"][event.stream_id] == "/hold/upload-credit"):
+                                if event.stream_id not in client["credit_released"]:
+                                    raise RuntimeError("fixture upload end preceded credit release")
+                                upload_values["body64"] = base64.b64encode(
+                                    client["uploads"].get(event.stream_id, b"")).decode("ascii")
+                            self.emit("upload_end", connection=number, stream=event.stream_id, **upload_values)
                             if (not self.manual and event.stream_id not in client["responses"]
                                     and client["targets"][event.stream_id].split("?", 1)[0] != "/hold"):
                                 body = bytes(client["uploads"].get(event.stream_id, b""))
@@ -324,8 +355,10 @@
                             self.emit("goaway_received", connection=number, code=int(event.error_code),
                                       last_stream=event.last_stream_id)
                         elif isinstance(event, h2.events.SettingsAcknowledged):
-                            self.emit("settings_ack", connection=number,
-                                      max_streams=conn.local_settings.max_concurrent_streams)
+                            settings_values = dict(max_streams=conn.local_settings.max_concurrent_streams)
+                            if self.hold_upload_credit:
+                                settings_values["initial_window"] = conn.local_settings.initial_window_size
+                            self.emit("settings_ack", connection=number, **settings_values)
                             self.emit("control", connection=number, kind=type(event).__name__)
                         elif isinstance(event, (h2.events.RemoteSettingsChanged,
                                                 h2.events.WindowUpdated, h2.events.PriorityUpdated)):
@@ -453,6 +486,17 @@
                 if (client["targets"] != {stream: "/health"} or client["pending"]
                         or stream not in client["responses"]):
                     raise RuntimeError("fixture write half-close requires completed sole health response")
+            elif op == "release_upload_credit":
+                if (not self.hold_upload_credit or value.get("credit_bytes") != 1 or
+                        client["targets"].get(stream) != "/hold/upload-credit" or
+                        stream not in client["credit_holds"] or
+                        stream in client["credit_released"] or
+                        conn.remote_flow_control_window(stream) != 0 or
+                        conn.inbound_flow_control_window <= 0):
+                    raise RuntimeError("fixture upload-credit release outside exact hold")
+                conn.increment_flow_control_window(1, stream)
+                conn.increment_flow_control_window(1)
+                client["credit_released"].add(stream)
             elif op == "settings":
                 conn.update_settings({h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS: value["max_streams"]})
             else:
@@ -466,9 +510,11 @@
                     return True
                 socket.socket.shutdown(client["socket"], socket.SHUT_WR)
                 client["write_closed"] = True
+            credit_values = {"credit_bytes": 1} if op == "release_upload_credit" else {}
             self.emit("command", op=op, connection=value["connection"], stream=stream,
                       command_id=value.get("command_id"), code=value.get("code"),
-                      last_stream=value.get("last_stream"), max_streams=value.get("max_streams"))
+                      last_stream=value.get("last_stream"), max_streams=value.get("max_streams"),
+                      **credit_values)
         return True
 
     def stop(self):
@@ -856,6 +902,7 @@
     parser = argparse.ArgumentParser()
     parser.add_argument("--protocol", choices=("tls", "h2c"))
     parser.add_argument("--manual", action="store_true")
+    parser.add_argument("--hold-upload-credit", action="store_true")
     parser.add_argument("--staged-start", action="store_true")
     parser.add_argument("--bind-address", default="127.0.0.1",
                         choices=("127.0.0.1", "127.0.0.2", "127.0.0.3", "127.0.0.4"))
@@ -890,7 +937,7 @@
     if args.protocol is None:
         parser.error("peer requires --protocol")
     peer = Peer(args.protocol, args.manual, args.alpn, args.max_streams,
-                args.bind_address, args.listen_port)
+                args.bind_address, args.listen_port, args.hold_upload_credit)
     commands = Commands()
     try:
         if peer.prepare(commands):
```

```diff
--- apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs
+++ /tmp/gaoxy-upstream-credit-streaming1.exs
@@ -91,8 +91,95 @@
     end
   end
 
-  defp fixture(:fixed, upstream, downstream), do: F.fixture(upstream, downstream, ["--manual"])
-  defp fixture(:group, upstream, downstream), do: G.fixture(upstream, downstream, ["--manual"])
+  for mount <- [:fixed, :group] do
+    describe "#{mount} managed H2 upload credit" do
+      if mount == :group do
+        setup do
+          assert :ok === boundary(:activation)
+          :ok
+        end
+      end
+
+      for downstream <- [:http1, :http2], upstream <- [:h2c, :http2] do
+        @credit_mount mount
+        @credit_downstream downstream
+        @credit_upstream upstream
+        test "#{downstream} -> #{upstream} holds exhausted upload credit then resumes exact body and ordered trailers" do
+          body = <<0, 255>>
+          prefix = <<0>>
+          trailers = [{"x-check", "first"}, {"x-check", "second"}]
+          f = fixture(@credit_mount, @credit_upstream, @credit_downstream,
+            ["--manual", "--hold-upload-credit"])
+          {socket, seen, guardian, completion} =
+            hold_upload(@credit_mount, f, "/hold/upload-credit")
+          connection = seen["connection"]
+          stream = seen["stream"]
+          held = capture_holds(@credit_mount, f, guardian, completion, "/hold/upload-credit")
+
+          assert %{"connection" => ^connection, "initial_window" => 1} =
+            F.event(f.peer, "settings_ack")
+          if @credit_upstream == :http2,
+            do: assert(%{"connection" => ^connection, "alpn" => "h2", "sni" => "localhost"} =
+              F.event(f.peer, "tls"))
+
+          if @credit_downstream == :http1 do
+            :ok = :gen_tcp.send(socket,
+              ["2\r\n", body, "\r\n0\r\nX-Check: first\r\nX-Check: second\r\n\r\n"])
+          else
+            :ok = F.send_body(f, socket, body, false)
+            {block, _} = HPAX.encode(:never_store, trailers, HPAX.new(4_096))
+            :ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
+          end
+
+          assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 1} =
+            F.upload_through(f.peer, seen, prefix)
+          prefix_hash = Base.encode16(:crypto.hash(:sha256, prefix), case: :lower)
+          assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 1,
+                   "held_bytes" => 1, "stream_window" => 0,
+                   "connection_window" => connection_window, "sha256" => ^prefix_hash} =
+            F.event(f.peer, "upload_credit_held")
+          assert connection_window > 0
+          assert_held(@credit_mount, f, held, guardian, completion)
+
+          assert %{"op" => "release_upload_credit", "connection" => ^connection,
+                   "stream" => ^stream, "credit_bytes" => 1} =
+            F.command(f.peer, seen, "release_upload_credit", %{"credit_bytes" => 1})
+          assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 2} =
+            F.upload_through(f.peer, seen, body, 1)
+          assert %{"connection" => ^connection, "stream" => ^stream,
+                   "fields" => [["x-check", "first"], ["x-check", "second"]]} =
+            F.event(f.peer, "upload_trailers")
+          body64 = Base.encode64(body)
+          assert %{"connection" => ^connection, "stream" => ^stream,
+                   "total_bytes" => 2, "body64" => ^body64} = F.event(f.peer, "upload_end")
+
+          assert %{"op" => "respond", "connection" => ^connection, "stream" => ^stream} =
+            F.command(f.peer, seen, "respond", %{
+              "status" => 200, "body64" => body64,
+              "fields" => [["content-type", "application/octet-stream"], ["trailer", "x-check"]],
+              "trailers" => [["x-check", "first"], ["x-check", "second"]], "ended" => true
+            })
+          result = F.response(f, socket, "POST")
+          assert result.status === 200
+          assert result.body === body
+          assert result.trailers === trailers
+          assert {"content-type", "application/octet-stream"} in result.headers
+          if @credit_downstream == :http1,
+            do: assert({"transfer-encoding", "chunked"} in result.headers)
+          :ok = :gen_tcp.close(socket)
+          clean(@credit_mount, f)
+          assert :ok = HTTP.RequestCompletion.await(completion, 0)
+          close(@credit_mount, f)
+        end
+      end
+    end
+  end
+
+  defp fixture(mount, upstream, downstream, peer_options \\ ["--manual"])
+  defp fixture(:fixed, upstream, downstream, peer_options),
+    do: F.fixture(upstream, downstream, peer_options)
+  defp fixture(:group, upstream, downstream, peer_options),
+    do: G.fixture(upstream, downstream, peer_options)
   defp hold(:fixed, f, target), do: F.hold(f, target)
   defp hold(:group, f, target), do: G.hold(f, target)
   defp clean(:fixed, f), do: F.clean(f)
@@ -100,7 +187,29 @@
   defp close(:fixed, f), do: F.close(f)
   defp close(:group, f), do: G.close(f)
 
-  defp capture_holds(mount, f, guardian, completion) do
+  defp hold_upload(mount, f, target) do
+    socket = F.connect(f)
+    fields = [{"trailer", "x-check"}] ++
+      if(f.downstream == :http1, do: [{"transfer-encoding", "chunked"}], else: [])
+    :ok = F.send_request(f, socket, "POST", target, fields, false)
+    seen = F.event(f.peer, "request")
+    assert seen["target"] === target
+    assert [":method", "POST"] in seen["headers"]
+    assert seen["ended"] === false
+
+    F.eventually(fn ->
+      Enum.any?(:sys.get_state(f.owner).tokens, fn {_, held} ->
+        match?(%HTTP.RequestCompletion{}, held.completion) and
+          :sys.get_state(held.guardian).submitted_url === f.origin <> target
+      end)
+    end)
+
+    if mount == :group, do: F.eventually(fn -> G.held_selection(f, target) != nil end)
+    [{_, held}] = Map.to_list(:sys.get_state(f.owner).tokens)
+    {socket, seen, held.guardian, held.completion}
+  end
+
+  defp capture_holds(mount, f, guardian, completion, target \\ "/hold/response-prefix") do
     [{transport_token, transport_hold}] = Map.to_list(:sys.get_state(f.owner).tokens)
     assert transport_hold.guardian === guardian
     assert transport_hold.completion === completion
@@ -114,7 +223,7 @@
     assert state.request_options === nil
     assert state.selector === nil
     assert state.awaiting_transport === nil
-    assert state.submitted_url === f.origin <> "/hold/response-prefix"
+    assert state.submitted_url === f.origin <> target
     assert :binary.referenced_byte_size(state.submitted_url) === byte_size(state.submitted_url)
     assert Enum.sort(Map.keys(state.request)) === [:completion, :promise, :resolved, :stream]
     assert [_ | _] = state.transport_pins
```
