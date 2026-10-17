# H2 identity rotation final inventory3

Status: **DONE planning only; every execution NOT RUN**. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Inherited baseline `8f6b884524d81d8defa7c5081230b8ab635e8107` was not queried by this task.

Authoritative data: `/tmp/gaoxy-h2-identity-final-inventory3.json`, SHA256 `766a8d3da8c4bcc5178b62eabcc6309c52297e4ca86fa6b7a4ced2d42bc58db1`. Source/availability hashes are read-only planning snapshots; root must perform its final freeze and independent SPEC then dependent CODE review.

## Final command inventory

All commands run from the repository above, serially, with 600-second planned command timeout and the collectors' existing bounded cleanup. The first nine child argv arrays are identical to proposal2. Only collector names/output paths use `-final1`. Final browsers use `green2/command2`.

| # | Name | Kind | Timeout | State |
|---|---|---|---:|---|
| 1 | `identity-final-strict-compile1-final1` | static | 600s | NOT RUN |
| 2 | `identity-final-format1-final1` | static | 600s | NOT RUN |
| 3 | `identity-final-syntax1-final1` | static | 600s | NOT RUN |
| 4 | `identity-final-scoped1-final1` | green | 600s | NOT RUN |
| 5 | `identity-final-scoped2-final1` | green | 600s | NOT RUN |
| 6 | `identity-final-scoped3-final1` | green | 600s | NOT RUN |
| 7 | `identity-final-consumer-core1-final1` | green | 600s | NOT RUN |
| 8 | `identity-final-consumer-http1-final1` | green | 600s | NOT RUN |
| 9 | `identity-final-peer-startup1-final1` | static | 600s | NOT RUN |
| 10 | `fixed-browser-green2` | browser | 600s | NOT RUN |
| 11 | `group-browser-green2` | browser | 600s | NOT RUN |

### 1. identity-final-strict-compile1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-strict-compile1-final1",
  "--timeout",
  "600",
  "--kind",
  "static",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "MIX_ENV=test",
  "unbuffer",
  "mix",
  "compile",
  "--force",
  "--warnings-as-errors"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-strict-compile1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-strict-compile1-final1.log`.
Depends on: full-stage SPEC PASS then dependent CODE PASS; exact source inventory frozen.

### 2. identity-final-format1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-format1-final1",
  "--timeout",
  "600",
  "--kind",
  "static",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "unbuffer",
  "mix",
  "format",
  "--check-formatted",
  "apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex",
  "apps/gaoxy_http/test/http2_worker_startup_test.exs",
  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-host1.exs",
  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-cohort1.exs",
  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-identity-rotation-browser-host1.exs",
  "/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-identity-rotation-browser-cohort1.exs"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-format1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-format1-final1.log`.
Depends on: identity-final-strict-compile1-final1.

### 3. identity-final-syntax1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-syntax1-final1",
  "--timeout",
  "600",
  "--kind",
  "static",
  "--",
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/syntax-check1.py"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-syntax1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-syntax1-final1.log`.
Depends on: identity-final-format1-final1.

### 4. identity-final-scoped1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-scoped1-final1",
  "--timeout",
  "600",
  "--kind",
  "green",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "MIX_ENV=test",
  "unbuffer",
  "mix",
  "test",
  "--warnings-as-errors",
  "--max-cases",
  "1",
  "apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-scoped1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-scoped1-final1.log`.
Depends on: identity-final-syntax1-final1.

### 5. identity-final-scoped2-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-scoped2-final1",
  "--timeout",
  "600",
  "--kind",
  "green",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "MIX_ENV=test",
  "unbuffer",
  "mix",
  "test",
  "--warnings-as-errors",
  "--max-cases",
  "1",
  "apps/gaoxy_proxy/test/upstream_transport_generation_test.exs",
  "apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs",
  "apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs",
  "apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs",
  "apps/gaoxy_proxy/test/upstream_group_transport_test.exs",
  "apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs",
  "apps/gaoxy_proxy/test/managed_generation_accounting_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_preparation_test.exs",
  "apps/gaoxy_proxy/test/upstream_group_proxy_test.exs"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-scoped2-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-scoped2-final1.log`.
Depends on: identity-final-scoped1-final1.

### 6. identity-final-scoped3-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-scoped3-final1",
  "--timeout",
  "600",
  "--kind",
  "green",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "MIX_ENV=test",
  "unbuffer",
  "mix",
  "test",
  "--warnings-as-errors",
  "--max-cases",
  "1",
  "apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_accounting_probe_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_pin_response_test.exs",
  "apps/gaoxy_http/test/generation_endpoint_validation_test.exs",
  "apps/gaoxy_http/test/generation_resource_consistency_test.exs",
  "apps/gaoxy_http/test/generation_resources_test.exs",
  "apps/gaoxy_http/test/generation_checked_capture_test.exs",
  "apps/gaoxy_http/test/generation_release_deadline_test.exs",
  "apps/gaoxy_http/test/generation_test.exs",
  "apps/gaoxy_http/test/http2_worker_startup_test.exs",
  "apps/gaoxy_http/test/http2_stale_start_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_group_source_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_envelope_test.exs",
  "apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-scoped3-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-scoped3-final1.log`.
