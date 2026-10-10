# HTTP Fetch public contract revalidation

## Published 0.19.1

The root lock selects the seven published Fetch/Core/Runtime/WebSocket/QUIC/TLS
packages at 0.19.1. The release tag identifies commit `c26a17712a02a03985a764b6b100ca840fcc4349`;
workflow main HEAD is not the release identity. #27–#30, #38, #45, #60 and #64
are closed. The [current audit](../../docs/m2-dependency-audit.md) and
[0.19.1 evidence](../../docs/acceptance/evidence/m2/http-fetch-0.19.1/) record
immutable Git tree/blob verification and dependency gates separately from
historical failures.

From the worktree root:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix test --warnings-as-errors \
  apps/gaoxy_proxy/test/http_fetch_contract_test.exs \
  apps/gaoxy_proxy/test/http_fetch_completion_test.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/method_body_probe.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/websocket_close_probe.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/empty_query_probe.exs
```

Thirteen streaming/WebSocket tests and five public RequestCompletion tests pass.
They cover raw bytes, trailers, early responses, GET/DELETE entities, exact valid
WebSocket close codes, incremental fixed-length responses and confirmed request
cleanup. `request_mode: :proxy` and WebSocket `mode: :proxy` preserve proxy
semantics; browser defaults retain their browser restrictions.
`stream_response: true` remains a per-request option.

Both string and URI Fetch inputs now preserve `/upload?` on the wire. The public
empty-query probe exits **0**, and both request cleanup receipts return `:ok`.
The equivalent end-to-end regression in `http_proxy_wire_test.exs` also passes.
The method-body and close-code probes pass all **6 and 4 cases**, exit 0.
No dependency patch, private target API or URI rewrite workaround is used.

## Historical 0.19.0 raw-target failure

HTTP Fetch 0.19.0 removed a present empty query from string and URI inputs:
`/upload?` reached the peer as `/upload`. The public probe exited **1** and the
proxy regression failed, even though request completion independently returned
`:ok`. Bug [#64](https://github.com/gsmlg-dev/http_fetch/issues/64) blocked that
raw-target gate until the published 0.19.1 fix. Original failed evidence remains
in [the earlier bundle](../../docs/acceptance/evidence/m2/http-fetch-0.19.0/).

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
0.19.1 behavior.
