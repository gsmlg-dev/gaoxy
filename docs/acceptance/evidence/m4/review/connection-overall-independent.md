# Independent overall G1 Connection review

Reviewer `/root/m4_connection_integration`, 2026-10-12. Task
`m4_task2_connection_overall_review`, direct independent Sol review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m4-http3`, branch `codex/m4-http3`,
HEAD `2b4a5e58bf3044baf289c266b96ee9a979f61309`; original M4 baseline
`78de9d0f3bba5a4662717359438eb3d0853a79b4`. This reviewer authored none of the
runtime source, Connection tests or peer contract repair under review. Runtime
source remained read-only; parent owns the source/Mix lease and fresh G1 run.
Only this receipt was written. No commit, publication or deployment occurred.

## Specification verdict: FAIL — one accepted-budget consistency defect

The whole Connection implementation, both owned unit suites, pure Protocol
interface, Options credit/reservation contract, Task 2 design/plan, recovery
handoff, Astra1 receipts, prior delta-only review, independent peer/runner and
raw acceptance evidence were reviewed. The recorded default fixture proves the
bounded G1 profile, but the accepted service limits permit a request-read
deadlock. Resolve finding G1-1 before overall acceptance or G2 progression.

### G1-1 — reject or support pending output below the required read reservation

Priority **P1**, `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex:241-245`;
configuration compatibility is in
`apps/gaoxy_http3/lib/gaoxy/http/http3/options.ex:182-194`.

`Options.normalize/1` accepts `h3_limits: %{max_pending_output: 16_384}` with
default `http_limits.max_read_chunk = 16_384`: the pending-output value is a
positive value below the advertised maximum, and reducing it only reduces the
aggregate reservation required by `budget/2`. All default service ceilings
remain sufficient. Yet a fresh bidi owner with `out = <<>>` has
`credit = 16_384 - 0 - 32 = 16_352`, below `max_read_chunk`, so
`receive_stream/2` returns without running even the empty Protocol continuation
or `QUIC.read/3`. No response can free further credit because request HEADERS
were never read. GET and POST therefore wait until request/header timeout and
are canceled instead of making progress. This is determined directly by the
accepted option predicates and unconditional read guard; no dependency behavior
is involved. No runtime reproduction was run by this reviewer while parent held
the Mix lease.

The same invariant also fails for an accepted `http_limits.max_read_chunk =
65_536` and default pending output, despite public `Gaoxy.QUIC.read/3` already
limiting actual read consumption to 16 KiB. The guard compares the configured
value rather than that effective quantum.

Make the minimum compatibility repair: either reject these inconsistent
reservations before endpoint initialization/service activation, or use a
bounded effective read/continuation quantum compatible with the available
output credit. Retain framing allowance, output ceiling, uncertain-write fence,
finite timeouts and protocol continuation/FIN ordering. Add a regression proving
rejection before activation, or actual ordinary/streaming progress under the
supported reduced budget; do not merely increase the fixture defaults. Existing
Options tests cover upper bounds and aggregate service capacity, but not this
cross-limit requirement. Existing G1 unit/live cases use the larger default
pending-output budget and therefore cannot expose it.

## Code-quality verdict: FAIL — G1-1; no other actionable finding

For the default fixture the architecture and implementation remain appropriately
bounded. The owner performs no Endpoint/Plug callback and admits only the named
minimal fixture. Authenticated `h3` readiness gates all application I/O. Local
control open/send state is explicit and raw status handles are wrapped using
the public facade; provisional and late local-open events are separated from
peer parsers. Public Protocol transitions retain the control prefix and exact
stream/connection error scopes.

Round-robin queue turns, bounded parser transitions/bytes, the callback turn
deadline and reserved local control progression prevent an ordinary blocked
request from monopolizing the callback. Bidi owner counts remain bounded after
receive FIN removes a pure parser. Unknown uni streams are stopped with bounded
state, incomplete uni work keeps an absolute deadline, and completed idle
critical streams clear that work deadline. Output is capped independently from
ingress. Definite blocked writes shrink their chunks and admitted writes restore
the quantum; receipts are admission, not delivery.

Pending operations retain their original reference/deadline and resolve through
public `operation_status/2`, without blind replay. Uncertain writes freeze the
corresponding destructive read/continuation path. Receive FIN is deferred until
credited empty-feed continuations stop changing parser state. Cancellation drops
queued output, preserves the first terminal code and remaining RESET/STOP tail,
and retains uncertain cleanup references/deadlines on reflexive peer events.
The focused whole-state regressions also retain sibling ownership. Connection
failure and clear/drop paths stay scoped to the current owner; host shutdown
performs process/socket/Admission cleanup.

The sole actionable quality issue is the missing agreement between accepted
configuration and the minimum credit assumed by that read/continuation guard.
No dependency patch, private API workaround, reorder, or upstream accusation is
justified by this review.

## Reviewed evidence and exact source identity

Fresh read-only verification compared every one of the **65** source hashes in
`connection/astra1/minimal/run-1791781594720455934/summary.json` against the
checkout: **zero mismatches**. The **44** raw peer PASS events match their summary
entries exactly, plus three fixture/runner observations for **47 recorded PASS
checks**. All five recorded children exited 0. These are independently inspected
existing execution receipts; this reviewer did not rerun Mix/network gates.
Parent must run fresh affected verification after fixing G1-1 and after review.

The Astra1 commands/units/raw logs record **12 tests / 0 failures**, expected
regression red **12 tests / 2 failures**, exact-file format-check exit 0 and
warnings-as-errors compile exit 0. The default real-peer run includes 311296
echoed bytes under 2048/4096-byte windows, progress before upload FIN, definite
blocked telemetry followed by admission/progress, ordered trailers, HEAD and
CONNECT501, request-before-SETTINGS, static/Huffman decoding, exact malformed
control/QPACK/stream codes, critical reset/FIN, stream/sibling isolation, zero
DATA growth after reset, incomplete-extension closure in 5127 ms within 6000 ms,
listener removal/Admission DOWN/port rebind, established sibling exchange and
bounded runtime stop with port/gate cleanup.

The separate unchanged-server diagnostic observed wire RESET_STREAM and
STOP_SENDING **0x10e** for both FIN/open requests. For FIN, aioquic suppressed the
STOP application callback through the original ten-second deadline; for open
send direction both exact callbacks arrived in 28 ms. The peer contract repair
therefore keeps FIN RESET assertions and five open-direction exact RESET+STOP
cases, preserving finite deadlines, sibling continuation and no-late-DATA
assertions. Underflow retains FIN. Original historical failures remain intact.
Restoring the disproven FIN STOP-callback requirement would be invalid.

SHA-256 review inputs:

| Path | SHA-256 |
| --- | --- |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex` | `81b1d2081aaeb363120d6c68f1a00ab95f4ee54dac8406ba59b8ef104d851008` |
| `apps/gaoxy_http3/test/connection_test.exs` | `63e110336373501259a4b3b2f1ae35a508b0164094bbe969cd78fb1cc647361b` |
| `apps/gaoxy_http3/test/lifecycle_test.exs` | `290d85e877f43c9a1c6f9b36bdb2128e20e5ed714a87ceb498895de5f154422c` |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/protocol.ex` | `0e7c588075ebccb16e6d3d6dde32c0ad2cb8a65dc04a4010e6d0fbdffcb9194f` |
| `apps/gaoxy_http3/lib/gaoxy/http/http3/options.ex` | `8c9d17c955373b16e12011fa2762e5fb7c1edc76ba564111e4ae625b0b826e0d` |
| `integration/http3/fixture.exs` | `262f5279b4792f63b8655f5a83f9332ebaa041794112e396bad97b5fc9543ce2` |
| `integration/http3/peer.py` | `5176df26f8cbf9bcf375203cc555494d6c48f9952f67a1f98bddf0170af705f7` |
| `integration/http3/run.py` | `c0233119ee4956c71bf289c4f412cc490d8481c337fbc3ecd4e637d1ea588c07` |
| `docs/designs/m4-http3.md` | `281f2eabeca29d7928e7c1afb61bf369d1aa3ae8bca070e7923f175d14bae876` |
| `docs/plans/m4-http3.md` | `0313ec847c1de403ecfd956fe6d16558acb75c0cbe39a8c622de9f7f2135d0d0` |
| `mix.lock` | `16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25` |
| `flake.lock` | `ab9cba40e49dca0023bfd18bff4df80e5470abb70ee2acd64f8419ffb8a19459` |

Controlled live unknown-operation injection remains **NOT RUN**; deterministic
map/ref/deadline preservation is separate from real fault injection. Arbitrary
Endpoint/Plug and worker ETS/lease cleanup are G2, not implemented/qualified by
G1. Browser/proxy/upstream/standalone, hosted CI, publication, deployment and
production acceptance remain separate. No dismissed issue97 proof is required.

Cumulative implementation recovery counters remain **Sol2 / unsuccessful2 /
Astra1 / unsuccessful0**. This read-only review adds no repair round and requests
no architectural redesign. All reviewer commands completed; no running command
or runtime source lease is retained. Parent owns the necessary targeted repair,
fresh verification and review closure. No product decision or external permission
is required for G1-1.
