# Group browser GOAWAY diagnosis1

Task /root/native_tls_spec2. DONE_READ_ONLY_DIAGNOSIS; direct bounded assignment. This is source/evidence diagnosis, not runtime qualification or stage acceptance.

Repository/worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation. Branch codex/m3-h1-resource-foundation, HEAD 7cff6e87edb9b67e2667897bfbb7ee7e0075162e. Parent-owned dirty/untracked group activation files were inspected and preserved. Only this /tmp report was written.

## Verdict

Browser5 failed because the fixture assumes GOAWAY immediately causes client EOF on an already-idle connection. The installed runtime instead enters draining and sets its default 30000ms timer. The browser waits only 20 seconds. No supported public API contract found promises immediate EOF; this evidence does not justify an upstream blocker. Do not extend the timeout blindly, relabel teardown EOF as success, or change dependency internals.

The actual command receipt remains FAIL, exit1, process_joined=true, timed_out=false, completed_cases=1; qualification elapsed45808ms, source_stable=true. Positive native-H2-to-TLS-H2 passed. Wrong-CA stopped before rotation/browser work; wrong-name was not executed. The group stage remains unaccepted.

## Trace and evidence

- apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py:393-396: goaway builds and sends a raw type7 frame, then flushes/emits command. It neither closes the socket nor signals its worker to retire. The fixture worker keeps recv polling until real EOF/reset, stop, or its overall deadline (serve217-311).
- integration/http_fetch_contract/managed_h2_group_browser.py:227-234: host start already proves successful completed health HEAD; only afterward does the suite send GOAWAY and wait for EOF before rotate_tls.
- integration/http_fetch_contract/managed_h2_fixed_qualification.py:1143-1158: Process.event defaults to20s. A queue.Empty escapes from Queue.get at the deadline; the observed traceback points exactly here and browser line233.
- deps/http_runtime/lib/http/http2/connection_owner.ex:25,117,930-975: GOAWAY records draining, excludes new admission through the pool notification and starts default30000ms drain timer. It does not immediately stop when the current stream map is already empty. release_stream491-521 does stop when releasing the last stream while draining, but the health completion/release happened before this GOAWAY. The timer327-329 eventually stops; terminate553-566 closes transport through close_transport1836 onward.
- deps/http_runtime/lib/http/http2/pool.ex:43-46 documents mark_draining as stopping new reservations; handlers279-296 and977-988 mark draining and cancel idle timers. deps/http_runtime/lib/http/managed_transport.ex:67 documents one-shot GOAWAY draining notices. Neither documents immediate EOF. Runtime and Fetch are locked Hex0.21.10 (mix.lock10-11; proxy mix.exs16).
- Browser5 wrong-ca-peer.log has ready, group_browser_ready, accept1, real TLS ALPNh2/SNIlocalhost, one HEAD /health stream1, upload_end, GOAWAY command, EOF. There is no tls_rotated, no joined and no post-health handshake. Events are not timestamped. The suite's exception then disposes actors in insertion order, terminating the host before the negative peer; that teardown can produce EOF. Therefore the final EOF cannot prove pre-timeout/pre-rotation closure. Browser5 FAIL must remain immutable.

Evidence directory E=docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089. Browser5 directory E/browser-three-cases5-1792101661338130027.

## Smallest correct next setup

Keep this fix in the dedicated group browser peer and canonical browser setup, with the actual GOAWAY event retained. Add an explicit, bounded, server-initiated health-connection retirement operation after the successful health completion and GOAWAY. Its contract must require the one original connection, exactly one request, target /health, completed response/no pending response data, no prior rotation and no other live connection. Physically terminate that socket and join the exact worker before replacing the SSLContext. Emit authentic separate provenance such as health_connection_closed with initiator=fixture, actual connection/stream, actual socket-closed and worker-joined results; record exactly one intentional retirement. Do not synthesize a remote EOF event or pretend that GOAWAY alone closed it. Keep final forced=0 meaningful as no emergency final teardown; explicitly preserve intentional retirement in the case evidence rather than hiding it in that counter.

The current base peer has no close command. Implementing retirement must account for its recv worker and keep its bookkeeping truthful: do not merely set client.eof to satisfy rotate_tls, and do not emit closure before socket close plus worker join. Prefer worker-owned closure or another explicitly synchronized close path; avoid concurrent SSL unwrap/read. Python3.13 SSLSocket.shutdown clears _sslobj (ssl.py1340-1343), so a casual cross-thread half-close is not a safe drop-in recommendation. A controlled actual transport close is sufficient for the certificate rotation setup; no graceful-TLS-close claim is needed.

