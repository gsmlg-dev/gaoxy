# M4 public Session consumer-affinity task delta

> For agentic workers: Sol coordinator assigns the existing disjoint owners and
> uses `executing-plans` or `subagent-driven-development`. Independent Sol
> specification then SDK/code review is required. Serialize all Mix/live work
> under the existing exclusive lease; freeze live sources during qualification.

**Goal:** qualify the request-lived public Session caller required by consumer
affinity, then resume the existing M4 upstream implementation gates.

**Architecture:** [consumer-affinity amendment](../designs/m4-public-session-consumer-affinity.md).
Separate adopted bootstrap exits before a stable caller connects as its own
consumer. Guardian alone schedules one operation at a time; endpoint stop and
all owned task termination remain the Service cleanup boundary.

**Tech stack:** existing Elixir/OTP, coordinated 0.21.4 cohort and independent
aioquic peer; no new dependency.

This is a delta to [the preserved plan](m4-public-session-upstream.md), superseding
its Architecture paragraph and Task 2/3 per-operation-task/guardian-consumer
instructions only. Its full semantics, compatibility commands, UP2, standalone,
browser/consumer and final review gates remain required. Original documents and
failed receipts remain unchanged. Baseline HEAD:
`b43a8ebc06fb13caf62fa9320f039b8bdd446023` on `codex/m4-http3`.

## A — Freeze and independently review the amendment

- [ ] Coordinator records exact new design/plan/SDK/root-lock hashes and confirms
  UP1 remains HOLD_UP0. Preserve the two prepared UP1 tests and concurrent docs.
- [ ] Independent Sol specification review checks all amendment requirements,
  bootstrap and caller lifetimes, every cleanup branch, notification handling,
  bounds and the task-to-design mapping below. Write a new unique review receipt.
- [ ] Independent Sol SDK/code review checks `Quic.Connection` consumer gates,
  public Session result shapes, Transport connect/attach/stop, endpoint acceptor
  and normal creator-exit behavior against exact installed sources. It must not
  infer runtime correctness from the earlier design approval.
- [ ] Resolve findings in amendment documents only; freeze approved hashes before
  harness implementation. Root owns status links and decisions; no routine
  user approval is needed under continuing authorization.

## B — Amend direct Session qualification, then freeze and run UP0

Sole writer: existing qualifier. Files:
`integration/http3/upstream/{session_probe.exs,run.py,origin.py,README.md}`.
Do not edit dependency or production source in this task.

- [ ] Preserve compile-failure `run-1791826957389704425` and first-poll affinity
  failure `run-1791827038372979204`; do not relabel nine double passes as network
  qualification. Carry direct-chain Sol 1/unsuccessful 1/Astra 0 forward.
- [ ] Replace transient operation callers with distinct bootstrap creator and
  one stable caller. Probe coordinator commands the entire next Session/options;
  caller invokes only that operation with connect `consumer: self()`, returns
  the full result, drains hints, and remains idle until the next command.
- [ ] Add deterministic barriers recording distinct creator/caller/guardian PIDs,
  descriptor adoption ACK, creator unlink/normal DOWN, live endpoint after DOWN,
  and identical caller PID across connect/open/request/poll/data/trailers/resume.
  Exact real peer response after creator exit proves usability. Never inspect
  private Session/connection fields to infer ownership.
- [ ] Add the following finite deterministic cases, with exact expected outcomes:

