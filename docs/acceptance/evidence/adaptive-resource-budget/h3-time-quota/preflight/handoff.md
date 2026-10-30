# ARB-H3-PREFLIGHT — bounded recovery handoff

DONE for read-only diagnosis/handoff. This is not ARB-H3 acceptance. Repository
`/home/gao/Workspace/gsmlg-opt/gaoxy`, current main at supplied baseline
`bc8a5ef5199293ada3b432c2e2741070d3b2d115` plus concurrent dirty integration.
No Git commands, builds/tests, network requests or source changes were performed.
Only this preflight directory was written. All commands are terminal.

Counters remain H3 Sol2/Astra2, CORE Sol2/Astra6, Phoenix Sol1/Astra0;
preflight consumes no repair rounds. The twelve-hour authorization ends
2026-10-30T02:09:44Z. One Astra and shared build lane stay serialized. H1H2 owns
next source/build work; parent must explicitly transfer the lane and any CORE
extension ownership before recovery edits.

## Established native-lifetime P1 and causal order

The independent review in `h3/recovery1/receipt.json:independent_review` is a
source-level P1, not a runtime reproduction. Its former numeric-budget stop is
superseded by current AGENTS time authorization; its evidence/counters remain.

1. `apps/gaoxy/lib/gaoxy/quic_bridge.ex:15` obtains metadata with five native
   byte metrics, acquires a callback-owned `:connection` lease with connection
   membership (`:19`), begins the callback (`:26`), then retains application
   `external_size` plus native bytes on that same lease (`:149`). No cleanup
   attachment exists. The native components are queued/ready/receive-buffered/
   I/O-queue/operation-result bytes, not packet counts or crypto cursors.
2. Native storage belongs to the independent engine (`deps/elixir_quic/lib/quic/
   connection.ex:1120`); callback death does not synchronously destroy it.
3. Admission observes callback owner DOWN/EXIT and `settle_lease` currently
   releases its allocation (`apps/gaoxy/lib/gaoxy/admission.ex:1382`, `:1392`).
   It does not wait for native termination. That allocation also holds the
   connection quota membership, so the early refund affects bytes **and quota**.
4. Engine consumption of its separate consumer-DOWN message occurs later
   (`deps/elixir_quic/lib/quic/connection.ex:641`). No causal ordering forces that
   ahead of Admission's terminal pair. Thus a schedule exists with native
   resources alive after their charge/quota refund. This establishes the local
   ownership defect; it does not establish an upstream missing API.

`QUICBridge.terminate/2:83` is best effort, remains on the callback owner and
cannot repair kill/forced-shutdown ordering. Abyss explicitly documents that
closed events and terminate may be skipped (`deps/abyss/lib/abyss/quic/handler.ex:10`).

## Supported public terminal proof

`Gaoxy.QUIC.info/1:26` delegates through `Abyss.QUIC.info/1:55` to public
`Quic.info/1:109`. The engine's generation-validated info handler permits an
observer other than the attached consumer (`connection.ex:289`); the observer
must retain the opaque handle, not extract/monitor its private engine PID.

- Exact `{:error, :closed}` maps `noproc`/normal call exit in public
  `safe_call/3:117`. This is usable terminal proof on the original handle.
- `{:ok, metadata}` means native ownership is still inspectable; preserve it.
  `{:error, :timeout}`, missing/malformed metrics, `{:error, {:closed, reason}}`
  and unavailable results must not be broadly equated with that exact proof.
- `close` returning `:ok` only admits a transition into `:closing`
  (`connection.ex:1300`); operation acceptance is not engine termination.
- Engine terminate sends `{:quic_closed, handle, reason}` from its terminate
  callback (`:1347`). Abyss may forward this as `{:closed, reason}` to the
  consumer (`deps/abyss/lib/abyss/quic/service.ex:504`). A killed callback misses
  it. For the new independent cleanup observer, use the exact public info proof;
  do not manufacture a terminal receipt from callback death, failed inspection,
  elapsed time or an accepted close request.
- Public info has a fixed5s call timeout (`connection.ex:54`). Run its observation
  outside Admission/Service critical handlers, with finite overall lifecycle
  bounds. An outer deadline does not magically shorten that call. On timeout or
  unknown termination retain/fence the obligation and report cleanup failure;
  do not free it. Do not reopen the previously withdrawn callback-deadline issue:
  Abyss already watchdogs the whole init/callback batch (`service.ex:446`, `:547`).

## Existing composition and precise CORE dependency

Reuse the existing authenticated Service/Admission cleanup protocol, not a new
global manager or private dependency process:

