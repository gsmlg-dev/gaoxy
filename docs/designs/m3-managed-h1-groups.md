# M3 managed H1 groups and probes

Date: 2026-10-13 Asia/Shanghai; readiness updated 2026-10-14.
Status: Local implementation/runtime acceptance **PASS**: independent complete
SPEC then CODE and fresh168/0, strict compile and formatcheck pass. Local commit
`5ea088a9e3fe2646a056b2078f31a34f7adb6049` completes this bounded package. The [acceptance ledger](../acceptance/m3-managed-h1-groups.md)
records exact source/log identities and preserves all historical failures. The
original readiness review retains its predecessor snapshot.
This bounded package follows full acceptance of
[fixed endpoints](m3-managed-h1-fixed-endpoint.md), and precedes
[Generation integration](m3-managed-h1-generation.md). It implements the group
and probe portion of existing M3 upstream-transport Task 5. See the
[implementation plan](../plans/m3-managed-h1-groups.md).

## Baseline, authority and scope

Inspected worktree `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, foundation HEAD
`5b73f5a951d506f194d090a0083183a79d577d6e`. Concurrent fixed-endpoint edits in
HTTP, Session, HTTPFetchClient, UpstreamTransports, their tests and parent-owned
documents/evidence are predecessor work, not this design's changes. Recheck the
accepted fixed-endpoint commit and actual diff at implementation kickoff.

Assignment `managed_h1_next_architecture`, mode architecture/design-only,
`astra_gate=PROJECT_ARCHITECTURE`: genuine resource ownership, probe lifecycle
and generation boundaries. This assignment writes only the four new group and
Generation design/plan documents. Sol implements; the parent assigns exclusive
files, owns serialized Mix/build/live commands and local commits, and obtains
independent readiness and post-implementation SPEC then CODE review. Continuing
authorization chooses this recommendation automatically, without routine approval.

Carry UP2 unsuccessful **20 live / 8 production / 3 harness**, foundation Step 7
**5 unsuccessful attempts**, fixed endpoint initial unsuccessful **1**, identity
repair **1 PASS** as reported at handoff. These are cumulative historical facts,
not this package's tests. Astra recovery remains **2/2 exhausted**; architecture
adds zero rounds. Later parent receipts supersede the current Sol counters.
During preparation the parent reported fixed package attempt **2**, with
**114 tests / 16 failures**; that package is not accepted by this document.

No dependency changes, H2/H3 activation, standalone configuration, capability
advertising, publication, deployment, production data/certificates, Vault, public
management or disabled release-artifact E2E. Preserve the seven-package 0.21.4
cohort, explicit DER trust, literal dial address and H1-only profile. TLS peer
selected ALPN remains exactly JSON `null`. `http_fetch#97` is excluded and no
equivalent native-memory certification is introduced. Existing dedicated default
and protocol assertions remain unchanged.

## Decision and alternatives

Use the existing group owner for selection/health and transport owner for scope
and request cleanup. Declare transport dependencies in a bounded immutable group
handle sidecar. Coordinate pins in the **caller of preparation**, outside either
owner. Session and Probe each independently own their transport request pins and
tokens. This needs no new persistent process or resource-provider protocol.

Making the group owner synchronously acquire/release transport pins would place
external waits inside health/selection callbacks and complicate cancellation and
owner call cycles. Having `resources/1` query the group owner would make Router
compilation impure and race resource discovery. Copying trust/policy into handles
would duplicate authority. The sidecar contains exact transport handles only.

Generation old-snapshot dispatch remains the next package: ordinary guardian pin
acquisition cannot reopen naturally closed admission. Group acceptance here uses
live configuration baselines; it does not claim old managed snapshots work.

## Pure configuration and handle contract

`UpstreamGroups.Options.compile/1` preserves each member's optional `transport`
through map compilation and `%Options{}` round trips, via the accepted pure
`HTTP.init/1`. Transport members allow only H1, HTTPFetchClient and the fixed
endpoint's no-override rules. Dedicated and managed members may coexist; a
managed member's origin must later match its prepared transport. Multiple
members may share one exact handle only when that handle matches every member's
origin. Health/member limits and strict key/byte bounds remain unchanged.

The fixed-endpoint predecessor is adding an explicit `config.transport == nil`
guard in **both** Options compilation branches and two pure regressions, because
the old raw-input path admitted `transport` while struct reconstruction silently
dropped it. This is a deliberate temporary rejection, not existing managed-group
support. Update those two assertions to round-trip preservation and remove both
guards only in this package's reviewed full integration. Never remove the guard
alone or allow a partial implementation to silently fall back to dedicated H1.

Dedicated-only groups retain their existing six-field handle. A managed group
adds exactly one field:

