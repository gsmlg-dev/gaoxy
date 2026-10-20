# Issue A independent specification and code review

Status: REQUEST_CHANGES; one actionable P2 finding. Task: review_recovery, direct review
assignment. Reviewed 2026-10-21 in `.trees/standalone-ci-followup`, HEAD
`c965ee775d0678308d488077612a0bb6061fbe8b`, requested baseline
`581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd`. Issue A is uncommitted; this
review is bound to the hashes below, not HEAD alone. B/C and incidental compiler
changes are outside this review. Product files were read only.

## Actionable finding

**P2 — Reject an exhausted activation budget without crashing RouteResources.**
`apps/gaoxy_http/lib/gaoxy/http/generation.ex:90-103` defines only the
`activate_declared/5` clause guarded by integer timeout > 0. The new caller at
`apps/gaoxy_server/lib/gaoxy/server/route_resources.ex:155-162` invokes it with
`Lifecycle.remaining(deadline)` after resource resolution and Router.compile.
Those operations can finish at/after the shared deadline, yielding 0. The call
then raises FunctionClauseError inside `RouteResources.handle_call/3`, killing
the coordinator and triggering the one-for-all runtime/owner restart instead of
an ordinary rejected reload. The old caller used `Generation.activate/4`, whose
fallback at generation.ex:86 returns `{:error, :invalid_activation_timeout}` for
that same value. Thus this is an introduced expired-candidate behavior regression.

Proof is the complete single-clause helper definition, nonnegative remaining/1
(`lifecycle.ex:8`) and unconditional post-resolution call; no runtime/build
mutation is needed to establish the missing-clause path. Add a bounded error path
for an expired deadline (preserving rejection behavior), plus a focused deadline
regression proving no coordinator/runtime restart and accepted routes remain
usable. Do not enlarge or reset the shared deadline. No production edit or
reviewer runtime repro was performed. Parent identified the deadline path for
explicit independent inspection; the finding supersedes the initial draft PASS.

## Specification review

- The short design records surviving Registry/store state, atomic accepted
  declaration publication, owner incarnation terminality and independent cleanup.
  Store activation updates resolved router, declaration and baseline together only
  after deadline, expected-generation, retired-empty, both compiled bounds and
  baseline acquisition succeed (`generation.ex:543-558`). Rejection preserves the
  accepted declaration; recovery reads the surviving declaration rather than
  startup routes (`route_resources.ex:116-163`). Initial store activation seeds
  the declaration through the same path.
- Only managed transport/group providers handle obsolete pin metadata. A normal
  release is attempted first; only `:not_running`, local owner PID, reference epoch
  and pin reference, recognized kind, and genuine monitor DOWN permit terminality
  (`managed_pin.ex:5-32`). A live owner returning an error stays retryable; generic
  Lifecycle and Resources error handling and the retired activation guard remain.
- Cleanup is separately owned: unlinked transport custodians monitor owner death,
  join public ManagedTransport retirement receipts and helper DOWN, and retain a
  failed resident state on unconfirmed cleanup. Group pins own metadata; nested
  transport pins, probes and guardians retain holder/owner monitors. Existing
  group probe and request cleanup paths are preserved. A terminal obsolete pin
  does not assert that independent scope cleanup succeeded. No dependency internals
  or unsupported upstream API were introduced.
- The fixed/group regression runs the actual standalone supervisor and public
  route reload path, proves accepted-route recovery and another successful reload,
  checks stale-candidate preservation, monitors owners/coordinator/custodians,
  holds custodians across owner death, then confirms normal custodian settlement,
  empty retirement obligations and final traffic/current resource usability.
  Polling is bounded, synchronization uses process messages/state and finite
  deadlines, and no store PID identity is asserted. The named owner-subtree kill
  triggers the documented recovery path; no supervisor child-layout assertion or
  broader specialist campaign was added.

## Code-quality review

