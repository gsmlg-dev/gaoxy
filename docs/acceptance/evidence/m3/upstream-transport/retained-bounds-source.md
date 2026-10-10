# Managed transport retained-bound source worksheet

Prepared 2026-10-11 Asia/Shanghai. Source-accounting assignment only; no Mix,
fixture, dependency installation, private API, or runtime memory measurement ran.
Gaoxy worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. Other writers own the adjacent
design, plan, API review and independent-peer fixture changes.

## Verdict and exact profile

**Worksheet complete; complete retained-byte reservation BLOCKED.** The numbers
below are a subtotal of bounded component budgets, not a proven total retained
allocation. Missing terms are named explicitly, never replaced with zero.
H2 needs independent confirmation of peer-driven header notification and
SETTINGS control backlog bounds. H1 can undergo a separate narrow review using
the existing Gaoxy PID-or-nil upload contract and explicitly frozen 8192-byte receive buffers. Its artifact,
public bounds/retirement and metadata/copy qualification remain separate gates.

Candidate upstream source is PR81 head
`11f1642cf6408219d4813772bda1055e605bbdc4`, merged as
`a75ec3c34446a1877366a0e52055743d28eabcc9`. It contains PR80's 256-frame header
fragment limit. Initial checkout inspection found the 0.20.0 cohort; parent
concurrently updated the current dependency requirement/lock cohort to 0.21.0
by final worksheet verification. This writer did not install or validate that
cohort, and this worksheet does not qualify installed runtime behavior. Parent reported containing v0.21.0 tag
`9813c126dc8b48055b9ee941c693fc27fa691489`; this writer independently downloaded
the same 24 selected source files at that immutable commit. **23 were byte
identical**, including Policy, Scope, Owner, Pool, HTTP1, HPACK and Bridge. Fetch
changed only line 322 from `RequestCompletion.new(options)` to
`RequestCompletion.new(options, request)`. Supplemental RequestCompletion
comparison shows a new proxy-eligibility branch; the managed policy rejects
proxy options, so the audited no-proxy accounting path is unchanged. Publication
and installed runtime identity remain the parent's separate gates.

Assumed managed profile: `max_connections=2`, `max_requests=32`,
`max_pending=0`, explicit `:http1`, `:http2` or `:h2c`; OTP TLS backend;
`:native_v1`; raw streaming response, no body decoding, manual redirects. The
policy permits socket buffer options up to 1,048,576 and defaults `buffer`,
`recbuf`, `sndbuf` to 65,536. C/R/P alone do not specify the delivery ceiling.
This worksheet excludes direct private-owner and extended-CONNECT operations.

## Source-backed limits and accounting units

Line citations below refer to the immutable candidate and abbreviations in the
provenance table. Serialized-term byte limits, logical payload byte limits and
HPACK table charge are different units. Their sum is a useful component charge;
it is not a conversion to BEAM heap/binary bytes.

