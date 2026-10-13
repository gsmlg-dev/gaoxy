# M3 managed H1 fixed-endpoint activation

Date: 2026-10-13 Asia/Shanghai. Status: **DESIGN PREPARED; implementation,
runtime verification and independent review NOT RUN**. This is the next bounded
slice of [existing M3 upstream-transport Task 5](../plans/m3-upstream-transport.md#task-5-endpoint-session-group-and-generation-integration-conditional).
It starts only after the entire [H1 resource foundation](m3-h1-resource-foundation.md)
passes its prescribed gates. Accepted foundation Steps 1–6 alone do not release
this package. See the [implementation plan](../plans/m3-managed-h1-fixed-endpoint.md).

## Source and authorization

Preparation inspected `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, at
`a2296e2ca9f24b8fd0480b06a6728fc15d190520`. This is the accepted, locally committed
Step 6 source, not the future implementation baseline. Step 6 repair 1 passed
74/0 but was rejected by independent specification review; repair 2 passed
75/0, independent SPEC then CODE review and fresh 75/0 verification. Preserve
both histories. Full foundation independent TCP/TLS acceptance remains outside
this preparation's evidence. The parent records its actual result and the
actual implementation path, branch, HEAD, tree, lock hashes, diff, untracked
inventory and writer ownership at kickoff. No future source SHA is invented.

Continuing authorization selects and executes the recommended bounded design
without routine approval pauses. Parent-managed Sol workers own implementation
and independent review; the parent owns serialized Mix/build/live commands and
local conventional commits. Preparation owns only this new design and its new
plan. Other source, evidence and documents belong to their assigned writers.
Carry unsuccessful UP2 counts **20 live / 8 production / 3 harness** and
**Astra recovery 2/2 exhausted**. Record subsequent Sol repair rounds across
handoffs; no counter reset or third Astra recovery is authorized.

Local development only: no push, package/image/release publication, deployment,
production data or operational certificates, Vault changes, public management,
or enabling/running the disabled release-artifact E2E workflow. Local fixture
certificates are test inputs. `http_fetch#97` remains excluded and is neither
recreated nor made a gate.

## Goal and exact boundary

An explicitly prepared H1 resource can serve a fixed reverse-proxy endpoint
through the existing HTTP Session and HTTPFetchClient. Sequential requests can
reuse the same upstream connection while retaining exact raw streaming, manual
redirects, no replay and original public completion ownership. Omitting the
transport keeps the existing dedicated-H1 behavior and its tests unchanged.

Production changes are limited to:

- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`: optional handle, pure validation,
  resource declaration and fixed dispatch pins.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`: authoritative validation,
  guardian pins, one transport checkout, completion binding and cleanup joins.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex`: managed Fetch option
  construction retaining the existing request/completion callback shapes.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`: one bounded read-only
  endpoint identity check; no modification of existing pin/token authentication,
  retirement joins, control-call limits or four-field handles.

Create `apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs`. Existing
`http_proxy_runtime_test.exs`, `http_proxy_wire_test.exs`, `http_proxy_tls_test.exs`
and `http_fetch_completion_test.exs` are scoped compatibility checks; change
them only if a necessary additional assertion cannot live in the new file.
Use existing fixture generation and local TCP/OTP TLS peers, without adding a
production dependency. Parent-owned acceptance documentation/evidence records
actual execution separately.

Groups, probes, Generation snapshot adoption/reload tests, upstream H2/h2c,
HTTP/3 integration, standalone configuration and capability declarations are
separate later packages. Generic HTTP Resources, Router and Generation remain
unchanged. `HTTP.resources/1` exposes the optional handle for the existing
endpoint contract; this package qualifies fixed dispatch outside Generation
only and must not advertise Generation integration. Current dedicated group
and H3 paths remain unchanged.

## Chosen option and alternatives

Use the existing four-field handle plus a read-only owner identity check before
token allocation. This adds one bounded compatibility call and keeps policy
authoritative in the existing owner. Copying policy into a larger handle or
trusting a caller-supplied descriptor would duplicate trust and break the frozen
handle contract. Validating only after checkout would allocate an unbound token
for a simple URI mismatch and poison cleanup accounting. The selected check
avoids both problems without adding a process, owner history or dependency API.

## Endpoint configuration and pure validation

The opt-in is `%{upstream: origin, transport: prepared_handle}` with existing
request limits. `upstream_protocol` is absent or `:http1`. Preserve HTTP's
existing config struct round-trip validation with a new `transport` field that
defaults to `nil`. Dedicated configurations retain their existing defaults and
certificate-file/numeric-pin behavior.

For a non-nil transport, `HTTP.init/1` validates exactly the existing identity:
`%{provider: Gaoxy.Proxy.UpstreamTransports, owner: pid, owner_epoch: reference,
resource: reference}`, four keys only. Validate a bounded root HTTP/HTTPS
authority, existing finite request limits and H1 compatibility. Reject non-nil
`cacertfile` or `connect_address` endpoint overrides, H3/H2 selections, unknown
keys and arbitrary client/options passthrough. Nil fields remain valid in a
struct round trip. Managed endpoint trust, dial address and socket policy come
only from preparation; matching duplicate overrides are deliberately omitted
from this narrow opt-in. No default trust or new file reads occur in this path.

Pure init does not call an owner, read its state, start a process, open a scope,
resolve DNS or claim authoritative identity/trust matching. Count-only status
cannot establish policy identity. `resources(config)` returns `[handle]` for
managed fixed config and `[]` for dedicated config.

Add the internal facade:

```elixir
UpstreamTransports.validate_endpoint(handle,
  %{origin: root_origin, upstream_protocol: :http1, instance: instance_pid},
  absolute_deadline)
# :ok | {:error, reason}
```

Reject malformed handle/identity before calling an owner. The identity map has
exactly three keys, a root-origin binary of at most 65,536 bytes, the fixed H1
protocol and a PID. Validate authority syntax using existing strict preparation
rules and compare normalized `{scheme, lowercase_host, effective_port}` with
the owner's stored prepared policy. Owner handler checks current epoch/resource,
matching `state.instance`, running owner, active/admitting resource and deadline
before returning `:ok`. A valid different authority or instance returns
`{:error, :transport_endpoint_mismatch}`; malformed identity returns
`{:error, :invalid_transport_endpoint}`. Retiring/unavailable/stale cases retain
the applicable existing resource/lifecycle/deadline errors. Return no policy,
trust bytes, scope, token or credential data; retain no supplied identity and
return the identical state. This check is not a checkout capability: subsequent
pin acquisition and checkout independently recheck lifetime/admission, preventing
a validate-to-checkout retirement race from opening a request.

## Lifetimes and request flow

Embedding code explicitly owns the instance, transport owner and metadata
baseline. Prepare with explicit numeric address and, for HTTPS, explicit DER CA
trust. Acquire a baseline pin before releasing preparation pins; keep its holder
alive for the fixed endpoint's configured lifetime. No hidden global owner or
owner created in `HTTP.init/1`. Stop the Gaoxy instance and confirm its retirement
before tearing down the sibling transport owner/baseline holder. A supervisor's
reverse child shutdown alone must not kill a sibling owner ahead of Gaoxy's
participant drain; arrange explicit stop ordering. Unexpected actor death
continues to use the foundation's conservative independent cleanup path.

Start the empty instance first, prepare its transport, then use existing
`Gaoxy.HTTP.service_spec/1` and `Gaoxy.add/2` to install the fixed service on
that same instance. `Gaoxy.HTTP.start_link/1` would create a different instance
and must not be used to attach an already instance-owned handle. No core or
HTTP service-start API changes are required. A service-add failure releases the
candidate's preparation/baseline pins and retires its resource through the
existing public owner lifecycle; keep actor ownership until cleanup confirms.

1. Native endpoint dispatch acquires an outer request metadata pin for the
   configured handle with `Resources.pin_many([handle], self(), :request, D)`.
   Retain it through `HTTP.call` and release in its `after` path. Pin failure
   returns unavailable without starting Fetch. This fixed-only path does not
   adopt or reinterpret Generation snapshot pins.
2. Start Session without network work; attach its service cleanup reservation
   through existing `Gaoxy.Service.attach_cleanup`. Admission denial cancels
   Session before activation, therefore no guardian pin, token or Fetch opens.
3. Upon authenticated `:gaoxy_cleanup_activate`, enforce existing cancellation,
   host-support and deadline checks. Validate endpoint identity against its
   instance using the bounded owner call above, before transport checkout.
4. Activated Session acquires its **own** request pin as `self()`, then calls
   `checkout(handle, guardian_pins, self(), min(D, opening_D))` once. Native
   dispatch pins belong to a different actor and cannot authenticate this
   checkout. Pass only the dedicated transport pin batch, not unrelated owner
   pins. On failed checkout release guardian pins; there is no token to finish.
5. Keep independent Session fields for guardian pins, transport `{handle, token}`
   and selected immutable client policy. Preserve the separate group selection
   field and existing Service cleanup token. Open one Fetch using the selected
   prepared origin plus the raw request path/query after identity validation.
6. Store the original request handle and bind `client.completion(request)` to the
   transport token before notifying `{:ready, upload, limits, D}`. The upload
   source may be created during open but receives no pump bytes before binding.
7. Preserve existing acknowledged upload/response delivery, trailer filtering,
   early final responses, cancellation and deadlines. There is no automatic
   alternate endpoint, retry, redirect follow or request replay.
8. Session polls/aborts the **original** public completion. On confirmed cleanup,
   finish the transport token, release guardian pins, then complete Service
   cleanup and join Session. Pending/unconfirmed completion retains accounting
   and cannot complete the Service reservation. Finish/pin-release errors remain
   visible; do not convert them into success. Outer dispatch pins have their
   independent release path. Holder/guardian monitors cover actor death.

## Adapter and uncertain failures

`HTTPFetchClient.open/1` receives internal `managed_transport` client metadata
only from Session checkout; it is not an endpoint/public options passthrough.
Dedicated Fetch options remain unchanged. Managed options use the fixed
`client.fetch_options`, `transport_scope: client.transport_scope`, request
URL/method/headers/upload PID/duplex, timeout and connect timeout. Omit dedicated
SSL, connect-address, socket-buffer and send-timeout overrides. Scope preparation
owns fixed socket writer settings; endpoint write deadlines still bound local
pump work. Preserve the conservative existing per-request reservation unless
new measured evidence requires a separately reviewed compatibility adjustment.

Use existing `ManagedH1Preparation`/Options request validation for compact,
bounded URL/fields/nil-or-PID upload input before public Fetch. Preserve raw path
escaping and present-empty-query distinction. Return the existing
`{:ok, %{promise: promise, completion: original_completion, stream: nil,
resolved: false}, upload}` shape; completion/cleanup callbacks remain unchanged.
Never traverse opaque scope/completion internals or private dependency processes.

Ordinary no-transport service paths require no extra owner identity/pin calls.
For managed cancellation/actor death, metadata holder monitors may remove an
outer dispatch pin before request cleanup; the independently bound request token
and guardian cleanup continue to retain ownership. Such metadata release cannot
refund a request token or physical reservation.

If checkout succeeds but open/bind fails without a usable original completion,
the request token is uncertain. Existing finish-without-completion behavior
returns cleanup unconfirmed and triggers resource retirement; guardian death
does not refund it. Join any owned upload helper through existing finite cleanup,
report failure and preserve the unresolved hold. Do not add a cancellation API
that pretends no request existed. If a request/completion exists but binding
fails, attempt its public abort/join while retaining the token; failure remains
visible. No-request validation/admission/checkout rejections avoid this branch.

Request cleanup releases request tokens, not physical transport reservations.
Sequential reuse keeps the idle resource accounted. Only public scope retirement
confirmation plus helper/creator joins can refund physical capacity and permit
successful instance stop, as already implemented by the foundation.

## Acceptance

The new ExUnit file uses real TCP and independently observed OTP TLS peers.
Both modes must prove sequential one-connection reuse, exact binary bytes/raw
targets/duplicate headers, upload before producer EOF, ordered trailers, raw
responses and manual redirects. Verified TLS uses local fixtures from
`scripts/generate-fixtures.sh`, explicit CA DER converted during preparation,
authority/SNI with a numeric dial pin, and wrong-CA/hostname rejection without
plaintext fallback or replay. No endpoint CA-file reload or credential forwarding.

Deterministic Session barriers/monitors prove no work before cleanup activation,
original bind before upload readiness, token/pin retention through pending
completion, finish only after actual public cleanup, native-owner death and
guardian death cleanup, and bounded shutdown while a request/ACK is held. Scope
and peer assertions distinguish active request cleanup from idle transport
retirement: zero tokens after completed requests with reservation still held;
physical peer EOF, creator/helper joins and zero owner accounting after stop.
Malformed/stale/cross-instance/mismatched authority checks allocate no token and
do not poison a valid resource; a subsequent valid request succeeds. Retirement
between identity validation and checkout rejects before Fetch. Dedicated default
two-connection and cleanup assertions remain unchanged.

Independent SPEC review precedes implementation; after GREEN, independent SPEC
then CODE review resolves actionable findings followed by fresh affected
verification. Parent records source hashes, environment/cohort, command, nonzero
counts, exits and owned peer/actor shutdown, distinguishing PASS, FAIL, BLOCKED
and NOT RUN. All package execution and review remain **NOT RUN** in this design
preparation. Acceptance does not imply full Task 5/M3, hosted CI, publication,
deployment or production acceptance.

## Preparation review and current prerequisite disposition

The [independent document review](../acceptance/evidence/m3/h1-resource-foundation/1791870010586271722/next-task5-document-review.json)
passed design SPEC and plan readiness against the exact preparation hashes. The
historical preparation above records its initial unreviewed snapshot; this
receipt records the subsequent review. Implementation and network acceptance
remain **NOT RUN**. Full foundation is **IN PROGRESS** after an independent scope audit corrected a harness-added ALPN requirement to the original exact null contract. [http_fetch#107](https://github.com/gsmlg-dev/http_fetch/issues/107) is optional and no prerequisite. Do not release executable Task 5 ownership until foundation's
prescribed TLS/profile and final review gates pass. Continuing authorization
remains active; no approval pause or product-scope expansion is introduced.
