# M3 HTTP/2 and gateway implementation plan

> For agentic workers: use subagent-driven-development for independently owned
> tasks, scoped red/green verification, and independent specification and code
> review. The continuing authorization in `AGENTS.md` replaces routine approval
> pauses. Checkboxes track executed evidence, not intended capability.

**Goal:** Deliver the existing M3 HTTP/2 and gateway milestone, preserving M2
behavior and request-scoped confirmed cleanup.

**Architecture:** Use native connection ownership and protocol-neutral Exchange
and Response operations, with isolated bounded H2 stream workers. Keep gateway
policy separate from the public upstream client and transport bridges. Prepare
immutable configuration generations before activation, retaining stable socket
owners and each in-flight request's selected generation.

**Tech stack:** Elixir 1.18.5 / OTP 28; Thousand Island and Abyss public adapters;
Plug/WebSock; pinned HTTP Fetch 0.19.1 until a qualified upstream update; HPAX for
HTTP/2 header compression; independent loopback peers.

**Base:** `71f1b02032b440c5626263bd48aa4f622260e70a`, worktree
`.trees/m3-gateway`, branch `codex/m3-gateway`.

The detailed component contracts and ownership are in
[`../designs/m3-gateway.md`](../designs/m3-gateway.md). Root maintains this plan
as tests and reviews complete. Compatibility edits required by the goal are
authorized, including core adapters and existing test contracts.

## Task 0: Authorization and current-source baseline

Files: `AGENTS.md`, `implement-plan.md`, `codex-prompt.md`,
`docs/dependency-followups.md`, `docs/acceptance/evidence/m3/`.

- [x] Preserve the root's untracked user prompt and create the ignored worktree.
- [x] Persist continuing authorization, annotate historical kickoff-only rules,
  and preserve explicit external-operation, Vault, E2E, and production limits.
- [x] Resolve the existing lock and strict-compile the current source using the
  pinned Nix shell; record the actual tool versions.
- [x] Execute the existing M2 HTTP/proxy/core compatibility suites and standalone
  configuration test before production changes.
- [x] Complete independent governance review (specification and quality PASS).
- [x] Commit the authorization (`c1dfa94`).

Canonical command environment:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix compile --warnings-as-errors'
```

Use the same environment for each `mix` command below. Store logs, exits, counts,
source hashes, and review findings under `docs/acceptance/evidence/m3/`.

## Task 1: Public upstream contract gate

Files: `integration/http_fetch_contract/pooled_completion_probe.exs`,
`docs/dependency-requests/http-fetch-pooled-completion.md`,
`apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` (upstream TODO only).

- [x] Audit installed RequestCompletion against the exact 0.19.1 release source.
- [x] Create Feature blocker `gsmlg-dev/http_fetch#66` with the required type,
  label, requester, public reproduction, expected contract, and severity.
- [x] Route the distinct upstream-H2 request-upload trailer prerequisite as
  Feature blocker `gsmlg-dev/http_fetch#67`; completion support alone cannot
  satisfy the full cross-version proxy trailer matrix.
- [x] Execute the public option-gate probe and confirm both exact failures:

```elixir
{:error, {:unsupported_completion, :http1_reuse}} =
  HTTP.RequestCompletion.await(HTTP.Promise.completion(pooled_h1), 0)
{:error, {:unsupported_completion, :http_version}} =
  HTTP.RequestCompletion.abort_and_await(HTTP.Promise.completion(h2), 0)
```

Run: `unbuffer mix run --no-compile --no-start integration/http_fetch_contract/pooled_completion_probe.exs`.
Expected: exit 0 proving the BLOCKED option gates, not pooling/H2 acceptance.

- [ ] After #66 and #67 are resolved and a containing dependency is installed, verify
  confirmed normal/cancel cleanup, live multiplexed siblings, pool retirement,
  TLS policy isolation, stale sockets, finite capacity, and old generations.
  Only then enable upstream H2; H1 reuse requires #66. Until then stop this task and
  continue independent tasks; no private pool calls or local workaround.

Final live checkpoint: both issues CLOSED; latest and installed0.19.1 predates
the fixes. The containing release/update and this qualification remain BLOCKED.

## Task 2: Native HTTP/2 and shared HTTP operations

Owned area: `apps/gaoxy_http/` H2 modules and Exchange/Response/Plug protocol
dispatch, plus directly required HTTP proxy compatibility seams and HPAX lock.

- [x] Audit HPAX package/version/license/public decoder and resize contract.
- [x] Add failing tests for independent stream cancellation, SETTINGS/window
  changes, malformed HEADERS/CONTINUATION, bounded decoding, and GOAWAY.
- [x] Introduce protocol-neutral read, poll, response, metadata, and terminal
  operations while preserving H1 state and wire behavior.
- [x] Implement the native H2 connection state machine and bounded stream
  workers; each worker owns its admission lease and absolute deadline.
- [x] Test HTTP semantics: request fields/trailers, body limits, informational
  headers, HEAD/204/205/304, duplicate fields, files, and streaming response.
- [x] Prove TLS ALPN `h2` independently; qualify explicit prior-knowledge h2c
  separately. Do not advertise h2c upgrade, push, or WebSocket extended-CONNECT
  without their own implementation and gates.
- [x] Prove flow-control demand, slow peers, fair sibling progress, RST_STREAM,
  downstream→dedicated-H1 proxy cleanup, drain and force-stop ownership.
- [x] Run `unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test apps/gaoxy_proxy/test`
  and independent H2 peer checks; resolve specification then quality findings.

Representative required assertion: after resetting one stalled upload, another
stream on the same TLS connection returns its exact response and the canceled
stream's cleanup reservation clears only after its public upstream completion.

## Task 3: Destination policy, forward HTTP, CONNECT and stream relays

