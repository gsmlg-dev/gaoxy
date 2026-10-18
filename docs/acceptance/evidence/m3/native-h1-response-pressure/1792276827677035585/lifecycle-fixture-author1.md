NATIVE_H1_MATRIX_LIFECYCLE_FIXTURE_AUTHOR1 — DONE

Only `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs` edited. Baseline SHA `fe6dc7ca61e98e42e0c734053e4232cd3a20b4b5b88f74d3494729ca7a155f79`; after SHA `f3e2c905ab750c48f2ea2e8ed9191a83ef2a44c11667f61ddb4662e30de53e45`.

Existing emit packets gain peer_at_us monotonic microseconds; original fields/event names remain intact. No extra process/query/roundtrip.

Peer terminal emitted only at original serve closed/enotconn/other branch, with connection/next request/await_request and safe peer_closed/peer_enotconn/recv_timeout/recv_other labels. Original :ok or raise preserved.

worker_terminal worker_exception emitted only inside existing rescue before original failure; original exception message/error result unchanged. local_socket_close emitted after the exact original close call returns; only close_ok/close_error/close_other labels; original close return retained. Close return does not prove successful physical close.

failure_diagnostic dispatch is failure-only runner contract. Reads existing fixture queue, selectively receives at most32 tuples matching exact own peer with zero wait; never consumes unrelated messages. Originals appended in receive order after pre-existing queue; no raw value lost or reordered.

Export max32 summaries across existing+additional; event whitelist accepted/request/upload_prefix/upload_end/command/failure/joined/peer_terminal/worker_terminal/local_socket_close. Keys event/connection/request/peer_at_us/phase/terminal_label plus existing safe method_label/route_label/action_label/ended only. No raw target/headers/body/error/PID/socket/TLS.

Parent explicitly confirmed queued-failure companion: existing event/3 split stops at first selector or failure in FIFO order; queued failure raises identical original RuntimeError/diagnostic context and remains present. No new wait/query/message; prevents newly retained raw failures from disappearing from cleanup handling.

5000ms, all RuntimeError/error prefixes, response release diagnostics, success oracles, actual failure/cleanup semantics and all resource/protocol bounds retained. No functional repair or dependency defect claimed.

Only own fixture edited; runner/pressure source and all evidence/docs/production/dependencies untouched. Whole baseline restored by exact inverse changes; source custody verified before edits.

Response: event=failure_diagnostic, events<=32, observed_total, truncated, additional_cap_reached. Timestamp peer_at_us. Zero-wait receive<=32; cap or missing event is not completeness/reusability proof.

Exact inverse baseline verification PASS. Formatter/compiler/runtime/parser/AST/browser/Git/subagents NOT RUN. Root owns subsequent verification. Stage OPEN and prior failures unchanged; cause UNKNOWN. Counter40 Sol6/runtimefailed6/Astra2of2 retained; added rounds0. Incident1: overlarge initial scoped read output truncated, parent notified. All commands finished; no background processes. Source/reports immutable at DONE; custody returned.

