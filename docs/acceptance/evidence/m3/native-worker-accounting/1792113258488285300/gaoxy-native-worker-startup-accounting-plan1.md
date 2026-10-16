# Native H2 Worker Startup and Dispatch Implementation Plan

> **For agentic workers:** Use executing-plans task-by-task under the parent's sole repository/runtime ownership. Frozen independent SPEC then CODE source reviews are required at the internal constructor checkpoint and final stage closure. Independent reviewers must not edit this scope.

**Goal:** Pre-admit complete native downstream-H2 startup and initial Exchange/endpoint dispatch using an ordinary child lease created around public atomic linked+monitored spawn_opt/4.

**Architecture:** Admission validates and reserves actualW plus one existing active slot before a primitive spawn of a generic core MFA bootstrap. Gate knows the real PID immediately, installs its ordinary active request lease, commits state, then activates/replies from the next callback. The native connection accepts only its original async request-id/token reply before constructing X/endpoint; worker protocol_bytes retains the allowance for its entire request. Stream Task.Supervisor use is removed at this one boundary; writer Task path is unchanged. No guardian, new resource class or ownership-transfer ticket.

**Tech Stack:** Existing Elixir1.18.5/OTP28, public spawn_opt/4 with [:link,:monitor] and gen_server send_request/check_response, Admission/Exchange/Generation/HPAX, independent Python h2 and Chrome/CDP. No dependency change/private API.

SOURCE-ONLY preparation: all implementation/verification below is NOT RUN. Design `/tmp/gaoxy-native-worker-startup-accounting-design1.md` is normative; binding1.json lists actual source hashes. Preparation baselinee189894 plus frozen E4 checked-capture candidate; parent reports it now fully closed as featurec4c4239c7d23f2e8d621c0359c75046cda8ac264 and docs58307a7084298db309a93697b9102b2cc4c87eda/treea038b7d0d24f662a75b9786ee15866957b53abf0, clean. Read-only HEAD/tree/status independently match that closure; binding records actual sources. All next-stage runtime checks remain NOT RUN. Cumulativegroup30/root35; Astra2/2 exhausted; preparation adds no attempts. Root owns all future edits/runtime, preserves others' files, and chooses routine details automatically.

## File ownership and narrow scope

Root creates/modifies only necessary stage files:

- Create `apps/gaoxy_http/lib/gaoxy/http/http2/worker_accounting.ex`: numeric-only actual-operand sizing, fixed point and separate post-result diagnostic rows.
- Create `apps/gaoxy/lib/gaoxy/admission/worker_bootstrap.ex`: generic core-only admitted MFA bootstrap; no HTTP/proxy imports or optional app activation.
- Modify `apps/gaoxy/lib/gaoxy/admission.ex`: async admitted spawn/cancel, ordinary lease creation, finite post-commit activation continuation and operation correlation completed after authenticated DOWN plus linked EXIT.
- Modify `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`: async startup, request-id/token authentication, source-sized full dispatch after Gate ownership proof.
- Modify `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex`: internal run arity7 with already owned lease, exact private bootstrap permit path, owner/gate/deadline checks and current endpoint/result semantics; no child acquire/begin.
- Create tests `apps/gaoxy/test/admitted_spawn_test.exs`, `apps/gaoxy_http/test/http2_worker_accounting_test.exs`, `apps/gaoxy_http/test/http2_worker_startup_test.exs`.
- Modify `apps/gaoxy_http/test/http2_stale_start_test.exs` only as required to move its private fixture from Task-before-reservation to async admitted spawn. Preserve stale-old-token/current-starter/queued-sibling/full-response assertions. Existing `http2_independent_review_test.exs` trailer-before-worker assertions remain mandatory.
- Create `docs/designs/m3-native-worker-startup-accounting.md`, `docs/plans/m3-native-worker-startup-accounting.md`, `docs/acceptance/m3-native-worker-startup-accounting.md` and immutable evidence root `docs/acceptance/evidence/m3/native-worker-startup-accounting/candidate1/`.
- New evidence browser fixtures `native-worker-browser-host1.exs`, `native-worker-browser-runner1.py` derived narrowly from E4 reviewed runner2. Never mutate archived evidence.

