# M3 managed H1 compact preparation

Date: 2026-10-11 Asia/Shanghai. Task: Task3 pure H1 preparation; direct Sol
assignment. Status: written design/plan, implementation specification and
code-quality reviews PASS; canonical formatter and global format check PASS.
Fresh tests of the reviewed formatted source pass26/0 with429 stable hashes.
Local commit remains pending; all P0-P6 activation obligations remain open.

Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. The installed seven-package
HTTP cohort is0.21.0, actual tag
`9813c126dc8b48055b9ee941c693fc27fa691489`. The qualification receipt pins
Elixir1.18.5, OTP28.5.0.7, ERTS16.4.0.6, SSL11.6.0.6, 64-bit. These are
profile identities, not newly executed qualification evidence.

## Decision and boundary

Implement two pure internal modules, `Gaoxy.Proxy.ManagedH1Preparation` and
`Gaoxy.Proxy.ManagedH1Accounting`, with two scoped test files. The first makes
bounded canonical policy/request values and scalar constructor manifests. The
second publishes named partial facts and unresolved obligations and always
refuses production activation. No manager, scope, transport handle, adapter
wiring, reservation process, deadline clock read, socket, file read, HTTP call,
dependency change or activation byte total belongs to this slice. The permitted
HTTP calls are the existing public pure Headers/Trailers helpers only.