```diff
--- before-lifecycle-diagnostics
+++ lifecycle-fixture-author1
@@ -216,7 +216,10 @@
   def event(f, selector, timeout \\ @timeout) do
     queued = Process.get({__MODULE__, f.key, :events}, [])
 
-    case Enum.split_while(queued, &(not selected?(&1, selector))) do
+    case Enum.split_while(queued, &(&1["event"] != "failure" and not selected?(&1, selector))) do
+      {_before, [%{"event" => "failure"} = value | _rest]} ->
+        raise "#{inspect(value)} queued_fixture_events=#{inspect(failure_events(f), limit: :infinity)}"
+
       {before, [value | rest]} ->
         Process.put({__MODULE__, f.key, :events}, before ++ rest)
         value
@@ -273,6 +276,48 @@
       "total" => length(queued),
       "truncated" => length(queued) > length(summaries)
     }
+  end
+
+  defp failure_diagnostic(f) do
+    key = {__MODULE__, f.key, :events}
+    queued = Process.get(key, [])
+    {additional, cap_reached} = diagnostic_messages(f.peer, [], 0)
+    observed = queued ++ additional
+    Process.put(key, observed)
+
+    summaries =
+      observed
+      |> Stream.filter(
+        &(&1["event"] in [
+            "accepted", "request", "upload_prefix", "upload_end", "command", "failure", "joined",
+            "peer_terminal", "worker_terminal", "local_socket_close"
+          ])
+      )
+      |> Enum.take(32)
+      |> Enum.map(fn value ->
+        Map.merge(
+          diagnostic_fields(value),
+          Map.take(value, ["event", "peer_at_us", "phase", "terminal_label"])
+        )
+      end)
+
+    %{
+      "event" => "failure_diagnostic",
+      "events" => summaries,
+      "observed_total" => length(observed),
+      "truncated" => length(observed) > length(summaries),
+      "additional_cap_reached" => cap_reached
+    }
+  end
+
+  defp diagnostic_messages(_peer, reversed, 32), do: {Enum.reverse(reversed), true}
+
+  defp diagnostic_messages(peer, reversed, count) do
+    receive do
+      {:matrix_peer, ^peer, value} -> diagnostic_messages(peer, [value | reversed], count + 1)
+    after
+      0 -> {Enum.reverse(reversed), false}
+    end
   end
 
   defp diagnostic_fields(value) do
@@ -500,6 +545,7 @@
   def dispatch(f, %{"op" => "request_clean"}), do: {f, request_clean(f)}
   def dispatch(f, %{"op" => "clean"}), do: {f, clean(f)}
   def dispatch(f, %{"op" => "stop"}), do: {nil, stop(f)}
+  def dispatch(f, %{"op" => "failure_diagnostic"}), do: {f, failure_diagnostic(f)}
 
   def run_case(case_id) do
     port =
@@ -731,6 +777,13 @@
                         rescue
                           error ->
                             emit(parent, peer, %{
+                              "event" => "worker_terminal",
+                              "connection" => connection,
+                              "phase" => "worker_rescue",
+                              "terminal_label" => "worker_exception"
+                            })
+
+                            emit(parent, peer, %{
                               "event" => "failure",
                               "connection" => connection,
                               "reason" => Exception.message(error)
@@ -738,7 +791,21 @@
 
                             {:error, Exception.message(error)}
                         after
-                          wire.close(socket)
+                          close_result = wire.close(socket)
+
+                          emit(parent, peer, %{
+                            "event" => "local_socket_close",
+                            "connection" => connection,
+                            "phase" => "worker_after",
+                            "terminal_label" =>
+                              case close_result do
+                                :ok -> "close_ok"
+                                {:error, _} -> "close_error"
+                                _ -> "close_other"
+                              end
+                          })
+
+                          close_result
                         end
 
                       send(peer, {:worker_finished, connection, result})
@@ -792,6 +859,14 @@
   defp serve(wire, socket, parent, peer, connection, request) do
     case wire.recv(socket, 1, @timeout) do
       {:error, reason} when reason in [:closed, :enotconn] ->
+        emit(parent, peer, %{
+          "event" => "peer_terminal",
+          "connection" => connection,
+          "request" => request,
+          "phase" => "await_request",
+          "terminal_label" => if(reason == :closed, do: "peer_closed", else: "peer_enotconn")
+        })
+
         :ok
 
       {:ok, first} ->
@@ -835,6 +910,14 @@
         serve(wire, socket, parent, peer, connection, request + 1)
 
       other ->
+        emit(parent, peer, %{
+          "event" => "peer_terminal",
+          "connection" => connection,
+          "request" => request,
+          "phase" => "await_request",
+          "terminal_label" => if(other == {:error, :timeout}, do: "recv_timeout", else: "recv_other")
+        })
+
         raise "upstream read failed: #{inspect(other)}"
     end
   end
@@ -978,7 +1061,8 @@
   defp identity(value),
     do: Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(value)), case: :lower)
 
-  defp emit(parent, peer, value), do: send(parent, {:matrix_peer, peer, value})
+  defp emit(parent, peer, value),
+    do: send(parent, {:matrix_peer, peer, Map.put(value, "peer_at_us", System.monotonic_time(:microsecond))})
 
   defp certificates(path),
     do:
```
