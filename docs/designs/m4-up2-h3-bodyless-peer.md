# M4 independent H3 bodyless-response peer

Repair7 passes all44 H1/H2 network rows and H3 GET before HEAD fails in the
independent peer. The native HEAD endpoint returns `:sent/ok`, with normal owner
and guardian DOWN, while the origin records HEAD, zero request bytes, one request
FIN and response FIN. The diagnostic execution records the peer's actual
H3_MESSAGE_ERROR270 and reason `content-length does not match data size`.
Preserve both FAIL47 records and cumulative fifteen unsuccessful live executions,
five failed production repairs and two failed harness repairs. No third Astra
recovery is authorized.

aioquic1.2.0's generic H3Connection response validator stores Content-Length and
compares it to DATA bytes at FIN without tracking HEAD or304 semantics. A legal
metadata length7 with zero response DATA is therefore rejected before it yields
the HEADERS event. Gaoxy must preserve that metadata and bodyless FIN; changing
native headers or supplying dummy DATA would be incorrect.

Reuse the already qualified `integration/http3/peer.py` raw-response convention
only for UP2 H3 HEAD and304 rows. Retain aioquic's public QUIC transport and
H3Connection's control streams/request encoding; decode only those response bidi
streams independently using public varint Buffer and pylsqpack.Decoder(0,0).
Ordinary rows retain standard H3Connection response validation. Do not patch
dependency code, override private validators or inspect SDK state.

The bounded raw decoder assembles split type/length varints and payloads, limits
frame/carry bytes, decodes literal/static QPACK and rejects dynamic references.
FIN must leave no partial frame. Record original HEADERS, response DATA bytes and
actual FIN in the same response structure. Preserve all original66+2 rows,
two-KiB windows, five-second deadline, body/hash/header-count/duplicate/trailer
assertions and endpoint/guardian/cleanup barriers. Add exact Content-Length7
metadata assertions for HEAD/304 and absence for204 across protocols. The raw
bodyless parser must reject any DATA frame and still require the original actual
FIN. This is stronger independent wire validation, not synthetic success.

Record the selected response-decoder profile in each completed bodyless row and
describe its scope in the matrix README. Independently review design/code and
actual complete matrix evidence, then fresh-repeat the entire matrix before final
M4 verification and conditional release. Production sources remain unchanged.
