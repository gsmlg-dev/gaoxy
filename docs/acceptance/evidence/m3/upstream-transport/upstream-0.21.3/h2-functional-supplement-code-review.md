# H2 functional supplement implementation review

Verdicts: **FAIL_SPEC**, then **FAIL_CODE**. One actionable finding. Runtime is **NOT RUN**. Direct bounded review in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, parent-supplied baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`.

Reviewed plan SHA256 `25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270` and prior independent SPEC reports (PASS_STATIC_SPEC, no open findings). Initial Elixir source `506420637ef2cb3403ea8649bd8d88e7a0446c41cbbbb5c5cb3d1cd2a4f66f24` was subsequently formatted by parent with recorded formatter exit0. Final formatted Elixir target is `83a947b179ce40e3f2b1e511fe3dd8f4995cd4fcff1743bb2b540d9141b43c62`; Python target remains `b1bcff8b19eba8c7bccb315ecd3ee66be860816128e76b2a15b5a36e0968f170`.

## H2-IMPL-01 — P2: acquisition-based cleanup is gated on a response stream

At `h2_functional_supplement.exs:208–210`, Fetch returns and its original completion is captured. A timeout/error in bounded Promise.await at223–224 can leave `state.stream` unset. Cleanup at473 then skips both supported RequestCompletion.abort_and_await (475) and follow AbortController.abort (477), because it requires `is_pid(state.stream)`. Controller/peer shutdown proceeds without public cancellation of that already acquired request. The original promise is not retained for late response handling.

`HTTP.Promise.await/2` delegates directly to Task.await (`deps/http_fetch/lib/http/promise.ex:89`). A caught wait timeout does not itself provide request cancellation or cleanup proof. If the request later produces a response stream, the current cleanup has no saved original promise from which to acquire, monitor, drain and join it. This violates the approved requirement to record cleanup responsibility for every acquisition and handle partial failures. Primary failure already remains FAIL; the issue is incomplete owned cleanup, not a false successful oracle.

Required repair: retain the original promise immediately. On primary failure cancel using the captured supported completion or owned follow AbortController regardless of whether a stream has been exposed, within originalC. Capture/register and drain/join a late public response stream when applicable. Preserve the unsupported-follow boundary, exact primary errors/reset codes, original deadlines and original FAIL. No private task/worker discovery or operations are needed.

## Other static sections

- **fixed_case_registration:** Exactly TLS98_LATE/EARLY, TLS100_ABORT/DEADLINE, H2C98_LATE/EARLY, H2C100_ABORT/DEADLINE in fixed list; invocation scope includes unique run/case.
- **public_profile:** Manual parser completion captured once; follow cancellation requires exact unsupported_completion:redirect. Explicit native_v1/reuse,6s request/2s connect, no connect_address, streaming_timeout prerequisite60000.
- **TLS_and_peer:** Four disposable OpenSSL commands cap10s, IP SAN127.0.0.1/serverAuth verified with verify_ip before ready; ssl verify_peer uses cacertfile and default hostname check, ALPNh2 required; package versions pinned.
- **wire_and_reader_oracles:** Exact14-byte nonterminal trailer HEADERS flags4/payload0001780176 and one DATA sentinelr. ACK before malformed early case; reset1 or8 with exact case-local connection/stream before first late read; exact public invalid_headers_transition/aborted/request_timeout and normal streamDOWN; reject extra stream messages.
- **deadlines:** Fixed ready45s, D10s/C15s afterready; request6s/connect2s unchanged. All waits derive remaining original deadline with2s operation ceilings except original deadline reset. Peer shared shutdown2s; original lifetime60s. External600s collector remains parent-owned and is not reviewed in these two sources.
- **bounds:** Peer emits≤128 events/4096-byte lines, reads≤4097, accepts≤3 controls includingstop, rejects duplicate/unknown controls; controller independently enforces matching bounds.
- **normal_teardown:** Public controller Agent.stop normalDOWN, peer stopped/live_threads0, original Port exit0+normalDOWN, disposable trust directory absent, exactly1accept/request/reset and actual ownedclose. Source drift prevents suitePASS; forcedcleanup preventsPASS; BLOCKED_HANDOFF on unconfirmed OS-group termination.
- **quality:** Qualification-only modules, no dependency/product adapter change or private runtime-operation calls. Clear fixed grammar and explicit public handles. Acquisition-based cleanup defect is the sole actionable finding.

## Verification and ownership

Python AST parse passed. All16 frozen source hash rows in the approved plan match current files; prior SPEC JSON matches the exact plan and has no open findings. Final input hashes and review JSON were validated after report creation. Elixir compilation and all runtime checks are NOT RUN. This review ran static reads/hash/AST checks only; no VM, Mix, test, peer, network, dependency or Git operation ran.

Only these two new reports were written. Other writers and their source/plan/evidence changes are preserved. All own commands completed synchronously; no background process exists. New H2 Sol0/unsuccessful0/Astra0; H1 Sol2/unsuccessful2/Astra1; TLS Sol4/unsuccessful2/Astra2, unchanged. Parent will assign the bounded cleanup repair and obtain fresh independent review before execution. Parent’s600s collector and loaded/native before/after identities remain separately required. This report does not establish native numerical/frontier acceptance, full M3 or production activation.
