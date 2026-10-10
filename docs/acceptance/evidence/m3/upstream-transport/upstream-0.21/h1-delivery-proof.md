# P1 managed H1 delivery source proof worksheet

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_delivery_proof`.
Assignment: direct Sol, bounded read-only source investigation.
Report status: **DONE — partial source lemmas and concrete closure work**.
Complete P1 delivery/backing/outstanding bound: **NOT ESTABLISHED**.
Runtime/probes/tests: **NOT RUN**. No reservation or activation is certified.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Owned additions are this report and [its source receipt](h1-delivery-proof.json).
All other changes, including the independent preparation review, were preserved.

## Exact source boundary

The installed runtime is OTP28.5.0.7/ERTS16.4.0.6/SSL11.6.0.6,64-bit,
under `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
The available direct Nix runtime source input is
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`.
`otp-source-provenance.json` identifies its fixed signed NAR; no recovered
source-deriver URL, revision or Git identity is claimed. Fresh SHA-256 checks
matched all15 receipt source files and all6 installed SSL/source pairs.
The installed HTTP cohort is0.21.0, tag
`9813c126dc8b48055b9ee941c693fc27fa691489`.

OTP filenames/lines below are relative to that exact source input. HTTP source
filenames are relative to this worktree. The earlier narrow review's older
OTP installation is not a source premise here.

The intended controlled profile is C2/R32/P0, H1, OTP SSL with the inet driver,
raw binary/header0 mode, effective buffer/recbuf/sndbuf8192, no kTLS/distribution
or caller TLS overrides, and effective internal active-N in1..100. The runtime
receipt's configured `nil` value was observed before startup; it does not pin
future effective settings. These remain integration preconditions to enforce
and verify without mutating global SSL environment.

## Driver lemmas: logical bytes and exposed payload capacity differ

For a fresh fixed raw inet socket with effective driver buffer B, no prior
positive-length passive receive, and no subsequent packet/buffer changes:

1. `inet_drv.c:13126-13152` allocates a virtual read buffer of B when
   `request_len=0` and calls `sock_recv` with at most that remaining capacity
   (`13179-13226`). `packet_parser.c:258-262` returns all currently available
   raw bytes as a complete packet immediately. Thus one raw TCP data event
   has logical length n<=B; raw mode does not expand to a peer-declared packet
   length. Explicit buffer setting marks `INET_FLG_BUFFER_SET`
   (`inet_drv.c:6958-6965`); the recbuf-driven automatic increase is guarded
   by the absence of that flag (`7321-7360`). Kernel receive-buffer size alone
   is not this logical event bound.
2. Allocation caching prevents assuming backing=B. `alloc_buffer/1`
   (`2070-2091`) can return a cached binary larger than the requested size;
   its virtual size remains B. The cache permits up to1MiB total
   (`2031-2032`, `2114-2146`). However `tcp_deliver/2` shares the driver binary
   only when `n >= s - (s >> 2)`, where s is its `orig_size`
   (`13062-13090`). This condition is `n >= ceil(3s/4)`, so shared exposed
   payload capacity satisfies `s <= floor(4n/3)`.
3. The other branch calls `tcp_message/3` with `ERL_DRV_BUF2BINARY`
   (`3987-4017`); `io.c:6006-6020` copies n bytes through
   `erts_hfact_new_binary_from_data`. `erl_bits.c:2758-2805` allocates exactly
   the payload size for refcounted output, or a small on-heap binary. The
   sharing branch uses `ERL_DRV_BINARY` (`inet_drv.c:4026-4052`), whose
   `io.c:5969-5999` implementation copies small binaries or wraps the original
   driver backing. Thus the exposed raw payload-capacity ceiling is
   `floor(4B/3)`, including the copy branch. At B8192 this is10922 bytes.

These lemmas concern payload capacity, not Binary/BinRef/message headers or
allocator slack. Header/representation conversion belongs to P2. They also
require the actual underlying socket/backend and effective buffer invariant,
not merely the options supplied by the caller. A different prior passive
receive or packet mode can invalidate the fresh fixed-raw-buffer premise.

## SSL trace: credit, record carry and application buffering

| Edge | Exact source behavior and implication |
| --- | --- |
| Transport construction | `deps/http_core/lib/http/transport/ssl.ex:12-31` creates a passive raw binary TCP socket before SSL upgrade. `tls_socket.erl:128-135,278-289` separates emulated user options and installs internal raw/header0/passive/binary settings for the inet transport. The effective backend and buffer still require runtime/profile enforcement. |
| Internal credit | `tls_dtls_gen_connection.erl:189-195` and `tls_gen_connection_1_3.erl:107-111,435-453` select internal N. `ssl_config.erl:134-147` uses the default100 or an application integer; neither path clamps an arbitrary override to1..100. |
| Driver emission | `inet_drv.c:4302,4329` applies `INET_CHECK_ACTIVE_TO_PASSIVE` after each successful raw message. The macro at1551-1559 decrements active-N and emits `tcp_passive` when credit reaches0. `tls_gen_connection.erl:724-731` requests another N only through internal activation. |
| Raw input and record carry | `tls_gen_connection.erl:283-305,604-645` parses a TCP event and appends complete records to existing ciphertexts. `tls_record.erl:109-120,474-575` retains only an incomplete encoded record in the record buffer on its ordinary non-downgrade path. Ciphertext length is checked before waiting for its body. TLS1.2 maximum is18432; TLS1.3 maximum is16640 (`ssl_record.hrl:142-144`, `tls_record.erl:704-709`). A conservative full encoded-record carry quantity is18437, including its five-byte header; it is not a public delivery bound. |
| Record aggregation | `tls_gen_connection.erl:734-827` decrypts and concatenates consecutive application records in the current ciphertext list. Non-application records can leave subsequent ciphertexts for later protocol events. One public data value can contain several records. |
| Private application buffer | `ssl_gen_statem.erl:939-950` adds each application fragment to `{Front,Size,Rear}`. Passive raw mode stores it (`1533-1571`). The raw active path delivers the first queued binary intact (`1750-1755`); it does not uniformly flatten the entire private queue. |
| Backpressure on reactivation | With no ongoing recv, public passive mode and nonempty application buffer, `tls_gen_connection.erl:679-687` waits instead of reactivating. Empty-buffer, active or different state paths can reactivate (`689-722`). The passive-marker handler can also activate when a recv exists and ciphertexts are empty (`291-305`). Therefore a complete invariant must track recv state, ciphertexts and user buffer together. |
| Public active-once | `ssl_gen_statem.erl:1586-1608,1783-1809` sends the data then changes user active-once to false; it stops further user delivery until rearmed. `1812-1861` constructs `{ssl, UserSocket, Data}` and sends it without binary-mode normalization/copy. |

The selected record decoding paths provide concrete backing evidence, not yet
a universal certified delivery constant. AEAD decryption creates output of
`in_len` after removing the tag (`lib/crypto/c_src/aead.c:243-271,303-310`);
TLS1.3 strips padding/type by slicing and checks final plaintext<=16384
(`tls_record_1_3.erl:369-410`). CBC/other `crypto_one_time` updates allocate
input+block temporary capacity, shrink to output length, then combine update
and final output into a new binary (`lib/crypto/c_src/api_ng.c:465-487,794-830`).
`ssl_cipher.erl:251-308` also has null/stream/block and error construction paths.
Closing a decrypt-output ceiling requires mapping the actually admitted suites
and successful/error paths to these native entrypoints and NIF binary semantics.
Internal decrypt temporaries may be excluded by the TLS-internal boundary;
backing retained by a returned application slice is included.

`iolist_to_binary` is **not a compaction barrier**. In
`erl_iolist.c:881-885,916-927`, a singleton binary list or binary input returns
that same term. A multi-element list uses a newly sized output
(`719-737`). SSL record splits and decrypted plaintext slices can therefore
expose larger backing even after an application-record concatenation call.

## Precise conditional connection-state lemma

Let B be the proved effective raw event limit, N the fixed positive internal
credit, and M the complete encoded-record carry ceiling. Consider one
application-buffer accumulation interval entirely in the established
`connection` state, without recv, downgrade, kTLS, distribution, external
setopts, extra public arms, owner transfer or renegotiation state transitions.
If the following credit invariant holds:

> While this interval retains application bytes, all charged queued/raw input,
> pending ciphertexts and record carry arise from at most one still outstanding
> N-credit driver epoch plus one previously incomplete record; another epoch
> is never armed until the retained application bytes are consumed.

then their contributing encoded bytes are<=`N*B + M`. With separately proved
non-expanding successful record decoding, each delivered application binary
has logical length<=those contributing bytes. This is a conditional lemma,
not an asserted value of d. It explicitly charges pending ciphertexts and
record carry rather than treating a TLS record or driver buffer as a message.

For backing, let K_decode bound the retained backing of a successfully
decoded single fragment on every admitted suite/path. The SSL singleton path
preserves K_decode; actual multi-fragment concatenation creates its own
logical-sized output. Consequently a candidate delivery payload-capacity
bound is `max(K_decode, d)`, once d, native output semantics and all relevant
branches are proved. It cannot be replaced by `byte_size(Data)` today.

The ordinary connection-state source supports this induction, but does not
complete it here. The initial handshake sets `recv.from` until acknowledgement
(`ssl_gen_statem.erl:1438-1443`), and non-connection paths use different
reactivation conditions (`tls_gen_connection.erl:668-670`). Peer-driven
renegotiation/control transitions and connection-entry carry must be covered
before using the lemma over the socket lifetime. Transport-message/passive-marker
ordering and gen_statem internal-event priority must also be linked to the
actual N-credit resets. The historical `100*8192+18437` value was not used as
a premise or promoted into a certificate; the old eight-window factor is
not an outstanding-delivery or backing proof.

## Public owner and parser: normal-loop bound, distinct retained roots

`SocketClient.owner_loop/1` normalizes a single transport message
(`deps/http_fetch/lib/http/socket_client.ex:1372-1390`). It parses the whole
event batch before dispatch. `handle_events/2:1412-1422` processes every
continuing event before `rearm/1:1517-1522` requests active-once again.
Body dispatch calls blocking `HTTP.Stream.chunk/3:1469-1473`;
`deps/http_fetch/lib/http/stream.ex:85-111` waits for a matching ACK/error.
Reader-ACK mode waits for the reader before acknowledging upstream
(`stream.ex:201-211,340,364-374`). Non-ACK reader mode can acknowledge on
handoff; consumer release is therefore a separate controlled-caller premise.

For one correctly owned socket in this normal loop, exactly one public data
message can be emitted per successful active-once arm before it becomes
passive; the owner consumes that message and its batch before the next arm.
Conditioned on sole arming authority and no stale transfer/idle message,
there is at most one unconsumed public data message per connection, hence
at most two for C2. This does not mean one live backing allocation, or one
combined pipeline copy, per connection. Old parser/header/consumer slices and
the new message can coexist. N internal raw messages belong to the TLS
transport credit, not N public owner messages.

Pool transitions are outside that normal-loop lemma.
`deps/http_runtime/lib/http/http1/pool.ex:97-120` arms idle sockets;
`144-150` makes them passive, calls recv(0,0), checks queued events and transfers
ownership on checkout. `189-191` copies a mailbox-list representation.
P1/P5 must cover old-recipient/in-flight signals and credit restoration across
these public barriers. No late-message counterexample or unbounded sequence
was demonstrated in this investigation.

`deps/http_core/lib/http/http1.ex:83-108` appends old carry to delivery before
validating a head. Chunked body events alone have the65536 emission cap
(`168-183`). Content-length and EOF modes can expose the whole available input
(`116-139`). A one-byte emitted chunk or carry can retain the appended backing.
Under a certified d, normal nonterminal logical carry H65536 gives invocation
size<=H+d, but terminal `:done` remainder can retain the full last input.

The source append allocator doubles requested used size through16MiB
(`erl_bits.c:70-73,1815-1825,1896-1907,1963-2005`), with an initial256-byte
floor on the checked nonwritable branch. Slices preserve refcounted backing
above the small on-heap threshold (`2635-2668`). A future recurrence must
account for **old carry backing + delivery backing + new append backing**, with
sharing proved explicitly. It must cover compiled concat alternatives, zero-byte
append reuse and failure/terminal paths before applying any numerical ceiling.
This report does not multiply logical H or d by a guessed pipeline factor.

## Closure work and next action

P1 remains local proof work, with these specific edges:

1. Enforce and independently record actual inet/raw/header0/binary/backend and
   effective buffer8192; verify N in1..100 when selected, without global mutation.
2. Complete the encoded-input credit induction over initial handshake,
   established traffic, permitted peer control/renegotiation, passive markers,
   EOF/errors and reuse/owner handoff. Prove the initial conditions and allowed
   transitions, including existing ciphertext/record/application carry.
3. Finish retained decrypt-output and singleton/multi-fragment backing formulas
   for every admitted successful/error branch using the exact native/NIF source;
   relate them to actual runtime suite/backend provenance. Keep TLS-private
   temporaries distinct from backing visible in public delivery.
4. Compose the sole-arm public message lemma with pool handoff/retirement and
   parser carry liveness. P2 supplies payload wrapper/allocation semantics;
   P4 supplies phase overlap. Full metadata, process accounting and the entire
   P4 table are outside this focused report.

Recommended next action: parent assigns a bounded source proof completing
item2, with P2's binary/NIF semantics feeding item3, then independent review of
the resulting d/backing/outstanding certificate. Serialized independent-peer
probes can corroborate the enforced profile and transitions later; they cannot
replace the induction. No demonstrated upstream missing bound or defect is
reported, and no new external blocker or upstream action is justified here.
No user product decision is required. All P0-P6/activation stay unqualified.

## Verification and handoff

Read-only git baseline/status, numbered source reads and source inventories
completed. Python verified15 existing OTP source hashes,6 identical installed
SSL pairs, driver threshold arithmetic, source receipt integrity and Markdown
whitespace/links/fences. Initial source searches included nonexistent guessed
filenames; one grouped read used the wrong source root. Corrected reads above
completed; these were search/read diagnostics, not runtime regressions.
No Mix, VM execution, network probe, dependency edit, upstream mutation or
commit ran. All own commands finished; parent-managed jobs were untouched.
Counters remain Sol unsuccessful0/Astra0; no escalation gate applies.

Exact hashes for all18 inspected OTP and9 repository/receipt inputs are in
`h1-delivery-proof.json`, SHA-256
`688b8d0bd3236c0486f1bdf69c664c2f49e5a2490798e06e5bc25aae30734fae`.
The unchanged preparation specification review SHA-256 is
`f4a2c672dee93da3c656a39c925901880f8b3ec75b79a0cded94482f42ebfd60`.
The available proof is partial and conditional; no full P1, production byte
reservation, managed H1/H2 activation or M3 acceptance follows.
