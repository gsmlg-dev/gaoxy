# M3 managed H1 Generation integration

Date: 2026-10-13 Asia/Shanghai; readiness updated 2026-10-14.
Status: **INDEPENDENT DESIGN/PLAN READINESS PASS**; implementation and runtime
acceptance **NOT RUN**. The original review preserves its predecessor snapshot;
execution still requires accepted groups/probes and a recorded fresh kickoff.
Depends on accepted [fixed endpoints](m3-managed-h1-fixed-endpoint.md) and
[groups/probes](m3-managed-h1-groups.md). Implements the remaining bounded H1
Generation portion of existing M3 upstream-transport Task 5. See the
[implementation plan](../plans/m3-managed-h1-generation.md).

## Source, authorization and boundary

Architecture assignment `managed_h1_next_architecture`,
`astra_gate=PROJECT_ARCHITECTURE`, design-only. Inspected
`.trees/m3-h1-resource-foundation`, `codex/m3-h1-resource-foundation`, HEAD
`5b73f5a951d506f194d090a0083183a79d577d6e` plus concurrent predecessor
fixed-endpoint edits. Actual execution baseline must be the later accepted group
commit, recorded by the parent with diff/untracked inventory and source hashes.
No executable changes or runtime commands belong to this architecture assignment.

Continuing authorization covers recommended local implementation and independent
review without routine approval. Parent assigns Sol writers and owns serialized
runtime/format/build commands, evidence and local commits. Preserve UP2
unsuccessful 20/8/3, foundation Step 7 unsuccessful 5, fixed endpoint initial
unsuccessful 1 and identity repair 1 PASS at handoff; later receipts update Sol
counts. Astra recovery is 2/2 exhausted; this design consumes zero rounds.
The parent subsequently reported fixed package attempt 2 with 114 tests /
16 failures during preparation; predecessor acceptance remains a future gate.

Four-field transport handles, eight-field public transport pins, ordinary
`validate_endpoint/3`, existing checkout guardian authentication, public original
completion/retirement joins and dedicated defaults remain contracts. Scope is
H1/explicit DER/numeric dial pins, seven-package 0.21.4 cohort. No new dependencies,
H2/H3 work, standalone schema/capabilities, publication/deployment, production
data/certificates, Vault, public management or disabled release-artifact E2E.
`http_fetch#97` remains excluded; no native-memory certification replacement.

## Evidence and chosen solution

`Generation.Store.handle_call({:snapshot_for_request, ...})` pins Router
resources for the authenticated native holder and returns one immutable router.
Activation obtains the new baseline before swapping, then asynchronously releases
old baseline pins. `UpstreamTransports.close_unpinned/2` immediately closes
admission when the last baseline/preparation pin leaves. It keeps the resource
alive while request pins/tokens exist. `pinnable/2` and `validate_endpoint/3`
require open admission. Existing `checkout/4` accepts a live guardian-owned
request pin on an active resource, independent of ordinary admission.

Therefore skipping only the duplicate outer pin is insufficient: a held old
snapshot that resumes after activation cannot validate/acquire a new Session
pin. Permitting arbitrary pin acquisition on closed admission would resurrect
unconfigured traffic. Lending a native pin directly to checkout violates its
holder/caller contract. Keeping all old baselines until dispatch ends delays
retirement/probes and requires a second generation-lifetime protocol.

Choose **bounded derivation of an already admitted request right**, authorized
by its authentic native holder, into an independently owned Session pin. It is
single-use per source-pin/resource, retains the old immutable policy, and adds no
generic provider callback, background process or persistent consumed-ref table.
Only this narrow API may operate after natural configuration closure. Ordinary
fixed activation and open-admission APIs retain their current restrictions.

## New internal transport API and linearization

```elixir
UpstreamTransports.delegate_request_pin(
  handle, source_pin, guardian,
  %{origin: root_origin, upstream_protocol: :http1, instance: instance},
  operation, absolute_deadline)
# {:ok, guardian_pin} | {:error, reason}
```

The native holder calls this API, not Session and not Generation.Store. `operation`
is a fresh caller-created reference used by the existing `cancel(owner,
operation)` mechanism. `source_pin` is one exact eight-field transport pin from
the captured resource set; never pass unrelated group/provider pins. Pure facade
checks exact handle/pin/identity shapes and existing 65,536-byte payload bounds
before owner calls. Validate authority using the accepted strict endpoint grammar.

The owner performs one local state transition in this order:

1. Authenticate `GenServer.from` caller equals the source pin's **stored holder**
   and supplied public holder, not merely its acquirer; exact supplied pin equals
   the live stored public pin. Require request kind, same owner/epoch, membership
   of the exact handle, live caller, live guardian distinct from caller, and a
   fresh/compatible operation. A derived pin cannot be a source.
2. Require running owner, active unconfirmed resource and no initiated resource
   retirement. Match the exact stored instance and normalized authority/H1
   against immutable prepared policy. Identity mismatch allocates neither pin,
   handoff marker nor token and does not poison the resource.
