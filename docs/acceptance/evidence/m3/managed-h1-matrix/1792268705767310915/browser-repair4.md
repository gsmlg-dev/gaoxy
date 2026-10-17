# Managed-H1 browser process-group repair4

DONE for implementation/static inspection; runtime NOT RUN. Direct targeted Sol repair4, Astra2/2 exhausted and unchanged. Ownership only `integration/upstream_transport/browser.py`; no other repository file edited. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.

Baseline candidate4 hash `f2920e140f7171a5ac31ee4b2034d9f4078928c0947fcdc71630a2a8bfd2b21c` matched before editing. After hash `c5251ea1d8847bc76c47275d3bce545961a2be7c1a17076293441479045d5713`.

Browser1 evidence:2 real row PASS, named Node/Chrome leaders exit0, but final disposal forced both remaining Node process groups and marked them unjoined. The outer collector subsequently reaped12 Chrome descendants rawstatus0 without force. This supports the missing adopted-child reaper diagnosis; it does not prove child state before the original signal. Historical FAIL remains unchanged.

The coordinator enables and verifies Linux child-subreaper status before Actor spawn. Each Actor retains its named Popen wait. After the leader is collected, it reaps only actual adopted children of that original owned PGID using waitpid(-pgid,WNOHANG), retaining PID/PGID/rawstatus/decoded exit/phase. Normal join waits for group disappearance within the original10s/remaining-case bounds. Failure disposal waits naturally before force, then partitions the remaining original10s budget for TERM/KILL and actual reaping; exception recording and other-actor disposal remain intact. No new helper-exit0 oracle was introduced; existing named-process and cleanup assertions remain.

Static checks PASS: ast.parse without candidate import; identical AST for all protocol/body/page/readiness/SPKI functions, existing actor read/send/event/call functions, and main require assertions. Deadlines unchanged10/5/20/600; whitespace clean. Runtime, browser, Mix, Git, imports and tests NOT RUN by assignment. All worker commands completed.

Chrome spawn in browser.mjs does not request detached sessions. Descendant-created new PGIDs are not proved absent and are outside the narrowly owned group waits; root outer adopted-child receipts must remain visible. Prior Mix-helper rawstatus10 remains factual, without role speculation or acceptance changes. No dependency defect or upstream issue established.

Exact diff:

