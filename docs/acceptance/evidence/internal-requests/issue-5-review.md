# Independent specification and code review: issue #5

Reviewer: `websocket_limits` Sol worker, independent of the TLS implementer.
Base: `32933790457bcfa3533e40dc2ae4d51ad91aa86d` on local `main`, with the
uncommitted issue #5 source recorded in
`.audit/internal-requests/5/source-sha256.txt`.

Verdict: **PASS**, no actionable findings.

Reviewed the complete issue contract, design, plan, public certificate guide,
core TLS validation, service-to-Hell forwarding, Phoenix option validation,
ListenerSet/HTTP-provider materialization, and conditional `:mtls` capability
requests. Peer verification requires an explicit nonempty CA path. Invalid modes,
nonboolean presence policies, and CA/presence options without peer verification
fail rather than silently disabling verification. Existing server-only TLS
configuration remains accepted. `:mtls` can only be requested on a peer-verifying
TLS service.

Traced certificate provenance through Hell's public OTP TLS options and
`peercert` API to HTTP exchange peer data. The certificate path does not read
HTTP identity headers. The existing H2 socket-certificate transfer remains
intact; this review's executed network coverage is H1 and Phoenix WebSocket.

Independently reran focused verification on Elixir 1.18.5 / OTP 28, Linux, using
`ELIXIR_ERL_OPTIONS='+S 2:2'`:

- Root: `python3 scripts/check-tests.py apps/gaoxy/test/client_certificate_config_test.exs apps/gaoxy_http/test/phoenix_client_certificate_config_test.exs`
  — exit **0**, core **4 tests**, HTTP **2 tests**, **0 failures**.
- `examples/phoenix_native`: `python3 ../../scripts/check-tests.py test/client_certificate_test.exs`
  — exit **0**, **4 tests**, **0 failures**. Both TLS 1.2 and TLS 1.3 prove trusted
  DER certificate propagation on HTTP and real Phoenix WebSocket upgrades,
  anonymous `nil` peer certificates despite forged headers, untrusted-certificate
  rejection on optional-presence listeners, and anonymous rejection on
  mandatory-presence listeners.
- Task-owned source whitespace: `git diff --check` — exit **0**.

Fresh reviewer output is retained in
`.audit/internal-requests/5/independent-config-review.log` and
`.audit/internal-requests/5/independent-network-review.log`. All reviewer commands
have finished. No production source was changed by this review. Publication and
downstream runtime acceptance remain separate parent-owned steps.
