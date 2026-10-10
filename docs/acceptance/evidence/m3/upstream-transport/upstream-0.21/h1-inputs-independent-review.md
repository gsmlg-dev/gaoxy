# Independent narrow H1 public-input confirmation

Task `m3_public_client_audit/h1-inputs`; direct independent Sol source review.
Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Prepared 2026-10-11 Asia/Shanghai. Own this new report only. Other writers'
changes, original accounting report and the425-file source freeze are preserved.
No Mix, runtime, peer, dependency, upstream action or commit was performed.

**Source findings confirmed with one runtime qualification:** oversized URI
metadata, late convenience Content-Type and zero-payload iodata structure are
PASS as public admission/retention gaps. TLS binary backing is QUALIFIED: accepted
policy has no compaction/backing-size guarantee, while an actual retained backing
size on the qualification VM was not measured. No finding certifies a runtime
leak, RSS growth, exploit, numeric reservation or complete H1 acceptance.

These findings support separate upstream **needed** input-bound requests under
the intended Gaoxy URL-string/bounded-explicit-header/nil-or-PID/compact-owned-source
profile. They do not automatically block that narrower H1 path. That path still
needs complete accounting and exact VM delivery/representation proof. Parent
owns issue routing and exact issue receipts; no dependency workaround is added.

## Accepted TLS binary backing: QUALIFIED

Installed Policy48–67 bounds TLS/socket terms by depth/list length and
`external_size`; Policy196,289–293,316–323 accepts CA/cert/key binaries by type
and logical `byte_size`. Materialize217–226 returns caller binary values unchanged
when no file option is used. Policy68–99 retains them in the returned transport
policy. Facade94–110 passes that policy to the scope; Scope10,30,35 places it in
configuration ETS and state. No explicit `binary.copy`, referenced-backing cap
or documented compact-input condition is applied along this path.

A >64-byte DER subbinary can have much larger backing than its logical/ETF size.
A complete owned-retention promise therefore needs a normalized backing bound,
a proven VM representation guarantee, or an explicit compact-input contract.
The caller initially allocates the backing; retaining it is different from the
scope allocating it. State/ETS references can share one backing; reference count
must not be treated as independent payload copies.

Minimal finite recipe, **NOT RUN**: take valid DER `der` with logical size>64
and well below1MiB; construct `backing = der <> :binary.copy(<<0>>, 8*1_048_576)`
and `slice = binary_part(backing, 0, byte_size(der))`. Before scope opening record
public input properties `byte_size(slice)` and
`:binary.referenced_byte_size(slice)`, requiring the latter to exceed the former.
Open the H1 HTTPS8192-buffer profile with `ssl: [verify: :verify_peer,
cacerts: [slice]]`; all policy constraints can pass without dialing or DER
validation at opening. Return from the function that constructed input while
keeping the creator process alive, then use public retire/await under finite
cleanup. Creator death automatically aborts the scope and is unsuitable for
showing continued open-scope retention. Runtime/GC representation evidence
would need its own explicit receipt; this source review does not assert that
exactly8MiB survives every process/ETS copy on the current VM.

The accounting report correctly labels its recipe and memory observations
NOT RUN. Its logical-policy claim is supported; any future unconditional claim
about actual backing retained across process/ETS transfer needs that separate
VM evidence. Controlled Gaoxy TLS preparation must cap original/normalized
file/DER backing and preparation concurrency/transients, not logical bytes alone.

## Oversized URI authority: PASS

Public Fetch docs/spec accept URL string or URI struct (Fetch98,281).
Fetch282–298 retains a nonbinary URL unchanged as `request.url`.
Policy170–173 matches scheme/host/port and nil userinfo/fragment, ignoring
`authority`. Policy148–157 charges path/query and explicit headers only.
Thus a valid-host `%URI{authority: huge}` satisfies the early managed charge.

Retention is concrete in source: Fetch340–364 captures the request in its task;
SocketClient304–314 stores the full request in context and531–556 merges context
into live H1 owner state. SocketClient1425–1434 returns the original URL on the
response. HTTP1's Host is separately generated from URI host/port
(HTTP1:444–455, Request129–141); arbitrary authority is unnecessary wire metadata
but remains an accepted managed request/response field.

Minimal finite recipe, **NOT RUN**, with an existing managed loopback H1 scope
and independent peer: set `url = %{URI.parse(origin <> "/") |
authority: String.duplicate("a", 1_048_576)}`. Fetch with that scope, manual
redirect, raw streamed response, telemetry false, timeout1000/connect500.
A held valid response permits admission and lifecycle observations. Once the
peer returns headers, the public response URL can establish original authority
preservation. Capture original completion, then finite abort/await and scope
retire/await with peer shutdown. Increasing finite authority length does not
change the charged path/query/header bytes. This is a metadata-bound gap;
host/port matching still controls the actual destination.

Gaoxy's bounded URL-string preparation excludes the inconsistent struct form;
that exclusion is not a guarantee about all broad public URI inputs or backing.

## Convenience Content-Type after charge: PASS

