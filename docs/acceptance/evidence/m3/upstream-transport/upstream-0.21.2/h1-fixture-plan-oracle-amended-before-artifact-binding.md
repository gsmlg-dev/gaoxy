# M3 H1 qualification fixture specification

Date: 2026-10-11 Asia/Shanghai. Task `m3_h1_slice_b_fixture_spec`, direct Sol
fixture author (`/root/m3_tls95_fixture_design`). Parent baseline
`b2ac78b518f459ec2c95b7823226640413f2ca95`, branch `codex/m3-gateway`, worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`. Baseline is parent-supplied;
this assignment performs no Git operation.

This concretizes Task2 of the independently reviewed
[complete accounting plan](m3-h1-complete-0.21.2-accounting.md) and its
[approved design](../designs/m3-h1-complete-0.21.2-accounting.md). It owns only
this plan and the [inventory](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-fixture-spec-inventory.json).
Executable implementation, Mix/VM, formatting, peer/network activity and Git are
**NOT RUN**. Independent fixture-spec review must precede code. Functional
Slice B does not close numerical P0–P6, M3, Task4 or activation.

## Concrete implementation prerequisite

Current B13 prerequisite is accepted: scoped22/0 and independent specification
then code-quality review pass for repair2. Exact source identities and the
retained failure/repair trace are in
[h1-no-launch-repair2-independent-review.md](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-no-launch-repair2-independent-review.md).
The unchanged-model requirement below records the initial reviewed specification;
its authorized repair changes no deadline/refund/native-frontier contract.

At that initial checkpoint: **BLOCKED_DESIGN B13: unchanged model lacks
pre-Fetch timeout terminal evidence.**
`expire_attempt/2` sets `outcome=:timed_out, phase=:cleanup_hold`, leaving
`completion=:none`. `reject_attempt` requires `outcome=:pending` and cannot
supply `:not_launched` after expiry. `release_attempt` requires that terminal
value for every nonlaunched attempt. Therefore no existing event sequence can
expire a preparing attempt, release its roots, reuse its slot and test old-nonce
isolation. This remains true with zero issued controls; N8 is not the obstacle
in this particular local-only trace.

The parent has been notified. B13 below specifies the required behavior and an
explicit prerequisite: a parent-assigned, independently reviewed compatibility
change that admits evidence of **no Fetch launch** for an expired local attempt,
without changing its timed-out outcome/deadline or releasing any controls. No
such model change is performed by this writer. The parent confirmed the gap and
will separately assign its repair/review. Preferred smallest repair: extend
`reject_attempt` for an unlaunched `:timed_out/:cleanup_hold` attempt only when
`lost_proof=false` and all controls are `:unused`; set `completion=:not_launched`
and preserve its timed-out outcome, deadline and uncertainty flags. Explicit
root release and existing `release_attempt` then decide reuse. Reject launched,
lost-proof or issued-control paths; test reserved and preparing expiry, stale
nonces and unchanged occupied replacement. Do not implement a
second admission model, fake a frontier, use different operation/request deadlines,
skip B13 or report the baseline20 gate green while this prerequisite is open.
The rest of the public fixture is independently implementable. If the parent
chooses another lawful trace, update/review this specification before code.

## Fixed grammar and public call sequence

Use new files only when the parent assigns their implementation:

- `integration/http_fetch_contract/managed_h1_accounting_fixture.exs`
- `integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs`
- `integration/http_fetch_contract/managed_h1_accounting_peer.py`

No historical peer or helper is imported by the new Python peer. It uses Python
standard-library socket/select/threading/hashlib/json and owns its framing.
Elixir imports only the new fixture and unchanged lease model; Gaoxy's compiled
preparation/accounting modules are already loaded from verified artifacts.
No dependency, adapter, activation API, older test, TLS95 source or proof edits.

Baseline is plain HTTP, origin `http://127.0.0.1:<peer-port>`, numeric route
`{127,0,0,1}`, explicit `:http1`. One peer listener is shared by scopes belonging
to that case; connection numbers are monotonically assigned within its fixed
case array. Use exact seven-key request source and three-key policy source:

```elixir
%{origin: origin, connect_address: {127, 0, 0, 1}, trust: nil}
%{url: url, method: :get, fields: fields, body: nil, trailers: [],
  timeout: remaining_request_ms, connect_timeout: remaining_connect_ms}
```

Call Gaoxy `ManagedH1Preparation.prepare_policy/1` and `prepare_request/2` only
from a reserved source actor. Their returned error is an atom or fixed tuple;
never capture/inspect the rejected payload in a result or exception message.
Pre-reserve G before policy allocation/capture and R before source/manifest,
stream or Fetch allocation. `prepare_policy` supplies the exact open list:
`origin, connect_address, http_version: :http1, tls_backend: :ssl,
http2_profile: :native_v1, max_requests: 32, max_connections: 2, max_pending: 0,
idle_timeout: 30000, ssl: [], socket_opts: sockets`. The socket list is exactly
`[buffer: 8192, recbuf: 8192, sndbuf: 8192, nodelay: true, send_timeout: 30000,
send_timeout_close: true]`. Only the persistent custodian calls public
`HTTP.ManagedTransport.open(policy.open_options)` and keeps its opaque handle.
Do not access any fields of a scope, receipt, completion or Promise task.

The entire Fetch mapping has exactly fourteen atom keys, in this order:

```elixir
HTTP.fetch(prepared.url,
  method: prepared.method, headers: prepared.fields, body: prepared.body,
  duplex: if(is_pid(prepared.body), do: :half, else: nil), request_mode: :proxy,
  redirect: :manual, decode_body: false, stream_response: true, telemetry: false,
  timeout: prepared.timeout, connect_timeout: prepared.connect_timeout,
  transport_scope: original_scope, http_version: :http1, tls_backend: :ssl)
```

