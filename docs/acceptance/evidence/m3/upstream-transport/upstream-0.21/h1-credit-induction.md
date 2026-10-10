# P1 managed H1 transport-credit induction

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_credit_induction`.
Assignment: direct Sol, bounded source investigation. Status: **DONE — conditional
encoded-credit and public-data handoff lemmas**. Full P1: **NOT ESTABLISHED**.
Runtime, Mix, VM, network probes and tests: **NOT RUN**. No reservation,
managed transport activation or M3 acceptance is certified.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Only this new report and [its source receipt](h1-credit-induction.json) are owned.
The earlier [delivery worksheet](h1-delivery-proof.md) and preparation review
remain unchanged. This report strengthens one conditional lemma in that
worksheet; it does not replace its backing and accounting limitations.

## Source and premises

The direct Nix runtime input is
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`. The installed runtime is
OTP28.5.0.7 / ERTS16.4.0.6 / SSL11.6.0.6, 64-bit, under
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
The existing [provenance receipt](otp-source-provenance.json) identifies the
fixed signed NAR and source/installed SSL matches. No Git source revision or
source-deriver URL is claimed. HTTP cohort0.21.0 has tag commit
`9813c126dc8b48055b9ee941c693fc27fa691489`. OTP references below are relative
to the direct source input; dependency references are relative to the worktree.

The conditional profile is C2/R32/P0, H1, OTP SSL using the raw inet driver,
public and internal raw binary/header0 modes, effective fixed
buffer/recbuf/sndbuf8192, no kTLS, distribution, downgrade, paused handshake,
custom transport callback, positive-length passive receive or caller TLS/socket
option changes. No actor independently arms or changes the underlying TCP
socket, injects transport messages, or concurrently arms the public socket.
Pool checkout's public SSL `recv(0,0)` is allowed. It does not change raw inet
packet/buffer settings or request a positive underlying passive read.
Termination-only TCP reads during SSL close are outside live delivery/reuse.

Let B be the proved maximum logical bytes in one raw driver data event, N the
socket's fixed positive internal credit, and M a conservative ceiling for one
incomplete encoded record. Require `1 <= N <= 100` and B8192. The earlier driver
lemma supplies B only under its fresh, fixed raw-socket premises. Record length
validation supplies M18437 (18432 ciphertext bytes plus five header bytes).
M includes the conceptual already-parsed header, even when represented as
scalar fields rather than queued bytes. This is a logical carry bound; it says
nothing about the carry's retained backing.

The pre-start configured `nil` receipt is not lifetime enforcement. The fixed
N is selected into each connection's protocol map; later application-environment
changes do not change that map through ordinary rearming, but can affect future
connections. Actual profile selection/enforcement remains unresolved. This
investigation does not mutate global SSL application settings.

## Epoch cut and induction

An epoch starts with one successful internal `{active,N}` request and ends
when the corresponding driver credit is exhausted or the socket terminates.
A cut is the instant an ordinary new epoch is armed. The useful invariant is:

> At every live ordinary epoch cut the ciphertext list is empty, and the only
> encoded record input carried across that cut is one incomplete record of
> conceptual length at most M. Every application fragment constructed during
> an epoch uses complete records drawn from that carry plus at most N raw data
> events of that epoch. No fragment-concatenation accumulator spans a cut.

This invariant does **not** require an empty private application queue. It
bounds each newly constructed fragment separately, including a fragment that
is delivered publicly much later.

1. **Base.** `tls_socket.erl:278-289` installs passive/raw/header0/binary inet
   settings. `tls_dtls_gen_connection.erl:188-195` initializes empty protocol
   buffers and application queue, toggle=true and socket_active0.
   `tls_gen_connection_1_3.erl:106-111` likewise initializes empty buffers and
   toggle=true. `tls_connection.hrl:34-37` defines empty record and ciphertext
   buffers. The first activation therefore has zero earlier credit and carry.
