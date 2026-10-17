Task h2_identity_full_code/close-diagnostic-proposal1 — DONE_PROPOSAL_NOT_EXECUTED.

Diagnostic copy only: /tmp/gaoxy-h2-identity-close-diagnostic-runner1.py

Active runner SHA256: 478a91928f42e5b0bdb154e7b383b1c83a5d7af6a80f90d52b890225e6089d74
Diagnostic runner SHA256: e05583648365a81a3e7e5106bfa251c288e52b55f19ea46d95e9c26882973049

Projection changes: fixed close_reason enum plus description_present boolean for HTTP2_SESSION_CLOSE; unknown description strings never stored. Add only the three source-verified network notification names. No arbitrary string/address parameter rule is added. Explicit ORIGINAL_RUNNER preserves real host/collector paths after relocating the copy to /tmp; inventory retains every original binding and adds diagnostic self, intended +1 path (286 to287).

The entire embedded browser JavaScript is byte-identical. All argv, headers, assertions, live cuts, deadlines, matrix, custody, cleanup order and qualification rules remain as in active candidate5. No runtime/import/compile/test/Git operation was performed. Parent must independently review static text and own any bounded diagnostic execution. Final acceptance must still use original candidate5. Root181/group61/runtime7/tooling38/Sol5/Astra2of2 retained. All commands complete.

Public matching-revision source links and line numbers are in the JSON; no full source SHA is claimed. The close enum may identify the graceful drain path without its initiating event. Network event absence in an incomplete projection cannot exclude a notification. SSL/certificate observer events are not invented.

```diff
--- /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-runner1.py
+++ /tmp/gaoxy-h2-identity-close-diagnostic-runner1.py
@@ -22,7 +22,8 @@
 import traceback
 
 ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
-HOST = Path(__file__).resolve().with_name('fixed-identity-rotation-browser-host1.exs')
+ORIGINAL_RUNNER = ROOT/'docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-runner1.py'
+HOST = ORIGINAL_RUNNER.with_name('fixed-identity-rotation-browser-host1.exs')
 COHORT = ROOT/'docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-cohort1.exs'
 PEER = ROOT/'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py'
 PEER_PYTHON = '/tmp/gaoxy-m3-h2-soak-venv/bin/python'
@@ -159,6 +160,16 @@
     'TCP_CONNECT', 'TCP_CONNECT_ATTEMPT', 'SSL_CONNECT', 'SSL_HANDSHAKE_ERROR',
     'SSL_SHUTDOWN', 'HTTP_STREAM_JOB_BOUND_TO_REQUEST',
     'HTTP_STREAM_REQUEST_BOUND_TO_JOB', 'HTTP2_STREAM',
+    'NETWORK_IP_ADDRESSES_CHANGED', 'NETWORK_CONNECTIVITY_CHANGED', 'NETWORK_CHANGED',
+}
+# Diagnostic-only fixed enums from the recorded Chromium revision; no raw descriptions.
+_CLOSE_REASONS = {
+    'Finished going away': 'FINISHED_GOING_AWAY',
+    'Closing idle connection.': 'IDLE_CONNECTION',
+    'Connection closed': 'CONNECTION_CLOSED',
+    'Write error': 'WRITE_ERROR',
+    'Closing current sessions.': 'CURRENT_SESSIONS',
+    'Closing all sessions.': 'ALL_SESSIONS',
 }
 _INT_KEYS = {
     'stream_id', 'last_stream_id', 'error_code', 'net_error', 'byte_count',
@@ -214,6 +225,12 @@
     if isinstance(params, dict):
         projected = {key: params[key] for key in sorted(_INT_KEYS) if _integer(params.get(key))}
         projected.update({key: params[key] for key in sorted(_BOOL_KEYS) if type(params.get(key)) is bool})
+        if name == 'HTTP2_SESSION_CLOSE':
+            description = params.get('description')
+            present = isinstance(description, str)
+            projected['description_present'] = present
+            projected['close_reason'] = (_CLOSE_REASONS.get(description, 'OTHER')
+                                         if present else 'ABSENT')
         error_code = params.get('error_code')
         if isinstance(error_code, str) and error_code in _ERROR_NAMES:
             projected['error_code'] = error_code
@@ -403,7 +420,7 @@
     paths = [path for folder in ('apps', 'config') for path in (ROOT/folder).rglob('*')
              if path.is_file() and path.suffix in ('.ex', '.exs') and not any(
                  part in ('deps', '_build') for part in path.relative_to(ROOT).parts)]
-    paths += [ROOT/'mix.exs', ROOT/'mix.lock', ROOT/'scripts/generate-fixtures.sh', HOST, COHORT, PEER, Path(__file__).resolve(), Path(__file__).resolve().with_name('browser-command-collector1.py')]
+    paths += [ROOT/'mix.exs', ROOT/'mix.lock', ROOT/'scripts/generate-fixtures.sh', HOST, COHORT, PEER, ORIGINAL_RUNNER, Path(__file__).resolve(), ORIGINAL_RUNNER.with_name('browser-command-collector1.py')]
     return {str(path): digest(path) for path in sorted(paths)}
 
 
```

Final static checks: each of four original full-string replacement anchors occurs exactly once in the active source (expected1/observed1); exact anchor text is recorded in JSON. The unified diff has five narrow hunks because one replacement adds ORIGINAL_RUNNER and adapts HOST. Full embedded BROWSER strings are equal: 8052 UTF-8 bytes, SHA256 82e4355f23827561fe0a11646b4eddff0fcc173171ec6e723814420ca4e354f1. Runner remains frozen at SHA256 e05583648365a81a3e7e5106bfa251c288e52b55f19ea46d95e9c26882973049. No execution/import/compilation performed.
