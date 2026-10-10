# Managed H1 generated String transform source worksheet

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_string_transform_proof`.
Assignment: direct Sol, bounded source investigation. Report: **DONE**.
Conditional generated trim/case result and constructor lemmas are established.
Full P3/P4, composed reachable-owned-object budget, reservation and H1/H2
activation: **NOT ESTABLISHED**. Mix, VM, runtime/network probes and tests:
**NOT RUN**. Python checks below are static generator/data arithmetic.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`. Baseline at assignment start:
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`; parent may advance Git history while
committing reviewed work. Source identities are the receipt's exact file hashes,
not an assertion that the initial dirty worktree equals that commit.
Only this new report and [its receipt](h1-string-transform-proof.json) are owned.
Preceding parser/source reports and concurrent parent work are preserved.

## Provenance, ledger and input boundary

[Elixir source provenance](elixir-source-provenance.json) pins generator/data
input `/nix/store/qa7m7ymrcm7izhjdki9r5z1gsvgbfd05-source`, fetched as
elixir-lang/elixir `v1.18.5`, signed and recomputed recursive NAR
`sha256-C7RXBjZZbdSgz4jdoOCKv8xfM95ChrYjXIIS/ahX+3Y=`. Generator, UnicodeData,
SpecialCasing and PropList hashes match that receipt; all four installed public
source matches and six installed BEAM fingerprints were rechecked statically.
Makefile:92-108 builds unicode.ex into String.Unicode/String.Break before public
Elixir sources. This identifies generator/data and installed artifacts, not a
reproduced build or the code actually loaded in a managed worker.

The Elixir derivation was compiled with Erlang28.5.0.5; the active parent runtime
receipt is OTP28.5.0.7 / ERTS16.4.0.6 / word8 / JIT. OTP source here is
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`. Conditional OTP constructor
semantics are from that exact source. Loaded-code identity and applicable compiled
instruction choices remain enforcement obligations; no VM/disassembly was run.
Elixir references below are relative to its source input; OTP references are
prefixed OTP; dependency paths are relative to the worktree. HTTP0.21.0 cohort
tag commit is `9813c126dc8b48055b9ee941c693fc27fa691489`.

Use [the architecture](h1-accounting-architecture.md) and
[parent layout](h1-term-layout-proof.md) boundary: reachable owned objects,
retained backing, simultaneous reachable copies, object headers/word padding and
included resource metadata. Unreachable garbage, unused GC heap space, allocator
slack/fragmentation, kernel buffers and TLS-private allocations are excluded.
Exposed TLS delivery backing remains included. Global immutable Unicode mapping
literals are outside scope, while newly constructed list slots referencing them
and any newly copied term occurrences are included.

The controlled request grammar supplies ASCII URL/origin text, host<=253 bytes,
ASCII token names, fields<=256 and trailers<=128, each capped aggregate<=65536;
opaque values can contain invalid UTF-8. Public Policy.freeze does not itself
preflight all original caller input/backing before transformation. These formulas
require the managed bounded boundary first; its eventual enforcement remains P0.
Caller-supplied option-key strings and convenience Headers.from_map/parse, Unicode
methods/hostnames, content_type and proxy modes are excluded by that grammar.

For any transform input let b be logical bytes and K its referenced payload
backing, K>=b. Response components use [the parser worksheet](h1-parser-root-proof.md):
head/trailer input cap H=65536, complete chunk-size line/input cap T=H+D, and
parser-origin backing<=A. Do not replace K by b when a field is a large-parent
slice. Let S(m)=m*(m+1)/2, m=min(b,64), accounting for all decreasing small suffix
or prefix copies in one monotone slice chain, as a conservative construction
count rather than a claim that every such object stays reachable.

## Exact generated case table

The generator reads15-column UnicodeData, then overwrites by the103
unconditional SpecialCasing rows preceding `# Conditional Mappings`
(lib/elixir/unicode/unicode.ex:18-31,76-114,159-188). It does not apply every
conditional locale mapping. String.downcase/1 chooses :default
(lib/elixir/lib/string.ex:928-943); generated explicit I/İ/sigma clauses implement
that default before generated lookup clauses (unicode.ex:235-295).