2. **Exactly N transport emissions.** `inet_drv.c:1551-1559` decrements credit
   after each successful data output (`4302,4329`), sets passive at zero and
   emits the passive marker. Raw data (`4004,4016,4052`) and marker
   (`4215-4238`) use the same port output sender and connected destination.
   Same-entity/same-destination signal ordering is documented in
   `ref_man_processes.md:507-511`; these ordinary messages preserve queue order
   (`349-357`). Thus processing a genuine marker follows the prior epoch's
   data events. Internal inserted events are processed before the next mailbox
   event (`gen_statem.erl:4746-4782`), so extracted protocol events cannot be
   bypassed merely by receipt of the marker.
3. **No overlapping live credit.** `tls_gen_connection.erl:724-731` sets
   toggle=false after an activation attempt. Its only activation callsites are
   `299` and `721`. The direct marker path requires ciphertexts=[] and a recv
   caller (`291-305`). Otherwise the marker sets toggle=true. The common
   `next_record` path drains nonempty ciphertexts first (`656-662`) and reaches
   activation only with ciphertexts=[] and toggle=true (`663-670,717-722`).
   Initial toggle=true is the base; the other toggle=true assignment is closed
   transport EOF (`362`). Driver integer active settings **add** credit
   (`6974-7000`), so genuine marker ordering and sole underlying arming are
   essential, not optional assumptions. The marker path cannot add to unused
   preceding live credit: the driver has already reached zero.
4. **Input conserved within the epoch.** Raw input is parsed and complete
   records appended to the existing ciphertext list
   (`tls_gen_connection.erl:604-645`). On the non-downgrade path, the record
   parser consumes all complete records and returns only an incomplete header
   or incomplete validated body (`tls_record.erl:474-490,546-575`). Therefore
   the records and carry generated since the cut draw from at most `N*B+M`
   encoded logical bytes. Earlier private application binaries are separate
   already-constructed fragments and are not appended to this ciphertext list.
5. **Fragment construction cannot fuse epochs.** Application aggregation
   initializes a fresh local Acc=[] and recursively decodes the current
   ciphertext list (`tls_gen_connection.erl:734-827`). It returns at exhaustion
   or a control-record boundary, leaving the remaining ciphertexts in state.
   Its accumulator is not stored across mailbox events or activation calls.
   Nonempty remaining ciphertexts prohibit a cut by step3. Conversely, if
   the list is exhausted, the fragment has already been constructed before
   any subsequent rearm. The TLS1.3 control-record retry restores its ciphertext
   and prior connection state (`769-779`), rather than retaining a cross-epoch
   application accumulator.
6. **Step.** At the next genuine ordinary activation all complete ciphertexts
   have been consumed, only one bounded record carry remains, and there is no
   outstanding preceding live driver credit. This restores the cut invariant
   for the next epoch, independent of the number of older private fragments.

Consequently, the encoded logical contribution to **each** constructed
application fragment is at most `N*B+M`. If a separate proof establishes
non-expanding successful decoding on every admitted suite/path, its logical
application length is also at most that expression. Neither that missing proof
nor retained backing follows from this induction. No numerical public delivery
certificate is asserted by substituting defaults into the expression.

## State, control and terminal coverage

