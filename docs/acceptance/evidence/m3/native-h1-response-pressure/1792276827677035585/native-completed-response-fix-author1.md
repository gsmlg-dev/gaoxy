# NATIVE COMPLETED RESPONSE FIX AUTHOR1

DONE for direct exact one-file implementation; root validation pending. Worktree /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation; baseline fb7d0fda2b7c16c42c65579736dc1f643e17d812 from root,Git not run.

Changed only apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex: add approved native transportnil/fixed0 pump branch after upload paths,before passivepoll. No other edit. Original source hash dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31; result 796f5058c7cb2fa23d46f93559caf8eae00836fc8812e6126c306e91455c8776. Exact inverse restores entire original source.

```diff
--- apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex.original
+++ apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex
@@ -831,8 +831,11 @@
 
       state.ready and not state.upload_stopped ->
         read_upload(state, min(@poll_ms, remaining))
 
+      state.exchange.transport == nil and state.exchange.response == {:fixed_stream, 0} ->
+        pump(state, min(@poll_ms, remaining))
+
       true ->
         # Passive TLS needs a waiting receive to settle an abrupt transport close.
         # Give it a finite turn only after idle, keeping data deliveries on poll0.
         poll_wait =
```

Root supplied independently accepted semantic RED enotconn/fixed0; author did not rerun or change test/assertions. Existing deadlines,genuine terminal validation/consumed and excluded incomplete/chunked/bodyless/framed states preserved. No compiler/formatter/runtime/Git. Source review and GREEN pending. Native pressure productionrepair1,cumulativeSol7,Astra2of2;root owns counter recording. Zero tooling incidents. All commands finished;no background processes. Assigned source/reports frozen atDONE;custody returnedtoroot.
