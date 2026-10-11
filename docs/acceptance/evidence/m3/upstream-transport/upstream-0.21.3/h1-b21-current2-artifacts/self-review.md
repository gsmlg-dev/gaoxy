# Slice B implementation handoff

Task: `m3_h1_slice_b_fixture_implementation`; direct assignment; CODE READY for
parent formatting, independent code review and actual baseline20. This is a
static implementation handoff, not DONE/runtime/termination acceptance.

Workspace: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`; branch
`codex/m3-gateway`. Original parent baseline:
`b2ac78b518f459ec2c95b7823226640413f2ca95`. Current parent-reported HEAD:
`85c2284a035e0b4ecbf577279eee01142702b5a3`; the parent committed the separately
owned model repair. This worker did not run Git and did not edit model/docs.

Owned implementation files: `managed_h1_accounting_fixture.exs`,
`managed_h1_accounting_fixture_test.exs`, `managed_h1_accounting_peer.py`, under
`integration/http_fetch_contract/`. Audit notes/source inventory are ignored
and confined to this directory. Three source files are quiescent at handoff.

## Evidence and counters

- Parent-confirmed test-first RED: absent fixture raised `Code.LoadError`,
  actual exit1, zero registered tests; original frozen1131 inputs unchanged.
- Reconstructed original RED source SHA256:
  `eac26726b5189b395190283b65c8f92be8befb79652ce26219a36f38ce5c6862`.
  Parent verified its exact match against the tracked original RED manifest.
  Original receipts/snapshots remain preserved.
- Accepted model SHA256, read-only rechecked by this worker:
  `a9a6b96b275735a0744847805f0723c20c256dbfbcad576a458963228609f865`.
  Parent reports fresh model22/0, public preparation/accounting26/0 and strict
  compile PASS. These are parent evidence, not fixture runtime acceptance.
- Slice B Sol repair rounds0; unsuccessful rounds0; Astra0. Separate model
  counters are Sol2/unsuccessful1/Astra0. No escalation gate is asserted.
- This worker ran only synchronous read-only `pwd`, `rg`, `sed`, `cat`, `ls`,
  `sha256sum`, and surgical `apply_patch` mutations within owned scope. Counts:
  exactly20 explicit test names and20 scenario clauses. One public Fetch
  callsite with exactly the approved14 options; one open callsite; two retire
  callsites (ordinary and explicitly gated B17 abort).
- Formatter, syntax/AST parser, VM, Mix, executable tests, network, peer launch,
  dependency operations and Git: NOT RUN by worker. No worker command/process
  remains active. Parent owns canonical formatting and fresh runtime checks.

## Contract review

Runner creates the cleanup ledger before peer/generation/source allocation;
original case t0 is captured after peer ready. Deadlines remain primary15s,
cleanup25s and owned shutdown30s; peer lifetime35s is only its lifetime cap.
Peer operations now carry the appropriate original phase deadline; peer wait
timeout returns a compact error while retaining its actor for cleanup. Cleanup
settles an existing peer command before issuing state/release/stop. Stop sends
remaining shutdown budget to the independent peer's joins.

Generation open/retire/abort issued flags and retirement-wait flags are burned
before invocation. Fetch is checked against original request/connect deadlines
before model launch and has a per-row issued flag plus source-actor guard.
Cleanup uses only unused distinct slots, settles existing originals, preserves
missing-original failures and still attempts unused abort after graceful
failure. Initial and late helper/public outcomes are registered in fixed rows.

Four generation rows,32 attempts/generation and665 actor slots are unchanged.
Per-generation roles use166 slots and peer uses slot664. Controller+ledger+peer
give the approved667 total roles. No respawn, extra polling caller or history
collector was added. Public Promise/completion/scope/retirement receipts are
registered synchronously before awaits/return. Only registered original handles
are used for cleanup. Finite public operation/helper caps remain enforced.

Source/prepared/manifest release uses tail frames before ACK; consumer bodies
use rolling hash/length and one model chunk credit before real ACK. Producer
chunks are capped65536 and a next chunk is not sent before previous result/ACK.
Owned producer shutdown uses its ordinary public-stream link cancellation for
an unattached rejected upload; no private upstream process is touched.

No `control_frontier_released`, private process stop, `System.halt`, numerical
refund or native-frontier proof is emitted. Public cleanup remains distinct
from pending symbolic native controls. Output always retains
`ACCOUNTING_BLOCKED_INPUT` and `native_frontier=unestablished`.

## Frozen-oracle amendments and evidence exports

B09 uses the real model `{:error,:ownership_pending}` result. B11 sends a huge
incomplete chunk size followed by `z\r\n`; public parser
`deps/http_core/lib/http/http1.ex:168` consumes all3 available body bytes before
the real `:closed` error. Its test asserts length3 and SHA256 of those bytes.
Parent accepted and documented these source-backed amendments; specification
review is parent-reported PASS. The original red source remains separately
preserved rather than overwritten.

B13's old challenge nonce/root leave the controller via a tail call carrying
only scalar observations before the launched negative trace.

Every case row includes current run-origin; summary refuses an artifact with
a different origin or ID, so old case files cannot count toward a fresh pass.
After owned joins/root release, the existing controller exports one diagnostic
row at a time to `Bxx-attempt-results.jsonl` (at most128 fixed rows) and
`Bxx-generation-results.jsonl` (at most4 fixed rows). Each encoded line is
limited4096 bytes. This diagnostic copy is a bounded controller workspace,
not a new process/monitor/control/root role. It exports public/late outcomes,
original deadlines, helper join enums, local releases and outstanding proof
observations without opaque handles, source fields, body bytes or bulk targets.
The fixed live coordinator holds actual handles only until existing joins and
local cleanup. This copy role needs independent code-review confirmation.

Loaded identity binds loaded BEAM MD5 to object code/disk origin, exact175
runtime source paths, application cohort0.21.2, interpreter/native origin hashes
and telemetry=false. Before/after identity equality is enforced. This is not
TLS95/numeric ABI evidence.

## Receipt interface and remaining acceptance

Default/no-flags or `--baseline` registers exactly B01-B20. stdout markers:
`H1_ACCOUNTING_FIXTURE_CASE` and `H1_ACCOUNTING_FIXTURE_SUMMARY`. Artifacts:
`run-identity.json`, `run-origin`, `Bxx-result.json`, the bounded per-slot JSONL
files and `summary.json` under this audit directory. Summary requires actual
total20/failures0/skipped0/excluded0/casesPassed20 and current-origin case rows.

B21 is deliberately deferred. Its exact TLS CLI fails closed as
`BLOCKED_TOOLING`, registered0, before ExUnit/peer allocation. Standalone frozen
TLS95 remains unchanged/blocked. Upstream Feature `gsmlg-dev/http_fetch#97` is
parent-owned and not worked around. No production activation is attempted.

Remaining: parent canonical formatter/AST, independent CODE QUALITY review,
fresh actual baseline20, source-before/after freeze and required receipts.
Runtime behavior and final line-size/cleanup outcomes are unverified here.
Any repair assignment must preserve cumulative Slice B counters. No new user
decision is needed for this handoff.