Preserve P and fixed Service9444956/group16478862/startup5963776. No deps edits, Session pin/cleanup redesign, upstreamH2 Generation activation, H3 worker accounting, operational certs, production/Vault/public management, release-artifact E2E, push/release/deployment. Core-only consumers stay isolated. No extra guardian process or public Task private-message workaround.

## Task 0: Bind predecessor closure and exact source

- [ ] Verify current worktree/HEAD/branch/status and exact feature/docs closure above; confirm all executable/test bytes match the supplied source binding. Record any root/pre-existing changes before edits. If ownership/source differs unexpectedly, BLOCKED_HANDOFF rather than overwrite.
- [ ] Create candidate1 evidence root only if unused; capture kickoff full source/diff/protected files/loaded toolchain/commands/counters. Copy design+plan into stage docs. No next-stage execution before predecessor full SPEC→CODE→fresh→localcommit receipt.
- [ ] Read qualified public Task comparison and source for public spawn_opt/4 with [:link,:monitor]/Process.monitor, generic MFA apply, alias async requests and existing Admission lease/watchdog/drain/force. Direct spawn removes Task wrappers from the stream runtime; do not retain fake Task ancestor/caller charges or invent a new cap.
- [ ] Use predecessor fresh baseline evidence for identical unchanged groups; run a scoped baseline only if actual source/commands differ. Existing baseline environmental failures remain BLOCKED_ENV; do not silently repair unrelated areas.

## Task 1: Behavioral RED and full integrated source implementation

- [ ] Add behavioral regressions using real Gate/listener/public spawn and deterministic test-owned tracing/barriers: byte_limit one byte short prevents child creation; exactW accepted before bootstrap activation; Gate reply proves real worker lease before endpoint; original owner death before activation and after spawn cannot orphan or refund early; late canceled success cannot replace current starter; full endpoint config/Exchange allowance persists through normal updates. Missing function alone is API RED, not full behavioral proof; fixture/compile errors are not expected RED.
- [ ] RED uses original source or no changed W-consuming path. Every fixture owns/restores its traces/suspensions/processes, finite deadlines and real actor monitors. No production test hook, mocked Admission charge or invented worker receipt.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/admitted_spawn_test.exs apps/gaoxy_http/test/http2_worker_startup_test.exs
```

- [ ] Implement `WorkerAccounting.reservation(state,stream)` returning exactly `{:ok,{:native_http2_worker_v1,N,W}}` or `{:error,:worker_capacity}`. It reads existing original operands and complete E sizes; it does not construct X/endpoint/dispatch/MFA/report rows precharge. Compute P+A+J and W=N+2head from the WHOLE source-role equation, monotone post-fixed point max64 iterations. Diagnostic worksheet is separate after numeric result. No endpoint init/callback/Store/provider/global config inventory, samples-as-maxima, guessed fixed delta or new endpoint/scalar ceiling.
- [ ] Preflight actual original operands and scalar identities without constructing request/MFA/Exchange/report wrappers. Qualified native args are exactly [owner,id,token,gate,N,D]; generic core validates flat scalar atoms/integers/PIDs/refs only, with no arbitrary config tree or invented size/depth/node/ancestor caps. Enumerate scalar queued request as the established pre-Admission control role; owner death before processing refuses before spawn.
- [ ] Include links in both directions, scalar monitor roots, complete EXIT/DOWN envelopes and timer ref/payload, then implicit Exchange struct/default keys, original complete request and `{module,initialized}` endpoint, actual full peer_cert/service/instance/peer/local/limits fields, source-local futurePID/ref bounds and all control/apply/correlation roots. Keep P unchanged and preserve every N/W bit-width transition. Store every role cap/multiplicity/subtotal/owner/lifetime for diagnostic independent review.

Implement these internal generic core entry points, preserving existing Admission APIs:

```elixir
def spawn_request(gate, parent_lease, token, bytes, deadline, mfa) do
  :gen_server.send_request(gate,
    {:spawn_request, parent_lease, token, bytes, deadline, mfa})
