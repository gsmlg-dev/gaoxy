# Final independent Gateway specification and code review

Task: unified-listeners-embedded-gateway / core_lifecycle final cross-review.
Assignment: direct, read-only production/source review; this audit file is the only review edit.
Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway
Branch: codex/unified-gateway
Baseline: 656dbf5bb84564adc6a4d68247c0ad2fe52c2625, with shared uncommitted task changes preserved.

## Verdict

PASS: no actionable findings in the reviewed Gateway declaration, upstream materialization, Coordinator, Generation authority, standalone migration, or minimal HTTP2 WorkerAccounting correction. This approves the reviewed implementation contracts; the parent still owns the complete acceptance gate, integration, documentation and publication verdict.

Reviewed against docs/designs/unified-listeners-embedded-gateway.md, especially representations, Gateway ownership/reload/recovery/shutdown and standalone compatibility. Reviewed current source and diffs for apps/gaoxy_http/lib/gaoxy/http/generation.ex; apps/gaoxy_proxy/lib/gaoxy/proxy/gateway/{declaration,coordinator,upstream}.ex; Gateway supervisor/runtime wiring; apps/gaoxy_server/lib/gaoxy/server.ex and server/{application,supervisor,route_resources,upstream_endpoint,upstream_supervisor}.ex; corresponding Generation, Gateway, lifecycle, standalone recovery/resource and shared-protocol regressions.

## Findings resolved and contract assessment

- Pure Gateway compilation normalizes owner-independent declarations without endpoint initialization, file reads, DNS or runtime resource creation. Upstream CA file references remain input data until bounded preparation. Managed semantic policy is shared by embedded and JSON adapters.
- Generation serializes admission, revision, epoch, router, immutable accepted declaration and terminal receipt. Commit pins the replacement baseline, rechecks the deadline, then changes accepted state and receipt in one store transition. Failed/stale/expired candidates preserve the prior router. A drain barrier rejects pending work and later epochs. Retention is bounded to the current pending operation and latest terminal receipt, with unknown status explicit after eviction.
- Runtime recovery retains stable stores outside the one-for-all runtime/owner subtree, resolves the latest accepted declaration in a new epoch and preserves logical revision. Accepted trust contains immutable DER data, so recovery does not reread a modified/deleted CA source. Two gateways have distinct registry namespaces and owners even with equal logical IDs.
- Coordinator preparation keeps upstream pins with the Coordinator; bounded helper processes contain file materialization/listener preparation and user endpoint initialization. Prior pins are retained across multi-set cleanup. Legacy activation now uses Generation.prepare rather than unbounded direct Router.compile. Owners register lifecycle participants before allocation. Startup/readiness calls carry the same finite absolute deadline and failed startup retains runtime drain ownership.
- Standalone remains a JSON/environment/readiness adapter over public Gateway APIs. Existing registry/runtime names and generation-valued reload result are preserved. The legacy recovery tests now wait for actual readiness after staged registration, and the preparation-timeout regression still requires old accepted state plus explicit pending-pin reconciliation.
- Shared-protocol tests use validating independent TLS H1/H2/aioquic H3 peers, verify a committed managed-upstream route across all three listeners, preserve an old held request snapshot and check accepted trust after owner recovery. Assertions were not weakened.
- The only WorkerAccounting change adds discovery: e(nil) to the complete Exchange ETF constructor. Exchange now has the discovery field default nil; the independent test instantiates the full struct and remains unchanged. The correction charges the real term instead of changing expected accounting or a budget constant.

The earlier independent HTTP/ListenerSet/Phoenix/discovery review remains separate; this review does not call my own Gateway lifecycle implementation independent. Parent performed that lifecycle cross-review.

## Evidence inspected

- .audit/gateway-reviewed-final.log: current Generation 3/0, Gateway 7/0 and standalone 20/0, all with seed 0/max_cases 1.
- .audit/gateway-lifecycle-final-reviewed.log: Gateway and lifecycle 20 tests, 0 failures.
- .audit/gateway-core-consumer-final.log and .audit/gateway-external-consumer-final.log: each external compile --warnings-as-errors and 1 test, 0 failures. Core optional-package isolation assertions remain intact; Gateway consumer has no Server/H3 dependency.
- .audit/unified-exact-final2.log: the unchanged independent WorkerAccounting suite now executes 7 tests, 0 failures. The same run subsequently ends at mixed_http_network_test.exs with 7 tests, 1 failure in the ListenerSet.Owner :services compatibility path. This failed historical run remains FAIL. The host test now obtains the core instance through ListenerSet.info(owner) before calling core APIs, preserving the mixed-protocol peer assertions. Its fresh passing evidence is recorded below. The full exact gate was not complete at review time.
- Scoped git diff --check over the reviewed Generation, accounting, Gateway and standalone source/tests: exit 0.

Only static reads/diff-check ran during this final cross-review. No root Mix commands competed with the parent gate; no production edits, commits, push, publication, deployment or permission changes were performed.

## Independent ListenerSet shutdown and H05 followup review

PASS, no actionable findings after the HTTP owner's repair and fresh verification.

ListenerSet starts its owner with GenServer.start and links it after readiness, so its manually managed actual host is not the OTP GenServer parent. When its host supervisor sent shutdown, the owner trapped and ignored that EXIT; the supervisor could not finish until its child deadline, and a parent DOWN could not resolve that wait. The fix retains the actual parent PID and handles only a matching parent EXIT by stopping with its reason, thereby entering terminate and draining the core. Existing core EXIT, matching parent-monitor DOWN and unrelated-message behavior remain intact.

The new deterministic regression registers a lifecycle participant, starts Supervisor.stop, requires the drain notification while both owner and core remain alive, then explicitly releases drain and requires exact core DOWN :normal and owner DOWN :shutdown. A separate test preserves direct-parent normal-exit cleanup and unrelated EXIT behavior. The compatibility-fixture adjustment and this actual host-shutdown product defect are distinct changes.

H05's direct-evidence gap is now resolved by three startup cases: target initialization refuses with its original structured reason; invalid H3 certificate returns a field-level credentials error alongside a valid HTTPS sibling; unsupported H3 wildcard binding is rejected. Each asserts named owner/core registrations are absent and its planned TCP/UDP ports are available afterward. Missing optional H3 remains covered by the isolated HTTP consumer. Source review confirms complete credential/target preparation precedes activation, so the socket availability assertions complement the no-early-bind control flow.

Evidence inspected: .audit/listener-owner-parent-red.log, 9 tests/1 failure requiring the previously absent :core_draining notification; .audit/listener-owner-parent-green.log, HTTP ListenerSet10 plus mixed network7 = 17 tests/0 failures, and H3 ListenerSet network8 tests/0 failures, exit 0 reported by the HTTP owner and all test output reviewed. Scoped diff-check on Owner/tests/manifest exits 0. Exact composition manifest counts change to ListenerSet10/H3network8 and retain all earlier required files. No assertions are weakened. No root Mix commands were run by this reviewer. The parent still owns the fresh complete exact-gate result and subsequent release qualification.

## Status and limits

DONE for this independent read-only review. All commands launched by this review finished. Sol repair increment 0 for this review; inherited whole-task counters remain parent-owned; no Astra gate/counter used here. Existing unrelated H2/h2c standalone runtime and http_contract timing baseline failures remain visible in their historical evidence. Specialist pressure/disconnect/slow-peer exclusions and http_fetch#97 scope dismissal remain intact. No new design decisions needed. Full fresh exact-gate success, final docs and publication evidence remain for the parent to establish.
