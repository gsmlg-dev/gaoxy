# Published HTTP 0.21.1 source/API review

Date: 2026-10-11 Asia/Shanghai. Direct independent Sol assignment
`m3_h1_preparation_spec_review/published-0.21.1-source-api`.

The published runtime source contains the fixes requested by issues86–89.
Issue95's OTP TLS tracking fix is absent. This is a **PASS for the bounded
source/API review**, with **TLS qualification BLOCKED** and fresh compilation,
public regressions and complete P0–P6 qualification **NOT RUN / UNQUALIFIED**.
Managed product activation stays disabled.

The [machine receipt](source-api-review.json) freezes all inspected published
files, their installed0.21.0 counterparts, archives and review inputs. The
[qualification plan](../../../../../plans/m3-upstream-0.21.1-qualification.md)
and historical [accounting architecture](../upstream-0.21/h1-accounting-architecture.md)
define the scope. No dependency, product, fixture or historical proof was edited.

## Identity and compatibility boundary

Review checkout: `.trees/m3-gateway`, branch `codex/m3-gateway`. Assignment
baseline was `6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`; parent advanced the
shared historical delivery to `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c` before
this receipt. Existing untracked parent identity/preservation receipts were
preserved. The incomplete clone was ignored.

Published tag commit is `bdf849adf119039ed679d24d5fbb0a321f5e578a`, tree
`2188645d94575d7cb452e41eab156e80d38a26ef`. Independent Python checks verified:

- Seven archive SHA256 values equal the frozen Hex checksums. All196 extracted
  files equal actual inner archive bytes and the parent archive hash map.
- All175 shipped `lib/` files equal their tagged Git blobs, computed as
  SHA1 of `blob <byte_length> NUL <file_bytes>`, using the untruncated1059-entry
  tree. Parent-collected network provenance is pinned; network collection was
  not repeated by this reviewer.
- Ten nonruntime app-tree differences are explicit: seven normalized packaged
  `mix.exs` files and Fetch's LICENSE/README/CHANGELOG. Fetch's three documents
  equal the root tag blobs; they do not equal the corresponding app-tree blobs.
  The receipt records expected, actual and matching tag paths.
- All196 old installed counterparts still identified0.21.0 at freeze and equaled
  the parent's preserved source copies and hash map. The freeze was handed to
  the parent before dependency replacement. Subsequent validation uses preserved
  old sources, never a later installed cohort.
- Every package specifies Elixir `~> 1.18`; every internal cohort runtime
  requirement is exactly `== 0.21.1`. The graph remains Fetch→Core/Runtime,
  Runtime→Core/HTTP3, WebSocket→Core/Runtime, Core→ExSSL/QUIC,
  HTTP3→Core/QUIC, QUIC→ExSSL. Fetch/Runtime/WebSocket retain telemetry `~> 1.0`.

Only14 shipped paths differ from installed0.21.0:

| Published path | Change class |
| --- | --- |
| `elixir_quic/mix.exs` | Package metadata/documentation |
| `elixir_quic_http3/mix.exs` | Package metadata/documentation |
| `ex_ssl/mix.exs` | Package metadata/documentation |
| `http_core/lib/http/http2/hpack.ex` | Runtime source |
| `http_core/mix.exs` | Package metadata/documentation |
| `http_fetch/CHANGELOG.md` | Package metadata/documentation |
| `http_fetch/lib/http/socket_client.ex` | Runtime source |
| `http_fetch/mix.exs` | Package metadata/documentation |
| `http_runtime/lib/http/http2/connection_owner.ex` | Runtime source |
| `http_runtime/lib/http/http2/pool.ex` | Runtime source |
| `http_runtime/lib/http/managed_transport.ex` | Runtime source |
| `http_runtime/lib/http/managed_transport/policy.ex` | Runtime source |
| `http_runtime/mix.exs` | Package metadata/documentation |
| `http_web_socket/mix.exs` | Package metadata/documentation |

