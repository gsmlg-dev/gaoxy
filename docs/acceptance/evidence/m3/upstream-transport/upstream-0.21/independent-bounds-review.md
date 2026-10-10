# Independent installed-source bounds review

Task: Task3 independent bounds/spec confirmation. Direct Sol review; source
inspection only. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`,
branch `codex/m3-gateway`, HEAD `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Only this report is owned by this reviewer. The reviewer previously authored
the managed probe; **this is not an independent review of that probe**.
No Mix, fixture, installation, private process inspection, upstream mutation
or commit ran. Other writers' source, documentation and dependency changes
were preserved.

## Verdict

**CONFIRMED: the worksheet identifies real missing hard accounting proofs for
peer-driven H2 header events and SETTINGS pool notifications in installed
0.21.0.** No indirect native writer/receive admission bound covers those
outstanding events. This blocks approving a complete H2 retained-byte
reservation and dependent H2 activation. It does not establish a measured
runtime leak, vulnerability, peak allocation or failed runtime test.

**H1 can proceed through a separate narrow qualification path.** The intended
Gaoxy PID-or-nil upload and bounded binary/ACK contract removes the public
buffered-iodata structure concern from that slice. Explicit frozen 8192-byte
receive buffers preserve the existing profile's numerical premises; default
managed 65536-byte buffers do not. H1 is **NOT YET QUALIFIED**: the worksheet's
261,199,114-byte subtotal still needs the named copy/metadata terms and exact
installed transport/host qualification. No invented constant or zero charge
may complete that formula. H2-specific failures need not block H1 work, while
full M3 acceptance remains gated on its entire prescribed matrix.

The root API/lifecycle mapping remains consistent with the already accepted
facade audit. Its accounting prose needs the current-release clarifications
listed below; this review does not repeat or reopen the full API audit.

## Installed bytes and reviewed artifacts

The lock names all seven coordinated packages at **0.21.0**. Parent supplied
containing tag `9813c126dc8b48055b9ee941c693fc27fa691489` and successful Release
38067971805; this reviewer did not perform publication qualification.

Compared every selected worksheet source hash with installed `deps/` bytes:
23/24 PR81-head rows match; the known `http_fetch/lib/http.ex` difference matches
the worksheet's supplemental containing-tag hash. Both supplemental tag rows
match installed bytes (Fetch and RequestCompletion). Thus **25 matching rows,
one explained older-ref difference**, across 25 unique source paths. The
changed Fetch line322 calls `RequestCompletion.new(options, request)`; the
managed direct-route constraints preserve the reviewed accounting path.

Important exact installed hashes:

| Installed path | SHA-256 |
| --- | --- |
| `deps/http_runtime/lib/http/http2/connection_owner.ex` | `18bb290088ebbfd8b56d141f45210f7055081deecbd01ab55edf47dc580d8857` |
| `deps/http_runtime/lib/http/http2/pool.ex` | `ff733ac8765233d817b8a951b617eb0af0099b79ffd02b66c4eca6772bb697b7` |
| `deps/http_fetch/lib/http/socket_client.ex` | `1b6b494264c8eb8620471bdb7b80910cd31db67e951d3f24e14e9cefecb4a3e7` |
| `deps/http_runtime/lib/http/managed_transport/policy.ex` | `d2164cc922893b9cb626b3886d1fbdc1c4f479f1253446277120df6720df1279` |
| `deps/http_fetch/lib/http.ex` | `b86d8cc723cbab453e04dee8cf2a8bd99ca5a08d638c07a1d677ef501a495f7b` |

Review inputs at the recorded snapshot:

- `../retained-bounds-source.md` SHA-256
  `1e2a4b0e7ad6a56d84b7001a321f63ae0bf7bd8b6ef39559ea1f41b692c71f79`.
- `docs/designs/m3-upstream-transport.md` SHA-256
  `56cb66605bbe3b274aac8d93a79049faf537dce6caae64097dbf833132055ab3`.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex` SHA-256
  `19e8485079568684bc83b6080f7831418fef93d6d43a368e03e01e1d6601efdc`.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` SHA-256
  `6650ed1169c8284be4e87a08341a747c475994f2bce6194eda48867c2e158615`.

The worksheet's writer updated its containing-tag provenance during review;
the final source comparison above uses that updated snapshot. Subsequent
documentation repairs are separately owned and do not change the installed
source evidence cited here.

## H2 header events: confirmed missing aggregate admission

Installed `connection_owner.ex:747–763` appends a complete transport delivery
to parser carry and recursively parses its frames before flushing accumulated
`response_events`. `decode_headers/4:1200–1219` adds each successfully decoded
header event. `notify_stream/3:1545–1549` sends it to the Fetch request worker
without an acknowledgment or outstanding-event charge.

