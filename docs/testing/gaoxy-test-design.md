# Gaoxy.Test design and frozen implementation contracts

## Scope and source

Implement all phases of `docs/plans/gaoxy-test.md`. Work began from main
`656dbf5bb84564adc6a4d68247c0ad2fe52c2625` (0.7.0). The checkout initially had
only the user-provided untracked plan. No worktree, reset, or dependency source
patch is required. Existing specialist qualification exclusions remain intact.

On resumption the remote had advanced to
`32933790457bcfa3533e40dc2ae4d51ad91aa86d` (0.8.0). The local checkout was
fast-forwarded to that commit after preserving task-owned changes in
`.audit/gaoxy-test/integration-before-upstream.patch`; overlapping integration
edits were reapplied explicitly. No reset, stash, history rewrite, branch or
worktree was used. New activation, ListenerSet, Gateway and deadline fixes are
retained. The final release version will be selected after independent review.

## Public contract

`Gaoxy.Test.open/1` defaults to automatic per-test ExUnit ownership; `mode:
:manual` never starts ExUnit. The opaque handle identifies one temporary
application-supervised coordinator, never a reusable registered name. Public
functions are `url/2` (default `/`), `info/1`, `expect/5` (default options),
`expect_once/4`, `stub/4`, `requests/1`, `await_request/3`, `verify!/2`,
`verify_and_close!/2`, and `close/2` (default options). Registration returns
`:ok`; URL returns a string; info and journal return maps; waiting returns
`{:ok, entry}` or `{:error, :timeout}`. Closing returns a report map with
`:status` (`:ok` or `:error`), `:failures`, and verification accounting.
Verification returns `:ok` or raises; expired/unavailable state always fails.

Exact routes are unique, methods normalized uppercase, paths exclude queries.
Default expectations require at least one admission, `times` positive exact,
stubs unrestricted. Atomic pure reservation precedes callbacks. Journals are
bounded independently of durable accounting. Callback failures retain the
original exception, kind, and stacktrace. A single original failure is reraised;
aggregate failures identify request and route. Snapshot verification includes
only callbacks admitted at its snapshot, without waiving later final checks.

## Internal ownership and shared interfaces

- Core owns `Gaoxy.Test`, `Handle`, `Application`, `Expectations`, `Instance`,
  `DispatchPlug`, `ExUnit`, exceptions, manifest, and core/lifecycle tests.
- Protocols owns `Gaoxy.Test.Server`, `Response`, `SSE`, `WebSocket`, packaged
  TLS assets, and protocol/helper tests. No edits to core-owned files.
- Integration owns external consumer projects, scripts, CI/release staging,
  repository docs, version alignment, and acceptance evidence.

`Server.start_link(coordinator, options)` returns `{:ok, server_pid}` only when
ready. Options include `:profile` (default `:http1`) and `:fixture_id` reference.
The bridge Plug is `{Gaoxy.Test.DispatchPlug, {coordinator, fixture_id}}`.
`Server.info(server_pid)` returns selected profile, bound endpoint/URL,
capabilities and TLS trust (`:cacertfile` when TLS). `Server.close(pid, timeout)`
returns `:ok` or an explicit cleanup error and shuts down owned resources using
public Gaoxy APIs. Its ownership guard monitors the coordinator and cleans up
even on abrupt coordinator death. No profile fallback or compile-time H3
struct/module requirement is permitted.

The info map keys are `:profile`, `:url` (base URL), `:endpoints`, `:ready`,
`:capabilities`, and `:tls` (nil or a map containing `:cacertfile`). Endpoint
discovery uses the actual `Gaoxy.info(runtime, service_id).local`, not configured
port zero. The coordinator adds opaque fixture identity to the public info.

Initial public option defaults: `mode: :auto`, `profile: :http1`,
`timeout: 5_000`, `retention: 60_000`, `journal_limit: 100`, and
`capture_body: false`. Body capture may instead be a positive byte limit and
must not change the callback's normal body-read contract. Terminal/verification
options accept `:timeout`; all supplied bounds must be finite positive integers.
Await matchers are maps with `:method`, `:path`, and optional `:after` cursor.
Journal shape is `%{entries: [...], truncated: boolean, dropped: count,
cursor: integer}`; entries have monotonic `:id`, method/path, headers, protocol,
outcome and helper events. Full request-body capture is explicitly marked when
truncated. No user matcher predicate executes in the coordinator.

