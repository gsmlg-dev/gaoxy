# M4 UP2 ACK polling credit implementation plan

> Root owns source and all serialized Mix/live executions. Independent Sol reviewer owns unique receipts; preserve others' edits and freeze apps/integration/scripts during runtime.

Goal: remove inherited idle polling delay after matching downstream ACK, including ACK/result ordering, without weakening original UP2 contracts.
Architecture: [bounded scheduling design](../designs/m4-up2-session-ack-poll-credit.md). No dependency/schema/window/deadline changes.

- [ ] Independent SPEC review of documented evidence, exact ref capture, both ACK/result orderings, idle backoff and unchanged bounds.
- [ ] Add deterministic regressions in apps/gaoxy_proxy/test/http3_session_client_test.exs. Keep prior ACK timer checks, include a controlled future poll_due, stale/duplicate no-op, captured paused poll ACK-before-result and result-before-ACK, one subsequent unpaused empty/control-only poll returning to5ms backoff. Record real assertion RED without production change.
- [ ] Minimal apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex change: matching ACK sets poll_due now; scheduling captures delivery ref in `{:poll, ref}` action and retains it through pending/continuation/resume; a poll result with actual target progress or observed release of its captured delivery sets due now, otherwise due+5. Preserve one operation/delivery/timer, generation fencing, limits and deadlines.
- [ ] GREEN focused tests; exact-file format, strict compile,302+affected scoped proxy tests and existing isolation. Record immutable source/log hashes/counts/exits. TDD RED is not another failed live execution.
- [ ] Independent CODE/prelive evidence review, resolve findings, fresh affected verification.
- [ ] Entire matrix with GAOXY_UP2_REPAIR=10 GAOXY_UP2_FAILED=18 via canonical nix develop/MIX_ENV=test/ERL_FLAGS=+S2:2. Require all66+2 rows, actual1MiB bytes/hash/FIN, original5sec and zero cleanup/ownership oracles. Preserve and diagnose any FAIL; update actual counters. After completePASS, independent actual-evidence review then fresh entire68 repeat and prescribed final M4 gates.

Root also updates the written status documents after actual results. Commit/main/push/v0.3.0 publication remain conditional on complete final validation and independent review; production/Vault/E2E restrictions remain unchanged.

A matching ACK must carry an actual outstanding reference: guard `is_reference(ref)`. With no delivery, nil ACK is an exact no-op and cannot manufacture polling credit. Include deterministic nil/stale/duplicate tests.
