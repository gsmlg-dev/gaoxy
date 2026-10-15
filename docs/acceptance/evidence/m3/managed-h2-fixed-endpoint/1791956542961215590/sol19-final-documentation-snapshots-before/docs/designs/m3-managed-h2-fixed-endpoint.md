# M3 managed H2 fixed-endpoint activation

Latest execution (Sol19 local request status repair): activation remains
INCOMPLETE and uncommitted at baseline `31f23eb`, blocked by upstream122.
Sol19 trusted local_fail now preserves only native400/413/431 for
ManagedH2Client and immediately discards raw diagnostics to :invalid_request.
Generic upstream errors still normalize before status selection; original
cleanup, unset-head/total-expiry, close, caps and deadlines are unchanged.
Independent bounded SPEC then CODE PASS with zero open findings. Complete
endpoint GREEN1 PASS38/0 and affected lifecycle/H1/H3 compatibility PASS141/0
(21 native HTTP +120 proxy), exit0/source stable/zero skips or exclusions.
These scoped passes resolve LOCAL_REQUEST_ERROR_STATUS_LOST, not stage acceptance.

Sol19 RED1 remains fixture FAIL38/8 on its invalid Trailer assertion; its sole
correction asserts exact authentic H2 pseudoheaders and no hop fields. Genuine
RED2 FAIL38/8 reached the exact closed wire response after original pending
barriers and observed502 vs400x2/413x2/431x4. Original30 cases and all8
status/completion/cleanup assertions remain unchanged. Actual release, bounded
design/plan, exact candidates/reviews and RED/GREEN receipts are preserved as
`sol19-local-status-*` in the existing stage evidence directory.

Collector Sol17 complete matrix GREEN12 PASS135/135 and browser-sol17-1
PASS3/3, exit0/source stable, retain135 identities/four cells/120 original
assertions. Browser negative CA/name outcomes remain
UNCONFIRMED_WITH_RETAINED_FAILURE, not cleanup confirmation. Both passes
precede Sol19; fresh format38/strict compile/public63/matrix135/browser3 must
follow full independent SPEC then CODE on the frozen repaired candidate.
Those full re-reviews and fresh final unblocked gates are currently pending.

