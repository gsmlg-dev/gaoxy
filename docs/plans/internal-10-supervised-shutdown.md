# Supervised HTTP shutdown implementation plan

- [x] Read issue #10 and trace HTTP/HTTP3 wrappers to the validated Gaoxy budget.
- [x] Add self-contained child-spec and real supervised HTTP shutdown regressions.
- [x] Preserve failing evidence for the missing budget and supervised active kill.
- [x] Share the pure core Config budget helper while retaining wrapper identity/start/error behavior.
- [x] Run scoped tests and existing lifecycle compatibility with zero failures.
- [x] Obtain independent review and fresh integrated verification.
- [ ] Include the fix in the coordinated 0.9.0 publication and clean consumer check.

Evidence: `.audit/internal-requests/10/`. Tests:
`apps/gaoxy_http/test/supervised_shutdown_budget_test.exs` and
`apps/gaoxy_http3/test/supervised_shutdown_budget_test.exs`.
