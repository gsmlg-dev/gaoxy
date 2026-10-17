# Fixed plateau browser source proposal

Status: SOURCE PROPOSAL READY; runtime NOT RUN. Tests executed: 0.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Baseline: `88e435a73429666717a4d20a83f9fca13e0a67e9`.

This proposal writes only the owned /tmp directory and reports. No repository/E4/E5 bytes changed. No fixture or runtime was executed.

## Exact scope

Two host cohort path literals E4->E5; one runner COHORT path E4->E5; collector dictionary iterable fixed+group -> (args.endpoint,). No other bytes change.

Retain six basenames; root freezes --endpoint fixed. One-line invocation binding makes source inventory explicitly follow selected endpoint without requiring group copies or changing fixed row/assert/actor/custody logic.

## Static comparison evidence

Three Python AST parses succeeded. All113 runner assertions and4 collector assertions (117 total) are identical, including line numbers. Syntax checker has0 Assert statements. Runner/collector full ASTs equal exactly the expected single binding substitutions.

BROWSER bytes: 8052; unchanged SHA256 `82e4355f23827561fe0a11646b4eddff0fcc173171ec6e723814420ca4e354f1`. Cohort, syntax checker and enum JSON are exact byte copies. Named E4 input bytes were rechecked and all six proposed disk hashes checked.

| File | Before SHA256 | After SHA256 |
| --- | --- | --- |
| `fixed-identity-rotation-browser-host1.exs` | `60b33e7f3ccbe6ec6b6b2e627d6a6d5af06b5c403a01e46a42174535e56d756a` | `f9bbd6a1b9de1c2c3dc6ef4da04616adf9232c5bac194bdcd2cae49a5bc7a47b` |
| `fixed-identity-rotation-browser-runner1.py` | `efeed7290e3f6faa05d948dee55b5611d4aea2dd377327e943e68865d1b59772` | `c2dc18575e2fb022191011a4870b2aa80c0cae1217ac7289b31e0fd0518850e3` |
| `fixed-identity-rotation-browser-cohort1.exs` | `7b758fd2d105e4a9c06dafbad4b2e3687b29d3d0f5abfd4f7f630f887dcb5078` | `7b758fd2d105e4a9c06dafbad4b2e3687b29d3d0f5abfd4f7f630f887dcb5078` |
| `browser-command-collector1.py` | `54089bcbdc4ccc18153a6a4fde022a6cb5704f6614ce86fde12c2ef8ea19b392` | `60f960fceeeae3fe71e4907c8839c095b9c0f524a3dea24da7f7b9935796e86a` |
| `syntax-check1.py` | `6984fd96748fe440aaa8ecab3c8618c10d930f8c1dcaf5f1b1fd6aa2ee195914` | `6984fd96748fe440aaa8ecab3c8618c10d930f8c1dcaf5f1b1fd6aa2ee195914` |
| `chromium-netlog-event-enums1.json` | `42ad21b2f1d4a317a00a33e90712bc7aa19790a812ce06984fce5e0355eff0ca` | `42ad21b2f1d4a317a00a33e90712bc7aa19790a812ce06984fce5e0355eff0ca` |

## Exact unified diff

```diff
--- /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-host1.exs
+++ /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/fixed-identity-rotation-browser-host1.exs
@@ -1,7 +1,7 @@
 # Fixed same-authority identity rotation browser host; proposal only.
 # Derived from accepted Generation fixture; preserves original custody/accounting gates.
 Code.require_file(
-  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-cohort1.exs"
+  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/fixed-identity-rotation-browser-cohort1.exs"
 )
 
 # Evidence-only independent arithmetic. Actual complete source constructors are
@@ -834,7 +834,7 @@
             Path.expand(__ENV__.file),
             Path.join(
               root,
-              "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-cohort1.exs"
+              "docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/fixed-identity-rotation-browser-cohort1.exs"
             )
           ]
 
--- /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-runner1.py
+++ /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/fixed-identity-rotation-browser-runner1.py
@@ -23,7 +23,7 @@
 
 ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
 HOST = Path(__file__).resolve().with_name('fixed-identity-rotation-browser-host1.exs')
-COHORT = ROOT/'docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-cohort1.exs'
+COHORT = ROOT/'docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/fixed-identity-rotation-browser-cohort1.exs'
 PEER = ROOT/'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py'
 PEER_PYTHON = '/tmp/gaoxy-m3-h2-soak-venv/bin/python'
 TARGETS = {'old':'/old%2Fpath?raw=%2F', 'new':'/new%2Fpath?raw=%2F'}
--- /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/browser-command-collector1.py
+++ /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/browser-command-collector1.py
@@ -104,7 +104,7 @@
             'host': endpoint+'-identity-rotation-browser-host1.exs',
             'cohort': endpoint+'-identity-rotation-browser-cohort1.exs',
             'rows': {(endpoint, 'h1', 'http2'), (endpoint, 'h2', 'http2')},
-        } for endpoint in ('fixed', 'group')
+        } for endpoint in (args.endpoint,)
     }
     expected = endpoints[args.endpoint]
     assert args.runner == expected['runner']
```

## Root invocation proposal; NOT RUN

```text
["<stage-pinned-python>", "-B", "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-fixed-reload-plateau/1792235229996913527/browser-command-collector1.py", "--name", "fixed-browser1", "--receipt", "fixed-browser-command1", "--runner", "fixed-identity-rotation-browser-runner1.py", "--endpoint", "fixed"]
```

Root must freeze actual stage-pinned interpreter/env and fresh output names after review.

## Concerns

- Collector CLI choices remain fixed/group exactly as inherited. Freeze --endpoint fixed. The invocation-bound manifest inventories only that selected fixed triple; no group fixture is copied, hashed or executed by the proposed fixed invocation.
- Runner retains its accepted OLD/NEW identity-rotation semantics and historical fixture_development_cutoff text. This two-row smoke does not prove twenty reloads or current cumulative counters.
- Adopt all six files into E5 together. EVIDENCE/HOST/event enums are __file__ relative; host output and runner evidence directories are CLI inputs. Do not run proposal copies from /tmp.
- Copied syntax-check1.py retains E.glob("*.py") and E.parents[5]. Root must freeze actual E5 operands before execution. Host/cohort formatting and Python/extracted JavaScript syntax remain NOT RUN here.
- Runner inventory binds enum JSON. Existing collector inventory does not directly include syntax-check1.py; retain root custody pins for all six adopted sources.
- All Chrome flags, deadlines, exact body, source/BEAM/owner/Service/Gate/accounting, physical-close, actor and nonforced custody gates are unchanged. Actual runtime feasibility/PASS remains unknown.

Runtime gates remain NOT RUN: root must obtain required source SPEC then CODE, static/format evidence, fresh two browser rows/four root-viewed images and authentic exits/raw waits before reporting acceptance. No group browser execution is claimed.

First proposal guard stopped before writes on a total-count distinction:113 runner assertions plus4 collector assertions makes117. No assertion changed and no runtime repair was attempted. Inherited counter62 and Astra2/2 exhausted remain unchanged. All own commands finished; no product/dependency change or new gate proposed.
