# M3 H1 0.21.2 complete accounting closure contract

Date: 2026-10-11 Asia/Shanghai. Task `m3_h1_complete_0_21_2_architecture`;
mode **architecture**, gate **PROJECT_ARCHITECTURE**. The parent assigned the
complete object/phase contract and finite execution plan; this is not an
implementation recovery. Baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`,
branch `codex/m3-gateway`, worktree `.trees/m3-gateway`.

## Decision and exact stopping condition

Use one closed-world ledger and one executable qualification fixture. Retain
G4/C2/R32/P0, compact bounded sources, nil/PID upload, numeric destination pin,
explicit H1, manual redirects, raw streaming, and the fixed 8192 socket profile.
Do not restart the accepted constructor lemmas. Every object below belongs to
a phase and an owner; every release needs its own evidence.

**The complete numeric bound cannot currently be evaluated.** Exact generated
native configuration/ABI and the native deferred timer/monitor/signal frontier
are missing. The supported public API supplies neither those constants nor an
old-control consumption certificate. The existing source worksheets do not
prove that frontier. This is an evidenced qualification impasse, not evidence
of unbounded H1 retention or an upstream bug. A list of passing partial lemmas,
the 22-test lease model, and the 39 functional cases do not change that result.

The deliverable here is the complete closure contract, including explicit
blocking inputs N0–N8 and release obligations Q0–Q5. It is **not** a completed
P0–P6 proof. No production reservation, evaluation-success API or Task4 runtime
edit is authorized by this document. The finite plan has an early native-input
checkpoint so execution cannot become another open-ended sequence of partial
worksheets. Missing inputs end the numerical lane with a precise blocker;
the separate functional Slice B can still expose defects.

The alternatives are: (1) source/ABI-certified accounting with enforced fixture
premises, selected; (2) obtain an upstream conservative accounting/control
contract if the finite source lane cannot close the frontier; (3) replace the
contract with measurements, allowances or rotation, rejected. Option 2 requires
an explicit upstream Feature request, containing release and fresh qualification.
It must not silently become a local dependency patch.

Read with [the transport design](m3-upstream-transport.md),
[the transport plan](../plans/m3-upstream-transport.md),
[the prior frontier](m3-upstream-0.21.1-accounting-frontier.md), and
[the executable follow-on plan](../plans/m3-h1-complete-0.21.2-accounting.md).
Existing generic lifecycle interfaces, persistent custodians, immutable route
pins, core isolation, original deadlines, Vault freeze and E2E restrictions
remain binding.

## Cohort and historical lemma rebinding

Published installed cohort: seven packages 0.21.2, tag
`f677ca49519a007a7a551a5a515127c0f29d8ae6`, tree
`664a2a0de2bd4820017599b2d25f62bc7dcf63b0`; parent receipts independently
verify 196 shipped files/175 runtime files, compatibility 486/0 and default
functional 39/39. Supplemental TLS registration is NOT RUN at this assignment's
handoff. These are parent evidence, not executions by this architecture task.
The new [source delta](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/source-delta.json)
changes seven runtime files relative to 0.21.1. In particular, the H1 pool is
not hash-identical to its 0.21.0 proof.

Import a local lemma only when its actual inputs match, with its original
premises. A changed caller invalidates whole-path reuse even when its callee
matches. The appended identity table records the current hashes; preserved
0.21.0 receipts hold the corresponding old hashes.

| Family | Rebinding disposition |
| --- | --- |
| HTTP1 parser, Headers, Trailers, Request, Response, Stream, raw ContentDecoder | Hash-match the historical String/parser receipts. Import local constructor/progress results only. ACK discipline and actual release still need Q2/Q3. |
| Generated String trim/case | Reuse `h1-string-transform-proof.md` and its independent review with matching Elixir generator/data and OTP helper hashes. `U_string` is not reopened; native split/regex/iolist/match scratch is N5. |
| FetchOptions 33-entry HAMT | Reuse `h1-map-layout-proof.md`: 8,984 skeleton bytes per occurrence under W8/L16, plus children. Never apply the flat-map formula to 33 entries. |
| Native normal Binary/ordinary messages | Reuse conditional algebra from `h1-native-object-layout-proof.md`; N0 still prevents certifying the actual layouts. Those classes do not cover monitors, timers, ETS, ports or magic resources. |
| Policy and request normalization | Current Policy hash differs from 0.21.0; `own_policy`, `normalize_request`, `normalize_url`, and `effective_fields` add copies/checks. Count them below, including rejected preparations after copying. Warm CA sharing is only the unchanged OTP lookup lemma, not a claim that owned DER is shared. |
| SocketClient | Changed since 0.21.0. Rebind actual H1 branch, including capacity error handling; old whole-file identity is inapplicable. |
| Tracker/SSL/dialer/scope/H1 pool | Rebind 0.21.2 TLS registration and handoff, failure-to-unconfirmed propagation and retirement controls. Old κ9/17-call/128-cancel/6-retirement totals are not whole-cohort bounds. |

Historical source/review files live under
`docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/`; preserve them.
Their old issue95 status is historical. In 0.21.2 the supported OTP28 socket
shape registers raw TCP plus receiver/sender, and handoff removes all three
from the request tracker while scope monitors remain. Failed TLS setup without
a socket makes cleanup unconfirmed and retires the scope. Neither source
containment nor a normal TLS success qualifies failed-handshake termination.

## Measurement algebra and enforced inputs

Count reachable owned term objects, all distinct retained backing, simultaneous
source/copy/construction roots, and owned native process/closure/message/ETS/
atomics/monitor/timer/port metadata. Exclude unreachable garbage, unused GC
capacity, allocator fragmentation, kernel buffers, VM RSS and TLS-private
allocations. Exposed TLS binary backing, TLS socket terms, and tracking metadata
are included. Immutable global literals/CA snapshot remain excluded only while
immutable; their referencing owned objects and copied children remain included.

For each row record `(phase, owner, object_class, count, term_formula,
backing_origin, copy_edge, release_predicate, source_hash, premise_id)`.
`term_formula` counts parent slots once, adds child objects, and separately adds
native metadata. Distinct offheap backing may be deduplicated by provenance;
otherwise explicitly overcount whole occurrences. No serialized-byte multiplier
or unnamed metadata reserve is admissible. Native missing terms are typed
errors carrying N/Q identifiers, never zero/default numbers.

| Primitive, conditional on N0 | Formula in bytes |
| --- | --- |
| Cons / n-tuple | `16` / `8*(n+1)`, plus children |
| Flat map n≤32 | `8*(4+2*n)`, plus children; normal non-DEBUG cutoff |
| HAMT n, L16 | `8*(33*n+2+2*floor(n/2))`, plus children; conservative collision bound |
| Heap binary b≤64 | `16+8*ceil(b/8)` including payload |
| Ordinary offheap occurrence | `64` wrapper bytes plus distinct backing `C_Binary+capacity`; driver allocation adds its proved padding≤7 |
| k-bit normalized bignum | `8*(1+ceil(k/64))`; conversion and arithmetic scratch separate |
| Closure e captured slots | `8*(2+e)` plus captured children; e needs compiled identity |
| Message | Actual selected reference + fragments + payload representation; ordinary conditional reference 40/48, fragment header40; special signals use N2 |

Let H=65,536, F=65,536, h≤253, request fields≤256, trailers≤128, DER
count≤128 and aggregate DER≤1,048,576 with each≤65,536. Use existing pure
manifests, including their own representation. Fixed options use atom keys,
no arbitrary URI structs, callbacks, iodata bodies, content-type convenience,
file/PEM passthrough or client keys. Any bounded external file reader precedes
the compact DER boundary and needs a separate charged source slot.

The fixture pre-acquires one of 32 attempts before copying/capturing or calling
Fetch. A fixed set of 32 source/guardian actors per generation prevents an
unbounded admission mailbox; rejection returns scalar identity only. One
persistent custodian opens each scope after acquiring a G4 slot. Prepared,
retiring and uncertain generations consume G slots. No new attempt releases
the previous attempt's roots merely by taking the same slot.

Use the canonical 14-key Fetch mapping in the historical request/wire proof,
including `telemetry: false`, and never pass `http2_profile` into an H1 Fetch
call. Public independently created upload streams must have a qualified
telemetry configuration: use supported `HTTP.Stream.start_link/1` with the
pre-established immutable disabled HTTP telemetry profile, or separately price
every attached handler. Do not call its `@doc false` overload to manufacture a
supported API. Runtime tracing, live code replacement and profile/CA mutation
invalidate this certificate and require drain/requalification.

## P0–P4 end-to-end phase and object ledger

`Q0` means scope/attempt pre-reservation and compact source ownership; `Q1`
means helper exit plus local source/result/manifest release; `Q2` means actual
stream credit plus previous-consumer-root release before ACK; `Q3` means public
request completion plus local roots/helpers released and P5 frontier certified;
`Q4` means public scope retirement plus custodian/helper/root release and P5
frontier; `Q5` is the exact immutable loaded-code/native/socket/CA profile.
These predicates are independent. The model's event names do not prove them.

| Phase / concrete path | Included objects, backing and copies | Count/shape rule and release |
| --- | --- | --- |
| G0 policy source → `ManagedH1Preparation.policy` | Source map, compact origin/DER, parsed URI, SNI, normalized policy, source/owned manifests, list reversals and validation helpers | One per G slot. Canonical HTTPS occurrence: `24+c+h` cons,22 pairs, Policy7 and address children; source+copied DER≤2 MiB. URI/N5 and transient roots additional. Q0/Q1. |
| G1 public `ManagedTransport.open` → `Policy.freeze` | Canonical options; origin parse/downcase; validations; accepted own(origin scheme/host); recursive own_policy SSL/sockets; tuple→list→tuple temporaries; transport8; deterministic ETF and SHA256 result; supervisor child map/start arguments | Charge source and each new binary copy separately. For each tuple arity a copied by own_policy: new `(a+1)` words plus `a` conversion cons and `a` mapped cons, recursively; each list element adds one mapped cons. Fixed HTTP SSL=[] branch never calls CA. HTTPS eager lookup needs warm immutable snapshot. N5/N6/Q5; Q1 only after opening result capture is released. |
| G2 scope initialization/steady state | Scope coordinator, H1 pool, idle H2 pool, H2 supervisor; creator/three-child monitors and links; ingress/config ETS; gate and latch atomics; scope/handle/receipt maps; injected policy and key | Four upstream processes per scope, two ETS tables,32 ingress tuples of arity5,one configuration tuple arity3, two atomics resources of length1. Scope policy + config row + startup/custodian/handle copies are separate occurrences. H2 pool exists even in H1 profile. N1/N3/N4; Q4. |
| A0 compact request → pure request preparation | Source7/canonical9 maps; URL/target/field/trailer copies, URI captures, two pair spines, validation byte lists, constructor manifest | Existing bound: q=f+t, skeleton≤96q; owned binary occurrences≤770; source+owned payload≤393,214. This does not include URI/native/manifest peaks. One bounded source per outer attempt before transfer; Q0/Q1. |
| A1 `HTTP.fetch` → options/request → managed prepare | URI9, Headers2, FetchOptions33 and update roots, User-Agent, Request9, supplied14-pair map list, ETS lookup copy, merged keyword variants10/16/23/24/25 | Charge each map version/copy edge, not only last Request. Fetch constructors precede upstream claim. Nil/PID and fixed atom keys exclude iodata/content-type/string-key normalization branches. N3/N5; all rejected branches keep outer lease. |
| A2 `Policy.normalize_request/effective_fields` | Up to257 initial field spine; URL scheme/host/path/query copied before aggregate rejection; accepted256 copied field pairs and Headers; synthetic User-Agent/Host/Connection/framing; temporary effective header tree and target | Normalize_url precedes aggregate check; own headers precedes effective check. Canonical success does not imply upstream success. Include old URL/headers, new copies and generated effective fields simultaneously. Same constructors recur at actual wire serialization; do not share fictional results. Q1/Q3. |
| A3 completion/tracker/task launch | Completion4/Promise3, latch atomics, tracker state/resources/completed maps, starter monitor; launch fun/request copies to Task supervisor/task; task monitor/alias/result | Tracker/task are created even after preparation rejection. Synchronous return of Promise does not release task captures. N1/N2/N4; Q3. |
| A4 owner/fresh dial/reuse | Task retains request; owner closure/request/context9/state17/parser9; owner/launch monitors, one deadline timer; fresh dial closure with host/port/policy opts/selection; offer/transfer/result messages | One owner and dial role per attempt; reuse omits dial. C2 slots include connecting and retained resources. Socket success, handoff and worker exit are distinct. Reuse copies existing socket handle terms, not the port. N1/N2/N7; Q3/Q4. |
| A5 head write / PID upload | Request retained; rebuilt request target and head iodata; nil path send-worker closure/copy; PID path writer closure/head/Headers, writer state7/handle4; upload source mailbox can receive first chunk before head send | Source, sender and native public-send representations coexist. Head/helper formula uses actual f/R/target/method constructors in old wire lemma with current effective-field call. PID writer replaces the nil-body send role; charging both is an explicit conservative duplicate. N5/N7/Q1. |
| A6 repeated upload | Compact current≤F plus bounded next-read source; producer→stream→writer message/terms; four-cons chunk frame, hex≤5, wire≤F+9; one finish, trailer trees and final wire≤65,539 | One outstanding chunk; producer retains source until ACK, writer ACK follows successful send. Charge overlap at each edge; release-before-next-read or one separately charged next-read slot. No body-lifetime count quota. N2/N7/Q2. |
| A7 receive/append/parse | Raw delivery, carry, new append, retained earlier head, parser map/version/status/remaining; event accumulator/reverse, header/trailer line splits/transforms and numeric intermediates | Cleartext conditional d=8192,K=10922,T=H+d=73728,A=max(K,256,2T)=147456. Three append operands≤2A+K; earlier head adds A. E≤T+3 events, two spines+event tuples≤64E; disjoint small body copies≤T. Other roots/copies remain separate. TLS substitutes certified d/K below. N5/Q2/Q5. |
| A8 owner→response stream→task→consumer | Full event batch retained while each chunk blocks; Response/status/header/URI; stream state/queue/pending ACK; reader message, consumer current chunk; old head/trailer/error roots | Separate sender/receiver term representations; offheap backing shared only where proved. Non-ACK reader is forbidden. Current batch, retained head and previous consumer chunk cannot be collapsed to one buffer. Consumer releases old chunk before ACK, terminal metadata before Q3. |
| A9 done/error/checkin | Done surplus≤T, final trailers/error tree, Response/result copies; pool pending/idle entry and transferred socket; send/upload cleanup; tracker latch transition | Nonempty terminal remainder prevents checkin. Errors may retain codings/name/stack arguments. Pool/socket lifetime transfers to G/connection ledger; request handle copies remain A-local. Public completion latch2 alone precedes tracker final stop. N1/N2/N5; Q3. |
| G3 retire/abort/uncertain | Original receipt/latch; fixed helper captures/results/monitors; close_idle/settle/reconcile controls, port/TLS tracking, canceled but not reclaimed native objects | One retire initiation and one abort escalation; initial/abort waits each at most once per attempt. Scope and local ownership releases are separate. Pending/unconfirmed keeps reservations; never reopen/retry an uncertain generation as a hidden rotation policy. N2/N7/Q4. |

### Parsing and helper edges that must remain visible

Accepted response fields can reach `floor(H/4)=16384`; malformed CRLF split
can construct `floor(H/2)+1` parts before rejection. Trailers eagerly split
before the128-result cap and may validate field129. Every complete numeric line
uses T, not the8192 incomplete-line limit. Bignum result bytes for n digits
are at most `8*(1+ceil(n/16))`; old/new arithmetic operands and native conversion
scratch are additional. String local results are already solved: downcase≤3b/2,
ASCII case preserves b; trim/split/case constructor formulas and small-copy
sums are imported from the matched String proof. Final-head downcase work
sum≤5H+48 is a per-invocation work envelope, not a response-memory multiplier.

The stream's `total_bytes` increases on every chunk even with telemetry disabled
(`stream.ex:222-226`). Do not price it as a small integer or infer its size from
one F-sized chunk. Matching `erl_term.h` defines ARCH_64 `BIG_ARITY_MAX=65535`;
the prospective conservative retained-result ceiling is `8*(1+65535)` per
bignum occurrence. N5 must prove the actual addition/system_limit/error paths
and old/new operand scratch before using it. This avoids inventing a lifetime
body quota or claiming an unbounded-growth counterexample from integer syntax.

TLS conditional delivery uses the matched delivery/credit/decode worksheets:
`d=N*8192+18437`, `K=max(d,18432,floor(4*8192/3))`, fixed positive N≤100,
`T=H+d`, `A=max(K,256,2T)`. These are **conditional**, requiring the exact
inet/raw/header0/binary profile, credit and decode premises throughout handshake,
active/passive changes and reuse. Header/consumer/copy/root counts are then the
same topology; TLS-independent resource tracking and failure terms differ.
No private scope/socket inspection or sampled delivery maximum establishes Q5.

## P2 native input inventory: finite blocking set

The actual derivation is
`/nix/store/ckl72c9yq125214w0zdglh7cr5jycz9r-erlang-28.5.0.7.drv`, recorded
in `.audit/m3-otp-derivation-current.json`, schema `derivations`; its source is
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`, installed output
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7`.
Its `patches` field is empty, but `postPatch` substitutes the disksup shell;
therefore do not describe the derivation as having no source transformation.
Neither the derivation JSON nor installed exported headers supplies all emulator
translation-unit definitions. Historical `config.h`/target Makefile absence
and unqualified ABI remain actual blocking inputs.

| ID | Exact missing input / native objects and entry paths | Required certificate output |
| --- | --- | --- |
| N0 build/ABI | Generated emulator `erts/x86_64-pc-linux-gnu/config.h`, generated target Makefile, effective wrapper/compiler flags/includes, ABI packing/alignment, atomic and USE_VM_PROBES selections, actual emulator/NIF identities | Match/reproduce this derivation's configuration and selected translation units; `sizeof/alignof/offsetof` for used types, linked to installed artifacts. Loaded file hashes alone cannot establish this. |
| N1 process/copy | `erl_process.h` Process and reachable process-specific auxiliaries; `erl_fun.h`; `copy.c`; `erl_gc.c`; compiled closures/stack roots for listed roles; DynamicSupervisor/Task child ownership | Per role native base and live auxiliary formulas, exact captures/stack-root upper bounds, spawn/ETS/message/GC copy-overlap rules. Exclude unused heap/stack capacity only under the approved boundary; include reachable duplicated objects. |
| N2 signals/refs/monitors | `erl_monitor_link.h`, `erl_proc_sig_queue.[ch]`, `erl_message.[ch]`, `erl_bif_unique.c`, gen call aliases/receive markers, port monitors, link/unlink/exit/demonitor signals | Selected ordinary/magic reference, monitor/link/alias, marker, ordinary/special signal layouts and ownership lifetimes. A DOWN term formula is not the monitor allocation formula. |
| N3 ETS | `erl_db.h`, `erl_db_hash.[ch]`, `erl_db_util.[ch]`; ingress public set with write_concurrency, config protected set with read_concurrency; tab2list/select_replace/select_count/lookup | Table/locks/buckets/segments/rows/resize/fixation and traversal/match-program scratch functions for32 ingress rows and one config row, plus concurrent caller copies. Physical row bounds must include resize versions and deferred destruction. |
| N4 atomics/magic resources | `erl_bif_atomics.c:AtomicsRef`, `erl_binary.h` magic binary, `erl_term.h` magic reference | For length n, payload `offsetof(AtomicsRef,v)+n*sizeof(erts_atomic64_t)` plus actual magic allocation/reference/destructor metadata. n=1 for each latch/gate; do not use normal Binary header in place of magic layout. |
| N5 bounded helpers | `erl_bif_re.c`/linked regex engine for URI and fixed trailer OWS; `erl_iolist.c`, binary split/search/match/restart objects; `big.c` plus preloaded integer helpers; `external.c`, crypto hash entry; map/copy yield states; bounded exception/stacktrace paths | Worst reachable native workspace and output capacity for each bounded argument grammar, including trap/yield state and failure, plus finite call/root multiplicity from the phase table. Returned capture/split/result bounds do not price native scratch. Include total_bytes arithmetic. |
| N6 CA/profile/loaded code | Warm `pubkey_os_cacerts` snapshot and immutability; generated String/code/BEAM compilation path; no mutable handlers/tracing; supported backend/socket constructor and every subsequent setopts | Validated lifetime deployment/profile predicate Q5. Cold load or snapshot replacement is not within bounded DER grammar; reject profile before preparing managed scopes or separately qualify the full loader. |
| N7 port/public send/TLS boundary | `io.c`, `erl_port.h`, `drivers/common/inet_drv.c`, `erl_io_queue.c`; gen_tcp send iovec/queued data; public SSL send call/message and error result; tracked TLS handle/monitor metadata | Local port/driver metadata, in-flight send fragments/backing, send-return versus ownership-release rule; receive/EOF/error/control payload bounds. TLS-private heap exclusion cannot swallow the external caller message or delivered/error term. |
| N8 timer/deferred reclamation | `erl_hl_timer.c` ACTIVE→TIMED_OUT before enqueue; canceled timer queues; timer-service executors and their limits; `erl_proc_sig_queue.c` offheap buffers, monitor/delete deferred work | History-independent ceilings for pending expiry/cancel/demonitor/exit objects and queued old generations, exact executor/profile input, non-yield/reclamation/ordering proof. This is missing semantic evidence as well as layout evidence; measuring sizeof cannot close it. |

Each N row is a precise missing native/profile input, not a numeric constant to
be supplied by callers. If its source cannot yield a finite contract, record
the exact unresolved operation and request a documented upstream contract. Do
not label absent local build evidence an upstream implementation defect.

## P5 control ledger and the release impasse

For class j, prove `outstanding_j = emitted_j - consumed_or_released_j` bounded
independently of completed requests. R means outer attempts still charged for
their included controls, **not** just the scope's active_requests snapshot.
No unbounded polling, retry callers, diagnostic messages or external direct
messages are in the fixture grammar. Scope lifetime has one open, one retire,
one abort escalation and a fixed scenario-declared snapshot count; each call
has a reserved helper and result slot.

| Control family / current source | Producer ceiling and payload | Release/frontier obligation |
| --- | --- | --- |
| Fetch/task/owner/dial/send/upload launch, offer, transfer, result, attachment | Fixed once-per-role edges in A3–A6; two stream attachments at most. Request/policy/head/socket copies are charged in the phase table | Fresh helper's mailbox ends with the helper; helper DOWN does not release copies already sent to another recipient. Q1 plus N1/N2. |
| Tracker and scope resource registration | Conservative union: ≤11 distinct fixed-path resources including optional enumerable producer and two TLS workers; ≤12 registration calls allows repeated raw-TCP registration during TLS setup. Manual fixture producer is separately owned, not falsely registered | Scope deduplicates existing identities; tracker calls scope before local dedup. Count calls even when registration deduplicates. Old resource DOWN/deferred monitor release needs N8 before attempt reuse. |
| Tracker fixed calls, completion/unconfirmed/abort | Registration≤12 plus prior fixed bind/stream-ready/handoff/complete union≤8 gives≤20 call emissions per attempt, deliberately overcounting mutually exclusive paths. One external abort_wait only; no retry fanout | Latch2 is set before tracker stop; completion does not imply every scope DOWN/control consumed. Unconfirmed-TLS casts also reach scope; preserve sticky uncertainty. These emission bounds alone are not outstanding-byte bounds. |
| Scope connection slots, connect_done, request/resource DOWN | C2 slots; one connect_start/connect_done per fresh attempt,≤one DOWN per monitor occurrence; creator1/children3 per scope | Slots wait for done/socket/dials/resources; nonconnection scope resources need the separate old-DOWN frontier. Requests free on tracker DOWN, not on proof of native reclamation. |
| Scope reconcile | One successor scheduled after consuming predecessor, so scheduled/unconsumed reconcile token≤1 | Native expired/canceled timer allocation and signal metadata still N8; one logical token does not imply one native allocation. |
| Scope retirement/settle/close_idle | Original seeds: retire/abort2+creator1+children3; add every current 0.21.2 `:unconfirmed` cast. `retire` may recast close_idle before stopping | Unconfirmed makes scope non-open, preventing future normal admission. Count racing already-reserved attempts and every failure branch, with no literal old6 total. N8 must cover native controls after all logical seeds are consumed. |
| H1 checkout/prepare/activate | ≤3 calls per attempt; pending/idle entries≤C2; keys/socket handles bounded by policy/connection rows | Timed-out GenServer.call leaves target call queued; alias deactivation affects reply, not target consumption. A completed later call is not automatically a cross-sender drain. |
| Pool pending/idle expiry and entry monitors |≤2 expiry emissions/entry occurrence, one owner monitor; current entry timers≤C2 | demonitor[:flush] closes matching logical DOWN residue; cancel_timer(false) does not acknowledge expiry enqueue. N8 separately bounds stale entry generations and deferred metadata. |
| Socket active-once / transfer / EOF / error | Existing credit proof gives ≤one unconsumed normal data message per live connection under sole arming and successful handoff; terminal signals are separate | Trace fixed TCP/SSL setopts/recv/controlling_process paths; N7/N8 must cover discarded/closing old sockets and native terminal controls. No private flush. |
| Pool mailbox snapshot | `queued_socket_event?` copies whole messages list, up to C2 scans in one checkout callback | With M certified messages, include both original message roots and each simultaneous copied payload/list representation; for a conservative bound charge C full snapshots. M depends on all P5 rows, so this row cannot independently close them. |
| Stream chunk/read/ACK/end/trailer/error and monitors | One current data credit per controlled direction, one terminal sequence; chunk and reader monitor operations repeat | User-message credit does not bound deferred demonitor metadata across many chunks. Q2 and N8 are required even within one long request; finite request count alone is insufficient. |
| Request/scope wait helpers, deadlines and call aliases | One initial and one abort wait/attempt; fixed per-generation helpers. Internal receive-after polling in await is one invocation/monitor, not a new monitor each10ms | Native monitor cleanup after helper return is N2/N8. Absolute deadline never resets; pending/unconfirmed retain ownership. |

Concrete counterexamples to *invalid inference*, not leak claims:

1. N8's `bif_timer_timeout` sets TIMED_OUT before allocating/enqueueing expiry.
   A racing cancellation can return false during that interval. Thus false
   cannot authorize `control_frontier_released`. The generic GenServer receive
   drains already-enqueued infos, but does not count native pre-enqueue objects.
2. `RequestLifecycle.settle` writes latch2 then returns `{:stop,...}`;
   `RequestCompletion.wait` immediately accepts latch2. Thus successful public
   completion alone is not tracker termination or native reclamation evidence.
3. `Process.info(self(), :messages)` observes/copies; it consumes nothing.
   A zero aggregate resource snapshot also exposes no timer/alias history.

No arbitrary-repeat retention counterexample is established. The exact missing
public capability, should N8 fail to close, is either a documented conservative
history-independent native/control accounting envelope for the controlled
profile, or a supported acknowledged control-quiescence operation with defined
included objects and ordering. Request it as **Feature**, severity blocker for
numeric accounting, from `gsmlg-dev/http_fetch`, requesting repo
`gsmlg-opt/gaoxy` branch `codex/m3-gateway`; include these three nonimplications
and the required contract. Do not claim timer leak/security exposure. The parent
owns issue creation and the required callsite TODO after a definite routing
decision; this read-only/network-excluded assignment creates no issue.

## P6 composition and gates

Once every row has a reviewed expression and enforced premises:

```text
B_scope(profile) = B_fixed + B_policy_peak
                 + 2*B_connection_external_peak
                 + 32*B_attempt_peak + B_shared_control_peak