```diff
--- before/integration/upstream_transport/browser.py
+++ after/integration/upstream_transport/browser.py
@@ -6,6 +6,7 @@
 """
 import argparse
 import base64
+import ctypes
 import hashlib
 import importlib.metadata
 import json
@@ -58,12 +59,25 @@
     return dict(path=path, resolved=str(resolved), sha256=sha(resolved.read_bytes()))
 
 
+def child_subreaper():
+    require(sys.platform == 'linux', 'owned browser child reaping requires Linux')
+    libc = ctypes.CDLL(None, use_errno=True)
+    if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
+        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
+    enabled = ctypes.c_int()
+    if libc.prctl(37, ctypes.byref(enabled), 0, 0, 0) != 0:  # PR_GET_CHILD_SUBREAPER
+        raise OSError(ctypes.get_errno(), 'PR_GET_CHILD_SUBREAPER')
+    require(enabled.value == 1, 'browser coordinator is not a child subreaper')
+    return dict(pid=os.getpid(), enabled=True)
+
+
 class Actor:
     """One owned process group, finite JSON bridge, bounded diagnostic log."""
     def __init__(self, argv, directory, name, actors):
         self.argv, self.name = argv, name
         self.events, self.rows, self.threads = queue.Queue(maxsize=4096), [], []
         self.closed, self.forced, self.exit_code = False, False, None
+        self.reaped = []
         self.deadline = None
         self.process, self.log = None, None
         self.lock = threading.Lock()
@@ -139,9 +153,44 @@
         self.send(value)
         return self.event(expected, timeout)
 
+    def group_alive(self):
+        if self.process is None:
+            return False
+        try:
+            os.killpg(self.process.pid, 0)
+            return True
+        except ProcessLookupError:
+            return False
+
+    def reap_adopted(self, expires, phase):
+        # Popen retains the named leader's wait; only then collect adopted
+        # children in this actor's original, isolated process group.
+        if self.process is None or self.process.returncode is None:
+            return
+        while time.monotonic() < expires:
+            try:
+                pid, status = os.waitpid(-self.process.pid, os.WNOHANG)
+            except ChildProcessError:
+                return
+            if pid == 0:
+                return
+            self.reaped.append(dict(pid=pid, owned_pgid=self.process.pid,
+                                    wait_status=status, exit=os.waitstatus_to_exitcode(status), phase=phase))
+
+    def await_group(self, expires, phase):
+        while True:
+            self.reap_adopted(expires, phase)
+            if not self.group_alive():
+                return True
+            remaining = expires - time.monotonic()
+            if remaining <= 0:
+                return False
+            time.sleep(min(0.05, remaining))
+
     def join(self):
         expires = min(time.monotonic() + START, self.deadline or float('inf'))
         self.exit_code = self.process.wait(timeout=max(0, expires - time.monotonic()))
+        require(self.await_group(expires, 'normal'), self.name + ' owned process group not joined')
         for thread in self.threads:
             thread.join(timeout=max(0, expires - time.monotonic()))
         require(not any(thread.is_alive() for thread in self.threads), self.name + ' log thread not joined')
@@ -149,7 +198,8 @@
         self.process.stdin.close()
         self.log.close()
         self.closed = True
-        return dict(argv=self.argv, pid=self.process.pid, exit=self.exit_code, forced=False, threads_joined=True)
+        return dict(argv=self.argv, pid=self.process.pid, owned_pgid=self.process.pid,
+                    exit=self.exit_code, forced=False, threads_joined=True, reaped=list(self.reaped))
 
     def dispose(self):
         expires = time.monotonic() + START
@@ -160,16 +210,18 @@
                 errors.append(repr(error))
 
         def group_alive():
-            if self.process is None:
+            try:
+                return self.group_alive()
+            except Exception as error:
+                failed(error)
+                return True
+
+        def await_group(deadline, phase):
+            try:
+                return self.await_group(deadline, phase)
+            except Exception as error:
+                failed(error)
                 return False
-            try:
-                os.killpg(self.process.pid, 0)
-                return True
-            except ProcessLookupError:
-                return False
-            except Exception as error:
-                failed(error)
-                return True
 
         def signal_group(value):
             try:
@@ -179,10 +231,20 @@
             except Exception as error:
                 failed(error)
 
-        # A reaped leader does not imply that its owned descendants have exited.
+        # Give the leader and adopted children a normal join before any signal.
+        normal_expires = min(expires, time.monotonic() + BARRIER, self.deadline or float('inf'))
+        if self.process is not None:
+            try:
+                self.exit_code = self.process.wait(timeout=max(0, normal_expires - time.monotonic()))
+            except subprocess.TimeoutExpired:
+                pass
+            except Exception as error:
+                failed(error)
+        await_group(normal_expires, 'normal')
         if group_alive():
             self.forced = True
-            term_expires = min(expires, time.monotonic() + BARRIER)
+            # Keep TERM and KILL/reap inside the original shutdown budget.
+            term_expires = time.monotonic() + max(0, expires - time.monotonic()) / 2
             signal_group(signal.SIGTERM)
             if self.process.poll() is None:
                 try:
@@ -191,8 +253,7 @@
                     pass
                 except Exception as error:
                     failed(error)
-            while group_alive() and time.monotonic() < term_expires:
-                time.sleep(min(0.05, max(0, term_expires - time.monotonic())))
+            await_group(term_expires, 'term')
             if group_alive():
                 signal_group(signal.SIGKILL)
         if self.process is not None:
@@ -200,15 +261,15 @@
                 self.exit_code = self.process.wait(timeout=max(0, expires - time.monotonic()))
             except Exception as error:
                 failed(error)
-        while group_alive() and time.monotonic() < expires:
-            time.sleep(min(0.05, max(0, expires - time.monotonic())))
+        await_group(expires, 'forced' if self.forced else 'normal')
         for thread in self.threads:
             try:
                 if thread.is_alive():
                     thread.join(timeout=max(0, expires - time.monotonic()))
             except Exception as error:
                 failed(error)
-        joined = not group_alive() and not any(thread.is_alive() for thread in self.threads)
+        joined = ((self.process is None or self.process.returncode is not None) and
+                  not group_alive() and not any(thread.is_alive() for thread in self.threads))
         for stream in (self.process.stdin if self.process is not None else None,
                        self.process.stdout if self.process is not None and joined else None,
                        self.process.stderr if self.process is not None and joined else None,
@@ -218,7 +279,8 @@
                     stream.close()
                 except Exception as error:
                     failed(error)
-        result = dict(name=self.name, forced=self.forced, exit=self.exit_code, joined=joined)
+        result = dict(name=self.name, owned_pgid=self.process.pid if self.process is not None else None,
+                      forced=self.forced, exit=self.exit_code, joined=joined, reaped=list(self.reaped))
         if errors:
             result['failure'] = errors
         return result
@@ -353,8 +415,10 @@
     old_alarm = signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('outer600s deadline')))
     signal.alarm(OUTER)
     try:
+        subreaper = child_subreaper()
         before = sources()
         environment = dict(python=sys.version, executable=sys.executable,
+                           child_subreaper=subreaper,
                            executable_sha256=sha(Path(sys.executable).read_bytes()), argv=sys.argv,
                            cwd=str(ROOT), env={key: os.environ.get(key) for key in ('MIX_ENV', 'ERL_FLAGS')},
                            packages={name: importlib.metadata.version(name) for name in ('h2', 'hpack', 'hyperframe')},
```

Ownership returned to root for freeze, independent review and actual browser2.
