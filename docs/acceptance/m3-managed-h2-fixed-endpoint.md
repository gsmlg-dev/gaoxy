# M3 managed H2 fixed-endpoint acceptance contract

Status: **DESIGN/PLAN CANDIDATE; ACTIVATION NOT IMPLEMENTED; ALL EXECUTABLE
ACTIVATION GATES NOT RUN**. The [design](../designs/m3-managed-h2-fixed-endpoint.md)
and [implementation plan](../plans/m3-managed-h2-fixed-endpoint.md) are normative.
The parent freezes their exact hashes for independent readiness, then records
actual kickoff/source/evidence inventory before tests-first implementation.

Accepted local preparation predecessor:
`c871e3d9ee87cf802acf764d7d7622e0a7b611d6`, worktree
`.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`.
Preparation complete independent SPEC/CODE PASS, fresh format/strict compile
97/0 and fresh public63/0, exit0, source stable, zero skips/exclusions. Those
are preparation/compatibility outcomes, not fixed-H2 activation acceptance.
Parent owns exact candidate source and environment recording; later admin-only
preparation closure changes do not invent a different accepted source.

Reserved successor evidence root:
`docs/acceptance/evidence/m3/managed-h2-fixed-endpoint/1791956542961215590/`.
Readiness, kickoff, RED/GREEN, diagnosis/repair, independent SPEC/CODE, fresh
gate, browser/network and local-commit receipts belong there when actually
created. No nonexistent receipt is linked or described as passing.

PROJECT_ARCHITECTURE recommendations consume zero recovery; inherited cumulative
Sol/harness/review counters are recorded verbatim at kickoff. Astra recovery2/2
remains exhausted. Continuing authorization selects local execution and next
bounded slice automatically, without routine approval. Publication/deployment,
production data/certificates, Vault, public management and disabled release-
artifact E2E restrictions remain. `http_fetch#97` or equivalent proof is excluded.

## Gate ledger

| Required gate | Required evidence | Current status |
| --- | --- | --- |
| Accepted pure preparation predecessor | Actual commit/source, complete reviews, fresh97/0+63/0 | PASS predecessor only |
| Fixed design/plan independent readiness | Three exact document hashes; complete interface/schema/ledger coverage | NOT RUN |
| Verified execution kickoff | Baseline/diff/untracked/source/lock/cohort; ownership/counters; all writers serialized | NOT RUN |
| Observed tests-first RED | Nonzero actual executed tests before production, preserved failures | NOT RUN |
| Pure envelope/client/reservation and owner tests | Exact/over/malformed/backing, protocol identity, complete slots | NOT RUN |
| Generation exclusion and renderer guards | Both Store paths; public renderer caps and actual Service reserve | NOT RUN |
| Four independent fixed-proxy protocol cells | Native H1/H2 downstream, real TLS-H2/h2c upstream, exact byte/cleanup oracles | NOT RUN |
| Deterministic backpressure/lifecycle | Full write->ACK and original completion release order; uncertainty retained | NOT RUN |
| Separate browser acceptance | Local native TLS/h2 browser navigation/stream/early/error and joins | NOT RUN |
| Existing public compatibility63 assertions | Fresh managed39/completion16/supplement8 with byte-preserved historical sources | NOT RUN for activation candidate |
| Affected H1/H2/H3 and Generation/group compatibility | Named unfiltered scopes, actual counts/exits/source stability | NOT RUN |
| Complete independent SPEC then CODE | Full candidate/evidence, findings resolved and counters preserved | NOT RUN |
| Fresh post-review canonical gates | Format/strict compile/scoped tests/public/network/browser; source-stable | NOT RUN |
| Safe owned shutdown and local commit | Parent commands stopped, helpers joined, stage owned files, actual commit | NOT RUN |

PASS requires actual executed assertions and zero required failures. Preserve
FAIL, BLOCKED and NOT RUN distinctly. A unit mock, public dependency supplement,
marker, prior snapshot or successful teardown cannot substitute for required
live adapter/browser/cleanup evidence. Hosted CI and release/deploy are separate.

## Pure schema and request assertions

- [ ] Exact eight-key envelope: protocol/url/target/method/fields/body_mode/
  request_limits/max_upload_bytes; no original Exchange, socket, arbitrary maps,
  trailer policy, manifest or path/query duplicates. URL/target raw escaping and
  present empty query preserve submitted identity.