Static faithful extraction found40116 UnicodeData rows and2981 combined entries.
The generated changed-downcase set excluding special I/İ/sigma has1457 entries,
25 ASCII keys handled by the byte fallback, one non-ASCII single clause and54
non-ASCII prefix tables. Prefix-table binary fallback widths are2/3/4 bytes
(16/28/10 tables). Every one of54*256 table-byte choices was checked, including
non-continuation bytes, using the literal fallback emitted at unicode.ex:213.

| Default operation | Maximum output/input byte ratio | Witnesses | Maximum mapped output |
| --- | --- | --- | --- |
| downcase | 3/2 | U+023A→U+2C65, U+023E→U+2C66, U+0130→`i`+U+0307 | 4 bytes |
| upcase | 3 | U+0390→U+0399+U+0308+U+0301; U+03B0→U+03A5+U+0308+U+0301 | 6 bytes |
| either, ASCII input | 1 | ASCII case changes preserve bytes | 1 byte per ASCII byte |

Upcase extraction additionally checked58*256 prefix-table byte choices; it has
1551 changed entries excluding special i, three non-ASCII single clauses and58
prefix tables (unicode.ex:345-379). Full upcase is recorded for completeness;
managed Request.method_token receives only seven fixed atoms, maximum7 ASCII
bytes, so its admitted upcase uses the1 factor (request.ex:100-109).

For every binary, including malformed UTF-8, result logical bytes obey
O_down(b)=floor(3*b/2), O_up(b)=3*b; ASCII uses O_ascii(b)=b. Every generated
branch consumes at least one byte, appends one accumulator item, and emits at
most its respective ratio. Singles/table prefixes match bytes; unknown table
bytes recreate the consumed prefix+byte; the final fallback consumes one byte
and only changes ASCII case. No branch calls a UTF-8 decoder or raises a Unicode
conversion error. Invalid bytes are not assumed discarded or normalized into
valid Unicode. In :default the sigma condition short-circuits before Greek
context scans. Other modes are outside these factors' admitted call paths.

## Case constructors and backing

For b>0, q iterations<=b. Each iteration makes one accumulator cons; final
:lists.reverse can allocate q more cons while the first spine survives
(unicode.ex:238-295,347-379). Therefore these spines use<=2*b cons or4*b words.
Items are immediate bytes, fixed literal mapped binaries, or a newly constructed
prefix-miss binary. Reversal shares each item; it does not copy its payload.

A table miss constructs `<<literal_prefix, byte>>`, logical length2..4. Source
Elixir lowering converts the literal prefix to Erlang string segments
(lib/elixir/src/elixir_erl_pass.erl:528-537); OTP v3_core expands them as integer
segments before initial append selection (OTP lib/compiler/src/v3_core.erl:
1393-1429,1595-1610; beam_core_to_ssa.erl:688-705). That **narrower compiler-path
lemma** produces a fresh<=4-byte heap binary. It has<=24 bytes including its
heap header and word padding under the parent layout formula. This source chain
is not an installed instruction certificate across the28.5.0.5/28.5.0.7 build
boundary.

For a bound that does not select that lowering alternative, admit the ordinary
fresh/checked-append/private-append constructor union from the parser worksheet.
A fresh result is its logical length; a copied nonwritable append has minimum256
payload bytes, otherwise at most twice used size while these small constructions
remain below16MiB (OTP erl_bits.c:70-73,1725-2008). A source literal is<=6 bytes
and never imports the caller backing. Thus **F_case=256** bounds one case-item
backing under this union. It is the actual append allocation floor, not a guessed
UTF-8/ETF multiplier. Counting up to b such candidate item occurrences deliberately
overcounts immutable literal items and repeated references to the same item.
The narrower fresh-prefix path may use F_case=6 as a conservative item payload
ceiling, provided that path/code identity is independently qualified.

IO.iodata_to_binary delegates to iolist_to_binary (io.ex:748-750). Empty output
is empty; `[binary]` returns that item unchanged; a real multi-item flat list
creates an exact logical-sized binary (OTP erl_iolist.c:719-737,881-885,916-927).
Consequently K_case<=max(F_case,O(b)) for b>0 and0 for empty. ASCII uses<=b:
its items are immediate bytes or fixed one-byte literals, with no table-miss
construction. Case output does not preserve the caller's K backing, but input
and current suffix still retain K until their roots leave the call.

