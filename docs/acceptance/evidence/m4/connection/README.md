# Task2 Connection evidence

Direct `/root/m4_spec_review` implementation in `.trees/m4-http3` on
`codex/m4-http3`. The worktree began at `78de9d0`; parent owns slice commits.
Root and consumer locks remain unchanged by this Connection worker.

Unit gate: **10 tests, 0 failures**, warnings-as-errors compilation and formatting
of the three owned Elixir files passed in the locked Nix test environment.
Live wire acceptance and independent review are **PENDING**; unit state-transition
success does not establish real HTTP/3 acceptance. The peer author owns fresh G1
runner evidence and independent code review.

`red.log` preserves 8 expected missing-module failures. `initial.log` passed 8
unit cases and exposed an unused-key compiler warning. `local-control-red.log`
preserves the 9-test/1-failure intended regression for treating the late local
control stream as peer-owned. `live-red.log` plus `../minimal-red/run-*/` preserve
the initial real-peer failure: public QUIC interpreted an absolute monotonic
value as a relative timeout, rejecting local control open with
`:deadline_expired` and connection code `0x102`. No peer cases passed this run.
All owned peer/build commands finished and the runner stopped its children.

Repair1 covers reviewed relative deadline conversion with the original absolute
uncertain-operation deadline retained; definite-blocked write chunk reduction;
late local-control event isolation; input fencing while write admission is
uncertain; a fixed incomplete-work deadline for uni type/frame/QPACK parsing
while preserving open idle critical streams; and the unused-key warning.
`repair1-units.log` records the fresh unit/build gate. Exact public
`operation_status/2` map/result semantics were checked in installed source.
Uncertain references are polled, never replayed or resized. A controlled unknown
operation injection remains NOT RUN; ordinary live blocked/admitted receipts
are checked by the independent fixture.

Cumulative Task2 counters: **Sol repairs 2; unsuccessful 1; Astra 0**, pending
live validation. Historical Task1/G0 and stage counters are not reset.
No assertion was weakened, dependencies patched, production endpoint executed,
commit made or publication performed by this worker.

Repair1 wire validation failed after 3 observed PASS cases (control, GET,
concurrency): the 311,296-byte streaming echo did not finish by the unchanged
10-second peer deadline. `../minimal/run-1791780283838403213/` preserves that run
and all exited-child receipts. The original runner incorrectly counted zero
checks after mode failure; the three raw PASS lines remain preserved, and its
independent author corrected later summaries without rewriting historical logs.
Definitive blocks could shrink writes to one byte permanently, causing request
expiry despite newly available credit.

Repair2 grows the chunk quantum after definite admission while preserving
unknown-operation freezing. It also normalizes the public opaque open-status
result through Gaoxy.Stream, fences request I/O while local control setup remains
pending, removes any early local stream entry after status resolution, and bounds
response owners separately from receive-side parser slots. The last bound's
intended red is `response-limit-red.log` (10 tests, 1 failure); the fresh unit/build
gate is `repair2-units.log` (10 tests, 0 failures). Independent fresh wire validation
and code review remain pending. No third Sol repair is authorized by this worker's
assignment if this second round fails.

Repair2 full live validation **FAIL**. `../minimal/run-1791780656197652152/`
records **31 observed PASS checks**, including one blocked-admission telemetry receipt and 311,296 echoed bytes under tiny
receive windows, trailers, HEAD, CONNECT501, requests before peer SETTINGS,
independent static/Huffman fields, critical stream/frame/QPACK failures and the
5,137-ms incomplete-discard close within its 6,000-ms bound. The next malformed
case, duplicate pseudo-header request, timed out waiting for **both RESET and
STOP code0x10e** on that stream. Cancellation and listener shutdown modes were
**NOT RUN**, not passing. The runner receipt confirms all owned children exited.

Final disposition **ESCALATE_TO_ASTRA**, `astra_gate=SOL_REPEATED_FAILURE`;
Sol repairs **2**, unsuccessful **2**, Astra recovery **0**. All assertions,
peer deadlines and raw failures are preserved. No further source edits by this
worker. Parent owns gate validation, routing and bounded recovery handoff.
