# Independent review: supervised HTTP shutdown budget

Reviewer: Sol (`websocket_limits`), independent of the #10 implementer.
Checkout: `main`, baseline `32933790457bcfa3533e40dc2ae4d51ad91aa86d`.
Scope: #10 design/plan, HTTP and HTTP/3 child-spec changes, deterministic budget
contracts and actual supervised idle/active-upload termination tests.

Final verdict: **PASS — initialization-side-effect finding resolved**.
The initial failure below remains preserved. The reviewer inspected repair 1
and independently reran its complete seven-test HTTP/HTTP3 issue suite.

The initial change correctly exposes the instance's drain plus cleanup allowance
and retains wrapper identity/start tuple/restart policy. Its new `child_spec/1`
calls the full `service_spec/1`, however, which initializes user endpoints/Plugs.
The original start tuple then calls `start_link/1` with the original options and
initializes them again. This adds user code execution and possible side effects
while constructing a child spec, and endpoint-init exceptions escape before
startup. The design explicitly required deferred startup behavior to remain.
Stateless `init/1` fixtures in the initial tests did not detect the regression.

Minimal read-only probes against current compiled test modules confirmed:

```text
init_calls_during_child_spec: 1
shutdown: 7000
raising_init: {:raised_during_child_spec, "endpoint init reached during child_spec"}
```

Logs: `.audit/internal-requests/10/independent-init-probe.log` (`MIX_ENV=test
mix run --no-compile --no-start`) and `independent-init-probe-direct.log`
(`elixir -pa '_build/test/lib/*/ebin'`, no Mix compilation or app startup).
Both public-API probes completed with exit 0; their output establishes the
unexpected behavior, not a passing regression check.

Required repair: derive the wrapper shutdown allowance from validated raw core
limits without endpoint initialization; preserve the core's single budget
calculation, finite invalid-input fallback and original wrapper startup path.
Add regressions for no init during child-spec construction, exactly one init
on actual startup, and deferred raising init. Preserve initial evidence and
rerun the scoped real shutdown tests before a final verdict.

## Repair 1 resolution and independent verification

Both wrapper child specs retain their original identity/start/restart maps and
obtain `shutdown` from a pure `Gaoxy.Config.shutdown_timeout/1` helper over raw
service limits. The helper reuses Config's existing defaults/limit validation
and runtime cleanup headroom; invalid limits retain a finite default. The core
child spec retains full service validation, selects its maximum drain and reuses
the same helper. No user endpoint initialization, synthetic service or skip-init
mode is introduced during wrapper child-spec construction.

New counting/raising-init regressions prove no initialization during HTTP/H3
child-spec construction, one initialization at actual supervised HTTP startup,
and deferred startup exceptions. Existing default/non-default drain, normal
termination acknowledgements, active progressing body, owned-process/socket
cleanup and port-rebind assertions remain intact. H3 remains a child-spec
contract check, not a new QUIC network-drain claim.

Fresh independent command with `ELIXIR_ERL_OPTIONS='+S 2:2'` under the shared
root Mix lock:

```text
python3 scripts/check-tests.py apps/gaoxy_http/test/supervised_shutdown_budget_test.exs apps/gaoxy_http3/test/supervised_shutdown_budget_test.exs
```

Actual result: HTTP 5 tests and HTTP3 2 tests, 0 failures, exit 0. Evidence:
`.audit/internal-requests/10/independent-repair-1-review.log`. The author also
reran existing core shutdown and HTTP lifecycle compatibility: 18 total tests,
0 failures (`repair-1-green.log`). Initial behavior and initialization red logs
retain their actual failures. No actionable findings remain in the repaired
scope. Author cumulative Sol repair rounds: 1 successful; Astra: 0.

No production or test files changed by this reviewer. All reviewer commands
finished. Publication and consumer application acceptance remain separate gates.
