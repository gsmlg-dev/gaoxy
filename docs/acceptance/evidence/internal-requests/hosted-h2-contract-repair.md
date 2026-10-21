# Hosted H2 stream-shutdown test contract repair

Source before repair: `044e1cd90ddf4cc1550df99411f2906209387f5f`, `main`.
Foundation run `39649482718`, native HTTP job `119393727060`, failed its
new H2 stream-shutdown assertion with seed 323678, max cases 4: HTTP 39/1,
core 4/0, H3 3/0. The hosted assertion did not print the unexpected value.
One unchanged local run with the same seed/concurrency passed 46/0; this
intermittent pass was not treated as a repair.

An instrumented bounded diagnostic cloned the same real-H2 drain test 24 times,
without changing runtime source. It reproduced two failures, both returning
exactly:

```elixir
{:error, {:services, [http: {:error, {:deadline_exceeded, :cleanup_pending}}]}}
```

The other 22 returned the direct caller deadline error. ADR 004 explicitly
permits both caller timeout and an instance coordinator's service aggregate.
The new test incorrectly assumed that the caller timeout always wins that
scheduling race. Runtime normalization would change the existing API contract.

Only the new H1/H2 test assertions are corrected to recognize the exact single
`:http` pending aggregate. Arbitrary service errors, cleanup failures and all
other return values still fail. The 500 ms stop budget, elapsed bound below
1500 ms, worker DOWN within 1000 ms and H1 socket-close checks remain. Both tests
also premonitor the instance and require its normal DOWN within 1000 ms.

Independent specification/code review by `/root/websocket_limits`: **PASS**,
no actionable findings. One successful Sol test-contract repair; Astra zero.
Other issue repair counters remain unchanged.

Fresh verification:

- Combined eleven-file issue gate, seed 323678/max cases 4: **46/0**, exit 0.
- Repaired real-H2 diagnostic: **24/0**, exit 0; it again observed two exact
  service aggregates, now with all worker and instance termination checks passing.
- After review, unchanged H1/H2 files at the same seed/concurrency: **12/0**,
  exit 0. Canonical formatting and whitespace checks: **PASS**, exit 0.
- Of the original 557 source-manifest entries, only the two test files changed.
  Runtime, package sources, dependency locks and workflows remain byte-identical.
  Refreshed manifest fingerprint:
  `d82c696ee30d855d79e9c0e8e2de8ecb17246d8c7ecaeddc8763172188f55bd2`.

`hosted-h2-contract-repair-audit.tar.gz` preserves the full hosted failure,
unchanged rerun, diagnostic source/red and green logs, patch, fresh verification
and receipt. The initial qualification manifest and audit remain unchanged.
Public-consumer verification additionally rejects excluded/skipped required
cases; its archived verifier now matches the script prepared for execution.

This is a test-contract correction, with no product change. Final committed-SHA
hosted verification and publication remain pending at this preparation point.
