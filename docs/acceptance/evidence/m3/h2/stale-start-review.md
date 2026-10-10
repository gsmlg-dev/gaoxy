# H2 stale admission-start receipt independent regression

Task `/root/upstream_cleanup`, independent S3 regression assignment,
2026-10-10. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`,
branch `codex/m3-gateway`, baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus preserved shared M3 changes.
Parent froze production and granted this fixture an exclusive Mix window.
Ownership: new `apps/gaoxy_http/test/http2_stale_start_test.exs` and this review
plus `stale-start-red.log`. No existing test or production file was edited.

## Finding S3 confirmed

`Gaoxy.HTTP.HTTP2.Connection.message/2` handles
`{:h2_stream_failed, _, id, _, _}` without checking the worker, token or whether
that stream is the current starter. It unconditionally sets `starting: nil`,
then resets the supplied stream and starts the next queued worker. In contrast,
the ready/done handlers match the recorded worker and token, and the monitored
worker DOWN handler clears `starting` only when its own stream matches.

A receipt for a canceled old starter can therefore clear the newer starter's
serialization slot and start another worker while the newer worker remains
blocked in admission. It can also enqueue an extra reset for the canceled ID.
The finding is in Gaoxy's owner-message lifecycle, not a dependency issue.

The fixture uses the public Gaoxy H2 listener and a real loopback socket. Stream
1 returns its exact `/seed` body and reports the native owner PID and gate from
the endpoint exchange. After its stream record disappears, local-test
`:sys.suspend(gate)` holds admission. Stream 3 starts a real worker; bounded
owner-state observation captures that worker and its token. A real peer RST
cancels stream 3, then real HEADERS queue streams 5 and 7. Before injection, a
finite poll requires stream 3 absent, `starting == 5`, a real stream 5 worker
with no lease, and stream 7's worker exactly `nil`.

The fixture then sends one controlled late failure receipt using the captured
stream 3 identity. A subsequent `:sys.get_state(owner)` from the same test
sender is the message-processing barrier. The expected `starting == 5`
assertion fails with actual `7`. This confirms the owner accepts an obsolete
receipt and starts another queued worker. The receipt is a controlled
simulation of an already-sent legitimate failure delayed past peer reset; the
test does not claim to have naturally triggered that transport/scheduler race.
Its explicit `:controlled_late_receipt` tag and source comment retain this limit.
No private upstream pool/client API is read or used.

## Exact verification and outcome

From the worktree root:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' sh -c 'mix format apps/gaoxy_http/test/http2_stale_start_test.exs && unbuffer mix test apps/gaoxy_http/test/http2_stale_start_test.exs --warnings-as-errors --max-cases 1' > docs/acceptance/evidence/m3/h2/stale-start-red.log 2>&1
```

Actual expected TDD RED: 1 test executed, 1 failure, seed 90841, command exit 2.
Failure: `assert after_receipt.starting == 5`, left `7`, right `5`, fixture
line 52. The first run reached the intended production-state assertion;
fixture correction rounds: 0. This is not a passing implementation gate.

The fixture's `after` block executed even on red: it resumed the admission
gate, closed the client socket, and used finite polling to require public
`Gaoxy.status(server, :http)` fields `active: 0`, `retained_bytes: 0`, and
`cleanup_pending: 0`. It produced no cleanup failure that could mask the
assertion. Command session `65595` finished with exit 2 and the Mix window was
released to parent. Reviewer `git diff --check` completed with exit 0.

On a future green run the same fixture additionally requires stream 5's worker
unchanged, stream 7 still unstarted after stale receipt, then resumes admission
and collects both streams' exact status/body responses, rejecting every
unexpected RST_STREAM or GOAWAY. Those post-failure assertions are NOT RUN in
this red checkpoint; no sibling-success claim is made here.

SHA-256 at red checkpoint:

```text
8e89194bb94b5a4b8bebca9bf1c63e3f0dea70b5bb775d6a383f607fe249693f  apps/gaoxy_http/test/http2_stale_start_test.exs
b341034fa9aae491f22f0dc336bb21f354a12a2530897414c686a9151ca84967  apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex
b6bbfcf79f1b1dd81a3a67a8251b027ca3008b554d4fa37376993a91fe383cbe  apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex
```

## Handoff

Status: DONE for the independently requested red regression and source finding;
production repair and green verification remain parent-owned. Authenticate the
failure against the recorded worker/token and the current admission starter;
ignore canceled or stale receipts without clearing another starter or emitting
an obsolete reset. Parent must validate its own narrow production repair with
this fixture and the required existing H2 scope.

Counters: previous Task 5 worker Sol rounds remain 2 successful, behavioral
repairs 0, Astra 0. This new independent fixture has 0 correction rounds and
0 production repair rounds; it does not reset or increment the Task 5 counter.
All reviewer commands are finished. No commit, push or publication was made;
no user decision is needed. Full H2/M3/RFC acceptance is outside this red
handoff, and naturally occurring late-delivery timing remains unqualified.

## Parent repair 10 narrow re-review

The historical red finding and evidence above remain unchanged. Parent repair
10 changes only the failure-receipt handler to match the recorded worker and
token, require its lease still `nil`, and require `state.starting == id` before
clearing/resetting that starter. Every canceled or mismatched receipt returns
the existing state, so it cannot start a new worker or emit a stale reset.
This matches the intended specification and adjacent identity-authenticated
owner-message pattern; narrow code-quality review has no actionable finding.

Freshly inspected `stale-start-repair10.log`: strict source compilation followed
by this regression and existing network/protocol scope executes 28 tests with
0 failures, seed 718263. Parent confirmed enclosing exit 0. The same unchanged
fixture now reaches its stream-5 worker identity, stream-7 unstarted, exact
sibling 200/body, unexpected-reset rejection, and zero-cleanup assertions.
Source SHA-256 after repair:
`7b697780bf886565cf9a84387bb0f70971aa21624c580e47e62e4e04471ccd98`.
The fixture remains
`8e89194bb94b5a4b8bebca9bf1c63e3f0dea70b5bb775d6a383f607fe249693f`.

Status: PASS for narrow S3 production specification/quality re-review and its
fresh scoped green evidence. Parent owns any broader canonical verification;
this does not claim full H2 or natural scheduler-race acceptance. No worker
fixture correction or production repair occurred; previous counters remain.
