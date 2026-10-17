# Unsent-trailer cancellation source contract

Task unsent_trailer_contract — DONE (direct read-only investigation). Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, parent/frozen baseline `ceb3c0c953d930768023da85875a95672876ce39`. HEAD not independently checked; no Git allowed.

Recommend four native-H2 RST cases: fixed/single-member-group × h2c/TLS upstream. Upload stream1 and healthy sibling stream3 share the SAME downstream socket and SAME upstream H2 connection, with distinct upstream streams. Current eight early-final cases remain separately scoped.

## Exact bounded sequence

1. Reuse fixture(mount,upstream,:http2,["--manual","--hold-upload-credit"]), native stream1 POST /hold/upload-credit, and existing singleton hold_upload/capture while only that original exists. Freeze guardian, original_request, completion, T token/resource/pins, G token/selection if group; monitor guardian and its state.owner actual native worker BEFORE cancellation.
2. Observe same-upstream-connection SETTINGS ACK initial_window1 (TLS also ALPN h2/SNI localhost). Submit DATA <<0,255>> without END_STREAM then duplicate ordered x-check first/second terminal trailer HEADERS on native stream1. Require exact peer prefix/hash/held_bytes1/stream_window0/connection_window>0. Never release upload credit.
3. On SAME native socket send ended GET /hold/response-prefix as native stream3. Require actual peer request and upload_end total_bytes0, same upstream connection number, distinct upstream stream. Capture second authentic guardian/original completion/T pins/G selection.
4. At both-live checkpoint assert both original completions cleanup_pending, native workers alive, exact captured original identities/tokens/pins/resource/selections, T request_tokens2, Service cleanup_pending2. Group additionally inflight2, exact controls, cleanup reserve 2*16478862. Derive pin cardinality from actual captured originals, do not guess.
5. Command sibling-only status200/application/octet-stream response with binary prefix, declared x-check trailers and ended=false. Use existing F.response(f,socket,"GET",3,progress). Start NO response on cancelled upload.
6. In one-shot exact-complete-prefix callback, require ended=false and both authentic holds again, then send :gen_tcp.send(socket,Frame.encode(3,0,1,<<8::32>>)). Actual native RST_STREAM(CANCEL) is the sole cancellation trigger. No Session.cancel, no abort_and_await from test, no upstream reset command, no socket close.
7. Within existing5000ms event budget require actual independent StreamReset for original upstream connection/stream, code8, upload_credit total_bytes1/body64 AA==/sha256(byte0)/credit_released=false/response_started=false. EOF/connection_reset cannot substitute. Exact snapshot plus strict peer trailer/end guards establishes terminal byte boundary without elapsed absence inference.
8. Within existing finite budgets require original producer/native worker DOWN :killed, original public completion await :ok then await0 :ok, guardian DOWN :normal; monitors installed before stimulus. Observe original T/G token/request pins removed after genuine cleanup; sibling original remains live and pending.
9. Before suffix, require exact surviving sibling holds/identities, T request_tokens1, Service cleanup_pending1, group inflight1/exact controls/G.assert_cleanup1. Only then command sibling binary suffix plus duplicate ordered trailers ended=true. Existing parser completes exact status200/prefix+suffix/trailers on native stream3 of same socket.
10. After sibling terminal response close native socket; unchanged F/G.clean and both original completion await0 :ok, then F/G.close. Retain physical upstream termination, all-zero Service/T/G accounting, baseline-only resource holds, actor joins and peer exact request count/forced0/live0/failedfalse/exit0. Four-case runtime remains NOT RUN.

## Public source chain

Native RST -> stream-local discard kills actual worker -> Session actual owner DOWN -> original_request cleanup -> public RequestCompletion.abort_and_await -> tracker actual resource cancellation -> registered Fetch owner abort -> SocketClient ConnectionOwner.cancel -> pure committed cancel_headers -> actual code8 control write. Then tracked resources DOWN/terminal latch and Session T/G/Service finish; shared healthy connection remains.

Full citations and exact pins follow. This is source support only; no runtime gate was executed.

## Helpers and scope

- Add new sibling-safe token capture/assert helpers selecting by exact guardian/completion; preserve existing singleton helpers and all current24 streaming cases.
- New count-aware group assertions accept live count2 then1 while retaining every original identity/pin/control/reserve assertion. Keep F/G production and helpers unchanged.
- Use existing response-prefix one-shot exact-prefix receipt pattern; await peer reset and original cleanup inside callback before releasing sibling suffix.
- Only intended executable change: apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs. Current independent peer already exposes needed reset snapshot; no peer/production/installed-dependency modification proposed. Parent writes/reviews bounded canonical design/plan/acceptance/evidence and executes required independent review and scoped gates.