end

def cancel_spawn(gate, parent_lease, token) do
  :gen_server.send_request(gate, {:cancel_spawn, parent_lease, token})
end
```

- [ ] Gate authenticates actual parent lease holder and live owner, ready mode, positive originalD, token uniqueness, module/function atoms plus flat scalar-only MFA args (atoms/integers/PIDs/refs; no endpoint/config/Exchange) and existing max_active/max_bytes. Form reservedW/slot state BEFORE public spawn_opt/4 with [:link,:monitor]. Use only generic module/function/args; no core HTTP references. Capture the primitive's immediate PID/ref; install the ordinary COMPLETE child lease with W,D,request_active=true,drain_notify=true and existing timer/send/cleanup fields. Add token correlation and queue `{:activate_spawn,token}` to Gate; return `{:noreply,newstate}`. Distinguish atomic pre-PID spawn failure from postspawn errors, which kill/join known child with retained custody.
- [ ] Set Gate trap_exit in init; spawn exactly `:erlang.spawn_opt(WorkerBootstrap,:run,[gate,owner,activation_ref,D,mfa],[:link,:monitor])`. Keep worker non-trapping. Record known admitted-child EXIT and authenticated DOWN independently in correlation exit_seen/down_seen booleans; keep its SAME ordinary lease charged until both observed, then refund once. Thus either arrival order is safe without an uncharged tombstone. Unknown non-parent :normal EXIT is ignored; unknown abnormal EXIT stops with actual reason, preserving prior external-link behavior. OTP gen_server actual-parent EXIT remains intercepted. Source-check qualified gen_server2373–2380 and existing Service parent at service.ex38; current supported Gate non-parent links are only these new workers. Legacy acquire/update/watchdog/cleanup APIs retain behavior.
- [ ] Extend original parent lease DOWN handling to kill every correlated worker owned by that exact PID+parent_lease before refunding that parent's own lease. Keep each worker's distinct current lease bytes until its own DOWN plus linked EXIT. This closes normal-owner-exit while endpoint is blocked. Isolated Gate :kill uses atomic worker link; controlled normal stop uses existing terminate kill. Do not rely on receive-loop monitor polling, Service fallback or an extra process.
- [ ] NEXT Gate callback validates correlation, original owner/parent lease/D/mode and child. Only then send `{:gaoxy_admitted_worker_activate,secret_ref,child_lease}` to bootstrap and GenServer.reply original alias with `{:ok,worker,lease}`. Store the sender-only secret inside Gate/bootstrap; never disclose it to parent/endpoint. On denial kill known child, send finite reason and keep W until actual childDOWN plus linked EXIT. Correlation remains running for late cancel until childDOWN plus linked EXIT; no extra active slot or modified generic lease grammar.
- [ ] Bootstrap receives `(gate,owner,activation_ref,D,{module,function,args})`, links owner, monitors owner+Gate and waits with remainingD for exact activation or matchingDOWN. Before apply check owner/Gate live and Dpositive; retire wait monitors with flush; invoke `apply(module,function,[lease|args])`. Its process dictionary starts empty. It performs no Task call, creates no helper process and names no HTTP module. Core consumers never activate optional libraries merely by compiling it.
- [ ] Native connection uses source-bound `mfa={Stream,:run,[owner,id,token,gate,N,D]}` and public async request id, storing original token/N/W/D/parentlease until reply. Preserve existing one current `starting` selector and per-stream deadlines. PING/RST continue while Gate reply waits. Same-sender cancel reaches Gate after spawn request. Original request-id/token/current stream must match before accepting returned actual PID/lease; stale success is cleanup input, never replacement of current starter.
- [ ] On authenticated success construct the exact full X/dispatch in the design, with protocol_bytes=N and original initialized endpoint. Only then send dispatch once. Stream internal run becomes `(lease,owner,id,token,gate,N,D)`; no acquire/begin. Immediately link/monitor owner and monitor Gate, recheckD/liveness before endpoint; validate dispatch original owner/token/lease/N. Preserve CONNECT501, result/error/raise/throw/exit/final response rules, Generation capture cleanup and finite done controls; end :ok.
- [ ] Native reset/timeout/close sends authenticated cancel and may discard its row; Gate's ordinary child monitor/lease/correlation persists. Pending canceled/dead-owner request refuses or yields a known canceled child which remains charged untilDOWN plus linked EXIT. Gate authenticated childDOWN cancels timer and records down_seen. Only after that child EXIT is also consumed does Gate subtract current lease bytes exactly once (including later captureB) and delete ordinary lease/correlation; no early refund and no uncharged post-DOWN tombstone. Existing mode/drain/force/terminate applies to ordinary child leasePID even before native receives success. No timer refund or cleanup-success claim without realDOWN.
- [ ] Stage ALL actual startup/dispatch source above before source checkpoint, with no W-consuming runtime yet. Do not introduce a runtime flag, alternate constructor, separate arithmetic-only milestone or local commit to bypass this order.

## Task 2: Actual-source SPEC→CODE checkpoint BEFORE first consuming changed W

- [ ] Freeze exact calculator/core bootstrap/Admission/native connection/Stream/dispatch source and tests. Independently rederive complete ordered constructor rows, raw operands, owners/lifetimes/multiplicities/all subtotals and WHOLE fixed point from actual source. Cover provisional state, public spawn result, full ordinary lease/correlation, postcommit activation, bootstrap apply args/frame, original request alias/from/reply/async-result/timer roots, cancellation and every complete Exchange/default/endpoint field.
- [ ] Bind public async wrappers from qualified OTP: request `{'$gen_call',{owner,[alias|reqid]},payload}`, reply `{[alias|reqid],reply}`, `check_response` returns `{:reply,reply}`, `{:error,{known_reason,gate}}`, `:no_reply`. Include `receive_response(reqid,0)` alias-retirement results and race payloads; alias retirement is not remote cleanup proof. No Task infinity/plain-ref/ancestor constructors remain on changed stream path.
- [ ] Independent actual-source SPEC must PASS design/authority/order/budget table, THEN independent CODE must PASS actual source/numeric-only path/no precharge largewrapper/privateAPI/lifecycle/compatibility. Receipt includes exact candidate hashes and numeric A/J/N/W at default, large valid initialized options and ETF integer-width boundaries. Any omitted wrapper, guessed cap or sampled maximum FAILS this internal checkpoint.
- [ ] Run fresh nonzero constructor tests WITHOUT consuming changed W. Tag pure arithmetic/raw actual-constructor checks `native_worker_constructor`; every required case selected, excludedcounts separate. Expected arithmetic must not call production sum twice.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --only native_worker_constructor apps/gaoxy_http/test/http2_worker_accounting_test.exs apps/gaoxy/test/admitted_spawn_test.exs
```