3. Require unexpired D, `D <= source_request_deadline`, and valid source lifetime.
   Add an internal admission deadline to ordinary request-pin records, initialized
   from their existing pin_many deadline; no new public pin field. Deadline is
   an admission bound, not permission to discard a pin/token with pending cleanup.
4. Permit open admission or **natural configuration closure with an existing
   source request hold**. Explicit owner stop, instance death, abandoned/failed
   resource and initiated scope retirement reject. Mark initiation synchronously
   in a bounded per-record `retirement_requested` boolean before sending the
   first custodian retirement message; never infer this solely from a delayed
   custodian lifecycle notification. Ordinary checkout also rejects that flag.
   Natural closed-but-held state has the flag false; no baseline is recreated.
   Reserve the flag's maximum serialized control metadata at resource creation
   in the existing owned-payload budget, so flipping it never needs capacity
   that could prevent retirement. It is not an uncharged history field.
5. Reserve the complete serialized delta for the source's one-use marker and
   new pin record, plus one existing `max_pins` slot, **before** monitors or state
   publication. No request token or scope is allocated by delegation. Use the
   existing `max_owned_payload_bytes`; rejection leaves the complete old state.
6. Atomically install a standard public request pin for `[handle]`, held by
   guardian, acquired by caller, with its own guardian monitor and internal
   derived/source metadata and D. Install one source marker keyed by resource,
   containing bounded guardian/operation/derived-ref data. At most one marker per
   source handle (source batch <=64). Markers are charged until the source pin
   disappears; never retain them in owner history after source removal.

An identical operation while the derived pin is live returns that same pin;
different operation/guardian for a consumed source-resource rejects. After the
derived pin is released, a repeat cannot mint another pin: keep the used marker
until its source is released. A pin with a used marker remains usable by its
original holder for its original request semantics; markers grant no new general
authority. Source removal releases marker accounting but does **not** revoke the
already transferred guardian pin. The independent guardian/token protects
cleanup after native death or dispatch return. Derived pins cannot form chains.

Facade rechecks D and guardian/caller liveness before returning success. On error
or late reply issue same-caller cancellation using the original operation; owner
must check D before admitting a queued call. Cancellation, explicit release and
holder DOWN are idempotent. Existing release permits holder or acquirer: native
may revoke its grant during handoff failure; after transfer, native releases only
its original pins, while Session owns the derived pin. Native death before reply
causes Session's existing owner monitor to terminate/cancel, and guardian DOWN
removes any unpublished grant. Keep all pending work charged until that happens.
No timer/helper/history per completed operation is added.

## Native dispatch and activated Session handshake

`Generation.call/2` remains the sole releaser of pins it acquired for the request
snapshot. HTTP fixed dispatch and GroupEndpoint recognize the captured complete
resource set and reuse its outer holds. They acquire ordinary pins only when no
captured set exists (fixed embedding) and release only those additional holds.
Do not reacquire old snapshot resources, replace them with current generation
resources, or trust an arbitrary `handles` field as an authentic transport pin.
The delegation owner check is authoritative. For group routes require the group
and every sidecar transport in the captured set; missing/partial/stale evidence
fails closed without fresh pins that might mix generations.

Keep captured transport pins only in native dispatch/pump state. Pass an optional
`transport_handoff` reference in internal Session startup args: nil for direct
fixed dispatch using its ordinary acquisition path, one fresh reference for a
fixed captured-snapshot path or managed group path with complete outer holds.
GroupEndpoint's own newly acquired outer set may also supply this group path;
it remains native-held and uses the same derivation checks while admission is
open. This needs no public endpoint option or new generic Exchange field.

The native code creates the unguessable handoff reference when starting Session.
Existing
`Service.attach_cleanup` triggers Session activation. No delegation, guardian
transport pin, transport token or Fetch occurs before Session has processed
`:gaoxy_cleanup_activate` and passed host/cancellation/deadline checks.

After activation, fixed Session knows its transport; group Session first performs
ordinary group selection and records its selection token. A managed selected
member sends the native pump a request event containing the private handoff
reference, its Session PID, selected handle, identity and decreasing opening D.
Session enters a cancellable awaiting-pin state; it must not block its GenServer
in a receive or synchronous call to the native process. Existing total/opening
timers and owner/service monitors remain effective.

Native pump accepts this event only from its recorded Session identity with the
exact private reference, once, before ready/upload, within current D, and for the
fixed handle or a member of the captured group sidecar. A PID field alone is
insufficient authentication. It selects the exact source pin it already owns
and calls `delegate_request_pin/6` under the minimum native/Session deadline.
No group↔transport call occurs. The transport owner authenticates native caller
and authority/instance atomically, including naturally closed old resources.

