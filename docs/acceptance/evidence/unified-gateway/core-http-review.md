# Final HTTP/core composition and workflow review

Task: unified-listeners-embedded-gateway / http_composition
Assignment: direct Sol implementation followup and read-only cross-review.
Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway
Branch: codex/unified-gateway
Baseline: 656dbf5bb84564adc6a4d68247c0ad2fe52c2625 (uncommitted shared task changes).

## Independent core review: PASS, no actionable findings

Reviewed current Gaoxy.activate/3 and activation_status/2 API; Config activation validation; Instance deferred lifecycle/receipts/deadline/caller/worker/stop handling; Activation complete-set comparison/startup/rollback; all 12 staged activation test contracts. Reviewed the HTTP/H3 provider materialization and ListenerSet.Owner integration against the core handshake.

Core preserves complete planned service budgets before binding; validates every finalized spec and fixed binding/transport/handler fields before first startup; permits only decreasing resource ceilings; serializes activation identity and retains bounded receipts. Late startup ownership survives caller timeout/death and stop waits for the activation cleanup before draining dependent participants. Core adds no HTTP, Proxy or H3 dependency. ListenerSet uses one absolute startup deadline through preparation, activation and readiness inspection, and reports cleanup pending explicitly.

This is a source cross-review, not a duplicate execution of the parent's root exact gate. No root Mix commands were run during this followup. Prior independent review of the HTTP implementation remains separate; this report does not call the HTTP author's self-review independent.

## Consumer implementation verification: PASS

