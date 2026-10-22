# Test workflow separation

**Date:** 2026-10-22, Asia/Shanghai
**Source baseline:** main at 09715de3f165db134e287e1ea5fd4e93b1325905, version 0.11.1
**Status:** Independently reviewed design; executable implementation has not started.

## 1. Required boundaries

1. test.yml has exactly one unit job on ubuntu-latest. It has no operating-system
   or BEAM matrix and no macOS runner. Keep Elixir 1.18.5 / OTP 28.5 initially.
2. Unit tests make no real service requests. HTTP, TCP, TLS, UDP, QUIC and
   WebSocket interactions, including localhost and port-zero fixtures, use mocks
   or controlled test doubles. They do not start a real server or protocol peer.
3. A unit may own an isolated process or temporary input file. A complete
   multi-component runtime, listener lifecycle or independently launched BEAM
   belongs to integration, even when it makes no network request.
4. All cross-platform execution belongs to portable.yml. Its purpose is a small
   can-run smoke on the already established Linux and macOS targets.
5. e2e.yml owns integration and end-to-end testing on Linux: component
   collaboration, real network/protocol tests and different HTTP clients.
   Use separate jobs within this workflow, without another integration workflow
   or a cross-platform matrix.
6. Remove browser tests, Playwright, Chromium setup and browser-only acceptance.
   Use HTTP clients and protocol peers for server behavior.
7. CI, E2E, package and release jobs use Linux. Existing macOS build and
   non-unit matrices move out of their former owners; portable is the only
   workflow allowed to select macOS.
8. Preserve ordinary assertions and nonempty/exact-count guards. Keep specialist
   pressure, sustained-load, slow-peer and deferred disconnect work deferred.
   Historical evidence retains its original results.

The scope is test organization and client-based verification. It grants no
publication, deployment, production-data, operational-certificate, Vault or
public-management changes. Planning does not enable the existing E2E placeholder.

## 2. Current source facts

The existing test.yml selects files explicitly; it does not run a default
umbrella-wide test command. Its four entries are the unit manifest, eleven
inline regression files, the test_helpers manifest and built-package consumers.

| Existing selection | Files | Declared/static cases |
| --- | ---: | ---: |
| check-repairs.py unit | 17 | 182 |
| Eleven inline regressions | 11 | 46 |
| check-repairs.py test_helpers | 7 | 69 |
| check-repairs.py protocol | 13 | 33 |
| check-repairs.py composition | 11 | 77 |
| Unique union of these selections | 59 | 407 |

These are planning counts, not new execution results. They exclude Python tests,
consumer projects and the additional portable/network gates. The apps directory
contains 214 test files; many are outside the current ordinary selection.

Four files in the existing unit manifest use real TCP or HTTP/TLS fixtures.
Other files mix configuration assertions with real network cases. The helper
suite includes real servers, H2/H3 peers and subprocesses. The current
portable.native_http job repeats the inline files, the complete repair manifest
and the package consumers.

The six app test helpers only call ExUnit.start(). There is no complete layer
classification. Existing loopback tags cover only part of the network tests;
adding an exclude flag cannot establish unit isolation.

## 3. Selected organization

| Workflow | Runner | Responsibility |
| --- | --- | --- |
| ci.yml | ubuntu-latest | Formatting, static inventory validation and strict compilation |
| test.yml | One ubuntu-latest job | Mocked/isolated unit tests and Python script unit regressions |
| e2e.yml | Linux jobs | Source integration, real network/protocol tests, isolated Linux networking and client-based published-server checks |
| package.yml | Linux jobs | Hex staging, clean source/built-package consumers, dependency isolation and source-built release smoke |
| portable.yml | Linux/macOS matrix | One minimal HTTP startup/request/stop smoke per platform |
| release.yml | Linux | Independent qualification of the exact publication source, then the existing manual publication flow |

CI stays on all pushes/PRs; unit tests stay on main pushes and PRs targeting
main. E2E, package and portable inherit all push/PR/manual triggers from the old
portable workflow. E2E's manual version input becomes optional, defaulting to
an empty string. Source integration jobs run on every event; release-clients
runs only for a manual event with a nonempty version, once its actual suite is
qualified. Ordinary pushes/PRs do not require an already published candidate.
Do not introduce schedules, path filters or cross-workflow dependencies.

Ordinary workflows use contents: read, separate concurrency groups and redundant
run cancellation. Release retains contents: write, its manual inputs and
cancel-in-progress: false. Record required-check name changes before rollout;
do not change repository protection settings as part of this work.
Python unit regressions moved out of ci adopt test.yml's existing main-targeted
trigger boundary. Add these current boundaries to AGENTS.md so later work does
not restore historical browser or mixed-test requirements.

