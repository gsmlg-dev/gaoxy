# Issue A local recovery evidence

Baseline: `581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`, branch
`codex/standalone-recovery`, isolated `.trees/standalone-recovery`.
Environment: Elixir 1.18.5, Erlang/OTP 28, ERTS 16.4.0.5;
`ELIXIR_ERL_OPTIONS='+S 4:4'`. Exact commands, exits, durations and source-file
hashes are in the JSON receipts. All child commands finished.
Independent review and integration are parent-owned and pending at this receipt.

`red.log` is the real pre-production-edit runtime regression: 2 executed tests,
2 failures, exit 2. Both fixed and grouped managed routes served `startup` after
successfully accepting `accepted`; both next reloads returned
`{:error, :resource_release_pending}`. All requests and supervised recovery
completed before those assertions. Earlier fixture validation/readiness and
synchronization failures remain separately preserved under the worktree's
`.audit/standalone-followup`; they are not product-red evidence.

The initial implementation preserved the declaration but monitor confirmation
used a zero-time receive; diagnostic logs in `.audit/standalone-followup` proved
that dead PID monitor delivery can still be pending. `green.log` preserves that
initial failed run. Sol repair round 1 waits for the owner DOWN within the
original release deadline, retains direct-store activation compatibility, and
synchronizes deferred retirement before the subsequent activation. No global
Lifecycle error mapping, retired guard removal, resource/pin clearing, dependency
patch, relaxed timeout or assertion weakening was used.

Passing scoped verification:

- `compatibility.log`: 75 HTTP generation tests and 14 standalone tests; exit 0.
  Includes current-route preservation on failed acquisition, stale CAS, rejected
  standalone preparation, and live-owner cleanup-pending reconciliation.
- `owner-compatibility.log`: 9 selected existing metadata/activation/deadline
  release cases executed, 46 other tests excluded (55 reported); exit 0.
- `standalone-compatibility.log`: 9 real managed H1/H2 fixed/group standalone
  requests, local reload/rollback and lifecycle shutdown cases; exit 0.
- `strict-compile.log`: `mix compile --warnings-as-errors`; exit 0.
- `final-recovery.log`: final focused regression, 2 tests/0 failures; exit 0.
  Both active transport custodians are held across owner death, remain alive,
  resume and terminate normally. Recovered traffic uses `accepted`; the next
  valid reload serves `final`, retired pins settle, and a current resource remains
  usable. Group health uses bounded status synchronization; recovery synchronizes
  the replacement coordinator without requiring a store PID/supervisor layout.
- Scoped `mix format --check-formatted` and `git diff --check`: exit 0.

The primary compatibility runs execute 107 cases; final recovery is an additional
2-case rerun of cases included there. Failed/blocked historical specialist
qualifications and http_fetch issue 97 remain outside this scope. No publication,
production mutation, deployment or dependency mutation was performed.
