# Test workflow separation implementation plan

> For agentic workers: use subagent-driven-development or executing-plans.
> Follow the task dependencies and ownership below. Preserve concurrent work.

**Goal:** Make test.yml a single Linux, fully mocked unit-test gate; separate
real-client integration, packaging, cross-platform smoke and Linux E2E; remove
browser testing.

**Architecture:** Reuse the existing file/count runner as the execution source.
Split mixed files, migrate each entry to one ordinary owner, and keep
cross-platform execution exclusively in portable.yml.

**Tech stack:** GitHub Actions, Elixir 1.18.5 / OTP 28.5, the existing macOS
BEAM baseline only for portable smoke, Python, curl, HTTPFetch, httpx, h2,
aioquic and websockets.

**Design:** ../designs/test-workflow-separation.md
**Baseline:** 09715de3f165db134e287e1ea5fd4e93b1325905
**Current deliverable:** Independently reviewed design and plan. All implementation boxes below are open.

## 1. Execution order and ownership

| Task | Owner/files | Dependency |
| --- | --- | --- |
| A: Freeze coverage and define selectors | Manifest/inventory owner: scripts/check-repairs.py and its unit tests; new inventory/checker | First |
| B: Split mixed tests | Test owner: app test files listed below | A's schema; can run beside C |
| C: Remove browsers and retain client coverage | Client owner: integration browser/client files and current usage docs | Design; can run beside B |
| D: Move ordinary workflows | Workflow owner: ci/test/integration/package/portable/release YAML | A, B and C |
| E: Small platform smoke | Smoke owner: isolated portable consumer and portable.yml | A; workflow writer serializes YAML edits with D |
| F: Linux client E2E | E2E owner: integration/e2e and e2e.yml | C and existing runtime artifact contract |
| G: Independent review and verification | Independent reviewers, then coordinator | All affected implementation |

Use Sol for implementation and ordinary review. Give each writer exclusive file
ownership. Shared runner changes precede dependent workflow edits. No worker may
revert another worker's changes. New worktrees, if needed at execution time,
belong in .trees/ on codex/ branches.

## Task A: Freeze coverage and define one executable manifest

**Modify:** scripts/check-repairs.py, scripts/test-check-repairs.py.
**Create:** scripts/test-inventory.json, scripts/check-test-inventory.py,
scripts/test-check-test-inventory.py.

- [ ] Record the actual starting SHA/status and all old active commands. Import
  the manifest without running its main function:

  ~~~python
  import importlib.util
  from pathlib import Path
  spec = importlib.util.spec_from_file_location('gate', Path('scripts/check-repairs.py'))
  gate = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(gate)
  for name, entries in gate.SUITES.items():
      print(name, len(entries), sum(count for _, count in entries))
  ~~~

  At the reviewed baseline expect unit=182, test_helpers=69, protocol=33,
  composition=77. The eleven additional files account for 46 static cases.
  These source counts are not execution evidence.

- [ ] Add inventory-checker unit regressions for an unknown test file, missing
  active file, duplicate active ownership, active/retained overlap, wildcard
  retention, nonpositive count and a valid explicit retained file. Use temporary
  fixture trees and fake manifests; do not run Mix or open sockets.
- [ ] Run python3 scripts/test-check-test-inventory.py and preserve its initial
  failure before implementing the checker.
- [ ] Keep SUITES as the only active path/count authority. Expose unit,
  component and protocol; all walks their union once. Keep MIX_ENV=test,
  warnings-as-errors, seed 0 and the existing count/failure protections.
- [ ] Until Task D migrates callers, keep old test_helpers/composition CLI
  selectors as aliases of canonical entries. They are not SUITES owners, do not
  duplicate counts in all and must not duplicate paths in inventory validation.
- [ ] Register existing unscheduled app files by exact path and reason in the
  inventory. Derive active ownership from SUITES rather than storing it twice.
  Retain existing specialist dispositions; do not execute retained entries.
- [ ] Implement checker arguments --root and --manifest so temporary regression
  fixtures do not depend on the real checkout. With no arguments it checks the
  current repository and imports scripts/check-repairs.py.
- [ ] Run the new inventory regression script, scripts/test-check-repairs.py
  and scripts/check-test-inventory.py. Expected: nonzero unit regressions pass;
  inventory has no unknown/missing/duplicate paths.

## Task B: Split files at the unit/mock boundary

Move existing tests and their required helpers; preserve test names, assertions,
timeouts and synchronization. Module names in new files must be unique. Do not
use line-number selectors or exclude network cases from a mixed unit file.

All paths in the table are relative to apps/. Counts are planning values.