### 3.1 Unit selection and mocks

Keep scripts/check-repairs.py as the authoritative executable manifest and its
existing counting runner. Its ordinary suites become unit, component and
protocol. The all selector is their deduplicated union for exact-source release
qualification. Workflows must not maintain additional inline app-file lists.
During migration, legacy CLI selectors may reference canonical entries as
compatibility aliases. They are not additional manifest owners and are not
included again by all. Remove them only after their workflow callers migrate.

Split mixed test files so a file has one layer. Pure configuration, parser,
header, renderer and single-owner state-machine cases stay unit. A fake
transport, fake owner or injected callback supplies controlled success, failure,
timeout and response data. Preserve the current ScriptedTransport-style
approach; do not add a mocking dependency merely to label existing doubles.

Calling an in-process fake is allowed. Starting Gaoxy.HTTP or a complete Gateway,
opening a real listener/socket, issuing an HTTP request, starting an independent
peer or testing whole-runtime cleanup is not allowed in unit. Do not replace
useful real-network regressions with mocks: move those regressions to integration
and add a focused mocked unit only where a local contract needs one.

The nine stream_lifetime_generation cases exercise multi-component collaboration
and therefore move to component, despite having no real listener.

Keep the three Python unit regression scripts now in ci.format under test.yml.
Their mocked socket functions, fake Mix executable and temporary inputs remain
isolated. The actual Hex staging/build regression belongs to package.yml.

### 3.2 Coverage inventory

Add scripts/test-inventory.json for app test files outside the executable
manifest. Each retained path has an explicit reason and existing disposition;
specialist_deferred and existing_not_scheduled remain distinct. No directory
wildcard may silently retain a newly added test.

The manifest remains the sole source for active ownership and counts. The
inventory checker derives active paths from it and requires:

- discovered app test files = active paths + explicitly retained paths;
- active and retained are disjoint;
- each active path belongs to exactly one ordinary suite;
- every path exists and every expected count is positive.

New files must be classified. New cases in an active file require an explicit
expected-count update. Add a unit module declaration and check that it agrees
with the manifest, but do not use tags as a second execution selector. File
inventory and declarations cannot prove mock isolation; source review must
check changed unit dependencies. Static call-site hints are advisory.

Runtime-owned Python entrypoints and independent consumer projects stay named
commands with one ordinary workflow owner. They are not executed by app-file
discovery. Preserve existing entrypoints that are not currently scheduled
without turning them into new automatic gates.

### 3.3 E2E integration jobs and package ownership

Within e2e.yml, source integration jobs are component, protocol and
isolated-network. They run independently on Linux without depending on
release-clients. Each job installs only the peers/tools it uses. Keep OpenSSL
and pinned H2/aioquic dependencies with the real network suites. The privileged
job retains Linux namespaces, IPv4/IPv6/backend variants, finite deadlines and
owned-resource cleanup.

Package jobs own staging/build regressions, built/extracted six-package
consumers, the three currently scheduled source consumers (external-consumer.sh,
gateway-consumer.sh and h3-gateway-consumer.sh), optional QUIC consumer and
production dependency/release isolation. Keep http-consumer.sh and
h3-consumer.sh release-only; this migration does not add new ordinary triggers
for them. Move source-built standalone release smoke here. These jobs never
publish. Preserve locks, temporary-project isolation, optional dependency checks
and nonempty execution.

Keep h2_rfc/run.py and reverse_proxy/run.py under e2e.yml's Linux protocol job.
The browser-free Phoenix gate.py/unified.py also belong to source protocol
integration, with the example project's own Mix tests under component
integration. Keep source-fixture identity and published-server identity distinct
within the same workflow; they use different jobs and commands.

Do not repeat unit or package-consumer suites in e2e.yml. Repeating required
checks on the exact publication source in release.yml remains intentional.

## 4. HTTP clients instead of browsers

Use clients according to their actual protocol capabilities; do not construct a
client-by-protocol Cartesian product.

| Client | Focus |
| --- | --- |
| curl | Basic H1 requests, status, headers and body; TLS with the fixture CA |
| Python httpx | Independent H1 and negotiated H2 requests, uploads and streaming |
| HTTPFetch | Public Elixir-client compatibility against the running server |
| Python h2 / aioquic | Explicit H2/H3 negotiation and protocol-specific ordinary exchanges |
| Python websockets / existing frame peers | WebSocket handshake, message and ordinary close behavior |

Keep at least two independent clients for the basic HTTP request/response
contract. Check actual negotiated versions before crediting H2 or H3. A browser
page loaded over H2 does not prove that its WebSocket used H2.

