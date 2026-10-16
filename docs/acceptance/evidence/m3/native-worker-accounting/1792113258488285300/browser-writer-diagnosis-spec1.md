# Browser writer diagnosis SPEC1

Verdict: cause UNKNOWN; no assertion relaxation is justified by current evidence. Source-only diagnosis completed.

Task `/root/native_worker_constructor_spec/browser_writer_diagnosis_spec1`; repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, archived HEAD `58307a7084298db309a93697b9102b2cc4c87eda`. Host3 `21280c6be63e9bef1956fa5fb30002896a7bd25e36583d2f8af1ec3f340b7778` and runner4 `eed9867759952b77a2d53a21e0fd717af08281cc8c416483232697ad3d8c51e6` verified. BrowserGREEN2 remains FAIL: H2 executed1, H1 NOT RUN; actual writer normal DOWN rejected before request_clean response; forced actor cleanup.

## What the requirement actually says

`docs/plans/m3-native-worker-startup-accounting.md:115-119`: Product-stage acceptance requires real negotiated H2 and H1 page, actual capture ownership/accounting, complete wire response, request+Session childpin+ordinary lease cleanup, finite actual normal owned actors/profile exits and final zero accounting. It does not require a browser keepalive connection to survive until an explicit process-close command.

`browser-notes1.md:90-96; host1/host3 request_native_clean`: Existing source-reviewed fixture contract adds an intermediate exact original connection+writer lease set, active2 and bytesC+R after request cleanup, before explicit Chrome close. This is a real existing fixture assertion, so cannot be silently erased; it is stronger ordering than the product plan.

`actual lifecycle SPEC1/SPEC2`: The auth-phase writer-survival guard was derived to preserve that stronger fixture profile and reject ambiguous early death. Source PASS proved implementation matches that profile, not that Chrome/native connection necessarily maintains it. Runtime now disproves its applicability to this execution, without proving the alternative benign.

The earlier source SPEC correctly checked that implementation against the selected fixture profile. The assumption that Chrome necessarily keeps its native connection/writer alive through that profile was unproven. We must reconsider that assumption, while preserving the existing assertions and immutable failures until the actual cause is traced.

## Confirmed evidence

- BrowserGREEN2 is FAIL: executed1 H2, H1 NOT RUN, source_stable true. Host3 raises on actual writer PID #PID<0.348.0> normal DOWN before request_clean response; browser/peer require forced SIGTERM cleanup and no acceptance is claimed.
- Captured actual H2 actors are worker #PID<0.349.0>, connection #PID<0.347.0>, writer #PID<0.348.0>. Custody event was emitted, but no request_clean, browser_close_authorized or stopped event exists in host log.
- Chrome CDP recorded protocol h2/TLS1.3, status200, full Network.loadingFinished, expected visible DOM and screenshot; no loadingFailed in recorded CDP events. This is intermediate complete-page evidence only, not native lifecycle acceptance.
- Raw peer emitted real HEAD /health and GET /checked and later idle_connection_closed reset with completed_responses2. It did not reach its normal joined event; post-host-failure upstream reset cannot explain the preceding downstream writer trigger.

## Why normal writer DOWN is insufficient

- Writer receives exact owner monitor DOWN, any owner reason: Writer returns :ok -> normal. Underlying owner may have peer_closed, local_closed, read_timeout, protocol error, service failure or another terminal reason.
- Writer receives :stop: Writer returns :ok -> normal. Connection.close sends :stop on handle_close/error/shutdown. Trigger may be legitimate peer close or a fault; writer normal alone does not identify it.
- Writer h2_write result outside [:ok,:expired]: Writer emits h2_written with actual error then stops normally. Socket.setopts/send, owner liveness, or Admission.start_send refusal can terminate writer normally; success of the earlier document does not prove later control sends succeeded.

