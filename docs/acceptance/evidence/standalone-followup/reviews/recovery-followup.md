# Issue A independent review follow-up — expired activation

Task: review_recovery. Status: DONE / PASS for specification and code review;
the initial P2 is resolved and there are no remaining actionable findings.
Direct focused re-review, 2026-10-21, `.trees/standalone-ci-followup`, HEAD
`7e30d14802ee5170b3864dba85eb913d1c650eee`, original baseline
`581bea7d27b9d86c7dd0e63a1d49fcbca3adc3dd` plus uncommitted A source.
The initial REQUEST_CHANGES artifact `recovery.md` is preserved unchanged;
its SHA256 remains `dd98788cd4cfadfa99601d1e0c891c9208bba21c78cb33e560d75b2a32ed3df0`.

## Specification and code result

`generation.ex:105-106` now returns `{:error, :invalid_activation_timeout}`
for typed resolved/declarative routers when timeout is invalid or exhausted.
This is the prior `activate/4` behavior and closes the coordinator exception
path without changing the shared deadline, activation guards, publication,
resource acquisition or cleanup semantics. No unrelated fallback/refactor was added.

The regression at `standalone_recovery_test.exs:118-162` gates endpoint init
inside the real RouteResources compile path after managed resource preparation.
It observes the original caller's deadline error and normal monitor DOWN,
confirms remaining budget is zero, then releases compilation. A synchronous
state barrier on the same coordinator proves its survival. It also asserts the
same runtime and owners, identical accepted declaration/generation and baseline
pins, pending preparation obligations followed by reconciliation, and accepted
route traffic. These identity checks specifically prove an expired candidate
causes no recovery; they do not prescribe store identity or supervisor layout
across the intentional recovery that follows.

The earlier stale-candidate, fixed/group supervised recovery, held independent
custodian survival/normal settlement, final reload, retired-pin settlement and
current-resource traffic/status assertions remain unchanged. The repair patch
only adds the fallback and extends the two existing cases. No assertion was
removed/weakened or original deadline enlarged. The endpoint gate has its own
finite failure deadline and uses explicit messages rather than an arbitrary sleep.

## Evidence and read-only verification

Reviewed immutable evidence:
`docs/acceptance/evidence/standalone-followup/repair2-expired-activation/`.
Receipt SHA256 verified:
`a0fb916e104f9b29bcbdb9a2bc0ad5b2da62fb71322767cccdb9d01c721d1c0c`.
Recomputed receipt, patch, all five log hashes, and both exported/current source
hashes; every expected digest matched. Red and green receipts bind the same
current test hash. Red uses the exact original production generation.ex hash.

- Actual red.log: both fixed/group cases reach the coordinator's
  `activate_declared/5(..., 0)` FunctionClauseError after caller deadline;
  2 executed / 2 failures, exit 2. This is a runtime product failure, not fixture setup.
- Actual green.log: 13 HTTP + 4 server tests, 17 executed / 0 failures, exit 0.
  The 4 server cases include the two extended recovery cases.
- Worker strict compile, scoped format and diff check: exit 0, Elixir 1.18.5 /
  OTP 28; these remain worker execution evidence, not fresh reviewer tests.
- Read-only Python AST inspection confirms the unchanged manifest contains 2
  recovery cases and 160 total cases (141 unit + 19 protocol). Only the two
  assigned A source files differ from the initial eight-file snapshot.

No reviewer Mix/build/test process was launched. Parent owns fresh integrated
verification on the final candidate and B/C/hosted/publication acceptance.
Original review scope and all production/specialist limitations remain.
Cumulative received A repair counters: Sol 2, Astra 0; reviewer added 0.
No escalation gate or decision is needed. All reviewer commands finished;
only this new review artifact was written, with no implementation edit/commit.

## Reviewed source identity

Canonical sorted compact JSON path-to-SHA256 snapshot digest:
`9420e2959a105ac443802693557b07ad9faa0e95644c9359d01a2405bf532eb0`. The initial six unchanged A files and gate retain their
initial review hashes. Updated files:

| File | SHA256 |
| --- | --- |
| `apps/gaoxy_http/lib/gaoxy/http/generation.ex` | `df20a47f0bf642fa03e50592fde97e3b733528ebe4584c63a724d713c851ed23` |
| `apps/gaoxy_server/test/standalone_recovery_test.exs` | `a94845f01bf908d1451a17e863efcdca2272dc0a1696c8d4074f5df8c5b145b2` |