Depends on: identity-final-scoped2-final1.

### 7. identity-final-consumer-core1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-consumer-core1-final1",
  "--timeout",
  "600",
  "--kind",
  "green",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "bash",
  "scripts/external-consumer.sh"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-consumer-core1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-consumer-core1-final1.log`.
Depends on: identity-final-scoped3-final1.

### 8. identity-final-consumer-http1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-consumer-http1-final1",
  "--timeout",
  "600",
  "--kind",
  "green",
  "--",
  "nix",
  "develop",
  "--command",
  "env",
  "ERL_FLAGS=+S 2:2",
  "bash",
  "scripts/http-consumer.sh"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-consumer-http1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-consumer-http1-final1.log`.
Depends on: identity-final-consumer-core1-final1.

### 9. identity-final-peer-startup1-final1

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py",
  "--name",
  "identity-final-peer-startup1-final1",
  "--timeout",
  "600",
  "--kind",
  "static",
  "--",
  "/tmp/gaoxy-m3-h2-soak-venv/bin/python",
  "-B",
  "apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py",
  "-v"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-peer-startup1-final1.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-peer-startup1-final1.log`.
Depends on: identity-final-consumer-http1-final1.

### 10. fixed-browser-green2

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/browser-command-collector1.py",
  "--endpoint",
  "fixed",
  "--name",
  "fixed-browser-green2",
  "--receipt",
  "fixed-browser-command2",
  "--runner",
  "fixed-identity-rotation-browser-runner1.py"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-browser-command2.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-browser-command2.log`.
Depends on: identity-final-peer-startup1-final1 AND identity-final-peer-startup1-final1-unittest-audit1 PASS; initial fixed/group browser1 qualification PASS or preserved actual status; full-stage SPEC then dependent CODE PASS; all previous final commands PASS.
Artifacts: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-browser-green2`; qualification: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-browser-green2/qualification.json`.

### 11. group-browser-green2

Exact full argv (JSON, no shell interpretation):

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/browser-command-collector1.py",
  "--endpoint",
  "group",
  "--name",
  "group-browser-green2",
  "--receipt",
  "group-browser-command2",
  "--runner",
  "group-identity-rotation-browser-runner1.py"
]
```

Receipt: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-browser-command2.json`; log: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-browser-command2.log`.
Depends on: fixed-browser-green2 AND identity-final-peer-startup1-final1-unittest-audit1 PASS.
Artifacts: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-browser-green2`; qualification: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-browser-green2/qualification.json`.

## Counts and scope

Scoped batches contain 9/9/17 path entries: 35 entries, 34 distinct files. Complete `managed_h2_fixed_endpoint_test.exs` repeats in batches 1 and 3. Batch 2 adds complete preparation (40 source registrations) and upstream-group proxy (7 source registrations). No filters, exclusions, skips or warning waivers are introduced. Exact path arrays appear in JSON and argv above.

239/170/475 = 884 is historical ExUnit invocations. Consumer historical core 1 / HTTP 2 remain separate. 940 is proposal2 prospective source-registration arithmetic only, never an expected or observed PASS total. Fresh ExUnit counts are unknown and require actual nonzero execution with zero failures/skips/exclusions/unexpected warnings. Strict compile/format/syntax execute zero protocol tests.

Python startup is the unchanged 11-method unittest suite under the exact pinned interpreter. Historical 19/0 is native H2 ExUnit `http2_worker_startup_test.exs`, already in batch 3; historical Python is 11/0. The static generic receipt retains ExUnit-only tests/reported_tests 0. Its PASS alone is insufficient. Mandatory separate audit requires exact raw-log binding, actual terminal `Ran 11 tests in ...` and `OK`, all eleven unique verbose successful method rows, zero errors/failures/skips/expected failures/unexpected successes/exclusions, normal actual joins and final source/receipt/collector/log hashes. Do not fabricate ExUnit output or rewrite receipt counts. This audit is not a twelfth protocol command. Full unchanged contract and exact method IDs are in JSON.

## Initial and final browser separation

Preserve initial fixed/group `green1/command1` names and commands below as conditional qualification prerequisites/reference, excluded from the eleven final commands. Record existing/unexecuted status, never overwrite, and recheck availability before launch.

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/browser-command-collector1.py",
  "--endpoint",
  "fixed",
  "--name",
  "fixed-browser-green1",
  "--receipt",
  "fixed-browser-command1",
  "--runner",
  "fixed-identity-rotation-browser-runner1.py"
]
```

