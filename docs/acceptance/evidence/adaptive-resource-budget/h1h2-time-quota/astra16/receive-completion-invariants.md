# H1/H2 funded completion and receive ownership

Task ARB-H1H2; recovery on main bc8a5ef. This note accompanies source and tests,
not independent acceptance. TLS limits are unchanged; no TLS single-record
assumption or private transport APIs are introduced.

## H2 connection total

For actual retained representation R, funded startup floor F, independent receive
floor Q, and current pre-decode peak P, total = max(F, R + Q) + P.
Temporary = total - R, hence temporary >= Q + P. The completed decode drops P;
there is no decoder high-water retained for an idle connection. Repartition is
used only inside the already-accounted total. Increasing total uses checked
admission, including while draining. The drain regression sends actual partial
frame carry, verifies unchanged F and Q, then requests a larger total from the
authenticated connection and requires :draining.

Existing connection reservation is split into 2*max_buffer completion credit and
Q = 2*max_buffer + 8*delivery. No copy coefficient is reduced. Completion credit
is distinct from Q and cannot consume it. TCP delivery uses max(16384, public effective buffer), so a smaller driver
readback cannot underfund complete receive-window copies. It comes from public
Hell.Socket.getopts([:buffer]) after the successful setopts; the supported inet
raw active-once driver returns the requested 16384-byte buffer. TLS keeps the
prior 100*16384+18437 delivery profile, including record aggregation. A lower TLS
profile has not been claimed or qualified.

Retained old carry/input is charged as R. Receive peak Q covers the incoming
active-once delivery and parser carry concatenation/detachment while the previous
state remains live. The native connection receive window is at most65535; at the
16384-byte TCP profile, 8*delivery is131072, exceeding two complete receive-window
copies. This covers input concatenation plus the disjoint delivered/rest copy
when an existing input is partitioned. The separate 2*max_buffer term preserves
parser concatenation and detached carry. Existing output/writer and per-worker
startup reservations stay independent. Decoder/Huffman expansion always uses P
before decoding. This is a logical allocation-overlap argument; VM allocator
fragmentation and garbage-collection delay remain covered by the separate VM
safety guard, not claimed as exact RSS measurement.

Stored parser rest, HEADERS continuation blocks, stream input, and delivery/rest
slices are detached whenever referenced_byte_size exceeds visible size. Delivered
wire ownership stays charged through acknowledgment/retirement; queued wire and
delivered wire remain bounded by native flow control. HPACK dependency already
detaches retained literal table entries. Bounded ordinary tests exercise parser
turn=1, fragmented DATA, extension frames, HEADERS continuation, held worker
slices, and actual public buffer readback. No specialist pressure/soak work added.

## Completion and close

Exchange records original total, reusable temporary credit and exact memberships.
Actual retained data is repartitioned inside the funded total; larger obligations
still require admission. H2 subtracts only stream completion credit from its
protocol_bytes, leaving startup/dispatch terms retained. The phase-receipt spawn
path requires the exact original OTP response alias plus the exact token.

WebSocket completion prepays two maximum server control frames (2*(125+2)=254)
and fixes its transport total across staging/release. WebSocket application
bytes remain independently classified and are never converted into transport
credit when released. Paid bounds update at callback commit and after each output
pop; known growth uses checked update directly instead of speculative rejected
repartition probes. Actual app/decoder ownership remains
classified; steady-state changes are checked. Unfunded legacy/H3 paths preserve
their API shape and callback timing.

H2 local_closed alone denotes queued FIN and is not completion proof. During
close only an original matching final-writer receipt can clear the successful
write slot. Such workers may finish their Admission commits before parent exit,
using one shared absolute deadline capped by existing cleanup, drain and request
bounds. All other workers cancel immediately. Before proving independent output
resources terminal, close stops the writer and observes its actual DOWN; then it
drops parent stream/carry/output references and submits existing authenticated
end_stream/finish_stream_resources proofs. Admission independently requires child
DOWN+EXIT and canonical budget commit. No refund follows DOWN alone. No new
GOAWAY ordering, detached cleanup child or per-worker deadline extension exists.
If the writer does not terminate by the original deadline, no output proof is
submitted. Forced stragglers retain their killed/failure disposition.