| Existing seam | Contract to preserve |
| --- | --- |
| `Gaoxy.Service.attach_cleanup/6`, service.ex:8/:226 | Caller is actual lease owner; Service authenticates gate/generation and registers guardian before sending activation token |
| `Admission.attach_cleanup/7`, admission.ex:599 | Only registered Service may attach; exact owner/lease, live distinct guardian, one attachment, finite matching deadline, byte checks and canonical Budget reserve |
| `{:gaoxy_cleanup_activate, token}`, service.ex:252 | Guardian remains inert until authenticated attachment committed; activation is not terminal proof |
| `{:gaoxy_cleanup_cancel, token, reason, deadline}`, service.ex:816 | Cancellation initiates bounded cleanup, not successful completion; retain original cleanup token/deadline |
| `Service.complete_cleanup/2`, service.ex:264 | Only registered guardian may submit receipt; only Service may mark canonical cleanup complete |
| Service receipt + guardian normal DOWN, service.ex:671; Admission:1441 | Both needed before cleanup refund; missing receipt/abnormal DOWN fails closed |
| Service terminate receipt loop, service.ex:824 | Complete pending authenticated handshakes while terminating; no deadlock waiting for Service death |
| ResourceBudget transfer/replace/repartition, resource_budget.ex:64 | Existing revision/operation/generation fenced mutation mechanism; preserve same ownership accounting, bounded retries and canonical receipts |

Actual production examples: Proxy.HTTP starts a supervised Session, then attaches
and only activates it after registration (`apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:647`).
Its Session captures the original token (`http/session.ex:141`) and submits the
receipt after client cleanup (`:1759`). Proxy.WebSocket independently waits for
the public client socket terminal barrier (`websocket/session.ex:197`). These
are composition examples, not permission to depend on the proxy from core.

**This is not a drop-in call for QUIC's present connection lease.**
`Admission.attach_cleanup` rejects unless `lease.request_active && lease.drain_notify`
(`admission.ex:611`), requires exact current lease deadline (`:617`), and adds a
separate fixed scalar byte reservation (`:632`–`:665`). QUIC acquire omits
drain_notify; acquire initializes request_active=false (`:1196`), and
begin_callback does not activate a request (`:587`). Bridge retention then clears
the callback deadline via end_request (`:381`). No current Service/Admission
facade atomically transfers/resizes a **connection** native obligation into this
cleanup record. Authority-level transfer exists, but directly calling it while
bypassing Admission's receipt/sequence state would desynchronize accounting.

Minimal requirements for a later bounded **CORE extension**, owned/serialized by
the parent with existing Astra CORE/H3 recovery:

- Typed connection-cleanup eligibility authenticates actual Service, connection
  lease owner/generation, original opaque handle identity and live guardian.
  Do not call begin_request or forge request_active to bypass request guards.
- Register before native ownership can outlive callback state, including init
  rollback, handler failure, watchdog kill and service drain. A partially
  registered/ambiguous attachment must remain charged or fenced, not disappear.
- Separate measured native bytes from application callback state. Atomically
  preserve/transfer the existing native charge and actual connection membership
  without duplicate charge, a gap, fake ordinary-request membership, or another
  connection quota slot. Native growth/shrink needs admitted bounded updates;
  existing attach's fixed byte reservation is insufficient by itself. Do not
  substitute a full worst-case native buffer reservation for measured usage.
- Callback DOWN/EXIT may end callback state, but **cannot** refund native bytes
  or connection quota. The connection stays accounted until exact engine proof,
  authenticated cleanup completion and guardian terminal requirements converge.
  Guardian itself adds no ordinary-request/connection quota membership.
- Preserve canonical operation IDs, revisions, gate/service generations,
  finite deadlines, dedup/reconciliation, safety/process guards and legacy scalar
  behavior. Do not relax attach_cleanup's existing request authentication.
- Persist enough public cleanup ownership after owner loss: handle identity,
  lease/allocation identity and revision, native measured bytes, activation token,
  callback terminal flags, native proof state, guardian identity, original
  deadline/cancellation, and canonical pending operation/receipt. These are field
  requirements, not a new global subsystem or prescribed storage redesign.
- Service stop/remove/termination must include the new obligation in pending
  accounting/failure reporting; unknown proof remains unconfirmed. CORE tests
  must cover auth, duplicate/stale tokens, deadline/guardian loss, reordered
  native proof vs callback terminal pair and registration rollback.

Do not modify accepted memory/owner/config behavior. No upstream issue or deps
patch is justified: the exact public terminal proof already exists. Any newly
confirmed covered-org dependency blocker must follow upstream routing and stop
the affected slice, not add a local bypass.

## Minimal deterministic RED and finite validation proposal

Nothing below was executed or implemented in this preflight.

Start with one controlled component regression extending the existing
QUIC-context/canonical budget fixture (`quic_context_test.exs:12`,
`resource_budget_h3_test.exs:23`). It must drive the real QUICBridge path with
five nonzero native metrics, a real authenticated Service/Admission composition,
and explicit callback/native-proof barriers:

