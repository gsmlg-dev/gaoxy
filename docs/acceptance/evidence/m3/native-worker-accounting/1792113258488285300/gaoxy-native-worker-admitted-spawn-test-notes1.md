# Core admitted-spawn RED test proposal 1

Task `/root/native_worker_accounting_design/core-red-proposal1`: DONE SOURCE-ONLY PREPARATION, direct assignment. Eventual repository target is `apps/gaoxy/test/admitted_spawn_test.exs`. Only the paired `.exs`, these notes and the JSON companion under `/tmp` are assignment-owned. No test, build, formatter, Elixir parser, application, network operation or Git mutation was executed; this is not a runtime PASS or a compiled-test receipt.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; HEAD `58307a7084298db309a93697b9102b2cc4c87eda`, tree `a038b7d0d24f662a75b9786ee15866957b53abf0`. Parent concurrently owns `implement-plan.md`, canonical next-stage documents and E5 untracked evidence. These were preserved. Core production sources remain at the reviewed baseline. Counters remain group30/root35/Astra2/2; source proposal adds zero repair/runtime attempts.

## Settled contracts exercised

The proposal invokes `Admission.spawn_request(gate,parent_lease,token,W,D,mfa)` and `Admission.cancel_spawn(gate,parent_lease,token)` through `apply` so missing APIs produce explicit API RED rather than undefined-call compiler warnings. Both return a public `:gen_server.send_request` reference owned by the real caller process. The caller classifies each received message with `:gen_server.check_response/2`; success wire is exactly `{[:alias|request_id],{:ok,worker,lease}}`, classified as `{:reply,{:ok,worker,lease}}`. Tests assert the improper alias tail, not a plain ref or proper singleton list.

Core callback MFA is `{Gaoxy.AdmittedSpawnTest,:probe,[observer,1,token,gate,W,D]}`: six flat scalar args with the same type roles as the qualified native caller. Generic core bootstrap prepends the actual lease, calling probe/7. It learns actual original lease owner from the real GenServer caller, not that observer scalar. Probe reads real Gate status and successfully updates the lease from its own worker PID, proving real lease ownership. It then blocks in application callback code without owner/Gate DOWN receive clauses, lifecycle flag changes or helper actors. Killing it cannot be justified by application monitor polling. No claim covers hostile callback process-flag/link manipulation.

W=100000 is a requested core API byte value used to test exact reservation/subtraction, not an invented native constructor maximum or a qualification of actual A/J/N/W. Native production W still needs its complete actual-source constructor checkpoint before any changed-W spawn execution. The core scalar request is the already documented pre-admission control role; these fixtures do not establish total VM/native/allocator memory bounds.

Parent explicitly selected `{:error,:cancelled}` for the original spawn reply when cancel wins before activation, with `:ok` on the cancel alias. Parent will add this finite atom to canonical constructor maxima before that checkpoint. This proposal makes one exact assertion, not an accepted-result union.

D is an integer absolute monotonic deadline. It may be negative. Validation is remaining(D)>0 / D>Lifecycle.now(), never D>0. A live negative-D acceptance test asserts the qualified environment actually supplies negative monotonic values and preserves that exact D through callback/ordinary lease. Signed ETF tests cover negative SMALL_INTEGER/INTEGER/BIG boundaries independently. The two `native_worker_constructor` tags execute no admitted spawn: API arities and pure signed ETF cases only.

## Deterministic fixtures and accepted evidence

Each test gets an isolated real Gate from an independently spawned actual OTP start_link parent. `scope.service_pid` deliberately names the test observer, a different process, so parent-normal/abnormal tests cannot accidentally validate a forged scope-parent assumption. A separate untrapped actor owns the real original Admission lease and both async aliases. Child-to-owner abnormal propagation preserves the existing native owner link contract; the child-crash sibling test uses a different owner and lease for the sibling. It asserts the exact first-worker status before creating the sibling, then exact joint status, without disabling assertions.

No-spawn refusals trace the real Gate with `:procs`. Once the reply/status boundary has executed, `:erlang.trace_delivered(gate)` makes the absence assertion deterministic for all prior Gate spawn events. The callback does not run, and bytes/slots remain exact. This complements the source gate requiring direct Gate primitive spawn; it is not an independent proof against an arbitrary hidden helper architecture. Tracing is test-scoped to the test tracer process.