| Component | Per-component limit | Evidence and limitation |
| --- | ---: | --- |
| Frozen TLS/socket policy | 1,048,576 serialized bytes | Policy 49–103; limit applies to `{ssl,sockets}`, not every policy/injection copy or PEM-decoding transient. Depth 16 and list length 4096 also bound accepted policy structure. |
| Scope request/preparation slots | 32 rows total | Scope 25–31, 66–98; preparing, active and cleanup-held requests consume ingress. Snapshot has no mailbox or retained-byte counter. |
| Scope connection slots | 2 | Scope 83–111, 233–247; reserved before dialing, retained until raw socket/dial/protocol resources confirm death. H1 active, idle and handoff-preparing sockets share this limit. |
| External pending request queue | 0 | Scope 15–22; Pool 487–545 rejects ordinary unadmitted waiting requests at `max_pending=0`. This is not a zero-mailbox/zero-control-queue claim. |
| Buffered request payload | 1,048,576 | Policy 153–171 checks `IO.iodata_length`; original iodata structure is not bounded by this check. |
| Request fields and target | 65,536 charge bytes, 256 fields | Policy 153–165 uses name/value bytes plus 32 per field and target bytes. Request, wire header and message copies are additional. |
| H1 head/framing carry | 65,536 | HTTP1 7–9, 83–108, 394–426; line limit 8192, emitted chunk limit 65,536. A transport delivery and concatenation can exceed carry size transiently. |
| H1 upload transferred chunk | 65,536 | Upload 4–7, 137–162; one source chunk, synchronous send, source ACK follows write. Source/worker/encoded framing overlap needs accounting. |
| H2 DATA admission | 1,048,576 per connection | Owner 122, 1170–1198; includes unacknowledged DATA and unused on-wire connection allowance. It does not bound headers, controls or OTP delivery allocation. |
| H2 frame carry | at most 16,392 logical bytes | Native max incoming frame payload 16,384; Boundary 5–8 and Frame.decode require 9-byte frame header. `:more` retains an incomplete frame. Its backing binary can be larger. |
| H2 compressed header block | 65,536, at most 256 frames | Owner 983–1038, 1083–1084; initial/final/empty frames count; empty fragments add no retained list cell. One connection-level reassembly block. |
| H2 decoded header block | 65,536, at most 256 fields | HPACK 365–375, 532–543, 681–709; per-block decoded output only, not aggregate response events/mailbox. |
| H2 decoder dynamic table | 4096 HPACK charge bytes | HPACK 365–375, 802–825. Entry charge includes name/value plus 32; heap/list/map overhead and backing binaries remain separate. |
| Native encoder dynamic entries | no new literal entries | Profile 24–28 and HPACK 493–515; native outgoing `:literal`, Huffman `:never`. Peer table SETTINGS change capacity bookkeeping but do not make native literal encoding accumulate dynamic entries. |
| H2 synchronous writer batch | 1,048,576 | Owner 667–710. `state.bytes` initializes to zero, is not incremented before send, and only decreases after it. This is a batch check, not proof of a 1MiB total upload/message queue. |
| H2 upload bridge | 65,536 source chunk, 16,384 piece | Bridge 10–11, 108–139, 223–235. One read and one inflight slice; source ACK waits for whole held chunk. Owner 1267–1288/1400–1428 retains one pending piece per stream and can copy the remainder. |
| H2 DATA delivery metadata | 128 entries per stream | Owner 1103–1138; at R32, conservative count 4096. Empty nonterminal DATA returns credit without an entry. This does not constrain header/control entries. |
| Fetch informational accumulation | 128 responses and 65,536 serialized bytes | SocketClient 1018–1054; enforced after Owner decodes and sends headers. |
| Fetch response trailers | 256 fields and 65,536 serialized bytes | SocketClient 1025–1037. |
| Upload trailers | 128 fields and 65,536 serialized bytes | Stream 119–139 validates through `HTTP.Trailers`; retain a separate allowance for source/bridge/writer overlap. Trailer validator source is not independently audited here. |

## Numeric subtotal for C2/R32/P0

The following adds **one charged representation** of each selected finite
component. It deliberately reserves both ordinary buffered-body and streaming
bridge allowances, and both connection decoded-header and request final-header
allowances; conservative double-counting is permitted. Copy/structure terms
below are still required. This is not a total safe upper bound.

```text
Q = 1,048,576                         # serialized TLS/socket policy budget
H2_connection_components =
    1,048,576                        # DATA admission
  + 1,048,576                        # synchronous writer batch
  +    16,392                        # incomplete frame logical carry
  +    65,536                        # compressed header block
  +    65,536                        # one decoded block
  +     4,096                        # decoder table charge
  = 2,248,712
H2_request_components =
    1,048,576                        # buffered-body payload
  +    65,536                        # transferred bridge source chunk
  +    16,384                        # owner pending upload piece
  + 5 * 65,536                       # request fields/target, informational,
                                     # final headers, response/upload trailers
  = 1,458,176
known_component_charge(2,32,0) = Q + 2*2,248,712 + 32*1,458,176
                             = 52,207,632 bytes (~49.79 MiB)
```

No allocation/measurement was used to obtain this arithmetic. In particular,
52,207,632 is neither an approved Gaoxy reservation nor an RSS estimate.

## Complete accounting formula and unresolved terms

Let `C=2`, `R=32`, `P=0`. A complete conservative charge must satisfy:

