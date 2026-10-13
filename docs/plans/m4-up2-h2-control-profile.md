# M4 UP2 repair7 fixture control profile

Root owns `integration/http3/upstream/fixture.exs`, matrix README, this
design/plan and all serial executions. The worker prepares only the assigned
`http2_control_rate_test.exs`; root copies/formats it after the live-source
freeze ends. Independent reviewers own unique receipts. Preserve others' work.

1. Preserve [repair6 FAIL](../acceptance/evidence/m4/upstream-matrix/matrix-1791849278870095368/result.json)
   and [actual GOAWAY diagnostic FAIL](../acceptance/evidence/m4/upstream-matrix/matrix-1791849461396561662/result.json).
   Keep cumulative live13, failed production5 and repair5 harness1. Repair7 is
   a test-profile correction; no native production changes are planned.
2. Independently review [the selected profile](../designs/m4-up2-h2-control-profile.md).
   Add real network guard regressions for default256 and selected2048. Record
   their actual passing execution against unchanged native policy. This coverage
   protects existing behavior; it is not a newly implemented production feature.
3. Select supported finite `control_rate: 2_048` in both matrix H2 services and
   report that profile in fixture startup metadata/README. Retain all existing
   assertion expressions,66+2 manifests, receive windows and absolute deadlines.
   Format exact files, strict compile, run affected native/proxy suites and
   independently review code/evidence, including diagnostic peer identity.
4. Run the entire matrix with `GAOXY_UP2_REPAIR=7 GAOXY_UP2_FAILED=13`. Preserve
   any failure and enter diagnosis. A full PASS needs independent actual-evidence
   review and a fresh full repeat. Then complete the prescribed final M4 gates
   and conditional release plan. Counters never reset.
