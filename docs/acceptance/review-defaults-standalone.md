# Default concurrency, WebSocket errors and standalone configuration

Status: **PASS within ordinary verification scope**, 2026-10-20.
Implementation source: `27bffd83e42a5da053fdf3366e13702469a5b4cd`, based on
local main `c063607e65cb3486dc19c78827f1ea8c62dbc87a`.

## Result

- H2 keeps the default 256 MiB service budget and protocol limits. Initial
  connection reservation is 30,359,591 bytes instead of 173,039,655. Before
  HPAX decoding, the connection lease grows to cover the actual complete
  compressed block using the existing conservative expansion formula. Its
  high-water reservation remains until connection exit. Maximum-block startup
  budget validation and standalone snapshot capacity remain enforced.
- WebSocket proxy failures use `Gaoxy.HTTP.Response`. Ordinary H2/H3 requests
  and unsupported extended CONNECT requests return empty 400 responses, retain
  sibling connection liveness, and create no upstream connection/session.
- Standalone JSON exposes existing managed H1, TLS H2 and h2c upstreams,
  homogeneous inline groups and health probes, WebSocket routes, and fixed
  TCP/TLS/UDP relays. Pure strict decoding remains separate from instance-bound
  preparation. Reload acquires generation baselines before releasing preparation
  pins; failed releases remain owned and block another activation until retried.
- Startup preserves exact/prefix/host/method matching and configured immutable
  shutdown budgets. Direct supervisor shutdown and concurrent explicit stop
  retain upstream owners until the runtime drain finishes. Failed initialization
  uses the same cleanup ordering. Scope custodians are joined before ordinary
  successful shutdown returns.

The [standalone guide](../../apps/gaoxy_server/README.md) includes JSON examples,
explicit numeric dial addresses and CA trust for named managed HTTPS origins,
finite limits, and reload/restart boundaries. Managed groups currently use
H1/H2; the existing dedicated H3 configuration remains separate. The WebSocket
proxy continues to implement H1 upgrades; H2/H3 rejection adds no proxy support
for those protocols. Relays retain their fixed destinations and UDP policies.

## Verification

Environment: Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5,
`ELIXIR_ERL_OPTIONS='+S 2:2'`, serialized Mix commands using
`flock /tmp/gaoxy-review-defaults-standalone.mix.lock` and
`/nix/store/hypwn40g5g43jvfgx8hha9b130v8vigy-expect-5.45.4/bin/unbuffer`.
No dependency or lockfile changes were required. H3 uses the restored aioquic
1.2.0 Python path recorded in the [receipt](evidence/review-defaults-standalone/final-receipt.json).

All test commands below use `--seed 0` and exited 0. Total: **217 tests,
zero failures**; repeated development/red-green runs are excluded from that
total.

| Check | Executed | Result |
| --- | ---: | --- |
| H2 codec, capacity, default concurrency, protocol, integration, worker accounting/startup, stale start, pre-settings, facade and independent-review files | 72 | PASS |
| WebSocket proxy, TLS, H2 rejection and H3 rejection files | 19 | PASS |
| `mix test apps/gaoxy_server/test` | 92 | PASS |
| Core config, runtime, shutdown-hardening and lifecycle-fault files | 34 | PASS |
| `MIX_ENV=test mix compile --force --warnings-as-errors` | 0 tests | PASS |
| Scoped `mix format --check-formatted` on 26 changed Elixir files; `git diff --check` | 0 tests | PASS |

The H2 command selects `apps/gaoxy_http/test/http2_{codec,capacity,default_concurrency,protocol,integration,worker_accounting,worker_startup,stale_start,pre_settings,facade,independent_review}_test.exs`.
The WebSocket command selects `apps/gaoxy_proxy/test/websocket_{proxy,tls,protocol_rejection}_test.exs`
and `apps/gaoxy_http3/test/websocket_proxy_rejection_test.exs`.
The server/core command selects the entire server test directory plus
`apps/gaoxy/test/{config,runtime,shutdown_hardening,lifecycle_fault}_test.exs`.

Regressions reproduced the original second-H2 byte-limit rejection and H2/H3
500 responses before their respective repairs. Integration regressions also
reproduced release ownership loss, compiled exact-match rejection, custom drain
budget rejection, and early supervisor return with live custodians. Cleanup
tests use deterministic barriers on Gaoxy-owned processes and finite deadlines.
Assertions and historical tests were retained.

Independent Sol specification/code review found and resolved relay listener-mode
validation, unconfirmed preparation release, shutdown ordering and concurrent
explicit-stop issues. The final independent review reported no actionable
findings. The inherited Astra allowance remains exhausted; no Astra round was
added.

Chrome DevTools exercised JSON decoding through the standalone supervisor and
real native upstream: `/managed` returned `200 BROWSER_MANAGED_OK`, ordinary
`GET /ws` returned empty 400, and a browser WebSocket upgraded, echoed
`BROWSER_WEBSOCKET_OK`, then closed cleanly with code 1000. The fixture reported
`BROWSER_CLEANUP_OK`. Ten README JSON examples also parsed successfully.
Source and raw-log hashes, counts and browser output are recorded in the receipt;
raw logs remain in the isolated worktree's ignored `.audit/review-defaults-standalone`.

## Release and scope boundaries

The existing [v0.5.2 release](release-0.5.2.md) already completed hosted run
[`39404989025`](https://github.com/gsmlg-dev/gaoxy/actions/runs/39404989025) at
`d9fb3a5e`, including the standalone artifact and five Hex packages. That source
does not include these new fixes. This task adds no push, tag, publication or
deployment; new hosted CI and release-artifact E2E are **NOT RUN**.

Specialist pressure, slow-peer, sustained-load and sole-native-H1 blocked-upload
qualification are **NOT RUN by the accepted scope**. Historical results retain
their original status. Production data/certificates, Vault and public management
boundaries remain unchanged.