- [ ] Parent issues source checkpoint receipt only after both reviews+fresh PASS, then first W-consuming native/direct integration may run. Any charged constructor/lifetime/multiplicity change reopens this SAME checkpoint before further W consumption. Final full-stage review is still separate. This is an integrated implementation checkpoint, not a worksheet milestone.

## Task 3: Real Admission/direct-spawn ownership GREEN

- [ ] Real Gate with real parent lease: W-1 exact byte_limit, unchanged status and no spawned child; W exact accepted, public status W+baseline before observed target/bootstrap effect, active baseline+1. A mocked charge/probe is insufficient. Original parent lease never moves; child gets real distinct owned lease before dispatch.
- [ ] At barriers kill original owner before Gate callback, after primitive spawn before activation, after activation before native success processing, after success before dispatch and during endpoint. Observe known actual childDOWN/unchanged sibling leases; bytes remain until genuine childDOWN. A normal parent exit while endpoint is blocked must be handled by Gate parent-lease DOWN→kill, not merely a worker receive monitor or normal link signal.
- [ ] Cancel while Gate suspended before request; resume Gate and assert ordered late accepted/denied result cannot dispatch. Cancel after activation but before response processing; child may already wait for dispatch but Gate kills it, keepsW untilDOWN plus linked EXIT, returns correct finite cancellation outcome. Test repeated/stale cancel/reply/DOWN cannot double-refund/replace current starter.
- [ ] Isolated core Gate tests: endpoint-blocked child dies on Gate :kill with terminate provably not used; normal owner exit kills the same blocked child through Gate parent-lease DOWN; reverse child abnormal exit leaves Gate/sibling alive; normal Gate stop and original Gate start_link-parent normal/abnormal exits join child. Explicitly assert the deliberate parent-normal behavior change under trap_exit using the actual start_link parent (scope service_pid may differ). Observe actual monitors and finite deadlines, test EXIT/DOWN order without refund twice. Use tracing+trace_delivered/status barriers for no-spawn refusal and committed lease before callback, never a test-only production spawn hook.
- [ ] Prove bootstrap private-ref authentication: wrong activation cannot enter target even if caller knows original streamtoken. Prove async alias reply correlation and exact workerleasePID ownership; old h2_stream_ready messages cannot grant custody. Real trace/source verifies no Task.Supervisor.start_child on this stream path; writer still uses public Task path.
- [ ] Gate pause/drain/expiry before activation deny target; after activation existing active request watchdog/force kills actual child. Gate/service stop before and during bootstrap/endpoint joins known child, parent/native owner, writer and listeners. Unexpected Gate :kill must kill/join an already endpoint-blocked worker through the atomic link, even in isolated core use; normal original-owner exit must kill/join it through Gate parent-lease DOWN handling. Preserve honest FAIL if either child survives, and never claim receive-monitor polling alone proves it.
- [ ] Validate active/status/highwater and exact current-byte subtraction with later update/captureB. No new resource class/ticket/guardian/process pool. Core source contains generic MFA/lifecycle only.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/admitted_spawn_test.exs apps/gaoxy/test/admission_timeout_test.exs apps/gaoxy/test/native_stream_test.exs apps/gaoxy/test/cleanup_attachment_test.exs apps/gaoxy_http/test/http2_worker_accounting_test.exs
```

## Task 4: Real native startup/dispatch, retained bytes and compatibility

- [ ] Raw h2c peer sends genuine preface/SETTINGS/HPACK HEADERS; at Gate/endpoint barriers observe exact W precharge before endpoint, correct real streamlease and protocol_bytesN. Initialized options larger than old65536 slack remain byte/content exact; one-byte-short rejects before child/endpoint/upstream effect, exactW succeeds. Use actual full public config forms, no global cap or sampled-max claim.
- [ ] Original stale-start case:3 canceled,5 current,7 queued; controlled stale response/failure/ready uses actual old identity and cannot clear/replace5 or advance7. Preserve exact responses5/7 and current/queued identity assertions. Fixture barrier may move from prelease Task acquire to new async Gate spawn, never remove/skip/weaken regression.
- [ ] PING/RST remain responsive during suspended Gate/slow bootstrap and stalled endpoint; siblings still respond. Preserve terminal trailers buffered before worker and explicit read-consumption checks, control-rate/window/error/write/reset and no-success-END_STREAM assertions. Primitive spawn must not be replaced with another blocking start API.
- [ ] Body poll/read/buffer updates, response/trailers/finalize and endpoint error preserve fullN in returned Exchange/public Gate status until actual workerDOWN. Full peer_cert, limits/defaults, service/instance/peer/local are included in independent exact constructor assertions.
- [ ] Genuine checked Generation downstreamH2->H1/static target keeps original G7/T8 holder===real worker, current captureB charge/owner-effect order, old/new immutable snapshot, public release/cancel and native response. Session childT8/cleanup attachment unchanged. Existing upstreamH2/h2c Generation exclusions stay asserted unchanged.
- [ ] Independent `.audit/h2peer/bin/python` tests run BOTH TCP and TLS/ALPN with cross-process writes, using current `test/support/h2_peer.py` and pinned requirements. Missing independent peer is BLOCKED_ENV, not skip/exclusion. Test fixture CA/certs come only from existing generator into test tempdir.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/http2_worker_startup_test.exs apps/gaoxy_http/test/http2_stale_start_test.exs apps/gaoxy_http/test/http2_capacity_test.exs apps/gaoxy_http/test/http2_independent_review_test.exs apps/gaoxy_http/test/http2_network_test.exs apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs
```

