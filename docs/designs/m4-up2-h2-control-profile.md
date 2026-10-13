# M4 UP2 H2 control-rate qualification profile

Repair6 removes the early initial-window reset: the original 1 MiB H2 request
now reaches the independent H3 origin with its full body and one FIN. Its echo
still closes before completion. The unchanged diagnostic run records actual
GOAWAY error11 (`ENHANCE_YOUR_CALM`), last-stream1, after304,162 response bytes.
This is the existing native control-frame rate policy, not raw-delivery overflow
or an upstream client failure. Preserve the FAIL and counters: thirteen
unsuccessful live executions, five failed production repairs and one repair5
harness failure. No third Astra recovery is authorized.

The independent H2 peer advertises a 2 KiB response stream window and returns
credit at roughly half that window. A 1 MiB echo thus needs about1,024 stream
WINDOW_UPDATEs, plus connection credit/settings/other controls, within the
existing five-second row deadline. The fixture currently selects the default
256-controls/second flood policy, which can reject a burst of those valid credit
frames. This policy is intentional and remains the production default.

Qualify this explicit tiny-window workload with the existing supported
`h2_limits.control_rate: 2_048` profile on both H2 fixture listeners. It remains
finite and below the qualified4,096 ceiling. Retain the origin16KiB and peer2KiB
windows, native receive16KiB, original frame/carry/body limits, worker/service
budgets, parser32-frame turn, five-second I/O deadlines, exact1MiB hash/bytes,
one FIN, all error/cancellation/sibling/zero-baseline assertions and66+2 rows.
The existing queue guard remains finite under this selected limit; the existing
16MiB connection bookkeeping reserve covers its bounded control records. Do not
change native defaults, rate counting, flood rejection or enable a new feature.
Document the selected profile in the matrix README and recorded fixture metadata;
do not describe its pass as proof of1MiB burst throughput under the default256.

Add real h2c regressions for the production default256 and selected2,048 limits.
PING ACK barriers prove that valid connection WINDOW_UPDATEs through the exact
allowance are processed. The next valid WINDOW_UPDATE must yield GOAWAY11,
followed by bounded zero admission/retained/cleanup state and TCP rebind. This
additional existing-policy coverage must pass without production changes.
Retain the new peer GOAWAY diagnostic and all original response oracles.
Independently review the design and profile/test source, then rerun the entire
matrix and review its actual result before the required full repeat.
