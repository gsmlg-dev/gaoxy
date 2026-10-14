# M3 managed H2 fixed-endpoint activation

Date: 2026-10-14 Asia/Shanghai. Status: **DESIGN CANDIDATE; NOT IMPLEMENTED;
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

URL is nil or the exact canonical nine-key URI derived from the submitted URL:
same scheme/host/port/path/query/authority, no arbitrary upstream redirect or
extra payload; total URI projection <=132,096 with per-source backing preflight.
Initial heads <=256 pairs and65,536 name+value bytes/backing, BEFORE cache,
normalization or policy. Informational is <=128 ordered `{status, Headers}`
blocks, status100..199, aggregate fields<=2,048, and aggregate
name+value+32<=65,536 with finite backing preflight. Retained fields are copied
after validation; no partial traversal or dedup shortcut establishes the bound.
Its upper envelope is 7+128*63+65,536=73,607; status-text70, URI132,096 and scalar/
wrapper8,192 yield metadata213,965, EXCLUDING initial fields separately charged.

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
| H2 | One HPAX returned iodata<=131,072; one compact block<=B(65,536); two request-owned encoded head/trailer frame-list/queue projections<=73,728 each; finite send traversal/control<=4,096 | 348166 |
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
HPAX.encode. Bound its returned public iodata by8,192 nodes/depth16,
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

## Closed control/message schemas

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
must establish public retirement, physical peer EOF and joined owned helpers.
Keep exact negative TLS uncertainty results if the pinned public contract cannot
confirm cleanup; do not turn test teardown into a successful Service receipt.

Before a response head: malformed request/envelope400; unsupported method/target
501; unavailable/identity/admission capacity503; timeout504; upstream protocol,
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
bytes; exercise upstream wrong-name/CA error without credentials/replay. Record
actual navigation/network/console outcomes and screenshots or trace, plus
public cleanup and fixture peer/helper joins. Restrict trust exception, if
needed, to the generated downstream test certificate SPKI; no operational
certificate issuance, global trust mutation or public listener. Browser checks
are separate from the four independent Python peer cells and cannot be claimed
from them. Parent uses the browser automation skill and captures real outcomes;
unavailable browser access is BLOCKED_ENV, not PASS.

Only after complete passing independent reviews and fresh gates may the parent
record this local slice accepted, make its local conventional commit, and
automatically design/execute the next bounded managed-H2 groups/probes slice,
then its Generation integration and later standalone/load qualification. Do not
claim whole M3, hosted CI, publication, deployment or production acceptance.
