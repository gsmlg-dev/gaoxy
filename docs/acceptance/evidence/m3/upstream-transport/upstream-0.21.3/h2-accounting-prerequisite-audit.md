# H2 accounting prerequisite audit — published/installed 0.21.3

**Complete retained-byte accounting is BLOCKED by the shared native/control
frontier in Feature #97.** Published H2 data/event caps provide useful finite
source inputs, but no supported complete envelope or reclamation receipt.
This is a missing contract, not evidence of an arbitrary-repeat memory leak.

Task `m3_h2_accounting_prerequisite_audit`, direct read-only Sol investigation.
Worktree `.trees/m3-gateway`, baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`.
The exact cohort tag/tree is `ceecbf2df62ca80c361597c7303f65a153f2ce3c` /
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. All inspected runtime bytes were
compared with installed `deps/` and the previously verified published cache,
then rechecked at the end. Exact paths, hashes, sizes and line anchors are in
[the audit JSON](h2-accounting-prerequisite-audit.json). No VM/test, dependency,
Git, issue, fixture or existing-document mutation occurred.

## One finite worksheet

Let `G` be a fixed, enforced outer-generation ceiling including opening and
uncertain generations; its H2 integration contract is an explicit missing input.
Let `C=max_connections` and `R=max_requests` be each frozen scope's accepted limits.
A charged pending/unconfirmed hold stays in those populations until the applicable
proof permits refund. `B_required` is the sum of the following classes at their
listed multiplicities, counting simultaneous copies and controls. It cannot be
assigned a finite accepted numerical value while any listed term is unresolved.
Source data charges below are not heap/RSS figures or an approved subtotal.

| ID / class | Enforced source expression | Missing retained-byte contract/input |
| --- | --- | --- |
| W01 Outer generations and failed/unconfirmed ownership (G) | A scope closes admission and keeps independently tracked resources through pending retirement. Never refund cleanup_pending/cleanup_unconfirmed. | INPUT_G: enforceable fixed outer generation count and operation grammar, including failed/opening/uncertain generations; no H2 production profile exists. Native release also needs NATIVE97. |
| W02 Frozen origin/TLS/socket policy and preparation (G plus bounded simultaneous constructor copies) | external_size({ssl,sockets})<=1048576; bounded_term depth16; accepted binaries copied; origin host<=253. Request traversal max65536 nodes/depth32. | POLICY_HEAP: source/ABI/profile heap conversion and simultaneous trust/file/PEM/preparation copy multiplicities, including parsed TLS and setup overlap inside the declared accounting scope. Serialized policy cap is not heap bytes. |
| W03 Request/preparing/connection/idle populations (G*R requests and G*C member slots; R=1..2048,C=1..256) | Ingress fixed R ETS slots; pending=0; connecting+checked-out+idle included in connection slot; scope slots<=C. H2 pool max_keys=1/max_streams=R/max_total_connections=C. Idle timeout1..60000ms does not refund live holds. | POPULATION_HEAP: per-slot/tracker/connector/owner/pool/ETS/monitor term/native costs and simultaneous release edges; NATIVE97 survives logical slot removal. Held connecting/preparing runtime states are not covered by default39. |
| W04 Prepared target, headers and trailers (G*R live request copies) | Managed effective fields+target<=65536 accounted bytes,<=256 fields; nil/PID body grammar for selected controlled profile; bounded trailer validation applies. | REQUEST_COPIES: enforce frozen H2 caller body/trailer/redirect/raw-stream grammar; bound concurrent prepared/header/wire/Fetch copies and structure via ABI. Do not import H1 copy lemmas as H2 proof. |
| W05 Raw TCP/TLS delivery, partial frame and concatenation (G*C plus overlapping received messages) | Native local max frame F=16384. Boundary rejects length>F after3 bytes. A :more carry has <F+9 logical bytes and is binary.copy compacted. Owner parses state.buffer<>delivery within callback and rearms active-once afterward. | INGRESS_ABI: maximum raw delivery backing for chosen TCP and OTP TLS options; raw message/caller/TLS delivery/tracking metadata, concat old/new overlap, kernel-vs-included boundaries and per-callback copies. active-once and DATA credit do not bound these allocations. |
| W06 Encoded header fragments and concatenation (G*C one current block per connection) | H=65536 logical encoded bytes;<=256 total HEADERS/CONTINUATION frames including empty; empty fragments omitted and nonempty compacted. Published conservative scratch:3*H encoded representations during fragment/reverse/concat overlap. | HEADER_REPR: convert finite fragment-list, frame/map/subbinary and scratch counts to actual heap/native bytes under certified runtime; callback and garbage root release must be enforced. |
| W07 Decoded HPACK blocks and Huffman transient (G*C one callback decoder, plus outstanding roots) | Decoded name+value bytes<=65536 and fields<=256; raw literal strings copied. Huffman bit list<=8*65536=524288 cells; output<=65536 one-byte binary entries; original+reverse lists, output binary and freshly constructed fixed decoding trie. | HPACK_HEAP: exact certified list/tuple/map/small-binary/subbinary/trie/recursion/GC overlap and release sizes; fixed trie size is source finite but no accepted runtime heap certificate. Published scratch count is not complete retained bytes. |
| W08 HPACK dynamic tables and outbound encoder (G*C decoder+encoder roots) | Native decoder4096 accounted bytes; entry_size=name+value+32 implies<=128 entries; reserve old/new4096 tables and insertion/eviction list overlap. Native encoder indexing=:literal,huffman=:never does not add dynamic entries, even when peer HEADER_TABLE_SIZE updates its scalar limit. | TABLE_HEAP: table tuples/lists/binary ownership and old/new root-release conversions; exact outbound header encoding scratch/structures still need source/profile conversion. Do not claim arbitrary peer-selected encoder table4096; current literal profile is the premise. |
| W09 Informational/final/trailer events after #86 (G*R lifetime recipients, not current protocol stream count) | Before enqueue:<=128 informational heads and<=65536 regular accounted bytes per stream lifetime; counters never replenish. Final/trailer each once;<=130 header events and<=33280 pairs. Published accounted-data expression65536+128*42+2*(65536+256*32)=218368 per request, for owner and recipient representations and separately Fetch representation. Terminal streams cannot renew header/upload-stop notices; rejected blocks still advance HPACK. | EVENT_HEAP_COPIES: actual term/structural bytes and simultaneous recipient/owner/Fetch copy/root multiplicity with release evidence. 32-byte field charge and218368 are accounting data conventions, not BEAM byte envelope; do not sum them into an activation constant. |
| W10 DATA credit, delivery queues and downstream copies (G*C receive allowance plus G*R deliveries) | Brecv=max(1048576,native connection_initial_window)=1048576. Return connection credit only while unacknowledged+receive_window fits Brecv; stream credit only after application consumption. Per-stream delivery queue<=128 entries; byte-stream coalescing begins at64; ordinary raw Fetch preserves ACK chain. | DATA_COPIES: exact owner events/subbinary backing/SocketClient/mailbox/HTTP.Stream/downstream copies and overlap until respective ACK; ingress W05 remains additional. Protocol bytes do not translate directly into physical residency. |
| W11 Upload bridge/source/pending writer pieces (G*R and owner stream roots) | Bridge<=65536 buffered source chunk, one inflight slice<=16384; credit clamped to buffer capacity; next source ACK after complete slice consumption. Owner pending_body one per stream, copies remaining piece on progress; EOF/trailer/stop messages finite per admitted request. | UPLOAD_COPIES: source backing under frozen nil/PID one-credit grammar, bridge/owner/sent-frame remainder overlap, term/ref costs and repeated monitor native frontier NATIVE97; external producer history excluded only by explicit declared scope. |
| W12 Synchronous writer batch and socket/TLS delivery (G*C writer plus G*R pending bodies) | Before transport_send, state.bytes+IO.iodata_length(frames)<=1048576; frozen finite send_timeout/send_timeout_close. Native profile max header/data fragment16384; bridge slices retain their credit discipline. | SEND_ABI: complete frame/iodata encode overlap, native TCP send queues/TLS caller and sender delivery metadata, ACK/ref lifetime and failed-send uncertainty. Synchronous send return or 1MiB batch cap is not a whole transport queue/reclamation receipt. |
| W13 SETTINGS/GOAWAY and per-stream protocol metadata (G*C plus G*R bounded stream records) | One unacknowledged capacity {token,snapshot} plus current desired/acknowledged state per connection; matching pool/token ACK only, stale ACK ignored; pool applies then ACKs, wire SETTINGS ACK continue. GOAWAY one draining update/connection and one nonterminal notice/surviving stream; decreasing cutoff terminates excluded streams once without new drain timer. Stream maps/ref/scheduler/header-phase state bounded by R; close_stream removes associated entries. | CONTROL_REPR: constant-size message/ref/map/queue representations and all-sender/native signal release. Repeated peer SETTINGS/PING/control frames can cause arbitrarily many sequential actions during idle lifetime; one logical in-flight snapshot does not certify reclaimed old controls. |
| W14 Timers, aliases, monitors, signals and deferred native reclamation (Active populations plus arbitrary request/chunk/idle histories) | Logical H2 idle/reservation timers are cancelled/replaced; owner SETTINGS/drain timers finite logical slots; scope repeats reconcile timer. Calls use aliases/monitors; Stream.chunk creates/demonitors a monitor every chunk; request completion can observe latch before tracker exit. Generation retirement waits coordinator DOWN but only proves named independently monitored termination. | NATIVE97: history-independent source/ABI/profile bound for native/deferred controls or supported acknowledged reclamation frontier; absent for H2 shared scope/lifecycle/Stream/TLS paths as for H1. cancel_timer, ACK, public send, demonitor flush, coordinator DOWN and zero snapshot individually do not establish it. |
| W15 Failed setup, idle and unconfirmed terminal holds (Existing charged G,C,R slots until proven applicable release) | OTP TLS independent receiver/sender tracking is installed. Missing returned TLS inventory/unsupported representation makes scope unconfirmed; request errors preserved. Retired generation cannot be credited by response terminal alone; unread parser-failed response keeps request lease until consumed/cancelled. | TLS_UNCERTAINTY: inventory/native delivery-tracking metadata on failed setup; complete per-held-resource bytes even after cleanup_unconfirmed; qualified lifetime/profile enforcement. Fail closed retains ownership; it does not supply a numeric size. |

All expressions use the supported managed `:native_v1` profile, explicit H2/h2c,
raw streamed manual/error redirects, finite deadlines and a bounded caller grammar.
The full H2 caller/outer-generation grammar still needs registration and enforcement;
the H1 four-generation profile is not silently reused. Private TLS/crypto/kernel
heaps may be excluded only by an explicit accounting boundary; externally visible
TLS caller/delivery/tracking metadata and failed-setup uncertainty remain included.

## What #86 now establishes

The source admits informational metadata before notifying, with lifetime counters
that never renew on flush. SETTINGS has one tokenized in-flight snapshot and current
state; stale ACKs cannot renew it. GOAWAY sends its draining/notice effects once.
These old #86 gaps are fixed in the verified release and are not fresh blockers.
The guide's 218,368-byte header-event charge is accounted data, and its finite
Huffman/fragment scratch counts still need representation and release certificates.
The native encoder uses literal indexing, so peer HEADER_TABLE_SIZE does not make
its retained dynamic entries grow; that premise must stay frozen.

## Shared blocker and next upstream deliverable

H2 pool idle/reservation timers cancel and replace native timers; the scope repeats
reconciliation timers; H2 requests use the same tracked timed calls and repeated
`HTTP.Stream.chunk` monitor/demonitor path as H1. H2 TLS uses the same failed-setup
and independent receiver/sender tracking. Logical timer removal, demonitor flush,
DATA credit, public send return and a zero resource snapshot do not certify old
native expiry/signal/alias/reference-count/thread-progress reclamation.
Generation retirement additionally waits coordinator termination, which is useful
monitored termination evidence but does not supply the missing native frontier.

The next actionable upstream deliverable is the source/ABI/profile-bound envelope
or acknowledged reclamation operation requested by
[Feature #97](https://github.com/gsmlg-dev/http_fetch/issues/97), explicitly covering
native H2 repeated SETTINGS/PING/GOAWAY, idle/reservation timers, calls/stream monitors,
all-sender/native executors, TCP/OTP-TLS caller/delivery/tracking metadata and uncertain
setup. It must define charge/refund rules and fail closed on missing/mismatched
certificates, then ship in a coordinated release for independent qualification.
An H2 evidence supplement belongs with that prerequisite; another requester-side
partial lemma or private flush cannot resolve it. No issue mutation was made here.

## Independent functional work that can proceed

The unchanged default39 driver already supports verified TLS H2 and separate h2c:
exact 256-frame success and 257-frame rejection; held request/unread capacity;
GOAWAY followed by peer-observed PING ACK before rejection; draining occupancy,
healthy independent scope and replacement without replay; finite unequal/short
deadlines; graceful pending/late checkin, abort and creator-death cleanup. Its existing
finite peer also accepts repeated `drain_connection` commands, permitting a separately
bounded controller to check repeated GOAWAY without adding a private API. No new
controller or test was implemented or run by this audit.

The current unchanged peer grammar does not implement SETTINGS or informational
floods, Huffman peak/scratch accounting, raw ingress/copy peaks, truly stalled upload
credit, or held preparing/connecting saturation. Upstream source regressions cover
notification cases but use owner-level test interfaces; they are inspected evidence,
not requester public-API runtime qualification. Register a finite independent-peer
specification before expanding those executable cases. Do not claim default39 covers
them. Current default39 holds a response but sends a small finite body; it is not an
adversarial full receive-budget or slow-upload memory test.

Existing functional command, only after parent-owned compile/loaded-identity gates:

```sh
ERL_FLAGS='+S 2:2' MIX_ENV=test nix develop --offline --command unbuffer mix run --no-compile --no-start integration/http_fetch_contract/managed_transport_probe.exs
```

Preserve all original errors, finite deadlines, independent-peer joins and receipt
assertions. Functional PASS would still leave the numerical Task3 worksheet,
production Task4–8, managed soaks and M4 gated. Audit status DONE; numerical H2 gate
BLOCKED. Sol repair rounds 0; parent/Astra counters unchanged. All own commands finished.