| Existing file | Unit disposition | Component/protocol disposition |
| --- | --- | --- |
| gaoxy_http/test/mixed_connection_lifecycle_test.exs | None | Entire 19 cases |
| gaoxy_http/test/connection_poll_test.exs | None | Entire 11 cases |
| gaoxy_http/test/native_proxy_seams_test.exs | None | Entire 21 cases |
| gaoxy_http/test/http_protocol_defaults_test.exs | Keep 9 | New http_protocol_defaults_network_test.exs, 2 |
| gaoxy_http/test/websocket_configured_limits_test.exs | Keep 5 | New websocket_configured_limits_network_test.exs, 1 |
| gaoxy_http/test/stream_lifetime_test.exs | New stream_lifetime_config_test.exs, 1 | Keep 9 |
| gaoxy_http/test/supervised_shutdown_budget_test.exs | New supervised_shutdown_budget_config_test.exs, 1 | Keep 4 |
| gaoxy_http/test/stream_lifetime_generation_test.exs | None | Entire 9 multi-component cases |
| gaoxy_test/test/helper_test.exs | New sse_encoding_test.exs, 1 | Keep 16 |
| gaoxy_test/test/protocol_test.exs | New server_profile_config_test.exs, 1 | Keep 12 |
| gaoxy/test/backend_options_test.exs | Keep first 5 | New backend_options_runtime_test.exs, 4 |
| gaoxy_http/test/backend_options_test.exs | Keep first 2 | New backend_options_runtime_test.exs, 3 |
| gaoxy_http3/test/backend_options_test.exs | Keep first 1 | New backend_options_network_test.exs, 4 |
| gaoxy/test/staged_activation_test.exs | New activation_config_test.exs, 1 | Keep 11 |
| gaoxy_http/test/listener_set_test.exs | New listener_set_plan_test.exs, 6 | Keep 4 |
| gaoxy_proxy/test/gateway_test.exs | New gateway_plan_test.exs, 2 | Keep 5 |
| gaoxy_proxy/test/gateway_lifecycle_test.exs | New gateway_config_test.exs, 3 | Keep 10 |

- [ ] Assign the remaining pure parser/options/header/renderer files to unit.
  Keep gaoxy_test/expectations_test.exs, HTTP phoenix_adapter and
  gateway_generation tests as isolated unit candidates.
- [ ] Keep gaoxy_test core/lifecycle/recovery/subprocess, stream_lifetime_h2,
  H3 listener network and server Gateway listener files outside unit. Review
  fake transports directly; a transport name alone does not imply real I/O.
- [ ] Confirm each retained unit uses mocks/doubles for service boundaries.
  Do not call a real server even to obtain an error or timeout.
- [ ] Add unit module declarations and check their consistency with SUITES.
  Review actual dependencies; declarations alone do not prove isolation.
- [ ] Bring all eleven inline files into the canonical manifest. Keep legacy
  selector aliases available; Task D removes them after migrating all callers.
- [ ] Preserve the one currently selected runtime_test.exs case, formerly at
  line 109, by extracting its named two-instance/fragmented-stream case to
  gaoxy/test/runtime_instance_network_test.exs. Leave the rest of the original
  file in its existing unscheduled disposition.
- [ ] Move the existing certificate_fixture, TLS, datagram_egress and
  backend_telemetry portable gates to Linux integration/package ownership.
  Do not bring their full historical neighbour suites into the run.
- [ ] Verify test-name/count conservation. For the initial 407 app cases the
  provisional partition is 184 unit / 223 component+protocol. Additional old
  portable selections are recorded separately. Any revised count requires an
  explained source mapping and fresh execution, not automatic acceptance.
- [ ] Run python3 scripts/check-repairs.py unit, component and protocol
  separately. Expected: exact declared positive counts, zero failures, no skipped
  or excluded required cases. Scope failures to the affected implementation.

## Task C: Delete browser testing and use HTTP clients

**Modify:** integration/phoenix_native/{run.py,gate.py,unified.py,requirements.txt,README.md};
integration/websocket_multiplexed/{run.py,requirements.txt,README.md};
integration/http3/matrix.py and current client usage documentation.

**Delete after reference checks:** integration/http3/browser.py;
integration/websocket_multiplexed/browser.py and browser_fixture.exs;
integration/upstream_transport/browser.py and browser.mjs.

- [ ] List every executable browser import, launch, requirement and caller:

  ~~~sh
  rg -n 'playwright|chromium|browser[.]py|browser[.]mjs' integration scripts .github
  ~~~

  Inspect each hit. Historical receipts under docs/acceptance are preserved.
  Application fixture pages are not browser automation and need no product edit.
- [ ] Separate the existing independent-client checks from the browser blocks.
  Keep h11/httpx HTTP/TLS checks, H2 peers, WebSocket frames and ordinary shutdown.
- [ ] Remove browser/UI assertions, Playwright imports and browser-only scripts.
  Replace server-facing static/SSE/reload assertions with direct requests.
  Preserve source restoration in finally blocks and actual process-exit checks.
