# Frozen ordinary qualification and read-only diagnosis

Date: 2026-10-29. Source: `main` at
`bc8a5ef5199293ada3b432c2e2741070d3b2d115` plus the uncommitted integration
identified by all 679 `source_hashes` in the command receipts. All five receipt
fingerprint maps are identical and match the current files. Implementation was
not changed during qualification or diagnosis.

## Executed coverage and commands

The task-local `run-qualified.py` records environment, source fingerprints,
command, exit, raw-log hash and process completion. Commands run serially with
`MIX_ENV=test`, `ELIXIR_ERL_OPTIONS='+S 2:2'` and the existing qualified H2/H3
Python peer environment. Full environment values are in each JSON receipt.

| Runner label | Wrapped command | Files | Cases / failures | Exit |
| --- | --- | --- | --- | --- |
| `frozen-candidate-unit` | `python3 scripts/check-repairs.py unit` | 53 | 377 / 0 | 0 |
| `frozen-candidate-component` | `python3 scripts/check-repairs.py component` | 17 | 224 / 3 | 1 |
| `frozen-component-remaining` | `python3 .audit/adaptive-resource-budget/qualify-remaining.py component` | 11 | 66 / 5 | 2 |
| `frozen-candidate-protocol` | `python3 scripts/check-repairs.py protocol` | 15 | 51 / 6 | 1 |
| `frozen-protocol-remaining` | `python3 .audit/adaptive-resource-budget/qualify-remaining.py protocol` | 22 | 98 / 2 | 2 |

For each supplemental suffix, the original invocation was:

```sh
python3 .audit/adaptive-resource-budget/run-qualified.py --timeout 900 frozen-component-remaining -- python3 .audit/adaptive-resource-budget/qualify-remaining.py component
python3 .audit/adaptive-resource-budget/run-qualified.py --timeout 900 frozen-protocol-remaining -- python3 .audit/adaptive-resource-budget/qualify-remaining.py protocol
```

The suffix runner imports the canonical manifest and verifies the attempted
prefix before selecting unattempted files. It executes each file through the
existing `check-tests.py`, requires its exact positive count and retains every
failure. The archived `canonical-check-repairs.py` is an immutable source
snapshot; `scripts/check-repairs.py` remains the sole active manifest.

Combined coverage is unit **377/0**, component **290/8**, protocol **149/8**:
**118 files, 816 cases, 16 failures**, zero exclusions or skips. Original failed
gates remain failed. This does not establish a passing `check-repairs.py all`.
Every command is terminal. [receipt.json](receipt.json) indexes hashes and
results; [failed-files.json](failed-files.json) records all seven failing files
and sixteen test names. All seven test files are unchanged from baseline, whose
exact commands passed in the immutable `../baseline/` logs. The earlier
provisional receipt is preserved as `receipt-before-remainders.json`.

## Diagnosed and unresolved paths

The original nine broader-HTTP failures are six PollBoundary accounting
assertions and three H1 shutdown wire regressions. Prior runtime traces confirm
`:draining` before the erroneous success terminator and both upload HTTP 500
responses. Correct reuse of prepaid completion credit must preserve retained
versus temporary classification and pressure-sample conservation. This run
retains those failures and observes seven more; it does not repair them.

### CORE staged activation: source-confirmed startup ordering

`apps/gaoxy/test/staged_activation_test.exs` executes **11/2**, baseline **11/0**.
The failing assertions at lines 245 and 301 expect late dispatcher startup and
rollback. Read-only independent tracing establishes this chain:

1. `apps/gaoxy/lib/gaoxy/instance.ex:263` cancels activation and drains the budget
   while service preparation is blocked.
2. `apps/gaoxy/lib/gaoxy/service.ex:60` creates Admission after preparation returns.
3. `apps/gaoxy/lib/gaoxy/resource_budget/ledger.ex:329` rejects registration for
   the already-draining instance, so service initialization stops before backend
   and dispatcher startup.
4. `apps/gaoxy/lib/gaoxy/activation.ex:29` propagates this startup error before
   its later cancellation check. The observed result is `{:error, :draining}`
   rather than the asserted `:stopping`.
5. Rollback and participant drain can finish without starting the dispatcher,
   explaining both missing `dispatcher_started` messages.

