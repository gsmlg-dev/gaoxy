# Same-authority group cold-close diagnosis and repair proposal1

Task `h2_identity_cold_close_repair1`: DONE for bounded diagnosis/proposal only. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation` remains read-only. Only this Markdown and companion JSON are written. Tests/build/syntax/browser/network/trace execution **NOT RUN**; worker executed0 tests and all own commands completed.

The root-run failure is real and preserved: `group-green1.log` reports144 tests/2 failures, both rotated native H1/H2 cases at OLD `rotation_close_health/2` waiting for physical termination. Root reports actual exit2,214s command time, joined/nonforced/no source changes. The log's ExUnit elapsed is203.9s; do not conflate those clocks. Log SHA256 `05f8359fe479d15f698c8dc2917716240277953380c4c0c94d00dc613ce4437a`.

The original assumption was wrong: GOAWAY is a drain/admission signal, not a promise that the remote peer will close TCP within5s. The fixture only writes the GOAWAY frame and emits its command acknowledgement. Current HTTP Runtime0.21.10 source enters draining with a default30s timer; final-stream release closes only when already draining. Here HEAD's original completion/release happened before GOAWAY. There is no source-supported <=5s physical-close guarantee. This is a fixture schedule correction explicitly allowed by design line37, not evidence of a required dependency bug. No upstream issue or local dependency workaround is justified on these facts. A later public admission/completion/cleanup failure after real socket closure would be a different finding.

Use the existing public JSON command seam to add **write_half_close** for the completed sole health response. Flush protocol output, then call `socket.socket.shutdown(client["socket"], socket.SHUT_WR)`. Crucially, call the base public socket method: the pinned Python3.13.15 `SSLSocket.shutdown` override at ssl.py1340–1343 clears `_sslobj`, which would discard the decoder used by the concurrent real reader. No private SSL state is assigned. Base shutdown preserves the TLS read path; the unchanged reader must observe actual remote EOF/reset and perform its existing finally-close. This is intentional TCP half-close, not a claim of graceful TLS close_notify. Command ack is not physical closure.

Do not close the socket in the command, set eof/stopping flags, synthesize a physical event, stop the peer/listener, call private client owners, swallow errors, or normalize final forced cleanup. The proposed narrow guard accepts only the sole `/health` response already sent with no pending body. Every syscall error stays a real failure. Final workers/readers still join through existing peer stop and must report forced0/live0/failedfalse.

Both group socket `rotation_close_health` and group browser runner `health_phase` need the same command/ack between unchanged GOAWAY ack and unchanged real physical-close wait. Store the extra command receipt in their health proof. Group browser host behavior remains unchanged: original completions2, Probe normal DOWN2 and zero accounting precede its5s runner acknowledgement barrier, and runner acknowledges only after both actual physical closes. Fixed browser has no health-close schedule; its behavior is unaffected, but its shared-peer source hash must be re-frozen for final verification.

The JSON contains exact unique old/new replacement fragments and unified diffs for only3 root-owned files, guarded by baseline hashes and proposed **unformatted** output hashes:

- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`: baseline `1ce3c5b4b95c133883127c24112ad04bd6402d9eefcc4242019fae21111698bf`; proposed `b6dfb66cb0e84a1525bd8bafe437a2d161273eeb862fbc92522eaabb916f26b5`; +7/-0 lines.
- `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs`: baseline `f3d2191cda2308048831d9f793d15a0a5ea89c17bb5de05817c3385b32a14b8c`; proposed `4080bb4386b65eb778b2322c278989b0b47e25e474325c907315455b72c47389`; +8/-1 lines.
- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-identity-rotation-browser-runner1.py`: baseline `89e7106e5018f3ed4186ca2c893a7b64b6773b50d8c0302387990fd217257e6b`; proposed `2f62b47e5aa650f1c19336b3a1a86598a2f478937d3091a5d76c87870a536dbf`; +10/-1 lines.

```diff
--- apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py
+++ apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py (proposed)
@@ -396,11 +396,18 @@
             elif op == "goaway":
                 payload = value.get("last_stream", stream).to_bytes(4, "big") + value.get("code", 0).to_bytes(4, "big")
                 client["socket"].sendall(len(payload).to_bytes(3, "big") + b"\x07\x00\x00\x00\x00\x00" + payload)
