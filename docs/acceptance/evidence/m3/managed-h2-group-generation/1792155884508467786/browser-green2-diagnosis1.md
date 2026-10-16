# Browser-green2 bounded diagnosis 1

Task: gaoxy-group-generation-browser-green2-diagnosis1. **DONE — diagnosis only.** Direct independent assignment. Exact early-return cause remains **UNKNOWN**; browser-green2 remains **FAIL**.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
Branch: `codex/m3-h1-resource-foundation`
Baseline: `8131af39a846c292a022ccbfd32c53376cd57887`

## Finding

The fresh native worker reached the real checked Generation capture on the reused H2 connection, then `GroupEndpoint.call` returned before the required fresh custody/bound observations. Host2 discards the actual return as `_original_result`, so the evidence cannot identify the original early-return reason. This is a confirmed observation gap, not a confirmed production defect.

Host log lines5–12 establish old worker `<0.390.0>`, successful old custody/bound/source retention/retirement/cleanup, and fresh worker `<0.408.0>`. Both captures have connection `<0.388.0>` and writer `<0.389.0>`. Old request_clean reports the exact genuine baseline: T1 record/2 weighted holds, G1 record; native/Session joined and connection alive. Line13 is MatchError false; line14 identifies host2:1506.

Runner2:546–553 sends dispatch then waits for new_a peer GET. It cannot issue prove_bound at572 until that GET/custody arrives; no GET arrives. The only setter of active.bound is prove_bound, so bound is still nil at the returned assertion. That explains the host failure. It does not explain why GroupEndpoint returned.

New_a/new_b peer logs each contain only the genuine health HEAD /health, then connection_reset. No fresh GET or fresh derived custody is recorded. Missing custody does **not** prove no Session was started.

The bounded sanitized Chrome projection confirms session55/socket54 reuse: old stream1, new SEND_HEADERS stream3 at11654782724, RECV_HEADERS FIN stream3 at11654782729, then session close at11654782751. It omits numeric response headers and reports read_complete=false/PROJECTED. Browser log reports ERR_HTTP_RESPONSE_CODE_FAILURE. Raw NetLogs were not read.

Qualification reports FAIL, executed1, h2-h2c only, source_stable=true, elapsed37486ms. The runner first encounters queue.Empty, then failure cleanup raises “owned browser/host/peer shutdown failed or required forcing”. Browser/host exits are1; four peers exit-15 with forced=true. All six recorded Actor readers and owned groups joined/gone. Seven adopted children were joined (one exit-10, six exit0), adopted_remaining=[]; cleanup_errors=[] does not turn forced cleanup into a graceful PASS.

## Actual source path and remaining candidates

| Boundary | Source | Implication |
|---|---|---|
| Native per-stream Exchange | http2/connection.ex:1191–1225; http2/stream.ex:14–65 | New worker receives fresh stream Exchange; same connection is reused. |
| Generation | generation.ex:133–166,308–340,445–456 | Checked acquisition/router already passed at capture. Original source pins release after Captured returns, beyond its return barrier. |
| Captured wrapper / host | host2:330–365,1241–1415,1425–1506 | Wrapper sends actual result unchanged; host ignores it before asserting bound. |
| Resource validation | group_endpoint.ex:27–46 | captured_resources rejection can return unavailable before any Session. |
| Request/startup | http.ex:352–454,567–758 | Header/target/method, Admission startup allowance, neutral/source/startup accounting, Session init/monitor, cleanup attachment and refund can reject before custody. |
| Service activation | service.ex:99–127 | Attachment can reject mode/gate/Admission; success sends actual cleanup activation. |
| Session before delegation | http/session.ex:26–96,141–160,1443–1537 | State/activation/group checkout/selection/timing/handoff preparation can fail before any derived T pin. Session existence remains unknown. |
| Pump/delegation/response | http.ex:940–995,1180–1220 | Delegation denial, polling, Session DOWN and timeout can also return before bound. |
| Loss of reason/status | framed_response.ex:5–16 | Successful empty error response returns ok Exchange with response=:sent; Exchange retains neither numeric status nor internal rejection reason. |

All sources above are under apps/gaoxy_http/lib/gaoxy/http, apps/gaoxy_proxy/lib/gaoxy/proxy or apps/gaoxy/lib/gaoxy. Candidate families are supported branches, not diagnosed causes. No evidence selects a particular startup/accounting/dependency defect. Fresh-connection socket91/0 evidence cannot settle this reused-connection path.

