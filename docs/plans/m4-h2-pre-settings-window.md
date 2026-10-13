# M4 H2 initial-window transition repair6

Root owns `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`, this design/plan
and all serial format/compile/test/live executions. The test worker owns only
`apps/gaoxy_http/test/http2_pre_settings_test.exs`. Independent reviewers own
unique new review receipts. Writers preserve others' changes and freeze
apps/integration during recorded executions.

1. Preserve [the terminal diagnostic FAIL](../acceptance/evidence/m4/upstream-matrix/matrix-1791848586737931556/result.json)
   and counters: unsuccessful live11, failed production4, repair5 harness1;
   production repair6 is pending. Independently review
   [the design](../designs/m4-h2-pre-settings-window.md).
2. Add the six bounded raw-frame native regressions described in the design,
   format only their file and execute an actual causal RED. Do not count compile
   or fixture errors as the required RED; repair those before production edits.
3. Apply only the pre-ACK default window, first-ACK delta/idempotence and zero-DATA
   credit correction in Connection. Preserve all existing assertions and limits.
   Run exact-file format, strict compilation and all affected H2/H1/H3/proxy
   lifecycle/guardian tests with nonzero executed counts.
4. Resolve independent CODE/evidence findings, including the current peer's
   diagnostic terminal assertion; run fresh scoped checks. Execute all66 network
   plus2 policy UP2 rows with `GAOXY_UP2_REPAIR=6 GAOXY_UP2_FAILED=11`. A new failure
   remains FAIL and enters diagnosis, without another Astra recovery round.
5. After complete PASS obtain independent actual-evidence review and fresh full
   repeat. Complete final Session, G1/G2/G3 browser, standalone and consumer gates,
   synchronize documentation and obtain final M4 review. Only completed M4
   permits the conditional main/push/v0.3.0 release plan and next-stage preparation.