- [ ] Source/compact logical/backing bounds before parse/copy; proper list/
  pair/binary grammar;256/65,536 headers and128/65,536 trailers; aggregate
  projection196,608; complete representation205,337. Oversized-backing slices
  reject even when logical payload is small; malformed/improper/expanded maps,
  forged structs and deep/unknown constructor/error values reject before size.
- [ ] Body:none/chunked/length unsigned64; finite methods; exact four-key
  effective minimum request limits; upload1..65,536. Signed64 times/deadlines,
  checked arithmetic, timeout1..86,400,000 and no overflow/scheduling leaks.
- [ ] Nil-body preflight never replaces compact RAW admissible source fields;
  valid Content-Length survives first/middle/last. Final actual-PID preparation
  with generated/supplied Content-Type checks effective native head defaults/
  pseudo fields/CL and complete projections BEFORE any Fetch bytes.
- [ ] Config exact HTTP struct, canonical nine-key URI, four-key transport
  handle and five-key limits, nil request trust/address overrides. TLS-H2
  requiresHTTPS; h2c requiresHTTP; no dedicated-H2 or managed-H3 activation.
  Initialization remains pure; compiled/raw round trips and raw authority/port
  rejection preserve accepted H1 behavior.
- [ ] open/1 exact seven-key map with nested request/client schemas; no aliases
  or extra options. Poll/event receive transient `{four_key_handle,submitted_url}`
  for H2 only. One compact URL occupies the existing Session request slot until
  first head/cleanup; tuple<=128 wrappers, no extra copy/private recovery.
- [ ] Request/selector/awaiting/opening payloads clear after original bind;
  managed_path:true retains original cleanup and mandatory Service receipt after
  managed_transport payload clear. H1/H3 callback arguments remain unchanged.
- [ ] Full transient preparation RETURN is charged: Request<=201,753,
  exact accounting<=3,456, exact manifest<=3,072, wrappers<=128, complete
  total<=205,337. Test maximal constructor facts/fifteen-key limits map; discard
  manifest immediately and never retain two preflight/final returns at once.

## Identity, scope and metadata assertions

- [ ] Owner prepare/request dispatch uses accepted H2 pure modules; owner
  complete policy accounting remains separate. Checkout exact policy/scope/
  fetch-options schema uses exact protocol, SSL/native_v1/reuse/manual/raw/stream
  settings and C2/R32/P0; no per-request override or private native process.
- [ ] Validation AND authenticated delegation include protocol+scheme/host/port/
  instance; H1/h2c identical authority cannot alias. Wrong protocol/authority/
  instance/epoch/resource/holder/operation rejects before checkout/Fetch.
  Captured pins preserve original identity; late/cancelled handoffs are revoked.
- [ ] H2 groups/probes remain explicitly rejected. Optional protocol-neutral
  Endpoint.generation_validate hook rejects H2 through Store preparation AND
  activation/forged prepared routers; static fixed Router.compile remains
  allowed. Old endpoints default :ok; H1 Generation remains qualified; no core
  dependency on proxy modules.
- [ ] Exact public Response13 fields+tag, final HTTP2 status200..599, bounded
  flags/type/status-text64, body nil/empty/consistent stream PID and no buffered
  bytes. Exact Headers wrapper, empty immutable streamed trailers, URL nil or
  bounded submitted-derived canonical URI; malicious URL/protocol/extra key
  rejects before head. Drop full Response/unused metadata after head extraction.
- [ ] Initial heads<=256/65,536 logical/backing before cache/policy; info<=128
  ordered blocks, aggregate fields<=2,048 and name+value+32<=65,536, exact wrappers;
  extra metadata213,965 excludes separately charged heads. Invalid status,
  improper lists, excess info/head or retained backing rejects.
- [ ] Current/original handles EXACT four keys; finite Promise/Task shells,
  original completion identity never substituted by resolved/current request.
  No Response or URL in shell; opaque scope/completion interiors never serialized.
- [ ] Pump-only exact request/response trailer policies; source Trailer and
  Connection token counts128 BEFORE dedup, allowed128/dropped265, retained
  payload65,642/complete policy67,689. Bounded token/declaration workspaces,
  forbidden/untrusted filtering and ordered duplicate actual trailers preserved.
  Downstream declaration names remain through Exchange/FramedResponse completion/
  cleanup. Native-valid129 terminal fields reject before Session cache/handoff.

## Complete reservation and renderer assertions