Apart from the exhausted-budget finding above, the managed-pin helper is
small and limited to the two providers; the declaration remains in the existing
store, with bounded routers and CAS publication rather than another mutable
registry. The old private four-element activation message is retained and
forwards to the new handler (`generation.ex:540-541`), preserving existing direct
store tests. Existing activation, rollback and live-owner release regressions
remain intact. Only two cases are added to `check-repairs.py` protocol gate;
unit remains 141, all becomes 160 (subject to fresh execution). Existing ordinary
CI (`portable.yml:42`) and prepublication (`release.yml:96`) both run `all`.

## Evidence inspected and limits

All eight imported file hashes match both the import manifest and worker receipt.
All eight receipt-listed raw log hashes were recomputed and match. The actual
pre-fix `red.log` reaches requests and completed recovery in both ownership modes:
recovered `startup` and next reload `resource_release_pending`, 2 executed / 2
failures, exit 2. Earlier fixture failures remain separate; the final test adds
stronger stale/custodian checks after that red and is not claimed byte-identical
to its earlier form. `final-recovery.log` records 2 executed / 0 failures, exit 0.

Worker evidence inspected: compatibility 75 HTTP + 14 standalone tests; owner
compatibility 9 executed (55 reported, 46 intentionally excluded); standalone
runtime compatibility 9 executed; all exit 0. Strict compile exit 0 on Elixir
1.18.5 / OTP 28. Final focused recovery is an additional 2-case rerun. This is
recorded worker execution, not a fresh reviewer runtime run. Source receipt:
`../standalone-recovery/docs/acceptance/evidence/standalone-followup/receipt.json`;
raw logs: `../standalone-recovery/.audit/standalone-followup/`.

Reviewer checks: Python AST parsing of the gate passed; read-only SHA256 source
and raw-log integrity checks passed. No Mix/build/test command was run, avoiding
shared build mutations. Parent must resolve the P2 finding and run fresh relevant integrated gates on
the final candidate. This review does not establish B/C, Elixir 1.20 qualification,
hosted CI, publication, deployment, production or excluded specialist acceptance.
Sol repair rounds received: 1; Astra: 0; review repair rounds added: 0. No
escalation gate applies. All reviewer commands completed; only this review
artifact was written. No product decision is needed; targeted Sol repair is required.

## Reviewed source SHA256

Canonical snapshot digest (sorted compact JSON mapping of the following paths to
SHA256 values): `ee92b741bc3d6f826eb048ed5bb5495f2324da0079971cc8dd00383d2e7a0757`.

| File | SHA256 |
| --- | --- |
| `apps/gaoxy_http/lib/gaoxy/http/generation.ex` | `3b734d0f728355193404d7fef952b2bc8947f79227399fd31676d25704ffb7f6` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` | `58012bff77844d5771105831cda5cc8bcfd82b05471ab1002c71565b9e8a3067` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex` | `f059adc5544b59a030eaedafe0dc150d0cab290d22cc90ff902e10524ecb7a81` |
| `apps/gaoxy_server/lib/gaoxy/server/route_resources.ex` | `39c9b5c4f91e92794afea95b0dae7c52451ab3f7330ff51d8eaaa66c175ab11e` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_pin.ex` | `62235740959ffd6fc633fa5721f58319c1ac825bc6d7e6789ae4eb029f2c79bf` |
| `apps/gaoxy_server/test/standalone_recovery_test.exs` | `57f299bced98bd879107e9dd14e51b00b181f5343b8c7e1f2175ae58cd5d281d` |
| `docs/designs/standalone-recovery-2026-10-21.md` | `801c5a842cf283ad4ac762c3088fcb90fecca78c6dd9d67d762f55ef8bf4f9e3` |
| `apps/gaoxy_server/README.md` | `31f0bb564a249839c286169619801e844b6f8ff87bba9cd0bd597c8d36add477` |
| `scripts/check-repairs.py` | `072f3d24312c67fdbaeb8d16366312610af41e150ea429fd205be9890b5c55c9` |