## Task 5: Actual Chrome negotiated-H2 and H1 browser cases

- [ ] Source-review new local-only host/runner from E4 runner2. Start TLS nativeH2 and H1 listeners through checked Generation to genuine public G-H1/T and independent rawH1 peer. Use existing `scripts/generate-fixtures.sh` ephemeral TEST certs only; no operational issuance/public listener.
- [ ] Real Chrome/CDP TLS navigation MUST assert response.protocol=="h2", URL/status and visible expected page/title/text+screenshot. h2c navigation/protocol inference cannot qualify browserH2. Also run existing H1 visible-page compatibility case on same source.
- [ ] At actual capture barrier verify real worker/lease/G7/T8 identity and public Gate bytes from independent N/W/B expectations plus ordinary connection/writer/other observed reservations; no summing unrelated or overlapping leases. End real wire response, request release, Session childpin release and ordinary lease/cleanup teardown.
- [ ] Join all owned Chrome/profile/host/peer/helper actors with finite deadlines and actual normal exits; profile removal and zero native/cleanup accounting are acceptance. Preserve complete-response-only idle-reset fixture policy, never accept partial requests/responses. Record percase actual PASS/FAIL, source/loaded bindings and command exit.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test python3 docs/acceptance/evidence/m3/native-worker-startup-accounting/candidate1/native-worker-browser-runner1.py --evidence-dir docs/acceptance/evidence/m3/native-worker-startup-accounting/candidate1/browser-green1
```

This exact new evidence path is proposed and must be created by root at Task0; this source-only author has created no repository fixture.

## Task 6: Scoped preservation, both isolated consumers, strict checks

- [ ] Run above new/affected groups unfiltered and explicit preservation group below. Record tests>0, failures, warnings, exclusions/skips and actual exits; overlapping command counts are executions, not distinct cases. Do not run unrelated umbrella-wide tests.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/http2_codec_test.exs apps/gaoxy_http/test/http2_facade_test.exs apps/gaoxy_http/test/http2_protocol_test.exs apps/gaoxy_http/test/http2_integration_test.exs apps/gaoxy_http/test/http2_pre_settings_test.exs apps/gaoxy_http/test/http2_control_rate_test.exs apps/gaoxy_http/test/native_proxy_seams_test.exs apps/gaoxy_http/test/connection_poll_test.exs apps/gaoxy_http/test/generation_checked_capture_test.exs apps/gaoxy_http/test/generation_resources_test.exs apps/gaoxy_http/test/generation_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_generation_accounting_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_test.exs apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs apps/gaoxy_proxy/test/http3_guardian_test.exs apps/gaoxy_proxy/test/http3_session_client_test.exs apps/gaoxy_http3/test/lifecycle_test.exs apps/gaoxy_http3/test/lifecycle_race_test.exs
```