The existing seven-line http.ex normalization diff was inspected and preserved: it normalizes only the transport error passed to accounting; no production edit is proposed here.

## Smallest versioned observation proposal

In a new versioned copy of host2, bind `original_result` in the existing returned clause. Immediately after `a = active!(s,label)`, emit one `returned_observed_v1` event **before the unchanged native/ref/bound/returned assertion**. The raw result is already in the host mailbox: no new worker message, tracing, process, delay, retry, constructor or production change is needed.

Record schema1, label, native PID, capture ref, native_matches, token_matches, dispatched, bound_present, session_present, returned_before and phase pre_bound/bound. Pattern-match known ok/error Exchange tuples to record result tag/arity, Exchange presence, known response mode and close boolean. For error tuples, project the original reason separately from the existing finite_reason normalization.

Projection must be bounded: at most depth3/15 nodes, tuples at most4 elements, atom names at most128 bytes and bounded integers; arbitrary binary/map/list/oversize content becomes type-only with explicit elision. Unknown result shapes receive only type/tuple arity. Cap the emitted event at4096 bytes. Never inspect or serialize the entire result/Exchange, headers, body buffers, certificate or private state; never traverse an arbitrary whole term for external_size.

**Do not claim a numeric status from response=:sent.** Record status=null/status_source=not_retained unless a bounded request_error tuple actually carries it. `{:ok, Exchange(response=:sent,close:true)}` can represent an empty rejection response and exposes no internal reason. If that is the observation, retain UNKNOWN; a separately reviewed bounded observation of the actual response-head status or failing startup transition is the next conditional step. The minimum result observer alone cannot recover information already erased by HTTP.error_response.

If the returned summary plus bounded genuine owner/group/Admission/deadline census remains insufficient, observe a targeted public ManagedH2GroupAccounting.validate/2, startup/2 or preflight_control/2 boundary in the exact native worker (and actual identified Session only if needed). Emit constant finite boundary/selector labels and bounded return verdicts; suppress all raw call/startup arguments and Exchange content. Preserve the actual return, correlate actual PID/capture, and independently review any such instrumentation before execution. A genuine numeric response-head status is a separate scalar observation. Census and boundary outputs do not replace custody/bound acceptance.

Keep the Captured wrapper, actual GroupEndpoint result, dispatch/return barriers, all bound/peer/Actor/cleanup/source-lifetime assertions, exact baseline, deadlines/caps/lifetimes and all failure receipts unchanged. Preserve host2/browser-green2; root owns new version/path/runner binding and any runtime rerun. Diagnostic events are not custody, bound, peer or cleanup receipts.

## Verification and limits

- Before/after digest check: **97 files unchanged** (90 product libs and7 host/runner/sanitized evidence files).
- All90 product lib digests match original qualification source_before. Seven observed sanitized artifact digests match qualification artifact_sha256.
- Product http.ex SHA256: `76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98`.
- Host2 SHA256: `1b017c4da8014868c3b0402f19c6f215f7cc600cbd374cd8fbba5adce8fc969e`.
- Runner2 SHA256: `c16d52dc8c3687a771af511b0c04e6a05211ef9859df414ce0a8db15036a8f2e`.
- Qualification SHA256: `bf3e2fc46b3338769b32175ea08814177511ae040dc0d121f867188933318dbd`.
- Scoped source/metadata parsing and digest commands completed, exit0. Two guessed source names were absent (stream_worker.ex and proxy/headers.ex), then resolved through rg --files to http2/stream.ex and http/headers.ex; no runtime validation was inferred.
- Tests executed **0**. Tests/Mix/build/network/Git writes/browser/process actions **NOT RUN** by assignment.
- No repository changes; only these two assigned /tmp reports were created. Concurrent root-owned changes and the excluded new group test were preserved. No raw NetLogs/private keys/forbidden raw terminal trace were read.
- Every own command completed synchronously; no own running command/session remains. Historical failures/forced cleanup remain visible.

Counters retained: group failedGREEN50/root92/orchestration26; stage failedGREEN5/production1/fixture5/orchestration19. Own Sol repair rounds0; Astra2/2 exhausted, no escalation gate and no reset. Collector ready-reap review belongs to another reviewer and was not expanded into.

No product decision or new external permission is needed for this observational proposal. It is **not implemented or runtime-validated**. No stage/production acceptance PASS is claimed. Full source/evidence manifests and structured distinctions are in the companion JSON.

