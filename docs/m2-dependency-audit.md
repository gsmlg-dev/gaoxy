# M2 dependency audit — 2026-10-10

Source contracts were refreshed before native server implementation on
2026-10-09 and revalidated against published HTTP Fetch 0.17.2 on 2026-10-10.
These are contract/provenance records; compatibility requires Gaoxy's own
network and browser acceptance.

| Package | Immutable upstream revision | Version | License | Selection |
|---|---|---|---|---|
| Plug | elixir-plug/plug `9fa11c8ebedbe68531eba25d8f81b9282e0514da` | 1.20.3 | Apache-2.0 | Exact Hex version and checksums in root lock |
| WebSock | phoenixframework/websock `1211bcc68739f284870c2afced76c81ecb64d911` | 0.5.3 | MIT | Exact Hex version and checksums in root lock |
| WebSockAdapter | phoenixframework/websock_adapter `80901f46c8864cb8bd5231c32b7171b9d0e330ce`; local fork `53ee1c7c9edb39fda9c531a5c79aec17ee081a6c` | 0.6.0 | MIT | Vendored immutable source, one runtime dispatch clause, independent review and wire regression passed; see `vendor/websock_adapter/GAOXY.md` |
| Phoenix | phoenixframework/phoenix `bd1801833b4fd7ceb02497cc7ba2d05e9bd391c8` | 1.8.15 | MIT | External fixture lock; browser and independent network acceptance passed |
| Phoenix LiveView | Exact Hex checksums in `examples/phoenix_native/mix.lock` | 1.2.12 | MIT | External fixture only; real click, binary upload and reconnect passed |
| HTTP Fetch/Core/Runtime/WebSocket | gsmlg-dev/http_fetch v0.17.2 tag `500fbb90ce4eeddbba16b9bb5da91f70f0764995` | 0.17.2 | MIT | Exact published Hex packages/checksums in root lock; library files match release source; five public-API contract tests pass |
| elixir_quic / elixir_quic_http3 / ex_ssl | Same v0.17.2 source release; Hex checksums in root lock | 0.17.2 | MIT / MIT / Apache-2.0 | Transitive proxy dependencies; compilation does not imply H2/H3 or refreshed generic QUIC acceptance |

The native server continues using the locked public Thousand Island socket
contract and OTP TLS. Core gains no HTTP application dependency. Phoenix stays
outside production's dependency graph. The proxy package now transitively requires
QUIC/TLS-engine packages; the core-only consumer isolation gate applies only to
standalone core consumers. Vendored WebSockAdapter retains its
original MIT license and provenance; its optional Bandit/Cowboy integrations
must not install or activate a Bandit production backend.

## Plug, Phoenix and WebSock

Plug's mandatory callbacks include ordinary/chunked/file responses, body reads,
informational responses, upgrade, peer and version data. Its optional callbacks
include local/TLS data and push. Send callbacks send
`Plug.Conn.Adapter.already_sent/0` to the request owner. Fixed Content-Length
chunked API calls require fixed-length wire streaming, not added transfer coding.

Phoenix calls the configured adapter's `child_specs(endpoint, config)` and
`server_info(endpoint, scheme)`. Development reload supplies
`Phoenix.Endpoint.SyncCodeReloadPlug`; it does not require another server.
Endpoint-managed startup must own exactly one configured listener per scheme.

WebSock requires `init/1`, `handle_in/2`, `handle_info/2`; control/termination
callbacks are optional. The server assembles fragmented data messages, answers
ping automatically before control callbacks, handles all push/reply/stop
variants, and uses restart code 1012 for `{:shutdown, :restart}`. Service drain
uses 1001 with the existing shutdown deadline. Extensions/compression
require separate bounded implementation before negotiation.

WebSockAdapter has no generic native registration API at the audited revision.
Its private tuple dispatch rejects `Gaoxy.PlugAdapter`. The plan permits a
minimal reviewed fork adding that actual native adapter; no existing adapter
module is impersonated and fetched dependencies are not edited.

## HTTP Fetch public H1 client audit