`http2_profile` is open-only; passing it to Fetch selects an excluded H2-options
path. No URI structs, callbacks, files/PEM, keys, enumerable/iodata bodies,
string-key options, proxy, content-type convenience or hidden defaults.
Each source actor calls Fetch, immediately gets `HTTP.Promise.completion/1`,
registers the **original** Promise/completion in the coordinator's fixed slot,
and receives registration ACK **before** it calls `HTTP.Promise.await/2`.
Promise.await delegates to Task.await and can exit on timeout; the same caller
catches that exit as a compact failure and still retains the registered cleanup
handle. It is not treated as a documented returned `{:error,:timeout}`.
No chained Promise, private Task polling or completion reconstruction.

A scope retirement initiation helper calls `HTTP.ManagedTransport.retire/2`
once for its mode, registers its original returned receipt and gets registration
ACK before any `await_retired/2`. One graceful operation and at most one abort
escalation per generation. Only public `snapshot/2`, `await_retired/2`,
`HTTP.RequestCompletion.await/2` and `abort_and_await/2` supply observations.
No `@doc false` upstream prepare/admit/pool/tracker/stream-stop calls, private
PID inspection, upstream kill/suspend, tracing, port introspection or direct
latch access. An owned fixture actor may deliberately exit or be stopped.

Before actor creation, the parent establishes immutable global
`Application.get_env(:http_fetch,:telemetry)==false` and
`Application.get_env(:http_runtime,:telemetry)==false` in an isolated run profile.
The fixture checks both and fails closed; it does not mutate application env.
Public `HTTP.Stream.start_link/1` defaults to stream telemetry=true but the
supported global opt-out suppresses its emissions. Do not call its hidden
start_link overload. No handler/profile/CA replacement, live code reload or
runtime tracing is admitted. Request telemetry:false alone does not qualify an
independently created upload stream.

## Ownership and finite capacity

Each test gets a new coordinator/model state and an isolated peer. Tests run
serially, without persistent registries or proof history across cases. The suite
is a finite functional experiment, not a claim that case-boundary VM cleanup
establishes N8. Retain a final compact `ACCOUNTING_BLOCKED_INPUT` verdict.

| Role / resource | Hard ceiling per generation / case |
| --- | --- |
| Coordinator, ExUnit controller, peer-control actor | One each per case; no extra rejection callers |
| Generation slots, custodians | Four slots; one custodian per occupied slot |
| Source/guardian actors | 32 persistent actors per occupied generation, indexed0..31; combined role, scalar-command mailbox; no actor per rejection |
| Upload producer / response consumer | One each per reserved attempt, max32 each per generation; allocate after R; no pre-read next upload binary |
| Public upload streams | One per PID attempt, max32 per generation; separately charged from producer/consumer actors; link ownership captured |
| Attempt cleanup helpers | Two distinct reserved helpers per attempt: one initial await and one abort-and-await; max64 per generation, never respawn/retry |
| Generation initiation helpers | Two per generation, graceful and abort; open is performed by its persistent custodian |
| Generation retirement-wait helpers | Two per generation, associated with the original receipts and original D; never launch a new caller on pending |
| Public snapshot actor | One persistent actor per generation; three calls maximum per generation, including failure path |
| Peer | One Python process/control channel, one listener, one accept thread, at most8 connection workers/case; sockets/worker slots never exceed8, at most2 live per scope |
| Results/control envelopes | Fixed four generation rows,32 attempt rows/generation,20 suite case rows (TLS runner1), one current operation per helper; no growing nonce/event list |

Fixture Elixir ceiling excluding upstream-created roles is
`3 + 4*(1+32+32+32+64+2+2+1) = 667` simultaneously allocated roles; the
four*32 public upload streams add128 potential public-source processes. This
is a conservative **role count**, not a native byte bound. Scope children,
trackers, tasks, owners, dials, send/upload writers and response streams remain
separate A/G ledger roles, including idle H2 children. Spawn only a declared
role after reservation; role death consumes its fixed slot for the case.
B14 does not respawn a dead actor. Local rejected attempts can release/reuse
their source actor after explicit source/prepared/manifest/chunk release if no
modeled control was issued; B13 needs the prerequisite above.

Actor commands carry `{case_id,generation_slot,attempt_slot,nonce,operation_id}`
and finite enums only. The selected actor builds its predetermined bounded
payload after admission. Bulk data never travels in admission/rejection queues.
There is one command in flight per role, with an ACK before the next command;
every stale reply must include its old nonce. A controller keeps at most one
old nonce in the B13/B20 challenge slot and drops it after the assertion. Result
slots retain exact compact public results plus separate fixture observations:
`public_result`, `published_outcome`, `original_deadline`, `helper_join`,
`local_roots_released`, `data_credit_released`, `native_frontier=unestablished`.
Errors not in the fixed oracle are FAIL; do not stringify arbitrary terms.
Diagnostic payloads and result JSON lines are capped at4096 bytes; file paths
are parent-known fixture paths, not request payloads.

Model real operation controls may record public results/helper release, but
**never** `control_frontier_released` without a separately reviewed N8
certificate. Consequently real attempts/generations remain proof-charged even
after successful functional cleanup. Functional B19 consumes nine distinct R
proof slots rather than recycling them. At case end discard the case-local
model only after preserving its pending-proof counts; report blocked accounting,
not refunded credits. Local source release does not erase a launched request's
completion obligation. No numeric refund or arbitrary turnover certificate.

## Original deadlines and operation budgets