A conservative per-call constructor envelope, allowing every constructed
candidate to coexist, is:

- list spines: <=2*b cons;
- candidate item binaries: <=b, each backing<=F_case;
- suffix/result binary occurrences: <=b+3; match contexts are a separate
  included runtime representation category;
- copied small decreasing suffix payload: <=S(min(b,64));
- distinct payload upper envelope: K + b*F_case + O(b) + S(min(b,64)).

Binary wrappers/heap headers and word padding use the parent layout as separate
terms. Match-context count/layout under the actual compiled pattern dispatch is
`M_match`; it is separate from the source-level binary occurrence count. Shared K is counted once in the payload union; repeated
wrapper occurrences are separate. The envelope also overcounts output when
singleton aliasing applies. Reachable stack roots and simultaneous term copies
require composition; unreachable loop garbage is outside the ledger.

Flat case accumulators contain no nested lists, so the iolist engine's nested-list
ESTACK push does not occur (OTP erl_iolist.c:156-207). Yield can retain result,
flat input, scalar state and one saved magic ErtsL2BState/ref; the initial and saved
state may overlap during the transfer (698-708,765-804). Name their included
layout/control charge `M_iolist`; its count is bounded by this path, but exact
magic object/native resource metadata is still P2 work. It cannot be silently
zeroed or charged as allocator slack. No badarg iodata branch is reachable from
the admitted byte/binary accumulator; resource/code-mismatch failures still need
exception/argument-root accounting.

## Generated trim paths

PropList contributes25 White_Space scalars: six1-byte, two2-byte and seventeen
3-byte literals; maximum3 agrees with @whitespace_max_size
(unicode.ex:383-410). The receipt lists all25 exact scalars and verifies the
widths. trim/1 is trim_leading then trim_trailing (string.ex:1321-1325).

Leading trim matches a whitespace literal, takes its remaining binary and tail
recurses; otherwise it returns that binary. Trailing trim reads a3-byte window,
returns input if no generated suffix matches, or takes a strictly shorter prefix
and tail recurses; the final size<3 uses the small-byte clauses (unicode.ex:
414-465). Every match removes1..3 bytes. Unknown/invalid UTF-8 bytes stop the
relevant byte-pattern trim rather than raising a Unicode error. The result is
an unchanged term, a suffix/prefix slice or a small copy; logical output<=b and
referenced payload<=K. Trim can therefore pin a huge parent through a short
field until the pipeline explicitly releases/copies that field.

Bound the combined leading/trailing monotone slice chains by3*b+4 binary
occurrences: at most b leading suffixes, b trailing3-byte windows and b shorter
prefixes, plus input/result/small-case allowance. Trailing windows each copy
<=3 bytes; the final `<<x>>` constructs at most one1-byte binary. Large slices
share K; small prefix/suffix copies total<=2*S(min(b,64)). A conservative payload
construction envelope is **K+3*b+2*S(min(b,64))+1**, plus occurrence headers/word
padding/match-context representation. No accumulator/list is constructed by
these trim loops. Construction-count overcount bounds any reachable subset;
GC garbage and unused heap capacity remain excluded.

## Literal splits, trailer regex and policy key regex

String.split literal branches use binary.split for unlimited/parts2 or repeated
splits for parts3 (string.ex:528-572,636-648). For nonempty delimiter width a,
returned parts<=floor(b/a)+1, additionally capped by :parts when present; returned
part byte lengths sum<=b and each backing<=K. Count returned cons/part wrappers
and small-copy payload separately. Native split/search control metadata is
`M_split`; no per-part fresh K allocation is inferred. Used delimiters are CRLF,
colon, space, comma, semicolon and dash; regex split/empty-pattern graphemes are
outside these call paths.

Trailers.trim_ows applies `Regex.replace(~r/\A[ \t]+|[ \t]+\z/, value, "")`
(trailers.ex:118). Successful matches are only at the two edges and consume
positive bytes, so m<=2. Output logical<=b; no-match returns original input;
actual multi-piece flatten makes at most b logical bytes; singleton/slice cases
preserve backing, hence final K_ows<=K. The public replacement constructor
(regex.ex:725-741,778-843) builds <=2*m+1 outer iolist cons, empty replacement
lists and one index tuple per match. Returned native capture data has one full
capture (no user capture groups): up to m outer cons, m inner cons and m
position/length two-tuples. These are finite returned constructors, not native
regex-engine workspace certification. Untouched slices share K or make small
copies; only disjoint untouched spans appear in the result iolist.

