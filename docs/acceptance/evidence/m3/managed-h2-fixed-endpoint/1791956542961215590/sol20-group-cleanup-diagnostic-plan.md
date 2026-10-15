# Sol20 group cleanup diagnostic plan

The new 0.21.10 complete full58 command executed853 tests with1 failure
and exit2 on stable source. Original cancellation classification passed.
The only failure is fixture cleanup in upstream_group_transport_test.exs,
which returns a protected ExUnit.AssertionError without its original values.
The cause is unknown; production changes are not justified yet.

1. Complete current independent static SPEC and release its candidate freeze.
2. Apply the independently prepared test-only diagnostic wrapper. It logs the
   original exception/stacktrace and reraises the same exception inside the
   existing protection. Preserve callback body, assertions and finite deadlines.
3. Extend ownership and format manifests by this existing test file; preserve
   all58 required paths. Freeze all writers and execute the complete group test
   file once with seed33011/max-cases1 under the same environment. This is a
   diagnostic, not acceptance. A green result does not resolve the retained
   full58 failure; if needed execute the original full58 with instrumentation
   to recover its original ordering/context.
4. Use the actual original assertion to choose one causal hypothesis. Before
   any repair, produce a deterministic failing regression and bounded repair
   design/plan. Then run affected tests, independent SPEC then CODE, and fresh
   full required gates. Never weaken assertions or replace the failure by a
   nonreproducing retry.

The prior cumulative counters and upstream122 full58failed1 persist.
Diagnostic instrumentation adds zero production repair rounds. Astra recovery
2/2 is exhausted. Root owns all repository writes and runtime; reviewers may
read in parallel and write only their assigned /tmp reports.