No other runtime file changed. Existing public function names and arities in
these six modules remain present by source diff inspection; lexical name-set
checks also passed. Pool `handle_cast/2` and Owner `handle_info/2` gain internal
callback clauses. `Policy.prepare/3` now explicitly requires `%HTTP.Request{}`;
its admission behavior is stronger. This source check does not establish loaded
API, compiler or runtime compatibility. ManagedTransport's runtime API and
structs are unchanged; its changed file contains documentation only.

## Issue86: peer header/control paths

`ConnectionOwner` adds lifetime counters and admission before response-event
construction (`:1243–1305`). Each request admits at most128 informational heads
and65,536 regular-metadata bytes, charging each regular pair as
`byte_size(name)+byte_size(value)+32`; pseudo fields are excluded from that
charge. Overflow fails that stream with `:http2_informational_limit`.
Unchanged StreamState validation requires exactly one initial `:status`, no other
pseudo field, one final head and at most one END_STREAM trailer block. Thus
there are at most130 admitted header notifications per ordinary request.

A conditional representation count is also finite: valid regular names have at
least one byte, so informational regular pairs total at most
`floor(65536/33)=1985`; informational status occurrences add at most128, and
final/trailer blocks each contain at most256 fields. This gives at most2625
header-pair occurrences across admitted notifications. It is an occurrence upper
bound, not retained bytes, heap words or peak memory. HPACK's unchanged decoded
byte budget counts name+value without the dynamic-entry `+32`; the two charges
must stay separate.

HPACK decoding still updates the shared decoder before checking a terminal
stream; already-terminal headers renew neither events nor upload-stop messages.
The terminal guard (`:1668–1673`) acts only once per live entry.

Capacity updates now keep one token/snapshot in flight per owner
(`:1791–1812`). Peer SETTINGS replace current connection state while that
snapshot awaits ACK. The matching ACK clears it and recomputes the latest
snapshot. Pool `:340–356` applies registered-owner snapshots and ACKs; it rejects
an unknown owner. Existing legacy cast handlers remain. This bounds the selected
peer SETTINGS path, not arbitrary callers sending operation messages.

Only the first GOAWAY sends the draining notice and creates the drain timer;
subsequent GOAWAY retains that timer. A decreasing last-stream id can newly fail
excluded streams, while terminal guards prevent repeated terminal notifications.
Header-fragment retention and partial-frame remainder retention now copy their
binaries. HPACK raw string extraction copies its retained slice (`:767–769`).
These source changes address the reported peer notification/backing paths.
Fresh independent-peer regressions, decode/copy overlap, native representation,
mailbox/root composition and full H2 lifetime bounds remain separate obligations.

## Issues87–88: request and frozen policy ownership

Policy request normalization (`:119–290`) limits explicit fields before copies,
then owns header binaries, URL scheme/host/path/query, flattened non-PID bodies
and normalized content type. The clean `%URI{}` keeps only scheme, host, port,
path and query; unused authority/userinfo/fragment metadata is discarded.
Nil/PID bodies stay unchanged. Other bodies are scanned before flattening with
65,536 node,32 depth and1 MiB logical-byte limits. The scanner counts cons,
leaves and empty tails. Content type has an additional65,536-byte limit after
conversion. Malformed/overflow normalization returns
`:transport_scope_request_limit`.

Admission now includes scheme+host+path+query and content-type bytes in the first
aggregate metadata check. It also computes actual effective H1 fields, including
User-Agent, Host, Connection and body framing, or H2 pseudo/body fields, then
rechecks256 fields/65,536 bytes. The temporary half-duplex PID request used for
this accounting does not replace later upload/duplex validation. A request near
the old explicit-field/target limit can now be rejected because generated fields
and additional URL components are charged.

After existing policy logical/depth/1 MiB external-term checks,
`freeze/1` copies origin scheme/host and recursively reconstructs list/tuple
policy values, copying every accepted binary (`:69–75,289–298`). Logical frozen
values and digest semantics are preserved. This removes caller/file/system-CA
binary backing from accepted retained policy values; it adds actual copy and
construction events.