1. Initialize Bridge and record positive public native charge and one connection,
   zero requests/streams. Signal callback-start/attachment barriers.
2. Confirm callback terminal pair while public native proof is deliberately
   unavailable/not closed. Assert native charge/connection membership remain and
   cleanup is pending; current source refunds these, so this is the expected RED.
3. Release only the controlled exact native-closed proof; require authenticated
   guardian receipt plus normal DOWN, then exact zero bytes/connections/requests/
   streams/leases/cleanup_pending and cleanup_failed=nil.
4. Reverse proof/owner-terminal ordering; assert convergence without duplicates.
   Add timeout/malformed/accepted-close negative cases only as needed to cover
   the implemented boundary; they retain/fence and cannot pass as zero cleanup.

Use controlled doubles at the public observer/receipt boundary; do not fake a
real engine PID, expand an opaque handle, suspend/inspect engine processes or
add a production backend selector merely for testing. Existing opaque metadata
fixture alone can prove **missing terminal proof retention**, but cannot prove
actual native engine death; label it honestly. Later actual QUIC network evidence
must separately verify public info becomes exact closed. If introducing the
controlled observer requires a small pure seam, keep it local to the new CORE
cleanup implementation and review it; no dependency patch or new package.

`cleanup_attachment_test.exs` supplies reference cases but is explicitly retained
unscheduled (`scripts/test-inventory.json:14`); do not automatically promote or
run its historical breadth. Put the bounded new cases in an existing active
component file and have parent measure/update only the canonical count.

After parent returns ownership/lane, proposed finite command sequence:

```sh
timeout 120s env ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test python3 scripts/check-tests.py apps/gaoxy/test/quic_context_test.exs apps/gaoxy_http3/test/resource_budget_h3_test.exs --seed 0 --max-cases 1
timeout 120s env ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test GAOXY_QUIC_PYTHON=/home/gao/Workspace/gsmlg-opt/gaoxy/.audit/h2peer/bin/python python3 scripts/check-tests.py apps/gaoxy_http3/test/resource_budget_network_test.exs --seed 0 --max-cases 1
timeout 120s env ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test GAOXY_QUIC_PYTHON=/home/gao/Workspace/gsmlg-opt/gaoxy/.audit/h2peer/bin/python python3 scripts/check-tests.py apps/gaoxy_http3/test/websocket_network_test.exs --seed 0 --max-cases 1
timeout 120s env ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test GAOXY_QUIC_PYTHON=/home/gao/Workspace/gsmlg-opt/gaoxy/.audit/h2peer/bin/python python3 scripts/check-tests.py apps/gaoxy_test/test/helper_test.exs --seed 0 --max-cases 1
```

Current expected counts before new cases:9,2,2,16. Timeout is a failure, never a
skip. After focused repair/review, rerun the existing18-file combined H3 command
recorded verbatim in `h3/recovery1/receipt.json:verification[0].command` (historical
96/0: CORE2+H3 94), plus strict compile/owned format and parent inventory/final
integrated gates. Measure new exact counts. No repeated full-suite loop while
focused cases are failing; all commands remain serialized.

## Helper/WebSocket failures: facts and next diagnostics

Historical passing H3 recovery96/0 does not erase later frozen failures:

- `qualification/frozen-candidate-component.log:338`: helper HTTP3 persistent
  SSE failed `Gaoxy.Test.close(fixture)` with cleanup=:ok but
  `session_terminated(reason: :killed)`, after initial/later SSE events had
  completed. Whole helper file16/3 also includes distinct HTTP2 cleanup timeout
  and TCP WebSocket close-frame failure; do not label all three as H3.
- Helper sends explicit session cancellation before drain (`instance.ex:483`),
  SSE's cancellation branch emits session_cancelled and returns (`sse.ex:113`).
  Its monitor treats killed session as failure (`instance.ex:391`). H3's
  stop_endpoint unconditionally kills a live request worker (`connection.ex:1009`),
  including clear/terminate paths (`:1475`). This is a relevant causal seam,
  **not proof which path killed the recorded worker**. Next run needs ordered
  cancellation-received / final response / worker-terminal / parent-clear
  observations with finite barriers. Do not swallow killed outcomes or change
  the existing helper assertions. CORE parent proof/deadline semantics may affect
  this; first qualify current CORE6, then reproduce on the integrated source.
- `qualification/frozen-protocol-remaining.log:113`: persistent H3 WebSocket file
  2/1, peer's30s first large-transfer wait timed out at5,056,787 of5,242,890 echoed
  bytes; peer had sent through stream offset5,242,955. `PEER_CLOSED NO_ERROR`
  appears **after** TRANSFER_PROGRESS while context unwinds; it does not establish
  server closure as timeout cause. Keep original5MiB +300KiB +300KiB transfers,
  small receive windows, idle/keepalive assertions, all deadlines and exact bytes.