```elixir
%{provider: Gaoxy.Proxy.UpstreamGroups, owner: owner, owner_epoch: epoch,
  group: id, generation: generation, max_url_bytes: bytes,
  transports: deduplicated_transport_handles}
```

`transports` is a nonempty first-occurrence-ordered list of exact four-field
UpstreamTransports handles, derived solely from compiled members. Enforce the
existing maximum 32 members, deduplicate before construction, and validate the
complete flattened resource list against `Resources.validate/1`: at most 64
handles and 65,536 serialized bytes. Aggregate Router resources retain the same
bounds across routes. No scope, trust, credentials or mutable health is exposed.
For the legacy shape preserve current dedicated behavior; for the new shape
accept only these seven keys and reject forged sidecar changes against the
owner's stored exact handle. Store and account for the sidecar's serialized
payload with the group's owned configuration, not in uncharged history.

Add pure `UpstreamGroups.resources(handle)` returning `[handle]` for a valid
legacy handle and `[handle | handle.transports]` for a valid managed handle.
`GroupEndpoint.init/1` validates this list without contacting owners;
`GroupEndpoint.resources/1` delegates to it. A structurally valid handle with a
nonresponsive owner must compile without waiting. Liveness/identity validation
belongs to preparation and runtime, not pure init.

Outside Generation, GroupEndpoint acquires the **whole flattened list** as outer
request pins and passes them in `exchange.resource_pins`. Its `after` releases
only pins it acquired. It may reuse a complete pre-existing set held for this
request; a partial set must not silently omit a transport. Authoritative stored
pin checks remain in owners. The next package supplies authenticated reuse and
closed-admission handoff for Generation; a superficial map membership test is
not transport checkout authorization.

## Preparation, candidate rollback and configured lifetime

Keep `UpstreamGroups.prepare(owner, compiled, preparer, D)` and its
`{:ok, handle, preparation_pins}` return. For managed groups, require its caller
to be `preparer`. Preserve legacy dedicated preparation behavior. Add a bounded
read-only `UpstreamGroups.instance(owner, D)` returning the instance PID; store
that PID alongside the existing monitor. It returns no configuration/pin/token
and does not call transports.

The public prepare facade, running in the preparer, performs:

1. Pure recompile and complete resource bound checks before side effects.
2. Fetch group-owner instance identity, validate each distinct member
   `(transport, origin)` with `UpstreamTransports.validate_endpoint/3` and the
   same absolute D. Cross-instance, malformed, wrong authority, closed transport
   or deadline failure publishes no group and allocates no request token.
3. Acquire deduplicated transport **preparation** pins with
   `Resources.pin_many(transports, preparer, :preparation, D)`.
4. Call the existing group-owner prepare handler with canonical compiled input;
   it derives and stores the exact sidecar locally, reserves its own capacity,
   publishes one group/preparation pin and may schedule probes. Return combined
   group and transport preparation pins to the preparer.

The facade prechecks the compiled members/transport list and a provisional
handle shape; the owner checks the actual generated handle plus flattened list
before inserting a group or creating its preparation pin. Reserve sidecar bytes
alongside compiled configuration; the final exact resource bound cannot be
deferred until endpoint compilation after publication.

Hold the resource's original preparation pins until step 3 succeeds; acquire a
configuration baseline for the entire flattened group resource list before
releasing the returned preparation pins. Calling `pin_many([group], ... )`
alone is insufficient for managed groups. Document/test this embedding contract.
Neither group pin provider nor group owner recursively acquires transport pins.

On any failure, cancel the group preparation operation through the existing
same-caller cancellation path, and release/cancel transport pins acquired by
this attempt. `Resources.pin_many` already rolls back partial provider batches;
keep its returned error. A late group reply is canceled; preparer death drops
all of its pins by monitors. Capacity remains charged until real cleanup;
failed cleanup stays visible. Preparation rollback must not retire a transport
still held by another candidate or active configuration. Transport preparation
does not imply scope ownership by the short-lived preparer: persistent
foundation custodians remain the public scope creators.

## Session selection and independent completion holds

After existing Service cleanup activation, select exactly one member through
`UpstreamGroups.checkout/5`. Preserve group/member capacity and health behavior.
For a dedicated member use the existing path. For a managed member, validate
origin/H1/instance, acquire the Session's own transport request pin, and checkout
once under the decreasing opening D. Outer group/transport pins are not Session
checkout credentials. Do not retry another member on transport capacity failure.

Keep separate `selection: {group, selection_token}`, `transport_selection:
{transport, transport_token}`, `transport_pins` and Service cleanup token.
Store each acquired hold before the next fallible step. Pass only the selected
owner's transport pin batch to checkout. Build Fetch using returned immutable
policy and the accepted managed HTTPFetchClient branch.

