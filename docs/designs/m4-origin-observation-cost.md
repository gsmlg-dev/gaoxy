# M4 independent origin observation cost

Coordinator repair2 still failed37/50 with750223 exact response bytes and
incomplete response. Its tiny-request local teardown is confirmed by explicit
public stop, normal endpoint/stop-task/bootstrap/caller/guardian DOWN and UDP
rebind. The abort Session outcome remains unknown and Service completion is
explicitly NOT CLAIMED. Earlier missing cleanup receipts remain historical.
The direct-chain counters remain
Sol2failed2/Astra2failed2; both coordinator repairs are unsuccessful. No third
Astra recovery is authorized. This is coordinator local repair3.

The independent peer audit measured the existing snapshot algorithm against
repair2's627 real DATA events: copying and hashing cumulative bodies processes
337047994 bytes for the1048576-byte payload. Five same-interpreter measurements
cost1250–1455ms (median1352ms); adding the existing JSON work costs1388ms median.
Incremental hashing plus identical JSON costs11ms median. These synchronous
callbacks block aioquic's event loop inside the original five-second request
deadline. They are a demonstrated fixture cost, not an upstream API defect or
proof of the sole runtime cause.

Keep the complete request body for actual echo and independent full-body
assertions. Initialize a separate SHA256 accumulator at initial request HEADERS,
update it with each original DataReceived.data exactly once, and use its digest
in snapshot. Snapshot continues to report the same complete cumulative byte
count, hash, ordered fields/trailers, request count and FIN. Do not coalesce,
drop or delay any original wire observation. No transport/window/deadline,
Session, payload or cleanup contract changes.

Before live execution, compare all627 captured original cumulative byte/hash
observations with the new incremental path and an independent full-body SHA256
reference, including empty and final body. Keep the original FAIL evidence
immutable. This differential check and AST validation are static proof only;
the complete50-row gate, independent review and fresh repeat remain mandatory.

Follow [the task delta](../plans/m4-origin-observation-cost.md).
