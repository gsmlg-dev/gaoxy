# AUTHOR1 runner source handoff

Status: DONE for direct bounded source authoring. Runtime and independent acceptance remain root-owned and NOT RUN.

Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
Source: integration/upstream_transport/run.py
Before SHA256: ca5ba4136a67eee50d25aeb5fee4cdaf8494e682989e778e91e059997feda7ca
After SHA256: f7561c5a5f88c401f3665d0d06521f6debddcfeea9c2b8237cfc0ac911a12d66
Design SHA256: bd2699c8ea4b078e864753de225ef08708f682d37919ce3fddf4894286e96b6f
Git baseline: NOT READ under assignment restriction.

Added exactly six lines before the original accepted-connection assertion. A mismatched connection invokes failure_diagnostic once via existing Case.call, appends its sanitized receipt separately, or records only the diagnostic exception class. The exact original assertion remains afterward. Success flow, request IDs, all original budgets, registry, missing/FAIL/cleanup behavior and existing bytes are preserved. No functional root cause or repair is claimed.

```diff
--- integration/upstream_transport/run.py.before
+++ integration/upstream_transport/run.py.after
@@ -327,6 +327,12 @@
         request = self.event("request", role="application", method=method, target=target)
         if self.connection is None:
             self.connection = request["connection"]
+        if request["connection"] != self.connection:
+            try:
+                diagnostic = self.call(dict(op="failure_diagnostic"))
+                self.receipts.append(dict(source="failure_diagnostic", receipt=diagnostic))
+            except Exception as error:
+                self.receipts.append(dict(source="failure_diagnostic_error", error=type(error).__name__))
         check(request["connection"] == self.connection, "application changed accepted upstream connection")
         check(request["request"] not in [r["request"] for r in self.requests], "duplicate upstream request ID")
         if self.requests:
```

Inverse preservation: `sed '330,335d' integration/upstream_transport/run.py | sha256sum` exited 0 and produced the exact before SHA256. The targeted diff exited 1 because the expected six added lines differ; this is not a failed acceptance gate. Source/design hashes and inverse preservation PASS. Syntax, formatter, parser, compiler, runtime, tests, network and independent review NOT RUN by explicit assignment; zero tests executed.

Incidents: the first nonmutating inverse check used incorrect line range 333..338 and produced c23157bfeaf2fe7d985737ff4431d492f9d1f1a2447acf53a41cdee18535720e. Correcting the range to 330..335 proved preservation; no source mutation occurred in either check. The initial draft caught BaseException; root explicitly directed Exception instead to retain external interrupt/SystemExit behavior, and final source follows that direction. Neither incident involved runtime validation.

Custody: only assigned run.py and these two /tmp reports written. Other writer's fixture and all forbidden paths were not read or modified; no Git, compiler, parser, formatter, runtime or network operation. All commands have finished; no background process started. Reports are finalized and root receives their SHA256 seals separately.

Received counters remain counter40 root666/orch551/tool76/Sol6/runtimefailed6/Astra2of2; no repair or recovery round added or reset. Stage remains OPEN. Root must review and perform syntax/runtime checks; historical failures remain unchanged. No decisions needed.