Remove UI-only checks: DOM rendering, clicks, browser uploads, JS execution,
page-console errors and screenshots. Server response bytes, TLS verification,
SSE framing, WebSocket frames, endpoint ownership, reload/source restoration and
shutdown assertions use existing client/peer fixtures. Do not recreate a
LiveView UI test framework.

Browser removal covers:

- integration/phoenix_native run.py, gate.py and unified.py browser blocks,
  requirements and current README commands;
- integration/websocket_multiplexed/browser.py and browser-only fixture,
  Playwright requirement and run.py dependency-version lookup;
- integration/http3/browser.py and its matrix.py launch/prerequisite branch;
- integration/upstream_transport/browser.py and browser.mjs browser entrypoints;
- workflow browser installation, browser environment variables and screenshot
  upload paths, including the release workflow.

Remove browser-only entrypoints after checking references. Retain independent
peer code. Historical acceptance logs, immutable reports and their old browser
claims remain unchanged; record UI-only removals as an explicit scope change,
not as passing replacement tests. Do not execute old specialist matrices while
retiring their browser entrypoints.

## 5. Small cross-platform smoke in portable.yml

Use the existing Linux and macOS targets, one established BEAM pair per target,
with fail-fast: false. The shared scenario is deliberately small:

1. Compile/install the candidate through its public package/API boundary.
2. Start one native HTTP service on loopback and port 0.
3. Make one real GET /health using OTP's HTTP client.
4. Require status 200 and a fixed body.
5. Stop the service and exit successfully within finite deadlines.

For push/PR validation use the candidate checkout through an isolated consumer;
record mode=candidate-source-boot. This proves that candidate can run on the
platform, not that a standalone archive was downloaded or published.

No full unit suite, protocol matrix, H3/WS/SSE suite, reload, pressure test,
privileged networking or browser runs here. Platform-specific compilation tools
remain only where the candidate's dependencies require them. A missing
dependency/platform capability produces a truthful failure or environment block,
not a skipped case reported as a successful smoke.

## 6. One Linux workflow for integration and E2E

e2e.yml owns all source integration described in section 3.3. Its component,
protocol and isolated-network jobs validate the candidate checkout on pushes,
PRs and manual runs. Existing ordinary real-client checks stay in these jobs.
The component and protocol manifests retain their distinct classifications and
exact-count guards; grouping them in one workflow does not merge their suites.

The additional release-clients job uses the optional manual version input and
the matching published Linux runtime. Download the archive and SHA256SUMS,
verify them, and run from a fresh temporary directory. Test fixtures/clients
may come from the matching release revision; this job must not build or
substitute the server from the current checkout.

Start a local-only server fixture, drive it with the clients above, and verify
ordinary request/response, headers/body, upload/streaming, TLS, supported H2/H3
and WebSocket behavior. Reuse ordinary peer cases; do not import specialist
load/disconnect qualification or add a large new conformance programme.

Use finite request/start/stop deadlines. Record version, server artifact, client
and actual protocol, individual results and process exit. Keep peer/server logs
and results; no browser or screenshot artifacts.

The existing release-artifact placeholder remains disabled during this planning
change. At implementation, that disabled state applies only to release-clients
until its actual suite is reviewed and qualified. It must not disable the
migrated source integration jobs or make them depend on a published version.
After qualification the release-clients condition is manual event AND nonempty
version. A manual run without version still runs source integration; a version
adds the released-server job. Keep these jobs independent.

Existing Linux artifacts suffice for the released-server checks; no macOS
artifact publication or two-mode server runner is needed.

## 7. Verification and migration acceptance

- test.yml has one literal ubuntu-latest runner, no matrix and no non-unit entry.
- All unit service boundaries use mocks/doubles; no real request/listener/peer.
- Only portable.yml contains cross-platform runners; its runtime scenario is one
  startup, GET and stop.
- E2E contains the Linux component, protocol and isolated-network jobs. They run
  on pushes/PRs and manual events without a release version; release-clients has
  its separate manual/version gate.
- No executable test entrypoint or dependency installation requires a browser.
- Every currently selected non-UI ordinary case has a new owner. For the 407
  app cases above, the provisional split is 184 unit and 223 component/protocol;
  actual ExUnit discovery and execution must confirm the final counts.
- Removed browser UI checks are listed separately. Never subtract them from app
  case accounting or rename their historical result.
- Each moved gate executes nonzero cases, with unchanged assertions and finite
  deadlines. Required cases cannot be skipped or excluded.
- Preserve current release source identity and publication guards. Publication
  and E2E dispatch are not part of implementing this local separation.

See ../plans/test-workflow-separation.md for files, task order and commands.
