# Dedicated HTTP/1 upstream groups implementation plan

Assignment `/root/upstream_cleanup`, Task 5, 2026-10-10. Worktree
`.trees/m3-gateway`, `codex/m3-gateway`, baseline `22b76e8` plus shared changes.
Follow `docs/designs/m3-upstream-groups.md`; parent owns review and commits.
Task5 started at0. The initial worker checkpoint had2 successful Sol
repair/validation rounds (compile warning and fixture correction), no unexpected
production behavioral failures and Astra0. Final cumulative Task5 counters are
Sol4/unsuccessful2 plus Astra2/unsuccessful1; the separate S5 recovery and parent
Generation repair are recorded below. Previous relay/H2 counters are preserved.

Goal: bounded round-robin groups with real health probes, immutable route pins,
and member slots released only after public dedicated-H1 cleanup confirmation.
Architecture: one explicitly started Groups owner holds bounded generations,
pins, health and selection state. Temporary probe/Session guardians own network
work; HTTP Resources bridges providers without an HTTP-to-proxy dependency.
Tech: existing Elixir/OTP, public HTTP Fetch 0.19.1, public OTP TCP/TLS.

## Ownership and verification

Create `proxy/upstream_groups.ex`, `proxy/upstream_groups/options.ex`,
`proxy/upstream_groups/probe.ex`, `proxy/group_endpoint.ex` and focused
`upstream_groups_test.exs`, `upstream_group_proxy_test.exs`,
`upstream_group_probe_test.exs`. Modify minimum HTTP/Session/client/Application
seams, HTTP Endpoint/Router/Generation/Exchange resource metadata, and focused
`generation_resources_test.exs`. Preserve parent Forward/Relay/H2 and worker UDP.
Serialize every Mix command with parent; no dependency patches, pooling, H2
upstream, replay, publication or operational changes.

- [x] Write initial tests and obtain a parent-granted red window. Run from root:
  `nix develop --command bash -c "export ERL_FLAGS='+S 2:2'; export MIX_ENV=test; unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/upstream_groups_test.exs apps/gaoxy_http/test/generation_resources_test.exs"`.
  Record actual missing-behaviour failures in `groups/initial-red.log`.
  Executed: five tests/five expected failures, seed 869135, exit 2.
- [x] Implement pure group/member/owner limits with strict duplicate/unknown-key,
  origin/TLS/address validation, idempotence, bounded config and 32 members.
  Initial groups are unknown. Real HEAD peers establish healthy selection.
- [x] Implement one owner: all-or-none deadline/holder-authenticated provider
  pins; finite preparation/request expiry, baseline lifetime, cancellation refs,
  holder DOWN; retiring generations remain until every pin/token/probe clears.
  Test cursor order, group/member saturation, group isolation and stale handles.
- [x] Implement temporary probes under the proxy supervisor. Reserve slot/bytes
  before spawn; use dedicated H1 HEAD with original identity, public completion
  bind/await/abort, finite total/opening timers, no replay and bounded results.
  Test initial success, failure/recovery thresholds, freshness, one probe/member,
  budget limit and unknown cleanup retaining capacity.
- [x] Add HTTP Resources provider metadata batching/rollback/cancellation. Add
  optional Endpoint.resources and bounded Router sidecar (64 handles), recursive
  static Router resources; mutable Generation obtains current pins at dispatch.
  Test malformed sidecars and duplicate handle deduplication.
- [x] Add Generation activation baseline pins and atomic snapshot request pins;
  Exchange carries request pins, endpoint return releases in `after`. Keep Store
  network-free and current Router-only. Test old snapshot pause across activation,
  stale CAS, store/caller DOWN, deadline timeout rollback, and retained resources.
- [x] Add Generation `:name` and mutually exclusive `:router`/`:routes` startup.
  `router: compiled` validates and activates without Endpoint.init repetition.
  Resolve validated OTP name to exact PID at endpoint initialization. Test
  Registry via naming, malformed names, compiled bounds and mutual exclusion.
- [x] Integrate GroupEndpoint into existing HTTP pump. After cleanup activation,
  Session checks out once, constructs escaped member URL, opens once and binds
  completion before upload-ready. Reserve worst-case client bytes first. Typed
  terminal outcome changes health only for attributable upstream failures;
  successful cleanup precedes member-token release and Service receipt.
- [x] Add Session-owned total timer and clipped opening/drain budgets. Guardian
  DOWN after bind uses completion-only recovery; unbound/lost cleanup fails the
  group closed and retains slot. Test owner/reset death, no replay, saturated 503,
  selected Host/path/TLS name, old/new exact peers and independent deadlines.
