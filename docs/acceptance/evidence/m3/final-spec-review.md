# Independent final M3 specification review

Task: `m3_final_review`; direct read-only review. Review file is the only owned mutation.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`; branch `codex/m3-gateway`.
Baseline HEAD: `22b76e8051ddaf09e36797cb781b9b119870a9d4` plus shared, uncommitted M3 changes.

**Specification verdict: PASS for all implemented nonblocked M3 runtime paths and independent-tool source contracts. S1–S5 are resolved with final candidate verification.**
Root explicitly accepted specification PASS and authorized a separate read-only quality phase.
**Quality verdict: PASS for the frozen implemented runtime/tool scope; no new actionable finding.**
Phoenix fixture lock completion also passes the separate addendum below. This is not an overall M3 verdict.
Root owns all production, test and integration-tool changes and the exclusive Mix/fixture execution window.
No Mix, fixture, compilation or test command was launched by this reviewer.

## Contract and scope review

Read `AGENTS.md`, `implement-plan.md`, the M3 gateway, standalone, groups, UDP and soak designs,
and the current production diff. Inspected native H2 selection/frame/state/admission/facade code;
Generation prepare/CAS/resource pins; strict standalone loader/supervision; authenticated forward/CONNECT;
TCP/TLS relay; dedicated H1 groups/probes/Session completion; UDP bridge/association admission;
and independent RFC, Chromium and sustained-load tooling.

- Product ownership matches the design: native Gaoxy H2 and public HPAX; no Bandit production backend,
  no private HTTP Fetch pool/client engine or dependency-source edits found in the inspected seams.
- HTTP Fetch #66 blocks reusable H1 and #66/#67 block upstream H2 and full M3. Dedicated H1 groups
  remain independently implementable. `HTTPFetchClient.open/1` keeps manual redirects and `http1_reuse: false`.
- H2-only prior-knowledge TCP and explicit TLS ALPN preserve default H1 behavior. H2 CONNECT returns 501;
  H2 WebSocket, push, H3 and unsupported relay modes are not qualified by this candidate.
- Generation preparation runs outside the store; request snapshots pin current resource handles atomically;
  publishing returns before retired-pin reconciliation. At most one bounded retired sidecar is retained,
  further activation returns `:resource_release_pending`, one provider release executes per message and
  failed releases rotate with a 100 ms delay. No old Router history is retained by the store.
- Standalone files are bounded before JSON decode, targets/modules and protocol strings are allowlisted,
  immutable listener settings stay outside route reload, and rest-for-one orders listeners after stores.
  External JSON currently exposes static/fixed reverse proxy only; Groups use explicitly supervised embedded
  handles. `implement-plan.md` section 7.4 does not define group JSON schema, and the standalone design
  explicitly states this narrow external format. Task 5 G5/schema-wiring language now explicitly names embedded Generation/resource integration and
  marks external group JSON UNSUPPORTED; do not claim JSON groups or full standalone feature coverage
  from embedded group tests.
- Dedicated groups select once, have no saturation queue, preserve old request/guardian holds and separate
  probe cleanup. UDP uses public Abyss dispatcher capabilities, connected per-peer sockets, fixed byte/item
  reservations, earned return credits, and the explicit local best-effort drain contract.

`docs/native-http.md` now states the public `HTTP.service_spec/1` constructor/prebind boundary,
manual raw-spec runtime fallback, qualified OTP28/inet/TLS range and fixed ingress buffers. Its
173,302,823-byte default minimum agrees with the current pure reservation arithmetic.
These are inspected contract paths, not fresh passing execution evidence for every feature.

## Actionable findings

### S1: zero WINDOW_UPDATE on an idle stream has the wrong error scope

Observed at `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:237`: the `increment == 0`
branch runs before idle-stream validation and issues `RST_STREAM(PROTOCOL_ERROR)`.
RFC 9113 section 5.1 requires a connection PROTOCOL_ERROR for any idle-stream frame other
than HEADERS or PRIORITY. Section 6.9's zero-increment rule does not make an idle frame valid.

Minimal independent wire: complete preface and SETTINGS handshake, then send type 8, stream 1,
payload `00 00 00 00` before opening any stream. Expected GOAWAY code 1; initial source resets stream 1.
The original selected suite covered zero on a live stream and nonzero on an idle stream separately,
so it missed their intersection. Root has added a scoped deterministic regression and independent case;
parent round 9 moves idle-stream validation first. `canonical-round9.log` records the corrected independent zero-idle case PASS and root reports the enclosing command exit 0.

### S2: malformed PRIORITY closes the connection and its independent test encoded that mistake

Observed at `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:281`: malformed PRIORITY length
calls `failure(:frame_size_error)`, emitting GOAWAY. RFC 9113 section 6.3 explicitly requires
stream FRAME_SIZE_ERROR for a length other than five octets. The initial independent `priority_length`
case expected the same incorrect GOAWAY.

Minimal independent wire: open stream 1 with a held request, send type 2, stream 1, payload `78`.
Require RST_STREAM stream 1/code 6 and the exact stream 3 sibling response over the same socket.
Stream 0 PRIORITY remains a connection PROTOCOL_ERROR. Root has moved this peer case to the
stream-error/sibling group and added a scoped regression; parent round 9 resets the identified stream for malformed PRIORITY. `canonical-round9.log` records the corrected sibling case PASS and root reports the enclosing command exit 0.

### S3: confirmed obsolete stream-failure receipt replaces the current admission starter

`Connection.message/2` for `{:h2_stream_failed, _, id, _, _}` clears `starting` without checking
worker/token/current start identity, unlike the adjacent ready/done handlers. An old failed admission
message that arrives after its stream was reset and a replacement worker started can clear the new
start marker and allow a third pending worker. Design requires authenticated late-reply tokens and
one pending worker start per connection.

The parent-assigned independent fixture now confirms this with a real listener, suspended admission,
captured old worker/token, real peer reset, queued streams 5/7, and one controlled obsolete failure
receipt. Same-sender `:sys.get_state` provides the processing barrier. RED: 1 test/1 failure, seed 90841,
exit 2, `starting` actual 7 versus required 5. See `h2/stale-start-review.md` and `h2/stale-start-red.log`.
The fixture deliberately simulates a late legitimate message and does not claim natural scheduler-race
coverage. It resumes the gate/closes the client and requires zero public reservations on failure.
Parent round 10 authenticates current worker/token, requires `lease: nil` and `starting == id`, and leaves obsolete receipts unchanged. `h2/stale-start-repair10.log` records 28/0 (stale/network/protocol), seed 718263, strict compilation PASS and enclosing exit 0. The full candidate must still be reverified after S4.

### S4: configurable control backlog is not tied to the fixed byte reservation

`HTTP2.Limits.normalize/1` accepts any positive `control_rate`, while
`Connection.enqueue/4` bounds pending frame count by `control_rate + max_streams * 8`.
The connection reservation retains a fixed 16 MiB state/copy allowance and no control-queue
byte admission changes. A large accepted rate (for example 1,000,000) permits a large
PING/SETTINGS response queue while a writer is blocked, without increasing that allowance.
The conservative finite default is not itself the finding; the admitted configurable
range is the concern. Root confirmed this unbounded configurable queue relationship in source. A blocked-writer/control-burst regression should substantiate a
safe hard queue/rate ceiling or a computed byte budget. This is a static bound analysis,
not an executed resource overrun. Root proposes a hard control-rate/turn ceiling and explicit
carry/delivery reservations in the pure prebind budget. Review also flags that arbitrary large TLS
`max_read_chunk` needs the qualified provider delivery factor or a safe H2-specific ceiling; four times
one receive buffer alone does not cover the 100-buffer OTP SSL delivery already documented by the
proxy/relay seams. Root settled the conservative formula:
`decode + 16 MiB + 65_535 + 4 * max_buffer_bytes + 8 * (100 * 16_384 + 18_437)`.
The fixed connection credit is 65,535 regardless of the advertised per-stream receive window.
Fix native TI buffers to 16 KiB independently of endpoint body credit; keep the old 16 MiB
state/control allowance, cap control_rate at 4096 and control_turn at 128, and reject unsupported
TLS `:inet`/`internal_active_n` host profiles before bind. TI re-arms `active: :once` in
`deps/thousand_island/lib/thousand_island/handler.ex:645` and passes raw `:ssl` data to the callback;
this is an active-once frontend, not the raw relay's passive recv path. The additional eight-window
allowance is conservative payload/copy capacity, not a total OTP/kernel/BEAM memory guarantee.
Final source independently inspected: fixed receive buffers, caps, carry/delivery reservation and
H2-only facade/runtime host checks are present. Parent reports first scoped green HTTP52/0, server18/0,
RFC40/0, seed655300, exit0 before the fixed-connection-credit correction.
The first final canonical log stops at `mix format --check-formatted` failure and remains preserved.
Parent formatting follow-up `canonical-round11-formatted.log` passes format/strict compile and executes
core90/0, HTTP196/0, proxy152/0, server18/0 (456 total), seed216300, plus corrected RFC40/0 and clean
core-consumer1/0, seed387754, enclosing exit0. Its RFC source hash map currently matches all recorded
production/manifests/tool files. This checkpoint closes S4 and predates the S5 repair. Independent capacity regressions cover pure prebind rejection/rebind, maximum legal control
limits, oversized carry, unchanged native buffer with large body credit, and host profile boundaries.
They do not claim an executed blocked-writer resource overrun or total RSS bound.

### S5: member timeout configuration does not consistently govern the shared pump

Full Task 5 specification trace observes accepted member `idle_timeout`, `write_timeout` and
`max_lifetime` in immutable compiled config, but the HTTP pump uses GroupEndpoint common limits.
Session applies member timeout values to HTTP Fetch open/socket options while its own total/opening
timers and deadline remain common; the downstream pump never receives member idle/write policy.
The existing three group expiry regressions set common endpoint limits, not member limits.

Minimal contract case: one healthy member configured with `idle_timeout: 80`, endpoint common
`idle_timeout: 2000`; the selected peer returns response headers and stalls. The pump computes its
idle timeout from common limits and permits the request beyond the member's 80 ms limit. This is
source evidence, not a reviewer-executed fixture. Parent must adjudicate the intended common/member
contract or implement effective clipped policy with deterministic regressions. A member total expiry
also currently arrives as a client error classified `:upstream_failure`, instead of Session's typed
total expiry. Parent confirms accepted member limits must intersect common/downstream limits, member
lifetime starts from the original Session start, and intentional policy total expiry must not poison
passive health. At that historical checkpoint the Task 5 worker owned the bounded TDD repair;
fixture/source verification was pending. The later recovery evidence below resolves it.
No production edit is owned here.

S5 bounded Sol repair evidence remains FAIL: first validation fails compilation on a private/public
`cancel/1` name collision; second executes26/2, seed107342. The new opening/idle cases and existing22
compatibility cases pass; two assertions abort before final health/cleanup checks. The worker stopped
after two unsuccessful production validations; parent owns bounded Astra routing. No reviewer edit
or counter reset occurred.

Independent read-only fixture adjudication: a member lifetime deadline propagated into Exchange
leaves zero permitted send time when it expires. `HTTP.Exchange.send_window/2` rejects sends at
remaining0, and the groups design clips all writes to total/drain remaining time. Empty response plus
bounded EOF is correct for this expired uncommitted request; requiring504 would require unapproved
extra time. A corrected regression must assert exactemptywire, bounded downstream/peer EOF,
unchangedhealth with failure_threshold1 and zero public group/service reservations. The opening
case retains504 because its independent total deadline remains live. The write case's peer advertises
Content-Length5; fixed-stream 200/length5/exacthello is the valid response. Correct that wire assertion
while retaining the real send_timeout80, effective-policy and cleanup assertions. Historical failures
remain FAIL; corrected assertions still need actual execution at that historical checkpoint.

Frozen S5 recovery is now independently reread and accepted: member/common minima reach the pump in
ready metadata, deadlines intersect the prior downstream deadline, total is anchored to `started_at`,
opening to cleanup activation, and intended total timeout cannot erase/upsert an upstream failure.
Astra changed only the two incorrect wire assertions plus required formatting; production is unchanged
from the Sol handoff. `member-limits-astra2-scoped.log` records strict format/compile and26/0;
`member-limits-astra2-proxy.log` records156/0, bothseed107342, actual VALIDATION_EXIT0. Exact EOF,
passive health with threshold1, actual send_timeout80, and zero public reservations all execute.
`member-limits-astra-recovery.md` hashes match the three current files. The group design now documents
intersection/original-start/no-extra-write-budget semantics. First Astra formatting failure remains
FAIL, zero tests. Cumulative Task5Sol4/unsuccessful2 and Astra2/unsuccessful1 are preserved.
Fresh whole-candidate verification now passes in `canonical-s5-final.log/.json`: strict format/compile,
core90/0 + HTTP196/0 + proxy156/0 + server18/0 =460/0, seed49315, enclosingexit0. Corrected
independentRFC40/0, exit0, runtimeDOWN/rebind also passes. Before/after maps contain197 identical
file hashes; independent reread finds zero current drift at this specification-PASS checkpoint.

## Evidence and remaining gates

- Historical failures and repair logs remain untouched. Initial green logs do not qualify later changes.
- Root reported Generation receipt regression RED 1/1 (seed 1281, exit 2); production receipt repair
  passed that case while two older synchronous-cleanup assertions failed in the wider group (HTTP 22/1,
  proxy 20/1, server 18/0; seed 618354). The existing one-second bounded eventual assertions now preserve
  those same cleanup predicates; the new strict 50 ms receipt assertion remains. Fresh root Generation/group/server checkpoint passes HTTP 22/0, proxy 20/0, server 18/0, seed 806307, exit 0; historical failures remain. Parent round 9 then passes the canonical four-package scope: core 90/0, HTTP 188/0, proxy 152/0, server 18/0 (448 tests), seed 378921, plus 40 corrected RFC cases, enclosing exit 0. This evidence predates S3/S4 repairs.
- RFC raw-frame peer is independent of Gaoxy codecs and verifies sibling survival and zero reservations,
  but original PRIORITY expectation needed the correction above. Round 9 now passes 40 corrected selected cases; it must be rerun after S3/S4 production changes.
- Browser tool adds independent verified TLS H2 and Chromium CDP `protocol == h2` proof plus LiveView
  interaction with H1 WebSocket fallback. New H2/browser execution is NOT RUN at this review checkpoint.
- Browser `results.json` contains individual checks, so a partial PASS list after failure is not gate PASS.
  Current `gate.py` records wrapper command/environment/exit, the exact complete check set,
  and before/after production/tool hashes; partial check lists cannot yield gate PASS. Source re-review
  accepts this wrapper; execution remains NOT RUN. RFC source identity
  now includes its own `run.py`/`fixture.exs`, all app manifests and root manifest/lockfile.
- Soak records frozen source identities, preselected bounds, exact bodies, resets after actual progress,
  generation reloads, samples, and bounded shutdown/rebind. Parent independent tool review found
  H2 Writer tasks absent from mailbox/process capture. Current source now enumerates public
  `Task.Supervisor.children(Gaoxy.HTTP.Tasks)` for monitoring/sampling and requires that supervisor empty
  after stop. Independent source re-review accepts this change with the original single 15-second
  teardown deadline and ceilings preserved; fresh execution remains pending.
  The 10-second 96/92/4 smoke remains
  UNQUALIFIED; the required default 600-second candidate run is NOT RUN. No full M3/production claim follows.
- No publication, deployment, production/Vault mutation, public management endpoint or restricted
  release-artifact E2E change was performed. Full M3 remains BLOCKED by upstream prerequisites even
  after independent local slices pass.

Reviewer repair rounds: 0; received Task 5 Astra recovery counter: 2 (one unsuccessful formatter
gate, one successful round). Task 5 Sol4/unsuccessful2 are preserved. No reviewer escalation or edit
to production/tests/tools occurred.
All reviewer commands completed; no reviewer-owned running process or test session exists.
No user design decision or unresolved runtime/source finding remains in this bounded specification gate.
Root owns later browser/sustained-load gates and fixture lock completion. At the specification-PASS
checkpoint quality was NOT RUN; root subsequently accepted the verdict and authorized the distinct
quality phase recorded below.

## Checkpoint identity

UTC: `2026-10-10T12:06:30.207194+00:00`.

SHA256 of canonical source-hash map: `a2182865e7c799c8345e8c31af6ce663e05b65c00001253473f1cc96eec3cd4c`.

The map includes all umbrella production `.ex` files, umbrella/app manifests and lockfile, the three
independent-tool directories, governing instructions and M3 designs. Source may change during parent
repairs; this checkpoint must not be reused as a frozen final candidate.

```json
{
  "AGENTS.md": "c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed",
  "apps/gaoxy/lib/gaoxy.ex": "68c001820bd7eeea92053ebb26be6053ee64ffdcefc2f5184143aa8f319dc974",
  "apps/gaoxy/lib/gaoxy/admission.ex": "169f311b2a4995b3de901ac41b5c2768208c8f8c3e26d2e57a58fdefdc013a75",
  "apps/gaoxy/lib/gaoxy/application.ex": "a651bb8a06b3223a6248fb235788e44916986daee09eca0d67b44b95af6b8950",
  "apps/gaoxy/lib/gaoxy/config.ex": "43609c0e7ea8150161f315b242e0d5c38d92baba4cb9f11700605195dbdcf241",
  "apps/gaoxy/lib/gaoxy/datagram_bridge.ex": "688ab1ac3c295ed886943f6570b96a11ab49f93a8f0048136330dde14db5e402",
  "apps/gaoxy/lib/gaoxy/datagram_dispatcher.ex": "8b240d116bf4fb76c397407ff8e6921801f74b894cf39b27b297313b6ac9be03",
  "apps/gaoxy/lib/gaoxy/datagram_dispatcher_bridge.ex": "eb6dc87e73301c09d67578fb765fb0b9c1fd45107ad8e6a96fd209fa4a33c054",
  "apps/gaoxy/lib/gaoxy/datagram_handler.ex": "3ff449882d182d20fc64311c31678ad10e51b810ee805c128aedc28a8c30f939",
  "apps/gaoxy/lib/gaoxy/instance.ex": "ba8e5f38f027adc1b20977b0612b5ef986663c656c0d0f0c2dd43ec390966b1e",
  "apps/gaoxy/lib/gaoxy/lifecycle.ex": "2fc9c20f820cb8049bb950698cd6a5206c511b15e65b4228351e3699d08c0f82",
  "apps/gaoxy/lib/gaoxy/native_stream_handler.ex": "ba9a4f897fc963aec9b82d3ef98949e26038a2096a4e3af83ea034ff03a74739",
  "apps/gaoxy/lib/gaoxy/quic.ex": "138f847c993bcbd7ae54127cd0f22614f726e78d3eccc8bc76e3d624b3031b98",
  "apps/gaoxy/lib/gaoxy/quic_bridge.ex": "249d39e3956212eb49c0692c19c46f401e9d29e846af0fd8f1e409d993cc6a32",
  "apps/gaoxy/lib/gaoxy/quic_handler.ex": "80bac8766df903c64f03245a3814bbe006ad9c180f8ddc479019ecce8bd1972d",
  "apps/gaoxy/lib/gaoxy/registry_policy.ex": "57d15d58f1e35ced0bf7deeb67d69b293eac02671950065aa4de9bfebf1401bd",
  "apps/gaoxy/lib/gaoxy/service.ex": "c0fa0549815500dad5f50779b05777880b008276540bae58d47a4cccd061037b",
  "apps/gaoxy/lib/gaoxy/stream_bridge.ex": "3f1b9ca7ba004cee152f39dde272600d5f2880974ce1244209ab9c8ea1becdd2",
  "apps/gaoxy/lib/gaoxy/stream_handler.ex": "5e96a0b3bc7e4629e9f305b50225e1056e50e91d8152f83f39992cf5945f7680",
  "apps/gaoxy/lib/gaoxy/telemetry.ex": "749421579aa4d6c5c8d8def5d9cdf502a59c7aa194203a8fb6c3051de1b72961",
  "apps/gaoxy/mix.exs": "0a51fdc9e60104fa65e45f61ef19c48c94aca0f0e1ed00848551e6ec2c63ef6c",
  "apps/gaoxy_http/lib/gaoxy/http.ex": "d84bad42a51af1c07b84ad26e7c6b6e10883aeda48f9794376dfab8ca511a1d3",
  "apps/gaoxy_http/lib/gaoxy/http/application.ex": "052d7f0eb9d2d8c08b3b83ac31724eda7adad32a07038dd110e849d5932fde3e",
  "apps/gaoxy_http/lib/gaoxy/http/connection.ex": "7c2b82c4d708728ac601fb6c5af82fd7e0c808ed6d8e8405ba8b8220b1b9c8e3",
  "apps/gaoxy_http/lib/gaoxy/http/endpoint.ex": "ae24f1266ba8c71b92800aab025b2dd3415cbd996fd154b28cc747a7c1fa7715",
  "apps/gaoxy_http/lib/gaoxy/http/exchange.ex": "0dd40f1635f8da7d7063e593c9f80cf5e402005ac9cb36f51d0aee96e0752c57",
  "apps/gaoxy_http/lib/gaoxy/http/generation.ex": "b4318cda8dc312984fbcc61b6d148727ed4ed98af8c9e9a22d34904be2a33f2a",
  "apps/gaoxy_http/lib/gaoxy/http/http1/body.ex": "3d4a54b993d49e526203c2814379ad1459295e22d491191a2104355114a90136",
  "apps/gaoxy_http/lib/gaoxy/http/http1/parser.ex": "1754519c713e292d02b8b49931d74f40ee27de4c387c904a6f2d0b3c62b5372c",
  "apps/gaoxy_http/lib/gaoxy/http/http1/response.ex": "7fbdc45512c525fea62dcdf99d43cda6a43a5835a119de04703e9ff40f178cf7",
  "apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex": "b341034fa9aae491f22f0dc336bb21f354a12a2530897414c686a9151ca84967",
  "apps/gaoxy_http/lib/gaoxy/http/http2/frame.ex": "319d286ef3d9bbe1185ae93b51f8e9af090c02b438de8c1f45118f7300016f9d",
  "apps/gaoxy_http/lib/gaoxy/http/http2/headers.ex": "99647e498ec9983383c6064d2031e4f1bb407708f290a64aa94469f78892d35a",
  "apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex": "513c774a5e45a06c44a516274bec2f7bd3dbc1a25d273b3df7499eff69bdfb24",
  "apps/gaoxy_http/lib/gaoxy/http/http2/response.ex": "49df4e5aed79f2789107f3bd774e1483d3d1b4b58b9cc154dc7897d692138e3d",
  "apps/gaoxy_http/lib/gaoxy/http/http2/settings.ex": "9d134d612e9c6e2408e78fd7be142b0b2dafb262becc2d591b6b28b18763cfe3",
  "apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex": "b6bbfcf79f1b1dd81a3a67a8251b027ca3008b554d4fa37376993a91fe383cbe",
  "apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex": "4cde148c32bc76e81dc62dc48c41a796f8e156ff543c97b67334148ba8f5ac8d",
  "apps/gaoxy_http/lib/gaoxy/http/http2/writer.ex": "54052d64cfb83fb4c0a8a2a834105f7b89d45994b582b5a73f095a1cea105235",
  "apps/gaoxy_http/lib/gaoxy/http/options.ex": "3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90",
  "apps/gaoxy_http/lib/gaoxy/http/plug_endpoint.ex": "ba94e2dc22cae2187e0dc32d1bcf143f9a25b64fb71f7a0b793b83f7d7967cdb",
  "apps/gaoxy_http/lib/gaoxy/http/request.ex": "44895f9382e126cfda120f95f2a6925e987383f5c5a2adf8d05dd9dc4edb1f1c",
  "apps/gaoxy_http/lib/gaoxy/http/request_error.ex": "351535c0c15bd8a919ed1c0588de15c4b32fac79a613d01030365b98dc41b2bb",
  "apps/gaoxy_http/lib/gaoxy/http/resources.ex": "0e58a4f0badd2ba6d21b9f118c5b3f6c4d1070b4371e76e9dfc0656796f0907b",
  "apps/gaoxy_http/lib/gaoxy/http/response.ex": "e198c13303dbf4ddd6b536a94f73bdcc4560fc406bb9645a81a26e4cf5f5fabe",
  "apps/gaoxy_http/lib/gaoxy/http/router.ex": "1cb7a4d354ae6f46cac993494eb81265725e10cacb147d20028aea96a326eee7",
  "apps/gaoxy_http/lib/gaoxy/http/websocket.ex": "393bcb7fcd6f97f04be0fc8c87d0ab63ed32e6b591257b1614ced9a5d4405b62",
  "apps/gaoxy_http/lib/gaoxy/http/websocket/frame.ex": "01b0dfcd187fe298811702d03340e34612dca3f0fdd938660bd5ee39efa00997",
  "apps/gaoxy_http/lib/gaoxy/http/websocket/handshake.ex": "2e402c2c5d516b40bf5f2be41def2838e8cb0b787342763236c108d5e3d63986",
  "apps/gaoxy_http/lib/gaoxy/http/websocket/message.ex": "84daa3a371fcbbaaffebf6343b6de2d1d555548ab915276a4d23d6e0eea85cd5",
  "apps/gaoxy_http/lib/gaoxy/phoenix_adapter.ex": "1f116b12c12b675248e8dfcb8e3421787b53de30dc703cfc02f01a5bb1361d9d",
  "apps/gaoxy_http/lib/gaoxy/plug_adapter.ex": "9266ad8012b86d9f7d390c25ce57abadadea0a4240844fc8a97c96b58f8ed827",
  "apps/gaoxy_http/mix.exs": "97895196031ec7e631cd0ff1ae0bbe1df55da57cd83b89184e167d76c3d83b8e",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/application.ex": "0142d4ba20e942f702fab7b99a0938d3efcbb61253cb2f102d9f8c72e6fbc708",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/destination_policy.ex": "6badadfae41b00713b7985ed149b5fcba9849a450e9e77af7c6090ce798b3eee",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/forward_http.ex": "41e84d5479796eab2170f175ce58e55528a76138dd8bfa8399247b14ecbd3f4c",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex": "3e768d161fe6f66ff3dd303a2ccbe8ba932587d1816eb1bd382c8c0391f7a4a8",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex": "d58d5dbedee32ea4c7630c580602e7b92706abc869cfa6dbb554590b0f04a48f",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex": "5364d4aa176410708de38d406c12ad8a620564f91bd1c0ddbb32d116db3caa2a",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex": "30e345233134f27bf2e3facc4543048dc27859270046de86be8f7952d14558e9",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex": "43341edee8f4e4c5177defcbb94d9dabb132e119513e95405244f7fd9c22b87a",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay.ex": "2288ab9904c55638923e71d2380866870bb09945d18728fff5bc7d495b0d3ad0",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay/upstream.ex": "348abdc36160ae10055117713023c68fbaf7746ddd3abd6148f75555a9f02c35",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/stream_relay/writer.ex": "1bd10e580e605b421a2452d12141b78e761f353229edca458f9d0b3017e25220",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/udp_relay.ex": "784ce2550f37a45e2ea970342b380b8daa67c1f9d6672bfca2e59897be4c1982",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/udp_relay/association.ex": "e371f703acf96ea6e260585b853918423e7d00a297b2573176b86555e67fad30",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/udp_relay/controller.ex": "efa000d4158372be85847612449fc895932e9a29300432a4795a83f6af90cd21",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/udp_relay/options.ex": "d98ee680090ae9be10ef67a9b9da71b45db44c10ecef2c625f87f5e866be2153",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_client.ex": "37818df2d566b3c3f3cf67ff5d6de605b579f9b98ea9fee68037402ac2f37fc9",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex": "53fe783cd687845547d45cfcb679e28ffae17b2b98855a1237fbe453d60d0466",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex": "4c4f216d609715b68e419ad75f3722aa4e982a42f6affbaecdeb644b54aef0ca",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex": "49a449884bc0466263a700b584eb237fef29b02c03a45de6dcabd4de214ba38f",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/websocket.ex": "d0b562be32a60d05d995f007f71f28b0d5229f3b80c6db0eb16523d0f3903321",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/websocket/handler.ex": "9caadd0cc6b8741a69fa5963b0484486045d5089eafb08d0fd9b05417bb070d5",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/websocket/session.ex": "ac9dcbee854c64b39910ac0b292e3d502b75e0ddde6a1ffe0c8dbb6739ca5bde",
  "apps/gaoxy_proxy/mix.exs": "ac9dbf6a3471be22149128bb5c91ad03b1bc34c0dd549f60f95e9544cb46178c",
  "apps/gaoxy_server/lib/gaoxy/server.ex": "53c5d0ecee486b2f1568cf9f1dfb83bbaaa708f69ebd2ec86562fe43c433205c",
  "apps/gaoxy_server/lib/gaoxy/server/application.ex": "d2fa2f01fc8bc86eb3f0bb281340e24c1e61913d360e7f4825f4fc5774b3b457",
  "apps/gaoxy_server/lib/gaoxy/server/config.ex": "437920e5c86ae5b7af8a79ce517752caa37b992d16e9288e36872f1e3a085867",
  "apps/gaoxy_server/lib/gaoxy/server/datagram_echo.ex": "766315d4976378671c532a1bf02ca5b6c5c17f36b789cbc3e5250461d15deeee",
  "apps/gaoxy_server/lib/gaoxy/server/route_config.ex": "5db93701da755bd1ca977c191e79e650bd9e58108ed28842491f4031dc8b95fc",
  "apps/gaoxy_server/lib/gaoxy/server/static_endpoint.ex": "633a9dc349eaf92add63fcdda799e0ed5d8f37878739a7c78e143734017c12dd",
  "apps/gaoxy_server/lib/gaoxy/server/stream_echo.ex": "630109b8a6f4f7115d7311b8c6639bfcde3213fe17b918ee00ae579ebc6e3ab7",
  "apps/gaoxy_server/lib/gaoxy/server/supervisor.ex": "fb5d68f5bd6b24ce2f5abdfe3002f81080325f87906502f81ad1b8f176dd27a7",
  "apps/gaoxy_server/lib/mix/tasks/gaoxy.validate.ex": "7d641d69dd177fc47cc5a74ade970b5e1d969b9842d8936720c0f62301ad6c1e",
  "apps/gaoxy_server/mix.exs": "e72f5bb607fd96c54d6f0742050ef0056a9a06374fc7e7def6c9f47c8bb7c2ff",
  "docs/designs/m3-gateway.md": "84c9064d5944fe71b6021ba25834f32acf321e7ff782561483ef2d9af45a0762",
  "docs/designs/m3-soak.md": "1c70a8ae76cfac87b46a066159e94ac70c836482740611c583849bef1183adf0",
  "docs/designs/m3-standalone-generations.md": "e525148963d52e3135581f59ae191b3c1027e325d6950b8b088845c21f0f903f",
  "docs/designs/m3-udp-associations.md": "060eec7e0bafc71fd585e2913fea280497369ccc3e4e04b136078f1823a5a5d3",
  "docs/designs/m3-upstream-groups.md": "0d595cb0384f6fcb0780309e8bbfb551fcf2e8d9d791b42d3a037aca5fa8b7e4",
  "implement-plan.md": "60f112e0f9c48fd52d4ac27b87303b5970a97b3b1a90bcbf952ac862adf3eb49",
  "integration/h2_gateway/README.md": "60c9eb7b103f653a1eaaa279b6b7dba81071c72df28ec95d3aa81a9f4d10d2dd",
  "integration/h2_gateway/fixture.exs": "7a43f6f2bbc59752b53d59089cff3f811269299e5d5055256afbaf83e6bc97b9",
  "integration/h2_gateway/requirements.txt": "b48d88c281542860a2eb451f551ce8793f22e8a6df4061307f90632213d3013a",
  "integration/h2_gateway/run.py": "c8de9127219c8858b84eae92a68c87614e4f4259449d07b75baa5ed26e2a1e44",
  "integration/h2_rfc/README.md": "1eee4021ac0aa73bcc316ece3ad97490b97c88521f2ce45b819ce0ddb5641bf4",
  "integration/h2_rfc/fixture.exs": "d79f42006635f41b3437eba3ea14e1d7259746eb397bed24d783190b5c707fa4",
  "integration/h2_rfc/run.py": "35b433afb1e8263cc5241f89582c45798b240605fe2929d3f97ec6cae3353c74",
  "integration/phoenix_native/README.md": "1b5e3d86b56fb00f4ab878ea041d2ca663517bcefffde5f6177d819d2aff3d9b",
  "integration/phoenix_native/requirements.txt": "7d9c0d371589120813e5b1d467967c1cbcf7638c8855b46d2ad5f9aab0de9fd9",
  "integration/phoenix_native/run.py": "f17880c8aae5c260a16697462058f0564bd2011eb43cc5ad657a4314408789c5",
  "mix.exs": "c9a5ee367ef5cbded58cc067fdbf0a177de3c69c9d024c65d4873fee028b39c9",
  "mix.lock": "0e02737877e7723048156f09b4f27310b1adce6dcaf39b46430bab75fa838381"
}
```

## Final specification checkpoint

UTC: `2026-10-10T12:50:57.565153+00:00`.

Final runtime/tests/manifests/fixtures/tool identity is the 197-entry `sha256` map in
[canonical-s5-source-after.json](canonical-s5-source-after.json), identical to the before map.
SHA256 of that canonical map (sorted keys, compact JSON): `c207214b9477e27430aa72a2e68273aba98cf1dd56fab2dea6f72d506802178b`.
The original 104-entry map above remains historical; it is not the current candidate.
The complete command/environment/exit wrapper is [canonical-s5-final.json](canonical-s5-final.json).
All evidence here is parent-run and independently read, not reviewer-run Mix evidence.

The review additionally binds governing instructions/designs and explanatory browser documentation:

```json
{
  "AGENTS.md": "c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed",
  "docs/designs/m3-gateway.md": "84c9064d5944fe71b6021ba25834f32acf321e7ff782561483ef2d9af45a0762",
  "docs/designs/m3-soak.md": "a9458a30adcc823b551c04cb06380b94f4c140b5469e0b3792a2953c095406bc",
  "docs/designs/m3-standalone-generations.md": "e525148963d52e3135581f59ae191b3c1027e325d6950b8b088845c21f0f903f",
  "docs/designs/m3-udp-associations.md": "060eec7e0bafc71fd585e2913fea280497369ccc3e4e04b136078f1823a5a5d3",
  "docs/designs/m3-upstream-groups.md": "77db9039bcb80533650a030cc585fca001df5158997f2df039d8c44c285dd654",
  "docs/native-http.md": "56aa2e72e742dcc1f8c6d2ef8cd0a1edeb87b6d578b6329650cd4a02aae2bb98",
  "docs/plans/m3-upstream-groups.md": "3d20151db08ecf1cf048cfc512df175392e44d265e8a1b2d4982864b5f464f76",
  "implement-plan.md": "60f112e0f9c48fd52d4ac27b87303b5970a97b3b1a90bcbf952ac862adf3eb49",
  "integration/phoenix_native/README.md": "34fb0a6818e75c3836fbaca93c05b13e042dcbf5bd490cb36b86e5092a453671"
}
```

Root's subsequent Phoenix fixture dependency/lock completion is a separate local browser prerequisite;
it may change `examples/phoenix_native/mix.lock`. Runtime and root lock remain frozen. Recheck that
addition and its exact tests before the fixture/final closure addendum; runtime quality is separate. Browser and required
600-second sustained-load execution remain NOT RUN, and full M3 remains externally BLOCKED.

## Separate independent quality review

Root explicitly accepted the preceding specification PASS against the197-file canonical map and
460tests/RFC40 evidence before authorizing this phase. Quality reviewed the current frozen source
read-only; the earlier specification trace is not substituted for this separate review.

**Quality verdict: PASS for the implemented nonblocked runtime and tool source. No additional
actionable finding was confirmed.**

- Public HTTP constructor checks host/protocol/minimum capacity before bind; H2 runtime checks actual
  transport and budget before writer/codec startup. H1-only construction stays outside the H2 host guard.
  The fixed ingress constant and reservation share one source; body-credit configuration is distinct.
- H2 writer/stream workers retain their own admission ownership. Bounded sends and owner links/monitors
  preserve teardown, and stream ready/done/failure receipts identify the recorded worker/token. The
  repaired obsolete-start failure path cannot clear the replacement starter. Reset refunds connection
  receive credit and resolves pending reads/polls/writes; already-started header blocks finish their
  CONTINUATION sequence while entirely unsent blocks are removed.
- Generation validates the candidate before CAS, prepares outside its store, pins current resources
  before delivering an execution snapshot, publishes before old-release reconciliation, and caps pending
  retirement metadata to one sidecar. Provider cancellation refs/holder monitors close timeout races;
  selected transport guardians retain holds independently of endpoint request pins.
- Groups select once under bounded owner/member capacity. Session binds public completion before
  upload-ready, confirms cleanup before member finish and Service receipt, and recovery reuses only
  the completion handle. Unbound/unconfirmed death fails closed. Effective member/common minima and
  deadlines reach the pump; intentional lifetime/idle expiry preserves passive health, while recorded
  attributable opening failure survives later cancellation. No timeout extends the original budget.
- Forward/CONNECT requires credentials plus explicit destination rules, checks all resolved addresses
  and passes the approved numeric dial through supported APIs while preserving authority. Relay and
  UDP paths retain typed receipt/monitor ownership; UDP permit tokens, worker tokens, earned return
  credits and failed shared-writer completion preserve reservation conservation within the qualified
  local best-effort contract. No private pool/client or shared UDP socket ownership workaround found.
- Independent tools have explicit complete-check/exit/source-restoration gates, raw peer framing,
  public task/guardian monitor capture and fixed bounded teardown. Test fixtures retain exact responses,
  finite barriers and public zero-resource assertions; S5 corrections preserve deadline and health
  assertions. No dependency source edits, unrelated cleanup or hidden test suppression found.

Verification supporting this verdict remains the freshly read parent-run strict format/compile,
460/0seed49315 and corrected RFC40/0exit0 on the canonical source; the S5 recovery adds26/0 and156/0
seed107342. This reviewer executed no Mix/fixture command. Read-only canonical hash comparison has
zero drift at quality review time. `git diff --check` for the owned review file passes.

Remaining boundaries: Phoenix fixture HPAX lock addition must be independently reread after the
parent resolves it; browser and600-second sustained-load execution remain separate NOT RUN gates.
Full M3 remains externally BLOCKED by HTTP Fetch66/67. Reviewer repair0, Task5Sol4/unsuccessful2,
receivedAstra2/unsuccessful1; no reviewer process remains running.

Quality checkpoint UTC: `2026-10-10T12:53:42.830203+00:00`.

## Phoenix fixture lock addendum

Specification/quality PASS for the fixture dependency completion. The only postcanonical197-map
change is `examples/phoenix_native/mix.lock`, adding exactly the HPAX1.1.0 Hex tuple already present
in root lock, including both matching package checksums; every other fixture dependency is unchanged.
The root lock and reviewed runtime/tool source remain unchanged. Independent source comparison of
the197-file checkpoint confirms this single expected drift.

Current fixture lock SHA256: `93bf8e6d37dec12445bbe2ee192373728c55e6a7fcfc114bd8fa54291a60ca1f`.
Current root lock SHA256: `0e02737877e7723048156f09b4f27310b1adce6dcaf39b46430bab75fa838381`.
Replacing only the fixture-lock entry in the197-file map gives canonical-map SHA256:
`de9bf144ed1ca14367dace459c5841ae0c9d29e793ee6e62fa78c99675737415`.
The runtime canonical command is not represented as a rerun after this fixture-only lock addition.

[phoenix-fixture-final.json](phoenix-fixture-final.json) records the exact root command/environment,
check-locked, strict compile, fixture2/0seed805388 and actualexit0 (root session86368). The reviewer
read the exact diff, wrapper and log; no reviewer Mix execution occurred. Generated fixture/browser
private keys remain ignored and are excluded from evidence packaging. Browser execution and the
600-second sustained-load gate remain independent; their final receipts will be recorded separately.

Addendum UTC: `2026-10-10T12:56:23.488095+00:00`.

## Nix/Linux browser environment addendum

Prior browser attempt is FAIL/BLOCKED_ENV before any checks: greenlet could not load
`libstdc++.so.6`. Its nonzero exit and source-restored manifest/log are preserved under
`browser-env-failed/`. It establishes no executed browser acceptance.

Environment specification PASS: root's fresh default `nix develop` import command uses the new
Linux-only `LD_LIBRARY_PATH` without a manual override. [browser-environment.json](browser-environment.json)
and [browser-environment-default.log](browser-environment-default.log) record actualexit0 (session24638),
pinned GCC15.3 runtime path and successful greenlet/Playwright imports. `flake.nix` adds only
`pkgs.lib.optionalAttrs pkgs.stdenv.isLinux` with `makeLibraryPath [stdenv.cc.cc.lib]`; pinned inputs
and package list are unchanged. The README explains running browser setup inside this dev shell.

Root accepted that bounded environment specification and authorized a distinct quality review after
the fresh receipt. Environment quality PASS: the attribute is confined to Linux, reuses the existing
pinned compiler runtime, creates no dependency/source/provider workaround, and leaves Darwin's
attribute set empty. The change does not touch application protocol logic, root Mix lock, tests or
browser-tool semantics. Diff whitespace check passes; no actionable finding. A full runtime suite
rerun is unnecessary for this environment-only change; the fresh import proof is scoped evidence.

Environment SHA256:

```text
46a5d573e0915937beec01de4cdf45f7a8f9f5886276b7f6d11415e668a80be9  flake.nix
ab9cba40e49dca0023bfd18bff4df80e5470abb70ee2acd64f8419ffb8a19459  flake.lock (unchanged)
eb5bbef2e96112b27f25e07756fbf5ca26ac745871db3675f6930cfef515b704  integration/phoenix_native/README.md
```

The197-entry runtime candidate map omits the dev flake and browser README; this addendum binds those
separately. Default environment import is not a browser/soak PASS. Fresh browser and required600-second
sustained-load receipts remain independent. No reviewer Mix/import command, production/test/tool
mutation or repair round occurred; all reviewer commands finished.

Addendum UTC: `2026-10-10T13:03:39.482240+00:00`.

## Independent browser evidence addendum

Browser gate PASS on actual root session89113exit0. Independent reread of
[browser/manifest.json](browser/manifest.json), [browser/results.json](browser/results.json) and the
runner/server logs confirms fifteen executed checks, the exact expected set, process_exit0,
source_restoredtrue, errors[] and wrapperexit0. Its102-entry source-before/source-after maps are equal
and match current files, including the resolved fixture lock. Tool-source/environment addenda above
remain the same reviewed candidate. No private certificate/key is included in the packaged browser
evidence directory; it contains only logs, manifest/results and a screenshot.

Actual checks include independent h11, verified HTTPS with hostname rejection, independent verified
HTTP/2 Phoenix, WebSocket framing, Chromium page/static/LiveView click/upload/channel/SSE/reconnect,
controller reload and byte restoration, no page errors, Chromium document protocol `h2`, H1 WebSocket
Upgrade fallback, and graceful1012 close/process exit/listener cleanup. The manifest records Python
3.13.15 and exact Playwright1.56.0/httpx0.28.1/h24.3.0/hpack4.1.0/hyperframe6.1.0/h110.16.0/websockets15.0.1.

This is parent-run browser/independent-peer acceptance, independently read by this reviewer. It is
not complete RFC conformance, upstreamH2/reuse support, hostedCI, fullM3 or production acceptance.
The prior environment-failed attempt remains preserved as FAIL/zero browser checks. Runtime/tool
specification and quality verdicts remain PASS; required600-second sustained-load evidence is pending.

Browser manifest SHA256: `9ea7375a2116fc9890351bcc9f7816464fa1e924336b5f7bd4aac812d1f2eeea`.
Browser results SHA256: `88425207d60606ae1670de626731927bc29657ddd0ebc22b28145847900f0c00`.
Addendum UTC: `2026-10-10T13:06:06.363587+00:00`.

## Reverse consumer and final frozen candidate

Reverse consumer PASS: [reverse-proxy/manifest.json](reverse-proxy/manifest.json) records actual
root session71267exit0 and six checks. Independent reread of `example-results.json` confirms the exact
expected six-member PASS set: local Plug, raw gzip/duplicate cookies, streamed upload/download,
SSE before origin EOF, manual redirect and drain/exit/listener cleanup. Its85 source hashes match
current runtime/fixture/tool files and the recorded canonical subset.

The final frozen runtime/tests/fixtures/tools/development-environment identity is the199-entry
`sha256` map in [candidate-frozen.json](candidate-frozen.json), baseline
`22b76e8051ddaf09e36797cb781b9b119870a9d4`, branch `codex/m3-gateway`. Independent current-hash
comparison finds zero drift. SHA256 of its sorted compact canonical map:
`6f8cb7c032c0f21ceb3bcdb1df9f8e401b1e847c6f6f26a5beb72cd44c021237`.
It incorporates the separately accepted fixture HPAX lock and flake/unchanged flake lock. Earlier
197/104 maps remain distinct historical checkpoints. README/governing-document additions remain
bound by their explicit supplemental hashes above; documentation bookkeeping is outside this runtime map.

Root has begun the required600-second sustained-load run with the preselected profile unchanged.
It is RUNNING, not PASS; source/tools/HEAD are frozen until its receipt. No reviewer Mix/fixture
execution or concurrent source write occurs. Full M3 remains blocked on HTTP Fetch66/67 regardless
of this independent load gate's eventual outcome.

Checkpoint UTC: `2026-10-10T13:08:03.000255+00:00`.

## Task 5 load qualification boundary

The agreed groups design G5 requires bounded mixed concurrency and generation changes to maintain
reservations; it specifies no separate 600-second groups profile. The agreed Task 7 soak explicitly
uses local echo and a fixed dedicated HTTP/1 reverse proxy. Its duration cannot qualify group load.

Existing passing group regressions establish two simultaneous selected member tokens with saturation
and real initial HEAD probes (`upstream_groups_test.exs`), one old/new group activation with an old
snapshot held before checkout and exact peers (`upstream_group_proxy_test.exs`), downstream-reset
cleanup holds, and live-probe freshness, nonoverlap, capacity, death and public-completion holds
(`upstream_group_probe_test.exs`). These are bounded concurrency/ownership gates, not a group soak.

The twenty-generation test in `apps/gaoxy_http/test/http2_integration_test.exs` holds one fixed
`ProxyEndpoint` request while new generations switch to a local `Endpoint`. It exercises neither
`UpstreamGroups` nor shared members/live group probes. Describe its repeated-generation coverage
separately. Do not combine these independent tests into a claimed twenty-generation/shared-member/
live-probe load profile. The generic Task 5 sustained-load checkbox needs this explicit bounded
qualification if marked complete; no group sustained-load execution receipt exists.

This adjudication reads existing designs and tests only. No execution or runtime/tool mutation occurred;
the parent remains the exclusive owner of the running frozen-candidate soak.

## Final 600-second soak specification conclusion

**Specification PASS for the agreed local sustained-load profile.** Independently read
[h2-soak-final/result.json](h2-soak-final/result.json) and
[h2-soak-final/gateway.log](h2-soak-final/gateway.log). The parent reports actual session `32874`
exit **0**; the receipt also records gateway and runner exits **0**.

The offered interval is **600.000146648 seconds**, with load plus drain **602.807060340 seconds**.
The original profile and ceilings are unchanged: one h2c connection, 32 concurrent streams,
131072-byte bodies, alternating echo/fixed dedicated-H1 proxy, 30-second requests, 5-second writes,
200 ms selected slow credit, and a single 15-second teardown budget. Execution conserves
**4064 offered = 3872 completed + 192 expected progress resets**; completions comprise
**1959 local / 1913 fixed-H1 proxy**. The frozen client checks status 200, exact response/upload
bytes, and requires upload completion plus actual response DATA before an expected reset.
Errors and unexpected errors are empty/zero; **12052 slow-credit events** and **299 same-port
reloads** executed. Completion throughput is **6.423282431/s**; P50/P95/P99 latencies are
**2.579810 / 4.605434 / 4.854889 seconds**.

Independent recomputation over all **600 samples** confirms maximum RSS growth **9940992 bytes**,
process growth **132**, owned mailbox **6**, admission active **34**, and retained admission
**371570471 bytes**, below every original ceiling; no sampled cleanup failure occurred.
These are sampled ceilings, not a guarantee about unsampled peaks or a total-memory bound.

Teardown completed in **7 ms**: **6082 captured / 6082 DOWN**, zero live captured owners,
zero active/bytes/cleanup reservations, empty proxy guardians and public HTTP task supervisor,
runtime DOWN, connection refusal and exact listener-port rebind. Gateway socket descriptors equal
the baseline minus its recorded listener; the origin reports no payload failures and closed client/
listener sockets. Raw log samples, reload counts and final stopped/exiting events agree with JSON.

All **199 frozen candidate hashes** still match current files. All **91 soak source hashes** match
the frozen subset and current files; baseline/branch are unchanged. Sorted compact map digests:

```text
6f8cb7c032c0f21ceb3bcdb1df9f8e401b1e847c6f6f26a5beb72cd44c021237  frozen 199 map
221800f4196d9e616508f74a9d368f038d5b1c1f549b7ea089b3dabebd08c893  soak 91 map
844556791aac6431fb4a9c03d7ffaabcb0f8177a11d1fa80a3e591e032ec2468  result.json
951d38c0e6093c74ca9a383ab85d5a850d8ab8861c4fef872e9988cdabd7c0aa  gateway.log
```

## Separate soak quality conclusion and current limits

**Quality PASS for the final soak tooling/evidence; no actionable finding.** This separately checks
that duration and profile were not relaxed, exact-response and progress-reset conditions remain in
the frozen runner, teardown assertions execute before the stopped receipt under one deadline,
and the raw log/JSON agree. Public DOWN/task/guardian evidence and descriptor conservation are
preserved. No private-state counter reset, test suppression, dependency patch or source drift was
needed. The initial smoke remains historical UNQUALIFIED; earlier pending browser/soak statuses
are superseded by their separate final receipts. No Mix, fixture or import command was reviewer-run.

This gate qualifies echo plus a fixed dedicated-H1 proxy, not a sustained group profile, TLS/browser,
complete RFC conformance, reusable upstream HTTP/1, upstream HTTP/2, hosted CI or production.
Full M3 remains **BLOCKED**. The parent's newer live upstream check reports #66 CLOSED at
`2026-10-10T13:12:38Z` and #67 CLOSED at `2026-10-10T12:59:54Z`; GitHub/Hex latest and installed
HTTP Fetch remain **0.19.1**, published before those fixes. The remaining upstream dependency gate
is a containing release/update plus the unqualified upstream reuse/H2 matrix. Earlier OPEN claims
describe older checkpoints and must not be read as current issue state.

Reviewer repairs **0**; cumulative Task 5 Sol **4 / unsuccessful 2**, received Astra
**2 / unsuccessful 1**. No reviewer runtime process was launched; all read-only commands finished.
Parent owns subsequent documentation/manifest closure and any separately authorized local commits.

## Final delivery-document specification closure

**Specification PASS for the bounded final delivery documents and gate manifest.** Read the final
acceptance matrix, implementation status, capabilities, gateway/groups plans, soak/groups designs,
`final-gates.json` and corrected `upstream-state-final.json` against the independently reviewed
execution receipts. They preserve local PASS versus full-M3 BLOCKED, exact gate counts and source
identity, historical failed/UNQUALIFIED evidence, sampled-resource exclusions, unsupported profiles,
and the closed-but-unreleased HTTP Fetch prerequisite. No actionable contradiction was confirmed.

Task 5 now accurately names bounded selections/saturation, probe ownership and one old/new group
activation. Repeated fixed-proxy generations and the 600-second echo/fixed-proxy soak remain separate;
no group/probe sustained-load receipt is claimed. Standalone JSON stays static/fixed reverse proxy;
groups/forward/relay use the qualified embedded APIs. Task 5's local-commit checkbox and Task 7's
documentation/commit checkbox are pending parent packaging, and whole-M3 completion remains unchecked.
Neither M4 progression nor publication/deployment/production acceptance is claimed.

The manifest's 199 source hashes equal the frozen map and match current files. Its 178 artifact hashes
also match current files. Canonical metadata matches its exact receipt; browser/reverse counts and
expected PASS sets agree with their raw results; soak counts, duration, limits and teardown agree
with the raw soak result. The embedded upstream record equals the corrected final live receipt:
both issues CLOSED, latest/installed 0.19.1 predating fixes, containing release/update and remaining
matrix qualification required. Delivery-audit and local-commit packaging fields remain PENDING.

Reviewed document checkpoint SHA256:

```text
fcd42e138cfa5f0712597a72ec3bf0557edfc9cd2161a6ecb7a4ac6001786246  docs/acceptance/m3.md
f08250eadf91af8e2cb556ad2c4e2638a320a178b37dea21b42de2b21e275699  docs/implementation-status.md
1d3147fd9b24c09e30c426369798e3c6cb056c3b8841dc6bd166a20506504468  docs/capabilities.md
6ce3284bcd46b2f2ff1cb541909605e8b90eaadbb8853610c29c80525d154ffe  docs/plans/m3-gateway.md
8e103cf4132f8136ee1bd5d94a8d7e3064d16cdcbb1791c2be7698281ab7101f  docs/plans/m3-upstream-groups.md
e502912cb5bb41f1641852979292b93f131e4b212bc87fc5ed0ccd1044e7e8d3  docs/designs/m3-soak.md
fe4ea0f888be75b98f416f23807e72fb02267131d6a82394e0162c24cf835c9d  docs/designs/m3-upstream-groups.md
12ee6b3485925ccd4ca473595e8f815d2cdd66c81426231f5f0ba3ee6038f452  docs/acceptance/evidence/m3/final-gates.json
719480397aff0ace9067066a6b71fa2dd482b7bc9e6a4b7d6f09004b4ae5763a  docs/acceptance/evidence/m3/upstream-state-final.json
```

This is the prepackaging document/manifest checkpoint; subsequent parent-owned commit/audit receipts
remain a distinct delivery step and do not change the tested runtime qualification.

## Separate final delivery-document quality closure

**Quality PASS; no actionable documentation/evidence-quality finding.** Separately checked readable
current versus historical status boundaries, local evidence links, manifest/receipt consistency,
fixed-profile exclusions, unsupported external JSON and upstream release distinctions. All local
Markdown links in the seven reviewed documents resolve. The artifact map excludes the manifest and
still-changing review/audit reports, avoiding circular or prematurely frozen report hashes; it names
no private-key artifacts. Pending packaging/audit fields accurately avoid claiming completed delivery.

Read-only metadata/hash/receipt/link assertions pass with exit 0. One earlier reviewer inspection
script raised `TypeError` because it treated the browser's integer executed-check count as a list;
the corrected inspection uses raw result names and passes every check. No runtime/test failure,
source mutation or repair round resulted. No Mix, fixture, import or runtime command was launched;
only this owned review report changed. Counters and full-M3 BLOCKED status remain unchanged.

During this closure the parent committed runtime/tooling through
`9eda1cae1eded7610e967472c64df82b6b6ad5d8` and updated only the reviewed manifest's packaging
receipt. Its new SHA256 is `60e67df884eef3ee637b3f15cc5097052238ba856e84bcb0c2e423abc3c4b505`;
the seven document hashes and all source/artifact hashes remain unchanged. Independent read-only
`git cat-file --batch` comparison confirms all 199 frozen file hashes equal committed blobs at
that delivery HEAD, exit 0. The tested HEAD remains `22b76e8`; no runtime gate rerun is claimed.
Documentation/evidence delivery and audit remain pending the parent's separate packaging step.
Specification/quality PASS remains valid for this receipt-only update; all reviewer commands finished.
