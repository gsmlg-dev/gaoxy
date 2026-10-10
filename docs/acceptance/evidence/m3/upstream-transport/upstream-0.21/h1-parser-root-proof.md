# P4 managed H1 parser roots and backing worksheet

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_parser_root_proof`.
Assignment: direct Sol, bounded source investigation. Report: **DONE**.
Result: **conditional parser progress, append-capacity and root-topology lemmas**.
Full P2/P4, reachable-owned-object budget, reservation and H1/H2 activation:
**NOT ESTABLISHED**. Mix, VM, tests and network probes: **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Only this new report and [its receipt](h1-parser-root-proof.json) are owned.
Concurrent implementation, status documents and all seven preceding reports
are preserved. No dependency edits, private-API use or upstream actions occurred.

The ledger uses [the approved accounting boundary](h1-accounting-architecture.md)
and [the parent term-layout boundary](h1-term-layout-proof.md): reachable owned
term structure, distinct retained binary backing, simultaneous reachable copies
and preparation transients, object headers/word padding, and owned ETS, atomics,
monitor, timer, message, closure, process and tracked resource metadata are
included. Any simultaneous term/backing copies still owned during a construction,
message transfer or GC move require a charge. Unreachable garbage, unused GC
heap capacity, allocator slack/fragmentation, total VM/RSS, kernel buffers and
TLS-private allocations are excluded. Exposed TLS delivery backing and tracked
TLS-resource metadata remain included. These exclusions do not remove reachable
parser/consumer roots or their construction overlap from P2/P4.

## Premises and quantities

Import [delivery](h1-delivery-proof.md), [credit](h1-credit-induction.md) and
[decode/backing](h1-decode-backing-proof.md) only under their controlled profile:
C2/R32/P0, H1 raw streamed responses, manual redirects, decode_body=false,
OTP SSL inet/raw/header0/binary, effective B8192 and fixed positive N<=100,
default TLS1.2/1.3 suites, no caller/backend/socket overrides. Effective profile,
loaded native identity, ownership enforcement and independent composition remain
unverified. Neither C2 nor R32 proves a lifetime bound for caller-held results.

Exact OTP source is the signed fixed-NAR input
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`; installed runtime is
OTP28.5.0.7 / ERTS16.4.0.6 / SSL11.6.0.6, 64-bit, under
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
No OTP Git URL/revision is claimed. HTTP0.21.0 cohort tag commit is
`9813c126dc8b48055b9ee941c693fc27fa691489`. Additional Elixir source files are
read from installed package `/nix/store/22fybrvpfzc2csw3n686x8nr486jsj0n-elixir-1.18.5`;
the receipt hashes them, without asserting an independently verified compiler
or loaded BEAM identity. OTP references below are relative to the OTP input;
HTTP paths are relative to the worktree; Elixir paths are relative to the
installed package's `lib/elixir/lib/elixir/lib/` directory.

Define H=65536 (head/trailer carry), L=8192 (incomplete chunk-size line),
J=65536 (chunk-data emission), D=N*B+18437, and
K_delivery=max(D,18432,floor(4B/3)). Let T=H+D, and
A=max(K_delivery,256,2*T). In the intended profile T<16MiB and
K_delivery<=D; these inequalities, rather than a selected/default N, justify the
2*T branch. A bounds one parser-origin append backing, not all roots or physical
allocator memory. H is not the capacity of every binary reachable from a parser.

## Progress and returned carry

`deps/http_core/lib/http/http1.ex:55-60,83-84` appends `buffer <> data` before
parsing or validating. Starting from an ordinary successful nonterminal return:

| State | Returned logical buffer | Relevant source |
| --- | --- | --- |
| head | <=H without delimiter; delimiter index<=H accepts head plus four framing bytes | 89-109 |
| content_length | empty on continuing return; done may keep surplus | 112-131 |
| body_eof | empty after emitting the entire nonempty buffer | 134-139 |
| chunk_size | <=L only when no complete CRLF line | 142-161,394-407 |
| chunk_data | empty on continuing return; nonempty input is consumed recursively | 164-183 |
| chunk_crlf | empty or one CR byte | 187-200 |
| chunk_trailers | <=H without terminal delimiter; terminal surplus may remain | 203-214,410-427 |