| Case | Required assertion |
| --- | --- |
| Cancel before adoption, after ACK/before creator DOWN, after creator DOWN/before caller start | No connect; stop/DOWN proof or explicit uncertainty; no leaked unadopted endpoint. |
| Creator dies before descriptor/after adoption | Lost descriptor remains uncertain; retained descriptor uses stop/normal DOWN; no success forged from creator death. |
| Idle caller dies before connect and after authenticated connect | Fail request, never replace/replay caller, retain endpoint until teardown evidence. |
| Guardian exits normally before connect, after connect and during paused ACK | Matching guardian monitor DOWN terminates idle caller; independent acceptor monitor terminates endpoint; unrelated DOWN is ignored; no Service completion forged. |
| Guardian exits normally while caller is blocked in a public call | Endpoint teardown proceeds independently; release the call barrier, then caller consumes DOWN and exits before another command/result; do not assert immediate caller death. |
| Guardian exits normally during bootstrap/adoption or endpoint stop | Creator never connects/waits indefinitely for adoption; retained descriptor receives bounded public stop; stop task attempts its one stop and exits without guardian ACK. All observable task DOWNs recorded, Service uncertainty preserved. |
| Caller blocks past original deadline; late success arrives | Guardian cancels promptly, starts independent stop; late result cannot revive/ACK/complete. |
| Duplicate result or stale command generation | No second admission or state transition. |
| Session returns advanced error/unknown/blocked | Full advanced value returned; unknown reconciles same identity, blocked continuation resumes latest Session. |
| Repeated reconciliation, many reads and paused ACK with notifications | Same caller, hints drained, finite mailbox high-water independent of bytes/iterations; no raw hint forwarding/private-handle access. |
| Endpoint DOWN before caller DOWN; caller DOWN before stop result | Completion waits for all required receipts; missing/abnormal endpoint DOWN or stop error retains uncertainty. |
| Normal response done while downstream consumption pending | Caller stays alive; no premature close or cleanup completion. |

- [ ] Label doubles separately from real network rows. Retain every original
  Task 2 real-peer assertion: exact zero/data duplicate trailers/FIN, strict TLS
  identities and negatives, 1 MiB tiny-window upload/download, four cancellation
  stages, owner loss, peer observations, sibling survival, public stop/normal
  endpoint DOWN, every owned task DOWN and owned UDP rebind.
- [ ] Freeze source hashes, review harness, then run under exclusive lease:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python integration/http3/upstream/run.py --gate session-contract --evidence docs/acceptance/evidence/m4/upstream-contract
  ```

- [ ] Record nonzero actual network and double counts separately, exact exits,
  source before/after hashes, public outcomes and process shutdown. Independent
  Sol evidence review followed by fresh qualification is required before UP1.
  Exit 0 requires all required rows; failure or unexecuted rows keep HOLD_UP0.

## C — Apply the same contract to UP1 after UP0 passes

Sole writer: existing UP1 implementer. Source ownership remains the original
Task 3 list, principally `apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex`
and `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`. Tests remain
`apps/gaoxy_proxy/test/{http3_session_client_test.exs,http3_proxy_test.exs}`.

- [ ] Extend prepared red tests with the deterministic lifecycle cases in B,
  asserting Service reservation retention/release and all process termination
  receipts, not only returned errors. Observe the expected failures first.
- [ ] Implement caller receive-loop helpers inside the selected adapter module;
  no new GenServer/supervisor. Track separate creator/caller/stop monitors and
  command generations. Preserve latest Session exclusively through correlated
  full commands/results and never await caller DOWN between operations.
- [ ] Implement bounded public-hint disposal, single guardian tick, idle caller
  crash handling and terminal rejection of late results. Every owned task
  explicitly monitors guardian; process only its matching DOWN, including normal
  exit, before/after calls and between hint batches. Test ACK stalls, normal
  guardian loss and blocked native-call cancellation using deterministic barriers/
  finite observation deadlines; preserve underlying SDK/resolver timeout limits.
- [ ] Preserve every original callback/semantics/bounds/policy red test and
  compatibility target. Run the full explicit compatibility command from original
  Task 3 plus its compile and changed-file format checks. For focused iteration:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python scripts/check-tests.py apps/gaoxy_proxy/test/http3_session_client_test.exs apps/gaoxy_proxy/test/http3_proxy_test.exs
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' mix compile --warnings-as-errors
  ```

- [ ] Independent Sol specification/code review of final source, resolve concrete
  findings and rerun affected checks with fresh hashes. Only then resume original
  UP2 and standalone tasks, including their unchanged real-peer and browser/
  consumer gates. No M4 completion or publication claim follows from UP0 alone.

## Evidence and handoff

The architecture candidate receipt records immutable original document hashes,
exact SDK/guardian/Service/root-lock hashes, pre-existing edits, historical
per-task counters and direct-chain Sol 1/unsuccessful 1/Astra 0. Architecture adds
zero Astra recovery rounds and grants no reset or additional recovery budget.
All commands above are **NOT RUN by the architecture author**. This plan's
unchecked boxes are required execution/review work, not missing design choices.
No unresolved product decision is introduced. Coordinator owns routing, runtime
acceptance and commits; this author writes only the two amendments and one new
candidate receipt, then stops.