Adapt rotate_tls to require that real retirement receipt and joined worker, retaining the exact1 HEAD/request/connection checks and changed certificate fingerprints. A peer-initiated transport retirement changes the documented setup assertion from unsupported immediate client EOF to proved physical termination; it must not alter any product behavior or the original certificate/response/accounting assertions. No private HTTP owner access or public-generation retirement/recreation is needed, and the same original group/transport generation remains under test.

After actual closure/join, switch only the listener's TLS context. Keep both negative requirements unchanged: original trust configuration, genuinely wrong CA or trusted wrong hostname, actual later failed TLS handshake on a different physical connection, no additional HTTP request (joined requests==1), Chrome502/error page with declared_bytes0/no console error, exact original completion outcomes and Service/G/T retained-failure or confirmed-cleanup proof. Keep all positive reuse, request, ledger and final-join assertions. Fresh independent source review and full original three-case execution are still required; diagnosis does not predict PASS.

An alternative that emits GOAWAY during the active health response could exercise the runtime's release-while-draining branch, but introduces ordering concerns and changes healthy-start timing. Explicit peer retirement after accepted health is the narrower certificate-test setup.

## Positive host :einval

Browser5 host.log lines6 and18 contain two MatchError crashes at Gaoxy.HTTP.Connection.handle_connection/2 line16, both at06:01:17.822, on distinct native downstream handlers before request_clean. The failing expression is {:ok, peer}=ThousandIsland.Socket.peername(socket). These handlers have not reached Gaoxy.HTTP.HTTP2.Connection.start, so the failed sockets have not acquired the newly introduced native-H2 connection/writer reservation path.

apps/gaoxy_http/lib/gaoxy/http/connection.ex is byte-identical to HEAD7cff6e8 (SHA d74a1ea9b35e996db51da5b698390afd3cdc5c47eb2c499d35c3af69de46d3f2), with no task diff. Its most recent commit is03d71ea, fix(http3): complete upstream cleanup and M4 qualification. Thus this unguarded close-before-peername race is pre-existing source, not introduced by group activation. The logs are consistent with closed speculative/browser TLS connections; exact initiator is not proved by these logs, so preconnect origin should remain an inference.

It is a real native-handler robustness defect/noisy error and should remain visible; do not call the whole host error-free. It did not prevent this positive case's actual browser/protocol/accounting acceptance: three browser requests plus health reused one upstream connection; positive peer joined accepts1/requests4/forced0/live0/failedfalse, browser joined code0/forcedfalse, original3 completions and confirmed public stop passed. Physical termination was authentic connection_reset104. This baseline defect neither explains the negative GOAWAY EOF failure nor invalidates those specific positive evidence assertions. Any fix requires its own bounded regression/review, not an unrecorded adjacent edit in this read-only assignment.

## Authenticated identities

Canonical group browser source:5c6544a5b3f70329f083ad2fb48b522b81fe7a990135136a12358dd436ef6dfa.
Group browser peer:0b73127aa1f3cf3d7a9257526db158c40b3ec76913089c028397175e5bafd259.
Base peer:b8b3c75760998d0e6dd5a8a2ad4a1820efb1eacfac5398103367e69d78237b00.
Runtime ConnectionOwner:6ed1fbcef6b03794dfb8fc89183faf3eb8a28d6f0f0f7e2eb521abfb3d740615.
Browser5 qualification:68045cc4d57a2dc1c061d3aca05be67faabcb8c3326ef0191a6b0135f0b2f6d2.
Browser5 wrong-ca-peer.log:9db21c19950b4fda30ded6debe81d38ef30b7850473d76327717c3b8477f88ac.
Browser5 host.log:28f47ed202f61f691baf05d9b6f3479381cde32d54f98d608f8ea60374edc16b.
Browser5 command receipt:828e4fa6a358e54961aa5f5e78c7e4ddf3ba03863e60cdf49e9a7b75b1c78817.
Browser5 command log:66bfb0e3babd28a6c904062249f1a9cfc6740278c515988bd025f4b72794b6e2.

## Validation and handoff

Read-only commands: pwd/git status/git rev-parse; scoped rg/sed source reads; git show HEAD and git log for native baseline; Python stdlib-only JSON parsing/byte hashes/source comparison. Expected absent-file/search/glob diagnostics were followed by the correct source paths; they are not implementation failures. No runtime, test, peer, browser, build, formatter or process control was executed. All own commands exited; no owned runtime process remains. Only /tmp/gaoxy-group-browser-goaway-diagnosis1.md was written.

Cumulative counters preserved:24 failed GREEN/26 ordered root events, Astra2/2 exhausted; this diagnosis adds0 repair/recovery rounds. No astra_gate; no environment/product decision needed. Runtime behavior of the proposed retirement operation remains NOT RUN, and the stage remains FAIL/incomplete until its actual required gates and independent review pass.
