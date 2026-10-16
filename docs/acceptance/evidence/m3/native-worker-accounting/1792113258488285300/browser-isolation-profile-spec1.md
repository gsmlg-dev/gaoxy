# Test-only one-selected-connection browser profile SPEC1

**DONE — admissible in principle with the conditions below.** This is a source-only review of the proposed fixture contract, not an implementation review or runtime PASS. No production or public configuration feature is needed for this profile.

Task5 requires actual Chrome TLS/H2 navigation to native Gaoxy, real custody/accounting and complete-response/lifecycle acceptance, plus H1 compatibility (`docs/plans/m3-native-worker-startup-accounting.md:114–119`). It does not explicitly require an unmediated TCP topology. A raw TCP relay can keep native Gaoxy as the TLS/ALPN and HTTP endpoint: Chrome and native Gaoxy exchange the same ordered TLS bytes, and the relay owns neither TLS keys nor HTTP responses. The resulting evidence must explicitly name the isolation profile and its split TCP topology. It cannot be described as direct Chrome-to-Gaoxy TCP or general browser multi-connection acceptance.

## PROFILE-S1 — Topology and scope

New immutable test fixture only. A loopback raw-TCP front door connects to the exact ready native Gaoxy loopback listener. Gaoxy still owns its listener, Connection/Writer/RequestWorker and checked Generation. No production/library/config/public API/dependency change. Profile explicitly discloses TCP relay and rejected additional browser sockets; it proves real browser/native protocol behavior under one-selected-connection isolation, not unmediated Chrome-to-listener TCP topology or general multi-connection acceptance.

## PROFILE-S2 — Irreversible single selection

First accepted frontend socket is atomically latched before concurrent work can accept/select another. Only it may initiate exactly one backend connection attempt; final success requires exactly one backend connection. No retries, replacement, reconnect, fallback, readiness TCP probe, selected-socket reassignment, or backend for rejected sockets. Backend connect timeout/failure or first socket failing to navigate is FAIL. Later frontend sockets are immediately closed and counted as rejected without parsing, backend creation or forwarding. Listener/accepted socket bounds and finite lifetime are enforced.

## PROFILE-S3 — Raw byte custody

No TLS/HTTP parsing, termination, certificate issuance, protocol translation, response synthesis, content rewriting, caching, retries or error masking. Forward byte order unchanged in both directions. Each direction uses bounded buffers/chunks and bounded send/read/control/join deadlines with backpressure. Record positive read/write byte counts for EACH direction, streaming SHA256 over source bytes and actually sent bytes, equality of lengths and digests per direction, and empty final buffers. Count partial sends accurately. Raw TLS/plaintext payloads and socket/sys-state secret dumps are not evidence artifacts.

## PROFILE-S4 — Real native TLS and browser evidence

Browser navigates front-door origin /checked but native Gaoxy presents the existing ephemeral TEST leaf certificate. Existing leaf-SPKI allowlist only, no general certificate-error bypass or TLS proxy mode. Keep Chrome CDP exact h2 plus TLS securityDetails, completed loading, expected URL/status/title/visible text/screenshot, native secure state/actual negotiated ALPN h2, source/loaded bindings. Preserve native H1 compatibility case on same frozen source. Record frontend/backend endpoint tuples and native listener identity to correlate the sole backend with the actual captured native actors; do not claim native peer tuple equals Chrome frontend tuple.

## PROFILE-S5 — Unchanged accounting and custody

All original Gate checks remain global and exact: live C/R/W active3 plus exact bytes before response, real original G7/T8 and derived Session custody/pins, strict full-response release barrier, requestworker and Session normal joins/cleanup0, exact original C/R active2 and exact bytes after request, zero active/bytes/cleanup after browser. No cap/Gate limit/calculator/95-row change, actor subtraction/filtering, target-only reinterpretation or early refund. Relay queues are bounded test-owned memory outside Gaoxy accounting, disclosed separately, never evidence that all Chrome/relay bytes are Gaoxy-charged.

## PROFILE-S6 — Authorization state machine

