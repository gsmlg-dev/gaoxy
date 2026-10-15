# M3 managed H2 preparation and public qualification

Date: 2026-10-14 Asia/Shanghai.
Status: **DESIGN FROZEN** for this bounded package. Runtime progress and acceptance
are recorded in the [acceptance ledger](../acceptance/m3-managed-h2-preparation.md);
they are not inferred from this design. Execution follows accepted
[managed H1 Generation](m3-managed-h1-generation.md). The parent records the
actual predecessor commit, source inventory and independent readiness before
releasing writers. See [plan](../plans/m3-managed-h2-preparation.md).
The versioned collector binds this immutable design, while the plan and ledger
carry mutable progress. Normative implementation contracts below are unchanged.

This is the next bounded slice of existing M3 upstream-transport Tasks4–5:
qualify the installed public 0.21.4 H2/h2c behavior, prepare finite immutable H2
inputs, and publish a numeric prospective payload worksheet. Fixed H2 activation
is the following slice; group/probe/Generation H2, standalone integration, the
four downstream/upstream combinations and both sustained-load profiles follow.

## Authorization, source and choice

Continuing authorization covers recommended design, implementation, repairs,
tests, independent review, documentation and local commits. Parent owns all
runtime/Mix/build/format/evidence/commits; independent Sol writers own disjoint
files and freeze before execution. Existing historical failures remain immutable.
Astra architecture task `m3_h2_prep_architecture`,
`astra_gate=PROJECT_ARCHITECTURE`, consumes zero recovery rounds; recovery2/2
remains exhausted. `http_fetch#97` is excluded, with no replacement native-memory
certification gate. No push/release/deploy, Vault, production data/certificates,
public management or disabled release-artifact E2E changes are authorized here.

The seven-package HTTP cohort is 0.21.4, lock SHA256
`aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
Architecture inspected groups documentation successor
`29068aa8575d4dfd47d04200d9019bdc27d2d193` plus uncommitted Generation work;
this is an observation baseline, not H2 acceptance source.

Choose additive pure preparation and a closed worksheet. Extending H1 dispatch
now would couple input qualification to live owner/Session changes. Publishing
`reservation_bytes/3` now would omit retained request trailers, trailer-policy
state, control/configuration and wrapper schemas. This package therefore exposes
only the following interfaces, without implementing `UpstreamClient`, changing
H1-only `UpstreamTransports.Options`, opening scopes or setting activation flags:

```elixir
ManagedH2Preparation.prepare_policy(source)
# {:ok, %ManagedH2Preparation.Policy{}, manifest} | {:error, reason}
ManagedH2Preparation.prepare_request(policy, source)
# {:ok, %ManagedH2Preparation.Request{}, manifest} | {:error, reason}
ManagedH2Reservation.worksheet()
# closed static map of units, profile, named maxima and later adapter obligations
```

Preparation has no I/O, process creation, clock, environment lookup or
runtime-derived defaults. Validate finite shapes, proper-list frontiers, logical
and backing bounds before copying, library transformations or `external_size/1`.
Only supported public dependency APIs may be used; do not patch `deps/` or
inspect dependency processes for acceptance.

## Policy contract

Source is exactly four keys:

```elixir
%{protocol: :http2 | :h2c, origin: root_url,
  connect_address: numeric_ip_tuple, trust: nil | [der_binary]}
```

Use the accepted H1 strict URL grammar: HTTP(S), root path, no query/userinfo/
fragment, valid authority and port; host at most253 bytes. URL logical and
referenced backing each at most65,536. Numeric IPv4/IPv6 tuples have valid
integer components. Protocol pairing is exact: `:http2` requires HTTPS and
nonempty explicit DER trust; `:h2c` requires HTTP and `trust: nil`. No file/default
trust read occurs in this package. DER list is proper, at most128 certificates,
each nonempty with logical/backing at most65,536; aggregate logical/backing each
at most1,048,576. Keep the complete SSL/socket policy external-size cap1MiB.

Policy contains `protocol`, `origin`, `scheme`, lowercase compact `host`, `port`,
`connect_address` and `open_options`. Open options have the accepted fixed order:
origin, connect_address, http_version, tls_backend, http2_profile, max_requests,
max_connections, max_pending, idle_timeout, ssl, socket_opts. Profile is
C2/R32/P0, idle30,000ms, OTP SSL and `:native_v1`. Socket options are
buffer/recbuf/sndbuf8192, nodelay true, send_timeout30,000ms and
send_timeout_close true. TLS is verify_peer, depth4, TLS1.3/TLS1.2, copied cacerts
and authority SNI. No ALPN key is added to the managed SSL whitelist: public
`http_version: :http2` already advertises exact `h2` and rejects nil/H1 negotiation.
Fresh independent TLS peers must verify exact negotiated `h2` and no fallback.

Every binary retained by a prepared value is compact. A Policy struct is
forgeable: `prepare_request/2` revalidates its exact field set, scalar domains,
bounded canonical SSL/options, protocol pairing and compactness before trusting
it. No unbounded traversal of forged options precedes rejection.

## Request contract and effective fields

Source is exactly the accepted seven keys:

```elixir
%{url: url, method: method, fields: [{name, value}], body: nil | pid,
  trailers: [{name, value}], timeout: timeout_ms, connect_timeout: connect_ms}