Installed `stream_state.ex:188–198` accepts repeated informational headers by
returning the unchanged stream and `:informational`. Its stream/header-phase
state does not count those responses. The 256-frame cap is **per header block**;
a legal END_HEADERS on every block starts a fresh block and does not exhaust
that cap. HPACK's per-block decoded bytes/field bounds likewise do not limit
the number of admitted blocks awaiting notification or consumption.

Fetch's `socket_client.ex:1039–1050` eventually limits informational responses
to128 and serialized informational metadata to65536. Those checks run after
the owner has decoded and queued/sent the events. Cancellation can stop future
work, but is not an admission barrier while the owner is parsing its current
delivery, nor a source-defined maximum on previously sent messages.

The DATA delivery count at Owner1123–1133 and receive-credit accounting at
1170–1198 concern DATA wire bytes/deliveries. Headers never enter that ledger.
Native HPACK/wire settings do not add an aggregate header-event ledger. A
qualified transport-delivery ceiling could bound one parse batch, but cannot
alone charge notification backlog retained from earlier deliveries. No hard
outstanding header-event count/byte allowance or consumer-credit protocol was
found on the actual Fetch path.

## H2 SETTINGS casts: confirmed missing outstanding notification bound

Empty non-ACK SETTINGS is valid: `settings.ex:49–50` decodes its zero-length
payload, and `Settings.apply_peer/2:57–68` accepts it. Owner853–885 applies each
peer SETTINGS, writes its ACK, then unconditionally calls `report_capacity/1`.
Owner1711–1725 casts `{:owner_settings, ...}` to the private pool once
`peer_settings?` is true. Pool337–345 consumes those casts individually.

The pool's finite connection/request/pending-reservation state bounds its
retained maps and admission queue, **not the mailbox awaiting those handlers**.
`max_pending: 0` does not reject peer-generated casts. There is no unchanged-
settings suppression, coalescing, outstanding count/bytes or acknowledgment
from the pool before the owner can parse/rearm again. The local outbound
SETTINGS pending limit in `Settings.begin_local/2:74–88` does not apply to this
peer-input path.

Owner667–685 checks one synchronous write batch against `max_queue_bytes`.
`state.bytes` initializes to0 at106 and is not increased before the write;
successful send only subtracts. Each SETTINGS ACK is9 bytes, and a peer can
drain those ACKs. Neither that writer check nor TCP backpressure supplies a
hard allowance for still-unconsumed pool messages. Active-once rearm at
Owner299–306/1510–1525 limits transport event admission; it does not wait for
the pool. Request timeout, scheduler fairness and observed steady consumption
are not source-derived retained-event constants.

## Buffered iodata and H1 profile classification

The upstream public concern is source-confirmed. FetchOptions278 returns the
original body; Fetch286–298 stores it in the request, then passes that request
to managed preparation at308 and captures it in the task at339–364. Policy
162–164 bounds ordinary body payload with `IO.iodata_length`, not original list
cell count/depth. A finite but arbitrarily long list of empty binaries can pass
with zero payload while retaining its list structure before wire normalization
at `Request.to_body/1:253–254`. This is not a claim that task copies are wholly
independent or a measurement of their heap cost.

That input is unreachable in the intended Gaoxy path:
`HTTPFetchClient.open/1:36–45` creates nil or an owned upload PID and passes that
at53. `Proxy.HTTP.read_upload/2:270–285` requests a bounded chunk and performs a
synchronous write. `HTTP.Stream.chunk/3:84–99` accepts only binaries and waits
for ACK; H1 Upload138–155 caps the chunk at65536 and ACKs after transport send.
Preserve those exact constraints when integrating managed transport. No broader
upstream buffered-iodata claim is approved by this exclusion.

H1 uses a separate parser/owner/pool. HTTP1:221–222 discards informational
heads without H2 fanout. SocketClient1384–1435/1469–1473 handles streamed body
delivery synchronously before active-once rearm1517–1522. H1 Pool108–126 arms
one idle event, then180–203 discards the socket on a matching event. Connecting,
checked-out, idle and preparing sockets remain charged through confirmed
retirement; request completion cannot refund the idle transport charge.

The existing Gaoxy constants are `D = 100*8192+18437 = 837637` and framing
carry65536. Existing `reservation/3` is eight such windows, eight upload chunks
and duplicated serialized request metadata. Policy261–271 permits explicit
8192 socket options but defaults all three buffers to65536. TCP.connect and
SSL.connect_cancellable pass the frozen options to the real transports.
The proposed narrowed H1 profile should explicitly freeze buffer/recbuf/sndbuf
8192 and retain the existing `:inet`/SSL `internal_active_n`1..100 host premise;
this review did not remeasure or independently rederive OTP's18437/100 premise.

