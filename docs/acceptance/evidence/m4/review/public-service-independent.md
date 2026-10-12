# Independent public service and H3 upgrade review

Reviewer `/root/m4_spec_review`, independent of root author, 2026-10-12.
Review is read-only for root-owned code. Worktree `.trees/m4-http3`, branch
`codex/m4-http3`, reviewed HEAD `2b4a5e58bf3044baf289c266b96ee9a979f61309`.

## Specification compliance: PASS

Reviewed `apps/gaoxy_http3/lib/gaoxy/http/http3.ex` and `test/service_test.exs`,
plus `apps/gaoxy_http/lib/gaoxy/plug_adapter.ex` and `test/http3_upgrade_test.exs`.
Public H3 selection uses the strict Options path and Gaoxy's native QUIC owner;
the endpoint initializes once. Invalid credentials fail before socket activation.
Service/child identity is preserved and re-validation does not reinitialize.
H3 WebSocket upgrade returns exact `{:error, :not_supported}` before interpreting
H1 handshake arguments. H1 malformed-handshake validation and H2 refusal retain
their existing contracts. Meaningful fail-first service/upgrade logs are retained.

`upgrade/green.json` records fresh exact-file format check, warnings-as-errors
compilation and **5 tests, 0 failures** (2 upgrade + 3 service). This reviewer
verified every input and raw-log hash against that execution receipt. No unresolved
specification findings remain for these four files.

## Code quality: PASS

The public facade is a thin explicit opt-in path, introduces no dependency or
runtime process outside the designed host, and delegates lifecycle to Gaoxy.
The one guard change matches existing return conventions and preserves ordinary
H1 dispatch. No adjacent cleanup or unsupported upgrade path was introduced.
No unresolved code-quality findings remain for these four files.

This receipt does not qualify Task2 wire behavior, arbitrary shared endpoints,
Plug execution, browser/upstream matrix, standalone, publication or deployment.
Root owns final fresh verification and commits. Reviewer commands finished.

## Clean H1/H2 consumer review

Source review of `scripts/http-consumer.sh`, `integration/http_consumer/mix.exs`,
`test/test_helper.exs` and `test/consumer_test.exs` found the intended fresh temporary
project and public H1/H2 exchange plus explicit optional-app exclusion assertions.
However the recorded `isolation-early/http.json` result is **FAIL: 2 tests,
2 failures**. Acceptance and code-review disposition for that consumer remain
pending root's diagnosis and fresh verification. No PASS is inferred from source.
