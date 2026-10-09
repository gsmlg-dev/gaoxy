# HTTP Fetch public contract revalidation

## Published 0.17.2

The Gaoxy root lock selects published Fetch/Core/Runtime/WebSocket and their
QUIC/TLS-engine dependencies at 0.17.2. The upstream release tag points to
`500fbb90ce4eeddbba16b9bb5da91f70f0764995`; published Fetch/Core/Runtime/WebSocket
library files match that archive. The original #27–#30 issues are closed.

From the Gaoxy worktree root, run the public-API contract tests:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix test --warnings-as-errors \
  apps/gaoxy_proxy/test/http_fetch_contract_test.exs
```

Five tests passed on 2026-10-10: buffered/ACK-streamed raw gzip and duplicate
headers, trailers before stream end, early 413 with upload stop, declared upload
trailers, and WebSocket upgrade/initial bytes/subprotocol/ACK writes/normal
cleanup. These are dependency contract checks, not full proxy acceptance.

Two required contracts remain blocked. Reproduce them with the same published
packages, without modifying dependencies:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/method_body_probe.exs
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix run \
  integration/http_fetch_contract/websocket_close_probe.exs
```

Each probe currently exits **1**, preserving actual failed gates:

- [#45](https://github.com/gsmlg-dev/http_fetch/issues/45): POST sends `abc` and
  Content-Length 3; GET/DELETE discard the same body and Content-Length.
- The valid-close-code subset of
  [#38](https://github.com/gsmlg-dev/http_fetch/issues/38): WebSocket close 1000
  succeeds; 1001/1008/1011 return `{:error, :invalid_close_code}`. Each code uses
  a fresh native WebSock connection and confirms cleanup. Closing with 1000 after
  a rejection is probe cleanup, not proxy close-code preservation.

The [current audit](../../docs/m2-dependency-audit.md) explains the scope and
static startup `streaming_threshold: 0` constraint for future proxy work.
[New evidence](../../docs/acceptance/evidence/m2/http-fetch-0.17.2/) is separate
from the historical native acceptance bundle. Full M2 remains incomplete;
no proxy endpoint or dependency workaround is implemented.

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
0.17.2 behavior.