| Transition | Preservation of the per-fragment invariant |
| --- | --- |
| Initial handshake and connection entry | Handshake `recv.from` can permit more epochs, but each uses the same empty-ciphertext gate. Initial TLS1.2 application-data rejection guards are at `tls_client_connection.erl:335-397`; TLS1.3 examples are at `tls_client_connection_1_3.erl:255-257,317-319`. The proof does not depend on a blanket rejection claim for every initial state: any fragment that reaches common application handling has already been constructed by the bounded aggregation. Handshake acknowledgement clears its recv caller (`ssl_gen_statem.erl:1438-1443`); it does not reset input credit or merge private application fragments. |
| Established passive traffic | `tls_gen_connection.erl:679-687` can block rearm when the private application queue is nonempty. Other flow-control branches permit activation, still with an empty ciphertext list. This stronger queue gate is not needed to prove each fragment's bound. |
| TLS1.2 renegotiation | Peer/internal/user initiation changes handshake state (`tls_dtls_client_connection.erl:425-446`); HelloRequest returns to hello (`tls_client_connection.erl:415-469`). `reinit/reinit_handshake_data` changes handshake/sender state, preserving protocol buffers and credit (`tls_gen_connection.erl:206-225`). Non-connection rearming may proceed with a nonempty private application queue. Thus a single epoch for the entire private accumulation interval cannot be assumed. Each newly constructed fragment still obeys the cut invariant. |
| TLS1.3 tickets/key updates and warning controls | TLS1.3 controls resume common record processing (`tls_gen_connection_1_3.erl:156-173`). TLS1.2 warning/rejection branches resume `next_event` or stop (`ssl_gen_statem.erl:1103-1161`). They create no independent raw credit and do not merge older application-buffer binaries into ciphertext aggregation. |
| Passive markers / recv timeouts | A marker either rearms from an empty ciphertext list or sets the toggle and resumes processing. Public recv timeout clears both recv fields (`ssl_gen_statem.erl:755-759`); it cannot add raw credit independently. |
| Raw EOF | Non-connection or active/recv EOF stops. Passive established EOF retains buffered data and sets toggle=true (`tls_gen_connection.erl:306-362`). That underlying socket is already closed; attempted activation cannot create new live data credit. Buffered fragments retain their original individual bounds. |
| TLS close/fatal alerts | Passive close/fatal alerts can linger with an explicit closed/alert flag (`tls_gen_connection.erl:893-906`); other paths notify and stop. Existing data is delivered through ordinary raw first-binary handling, not a special flattening operation. A TLS alert alone need not mean physical TCP EOF; any subsequent live transport activation still uses the ordinary empty-ciphertext gate. |
| Decode/transport/activation errors | Parse/decode alerts stop or enter alert handling; transport errors stop (`ssl_gen_statem.erl:861-897`), and failed activation enqueues close and clears toggle (`tls_gen_connection.erl:729-731`). These paths construct no new cross-epoch application fragment. Error-term backing/metadata remains a separate P2 obligation. |

Private TLS heaps/queues are excluded by the declared ledger boundary. Repeated
renegotiation allowing private accumulation is therefore not, by itself, an
included-memory defect. The backing of any fragment exposed publicly is included.
This pass demonstrates no upstream defect or missing dependency feature.

## Raw public delivery and pool handoff

`ssl_gen_statem.erl:939-950` appends constructed fragments to a private queue.
`1517-1528` selects the first binary. In raw active mode or recv(0),
`1750-1755` returns that binary intact. It does not use the queue-flattening
packet/positive-recv branches at `1540-1560`. Binary/header0 formatting
preserves Data (`1812-1831`), and active-once sends one data message then
becomes passive (`1783-1809,1850-1861`). Therefore a publicly delivered raw
binary is one of the individually bounded fragments, even after several
private epochs or an owner transfer. This is a logical correspondence, not
proof of compaction or a backing ceiling.

The ordinary SocketClient loop consumes a transport message, parses its event
batch, blocks on streamed-body dispatch, and rearms only after all continuing
events (`socket_client.ex:1372-1422,1469-1473,1517-1522`). A terminal `:done`
does not rearm. Successful reuse requires a completed persistent framed H1
response, empty parser buffer, no live upload and no pending cancellation
(`1572-1615`). Under sole arming authority, this completion consumed the sole
public arm's data message before checkin starts. Earlier parser/consumer roots
may remain live; they are distinct accounting obligations.

For OTP SSL ownership transitions, public setopts once/false is emulated
(`ssl_gen_statem.erl:2066-2069`), not an independent raw driver active setting.
`ssl:controlling_process` calls `new_user` (`ssl.erl:2764-2766`), whose handler
changes only the monitored user PID and replies (`ssl_gen_statem.erl:821-826`).
It does not forward the old owner's mailbox or reset protocol buffers/credit.

**Checkin.** `pool.ex:23-30` makes public delivery passive, prepares an entry,
transfers ownership while passive, then requests one idle arm (`97-120`).
The old owner has no unconsumed arm's data message under the normal completion
premise above. Buffered/private input can later produce at most the pool's
one idle-arm data message. Parent/user concurrency and arbitrary owner changes
are outside this premise.