## Limits and gaps

- Native socket-submitted duplicate trailers are not proof that proxy pump parsed trailers, called HTTP.Stream.finish, or queued upstream trailing HEADERS. Call this cancellation with downstream-submitted trailers still absent at actual upstream reset; do not claim a parsed upstream trailer queue.
- Native H2 source does accept terminal trailer fields into native stream state (connection465-473) independently of blocked pump. Later same-socket stream3 peer request shows ordered native processing; do not equate that with upstream finish. No new parsed-queue requirement is proposed.
- Existing eight early-final cases remain separate. New cases start no response on upload and require response_started=false, distinguishing native reset abort from early-response release cancellation.
- H1 disconnect at held-body phase lacks a prompt causal source observation: synchronous endpoint/pump may wait in Stream.chunk until ACK/error/timeout and cannot poll H1 socket then. A deadline-driven abort must not be relabelled disconnect acceptance. Later H1 qualification needs a separately evidenced phase or normal diagnosis of an actual failure.
- Existing Session.cancel then later sibling is sequential; existing peer reset cases stimulate upstream-to-downstream direction. Neither supplies native downstream RST acceptance.
- F.response uses a fresh HPAX decoder and discards unrelated response frames; proposal sends response only for stream3, avoids parallel response headers/data, and uses existing never_store request encoding. No demultiplexer needed.
- Runtime outcomes including live same-socket isolation and accepted exits are source-backed expectations only, all NOT RUN. No actual dependency bug found; no upstream issue opened; dismissed #97 not pursued.

## Exact source pins and lines

Frozen candidate `docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262/source-candidate1.json` SHA256 `2e19676b87baaeb0d2e5b0b0bb9d8df66afc0a5431352a34b3c1acb2e8c4f503`; all22 frozen source/document pins match. Additional lifecycle file read/hash authorized by parent.

- `AGENTS.md` SHA256 `73b78c7642c2a38061aa23a36d4ffc2014e97ba7129766fbdb0d10f7e5fde9d4`
  applicable instructions
- `docs/plans/m3-upstream-transport.md` SHA256 `a1bd4f729e3ed63594a263b180201752b44419ac9b3ff17bfa965ae572497a31`
  639-667 Task6 requirements
- `docs/designs/m3-managed-h2-early-final-exhaustion.md` SHA256 `8c84da9ee3d431ee75a809b30ce57f852b919f1bc6a68187cf1f7f276184f8da`
  11-39 eight-case scope and submission versus parsed/finish limits
- `docs/plans/m3-managed-h2-early-final-exhaustion.md` SHA256 `c87359b1cc422d75a81025fe74a66b0fa0dc153e6d7f087f493f465be9d5671e`
  58-85 public cancellation contract and actual reset snapshot
- `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs` SHA256 `4841b853093424b26eeb5efd2ce75c3e46b38162a2d6edc3fcd70b71a41f5c54`
  24-88 open prefix callback; 236-329 current early-final cases; 350-373 singleton setup; 375-461 authentic original capture/assert and singleton/count1 assumptions
- `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` SHA256 `2b53e3848a286147ff1b00ac10b5364238b070396d30cb729fcd12300f17dbc8`
  121-163 finite peer commands/events; 169-206 exact upload/hash; 313-371 native socket/stream-ID primitives; 476-549 response callback/parser rejects any server RST or GOAWAY; 552-638 cleanup and joins; 957-981 upstream reset/sibling precedent
- `apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs` SHA256 `68ab3678fb6945d7a7cc18eb13b111572d8fb6356014d75a98c5731c79179ced`
  191-220 simultaneous authentic group holds and pending sibling; 285-310 guardian cancellation with later sequential sibling
- `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs` SHA256 `4d5f70dcee198409fb481947ddfb24e9d65dc65b3b41c0a58e8f6627778b1c53`
  258-297 target lookup and exact reserve; 299-319 all-zero cleanup; 345-398 exact control charges/accepted exits
- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py` SHA256 `ea4312215fbd5ca5ae29dfe7d65e8a1cd52429ad99c3f027fc9a7d05890442b6`
  293-366 exact held DATA/strict trailer-end guards/actual reset snapshot; 445-469 response-start and output; 471-530 manual commands/exact credit release
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` SHA256 `dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31`
  607-617 actual owner is native endpoint worker; 829-908 synchronous chunk then finish; 1189-1204 local error cancels guardian
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex` SHA256 `8a041a6bc217ef5ec626dc9e4efc2ec495db3a668912214420ad01bd4d449eac`
  46-52 actual owner monitors; 286-312 authenticated cleanup cancel and owner DOWN; 1346-1417 original cleanup before T/G/Service release
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex` SHA256 `e8c60d1d5a67f3b9737478149ac6e28b8e9ddf778289a2fac6035054379e7313`
  59-86 public abort_and_await cleanup; 142-175 public chunk/finish; 230-235 upload Stream creation