All values below remain **PROPOSED/UNACCEPTED** until executable enforcement,
independent review and fresh gates pass. Unit is bounded complete ETF payload,
not heap/native/VM/OS/kernel/process memory.

| Charge | Formula | Bytes |
| --- | --- | ---: |
| Request representations | 5*205337 | 1026685 |
| Fixed configs | 5*147456 | 737280 |
| Checked policies | 2*1183744 | 2367488 |
| Pump trailer policies | 2*67689 | 135378 |
| Retained downstream declaration | N(128,65536) | 66183 |
| Heads | 4F(256,65536) | 274460 |
| Terminal trailer lists | 4F(128,65536) | 268316 |
| DATA | 3B(1048576) | 3145746 |
| Upload | 2B(65536) | 131084 |
| Downstream DATA piece | B(16384) | 16390 |
| Public extra metadata | Complete projection | 213965 |
| Proxy scratch | 3F(256,65536)+2N(393,65642)+2B(65536) | 472157 |
| Closed controls | 16384+8192+2*4096+16*2048 | 65536 |
| Proxy subtotal | Sum | **8920668** |
| Bounded public downstream renderer | Unified cap above H1/H2 complete sums | **524288** |
| Service activation reserve/request | Sum | **9444956** |
| R32 allowance | 32*9444956 | **302238592** |

B(b)=b+6; F(n,b)=b+12n+7; N(n,b)=b+5n+7. Historical worksheet2918508
remains untouched; old proposed8986210 and6053414 do not become runtime constants.

- [ ] Exact activation_contract/evaluator/facade arithmetic covers every row,
  full complete values once, known phase owner/release points and multiplicities.
  Callback validates finite inputs then returns9,444,956 regardless of small/
  missing later input. Invalid inputs raise fixed ArgumentError before
  serialization; HTTP prevalidates and maps malformed request400.
- [ ] Source URL/target assembly uses its existing complete request slot;
  Session residual URL and transient tuple use its Session request slot;
  manifest uses canonical return slot. No sixth request/config, third checked
  policy, extra uncharged queue/error/history or zero-charged opaque projection.
- [ ] One scope/original completion capability and two shell references recorded
  separately; owner token/pin/control/native policy stays outside request payload
  sums, with public completion/retirement obligations. No private serialization.
- [ ] Session<=16,384, pump<=8,192, each handle shell<=4,096, sixteen exact
  finite message-wrapper slots<=2,048; <=4 actor monitor pairs, opening+total+
  ONE poll timer, one pin/token/handoff/awaiting/DATAref and nil group. Fixed
  errors only, depth<=3/arity<=3 wrappers, no raw exceptions/stacktraces.
- [ ] Public H1 renderer finite proper iodata preflight<=8,192 nodes/depth16,
  logical/backing65,536; complete rendered head/trailer<=81,920, formula
  b+35n+7 for field lists and finite outer wrappers. Two slots+compact wire+
  traversal233,478<=524,288. Exact/over bytes/constructors/backing are tested.
- [ ] Public H2 returned HPAX iodata<=131,072 complete after finite preflight,
  block<=65,536, <=4 header frames of16KiB payload each, full frame-list/queue
  projection<=73,728, at most2 request-owned final/trailer queue projections.
  Combined131,072+65,542+147,456+4,096=348,166<=524,288. Release on full write;
  duplicates/extra queue/over encoded output reject. This is Gaoxy public renderer
  qualification, not HPAX/private/native internals certification.
- [ ] Encoded-head B(65,536) moves from proxy scratch to renderer exactly once;
  existing Service attach_cleanup reserves the combined allowance. No second
  owner/ledger/framework and no inference that old backend queue count alone
  established a byte admission bound. Existing H1/H2/H3 rendering compatibility
  passes after the minimal guards.

## Independent network, browser and lifecycle assertions

Each row below executes against real independent peers, with actual test/case
IDs/counts and bounded joins. Do not preassign an activation test count.

| Required protocol cell | Peer and downstream | Status |
| --- | --- | --- |
| H1 -> TLS-H2 | Native Gaoxy H1 downstream, independent verified TLS/h2 peer | NOT RUN |
| H1 -> h2c | Native Gaoxy H1 downstream, independent prior-knowledge TCP/h2 peer | NOT RUN |
| H2 -> TLS-H2 | Native Gaoxy H2 downstream via independent h2 client, verified TLS/h2 peer | NOT RUN |
| H2 -> h2c | Native Gaoxy H2 downstream via independent h2 client, TCP/h2 peer | NOT RUN |
| Browser -> fixed TLS-H2 | Local native TLS/h2, test fixture trust, Chrome DevTools | NOT RUN |

