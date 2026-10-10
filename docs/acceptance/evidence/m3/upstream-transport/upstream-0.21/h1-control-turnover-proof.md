# Managed-H1 control turnover source investigation

Date: 2026-10-11 Asia/Shanghai. Task `M3-H1-P5-CONTROL-TURNOVER`, direct Sol
assignment. **TLS-dependent qualification BLOCKED_UPSTREAM** by
[http_fetch#95](https://github.com/gsmlg-dev/http_fetch/issues/95).
The bounded source investigation is complete; **full P5 is NOT ESTABLISHED**.
This report provides component ceilings and names the remaining consumption
conditions. It does not certify a scope byte budget, P0–P6 composition, managed
activation, complete M3, or arbitrary public-operation traffic.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`; starting HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Inspection handoff HEAD `7cabfb77f2e87ee23d7684c118d4206f17f4fd95` reflects
parent-authorized commits; the six recorded transport source identities and
four key input-report identities still match. Only this report and its
[JSON receipt](h1-control-turnover-proof.json) are owned by this assignment.
Parent/user edits and all other untracked evidence remain untouched.

## Boundary and method

Use the approved [accounting envelope](h1-accounting-architecture.md): `C=2`,
`R=32`, `P=0`, fixed H1, nil or one controlled upload PID, manual redirects,
no retry, one upload producer, one response reader, finite original deadline,
and one retirement initiation plus one abort escalation. These are controlled
profile premises, not guarantees for every PID or every legal public API use.
Private TLS allocations/queues are excluded under the reviewed reachable-owned
object boundary. Exposed delivery binaries, owned socket terms, monitors and
control objects remain included. Existing credit/parser/term lemmas and their
[independent review](h1-source-lemmas-independent-review.md) are inputs, not
reproved or independently certified by this investigator.

For every class, the potential is
`outstanding = emitted - consumed_or_flushed`. Count a recipient's termination
as release of its owned mailbox roots, distinct from successful consumption.
Include queued signals and in-flight/native metadata where they remain within
the ownership boundary. A per-attempt emission count becomes an arbitrary-history
ceiling only after proving that unresolved attempts/old generations retain
bounded credits. A finite map, synchronous call, timeout, mailbox scan, or
eventual scheduler progress alone does not supply that proof.

Plan executed: enumerate producers and release paths; check exact OTP timer,
monitor and call semantics; separate component ceilings from generation
barriers; record the upstream prerequisite; hash inputs and validate this
bounded report. No executable edits, VM/Mix tests, network operations, fixtures,
upstream mutations or subprocess delegation were performed in this assignment.

## Signal inventory and potentials

Source paths below are relative to the worktree; line references identify the
inspected pinned files. `κ` denotes distinct fixed-path resource registration
occurrences per attempt, excluding the blocked TLS independent registrations.
`G` denotes attempts still charged by a future all-attempt reservation, including
rejected and uncertain attempts. No value of `G` is certified here. `a` denotes
additional externally generated tracker aborts per attempt; it is a premise,
not a proposed quota or default. Component counts below include failure branches.

| Class and producer | Emission/credit fact | Consumption or flush barrier; remaining condition |
| --- | --- | --- |
| Scope setup/handle/snapshot/retire calls and replies | Open constructs one scope; handle retrieval once. Controlled retirement calls ≤2. Each call produces at most one ordinary reply. Snapshot uses finite timeout and may be repeated publicly. | Reply reception proves callback consumption; timeout only disables its reply alias. Public snapshot retries need a finite producer/outstanding-generation contract; bounded concurrent callers do not bound sequential timeout retries. `managed_transport.ex:93-155`, `scope.ex:54-80,114-117`. |
| Scope connect_start/track calls and replies | One connect_start per fresh dial; ≤κ track forwards per fixed attempt, deduplicated by resource identity. At most C stored connection tokens. | Calls serialize the issuing tracker/dial path. A deadline timeout can leave the original call queued. Slot reuse waits for done, nil socket, empty dial set and no associated resource metadata. Rejected/uncertain attempt retention and the old nonconnection-resource frontier still need proof. `scope.ex:83-111,234-246`; `request_lifecycle.ex:318-325`. |
| Scope connect_done cast | At most one per fresh dial attempt. | Consumed cast marks slot done; failed tracker DOWN also marks its slots done. A slot cannot prune until registered resources release. Cast lifetime/order against tracker DOWN needs to be composed with old-generation credits; C alone is not a queue ceiling. `dialer.ex:39-60`; `scope.ex:121-150,234-246`. |
| Scope tracker/resource DOWN | At most one terminal DOWN per monitor occurrence; resource registration deduplicates. Creator1 and child3 terminal DOWN are lifetime constants. | Active request ingress is released while consuming tracker DOWN. Scope resource metadata is removed while consuming its own DOWN. Tracker DOWN and scope resource DOWN come from separate monitor occurrences; request lease release does not itself consume all old scope resource controls. Connection slots retain associated resource metadata. `scope.ex:24,37,101-111,133-173,287-308`. |
| Tracker calls/replies | ≤κ+8≤17 fixed-path calls: registrations κ, bind_scope/bind_connector2, stream_ready≤2, handoff1, complete≤3. Some are mutually exclusive; this is a conservative ceiling. | Local infinity calls await reply; deadline calls may time out without target consumption. A fresh tracker belongs to one attempt and cannot inherit prior trackers' mailboxes. Aggregate ceilings require G retention through control release. `request_lifecycle.ex:23-27,53-64,88-94,99-162,184-243`. |
| Tracker complete/unconfirmed/launch_failed controls | Complete calls/casts ≤3, unconfirmed casts ≤2, launch_failed ≤1 per attempt; complete≤3 is already included in the call ceiling where applicable. | Task completion cast precedes its own terminal DOWN by same-sender ordering. DOWN removes the registered resource; tracker stops only sealed and resource map empty. These are per-attempt ceilings, not permission to double-count complete calls and casts as simultaneous disjoint maxima. `request_lifecycle.ex:57-64,237-249,262-292`. |
| Tracker abort and cancellation fanout | Internal aborts A≤8+a: task error1, owner failure1, dial stop1, scope cancellation1, deadline-call timeouts≤4. Repeated tracker abort is not coalesced. Cancellation invocations conservatively ≤κ(A+6)+2, hence128 at κ9/a0. | Each tracker consumes abort then fans out across its resource map; repeated aborts can repeat controls. Additional triggers are scope DOWN1, incomplete-role DOWN≤4, late already-aborted registration and stream_ready≤2. The formula counts cancellation invocations, including native close/exit operations, not only mailbox messages. External abort_and_await retries require the explicit a premise. `request_lifecycle.ex:150-162,195-201,228,252-287,328-348`; `request_completion.ex:92-99`. |
| Resource/launch/transfer results | One task launch; one owner launch; one dial launch/offer/transfer/result; one initial send-worker launch/result; PID upload adds one writer start/result and ≤2 attach request/ACK exchanges. Dial failure sends close_socket≤2. | Results or terminal DOWN release local helpers; launch and attachment monitors use demonitor flush. Writer result precedes writer exit. Socket ownership transfer is checked before reuse. All-attempt G and the blocked TLS termination prerequisite remain; no transfer is a private mailbox flush. `http.ex:336-389`; `socket_client.ex:45-74,1748-1794`; `dialer.ex:182-297`; `upload.ex:22-93`. |
| Owner deadline and receive waits | One owner deadline timer per fixed request; receive-after timeouts are not send_after timer messages. | Canceling the timer does not consume an already emitted :deadline. The short-lived owner cannot inherit previous owners' mailboxes, but native pending/cancel metadata still needs P2/P5 classification. `socket_client.ex:302-360,1573,1624`; OTP `erlang.erl:1468-1506`. |
| ACK/chunk/terminal stream edges | Each controlled ACK edge has bounded outstanding credit, independent of body length; no per-body lifetime emission ceiling is claimed. One controlled finish; bounded trailers/terminal sequence. | Producer advances after chunk ACK; upload writer ACKs after successful send. Apply the existing credit induction separately to producer→source→writer and owner→response→reader edges, including stop/error and terminal overlap. Arbitrary PID behavior or repeated direct post-done calls are outside the premise. `stream.ex:85-153,180-239,280-378`; `upload.ex:98-155`. |
| Scope :reconcile | Exactly one initial seed and each consumed tick schedules one successor: outstanding scheduled/unconsumed tick ≤1. | Successor is scheduled after receipt of the current message, before reconcile/settle work completes. This proves the tick class only; it does not bound work emitted by a callback. No guessed scheduler fairness is needed. `scope.ex:31,179-181`. |
| Scope retirement/:settle/pool :close_idle | Controlled seeds ≤2 public calls + creator DOWN1 + child DOWN3 =6. :settle outstanding≤6; close_idle per pool≤6. First transition into aborting cancels each occupied ingress lease at most once. close_resource invocations≤2 per registered resource occurrence. | :stopping retire is a no-op; cancellation CAS changes phase to :canceling before emitting one tracker abort. Later reconcile cannot emit endlessly for that lease. A resource is closed on abort entry or late registration, then at stopping. These ceilings rely on the two controlled public calls; unrestricted repeated retire calls are not coalesced. `scope.ex:110,114-117,133-173,186-218,330-341,378-387`. |
| Pool checkout/prepare/activate calls and replies | One checkout and, on successful return, prepare≤1/activate≤1 per fixed request; ≤3 calls per attempt. Stored entries≤C2. | Each ordinary callback consumes its call before reply. Call timeout5000 does not remove queued request. Nested SSL setopts/recv/transfer and tracker handoff can stall a callback while old calls remain queued. Thus Q_pool≤R is not proved from upstream ingress alone. `pool.ex:16-30,70-150`; OTP `gen.erl:239-282`. |
| Pool entry monitor DOWN | Pending token installs one owner monitor; activation/removal demonitor-flush it. ≤1 DOWN per occurrence. | OTP demonitor guarantees no future matching DOWN reaches the caller queue after return; [:flush] removes already queued matching DOWN. This closes the logical monitor-message residue for that occurrence, unlike cancel_timer. Deferred target-side monitor metadata needs separate P2 accounting. `pool.ex:83,101,173-177,205-215`; OTP `erlang.erl:1977-1984,2023-2036`. |
| Pool pending/idle timer expiries | One pending1000ms timer and at most one idle timer per token: ≤2 emitted {:expire,token} messages. Live entry timers≤C. | Expiry handler consumes even stale tokens; removal cancels the current timer. ≤2 per token does not bound arbitrarily many old tokens' emitted/in-flight expiries. Exact stale-generation frontier and native race window remain open, detailed below. `pool.ex:70-120,164-171,205-215`. |
| Pool socket events and ownership changes | Pool enables idle active:once; checkout makes passive, recv(0,0), scans queued events and transfers controlling process; recursion can inspect/discard≤C entries. | Generic gen_server receive consumes infos, including unknown socket messages. Scanning is not consumption. Old SSL terminal-signal qualification is stopped on #95. No claim that raw close, active:false or transfer drains all included old TLS signals. `pool.ex:103-120,129-150,180-191`; `ssl.ex:68-73`. |
| Pool copied mailbox snapshots | At most C snapshot constructions within one checkout callback, one per inspected entry, from Process.info(self(), :messages). | Each copy includes the entire mailbox present, including unrelated included control payloads. Before pricing C×snapshot(M), prove M and payload/backing bounds. Simultaneous snapshot/root overlap remains part of P4/P5; no zero cost or guessed fixed M. `pool.ex:129-150,189-191`; OTP `erl_bif_info.c`. |
| Receipt/request await monitors | One monitor per await invocation; repeated public waits are supported. | Each invocation receives matching DOWN or demonitor-flushes on return; receive-after polling creates no mailbox timer messages. Native monitor/demonitor signal metadata across sequential retries still needs a producer/barrier bound if included in scope ownership. No new waiter/default limit is proposed. `managed_transport.ex:148-190`; `request_completion.ex:81-89,109-134`. |
| AbortController Agent controls | One controlled controller may emit owner abort once at first abort, plus abort on a later set_request_id if already aborted. | Agent state coalesces repeated abort owner messages but not arbitrary Agent calls/reassignments. Agent caller controls and controller lifecycle need the chosen controlled protocol if used; no arbitrary public-use ceiling. `abort_controller.ex:104-136`. |

## Conditional resource and count derivation

Fixed-path roles are task, owner, dial, raw socket, initial send worker and final
response stream: six. PID upload adds source stream and upload writer: eight.
A standard from_enumerable stream may register one producer: `κ≤9`
(`stream.ex:180-183`). Some paths register fewer; nil upload omits the extra
roles. Starter and scope monitors overlap these roles and must be charged
separately. Resource kinds absent from this profile (H2 connection/bridge,
redirect/retry chains) are not silently assigned zero in other profiles.

The supplied PID must satisfy the controlled one-source/one-producer protocol.
The library accepts arbitrary PIDs; source inspection cannot turn that wider
API into κ≤9. Independent TLS resources are deliberately absent from these
conditional arithmetic counts because their registration is broken in the
installed cohort; this omission prevents whole-scope qualification.

Per-attempt call/control counts can give bounds such as `17G` tracker call
emissions and `3G` pool call emissions only if G counts every attempt whose
included controls survive. They are not evaluated byte budgets. In
`http.ex:308-390`, preparation may fail but a tracker/task is still constructed;
therefore R upstream ingress slots alone do not cap rejected-attempt objects.
The approved all-attempt reservation must begin before Fetch and keep uncertain
attempts charged until included controls are consumed, flushed or released.
Its enforcement and cross-generation composition remain P0/P5 obligations.

## Timer race and queue ordering

Pinned OTP public documentation states cancel_timer is synchronous by default
but false does not establish whether an expired timeout reached its destination
(`erlang.erl:1468-1506`). The timer service contains independently executing
entities with no total service-signal ordering guarantee
(`ref_man_processes.md:248-270`). Do not substitute same-sender ordering for
that service guarantee.

Exact native source confirms the gap: timeout callback atomically sets
TIMED_OUT before constructing/enqueuing the expiry (`erl_hl_timer.c:1089-1147`).
Cancellation succeeds only while ACTIVE (`1810-1849`); remote receiver-side
fast cancellation can return false in the intervening window (`2105-2136`).
Synchronous remote cancellation replies/traps (`2168-2259,2575-2578`) therefore
do not themselves acknowledge original expiry consumption. Message enqueue can
use offheap signal buffers (`erl_message.c:390-459,493-501`), partitioned by
sender hash and fetched/flushed through signal-queue code
(`erl_proc_sig_queue.c:1331-1348,10260-10289,10494-10549`).

The ordinary gen_server loop has a generic receive (`gen_server.erl:2320-2335`)
and the pool consumes unknown infos, so already queued expiries cannot be
selectively bypassed forever by ordinary later calls. That fact does not price
all pre-enqueue/native timeout windows or timed-out call generations while a
callback blocks. A useful remaining decomposition is live timer credits,
already queued generation frontier, and native expiry race window. A scheduler
concurrency parameter and callback non-yield window might close the latter,
but neither a fully certified cardinality nor a numeric ceiling was established
here. General timer/deferred cancellation metadata remains P2/P5 work.
No legal arbitrary-repeat native-retention counterexample was proved; an open
proof condition is not evidence of unbounded growth.

## Confirmed TLS prerequisite and stopped work

Installed `request_lifecycle.ex:29-42` matches only
`{:sslsocket, _, processes}` with a list in position3, otherwise returns :ok
without independently registering TLS processes. Pinned OTP `ssl_api.hrl:28-35`
defines seven record fields (tuple arity8); `tls_socket.erl:169-176` constructs
separate connection-handler and payload-sender fields. The installed header
matches pinned source SHA256
`410a6ae339a8578b097d3b0f8d883cdbb06b3a150740507b9be6c5ae0934b8d3`.

Parent-executed [repaired shape receipt](tls-socket-shape-repair1.json) and
[log](tls-socket-shape-repair1.log) record exit0, one verified public TLS1.3
loopback connection, actual tuple arity8, false legacy-pattern match, h2 ALPN,
joined peer and zero live peer threads. The use of h2 ALPN is only the shape
probe's independent peer protocol; it does not qualify H1. Its429 frozen source
identities are unchanged. The preserved [initial receipt](tls-socket-shape-probe.json)
records PARTIAL_SHAPE_CONFIRMED_PEER_ALPN_FAILURE; it is not a successful peer
qualification. Parent's diagnostic repair counters are one successful Sol
validation, zero unsuccessful repairs and zero Astra, separate from this task.
This investigation inspected/hashes those receipts and did not execute the VM.

Aggregate public scope snapshots expose only a resource count, not individual
kinds (`scope.ex:66-80`). Missing TLS registration follows the concrete source
match and shape receipt, not an inference from an aggregate count. Normal
scope slot/latch release checks registered resources only. Raw socket close or
SSL close reply cannot establish both independent worker DOWN barriers:
`ssl_gen_statem.erl:773-779` uses stop_and_reply;
`gen_statem.erl:4877-4897` replies before final termination; receiver/sender are
separate one_for_all supervised workers (`tls_dyn_connection_sup.erl:61-80`),
and sender reacts to later supervisor shutdown (`tls_sender.erl:536-537`).
Canceled-upload abort closes raw TCP first (`socket_client.ex:1878-1884`,
transport `ssl.ex:68-73`).

Parent created typed Bug, internal request, severity blocker
[http_fetch#95](https://github.com/gsmlg-dev/http_fetch/issues/95).
TLS independent termination and old TLS terminal-signal qualification stop
here until the upstream fix is published, installed and requalified. No private
flush, workaround, rotation, quota or dependency patch is added. The
[parent status refresh](upstream-status-refresh1.json) observes #95 open and
latest published release v0.21.0; #86/#87/#88/#89 closure does not change the
installed cohort or certify it. Full lifecycle-race execution remains NOT RUN.

## Verification and remaining conditions

Python recomputed all recorded input hashes, checked the six carried source
hashes and four key report hashes, compared the repaired diagnostic's complete
before/after snapshots, validated its log identity and concrete shape/peer
fields, and checked κ9/calls17/cancellation128/retirement6 arithmetic. The JSON
receipt stores all13 repository,17 OTP and17 evidence identities. Fresh final
validation rechecks those identities, JSON/schema fields, report hash, local
Markdown links/fences and whitespace. These are static evidence checks, not
runtime controls or independently reviewed full-P5 acceptance.

Remaining conditions are (1) fixed TLS tracking plus independent termination
barriers from #95; (2) all-attempt retention through rejected/uncertain control
release, including queued pool/scope calls and old resource DOWN; (3) exact
stale-token expiry and native cancellation frontier; (4) controlled budgets or
proved barriers for snapshot/await/abort retry producers; (5) mailbox payload
and simultaneous snapshot/root accounting; and (6) P2 runtime metadata/P4 phase
composition/P6 independent review. No numeric activation reservation is emitted.
Task repair counters Sol0, unsuccessful0, Astra0; no escalation gate used.
All this assignment's commands have completed; no child process remains.
