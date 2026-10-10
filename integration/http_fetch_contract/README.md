# HTTP Fetch public contract revalidation

## Published 0.19.0

The root lock selects the seven published Fetch/Core/Runtime/WebSocket/QUIC/TLS
packages at 0.19.0, release commit `09b1686fb2ce529a17287d97801107c53b1ac57c`.
Fetch/Core/Runtime/WebSocket library files match that archive. #27–#30, #38,
#45 and #60 are closed.

From the worktree root:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix test --warnings-as-errors \
  apps/gaoxy_proxy/test/http_fetch_contract_test.exs \
  apps/gaoxy_proxy/test/http_fetch_completion_test.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/method_body_probe.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/websocket_close_probe.exs
```

Thirteen tests pass, covering original raw bytes/trailers/early-response/WS
contracts plus buffered/PID GET/DELETE entities, valid WebSocket close codes and
small fixed-length streaming before body EOF. Both probes now exit **0**: six
POST/GET/DELETE body cases and four exact close-code cases. The fixes require
`request_mode: :proxy` and WebSocket `mode: :proxy`; browser defaults intentionally
retain their browser restrictions. `stream_response: true` is per request and
replaces the earlier proposed global threshold constraint.

The [current audit](../../docs/m2-dependency-audit.md) and
[0.19.0 evidence](../../docs/acceptance/evidence/m2/http-fetch-0.19.0/)
record these dependency gates separately from the historical 0.17.2 failures.
Five additional completion tests pass with the public RequestCompletion handle,
including cancellation before establishment, upload and outstanding response ACK,
plus confirmed completed-request cleanup. The WebSocket proxy has its own
wire/TLS/lifecycle acceptance tests.

Raw-target acceptance remains blocked by
[#64](https://github.com/gsmlg-dev/http_fetch/issues/64): both string and URI
Fetch inputs remove a present empty query. This probe intentionally exits **1**
on 0.19.0, separately from the passing body/close/completion contracts:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/empty_query_probe.exs
```

The equivalent end-to-end regression remains enabled in `http_proxy_wire_test.exs`.
No dependency patch, private target API or URI rewrite workaround is used.

## Historical 0.17.1 reproduction

The original `probe.exs` and `observed.log` preserve the 2026-10-09 blockers
against HTTP Fetch 0.17.1 at `a78c0a35d84921678de40e8623eeeae71389c4ce`.
The probe runs actual `HTTP.fetch/2` against a loopback TCP peer, without
modifying upstream modules or installing the optional H2/H3/QUIC stack.
It is not a replacement package acceptance suite.

From the Gaoxy root, supply an untouched checkout of that revision:

```sh
git clone https://github.com/gsmlg-dev/http_fetch.git .audit/http-fetch-contract
git -C .audit/http-fetch-contract checkout --detach a78c0a35d84921678de40e8623eeeae71389c4ce
HTTP_FETCH_AUDIT_DIR="$PWD/.audit/http-fetch-contract" ELIXIR_ERL_OPTIONS='+S 2:2' \
  elixir -pa _build/test/lib/telemetry/ebin integration/http_fetch_contract/probe.exs
```

Expected observations at that historical revision are incorrect decoded gzip
bytes with unchanged headers, missing trailer metadata, and timeout instead of
early 413. Undefined H2/H3 module warnings are expected because only H1 modules
are compiled in memory. The recorded log used the same source files from the
audit snapshot. The separately source-audited 101 upgrade ownership gap was #30.
Do not count historical defect output as a passing proxy gate or as current
0.19.0 behavior.
