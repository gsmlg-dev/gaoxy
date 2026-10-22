# Gaoxy 0.12.0 release acceptance

Date: 2026-10-22, Asia/Shanghai. The user requested internal-request fixes
directly on `main` and the next version release. The initially clean source was
`0b3f97fc08549649b4b367e3a85a8526e162f53f`. The local results below cover its
reviewed working-tree changes; logs that print `REPAIR_SOURCE` show that base
commit. Hosted and publication checks must additionally qualify the exact
committed source, recorded after publication.

## Accepted behavior

- #12: HEAD preserves validated declared representation Content-Length,
  suppresses the body, and retains existing status/framing validation.
  Independent H1/H2/H3 peers check 16 rows per protocol, 48 total.
- #13: ordinary native/Plug H1/H2 targets accept the explicit
  `http_limits: %{request_timeout: :infinity}` option. Finite defaults,
  header/read/write limits, startup admission, cancellation and shutdown
  remain bounded. File responses inherit the request lifetime. Direct or
  wrapped Generation, managed gateway and H3 targets explicitly reject the
  option before target initialization/preparation.
- #14: Phoenix's exact `{:shutdown, :disconnected}` WebSock result closes
  with 1000 and calls terminate with `:normal`. Restart/error/explicit-code
  behavior retains its established contract. A real Phoenix channel
  broadcast verifies wire closure and transport/channel cleanup.

All seven own application/root manifests advance to 0.12.0. The six Hex
distributions advance together. Dependency pins and vendor provenance are
unchanged. No deployment, production data, operational certificate, Vault,
public management or deferred specialist qualification is included.

## Fresh local verification

Environment: Linux NixOS; Elixir 1.18.5, OTP 28, Python 3.13.15. Mix commands
use `ELIXIR_ERL_OPTIONS='+S 2:2'`. The pinned independent peer environment
contains h2 4.3.0 and aioquic 1.2.0. All PASS entries exited 0.

| Check | Result |
| --- | --- |
| `python3 scripts/check-repairs.py all` | PASS: 452 executed; unit 193, component 137, protocol 122; 0 failures, exclusions or skips |
| Focused request-lifetime/configuration/accounting regressions | PASS: 26 tests, 0 failures |
| Full Phoenix fixture: `PHOENIX_NATIVE_H3=1 python3 ../../scripts/check-tests.py --seed 0 --max-cases 1` in `examples/phoenix_native` | PASS: 23 tests, 0 failures |
| `python3 scripts/test-stage-hex-packages.py` | PASS: 10 packaging regressions |
| `python3 scripts/test-check-repairs.py` | PASS: 9 tests |
| `python3 scripts/test-check-test-inventory.py` | PASS: 14 tests |
| `python3 scripts/test-check-tests.py` | PASS: 8 tests |
| `mix format --check-formatted` | PASS |
| `MIX_ENV=prod mix compile --warnings-as-errors` | PASS |
| `git diff --check` | PASS |

The canonical manifest classifies all new app test files and schedules the
14-test controlled WebSocket stream file as component coverage. Its retained
inventory entry is removed. Unit cases use controlled/pure contracts; real
listeners and independent peers run in the protocol or Phoenix fixture gates.

The focused request-lifetime run used
`python3 scripts/check-tests.py apps/gaoxy_http/test/stream_lifetime_config_test.exs apps/gaoxy_http/test/http2_worker_accounting_test.exs apps/gaoxy_http/test/request_lifetime_network_test.exs apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs apps/gaoxy_proxy/test/gateway_plan_test.exs --seed 0 --max-cases 1`.

## Review and preserved failures

[Independent review](evidence/internal-requests-0.12.0/review.md) passed after
the configuration-wrapper and finite `100 Continue` send-deadline repairs.
The #12 writer was reviewed by the #14 writer; the #12 writer independently
reviewed #13 and #14. Final fresh gates followed the resolved findings.

Raw parent logs are retained as deterministic gzip copies under
`evidence/internal-requests-0.12.0/`. This includes original #13 RED/review
failures and the first failed accounting/test-fixture attempt, the earlier
451-test PASS, and the final 452-test PASS. The original #14 green Phoenix
log is preserved too. #12 and #14 RED commands/counts were reported in worker
tool transcripts; their plans record those observations without inventing
raw log files. Historical failed runs are not relabeled by later passes.

**FAIL, separate unscheduled compatibility run:** the #12 worker executed
`http_network_test.exs` and `http2_integration_test.exs`: 37 tests, 1 failure
at `apps/gaoxy_http/test/http_network_test.exs:351`, “one large client write
streams through a smaller parser buffer”. The response was 500 instead of
the expected body `2000`. Baseline status was not established. Investigation
of that unrelated failure stopped; no assertion or production workaround
was changed. These files retain their existing unscheduled disposition.
The 452-test ordinary gate does not claim to cover that failure or the
deferred specialist suites.

## Publication status

NOT RUN at this local acceptance checkpoint: exact-source hosted workflows,
release qualification, GitHub/Hex publication and public-package issue
regressions. Follow the existing guarded `release.yml` with the full versioned
commit SHA. Record final source, run IDs, asset/package receipts and downstream
results here after their actual execution; do not infer publication from local
test success.
