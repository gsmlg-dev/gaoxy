# M4 public Session upstream implementation plan

> For agentic workers: the Sol coordinator assigns disjoint owners and uses
> `executing-plans` or `subagent-driven-development` task by task. Independent
> Sol specification/code review precedes activation. Serialize Mix/live commands
> under the existing exclusive lease; never modify frozen live-gate sources.

**Goal:** qualify and enable fixed HTTPS/H3 reverse origins using caller-owned
public Session/endpoint lifecycle, completing the existing remaining M4 rows.

**Architecture:** use [the bounded Session design](../designs/m4-public-session-upstream.md).
The existing HTTP guardian schedules one public operation task and retains a
dedicated endpoint cleanup token; endpoint stop runs independently when needed.
H1 remains the default. Fetch diagnostics remain historical/diagnostic evidence.

**Tech stack:** existing Elixir/OTP umbrella and exact 0.21.4 HTTP/QUIC cohort,
locked Nix development environment, aioquic independent peers, existing native
H1/H2/H3 downstream implementations and standalone JSON generations.

This plan replaces the Fetch-specific UP0/UP1 mechanism in
[the resume plan](m4-upstream-resume.md); its UP2, standalone and final M4 gates
remain required. Baseline `ed6ac187f052063fe2c0695c1343cb2980214b62` has concurrent
coordinator dependency and peer harness changes. Preserve them and immutable
receipts. Recheck current source/lock identity before each gate.

## Ownership and ordering

| Step | Sole writer | Files |
| --- | --- | --- |
| Specification review | Independent Sol reviewer | Unique new review receipt only |
| UP0-Session | Independent-peer implementer after Fetch harness handoff | New `integration/http3/upstream/session_probe.exs`; extend `run.py`, `origin.py`, `README.md`; `probe.exs` only for preserving explicitly labelled Fetch diagnostics |
| UP1 | Client implementer | New `apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex`; modify `upstream_client.ex`, `http.ex`, `http/session.ex`, `http_fetch_client.ex` only for required behavior annotations, `group_endpoint.ex`, `upstream_groups/options.ex`; scoped tests below |
| UP2 | Peer implementer after UP0 and UP1 | New `integration/http3/upstream/fixture.exs`; extend the same origin/runner plus native downstream client support under this directory |
| Standalone H3-origin | Standalone implementer after UP1; serialize shared peer edits | `integration/http3/standalone/{fixture.exs,peer.py,run.py,README.md}`; `apps/gaoxy_server/lib/gaoxy/server/route_config.ex`; `apps/gaoxy_server/test/http3_generation_test.exs` |
| Cohort/acceptance/docs | Coordinator | Exact root/consumer/Phoenix pins/locks; README/capability/m4 acceptance and old design/plan cross-references; unique source-bound receipts |

No new dependency, dependency patch, private transport encoding, upstream pool,
forward-H3, CONNECT-H3, global autofix or unrestricted test suite is part of this
plan. The coordinator resolves file ownership before implementation; two workers
must not concurrently edit the shared runner/origin.

## Task 1 — independently review and freeze the selected contract

- [ ] Reviewer reads the design, installed Session/Transport public APIs and
  existing guardian/Service cleanup contract. Check all advanced return shapes,
  adoption ownership, borrowed-endpoint teardown, stale-task handling, queue
  bounds, early-response continuation behavior and absolute deadlines.
- [ ] Resolve concrete findings in the design before client implementation.
  Coordinator updates current selected-design links without rewriting historical
  blocked receipts. Record reviewer identity, exact source/design hashes and
  PASS/FAIL/NOT RUN distinctions. Architecture review is not UP0 runtime PASS.
- [ ] Confirm Fetch diagnostic owner has finished and released the Mix/live
  lease and four harness files. Record current cohort/lock and received counters.

## Task 2 — direct Session qualification (UP0-Session)

Add runner choice `--gate session-contract`; keep `--gate contract` as the
existing Fetch diagnostic with its honest unsupported cleanup result. The new
probe uses only public Session and Transport calls and known fixture ports.

- [ ] Add a red assertion first: the selected direct Session gate does not yet
  exist and cannot report PASS from the Fetch export audit or diagnostic rows.
- [ ] Implement public bootstrap/adoption and retained descriptor flow exactly
  as the design. Record every public result, monitor reason, request ref, known
  bind address/port and operation deadline. Never query `:sys.get_state`, private
  socket/process handles or a Fetch Session. Use explicit fresh loopback bind
  ports for local endpoint rebind receipts; catch real occupied-port failure.
- [ ] Create the endpoint with public `acceptor: guardian_pid`. Prove the
  adopted endpoint remains alive and usable after its creator's normal DOWN,
  before connecting; links alone do not transfer the monitored acceptor role.
- [ ] Execute zero/three DATA bytes × absent/valid Trailer declaration, with
  `[{"x-check", "one"}, {"x-check", "two"}]` exactly in one terminal trailing
  HEADERS block. Assert one request, exact DATA hash/length and one FIN; record
  local admission result separately. Verify repeated response trailers too.
