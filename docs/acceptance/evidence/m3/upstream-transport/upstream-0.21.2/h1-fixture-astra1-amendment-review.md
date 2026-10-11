# H1 fixture Astra1 amendment independent review

Task `m3_h1_fixture_astra1_amendment_review`; direct bounded independent design
review in `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`85c2284a035e0b4ecbf577279eee01142702b5a3`. SPEC first, then CODE QUALITY:
**PASS for the concrete proposed B05/B17 amendment**, no actionable finding.
Executable correctness and runtime acceptance are NOT REVIEWED/NOT RUN.

Reviewed design SHA256:
`1cdb35da920d7f800d20db82ed643cd7e5fe24315d4481897a4a3fcefd092776` (MD),
`59f7742377a0889228c754c50bfbd43b721503db8d1c3bdff347047ee54e1ce7` (JSON).
Canonical plan remains
`01acb850d85b90c2409092d7bf25c5400ad2e519d233858d9194dbce211e6720`.
All three current executable hashes match the design and pre-Astra preserved
copies. No executable or canonical plan was changed by this review.

## SPEC

B05's append-created parent has logical size65536/131072 but the parent's
referenced allocation is131072/157286. The preserved parent OTP28/Elixir1.18.5
probe records that copying the completed parent produces exact65536/131072
backing for both parent and slice. `:binary.copy/1` before slicing is the
smallest source-construction repair: keep the exact referenced-size assertion,
existing boundary rejection/compact-copy counts, slice greater than64 bytes,
malformed-input expectations and zero Fetch. Temporary append/copy roots stay
within the already reserved source role; this is no numerical peak or native
release certificate. Probe exit0 is parent-reported; the reviewer rehashed and
read the preserved rows without executing a probe.

B17's preserved generation row has originalD500, published `timed_out`, two
issued waits with actual public `cleanup_pending` for both, and no retirement
confirmation. Request cleanup provides no ordering edge that guarantees a
zero-time second generation wait sees retirement. Keep the strict test's
`:ok` retirement confirmation. The proposed second wait is a distinct finite
cleanup observation on the original returned abort receipt, using remaining
time to predeclared t0+25000, while slot0 retains originalD=t0+500, its exact
published pending and tolerance<=100ms. Shutdown remains t0+30000, primary
remains t0+15000, and request/connect deadlines stay unchanged. The model's
late `scope_retired` transition already preserves `:timed_out`; its static
regression asserts the same separation. No model edit is required.

Accept this exception only for B17 slot1 after slot0 pending/D500, with separate
bounded purpose/deadline/result fields. Preserve one graceful call, one abort
call, two reserved wait helpers/observations, the owned pre-call barrier and
registration-before-wait. No third wait, renewed D, new helper/receipt, retry,
poll, sleep, private operation, native control refund or snapshot-derived
success is authorized. Late pending/failure or missing original public `:ok`
remains FAIL; all original owned joins remain required.

## CODE QUALITY and execution boundary

The design is specific and minimal: one exact parent materialization and a
restricted use of an existing wait slot. It explicitly calls out the canonical
role-table, original-deadline and B17 zero-time paragraph contradictions.
**Parent must update and rebind those canonical specification sections before
executable GO.** This design review does not silently supersede the current
plan and does not grant executable GO. Later implementation SPEC/CODE review
must verify slot/deadline guards, separate evidence export, strict test assertions
and unmodified operation ceilings before scoped B05/B17 runtime verification.

B11/B12's upstream blocker is source-evidenced: SocketClient sends lifecycle
abort before exact stream error; lifecycle cancellation sends stream stop from
a different sender; unread stop can flush nothing and exit. Preserved B11/B12
rows show missing consumer terminal observations and one delivered
`trailers_too_large` success, while exact baseline scheduling is unobserved.
The proposed public reproduction is NOT RUN. The parent-owned issue body routes
a blocker Bug to `gsmlg-dev/http_fetch`, requesting `gsmlg-opt/gaoxy` on
`codex/m3-gateway`; issue creation and actual-number TODO remain parent-owned
and pending as of the handoff. Stop those cases without local timing workaround,
generic-abort substitution, skipped tests or dependency patch. All20 original
test definitions and all failed receipts stay visible; a selected B05/B17 run
cannot be called baseline20 PASS. Full baseline awaits the upstream fix and
updated dependency.

The historical baseline remains20/4, childexit1, zero skips/exclusions,1132
unchanged inputs and no reported remaining peer. Exact log and selected artifact
hashes match its receipt/analysis. B05/B17 failure rows retain failed public
cleanup proof even though their fixture actors joined. No failed result is
promoted to acceptance. B21 stays deferred/fail-closed; #97/N8, numerical proof,
managed activation and M3 remain blocked. TLS Sol2/unsuccessful2/Astra2 is a
separate exhausted chain. Fixture Sol2/unsuccessful2 is preserved; Astra1 is
assigned/reserved, completed Astra executable repair validations remain0.

Only this report and its JSON companion were written. Reviewer repair counters
Sol0/unsuccessful0/Astra0, received completedAstra0. All static read/hash/JSON
commands finished synchronously. No Git, VM/Mix, network, formatter, dependency,
parser/AST, executable mutation or background command was launched. Other
writers' sources/processes were untouched. Exact bindings and next-gate
requirements appear in the companion.
