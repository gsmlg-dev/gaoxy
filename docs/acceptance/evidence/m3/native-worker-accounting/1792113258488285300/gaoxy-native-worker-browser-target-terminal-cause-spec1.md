# BrowserGREEN2 target-writer terminal-cause investigation

Task: native_worker_constructor_spec / browser-target-terminal-cause-spec1.
Status: DONE for the bounded independent read-only source/evidence investigation. Original GREEN2 runtime status remains FAIL; target terminal cause remains UNKNOWN. This is a direct parent assignment, not an Astra recovery or runtime acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Saved GREEN2 baseline: `58307a7084298db309a93697b9102b2cc4c87eda` from qualification.json; no Git command was run to independently refresh HEAD or the worktree diff, as expressly prohibited by this assignment. Existing/ongoing parent changes were preserved. Evidence root E: `docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300`.

## Findings

1. The safe host log binds the captured target C=`#PID<0.347.0>`, R=`#PID<0.348.0>`, W=`#PID<0.349.0>`. It records ready, captured, session_custody, then rejects the exact authenticated monitor DOWN of R with reason `:normal` at frozen host3 line 994. It has neither request_clean nor browser_close_authorized emission. Its final error establishes the terminal symptom, not which writer branch returned.
2. A successful Chrome document is intermediate evidence only. browser-events.json has requestWillBeSent at CDP monotonic 11625470.236065 and loadingFinished at 11625472.184387: 1,948.322 ms. The completed document had HTTP 200, h2, 186 decoded bytes, 248 encoded bytes, visible DOM, and a saved screenshot. ResponseReceived was 11625472.184996; CDP event timestamps do not always follow emitted-list order, so do not fabricate a strict packet ordering from those submillisecond differences.
3. CDP response timing has ~1,898.827 ms before DNS start, a 5.547 ms connect interval, 5.315 ms TLS interval, and 39.649 ms from request sendEnd to receiveHeadersStart. Thus the ~1.95 s document timing mostly precedes the actual request send, rather than showing slow response transfer or a 10 s write.
4. qualification.json elapsed_ms=10799 uses Python time.monotonic from before test-certificate generation and actor startup through actor cleanup and the final source inventory. It is not a measured post-response cleanup interval, and supplies no timestamp for writer death or the request_clean command. It cannot establish that a 10 s host polling deadline fired. It does give a useful upper bound: with the recorded fresh-process setup and unchanged configuration, a normally elapsing 15 s request deadline or 30 s native idle deadline cannot expire in a total 10.799 s run. This exclusion is source/timing based; no terminal event directly names either timer. The 5 s H2/frame/write timers remain temporally possible and unproven.
5. Frozen runner4 sends request_clean only after the browser probe, waits for its ack, then sends authorize_browser_close, waits for that ack, and only then sends browser exit. The host failure is the generic outer loop catch-all, not an assertion from wait_until or join_native. request_clean does not return to that loop until after emitting its ack. Together with the complete host log, this places the observed rejection before completion of that branch, consistent with DOWN being handled before the request_clean command. It does not give exact cross-process enqueue times. The 10 s wait helper only polls and raises on expiry; it contains no writer stop action.
6. Forced cleanup is recorded: node exit -15 and peer exit -15, both forced; host exit 1. All owned groups were absent after cleanup. peer.log's later idle_connection_closed/reset and browser cleanup cannot be assigned as the original cause: they lack common phase timestamps and may be consequences of host failure. H1 was NOT RUN.

## Source-bound writer and connection paths

The reviewed production hashes below match GREEN2 source_before. Writer.run/5 is a Task.Supervisor child with a monitor on its real C owner, not a process with its own idle receive timer.

`http2/writer.ex:6-66` has these relevant normal-return paths:

- Initial Admission.acquire refusal sends h2_writer_failed and returns. The captured live R and its proved ordinary lease exclude treating this as the captured writer's already-completed initial refusal.
- For a write, it computes a result, sends C `{:h2_written, R, token, result}` at line 52, and loops only for :ok or :expired. A different returned result therefore makes R exit normally. In particular, a socket/setopts/admission/send failure can cause normal DOWN. The :expired result alone does NOT end R.
- Exact owner-monitor DOWN returns :ok, regardless of C's reason.
- Receiving :stop returns :ok. The payload alone does not identify its sender.
- There is no receive-after idle timeout in loop/6. Drain notification only loops.