Dispatch sets `conn.private[:gaoxy_test]` to
`%{instance: coordinator, request_id: id}` before executing the callback.
`Instance.event(coordinator, request_id, event)` records helper observation;
`Instance.establish(coordinator, request_id, session_pid)` synchronously declares
an established persistent helper session. Helpers never mark arbitrary ordinary
callbacks persistent. Helpers expose finite streaming and SSE; persistent SSE
and WS sessions are cancellable only after establishment. Dispatch reports
outcomes before returning. Session observations remain distinct from terminal
outcomes. Helper events are available through the bounded journal.

## Lifecycle invariants

An application-owned DynamicSupervisor starts no listener by itself. Instances
are temporary and monitor their owner. Test-supervised processes may terminate
before `on_exit`, but the coordinator/report survives. Hook registration failure
rolls startup back. Owner death and all terminal APIs join one sealed finalizer.
The coordinator continues receiving callback outcomes while shutdown runs in a
monitored worker. One absolute monotonic deadline bounds callback draining and
cleanup; ordinary unfinished callbacks fail. Cleanup failure is never success.
Retained reports last a finite configurable period, automatic hooks consume them,
and manual repeated close returns the same retained report. A lost coordinator
is an infrastructure error, not an empty restarted fixture.

## Protocol and packaging boundaries

Profiles: `:http1`, `:https`, `:h2c`, `:http2`, opt-in `:http3`. Certificates live
in package `priv` and use application-relative paths and verified localhost/IP
trust. WS is H1 only; extended CONNECT remains out of scope. Public unary Plug
callbacks preserve normal lazy body reads. Capture, when requested, is bounded
and visible. H2/H3 acceptance requires actual independent-peer traffic.

Runtime closure: `gaoxy_test -> gaoxy_http -> gaoxy`; optional `gaoxy_http3`.
No reverse dependency, proxy, standalone, HTTPFetch or WebSocket client package.
The standalone release explicitly excludes test infrastructure. External base,
H3, HTTPFetch and production consumers prove package boundaries independently.

The landed ListenerSet API is intended for reusable pure declarations and rejects
PID/reference/function values. This fixture's DispatchPlug carries its live
coordinator PID and per-instance reference, so it retains the documented public
`service_spec/1` and Gaoxy lifecycle APIs. Introducing an extra global lookup
only to force that declaration format would add ownership machinery without
benefiting a single selected-profile ephemeral fixture. This choice preserves
the newer public APIs and their invariants without modifying production layers.

## Execution record

| Task | Initial/current worker | Counters | State |
| --- | --- | --- | --- |
| GT-CORE | sol_worker / astra_worker recovery complete | Sol repairs2; Astra repairs3/max4; astra escalated once | Round3 canonical119/126, helper69 and browser8 PASS; no round4 started |
| GT-PROTOCOL | sol_worker / integrated Astra recovery complete | Sol repair1; integrated Astra repairs3/max4, no reset | Review fixes accepted; canonical compatibility and bounded browser selection verified |
| GT-INTEGRATE | coordinator | No escalation | Consumers, staging and CI integration in progress |

Validation proceeds from scoped pure/network/subprocess tests to isolated staged
consumers and existing curated release gates. Final independent read-only review
precedes aligned versions and fresh final verification. Publication evidence and
fresh Hex-only verification are recorded separately from local builds.

Dispatch on 2026-10-21 returned `Unknown model \`gpt-6.1-sol\` for spawn_agent`.
The service advertised `gpt-6-sol` but not the named role's configured model.
No worker was created; there is no competing writer or running worker command.
This was an environment/access blocker, not an implementation failure or Astra
admission gate. On 2026-10-22 the unchanged named-role dispatch succeeded:
core worker `01a15f7b-1283-7222-9770-7253bb67e7e3` and protocol worker
`01a15f7b-6453-7731-9bd3-a411e010407b`. The tool advertises the role's configured
`gpt-6.1-sol`/high runtime; no model override or role substitution was used.
Independent specification/code review remains required; this document does not
assert either review has passed.

### Bounded recovery admission — 2026-10-22

`ROUTE task=GT-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE`