Added only integration/h3_gateway_consumer/** and scripts/h3-gateway-consumer.sh. The script copies Core, HTTP, Proxy and HTTP3 app sources, supported vendored WebSock adapter, pinned peer fixtures and certificates helper into a temporary external project. Server source is absent. Optional cached dependency copying dereferences the source deps symlink into a separate real directory.

Command: GAOXY_CONSUMER_DEPS="$PWD/deps" GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" ELIXIR_ERL_OPTIONS='+S 4:4' bash scripts/h3-gateway-consumer.sh
Evidence: .audit/h3-gateway-consumer.log
Actual: exit 0; compile --warnings-as-errors PASS; 1 test, 0 failures, 3.1 seconds. Real validating TLS H1/H2 and pinned independent aioquic H3 peers verify managed upstream content and Gateway-owned Alt-Svc, then the committed reloaded generation across all three versions. Ready revisions 1 and 2, stopped Gateway PID, refused TLS connection, released QUIC UDP port, and absent Server module/application are asserted.

## Workflow review and static verification: PASS

portable.yml native_http now runs Gateway without H3 and Gateway with H3 as isolated external consumers. It provisions optional example H3 dependencies and pinned aioquic before compiling a dev reload/H3 fixture and executing actual unified Phoenix browser acceptance. Deferred sustained-load step remains disabled.

release.yml now runs isolated Core, HTTP, optional H3, Gateway without H3 and Gateway with H3 consumers against the exact checked-out publication source. It prepares the example in MIX_ENV=dev with H3/reload before the --no-compile unified fixture; the fixture also explicitly launches in dev despite global release MIX_ENV=prod. Browser and aioquic dependencies remain pinned. Evidence artifacts preserve reports/log/screenshots. Existing exact SHA/version checks, package ordering and irreversible publication sequence remain intact. No deployment or disabled release-artifact E2E changes were made.

Actual static commands: both YAML files parsed using isolated PyYAML 6.0.3; all 35 portable and 20 release run blocks passed bash -n; new script bash -n PASS; scoped git diff --check PASS. Ordering assertion confirms new consumers and real browser acceptance precede Publish and verify Hex packages.

Hosted GitHub workflows were NOT RUN here. Earlier actual local unified Phoenix evidence remains .audit/unified-phoenix/report.json (8 checks PASS, process_exit 0, source_restored true). This followup did not rerun the already-passing browser gate or unrelated baseline tests.

## Status and counters

DONE for this owned consumer/workflow implementation and read-only review; parent integration/release remains independently coordinated. No commits or publication performed. All owned commands completed and temporary consumer processes cleaned by script. No repair rounds required for this followup (Sol increment 0); inherited cumulative parent counter is unchanged/parent-owned. No Astra gate invoked. No new decisions needed. Remaining limitation: configured hosted workflow execution has no fresh hosted result yet.

## Subsequent mixed-network contract update

Parent assigned the existing mixed_http_network_test.exs Phoenix test contract seam after its exact gate exposed that the logical ListenerSet owner PID was treated as a core instance. Changed only child PID naming and extracted %{instance: server} through public ListenerSet.info(owner); all seven tests and native independent-peer assertions/deadlines are preserved.

Command: flock .audit/mix.lock env MIX_ENV=test ELIXIR_ERL_OPTIONS='+S 4:4' mix test apps/gaoxy_http/test/mixed_http_network_test.exs --warnings-as-errors --seed 0 --max-cases 1
Actual: exit 0; 7 tests, 0 failures (8.5 seconds), .audit/unified-mixed-http-contract.log. One successful scoped contract repair/validation round.

New actionable lifecycle finding reported to parent: normal supervisor teardown leaves the ListenerSet Owner trapping and ignoring its parent's EXIT message; Owner only monitors parent DOWN, which cannot arrive while the supervisor is awaiting child shutdown. The focused test consequently consumes the child shutdown timeout and the core logs its Owner parent being :killed. ListenerSet.start_link uses GenServer.start then manual Process.link, and Owner.handle_info handles instance EXIT but currently ignores parent EXIT. Parent is coordinating this new targeted production repair. The prior PASS disposition above remains scoped to the independent core review and consumer/workflow work, not this newly found Owner teardown issue.

## Owner lifecycle repair and H05 completion: PASS

The subsequent Owner teardown finding is resolved. Owner retains its actual linked host PID in state and handles only that parent's EXIT by terminating with the original reason. Existing core-instance EXIT, parent monitor DOWN, and unrelated EXIT behavior remain intact.

RED: .audit/listener-owner-parent-red.log, exit 2, 9 tests / 1 failure. New supervised shutdown test failed because the core lifecycle participant never received drain. The separately added direct parent normal-exit/unrelated-EXIT contract already passed.

GREEN: flock .audit/mix.lock env MIX_ENV=test ELIXIR_ERL_OPTIONS='+S 4:4' mix test apps/gaoxy_http/test/listener_set_test.exs apps/gaoxy_http3/test/listener_set_network_test.exs apps/gaoxy_http/test/mixed_http_network_test.exs --warnings-as-errors --seed 0 --max-cases 1
Actual: exit 0, HTTP ListenerSet10 + mixed network7 = 17 tests / 0 failures in 1.5 seconds; optional H3 ListenerSet network8 tests / 0 failures in 5.7 seconds. Evidence .audit/listener-owner-parent-green.log. No forced-killed teardown output. Existing seven native peer test assertions are preserved.

The supervised shutdown regression registers a real core lifecycle participant, waits for drain while both Owner and core are alive, explicitly releases cleanup, and asserts exact DOWN reasons core :normal / Owner :shutdown under finite deadlines. A second regression proves direct parent normal exit and unrelated EXIT handling. H05 adds exact startup error and cleanup proofs for failed target initialization, invalid H3 certificate data, and unsupported H3 wildcard bind: named Owner/core are absent and explicitly chosen TCP/UDP ports are available afterward.

Manifest exact counts updated only for these suites: ListenerSet7 to10; H3 ListenerSet network6 to8. Composition now58, whole repair manifest265.

Independent cross-review by core_lifecycle: PASS, no actionable findings; reviewed current source, unchanged native assertions, actual RED and GREEN evidence. All commands finished and scoped diff checks pass. No further edits pending for this assignment. Successful targeted Owner repair/validation increment1; cumulative parent counters remain parent-owned and unchanged except this reported increment. No failed Sol repair rounds or Astra invocation in this followup. Parent coordinates fresh exact whole-manifest verification and final integration/publication.