H3 cases preserve changed Admission lifecycle compatibility only; they do not qualify H3 worker accounting. Assert existing fixed/group/startup constants and upstreamH2 exclusions unchanged.

- [ ] Run both fresh isolated consumers; core must prove no optional HTTP/proxy/Plug/Bandit/QUIC activation; HTTP-only must compile/work with proxy absent. If exact unchanged-lock network Git transport fails, preserve BLOCKED_ENV and use parent-authorized separately fsck-qualified local source route with new consumer counts; never change lock or claim failed network route passed.

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/external-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' bash scripts/http-consumer.sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy/lib/gaoxy/admission.ex apps/gaoxy/lib/gaoxy/admission/worker_bootstrap.ex apps/gaoxy/test/admitted_spawn_test.exs apps/gaoxy_http/lib/gaoxy/http/http2/worker_accounting.ex apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex apps/gaoxy_http/test/http2_worker_accounting_test.exs apps/gaoxy_http/test/http2_worker_startup_test.exs apps/gaoxy_http/test/http2_stale_start_test.exs
```

Append exact additional changed fixture files only if actually edited; no repository-wide format/autofix.

## Task 7: Final full independent SPEC→CODE, fresh verification and local commit

- [ ] Freeze actual production/test/docs/fixture/evidence hashes and loaded toolchain. Independent SPEC checks every design requirement/full row table/equation/pre-effect real Gate proof/native and independent-peer/browser/consumer evidence/minimal lifecycle scope. Then independent CODE follows actual source send/call/monitor/lease/cancel/death/activation/default-field paths, no private APIs/options cap/early refund, and assertion strength. No automatic Astra review.
- [ ] Resolve actionable findings. Charged constructor/lifetime/multiplicity changes reopen Task2 BEFORE further W runtime. Preserve cumulativegroup30/root35/Astra2/2 across attempts. Ordinary Sol repairs are authorized; technical impasse returns evidenced to parent, not a third Astra/reset.
- [ ] After final SPEC and CODE PASS run fresh affected scoped union and both browser cases on the final reviewed candidate. Collect finite600-second owned command groups, actual joins/exits/source-before+after/counts/warnings; no failed/blocked/unexecuted gate becomes PASS. Stop affected broadening on unrelated test failures; report without silently fixing them.
- [ ] Parent closes design/plan/acceptance with exact source/commit and scoped verdict. Confirm all own commands finished, suspensions restored, actors joined and no forced-cleanup-as-success. Successful native stop/drain requires actual Gate zero and real worker/writer/peer joins.
- [ ] Stage only task-owned files, inspect index/blob hashes vs reviewed frozen candidate, preserve unrelated files. Make local conventional commit `feat(http): account native h2 worker startup and dispatch` only after full SPEC→CODE→fresh. No arithmetic-only checkpoint commit/push/release/deployment.
- [ ] Automatically prepare the next bounded documented stage. UpstreamH2 Generation activation and H3 worker accounting remain separate; this stage is not full M3 completion.

All commands are PLANNED/NOT RUN by this source-only author. No unresolved user product decision is needed. Actual implementation constructors and numeric per-input subtotals still require the stated internal source gate; source preparation cannot claim runtime qualification.

## Independent source-only lifecycle finding incorporated

Reviewer `/root/checked_capture_full_code` reported the concrete source gap and narrow correction: monitor-only bootstrap cannot stop an endpoint-blocked child on isolated Gate :kill, which bypasses terminate; production Service cascade is fallback only. Atomic linked+monitored spawn closes the startup link window. Qualified OTP28 gen_server2373–2380 intercepts actual start_link-parent EXIT before Admission.handle_info, while scope service_pid is not necessarily that parent. Trap-exit deliberately makes actual-parent normal exit take termination rather than the old ignored normal link signal. Gate normal stop must kill pending/active children; original owner normal death needs explicit Gate lease-DOWN cleanup before native PID receipt. No stream membership/$callers dependency was found; writer stays Task-supervised. Do not broaden Lifecycle.resources ancestry filters. This is a source-audit finding, not an implementation/runtime PASS. Core/native lifecycle tests and complete constructor checkpoints above are still NOT RUN.

Lifecycle audit artifacts read and incorporated: `/tmp/gaoxy-native-worker-direct-spawn-lifecycle-audit1.md` and `/tmp/gaoxy-native-worker-direct-spawn-lifecycle-audit1.json`. Binding records their hashes. The explicit unknown non-parent EXIT policy and paired child EXIT/DOWN completion preserve the auditor's non-child lifecycle condition. Child ordinary lease may conservatively remain charged after its DOWN until linked EXIT is consumed; there is no early refund or extra resource class.
