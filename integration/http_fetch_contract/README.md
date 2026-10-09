# HTTP Fetch public contract reproduction

This probe preserves the M2 upstream blockers against HTTP Fetch 0.17.1 at
`a78c0a35d84921678de40e8623eeeae71389c4ce`. It runs actual `HTTP.fetch/2`
against a loopback TCP peer, without modifying upstream modules or installing
the optional H2/H3/QUIC stack. It is not a replacement package acceptance suite.

From the Gaoxy root, supply an untouched checkout of that revision:

```sh
git clone https://github.com/gsmlg-dev/http_fetch.git .audit/http-fetch-contract
git -C .audit/http-fetch-contract checkout --detach a78c0a35d84921678de40e8623eeeae71389c4ce
HTTP_FETCH_AUDIT_DIR="$PWD/.audit/http-fetch-contract" ELIXIR_ERL_OPTIONS='+S 2:2' \
  elixir -pa _build/test/lib/telemetry/ebin integration/http_fetch_contract/probe.exs
```

Expected observations at that revision are incorrect decoded gzip bytes with
unchanged headers, missing trailer metadata, and timeout instead of early 413.
Undefined H2/H3 module warnings are expected because only H1 modules are compiled
in memory. The recorded log used the same source files from the audit snapshot.

Track raw-byte mode in upstream #27, early H1 response in #28, trailers in #29,
and the separately source-audited upgrade ownership gap in #30. Do not count
the expected defect output as a passing proxy acceptance gate.