```text
B_H2 = known_component_charge(C,R,P)
     + Q_policy_copies_and_prepare_transients
     + C * (D_transport_delivery_and_backing
            + X_framing_reassembly_and_header_copies
            + X_hpack_decode_and_table_structure
            + X_send_batch_encoding_and_copy_overlap
            + M_connection_resource_timer_scheduler_control)
     + R * (X_buffered_body_structure_and_source_copies
            + X_upload_bridge_owner_writer_overlap
            + X_response_delivery_header_trailer_overlap
            + M_request_tracker_guardian_stream_and_ingress)
     + M_peer_header_event_backlog
     + M_peer_settings_pool_backlog
     + P * M_external_pending_request
```

Every `D`, `X` and `M` needs a source-backed maximum, a documented runtime/profile
conversion, or a narrower supported admission contract. The **external pending
request term alone** is zero for this profile. Resource preparation and cleanup
holds are covered by the C/R charges and remain charged until their respective
public completion/retirement barriers; pending/unconfirmed does not refund them.
A timeout is not a memory bound or cleanup proof.

Specific missing terms:

- Delivery/copy ceiling: Owner 747 concatenates carry with the whole transport
  event and parses all frames before notifying. Active-once rearm (Owner
  297–310, 1510–1530) bounds receive-event count, not the bytes of one OTP/TLS
  event or referenced backing binaries. TCP/SSL wrappers do not enforce an
  application delivery-byte cap. Socket options and OTP/backend must be pinned
  and qualified; DATA credit cannot cap a control/header-only delivery.
- Reassembly overlap: Owner 1024 makes a reversed fragment list, joined binary,
  then final concatenation; each payload representation is bounded by 65,536,
  but more than one can coexist. One 65,536 charge omits those overlaps.
- HPACK transient structure: HPACK 828–868 materializes eight bit-list elements
  per encoded byte (at most 524,288 from the block budget), at most 65,536
  one-byte output entries, a reversed output list and final binary. It builds
  the Huffman tree on each call. Counts are finite; their BEAM word/binary/map
  cost and dynamic/static-entry backing ownership need explicit conversion.
- Upload overlap: bridge source, source stream, slice, owner pending piece,
  copied remainder, framed send batch and caller buffered body may coexist
  until ACK. SocketClient 819–846 explicitly copies 16KiB buffered-body pieces;
  Owner 1417 copies pending remainder. A 1MiB batch check omits pre-encoding,
  unsent bridge payloads and their messages.
- Peer-driven header backlog: Owner 1200–1219 appends decoded headers to
  `response_events`; 747–765 flushes only after the full delivery; 1545–1549
  uses unacknowledged `send`. StreamState 188–198 accepts repeated legal
  informational responses. Fetch's later informational limit is not an owner
  aggregate-event/mailbox admission bound. If delivery bound D were proven,
  the per-delivery event count would be finite (frame headers cost 9 bytes);
  decoded amplification and retained events from previous deliveries still
  need accounting. No source hard outstanding header-event cap was found.
- Peer-driven SETTINGS backlog: each valid empty non-ACK SETTINGS runs Owner
  853–885, writes an ACK and calls 1711–1725 asynchronous pool cast. Incoming
  rearm does not await pool consumption. A finite delivery could bound one
  batch of casts, but repeated deliveries renew casts while old pool messages
  may remain. No backlog admission, coalescing or consumption barrier was found.
  This concern arises from valid peer bytes, not excluded arbitrary caller
  messages; it is a missing hard proof, not a performed leak measurement.
- Buffered iodata structure: FetchOptions 278 returns original input; Fetch
  284–294 stores it directly; Policy 168–171 accepts by payload length. An
  arbitrarily long list of empty binaries has zero `IO.iodata_length` and is
  retained before Request 254 flattens it for wire preparation. This affects
  H1 and H2 public buffered bodies. Caller-owned producer input is excluded,
  but an admitted buffered body copied into request state is not zero-cost.
  The existing Gaoxy adapter already creates a PID upload or nil
  (`HTTPFetchClient.open/1:36–45`), and Proxy.HTTP 270–285 submits only bounded
  binary chunks. Thus arbitrary buffered iodata is unreachable in the intended
  Gaoxy H1 slice. This is a separately routed upstream public-input defect, not
  automatically an H1 activation blocker. Preserve that exact input contract;
  it does not prove the broader upstream buffered-body claim.

