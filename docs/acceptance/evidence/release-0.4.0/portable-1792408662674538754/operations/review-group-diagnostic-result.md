# Group diagnostic result — product FAIL, root cause confirmed

Independent raw-evidence review PASS; this is not a passing product gate. Frozen source `9253b787b57b768682bb4d894f25ca82919c0a94` ran the exact approved line21 selector:28 defined −24 excluded =4 executed,2 original failures, exit2. Both H2→group H2/h2c cases returned503 on `/a%2Fb?q=%2F`; both H1 controls passed.

The original validator accepted H1 limits containing14 native integer fields (290 validation observations). It rejected H2 limits containing16 fields, including `extended_connect` boolean and `websocket_limits` map, with `{:error, :invalid_group_accounting}` (2 observations). Final unmatched_calls=0. Observation counts are not test counts. Combined with the inspected startup/fallback path, this confirms the source incompatibility causing503.

The record reports exact helper restoration, its original hash matches `ExUnit.start()\n`, source identity matches, elapsed109.8s stayed within300s, and stderr is empty. This satisfies the runtime prerequisite for the separately reviewed narrow H2/H3 boundary repair. It accepts no repair or release: original portable qualification/product cases remain FAIL until fresh repaired verification.

Only raw-log/hash/record checks performed; no reviewer Git/build/test/runtime/browser/network execution. Only ignored review receipts written. All reviewer commands finished; parent processes untouched. Completed release Sol2, proposed repair3, reviewer repair0 and inherited Astra2/2 unchanged. Await actual-source plus synchronized scope/verifier CODE review readiness.
