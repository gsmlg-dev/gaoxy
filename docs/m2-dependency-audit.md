# M2 dependency audit — 2026-10-09

Source contracts were refreshed before native server implementation. These are
contract/provenance records; compatibility requires Gaoxy's own network and
browser acceptance.

| Package | Immutable upstream revision | Version | License | Selection |
|---|---|---|---|---|
| Plug | elixir-plug/plug `9fa11c8ebedbe68531eba25d8f81b9282e0514da` | 1.20.3 | Apache-2.0 | Exact Hex version and checksums in root lock |
| WebSock | phoenixframework/websock `1211bcc68739f284870c2afced76c81ecb64d911` | 0.5.3 | MIT | Exact Hex version and checksums in root lock |
| WebSockAdapter | phoenixframework/websock_adapter `80901f46c8864cb8bd5231c32b7171b9d0e330ce`; local fork `53ee1c7c9edb39fda9c531a5c79aec17ee081a6c` | 0.6.0 | MIT | Vendored immutable source, one runtime dispatch clause, independent review and wire regression passed; see `vendor/websock_adapter/GAOXY.md` |
| Phoenix | phoenixframework/phoenix `bd1801833b4fd7ceb02497cc7ba2d05e9bd391c8` | 1.8.15 | MIT | External fixture lock; browser and independent network acceptance passed |
| Phoenix LiveView | Exact Hex checksums in `examples/phoenix_native/mix.lock` | 1.2.12 | MIT | External fixture only; real click, binary upload and reconnect passed |
| HTTP Fetch umbrella | gsmlg-dev/http_fetch `a78c0a35d84921678de40e8623eeeae71389c4ce` | 0.17.1 | MIT; transitive ex_ssl Apache-2.0 | Audit only; required proxy contracts blocked |

The native server continues using the locked public Thousand Island socket
contract and OTP TLS. Core gains no HTTP application dependency. Phoenix stays
outside production's dependency graph. Vendored WebSockAdapter retains its
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
option. Duplicate headers survive ordered lists; converting headers to a map
would discard them.

`HTTP.AbortController.abort/1` signals cancellation; its return is not a cleanup
barrier or proof that an upstream request was unexecuted. No automatic replay is
appropriate. `redirect: :manual` prevents reverse-proxy redirect following.
The OTP SSL transport supports explicit verified TLS, CAs, hostname matching and
SNI; Gaoxy must not accept configuration that silently disables this policy.
H1 closes connections after responses; H2/H3 reuse does not establish H1 pooling.

An executable loopback probe of untouched selected H1 source established:

1. Gzip bytes were decoded in both buffered and ACK-streamed responses while
   original encoding/length headers remained. Unknown `raw_body`/`decompress`
   options were ignored. Existing blocker
   [#27](https://github.com/gsmlg-dev/http_fetch/issues/27) covers a raw mode.
2. A final 413 sent after request headers but before upload EOF was not received;
   the call timed out. The public H1 owner finishes upload before activating its
   read loop. Filed Bug
   [#28](https://github.com/gsmlg-dev/http_fetch/issues/28).
3. H1 chunk trailers were discarded, with no trailer event before stream end.
   Upload trailers are also absent. Filed Feature
   [#29](https://github.com/gsmlg-dev/http_fetch/issues/29).

Source inspection also proves H1 status 101 returns
`:unsupported_protocol_switch`, with no public upgrade/tunnel ownership path.
Filed Feature [#30](https://github.com/gsmlg-dev/http_fetch/issues/30).

These are blockers for M2's required proxy semantics. The proxy task stops until
the public contracts are fixed and the dependency updated. Native server,
WebSock/Phoenix and pure routing work continue independently. No alternate
private socket access, body collection, header rewriting or re-compression is
used to hide the gaps.

The [probe](../integration/http_fetch_contract/probe.exs) and
[observed log](../integration/http_fetch_contract/observed.log) preserve the
execution. It compiled only selected untouched H1 modules into memory with the
existing Telemetry dependency; uncompiled H2/H3 references produce warnings.
This is focused reproduction evidence, not full upstream package acceptance.