Thus carry logical length<=H by induction from new/1's empty buffer, and one
ordinary input has logical length<=T. Delimiter searches and parsing can use all
T bytes. An oversized rejected head or trailer is appended before rejection;
no H-sized allocation claim follows from the error atom. Informational heads
are consumed and parsing repeats in the same input (221-223). Each iteration
consumes at least its four-byte delimiter, so the number of such completed heads
is bounded by input progress, even when the final head remains incomplete.

The bound excludes arbitrary direct calls to stream/2 after :done: append still
runs, while parse(:done) returns the growing buffer unchanged (87). SocketClient
stops on :done instead of rearming (1408-1422,1489-1515), so no ordinary response
continuation uses that path. Any admission permitting post-terminal calls must
supply a new bound. close/1 adds no new delivery/append: EOF close emits its carry
and clears it; already-done close preserves conn (HTTP1:64-80).

## Append constructors, copies and induction

Elixir `Kernel.<>/2` expands to byte-aligned bit syntax (kernel.ex:2053-2083).
The source-backed union below avoids guessing that every append copies or that
every append is private/writable. Exact installed parser disassembly was not run.
The capacity lemma is conditional on compilation using the ordinary matching OTP
bit-syntax construction paths; executable identity remains a qualification gate.

| Alternative | Payload capacity and copy consequence |
| --- | --- |
| fresh ordinary bit-syntax binary | Logical size s<=T; normal binary allocation uses s. Interpreter `emu/bs_instrs.tab:572-610`; JIT `jit/x86/instr_bs.cpp:2294-2317` dispatches ordinary bit initialization. |
| checked append, nonwritable source | Copies old logical carry into new storage; new capacity=max(256,2*s) while s<=16MiB (`erl_bits.c:1845-1924`, growth macro70-73). New data is written into that destination. |
| checked append, writable source | Reuses capacity if sufficient; otherwise reallocates to2*s, clearing incoming writable permission and returning a new writable descriptor (`erl_bits.c:1749-1843`). Zero new bits may return the old binary unchanged. |
| private append | Reuses/reallocates to2*s; trace-induced nonwritable fallback makes a fresh2*s copy (`erl_bits.c:1928-2008`). Tracing retention itself is excluded from the admitted accounting profile. |
| eliminated empty/singleton construction | Returning an input unchanged preserves its existing capacity; charge the original root, not a fictional exact-size copy. |

Both interpreter and x86 JIT call the checked/private helpers above
(`bs_instrs.tab:539-570`, `instr_bs.cpp:2210-2292`). Normal allocation/reallocation
sets `orig_size` to the requested payload capacity (`erl_binary.h:287-347`).
The writable branch may preserve a larger previously allocated capacity, so an
induction is essential: initial carry is empty; delivery capacity<=K_delivery;
all fresh or grown append capacities<=max(256,2*T); extraction never enlarges
backing. Any reused capacity is therefore<=A, and subsequent carry backing<=A.
This holds across fragmented head, line and trailer appends regardless of whether
the runtime copies each fragment or amortizes writable growth. No fragment count
multiplier is needed for the *returned carry's one backing*.

At a copying append boundary the old carry root (<=A), new delivery root
(<=K_delivery), and new destination (<=A) can overlap. Distinct payload storage
for those three operands/results is therefore<=2*A+K_delivery. If reuse or
aliasing occurs, count the same allocation once. The two capacities allow for
old/new reachable operand/result backing; internal realloc block overlap without
an owned reachable object is outside this ledger. Included backing-object headers
and reachable simultaneous term copies remain separate P2/P4 charges; allocator
slack/fragmentation and unused GC capacity are excluded. This three-root formula
excludes stored response metadata, parser temporaries and consumer roots.

## Slices and event batches

`binary_part`, matching and split expose slices or copies. `erl_bits.c:2635-2668`
and `erl_bits.h:167-168` copy extracted slices<=64 bytes to heap binaries; larger
slices preserve the original BinRef. `binary.c:476-512` and the backing observation
`erl_bif_binary.c:2508-2533` agree with that distinction. Large header/body/rest
slices of one append share its <=A payload; they do not each create a distinct
A-sized allocation. Small slices add copied bytes and wrappers and need a separate
charge. In particular, one-byte body events normally carry small heap copies.
A blanket claim that every one-byte event pins its own full append is incorrect.

