# Owner capacity deadline test contract — independent SPEC source review

**PASS source only:10/10 checks; no actionable findings.** Runtime/tests/build/formatter NOT RUN.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Parent baseline HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`, tree `a26656f16425d35ccc08584ee0486abb296a3c39`; no Git/index commands.

Saved pre-repair source SHA `3be48a3ea58ff72716de80b9ee1b8fce9afb976b6192ac2411469ba2f111efd1`; current owner test SHA `63dc0e3bf377ec906309c442f54a140da5d383b56c03638af31765951d3907d7`. Full-file Python difflib shows changes only in the assigned capacity test.

- **OD1 PASS:** One absolute Lifecycle.deadline(60_000) is created after fixture startup and passed unchanged to all64 preparations, recursive fill and final denied pin_many call. No renewal or infinite retry; fill_control retains finite remaining>0 and pin-count bounds.
- **OD2 PASS:** The original loop1..64 and exact128-byte distinct group IDs, successful compile/prepare, actual64 handles and real public baseline pin filling are unchanged.
- **OD3 PASS:** All original byte-capacity assertions remain: pins nonempty; below max_pins; control_bytes<=limit and control_bytes+pin_cap>limit; exact per-record control sum; explicit group_capacity on extra real pin_many.
- **OD4 PASS:** Exact denied full owner state and actual sorted monitor snapshot equality remains. Added Map.take(state.pins, Map.keys(before.pins))===before.pins authenticates complete original preparation records at denial.
- **OD5 PASS:** Original removed_record exact stored charge decrement remains; added original-pin map identity after refund. Duplicate release still asserts :ok and entire refunded owner/monitor snapshot unchanged.
- **OD6 PASS:** Remaining actual filled pins all release with :ok; restored.pins===before.pins strengthens final original pin identity. Original control_bytes===before.control_bytes equality retained via named restored state.
- **OD7 PASS:** Added Lifecycle.remaining(operation_deadline)>0 before original preparation release guards against a false restored observation after expiration. Original Resources.release for every preparation and assert_empty_groups remain.
- **OD8 PASS:** Only the target test changed: shared deadline substitution, additive identity/time assertions and removal of temporary IO diagnostic block. No production or helper changes in compared file; ExUnit finite120s cap unchanged.
- **OD9 PASS:** Lifecycle.deadline/remaining use monotonic milliseconds; public owner pin preparation expirations use the supplied deadline. The source repair directly resolves differing30s preparation /60s fill budgets without claiming the observed failure cause proved.
- **OD10 PASS:** Original FAIL24/1 remains preserved and attribution UNPROVED. Root diagnostic24/0 did not reproduce it and wrapper exit1 due expected2 remains visible; no runtime acceptance inferred.

No original capacity, no-effect, exact refund, duplicate-release idempotency or final cleanup assertion was removed/weakened. The removed lines are temporary diagnostic IO only. The new common absolute60s deadline stays under the unchanged120s test cap and is never refreshed during filling.

The original FAIL24/1 cause remains UNPROVED; diagnostic24/0 with little time remaining did not reproduce it, and its wrapper exit1 is not a passing gate. This review certifies the test-contract source repair only. Root retains runtime/evidence responsibility. Prior handoff-failure and partial-write-failure gaps remain open pending drafts.

Repository unchanged. Only the two assigned /tmp reports written. All reviewer commands finished; no reviewer process remains. Reviewer Sol repair0; inherited Astra2/2 exhausted, with all root counters preserved without reset or inferred aggregation.