Capture one monotonic case origin t0 after peer ready. Primary deadline=t0+15000,
cleanup deadline=t0+25000, owned fixture shutdown deadline=t0+30000. These are
three predeclared phases; cleanup is not a renewed request/retirement D. A
request reserves `D_req=min(case_primary,t_reserve+10000)` and
`D_connect=min(D_req,t_reserve+3000)` before capture. At Fetch use remaining
positive milliseconds from these originals; no request can be launched after
its deadline. All reply waits, chunk sends, barriers and helper joins take
remaining time from the corresponding original. Local B13 D=t0+200;
B17 retirement D=t0+500. Other retirement D=min(primary,retire_start+3000).
A pending deadline result is immutable; late evidence is stored separately.

Per generation caps: open1, retire1, abort1, snapshot3, retirement await2.
Per attempt caps: Fetch1, Promise await1, initial completion await1, abort wait1,
response reader attachment1, upload finish1; one end/error sequence per stream.
The B12 upload permits three explicitly counted finish validations (two invalid
then one terminal); all other uploads permit one. Public zero-time waits in
cases consume these budgets, rather than adding a
probe plus another caller. Initial wait's returned pending result stays pending;
a later abort_wait may independently return ok. No repeated await/poll callers.
A receipt wait helper may use the dependency's own bounded await loop; fixture
code never replicates it with retries. Peer controls≤64/case, unsolicited peer
receipts≤128/case, all control/event lines≤4096 bytes. These cap whole case
cleanup as well as primary assertions. Baseline suite absolute deadline=run
origin+660000 ms; TLS-only=run origin+45000 ms. ExUnit test timeout=35000 ms,
peer lifetime35000 ms. Parent watchdog preserves already-written failure/cleanup
receipts and only terminates its own fixture jobs, never unrelated jobs.

## Independent peer and wire/data oracle

Launch through `HTTP_FETCH_PEER_PYTHON` (parent verifies interpreter executable
hash) and `--mode h1` or gated `--mode tls-clienthello`. Bind127.0.0.1 port0;
ready includes actual port/protocol/case ID. Finite JSON commands:
`arm`, `release`, `wire_cut`, `close`, `stop`; command includes unique operation
ID. Replies are `ready`, `armed`, `accepted`, `head`, `body`, `sent`, `eof`,
`wire_cut`, `closed`, `stopped`, `failure`. Fixed event slots hold lengths,
SHA256, connection/request IDs, enum phase and counters only. No streamed body
history. Worker exception category is a finite enum; arbitrary repr is forbidden.

`arm` preselects a scenario/subcase in a fixed table, not arbitrary bytes or
URLs in commands. `release` enables a declared peer phase. Peer H1 read buffer
is≤131072; request head ceiling131072, body workspace8192, trailer
workspace65539, emitted response piece≤8192 except explicitly declared finite
B09 fanout8197. Body length per request≤131073; case wire ceiling4MiB; counters
stay fixed-width by rejecting at those finite ceilings. Hash expected bytes in
Python and Elixir independently. Response bodies are `byte(i mod251)` for
positions0..n-1; X/Y upload blocks are ASCII X/Y with exact counts.
Headers use exact ASCII CRLF, no decompression, informational heads or redirects.
Default response is `HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok`.
Held response is chunked head, then `1\r\nh\r\n`, withheld terminal until
release; terminal `0\r\n\r\n`. Upload response is withheld until peer sees the
request's actual terminal framing and validates body length/hash/trailers.

Peer `wire_cut` runs after the originating public result/owned actor barrier:
under worker locks it performs bounded nonblocking drain of readable sockets
and listener, records accept/request/header-byte counters and returns one
acknowledged cut. This establishes bytes through that cut; it cannot certify
future network silence. Every reject also asserts no later request attributable
to the rejected nonce through peer stop and joined worker EOF. Source/data
absence additionally uses fixture launch/producer counters; never infer
"no attempted dial" merely from zero accepted sockets. A reject outcome that
should precede dialing is bound to current source contract, not socket tracing.

One response consumer subscribes with `{:read_chunk,self(),:ack}`. For each
`{:stream_chunk,stream,binary,ref}`, reduce into finite length/hash/count state,
release the binary/current model consumer root in a tail-call boundary, then
send `{:stream_chunk_ack,ref}`. Retain one scalar current ref only; no body list
or second consumer credit. `stream_trailers` is copied into a bounded ordered
metadata oracle (≤128 fields), checked/released before `stream_end`; errors
record exact compact reason. Complete event lists produced by a parser delivery
remain upstream-owned; one socket delivery is never assumed to be one event.
The new peer sends B09's fanout in one send call, but does not claim one TCP
packet or one dependency parser batch. Acceptance is correct full data/order
and sole consumer credit for every public chunk, whatever segmentation occurs.

Upload producer builds one compact binary≤65536 and calls public chunk/3 from
its reserved actor. Next input is scalar `{pattern,length}` until previous
chunk/producer root is released and its ACK result accepted. After last ACK,
finish(stream,[]) once. ACK is a local backpressure/write observation, not remote
receipt; compare peer body digest separately. Preloading B08 may overlap a
pending producer chunk with the head write; the public peer cannot suspend the
private writer or guarantee a blocked kernel send. Its decisive write barrier
is head-before-body on wire, not an inspection of private writer state.

### Initial/effective header oracle

The fixture implements an independent ASCII list oracle; it never calls private
Policy/Request functions. `C(fields)=sum(len(name)+len(value)+32)`.
Pure preparation checks `len(target)+C(supplied)≤65536` and f≤256. Fetch adds
User-Agent if absent *before* managed initial validation. Managed initial check
uses f_after_UA≤256 and
`I=C(after_UA)+len("http")+len("127.0.0.1")+len(path)+len(query-or-empty)≤65536`.
Its URL charge excludes the port and the query separator. Final effective
check is f_effective≤256 and `E=C(effective)+len(target)≤65536`.