Both worksheet subtotals independently recompute exactly:
H1 C2/R32/P0 =261199114; H2 C2/R32/P0 =52207632. Neither is a complete retained
allocation bound. Serialized-term, payload, HPACK charge and BEAM allocation
units must remain distinct. H1 can qualify independently after delivery-profile,
header/target serialization, policy/response/upload copy overlap and chosen
metadata coverage/exclusions are resolved, then its public lifecycle cases run.
The H2 event gaps do not logically add a term to this H1 parser. Full M3 must
still keep H2, h2c and its other acceptance requirements visible and unpassed.

## Actionable worksheet/design clarifications

1. Keep both H2 event terms unresolved and route the missing supported hard
   aggregate admission/accounting contract as an upstream **blocker for H2
   activation**. The source suffices to describe the missing proof; do not title
   or report it as a measured leak. No wrapper timeout/constant compensates.
2. Root design accounting451 currently calls the1MiB writer check a send queue;
   describe a synchronous batch limit and keep notification/control backlog
   separate, as the worksheet does.
3. Root design accounting485–495 still states the old empty-CONTINUATION cons
   gap and missing managed facade as present. Mark that explanation historical:
   installed0.21 contains the frame256 cap and skips empty fragment cells.
   Preserve the remaining event-accounting gates instead of declaring complete
   retained bounds from those fixes.
4. Worksheet's general8192 H1 line-limit wording needs precision. HTTP1
   `read_line/1:394–406` checks8192 only while no CRLF is present; its completed
   line branch does not enforce that number. A completed chunk-size line can
   exceed8192 within one admitted delivery. Charge its transient to qualified
   delivery+carry, and do not use8192 as a universal completed-line ceiling.
   This is not a newly unbounded H1 backlog under a qualified delivery profile.

## Minimal finite public-peer follow-up — NOT RUN

Use published0.21, separate verified TLS H2 and h2c runs, scope limits C1/R2/P0,
finite request/control/readiness/shutdown deadlines and original completions.
An independent scope holds or completes a healthy sibling to verify isolation.
Public snapshots and completion/retirement outcomes never certify mailbox size.

- Headers: open one admitted request. Send128 legal103 blocks as a positive
  boundary, then separate fresh cases with129 and4096 blocks. Each is an
  END_HEADERS, non-END_STREAM HEADERS carrying HPACK `08 03 31 30 33`
  (`:status: 103`), so each block is5 compressed bytes,14 wire bytes and well
  below every per-block limit. Compare coalesced writes and bounded successive
  batches, without asserting one write equals one OTP delivery. Observe final
  response or exact `:http2_informational_limit`, settle all originals and
  retire the scope. Any optional whole-VM memory samples are diagnostic only;
  public success or eventual rejection cannot prove pre-consumer admission.
- SETTINGS: after the initial exchange and admitted request barrier, send256
  then4096 valid empty non-ACK SETTINGS frames in separate cases. Read/count
  their exact ACKs concurrently so the9-byte writer is not the induced stall.
  Then send a valid final response, require independent-scope progress and
  finite original-completion/retirement outcomes. The fixed sequence confirms
  valid-wire ingress; a passing run does not prove an outstanding-cast bound.

The upstream repair acceptance must add a documented finite aggregate
header/control notification admission or coalescing/consumption contract and
deterministic upstream regressions for its actual owner/subscriber/pool path.
Consumer tests must preserve `cleanup_pending`/`cleanup_unconfirmed` outcomes.
No upstream issue or peer implementation was authored by this read-only review.

## Verification and handoff

Performed read-only scoped `rg`/`sed`/numbered-source inspection, Python SHA-256
comparison against installed files and exact integer arithmetic. Final hash
comparison passed with the one documented older Fetch-ref difference. An
initial diagnostic assumed24 total table rows and exited1 when the author added
two supplemental rows; it was corrected to account for all26 rows, without any
source change or hidden failed acceptance check. Report whitespace and required
content checks are recorded by the final verification command.

Review status: **DONE**, independent bounds findings confirmed; H2 activation
**BLOCKED on missing hard accounting contract**, H1 qualification **NOT RUN**,
full M3 **NOT PASSED**. Sol repair rounds0; Astra repair rounds0. All commands
finished, no owned runtime/peer process started. Parent owns routing, final
accounting decisions, document repairs and exclusive runtime execution.