Policy.normalize_key's different regex inserts one `_` between matched ASCII
lowercase/digit and uppercase pairs (policy.ex:328-351). For capped binary key b,
nonoverlapping matches m<=floor(b/2), result bytes<=b+m; subsequent downcase is
<=floor(3*(b+m)/2). There are three captures (whole plus two groups) per match,
a three-item replacement list and one three-entry index tuple; the same
apply_list control gives<=2*m+1 outer cons. Captures can retain the input K,
while inserted underscore literals are global. This binary-key branch is not
entered by controlled fixed atom options, and no unbounded public option-key
acceptance is claimed. Regex-native scratch/compiled-pattern/capture resource
metadata remain `U_regex_native`, even when returned term counts are bounded.

## Actual callsites and repeated inspection

| Callsite | Relevant finite transform |
| --- | --- |
| Policy.origin (policy.ex:167-173) | downcase host before public host-limit check; controlled ASCII/capped input must arrive first |
| Policy.freeze_ssl (202-210) | three eager String.to_charlist(host) expressions on a successful HTTPS path, including Keyword.get's default even with explicit SNI |
| HTTP1 parse headers/CL/chunk line (266-271,310,431-436) | two trims per field; CL trims again; complete hex line trim uses T, not8192 |
| Headers get/get_all/has?/delete/set_default | one downcase of query plus one per visited stored name; result values are returned unchanged |
| Headers.set (225-239) | normalized query then per stored field downcase(name) **and** downcase(normalized_name) inside the callback |
| Trailers declaration/connection_names/validate (16-33,57-75,90-118) | split/OWS trim/downcase token names; validation downcases field name again, twice on forbidden-name error |
| Request.method_token; HTTP1 generated headers | fixed ASCII method upcase, normalize synthetic header names through downcase/dash split/capitalize/join |
| SocketClient reuse/stream framing | repeated Headers lookups, joined connection values then downcase (1587,2010-2019); their invocation/lifetime count remains phase work |

For f stored fields with name-byte sum S_name and query length a, one full
get/get_all/has?/delete/set_default inspection has <=f+1 downcase calls and
processed-byte sum Q<=S_name+a. Early exit only decreases this envelope.
get_all adds filter/map result spines with <=f entries each. One set inspection
instead processes Q<=S_name+f*a after query normalization, where a now denotes
that normalized name's actual byte length, because it is lowercased inside every
callback. Do not reuse the one-query formula
for that inner callback or treat pre-normalized stored names as cost-free.

An isolated final HTTP1 head parse uses at most four complete named lookup scans:
Trailers.declaration gets trailer and connection, set_body_framing gets
content-length, and transfer_codings gets transfer-encoding. Their fixed query
bytes total48. Token values for trailer/connection/transfer-encoding belong to
disjoint selected fields, sum<=H; their split+trim byte inputs do not expand.
Thus the parser final-head **downcase work sum** is Q<=5*H+48, before later
SocketClient/stream/reuse passes. It bounds processed bytes and permits summing
per-call constructors, not a complete live-memory or per-response budget.
Individual valid head field counts can reach floor(H/4); response names need
not be ASCII. Managed request names are ASCII and remain separately count/byte
capped; the response bound cannot borrow the256-field request cap.

Trailers.parse eagerly creates all line/field entries before validate's128-field
result cap. The129th field can call validate_field before count<128 fails
(trailers.ex:20-29), so bound validation attempts by min(parsed_count,129), not128.
A forbidden name may downcase twice; malformed/oversized inputs still own their
already-created metadata. For a finite call multiset with Q=sum(input lengths),
case results sum<=3*Q/2, case list construction<=2*Q cons; sum the per-call small
slice allowances, candidate capacities and retained outputs by actual phase.
Repeated inspection creates new results even when semantically equal; never
convert these bounds into a fixed entire-request multiplier without a call table.