Neither change bounds original caller roots, pre-validation file/CA loading,
all request options or whole-process/VM memory. Eager
`public_key:cacerts_get/0` in policy and SSL defaults remains unchanged. The
historical [policy/CA proof](../upstream-0.21/h1-policy-ca-overlap-proof.md)
is still0.21.0 evidence: its shared retained DER-list facts and construction
counts cannot be reused for0.21.1 without accounting for recursive copying.
Host snapshot identity/immutability, warm/cold overlap, serializer, ETS and
process copies, and release remain open P3 work.

For the current compact H1 profile, retain its narrow nil/PID body grammar and
explicit bounded metadata. It is narrower than the new upstream buffered-body
support. Canonical preflight success alone no longer implies upstream success
near limits. Refresh source fingerprints, effective-field expectations and the
[request-wire proof](../upstream-0.21/h1-request-wire-proof.md)'s affected
normalization/copy phases; retain historical assertions/failures under0.21.0.
Do not treat upstream copies as a substitute for Gaoxy's charged roots,
preparation slots, native/process metadata or phase maximum.

## Issue89: managed connection-capacity error

SocketClient passes the nonnil transport scope into its reservation helper
(`:454–489`) and maps `{:error, :pending_capacity}` to
`{:error, {:transport_scope_capacity, :connections}}`. Dedicated nil-scope
behavior remains unchanged. Capacity admission, deadlines and replay mechanisms
are otherwise unchanged in the diff. A fresh h2c public-contract regression is
required; TLS-based variants stay blocked by95.

## Issue95: containing TLS fix absent

Published RequestLifecycle and SSL transport are byte-identical to0.21.0.
`track_tls/2` (`:29–42`) recognizes only `{:sslsocket, _, processes}` with a
list in its third element. Other shapes silently return `:ok`.
SSL `connect_cancellable/4` tracks TCP before the public TLS upgrade and then
calls that unchanged tracker (`ssl.ex:23–34`). No alternative supported release
barrier changed anywhere in the175-file cohort.

Frozen OTP `ssl_api.hrl:28–35` defines seven record fields; the tuple therefore
has eight elements including its tag. `tls_socket.erl:169–176` constructs that
record with separate receiver/sender fields. These exact OTP files are hashed.
The historical [public shape probe](../upstream-0.21/tls-socket-shape-repair1.json)
observed arity8/patternfalse with verified TLS1.3/h2, public close and joined peer;
it did not run the lifecycle race. It is corroborating historical evidence,
not a fresh0.21.1 runtime test.

The published tracker cannot register those independent TLS receiver/sender
processes. [Upstream95](https://github.com/gsmlg-dev/http_fetch/issues/95)
continues to block managed TLS H1/H2, turnover and whole-generation retirement
qualification. No private workaround is authorized or introduced.

## Verification and remaining gates

Successful Python archive/hash/tree/metadata/delta checks exited0, verifying
7 archives,196 new files,196 old/preserved files,175 runtime blobs and24 other
pinned inputs. Independent static arithmetic checks passed. The earlier OTP
read diagnostic's out-of-range indexing was corrected to bounded slicing and
rerun successfully; it was a diagnostic error, not a product regression.
Final receipt revalidation checks frozen hashes, JSON, local links, fence
balance and whitespace. No VM, Mix, compiler, network, gh, dependency mutation,
fixture edit, commit or child agent was launched by this reviewer.

Fresh strict compile, scoped compatibility tests and public regressions remain
NOT RUN here and belong to the parent's serialized qualification. Source
containment permits those applicable cleartext checks; it does not certify the
public runtime contracts. TLS95 remains BLOCKED. Complete P0–P6, production
integration, activation and milestone completion remain UNQUALIFIED.

Cumulative counters for this fresh assignment: Sol repair rounds0, unsuccessful
Sol rounds0, Astra rounds0. No escalation gate applies. All own commands have
finished; no own background process remains. The only owned changes are this
report and its JSON receipt. No new product decision is needed for this bounded
review.