Effective fields preserve duplicates except replacement/deletion semantics:
UA default, Host default=`127.0.0.1:<port>`, Connection replaces all instances
with `keep-alive`; nil body deletes Content-Length. PID body with no CL replaces
TE with `chunked` and defaults Content-Type=`application/octet-stream`; one
valid CL retains normalized CL and removes TE. Explicit UA/Host/CT prevent
corresponding default insertion. Record independently serialized effective
header digest/length and ordered fields at the peer; metadata backing remains
bounded. The head wire digest is over exact method/target/version/header bytes;
no 32-byte accounting overhead appears on wire. Use explicit UA=`u`, Host
matching the peer and Connection=`keep-alive` where an exact count is needed.
Generated UA subcases obtain the documented `HTTP.Headers.user_agent(:http_fetch)`
value before request admission under immutable identity; its length/digest is
bounded≤1024 and verified against peer, not hard-coded across runtimes.

Nil query and present-empty query must produce `/b04` and `/b04?`; the latter
adds one target byte while initial I is unchanged. Padding `x-pad` has name5
and variable ASCII p value; compute n by subtracting all other oracle charges,
then assert both calculated charges before launch. Fixture expectations below
are scoped to0.21.2 source and do not use the historical0.21.0 header check.

## Baseline twenty cases

Each heading below is exactly one executed ExUnit test. Subcases use distinct
reserved attempt slots; none skips on failure. Each uses the common failure
cleanup and emits a single fixed case row with assertions and joins. The
inventory supplies per-case generation/attempt/snapshot ceilings; these include
all subcases and cleanup. Final actual counts must be no larger than ceilings.

### B01 — four generation reservations before opening

Acquire four G tokens and hold all four persistent custodians at a scalar
pre-open gate; no policy payload or public open before acquisition. Fifth
reservation returns `:busy` through the existing coordinator, with no new actor,
policy capture or open. Release only G1/G2 to open. G2 launches one held response
and registers graceful retirement; G3 stays preparing; G4's owned local helper
loses its fixture result proof before any public open, making local uncertainty
explicit. Repeat fifth reservation; all four occupied preparing/ready/retiring/
uncertain rows count. Assert unchanged token/root/control counts and open counter2,
never claim upstream cleanup_unconfirmed for G4. End: release held response,
join/retire G1/G2, record pending model-native controls; pre-open G3/G4 terminate
owned roles without fabricating release evidence.

### B02 — local preparing R32 gate

Open one scope. Acquire32 R tokens, give each source actor a compact bounded
request source, retain source root and hold before Fetch. Request33 is a scalar
admission command from the same fixed controller: immediate busy, actor count
unchanged, Fetch/peer request counters zero. Release each local preparation by
explicit rejection and root/manifest release; no modeled attempt control. Assert
all32 roots stayed held until their own release. This covers fixture-local
preparing only; no public preparing_requests or private preparation claim.

### B03 — initial and effective field counts

Eight slots/subcases. Nil request: 256 supplied fields consisting of explicit
UA, Host, Connection plus253 ordered duplicate `x-a: v` entries passes with256
effective fields. Add one extra x-a: pure rejection `:request_limit`, no Fetch.
256 fields with Host+Connection but no UA passes pure input and rejects public
Fetch with `:transport_scope_request_limit` after UA insertion257. 256 with
UA+Connection but no Host rejects after effective Host257. PID request: explicit
UA,Host,Connection,TE=chunked,CT plus251 x-a entries passes256; removing CT and
replacing it with x-a rejects generated CT257; omitting TE in the same way rejects
generated TE257. Final nil request has UA,Host,Connection,CL plus252 x-a: CL
removed on wire, effective255. Assert ordered field digest, no rejected nonce
wire bytes and rejection copies/outer slot held through registered completion
and source release. Accepted PID uploads are one X byte and finish([]).

### B04 — 65536/+1 charges and opaque empty query

Twelve slots. For both `/b04` and `/b04?`, four nil cases: (1) explicit UA,Host,
Connection,x-pad, tune I=65536: pure and Fetch pass, E=65536-13 for nil query or
65536-12 for empty query; (2) I=65537: pure passes but public request_limit;
(3) explicit UA,Host,x-pad, omit Connection, tune E=65536: I=65497 or65496,
public pass and generated Connection52 charged; (4) E=65537: pure/initial pass,
public effective request_limit. Four additional generated-header variants:
withhold UA and Host for nil body and for PID body, exact E=65536 versus65537.
PID oracle includes generated TE/CT/Connection and one X-byte upload; all
initial/pure charges must pass before its effective boundary is tested. Compute
UA using the documented public value and independently compare wire defaults.
Hold canonical source/manifest roots after each rejection until explicit source
release; public rejected copies have only actual completion evidence, never
"freed at admission". Assert exact targets, fields, digests and one-byte
boundary; port length is derived from ready, never assumed five digits.

### B05 — bounded backing and malformed input

Eight local slots, zero Fetch. URL slice longer than64 bytes from a131072-byte parent rejects
`:source_backing_limit`; slice from65536-byte parent compacts and its output's
referenced_byte_size equals logical size. Field value slice from131072 rejects;
one from8192 with name independently compact passes and compacts. Use4096-byte
field slices and check actual referenced backing before the tested call; small
heap-binary copying must not erase the intended large-parent boundary. HTTPS policy
DER slice of4096 from65536-byte parent passes pure trust grammar/copies
compactly (origin uses https, do not open); from65537 rejects source backing. Individual DER backing is capped65536 even
when aggregate trust backing permits1048576.
Invalid `x\r\n` name rejects `:invalid_fields`. Trailer129 short fields rejects
`:trailer_limit` before inspecting the excess tail; malformed128th field must
instead return `:invalid_trailers`. This last pair shares one slot only after
explicit local rejection and roots released, no controls. No cryptographic DER
validity or TLS open is inferred from pure grammar. Error outputs are compact
atoms and never contain parent bytes. Roots include both parent/source and
canonical/manifests until the real local release; invalid payload building is
bounded to the stated sizes even though intentionally outside accepted grammar.

