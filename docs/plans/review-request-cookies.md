# Split Cookie forwarding implementation

Date: 2026-10-20, Asia/Shanghai. Scope: R3 of the correctness repair.

1. Inspect the shared request preparation and both H1 upstream modes.
2. Reproduce separate Cookie fields in pure tests and on actual H1 origin wire
   for H2 dedicated, H2 managed and H3 dedicated requests.
3. Join only multiplexed request Cookie fields after hop filtering and before
   final header limits. Preserve H1, unrelated repeated fields and Set-Cookie.
4. Run the focused suite and existing header regressions; obtain independent
   specification and code review, then rerun the integrated repair gate.

No dependency changes, specialist suites or new proxy protocols are included.