Content-length emits min(buffer,remaining) in one body event, without J cap;
EOF emits the whole buffer in one event (HTTP1:116-139). Their safe logical
per-invocation ceiling is T; J applies only to chunk-data (168-183). Empty
content-length with remaining0 can carry completion to close/1; it causes no
unbounded body list. For chunk-data every positive event consumes >=1 input byte,
and the loop continues until carry is empty or framing needs more bytes.
One-byte wire chunks can therefore create a large event batch before any ACK.

Let n be positive body events in one stream/2 call and E all returned events.
Then n<=T, sum of emitted body logical bytes<=T, and E<=n+3<=T+3: at most one
final headers tuple, one trailers tuple and :done. Informational headers emit no
events; no extra body event is created without consuming bytes. Starting midway
through chunk framing does not invalidate this progress bound. It is deliberately
loose; no unproved six-wire-byte ratio is applied at fragmented boundaries.

Parser accumulation uses one cons/event; Enum.reverse can create another
cons/event while the old spine survives. Bound both spines by2*E cons cells,
4*E words. Event tuples have at most three fields plus a header: <=4*E words.
Thus <=8*E words (64*E bytes at64-bit) covers these specific list/tuple
constructors only. Reverse shares the event terms; it does not copy every body
payload. Small body-payload copies total<=T for this emitted batch because those
body slices are disjoint. Their heap headers/rounding, repeated intermediate
rest slices, reachable Enum intermediates and process-message copies are separate
P2/P4 costs, not included in64*E. Unreachable garbage and unused heap capacity are
outside the declared boundary.

SocketClient parses the *entire* input before reducing the batch
(socket_client.ex:1382-1390,1408-1422). HTTP.Stream.chunk/3 then blocks once per
body event (1469-1473; stream.ex:85-111). The owner may retain unprocessed events,
protocol and earlier response metadata while waiting; “one SSL delivery” or
“one stream pending ACK” does not make the parser batch one body event.

## Heads, trailers and construction temporaries

Accepted head length<=H; parse_head splits status/header lines
(HTTP1:235-281). A valid header consumes at least `a:` and a CRLF separator;
status syntax contributes positive overhead, so accepted field count<=floor(H/4).
There is no explicit response field-count128/256 cap. On malformed input the
initial CRLF split still constructs up to floor(H/2)+1 line entries before header
validation rejects empty/malformed lines. Header construction creates tuples,
accumulator and reversed spines. Headers.new simply wraps the list without
compacting or normalizing stored fields (headers.ex:83-85).

String.split with the literal delimiters used here dispatches :binary.split for
unlimited/parts2, or repeated splits for parts3 (string.ex:528-572,636-648).
Each split list and small-copy slice is a separate constructor charge. Headers
name/value trim can preserve backing; final accepted metadata is not guaranteed
compact. trim delegates to generated String.Break and default downcase to
generated String.Unicode (string.ex:1261,1292,1321-1325,934-943). Those generated
implementations were not available as source in this installed package. No
universal byte expansion/copy factor for them is asserted here, especially for
unvalidated Unicode response field names. Exact transform construction peaks
remain symbolic `U_string`, including Headers.get/get_all repeated downcase,
transfer-coding maps and trailer declaration/connection-name maps.

Trailers.parse enforces block+4<=65536 *before* splitting
(trailers.ex:39-55). This blocks a long complete trailer block after the append,
but its eager global CRLF split can still allocate up to floor((H-4)/2)+1 line
entries before validate applies128 fields/serialized-byte limits (16-33).
Successful trailers are <=128 fields and <=65536 serialized bytes. Their parsed
line tuples, two reversal phases, validated tuple/spine construction, forbidden
name lists and :binary.bin_to_list validation intermediates are distinct costs.
The128-field result limit cannot be used as the transient split-list limit.