## H1 separation and narrower gate

H1 has no H2 header-notification or SETTINGS-pool fanout. HTTP1 220–222 discards
informational heads; SocketClient 1384–1435/1469–1473 processes streaming chunks
synchronously with ACK, then rearms (1521–1525). Idle H1 Pool 108–126 arms once;
180–203 closes/discards on a socket event. Checkin requires empty parser carry,
complete self-delimited response and no active/cancelled upload (SocketClient
1583–1598). Idle/handoff-preparing entries still own sockets/TLS and metadata;
reserve C2 resources before creation and retain that charge until retirement.

Existing Gaoxy `HTTPFetchClient.reservation/3` is H1-only:

```text
D_existing = 100*8192 + 18,437 = 837,637
F = 65,536
B_existing_request = 8*(D_existing+F) + 8*chunk_bytes
                   + 2*external_size({fields,url})
                   = 7,225,384 + 8*chunk_bytes + metadata
```

This qualifies `:inet` and SSL `internal_active_n` 1..100, excludes OTP/kernel
buffers and process metadata, and was written for the pinned older direct
client. **Do not transplant it to default managed sockets**: their buffer is
65,536, not 8192. Substituting 65,536 gives `D=6,572,037` and an eight-window
base of **53,100,584**, but this is unqualified arithmetic, not fresh OTP proof.
A managed profile explicitly choosing 8192 buffers is policy-valid; its exact
installed path and host delivery assumptions still require confirmation.

For the intended narrow Gaoxy H1 slice, freeze `buffer=8192`, `recbuf=8192`
and an explicit bounded `sndbuf` (8192 is the proposed worksheet setting).
Preserve PID-or-nil upload, chunks at most 65,536, acknowledged writes, raw
streaming response, manual redirect and the qualified host assumptions above.
The buffered-body payload/iodata-structure term then does not apply because
that input is unreachable, not because its upstream check is sufficient.

A conservative numeric component charge on this narrow profile is:

```text
H1_request_components = 7,225,384 + 8*65,536
                      + 2*65,536       # request fields/target duplicate charge
                      + 3*65,536       # final head, response/upload trailers
                      = 8,077,352
H1_known_component_charge(2,32,0) = 1,048,576 + 2*837,637
                                 + 32*8,077,352
                                 = 261,199,114 bytes (~249.10 MiB)
```

The C2 allowance charges a possible idle/preparing delivery in addition to R32
request windows. This deliberately over-reserves the C2 actual H1 active socket
capacity. It remains a component subtotal: policy copies/preparation, process
and ETS metadata, header structural overlap and exact managed/installed OTP
qualification have not been converted to a final hard retained allocation.
The 65,536 header/target charge is an assumed Gaoxy admission profile ceiling;
verify its exact serialization before approving the doubled metadata allowance.

A separately approved H1 formula can use those conservative request windows
plus the C2 idle/preparing resource allowance:

```text
B_H1 = Q_config_with_copies_and_preparation
     + C*(D_qualified_idle_or_connect + M_socket_TLS_pool_slot)
     + R*(8*(D_qualified_active+65,536) + 8*upload_chunk
          + request_headers_target_body_and_trailers
          + M_ingress_tracker_guardian_and_pool_messages)
```

Reserving R32 active-request windows over-reserves H1's C2 socket capacity and
is acceptable. Final constants need qualification of the explicitly frozen managed D profile,
Gaoxy's bounded header/target input, header/trailer overlap and explicit metadata
exclusions/conversion. The PID-or-nil upload contract addresses the public
buffered-iodata concern for this Gaoxy slice. The H2
backlog concerns alone do not block that separate H1 qualification effort;
this worksheet does not mark it passed.

## Minimal finite public peer checks for independent confirmation

These are source-derived recipes, **NOT RUN** by this worksheet. Use only
`HTTP.ManagedTransport.open`, `HTTP.fetch`, public completion/snapshot and
retirement receipts with finite deadlines; no private process introspection.