- `apps/gaoxy_http/lib/gaoxy/http/connection.ex` SHA256 `1b7e3caf6f99352f622f3243dbf3c1742a039182779af06c0ae5fe94eaa708a4`
  210-220 H1 synchronous endpoint; 354-378 close handlers
- `apps/gaoxy_http/lib/gaoxy/http/exchange.ex` SHA256 `75b752c358d861be75446b99fef948f023082e6de177840bef35f99ce20776d0`
  105-130 finite body read; 133-183 poll_connection closure receive
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex` SHA256 `586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52`
  150-174 ordered native parsing; 244-247 PING ACK; 283-285 native RST discard; 437-475 native trailer acceptance; 1333-1379 stream-local discard kills worker; 1411-1418 full close kills all
- `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex` SHA256 `2276f9bfb14053ff853a13b564397ba82e5ad685a1451619dde89e398980a581`
  7-27 per-stream worker owns endpoint invocation
- `deps/http_fetch/lib/http/stream.ex` SHA256 `d67a6ba36851dc255376ba93131e84dd003c9da2497fc0bb6e7d6c721c4be77b`
  110-139 producer chunk ACK/error/timeout; 149-165 ordered trailers/asynchronous finish; 211-218 tracked stop replies then terminates; 269-282 finish processing; 425-440 ACK ownership
- `deps/http_fetch/lib/http/request_completion.ex` SHA256 `157a371b838a2f72117a7e92f97d2f602a0363cc228411c77c1e22ba7865237c`
  10-22 logical cleanup versus remote receipt/shared connection; 95-103 public abort; 112-140 terminal tracker wait
- `deps/http_fetch/lib/http/http2/body_bridge.ex` SHA256 `e27351a43ca89e80e169a66b8a186c9ae9079d522ba87d769a62cd5746c9ecb3`
  127-140 pending slice; 223-245 credit gates next read; 249-285 stop clears pending DATA/trailers
- `deps/http_fetch/lib/http/socket_client.ex` SHA256 `245784a82edfdc741d18a967f611568cf81682409c3f8acb212e0dcd5b12c6ef`
  57-74 actual owner registered with tracker; 928-930 abort; 1254-1258 supported ConnectionOwner.cancel; 1304-1328 stream/pool release and tracked bridge stop
- `deps/http_runtime/lib/http/http2/connection_owner.ex` SHA256 `6ed1fbcef6b03794dfb8fc89183faf3eb8a28d6f0f0f7e2eb521abfb3d740615`
  439-459 cancel_headers and write; 488-524 healthy shared stream release; 676-677 actual code8 control frame; 1653-1665 unfinished upload cancel
- `deps/http_core/lib/http/http2/connection.ex` SHA256 `b9079e36ef4a98502852943af5d371d781094905ca0f36d45662931c7eb10716`
  289-292 committed request cancellation emits rst_stream cancel
- `deps/http_core/lib/http/request_lifecycle.ex` SHA256 `0231b77a39529e54e1e4d25fa95981fec31dca8e2be566b2d513fb22a45a974c`
  296-315 resource monitors/late registration; 377-379 tracker abort; 395-422 actual DOWN and latch; 460-493 notify actual owner first and stop source Stream/bridge

## Verification, counters, incidents, shutdown

Runtime/build/tests/browser/Git NOT RUN. Source hashes PASS22/22 frozen. Repository changes none; only owned JSON/Markdown written. Owned processes none; all commands finished. Product Sol repairs0; inherited Astra2/2 exhausted; no recovery attempted. Report-tooling repair1. No upstream issue or user decision needed.

Own incident delta: six failed read/search/report operations, grouped below. No protected E4/raw/private/prompt access, repository mutation, test/runtime/fixture failure, or lingering owned processes. Parent classifies orchestration/scope totals separately.

- 2 failed operations: one batch omitted W, producing JSON FileNotFoundError(exit1), rg missing worktree files(exit2), and parent-checkout Task6 text inadvertently read; discarded/re-read all intended sources under W. No writes.
- 3 failed operations: rg guessed nonexistent deps/http_fetch/lib/http/request_lifecycle.ex, nl and rg guessed nonexistent deps/http_runtime/lib/http/request_lifecycle.ex. Scoped rg --files located actual http_core source; parent explicitly authorized extra same-chain reads/hash.
- 1 failed operation: first report-generation Python command had SyntaxError unmatched parenthesis before execution and wrote no files. Replaced with simpler sequential dictionary construction and validated actual artifact readback below.