### B06 — retained H1 connection C2

One scope, three distinct R slots. Launch two GETs; await both public response
heads while peer withholds terminal and consumers withhold first chunk ACK.
Peer records two accepted connection IDs and each complete head. Third Fetch
must return `{:error,{:transport_scope_capacity,:connections}}`; record its
completion before Promise await, wire-cut/stop receipts show no third request
or accepted connection. One public snapshot confirms connections2/pending0.
Release both consumers/peer terminals, cleanup originals. This proves held
response capacity; it does not certify actually connecting cleartext.

### B07 — unread stream through graceful retirement

One held response head; leave consumer unattached and first peer chunk unread.
Register graceful retirement receipt. Original completion.await(0) and
await_retired(receipt,0) each return cleanup_pending, consuming the initial
wait slots. Snapshot once; outer attempt/root/proof slot remains occupied.
Attach sole ACK consumer, drain h and terminal, then use the one previously
reserved abort-wait role to request/await cleanup and the second retirement
wait role under original D; require real ok outcomes. Neither stream_end nor
zero snapshot alone releases native frontier. No new wait caller on pending.

### B08 — PID upload, preloaded first chunk and ACK order

Create public upload stream and producer after R. Producer sends one65536-byte
X chunk before Fetch while no reader is attached; fixture producer-started gate
records call in progress, no ACK accepted. Source actor launches POST with PID,
explicit UA/Host/Connection/TE/CT and awaits head/body response only after original
completion registration. Peer head framing must precede all body receipts.
Producer's real chunk return follows writer credit; release X root before
building second input65536 Y, then await its ACK and finish([]). At most one
producer data root/call and one scalar next descriptor. Peer validates131072
body bytes, exact chunk boundaries65536 each and terminal `0\r\n\r\n` before
sending ok response. No assertion orders local send ACK against remote head
receipt wall time, or says peer prevented a kernel write. Assert the actual
wire order, root-before-next-input order and exact chunk ACK sequence instead.

### B09 — one-byte chunk fanout with controlled ACK

Peer sends chunked response head, then one send call containing
`("1\r\na\r\n"*1365)+"0\r\n\r\n"` (8195 bytes), phase receipt carries its
length/hash. Consumer receives first credited chunk and holds ACK at fixture
gate. While held, coordinator sees one current consumer root/ref and no
permission for another local data offer; the controller's invalid second offer
returns exactly `{:error, :ownership_pending}` without another reader/ACK.
This held-chunk refusal is distinct from the coordinator's reservation `:busy`
result. Release by digest/release-root/ACK
order. Drain all actual public events, total1365 ASCII a bytes, ordered trailers
absent, exactly one end, real completion. Record actual delivery/event counts
as finite diagnostics, without requiring1365 callbacks or one delivery/batch.

### B10 — content-length and EOF larger than F

Two requests, separate scopes or peer-close identities as declared: n=131073
pattern bytes. CL head has Content-Length131073; EOF head has Connection:close
and no framing fields, peer performs write shutdown only after final byte.
Send pieces≤8192; consumer accepts every actual public chunk and validates
full rolling digest/length, end and completion. No assertion caps these
framing-mode emitted chunks at65536 or demands a >F socket delivery. This
qualifies total preservation above F under actual segmentation, while the
source ledger separately accounts for a possible large CL/EOF delivery.

### B11 — finite chunk-size lines and real bignum outcome

Four attempts on fresh connections (error branches close): (a) head then8192
ASCII0 bytes, peer phase barrier withholds CRLF; complete with `\r\n\r\n` and
require empty body/end/ok; (b) head then8193 ASCII0, withhold CRLF permanently
until actual stream_error=:line_too_long, then close; (c) complete4096 hex f
line plus `\r\nz\r\n`, peer EOF: size is finite16384-bit positive integer,
all three bytes `z\r\n` are preserved as unfinished chunk data, with exact
length3 and SHA256 `ae7c791a527d756a15cdb11de8c13feefd266a81ea9671d3e65f1e7da00e2e5e`.
Final public stream error=:closed for incomplete chunk;
(d) complete `g\r\n`, actual error=:invalid_chunk_size. The source parser
matches CRLF before incomplete-line guard; case(c) is deliberately below8192
to avoid treating TCP send boundaries as parser deliveries. Case(a) proves
accepted boundary once complete, not prior parser ingestion at the peer barrier.
Record finite source/line/bignum/rejected-input root obligations; don't export
huge integer or full line in diagnostics. Completion expectations are real
registered handles and must be checked separately from stream errors.

### B12 — trailer count, forbidden field and exact wire limit

Five response attempts and one PID-upload slot. Responses use chunked body q
then zero chunk. Trailer128 duplicates `x-t: v000`..`v127` must arrive in order
and precede stream_end. Trailer129 returns trailers_too_large; forbidden
`Content-Length: 1` returns `{:forbidden_trailer,"content-length"}`. Exact
trailer area is `x-t: ` + (p*65527) + `\r\n\r\n`, length65536 including final
blank line; accept and preserve trimmed value/hash. Add one p makes65537 and
returns trailers_too_large (both match-before-bound and buffered-limit paths
have that same public error). Upload POST has Trailer:x-t; finish(stream,
128 duplicate x-t pairs) after one q ACK succeeds and peer observes ordered
terminal trailers. Before that valid finish, finish with129 returns
trailers_too_large and with forbidden name returns exact forbidden_trailer;
these invalid calls do not finish the stream. They consume an explicit **three
finish validations** budget on this B12 upload, superseding the default finish1;
only the final valid invocation emits terminal. Local pure129/malformed cases
remain B05; no internal parser call. Each error attempt uses actual cleanup
terminal before local roots released and carries no invented byte refund.