1. H2 SETTINGS: independent h2c peer completes SETTINGS exchange, holds one
   admitted request, sends a fixed bounded sequence of legal empty non-ACK
   SETTINGS frames (stream 0, flags 0), reads each ACK, then returns a valid
   final response and awaits request completion and scope retirement. Repeat
   bounded batches under documented limits. Public success/retirement checks
   cannot by themselves prove a mailbox ceiling; require a documented aggregate
   contract or accounting evidence as well.
2. H2 headers: same profile/held request, send fixed bounded batches of legal
   `103` HEADERS blocks (END_HEADERS, no END_STREAM), each within HPACK budgets,
   then final response or observe the public informational-limit error and
   confirm public cleanup. Test coalesced delivery and successive deliveries;
   distinguish owner pre-consumer retention from eventual Fetch rejection.
3. Buffered input: submit a small finite list of empty binaries as an otherwise
   legitimate buffered body under the managed scope and compare increasing
   finite list lengths. The payload check stays zero. Inspect the supported
   admission contract, without treating runtime success as proof of metadata
   boundedness. Gaoxy's narrower upload contract needs its own scoped test.

No new upstream issue was created by this writer. Parent owns independent
confirmation, severity/issue routing and architecture decisions. This document
provides no evidence of a runtime exploit, whole-VM leak or completed M3 gate.

## Immutable source provenance

All source links below are immutable PR81-head paths. The shared cache manifest
records Git blobs and SHA-256; the accounting cache also records immutable raw
URLs. Tag source comparisons are saved separately with SHA-256. The shared facade cache contains seven
files; the separate accounting cache contains twenty selected files. The table
lists the source files used in this worksheet, not a complete upstream archive.