`http2/connection.ex:1001-1050` consumes matching h2_written: :ok clears matching started inflight and can still expire an associated deadline; :expired clears the slot and can close a control write or an already-closing connection; matching {:error, _} closes. Stale tokens can be ignored. R's normal DOWN is itself another unconditional C-close trigger at 1079-1082. Observing C local_closed after R DOWN does not distinguish cause from consequence.

`http2/connection.ex:1242-1283` ordinary response-write completion replies to the endpoint and clears its write; it does not routinely stop R. `schedule/1:854-877` queues h2_close only if close_after_write or drained/no streams, not merely because a response completed. `failure/2:1383-1390` queues GOAWAY and marks closing/close_after_write. Hence a pre-existing protocol failure followed by a successful response/GOAWAY write could end C without a failed R write; the original logs do not establish this path.

`http2/connection.ex:1099-1146`: h2_read_timeout replies pending; h2_poll_timeout replies :ok and clears poll. Neither directly closes C. h2_write_timeout expires a write, with connection closure possible for a started header block; settings-start timeout can generate settings_timeout, and partial-frame timeout can generate protocol_error. Those require matched tokens/state. Successful response rendering alone does not prove settings_ack=true or partial_token=nil.

`http2/connection.ex:1411-1418` close/1 sends R :stop after cancelling/killing stream workers. `http/connection.ex:352-375` routes H2 handle_close/error/shutdown/timeout to that function. Current installed ThousandIsland handler receives ssl_closed/tcp_closed as peer_closed; read_timeout as shutdown/read_timeout; socket errors as their reason. Its terminate clauses invoke the appropriate Gaoxy callback, which can enqueue :stop before C itself exits. Therefore R normal DOWN can arrive at the host before C DOWN even when C initiated termination.

Original options override request_timeout to 15000 only. Default H2 frame_timeout and HTTP write_timeout are 5000. Config idle_timeout=30000 is passed to ThousandIsland read_timeout by service.ex. Current installed dependency source was inspected, but it has no saved GREEN2 source hash; its exact historical identity is not independently proved by this investigation.

## Recommended bounded causal probes

Keep the original target-live/unjoined C/R close-authorization guard and all deadlines/assertions. Do not repair this failure by accepting early R death, by extending a deadline inferred from elapsed_ms, or by calling post-failure browser shutdown its cause.

The minimum discriminating observation is a safe terminal chronology for the actual R and C, starting before dispatch and ideally before their first I/O. Install public TI lifecycle telemetry before starting the browser; arm any message tracing at the process-creation/admission seam before relevant events can occur. A late trace attached after capture can miss a close-triggering message that has already set closing=true; report that coverage gap rather than infer absence.

- R sends: project only h2_written writer PID, real destination C PID, token identity, and result class (:ok/:expired or a bounded safe error projection). Also project h2_writer_failed if it occurs. No socket/bytes payload. The matching R h2_written failure followed by R exit is a concrete failed-write-return discriminator even if C dies before consuming it.
- R receives: project only exact :stop and exact monitor DOWN of actual C, with known monitor correlation and bounded safe reason. Correlate C's send of :stop to actual R, rather than assigning sender from receive payload. Keep R exit/host monitor DOWN independently authenticated. If multiple terminal inputs are already queued, receive order plus final send/result is required to identify the branch actually taken.
- C receives/sends: project only matching socket-close/error tag, read_timeout, h2_start_timeout/h2_partial_timeout/h2_write_timeout/h2_close/drain, matching h2_written result, and exact R DOWN. Preserve token-match booleans; a timeout tag with a stale token is not evidence that it took effect. Record C->R :stop, native close-callback kind, public TI terminal event, and actual C monitor reason. A public TI stop event without an error does not itself separate local/peer/shutdown; keep the actual reason/trigger observations.
- For each relevant C event, record scalar state before/after: settings_ack, closing, draining, close_after_write, preface complete, buffer byte length, continuation-present, partial-token-present/match, stream count, inflight-present/started and token-match, outgoing-block-present/started, queue length, relevant remaining deadline. Do not dump state, SSL/TLS structs, socket values, exchange, raw messages, data frames, certificates or keys. Use validated allowlists and bounded reason wrappers with omission fallback.
- Host and Python actor boundary: timestamp command send, command dispatch, request cleanup subphase entry/exit, browser probe, close authorization and actor dispose start with monotonic clocks. Browser CDP request/response/loadingFinished and a per-actor timestamp bridge provide relative correlation; do not directly subtract unrelated clock epochs. This will distinguish a queued DOWN before command dispatch from a death during provider cleanup.

