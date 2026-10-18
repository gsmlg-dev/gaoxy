MATRIX DIAGNOSTIC AUTHOR1 — DONE

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Only assigned fixture edited.

Before SHA256: `c1073325d4b816175462a4524d106a52ddae93a25429532608dc63e51460ffb0`. After SHA256: `73f0ef92ba14b0874b07ada5e8afa34178d2c8a4bda1af34572dbc3bdaacc728`.

Timeout retains RuntimeError, original response release deadline prefix and unchanged @timeout5000. Existing base only; no extra wire or process queries.

Timeout fields connection/request, method POST/DELETE/other, route temporal/trailers/other; no raw target/headers/payload.

Existing fixture-owned queued events inspected only when next_event receives failure. At most16 whitelisted summaries; total includes all queued events and truncated indicates any omission. Whitelist accepted/request/upload_prefix/upload_end/command.

Summary fields limited to event/connection/request/ended plus method_label/route_label/action_label. Missing fields stay absent; action send/continue_upload/other. Unknown events counted only.

Original peer failure remains RuntimeError on same raise path; cleanup failures and assertions unchanged. Success clauses/queries/messages/mailbox drains/processes untouched.

Only assigned fixture edited. Other pressure writer scope untouched. Exact inverse delta restores complete baseline; file custody rechecked before mutation.

Exact inverse checks PASS. No formatter/compiler/runtime/tests/browser/Git/agents run. Root owns formatting, independent review and subsequent gates. Cause remains UNKNOWN; no functional repair/dependency claim. Counter33 Sol5/runtimefail5/Astra2of2 retained, added rounds0. Incidents0. Commands completed; no background processes. Source and reports immutable at DONE; custody returned to root.

```diff
--- before-matrix-diagnostics
+++ matrix-diagnostic-author1
@@ -237,7 +237,7 @@
 
     receive do
       {:matrix_peer, peer, %{"event" => "failure"} = value} when peer == f.peer ->
-        raise inspect(value)
+        raise "#{inspect(value)} queued_fixture_events=#{inspect(failure_events(f), limit: :infinity)}"
 
       {:matrix_peer, peer, value} when peer == f.peer ->
         if selected?(value, selector) do
@@ -253,6 +253,37 @@
     after
       remaining -> raise "managed-H1 event deadline: #{inspect(selector)}"
     end
+  end
+
+  defp failure_events(f) do
+    queued = Process.get({__MODULE__, f.key, :events}, [])
+
+    summaries =
+      queued
+      |> Stream.filter(&(&1["event"] in ["accepted", "request", "upload_prefix", "upload_end", "command"]))
+      |> Enum.take(16)
+      |> Enum.map(fn value ->
+        Map.put(diagnostic_fields(value), "event", value["event"])
+      end)
+
+    %{"events" => summaries, "total" => length(queued), "truncated" => length(queued) > length(summaries)}
+  end
+
+  defp diagnostic_fields(value) do
+    Enum.reduce(
+      [
+        {"method", "method_label", %{"POST" => "POST", "DELETE" => "DELETE"}},
+        {"target", "route_label", %{"/temporal" => "temporal", "/trailers" => "trailers"}},
+        {"action", "action_label", %{"send" => "send", "continue_upload" => "continue_upload"}}
+      ],
+      Map.take(value, ["connection", "request", "ended"]),
+      fn {key, label, allowed}, fields ->
+        case Map.fetch(value, key) do
+          {:ok, raw} -> Map.put(fields, label, Map.get(allowed, raw, "other"))
+          :error -> fields
+        end
+      end
+    )
   end
 
   defp selected?(value, selector),
@@ -866,7 +897,8 @@
 
         if not ended, do: respond(wire, socket, parent, peer, base)
     after
-      @timeout -> raise "response release deadline"
+      @timeout ->
+        raise "response release deadline #{inspect(diagnostic_fields(base), limit: :infinity)}"
     end
   end
 
```
