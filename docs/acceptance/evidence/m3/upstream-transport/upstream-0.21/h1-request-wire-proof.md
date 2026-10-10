# H1 request construction and wire-preparation source proof

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_request_wire_source`.
Assignment: direct Sol bounded P3/P4 source investigation. Status: **DONE** for
this worksheet and static receipt; independent review is pending. Full P0-P6,
activation, runtime ownership enforcement and a composed memory total remain
**NOT ESTABLISHED**.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`. Task start baseline:
`7cabfb77f2e87ee23d7684c118d4206f17f4fd95`; source collection HEAD:
`dcf2449c237914f94c041bddfcfb0a0a6e58c12f`. Parent Git-only advances are
permitted. Exact file identities, rather than HEAD alone, bind the proof.
Only this new worksheet and [receipt](h1-request-wire-proof.json) are owned by
this task. All previous evidence, executable files, concurrent shared edits
and parent jobs are preserved.

## Boundary and trusted inputs

This trace starts with the current pure canonical preparation grammar, follows
its conditional conversion into `HTTP.fetch/2`, and stops at H1 send preparation
and the public transport-send call. It does not qualify a managed OTP TLS
connection, run a worker, compose activation or change the adapter. Upstream
`gsmlg-dev/http_fetch#95` remains the separate TLS qualification blocker.

The [independent String review](h1-string-independent-review.md) is trusted for
default case/trim/split/ASCII header-normalization lemmas; Unicode tables are not
rederived here. The reviewed worksheet SHA256 is
`d6b818575aacc4e2a8bed8dd6d990eae24225a866f320bca0f6a657762f8174e`;
its receipt is `be02ca597c7cab533230bf091d98c0ef06cc51108da8c96f6499e8c607200dab`.
The source inputs are Elixir1.18.5 at
`/nix/store/qa7m7ymrcm7izhjdki9r5z1gsvgbfd05-source` and OTP28.5.0.7 at
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`. The existing Elixir
provenance identifies an OTP28.5.0.5 compiler input, distinct from the parent's
OTP28.5.0.7 / ERTS16.4.0.6 runtime. Generator/source identity does not establish
loaded BEAM identity or compiled reproduction. HTTP0.21 cohort tag commit:
`9813c126dc8b48055b9ee941c693fc27fa691489`.

The [accounting architecture](h1-accounting-architecture.md) includes reachable
owned terms, distinct retained backing, simultaneous reachable preparation
copies, headers/padding and owned process/message/closure/ETS/monitor/timer/
tracked-resource metadata. Unreachable garbage, unused GC capacity, allocator
fragmentation, total VM/RSS, kernel buffers and TLS-private allocations are
excluded. An exposed delivery or retained caller binary remains included.
No unresolved term below is replaced by zero.

Conditional representation inputs from [term layout](h1-term-layout-proof.md):
W=8, cons=16, two-tuple=24, n-tuple=(n+1)W, flat map with n<=32 entries
=(4+2n)W including its key tuple. Ordinary offheap/slice occurrence wrappers
cost64, with distinct backing separately; small heap binary b<=64 costs
16+8*ceil(b/8). `C_Binary=offsetof(Binary,orig_bytes)` remains a qualified build
input; driver padding is at most7. Immediate internal PID terms do not own the
producer process; external PID terms need their separate32-byte object.

## Canonical preflight and copy construction

Let H=65,536, u=URL logical bytes, K_u=its source referenced backing,
f/t=field/trailer counts, R=sum field name/value logical bytes,
D=sum trailer name/value logical bytes, and l=derived origin-form target bytes.
Successful pure request preparation proves:

```text
1 <= u <= H; K_u <= H; f <= 256; t <= 128
l + R + 32*f <= H; 2 + D + 4*t <= H
field backing-occurrence sum <= H; trailer backing-occurrence sum <= H
method in {get,head,post,put,delete,patch,options}; wire method m <= 7
body is nil or a PID; timeout/connect_timeout in 1..86,400,000
```

`ManagedH1Preparation.request/2` (68-110) first checks seven exact source keys,
scalars, URL/backing and pair limits, then parses/matches the origin, derives
l, checks the combined field charge, validates field bytes and declarations,
and calls public `HTTP.Trailers.upload/2`. The excess field257/trailer129 cell
rejects before its contents are inspected. URL parsing starts only after u/K_u
are bounded and ASCII/percent preflight succeeds. Rejected admitted-size URLs
can still contain a long decimal port; its parser/conversion work is included
before final port rejection. Nil body requires an empty trailer list; a PID
term alone does not prove producer ownership or ACK discipline.

Absent/empty path becomes `/`. Present query, including `""`, produces
`path <> "?" <> query`; absent query preserves path. Thus l is either the
path's logical size (at least1) or path bytes+1+query bytes. The target preserves
escaping, order and empty-query spelling. The canonical target is stored, but
upstream later **recomputes** it from its separately parsed URL.

`copy_pairs/1` (343-349) builds a reverse list of newly copied names/values and
new two-tuples, then reverses the spine. For q=f+t, new pair tuples<=q,
new spines<=2q; source pairs/spines can overlap. Charging source plus both
owned spines plus source/owned pair tuples gives `96q` skeleton bytes, at most
36,864, before maps/binaries/helpers. Reversal reuses tuple leaves; it does not
make another backing copy. `binary.copy/1` copies each URL, target and pair
leaf once; OTP `do_binary_copy` at `erl_bif_binary.c:2400-2447` allocates the
specified result bit length and can yield with source and result both rooted.
Zero-length results have zero payload, not necessarily zero term structure.

```text
owned binary occurrences = 2 + 2*f + 2*t <= 770
owned compact payload = u + l + R + D
                     <= u + 2*H - 2 - 32*f - 4*t <= 196,606