```

Method is one of get/head/post/put/delete/patch/options; timeouts are integer
1..86,400,000. URL has the policy's exact scheme/lowercase-host/port. Preserve
raw origin-form path/query including an empty query. Reject malformed percent
escapes, control bytes, whitespace, backslash, fragment and userinfo. Source URL
logical/backing cap65,536; proper fields≤256 and trailers≤128, each pair binary
token/value syntax. Existing source field budget uses name+value+32≤65,536 and
source trailer budget2+Σ(name+value+4)≤65,536. Backing occurrences in each pair
list sum to≤65,536 before transformations. Nil body requires no trailers. PID
body keeps the existing safe upload-trailer declaration/forbidden-name policy;
preflight at most128 declaration tokens before the public trailer validator.

Canonical ordinary fields obey these exact rules:

- Lowercase names; preserve ordinary duplicate order.
- Reject pseudo-fields, host, connection, keep-alive, proxy-connection,
  transfer-encoding and upgrade.
- TE accepts only trimmed case-insensitive trailers and stores `"trailers"`.
- Validate the source Trailer declaration under the bounded upload policy, then
  remove Trailer from canonical ordinary fields. The public H2 encoder rejects
  this H1 framing header; terminal trailers remain separate request metadata
  sent later through public `HTTP.Stream.finish/2`.
- When User-Agent is absent, append explicit `{"user-agent", "gaoxy"}`; preserve
  supplied User-Agent. This avoids a runtime-derived default in pure production.
- For PID body, append `{"content-type", "application/octet-stream"}` if absent.
  Preserve supplied Content-Type. Nil body adds none.
- Content-Length is decimal unsigned64 with native≤20-byte syntax. Reject
  invalid/conflicting duplicates; identical duplicates collapse for PID bodies.
  Place the single retained PID Content-Length last, after explicit UA/Content-
  Type defaults, matching native `Headers.set` framing normalization. Nil body
  removes Content-Length. Streaming H2 can retain valid Content-Length.

Prepared Request fields are url, method, fields, body, trailers, timeout,
connect_timeout and target. Copy every retained URL/target/field/trailer binary;
trailer pair ordering and safety remain the accepted H1 contract.

Let O be the canonical ordinary fields. Effective projection is the native
compatible four pseudo-fields followed by O:

```text
(:method, uppercase method), (:scheme, scheme),
(:authority, native-compatible authority), (:path, raw origin-form target)
effective_count = 4 + length(O) ≤ 256
effective_bytes = Σ(name_bytes + value_bytes + 32) ≤ 65,536
```

The generated default User-Agent costs47 bytes and PID Content-Type costs68.
Count defaults and pseudo-fields before success. Test the exact projection
against public `HTTP.HTTP2.request_headers/3` with `order?: false`, proxy mode and
PID duplex half. The public function evaluates runtime User-Agent even when
supplied, so use it only as a test oracle, never in pure preparation.

Also enforce aggregate logical≤196,608 for both source-derived and canonical
`{url, target, fields, trailers}` projections. Effective header bounds alone do
not bound removed source fields. Only after these checks compute manifests:

```elixir
%{
  kind: :policy | :request,
  source: constructor_facts,
  owned: constructor_facts,
  transient: %{source_plus_owned_backing_upper: source.backing_bytes + owned.backing_bytes},
  source_external_bytes: :erlang.external_size(source_value),
  prepared_external_bytes: :erlang.external_size(prepared_value),
  limits: %{
    url_bytes: 65_536, fields: 256, trailers: 128,
    field_bytes: 65_536, trailer_bytes: 65_536,
    effective_field_count: 256, effective_field_bytes: 65_536,
    projection_logical_bytes: 196_608, projection_external_bytes: 201_241,
    certificates: 128, certificate_bytes: 65_536, trust_bytes: 1_048_576,
    ssl_socket_policy_external_bytes: 1_048_576,
    policy_source_backing_bytes: 1_114_112, request_source_backing_bytes: 196_608
  }
}
# Policy adds exactly: policy_external_bytes = external_size(prepared Policy).
# Request adds exactly: source_projection_external_bytes,
# canonical_projection_external_bytes, effective_field_count, effective_field_bytes.
```

Constructor facts have the same exact keys as H1: logical_bytes, backing_bytes,
binary_occurrences, cons_cells, tuples (arity→count), maps (size→count),
atom_occurrences, integer_occurrences and pid_occurrences. A policy has no
request projection or effective-field keys. Request projection is precisely
`{url,target,fields,trailers}`; source target is the bounded source-derived target.
The duplicated policy/prepared size is an explicit fact alias, never a second
charge. Transient facts describe simultaneous binary backing, not a complete
constructor/heap peak or all intermediate normalization lists.

Complete source/prepared sizes include their wrappers. A projection must not be
added again when a complete value already includes it. Manifest facts describe
these bounded representations, not VM memory or a live reservation.

## Prospective payload worksheet

Unit is `:external_term_payload_bytes`; do not mix heap, native or VM memory.
For binary payload b and field-list logical payload b over n pairs:

```text
B(b) = b + 6
F(n,b) = b + 12n + 7
Q = E({url,target,fields,trailers}) ≤ 196608 + 4633 = 201241
```

Q's wrapper uses fields≤256, trailers≤128, two binaries and one four-tuple.
The closed worksheet enumerates:

| Named envelope | Formula | Bytes |
| --- | --- | ---: |
| Source request projection | Q | 201241 |
| Canonical request projection | Q | 201241 |
| Response heads, received and normalized | 2F(256,65536) | 137230 |
| Response trailers, cached and filtered | 2F(128,65536) | 134158 |
| Upload, original and compact | 2B(65536) | 131084 |
| DATA delivery, original and compact | 2B(1048576) | 2097164 |
| Downstream framed piece | B(16384) | 16390 |
| Named prospective subtotal/request | Sum | **2918508** |
| Fixed response/upload/write subtotal | Sum excluding Qs | **2516026** |
| R32 named prospective subtotal | 32×2918508 | **93392256** |

This subtotal is a worksheet, not a usable runtime reserve. The later adapter
must define retained Gaoxy control/config/trailer-policy schemas, owners,
multiplicities and release points before `reservation_bytes/3` can include finite
maxima for omitted parameters. Do not serialize opaque completion/scope internals,
insert unknown multipliers or give uninspected projections zero charge. Resource
pin/control metadata remains in the owner ledger; request/body payload remains
in request reservation accounting.

Required later adapter work is explicit local implementation scope:
compact before Session request retention; response heads256/64KiB and
trailers128/64KiB before cache/policy; DATA logical/backing1MiB before copy;
upload logical/backing65,536; finite token traversal before splitting; one
outstanding delivery; ACK only after downstream write; public original completion
before request-hold release.16KiB bounds frame/write pieces, while native DATA
delivery may coalesce frames up to the separate1MiB envelope.

Public native limits are reported separately: C2/R32/P0, policy1MiB, effective
request64KiB/256, upload bridge64KiB, writer/receive1MiB each/connection
(C2 total4194304), header block64KiB/256 fields/256 frames, informational128,
lifetime metadata64KiB/130 notifications. Native_v1 has four pseudo-fields,
push0, windows65535, DATA/header fragments16384, no Huffman/literal indexing and
no priority padding. Those caps are not added to the ETF worksheet as a native
memory certification.

## Qualification and acceptance

Use a new versioned0.21.4 collector. Preserve the old0.21.3 supplement, its plan
hash and all eight assertions/history. Run fresh existing public managed39 and
pooled completion16, plus all8 supplement cases (TLS4/h2c4). Record exact cohort,
loaded BEAM/native identity, Python/h2/OpenSSL, source-before/after hashes,
commands/exits/counts, public cleanup, physical EOF and joined peer processes.
Historical diagnostic strings in unchanged runners do not supersede the actual
fresh outcomes. An unexecuted or blocked command cannot pass.

Unit acceptance requires exact/over boundaries, malformed/improper lists,
oversized binary backing, forged Policy structs, pure deterministic defaults,
effective native-oracle equality, compact outputs and arithmetic for every
worksheet row. H1 preparation/options/completion compatibility remains relevant.
Complete independent SPEC then CODE, resolve findings, execute fresh scoped
format/strict compile/tests/qualification, then make a local conventional commit.
Preparation PASS cannot claim fixed/group H2 activation, standalone support,
protocol matrix, sustained-load acceptance or whole M3 completion.