- [ ] Exact h2 ALPN/no fallback, wrong CA/name rejection, numeric routing+
  authority/SNI, no replay/credential forwarding; h2c prior knowledge exact.
- [ ] Sequential reuse and simultaneous multiplex, C2/R32/P0 saturation/refused
  33rd request with no hidden pending/replay; reset/GOAWAY failure and healthy
  sibling survival. Observe exact connection/stream IDs and public completions.
- [ ] Upload bytes observed before producer EOF, ordered safe request/response
  trailers, early final stops upload and preserves final bytes; escaped target/
  empty query/duplicates, manual redirect, raw compressed bytes/original CL,
  HEAD/204/205/304 and framing semantics.
- [ ] Real feasible exact/over heads/trailers/info/declarations; native-valid
  trailer129 reaches adapter then rejects. Pure malformed/backing inputs remain
  separately observed where no valid wire input can construct them.
- [ ] DATA16,385/64KiB/1MiB accepted; >1MiB logical/backing rejected before copy;
  upload65,537/backing over rejected. Downstream16KiB pieces do not become a
  native event limit. Deterministic withheld write prevents next DATA/ACK;
  full write permits exactly one ACK; failed partial write cancels with noACK,
  no replay or second response.
- [ ] Before head400 invalid request,501 unsupported,503 admission/identity,
  504 timeout,502 upstream protocol/metadata/delivery; after head terminate with
  no second response. Bound open/idle/write/total/cancel behavior.
- [ ] Producer/downstream/Session/native owner/transport owner/instance death,
  unread body, repeated cleanup, captured-pin mismatch, activation races and
  late handoff use barriers/finite polling and original identities.
- [ ] Bind original completion BEFORE ready/upload. Pending/unconfirmed retains
  token/pins/Service reserve; end/task DOWN/consumption alone do not release.
  Observe completion:ok ->owner finish ->Session pin release ->Service receipt
  ->Session DOWN. Wrong CA/name uncertainty never becomes successful cleanup.
- [ ] Healthy shared connection survives individual request release. Final
  Custodian scope retirement confirms public receipt, physical peer EOF and
  all owned helpers joined, with owner physical vs request vs Service accounting
  separately recorded. Scope-retirement is not request-completion substitution.
- [ ] Browser navigates local /probe, fetches /stream and /early, confirms h2
  and exact visible/fetched bytes, bounded upstream name/CA error without replay;
  capture network/console and screenshot/trace plus cleanup/joins. Test SPKI-only
  downstream trust where needed; no operational/global certificate changes.

## Closure evidence

- [ ] Preserve all63 public assertions and original historical supplement/
  collector/plan hashes/evidence. Fresh unchanged public0.21.4 qualification
  records managed39/completion16/supplement8, actual loaded identities, EOF and
  joined peers. This gate alone does not accept fixed adapter.
- [ ] Run plan's named pure/fixed/options/accounting/H1 prep/identity/handoff/
  Generation/group/probe/completion/runtime/wire/TLS and affected H3 tests,
  plus explicit new Generation/renderer and affected downstream seam scopes.
  Record discovered nonzero counts,0 failures/exclusions/skips, exact exits,
  source-before/after, loaded cohort and toolchain, CLI/Python OpenSSL separately.
- [ ] Independent complete SPEC then CODE pass against frozen full candidate
  and actual evidence; findings/counters and all failed receipts remain. Fresh
  post-review canonical format/strict compile/scoped/public/network/browser pass
  after any repairs. No failed/blocked/unexecuted gate is promoted to PASS.
- [ ] Parent confirms all own commands/actors safely stopped or explicitly
  unconfirmed, preserves user files/unrelated edits, stages only task-owned
  files and records actual local conventional commit. No generated-by/AI trailer.
- [ ] Only complete passing acceptance marks this fixed slice DONE. Continuing
  authorization then advances to written managed-H2 groups/probes, later
  Generation and standalone/load plans. Whole M3, hosted, release/deploy and
  production acceptance remain separate and are not inferred.

Document preparation itself used read-only source inspection and scoped static
document checks only. No implementation, format, compile, tests, browser, peers
or runtime commands are claimed for this documentation assignment.