Public `:sys.install/3` debug triggers run only inside these isolated test Gates. Qualified OTP `gen_server.erl:2390–2393,2570–2581` emits `{:in,message}` before callback dispatch and `{:noreply,actual_state}` after callback return; `sys.erl:690–724,876–902` documents installs/state/removal. The post-return trigger observes the actual complete Gate state with ordinary child lease/W/slot before the next activation callback, then waits for a test acknowledgement. It does not replace, fabricate or adjust Admission state. The observer cannot call public status while Gate is paused inside that trigger; it inspects the actual post-callback state snapshot instead. After release, the callback itself supplies public status and successful real owned update evidence.

For pending normal-stop/actual-parent tests, that trigger selectively holds the real already queued `{:activate_spawn,token}` continuation before acknowledging the boundary. A real system normal-stop or genuine parent EXIT is then queued and handled first. The held continuation is never replaced by a guessed private activation. This is deliberate test scheduling, not a production hook or an assertion that normal stop can preempt an earlier unpaused application message.

For terminal order coverage, the trigger pauses on an ordinary status request while the real child exits. It collects the actual child linked EXIT and actual Gate-monitor DOWN with their original PID/ref/reason. It requeues these two unmodified messages in the selected order, withholding the second until the first callback's real post-return state is observed. Both EXIT-first and DOWN-first must retain the SAME ordinary child lease and its current W+B. Releasing the second must produce one exact refund. Replaying the captured normal terminal envelopes cannot subtract twice. There is no synthetic DOWN, injected guessed monitor, fake death, state replacement or uncharged tombstone. The extra debugger custody is test scheduling and does not qualify production row multiplicities.

All waits use a finite original deadline or an explicit 2000ms fixture limit. State/message barriers use bounded public status/process-info polling without sleeps. Real watchdog test waits for its real 1000ms expiry and actual :killed DOWN; it injects no timer envelope. Every required product termination observes actual monitors; each remaining test-owned actor has finite monitored failure cleanup. Failure cleanup may force-kill fixtures and is never counted as successful product stop/drain. No other process, user's runtime or global tracing flag is touched. No actor was actually started by this source-only assignment.

## Proposed cases and later commands

The file contains 26 test declarations, expanding to an expected 34 tests (2 constructor-only, 32 core runtime). This count is source-derived and must be checked against the real ExUnit receipt; zero were executed here.

- Byte limit W-1/no spawn versus exact W, real committed child lease/slot and real callback-owned update.
- Active limit, authentic owner mismatch, paused/draining/failed modes, expired D, non-scalar MFA, and unauthorized cancel.
- Signed negative live D, full original deadline, wrong activation ref and one actual Gate activation send.
- Original owner normal/abnormal death queued before callback, after known spawn before PID receipt, and while endpoint is blocked.
- Actual OTP parent normal/abnormal death both pending and already endpoint-blocked; scope PID deliberately differs.
- Gate :kill both pending and endpoint-blocked, normal stop both pending and endpoint-blocked, and the real finite request watchdog.
- One child's abnormal exit preserves shared Gate and different owner/sibling; unknown non-parent normal versus abnormal link policy.
- Both genuine terminal EXIT/DOWN orders with W+37001 current bytes, exact retention after first event, one refund after pair and duplicate normal envelopes.
- Same-sender queued spawn/cancel ordering and exact cancellation replies; alias retirement is local and later cancel still joins known child.

Before adoption parent must source-review the fixture against the implemented bootstrap/control constructors and charged-role table. A constructor change reopens the source checkpoint. Initial execution against baseline will chiefly show missing-API RED; it must not be labeled behavioral reproduction. Actual meaningful Gate behavior requires the implemented direct-spawn path, after independent source SPEC→CODE authorization for first changed-W consumption.

Planned commands, NOT RUN:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --only native_worker_constructor apps/gaoxy/test/admitted_spawn_test.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy/test/admitted_spawn_test.exs
```

The first should select exactly 2 non-spawn tests with excluded cases reported separately; the second should execute all34, zero skips/exclusions/warnings/failures. Neither expectation is an observed result. Original assertions, existing Admission compatibility tests, native protocol/peer/browser gates and final independent review remain required. This source proposal does not replace them. Parent alone owns repository adoption, actual RED/readiness/runtime evidence and Git. No external permissions, architecture decision or model escalation is needed to deliver this proposal.
