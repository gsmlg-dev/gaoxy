# M4 total-deadline ordering execution delta

Root owns `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, `http/session.ex`, this
design/plan and all serial Mix/live commands. The worker owns only assigned
deadline regressions in the proxy test directory. Reviewers own unique new
receipts. Writers preserve others' work and freeze all apps/integration sources
during every recorded execution.

1. Preserve [repair3 FAIL](../acceptance/evidence/m4/upstream-matrix/matrix-1791846819392530106/result.json)
   and cumulative counters: unsuccessful live8, unsuccessful production3;
   production repair4 is pending, UP0 Sol2/Astra2 remains exhausted.
2. Independently review [the ordering design](../designs/m4-proxy-total-deadline.md).
   Add deterministic expiry-cast/timer callback-order regressions using a
   controlled deadline and token:nil; their scope is notification ordering,
   not allocated-resource cleanup. Preserve the existing real guardian test and
   original error, no-FIN/reset and finite-deadline assertions; record actual RED.
3. Implement only the guardian expiry notification seam and selected H3 total
   ordering in the proxy. Keep idle/default H1 and ordinary cancellation behavior.
   Guard queued successful/nonterminal events before dispatch after total expiry;
   route owner-local read/poll/write timeouts at the actual H3 total deadline into
   the same finite terminal-only wait, without recursive guardian-error handling.
   Format exact authored files, strict compile and execute all relevant proxy,
   native H1/H2/H3 and guardian/lifecycle compatibility tests.
4. Resolve independent CODE/evidence findings and run fresh checks, then execute
   the unchanged66 network+2 policy matrix with actual cumulative counters.
   New failures enter diagnosis; do not weaken their assertions.
5. After complete PASS independently review actual evidence and fresh repeat.
   Complete affected G1/G2/G3, standalone, consumers and final M4 verification
   before conditional main/push/v0.3.0 publication and next-stage preparation.