`Writer.run` has no autonomous idle receive timeout. `Connection.close` sends writer :stop; Gaoxy invokes close from native handle_close, handle_error and handle_shutdown. Writer monitor DOWN also closes the connection. Native H2 can locally close after incoming GOAWAY/drain, protocol/control failure, write failure/expiry and several timer paths. ThousandIsland remote tcp_closed/ssl_closed yields exact peer_closed; local H2 info close yields local_closed. The same writer :normal result can accompany benign or failed connection paths.

No authentic connection monitor DOWN/exit reason is present before host raises; no recorded writer triggering receive or last h2_written result. Exact production connection-close cause is UNKNOWN.

Candidate source paths include peer EOF; incoming GOAWAY->drain->h2_close/local_closed; protocol/control/frame/start timeout->failure/local close; socket/write error; native owner/service termination. None is established for this run.

Service idle default30s and configured request15s do not explain a whole case elapsed10.799s without more timing evidence. Frame/settings/write defaults5s exist; no observed timer/input associates them with this failure. Do not invent a deadline explanation.

## Recommended bounded diagnosis

- Root may create a new immutable diagnostic-only fixture variant, leaving host3/runner4, all assertions and browserGREEN2 failure unchanged. Do not change production, startup95, public APIs, deadlines or acceptance rules.
- Before releasing the existing capture/dispatch barrier, trace only the actual captured connection+writer (and existing Session/native request monitors) with a dedicated owned collector: send, receive and process-exit events with monotonic timestamps and exact real PIDs/monitor refs. No fake DOWNs, arbitrary sleeps, broad trace-on-spawn, or success after force cleanup.
- Record the writer triggering input: :stop; exact owner DOWN reason; or h2_write token/deadline plus matching h2_written outcome. Record connection socket close/error; h2_written/error, writer DOWN, drain/control timeout and h2_close input; authentic connection exit and its monitor DOWN.
- For inbound decrypted SSL/TCP data, retain a bounded independent framing summary sufficient to identify actual GOAWAY(last_stream,error_code), RST_STREAM and SETTINGS/partial-frame completion. Preserve partial carry and stream IDs; never infer a full control frame from a partial delivery. Byte counts/hashes and finite event/byte bounds keep diagnostics reviewable.
- Record ordered phase markers at capture/dispatch, Chrome probe receipt, request_clean command receipt and each cleanup checkpoint, authorization request+ack, Chrome close command and genuine terminal observations. Correlate sequence IDs through the control channel instead of assuming unrelated monotonic clock epochs align.
- Flush and join the diagnostic collector on both success and failure with finite deadlines; preserve exact source hashes, process groups and actual exits. All existing strict peers, :normal Session/H2 request-worker/writer joins, exact connection reason expectation, Gate/resource zeros and forcedFAIL assertions remain until diagnostics justify a reviewed contract update.

## Gate policy

- Do not simply remove the phase guard, classify every normal writer DOWN as harmless, accept arbitrary connection reasons, skip the C+R checkpoint, increase timeouts speculatively, or claim browser acceptance from DOM/CDP alone.
- If authentic diagnostics prove complete request+response+Session/native cleanup followed by valid peer EOF or an actual NO_ERROR GOAWAY, a separately reviewed fixture contract may model that concrete naturally closed branch with exact connection reason, corresponding normal writer/worker/Session joins and final Gate0. The live C+R branch must still assert its exact lease set when live; no broad terminal-reason allowlist.
- If diagnostics instead show failed write, protocol error, timeout, missing cleanup or unexplained owner death, diagnose that concrete failure. Product completion still requires H2 and H1 full lifecycle and normal owned actor exits.

No production/startup95 change or architectural expansion is needed for this diagnosis. Source hashes and precise source references are bound in companion JSON. Reviewer used only source/log reads, JSON parsing and hashing; no runtime, Mix, browser, tests, builds, network or Git. Only assigned two `/tmp` reports were written. All commands finished, no background processes started.

Counters unchanged by review: group37/root44/stage failedGREEN7/Astra2of2. Review adds0 failedGREEN and0 repairs. No third Astra or user permission request. Root can continue the bounded diagnostic work; current exact connection-close reason remains unverified.