```json
[
  "python3",
  "-B",
  "docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/browser-command-collector1.py",
  "--endpoint",
  "group",
  "--name",
  "group-browser-green1",
  "--receipt",
  "group-browser-command1",
  "--runner",
  "group-identity-rotation-browser-runner1.py"
]
```

Final browser2 requires exactly fixed `(h1,http2),(h2,http2)` plus group `(h1,http2),(h2,http2)`: two rows per endpoint, four total. Each row has OLD and NEW screenshots: four images per endpoint, eight root views. Navigations are not rows; initial browser1 runs are not aggregated into final counts.

Browser receipt PASS requires actual exit0, joined/group gone, no timeout/wait error/forced cleanup/remnants, exact rowset and executed2, unchanged final source, matching collector/log/qualification/all-artifact hashes. Qualification binds all original actual joins, custody, source, trust rotation, physical health/forwarding connections, native H2 accounting and cleanup. Actor exits must remain actual normal0; do not synthesize closure, normalize waits, or weaken existing assertions. `fixture_development_cutoff` and `astra` are historical annotations.

Browser visibility is actual DOM/title/text/URL, status200/protocol, exact response bytes/hash and all eight root-viewed images. Existing BROWSER assertions reject console/Runtime exceptions; inspect allowed `old/new-browser-events.json` when needed. Do not invent a console field on a case row or inspect raw NetLog. Full receipt fields and case acceptance contract are in JSON.

## Source/path inventory and audit

JSON includes all exact scoped/format/syntax paths, both collectors, endpoint runners/hosts/cohorts, peer/suite, scripts, planned receipt/log/qualification/allowed artifact paths, and separate generic/browser-collector/endpoint-runner manifest inventories with current SHA256 hashes. Endpoint-runner actual receipt manifests use absolute keys. Source hashes are snapshots and must be reconciled after concurrent root-owned repairs; no loaded runtime proof or review PASS is implied.

Direct stage Python snapshot:

- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/browser-command-collector1.py`
- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/command-collector1.py`
- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/fixed-identity-rotation-browser-runner1.py`
- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/group-identity-rotation-browser-runner1.py`
- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/syntax-check1.py`

Generic manifest: 401 files; browser collector: 399 files; endpoint runner manifests: fixed 286, group 286.
Filename-only prohibited candidates skipped without content reads: 0; missing planned source paths: 0; source drift during paired snapshot reads: 0. Root must still recheck before freeze.

Startup audit outputs:

- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-peer-startup1-final1-unittest-audit1.json`
- `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/identity-final-peer-startup1-final1-unittest-audit1.md`

Common collector acceptance checks bind exact command/cwd, collector hash, actual exit, actual waits/descendant cleanup, matching source_before/source_after with empty changes, and actual raw-log hash. Static warnings require explicit inspection because the static verdict alone does not reject them. Preserve Nix dirty-tree annotations for classification and keep all unexpected warnings visible.

## Planning verification and handoff

Planning data invariants were checked before writing: eleven commands; every timeout600; all nine child arrays preserved; 9/9/17 entries and 34 distinct paths; exact startup audit name; unchanged startup-suite hash. Readback and report hashes are recorded by the handoff command. No candidate code imported/executed and no syntax, tests, builds, browser, network, Git, process action, private-key/raw-NetLog/prohibited-trace reads or repair self-review occurred. Only these two `/tmp` reports were written.

Latest received counters, unchanged: `root160/orch86/tooling26/groupfailed56/runtimefailed2/fixtureRepair2/Solrepair2/production0/Astra2/2`. Inventory3 adds zero tooling errors, runtime failures, Sol repairs or Astra rounds. All own commands completed. Root owns final review/freeze, initial qualification, all eleven final executions, startup audit and image inspection.