Owned area: new `apps/gaoxy_proxy/lib/gaoxy/proxy/` destination-policy,
forward/CONNECT, and stream-relay modules plus their tests and user documentation.
Serialize any shared `HTTPFetchClient` changes with Task 2.

- [x] Write failing policy tests for absent authentication/rules, duplicate
  credentials, resolved IPv4/IPv6/mapped destinations, and explicit CIDR/port
  allow rules. Authentication and destination rules must be deliberate.
- [x] Resolve once within the dial deadline, check every candidate, and dial
  only the approved numeric address; retain URL authority and TLS identity via
  the documented public `connect_address` option.
- [x] Implement separate forward HTTP configuration and explicit CONNECT
  authentication; strip proxy credentials before upstream exchange.
- [x] Implement bounded duplex raw transfer with one credited chunk per
  direction, finite writes/idle/lifetime, tested half-close and force cleanup.
- [x] Distinguish TCP, OTP TLS termination, verified upstream TLS, and opaque
  passthrough. Reject unsupported interception/PROXY/SNI inspection claims.
- [x] Run focused policy and relay tests against real peers; verify no replay,
  a live sibling under blocked writes, EOF→directional shutdown→remaining reply,
  credential rejection, TLS name/trust rejection, and resource restoration.
- [x] Complete independent specification and quality review before commit.

Required wire assertion: a peer that receives request bytes until FIN can still
send its exact response through the relay after the client calls write shutdown.

## Task 4: Immutable route/configuration generations

Owned area: a new route-generation endpoint/store in `apps/gaoxy_http/`,
allowlisted data configuration in `apps/gaoxy_server/`, and focused tests.

- [x] Write failing real-listener tests that pause an old request at a barrier,
  prepare/activate a new route table, and prove old/new requests use their own
  generation while the listener's bound port and owner remain stable.
- [x] Compile and validate outside the generation owner; use an expected
  generation on activation so concurrent stale updates fail atomically.
- [x] Bound configuration bytes/routes and endpoint preparation; failed
  preparation must leave the live route table unchanged.
- [x] Decode named endpoints through a fixed allowlist; reject unknown keys,
  arbitrary modules, atom creation, and code evaluation in external data.
- [x] Keep same-port listener changes explicit: reject changes requiring
  restart, rather than claiming an unimplemented transactional handoff.
- [x] Test reload rollback, concurrent activation, an in-flight old-generation
  proxy, repeated updates under traffic, and bounded retained state.
- [x] Run focused generation/server tests and independent review; commit only
  after the wire and rollback assertions pass.

## Task 5: Upstream groups and complete reverse-proxy policy

Owned area: group/health policy modules in `apps/gaoxy_proxy/`, client options
required by explicit deadlines, and focused tests.

- [x] Add bounded immutable upstream groups, deterministic load balancing,
  finite health probe intervals/deadlines, and explicit availability state.
- [x] Preserve verified HTTPS, header/trailer policy, raw compression, separate
  opening/idle/write/total deadlines, no automatic redirects, and no replay.
- [x] Prove failed selection sends at most one request; health recovery and
  new-generation membership do not move an in-flight request's selected peer.
- [x] Qualify bounded concurrent selections/saturation and health-probe
  ownership/cleanup, with exact old/new group peers across one activation.
  G5 requires these bounded concurrency/generation gates. Repeated fixed-proxy
  generations and Task7's600-second echo/fixed-proxy profile have separate
  evidence; no group/probe soak is claimed. Keep Task1's release blocker visible.
- [x] Complete scoped red/green, independent review and local commit (`6d92298`).

## Task 6: Persistent bounded UDP associations

Owned area: core validated datagram-dispatcher adapter, proxy UDP relay modules,
and scoped core/proxy tests; keep ordinary UDP/core-only consumers unchanged.

- [x] Add the smallest explicit core adapter for public
  `Abyss.DatagramDispatcher` and generation-tagged send capabilities.
- [x] Bound association count, per-association/aggregate retained bytes,
  datagram sizes, idle expiry, and writer admission/receipt deadlines.
- [x] Validate upstream return source and preserve each datagram, including
  empty payloads. Never retry an admitted/uncertain send.
- [x] Prove independent associations, expiry, admission rejection, stale
  receipts, listener force-stop, and association socket cleanup.
- [x] Keep broadcast/multicast relays opt-in with explicit ingress/egress and
  loop/amplification constraints; unsupported modes reject before binding.
- [x] Run focused core/datagram/proxy suites and external core consumer;
  complete independent review before commit.

## Task 7: Operational gates, acceptance and progression

Files: `docs/acceptance/m3.md`, M3 evidence bundle, feature/capability/status
documentation, independent loopback/load harnesses and scoped CI wiring.

- [x] Execute nonempty interoperability, security, cancellation/slow-peer,
  relay, reload, and sustained-load gates for the actual candidate.
- [x] Record concurrency, payloads, throughput/latency, retained bytes, drops,
  environment, limits and measurement exclusions; no conformance/security or
  production claim follows from selected local gates.
- [x] Re-run changed compatibility suites, strict compilation, canonical
  formatting, external core-consumer isolation, and relevant native fixture.
- [x] Perform independent full specification and code review; repair findings
  with deterministic regressions, maintaining Sol/Astra repair counters.
- [x] Update current capability docs without rewriting historical logs, review
  the diff/staged files, and create local conventional commits.
- [ ] Mark M3 complete only if every required gate and upstream prerequisite
  passes. Then write the M4 design/plan and automatically continue. If #66/#67
  remains open or the installed release lacks its contract, report BLOCKED for
  the affected tasks/M3 completion and preserve all tested independent work.

No push, release publication, deployment, production-data operation, Vault
change, public management listener, or release-artifact E2E enabling is part of
this execution plan.