- [ ] Retain existing h2_peer.py/h3_peer.py; remove Playwright from both active
  requirements and dependency-version metadata. In particular update
  websocket_multiplexed/run.py so absence of Playwright is not a setup failure.
- [ ] Update gate.py's required-check set to client/server checks. List removed
  UI checks explicitly in the migration receipt; do not label them as passed.
  Preserve nonempty required protocol checks and protocol-version receipts.
- [ ] Use curl and httpx for overlapping basic H1 response assertions; retain
  HTTPFetch consumer compatibility and existing h2/aioquic/WebSocket peers.
  Reuse supported client APIs instead of reproducing browser/LiveView UI logic.
- [ ] Remove browser branches from retained matrix entrypoints without running
  deferred specialist matrices. Keep independent non-browser assertions and
  historical outcomes distinct.
- [ ] In a Python environment containing only the remaining client requirements,
  run the ordinary Phoenix peer gate and unified client gate:

  ~~~sh
  GAOXY_PHOENIX_EVIDENCE=.audit/workflow-split/phoenix python3 integration/phoenix_native/gate.py
  GAOXY_PHOENIX_EVIDENCE=.audit/workflow-split/unified python3 integration/phoenix_native/unified.py
  ~~~

  Prepare the existing Phoenix fixture dependencies and H2/H3 settings exactly
  as the old ordinary gate required. Expected: real client exchanges, required
  server behavior, restored source and clean fixture exit; no browser installed.

## Task D: Move ordinary workflow ownership

**Modify:** .github/workflows/{ci.yml,test.yml,portable.yml,release.yml},
AGENTS.md (a current testing-boundary section).
**Create:** .github/workflows/{integration.yml,package.yml}.

- [ ] Make ci.build Linux-only; retain formatter and strict compilation.
  Move its three Python regression executions to test.yml. Static inventory
  validation stays in ci; its unit regressions run in test.yml.
- [ ] Replace the unit matrix with this fixed job boundary:

  ~~~yaml
  jobs:
    unit:
      runs-on: ubuntu-latest
      timeout-minutes: 15
  ~~~

  Preserve checkout, fixed BEAM setup, locked dependencies and relevant cache.
  Install Python for script unit regressions. Keep a compiler only when unit
  dependency compilation actually needs it. Do not install OpenSSL fixtures,
  H2/aioquic peers, browsers or consumer projects for this job.
- [ ] Give test.yml only these behavioral entries:

  ~~~sh
  python3 scripts/test-check-tests.py
  python3 scripts/test-check-repairs.py
  python3 scripts/test-release-smoke.py
  python3 scripts/test-check-test-inventory.py
  python3 scripts/check-repairs.py unit
  ~~~

- [ ] Create Linux component/protocol/isolated-network integration jobs.
  Copy their necessary OpenSSL/client prerequisites, locks, privileged tools,
  deadlines and non-browser evidence uploads. Do not call all here.
  Assign h2_rfc/run.py, reverse_proxy/run.py and the browser-free Phoenix
  gate.py/unified.py to protocol. Assign examples/phoenix_native's existing
  Mix test command to component, retaining its fixture dependencies/settings.
- [ ] Create Linux package jobs for test-stage-hex-packages.py,
  test-consumers.py, external-consumer.sh, gateway-consumer.sh,
  h3-gateway-consumer.sh, optional QUIC consumer and source-built release smoke.
  Keep http-consumer.sh and h3-consumer.sh release-only. Preserve production/test
  dependency isolation. Do not add registry credentials or publish packages.
- [ ] Move the old portable loopback checks and release smoke to their new
  Linux owners. Replace portable's body with Task E's minimal matrix only.
- [ ] Remove browser steps, browser requirements and screenshot artifact paths
  from both ordinary and release workflows. Keep release's exact-source
  required suite, consumer qualification and pre-upload SHA checks.
- [ ] After all workflow callers reference canonical suites, delete the
  test_helpers/composition compatibility selectors. Recheck that all still
  executes the canonical union once and the inventory has one owner per path.
- [ ] Check triggers, concurrency, permissions, cache ownership and evidence
  paths against the design. Record intentional runner and UI-scope reductions.
  Python unit regressions now inherit test.yml's main-targeted triggers.
  Inspect required-check references before naming/removing jobs.
- [ ] Add a current AGENTS.md testing-boundary section: single Linux mocked
  unit gate; real clients for integration/E2E; portable-only cross-platform
  smoke; no browser testing. Retain historical scope/evidence text.
- [ ] Run actionlint on all seven workflows, plus the inventory checker and
  scripts' mocked unit regressions. Expected: no configuration errors or lost
  required entries. Hosted run status remains NOT RUN until actually observed.

