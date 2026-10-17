# Managed-H1 framing repair3

DONE for one-line implementation and static checks; runtime acceptance NOT RUN.

Task: managed_h1_matrix_framing_repair3. Direct follow-up, targeted Sol round3 under continuing authorization. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `1426657e65d726629d618dcf03880df718375dd1` plus candidate3. Owned source matched root pre-edit archive byte-for-byte. No other repository file edited by this worker.

Local root cause: the adapter mapped both absent body and explicit zero-length body to nil. Dependency nil-body framing removes Content-Length. Installed http_fetch/http_core0.21.10 provenance is https://github.com/gsmlg-dev/http_fetch, established from package mix.exs lines4-5. No upstream defect established.

The repair chooses nil only for :none. Explicit {:length,0} now uses existing public HTTP.Stream.start_link(0), duplex:half and existing zero-byte finish_upload handling, within the existing nil/PID preparation contract.

```diff
--- before/apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex
+++ after/apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex
@@ -38,7 +38,7 @@
   @impl true
   def open(options) do
     upload =
-      if options.body in [:none, {:length, 0}] do
+      if options.body == :none do
         nil
       else
         {:ok, stream} = Stream.start_link(0)
```

Before SHA256: `a4f6e5f6a2e7212ab641c8a33bb10d177d9ffba008362945620b6aa6e402cf22`
After SHA256: `b0fc774be009a2fea62ceee3a7fd7e8a35be7096ebaa249713678c9a1bdfe6c9`

Static checks PASS: exact single replacement against archive, no trailing whitespace, final newline, unchanged hashes for matrix run.py, independent client and ExUnit case registry. Tests/assertions/docs/dependencies untouched by this worker. No Elixir parse, runtime, Mix, tests, Git or browser commands run. Existing prior red real-wire matrix remains unchanged and is the regression. Root must verify CL0 bytes/framing, EOF, original completion/upload join and reuse after review.

Prior root evidence remains16 tests/12 failures/exit2; H1 standalone failed first POST /empty explicit Content-Length oracle. Diagnosis1 reports preserved. Shared fixture H2 budget/exception masking belongs to the other worker.

Counters: root-targeted Sol round3; this worker one implementation edit; root counter12 unchanged; Astra2/2 exhausted and unchanged; no escalation gate. All worker commands finished and no runtime processes launched. No new product decision needed.