- For that ordinary compatibility regression, capture public QUIC five native
  counters/operation outcomes, public HTTP3 queue telemetry and budget snapshots
  around last progress. Access a handle only at its supported callback boundary;
  otherwise add bounded Gaoxy-side diagnostic telemetry under assigned ownership,
  never extract a private engine/worker PID from listener state. Follow current receive-credit, pending write, flush,
  WebSocket transport-operation and keepalive paths (`connection.ex:363`, `:1101`,
  `:169`). Verify each output/native obligation is accounted once. Do not raise
  buffers/budgets, shrink payloads, lengthen deadlines or infer a buffer/idle/
  admission defect from progress alone. Root cause remains unknown.

Current H3 spawn path uses legacy `Admission.spawn_request/7` (`connection.ex:633`)
and maintains aliases with wait_response (`:660`). CORE now offers optional
attempt-bound `:phase_receipt` at Admission:21; H1H2 recovery is consuming that
contract. H3's rejected+stale-cancel absence inference (`connection.ex:1375`) is
an affected compatibility seam: review it against the new exact reservation
phase proof, preserving live aliases, original operations/deadlines, immediate
Operations row revocation and independent pending native cleanup. Do not treat
ordinary spawn rejection/cancel acknowledgement as native terminal proof. This
is a source-migration check, not a diagnosed cause of the three failed runs.

## Mixed actual Phoenix startup: unknown cause, concrete boundary

`phoenix/time-quota/focused-failure-receipt.json` records3/1, original2 pass.
Config uses one actual Endpoint/ListenerSet, loopback ephemeral HTTP/HTTPS/H3,
generated CA/cert/key and adaptive defaults. Adapter supports exactly those
options. Ready roles/transports/public nonzero bound-port assertions passed.
Python completed verified H2 SETTINGS and h3 ALPN before close0x1 while waiting
for H3 SETTINGS. All requests follow that barrier; missing `/http` worker is a
consequence, not an H1 dispatch diagnosis.

Public startup sequence is Abyss attach→info→handler.init (`service.ex:445`),
Bridge native charge→handler state, H3 ready metadata validation
(`connection.ex:53`), control-open/write operations (`:245`, `:286`), then peer
SETTINGS. Current raw log has no worker stop reason or admission reason. Cause
cannot be called consumer_down, budget rejection, protocol defect or upstream
failure from close0x1 alone.

First diagnostic change, only after parent lifts example-source freeze: retain
all aioquic ConnectionTerminated fields (error_code/frame_type/reason_phrase)
using the same public event override already in WebSocketNetworkTest:70; make
Elixir's bounded worker barrier consume peer stdout/early exit immediately and
include public ListenerSet listener info, Gaoxy.status and resource_budget.
Attach existing `[:gaoxy, :admission_rejected]` telemetry with scope/reason
(`admission.ex:1498`) and H3 queue telemetry (`connection.ex:1092`) for this fixture.
Use observed reasons to choose the next production branch. If those do not
expose the callback stop reason, a later narrowly scoped Gaoxy diagnostic event
around the existing bridge init/error/terminate result is preferable to deps
patches or private worker discovery; parent must assign/review that source scope.
Do not alter configuration or send requests before SETTINGS to mask startup.

Focused proposal once source/lane explicitly returns:

```sh
python3 .audit/adaptive-resource-budget/run-qualified.py --cwd examples/phoenix_native --env PHOENIX_NATIVE_H3=1 phoenix-mixed-after-h3-recovery -- python3 ../../scripts/check-tests.py test/resource_budget_test.exs --seed 0 --max-cases 1
```

Run-qualified options precede its label (REMAINDER parsing). Retain existing
finite peer/test deadlines and source fingerprints. The fixture belongs to the
Phoenix owner; H3 recovery may request diagnostic edits, not overwrite it.

## Ownership and completion boundary

H3 writer scope remains QUICBridge, current H3 Connection/Operations/Stream and
their bounded component/network tests. Any typed native cleanup extension
necessarily touches CORE Admission/Service/Budget integration and needs an
explicit serialized parent assignment **after H1H2 relinquishes the lane**.
Manifest/docs/evidence integration and final review remain parent-owned. Do not
edit accepted owner/memory modules or proxy clients unless a concrete necessary
compatibility dependency is separately assigned. No branch/worktree, deps patch,
network issue filing, publication/deployment or operational changes here.

Required outcome: native bytes and actual connection quota survive callback
termination until exact public engine proof; request/stream memberships retain
their independent semantics; H3 helper/WebSocket and mixed Phoenix pass with
unchanged assertions, fresh positive counts, independent review and zero cleanup.
Unknown causes and unexecuted native-lifetime runtime reproduction remain open.
