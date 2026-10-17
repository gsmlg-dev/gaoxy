# Managed-H1 matrix watchdog repair2

DONE for direct assigned static F1 repair; runtime remains NOT RUN.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Parent-verified entry: `1426657e65d726629d618dcf03880df718375dd1`. Candidate2 test/fixture hashes matched before editing.

Only `apps/gaoxy_proxy/test/upstream_transport_h1_matrix_test.exs` changed: outer ExUnit watchdog40s →90s, with two explanatory comment lines. Budget:35s attached receive watchdog +40s composed accounting dispatch +10s mandatory cleanup +5s framework scheduling margin. Prescribed5s barriers,20s cases and10s startup/shutdown remain unchanged.

The longest composed accounting dispatch is `clean`: `request_clean` permits5s completion await +5s polling window +1.1s final predicate +6s receipt status calls =17.1s. The remaining `clean` work permits5s polling window +6.1s final predicate +5s `:sys.get_state` +6s final statuses =22.1s. Total39.2s is rounded to40s. Startup is the initial dispatch rather than a dispatch started near the receive deadline.

Static exact-diff reconstruction passed: restoring the original watchdog and removing only the added comment recreates candidate2 SHA256, proving all assertions and16 generated tests unchanged. Whitespace/final-newline checks passed. Fixture source still matches candidate2. All checks exited0. No Git, Mix, tests, runtime or browser ran. Parent owns canonical formatting and runtime verification.

Changed test SHA256: `5b8a4c17cdd1b3f6ad5fc1c4e2a1b4907989f647fd20279174308397b3806b62`. Fixture unchanged SHA256: `f1549e2d0493ac6f7481b57e64361d9b5635ecc4fd5b5e0e261e9fc40744ff1c`.

No other source edits, repository evidence/counter writes or background processes. All commands finished. No product decision needed.