The source path matches the executed failures; exact registration traces were
not captured. This is separate from completion-credit reuse. Recovery must
preserve late startup/rollback termination, cancellation result, participant
ordering, successful stop, reusable port and Ledger's drain guard. An optional
minimal trace would capture registration result, instance mode and activation
cancellation identity at preparation release.

### Helper finalization: three distinct observations

`apps/gaoxy_test/test/helper_test.exs` executes **16/3**, baseline **16/0**.

- H1 WebSocket closes before the expected close frame. The close-frame path at
  `apps/gaoxy_http/lib/gaoxy/http/websocket.ex:477` requests accounting growth
  before writing, and `resource_budget/ledger.ex:780` rejects growth while
  draining. Callback entry has another drain rejection path. This supports a
  link to completion-credit accounting, but no trace identifies the executed
  rejection branch. Preserve close-frame, acknowledgement and normal-cleanup
  assertions.
- H2 persistent SSE returns `cleanup_deadline_exceeded`.
  `apps/gaoxy_test/lib/gaoxy/test/instance.ex:447` emits that result when the final
  cleanup report has not arrived. H2 drain grows GOAWAY/inflight state while
  retaining fixed temporary credit, but the evidence does not distinguish
  pending leases/proofs from TLS/backend shutdown delay. Future observations
  need gate leases/spawns, connection retirement/output, writer operations and
  runtime shutdown phase before expiry.
- H3 persistent SSE records `session_terminated: :killed`, despite cleanup `:ok`.
  `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex:1013` kills live workers
  through cancellation, stream drop or connection clear. Fixture finalization
  does not wait for persistent sessions before runtime shutdown. The executed
  kill caller and preceding operation state are missing. This symptom is not
  established as the separate native-engine refund P1.

### H3 persistent WebSocket: partial output and timeout

`apps/gaoxy_http3/test/websocket_network_test.exs` executes **2/1**, baseline
**2/0**. The first case passes its quiet-window and ping prerequisites, then
times out after 30 seconds during the first echo-output transfer. It reports
`TRANSFER_PROGRESS 5056787 5242890 5242955`: response bytes, expected response
bytes and client-stream transmitted extent respectively; 186,103 response bytes
are missing. Later 300 KiB
transfers, Close and reuse assertions are not reached in that case.

The test prints progress inside its `TimeoutError` handler, then raises through
`async with connect`. The subsequent `PEER_CLOSED NO_ERROR` can arise from that
context cleanup and does not prove a server-initiated close. The precise output
stall branch requires the worker output cursor/ETS operation, connection
output/pending write/deadline, native operation status/flow credit and accounting
rejection results. The log does not establish its cause or a connection to the
native-refund P1. Preserve transfer sizes, deadlines, flow windows, peer-idle
checks and exact output assertions.

### H2 stream lifetime: unexpected connection close

`apps/gaoxy_http/test/stream_lifetime_h2_test.exs` executes **2/1**, baseline
**2/0**. Its independent peer fails at support-script line 70 during the initial
stream 3 reset and stream 1 survival/progress check beyond 0.8 seconds; `recv`
returns no data. Shutdown, cancellation, reuse and zero-window scenarios have
not yet begun. Admission expiry at `admission.ex:903` kills the affected worker;
the H2 DOWN path at `http2/connection.ex:1386` should reset only that stream.
The executed connection-close branch is unobserved. Neither drain-credit nor
expired-start attribution is established. Minimal future observations are owner
termination reason/close branch, writer result, stream 1/3 lease deadlines and
DOWN reasons, and existing `h2_stream_error` messages. Do not weaken peer reset,
sibling, cancellation, lifetime or bounded-write assertions to accept the close.

Independent diagnosis used no writes, builds, tests or runtime instrumentation.
It also accepted the qualification counts and documentation/plan/receipt
dispositions and verified all seventeen then-indexed artifact hashes. The
coordinator subsequently recorded this diagnosis and verifies the final archive
separately; that integrity check is not another protocol acceptance run.

## Recovery boundary

CORE, H1/H2 and H3 each remain **Sol 2 / Astra 2**, exhausted. The consolidated
request for at most two additional Astra repair/validation rounds per affected
task is pending; no approval follows from a goal continuation. These findings
remain with their existing tasks and do not reset counters. No affected
implementation or test source was edited. No new commit, version bump, push,
publication or deployment followed this qualification. Final integration,
independent acceptance and exact-source release gates remain outstanding.
