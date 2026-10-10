# M3 Task 5: dedicated HTTP/1 upstream groups

Date: 2026-10-10. Architecture deliverable, not implementation acceptance.
Checkout: `.trees/m3-gateway`, `codex/m3-gateway`, base
`22b76e8051ddaf09e36797cb781b9b119870a9d4`. Requirements: Task 5 in
`docs/plans/m3-gateway.md`, `implement-plan.md` §§7.1–7.2, and the settled M3
group/generation boundaries in `docs/designs/m3-gateway.md`.

## Decision and existing seams

Use one instance-scoped `Gaoxy.Proxy.UpstreamGroups` owner for bounded immutable
group generations, health records, selection cursors and resource holds. Network
operations run in existing request Session guardians or dedicated temporary
probe guardians. Selection is equal round-robin, has no wait queue, and opens one
dedicated H1 connection per selected request. There is no transport pooling.

Alternatives rejected: a process per member adds lifecycle without useful
isolation (the network guardians already provide that); embedding health/network
work in the HTTP Generation store would serialize request/configuration control
behind I/O and create a reverse dependency. Keep pure group compilation separate
from its one mutable resource owner.

Current source observations:

- `Proxy.HTTP.start_session/4` starts `HTTP.Session`, then attaches its cleanup
  reservation to the downstream owner lease. Session opens upstream only upon
  `{:gaoxy_cleanup_activate, token}`. Preserve that ordering.
- Session retains the request until `HTTPFetchClient.cleanup/2` confirms public
  completion; owner/service/gate death cancels the request. Group membership must
  follow the guardian, not the downstream process or response-header lifetime.
- `HTTPFetchClient.open/1` already sets H1, `http1_reuse: false`, manual redirects,
  raw body streaming, OTP TLS and public `connect_address`. Its conservative
  reservation is roughly 8 MiB/request. Preserve this qualified host boundary.
- `HTTP.Headers.request/1` removes client Host and forwarding fields, then
  generates trusted forwarding metadata. The selected URL supplies upstream
  authority; do not forward the incoming Host as an unvalidated upstream name.
- `HTTP.Generation.call/2` currently snapshots a Router then dispatches outside
  the store. There is no resource pin between these events. Retiring a group
  when its selected-session count reaches zero would race an old snapshot that
  has not selected its member yet. The small generic sidecar below closes this
  race without retaining old Router values.