Native sends the result back with the private reference. Session accepts exactly
one matching result while awaiting it, rechecks cancellation/D, stores its new
pin immediately, then calls the **unchanged guardian-authenticated checkout**
as `self()`. It bypasses open-only `validate_endpoint/3` only on this delegated
branch: equivalent strict identity validation has already occurred atomically
inside delegation. Direct fixed/probe paths continue to validate then acquire
ordinary guardian pins. Never use the source pin as checkout credentials.

On native cancellation/timeout/drain or Session death during handoff, cancel the
pending operation/release a known undelivered grant; do not wait past D. A late
grant received by a canceled Session is released without checkout. Native drain
can shorten D; include current native D in the reply, and Session takes the
minimum before checkout. Duplicate/stale/forged requests and replies cannot add
pins or tokens. Successful handoff does not start a new budget. Subsequent Fetch,
same-original-completion binding, uncertain-token handling, group-health outcome
and Service cleanup order remain the accepted endpoint/group contracts.

## Candidate preparation and atomic replacement

No new generic Generation resource API is required. Pure Router collection
already deduplicates resources, and group sidecars expose the full set. Use an
explicit **candidate coordinator** (the embedding/reload caller, not a new
production service) that remains alive from transport/group preparation through
activation result and cleanup. It prepares fresh resource handles with explicit
CA DER and numeric address, holds all candidate preparation pins, invokes pure
`Generation.prepare`, then CAS `Generation.activate` against the captured old
generation. Acquire new baseline before releasing candidate preparation pins.

Do not create transport/group resources inside the short-lived
`Generation.prepare_with` loader and assume its preparation pins survive: the
store terminates that worker after compilation. Loader reads/pure compilation
may still be used; managed resource ownership stays in the live coordinator.
This is a documented embedding contract, not standalone reload integration.

On stale CAS, invalid route, capacity/preparation failure or activation timeout,
release **only candidate-owned** preparation pins. Generic partial baseline
acquisition rollback retains the old router/baseline. Shared handles survive
other live pins. Candidate coordinator death drops its holds via monitors;
successful activation's new baseline survives it. If activation reply is lost,
releasing candidate pins is safe because activation owns the new baseline;
observe current generation rather than retrying activation blindly.

Replace old/new resources atomically even at the **same authority**. New numeric
address or DER trust creates a new immutable transport; never mutate an existing
resource. A native snapshot taken before activation keeps old group selection
and old transport policy even when its dispatch starts after old baseline
release. Fresh snapshots use only the new router/resource set. New probes stop
on old groups at retirement; old admitted requests drain through their captured
rights. A stale CAS must open no candidate request/probe after its candidate
configuration is retired, apart from already admitted in-flight cleanup.

Store death closes configuration admission by dropping its baselines. Already
pinned old requests may complete through authenticated derivation while the
instance/transport owner still runs; new snapshots fail. Explicit instance or
transport-owner retirement overrides this right and rejects handoff/checkout.
Late cleanup cannot change the original timeout/non-success result into success.
Physical resource reservations remain until public retirement and creator/helper
joins, separately from zero active request tokens.

## Required acceptance

Use deterministic barriers before dispatch, before handoff admission, after grant
and before checkout, plus finite monitors/polling. Required unit cases cover
wrong holder/acquirer, forged/expanded/stale pins, wrong owner/epoch/instance/
authority, source missing handle, baseline/preparation source, derived chaining,
duplicate grant and replay after release, capacity at exact pin/payload limits,
expired/extended deadlines, caller/guardian death, delayed replies, cancel/release
reordering, source release independence and explicit retirement-before-grant.
No denied identity request allocates a request token or mutates valid policy.
Assert no permanent operation/consumed-ref history after source/child cleanup.

Real TCP and verified TLS tests cover fixed and group routes. Hold the old native
snapshot **before Session starts**, activate new configuration, await actual old
baseline release/admission closure, then dispatch old and fresh requests. Require
exact old/new peer identity and bytes, original completion, no duplicate outer
pins, Session-owned guardian pin and physical old-peer EOF after final cleanup.
TLS uses same authority and port on distinct loopback addresses with distinct CA
DER chains and leaf identities; record SNI and exactly null ALPN. Swap to fresh
numeric address **and** trust atomically. Wrong CA/hostname must fail with no
fallback/replay. Local fixture certificates are never operational certificates.

Include stale CAS, route/preparation/partial baseline failures, coordinator/store
death, old request cancellation, held ACK/completion, bounded instance stop,
late cleanup and 20 sequential reload cycles after a two-cycle warmup. Join each
retired resource before the next steady-state sample; compare owner-owned
resource/pin/token/helper/serialized-payload counts and group records/bytes to
the first identical topology sample. They must plateau, and reach zero after
final stop with independently observed peer EOF and owned actor joins. This
measures Gaoxy's bounded ledger, not total VM/OS/native allocation.

Readiness review precedes implementation. Independent SPEC then CODE review
after GREEN and fresh source-bound verification precede local commit. All
execution remains **NOT RUN** here; existing release/foundation results do not
qualify this slice. H2 and standalone require separate bounded packages.
