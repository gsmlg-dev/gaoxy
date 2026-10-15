# Managed H2 group queued-terminal open/bind control

Status: IMPLEMENTED, original FULL implementation SPEC47/47 and CODE48/48 PASS. The retained fresh compatibility603/1 failure led to fixture repairSol1. Complete repaired initial gates PASS on99 stable inputs: Python11/0, affected fixture97/0, format/forced strict compile, pure452/0 and compatibility603/0. Independent repair SPEC/CODE, fresh gates and commit remain pending. Predecessor startup catalog is DONE locally at `b30bdb0dcbdd3bc33b3b8e06a6f691e3584e42f1`. No new reserve/activation/publication authorization follows.

The accepted opening design explicitly leaves a continuation/mailbox gap: GenServer handle_continue runs before queued ordinary messages. Session currently checks state flags and absolute deadlines but can overtake queued terminal control in both `:group_open` and `{:group_bind,upload}`. The literal accounting denial currently prevents H2 group open; this is a staged behavior dependency, not a claim of an existing live Fetch race. Probe already has its own guard and remains unchanged.

## Finite behavior and implementation choice

For a well-formed staged managed-H2 group Session, each real open/bind continuation must check for at most one already pending recognized terminal event before the group open or the first owner bind/ready notification. Use one explicit private selective receive with after0, no recursion, mailbox drain, new process, timer or configurable callback. The helper is called only by these two group continuations after their existing source-specific staged/bind-carrier shape checks. It returns `:clear` on no recognized event or a tagged existing callback result on one recognized event. No new public helper/API is necessary.

On a recognized event, drop opening aliases with the existing `drop_group_opening/1`, then dispatch to the EXISTING matching handle_cast/handle_info handler and return that callback result unchanged. This preserves exact cancel/consumed/timeout/cleanup behavior and health semantics without inventing a uniform error or new cleanup protocol. In particular consumed keeps existing consumed/success semantics; cancel and authenticated DOWN keep cancellation semantics; ordinary timeout handlers retain their current stage-specific outcome and notification. A terminal callback result carries no new group continuation. Preserve original request/completion, selection/transport tokens, pins, monitors and cleanup authority for existing settlement; dropping payload is no refund. No promise of successful owner cleanup follows from modeled callback tests.

With no recognized event, preserve the state byte-for-byte and continue existing validation/deadline/activation behavior. Compute current time after the mailbox check, then compare original absolute total/open deadlines and derive remaining time; never extend either deadline. The only H2 group open stays dominated by the unchanged literal `ManagedH2GroupBoundary.activation/0` denial. The bind continuation checks before its FIRST owner bind and ready notification, retains the original captured request/completion and never reopens/replays. No group Options/admission/resource authority change.

| Already queued control | Exact matching and existing handler |
| --- | --- |
| Public cancel/expire/consumed casts | Exact `{:"$gen_cast",:cancel|:expire|:consumed}`, dispatch corresponding handle_cast |
| Service cleanup cancel | Exact `{:gaoxy_cleanup_cancel,token,reason,deadline}`, token===state.token and signed64 integer deadline, same H2 guard as ordinary handler; dispatch existing handle_info, raw reason is discarded |
| Monitored DOWN | Exact `{:DOWN,ref,:process,pid,reason}`, BOTH ref in state.monitors and stored PID===pid; dispatch existing handle_info, raw reason discarded |
| Opening/total expiry | Exact :opening_expired/:total_expired, same ordinary timer message authority and handler |

Wrong token/reference/PID, malformed/out-of-range cleanup deadlines and unrelated messages remain pending. Use receive guards for exact identity/finite deadline checks; do not consume then reject unmatched traffic. The first matching message in mailbox order wins; later recognized messages stay pending. No invented stronger authentication for bare timer atoms. State already cancelled/consumed or elapsed original deadlines still terminates through existing local checks.

This is a finite message-schema/transition claim. It establishes no mailbox-size/scan-time bound, atomic cross-process cancellation barrier, VM/native/private memory bound or guarantee for events arriving after the check. The after0 receive does not make mailbox scan constant-time. No replacement proof for dismissed http_fetch#97 is required. Separate G/T ledgers need no strict cross-owner refund order; no new helper-through-exit contract is adopted.

## Tests and acceptance

Use ONE complete new ExUnit file and real pure preparation/group_open_result to build well-formed staged open/bind state. Source callbacks may be invoked directly in the test process with clearly labeled structural fixtures and cleanup token=nil, so terminal settlement takes the existing unactivated path. Those handles/selection tokens are structural identities and grant no owner authority. Never start Fake Fetch, override activation/client, fabricate owner replies or claim live cleanup/no-network causality under the denied gate.