Trailer trim_ows uses Regex.replace removing only space/tab edge matches
(trailers.ex:118). Regex.replace returns the original on no match, or collects
an iolist and flattens it (regex.ex:725-741). Its final logical output does not
expand; a real flatten may copy, while singleton/no-match can retain backing.
Reachable regex capture/scratch objects and owned regex-resource metadata remain
`U_regex`; allocator slack/fragmentation is outside the ledger.
Response head framing/trailer declarations also allocate get_all/filter/map lists
(headers.ex:175-180,200-208; HTTP1:284-342,375-390; trailers.ex:57-75,110-118).
Repeated inspection costs cannot be silently folded into the final metadata size.

## Long integers and rejected inputs

Status parsing accepts Integer.parse(status_code) with full consumption, without
a three-digit/range guard (HTTP1:248-253). Content-Length accepts all decimal
digits and converts via String.to_integer, including repeated equal values
(309-342). Complete chunk-size lines have *no* L guard: read_line first accepts
any found CRLF; only no-match carry>L errors (394-407). A complete line in the
bounded input may be almost T bytes, and parse_chunk_size accepts arbitrary
nonnegative hexadecimal Integer.parse results (431-441). Rejecting an invalid
suffix can occur after constructing a large integer prefix. L is therefore not
the digit limit for an accepted complete hexadecimal line.

Integer.parse first counts/splits the digit prefix then calls
:erlang.binary_to_integer (integer.ex:275-317); String.to_integer dispatches the
same BIF (string.ex:2964-2981). The C small path falls back to Erlang large-number
segmentation and pairwise multiplication/addition (big.c:3029-3126;
erts/preloaded/src/erlang.erl:1025-1141). Arbitrary-sized integers are heap terms,
not fixed64-bit counters. For d decimal or hexadecimal digits, magnitude bit
length<=4*d. Normalized bignum representation has one header plus base2^64 limbs
(big.h:55-98), so retained result words<=1+ceil(d/16) (small immediates cost no
boxed result words). Hence status/individual Content-Length result<=1+ceil(H/16)
words, and a chunk-size result<=1+ceil(T/16) words. These are result representation
bounds, not integer conversion/multiplication workspace or allocation totals.

A continuing protocol stores status and either remaining or chunk_size; consuming
body creates subtraction results while old integers may still be live. Multiple
Content-Length fields build a parsed integer list then Enum.uniq; their aggregate
digit bytes are bounded by accepted head length, but each has its own header and
list nodes. SocketClient parses Content-Length again for stream startup metadata
(2016-2019). HTTP.Stream.start_link passes that integer to streaming_start and a
startup closure (stream.ex:28-44); the steady stream struct does not store
content_length. Telemetry handlers/closure lifetime require separate accounting.
Integer pairwise combine may allocate successive limbs, radix squares and lists;
no retained-result factor bounds those reachable conversion/intermediate objects
or their simultaneous copies; unreachable GC garbage is excluded.

Rejected oversized heads/trailers retain the <=A append at least during the
rejection; malformed accepted-sized heads can already have split lists, header
tuples, bignums and transforms. Most parser errors are atoms, but unsupported
transfer encoding returns `{:unsupported_transfer_encoding, codings}`
(HTTP1:371,375-390); forbidden trailer returns a downcased name
(trailers.ex:90-94). These metadata binaries/lists may survive in terminal error
messages. Integer errors/exceptions also require stack/argument-root accounting;
no error path is charged as zero merely because no successful event was returned.

## Returned and terminal root inventory