source backing-occurrence sum <= 3*H = 196,608
source-plus-owned payload upper <= 393,214 (6*H also safely overcounts)
```

Source request map7 and canonical Request map9 have conditional body/key-tuple
charges144/176. The copied target can overlap its original URL-derived slice
or concatenation result; this overlap is extra to source-plus-owned backing.
The returned constructor manifests are also retained terms. `constructors/1`
walks source and owned trees; tuple traversal constructs `Tuple.to_list` helper
spines, and map/histogram updates construct bounded result maps. The manifest
is a five-entry map with source/owned counters, two-entry transient facts and a
fixed limits map. Its counters and helpers must be charged; the returned
source-plus-owned fact is not a full parsing/transformation/manifest peak.

## URI construction and its remaining helper terms

Elixir `URI.parse/1` (`uri.ex:785-864`) calls two non-global `Regex.run`s: the
outer URI regex has nine capture groups (at most10 results including full
match); authority has five (at most6). Returned capture spines therefore have
at most16 cons, with at most16 binary occurrences, each of logical length<=u.
Their total logical occurrence sum is at most16u, an intentional overcount of
overlapping ranges. Regex options/result tuples and native restart state are
additional. `Regex.run` uses binary captures by default (`regex.ex:360-371`).
OTP `erl_bif_re.c:1152-1185,1207-1239` uses `erts_make_sub_binary` for binary
subjects and fresh data otherwise. The slice rules retain the original bounded
backing or copy small payloads; capture logical bytes are not independent
input-sized backing allocations. For the binary subject, a conservative union
is original K_u plus up to16 small capture copies of at most64 bytes each,
with each occurrence wrapper accounted separately. Trim/query-prefix slices
and regex-native state are additional, not hidden in that fixed capture count.

`URI` has eight fields plus `__struct__`: map9=176 conditional skeleton bytes.
The parse retains authority as well as host/path/query/scheme; host trimming
and lowercase scheme may produce new binaries. Match/capture/trim construction
and native regex workspace remain `M_match`, `M_URI_trim` and `U_URI_regex`.
No linear native-regex time/space claim is made. Decimal port parsing can read
up to u digits before admission rejects an oversized port. A conservative
port-result bit bound is4u (the source text is bounded), with separately open
`U_integer_parse(u)` for scratch and simultaneous accumulators. A valid final
port1..65,535 is immediate; that does not price its rejected-input conversion.

Pure preparation and Fetch each parse the URL. Their URI results need not be
simultaneously live, but the canonical owner can still retain source/canonical
values during Fetch. P4 must establish release edges; this report neither
forces all earlier transients live forever nor assumes them released at a
source-language rebinding.

## Conditional Fetch mapping and finite option construction

The existing `HTTPFetchClient.open/1` still makes its dedicated, unscoped call;
it does not call the canonical preparer or pass `transport_scope`. It uses
`http1_reuse:false`, explicit scalar options and a stream it creates itself.
This report therefore studies this **conditional future mapping**, not a
shipped integration:

```text
HTTP.fetch(canonical.url, [
  method: canonical.method, headers: canonical.fields, body: canonical.body,
  duplex: if PID then :half else nil, request_mode: :proxy,
  redirect: :manual, decode_body: false, stream_response: true, telemetry: false,
  timeout: canonical.timeout, connect_timeout: canonical.connect_timeout,
  transport_scope: existing_scope, http_version: :http1, tls_backend: :ssl
])
```

This is14 keyword cons plus14 two-tuples (560 skeleton bytes). No supplied
map headers, binary method, arbitrary content type, callback, proxy or Unix
socket branch is used. `FetchOptions.new` wraps list headers unchanged in
Headers map2=64 and keeps admitted method atoms; it does not enter binary
method downcase/atom creation. Policy's open-only `http2_profile:native_v1`
must not be forwarded as a Fetch H1 option: `Dialer.http2_options?/1` treats a
non-nil profile as H2 options and rejects it in H1. `Policy.freeze/1` correctly
omits that key from the eight-entry H1 transport injection. This mapping relies
on an already frozen, matching scope; scope opening is outside this trace.

`FetchOptions` has32 declared fields plus `__struct__` = **33 map entries**.
It is above the normal32-entry flat-map cutoff. Its constructor/updated copies
require `M_FetchOptions33` for the exact fixed-key HAMT shape and update paths;
using `(4+2*33)W` would be unsupported. A source-key extractor independently
counted the fields. Options normalization evaluates fixed scalar branches,
then Fetch makes an additional updated options map. Map updates may share
nodes; neither full copying nor zero allocation is assumed.

With this literal mapping, `to_transport_options/1` produces10 unique entries
(scope, telemetry, decode, stream, timeout, raw error mode, connect timeout,
redirect, version and TLS backend). `maybe_add` omits nil and uses Keyword.put.
Managed `Policy.prepare` merges eight transport entries, two overlapping, for
16 unique entries. Scope injection adds seven for23; lifecycle then24;
`handle_async_request` inserts `connect_failure_token` even when nil, for25.
TLS pinning replaces a key. The source list union is finite: a complete keyword
representation costs40n skeleton bytes, before nested children. Intermediate
Keyword filtering/merge/update spines and callback captures remain
`M_keyword(n)`; output n alone is not a whole operation peak. `Policy.prepare`
normalizes the14 supplied pairs into another14-cons/14-tuple list. Atom keys
bypass binary camel-key normalization. ETS lookup also copies its policy and
injection into the calling process: charge those term trees and lookup-list/
row metadata; no fresh DER payload copy is inferred when backing is shared.

`HTTP.fetch` parses u first, makes Request map9, computes a default User-Agent,
then invokes ManagedTransport preparation; preparation is **after** these
constructors. The managed admission claim at `prepare/2:201` does not prove the
future Gaoxy pre-Fetch token or bounded-rejection ownership invariant. The
conditional caller must hold its own preparation reservation before these
operations and retain it through release, including rejected Fetch attempts.

`Policy.request_bounded?/1:148-160` checks fields **after Fetch User-Agent
insertion**. Its temporary target is `(path || "/") <> (query || "")`, without
`?`; canonical preparation's l includes `?`. Canonical acceptance does not
promise successful scope preflight: f=256 with no User-Agent becomes257 and
rejects; a nearly full byte charge can also reject after the new UA. Preserve
those rejections and charge their preparations. No upstream validator is
bypassed and no local workaround is proposed. Pure trailer acceptance likewise
does not pre-approve the later H1 framing checks.

## Header mutations and logical head bound

Fetch evaluates `Headers.user_agent(:http_fetch)` before set_default; HTTP1
later evaluates `Headers.user_agent(:http_core)` before its own set_default.
The latter result is discarded on the successful path because Fetch has
already ensured at least one UA field. Both evaluations still construct
transients even with explicit UA. Let a be the logical bytes of the generated
http_fetch UA, and retain separate candidate backing/helper terms for both
calls. Its source expression has the form:

```text
Mozilla/5.0 (OS; ARCH) OTP/OTP BEAM/ERTS Elixir/ELIXIR APP/VERSION
length = 37 + |OS| + |ARCH| + |OTP| + |ERTS| + |ELIXIR| + |APP| + |VERSION|
```

OS/architecture/version/Application.spec outputs and interpolation backing are
runtime/profile inputs `U_UA`; this task supplies no numeric UA cap. Explicit
UA fields are already counted in R. Generated candidates are not cost-free
when an explicit field wins. Logical head bounds below leave a symbolic.

Direct proxy routing returns original headers and origin-form target;
absolute-form/CONNECT/proxy auth branches are excluded. H1 framing validation
accepts no TE, or exactly one trimmed case-insensitive `chunked` TE with a PID
stream and no CL; conflicting TE/CL and unsupported framing can reject.
`request_headers` then ensures UA, defaults Host, and replaces all Connection
fields. Managed H1 injects reuse=true, so Connection is `keep-alive` (10 bytes);
the dedicated adapter's `close` is5 and is not substituted here.

`Request.authority/1` adds IPv6 brackets where needed and a decimal non-default
port. For accepted parsed host h<=253 and port<=65,535, generated A<=h+2+1+5
<=261. Default ports add no suffix. Authority is eagerly computed even if an
explicit Host survives; its construction/backing remains a transient. Explicit
Host values/order/duplicates survive set_default and remain included in R.

| Body mode | H1 mutation after common UA/Host/Connection | Maximum final fields from original f | Extra logical wire upper beyond original R+4f |
| --- | --- | --- | --- |
| nil | Delete every CL; no content type addition; body is `""` | f+3 | a+A+46 |
| PID, existing valid CL | Unique exact decimal1..20 bytes, <=uint64; replace CL with same value, delete TE, default CT | f+4 | a+A+86 |
| PID, no CL | Replace TE with literal `chunked`, default CT | f+5 | a+A+114 |

The fixed-length row includes zero length. Repeated **identical** CL values
collapse through Enum.uniq and Headers.set; differing textual decimal values
reject. New CL cannot appear in that row without a source CL, and its normalized
ASCII name has the same14 bytes. No additive CL wire allowance is needed.
The chunked replacement has17-name+7-value+4-framing=28 bytes; CT is
12+24+4=40; UA10+a+4; Host4+A+4; Connection10+10+4=24. Counting all defaults as
new and retaining removed input charge intentionally overcounts duplicates
and absent branches. Successful scope preflight has f_after_Fetch<=256, so
its final serialization count is at most260; f+5<=261 is the broader canonical
constructor bound and is not an assertion that257-field preflight is accepted.

For actual emitted fields `g`, `R_h=sum wire name/value bytes`, and admitted
method m, the exact logical request-head length is:

```text
W_head = m + l + 14 + R_h + 4*g
14 = method-target space1 + " HTTP/1.1\r\n"11 + final CRLF2