| Abbreviation / path | SHA-256 |
| --- | --- |
| [managed_transport.ex: `apps/http_runtime/lib/http/managed_transport.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/managed_transport.ex) | `92e0cc7649790029cf95b51c09e6d4e845c6183462083ab2272818cf57197c54` |
| [Policy: `apps/http_runtime/lib/http/managed_transport/policy.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/managed_transport/policy.ex) | `d2164cc922893b9cb626b3886d1fbdc1c4f479f1253446277120df6720df1279` |
| [Scope: `apps/http_runtime/lib/http/managed_transport/scope.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/managed_transport/scope.ex) | `73fb847f72846aa1d1f3fa0f3e4fc039741f0212b1d7fd4177f63d020e26b57b` |
| [Owner: `apps/http_runtime/lib/http/http2/connection_owner.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/http2/connection_owner.ex) | `18bb290088ebbfd8b56d141f45210f7055081deecbd01ab55edf47dc580d8857` |
| [SocketClient: `apps/http_fetch/lib/http/socket_client.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_fetch/lib/http/socket_client.ex) | `1b6b494264c8eb8620471bdb7b80910cd31db67e951d3f24e14e9cefecb4a3e7` |
| [Bridge: `apps/http_fetch/lib/http/http2/body_bridge.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_fetch/lib/http/http2/body_bridge.ex) | `e27351a43ca89e80e169a66b8a186c9ae9079d522ba87d769a62cd5746c9ecb3` |
| [Stream: `apps/http_fetch/lib/http/stream.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_fetch/lib/http/stream.ex) | `552c5951d30c21ce864a77c1a61dc5e8bcda038559040028e4f3282074325d05` |
| [H1 Pool: `apps/http_runtime/lib/http/http1/pool.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/http1/pool.ex) | `703edf9b1152889ac9bc6d8d48cedda528affed3b9e1ed41fdd057b42c067fcb` |
| [Runtime Stream: `apps/http_runtime/lib/http/runtime/stream.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/runtime/stream.ex) | `bae9da970e912314bca6234662eced261e61b2417303857ead9133f56ac6c5af` |
| [request_lifecycle.ex: `apps/http_core/lib/http/request_lifecycle.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/request_lifecycle.ex) | `81a3b158e33b7291422c009fb47170574b3bf6b7d9ad4023619ca84147fcf01f` |
| [Frame: `apps/http_core/lib/http/http2/frame.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http2/frame.ex) | `b3140bfcfca3691d7868c2542e839adc7332c0ae196640c57d8f5674521adf01` |
| [Profile: `apps/http_core/lib/http/http2/wire_profile.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http2/wire_profile.ex) | `0ba06539f405188c51c9a009475baad676b83268d2151293d8ac4df780e086e6` |
| [HPACK: `apps/http_core/lib/http/http2/hpack.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http2/hpack.ex) | `ceb014b64da2567fdf6daad41d84ebd09b9c4a1e4bc670c36f70fd415f3ed317` |
| [Boundary: `apps/http_core/lib/http/http2/boundary.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http2/boundary.ex) | `67bebd1b226069753fab1c4b70b21cce1fc2e5846f8b45a219dd69c5bee283ee` |
| [connection.ex: `apps/http_core/lib/http/http2/connection.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http2/connection.ex) | `b9079e36ef4a98502852943af5d371d781094905ca0f36d45662931c7eb10716` |
| [tcp.ex: `apps/http_core/lib/http/transport/tcp.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/transport/tcp.ex) | `2685ee728c19fc21014972792e5d71560fc8b08f5553b9a3874707fe534a7c9d` |
| [ssl.ex: `apps/http_core/lib/http/transport/ssl.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/transport/ssl.ex) | `43f5f1c2d8c8d28b0cafe9e1e7b8764bc5d462214db9960815b35e0de4917636` |
| [Pool: `apps/http_runtime/lib/http/http2/pool.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_runtime/lib/http/http2/pool.ex) | `ff733ac8765233d817b8a951b617eb0af0099b79ffd02b66c4eca6772bb697b7` |
| [Request: `apps/http_core/lib/http/request.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/request.ex) | `b097ad2d68d3a4d715dad594f02cc9025b6a17a267175b375a4b7d37bc675dcf` |
| [Fetch: `apps/http_fetch/lib/http.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_fetch/lib/http.ex) | `1315344d3eec679d7ef4a0c6ea0cbf63c55ead595e3a8468f766c37b68196513` |
| [HTTP1: `apps/http_core/lib/http/http1.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http1.ex) | `c84ddf5081b4d61a824789ebb9f606dc4c6d6aa91b69f233bde3b3c5d3997422` |
| [Upload: `apps/http_fetch/lib/http/http1/upload.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_fetch/lib/http/http1/upload.ex) | `e55ed4591faf1a0253d2d506dce43d1b3f794f831d48825644045250f3888d65` |
| [StreamState: `apps/http_core/lib/http/http2/stream_state.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_core/lib/http/http2/stream_state.ex) | `ea6dc2679733fe88c7f686df3cf417e220ebbe38923e704254aae849a1b6e280` |
| [FetchOptions: `apps/http_fetch/lib/http/fetch_options.ex`](https://github.com/gsmlg-dev/http_fetch/blob/11f1642cf6408219d4813772bda1055e605bbdc4/apps/http_fetch/lib/http/fetch_options.ex) | `8e035e1ec4a8c3afb68731ceb325ddf1cd1b5a780bd1b2a063e3f417241b6061` |

Supplemental containing-tag provenance:

| Immutable tag source | SHA-256 |
| --- | --- |
| [`apps/http_fetch/lib/http.ex`](https://github.com/gsmlg-dev/http_fetch/blob/9813c126dc8b48055b9ee941c693fc27fa691489/apps/http_fetch/lib/http.ex) | `b86d8cc723cbab453e04dee8cf2a8bd99ca5a08d638c07a1d677ef501a495f7b` |
| [`apps/http_fetch/lib/http/request_completion.ex`](https://github.com/gsmlg-dev/http_fetch/blob/9813c126dc8b48055b9ee941c693fc27fa691489/apps/http_fetch/lib/http/request_completion.ex) | `2579b9bbae473603227bcf0edc9509adb8c070927d44fb4e141e7d11160bcb9f` |

Local Gaoxy source: `apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex:6–33`
at the stated baseline. Verification: cache content SHA-256 and Git blob IDs
recomputed against both manifests (27 files); containing-tag comparison
confirmed 23/24 selected files identical and reviewed the one change and its
RequestCompletion branch; component arithmetic recomputed; owned
Markdown whitespace checked. Runtime checks, installed containing release,
public wire regressions and numerical heap conversions by this writer: **NOT RUN**.