`astra_gate=SOL_REPEATED_FAILURE`: Sol completed repair/validation round 1
(`.audit/gaoxy-test/core-repair1.log`, 60/61, exit 2) and round 2
(`.audit/gaoxy-test/core-repair2.log`, 60/61, exit 2). The final unresolved case is
`http2: abrupt coordinator death closes the listener and accepted sockets`:
socket receive returned `:timeout` instead of `:closed`/`:econnreset` after the
coordinator was killed. Normal session classification and setup-hook report proof
were repaired; all 35 core tests passed in round 2. The integrated acceptance
failure remains unresolved and is not relabeled as expected. Initial protocol
run was 21/26, exit 2, and its TLS-alert-drain repair passed the first joint run
but not the second. Preserve all counters; no new task name resets this budget.

The predecessor reported all commands finished and writes stopped and was closed
before specialist dispatch. Recovery scope is the existing core/protocol
ownership/lifecycle acceptance, with at most two Astra repair/validation rounds.
Preserve original assertions/deadlines, identify fixture versus product versus
dependency behavior from concrete evidence, and follow upstream issue routing
for dependency blockers. No changes to publication permissions or product scope.

### Independent review — development snapshot

The integration review found two P2 issues: local consumer `--version` could
mislabel source, and the missing-H3 consumer did not compare resource allocations.
The runner now rejects a local version mismatch before staging, and the base
consumer compares fixture children and live fixture/runtime resources before and
after failed H3 startup. The revised base consumer passed all three ExUnit cases,
manual mode and actual production release exclusion; final aligned-source evidence
remains pending.

Core reviewer `01a15f7b-6453-7731-9bd3-a411e010407b` independently reviewed the
facade, pure ledger, coordinator, dispatch, ExUnit adapter, manifest and core tests.
It found a P1 report-freezing race: cleanup could finish before an established
session's failure message arrived. Closed-state handling then discarded the late
event or abnormal monitor result. An isolated actual-handler harness established
and completed a WS reservation, delivered cleanup success, then session failure;
the retained report incorrectly remained `status: :ok`, `failures: []`. This
establishes the handler-order defect, without claiming a reproduced wire schedule.
The finding and missing regression were handed to the current Astra recovery
writer within the same cumulative budget. No further core findings were
established. The reviewer made no file changes, used no shared build, finished its
commands and was closed. This is not final acceptance.

`ROUTE task=GT-PROTOCOL-REVIEW agent=sol_worker reason=independent_protocol_review`

Protocol reviewer `01a15f99-a915-78a0-b348-8aabd71e194c` has read-only ownership
of an independent review of Server/Response/SSE/WebSocket, TLS assets and protocol
tests. It did not author those files and must not take recovery writes or the
shared build slot. Review counters are zero; the original GT-CORE Sol2/Astra0
dispatch and GT-PROTOCOL Sol1 counters remain unchanged.

The protocol review completed with three actionable findings, all transferred to
the existing Astra recovery before its repair validation:

- P1: WS lifetime expiry could skip the termination callback under an expired
  transport deadline and then pass verification as normal local closure. A real
  socket probe with `max_lifetime: 100` observed only establishment, normal-looking
  session DOWN, successful verification while open, and an empty final report.
- P2: SSE checked its absolute deadline only through `receive ... after`, so queued
  messages, including normal finish, could bypass expiry. An actual-source harness
  with stubbed transport queued 100,000 events and finish; a one-millisecond
  lifetime returned normally after nine milliseconds. This is deadline-logic
  evidence, not a wire-protocol acceptance run.
- P2: bare WS TCP EOF was accepted as normal `:remote` termination. A real socket
  probe without a close frame returned successful verification and no failures.
  The existing public optional `gaoxy_close/2` callback can distinguish a received
  close handshake from an abrupt disconnect.

TLS chain/server-purpose and hostname/IP checks passed; leaf/key public-key hashes
matched. No additional Server/Response findings were established. The reviewer
performed no writes, builds or dependency mutations and finished its commands
before closure. Review acceptance remains pending fixes and fresh evidence.

### Independent recovery resolution review

The same independent protocol reviewer resumed for bounded read-only resolution
review after Astra round1. It found no new actionable issue and accepted all four
review fixes and the narrow production shutdown change. Independent build-free
execution passed all four recovery regressions, both WS probes now fail
verification as required, and the actual-source queued SSE harness raises at its
one-millisecond lifetime. No root build, source edit or dependency mutation was
performed; all commands finished before the reviewer was closed again.

The production fix suspends stream acceptance, then authenticates the active drain
helper's request to retain a second descendant/monitor snapshot before supervisor
unlinking. It preserves the existing absolute deadline and cleanup-error handling.
The teardown probe now retries transient connection resets but still requires
connection refusal within the same seven-second deadline. The reviewer accepted
this as preserving the original assertion. Fresh aggregate and OpenSSL3 production
verification remain required; Astra round1 is used and round2 is pending.

