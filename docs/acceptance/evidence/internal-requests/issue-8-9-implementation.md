# Phoenix WebSocket options and LiveView composer implementation evidence

Issues: gsmlg-dev/gaoxy#8 and #9. Implementer: Sol (`websocket_limits`).
Checkout: `/home/gao/Workspace/gsmlg-opt/gaoxy`, `main`; baseline
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`. Other workers' changes preserved.

Implementation verification: **PASS**. Independent review and publication are
separate release-owner gates.

Issue #8's Phoenix-owned `log` and `code_reloader` options were missing from the
existing application policy allowlist. Added those two keys only; wire limits
remain separately validated. Issue #9 shares #6's repaired independent message
default; no additional production feature or persistence code was introduced.

Commands, run with `ELIXIR_ERL_OPTIONS='+S 2:2'` and the shared per-project Mix
locks:

| Scope | Command | Actual result |
|---|---|---|
| Root, red | `python3 scripts/check-tests.py apps/gaoxy_http/test/websocket_application_options_test.exs` | 2 tests, 1 failure, exit 2: valid Phoenix policies rejected |
| Phoenix example, red | `python3 ../../scripts/check-tests.py test/websocket_phoenix_compatibility_test.exs` | 5 tests, 1 failure, exit 2: actual application socket returned HTTP 500; four LiveView capacity cases already passed using #6's repair |
| Root, green | `python3 scripts/check-tests.py apps/gaoxy_http/test/websocket_application_options_test.exs apps/gaoxy_http/test/websocket_configured_limits_test.exs apps/gaoxy_http/test/websocket_network_test.exs apps/gaoxy_http/test/websocket_frame_test.exs` | 25 tests, 0 failures, exit 0 |
| Phoenix example, green | `python3 ../../scripts/check-tests.py test/websocket_phoenix_compatibility_test.exs test/websocket_configured_limits_test.exs` | 11 tests, 0 failures, exit 0 |

The new real Phoenix acceptance covers successful HTTP/1 upgrade, channel join
and echo with `log: false` / `code_reloader: false`; actual LiveView sessions
with retained cookies and CSRF/session/static tokens; normal form events carrying
exactly 300KiB of double quotes; full escaped outbound rendered content; exact
test-store persistence; actual HTTP reload and LiveView rejoin; fragmented input
with interleaved ping; and close 1009 for both frame and aggregate oversize input.
The composer uses a 16MiB service budget and supported 2MiB frame limit.

Logs: `.audit/internal-requests/8/{options-red,phoenix-red,options-green}.log`
and `.audit/internal-requests/9/phoenix-green.log`. Source hashes and counts:
`.audit/internal-requests/9/report.json`. Formatting ran on the changed Elixir
files; `git diff --check` passed.

Sol repair rounds for #8/#9: 0; Astra rounds: 0. #6 retains its separately
recorded one test-premise repair. All own commands finished; no commit, push,
tag, GitHub mutation, publication or deployment was performed. Consumer database
and application acceptance remains with the requesting repository.
