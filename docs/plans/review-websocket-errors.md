# WebSocket proxy error response repair

1. Add independent H2 wire and aioquic H3 rejection regressions, including sibling
   connection liveness and no upstream session/connection. Run before the repair
   and record the expected 500-versus-400 failures.
2. Select the protocol-neutral response API in `Gaoxy.Proxy.WebSocket`.
3. Run the new regressions and existing ordinary H1 WebSocket proxy/TLS tests.
   Format only owned files and request independent review through the parent.

No dependency edits, publication, deployment, pressure, slow-client or historical
blocked-upload qualification are included.

## Verification

Baseline: `c063607e65cb3486dc19c78827f1ea8c62dbc87a`, branch
`codex/review-defaults-standalone`, 2026-10-20. Run Mix commands from the worktree
root with `ELIXIR_ERL_OPTIONS='+S 2:2'`, the shared Mix flock, and `unbuffer`.
The H3 peer uses `GAOXY_QUIC_PYTHON` pointing at the restored M5 aioquic 1.2.0
environment; the default `.audit/m5/venv` is absent in this worktree.

- RED: `mix test apps/gaoxy_proxy/test/websocket_protocol_rejection_test.exs
  apps/gaoxy_http3/test/websocket_proxy_rejection_test.exs` executed two tests,
  both failed because the actual response was 500 instead of 400; exit 2.
- GREEN: the same two files plus `apps/gaoxy_proxy/test/websocket_proxy_test.exs`
  and `apps/gaoxy_proxy/test/websocket_tls_test.exs` executed 19 tests, zero
  failures; exit 0. This covers H2/H3 GET and CONNECT rejection, connection
  siblings, no upstream connection/session, existing H1 upgrade, H1 upstream
  errors and verified TLS behavior.
- `mix format` on the changed module and two new test files: exit 0.

Implementation repair rounds: 0. Independent review and final integration
verification are coordinated by the parent.