Astra round2 subsequently passed all69 package tests and all47 scoped production
lifecycle tests with OpenSSL3, seed457284, exit0. Canonical formatting and diff
checks passed. The worker reported all commands finished and writes stopped,
returned the root Mix slot and was closed. Cumulative counters remain Sol2/Astra2;
there is no remaining recovery budget for this task without explicit extension.

Only after that handoff was the source reconciled with remote0.9.0 commit
`044e1cd90ddf4cc1550df99411f2906209387f5f`, preserving its stream lifetime,
Phoenix migration, shutdown and certificate changes plus all task edits. The
versioned target is now0.10.0. Those newer sources require fresh acceptance;
earlier passing evidence retains its actual0.8.0 scope.

### Final-source blocker after budget exhaustion

Independent final reconciliation review accepted the unchanged production fix,
preserved0.9.0 contracts/gates and aligned0.10.0 package metadata. Fresh staging10,
all extracted consumers7, upstream internal regressions46 and canonical
composition58 passed. The local full curated run retained the old Linux-specific
alternate-loopback failure; Elixir1.20 composition retained an unchanged test type
warning. Both remain visible separately from implementation failures.

The final canonical1.18.5 package/production/remainder command executed119 tests
with zero assertion failures but exited1 on task-owned protocol-test constant
comparison warnings at lines169/186/201. The existing browser release suite also
failed at H3 LiveView connection after independent H1/H2/H3 and H2 browser/reload
checks passed; its cause remains unknown. These do not satisfy final acceptance.

The original two-round Astra budget was exhausted at Sol2/Astra2. All workers
were closed and commands finished at that handoff. On 2026-10-22 the user explicitly
authorized “不行可以使用 astra worker, 最多4轮”: the cumulative Astra maximum is now
four, with two used and two remaining. This is an explicit budget extension for
the same GT-CORE recovery, not a counter reset or a new escalation.

`ROUTE task=GT-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE`

Task record: initial_worker=sol_worker; current_worker=astra_worker;
sol_escalated=false; astra_escalated=true; sol_repair_rounds=2;
astra_repair_rounds=2; astra_max_rounds=4; astra_gate=SOL_REPEATED_FAILURE.
The original failed Sol checks above remain the admission evidence. Resume the
same worker with exclusive recovery writes and root Mix build ownership. The
bounded correction preserves profile assertions and protocol coverage, followed
by unchanged canonical gates and H3 browser diagnosis. See
`docs/acceptance/gaoxy-test.md` and archived final logs for handoff evidence.

`ROUTE task=GT-FINAL-SPEC-REVIEW agent=sol_worker reason=independent_specification_acceptance_review`

The existing independent reviewer resumes read-only to reconcile the complete
A01–A20 contract against implementation, external consumers and release gates.
It owns no edits or root build slot; Astra retains recovery ownership. Known
canonical warnings and local H3 browser failures remain explicit pending checks.

The independent reviewer accepted the Phase 0 contract and found no new actionable
implementation or CI/release issue across A01–A20. Its read-only AST comparison
confirmed all 15 browser-suite assertions are identical to baseline; the explicit
browser override preserves default selection and records browser identity. It
also checked aligned 0.10.0 manifests, unchanged Abyss 0.9.0 and retained upstream
gates. Phase 5 still requires fresh canonical/browser, actual standalone,
hosted-source and published-consumer evidence. All review commands finished and
the reviewer was closed; no repair counter changed.

Authorized round3 subsequently passed canonical119/119, expanded126/126,
exact-helper69/69, browser8/8 and formatting, all exit0. Only protocol-test
predicates, explicit browser selection/reporting and its documentation changed;
no production source changed. Cumulative counters are Sol2/Astra3, with one
authorized Astra round remaining and no round4 started. All worker commands
finished and both workers were closed before final integration.

The coordinator then verified zero incoming/task path collisions and directly
fast-forwarded to `6c82d5be5dd10a1cf96343113addbc926bfacb5c`, preserving the task
diff. Incoming changes affect only two stream-shutdown contract tests and 0.9.0
publication evidence. Runtime/package payloads are unchanged; the affected
upstream issue gate receives fresh verification. See the acceptance record for
browser comparison limits and exact archived handoff commands.
