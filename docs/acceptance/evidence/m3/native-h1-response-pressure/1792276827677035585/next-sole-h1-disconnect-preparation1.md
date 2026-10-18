# Sole native-H1 disconnect preparation1

Status: DONE (read-only preparation). Runtime: NOT RUN. Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.

Parent-supplied predecessor: `fb7d0fda2b7c16c42c65579736dc1f643e17d812`. No Git command or dirty-state validation was permitted.

The source supports a Gaoxy-owned synchronous ownership gap: native H1 `read_upload` cannot poll downstream while its public `Stream.chunk/3` write is blocked. This is a hypothesis requiring reproduction; no dependency defect is established. The smallest recommended next slice is one fixed/h2c upstream with one passive TCP native-H1 client and no siblings.

## Source evidence

- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:790-896`: pump_wait and progress poll events/socket; read_upload calls write_body synchronously and only pumps/finalizes after return. @poll_ms=5. write timeout is min(config.write_timeout, remaining original deadline).
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:142-159`: write_body bounds chunk to 65536 bytes, copies it, and calls public HTTP.Stream.chunk/3 synchronously.
- `apps/gaoxy_http/lib/gaoxy/http/exchange.ex:131-183`: poll_connection owns byte-preserving Socket.recv(1), retained-buffer accounting, buffer cap and original deadline. A competing socket watcher would need new byte ownership/transfer machinery.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:46-56,101,287-310,744-748,1346-1409`: Session monitors original owner/service/instance/gate; cast cancel marks cancelled. settle uses original_request on managed paths, calls client.cleanup and retains pending cleanup. Cleanup deadline is original deadline+1000ms, optionally capped by authenticated requested deadline.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:58-86`: cleanup reaches original public RequestCompletion; cancellation calls RequestCompletion.abort_and_await(completion,0), preserving pending/unconfirmed status.
- `deps/http_fetch/lib/http/stream.ex:109-140; deps/http_fetch/lib/http/request_completion.ex:76-105`: Public chunk is synchronous with finite timeout. Public abort_and_await cancels original request and waits for cleanup. Raw :abort/:deadline messages and @doc false Stream.stop are not proposed public cancellation APIs.
- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py:327-343`: Unchanged independent peer emits upload_credit_held only after exactly one received upload byte, stream window0, positive connection window and no END_STREAM; holds credit without automatic acknowledgment.
- `apps/gaoxy_proxy/test/support/managed_h2_fixed_fixture.exs:10-34,326-359,552-582; apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs:14,271,285-323`: Unchanged helpers can launch peer with explicit options, send native H1 headers/body, capture original guardian/completion from Gaoxy-owned state and verify resource baselines. Existing hold helper sends GET, so reproduction must send POST directly.

## Proposed reproduction

Before execution, fix total/idle/write budgets with ample remaining write/total time at the close barrier. Proposed disconnect observation 1000ms, write_timeout 5000ms, total_timeout at least 20000ms; these are proposed test budgets, not measured behavior or an existing latency guarantee. Require observation boundary strictly before both captured write-expiry and original total-expiry. Preserve original cleanup deadline, with no deadline extension.

1. Start only the original fixed managed-H2 resource and unchanged independent peer with --manual --hold-upload-credit. Capture baseline Service/token/helper/pin/selection/resource counts.
2. Connect one passive TCP H1 client; send POST /hold/upload-credit with an explicit finite Content-Length. Capture original native owner, guardian, request token, public RequestCompletion identity and resource pins from Gaoxy-owned observations.
3. Supply bounded upload bytes, starting with one byte and at most one additional byte for the first candidate. Require upstream upload_credit_held receipt with exact byte1/window0/positive connection credit. Minimum payload needed for a persistently blocked chunk is not established by the public API; do not claim two bytes is sufficient until the block barrier succeeds.
4. Require a finite Process.info barrier on the original Gaoxy native owner: waiting with HTTP.Stream.chunk/3 visible in the read_upload/write_body call path. If the block barrier is not reached, record PRECONDITION NOT MET; design a bounded payload increase based on fresh evidence rather than claiming a disconnect failure.
5. Close the sole original downstream socket. Do not release upload credit, issue upstream response, add a sibling, inject drain/cancel/deadline messages, restart resources or use a substitute request.
6. Within the predeclared observation window, require cancellation evidence attributable to that downstream close, tied to the original token/completion and independent peer reset/end receipt. A cancellation first observed at write/idle/total timeout does not pass the prompt-disconnect oracle.
7. Under original finite cleanup budgets, require original public completion success, guardian/helper/native owner joins, original token release, exact Service/Admission/transport/group pin conservation, no unexpected retained bytes, and normal peer/process joins. Preserve cleanup_pending/unconfirmed as failures or blocked observations, never cleanup success.

A helper repair must replace the baseline native-owner blocked-stack precondition with an identity-bound one-pending-write helper stack plus the live original native owner polling; otherwise the regression would incorrectly require the old synchronous implementation.

Only after real red reproduction, targeted repair, fresh verification and independent receipt review: fixed/group x h2c/TLS-H2. Keep native-H1 response-pressure work separate.

## Bounded repair candidate

Use one Gaoxy-owned monitored helper for exactly one public upload write. Leave socket polling, drain/deadline handling and original Session cancellation in the native H1 owner.

- Retain exactly one pending upload write with an identity/ref, original write deadline, helper PID/monitor and terminal-body marker. Do not read or enqueue another body chunk while pending; do not retry or resubmit a timed-out/cancelled chunk.
- Keep Exchange.poll_connection on its original socket owner and preserve all received bytes, Admission accounting and maximum buffer enforcement while pending. Avoid an independent socket reader.
- Use existing client.write_body/3 and original Session.cancel authority. Do not send raw messages to dependency internals, patch deps, access private fetch processes or manufacture completion receipts.
- Reserve/charge all helper state, copied binaries, pending result/control envelopes and process budget before spawn; bound logical and backing bytes. Integrate with the applicable fixed/group accounting and native Admission reservation instead of hiding an extra worker outside existing conservation.
- Monitor parent/helper in both directions, bind results to the one current ref, handle result/DOWN ordering, finite deadline/drain races and normal/abnormal owner exits. Ensure original cancellation wakes/settles the public chunk or join/terminate the owned helper finitely; helper death alone never proves original upstream cleanup.
- Do not finish upload before successful pending-write acknowledgment. Preserve existing early-final-response handling (upload_stopped, close, valid response-head delivery) and error classification.
- Keep original deadlines; no fresh write budget on each polling turn and no extra per-stage wait beyond prescribed cleanup. Finalize only after helper and original completion cleanup are both joined.

## Remaining uncertainties

- No runtime reproducer, failing test, dependency defect or prompt-cancel latency is established in this assignment.
- Exact minimum payload/chunk sequence required for the public chunk receive to remain blocked under initial-window1 needs the prescribed runtime precondition; a held-credit receipt alone is insufficient.
- TCP FIN is observed after queued bytes. The reproduction must minimize outstanding upload bytes and preserve/measure them; do not introduce a large unread payload whose drain or buffer-limit path masks the close scenario.
- Exact helper reservation amount/control envelope shape and integration with fixed/group/native ledgers require a scoped implementation design and independent review; no public interface or architecture redesign is authorized by this report.
- Stream.start_link upload is originally linked to the Session that opened it. Future helper is only a producer; preserve that original ownership and RequestCompletion identity.
- Proposed 1000ms close-response oracle needs review before execution; source proves a 5ms polling cadence, not a hard scheduler latency guarantee. Deadline-only cleanup must remain distinguishable.
- Current branch/dirty state and source-to-predecessor Git equivalence were not revalidated because Git was explicitly prohibited.

## Exact source pins

- `dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31` `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`
- `8a041a6bc217ef5ec626dc9e4efc2ec495db3a668912214420ad01bd4d449eac` `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`
- `e8c60d1d5a67f3b9737478149ac6e28b8e9ddf778289a2fac6035054379e7313` `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex`
- `b0fc774be009a2fea62ceee3a7fd7e8a35be7096ebaa249713678c9a1bdfe6c9` `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex`
- `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0` `apps/gaoxy_http/lib/gaoxy/http/exchange.ex`
- `c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947` `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`
- `b1c1d7ce20fcd69fbf37f1f805b6f25fe24d7986a897be72f6f4ec73b959e9f5` `apps/gaoxy_proxy/test/support/managed_h2_fixed_fixture.exs`
- `9009d7ba27b184d9c8ce0743e40cb610dd20e22b4828abe34fbd299d16f74a42` `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs`
- `d4429aa3fe49b9faca2c05bef631ef97cf6ca4f6fe69d350dea71bd147a367f0` `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`
- `3e9821a577d5aabe77a13194eb81f3e9859c64a45f0ab766c186ee844e03866e` `deps/http_fetch/mix.exs`
- `d67a6ba36851dc255376ba93131e84dd003c9da2497fc0bb6e7d6c721c4be77b` `deps/http_fetch/lib/http/stream.ex`
- `157a371b838a2f72117a7e92f97d2f602a0363cc228411c77c1e22ba7865237c` `deps/http_fetch/lib/http/request_completion.ex`

## Verification and handoff

Targeted source inspection and artifact validation PASS. Runtime, tests, browser, Git and upstream issue work NOT RUN as required. No repository files changed. Source hashes were rechecked after report construction.

Inherited counters: H2 source Sol1; H1 Sol4; Astra2/2 exhausted. This preparation adds zero implementation/runtime repair rounds. New tooling incidents:2, retained exactly as recorded in the inherited summary; no additional clipping incident occurred during this continuation.

Return repository/docs/evidence/runtime/Git ownership to /root. This agent changed only the two requested /tmp reports; no commands remain running. WholeTask6/Task5/M3 remain OPEN; new H1 pressure runtime remains NOT RUN by this assignment. No upstream issue or product approval request is raised.