Headers.normalize_name applies downcase, dash split and map_join(capitalize)
(headers.ex:98-103). It is used for synthetic fixed ASCII names (Host, Connection,
User-Agent, Trailer, Content-Length and Transfer-Encoding), while parsed response
fields use Headers.new and bypass this normalization. For ASCII token length b
and p dash parts<=b+1, capitalization preserves each part's length: default
String.capitalize uses first ASCII grapheme/titlecase plus downcase(rest)
(string.ex:991-1003); OTP generated gc fast paths and case tables preserve a single
ASCII scalar (OTP gen_unicode_mod.escript:334-344,620-629,704-728,837-847;
string.erl:696-700). Static Unicode tables confirm the ASCII mappings. Its concat
has capacity<=max(256,2*part_length); total part-result backing<=256*p+2*b;
final map_join logical b and backing<=max(256,2*b), because real joining copies b
and singleton may inherit a part result. map_intersperse for a list constructs
2*p-1 cons without a reverse (enum.ex:1777-1779,1813-1817,4493-4501), plus the
split list and per-part case constructors. Tiny gc/titlecase argument/result
lists and binary headers remain included constant-per-part objects; their
primitive layouts and exact loaded helper identity remain separate obligations.
No arbitrary Unicode-capitalize expansion factor is borrowed from this ASCII
callsite, and no convenience header-normalization entrypoint is certified.

## SNI conversion and error roots

String.to_charlist calls unicode.characters_to_list and returns the result or
raises on error/incomplete (string.ex:2870-2883). In OTP a binary UTF-8 input uses
the optimized binary path (erl_unicode.c:1122-1146); it constructs two-word cons
per scalar (1342-1358), with original input and a bounded six-field restart tuple
when yielding (1728-1845). For controlled ASCII host b<=253, output has exactly b
immediate integer entries, <=b cons, no binary payload child and no Unicode-error
branch. A successful Policy.freeze_ssl evaluates that conversion three times;
a conservative constructor count is3*b cons, including possible overlap of the
two comparison operands and final stored SNI. Existing caller SNI and the host
binary remain separate roots. Pure preparation also makes/validates SNI lists;
its per-phase invocation and source/owned root overlap must still be composed.

For invalid UTF-8 outside that ASCII premise, native error/incomplete returns
valid-prefix list and rest slice (erl_unicode.c:1814-1845), and String raises
UnicodeConversionError. exception.ex:2138-2158 stores encoded prefix and a message
constructed through inspect(rest); it does not store rest as a final field, but
constructor opts, native return tuple and stack/argument roots can retain it
while the message is built. Native unicode.erl:277-284 also preserves original
arguments in error_with_info. Any exception-formatting/inspect configuration
and resource/code-mismatch failure metadata require `U_exception`; a scalar
error classification does not release those roots by itself. Default trim/case
on admitted binaries has byte fallbacks rather than these Unicode errors.

## Limits, verification and next phase

This closes the prior `U_string` generated trim/default-case result and finite
constructor/progress gap conditionally; it does not edit that earlier worksheet
or declare every public String transformation, helper native state or lifecycle
qualified. Remaining terms are `M_iolist`, `M_split`, `M_match`, included helper/resource
layouts, `U_regex_native`, `U_exception`, integer conversion/subtraction scratch,
URI/serialization/host-CA/policy transformations, and P4/P5 root-release/multiplicity
composition. Effective transport/profile and loaded code/native identity remain
unestablished. There is no numeric production reservation or activation PASS.

Smallest next bounded task: write the release/phase table for preparation,
final-head/event-batch handling, blocking ACK, terminal trailers/error, and
owner/pool turnover. Inventory each repeated helper invocation and distinguish
shared backing from new wrappers/small copies; then close remaining owned helper
resource-layout terms and independently review composition before runtime jobs.
No new demonstrated dependency bug, upstream action or product decision arises.

Fresh static checks verify all generator/data/public/BEAM input hashes, finite
mapping/whitespace counts, every54*256 downcase and58*256 upcase table-byte choice,
formula arithmetic, preserved reports, document links/fences/whitespace and
source fingerprints. These checks do not execute generated modules or tests.
Current String task Sol repair0 / unsuccessful0 / Astra0. Parser reporting
correction1 / executable repair0 and credit successful evidence repair1 are
preserved. Parent provenance successful repair1 / unsuccessful0 / Astra0 remains
recorded, including the earlier retained failed provenance collector. Own commands
finished; parent runtime jobs untouched; no commits or other file edits occurred.
