# TLS95 fixture independent specification and code-quality review

Task `m3_tls95_fixture_independent_review`, direct independent Sol; **DONE** for
this static review assignment. **FAIL** for fixture specification conformance and
code-quality acceptance: three actionable failure-cleanup findings remain.
Candidate GREEN, baseline RED, compilation and all runtime cases are **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`.
The historical spec baseline `81b01bd` is preserved. Parent reconciled its later
pure model commit; no TLS input hash drift was found. Pre-existing model, dependency,
lock, plans and evidence changes are preserved. Only this report and its
[JSON receipt](tls95-fixture-code-review.json) were created.

| Finding | Location in managed_tls_tracking_probe.exs | Required repair |
| --- | --- | --- |
| TLS95-FIXTURE-01 (high) | 334,358-360,742-743,775-789,887-905 | Retain every successful late custodian open and explicitly retire its scope before stopping the creator. |
| TLS95-FIXTURE-02 (medium) | 671-674,840-843,857-883,887-913 | Require successful captured helper/custodian results and join checks as well as normal DOWN for cleanup PASS. |
| TLS95-FIXTURE-03 (medium) | 485-496,775-854 | Register each original retirement receipt before awaiting and explicitly retry/check each retained receipt during cleanup under its original deadline. |

**TLS95-FIXTURE-01:** `open_scope` records the public handle only after its primary
wait succeeds. If that wait expires and the custodian returns an open scope during
cleanup, `receive_owned` saves only `custodian.opened`; the explicit cleanup scope
list remains empty. Creator shutdown then initiates upstream abort without any
confirmed public receipt check. Cleanup can incorrectly claim PASS. Record the
expected result before spawn, reconcile all open results during cleanup, retire
all recovered scopes, and preserve FAIL for unavailable/unknown open results.

**TLS95-FIXTURE-02:** A helper assertion is captured as an error result while the
helper still exits normally. `join_jobs` accepts any non-nil result; cleanup checks
only joined/normal DOWN/not forced. Custodian open errors are likewise omitted from
the PASS predicate. Require the actual successful captured result and successful
join check for every healthy helper and custodian, while retaining the primary
error separately and attempting all remaining cleanup. Unknown CA remains a
successful producer result with the exact pre-registered unconfirmed terminal;
it must not be confused with a captured fixture exception.

**TLS95-FIXTURE-03:** The original durable retirement receipt is returned to the
parent only after both await assertions and a successful helper join. If retirement
succeeds but waiting fails, that receipt disappears from parent ownership.
`state.receipts` is also never enumerated by cleanup. Send and acknowledge receipt
registration immediately after acquisition, retain its exact expectation, and
attempt every original receipt during cleanup even after an earlier failure.
Keep the same absolute deadlines and ten-helper cap; existing retirement cleanup
helpers can carry these checks rather than adding an unbounded caller loop.

Static requirements otherwise match the reviewed plan: five candidate/two baseline
cases; source-derived H1 resources3 and H2 resources4; genuine absent H1 ALPN and
H2 h2; immutable oracle on baseline1/2; mismatch accumulation through both GETs,
body/reuse/original completions and commanded-close zero barrier; independent B
live before/after A retirement and survivor reuse; exact structured unknown_ca
with empty explicit trust and conservative cleanup_unconfirmed; original ACK/EOF
and deadlines; sole budgeted public snapshot entry with two stable maps and
682/240 global,120/201/40 case,40 window caps. Healthy flow uses at most5/9/4 helper
starts for inventory/retirement/handshake and at most two custodians/producers.
Owned fallback shutdown retains cleanup FAIL. The fixture uses public APIs and
owned fixture PIDs only; it has no private TLS/socket injection, client-process
inspection/kill, System.halt or unbounded evidence history. It returns/raises only
after case/cleanup/summary reporting for the separate same-VM identity wrapper.

The pinned OTP record/constructor plus candidate registration/dedup/handoff source
reconfirm TCP1+TLS2 and H2 owner1; original-token pruning needs actual resource
DOWN. Baseline source ignores the eight-element TLS representation and predicts
1/2. Unsupported/legacy shapes remain source-only. No individual TLS PID or byte,
native/backing, arbitrary-history, full P0-P6 or activation claim is made.

Fresh static checks: **14/14 freeze hashes,63/63 inventory input hashes,35/35
embedded source-reference hashes match**; unchanged historical39 driver/helper
bytes are included. Python `ast.parse` passes for the adapter and both inherited
peers without imports/execution/bytecode. Source identities:

- Driver: `efb1eb2864eec629701c20d8c16dea4a7249890a41d811c0568c4bf4ce278b76`.
- TLS peer: `5fba2a96dc3274f7b9ef3f1e2a893d76ab43f7a47d633e355254fd25ed715406`.
- Plan: `9951eaeb0cc8ea82ceebcf3ade4c74301c18de6ed69eba7f9394c0adb50cf0a0`.
- Inventory: `4f74eb993e8693fd01bad4758888f96ad6191bef757e3c19a07b9df710c680e5`.
- Freeze: `1a8bda380a7b4dec92bc2bec205b538d37ecf84623e60a24222e1534da36cb93`.

The receipt contains every exact input hash, source reference, command outcome and
finding. Initial read-only Git status/HEAD commands exceeded the parent's no-Git
actions boundary; this was disclosed immediately, changed no state, and no further
Git command ran. No VM, Mix, formatter, peer, network, dependency action or delegation
ran. No Elixir compile/AST claim is made. Parent's previous formatter diagnostic
is distinct from runtime qualification; parent tooling has a separate review.

Fixture chain remains Sol repair0/unsuccessful0/Astra0; historical specification
Sol2/unsuccessful1/Astra0 and parent tooling Sol1/unsuccessful0/Astra0 are unchanged.
This reviewer repaired no implementation. Parent should assign targeted fixture
repair1, preserve these original FAIL reports, freeze changed bytes and obtain
independent re-review before execution. No product decision or Astra gate is needed.
All own commands finished synchronously; no owned background process/VM/peer was
started. Review-output ownership is released on handoff.
