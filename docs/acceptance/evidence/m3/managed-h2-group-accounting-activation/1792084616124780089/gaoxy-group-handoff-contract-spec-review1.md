# E4 handoff contract repair — independent SPEC review 1

Task: `E4/group_handoff_contract1/spec`. Status: **DONE — SOURCE_ONLY_SPEC_PASS**.
Direct bounded independent review; this is not runtime or stage acceptance.
Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Read-only HEAD/ref inspection confirmed `codex/m3-h1-resource-foundation` at
`7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Root owns the dirty worktree,
source, build, runtime, evidence and Git. No repository write or Git command was run.

Applied the verification-before-completion skill to distinguish the actual
source checks below from unexecuted runtime validation. Read applicable
AGENTS.md, stage Task E4/F requirements, the patch and its author handoff,
current live-gap test, owner delegation, HTTP finite accountant/dispatch,
Session handoff/failure, and exact available OTP source.

## Verdict and root cause

No actionable specification finding in this bounded correction. **16/16 source
requirements pass.** The earlier test expected the raw capacity tuple at Session
and status503. Production genuinely refuses the fifth pin with the raw tuple,
then intentionally rejects that non-finite pin reply and sends the bounded
`invalid_resource_pin` reason; its downstream response classification is502.
The patch requires both actual observations, preserves the validator and exact
no-effect/refund/identity assertions, and makes no production change.

## Requirements checklist

| ID | Requirement | Source evidence / result |
| --- | --- | --- |
| S01 | Bounded E4 scope | PASS: Only two generated genuine handoff cases and a new nonblocking test observer change; no production or fixture edits. |
| S02 | Real owner refusal | PASS: UpstreamTransports.handle_call delegates to reserve_derived_pin; max_pins refusal is exactly {:error, {:capacity, :pins}} and retains state. |
| S03 | Actual finite normalization | PASS: HTTP.account_pin_reply validates {:owner_reply, :transport, :pin}; closed accountant reasons reject the capacity tuple and HTTP cancels then sends invalid_resource_pin. |
| S04 | Exact downstream status | PASS: Session handles the normalized error through local_group_fail; HTTP.fail maps invalid_resource_pin to exactly 502 and an empty response. |
| S05 | Actual owner observation | PASS: Observer only reports the real OTP four-element out event following the actual reply; it does not manufacture or replace an owner result. |
| S06 | Full correlation | PASS: Observer captures the genuine {pump, call_tag} and operation from input; assertion pins those independently captured by the existing input barrier, plus owner and exact raw error. |
| S07 | Actual Session handoff | PASS: Barrier and assertion pin the original handoff reference and exact normalized error; no wildcard alternate error or status family. |
| S08 | Original capabilities | PASS: Exact original sibling G/T hold and completion identities, selected group/handle/instance, source holder/handles, operation reference, and pre-open nil original completion/T selection remain. |
| S09 | Held public ledgers | PASS: G2, T1/pins4, Service2*16_478_862 and selected cleanup token full reserve remain observable while Session input is frozen. |
| S10 | Exact refund | PASS: Original selected G and Service token disappear; sibling G/T hold remains exact; T1/pins3 and Service1*16_478_862 remain. |
| S11 | No side effects/replay | PASS: Original repeated no extra peer request assertions and no-open state assertions remain unchanged. |
| S12 | Sibling health and joins | PASS: Sibling response exactly 200/healthy, original completion confirmed, denied guardian normal DOWN, fixture cleanup and close remain. |
| S13 | Partial-DATA coverage retained | PASS: Both generated native H2 partial-write/reset cases are byte-identical: first p with no END_STREAM, no failed-delivery ACK/success/replay, healthy sibling and single ACK remain. |
| S14 | Finite synchronization | PASS: Existing finite barriers/deadlines are unchanged; observer itself never blocks, retains no owner state or capability and returns :done after correlated output. |
| S15 | Two-protocol count retained | PASS: Two templates across http2 and h2c still generate four tests; no additions, deletions, skip or exclusion changes. |
| S16 | Evidence boundaries | PASS: Prior 110 tests/10 failures stays FAIL; patch remains an unexecuted source-only correction requiring fresh root integration/format/compile/runtime validation. |

## Authentication and executed review checks

- Patch SHA256: `4419cd51e207f727171b7121cf344c0b5aacd5d5474bb76c38db4ded48038aa3`.
- Author Markdown SHA256: `40bc2b12d5879cbd8fcf54bb6b7f8c3ee11b6247da46507e5cd9f09bf4590569`.
- Author JSON SHA256: `3106b7570cec002fc34bd0aa264a053ad72198547856671d00970cdffd473745`.
- Actual predecessor test SHA256: `8b2456198ee065355c0fda89a8e5b610cdac88f1194b70c3ca5975ccedeb638d`.
- Exact in-memory patched test SHA256: `f421db612017b309e1fca9e8fb088c487c841edbd7b77b743f9853f3a5e2dded`.
- Read-only Python unified-patch reconstruction verified every original hunk line,
  expected final bytes, two before/after templates and byte-identical entire
  native partial-DATA template. Exit0; no source writes.
- `sha256sum` independently matched all patch/source hashes above, owner/HTTP/
  accountant hashes in the author receipt, available OTP gen_server source,
  and actual historical gate/log hashes. Exit0.
- OTP `gen_server.erl` at
  `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/lib/erlang/lib/stdlib-7.3.0.1/src/gen_server.erl`
  SHA256 `66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db`
  lines2591-2594 emits `{out, Reply, From, State}` after `reply(From, Reply)`.
  `sys.erl` lines889-898 removes the callback when it returns `done`; therefore
  this observer removes itself after its correlated observation. The on_exit
  removal remains a finite cleanup fallback, and stores no owner state.
- One exploratory rg named nonexistent `reason.ex` and exited2 with the exact
  missing-file error; no such file was required. The actual status mapping was
  read in HTTP.fail/2. This is a source-search result, not a test or build gate.

Historical actual gate receipt remains SHA256
`3dd4dd4d3fc95e2e34908bcc6b243465dbc76c197526560265fa3acdd8516fc0`;
its log remains SHA256
`918574b926afb450d328f4992c877c668864fc25961b7067e47860fce887ffc7`.
110 tests/10 failures remains **FAIL**, not evidence this patch passed runtime.

## Limits, counters and shutdown

Runtime, formatter, compiler, browser and Git: **NOT RUN**. No application actors
were started, signalled, stopped or joined. All this reviewer's commands finished.
Only the two assigned NEW /tmp review reports are written; repository writes0.
Local reviewer repair rounds0; inherited Sol/root counters unchanged and
parent-owned. Astra recovery2/2 exhausted; no escalation or third round requested.
Fresh root format/compile/full required scoped runtime gate remains necessary.
No product decision or external permission needed. Other active root-owned
repair candidates were outside this review.