- [ ] Execute progressive upload/download barriers and a 1 MiB tiny-window row;
  pause origin receive credit/owned UDP transport after request HEADERS. Assert
  a public definite blocked/finite pending result, no replay and exact origin
  request/DATA counts. Resume peer IO after cancelling to observe its terminal
  cancellation. A scheduling delay alone is not blocked-write proof.
- [ ] Execute two distinct certified fixed authorities, authentication rejection
  for wrong CA and hostname, exact absent-trust rejection, and pre-allocation
  Gaoxy-policy rejection of address pinning. The latter is a policy row, not a
  claim that raw public Transport rejects the Fetch option. Every rejected
  request leaves independent origin request counts unchanged.
- [ ] Execute normal close plus cancellation before response headers, during
  blocked upload, with one unacknowledged response and after downstream owner
  loss. For each, separately record Session close/abort outcome, explicit public
  endpoint-stop outcome, normal endpoint DOWN, all owned task DOWNs, peer result,
  and same-address/port UDP rebind. Interleave a sibling request on its separate
  endpoint and prove it survives each teardown.
- [ ] Add deterministic tests/double-driven probe subcases for unknown connect,
  unknown DATA/trailers, advanced error state, bootstrap-before/after-adoption
  cancellation and stop error/abnormal DOWN. Unknown is reconciled by ref only;
  no second send/request is allowed. Label doubles separately from network rows.
- [ ] Run the newly implemented gate under the exclusive lease:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python integration/http3/upstream/run.py --gate session-contract --evidence docs/acceptance/evidence/m4/upstream-contract
  ```

- [ ] Independent Sol source/evidence review, then fresh repeat from frozen
  hashes. Exit 0 requires all executed required Session rows and child cleanup;
  exit 1 is failure; exit 2 is an actual public/environment block. Keep evidence
  in new run directories, never overwrite Fetch or 0.21.3 history.

**UP0 exit:** qualified selected public Session transport and independent review.
Any unresolved required public API gap stops dependent activation and follows
upstream issue policy; unrelated unblocked work can continue.

## Task 3 — selected client and guardian integration (UP1)

Create `apps/gaoxy_proxy/test/http3_session_client_test.exs` and
`apps/gaoxy_proxy/test/http3_proxy_test.exs`. Extend existing group/config tests
only at their existing boundary. No wholesale H1 adapter refactor.

- [x] First red tests: explicit H3 chooses `HTTP3SessionClient`; default remains
  H1; reject HTTP/H3, missing CA, unknown protocol, oversized upload, module
  injection, address pinning and forged struct mismatch. Reject H3 group maps
  and structs; ForwardHTTP remains H1 after its existing policy checks.
- [x] First red lifecycle tests, using deterministic task/adoption barriers:
  bootstrap cancellation before and after adoption; connect fails before a
  Session connection exists; request returns advanced error/unknown; delayed
  task result after deadline; guardian remains responsive while operation blocks.
  Creator normal exit must leave the adopted endpoint usable with its guardian
  acceptor; guardian owner loss still enters the confirmed teardown contract.
  Assert endpoint-stop invocation and token completion/retention, not just an
  error tuple. A `cleanup_pending`/abnormal DOWN case must retain its reservation.
- [x] Implement the design's explicit map/upload token shape and phase machine
  in `HTTP3SessionClient`. Define task runner helpers in that same module; one
  operation task and one exceptional stop task are sufficient. Every result is
  generation-correlated; store advanced Session before any subsequent operation.
- [x] Wire allowlisted selected client into endpoint reservation/write/finish
  and guardian open/poll/event/subscribe/ack/cleanup. Declare host/reservation and
  optional begin-cleanup callbacks; normalize legacy H1 and stateful H3 ACK/
  cleanup results exactly as the design. H1 stream/promise semantics stay local.
- [x] Add red semantics tests: every H3 request receives a finish token including
  zero body; request opens `:stream`; DATA stays below 16 KiB; exactly one FIN;
  ordered duplicate trailers after accepted DATA; unknown trailer FIN resumes
  same operation without resending; early final head fails outstanding upload
  once and stops future reads; late/stale ACK cannot unlock another delivery.
- [x] Add red bounds tests: one pending write and one continuation maximum;
  one delivery before ACK; event bytes/count cap; paused polling consumes no new
  response DATA; queued trailers/end follow last ACK; original opening/total/
  write deadlines do not move on wakeup/resume; oversized fields fail visibly.
- [x] Implement minimum behavior to pass those tests. Strict TLS options and
  pseudo-header construction come from selected fixed authority and existing
  Headers policy. No caller options bypass protocol or TLS allowlists.
- [x] Run the entire explicit compatibility set (nonzero tests required):

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python scripts/check-tests.py apps/gaoxy_proxy/test/http3_session_client_test.exs apps/gaoxy_proxy/test/http3_proxy_test.exs apps/gaoxy_proxy/test/http_fetch_contract_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs apps/gaoxy_proxy/test/http_proxy_runtime_test.exs apps/gaoxy_proxy/test/http_proxy_wire_test.exs apps/gaoxy_proxy/test/http_proxy_tls_test.exs apps/gaoxy_proxy/test/http_headers_test.exs apps/gaoxy_proxy/test/forward_http_test.exs apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy_proxy/test/upstream_group_proxy_test.exs apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' mix compile --warnings-as-errors
  ```