Live read-only recheck confirms [http_fetch#122](https://github.com/gsmlg-dev/http_fetch/issues/122)
OPEN/Bug/internal request/blocker. Latest v0.21.9/main `81ad386f` is unchanged
and fixes119, not122; dependency cohort remains0.21.4. Historical full58
FAIL845/1 expected original Promise:aborted but observed:einval. Later5/0 and
32/0 are not repairs. Full58 stays BLOCKED_UPSTREAM122 without workaround,
omission or weakened assertion, pending upstream fix and compatible update.

Counters: fixedSol19/unsuccessfulGREEN14; collectorSol17/unsuccessfulGREEN12;
matrixfailed11; browserfailed5; R32diagnosticfailed5; nativeH1 RED2/fixture2;
nativeH2 shape RED2/fixture1; local-status RED2/fixture1; full static CODE failed1.
Astra recovery2/2 remains exhausted. Owned46/format38/full58 remain complete.
Forward-only runner3 captures AGENTS.md/implement-plan.md alongside the earlier
source set; old receipts and smaller coverage remain immutable. No stage
acceptance, commit or next-stage activation is claimed.

Previous execution checkpoint (before matrix GREEN12 and Sol19), retained as history:

Latest execution: managed H2 fixed-endpoint activation is INCOMPLETE and
uncommitted. Native H1 Sol17/Sol18 focused GREEN2 passed67/0 with stable
source and narrow independent SPEC then CODE; historical failures are retained.
Fresh format37 and strict compile passed. Full58 executed845/1, exit2,
source stable with zero skips/exclusions. Its sole pre-head public H1
cancellation assertion expected:aborted and observed:einval after confirmed
cleanup. The unchanged file later passed5/0 and the bounded public diagnostic
passed32/0; neither result proves a repair or erases full58's failure.

Upstream [gsmlg-dev/http_fetch#122](https://github.com/gsmlg-dev/http_fetch/issues/122)
is confirmed OPEN, type Bug, label internal request, severity blocker for the
existing cancellation compatibility gate. The callsite has its required TODO;
no local workaround or weaker assertion is authorized. That task remains
BLOCKED until an upstream repair and compatible dependency update. Other
unblocked verification continues. Comment-only routing makes owned46/format38;
the required complete test manifest remains full58, with no omission.

Released canonical Collector Sol16 passed narrow independent SPEC then CODE.
Diagnostic8 PASS4/4 authenticated all128 held cleanup refs and2 refused extras
against all130 authentic raw calls (:ok, max6.594785ms), with real joins and
unchanged1024 caps. Diagnostic7's original overall FAIL remains historical.
Complete matrix GREEN11 remains FAIL87/135, exit1/source stable. The next H2
head-bytes-exact response needs65688 RFC metadata bytes; the fixture advertised
131072 but its decoder retained65536. This establishes a fixture mismatch,
not a production defect. The public update_settings/matching ACK candidate
preserves the existing finite131072 cap,135 identities and120 original collector
assertions. Initial independent SPEC passed; CODE found a first-request/ACK-send
absolute-deadline gap in a controlled-clock model. The targeted candidate repair
passed fresh independent SPEC then CODE with24 deadline and4 fail-closed
models and no actionable findings. Root released Collector Sol17 and its
managed-only peer ACK profile; complete matrix GREEN12 is pending execution.
The first reviewer response-vector arithmetic failure and exact correction are
preserved separately; it occurred before candidate execution.

Fresh public63 PASS63/63 is retained as scoped evidence; browser3 is not fresh
for the eventual final candidate. Current counters: fixed Sol18/unsuccessful
GREEN14; collector Sol17/unsuccessful GREEN12; matrix failures11; browser
failures5; R32 diagnostic failures5; native H1 poll-floor RED failures2/fixture
corrections2; native H2 shape RED failures2/fixture correction1. Astra recovery2/2
is exhausted. Full58 is BLOCKED by upstream122; format38, complete matrix135,
browser3, full stage independent SPEC then CODE and fresh post-review gates
remain required. No phase acceptance or commit is claimed.
Earlier execution summaries below are historical.

Latest native H1 compatibility execution: [clean RED2](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/native-h1-partial-upload-red2-1791989000488049202.json)
failed8/4 on exactly the four withheld-eight-byte cases, with the fixture
contracts corrected. Sol13's [GREEN1](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/repair13-native-h1-green1-1791989166975977591.json)
executed53/1: all8 new upload cases and original-deadline/cap/network checks
passed; the unchanged trailer-limit error contract was the sole failure.
The bounded short-read [independent SPEC then CODE review](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/native-h1-short-read-independent-spec-code-review.json)
passed with no findings. It does not accept the full fixed-H2 slice. Sol14
restores the exact response_trailer_limit reason at the trailer preflight,
retaining every bound and unchanged test assertion. Its focused GREEN passed63/0,
exit0, source stable and zero skips/exclusions.
Current cumulative counters are fixed Sol16/unsuccessful GREEN11, native H1
RED failed runs2/fixture correction1, header RED failed runs2/upload-event
fixture correction1, collector Sol14/unsuccessful GREEN9, matrix failed runs8
and browser failed runs5. Astra recovery2/2 stays exhausted. Sol15 relevant
GREEN87/0 and narrow SPEC/CODE PASS; pre-review full57 PASS824/0, stable exit0
with zero skips/exclusions. Collector Sol14's narrow SPEC then CODE review also
passed with no findings.
Matrix GREEN8 remains FAIL84, exit1/source stable. Both complete H1 cells and
H2→TLS functional/concurrent/controlled cases passed. The R32 repair dispatches
all32 authentic response commands before client joins in17.206/29.193/19.095ms
for those three cells, preserving opening/capacity/identity/byte/cleanup checks.
Those are collector observations, not certified Session timer receipts. Next
H2→TLS head255 expected200 emitted complete empty502. The same255 regular
upstream fields plus status passed both H1 cells. The supported public HPAX
runtime diagnostic confirms256 total fields are feasible: bulk encoding nests
its accumulator to depth258, exceeding the unchanged RendererBounds depth16.
Ordered single-field encoding returns identical bytes, exact public decode and
valid frames at depth4/nodes3832/ETF15994. This is codec diagnosis, not server
acceptance. The diagnostic source and receipt are retained in the evidence root.
Sol16 is planned to build one proper outer list using supported per-field HPAX
calls and carried encoder state, preserving empty-block resize-prefix semantics.
The existing aggregate preflight stays before binary conversion/frames, with
the transient input conservatively charged within the unchanged renderer
allowance, with no cap, field-count, byte or deadline change. Clean native RED2 executed57/2, exactly the head255/trailer128 refusal, while
empty-block wire semantics and renderer arithmetic passed. RED1 executed46/2
with generated-test type warnings; one warning-only fixture correction retained
all assertions. Source-stable RED2 has no compiler warnings. Sol16 production
is released solely for supported codec assembly; native H2 shape RED failed
runs2/fixture correction1 are separate cumulative counters. All earlier
failures and retained uncertainty remain. Complete135 and final complete
review/post-review gates are still incomplete.

Pre-review full57 is PASS824/0. Complete135 matrix, fresh public63/browser3,
final independent full SPEC/CODE and fresh post-review gates remain required
and incomplete.

Date: 2026-10-14 Asia/Shanghai. Status: **IMPLEMENTATION IN PROGRESS;
ACTIVATION CEILING UNACCEPTED**. This document defines the next bounded slice
after [managed H2 preparation](m3-managed-h2-preparation.md). The preparation
candidate has complete independent SPEC then CODE PASS, fresh format/strict
compile and 97 combined preparation/compatibility tests passing, plus fresh
63-case public qualification, both exit0 with stable source and no skips. These are predecessor
observations, not activation evidence. Accepted local preparation predecessor is
`c871e3d9ee87cf802acf764d7d7622e0a7b611d6`. Parent captures actual source/evidence
inventory at kickoff in `docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/`.

The [implementation plan](../plans/m3-managed-h2-fixed-endpoint.md) and
[acceptance contract](../acceptance/m3-managed-h2-fixed-endpoint.md) are normative
companions. The immutable [architecture proposal](../acceptance/evidence/m3/managed-h2-preparation/readiness-1791948336209525501/fixed-h2-activation-architecture-proposal.md)
is PROJECT_ARCHITECTURE, zero recovery. This design refines its envelope and
copy ledger; neither its historical 6,053,414 estimate nor preparation's
2,918,508 worksheet is a runtime reservation. Astra recovery remains 2/2
exhausted. Continuing authorization selects the recommended local approach and
execution automatically; no routine approval pause is introduced.

Current verification remains incomplete: full53 PASS761/0, public PASS63 and
browser PASS3 precede the latest changes. Matrix GREEN2 failed after13 cases
because local normalization changed the public capacity tuple into502 instead
of503. Both control supplements failed63/2; the bounded trace diagnostic
failed30/1 on a non-original-Task `{ref, false}` reply. Renderer network33/0
proved projection release and repeated terminal rejection. These preserved
partial results do not accept activation or replace final SPEC/CODE and fresh
verification. See the acceptance ledger for exact receipts and repair counters.
Matrix GREEN4 remains FAIL after15 completed cases, exit1 and source stable.
R32 passed with two actual SETTINGS ACK16 receipts,32 simultaneously held
requests, blank503 refusal33, healthy responses and joins. The next pre-EOF H1
upload sent16392 bytes but delivered only16384 upstream;8 bytes remained buffered
with Content-Length32781 and EOF withheld. The immutable
[diagnosis](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/matrix-green4-h1-partial-upload-diagnosis.json)
and [run receipt](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/matrix-green4-1791987688394641648.json)
preserve this failure; activation acceptance remains incomplete.

## Choice, goal and scope

Choose an additive `Gaoxy.Proxy.ManagedH2Client` implementing the existing
`UpstreamClient` behaviour, with a pure `ManagedH2Envelope` and an additive
activation evaluator in `ManagedH2Reservation`. Reuse `UpstreamTransports`, its
Custodian, Service admission and the existing Session/pump cleanup seam. Keep
the dedicated and managed H1 `HTTPFetchClient` paths. This isolates H2's delivery
and metadata contract without a second owner framework.

Extending `HTTPFetchClient` into a multi-protocol adapter would mix its qualified
H1 receive bound with native-H2's 1 MiB delivery contract. Introducing a separate
pool/supervisor framework would duplicate the accepted owner/Custodian lifecycle.
Neither is selected. Custodian remains read-only. Two demonstrated compatibility
seams are assigned below: protocol-neutral Generation exclusion, and bounded
downstream rendering/admission. Neither activates H2 Generation.

Activate fixed endpoints only, for upstream `:http2` over verified OTP SSL and
`:h2c` prior knowledge over TCP, using the exact `:native_v1` C2/R32/P0 policy.
Downstream native H1 and H2 are both required. There are no H2 groups, H2 probes,
H2 Generation activation, standalone configuration or sustained-load claims in
this slice. Those need their own design, plan and gates after fixed acceptance.
No private client processes, dependency patches, Bandit production substitute,
new dependency or new UpstreamClient callback is needed. Core isolation stays
unchanged. `http_fetch#97` and equivalent certification are excluded.

This is local development and local conventional-commit scope. Push, packages,
images/releases, deployment, production data/certificates, Vault changes, public
management and enabling disabled release-artifact E2E remain restricted.

## Existing and additive APIs

Existing owner signatures remain:

```elixir
Options.prepare_policy(source) # {:ok, policy, accounting} | {:error, reason}
Options.prepare_request(policy, source) # {:ok, request, accounting} | {:error, reason}
UpstreamTransports.prepare(owner, source, preparer, deadline)
UpstreamTransports.validate_endpoint(handle, identity, deadline)
UpstreamTransports.delegate_request_pin(handle, source_pin, guardian, identity, operation, deadline)
UpstreamTransports.checkout(handle, pins, guardian, deadline) # {:ok, client, token}
UpstreamTransports.bind_completion(handle, token, completion)
UpstreamTransports.finish(handle, token)
```

Dispatch H2 policy sources and H2 Policy request preparation through the accepted
`ManagedH2Preparation`; H1 retains `ManagedH1Preparation`. Neither path performs
I/O in preparation or endpoint initialization. Owner accounting includes complete
validated prepared values once, using its existing separate owner ledger.

The new pure helper contract is:

```elixir
ManagedH2Envelope.prepare(config, source) # {:ok, envelope} | {:error, atom}
ManagedH2Envelope.validate_request(envelope) # :ok | {:error, atom}
ManagedH2Envelope.validate_config(config) # :ok | {:error, atom}
ManagedH2Envelope.validate_checked_client(client, protocol) # :ok | {:error, atom}
ManagedH2Envelope.validate_trailer_policy(policy) # :ok | {:error, atom}
ManagedH2Envelope.validate_response(response, submitted_url)
# {:ok, %{status: integer, fields: compact_pairs, stream: nil | pid}} | {:error, atom}

ManagedH2Reservation.worksheet() # historical prospective output remains byte-identical
ManagedH2Reservation.activation_contract() # closed proposed ceilings/slot facts
ManagedH2Reservation.evaluate_activation(values) # {:ok, manifest} | {:error, atom}
ManagedH2Reservation.reservation_bytes(fields, url_bytes, chunk_bytes) # integer or ArgumentError
```

`source` has exactly seven keys: `url`, `target`, `method`, `fields`, `body_mode`,
`request_limits`, `max_upload_bytes`; `prepare/2` adds protocol from the validated
config. All validators are pure and reject additional keys, forged structs,
improper lists and oversized backing before normalization or serialization.
`evaluate_activation/1` takes exactly `request`, `config`, `checked_client`,
`trailer_policy`, `response_policy`, `response`. Request/config are mandatory;
other values may be nil when their phase has not produced them. Non-nil values
must satisfy their exact schema. The manifest records measured complete bounded
projections and named slot ceilings; missing values never reduce the ceiling.
Accounting markers for opaque capabilities are tagged atoms in the projection,
never replacements for the live capability. No private interior is serialized.

`ManagedH2Client` implements all existing callbacks:

```elixir
host_supported?() # same qualified host constraints, no global changes
reservation_bytes(fields, url_bytes, chunk_bytes) # delegates to additive evaluator facade
open(options) # {:ok, handle, upload_pid_or_nil} | {:error, finite_reason}
poll_headers({handle, submitted_url}) # {event, updated_four_key_handle}
event({handle, submitted_url}, public_message) # {event, updated_four_key_handle}
subscribe(handle) # :ok
write_body(upload_pid, bytes, timeout) # :ok | {:error, finite_reason}
finish_body(upload_pid, trailers) # :ok | {:error, finite_reason}
acknowledge(handle, data_ref) # :ok
completion(handle) # ORIGINAL public completion
await_completion(completion, abort?) # :ok | {:error, finite_reason}
cleanup(handle, abort?) # :ok | {:error, finite_reason}
```

`open/1` accepts EXACTLY seven keys without aliases:

```elixir
%{request: exact_eight_key_envelope, managed_transport: exact_checked_client,
  timeout: positive_integer, opening_timeout: positive_integer,
  write_timeout: positive_integer, deadline: signed64, opening_deadline: signed64}
```

Timeouts are1..86,400,000 and opening_deadline<=deadline. Nested envelope and
checked client protocol/origin match. `fields`/`body_mode` are sole sources;
no `headers`/`body` alias, trust/address override or arbitrary map is allowed.
Create upload from body_mode only after admission/checkout. This client does
not implement optional `begin_cleanup/3`. Cleanup returns only :ok or
`{:error, finite_reason}`, including cleanup_pending/unconfirmed; no updated
handle or pending tuple variant. Existing H1/H3 optional callback remains.

For H2 only, Session passes `{handle, submitted_url}` into poll_headers/event
using the same behaviour arities; all other callbacks still receive the exact
four-key handle. This transient two-tuple has no copied URL or stored Response,
and its <=128 wrapper bytes use the request-slot wrapper allowance. Before
resolution submitted_url must be a validated compact binary; afterward it is
nil. Returned handle remains four keys. This gives validate_response/2 an
executable public URL provenance path without storing it in private Task or
completion interiors. H1/H3 keep their current callback arguments.

Keep the existing event algebra: `:none`, `{:headers, status, fields}`,
`{:chunk, bytes, ref}`, `{:trailers, fields}`, `:end`, `{:error, reason}`. No
Response, preparation manifest or private native state crosses that seam.

## Protocol identity and exact configuration

The existing three-key identity retains its shape:

```elixir
%{origin: "https://upstream.test:443", upstream_protocol: :http2, instance: instance_pid}
%{origin: "http://upstream.test:8080", upstream_protocol: :h2c, instance: instance_pid}
```

Owner validation AND authenticated delegation compare
`{protocol, scheme, lower_host, port, instance}` against the prepared resource and
owner's instance. H1 maps to `:http1`; H2 uses `:http2` or `:h2c`. An H1 handle
and h2c handle for the same HTTP authority must never alias. Reject protocol,
authority, instance, epoch and resource mismatch before checkout or Fetch.
Captured pins retain their original immutable resource identity and cannot be
replaced with current routing information. Late handoffs are authenticated,
cancelled/revoked and released using the existing operation identity.

The compiled fixed config is the exact existing `%Gaoxy.Proxy.HTTP{}`: seven
fields `uri`, `cacertfile`, `connect_address`, `transport`, `limits`,
`upstream_protocol`, `client`, plus its struct tag. H2 requires non-nil managed
transport, `client: ManagedH2Client`, nil `cacertfile` and nil `connect_address`.
Only owner-prepared trust/address/scope can reach Fetch. Raw options retain the
existing exact whitelist; add `:http2`/`:h2c` only with this managed handle.
Dedicated H2 without a handle and managed H3 are rejected. Existing standalone
configuration and group preparation continue to reject unqualified H2 members.
Existing group/probe compile guards remain H1-only. Generic Generation currently
has no protocol gate, so add a protocol-neutral optional Endpoint callback:

```elixir
generation_validate(config) :: :ok | {:error, atom}
# Proxy.HTTP implementation:
generation_validate(%__MODULE__{upstream_protocol: p}) when p in [:http2, :h2c],
  do: {:error, :unsupported_generation_endpoint}
generation_validate(_), do: :ok
```

Generation.Store.compiled_bound/2 invokes it for every compiled route during
preparation AND activation; endpoints without it default to :ok. Reject other
returns/exceptions with a finite error. Static Router.compile still allows
fixed H2. No gaoxy_http->proxy dependency or proxy-specific module dispatch is
introduced. Test both Store paths and forged prepared routers; H1/old endpoint
compatibility remains. This narrowly prevents Options dispatch activating H2
Generation indirectly.

`transport` is exactly four keys:

```elixir
%{provider: UpstreamTransports, owner: pid, owner_epoch: reference, resource: reference}
```

`limits` is exactly five keys: `max_chunk_bytes` in 1..65,536, plus
`opening_timeout`, `idle_timeout`, `write_timeout`, `max_lifetime`, each integer
1..86,400,000. Do not globally narrow unrelated dedicated H1/H3 options.
The canonical URI has exactly nine keys including `__struct__: URI`, and
`scheme`, `userinfo`, `host`, `port`, `path`, `query`, `fragment`, `authority`.
Require `https` for TLS-H2, `http` for h2c; host 1..253, port 1..65,535, nil
userinfo/query/fragment, root path canonicalized to nil, exact raw-authority
validation preserving IPv4/IPv6/default ports and malformed-port rejection.
Origins have logical/backing <=65,536 before parse/copy; URI binary occurrences
are bounded/compact, aggregate within the 132,096 URI allowance. Complete fixed
config <=147,456 external-term bytes. Struct round trips revalidate exact schemas
and canonical equality; no unknown retained option map or path/query duplicate.

Checkout client is exactly `%{policy: policy, transport_scope: scope,
fetch_options: options}`. The scope is an opaque public capability. H2 Policy
has the accepted seven fields plus tag; validate its canonical open-options
schema, including SSL policy/trust and C2/R32/P0 limits through preparation.
`fetch_options` is a proper exact keyword list, each key once:

```elixir
[
  http_version: protocol, tls_backend: :ssl, http2_profile: :native_v1,
  http2_reuse: true, redirect: :manual, request_mode: :proxy,
  decode_body: false, stream_response: true, telemetry: false
]
```

Here `protocol` is exactly `:http2` or `:h2c`, matching the policy. Confirm the
supported pinned public H2 reuse option at the public-contract gate; an absent
required public option uses dependency routing, never a private fallback. Add
only prepared request method/fields/body, optional half duplex, finite timeout/
connect timeout and the owner's public scope at Fetch. There are no per-request
TLS, address, origin, profile, connection, pending, request-limit or scope
overrides. C2/R32/P0 and native SSL options are configured when opening the
owner-prepared scope. Checked policy projection <=1,183,744 includes its complete
finite wrapper/origin occurrences/approved options; opaque scope is a typed
marker only in the accounting projection. Owner policy is a separate charge.

## Pre-Session request envelope and upload

Before `DynamicSupervisor.start_child/2`, fixed-H2 HTTP dispatch constructs and
validates exactly this eight-key envelope; the original Exchange remains only
in its existing downstream pump/HTTP ownership boundary:

```elixir
%{
  protocol: :http2,
  url: "https://upstream.test/a%2Fb?",
  target: "/a%2Fb?",
  method: :post,
  fields: [{"x-trace", "first"}, {"x-trace", "second"}],
  body_mode: :chunked,
  request_limits: %{
    max_headers: 256, max_header_bytes: 65_536,
    max_trailers: 128, max_trailer_bytes: 65_536
  },
  max_upload_bytes: 65_536
}
```

Allowed methods are `:get`, `:head`, `:post`, `:put`, `:patch`, `:delete`,
`:options`. Body mode is `:none`, `:chunked`, or `{:length, n}` where
`n` is unsigned64 (0..18,446,744,073,709,551,615). Effective request limits are
the minimum of downstream limits and 256/65,536/128/65,536 respectively, positive
integers with exactly these four keys. Max upload is 1..65,536 and may be lower
by configured chunk size. Signed64 applies to every timestamp/deadline, including
computed opening/total/cleanup deadlines; reject overflow before scheduling.

URL and target are independently logical/backing <=65,536. Target is submitted
origin-form, keeps wire escaping and distinguishes no query from a present empty
query. Pair sources are proper finite lists, names/values are binaries, counts
<=256, aggregate name+value <=65,536, aggregate referenced backing <=65,536;
syntactic header rules and accepted effective pseudo/default-field limits also
apply. Source/compact URL+target+fields aggregate logical/backing <=196,608.
Copy only after finite traversal, grammar and backing preflight. Reserve the
complete envelope/prepared-request/options representation ceiling 205,337;
201,241 is the historical complete projection ceiling and 4,096 covers finite
scalars/wrappers/body modes/limits. Do not add that projection to its complete
representation again. No trailer policy, arbitrary Exchange, downstream limits,
manifest, socket, path/query copy or caller diagnostic is in the Session request.

Pre-Session validation checks the exact envelope, raw admissible source field
grammar/count/logical/backing, URL/target equality and origin, effective request
limits, finite body mode, and complete205,337 envelope ceiling. A nil-body
`Options.prepare_request` preflight can check URL/policy/pseudo/default-field
feasibility, but its canonical fields MUST NOT replace the envelope's compact
raw source fields: nil-body normalization removes Content-Length, which must
remain available for actual PID framing. Retain those validated compact source
fields in original order, including valid source Content-Length. No nil-body
manifest proves the later actual-PID request.

After Service activation
and successful authenticated checkout create the upload PID when body mode is
nonempty. Re-run `Options.prepare_request` with the ACTUAL PID before public
`HTTP.fetch`, so native generated Content-Type/defaults and Content-Length
placement are checked. This final preparation checks complete Policy/source
schemas, actual body PID, retained Content-Length first/middle/last with generated
or supplied Content-Type, effective native head count/bytes, projection and
complete representation ceilings. It must pass before any Fetch bytes. The
source is exactly seven keys:

```elixir
%{url: envelope.url, method: envelope.method, fields: envelope.fields,
  body: upload_pid_or_nil, trailers: [], timeout: remaining_total,
  connect_timeout: min(remaining_total, remaining_opening)}
```

Options.prepare_request constructs its full accounting even when ignored.
Charge the complete `{:ok, Request, accounting}` in the canonical-preparation
request slot. Request's eight fields plus tag fit201,753 (Q201,241+512
wrappers/scalars). Accounting is exactly owned_serialized_payload_bytes and
preparation, <=3,456. Preparation <=3,072 has exactly kind/source/owned/transient/
source_external_bytes/prepared_external_bytes/source_projection_external_bytes/
canonical_projection_external_bytes/effective_field_count/effective_field_bytes/
limits. Kind is :request. Source/owned each have logical_bytes, backing_bytes,
binary_occurrences, cons_cells, tuples, maps, atom_occurrences,
integer_occurrences, pid_occurrences; tuples/maps contain only schema-derived
arity/size integer keys and finite counts. Transient is exactly
source_plus_owned_backing_upper; limits is the accepted fifteen-key constant
map. Return wrappers<=128 yield201,753+3,456+128=205,337. Executable maximal
constructor tests must prove each cap AND complete return. Discard manifest
immediately after validation. Nil-body and actual-PID returns reuse this slot
sequentially, never two retained accounting returns.

Bind `HTTP.Promise.completion(promise)` to the original transport token BEFORE
`:ready` or any upload read. After binding, clear Session request envelope,
fixed selector, awaiting/opening config/client payloads and handoff payloads;
retain compact limits, resource selection/control, two handle shells, finite
managed_path:true and one compact submitted_url in the Session request slot.
Submitted URL<=65,536 logical/backing remains until validate_response/2 or
cleanup, then clears; it is never an extra handle key or control-shell payload.
This residual URL occupies the existing Session request slot, not a sixth copy.
Use managed_path rather than managed_transport truthiness for ORIGINAL cleanup
and mandatory Service receipt after checked-policy payloads clear. Nil client
payload must not switch the request into dedicated cleanup semantics.
Pump holds the request trailer policy. Rejection before
admission/checkout creates no upload and emits no Fetch bytes. Open failure
joins an owned upload actor or reports `cleanup_unconfirmed`; it cannot invent
an original completion for an unbound token.

## Trailer and public response contract

Request and response trailer policies live only in the pump, each exactly:

```elixir
%{allowed: compact_names, dropped: compact_names, max_count: integer, max_bytes: integer}
```

Preflight bounded field lists and binary backing before normalization, splitting,
deduplication or joining. Across all Trailer fields count <=128 tokens before
deduplication, including repeats; across Connection fields <=128 likewise.
Allowed names <=128; dropped names <=265 (128 Connection +128 removed forwarding
+9 fixed hop names). Retained token payload <=65,642, counting dynamic65,536
+fixed106; names are compact lowercase tokens and existing forbidden-name and
forwarding-trust filtering stay exact. Policy max_count is 1..128, max_bytes
1..65,536; complete policy <=67,689 (82 wrapper/scalars+5*(128+265)+65,642).
Join a declaration only after preflight and prove the resulting field list fits
effective head limits; declaration buffer <=B(65,536). A singleton declaration
does not waive pre-dedup token limits. Retain ordered duplicate actual trailers;
drop only declared hop/untrusted names and reject forbidden/undeclared names
under the existing safe policy. Request policy releases after upload finish or
early final stop; response policy releases after terminal filtering/write.

Before forwarding a head, validate exactly 13 public Response fields plus
`__struct__: HTTP.Response`: `status`, `status_text`, `ok`, `headers`, `body`,
`body_used`, `url`, `redirected`, `type`, `stream`, `http_version`,
`informational`, `trailers`. Require `http_version: :http2` even for h2c, final
status 200..599, boolean flags, type in `:basic|:cors|:error|:opaque`, status-text
logical/backing <=64; body nil, empty binary or the response stream PID, with
stream nil or PID and consistent body/stream identity. Buffered nonempty body,
extra struct keys and malformed wrappers reject. Immutable streamed `trailers`
must be empty. Both Headers wrappers are exactly
`%HTTP.Headers{headers: proper_pairs}` (two map keys including tag).

URL is nil or a closed nine-key URI with the submitted scheme/host/port/path/query,
no userinfo, fragment, arbitrary upstream redirect or extra payload. The pinned
public managed preparer returns a normalized URI with `authority: nil`; accept
that exact representation only after validating and matching all address and
target fields. A supplied authority still has to be valid and match the submitted
authority. Do not rewrite a Response to manufacture provenance. Total URI
projection remains <=132,096 with per-source backing preflight. This compatibility
amendment follows the executed `native-response-url-diagnostic2` receipt: replacing
only the native nil authority with the parsed submitted URI changed rejection
to success, while all other Response fields stayed identical. Both accepted
representations and every mismatched field require independent review/regressions.
Initial heads <=256 pairs and65,536 name+value bytes/backing, BEFORE cache,
normalization or policy. Informational is <=128 ordered `{status, Headers}`
blocks, status100..199, aggregate fields<=2,048, and aggregate
name+value+32<=65,536 with finite backing preflight. Retained fields are copied
after validation; no partial traversal or dedup shortcut establishes the bound.
Its upper envelope is 7+128*63+65,536=73,607; status-text70, URI132,096 and scalar/
wrapper8,192 yield metadata213,965, EXCLUDING initial fields separately charged.

Keep adapter and native wire boundaries distinct. The pinned native HPACK
256-field limit includes `:status`:255 regular fields plus status reach the
adapter, while256 regular fields plus status fail natively with
`{:transport_error, {:hpack, :hpack_field_count_exceeded}}`. The pure adapter
must still accept256 regular fields and reject257. The executed header-boundary
diagnostic also observed original `:cleanup_unconfirmed` after native rejection;
retain that negative result and the resulting request/Service failure evidence.
It is never a successful cleanup receipt. No dependency internals or new
cleanup certification are required to replace a documented uncertain outcome.

The four-cell byte matrix measures each reachable enforcement boundary in its
own unit. Adapter name+value and backing caps remain65,536; exact/over adapter
65,536/65,537 are independently verified by the unchanged pure tests. They
cannot be claimed as feasible final-head network positives: the upstream
native decoded head also counts `:status` (10 bytes), and H1 adds status and
framing bytes. Matrix GREEN6's three-field fixture had field-wire65,536 but
complete H1 wire65,600, so its expected200 was infeasible. Preserve that FAIL21
receipt and the strict renderer rejection; do not raise any cap.

Use four ordered upstream fields `content-length:0`, `x-pad:a*p`, `x:b`, `y:c`
for empty200 byte-head cases. Their name+value is p+24, native decoded head
including status is p+34, and proxy field-wire including CRLF is p+42. H1 uses
fixed framing: status line17 and connection-close19 yield full wire p+78.

| Network boundary | Exact/over padding p | Exact/over measured bytes | Other exact budgets |
| --- | --- | --- | --- |
| H1 complete rendered wire | 65458/65459 | 65536/65537 | Adapter65482; native65492; field-wire65500 |
| H2 proxy field-wire | 65494/65495 | 65536/65537 | Adapter65518; native65528; downstream decoded65688 |
| Native terminal trailer metadata | 65497/65498 (`x-check:a*p`) | 65536/65537, name+value+32/field | Adapter65504; field-wire65510; H1 terminal65513 |

Both upstream protocols retain all135 matrix identities and all four cells.
Successful exact cases require exact ordered fields/trailers and bytes; over
cases retain pre-head empty502 or post-head termination as applicable. The H1
uncommitted renderer `:response_header_limit` is an upstream metadata failure
at Proxy.HTTP and must use its existing502 cleanup path, before any partial
head can escape. Ordinary native core renderer behavior is unchanged. H2's
compressible padding must additionally satisfy the existing bounded HPAX/encoded
block guards; arithmetic does not establish runtime success.

Trailer byte exact/over network evidence is explicitly native metadata,
including32 bytes per field, rather than adapter name+value. The original
field-wire65,536 positive would exceed native metadata and H1's full terminal
cap. Keep the unchanged pure adapter trailer65,536/65,537 and public renderer
exact/over tests. If native rejection yields an unconfirmed original completion,
preserve that exact failure, token and Service receipt with genuine helper and
peer joins. Scope retirement or actor disposal never converts it to cleanup:ok.

Extract only bounded status/fields/stream, discard URL/status-text/informational
and the full Response immediately. Handles contain exactly four keys:
`promise`, `completion`, `stream`, `resolved`. `resolved` is boolean, stream
nil/PID; Promise is exactly its public struct tag/task/completion. Task shell
has exactly the public Task tag/owner/pid/ref/mfa keys, owner/pid PID, ref
reference and the pinned anonymous-task finite MFA `{:erlang, :apply, 2}` or
nil. No function/args/Response are retained. Two handle projections cover
current and original, preserving ORIGINAL completion identity. Scope and
completion interiors remain opaque and outside this serialized-payload unit;
record their multiplicities and public cleanup obligations separately.

Terminal trailers preflight <=128 fields and65,536 name+value bytes/backing
BEFORE Session cache and pump handoff. A native-valid129-field trailer event
must be rejected by the adapter, regardless of the dependency's native256 cap.
The pump validates its policy, filters/copies and forwards in order after all
DATA acknowledgements and before final response completion.

## Activation ledger and enforcement

Unit: conservative bounded complete external-term payload representations;
not heap/native/VM/socket/kernel/process memory or an account of arbitrary
external mailboxes. For nonempty proper lists including ETF framing:

```text
B(b) = b + 6
F(n,b) = b + 12n + 7
N(n,b) = b + 5n + 7
```

These are upper envelopes; empty lists also fit. Validate exact schema,
constructor/scalar ranges, logical/backing and bounded traversal BEFORE any
`:erlang.external_size`. Evaluate only complete bounded values or explicitly
typed opaque projections. Measure each once; complete representations already
contain their projections. Projection facts and native limits are not new
charges. The following proposal replaces neither historical worksheet output
nor owner accounting:

| Payload slot | Multiplicity and charge | Bytes/request | Owner and release point |
| --- | --- | ---: | --- |
| Complete request representations | 5*205337 | 1026685 | Pump/source and URL/target assembly; Session envelope then residual submitted_url through head/cleanup; complete preparation return including manifest; source Fetch options; complete submitted Fetch representation. Clear envelope after bind while retaining URL in the same slot; discard accounting/options after Fetch. Reserve all five even when phases do not overlap. |
| Fixed config | 5*147456 | 737280 | Pump; Session config; fixed selector; awaiting-checkout config; opening config. Clear selector/awaiting/opening after binding; reduce Session config to finite needed control/limits. Pump ends at cleanup. |
| Checked policy | 2*1183744 | 2367488 | Session checkout and opening/Fetch projection; discard opening at Fetch and Session policy after bind. Owner policy remains separately charged. |
| Trailer policy | 2*67689 | 135378 | Pump request and response; release at upload completion/early stop and terminal response write respectively. |
| Downstream declaration names | N(128,65536) | 66183 | One retained declaration-name list in Exchange.response_trailers/FramedResponse through downstream completion or cleanup. |
| Response heads | 4*F(256,65536) | 274460 | Received/native boundary; compact adapter; Session-to-pump handoff; filtered downstream head. Original dropped after validation, adapter/Session after handoff, downstream after write. |
| Terminal trailer lists | 4*F(128,65536) | 268316 | Received/Session cache; handoff; filtered response; filtered upload. Release raw/cache after terminal handoff and filtered values after finish; no extra retained trailer list. |
| DATA event | 3*B(1048576) | 3145746 | Original public event; compact Session delivery; pump handoff. Logical/backing<=1MiB before copy. Release original after validation, retained handoff after full write/ACK or cleanup. |
| Upload | 2*B(65536) | 131084 | Original downstream read and compact upload bridge; release after synchronous accepted upload or abort/join. |
| Downstream framed piece | B(16384) | 16390 | One piece during full write; release before next piece. |
| Extra public metadata | 1*213965 | 213965 | Only transient validated Response projection, immediately discarded after bounded head extraction. |
| Proxy normalization scratch | 3F(256,65536)+2N(393,65642)+2B(65536) | 472157 | Three normalization/filter/generated field lists; two token workspaces; two declaration joins. Encoded-head buffer moves to the renderer allowance below. Reuse only after releasing predecessor workspace. |
| Closed control and message wrappers | 16384+8192+2*4096+16*2048 | 65536 | Session, pump, current/original handles, sixteen control/message projection slots; release with each transition/termination. |
| Proxy payload subtotal | Sum above | **8920668** | Historical proposed8,986,210 minus moved B(65,536)=65,542. |
| Downstream renderer allowance | Closed public renderer slots below | **524288** | Same Service reservation; no second owner/process ledger. |
| Conservative activation allowance | 8920668+524288 | **9444956** | Service reservation retained through confirmed cleanup. |
| C2/R32/P0 request allowance | 32*9444956 | **302238592** | Separate from owner policy/physical/native ledgers. |

Target/URL assembly is part of the first complete source-request slot: build
each bounded value into that slot and release its prior input before advancing
the slot. It does not occupy the encoded-head scratch slot. If implementation
needs a sixth concurrent request representation or independent assembly buffer,
revise the ledger and ceiling before acceptance; do not silently alias live slots.

The callback validates a proper <=256 field list with logical/backing<=65,536,
URL bytes integer1..65,536 and chunk integer1..65,536, then returns **9,444,956**
even for a small request. Invalid input raises a fixed `ArgumentError` before
serialization; HTTP performs envelope validation first and maps request errors
to400. The facade must not discount unavailable config/policy/metadata/trailer
arguments. `evaluate_activation` proves actual finite inputs fit the same slot
ceilings and emits exact component arithmetic/manifests, without reducing the
reservation. No uninspected projection is zero-charged. Proposed ceiling status
becomes enforced only after validators, all slot paths, arithmetic, peers,
independent SPEC/CODE and fresh gates pass.

Explicit multiplicities are required in executable contract tests and source
review. No sixth config/request copy, third checked policy, new queue, extra
retained event or error payload may be silently absorbed. A needed additional
slot revises design, arithmetic and tests before implementation acceptance.
Scope1 and original completion1 per request are opaque public capabilities,
with two shell references to the same original completion; token1 and delegated
request pin1 are separately accounted owner controls. Complete Service receipts
and scope-retirement internals are also opaque; public success/failure and joins
remain required. Do not serialize private interiors or claim native memory proof.

## Downstream renderer boundary and compatibility repair

Source inspection establishes two missing obligations rather than an existing
measured backend allowance. HTTP1.Response.head/3 renders an eight-element
iolist whose fields/1 entries are four-element iolists; send_head/4 checks wire
iodata_length only. H2Connection.encode_headers/5 creates HPAX iodata, a compact
block and frame queue; enqueue/2 bounds queue count, not encoded-head bytes.
Exchange.retained_bytes does not account complete rendered head constructors.
The proxy must not label all of these representations B(65,536).

Move the historical encoded-head B(65,536) scratch charge out of proxy scratch
and charge a **524,288-byte renderer allowance** in the SAME attach_cleanup
Service reservation. No second owner, new process or native-memory certificate.
The combined conservative facade returns9,444,956 and R32 is302,238,592.
The renderer boundary owns the following bounded complete public Gaoxy payloads:

| Backend | Simultaneously allowed complete slots | Maximum |
| --- | --- | ---: |
| H1 | Two complete head/trailer rendered iodata slots<=81,920 each; one compact wire projection<=B(65,536); finite send traversal/control<=4,096 | 233478 |
| H2 | One HPAX aggregate returned iodata<=131,072; one transient single-field codec input<=F(1,65536); one compact block<=B(65,536); two request-owned encoded head/trailer frame-list/queue projections<=73,728 each; finite send traversal/control<=4,096 | 413721 |
| Unified renderer ceiling | Conservative ceiling above both backend sums | **524288** |

H1 conservative field-iolist formula is `b+35n+7`, because each field has two
payload binaries, two two-byte delimiter binaries and four-list framing.
At256/65,536 it is74,503; outer status/version/reason/CRLF wrappers must fit the
remaining7,417 of the81,920 complete cap. The existing wire cap65,536 remains;
status/reason are finite and no arbitrary caller text is accepted. Render
preflight checks finite proper iodata, bounded constructor nodes/depth and
aggregate logical/referenced backing BEFORE serialization/conversion/send.
Max nodes8,192 and depth16, with only byte integers or binary leaves, bound
traversal; cap its complete external representation81,920 before retaining.
Do not double-charge the already charged field input as another new field slot.

For H2, preflight outgoing finite heads/trailers and status semantics before
HPAX.encode. Assemble one proper ordered outer list from supported
`HPAX.encode(:never_store, [field], encoder)` calls, carrying the returned
encoder. Recursion constructs the result directly without a reversed second
list or an unchecked bulk-encoding copy. Empty headers must use the supported
empty encode so a pending table-size update remains on the wire; preserve exact
bytes for nonempty heads and trailers too. The full aggregate occupies the same
single returned-iodata slot. Conservatively charge the transient one-field codec
input as F(1,65536)=65,555, even though it references the already bounded field.
Only one such input is live per supported call; no second full input list or
encoded aggregate is constructed. H2 complete public slots therefore sum to
413,721, still below the unchanged524,288 allowance and9,444,956 reservation.
HPAX/VM stack internals remain opaque; finite field-count recursion is not a
certificate of native memory or a claim that the4,096 public control charge
measures the VM stack. Bound its returned public iodata by8,192 nodes/depth16,
logical/backing65,536, complete external size131,072 before binary conversion;
then compact encoded block<=65,536 and framed piece<=16,384 payload. At most
four header/continuation frames per block, each9-byte wire header plus binary
wrapper, yields complete frame-list bound65,536+4*(9+6)+7=65,603, below the
enforced73,728 cap including Gaoxy queue-entry/control wrappers. Allow at most
two outstanding request-owned final-head/terminal-trailer queue projections;
retire each when its full downstream write completes. Proxy emits no outgoing
informational heads and duplicate terminal emission rejects. Unrelated shared
connection control queues stay in their existing connection count/lifecycle
boundary; these new byte caps cover the exact request-owned rendered payloads,
not all connection/native/OS memory. Explicit per-stream occupancy and complete
projection tests must verify this, rather than infer it from a queue count.

Assign the minimal compatibility guards to HTTP1.Response, H2Connection and
their scoped renderer tests; check caps before retaining/enqueueing and preserve
headers/trailer/control ordering. If HPAX output cannot fit a finite return cap,
fail the head before downstream response starts with the existing bounded
upstream-error path, or terminate after head. No partial extra response. Existing
FramedResponse/Exchange write paths must preserve full-write completion before
proxy ACK. Guard tests cover exact/over rendered bytes/constructors/backing,
post-encode block/frame queue caps, repeated terminals and H1/H2/H3 compatibility.
This assigns a bounded public Gaoxy backend repair, not HPAX/private/native
certification. No third queue/rendered copy is silently absorbed; additional
overlap revises the contract before acceptance. Both backend component sums and
the complete combined Service reserve require independent executable tests.

## Native H1 incremental-read compatibility repair

`Exchange.recv_body/5` requests an exact passive-socket length. After forwarding
the first16384 bytes, another16384-byte receive withholds an available8-byte
fragment while the producer deliberately withholds EOF. Preserve the existing
incremental Body decoder, read credit and maximum read chunk. The proposed
bounded repair first probes that maximum size with timeout0, halving on timeout
down to1; if every probe times out, make one finite1-byte wait using the same
absolute read deadline. Successful fragments stay within existing reserved
credit. Do not use unbounded recv0, add queues or payload copies, relax byte
assertions, or renew the deadline between probes.

B owns only `apps/gaoxy_http/lib/gaoxy/http/exchange.ex` and new
`apps/gaoxy_http/test/http1_partial_upload_test.exs` for this compatibility slice;
parent owns runtime/format/evidence. Native H1 RED1 executed8/6, exit2, source
stable and zero skips/exclusions: four failures reproduce byte delivery, while
two new fixture assertions incorrectly expected `:normal` instead of exact
`{:shutdown, :local_closed}`. An invalid Endpoint two-tuple abort also logged a
CaseClauseError. These fixture failures are separate from capacity and production
failures. B is correcting tests only before RED2; Exchange production stays
frozen until parent releases it. Final verification must use the intended
full57 manifest, including this new suite and the existing
`native_proxy_seams_test.exs` original-request-deadline regression.

## Closed control/message schemas

The executed Task7 zero-flow-credit regression exposed a native downstream H2
compatibility gap: its operation call, queued frames and DATA flow wait used the
request deadline rather than the endpoint write timeout. The necessary bounded
repair propagates an absolute per-operation write deadline for head/DATA/trailer
writes, using the minimum of the request deadline and now plus write timeout.
Track one identity/timer/caller for each pending operation; queued and in-flight
frames use that same deadline. On expiry, return timeout while the pump remains
able to cancel and join its genuine original completion. Latch failed writes to
prevent a fallback head, replay or late successful callback/ACK; read/poll and
overall stream deadlines remain separate. An unsent expired frame may preserve
siblings. If a HEADERS fragment has already reached the wire, hard deadline
expiry closes the connection rather than dropping a required CONTINUATION.
Existing ordinary-reset END_HEADERS draining remains independently qualified.
This adds no dependency/private-actor or memory certification requirement.

Session projection is <=16,384; pump control projection <=8,192; each handle
shell <=4,096. Permit only finite booleans/enums, signed64 times, bounded unsigned
lengths, PIDs/references (each public scalar ETF<=2,048), known module atoms,
nil or finite named tuples/maps. Session has <=4 actor monitor pairs (existing
owner/service/instance/gate), opening+total+ONE poll timer, one awaiting checkout,
one delegated pin, one token/selection, one DATA ref, one handoff ref and nil group
selection. Pump has finite readiness/upload-stopped flags, original actor refs,
finite timestamps, one handoff and at most one source captured request pin.
Payload fields point to the dedicated ledger slots above, never control budget.

The whitelist below has sixteen retained message/control-envelope families,
each <=2,048 after dedicated payload extraction. Finite alternatives are explicit;
they do not authorize arbitrary tuples or queues. Existing public wire shapes
remain; no new framework/message bus is introduced.

| # | Allowed shape/family | Dedicated payload |
| --- | --- | --- |
| 1 | `{:gaoxy_cleanup_activate, service_token}` | Opaque token marker |
| 2 | `{:gaoxy_cleanup_cancel, token, finite_reason, deadline}` | Token marker |
| 3 | `{:gaoxy_transport_handoff, ref, {:ok,pin}|{:error,finite_reason}, deadline}` | Exact owner pin capability/control |
| 4 | `{:DOWN, monitor_ref, :process, pid, finite_reason}` | None; raw reason normalized immediately |
| 5 | `:opening_expired | :total_expired | :poll` | One timer of each kind, one scheduled poll |
| 6 | `{:"$gen_cast", :cancel|:expire|:consumed}` | None |
| 7 | `{:"$gen_cast", {:acknowledge,data_ref}}` | None |
| 8 | `{task_ref, exact_Response|{:error,finite_reason}}` | Metadata and initial-head slots; Response immediately discarded |
| 9 | `{:stream_chunk, stream_pid, bounded_bytes, data_ref}` | DATA slots |
| 10 | `{:stream_trailers, stream_pid, exact_Headers}` | Terminal-trailer slots |
| 11 | `{:stream_end, stream_pid}` | None |
| 12 | `{:stream_error, stream_pid, finite_reason}` | None |
| 13 | `{:gaoxy_proxy_http, session_pid, {:ready,upload_pid_or_nil,exact_limits,deadline}}` | Five-key limits inside config/control allowance |
| 14 | `{:gaoxy_proxy_http, session_pid, {:transport_handoff,ref,handle,identity,deadline}}` | Fixed-config/owner-control identity slots |
| 15 | `{:gaoxy_proxy_http, session_pid, {:headers,status,fields}|{:chunk,bytes,ref}|{:end,trailers}|{:error,finite_reason}}` | Corresponding head/DATA/trailer slots |
| 16 | `{:gaoxy_drain, gate_pid, lease, deadline}` | Opaque lease marker |

Public outbound read/ACK/upload calls and Service/owner calls use transient
wrappers within their named control slot, not extra retained mailboxes.
Synchronous public timer cancellation replies are transient controls too:
measure the complete `{ref, false | nonnegative_signed64}` tuple within2,048,
requiring same-actor public cancel_timer CALL/receive/RETURN provenance and exact
returned result. This adds no retained family or allowance. A reference that
differs from the original Task reference is never accepted as a Task result;
missing, mismatched or expanded transient wrappers fail the evidence projector.
Repair12 combined scoped verification passed96/0, including strict constructor
counterexamples and real h2c provenance1; TLS observed0. The separate raw C2
public Promise witness passed. Matrix GREEN3 passed C2 but failed after14 cases
because R32's fixture launched requests while its second connection was cold;
preparation barriers preserve the required32 held streams and all P0 limits.
Unexpected messages are ignored/dropped without copying/retaining/logging raw
payloads. Authentication checks refs/PIDs before accepting each form. Raw task,
monitor, exception, stream or downstream errors are normalized before retention
to fixed atoms: `:invalid_request`, `:invalid_policy`, `:invalid_response`,
`:upstream_failure`, `:upstream_task`, `:upstream_delivery_limit`,
`:upstream_delivery_overlap`, `:upstream_trailer_limit`, `:timeout`,
`:request_timeout`, `:unavailable`, `:cancelled`, `:cleanup_pending`,
`:cleanup_unconfirmed`, `:invalid_resource`, `:invalid_resource_pin`,
`:invalid_transport_endpoint`, `:unauthorized`, `:retiring`, `:resource_unavailable`.
Existing finite cleanup tuples may wrap only these atoms under
`:cleanup_failed`, `:transport_cleanup_failed`, `:pin_release_failed`,
`:service_cleanup_failed`, `:selection_cleanup_failed`, each depth<=3 and
arity<=3. No raw exception, stacktrace, text diagnostic, historical result,
function or arbitrary nested map/list becomes retained error state. External
evidence can describe an error without placing it in runtime reservation state.

## Delivery, cleanup and HTTP behavior

One outstanding DATA reference. Adapter validates logical AND referenced
backing<=1,048,576 before copy/handoff. A valid16,385-byte,64KiB or1MiB delivery
is accepted;16KiB is solely the downstream framed-piece bound. Pump writes the
entire event in bounded framed pieces, then ACKs once. While write is withheld,
no next event/ACK is permitted. Failed/partial downstream write cancels and
never ACKs, retries or replays. Overlapping deliveries fail
`:upstream_delivery_overlap`; >1MiB logical/backing fails before retention.
Upload validates logical/backing<=65,536 before public Stream.chunk and uses
bounded timeout;65,537 rejects. Actual upload trailers finish safely in order.

A valid early final response stops upload promptly, preserves response head/body/
trailers and never replays unread request bytes; downstream connection closes
where existing unread-body semantics require it. Redirects are manual, compressed
responses remain encoded with original fields, duplicate ordering survives,
HEAD/204/205/304 and Content-Length semantics retain existing protocol rules.

Bind ORIGINAL public completion before `:ready`, including failure/cancel races.
Required release order:

```text
original HTTP.RequestCompletion confirmed (:ok)
  -> UpstreamTransports.finish(original token)
  -> Session guardian request pins released
  -> Gaoxy.Service.complete_cleanup receipt
  -> observed Session termination
```

Consumption, end/trailer events, task DOWN, Session/owner/instance death, or an
expired caller wait do not establish completion. Pending/unconfirmed completion
retains token/pins/Service request reservation; cleanup retries are finite and
single-poll. Owner scope retirement through Custodian is separate. A healthy
shared connection may remain after one request completes; final owner retirement
must establish public retirement, actual physical socket termination and joined
owned helpers. Record orderly EOF and `ConnectionResetError` separately on both
normal and abort paths. The executed normal-retirement diagnostic confirmed
three original completions and graceful scope retirement for BOTH protocols,
with peer reset, exactly three requests and zero forced/live helpers. The public
contract does not guarantee FIN-only termination even after normal completion.
All tests require the observed terminal signal, unchanged public receipts/zero
ledgers, exact final request counts and all actor joins. A reset is never
relabeled EOF, and forced peer disposal is never confirmation.
Keep exact negative TLS/native-rejection uncertainty when the pinned public
contract cannot confirm cleanup; retain failure and holds instead of treating
test-owned disposal or physical closure as a successful Service receipt.

Instance death may leave the original public abort able to join successfully
while the separate Service is already unavailable. It does not imply that the
original completion must become uncertain, or manufacture a Service receipt.
Qualify that confirmed-original case with Custodian retirement held until the
actual abort completes, then require the exact unavailable Service failure.
Separately establish genuine published Response Stream death and the original
`cleanup_unconfirmed` before instance collapse; preserve that original identity,
retained request token and missing receipt through recovery. These are two
deterministic fault cases, each with one exact outcome.

Before a response head: malformed request/envelope400; authentic native upload
body/trailer limits413/431; unsupported method/target501; unavailable/identity/admission capacity503; timeout504; upstream protocol,
metadata, delivery/reset/GOAWAY failure502. After a response head, cancel and
terminate the stream/connection; send no second response. Bound open, idle,
write, total and cleanup deadlines, cancellation and producer/Session/owner/
instance death using existing Service/Custodian lifecycle rather than hidden
successful fallback.

## Verification and stage transition

Parent alone owns runtime/Mix/format/build/peer/evidence/commits. Freeze all writers
before any command; record actual accepted preparation commit/cohort/environment,
diff/untracked inventory, source-before/after and lock hashes, loaded public BEAM/
native identities, executed counts/exits/no skips, peer EOF and helper joins.
RED comes before production changes for each interface/adapter seam. Count only
actual tests; preserve all failures. Independent SPEC then CODE must review the
complete frozen candidate and evidence; resolve findings, then run fresh gates.

Required matrix: H1->TLS-H2, H1->h2c, H2->TLS-H2, H2->h2c; exact h2 ALPN,
no fallback, correct CA/name rejection, numeric routing+authority/SNI, shared
multiplex/reuse, C2/R32/P0 refusal without replay, reset/GOAWAY sibling isolation,
pre-EOF upload, early final and permitted ordered trailers, raw compression,
bodyless status and CL behavior. Deterministic envelope/metadata/control/slot
limits and withheld-write/lifecycle tests are enumerated in acceptance.
Retain all63 existing public assertions and their historical sources/evidence.
Run affected H1 fixed/options/accounting/preparation/identity/handoff/Generation/
group/probe/completion/TLS/wire/runtime and affected H3 Session/Headers tests.
Pure public-contract qualification is compatibility, not fixed-adapter acceptance.

Required browser verification uses a local native Gaoxy TLS downstream with
test-only fixtures and a real fixed TLS-H2 peer. Through Chrome DevTools, load
a local `/probe` HTML response, fetch a streamed `/stream` body and a `/early`
response, inspect browser network protocol h2, exact visible content and final
bytes; exercise upstream wrong-name/CA error without credentials/replay.
Positive `Page.navigate` must return no error and complete normally. The pinned
Chrome negative case has a separate exact contract: h2 status502 and
Content-Length0, navigation errorText and matching Document loadingFailed
`net::ERR_HTTP_RESPONSE_CODE_FAILURE`, then a `chrome-error://chromewebdata/`
frame/document displaying HTTP ERROR502. Browser-generated error content is
separate from the zero-byte server body. Capture matching request/loader/frame
identities, network/console and screenshot/trace, public cleanup and helper joins.

While browser sockets remain open, classify every charged native Connection and
Writer lease by actual PID/ref and require a bijection with exact summed bytes.
Connection acquisition precedes asynchronous Writer acquisition; wait finitely
for `writer_ready`, then take a fresh exact ledger. This is no count allowance.
Diagnostic2 proves2C/2W and346,212,430 bytes; its speculative connection with
`preface:false` remains a charged connection with a real Writer. Historical
diagnostic1 active3 lacks exact actor evidence and remains unexplained;
the finite Writer-readiness path executed in failed browser timeline GREEN1
with exact2C/2W and `writer_ready:true`; final fresh verification remains. For confirmed positive
request cleanup, explicitly exit/join the isolated browser before the unchanged
zero-active/zero-retained Service ledger and repeated original completions.
For actual original `cleanup_unconfirmed`, preserve failure: capture the exact
9,444,956 live cleanup-reserve timeline before Service exit, original identity,
terminal missing-Service receipt, retained owner token/resource and explicit
failed actor disposal/joins. Absent post-exit fields cannot establish zero or
successful cleanup. Earlier failed browser timeline GREEN1 records this exact live reserve and
terminal failure, but retained helpers1 violates required0. Wait
finitely for actual helper joins before sampling the retained ledger and test
disposal; keep helpers0 and do not manufacture it through disposal. Preserve the
[navigation/Service diagnosis](../acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/browser-navigation-and-service-timeline-diagnosis.json);
[actual browser receipts](../acceptance/m3-managed-h2-fixed-endpoint.md#latest-scoped-receipts)
preserve all earlier failures. Browser helper-join GREEN1 now passes3/3 with
actual helper DOWN/slot settlement and exacthelpers0 before disposal, while
wrong-CA/name cleanup_unconfirmed remains UNCONFIRMED_WITH_RETAINED_FAILURE.
Full53 GREEN1 passes761/0 and public GREEN1 passes63/63. Matrix GREEN1 remains
FAIL5 due to stale upload-end event selection; exact connection/stream repair
has a passing recorded-event replay, with complete rerun pending. Supplemental
complete control and renderer-release tests plus final SPEC/CODE/fresh gates
remain required before activation acceptance.

Restrict trust exception, if needed, to the generated downstream test certificate
SPKI; no operational certificate issuance, global trust mutation or public
listener. Browser checks are separate from the four independent Python peer
cells and cannot be claimed from them. Parent uses the browser automation skill
and captures real outcomes; unavailable browser access is BLOCKED_ENV, not PASS.

Only after complete passing independent reviews and fresh gates may the parent
record this local slice accepted, make its local conventional commit, and
automatically design/execute the next bounded managed-H2 groups/probes slice,
then its Generation integration and later standalone/load qualification. Do not
claim whole M3, hosted CI, publication, deployment or production acceptance.

## Native H1 polling compatibility repair — Sol17 planned after diagnostic6

Diagnostic6 retained all1024 first-distinct original snapshots and rejected
key1025, despite suppressing2737 exact repeats. Raw high-water226 was below1024;
no normal observer/Gate/tracer join or cleanup call executed. This confirms an
actual H1 empty-poll state-combination limit, not merely a raw queue backlog.
The canonical collector remains Sol15 v2; neither experimental projection set
has been released as a passing collector repair.

The recommended bounded repair keeps native buffer/poll workspace as a
persistent conservative request lease floor. Add `poll_buffer_bytes: 0` to
Exchange; `retained_bytes/1` charges `max(byte_size(buffer), poll_buffer_bytes)`
in place of its previous raw-buffer term. For each native poll, prepare a
candidate floor `max(poll_buffer_bytes, 2 * byte_size(buffer) + 2)`, check
Admission against its full total, and perform the unchanged one-byte receive
only after admission. A refused increase returns the original Exchange and
performs no receive. Timeout/close retains the admitted floor. A successful
receive adds one actual buffered byte without increasing the admitted total:
`b + 1 <= 2 * b + 2`. Body/response operations already use `retained_bytes/1`,
so carry the same floor. H2 facade exchanges keep the default0 and previous
buffer accounting.

The floor is at most `2 * max_buffer_bytes`: polling refuses a full buffer
before computing it. For buffer size b, the old buffer b, received byte1 and
new concatenation b+1 have peak2b+2. Preflight charges this peak before receive,
without depending on compiler allocation optimizations. Returned state cannot
exceed that preflight merely because its buffer grew by1. The floor is released
by the existing real request/reuse transition
`Admission.retain(..., byte_size(exchange.buffer))` or connection lease removal;
a newly constructed Exchange starts with0. No Service/Admission lifecycle,
cleanup50ms, limits, slot multiplicities or request deadline is changed.
Original checks continue on every poll; no stale-lease check is bypassed.
The earlier additive b+1 proposal was rejected during read-only arithmetic
review before implementation: it undercounted the separately live input/copy
peak and allowed returned-state growth beyond preflight at an exact cap. This
readiness correction is not a production repair attempt or GREEN result.

Parent first requires real passive TCP regression RED for stable admitted
workspace across repeated empty waits, high-water buffer copy accounting,
byte-cap refusal before consuming input, original deadline/close behavior,
read/send persistence and real native keepalive reuse release. Only the
observed intended RED permits production release. After focused GREEN and
independent narrow SPEC then CODE, use the independently proven exact adjacent
projection suppression experiment against all four original R32 cells/128
cleanup pairs. It may suppress only adjacent states rendering the same full
original snapshot; first different states, invariant failures, both1024 caps,
FIFO fences and sticky overflow remain. A passing experiment does not replace
the full135 matrix or the complete stage reviews and fresh post-review gates.

All writers remain frozen during parent runtime. Current counters are
fixed Sol18, collector Sol16 and R32 diagnostic failures5. Collector Sol16
is released after actual diagnostic8 PASS4/4; full135 is still required. Astra recovery2/2 remains exhausted; no third
round is allowed.