**Checkout.** The pool serializes checkout in its callback. It makes the idle
socket passive, requires recv(0,0) to return timeout, scans its own queued
socket events, and changes the user while still passive (`pool.ex:131-150,
189-191`). A data message emitted by SSL before the passive-setting operation
is followed by that same SSL process's call reply. The ordinary local call/reply
uses a monitor or nonpriority monitor alias (`ssl_gen_statem.erl:1304-1305`,
`gen.erl:235-276,549-554`). Same-sender destination ordering means that consuming
the reply cannot precede arrival of an earlier data message. Alias addressing
does not select a different destination process or priority message path;
priority requires explicit alias/send options (`ref_man_processes.md:415-423`).
Subsequent input is buffered with public active=false. The exact self message
inspection fetches incoming signals and builds the message list
(`erl_bif_info.c:1196-1269,1354-1361,1689-1736`); the scan is not asserted as a
universal barrier for future messages. A recv timeout clears its caller before
replying (`ssl_gen_statem.erl:755-759`), so data arriving after timeout and before
new_user stays private. Data obtained by recv instead of timeout rejects the
lease and closes it. The later new_user handler emits no application data.
Thus successful checkout excludes an already-emitted pool data message and
leaves any newly arriving application input private for the new owner's arm.
If closure/error wins, calls fail/discard rather than certify a successful lease.

Under these premises, old and new public arms do not overlap across successful
normal checkin/checkout: at most one unconsumed public **data** message per
live socket, hence at most two for C2, including idle-arm messages. This does
not bound all mailbox controls, failed-request roots, the copied pool mailbox
snapshot, parser/consumer slices or all live payload allocations. Retirement,
process/heap reclamation and their overlap remain P4/P5 work. No runtime race
probe was run and no absolute pool safety/retirement certificate is claimed.

## Remaining closure obligations

1. Enforce and record the actual backend, raw/header0/binary, fixed fresh driver
   buffer and per-connection N selection for every live/reused socket. Do not
   treat constructor options or a pre-start application-env receipt as proof.
2. Prove successful admitted TLS decoding is non-expanding and derive its
   retained output/backing ceiling from the exact native/NIF semantics, covering
   singleton slices and multi-fragment concatenation. The logical encoded bound
   does not compact carried slices or account for native allocation capacity.
3. Compose this per-fragment/handoff result with P2 wrappers, record-buffer
   backing, parser concatenation/carry and consumer release; account for old and
   new roots together. Source-ordering data-message bounds cannot supply a
   guessed pipeline multiplier or complete P4/P5 reclamation proof.
4. Independently review the resulting complete certificate and corroborate the
   enforced runtime profile and transition races with parent-serialized probes.
   All P0-P6 activation gates remain unqualified here.

No product decision, upstream mutation or external blocker is required to
continue those bounded proof tasks. TLS-private accumulation alone is not a
reason to open an upstream issue. The expression above must not be promoted to
production d, backing bytes or a byte reservation while these obligations remain.

## Verification and handoff

Fresh static verification matched all18 OTP and9 repository/receipt hashes in
`h1-delivery-proof.json`, and all three preserved report hashes. Numbered source
reads and activation/toggle inventories completed. Source searches encountered
nonexistent guessed filenames and one read used the worktree rather than OTP
root; corrected reads completed. These were read diagnostics, not runtime
regressions. The first evidence-writing check stopped because it checked the
new JSON link before creating that receipt. The receipt was then created and
the complete static checks passed (one successful evidence repair round; zero
unsuccessful Sol rounds). The accompanying receipt hashes every proof input and
records Markdown/link/fence checks. No executable source, dependency, Mix/VM job,
network probe, upstream object or commit was changed or run.

All own commands finished; parent-managed jobs were untouched. Cumulative
unsuccessful Sol repair rounds0; received Astra repair counter0. No escalation
gate applies. Delivery/backing/reservation and managed H1/H2 activation remain
**NOT ESTABLISHED** despite completion of this bounded source report.