B_instance = B_manager_and_participants
           + sum(B_scope(profile_g), g in all reserved G slots), G <= 4
```

`B_attempt_peak` is the conservative sum of bounded one-shot A0–A5/A9 peaks,
plus the jointly live A6–A8 credit frontier, plus role/process/native costs.
One-shot constructor sums deliberately overcount mutually exclusive phases.
Repeated chunks/reuse are charged by the invariant, never total historical
allocations. Distinct connection backing remains connection-owned across pool
handoff; request-local handle/wrapper copies remain attempt-owned. Include
fixture guardian/source/consumer/custodian/control roles and future manager/
participant roles explicitly; no role is free because absent from upstream.
Existing64-participant instance bound is separate from G4 and needs its own
representation, not another unbounded registry.

| Obligation | Completed design/local facts | Missing acceptance |
| --- | --- | --- |
| P0 | Fixed grammar, exact pre-reservation point, role/owner edges | Slice B Q0/Q1 and later real ingress source/backing conformance |
| P1 | Conditional raw/TLS delivery/append arithmetic, explicit profile inputs | Q5 and failure/ownership/terminal-path certificate N7/N8; TLS supplemental |
| P2 | Term/String/HAMT/ordinary message local algebra reused; all native classes inventoried | N0–N8 certificates and compiled role/copy inventory |
| P3 | 0.21.2 recursive own-policy/request-copy phases and source overlap specified | N5 helper peaks, N6 immutable warm profile, exact simultaneous occurrence table |
| P4 | Complete A/G root/copy/release topology and repeated-credit requirements | Fixture Q1/Q2/Q3 enforcement and compiled/native helper/root proof |
| P5 | Every control family has producer and release dependency; three false-release inferences refuted | N8 plus Q3/Q4 executable mapping; no full turnover induction yet |
| P6 | Explicit object partition and G4 expression with unknown-error rule | Numeric evaluation NOT RUN; independent complete-ledger review and fixture conformance |

Task4 remains blocked until applicable P0–P6 and lifetime contract qualification
pass. Task4 must then prove actual Connection/Session/adapter/manager/custodian
conformance; fixture-only Q predicates do not certify production. H2, both
≥600-second managed protocol soaks, browser/independent-peer requirements,
trust/destination policy and M3 completion keep their separate gates.

## Self-review and assignment verification

Self-review: no old constructor proof restarted, no native unknown defaulted,
no effective-header acceptance inferred from pure canonicalization, no body
chunk cap misapplied to EOF/content-length, no response256-field assumption,
no TLS-private exclusion extended to exposed backing, no pure-model release
event treated as runtime evidence. The closed-world inventory includes unused
H2 scope children, telemetry counter bignums, repeated chunk monitors, mailbox
snapshot copies and rejected preparation roots.

Only this file and its companion plan are assigned writes. At start the four
tracked accounting/pin/lock edits, new 0.21.2 evidence, two qualification plans
and TLS peer/probe were pre-existing and left untouched. Static hash, link,
fence and whitespace validation is recorded at handoff. A mistaken initial read
of Policy under `http_fetch` returned ENOENT; the discovered `http_runtime` path
was read successfully. No VM/Mix/formatter/network/acquisition/Git mutation or
background command was run. Architecture repair rounds0; received Sol recovery
counter not applicable. Architecture completion does not imply accounting PASS.

## Rechecked source identities

SHA-256, current read-only checkpoint. `OTP/` denotes the exact Nix source
root above. Static revalidation matched all105 historical OTP/Elixir/helper
source comparisons selected from String/parser/decode/native/map receipts.
This verifies input identity, not compiled reproduction or complete accounting.
Generated source-tree config.h and emulator target Makefile are absent at the
exact N0 paths; the referenced native source filenames exist.

| Input | SHA-256 |
| --- | --- |
| `AGENTS.md` | `c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed` |
| `.audit/m3-otp-derivation-current.json` | `928a83d6617ddf0dfc7f4bc9d2720a85680f1f4e0517ebfbbc04aba99e0503c8` |
| `deps/http_runtime/lib/http/managed_transport/policy.ex` | `248f6091799727d6c43589585c8eacfc4d72b92ee6b3663298899468e1f1ad14` |
| `deps/http_runtime/lib/http/managed_transport/scope.ex` | `eebb773bdd3bf08523fbaa295e40bdb402b05c94acd1dfaf9dc40b26c912c967` |
| `deps/http_runtime/lib/http/managed_transport.ex` | `8de7281cd7fb7177ef9efe590b8697dbfc2245ace63edfa75bfb08ca8abd659a` |
| `deps/http_runtime/lib/http/http1/pool.ex` | `d7ef7edbd880fed75ebc1f1b043fba47524af658d6b7e62a4c78ebb0a7542978` |
| `deps/http_runtime/lib/http/runtime/dialer.ex` | `bcbd4263b27d92097366c20b8d72a56c954ba468681f7120e1a9a7c814e30cba` |
| `deps/http_core/lib/http/request_lifecycle.ex` | `7ea6f109aea3c32d556cf02a957cc56f8075a4c89d678645338f789b4edb5a37` |
| `deps/http_core/lib/http/transport/ssl.ex` | `b6a97b20bd0266ef378e7eb101f29acfcbab3a3c6a07e32e58ab63c34e170ba2` |
| `deps/http_core/lib/http/transport/tcp.ex` | `2685ee728c19fc21014972792e5d71560fc8b08f5553b9a3874707fe534a7c9d` |
| `deps/http_core/lib/http/http1.ex` | `c84ddf5081b4d61a824789ebb9f606dc4c6d6aa91b69f233bde3b3c5d3997422` |
| `deps/http_core/lib/http/headers.ex` | `490e85607b4e375323945e984b618319a48b3bc4d08148d2e55195e41d427a4a` |
| `deps/http_core/lib/http/request.ex` | `b097ad2d68d3a4d715dad594f02cc9025b6a17a267175b375a4b7d37bc675dcf` |
| `deps/http_core/lib/http/trailers.ex` | `440b945822366705f2098804657e8ed07b2a5e6dd29be216730a4c8e753dec75` |
| `deps/http_fetch/lib/http.ex` | `b86d8cc723cbab453e04dee8cf2a8bd99ca5a08d638c07a1d677ef501a495f7b` |
| `deps/http_fetch/lib/http/fetch_options.ex` | `8e035e1ec4a8c3afb68731ceb325ddf1cd1b5a780bd1b2a063e3f417241b6061` |
| `deps/http_fetch/lib/http/socket_client.ex` | `32790c3df4be3519957cc31404a8c4b6d533db38a36c02a0010c5f9ad4e004e3` |
| `deps/http_fetch/lib/http/stream.ex` | `552c5951d30c21ce864a77c1a61dc5e8bcda038559040028e4f3282074325d05` |
| `deps/http_fetch/lib/http/http1/upload.ex` | `e55ed4591faf1a0253d2d506dce43d1b3f794f831d48825644045250f3888d65` |
| `deps/http_fetch/lib/http/request_completion.ex` | `2579b9bbae473603227bcf0edc9509adb8c070927d44fb4e141e7d11160bcb9f` |
| `deps/http_fetch/lib/http/content_decoder.ex` | `8c57799ff108637c17c70d94c73f6cea6586ce81eacc80b896646e51d62f9bc8` |
| `deps/http_fetch/lib/http/response.ex` | `0de0db25ab6b211412a94683512674a1f87441761285cb64ec093e9547d895b2` |
| `integration/http_fetch_contract/managed_h1_lease_model.exs` | `0fd4f9fe81dc605ad6265635ddbfce1f4855245df05c73d0bcbe2cc03541dd6d` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-string-transform-proof.md` | `d6b818575aacc4e2a8bed8dd6d990eae24225a866f320bca0f6a657762f8174e` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-map-layout-proof.md` | `094bd03e12eba6440cad29f203b4bd15e507c60e220451e07a45f85c90160b57` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-parser-root-proof.md` | `c47dd42053b2168dfb1c7daf119f9137c34e89c3d2760d3fbaa60ac20e9ea97e` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-request-wire-proof.md` | `9270fe02df98a51a6dcbb8bbc4e1fcb4eecf1d8461b13de732eb9104602103dc` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-control-turnover-proof.md` | `613cf2ed23571f36eb527727b8d574b745fa6cc075b3e8b59e1c42fa7b565604` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-native-object-layout-proof.md` | `cf9b651f77e8514aed1e626e8a2f456484f2ed9ded9c29c43d4d5916e10124e8` |
| `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-policy-ca-overlap-proof.md` | `07cfb87281e5891673238c1614ea0a7d5fd5b89001f8eff0b9ba043e546832cc` |
| `OTP/erts/emulator/beam/erl_term.h` | `1b9d8b240ca04583fdf876baf77d9578cb4c3e91b89e8de434e29b783d240264` |
| `OTP/erts/emulator/beam/erl_hl_timer.c` | `3b80a2872c32e2b719375a7b342215f1ba102d36b2f09e33eceabd72fffdb254` |
| `OTP/erts/emulator/beam/erl_proc_sig_queue.c` | `2d5cc2ce101428130ccb284cdd25e78993cebd34e6dc3a49afa26837903720db` |
| `OTP/erts/emulator/beam/erl_bif_atomics.c` | `bf8ef4bcd6667f5acba223c8d52e41453bc9987f3186a72c939fd18069559948` |

## Execution checkpoint — 2026-10-11

The finite ledger is complete as a static inventory: 72 rows over 14 phases,
with five concrete nonimplication traces and 187 frozen source/evidence hashes.
Independent review passes the inventory while returning `ACCOUNTING_BLOCKED_INPUT`;
this is not complete P0–P6. The original exact Nix unpack/patch/configure phases
were recovered and executed unchanged, and the five original NAR equalities
were verified. Generated configuration inputs are available, but selected-TU
ABI/layout and native lifetime certificates remain unqualified. The original
missing-input description above records the architecture handoff state.

The numerical lane stops on [Feature97](../dependency-requests/http-fetch-managed-h1-control-frontier.md):
N8 cannot follow from the supported public receipts, and no control byte/refund
certificate is established. No further partial worksheet or local workaround
closes that blocker. Independent functional Slice B remains authorized under
[its reviewed specification](../plans/m3-h1-qualification-fixture.md).