Safe tracing must filter/project before any artifact is written; broad send/receive or sys.get_state logging risks the previously observed ephemeral TLS disclosure. A tracer may classify only bounded whitelisted shapes, with all other messages omitted. Apply this to every actual native cohort member, then identify the original target by recorded C/R/lease identity; do not conflate another Chrome connection's terminal event with target R.

Interpretation rules: failed-write envelope + actual R return, exact C-monitor receive, or :stop receive plus correlated sender/close callback are positive causal evidence. Missing observations are UNKNOWN when coverage is late, dropped, incomplete or no branch-return observation exists. Wire completion does not establish a live persistent connection, and an independent subsequent run diagnoses that run; it cannot retroactively prove the cause of GREEN2.

## Evidence identity

All paths in this table are relative to E unless prefixed by apps/ or deps/.

| Input | SHA256 |
| --- | --- |
| browser-green2/qualification.json | 6d7f2e8eab8e57d68c86a6b24d0882eec900a77f90f2884ad485315a76853d05 |
| browser-green2-failure-diagnosis1.json | e56db695ef4154139ed4abcbf6d1aff3e08cfa1fc3c20d6496c06c054b011d75 |
| browser-green2/h2/host.log | ae198558145f276c33bcade0fccc5cea7867814f4976dee3598eeb8bb20e9c7c |
| browser-green2/h2/browser.log | 0132eebc1cc60d35c15e398792487fa3e47a9604495603cc9af7a4f95099f070 |
| browser-green2/h2/peer.log | 14417a7d5537c65fa08d7675b89eca40e8f9c0025d8917181a9cad124bf38328 |
| browser-green2/h2/browser-events.json | e2b95e1ffda0abdc67e2061bf91de7a52b75dfe9b6cf7714cdf1388e73420427 |
| native-worker-browser-host3.exs | 21280c6be63e9bef1956fa5fb30002896a7bd25e36583d2f8af1ec3f340b7778 |
| native-worker-browser-runner4.py | eed9867759952b77a2d53a21e0fd717af08281cc8c416483232697ad3d8c51e6 |
| apps/gaoxy_http/lib/gaoxy/http/http2/writer.ex | 6af7f110ce8a39a834f40409b08f7626ca057230ee66cab0b65304584cec562a |
| apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex | 586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52 |
| apps/gaoxy_http/lib/gaoxy/http/connection.ex | d74a1ea9b35e996db51da5b698390afd3cdc5c47eb2c499d35c3af69de46d3f2 |
| apps/gaoxy_http/lib/gaoxy/http/options.ex | 3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90 |
| apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex | f8d922deee2f7a45ecf3070498a3f82a50af47b5fbe0007545ab11bf3cf831ab |
| apps/gaoxy/lib/gaoxy/config.ex | 3054657e55350afeb23f0690a4c3d6d0d3df352e564184ce5579cb6f30583cde |
| apps/gaoxy/lib/gaoxy/service.ex | 740d69a364e52cda9d05a997136ce864e9ec464149adcc81045bc9c109ed4472 |
| deps/thousand_island/lib/thousand_island/handler.ex (current installed) | baa63be02492beb348e11412fd4a8524a288ecdb1010f6f2c08df2e02f202319 |

## Work and verification boundary

Only this /tmp report was created. Commands were bounded source reads, rg searches, and Python JSON projection/hash/timing arithmetic; all completed exit 0 except any normal no-match search included in an otherwise successful read batch. No runtime, Mix, browser, test, Git or network command was run; no repo/evidence file was edited; no agent was delegated. No diagnostic raw trace or full sys-state reply was read. No new runtime acceptance is claimed. Scope review used systematic-debugging and verification-before-completion skills.

Parent cumulative counters received: group37/root48/stage7, Astra2of2 exhausted, diagnostic failures4. This assignment adds zero runtime attempts and zero repair rounds; counters unchanged. No Astra escalation. All own commands are finished. Remaining risk: the historical target-cause gap persists until sufficient original evidence is found; fresh probes can positively diagnose a new occurrence without rewriting historical UNKNOWN. No user decision or new permission is requested; parent owns implementation/runtime/evidence/Git.