- [x] Format-check exactly task-owned changed Elixir files with `mix format
  --check-formatted <explicit changed paths>`; coordinator supplies the concrete
  audited path list in the receipt, never runs a repository-wide autofix.
- [x] Independent Sol specification and code review, resolve findings, fresh
  affected checks, record counts/exits/source hashes; local conventional commit
  by coordinator only after those pass. Do not announce UP2 from unit tests.

## Task 4 — independent downstream-to-upstream matrix (UP2)

- [ ] Implement `--gate matrix` using actual native H1, H2 and H3 downstreams
  through Gaoxy to the independent aioquic origin. A first red fixture selecting
  the new client must fail before activation; retain its exact result.
- [ ] For each downstream protocol execute GET/HEAD, progressive upload/download,
  1 MiB/tiny windows, HEAD/204/304/bodyless, duplicate fields, raw compression,
  escaped paths and empty query, redirect/no-follow/no-replay, zero/data request
  trailers, duplicate response trailers, early final response, downstream cancel,
  upstream reset and original opening/total timeout. Include strict TLS negatives
  and two interleaved authorities with distinct certificate identities.
- [ ] Assert exact independent method/path/authority/DATA/trailer/FIN observations,
  response bytes and request counts. Assert sibling/other-listener survival and
  eventual active/admission/cleanup baselines. Preserve bounded stalls and exact
  failure categories. A healthy followup alone cannot certify the failed request.
- [ ] Run under the exclusive lease:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python integration/http3/upstream/run.py --gate matrix --evidence docs/acceptance/evidence/m4/upstream-matrix
  ```

- [ ] Independent review of frozen harness and evidence, then fresh affected
  verification. Keep Session-UP0, UP1 tests and UP2 peer counts separate.

## Task 5 — standalone H3-origin and completion

- [ ] Extend existing standalone JSON fixture with fixed explicit H3 upstream
  using the qualified adapter and local fixture CA. The inspected
  `Gaoxy.Server.RouteConfig` proxy clause currently allows only `type`, `upstream`
  and `cacertfile`: add `upstream_protocol` with only string `http1`/`http3`
  mapped to fixed atoms, defaulting to H1. Pass it through `HTTP.init/1`; reject
  arbitrary modules/options/other strings without dynamic atom creation.
  Add red/green `http3_generation_test.exs` tests for acceptance, H1 default,
  invalid enum, invalid TLS and invalid reload preserving the old generation.
- [ ] Execute independent H3-origin streaming/trailers through actual standalone
  Application/Config/Supervisor startup; preserve static and dedicated-H1 rows,
  in-flight old-generation reload, invalid reload rollback, sibling survival,
  stop/UDP rebind, and bootstrap rollback. No operational certificates or live
  deployment is involved.
- [ ] Run the extended existing command:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python integration/http3/standalone/run.py --evidence docs/acceptance/evidence/m4/standalone
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python scripts/check-tests.py apps/gaoxy_server/test/http3_generation_test.exs apps/gaoxy_server/test/standalone_generation_test.exs apps/gaoxy_server/test/standalone_independent_review_test.exs
  ```

- [ ] Coordinator runs previously prescribed affected shared/downstream gates,
  real Chromium/Phoenix acceptance and clean core/H1-H2/H3 consumer checks with
  updated locked closures. Use the exact commands in the existing M4 plans and
  record actual new counts, not historical counts. Confirm core isolation.
- [ ] Independent final specification/code/evidence review and fresh affected
  checks; update current acceptance/capability documentation to name the Session
  client and actual complete/incomplete rows. No upstream pool/H2 claim.
- [ ] Only complete M4 verification and review satisfy conditional main/push/
  release authorization. Deployment and release-artifact E2E remain separate.

## Reporting and counters

Every receipt records worktree/HEAD/dirty task sources, root and relevant consumer
lock hashes, peer/certificate hashes, exact command/environment, executed cases or
test counts, exit, owned children termination and PASS/FAIL/BLOCKED/NOT RUN.
Do not include private keys. Read current `checkpoint-2026-10-12.json` plus the
coordinator's subsequent receipts before repairs; carry all historical counters
forward. This architecture/planning assignment adds **0** Astra recovery rounds;
it neither resets counters nor grants extra Astra repair budget.

At handoff, this plan and design are drafted and self-checked. All implementation,
unit, direct-Session, matrix and standalone runtime commands above are **NOT RUN
by the architecture author**. The coordinator owns independent review, execution,
final acceptance and any local commits/publication.