FetchOptions289–290/306–307 stores and retrieves the convenience value unchanged;
Fetch286–298 places it in `request.content_type`. Policy148–164 charges existing
headers/target/body, not that field. A PID body passes immediately. For POST
with `duplex: :half`, Request152–154 returns the provided type;
Request183–189/263–264 inserts it as Content-Type after managed preparation.
Headers412–426 retains the value. H1 serialization runs later
(SocketClient1695–1716, HTTP1:44–52); HTTP1:502–538 validates header syntax but
adds no aggregate size limit. A large printable value therefore escapes the
promised64KiB metadata charge and enters header/wire representations.

Minimal finite recipe, **NOT RUN**: create `HTTP.Stream.start_link(0)` upload,
then Fetch a matching URL with common raw/manual/deadline options, method POST,
body upload, duplex half, no explicit Content-Type header, and
`content_type: "application/octet-stream; x=" <> String.duplicate("a", 65_537)`.
Use a peer prepared to read that finite head, finish the upload, return a valid
response, and require original completion plus scope retirement and peer shutdown.
The stream and defaults remain within ordinary preparation limits; the
convenience value alone exceeds the charged request-header ceiling. An explicit
Content-Type field would be charged early, so it is a useful paired rejection
control in an upstream deterministic regression.

Gaoxy passes explicit bounded headers and omits the convenience option. Preserve
that admission contract; also charge inserted default/framing fields in its
complete formula.

## Zero-byte buffered iodata structure: PASS

FetchOptions278/309–310 retains original body input; Fetch286–298 stores it.
Policy162–164 allows any iodata with logical payload<=1MiB. `List.duplicate(<<>>,
N)` has zero payload for arbitrarily increasing finite N and no list-depth/count
cap on this request-body path. Request172–173/254 only flattens the list later
when H1 prepares the body. The original request still remains in owner context/
state (SocketClient304–314/531–556), even after the wire body is normalized.
An input copied into managed task/request state has structural cost beyond
caller producer input, which the public docs exclude (Facade48–53).

Minimal finite recipe, **NOT RUN**: matching managed H1 POST with
`body: List.duplicate(<<>>, 100_000)` and common raw/manual/finite-deadline
options. Its payload charge is0. Hold the peer's response briefly under the
fixed request deadline, then complete or abort and require public completion,
retirement and peer shutdown. Compare separate predeclared finite list lengths;
a successful finite runtime case alone cannot prove the missing structural cap.
Expected upstream behavior must bound/normalize retained structure before launch
or expressly narrow the accepted buffered-input contract.

Gaoxy creates only nil/PID uploads (adapter36–45) and forwards bounded binary
chunks (proxy HTTP270–285). ACK limits outstanding logical payload; compact
owned backing is a separate premise for producer pieces, headers/URL and policy.
No general buffered-iodata bound is certified by this exclusion.

## Verification and disposition

Read-only numbered source reads, targeted `rg`, SHA-256 recomputation and inline
Python checks confirmed the original H1 report's inspected dependency hashes
and all425 frozen live hashes. No claim here uses private scope/process state.
Recipes, runtime acceptance, memory measurements and publication: NOT RUN.
No incorrect source finding was identified within this bounded assignment;
TLS's source-backed missing guarantee is deliberately distinguished from actual
VM retention measurement. Original H1 report is preserved unchanged.
All owned commands finished; no owned jobs remain. Review repair rounds0,
Astra0. Parent routing and any revised public contract remain separate work.

## Input SHA-256

| File | SHA-256 |
| --- | --- |
| `deps/http_runtime/lib/http/managed_transport.ex` | `92e0cc7649790029cf95b51c09e6d4e845c6183462083ab2272818cf57197c54` |
| `deps/http_runtime/lib/http/managed_transport/policy.ex` | `d2164cc922893b9cb626b3886d1fbdc1c4f479f1253446277120df6720df1279` |
| `deps/http_runtime/lib/http/managed_transport/scope.ex` | `73fb847f72846aa1d1f3fa0f3e4fc039741f0212b1d7fd4177f63d020e26b57b` |
| `deps/http_fetch/lib/http.ex` | `b86d8cc723cbab453e04dee8cf2a8bd99ca5a08d638c07a1d677ef501a495f7b` |
| `deps/http_fetch/lib/http/fetch_options.ex` | `8e035e1ec4a8c3afb68731ceb325ddf1cd1b5a780bd1b2a063e3f417241b6061` |
| `deps/http_fetch/lib/http/socket_client.ex` | `1b6b494264c8eb8620471bdb7b80910cd31db67e951d3f24e14e9cefecb4a3e7` |
| `deps/http_core/lib/http/request.ex` | `b097ad2d68d3a4d715dad594f02cc9025b6a17a267175b375a4b7d37bc675dcf` |
| `deps/http_core/lib/http/http1.ex` | `c84ddf5081b4d61a824789ebb9f606dc4c6d6aa91b69f233bde3b3c5d3997422` |
| `deps/http_core/lib/http/headers.ex` | `490e85607b4e375323945e984b618319a48b3bc4d08148d2e55195e41d427a4a` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` | `c58065e3e7e1accf355b9bc288fd62473918a88581008af2cb26ad941f2637a0` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` | `6650ed1169c8284be4e87a08341a747c475994f2bce6194eda48867c2e158615` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-review.md` | `3257a66c8c5423e081f20eba43f2e71d9077454cbedf94a0588c84e151667368` |