### B13 — expired pre-Fetch nonce versus occupied replacement

**BLOCKED until the compatibility prerequisite is resolved.** One scope,
persistent source actor0. Acquire old token, retain source/prepared/manifest
roots, hold before Fetch; issue no modeled control, Fetch or stream operation.
Reach original200ms deadline through one bounded receive-after, advance the
model to that real relative time; publish timeout once. Release **all** old
local roots through the same persistent actor's tail-call/ACK barrier; provide
reviewed no-launch terminal evidence. Only then release old local attempt and
acquire replacement in the same slot/new nonce while its source root is held.
Actor sends exactly two deliberately late **fixture-local** scalar messages:
old preparation-success and old root-release nonce. Assert replacement state
and token unchanged, old outcome/deadline in the single challenge slot unchanged,
both messages ignored stale. No fake public Fetch success or model control
result. A separate launched-slot negative trace records a real pending initial
completion control and confirms release_attempt fails ownership_pending even
when local roots vanish; never recycle that slot without N8. Late public data
is tested on distinct retained slots, not as a reason to reuse the old one.

### B14 — owned source/guardian death before and after launch

Two separate generation/attempt pairs. First source actor exits deliberately
at pre-Fetch gate: no Promise/control, source exit is local release evidence
only and fixture result is failed/lost proof as appropriate, never success.
Second actor registers original Promise/completion, receives public response
head and transfers bounded consumer descriptor, then exits deliberately via
owned fixture command. Coordinator retains original cleanup handle and aborts
through its reserved role. No monitor/examination/kill of private upstream PID.
Assert no public outcome fabricated from DOWN, no credit refund, every remaining
owned producer/consumer/control helper and peer joins or reports explicit
cleanup failure. A deliberate actor's declared exit reason is expected; a
missing completion registration or unexpected owned exit is FAIL.

### B15 — retire during local preparing

Reserve source/prepared root and hold before Fetch in one open generation.
Register graceful retirement, close fixture admission, then release the local
preparation gate. Its late prepared value cannot publish or invoke Fetch;
coordinator rejects the launch because generation is retiring, releases local
roots under its own barriers and joins actors. Assert Fetch0/request0 and
original receipt outcome. Also hold a second custodian before open, mark local
retirement, then let its already-authorized open operation return; register the
late real handle, immediately retire/clean it without publishing readiness.
This is fixture-local opening/preparation coverage, never a claim of observing
private upstream preparation. Late original deadline/outcome stay immutable.

### B16 — abort A while B exchanges bytes

Two scopes on shared peer, each with held response. Register originals and sole
consumers. Retire A abort once; record its real receipt/cleanup results. Keep
B alive at ACK barrier, then peer/consumer exchange h and terminal while A
cleanup runs. Assert B digest/end/ok and its original connection ID not closed
by A's retirement. B own graceful retire occurs only after that assertion.
No operation references B during A cleanup; all fixed role/peer joins bounded.

### B17 — original D across graceful and single abort escalation

One held request/stream. Graceful initiation before D=t0+500 registers original
receipt; start initial await until remaining D. Before D, begin exactly one
abort initiation helper and hold it at an **owned fixture pre-call/delivery**
barrier; its operation identity/receipt row is reserved already. Caller returns
fixture cleanup_pending by original D with tolerance≤100ms, with local helper
join evidence pending. Release that owned barrier after D, let the already
issued helper invoke/finish its one public retire(:abort); register actual
returned receipt before its zero-time public wait if any. This is late completion
of an issued operation, not a new escalation or renewed deadline. Preserve
public reply/receipt separately; if retire_call's built-in5000ms duration
outlives D in practice, its helper remains owned until original cleanup end.
Do not guarantee or force private call blocking. No upstream suspension, extra
retire invocation, D replacement, new wait or rewritten caller result. Assert
one graceful/one abort, initial published pending immutable even if cleanup
later confirms. Join late helper/response actors and original request cleanup.

### B18 — public waits versus deliberately lost local proof

Three distinct attempt rows in one scope: successful finite response uses
initial completion await and returns ok; held response initial await(0) returns
cleanup_pending; third finite response performs a real await returning ok but
its owned helper deliberately drops the fixture result delivery before exiting.
Register completion before await in all three. For third preserve actual public
ok in a separate bounded oracle channel **before** deliberately discarding the
expected proof channel, then record fixture lost-proof and pending release.
The pending request is closed through reserved abort_wait; actual public result
is retained unchanged. Graceful receipt wait pending/second abort-mode wait ok
are separately budgeted. Never label local lost proof as a public
cleanup_unconfirmed or inject it into control_result. Genuine upstream
cleanup_unconfirmed is exclusively the failed TLS handshake part of B21.

### B19 — finite reuse with held sibling

One scope, held response on connection1. Execute eight sequential ok responses
on connection2, each in a distinct reserved R proof slot with original cleanup
handle. Consumer end+actual request completion are checked each time before
next Fetch. Peer validates all eight heads and connection identity equality,
no additional dial/accept attributable to those requests; sibling stays held
and resumes successfully after the eighth. Nine attempts total, no proof
credit recycling, numeric turnover claim, body lifetime quota or rotation.
At end native frontier remains unestablished despite functional reuse.

### B20 — operation caps, invalid commands and stale replies

