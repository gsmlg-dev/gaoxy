# M4 public Session consumer-affinity amendment

Architecture candidate, 2026-10-13. Task `/root/m4_session_affinity_design`;
`astra_gate: PROJECT_ARCHITECTURE`; `mode: architecture`. Independent Sol
specification and SDK/code review are pending. Runtime checks are **NOT RUN**
by this author; this amendment adds **0** Astra recovery rounds.

## Scope and precedence

Read with [the original Session design](m4-public-session-upstream.md) and
[original plan](../plans/m4-public-session-upstream.md), preserved byte-for-byte.
This amendment supersedes only their per-operation task lifetime, guardian-as-
consumer option, result-plus-task-DOWN scheduling rule, associated handle fields,
task accounting, and corresponding UP0/UP1 instructions. All other decisions
and acceptance gates remain required. Execute the
[task delta](../plans/m4-public-session-consumer-affinity.md) before resuming UP1.

Baseline: `codex/m4-http3`, HEAD `b43a8ebc06fb13caf62fa9320f039b8bdd446023`,
worktree `.trees/m4-http3`; installed coordinated seven-package cohort 0.21.4;
root lock SHA256 `aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
Exact source/document hashes belong to the accompanying candidate receipt.

## Evidence and choice

[Direct qualification](../acceptance/evidence/m4/upstream-contract/run-1791827038372979204/result.json)
failed at first real Session poll with `{:error, advanced_session, :not_consumer}`.
Its nine boundary-double passes and zero network passes are not qualification.
The [diagnosis receipt](../acceptance/evidence/m4/upstream-contract/session-consumer-affinity-diagnosis-1791827196294978658.json)
records the preceding compile failure and one unsuccessful Sol repair.

Installed `deps/elixir_quic/lib/quic/connection.ex` requires the events/read caller
to equal its attached consumer (lines 294–323, 375–376); consumer DOWN closes the
connection (637). `Transport.Quic.connect/3` retains the supplied consumer and
attaches it (transport `quic.ex:83–157`). Public Session does not expose a
consumer-transfer operation. Therefore fresh operation callers cannot implement
the original selected contract.

1. **Selected: one finite request-lived Session caller**, scheduled by the
   existing guardian. Set connect `consumer: self()` inside that caller. It
   remains alive between calls, including while downstream ACK or upload input
   is pending. This adds one bounded receive loop, not a pool or GenServer.
2. Run Session calls directly in the guardian: caller affinity works but native,
   DNS and query calls can block cancellation/deadlines; reject.
3. Reattach for every operation: requires private Session handle extraction and
   potentially a five-second blocking attach in the guardian; reject.

This is an application ownership correction, not evidence of a missing SDK API.
No dependency change, private Fetch inspection, wire encoding, issue97 proof or
native ledger is introduced. Further demonstrated public API gaps follow the
existing upstream routing policy.

## Processes and state ownership

The existing `Gaoxy.Proxy.HTTP.Session` guardian remains the sole scheduler,
deadline owner, adapter-state holder and Service completion reporter. The
downstream endpoint continues to own Exchange reads and Response writes.

| Process | Lifetime and authority |
| --- | --- |
| Bootstrap creator | Creates only the public endpoint, hands it to guardian, unlinks after adoption ACK, exits normally; never connects. |
| Stable caller | Starts only after successful adoption and bootstrap normal DOWN. Executes exactly the guardian's next public Session operation; lives until request cleanup. |
| Exceptional stop task | Calls public `Transport.Quic.stop_endpoint/1` independently of a blocked caller; reports full result and exits. |

All three are Gaoxy-owned, linked and monitored with distinct refs. The guardian
traps its owned link exits, handles monitor DOWN explicitly, and never treats a
link exit as a successful cleanup receipt. No replacement caller is started
after a caller crash. At most one Session operation is outstanding. Bootstrap
and caller do not overlap; one stop task may overlap either during teardown.

Each owned task also monitors the guardian from task entry, before allocation or
accepting commands. Match both that monitor ref and guardian PID. **Any matching
guardian DOWN, including `:normal`, ends command acceptance**; unrelated DOWNs
do not signal guardian loss. Ordinary links do not terminate a task on normal
guardian exit. The stable caller checks for this DOWN before each invocation,
after each public call and between hint-drain batches; once observed it discards
any result and exits without another Session operation or a completion claim.
An idle receive loop handles this DOWN directly, including while awaiting ACK
or upload input. Discarding `:quic_closed` must never discard this monitor signal.

Bootstrap checks the same monitor around client creation and while awaiting
adoption. On guardian loss it performs no connect or further adoption handshake:
if a descriptor exists, attempt its public bounded endpoint stop, then exit; if
none exists, exit without claiming confirmed cleanup. A stop task already owns
only one teardown operation: guardian loss does not cancel that obligation; it
finishes/attempts that public stop once, then exits without waiting for a guardian
ACK or sending a Service receipt. Both tasks consume their matching guardian DOWN
at their next receive boundary and have no surviving idle loop.

A monitor cannot interrupt a synchronous SDK/native/DNS call. DOWN handling may
wait for that call to return or hit its underlying transport/resolver timeout;
Session's admission deadline is not that wall-clock bound. Public QUIC query/
attach and endpoint-stop calls use finite timeouts (commonly 5,000 ms); DNS uses
the runtime resolver's own bounds, not a new five-second promise. On return the
task processes pending guardian DOWN before sending results or accepting work.
Meanwhile endpoint's independent acceptor monitor handles guardian loss without
waiting for the caller. Do not claim immediate caller death, a new request-wide
SDK bound, or Service completion. Qualification records actual task DOWN after
releasing a blocked-call barrier; an unreturned call remains unconfirmed.

Replace per-operation task metadata with `caller` PID/monitor/generation,
separate `bootstrap` and `stop_task` records, and `operation` command ref/kind/
original absolute deadline. Keep the original bounded Session, continuation,
events, delivery, upload waiter, endpoint descriptor/monitor and timers. No
dependency-private state is added.

Between operations the entire current Session belongs to the guardian. A
command contains request ID, caller generation, fresh command ref, allowlisted
operation, full latest Session, bounded arguments/options and original absolute
deadline. Only connect adds `consumer: self()` in the caller. The caller checks
the command correlation and remaining deadline before invocation, executes
exactly once, returns the **entire** public result with the same identifiers,
then forgets Session/arguments/result and waits. It does not choose, replay,
resume or poll autonomously; even `resume`, `suspend_blocked`, `ready`, `open`,
`close` and `abort` are guardian-selected commands.

The guardian accepts one matching result, stores every advanced Session before
choosing the next command, and clears the outstanding operation. **It does not
wait for caller DOWN between operations.** Results sent before a caller DOWN
may be observed first; the ensuing unexpected DOWN still fails the request.
Duplicate/stale results and commands cannot advance state. The old Session is
ineligible for reuse while a command is outstanding. After terminal cancellation,
a late result may be recorded for diagnostics but cannot restart work, acknowledge
an upload, emit success, extend deadlines or release a token.

An idle caller crash before connect has no connection but still requires retained
endpoint teardown. During/after connect, advanced admission may be lost: preserve
uncertainty and stop the endpoint, with no retry/reconstruction. Idle crash after
connect also fails the request even if no operation was outstanding; its consumer
monitor will close the connection, which is not an endpoint cleanup receipt.

## Bootstrap and cancellation races

Preserve the original explicit descriptor protocol: creator calls public
`client/1` with `acceptor: guardian_pid`; guardian records descriptor PID, links
and monitors it, then ACKs adoption. Creator unlinks only after that ACK and
exits normally. `Quic.public_opts/2` preserves explicit acceptor, and endpoint
acceptor DOWN stops it (`endpoint.ex:232–235`). This separates lifetime ownership
from the creator's start_link parent relationship.

Guardian must observe creator **normal DOWN before starting the caller**, recheck
terminal state/deadlines/endpoint DOWN, and qualify that the endpoint survives
creator exit. Real subsequent connect/open/request/poll establishes usability;
an `alive?` check alone does not. No connect occurs from bootstrap.

Before adoption, cancellation leaves creator responsible for confirmed stop/DOWN
or lets guardian adopt solely for teardown. ACK and cancellation crossing cannot
start a caller: guardian's terminal state wins. After ACK but before creator DOWN,
stop the retained endpoint and collect creator DOWN. After creator DOWN but before
caller launch, cancellation starts only teardown. Creator crash or lost descriptor
without no-allocation/stop evidence stays `cleanup_unconfirmed`. Do not infer
cleanup from creator DOWN, unlink or a failed connect. Preserve the original
link-coverage invariant and separately test creator failure around adoption.

## Public notifications and mailbox bounds

The installed public consumer surface sends `{:quic_ready, handle, metadata}` on
attach/first readiness (`connection.ex:268,1128`) and
`{:quic_closed, handle, reason}` on termination (1302). Stream/readable/writable
events stay in the dependency's bounded pull queue (`queue_event/2`); they are
not DATA messages sent to the caller.

The stable caller **consumes and discards these two notification shapes**, both
while idle and between commands, without storing/inspecting their handle or
forwarding their payload. They are optional hints, not Session state. The
guardian's existing single deduplicated 5 ms H3 tick drives authorized public
ready/poll/resume checks within unchanged deadlines. Closure becomes visible
through these public results or owned endpoint/caller DOWN; no immediate raw
closure hint is required for correctness. The caller has no polling timer.

Drain recognized hints before accepting the next operation, using bounded receive
batches of at most 16 and yielding to control messages between batches. Do not
selectively receive only commands and leave transport messages accumulating.
There is at most one queued command, one result and one stop control message for
this private caller protocol; unknown messages are discarded without logging
their contents or retaining a list. The matching guardian DOWN is a terminal
control message, never an unknown message or transport hint. No raw transport
payload reaches the guardian.
SDK attach can notify again on reconciliation, but each guardian-authorized
operation is separated by hint draining; first-ready and terminal-close each
occur once for this one connection. Qualification must measure supported-message
mailbox high-water at deterministic barriers, including repeated unknown-connect
reconciliation and paused ACK, and show no growth with payload size/operation
count. Arbitrary external BEAM-message injection is not a claimed mailbox bound.

The guardian has at most one tick, one correlated operation result and its existing
bounded adapter queue, not a notification queue. Keep the original reservation;
account for the bounded Session command/result copy without retaining historical
copies. This is an application bound, not a native/VM allocation claim.

## Cleanup and unchanged invariants

Normal consumption: command close when safely idle, preserve result, publicly
stop endpoint, observe normal endpoint DOWN, ask idle caller to exit, observe
all bootstrap/caller/stop task DOWNs, then allow Service completion. The caller
must not exit merely because response `:done` arrived; it remains available
until the guardian begins terminal teardown.

Cancellation/owner loss/deadline: mark terminal immediately and fail any waiter
once. Command abort only when the caller is safely idle; do not enqueue another
Session command behind a blocked call. Start independent endpoint stop promptly,
without waiting for abort or the outstanding operation. After endpoint DOWN,
terminate a still-blocked **owned caller** if necessary and observe DOWN.
Guardian loss uses the explicit per-task monitor contract above as well as links
and the endpoint acceptor monitor; this includes normal guardian exit. Service
accounting remains uncertain without its required guardian completion protocol,
even when an independent observer sees every task and endpoint terminate.

Cleanup succeeds only with the original public stop/monitored normal endpoint
DOWN evidence (or its already-observed normal-DOWN case), **and every owned
bootstrap/caller/stop task DOWN**. Caller exit does not imply endpoint exit;
consumer connection closure does not imply endpoint exit; `:noproc` stop success
without recorded normal DOWN does not suffice. Stop error, abnormal/missing DOWN
or exhausted original cleanup grace retains accounting uncertainty. Never kill
dependency processes to manufacture normal teardown. Independent known-port UDP
rebind and peer cancellation/sibling observations remain mandatory acceptance.

All original 16 KiB uploads/deliveries, one upload waiter/continuation, one
delivery per ACK, 262,144-byte/256-event queue, poll max16/batches1/paused refs,
stream/field limits and conservative reservation remain. Unknown operations only
resume their identity; definitely blocked upload uses suspend/poll/resume latest
Session; early final response discards continuation through public reset.
Trailers/end follow the last DATA ACK, zero-body trailers retain one FIN, and
original absolute opening/total/write/cleanup deadlines never restart.

Keep callback/API normalization, fixed authenticated HTTPS/H3 reverse origins,
H1 default and groups/forward behavior, core isolation, seven-package pins,
privacy/redacted receipts and Service token semantics. No pool, fallback, replay,
new feature, deployment or release-artifact E2E activation is authorized here.
UP0 direct Session, UP1, UP2 and standalone/browser/consumer acceptance remain
separate gates. Architecture completion does not pass any runtime gate.
