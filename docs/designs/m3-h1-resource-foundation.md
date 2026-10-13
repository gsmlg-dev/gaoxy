# M3 H1 transport resource foundation

Date: 2026-10-13 Asia/Shanghai. Status: **DESIGN ONLY; implementation and runtime
acceptance NOT RUN**. This is the next bounded package of existing
[M3 upstream-transport Task 4](../plans/m3-upstream-transport.md#task-4-pure-policy-and-bounded-transport-resource-conditional),
after the current M4 verification completes. It is not a new milestone.

Source checkpoint: `.trees/m4-http3`, branch `codex/m4-http3`, HEAD
`d5831d7613e8c8edd2adf76fbd7b86b408e62de6`, with concurrent uncommitted M4 work.
Recheck the execution checkout and installed cohort before implementation.
Continuing authorization permits routine design, implementation and local
review; the parent releases source freezes and assigns exclusive file ownership.

## Decision and boundary

Implement the existing Task 4 contract in three dependent slices:

1. Generic instance-stop participants in core, verified without any HTTP client.
2. Pure immutable H1 options and an instance-associated transport ledger whose
   persistent custodians create and retire public managed scopes.
3. Existing resource-provider pins, separately accounted request holds and
   transport retirement receipts, with bounded public-API network qualification.

Production endpoint, Session and generation activation remains **Task 5**.
Group selection/probes and upstream H2 require later packages of the existing
M3 plan. Existing endpoints continue using dedicated H1; preparation or a green
resource test must not advertise production connection pooling.

The alternatives are to start with endpoint integration, which mixes lifecycle
ownership with traffic activation, or to rely on instance DOWN/idle expiry,
which cannot contribute retirement evidence to `Gaoxy.stop/2`. The selected
sequence makes the stop barrier independently testable before resource creation.

This package adds no dependency, HTTP protocol implementation, public management
endpoint, deployment, operational certificate, Vault change or release-artifact
E2E enablement. It preserves the reviewed dismissal of `http_fetch#97` and does
not replace it with native-memory certification or historical P0–P6 gates.
Historical accounting facts and failures remain unchanged; the old
`ManagedH1Accounting.activation_status/0` is not a gate for this package.

## Verified source and public API

The installed pins are `http_fetch == 0.21.4` and `http_runtime 0.21.4` in
`apps/gaoxy_proxy/mix.exs:16` and `mix.lock:10`. Both package `mix.exs` files
identify `https://github.com/gsmlg-dev/http_fetch` as their source. These are
source observations, not fresh managed-H1 runtime qualification.

| Source | Verified contract and implication |
| --- | --- |
| `deps/http_runtime/lib/http/managed_transport.ex:3` | Public managed generation, fixed origin/literal address, immediate request/connection capacity rejection, no replay. Creator death initiates abort retirement. |
| Same file, `:40` | H1 HTTP/HTTPS supported; finite request/connection limits, `max_pending: 0`, immutable OTP TLS/socket policy. Trust is captured at open. |
| Same file, `:111` | `open(options)` returns `{:ok, scope}` or error. Its handle call has the default 5,000 ms timeout; there is no caller-deadline argument. |
| Same file, `:136` | `snapshot(scope, finite_ms)` returns bounded aggregate status. Status failure is not retirement proof. |
| Same file, `:140` | `retire(scope, mode: :graceful | :abort)` returns an opaque durable receipt; initiation has a fixed 5,000 ms control call. |
| Same file, `:166` | `await_retired(receipt, finite_ms)` returns `:ok`, pending or unconfirmed cleanup. Repeat waits use the public receipt; coordinator termination is part of success. |
| `deps/http_fetch/lib/http/promise.ex:59` | `HTTP.Promise.completion(promise)` captures the original request completion. |
| `deps/http_fetch/lib/http/request_completion.ex:3`, `:76`, `:95` | `await/2` and `abort_and_await/2` are finite request barriers. Reused H1 connections may remain open after request completion. |
| `apps/gaoxy_http/lib/gaoxy/http/resources.ex:5` | Existing provider callbacks are `pin_many/5`, `release/1`, `cancel/2`; facade calls remain `Resources.pin_many/4` and `Resources.release/1`. Handles are capped at 64 and 65,536 serialized bytes. |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex:25` | Pure compact policy/request preparation already exists: H1, C2/R32/P0, explicit literal address, nil/PID upload, bounded DER trust, manual/raw streaming profile. It opens no scope. |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex:65` | Current production Fetch adapter explicitly uses `:http1` and `http1_reuse: false`. |
| `apps/gaoxy/lib/gaoxy.ex:40`, `gaoxy/instance.ex:115`, `gaoxy/lifecycle.ex:196` | Public stop has one absolute deadline and a service-drain coordinator. It currently has no external-resource participant registry. |

The facade file SHA256 is
`2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.
No missing public API blocker was established by this source assessment.
Dependency source is read-only: use only the documented APIs above, without
inspecting opaque scope/completion/receipt fields or private pools/processes.

## Slice A: generic instance-stop participants

Retain the existing design's proposed API:

```elixir
Gaoxy.register_lifecycle_participant(instance, timeout_ms)
# Called by the participant itself before external resource allocation.
# {:ok, registration_handle} | {:error, reason}
```

Core authenticates the GenServer caller PID, monitors it, rejects duplicates and
registration after stopping, and caps all live/failed registrations at 64.
Registration is instance-lifetime. There is no unregister/replacement operation
that could discard unconfirmed resource ownership. A registration timeout must
not permit the caller to allocate a managed scope.

Core stores only generic PID, monitor, registration/epoch references and bounded
outcome metadata. It must not depend on `gaoxy_http`, `gaoxy_proxy`, HTTP Fetch,
protocol types or upstream policy. The new behavior belongs in existing core
files, not a global application service or transport-specific core callback.

For `Gaoxy.stop/2`, close configuration admission, capture services/participants
and dispatch both barriers before awaiting either set. The coordinator sends:

```elixir
{:gaoxy_lifecycle_drain, registration, operation, coordinator, absolute_deadline}
{:gaoxy_lifecycle_result, registration, operation, participant_pid, result}
```

Validate registration, active operation and registered sender identity. Forged,
duplicate and stale receipts cannot settle a participant. Participants reply
directly to the coordinator, keeping `Instance` responsive and avoiding a call
back into an instance already terminating. Receipt collection and monitor
handling must accept either delivery order without discarding an already
authenticated result.

Use the original D for service drains, participant retirement and public waits.
No timeout starts a new success budget. Preserve existing service-only result
shapes when the participant set is empty. Pending at D remains
`{:error, {:deadline_exceeded, :cleanup_pending}}`. Participant death without
confirmed success records resource-tagged `:cleanup_unconfirmed`; known failures
use the existing design's `{:error, {:shutdown, service_errors, resource_errors}}`.
A coordinator crash cannot become success.

`Instance.terminate/2` uses the same combined helper: reuse explicit-stop D or
the existing bounded shutdown deadline, and retain the earlier non-success
result. Existing cleanup headroom permits cleanup after D, not a late successful
public stop. Configuration owners call `Gaoxy.stop/2` while participant siblings
are alive, then stop their enclosing supervisor.

## Slice B: immutable H1 resource and persistent custodian

Create `Gaoxy.Proxy.UpstreamTransports` and its pure `Options` module. An owner
is explicitly supervised alongside its instance, registers before resource
allocation and monitors that instance. Use temporary children; a blank restarted
ledger cannot replace uncertain live ownership.

`Options` accepts a strict fixed-shape policy source and delegates compact
construction to `ManagedH1Preparation`. Retain C2/R32/P0, explicit H1, literal
address, OTP TLS, frozen DER trust, fixed finite socket/idle policy. Requests
cannot override authority, address, trust, protocol or transport identity.
No arbitrary upstream keyword passthrough, SSL callbacks, file-reader policy or
client-certificate feature is introduced in this slice. New trust requires a
new immutable resource. Per-request timeouts are decreasing budgets, not policy
identity changes.

Owner limits require explicit finite positive resource, pin, request-token and
owned-payload budgets; resource count cannot exceed the existing 64-handle
boundary. Reuse the existing plan's no-queue admission. Reserve record/policy
payload and finite connection capacity before any custodian or scope creation.
Count opening, active, retiring and failed records, and unsettled helpers.
Do not derive a total VM/OS memory reservation from serialization size or the
historical subtotal. Accounting tests concern actual owned payload/holds and
finite counts; the scope of these bounds must be stated in status/evidence.

Each admitted record gets one persistent custodian that calls public `open/1`
and remains alive through retirement. A short-lived preparer must never be the
scope creator. A timed-out/dying preparer cannot publish a handle; a late open
result is retired and its reservation stays held until public confirmation.
Open/retire initiation may outlive a short D because the public calls use fixed
5,000 ms timeouts. Run them outside the ledger, retain their ownership and
finite capacity, and bound each record to one initiation helper and at most one
abort-escalation helper. Public response waits remain bounded by D even while
cleanup continues. Never kill a custodian to pretend its allocation is gone.

An immutable handle contains provider, owner PID/epoch and resource identity,
not a socket, client PID, credentials or public managed-scope internals.
`status/1` returns bounded redacted counts/lifecycle/limits; no request history.
Cross-instance/stale-epoch handles and oversized batches reject before effects.

## Slice C: pins, request holds and retirement

Keep the existing Task 4 interfaces:

```elixir
UpstreamTransports.start_link(instance: instance, limits: limits)
UpstreamTransports.prepare(owner, options, preparer, absolute_deadline)
# {:ok, handle, preparation_pins} | {:error, reason}
UpstreamTransports.checkout(handle, request_pins, guardian, absolute_deadline)
# {:ok, immutable_client_policy, request_token} | {:error, reason}
UpstreamTransports.bind_completion(handle, request_token, completion)
UpstreamTransports.finish(handle, request_token)
UpstreamTransports.retire(owner, absolute_deadline)
# {:ok, owner_retirement_receipt} | {:error, reason}
UpstreamTransports.await_retirement(owner_retirement_receipt, absolute_deadline)
UpstreamTransports.status(handle)
# Provider: pin_many/5, release/1, cancel/2; no new facade cancel API.
```

Baseline/preparation/request pins are metadata capabilities. Holder monitors,
caller-created operation references and idempotent cancellation/release prevent
late pin acquisitions from escaping the ledger. Checkout requires an admitted
request pin held by the authenticated guardian and a live resource epoch.

A request token is distinct from every metadata pin. Bind the original public
request completion immediately after Fetch opens, before publishing request
success. `finish/2` releases that request hold only after public completion;
pending/unconfirmed cleanup keeps it accounted. Guardian death initiates bounded
public abort/recovery. An open-to-bind failure retains the uncertain request
hold and triggers resource retirement; it never refunds on guardian DOWN alone.

A request completion releases no transport reservation. Physical transport
capacity survives idle reuse and is released only after the public managed
retirement receipt confirms `:ok`. Losing baseline/preparation pins closes new
pins; captured request pins/tokens may finish before ordinary resource retirement.
Instance retirement closes all new preparation/pin/checkout admission immediately,
invalidates configuration pins as admission capabilities, and retires idle
scopes without waiting for a live generation store to release baseline pins.

All owner retire calls join one operation whose D can only tighten. Graceful
retirement drains admitted requests; at D request public abort escalation.
Recover an initiation result only by bounded repeated public `retire/2`, then
wait on its opaque receipt with `Lifecycle.remaining(D)`. Snapshot errors or
helper DOWN do not confirm release. Late public confirmation may refund held
capacity; it cannot rewrite a timed-out stop receipt as success.

After successful retirement, keep the owner inert until instance DOWN so it
can return its cached authenticated result. Unexpected instance DOWN closes
admission and retires under known D or the configured finite emergency budget;
that fallback does not certify the preceding instance stop. Owner death before
confirmation leaves the core registration failed and prohibits blank restart.

## Acceptance and nonclaims

Slice A uses deterministic generic participants with receive barriers: forged
and stale receipt rejection, registration boundary, concurrent service/participant
fan-out, identical D, cached success, pending/failure/death, coordinator death,
termination path, unchanged no-participant behavior and instance isolation.
Core-only consumer/dependency isolation is required; HTTP startup is forbidden
for these tests.

Slices B/C test option rejection before allocation, custodian lifetime, exact
ledger deltas, refusal at finite limits, late preparation/pin cancellation,
stale identities, idempotence, open-to-bind uncertainty, completion pending and
retirement pending/unconfirmed without credit refund. Use public aggregate status
and test-owned actor monitors, without exposing private dependency state.

For actual managed H1 ownership, use an independent raw TCP/CPython OpenSSL
origin with finite readiness/receive barriers and exact connection/request IDs.
Prove sequential self-delimited requests reuse one connection; original request
completion can settle while that connection is idle; retirement closes it and
public receipt joins; retiring instance A preserves same-origin instance B.
Hold an unread response or upload producer at a peer barrier to test cancellation,
no replay, request-credit retention and short-D stop uncertainty. TLS qualifies
CA/hostname/authority with the literal dial address. Preserve exact body hashes,
trailers, finite deadlines, nonzero executed counts and all owned joins.

Record source/cohort identities, commands, counts, exits and receipts with PASS,
FAIL, BLOCKED and NOT RUN distinct. Require independent specification and code
review plus fresh scoped verification before each local commit. This package
does not establish production endpoint pooling, upstream H2, total native-memory
bounds, full M3 acceptance or publication/deployment. Its implementation,
tests, independent review and real-peer acceptance are currently **NOT RUN**.