One scope, one held attempt, then completion cleanup. Public snapshot actor
performs exactly three scheduled calls (ready, held, after retire) with bounded
single invocations; the final outcome is either the exact public transport_scope_retired error or
a valid finite snapshot with lifecycle not open; preserve which actual reply
occurred and never retry it. Initial completion await(0), abort_and_await once,
graceful retire once/one allowed abort if required, retirement awaits≤2.
Submit fixture invalid operation enum, duplicate begin-control and old-nonce
result; they must reject/cache/ignore with unchanged helper spawn/call counts
and current result rows. These are fixture validation messages, not arbitrary
unsupported dependency inputs. No polling-created processes/monitors or historical
result append. Fixed result arrays remain same shape, compact serialized output
≤4096 per row, stale-message challenge slot cleared after assertions.

## B21 — separately admitted TLS connecting and failed handshake

This is one **additional, separate invocation**, never a skipped baseline test.
Flag `--tls-connecting --tls95-gate <absolute-json-path>` requires parent-created
TLS gate receipt before registration. Gate exact schema1:
`status="PASS_TLS95_SUPPLEMENTAL"`, `cohort="0.21.2"`, pinned tag/tree, actual
run exit0, candidate executed5/casesPASS5/cleanupPASS5, expected old-baseline
negative oracle established, both tls_h1/tls_h2 registration/handoff verified,
source-before/source-after/loaded-profile digests matched and independent review
PASS. Gate also supplies a hashed absolute path to a disposable test root DER
certificate (nonempty, ≤65536 bytes), consumed from a reserved policy-source
actor by a bounded65537-byte reader before pure compact preparation. It is
never a file/PEM option passed to upstream; no operational certificate issuance. Include hashed paths of actual run logs/results/freezes/review; missing,
NOT RUN, stale or mere static source containment is BLOCKED, not a skipped test.
Parent maps its real TLS receipts into this envelope; this author creates none.

New standard-library peer accepts two raw TCP sockets and reads TLS records
bounded to65536 wire bytes/connection. It validates complete initial handshake
message type1/ClientHello across records using a finite scratch buffer, emits
length/digest plus connection ID, sends no ServerHello/certificate and holds
both sockets behind release gates. Open HTTPS scope with the same frozen numeric
pin/C2/profile, `trust: [fixture_root_der]`, supported verify_peer; actual TLS client handshake
cannot complete while held. Two received ClientHellos plus pending originals
are the deterministic connecting barrier. Third Fetch must fail connection
capacity and cause no third accept/ClientHello. One aggregate snapshot confirms
connections2/pending0; it has no public connecting field and cannot itself prove
phase. Third R slot remains charged through actual completion.

Register graceful then one abort receipt while ClientHellos are held; preserve
all actual public pending/unconfirmed results. Release peer sockets by orderly
EOF without a server handshake. This is a real failed public TLS handshake:
original request completion and generation retirement must expose genuine
`{:error,:cleanup_unconfirmed}` under the0.21.2 source contract once TLS failure
settles; failure to observe it is FAIL, not local proof-loss substitution.
Peer EOF/worker joins do not independently certify OTP TLS-private termination.
If no supported public deterministic barrier achieves these outcomes, preserve
all logs, return exact BLOCKED_CONTRACT to parent and retain the test; no sleep,
private TLS worker inspection or relaxed C2 oracle. B21 certifies TLS connecting
coverage only after TLS95 gate, never cleartext kernel-connect saturation or N8.

## Common success/failure cleanup

Install an after/finally cleanup ledger before first G/source allocation. Every
resource is registered in its preallocated row immediately when acquired; no
await is allowed before original handle registration. Cleanup is attempted
independently for every row even after a primary assertion/registration failure.

1. Close fixture admission and peer production gates. Tell every owned local
   preparing actor to drop bounded source/prepared/manifest/root values and ACK;
   dead owned actor uses its declared DOWN/join evidence, never upstream credit.
2. For each registered completion, issue at most its existing unused abort_wait
   and retain exact returned ok/pending/unconfirmed; a used helper never causes
   a retry. Register late handles from already-issued operations before cleanup.
3. For each real scope use unused graceful/abort operation slots within original
   cleanup deadline. Record original receipts before their remaining wait roles.
   Await every original receipt exactly within its reserved budget; pending or
   unconfirmed is retained as actual evidence. Unconfirmed permitted in B21
   still blocks numerical/termination qualification; unexplained cases FAIL.
4. Join all owned source/guardian, upload producer, consumer, wait, initiation,
   snapshot and custodian actors via their original monitor rows/deadline. Public
   streams are terminated through finish/error/cancellation or reader exit; no
   private stream-stop call. No local actor is free because helper returned.
5. Peer stop performs listener shutdown, release/close of each owned socket,
   joins accept thread and all bounded workers, writes stopped with aggregate
   join counts and zero alive workers, closes channel and exits0. Controller
   confirms child exit and its peer-control actor join. Its bounded forced-owned
   fallback is FAIL and still records prior results; never System.halt the VM.
6. If an original deadline expired, keep published result fixed. Later joins/
   receipts fill separate evidence fields; report cleanup failure when proof is
   absent. A missing late scope/receipt, failed join or unknown owned command is
   BLOCKED_HANDOFF/FAIL, never silently discarded on actor DOWN. Preserve all
   rows plus pending model-native counters and source-after freeze.

Budget exhaustion stops new primary work and attempts existing cleanup slots;
no extra helpers, polling windows or result allocations. Expected owned fault
in B14/B18 is distinguished from unexpected helper exit. Other processes and
parent TLS/native jobs are never inspected/stopped by this fixture.

## Runner, freezes and handoff gates