HTTP Fetch 0.19.1 remains selected. H1 reuse is blocked on
[http_fetch#66](https://github.com/gsmlg-dev/http_fetch/issues/66); upstream H2
additionally needs [#67](https://github.com/gsmlg-dev/http_fetch/issues/67) for
request trailers. No option changes, private pool calls, dependency workaround,
or new dependency are authorized by this slice. Direct H1 groups and public
cleanup/probes have no identified upstream blocker.

## Immutable configuration and selection

Pure `UpstreamGroups.compile/1` validates a nonempty ordered list of at most 32
members with unique bounded binary IDs. Each member has an origin-only HTTP(S)
URL, optional CA file and optional numeric `connect_address`, plus positive
finite concurrency and timeout limits. Reuse `Proxy.HTTP.init/1` validation;
reject userinfo, fragments, origin path/query, duplicate IDs, unknown keys and
unsupported client options. TLS identity and trust settings belong to that
immutable member generation. CA material changes require a new generation;
operators must not mutate a referenced CA file underneath a running generation.

One compiled group contains ordered members, `max_inflight` (default 64), each
member's limit (default 16), health policy and bounded configuration bytes. No
weights, hashing, least-connections selection, sticky sessions or retries are
needed. Membership changes prepare a new group generation; no in-place mutation
of a live member URL, name, trust setting or timeout policy.

Core resource API, all with finite deadline-aware calls:

```elixir
UpstreamGroups.start_link(instance: instance_pid, name: optional_otp_name, limits: limits)
UpstreamGroups.prepare(owner, compiled_group, preparer_pid, deadline)
# {:ok, handle, preparation_pin} | {:error, reason}
# handle = %{owner: owner_pid, owner_epoch: reference, group: binary, generation: reference}
UpstreamGroups.checkout(handle, route_pin, guardian_pid, request_context, deadline)
# {:ok, immutable_member, selection_token} | {:error, :unavailable | reason}
UpstreamGroups.bind_completion(handle, selection_token, completion_handle)
UpstreamGroups.finish(handle, selection_token, outcome)
# Called by the bound guardian only after public cleanup confirmation.
UpstreamGroups.status(handle)
# Bounded availability/health/count metadata, no credentials or raw URLs.
```

Start the owner explicitly under the embedded/standalone instance's supervising
application. `Endpoint.init/1` only accepts/validates an already-prepared handle;
it must not start an owner or perform probes. A stable OTP name locates the owner
for configuration; runtime handles include the PID and epoch, so a restart never
silently redirects old handles to a new ledger. Instance death triggers draining.
Do not add dependencies or controller callbacks to core Config/Service.

Checkout scans from the cursor through the ordered vector once. A member is
eligible only when healthy, its health result is fresh and its confirmed-held
request count is below the member limit. Select the first eligible member,
increment group/member counts and create the token atomically, then advance the
cursor to the following vector position. No selection means 503 before opening
any upstream request. Saturation does not count as a health failure. Concurrency
makes order the owner's accepted-checkout order, not the callers' wall-clock
arrival order. There is no automatic second checkout after a selected attempt.

## Generic route-resource sidecar (parent-owned integration)

Once CAS publishes a candidate, return its receipt before releasing old metadata
pins. Keep at most one bounded retired sidecar alongside the current router;
reject another activation with `:resource_release_pending` until it clears.
Reconcile one provider pin per message, rotating an unconfirmed release to the
end with a 100 ms retry interval. This prevents up to 64 bounded provider calls
from extending a committed activation's caller deadline or monopolizing one
owner dispatch. The old router is not retained by the store; admitted requests
hold their own immutable snapshots and resource pins.

Keep `gaoxy_http` independent of `gaoxy_proxy`. Add an optional pure endpoint
callback `resources(initialized_options) :: [resource_handle]`, default `[]`.
`Router.compile/1` collects/deduplicates these handles into a bounded `resources`
sidecar; static nested Routers preserve reachable resources. A nested mutable
Generation acquires its own current resource pins when dispatched; do not freeze
that store's current sidecar into its enclosing Router at compile time.
The Group endpoint returns its group handle. No provider code performs I/O or
starts resources during route compilation. Limit sidecar handles to 64 and
include them in existing configuration-byte bounds.

Use a small generic HTTP resource-provider behaviour implemented by the proxy
owner facade; opaque handles include the provider module and owner identity:

```elixir
pin_many(handles, holder_pid, kind, operation_ref, absolute_deadline)
# {:ok, opaque_pin} | {:error, reason}; all-or-none per provider owner
# kind = :baseline | :preparation | :request
release(opaque_pin) # idempotent, holder/owner authenticated
```

These are bounded metadata operations only. Never call an endpoint or network
operation in the Generation store. Batch handles for the same provider owner;
roll back earlier pins if a later provider fails. A provider timeout is not proof
that no pin was acquired: use a caller-created operation ref, ordered cancellation
and holder monitoring. Preparation/request pins expire by their prescribed
deadline. Baseline pins live until explicit release or holder death; their call
deadline bounds acquisition, not the lifetime of the active configuration.
No timed-out call may create an unbounded orphan pin. Provider modules
are trusted compiled code, never atomized from external configuration.

Required minimum Generation additions:

1. Preparation remains outside `Generation.Store`. The configuration coordinator
   prepares group records first under a finite preparation pin (default 5 s),
   then builds routes referring to their immutable handles. On validation or
   stale-CAS failure, it releases only its candidate preparation pins. Dropped
   coordinator/prepare processes are monitored. Existing active groups survive.
2. Activation checks expected generation and deadline, obtains baseline pins
   for the candidate's sidecar, publishes the new Router, then releases the old
   baseline pins. Provider metadata calls are deadline-bounded; failure before
   publication leaves the current Router unchanged. Release failure after
   publication retains capacity conservatively and is reconciled, not rolled
   back by pretending activation never happened. While old releases remain
   pending, reject further activation with `:resource_release_pending`; preserve
   the published Router and resume activation after reconciliation clears them.
   This bounds retained release metadata to one old sidecar plus the current
   baseline set. The store owns exactly one current Router.
3. Add `snapshot_for_request(store, holder_pid, deadline)`, used by
   `Generation.call/2`. Within the same serialized store operation, pin the
   current sidecar for that request before delivering the Router value. Return
   `{generation, router, request_pins}`. Old baseline release therefore cannot
   race snapshot pin creation. Continue dispatch outside the store.
4. Put request pins in Exchange metadata and release them in `after` when the
   endpoint returns. Holder DOWN is an idempotent fallback. A selected Session
   has its own token, so releasing snapshot pins never frees active transport
   holds. Keep snapshot accounting in the existing downstream Admission lease.
   Plain `snapshot/1` remains a read-only inspection API, not an execution lease.

Request pins are unforgeable, bounded capabilities that may be passed to the
Session guardian for checkout. The owner checks their group generation, live
holder and expiry, and binds the resulting selection token to the calling
guardian. Only the holder/configuration coordinator may release a pin; possession
of a request pin alone cannot release it or another guardian's selection token.

The proxy owner marks a record retiring once it has no baseline/preparation
pins. Existing request pins still permit old-snapshot checkout; unrelated new
requests cannot acquire that retiring generation. Suspend new health probes
for retiring records, allow selected requests to finish, cancel in-flight probes
through their public completion path, and delete a record only when baseline,
preparation, request, selection and probe holds are all zero. Keep only resource
IDs/configuration/holder metadata in this ledger, never old Router snapshots.

An endpoint mounted without Generation obtains/releases a request pin itself;
its explicit supervising configuration owner holds the baseline pin. No resource
can be retired merely because the first request has not arrived yet.

## Request guardian integration

Add a separate `Proxy.GroupEndpoint` implementing the existing synchronous
Endpoint contract. Its initialized config is the immutable group handle plus
bounded common proxy limits. It dispatches through the existing HTTP pump; do
not duplicate header/body/trailer handling or invent a second client stack.

Minimal shared seams, serialized with the parent/H2 writer:

- `Proxy.HTTP` accepts an internal upstream selector (fixed config or group
  handle/request pin). Before starting Session, reserve the maximum existing
  `HTTPFetchClient.reservation/3` across that group's possible URL/header sizes.
  Config sizes are already bounded; do not allocate payloads to compute it.
- Session receives that selector. **After Service cleanup activation**, it
  performs one group checkout as the guardian PID, constructs the selected URL
  with the original escaped path/query, and opens the dedicated client once.
  The selection token is attached to the guardian from creation; there is no
  downstream-owner-to-guardian transfer race.
- After opening, Session binds the client's public completion handle to its
  group token before notifying the pump that upload can start. Add narrow
  `completion(handle)` / `await_completion(completion, cancel?)` adapter methods
  if needed; these wrap public Promise/RequestCompletion APIs, not client PIDs.
- On terminal result, record a bounded outcome, but release the selection token
  only after `HTTPFetchClient.cleanup/2` returns `:ok`. Then complete the existing
  Service cleanup receipt. Response headers, response EOF, downstream death,
  Session DOWN and timeout alone never release the selected-member slot.

If a guardian dies after binding completion, a bounded recovery guardian may
abort/await that same public completion handle and release only after `:ok`.
It sends no new HTTP request. If it dies in the open-to-bind interval or public
cleanup says unconfirmed, preserve the token/reservation, mark the resource
failed/unavailable and retain existing Service fail-closed behavior. Do not
infer cleanup from process death or reset the owner ledger automatically. Lost
proof is explicit failed cleanup, not successful retirement. A group-level
failure never changes another group's selected destination.

## Health probes and availability

States are `unknown`, `healthy`, `unhealthy`, with `retiring`/`failed` on group
lifecycle. Initial unknown members are ineligible until a successful probe.
One successful initial probe enables a member; after it becomes unhealthy,
require two consecutive probe successes to restore it. Three consecutive probe
or attributable passive transport failures remove a healthy member. A success
resets the corresponding failure streak. Ordinary request HTTP statuses do not
count as passive transport failures; downstream cancellation, overload, client
body errors and downstream write failure must not poison upstream health.

Active health policy: HEAD of a configured bounded origin-form path (default
`/`), healthy status 200–299, no redirects, same URL identity/CA/pinned address as
normal requests, 5 s interval, 2 s total/opening bound and deterministic bounded
phase jitter. One probe/member at a time; schedule next due time after confirmed
probe cleanup. No catch-up bursts or duplicate timer chains. The owner's finite
member records store due times; there is no growing queue of missed probes.
Results carry owner epoch, group/member generation and probe token.

Run each probe as a temporary `UpstreamGroups.Probe` guardian outside the owner.
Reserve its full conservative client byte allowance and a probe slot before
spawning/opening. It obtains the public completion handle, binds it to its
probe token, observes headers/terminal state, and then awaits or aborts public
cleanup. A HEAD response needs no body collection; reject malformed/unexpected
body delivery within the existing finite client bound. Do not ack unlimited
chunks merely to decide health. Health can be recorded on terminal outcome, but
probe capacity and retirement holds remain until cleanup is confirmed.

The owner authorizes at most four concurrent probes across its scope, with a
separate default 64 MiB probe budget; compute each reservation with the same
client function. Fairly cycle due members; capacity exhaustion delays a probe
without spawning. A result older than 15 s is stale and ineligible at checkout,
even if its stored state says healthy. Expose scheduling lag/unknown/stale
explicitly; do not promise every configured member is probed every five seconds
when capacity cannot support that. Validate all intervals/thresholds and permit
operators to size finite concurrency/budgets for their configured membership.

Probe timeout triggers cancellation, not an immediate replacement. Owner death
instructs surviving probe guardians to abort/await and stop; a stopped owner is
not a cleanup receipt. Lost cleanup evidence uses the same failed-resource and
retained-capacity rule as requests. Never restart the ledger empty while old
guardians may still own transports. Instance shutdown drains resources with one
deadline and records unconfirmed cleanup separately from process termination.

## Deadlines and identity

All request deadlines use monotonic absolute time; selection and preparation do
not restart a budget. Preserve existing defaults: opening 5 s, write 5 s, idle
60 s and total 30 s, clipped to the downstream request deadline. Intersect each
common endpoint limit with the selected member's corresponding limit, including
opening, idle, write, total lifetime and maximum chunk bytes; the smaller value
wins. Propagate these effective limits and the absolute deadline to the HTTP
pump before upload or downstream response writes. The effective total starts at
the original Session start, before selection. Opening runs
from Session activation until final response headers, including selection/DNS/
connect/TLS. Connect timeout is the minimum of opening remaining and total
remaining. A stale opening timer cannot cancel a request after headers.

Expiry never creates a fresh error-write budget. Opening expiry may emit 504
while the total/downstream deadline still permits a write; expiry of the absolute
total deadline closes the downstream without adding response bytes. Both paths
still require confirmed client cleanup and zero released transport holds.
Intentional total/idle expiry must not make a healthy member unhealthy; a genuine
upstream opening failure retains its attributable health outcome.

Idle measures actual admitted body progress/terminal activity, not control polls,
timer messages or window updates. A response chunk held because the downstream
has not consumed it is bounded; its wait is governed by downstream write/total
limits. Each body/write/finish operation is clipped to remaining total/drain
time. Add a Session-owned total timer as an independent guard, not only checks
in the downstream pump. Use typed outcome phase tags so downstream stall/expiry
is not mislabeled an upstream transport failure.

`HTTPFetchClient` needs only finite supported options and public completion
accessors; do not use its pool idle-timeout option as a request inactivity timer.
Preserve no replay, `redirect: :manual`, `decode_body: false`, streaming demand,
ordered duplicate fields/trailers, early responses and guardian cleanup.

HTTP Host and HTTPS SNI/hostname validation come from the selected immutable
member URL. Optional numeric `connect_address` changes the dial destination
only, through the public API. It must not change URL authority, TLS name, trust
policy or route generation. Failed TLS validation does not select a new member
for the same request. Probes must use the same identity, never an IP URL with
hostname verification disabled. No ambient proxy settings or redirect targets
may change this routing decision.

## Bounds, ownership and acceptance

Default owner bounds: 64 group-generation records including prepared/retiring/
failed records, 16 MiB group configuration, 1,024 metadata pins and 1,024 selected
request tokens, plus the independent four-probe/64 MiB budget. Service Admission
still limits each downstream request's transport reservation. Reject preparation
with `:group_capacity` and checkout with `:unavailable` before side effects when
limits are exhausted. Pin/token messages contain fixed bounded metadata, no
body or unbounded URL/header payloads. A pin deadline can stop new work and cancel
its owner; it cannot free a live guardian's unconfirmed transport token.

| Slice | Ownership / seam | Required tests |
| --- | --- | --- |
| G1 pure config + owner | New `proxy/upstream_groups.ex` and options/state helpers | Strict/idempotent limits; deterministic round-robin, saturation/no queue; unknown/unhealthy/stale exclusion; isolated groups |
| G2 resource lifecycle | New generic HTTP resource facade/optional Endpoint callback/Router sidecar; parent owns Generation edits | Old snapshot paused before checkout survives activation/retirement; selected old member stays fixed; stale CAS and failed preparation release only candidates; caller/store crash and bounded retained records |
| G3 Session integration | `group_endpoint.ex`; serialized `http.ex`, `http/session.ex`, client/behaviour seams | Selected peer receives at most one request on connect/TLS/upload/response failure; no redirect/replay; downstream reset retains group count until public cleanup; guardian death/open-to-bind uncertainty |
| G4 real probes | New `upstream_groups/probe.ex`, bounded supervisor under proxy application | Real H1/verified HTTPS HEAD probes; threshold/recovery/freshness; never-overlapping probe; timeout, owner death and public cleanup holds; stale results ignored |
| G5 policies/load | Scoped proxy tests and embedded Generation/resource integration | Opening/idle/write/total independently expire; SNI/Host/trust preserved; mixed concurrency and generation changes maintain reservations; no connection reuse claim |

New groups tests should use existing real-network proxy/TLS fixtures and public
HTTP Fetch barriers. Use explicit controllable cleanup/peer barriers for races,
and independent peer observations for request counts and TLS identity. Do not
make cleanup pass by sleeping, suppressing a monitor or resetting a counter.
At minimum pause an old request immediately after snapshot pinning, activate a
new group, verify retirement remains held, release the barrier, and assert the
old/new requests hit their respective exact peers. A separate test delays public
cleanup after the response and proves both request/probe tokens remain occupied.

Suggested focused files: `upstream_groups_test.exs`,
`upstream_group_proxy_test.exs`, `upstream_group_probe_test.exs` under the proxy
test directory, plus parent-owned Generation resource tests. Run those and the
affected existing proxy/generation compatibility suites after implementation.
No core Config/Service/UDP files are needed. Parent serializes shared HTTP/client/
application files with current writers. Standalone JSON keeps the defined
`static` and fixed `reverse_proxy` target allowlist; group resources use explicit
supervised embedded APIs. External group JSON is UNSUPPORTED and is not implied
by the product's same-runtime/data-only configuration requirement.

At the design-time checkpoint this assignment ran source/document checks only: compilation/network/tests
NOT RUN. No runtime support, full M3 completion or production acceptance follows
from this design. Remaining qualification risks are resource pin handoff,
guardian/probe failure windows and independent deadline/cleanup evidence.

Final implementation and bounded concurrency/health/ownership qualification are
recorded in `../plans/m3-upstream-groups.md` and `../acceptance/m3.md`.
Effective member-deadline recovery, scoped26/0, fullproxy156/0 and final460/0
canonical verification pass; independent specification and quality pass.
G5's bounded mixed-concurrency/generation gates do not establish a20-generation
group/probe soak. The repeated-generation and600-second H2 profiles use a fixed
dedicated-H1 proxy endpoint. Reuse/upstreamH2 remain blocked on the containing
release and qualification of closed#66/#67 fixes.