For both http2 and h2c and BOTH real continuations, queue each recognized event before invoking the callback; assert event consumption, exact returned callback shape/flags/outcome and error/no-error notifications, no continuation/ready, payload drop, unchanged original handle/completion and cleanup identities/deadlines. Derive expected semantics independently from existing ordinary handlers: cancel and DOWN have no error notification; consumed returns consumed/success (token=nil yields noreply); expire emits timeout or request_timeout according to original deadline; opening_expired uses its stage-specific ordinary handler; total_expired emits request_timeout. Matching service cleanup cancellation retains supplied cleanup-request deadline without extending total/open deadlines. Raw function/large reasons are never called or retained.

Test unrelated sentinel before recognized control and two recognized controls: only first matching event consumed; unrelated/later event remains. Test wrong token/ref/PID and malformed cleanup deadlines before a real recognized event at both stages, and alone at the open stage (gate remains unavailable). No-message open callback retains gate-denied behavior. For no-message bind, source review confirms :clear reaches the unchanged owner bind; do not fake owner authority just to run this branch. Existing real group/transport tests supply actual owner compatibility. Use finite exact assert_receive/refute_receive and deterministic setup; no arbitrary sleeps. Clean test-owned timers/messages in baseline RED as needed without masking failures.

Complete behavior RED must run before Session edits. Expected assertion failures are queued controls not consumed/ordinary terminal state not selected; known no-message/denial baselines may pass. Syntax, fixture exceptions, self-call crashes, zero tests or warning failures do not authenticate the intended RED. Retain all failures and root-authenticate each actual failing test. No missing-helper public API is required.

After implementation and complete initial GREEN, independent FULL SPEC then CODE checks real helper dominance before open/first bind, no bypass, exact queue matching, existing-handler semantics/custody, fresh absolute deadlines and unchanged gate. Then fresh full scoped gates, documentation-only rebind if needed, byte audit and local conventional commit. Current result is QUEUED_PREOPEN_CONTROL_IMPLEMENTED_GATED, not live group activation or no-Fetch acceptance. Later accounted activation still requires real peers/browser and lifecycle acceptance. Fixed reserve9444956/ACCOUNTING_NOT_READY and all prior counters/Astra2/2 exhausted remain.

## Necessary compatibility fixture repair

The retained fresh failure occurs in the existing real h2c peer's startup,
before instance/Session creation. Source diagnosis establishes unconditional
two-RSA-key TLS provisioning inside a five-second readiness wait, despite its
own twenty-second preparation allowance. It also establishes cleanup registration
after readiness, unobserved collector failure and unsafe partial-start cleanup.
The original log does not establish which operation consumed those five seconds;
controlled reproduction must remain distinct from that historical incident.

Keep Session and its198 tests unchanged. Plaintext h2c must perform no TLS-only
PKI work. Retain the ready schema's ca/cert/key keys and report their values,
certificate digest and OpenSSL command metadata as JSON null (not omitted).
TLS keeps the existing certificate script, profiles and validation. Charge all
TLS subprocess work, including OpenSSL version metadata, to one original
twenty-second preparation deadline, with bounded two-second TERM/two-second KILL
cleanup. The fixture's preparation handoff wait is twenty-five seconds to cover
that work, cleanup and diagnostics. Separate it from the unchanged five-second listener-ready
handshake; the fixture may use an explicit staged-start handshake while ordinary
qualification callers retain automatic startup. Register cleanup before startup
waits, monitor the caller/collector, and propagate primary startup/collector
diagnostics. Stop, EOF and preparation timeout must join owned subprocesses and
remove their owned temporary files; Python stop must be safe before a listener
or acceptor exists. No retry, generic readiness-timeout increase, assertion
weakening, production workaround or new protocol-success claim is authorized
by this fixture repair.

Write real-peer regressions before the repair: h2c without OpenSSL and actual
HTTP/2 exchange/join; staged TLS preparation/listener separation and actual TLS
exchange; deterministic blocked preparation cancellation/timeout and early error
cleanup; collector-DOWN diagnostics. Use finite barriers and process identities,
not arbitrary sleeps. Keep the failed603/1 receipt immutable. Run the full affected
fixture consumers and original452/603 gates, independent repair SPEC/CODE, then
fresh complete gates before local commit. Additional fixture/test source paths
enter a versioned runner/candidate; the original runner/candidate is immutable.

RepairSol1 now implements that contract. Its collector exception path attempts
stop and independently observes owned port exit before re-raising the original
exception; a cleanup failure is recorded separately. Timeout disposal alone
does not count as joined. Session and198 tests are byte-identical;46 other
existing test files and the entire fixed-endpoint fixture suffix from no_event
through existing tests remain byte-identical. The first draft's collector-failure
gap was corrected before adoption/runtime, with both author versions retained.