Immediately after open, bind the **same original** public RequestCompletion to
the transport token and group token before ready/upload. Bind failure uses the
original public abort/join and preserves uncertainty; no synthetic completion.
Only after original request cleanup confirms `:ok`, finish transport ownership,
release guardian pins, finish group selection once, then complete Service
cleanup. Pending cleanup retains both token ledgers and service accounting.
Group and transport owner recovery may independently await/abort the same public
completion; neither calls the other owner.

Distinguish pre-Fetch rejections from upstream failure. If transport validation,
pin acquisition or checkout rejects before a transport token/Fetch exists,
release acquired pins and finish the group selection as `:cancelled`; member
health is unchanged. After a transport token exists without original completion,
the foundation's unbound-token uncertainty applies: do not refund that token or
report successful service cleanup. Once Fetch was attempted, preserve the
existing upstream-failure/passive-health classification; never retry/replay.

## Probes: same policy, bounded ownership and retirement

Existing probe scheduling remains bounded by `max_probes`, `probe_bytes`, one
probe per member and finite health deadlines. `Probe.init/1` must not contact
owners or open Fetch. The owner records the probe PID/token and reservation
before authorizing any managed open. Add local
`UpstreamGroups.claim_probe(owner, token, D)` called by Probe itself in its
continuation. The owner authenticates caller PID against the stored probe,
ready mode, exact group generation, active lifecycle, not-yet-claimed flag and
deadline; it returns the stored instance identity. The flag lives only in the
existing bounded probe record. The owner does not call transport owners.

Execution dependency: preparation currently publishes members due immediately
and queues `:kick_probes`. The first live managed preparation verification must
therefore include this managed Probe continuation; the prior dedicated open
continuation ignores `config.transport`. Implement the owner claim/interface
before disjoint Probe/Session work, and wait for Probe support before declaring
live preparation GREEN. Preserve scheduling, rollback tests and final gates;
no production scheduling switch or intermediate dedicated fallback is added.

This claim is the probe admission linearization point. A retired group can never
grant a new claim, including a probe process started just before retirement but
held before claim. An already claimed probe is in flight: retirement cancels
it through the existing monitored cleanup path. Cancellation after claim cannot
retroactively promise zero upstream bytes. Check cancellation/deadline again
before Fetch; retirement blocks new scheduling and new claims immediately.

For a managed member, Probe validates the exact stored member origin against the
transport and instance, acquires its **own** request pin as `self()`, checks out
once, and issues HEAD using that policy's origin/address/DER/H1 scope and the
existing health path. Never re-read `cacertfile`, substitute default trust or
open a dedicated fallback. Dedicated probe behavior remains unchanged.

Bind the original completion to transport then group probe token before polling
headers. On confirmed request cleanup, finish transport token and release its
pin **before** `probe_finished`. Cancellation, owner death, opening/bind error,
unknown completion and guardian death retain conservative cleanup exactly as
Sessions do. No group↔transport synchronous call edge is introduced; calls run
from facade, Session or Probe. Probe-supervisor startup must not call either
owner synchronously from `init/1` while group owner awaits child startup.

Preserve current health rules: unknown/unhealthy/stale selection, HEAD 2xx
success, thresholds, deterministic jitter, max inflight and no selection-health
penalty for local capacity denial. For a managed probe denied by local transport
capacity **before Fetch**, add a distinct `:cancelled` completion outcome:
release probe reservation and schedule next due time without changing checked,
success/failure counters or health. Do not misreport that denial as successful
health refresh. Actual wire/TLS/timeout failures keep failure behavior. Existing
dedicated cancellation semantics need not change. Bound all cleanup continuations
and retain failure receipts; scope retirement proof is separate from HEAD end.

## Acceptance and readiness

The plan requires pure sidecar/round-trip tests; multi-owner partial rollback;
identity/capacity/caller-death tests; real TCP and verified OTP TLS group requests
and HEAD probes; exact original completion binding to both ledgers; local-denial
health neutrality; retired-before-claim rejection; cancellation/guardian death;
shared-handle deduplication; and idle reuse followed by physical peer EOF and
owner/helper joins at stop. Retain dedicated group/probe/TLS/member-limit and
fixed-endpoint regressions. Assert peer ALPN exactly `null`, explicit DER trust,
SNI authority despite numeric dial address, wrong CA/hostname rejection and no
replay. No private dependency pool/process inspection.

At preparation handoff every execution box remained unchecked. Current plan
checkboxes and the acceptance ledger record subsequent execution. Readiness
review authorizes Sol's next kickoff only after fixed endpoint acceptance; it
is not implementation acceptance. Parent records exact tree/cohort/environment, commands, nonzero test
counts, exits, independent SPEC then CODE findings and fresh post-review checks.
Full Task 5, Generation, H2, standalone, publication and production acceptance
remain separate.