The actual public path is `HTTP.fetch/2` then `HTTP.Promise.await/2`. PID body
uploads use `HTTP.Stream` and `duplex: "half"`. Response streams support explicit
ACK mode: `{:read_chunk, consumer, :ack}`, one
`{:stream_chunk, stream, bytes, ref}`, then `{:stream_chunk_ack, ref}`. The other
mode can send subsequent chunks eagerly and is unsuitable for bounded mailboxes.
Streaming is automatic for chunked/unknown or sufficiently large bodies; the
global threshold defaults to 5,000,000 bytes, without a per-request force-stream
option. A future proxy can require explicit static startup
`streaming_threshold: 0`, validate it at initialization and never mutate it per
request. Under this documented host constraint, per-request streaming issue
[#37](https://github.com/gsmlg-dev/http_fetch/issues/37) is not an M2 blocker.
Duplicate headers survive ordered lists; converting headers to a map would
discard them.

`HTTP.AbortController.abort/1` signals cancellation; its return is not a cleanup
barrier or proof that an upstream request was unexecuted. No automatic replay is
appropriate. `redirect: :manual` prevents reverse-proxy redirect following.
The OTP SSL transport supports explicit verified TLS, CAs, hostname matching and
SNI; Gaoxy must not accept configuration that silently disables this policy.
H1 closes connections after responses; H2/H3 reuse does not establish H1 pooling.

## Historical 0.17.1 blockers

The original audit selected gsmlg-dev/http_fetch
`a78c0a35d84921678de40e8623eeeae71389c4ce` (0.17.1). An executable loopback
probe of untouched selected H1 source established:

1. Gzip bytes were decoded in both buffered and ACK-streamed responses while
   original encoding/length headers remained. Unknown `raw_body`/`decompress`
   options were ignored. Then-open blocker
   [#27](https://github.com/gsmlg-dev/http_fetch/issues/27) covers a raw mode.
2. A final 413 sent after request headers but before upload EOF was not received;
   the call timed out. The public H1 owner finishes upload before activating its
   read loop. Filed Bug
   [#28](https://github.com/gsmlg-dev/http_fetch/issues/28).
3. H1 chunk trailers were discarded, with no trailer event before stream end.
   Upload trailers are also absent. Filed Feature
   [#29](https://github.com/gsmlg-dev/http_fetch/issues/29).

Source inspection at that historical revision found H1 status 101 returned
`:unsupported_protocol_switch`, with no public upgrade/tunnel ownership path.
Filed Feature [#30](https://github.com/gsmlg-dev/http_fetch/issues/30).

These blocked M2 proxy work on 2026-10-09. All four issues were subsequently
closed; the current release revalidation below supersedes their open status.
The historical probe and its observations remain intact.

The [probe](../integration/http_fetch_contract/probe.exs) and
[observed log](../integration/http_fetch_contract/observed.log) preserve the
execution. It compiled only selected untouched H1 modules into memory with the
existing Telemetry dependency; uncompiled H2/H3 references produce warnings.
This is focused reproduction evidence, not full upstream package acceptance.

## Published 0.17.2 revalidation

The root lock now selects the actual Hex packages `http_fetch`, `http_core`,
`http_runtime`, `http_web_socket`, `elixir_quic`, `elixir_quic_http3` and `ex_ssl`
at 0.17.2. Other existing lock entries are unchanged. Strict umbrella compilation
passed. The Fetch/Core/Runtime/WebSocket published library sources match the
v0.17.2 release archive byte-for-byte (15/30/18/10 files). The tag identifies
commit `500fbb90ce4eeddbba16b9bb5da91f70f0764995`; observed upstream main
`59d185ac745c2056a45ccabe37f7d8f64310ec05` is a different revision and is not the
release identity. Exact package identities and logs are preserved in
[the new evidence bundle](acceptance/evidence/m2/http-fetch-0.17.2/).

Five [public-API contract tests](../apps/gaoxy_proxy/test/http_fetch_contract_test.exs)
passed with the published dependency graph:

1. `decode_body: false` preserves buffered gzip bytes and duplicate headers.
2. ACK streaming preserves gzip bytes and delivers ordered trailers before
   terminal end, without assuming that TCP pieces equal HTTP chunks.
3. An early 413 is delivered while upload remains open and its upload source
   terminates.
4. `HTTP.Stream.finish/2` sends declared ordered upload trailers with H1 chunk
   framing.
5. Public `HTTP.WebSocket` preserves the first frame coalesced with the 101 head,
   negotiated subprotocol, ACK delivery, acknowledged text/binary writes,
   normal close and owner cleanup.

Original #27–#30 are CLOSED as of the 2026-10-10 issue refresh. Two remaining
required contracts fail against the same published packages:

| Contract | Observed result | Upstream blocker |
|---|---|---|
| Forward supported GET/DELETE request bodies | POST preserves `abc` with Content-Length 3; GET/DELETE send an empty body and remove Content-Length, while all calls return 200 | New Bug [#45](https://github.com/gsmlg-dev/http_fetch/issues/45), OPEN |
| Propagate valid WebSocket close codes | 1000 returns `:ok`; 1001/1008/1011 return `{:error, :invalid_close_code}` | Valid-close-code subset of Feature [#38](https://github.com/gsmlg-dev/http_fetch/issues/38), OPEN |

Both have the `internal request` label. The
[method-body probe](../integration/http_fetch_contract/method_body_probe.exs)
and [close-code probe](../integration/http_fetch_contract/websocket_close_probe.exs)
use public APIs and exit 1 when the required behavior fails. Their nonzero exits
are failed dependency gates, not passing acceptance. The close probe uses a
fresh native WebSock connection per code and confirms owner cleanup; its 1000
cleanup after a rejected code does not preserve the requested semantics.

M2 requires message-level WebSocket forwarding with valid close-code propagation;
exact frame fragmentation and ping/pong forwarding are not required. The proxy
task remains blocked on #45 and this subset of #38. No proxy endpoint, private
API bypass, method rewrite, body-dropping fallback or close-code mapping is
implemented. Native server, WebSock/Phoenix and local routing results retain
their independently recorded scope; full M2 is incomplete.