+            elif op == "write_half_close":
+                if (client["targets"] != {stream: "/health"} or client["pending"]
+                        or stream not in client["responses"]):
+                    raise RuntimeError("fixture write half-close requires completed sole health response")
             elif op == "settings":
                 conn.update_settings({h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS: value["max_streams"]})
             else:
                 raise RuntimeError("unknown fixture operation")
             self.flush(client)
+            if op == "write_half_close":
+                # Preserve SSLSocket's decoder for the real reader EOF/reset.
+                socket.socket.shutdown(client["socket"], socket.SHUT_WR)
             self.emit("command", op=op, connection=value["connection"], stream=stream,
                       command_id=value.get("command_id"), code=value.get("code"),
                       last_stream=value.get("last_stream"), max_streams=value.get("max_streams"))
```

```diff
--- apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs
+++ apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs (proposed)
@@ -1138,11 +1138,18 @@
                } =
                  F.command(entry.peer, request, "goaway", %{"last_stream" => stream, "code" => 0})
 
+        # GOAWAY is an admission/drain signal, not a TCP close guarantee.
+        # End only the peer write side; the original reader must observe EOF/reset.
+        assert %{"op" => "write_half_close", "connection" => 1, "stream" => ^stream} =
+                 close_ack = F.command(entry.peer, request, "write_half_close")
+
         assert %{"connection" => 1} = termination = F.physical_termination(entry.peer)
         F.no_event(entry.peer, "accept")
         F.no_event(entry.peer, "tls")
         F.no_event(entry.peer, "request")
-        Map.put(entry, :physical_termination, termination)
+        entry
+        |> Map.put(:write_half_close, close_ack)
+        |> Map.put(:physical_termination, termination)
       end)
 
     assert_no_open(f, candidate)
```

```diff
--- docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-identity-rotation-browser-runner1.py
+++ docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-identity-rotation-browser-runner1.py (proposed)
@@ -522,9 +522,18 @@
         assert ack['op'] == 'goaway' and ack['command_id'] == command_id and ack['code'] == 0
         assert ack['last_stream'] == request['stream']
         assert ack['connection'] == request['connection'] and ack['stream'] == request['stream']
+        # GOAWAY alone does not promise physical close. Preserve the TLS reader
+        # while explicitly ending only this completed health socket's write side.
+        close_command_id = case+'-'+name+'-health-write-half-close'
+        peer.send(dict(op='write_half_close',connection=request['connection'],
+                       stream=request['stream'],command_id=close_command_id))
+        close_ack = peer.event('command')
+        assert close_ack['op'] == 'write_half_close' and close_ack['command_id'] == close_command_id
+        assert close_ack['connection'] == request['connection'] and close_ack['stream'] == request['stream']
         physical = event_one_of(peer,('eof','connection_reset'))
         assert physical['connection'] == request['connection']
-        health[name].update(goaway=ack,physical_close=physical,original_completion_before_goaway=True)
+        health[name].update(goaway=ack,write_half_close=close_ack,physical_close=physical,
+                            original_completion_before_goaway=True)
     host.send(dict(op='health_closed',phase=phase))
 
 
```

All original HEAD/completion/Probe/admission/accounting assertions,5s deadlines, actual connection1 EOF/reset and cold GET connection2 assertions remain. Accept/request/selection/credential/G/T/source/custodian/native95/cap/normal Actor/zero/rebind gates are unchanged. No production or dependency edits are proposed.

Root owns adoption after failed receipt custody completes, guarded application, new source/argv/browser-hash freeze, independent bounded SPEC then CODE, static checks and fresh nonzero scoped/Python/browser verification. This proposal has not established that half-close satisfies the5s physical termination gate; preserve actual future outcome. No parallel runtime/fixture or raw NetLog/prohibited trace/private-key read occurred.

Companion JSON SHA256 `54b1de75c6b084b57fd3d0752bf3568cba05affbdcbf3d94406d618a8e003404`. Pinned stdlib ssl.py SHA256 `6deea04be4d1a5070e25f2f1523a417474cff6c28128b28dd944fb3ec3d01140`. Latest received counters root160/orch86/tooling26/groupfailed56/runtimefailed2/fixtureRepair2/Solrepair2/production0/Astra2/2; root alone manages them. No new worker errors or runtime failures; no worker repair-and-validation round executed. No new product decision required.
