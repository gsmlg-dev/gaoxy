ARB-CORE-REVIEW: scoped acceptance

No actionable specification or code findings in the exact seven-file Astra4 task diff.

Reviewed guarantees:
- Canonical repartition normalizes complete accounting, requires nonincreasing funded total and identical memberships/process credit, preserves allocation identity, verifies owner/gate/service/instance liveness, and passes the existing epoch/revision/actor/deadline/dedup/final-commit fences. resource_budget.ex:204-214; ledger.ex:452-503,616-653,1346-1386.
- Canonical transport-category cap remains checked even though funded repartition bypasses new-growth checks; legacy local gates call the same Accounting.validate path. ledger.ex:761-787; admission.ex:1475-1489; admission/accounting.ex:12-18,83-91.
- Repartition updates canonical retained/temporary totals and in-flight sample baseline. Subsequent real admission still evaluates temporary plus unsampled retained growth through Safety.check; replenishing credit does not remove that debit. ledger.ex:790-880; resource_budget/safety.ex:8-21.
- Existing scalar replacement code is preserved. Omitted repartition fields merge with the prior complete allocation; action-specific operation fingerprints prevent update/repartition receipt aliasing. admission/accounting.ex:12-48; admission.ex:366-417.
- Startup establishes the gate before blocking dispatcher preparation. Instance drain still fences new admissions through canonical growth checks. Failed preparation confirms gate termination, reconciles/retire service scope, and cancels registry policy; the existing no-backend failure regression and two late-start/rollback/participant-order assertions pass unchanged. service.ex:60-119; resource_budget_admission_test.exs:1320-1359; staged_activation_test.exs:223-250,275-305.
- Eight new admission/owner tests exercise observable acceptance/rejection, numeric ownership and repeated safety/deadline/identity behavior. Existing test lines are preserved in order relative to before/. Both changed test files remain component-scheduled; no unit network case was added.

Fresh exact fourteen-file regression: 268 tests, 0 failures, 0 excluded, 0 skipped; exit 0. Source fingerprint: all 679 paths unchanged through execution and final review. Raw log SHA256 f35eee6b2de4ff5e66c03a1691936cbb8688dbaa352cdb1d9800df1f7af89ca3.

Verified candidate eight current source hashes (seven owned files plus staged activation), exact task.diff SHA256, and four raw verification-log hashes. Existing strict compile and scoped format passed on these same hashes; not rerun because no source changed. Current manifest: unit377/component298/protocol149; Admission44/Owner56/staged11.

Limits: this accepts only CORE funded-repartition and startup recovery. It does not certify unmigrated H1/H2 callers, H1 wire13/3, H3 native-terminal ownership, Phoenix mixed-H3 draft or full-goal release acceptance. Caller-confirmed relinquishment of retained resources remains a required protocol precondition.

No source/docs/manifest/draft changes. Only new review evidence under .audit. All commands terminal, no temporary processes remain, shared build lane released to parent. Cumulative CORE Sol2/Astra4 retained; review repair count0. Parent may route remaining CORE findings back to the existing Astra owner if integration exposes any.

Preparation-failure follow-up: the unchanged RejectPrepare regression at resource_budget_admission_test.exs:1320-1359 now explicitly executes the post-gate error branch. Its zero ownership and empty canonical services assertions, together with Reconciler.finish live-gate refusal and registration retirement gate-count checks, establish normal failure cleanup. RegistryPolicy.cancel synchronously unregisters the service key before init returns. Direct gate-PID/Registry lookup assertions would improve clarity but are not required to establish this scoped source path.