| Root/stage | Retention and release obligation |
| --- | --- |
| conn.buffer | Nonterminal logical<=H, backing<=A; done surplus logical<=T can retain the entire append. HEAD/204/304/zero CL all allow such surplus. close(:done) keeps it. |
| conn.headers/version/status | Final header tuples and version may retain the head-completing append after body carry is empty, across later deliveries. Informational version can likewise survive while the next head is incomplete. Status can be a bignum. |
| returned events | Headers share metadata; large body/rest/trailer slices can share the append; small slices are copies. Both event-list spines can overlap during reversal; waiting for ACK retains the batch. |
| Response | Response.new preserves status/headers and request URL; with_stream_body replaces body/stream by PID (response.ex:241-269,339-341). status_text is a fixed lookup/default empty string (status_text.ex:109-112), not the arbitrary peer reason phrase. |
| Stream body queue / reader message | Raw decode with [] returns the same chunk (content_decoder.ex:30-38). No reader means queued chunk+pending ACK; ACK reader sends the chunk and waits for its ref; legacy reader ACKs producer after send (stream.ex:311-330). The latter permits reader mailbox growth across deliveries. |
| Stream terminal trailers/error | Trailers/error are stored/sent (stream.ex:235-267,279-288,341-374). Done/error without a reader loops even on timeout (294-295), retaining terminal metadata until a reader/stop arrives; producer ACK does not imply reader releases a binary. |
| SocketClient failure/result | Parser error reason is sent to parent or existing stream, then cleanup runs (socket_client.ex:1551-1570,1670-1686). The original owner protocol can remain a temporary root during cleanup. No automatic compaction of error metadata is performed. |
| buffered body | Enforced forced streaming excludes positive-body buffering. Without enforcement chunks accumulate across deliveries and final iodata flatten adds a body copy (1476-1477,1495-1508). Body-forbidden buffered response has empty body, but protocol surplus/head metadata can still retain backing. |
| pool reuse | Requires done and empty protocol.buffer (1572-1598); nonempty surplus forbids checkin. This does not revoke caller Response/header/error roots or stream/reader messages. |

For the current owner alone, raw parser-origin payload roots can include a stored
head allocation (<=A) in addition to the three append-boundary operands. Their
union is bounded by3*A+K_delivery *only for these four provenance classes*, with
aliasing deduplicated. Add final trailer backing if an external stream/response
holds it, transform outputs, small-copy storage and representation charges.
Previously delivered body/header/trailer/error allocations retained by consumers
are outside that four-class bound. It is neither an owner reachable-owned-object total
nor a connection/request-wide lifetime budget. A lifecycle table must establish
how many distinct earlier batches/results may coexist and when each charge is
released. A caller can preserve many completed responses regardless of C2/R32.

## Remaining gates and smallest next step

The worksheet closes source progress and ordinary append-capacity alternatives
under stated premises. It deliberately leaves these named terms unresolved:

- `U_string`: generated Unicode trim/downcase output/scratch, repeated metadata
  transforms, error outputs and peer-invalid Unicode behavior.
- `U_integer`: conversion segments/radix/multiplication/subtraction scratch and
  aggregate liveness, beyond normalized result words.
- `U_regex`: trailer regex/capture construction and engine allocation.
- `U_representation`: BinRef/slice/map/list/message wrappers, object headers and
  word padding, reachable simultaneous term/backing copies, and included owned
  native/resource metadata (P2). Unreachable garbage, unused heap capacity and
  allocator slack/fragmentation are excluded rather than unresolved charges.
- `U_lifetime`: parser/event/stream ACK, non-ACK reader, timeout/abort, terminal
  response/error/trailer and consumer roots across batches/requests (P4/P5/P0).
- `U_composition`: exact compiled/loaded cohort and effective transport/profile,
  admitted concurrency, reservation-before-copy enforcement, independent review.

Do not replace these with a guessed constant, production number, eight-window
factor, per-field A multiplier or zero-cost failure term. Full P1/P2/P4 and
P0-P6 composition/activation remain **NOT ESTABLISHED**.

Recommended next bounded task: obtain matching generated Elixir String.Break /
String.Unicode source provenance and close transform result/scratch constructors;
then write the P4/P5 root-release table for ACK and terminal lifecycle. Qualify
compiled identity/effective profile and independently review the resulting
composition before any parent-serialized runtime run. The observed limit paths
are recorded facts, not a demonstrated new upstream defect or issue request.
No product decision or permission request is needed for this evidence handoff.

Static verification checks source/receipt hashes, all seven preserved reports,
formula inequalities across admitted N1..100, evidence links, whitespace and
balanced fences. Current task Sol repair0 / unsuccessful0 / Astra0; preceding
credit evidence's successful repair1 / unsuccessful0 remains recorded. One
reporting-boundary correction resolves the independent review finding; it is not
an executable repair round and does not change the conditional formulas. Own
commands finished (including an interrupted broad read-only file search);
parent jobs untouched. No VM, runtime/network validation or tests were executed.