Exact default CLI is no flags or `--baseline`; TLS CLI is exclusively the flags
above. Unknown flags/env selectors fail. ExUnit starts `autorun:false`,
`max_cases:1`, `seed:21112026`, `timeout:35000`, empty include/exclude filters.
Register exactly B01–B20 for baseline or exactly B21 for admitted TLS; do not
require the model test file (its22 tests are separate). Capture ExUnit.run totals,
actual individual IDs and joins; assert total20/1, failures0, skipped0, excluded0.
Print `H1_ACCOUNTING_FIXTURE_CASE` for each case and
`H1_ACCOUNTING_FIXTURE_SUMMARY` containing test count/IDs, bounded actual actor/
operation counts, public versus local outcomes, numerical blocked status,
cleanup join results and source/profile/run identity. Raise on any count or
outcome mismatch; parent command wrapper records **actual exit code** rather
than trusting a printed exit field. Summary is emitted before the raise, never
by bypassing cleanup or halting the interpreter.

Parent executes only after concrete spec/B13 prerequisite and code independent
review. Establish isolated immutable telemetry=false config via the supported
Mix --config option before dependencies start; parent-generated config contains
only `import Config; config :http_fetch, telemetry: false; config :http_runtime,
telemetry: false` on separate lines and is frozen as an input. It is not created
by this author. Verify selected artifacts already compiled against cohort.

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix format --check-formatted integration/http_fetch_contract/managed_h1_accounting_fixture.exs integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --config .audit/m3-transport/h1-accounting-runtime-config.exs integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs --baseline'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix run --no-compile --config .audit/m3-transport/h1-accounting-runtime-config.exs integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs --tls-connecting --tls95-gate /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/.audit/m3-transport/h1-accounting-tls95-gate.json'
```

TLS gate CLI requires an absolute path as shown.
These are **NOT RUN** proposed commands. No --no-start: real dependencies must
start. Python syntax validation is AST parse only before runtime; no imported
historical helper or new dependency. Parent freezes three new executables,
this plan/inventory, preparation/accounting/model/model-tests, direct manifests,
lock, complete seven-package175 runtime sources and required configs, loaded
BEAM/native/profile/interpreter identities before/after every red/repair/green.
Historical four peer/probe/helper executable inputs and old reports remain
byte-identical; preserve them even though new fixture does not import them.
TLS gate/identity/certificate artifacts (if supplied) join TLS-only freeze.
Any changed/missing input invalidates a run; distinguish newly parent-authorized
model repair from pre-existing pins/TLS/native-ledger changes. New actor/copy
roles require complete-ledger update before numerical acceptance.

Implementation handoff checklist:

- [x] Parent resolves and independently reviews B13 prerequisite without native
  control release or deadline/outcome rewrites; revise frozen model identity.
- [ ] Another Sol independently reviews this concrete specification/inventory,
  including header formulas, public APIs, B08/B09/B11 observation limits,
  B13/B17/B18 and cleanup/budgets; author's self-review is not that verdict.
- [ ] Implement only assigned three executable paths after ownership grant;
  parent runs baseline red, preserves exact case failures, then bounded repair.
- [ ] Code review before fresh green; baseline20/0/no skips/exclusions, real
  exit0 and every declared owned join must pass under matched source/profile.
- [ ] Separate B21 invocation only with real supplemental TLS PASS envelope;
  baseline never registers/skips it. Actual failed-handshake uncertainty required.
- [ ] Complete ledger/N inputs/Q predicates are separately reviewed. Functionally
  passing fixture remains ACCOUNTING_BLOCKED_INPUT while N8/full numeric proof
  is absent; activation_status stays unqualified and Task4 remains conditional.

This author performed static source/API/wire-arithmetic/hash/document checks
only. A first optional telemetry/config search used absent paths; scoped file
lookup located the actual modules, which were read. No test or VM claim follows
from static validation. Plan implementation and independent review are NOT RUN.
Cumulative fixture-spec Sol repair rounds0, unsuccessful0, received Astra0;
TLS tooling, TLS fixture and complete-contract counters remain separate.
All own commands completed synchronously; no owned background process exists.

## Current implementation checkpoint — 2026-10-11

B13's narrow compatibility repair has deterministic RED/GREEN and independent
specification/code-quality PASS, with model22/0 and no skips/exclusions. One
failed independent repair gate is retained; cumulative model counters are
Sol2/unsuccessful1/Astra0. The original reviewed specification and inventory
remain preserved as historical inputs; the parent current inventory rebinds
authorized model/document changes rather than relabeling old hashes as current.

Baseline executable ownership is the three new fixture files. Exactly B01–B20
are under implementation; code review and actual baseline runtime acceptance
remain pending. B21 executable is intentionally deferred and TLS flags must
fail closed before actor/peer/test allocation until its actual gate is ready.
No blocked TLS case is included in the baseline20 count. Numerical acceptance
and production activation remain BLOCKED on Feature97/N8; no actual functional
observation can refund a model native control credit.

### Source-backed B09/B11 oracle amendments

B09 now requires the model's actual held-chunk error `:ownership_pending`;
the earlier draft test incorrectly normalized it to reservation `:busy`.
B11's huge incomplete chunk consumes `z\r\n` as three data bytes because its
declared size has not been reached; those CRLF bytes are not a chunk terminator.
Require their exact length and digest without requiring a particular delivery
segmentation. The peer wire, final `:closed` error, actor budgets and cleanup
obligations are unchanged.

The parent preserved the original plan and test-only RED source, verified the
RED source against its original run manifest, and recorded source pointers in
`../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-fixture-oracle-amendments.json`.
These amendments require independent fixture SPEC then CODE QUALITY review
before actual baseline execution. The prior test-only RED executed zero cases;
it remains absence evidence rather than functional acceptance.