Runner obtains existing host request_clean, exact payload custody and same captured Connection+Writer alive/unjoined authorization ack, then sends authorize_close to relay and waits for its explicit ack, only then commands Chrome Browser.close. Host and relay authorization state are independent positive receipts, each single-use, correlated to case/selected connection. Relay starts unauthorized and any selected read EOF/error, failed write, timeout, control EOF/malformed/out-of-order/duplicate command before authorization latches permanent FAIL. Authorization never clears earlier failure. No preemptive selected shutdown/close or synthetic EOF to make native termination look like browser EOF.

## PROFILE-S7 — EOF and race honesty

One relay event owner serializes readiness, I/O, sticky failure and control authorization; avoid independent threads toggling booleans after queued EOF. Immediately observable selected terminal state is checked before authorize ack. Report authorization and EOF events with ordered sequence and monotonic timestamps. Read EOF must be distinguished from reset/exception and from local disposal. Do not assert observation order proves an unknowable remote physical FIN time. If evidence cannot resolve a preauthorization terminal race, fail the run. Selected reset/I/O error is FAIL even after auth; only actual clean per-direction EOF and the unchanged host terminal-reason checks qualify.

## PROFILE-S8 — Drain and normal teardown

After actual authorized source EOF, drain that direction completely, then propagate write-half-close to its destination. Keep reverse direction alive to drain its actual bytes and await actual EOF; do not close both sockets immediately at first EOF or use cleanup close to manufacture normal EOF. Require both source EOFs, both destination write-half-closes after drain, both queues empty, per-direction byte/digest equality and positive traffic, exactly one backend, no sticky failure, socket closure/listener closure and all relay threads/processes/log readers joined with actual exit0 under finite deadlines. Keep existing native Connection {:shutdown,:peer_closed}, Writer :normal, worker/Session :normal and strict upstream raw-peer framing/complete-response/idle-reset policy unchanged. Forced cleanup and timeout are FAIL, while still disposing every owned actor.

## PROFILE-S9 — Qualification and immutable evidence

Before browser qualification: review actual new relay/runner source independently for SPEC then CODE, bind source hashes and record limits/endpoint mapping/control-event order/counters/bytes/digests/EOF/queue/exit outcomes. Exercise focused relay contract checks for rejecting extras with no second backend, early selected EOF/error sticky failure, partial send/backpressure byte preservation and bounded normal half-close/join. Fresh actual H2 and H1 must pass complete existing gates plus relay joins on same frozen source. Preserve prior failures and current counters; no source-proposal verdict is runtime PASS.

## Pitfalls and causal boundary

- A TLS-terminating HTTP proxy, Chrome proxy flag, fabricated page, protocol inference, or direct TI native substitution invalidates this profile.
- First accepted connection can be speculative and unused; rejecting the request-bearing second connection can fail navigation. That remains FAIL; do not choose the first HTTP request or reconnect to obtain a pass.
- A raw relay splits TCP flow control and changes packet timing/peer socket tuple. Stream identity preserves TLS/H2 semantics but does not preserve direct TCP timing or establish root cause of previous writer death.
- Closing extra frontend sockets deliberately is permitted only before backend creation and separately recorded. It does not authorize terminating/filtering already admitted native C/R actors.
- sendall success alone is not receiver consumption; relay end-to-end counts/digests plus browser completion and native peer/lifecycle evidence are complementary.
- One-way EOF is not complete relay join; premature full close can lose buffered TLS close_notify or application bytes, hide reset or manufacture native peer_closed.
- Authorization race or worker exception cannot be swallowed by logging, actor cleanup, thread daemonization, or treating socket errors as ordinary EOF.
- No payload/key/TLS-state dumps; record bounded scalar metadata and ciphertext digests. Preserve raw-trace quarantine restriction.

The prior target writer-before-authorization cause remains **UNKNOWN**. This profile constrains frontend fanout and may enable a clean diagnostic/qualification run, but a future PASS would not establish that fanout caused the earlier writer exit. The previous Diagnostic2 global5 evidence and failed browser attempts remain immutable.

No dependency issue is established: this is test topology control, not a production workaround for an identified dependency bug. No raw archive, runtime, browser, network or Git command was used. All reviewed source identities are bound in the companion JSON. All own commands completed; no process was launched. Only the two `/tmp` reports were created.

Counters unchanged: group37/root47/stage7 failedGREEN; Astra2of2 exhausted; this review adds zero failedGREEN and zero Sol repairs. Current full-stage acceptance remains OPEN.