This applies the [architecture memo](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
with a smaller accounting interface. A generic expression evaluator would need
uncertified runtime constants and copy-edge schemas; accepting caller-supplied
certificates would imply proof validation that this slice cannot perform.
Named facts are useful and independently testable without either mechanism.
Waiting for every runtime proof before making pure copies leaves the boundary
work circular; bounded preparation can proceed while activation stays closed.

The fixed profile is C2/R32/P0, `:http1`, OTP `:ssl`, `:native_v1`,
`buffer=recbuf=sndbuf=8192`, raw streamed responses and manual redirects.
There is no caller-supplied option tree. TLS is server authentication with
explicit DER trust, `verify_peer`, depth4, TLS1.2/TLS1.3 and generated SNI.
Connect/send timeout and idle policy are finite fixed policy choices below;
per-request timeouts remain finite decreasing budgets supplied by a later caller.
The historical261,199,114 subtotal is not a budget. H1 activation is
**NOT ESTABLISHED**; H2 remains separately blocked on
[http_fetch#86](https://github.com/gsmlg-dev/http_fetch/issues/86).

## API and canonical values

All APIs are internal (`@moduledoc false`), follow existing `{:ok, value}` /
`{:error, atom}` conventions, and introduce no production dependency.

```elixir
ManagedH1Preparation.prepare_policy(source)
# {:ok, %ManagedH1Preparation.Policy{}, manifest} | {:error, atom}
ManagedH1Preparation.prepare_request(policy, source)
# {:ok, %ManagedH1Preparation.Request{}, manifest} | {:error, atom}
ManagedH1Accounting.facts()
# Fixed profile/cohort/runtime identities, named partial facts and obligations.
ManagedH1Accounting.activation_status()
# {:error, {:unqualified, [:p0, :p1, :p2, :p3, :p4, :p5, :p6]}}
```

`Policy` has only `origin`, `scheme`, `host`, `port`, `connect_address`,
`open_options`. `scheme` is `:http` or `:https`. `origin` is an owned URL string;
`host` is a separately owned lower-case ASCII hostname or numeric IP literal.
`open_options` is a newly constructed fixed keyword list, with references to
the same owned origin/certificates; it is never passed to `open/1` here.

`Request` has only `url`, `method`, `fields`, `body`, `trailers`, `timeout`,
`connect_timeout`, `target`. `url` is an owned exact copy of the validated input
string; `target` is a separately owned origin-form string including a present
empty query delimiter. Fields and trailers retain spelling, order and duplicates.
Neither output stores the parsed `%URI{}`, caller input map or source binaries.

The modules are not a capability/security boundary: Elixir structs can be
constructed by callers. `prepare_request/2` must validate the policy's finite
canonical grammar, fixed options, compact binary leaves and consistency among
origin, scheme, host, port and options before using it. Reject out-of-grammar or
inconsistent values with `:invalid_policy`, without traversing an arbitrary tree.
Structurally valid copies are allowed; this validation proves no construction
provenance or unforgeability. It does not open an upstream policy or create a
cryptographic credential identity.

## Source grammar and independent limits

Before examining any nested values, check exact top-level map size and required
keys. Structs, extra keys, missing keys and other top-level types are rejected.
Checking map size before a bounded key walk avoids enumerating huge maps.

Policy source is exactly `%{origin: binary, connect_address: ip_tuple, trust: value}`.
Request source is exactly `%{url: binary, method: enum, fields: pairs, body: nil_or_pid,
trailers: pairs, timeout: integer, connect_timeout: integer}`.

| Component | Logical/input-shape limit | Separate source referenced-backing limit |
| --- | --- | --- |
| Policy origin | 1..65536 bytes; absolute HTTP(S) URL, root/absent path only, no query/userinfo/fragment; host1..253 bytes, port1..65535 | origin backing≤65536 |
| Request URL | 1..65536 bytes; absolute HTTP(S), matching scheme/lowercase host/effective port; no userinfo/fragment; target begins `/` | URL backing≤65536 |
| Fields | proper list≤256; binary two-tuples; target bytes + sum(name bytes + value bytes +32)≤65536 | sum of backing bytes of all name/value occurrences≤65536 |
| Trailers | proper list≤128; binary two-tuples; 2 + sum(name bytes + value bytes +4)≤65536 | sum of backing bytes of all name/value occurrences≤65536 |
| HTTPS trust | proper nonempty list≤128 DER byte binaries; each1..65536; logical aggregate≤1048576 | each backing≤65536; aggregate backing-occurrence sum≤1048576 |
| HTTP trust | exactly `nil`, producing `ssl: []` | no caller trust retained |
| Method | exactly `:get`, `:head`, `:post`, `:put`, `:delete`, `:patch`, `:options` | fixed existing atoms; no string-to-atom conversion |
| Upload | exactly `nil` or PID | PID term only; producer ownership/memory is an external P0/P4 obligation |
| Timeouts | integers1..86400000 for both request values | immediate bounded integer values; no clock access |
| Numeric dial | IPv4 tuple of4 integers0..255 or IPv6 tuple of8 integers0..65535 | no hostname lookup, list input or scope identifier |

Backing means `:binary.referenced_byte_size/1`; caps apply before copies.
Source aggregate policy binary backing-occurrence sum is≤1114112
(65536+1048576), and source aggregate request sum is≤196608
(URL+fields+trailers). Shared parent backing is counted per occurrence as an
explicit conservative upper bound. This rejects some physically smaller shared
trees; it keeps the contract simple and never undercounts them. Aggregate limits
are enforced as each leaf is visited, independently of logical charges.

Each name must be a nonempty ASCII HTTP token. Values permit HTAB and bytes≥32
except DEL; reject CR, LF, NUL and other controls. URL/origin text must be ASCII,
without whitespace/control, backslash, malformed percent escape or literal `#`.
Use `URI.parse/1` only after URL/backing size and ASCII preflight; validate its
bounded derived fields. No Unicode/IDNA hostname conversion or URL normalization
framework is added. Preserve percent-escape spelling, query ordering and empty
query. An absent/empty path becomes `/` only in the separately constructed target;
the accepted absolute URL string is unchanged. IPv6 authority brackets are valid.

Policy origin follows existing dedicated origin validation: only no path, empty
path or `/`, with no query, userinfo or fragment. Match request origin by parsed
scheme, ASCII lower-case host and effective port, so explicit default port and
host case do not create false mismatches. Literal IP dialing remains distinct
from hostname authority/SNI. This is validation, not destination authorization;
the existing destination policy still owns authorization at eventual connection.

The field charge conservatively counts the actual origin-form `?` byte, unlike
the upstream0.21 request check's `path <> query` charge. It therefore satisfies
both limits without rewriting the URL. Generated Host/framing/User-Agent and
transport transformations remain P3/P4 work, not an asserted full wire bound.

## Trailers and trust

Preflight all pairs, counts and byte/backing totals before trailer helpers.
For bounded initial `trailer` and `connection` values, scan comma-separated token
names with an explicit128-token ceiling per class across all fields. Trim only
OWS, reject empty/invalid tokens, and lower-case ASCII for comparison. This is
an additional managed-profile restriction; it avoids an unbounded declaration
list before the public trailer checks. Do not reorder or normalize output pairs.

Use public `HTTP.Trailers.upload/2` with bounded `%HTTP.Headers{headers: fields}`
to enforce static forbidden names, Connection-nominated forbidden names and H1
declarations. Convert every helper rejection into `:invalid_trailers`; never
return its arbitrary field/name payload. Nil body requires empty trailers.
Empty PID upload with declared trailers is valid; this module does not start,
finish, query or assert ownership of that PID.

DER-list payloads are opaque bounded byte strings here, not a claim of valid DER
or trusted identity. HTTP/OTP retain real validation. Copy every payload.
Host-default CA trust, paths, charlists, PEM/file input options, client
certificates/private keys, callbacks and arbitrary SSL keywords are explicitly
unsupported. No PEM decoding occurs, so a PEM payload inside an otherwise valid
binary list is not detected or rejected as PEM by this module. A future
bounded file reader may yield this DER grammar, but requires its own reader and
source/copy proof; this module performs no I/O. Existing dedicated transport
configuration and file-backed trust remain unchanged.

Construct fixed `open_options` with `origin`, `connect_address`, `http_version:
:http1`, `tls_backend: :ssl`, `http2_profile: :native_v1`, `max_requests:32`,
`max_connections:2`, `max_pending:0`, `idle_timeout:30000`, `ssl`, `socket_opts`.
HTTPS `ssl` is exactly `verify: :verify_peer`, `depth:4`, `versions:
[:"tlsv1.3", :"tlsv1.2"]`, `cacerts: owned_der_list`,
`server_name_indication: generated_ascii_charlist`. Socket options are exactly
`buffer:8192`, `recbuf:8192`, `sndbuf:8192`, `nodelay:true`,
`send_timeout:30000`, `send_timeout_close:true`. SNI charlist has≤253 cons cells.
Only after constructing this finite tree, require
`:erlang.external_size({ssl, socket_opts})<=1048576` to match upstream policy's
final ETF cap. That cap makes DER aggregate equality potentially unacceptable
once ETF/option overhead is included. ETF bytes are a compatibility charge,
never heap bytes. Do not invoke the private upstream Policy module.

## Validation, bounded work and errors

Use two bounded passes: validate complete permitted source shapes/backing, then
construct owned copies. Pair traversal inspects at most257 list cells for fields
and129 for trailers; trust inspects at most129 cells. At the first excess cell,
reject without inspecting its head/tail. Improper tails and malformed pairs
reject by pattern matching. Do not call `length`, `Enum` or `external_size` on
an unvalidated input list/tree. Byte scanners run only after their corresponding
logical/backing caps and stop at first rejection.

Unsupported maps/trees, functions, URI structs, header structs, buffered
iodata/empty binaries, convenience `content_type` and `duplex`, options trees,
trust/path forms and protocol overrides return a fixed atom. Error categories
are `:invalid_policy`, `:invalid_request`, `:invalid_url`, `:origin_mismatch`,
`:invalid_fields`, `:invalid_trailers`, `:invalid_trust`, `:source_backing_limit`,
`:request_limit`, `:trailer_limit`, `:trust_limit`, `:policy_limit`.
Precedence is shape, scalar constraints, bounded source traversal, semantic
validation, construction, final policy ETF cap. Tests assert atoms or the exact
intended limit category; no input value, path, credential, binary or stacktrace
appears in errors. No logging/inspection of rejected input.

Inspecting an already supplied giant binary/tree cannot undo its allocation or
earlier transfer. Even first-pass rejection leaves the caller's existing source
reachable until that caller releases it. This slice bounds work/new output for
valid finite sources and rejects unsuitable backing; the eventual caller must
establish the boundary before worker capture, mailbox send or admission. P0
therefore remains unresolved. No reservation/refund behavior is implemented.

## Manifest and ownership facts

Manifest is scalar-only fixed-shape data with `kind: :policy | :request`,
`source`, `owned`, `transient`, `limits`. It contains no input/canonical binary,
PID, certificate, callback or source term. Its own finite structure must be
included by later P2/P3 accounting; this manifest is not the full ledger.

`source` records logical binary bytes, conservative backing-occurrence bytes,
binary occurrences, cons cells, tuple counts grouped by arity, maps grouped by
entry count, atom occurrences, bounded-integer occurrences and PID occurrences.
It counts only the fully validated grammar, including its top-level map and IP
tuple. `owned` records those same named constructor counts for the entire
canonical struct/tree, using binary logical bytes and referenced-backing bytes
of the constructed leaves. Counting each reference as a whole representation
is intentional overcount; do not deduplicate arbitrarily by binary value.
No process/ETS/message/wrapper byte conversion is asserted.

`transient` records `source_plus_owned_backing_upper = source.backing_bytes +
owned.backing_bytes` and `pair_reversal_extra_cons = field_count + trailer_count`
(zero for policy). The first is a bound for retained source/canonical backing
coexistence, not an all-transformation peak: parsing, validation, target/SNI/ETF
construction and serialization temporaries are separately open P3/P4 obligations.
The reverse accumulator and final list can coexist; pair tuples can be shared,
so extra cons cells are recorded separately. Trust lists are copied with one
bounded construction walk; no redundant reverse-list claim is necessary.

Compact copies use `:binary.copy/1`. Every retained source-derived binary leaf
and derived target/host must have referenced backing equal to logical size on
the pinned runtime. Fixed immutable literal atoms/strings have separate provenance;
all retained constructed binary occurrences are included in `owned`. Tiny accepted
slices into an8192-byte parent exercise compaction; slices into oversized parents
reject. Source statistics are computed before copying, never overwritten with
new logical sizes. A zero-length value is a legitimate0-byte leaf; it does not
make source backing, constructors or an unknown ledger term zero.

## Named accounting facts and unresolved obligations

`facts/0` exposes fixed identities/profile and these independently derived
partial facts: request pair cap256, trailer pair cap128, conservative response
pair cap16384; cons2 words and pair tuple3 words on the declared64-bit profile;
pair skeletons10240/5120/655360 bytes for one list representation; upload chunk
cap65536 with maximum9 chunk-framing bytes; max URL65536; trust source caps and
aggregate backing caps above. These describe selected constructors only.
The response pair ceiling is derived from a≤65536-byte response head and minimum
four-byte ordinary header line; it is not the request256-field limit.

The API has no `evaluate`, `proofs`, `certificates`, allowance parameter, numeric
scope total, synthetic-production mode or activation-success result. All P0-P6
remain open, with fixed reason atoms: boundary/admission enforcement; delivery
logical/backing bound; runtime representation; policy/transformation peaks;
request phase/copy overlap; turnover controls; independently reviewed composition.
Body EOF/content-length events can exceed65536; one-byte event lists, complete
long chunk-size integers and rejected parser heads remain covered by named P4
work, without selecting a guessed delivery bound or fake multiplier. Static
constructor facts cannot close P1/P2/P5 or qualify network behavior.

## Acceptance and next boundary

Meaningful pure tests cover all exact limits and +1/count257/count129 rejection,
improper tails/unsupported trees, duplicate ordered fields/trailers, matching
origin, explicit default ports, literal IPv6, preserved escaping and `/upload?`,
all finite methods, nil/PID upload, timeout edges, trust aggregate versus final
ETF cap, source backing/aggregate versus logical size, and compact copies of
bounded parent slices. Independently calculate manifest counts for a small
fixture and verify source-plus-owned coexistence. For rejection, test a limit
prefix followed by a huge unsupported tail; constant-size returned error must
retain none of it. Check errors for credential material only through fixed exact
values, not by constructing/logging unbounded diagnostics.

Accounting tests assert independent arithmetic and open obligation identities;
assert that production activation is refused after successful preparation and
cannot accept a caller's constants or mismatched profile. Scope tests remain
unit-only. Required formatter, fresh scoped tests and independent specification
and code review occur after the parent releases the executable freeze and
serializes the commands. The implementation worker runs no Mix/network job;
the parent executed the scoped checks recorded below.

After this slice, P0 boundary/admission and P1-P5 must be proved, then P6 reviewed;
the parent owns future manager/custodian and adapter integration. The mandatory
managed H1 functional probes and separate≥600-second soak remain separate gates.
No host-default/PEM/path support, shared resource activation, H2 activation, full
M3 acceptance, publication/deployment or release-artifact E2E claim follows.
Initial counters for this pure task: Sol unsuccessful0, Astra0.

## Implementation handoff, 2026-10-11

The two pure modules and two scoped test files are written. Executable writing
stopped after the parent reported pre-format strict scoped GREEN:26 tests,0 failures,
exit0, seed21108026, all429 frozen source hashes unchanged. Readback of the
parent's [receipt](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-accounting-green.json)
and raw log confirms that result. Written design/plan specification review is
[PASS](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-spec-review.md).
The parent then canonical-formatted the four new executable files and ran the
global `mix format --check-formatted`, exit0. Independent
[implementation specification](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-implementation-spec-review.md)
and [code-quality](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-implementation-quality-review.md)
reviews PASS. The [fresh final run](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-final.json)
executes26 tests/0 failures, exit0, seed21108026, with429 unchanged source
hashes. Both reviews' four executable hashes match that run and current files.
The local commit is the remaining delivery step. No full acceptance or
production activation claim.

Three unexpected initial validation runs are preserved as FAIL: the map
constructor walk tried Enumerable on a struct; an append-built fixture retained
doubled backing; two exact manifest fixture counts omitted the top-level port.
Targeted repairs used `:maps.fold/3`, a compact fixture parent and independently
recalculated integer counts17/30. All three repair validations succeeded; the
last was clean expected accounting RED with all22 preparation tests passing
and only the missing accounting API failing. Expected API/struct red checks
remain distinct from those three FAIL receipts. A preliminary Python byte-count
audit also corrected an unexecuted request fixture expectation to54/62/116.

Cumulative counters: initial unexpected validation runs3; actual Sol repair
validations3 successful,0 unsuccessful; Astra0. No escalation gate applies.
All worker commands finished; no worker Mix/network/commit command or managed
runtime/process/file-I/O operation ran. Parent/shared edits are preserved.
All P0-P6 remain unqualified; H1 numeric activation is NOT ESTABLISHED.
