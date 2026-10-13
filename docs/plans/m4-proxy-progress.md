# M4 proxy progress execution delta

Root owns the proxy wait loop, shared fixture, this design/plan and all serial
Mix/live commands. The H1 worker owns only native H1 connection initialization
and its real-TLS network regression. The independent reviewer owns unique new
receipts. Writers preserve each other's changes and freeze apps/integration
sources during every recorded execution.

1. Preserve the five FAIL runs and unchanged cumulative Sol/Astra counters.
   Independently review [the design](../designs/m4-proxy-progress.md), especially
   closure behavior of zero-wait polling for all three downstream protocols.
2. Add the meaningful 1 MiB native H1 TLS regression; record its actual RED
   before the two-line socket-capacity change. Record each production repair
   and verification failure separately. Confirm H3 closure semantics before
   activating the mailbox wait correction.
3. Remove the fixture's diagnostic receive-capacity behavior flag. Format only
   authored files, strict compile, then run the native H1 and relevant proxy
   configuration/wire/runtime/TLS/header/Session compatibility tests. Keep
   assertions and deadlines unchanged; diagnose every actual failure.
4. Obtain independent specification and code review, resolve concrete findings,
   then execute the unchanged full UP2 matrix without diagnostic flags:

   ```sh
   nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
     integration/http3/upstream/run.py --gate matrix \
     --evidence docs/acceptance/evidence/m4/upstream-matrix
   ```

   Require all 66 network plus two policy rows, exact source stability,
   admission/guardian baselines, children exited and UDP ports rebound.
5. Diagnose later failures, preserving original error/FIN contracts. After full
   PASS obtain independent actual-evidence review and a fresh repeat. Run
   affected downstream/standalone/browser/consumer and final M4 checks before
   updating acceptance or integrating/publishing under the conditional release
   authorization. This delta adds no new product scope or deployment authority.

Repair1 still fails the unchanged tiny response row. Apply the design's bounded
matching-ACK timer correction as repair2: record the new regression's actual RED,
review the timer/ACK contract independently, make the one-site correction, run
fresh scoped checks/code review and repeat the unchanged matrix. Preserve
repair1 FAIL and cumulative six unsuccessful live executions. Root additionally
owns only HTTP3SessionClient.acknowledge and its scoped test for this delta.

Repair2 passes the original1MiB row but fails native H1 abrupt TLS cancellation.
Preserve its FAIL and seven unsuccessful live executions; begin production
repair3 without resetting any Sol/Astra counters. Root owns the narrow idle
TLS polling amendment to the proxy wait loop and these documents. The worker
owns only the new actual TLS-abort regression in `http_proxy_runtime_test.exs`.
Independently review the design using the current locked OTP28 source, record
actual scoped RED, implement the idle-only one-millisecond TLS poll, format and
strict compile, then execute fresh relevant protocol/proxy compatibility tests.
Obtain independent CODE/evidence review before another unchanged66+2 matrix.
Keep all existing endpoint error, FIN, cancellation, error-class and deadline
assertions intact, including later total-timeout rows. No third Astra recovery
round is authorized.
