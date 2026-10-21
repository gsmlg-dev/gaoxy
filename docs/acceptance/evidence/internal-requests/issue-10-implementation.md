# Supervised HTTP shutdown implementation evidence

Issue: gsmlg-dev/gaoxy#10. Implementer: Sol (`tls_client_cert`).
Checkout: `/home/gao/Workspace/gsmlg-opt/gaoxy`, `main`, baseline
`32933790457bcfa3533e40dc2ae4d51ad91aa86d`. Concurrent edits preserved.

Implementation verification: **PASS**. Independent review, publication and
requesting consumer acceptance remain separate gates.

HTTP and HTTP/3 child specs now obtain shutdown allowances from the pure shared
`Gaoxy.Config.shutdown_timeout/1` helper. It validates raw limits through Config's
existing defaults and checks; the core Gaoxy child spec retains its full service
validation and delegates its selected maximum drain to the same calculation.
Wrapper identity, start tuple, restart policy and deferred initialization/errors
remain unchanged. No drain formula or lifecycle algorithm was duplicated.

With `ELIXIR_ERL_OPTIONS='+S 2:2'`, under the root Mix lock:

- Confirmed red: `mix test apps/gaoxy_http/test/supervised_shutdown_budget_test.exs
  apps/gaoxy_http3/test/supervised_shutdown_budget_test.exs`: HTTP 4 tests,
  3 failures; HTTP/3 1 test, 1 failure; exit 2. Budget omission and both progressing
  active-upload instance `:killed` exits reproduce the issue. Idle cleanup passes.
  `.audit/internal-requests/10/red-confirmed.log` preserves this evidence.
- Initial green: the same files plus `apps/gaoxy_http/test/http_lifecycle_test.exs` and
  `apps/gaoxy/test/shutdown_hardening_test.exs`: core 8, HTTP 7 and HTTP/3 1 test,
  zero failures, exit 0. `.audit/internal-requests/10/green.log`.

- Independent review found premature user initialization caused by the first
  wrapper implementation invoking `service_spec/1` during child-spec construction.
  New counting regressions failed for both wrappers (2 executed, 2 failures,
  exit 2), preserved in `red-initialization.log`; the independent raising probe
  remains in `independent-init-probe{,-direct}.log`.
- Repair 1 green: the same two new files plus existing lifecycle/shutdown files
  listed above: core 8, HTTP 8 and HTTP/3 2 tests, zero failures, exit 0.
  `.audit/internal-requests/10/repair-1-green.log`. Counting/raising tests prove
  child-spec construction invokes no user callback, supervised HTTP startup
  initializes once, and startup exceptions retain their original boundary.

The actual supervised HTTP tests hold incomplete requests across default 5000ms
and non-default 5500ms drains, supplying body progress every 100ms to prevent
idle timeout. They require instance monitor reason `:shutdown`, backend/service/
gate descendant termination acknowledgements, worker termination, closed client
socket and successful listener port rebind. Completion remains below drain plus
2000ms. HTTP/3 coverage is a budget contract test, not a QUIC network drain claim.

The initial red fixture passed the test PID rather than the service PID to the
owned-descendant snapshot; that isolated fixture error was corrected before the
confirmed red. Its original evidence remains in `red.log`. This did not change
production behavior or weaken assertions. Cumulative Sol repair rounds 1
(successful); Astra rounds 0. All commands finished. No commit, push or publication by worker.
