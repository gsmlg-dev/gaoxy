# G1 independent-review budget correction

Independent whole-Connection review found that Options accepted an output budget
which could never provide a complete read quantum plus the Connection's 32-byte
framing reservation. With default `max_read_chunk = 16384`, accepted
`max_pending_output = 16384` yielded credit 16352, so the callback never read any
request. A shared HTTP limit of `max_read_chunk = 65536` produced the same problem
with the H3 maximum output budget. Default live fixtures had not exercised these
accepted option combinations. This is a Gaoxy configuration defect, not an
upstream defect.

The new regression first failed **9 tests / 1 failure**, exit2, because the first
underfunded configuration was accepted. The correction adds one activation-time
cross-budget check before endpoint initialization. The regression rejects both
underfunded configurations and accepts the exact 16416-byte boundary with a
single endpoint initialization. No existing assertion or protocol error code is
changed.

`execution.json` records authored-file formatting, strict compilation and all
affected scoped suites **78 tests / 0 failures**, with commands, source and log
hashes. Independent resolution review and post-review full G1 verification are
recorded separately; this unit result is not a substitute for the live gate.
Options cumulative counters are **Sol4 / unsuccessful1 / Astra0**. Connection
counters remain **Sol2 / unsuccessful2 / Astra1 / unsuccessful0**; the Options
compatibility repair does not erase or restart the Connection recovery chain.
