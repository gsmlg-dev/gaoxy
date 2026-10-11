# H1 collector Astra counter independent review

Task `m3_h1_collector_astra_counter_review`; direct bounded independent review.
Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`85c2284a035e0b4ecbf577279eee01142702b5a3` confirmed by read-only worktree/ref
file reads. Review order: SPEC, then CODE QUALITY. Both PASS for the exact
collector counter delta; no actionable finding.

The preserved collector differs from current source in exactly two lines:
add `--astra-rounds`, integer choices `[0, 1, 2]`, default `0`; replace the
selected lane's hardcoded Astra zero with `args.astra_rounds`. Current and
preserved repaired copies match SHA256
`28a9a9b4c8335a01d1271df6c98cb8f298c7c8ecf9ae23de6b0ae52df20feb00`.
The previous source remains
`8a2ce4c4993c15fffe88ee327c3d52f079427634a565a61a8e194af70387ef42`.
All other bytes, including separate hardcoded TLS Sol2/unsuccessful2/Astra2,
remain unchanged. The value records a parent-supplied counter; it does not
prove budget authorization or enforce a global repair ledger. Options retain
existing argparse placement before the receipt name and remainder command.

The old-source argument rejection receipt binds exit2/no child. Parent current
Astra1 and default0 smoke receipts each bind1132 equal before/after inputs,
current collector source, empty-log hash, actual childexit0, tests0 and no
reported matching peer processes. The preserved out-of-budget3 parser log and
parent analysis bind exit2/no child. Parent's first analysis extraction failed
because argparse quoted `'3'`; its read-only summary correction did not change
source or rerun collector/runtime. This review checked the corrected analysis
against the preserved log. No prior receipt or review was rewritten.

These are collector smoke results only. No VM/Mix, network, formatter,
dependency operation, collector import/execution, AST parsing or Git command
was run by this reviewer. No fixture executable correctness, baseline H1/TLS
case, cleanup ownership, native accounting, managed activation or M3 acceptance
is established. Fixture counters Sol2/unsuccessful2/Astra1 are separate from
exhausted TLS Sol2/unsuccessful2/Astra2. B05/B17 recovery-design review is PENDING
until its concrete design artifacts exist; this report gives no code GO.

Only this report and its JSON companion were written. Review repairsSol0 /
unsuccessful0 / Astra0; receivedAstra0. All own commands finished synchronously;
no background process started and others' edits/processes remain untouched.
Exact source/receipt hashes and static verification appear in the companion.