nil:         W_head <= H - 28*f + m + a + A + 60  <= 65,864 + a
PID fixed:   W_head <= H - 28*f + m + a + A + 100 <= 65,904 + a
PID chunked: W_head <= H - 28*f + m + a + A + 128 <= 65,932 + a
```

These are logical wire bounds conditional on successful H1 serialization,
not a65,536 head cap or a byte-memory reservation. Header values remain binary
and opaque safe bytes, including invalid UTF-8; `to_string(binary)` preserves
them. No case expansion is applied to values. Literal method atoms become
ASCII uppercase m<=7. Query-present target concatenation, authority interpolation,
method conversion and UA interpolation may create backing not equal to their
logical length. Keep `B_target(l,K_u)`, `B_authority(A,K_u)`, `B_method(m)` and
`B_UA(a)` with their constructor/provenance dependencies. The source-language
`<>` expression alone does not certify compiled append capacity or aliasing.

## Header/list work and wire constructors

The String review bounds a query helper on n fields by at most n+1 downcases
and processed name bytes<=N+query bytes, where N is the current name-byte sum.
Headers.set additionally lowercases its normalized query per callback, so its
processed bytes after normalization are<=N+n*query bytes. The fixed queries
here have at most17 bytes. At most16 Headers query/set/delete operations occur
on a successful Fetch-through-H1-head path, including the original-CL query
and optional Trailer declaration's two get_all calls. This excludes pure
preparer trailer validation and later body processing. A conservative work
allowance is `16*(N_max+17*n_max+17)` plus at most five synthetic name
normalizations and value trim/case/declaration work. It is constructor/work
accounting, not a simultaneous payload amount. N_max may be bounded by
R+10+4+10+17+12; n_max<=261, with removed fields deliberately retained in the
sum. Fixed query normalization uses reviewed ASCII length/backing lemmas.

Elixir Enum list paths (`enum.ex:1123,1713,2616,4389,4520`) recurse over lists:
filter/reject builds at most n output cons, reusing pair tuples/leaves;
map builds one output cons per entry. Therefore:

| Operation on n entries | New visible constructors; original roots are extra |
| --- | --- |
| Headers.set_default, field exists | No new Headers map/spine from this function; query and eager value transients still exist |
| Headers.set_default, field absent | One Headers map2, one cons, one pair tuple; new normalized name/value children |
| Headers.set | <=n reject cons + <=n copied append-prefix cons + one appended cons/pair tuple + Headers map2 |
| Headers.delete | <=n reject cons + Headers map2; pair tuples/binaries reused |
| Headers.get_all | <=n filter cons + <=n mapped-value cons; no copied pair tuples |
| Enum.uniq(CL values) | <=n result cons and at most n distinct map keys; `M_uniq(n)` includes map update shape/helpers, including rejected conflicts |

Each callback closure/call stack and reviewed String work is additional. These
are per-operation constructor bounds; summing them as an explicit overcount
is possible, but maximum retained old/new roots needs P4 release proof.
`HTTP1.header_line` constructs four cons `[name,": ",value,"\r\n"]` per field;
header_lines outer map adds g cons. Head builds six cons; nil buffer wraps
`[head,body]` with two more. Thus:

```text
H1 head iodata skeleton = 16*(5*g+6) = 80*g+96 <= 20,976 at g=261
nil buffer wrapper adds32; {:buffer,iodata} adds a two-tuple24
PID prepared tuple {:http1_stream,head,stream,length} is arity4,40 bytes
prepare return pair is24; serialize result arity4 is40
HTTP1.new parser map9 skeleton is176, plus Headers map2/default children
```

A wire line references existing binaries/literals; there is no HTTP-layer
whole-head `IO.iodata_to_binary` in this restricted nil/PID path. Ordinary
binary fields reuse their leaf objects in-process. Method/target/authority/
synthetic names and UA may still be distinct new binary allocations. Token,
request-target and header-value validation uses `binary.bin_to_list`: one cons
per input byte. Across successful head validation this is at most
m+l+R_h byte-list cons as a conservative constructor-union count; callbacks,
stack/match state and release lifetimes remain separate. PID serialization
queries the original request CL and converts its validated at-most20 decimal
bytes; nonnegative parsed length is at most64 bits, not necessarily a tagged
small integer. Price it with the bignum formula plus `U_integer_parse(20)`.

## Request roots, copy edges and release table

This table supplies the concrete P4 graph for this bounded preparation phase.
A source-level transition names a possible release boundary, not a proven
runtime release barrier. Shared offheap backing is counted once per distinct
allocation, with sender/receiver wrappers and on-heap small-payload copies
separately. Do not multiply all payload bytes by a fixed pipeline factor.

| Phase / source | Reachable roots and copy edge | Release obligation / unresolved cost |
| --- | --- | --- |
| Pure preflight/copy (`ManagedH1Preparation:68-110,343-349,465-535`) | Source7 map, bounded original URL/pairs; URI slices; target result; copied Request9; reverse/ordered pair spines; source/owned counters and manifest | Caller must release source/URI/copy transients and decide manifest lifetime before refund. `M_match`, `U_URI_regex`, `M_URI_trim`, copy-yield state and manifest helpers overlap. |
| Fetch caller (`http.ex:282-337`) | Canonical owner can retain c and manifest; literal init14; new URI9; Headers2; FetchOptions33 and updates; Request9; UA candidate; ETS lookup policy/injection, normalized supplied list, transport keyword variants | Successful preparation does not release canonical.target/trailers held by caller. Rejection still creates completion/task path later; prep lease cancellation is not proof that caller roots have gone. `M_FetchOptions33`, `M_keyword`, lookup/counter/runtime metadata. |
| Task launch (`http.ex:339-391`) | Outer launch fun captures tracker, calling PID, association, request, abort controller, Unix path; Task async_nolink copies captured Request/URI/headers/options into task; launch monitor; Promise map3 and Completion map4 | Caller/source and launch/task representations can overlap. Payload is not carried by the `:request_launch` atom itself. `M_Task_launch`, process, closure environments, ordinary/magic ref and monitor/message metadata remain open. |
| Socket owner (`socket_client.ex:45-79,262-370`) | Task keeps request during await; start_child copies request into owner closure; launch monitor, owner parent monitor, ref and deadline timer. Context map9 includes request; owner state map17 after eight added keys | Task/owner structures coexist. Map.merge/update sharing and release of context/selection/prepared tuple need exact code/lifetime proof. Cancellation/death may delay release until confirmed completion. |
| Dial preparation (`dialer.ex:42-60,157-214,424-449`) | On a new connect, owner builds six-entry transport opts plus proxy_route (nil), socket keyword updates and H1 selection map2; dial closure captures host/port/options, not complete Request. Copies policy-bearing option children to dial worker | No claim of connect/TLS qualification. Connection success message/socket handoff and dial worker death are distinct. Reuse branch skips this new-dial edge. Address-pin validation eagerly converts host to charlist; SNI comparisons/conversions have finite h<=253 length but helpers remain open. |
| H1 serialization (`socket_client.ex:531-561,1695-1715`) | Owner Request remains intact while temporary normalized header spines/maps and head iodata are built. State stores original request and HTTP1 parser; prepared tuple contains head/body | Final header-line tree may release temporary Headers containers while retaining their binary leaves. Literal method/target recomputation can overlap canonical and URI pieces. Provenance/capacity terms above remain open. |
| Nil send (`socket_client.ex:1748-1803`) | Owner passes `[head,""]`; start_child closure copies iodata and socket into send worker; parent/ref captured. Worker calls transport.send then sends `{:send_result,ref,result}` | Normal result no longer embeds head, but send-worker exit/release and caller stack release must be proved; abort/timeouts kill worker without an immediate release certification. `M_send_public(W_head)`, copied skeleton/wrappers, process/control metadata remain open. |
| PID upload head (`upload.ex:8-62`, `socket_client.ex:1805-1821`) | Linked/monitored spawn copies head, original Headers and policy-bearing socket plus scalar captures. Upload state map7 stores original headers, not head; owner receives handle map4. `{:read_chunk,pid,:ack}` subscription precedes `{:start_upload,token}` | Head is sent before body read; subscription permits one producer chunk to overlap head send in worker mailbox. Head lexical root release must be established before next phase. Charge producer/chunk/source backing separately. Link, monitor, ref, message, process and upload-state metadata remain included. |

The context fields are nine; state fields are seventeen, with map skeletons
176/304 under the conditional layout. Upload state7/handle4 are144/96;
Promise map3/Completion map4 are80/96; their children are extra. Closure cost
is `(2+e)W` plus captured children, but actual compiled e/code identity and
spawn/message copy metadata remain named obligations. These sizes do not
claim the whole runtime object is an Elixir map. PIDs/ref slots do not include
resource records, lifecycle tracker, producer process or a scope's ETS tables.

The public TCP/SSL send boundary is `Transport.TCP.send/2:30` -> `gen_tcp.send`
and `Transport.SSL.send/2:107-108` -> `ssl.send`. No TLS/native flattening,
public-send error retention, exposed iovec/message or tracked resource cost is
silently zeroed or automatically classified as TLS-private. This task ends at
that boundary. Post-send response parsing/credit and full completion tracking
remain the preceding and subsequent independent obligations.

## Upload/trailer handoff, without body-lifetime qualification

A fixed CL upload writes raw chunks and decrements remaining. Chunked mode
writes `[hex(n),"\r\n",chunk,"\r\n"]` for nonempty n<=65,536: four cons,
hex digits<=5, logical chunk wire<=65,545. ACK follows successful send. Empty
chunk does not construct chunk framing. Final chunked send is
`["0\r\n", serialized_trailers_or_empty, "\r\n"]`: three cons plus the
trailers' outer/line lists (5t cons). Canonical trailer wire admission gives
final logical wire `3 + (D+4t) + 2 <= 65,539`. Actual upload repeats public
trailer validation and requires the original declaration; forbidden fields
and fixed CL trailers can reject. This establishes finite handoff shapes only.
It does not establish producer admission, concurrent source release, one-ACK
runtime enforcement or unbounded request-body total length. No numeric body
or trailer-root lifetime is added to the head reservation by assumption.

## Static verification, failures and next obligation

No Mix, Elixir/OTP VM, formatter, fixture, test, network operation, upstream
mutation or commit was run. No owned background command was created. Commands
finished and parent jobs were untouched. Files were read with scoped sed/rg
and hashes/static calculations used Python3 only.

The source collector's first run exited1: its regex `[a-z_]+` omitted
`http1/http2/http3` field names and incorrectly extracted23 FetchOptions map
entries. This was a collector failure, not a source finding. Repair1 accepts
digits after the first identifier character; the fresh collector exits0 and
extracts33/9/9 entries for FetchOptions/Request/HTTP1. The initial failure and
successful repair are retained in the receipt. The initial worksheet also misstated the UA fixed-literal sum as42; a
separate literal calculation gives37. Reporting repair2 corrects that sum,
the authority regex group count (five groups, six returned results), its
combined capture bound16, and one local evidence link. Both diagnostics remain
in the receipt. Sol repair rounds: **2**, all successful; unsuccessful repair
rounds0, executable repairs0, Astra0. Earlier
String/provenance/credit/parser counters are separate and preserved. One
preliminary sed lookup used the wrong `http_core` FetchOptions path, returned
ENOENT and was immediately corrected to the discovered `http_fetch` path;
it made no edit or validation claim.

Static checks:19 prior file-hash comparisons match;25 exact source inputs are
hashed; fixed literal lengths, keyword set unions10/16/23/24/25 and struct
shapes agree. Python checks5,397 head-bound algebra cases (f0..256, method
length1..7, three body branches); these model arithmetic and do not execute
HTTP. Final source/preserved-evidence hash stability, receipt identity,
Markdown links/fences/whitespace and changed-file ownership are rechecked after
writing. Exact command results are in the receipt. Independent review remains
required before the parent adopts this worksheet.

Remaining terms: fixed-key FetchOptions HAMT/update shape, URI/native regex and
integer scratch, UA/profile identity and backing, concat/compiled append
capacity, manifest/Keyword helpers, exact closure environments, public send
representation, runtime/message/monitor/timer/ETS/resource layout, rejection
roots and release multiplicities, policy/host-CA transformation overlap, code
identity enforcement and managed admission/producer discipline. They are not
new product decisions for this bounded report. The parent separately owns the fixed-key33-entry map proof; this report
keeps its charge symbolic until independent review. The next small request
source phase is to close **URI/UA/concat helper constructions**, then prove
the spawn/phase release intervals using the graph above. TLS#95 qualification and activation composition remain gated.
