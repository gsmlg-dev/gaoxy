# S5 member limits bounded recovery handoff

Task: Task 5 S5 member-limit repair. Status: ESCALATE_TO_ASTRA.
Assignment: direct bounded repair from root; parent-managed routing required.
Gate: SOL_REPEATED_FAILURE, two unsuccessful S5 production validations.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.
Branch: `codex/m3-gateway`; HEAD: `22b76e8051ddaf09e36797cb781b9b119870a9d4`.
The checkout contains other workers' M3 changes; preserve them.

## Ownership and preservation

- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`
- `apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs`
- Evidence files `docs/acceptance/evidence/m3/groups/member-limits*`

No other files were edited during S5. No dependency edits, commits, publishing,
processes owned by other workers, or subagents. Root owns final independent
review, stage documentation, canonical validation, and commit decisions.

Pre-S5 source SHA256:

```text
d58d5dbedee32ea4c7630c580602e7b92706abc869cfa6dbb554590b0f04a48f  http.ex
30e345233134f27bf2e3facc4543048dc27859270046de86be8f7952d14558e9  http/session.ex
```

Frozen handoff SHA256:

```text
6650ed1169c8284be4e87a08341a747c475994f2bce6194eda48867c2e158615  http.ex
c1e123186e089adfc8a86490227cb72d1545c1c7d169a1686549ba0fdb1c4375  http/session.ex
ae28c9335c41ab7629fb46c564166670a8a65dc8e4ac990d695f84efdba0fb34  upstream_group_member_limits_test.exs
```

## Specification

Effective common/member limits are minima, including max_chunk_bytes. Preserve
the downstream absolute deadline. Member total lifetime begins at original
Session start; opening begins at cleanup activation and includes selection.
Propagate limits and absolute deadline to pump; enforce idle and upload/downstream
write limits. Intentional total expiry must preserve passive health; opening
expiry is upstream failure. Preserve one checkout/client, no replay, public
completion cleanup, selection/probe holds, and existing common-expiry behavior.

## Evidence and actual outcomes

All commands used `nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2'`.
Logs preserve exact command environment output, seeds and assertion errors.

1. `member-limits-red.log`: initial four tests/four failures, exit 2,
   seed 630936. FIXTURE FAIL: SocketObserver lacked secure?/0, so endpoint never
   reached Session. Added secure?/0 and close/1. No production round counted.
2. `member-limits-red-fixture1.log`: corrected behavioral RED, four tests/four
   failures, exit 2, seed 862773. Opening/idle exceed 500ms; member total expiry
   poisons passive health; ready has only upload, no effective limits/deadline.
3. `member-limits-green1.log`: compile FAIL, exit 1, zero tests. New private
   cancel/1 collided with existing public cancel/1. Unsuccessful S5 production
   validation 1. Renamed helper to mark_cancelled/1.
4. `member-limits-green2.log`: 26 tests/two failures, exit 2, seed 107342.
   Unsuccessful S5 production validation 2. The 22 existing tests in
   http_proxy_runtime_test.exs and upstream_group_proxy_test.exs passed.
   New opening and idle tests passed. Source edits STOPPED immediately.

The last two validation commands format the three owned source/test files and
run:

```sh
unbuffer mix test apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs apps/gaoxy_proxy/test/http_proxy_runtime_test.exs apps/gaoxy_proxy/test/upstream_group_proxy_test.exs --warnings-as-errors --max-cases 1
```

## Retained repair and unresolved failures

HTTP records started_at, propagates ready limits/deadline, clips exchange writes,
and treats upload write timeout as failure rather than early-final suppression.
Session computes minima; member lifetime is clipped to started_at, opening to
activated_at. Timers use absolute remaining budgets; HTTP Fetch uses remaining
effective total/opening. Request timeout/expired total is intentional cancelled;
later cancellation/owner-down cannot erase previously recorded upstream failure.

Remaining failures:

- Metadata/write fixture passed ready metadata/deadline assertions, then wrongly
  expects chunk framing even though its peer sends Content-Length:5. Actual wire
  response is correct `HTTP/1.1 200 OK ... content-length: 5 ... hello`.
  Fixture should assert the specified framing it actually sends without reducing
  timeout bounds or dropping actual send_timeout/cleanup/health assertions.
- Member total expiry before headers returns empty downstream close, whereas
  fixture expects 504. HTTP now correctly clips exchange.deadline to effective
  member total. Exchange.send_window/2 rejects writes when that deadline expires;
  HTTP.fail/2 attempts 504 using the expired exchange, leaving no response bytes.
  Resolve whether strict absolute expiry requires close rather than 504, or a
  separately bounded error write is allowed. Do not renew request budgets or
  silently bypass the accepted total deadline merely to satisfy a fixture.

The lifetime test fails before peer-cleanup and passive-health assertions, so
those assertions remain NOT VERIFIED for this final production tree. Existing
common maximum-lifetime/blocked-write tests passed. Full proxy suite and final
independent S5 review remain NOT RUN after this repair.

## Counters and shutdown

Earlier Task 5 Sol rounds: two successful, zero unsuccessful; preserved.
S5 Sol production validations: two unsuccessful (compile then scoped run).
Fixture corrections do not count as production repair rounds.
Received Astra repairs: zero. Root must validate and arrange bounded recovery;
this worker has not spawned another agent or changed models.
Sessions 33619, 67359 and 72438 all finished with exits 2, 1 and 2 respectively.
No S5 command remains running. Owned source/test files are frozen for handoff.