- [x] Obtain serialized green checkpoint: new group/resource tests plus existing
  proxy/TLS/Forward and Generation compatibility files. Record commands, seeds,
  counts, exits and source hashes. Scoped formatting and strict compilation are
  required; do not claim unexecuted independent TLS/cleanup cases as passing.
- [x] Self-review design coverage, then parent independent specification/quality
  review. Repair actionable findings through the recorded Sol/Astra routing.
  Mark only passing scoped gates complete; upstream #66/#67 still block reuse/H2
  and full M3. Parent coordinates local commits separately.

Public regression examples (exact contract):

```elixir
{:ok, compiled} = UpstreamGroups.compile(%{id: "api", members: members})
{:ok, handle, preparation} = UpstreamGroups.prepare(owner, compiled, self(), deadline)
{:ok, baseline} = Resources.pin_many([handle], self(), :baseline, deadline)
{:ok, request} = Resources.pin_many([handle], self(), :request, deadline)
{:ok, member, token} = UpstreamGroups.checkout(handle, request, self(), %{}, deadline)
:ok = UpstreamGroups.finish(handle, token, :success)
:ok = Resources.release(request)
:ok = Resources.release(preparation)
{:ok, store} = Generation.start_link(router: compiled_router, name: registry_name)
{:ok, generation, router, pins} = Generation.snapshot_for_request(store, self(), deadline)
```

The owner must reject expired/unauthorized metadata before mutation. These
regressions must execute against real HEAD peers for health; transport cleanup
tests use public RequestCompletion barriers, never counter resets or sleeps.


## Expanded checkpoint and parent handoff

`groups/expanded-fixture1.log`: Generation/resources/loader21 and proxy59 tests,
zero failures, seed709212, command exit0. `expanded-compile.log` strict compile
exit0. `groups/README.md` records all actual reds/failures, scoped coverage and
frozen source hashes. Worker commands finished and source/tests froze before
releasing the Mix window to parent. New `generation_loader_test.exs` verifies
trusted `prepare_with/3` inside the existing bounded preparation worker for the
parent standalone regular-file loader seam.

Parent independent review identified synchronous old-resource release after
publication delaying a short caller receipt. Worker read-only analysis confirms
this finding. Parent production repair 1 returns the receipt before bounded
self-message release reconciliation; fixture contract update 1 preserves exact
metadata assertions with the existing finite `eventually` helper. The first
whole validation remains FAIL (HTTP22/1, proxy20/1, server18/0, seed618354).
The second scoped command passes (HTTP22/0, proxy20/0, server18/0, seed806307,
parent session23961 exit0). Worker narrow specification/quality re-review is
PASS in `groups/generation-release-rereview.md`; worker cumulative rounds remain
2, behavioral repairs0, Astra0. No third worker repair/validation round occurred.
At that historical checkpoint the final Task5 review remained open; the narrow
receipt review did not substitute for the complete review.

## Final qualification

The independent complete review's S5 finding is resolved: common/member
opening, idle, write, lifetime and chunk limits intersect without restarting the
original Session lifetime. Sol validation1 failed compilation; validation2
executed26/2, seed107342. Bounded Astra recovery corrected two erroneous wire
fixtures while production hashes stayed unchanged: expired absolute lifetime
requires bounded empty EOF, and Content-Length5 preserves exact fixed framing.
Opening504, observed socket send_timeout80, peerEOF, healthy status, deadlines
and zero group/Service resources remain asserted.

Astra round1 formatFAIL executed zero tests. Round2 strictformat/compile,
scoped26/0 and fullproxy156/0 pass at seed107342, actual exits0. Final canonical
executes460/0 seed49315 and independentRFC40/40. Separate complete specification
and quality reviews pass in `../acceptance/evidence/m3/final-spec-review.md`.
Cumulative Task5Sol4/unsuccessful2 and Astra2/unsuccessful1 are retained; there
is no third recovery round. Local group/policy delivery is committed in
`6d92298`; its source matches the canonical/frozen maps.

Group qualification covers bounded concurrent selections/saturation, real HEAD
probe freshness/nonoverlap/cleanup holds and exact old/new peers across one
activation. The20-generation fixed-proxy test and600-second echo/fixed-proxy
soak are separate; no group/probe sustained-load receipt is claimed. Both
upstream issues are CLOSED but lack a containing installed release; reuse/H2
and fullM3 remain BLOCKED.
