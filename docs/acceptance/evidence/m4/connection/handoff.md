# Bounded Task2 recovery handoff

Task ID `m4_task2_connection`; status **ESCALATE_TO_ASTRA**;
`astra_gate=SOL_REPEATED_FAILURE`. Direct Sol assignment, not a prior Astra
handoff. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m4-http3`, branch
`codex/m4-http3`, starting baseline `78de9d0f3bba5a4662717359438eb3d0853a79b4`.
Parent committed earlier slices; recheck HEAD/status and all input hashes before
recovery. Preserve all parallel/root/peer changes and unrelated root untracked
`gaoxy-m1.1-fix-prompt.md`. Root owns commits; this worker made none.

## Owned scope and current state

`apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex`,
`test/connection_test.exs`, `test/lifecycle_test.exs`, this Connection evidence,
and independent receipts `review/host-independent.md` and
`review/public-service-independent.md`. Other app source, Options, pure protocol,
public HTTP3 entrypoint/service tests, shared Plug guard, consumer and independent
peer are owned by parent or peer author; obtain ownership before editing them.

The current Connection implements fixture-only minimal GET/HEAD `/ok`, streaming
POST `/echo`, response trailers, CONNECT501; it invokes no arbitrary Endpoint or
Plug callback. It waits for authenticated `h3`, opens one local control stream,
uses only public Gaoxy QUIC operations, rotates finite stream turns, reserves
bounded input/output bytes, defers FIN through credited pure continuations,
retains original uncertain-operation deadlines, never blindly replays a ref,
normalizes raw public open-status handles, isolates local control events,
restores definitively admitted write quantum after small-window blocks, bounds
output owners separately from pure receive parsers, and bounds incomplete uni
work while keeping idle critical streams open.

Unit/build state: `repair2-units.log` **10 tests, 0 failures**, format command and
warnings-as-errors compile exit0. The independent peer reviewer accepted source
repairs but the full wire gate is FAIL; no DONE claim is made.

## Cumulative repair evidence

Task2 Sol repairs **2**, unsuccessful **2**; Astra recovery **0**. Do not reset
these counters under a new task name. Historical Task1/G0/stage counters remain
separate and preserved in their receipts.

- Initial expected red: missing Connection, 8 tests/8 failures. Initial unit
  implementation passed8 but had an unused variable warning.
- Expected local-control red: 9 tests/1 failure. Initial live expected red,
  `../minimal-red/run-1791779991925797916/`: control_open deadline_expired ->0x102;
  zero passing cases. Absolute monotonic D had been passed as a relative duration.
- Repair1: relative remaining deadlines, definite-block chunk shrink, local
  control-event isolation, uncertain-write input fence, incomplete-uni timer,
  warning cleanup. Fresh9unit tests and strict compile passed. Full wire
  `../minimal/run-1791780283838403213/` FAIL after3 raw PASS cases: tiny-window
  streaming POST timed out. Shrink-only quantum eventually became1 byte after
  transient empty credit and never recovered. Original runner summary0checks
  after mode failure is preserved; raw logs show3PASS, later runner fixes the
  accounting without rewriting history.
- Expected response-owner-limit red: 10 tests/1 failure.
- Repair2: grow quantum on admitted writes, unknown control-open setup fence,
  public raw-handle wrapping and provisional local-entry cleanup, separate8
  active response owner bound. Fresh10unit tests and strict compile passed.
  Full wire `../minimal/run-1791780656197652152/` FAIL after31 recorded PASS checks:
  duplicate pseudo-header stream case waits for BOTH RESET and STOP0x10e and
  expires its unchanged10-second peer deadline. Streaming311296bytes and
  uni-discard timeout5137ms/6000ms passed. Cancellation/listener shutdown modes
  were NOT RUN after that failure.

## Unresolved technical question / bounded recovery

Determine why the duplicate-pseudo request, already receive-FIN at the peer,
never yields the required exact scoped RESET+STOP pair. The pure parser tests
already return stream H3_MESSAGE_ERROR0x10e; ordinary and connection-scoped
malformed cases passed. Current cleanup executes RESET before STOP across turns.
A read-only hypothesis is that peer sender-FIN plus received RESET finishes its
QUIC stream before later STOP is observed. Also inspect unsolicited
`{:stopped,key,code}` / reset callbacks while cleanup is pending: they currently
call Protocol.reset and cancel again, which can replace original error/cancel
commands with a peer code. Actual reset/stop dictionaries for the failed run were
not logged, so do not present either hypothesis as confirmed.

Retain exact code/scope, sibling continuation and no-late-DATA assertions. Use
read-only instrumentation or independent peer evidence to determine whether
public host emitted both operations and whether event ordering or peer-finished
stream behavior explains the result. If a real listed-org dependency defect is
proved, follow upstream issue routing; do not implement a private workaround.
Otherwise perform a narrowly bounded cleanup/order correction with regression,
fresh10unit+strictbuild and full minimal independent wire gate, then independent
review. This is recovery after two failed full-gate rounds, not project redesign.
Another unrestricted Sol iteration would violate the assigned repair ceiling.

## Shutdown and permissions

All this worker's exec sessions finished. Both failed runner summaries confirm
`owned_children_exited: true`; peer author owns the final session receipt and
root Mix lock handoff. Source is frozen after repair2; no subsequent edit by this
worker. User authorizes continuing local implementation/repairs/docs/tests/review
and local commits. Publication/deployment/production credentials/data, public
management, Vault freezes and disabled release-artifact E2E remain restricted.
Do not revive dismissed http_fetch#97 or equivalent replacement gates.