## Task E: Minimal platform smoke

**Create:** integration/portable_smoke/{mix.exs,smoke.exs,README.md},
scripts/portable-smoke.py.
**Modify:** .github/workflows/portable.yml.

- [ ] Create a clean consumer of candidate gaoxy/gaoxy_http through the existing
  source-consumer staging pattern. Do not depend on proxy, Server, H3 or
  gaoxy_test for this minimal HTTP scenario.
- [ ] Implement one public-API scenario: start a native endpoint on loopback
  port 0; OTP :httpc requests /health; require 200 and body "ok"; stop in an
  after block with a finite timeout; require successful VM exit.
- [ ] Make the wrapper create its project under a temporary directory, preserve
  failure logs and print GAOXY_PORTABLE_PASS only after request and stop succeed.
  Record mode=candidate-source-boot, source SHA and platform.
- [ ] Set the only cross-platform matrix in portable.yml to ubuntu-latest
  Elixir 1.18.5/OTP 28.5 and macos-15-intel Elixir 1.20.1/OTP 29.0.2,
  fail-fast: false. Preserve existing supported targets; add no new platform.
- [ ] Run python3 scripts/portable-smoke.py on the local supported Linux
  environment. Expected: one successful request and normal stop. macOS is
  NOT RUN until a macOS runner executes it; do not infer it from Linux.

## Task F: Linux E2E using different clients

**Create:** integration/e2e/{run.py,fixture.exs,requirements.txt,README.md}.
**Modify:** .github/workflows/e2e.yml.

- [ ] Keep workflow_dispatch.version and a single Linux environment. Download
  the existing Linux runtime archive and SHA256SUMS for that version into a
  fresh directory. Verify integrity before extraction and record the release
  revision. Never compile or substitute the server under test from the checkout.
- [ ] Reuse the existing public runtime/fixture startup pattern. Bind only
  loopback ephemeral listeners. Use clients from the matching revision, with
  explicit finite start, request and stop deadlines.
- [ ] Implement this bounded client set: curl H1 status/headers/body and trusted
  HTTPS; httpx independent H1/H2, upload and streaming; HTTPFetch public-client
  compatibility; aioquic H3 request/body; existing WebSocket message/close peers.
  Require two independent clients to agree on the basic response contract.
  Check negotiated versions rather than inferring them from requested options.
- [ ] Write per-client PASS/FAIL results, actual server version and protocol,
  client/server logs and process exit. Missing prerequisites are BLOCKED_ENV,
  never a passing empty suite. Do not add browser, UI, sustained load or
  specialist exceptional-test cases.
- [ ] Validate the harness locally against an existing published Linux version:

  ~~~sh
  python3 integration/e2e/run.py --version 0.11.1 --evidence .audit/workflow-split/e2e
  ~~~

  Expected: nonempty actual client results and bounded cleanup, with no server
  build from checkout. Change the version only to another verified existing
  release; a locally built package is not an artifact-E2E pass.
- [ ] Replace the placeholder/disabled job only after its actual suite and
  cleanup are reviewed and qualified. This design task itself does not enable
  or dispatch it. Do not publish a release to obtain test inputs.

## Task G: Review, verify and commit locally

**Create:** docs/acceptance/test-workflow-separation.md.

- [ ] Independently review the design and implementation against every boundary:
  unit mocks/no requests; all cross-platform only in portable; E2E different
  clients; no browsers; no active-case loss or accidental specialist execution.
- [ ] Review the ownership ledger: each old command/case has one ordinary owner
  or an explicit UI-only retirement. Distinguish repeat verification on a
  publication source from unintended duplicate ordinary CI.
- [ ] Repair actionable findings without weakening assertions, then run fresh
  affected suites. Record source SHA/diff, environment, command, count, exit,
  PASS/FAIL/BLOCKED_ENV/NOT RUN and evidence paths.
- [ ] Run these final structural checks:

  ~~~sh
  git diff --check
  actionlint
  python3 scripts/check-test-inventory.py
  python3 scripts/test-check-tests.py
  python3 scripts/test-check-repairs.py
  python3 scripts/test-release-smoke.py
  python3 scripts/test-check-test-inventory.py
  python3 scripts/check-repairs.py unit
  ~~~

  Inspect all workflow runner declarations: only portable.yml may contain macOS
  or an OS matrix; test.yml must contain one literal ubuntu-latest unit job.
  Inspect active entrypoints/requirements for browser imports and launches.
- [ ] Keep scoped, reviewable commits for runner/test classification, browser
  removal, workflow separation and the smoke/E2E harnesses. Stage only owned
  files. No push, publication, deployment or remote settings change.
- [ ] Update the acceptance receipt with observed local and hosted evidence
  separately. Stop after the agreed separation scope is verified; do not expand
  into deferred specialist work.
