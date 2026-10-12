# M4 upstream HTTP/3 and standalone integration

**Selected-client update, 2026-10-13:** The
[public Session design](m4-public-session-upstream.md) supersedes this document's
Fetch-specific upstream mechanism and qualification boundary. HTTP Fetch #101
is closed and 0.21.4 passes request-trailer diagnostics, but Fetch cleanup
completion remains unsupported. The original standalone scope, HTTP policy and
matrix remain required. The dated architecture and source identity below are
preserved as history; follow the [selected plan](../plans/m4-public-session-upstream.md)
with its reviewed [consumer-affinity amendment](m4-public-session-consumer-affinity.md)
and [task delta](../plans/m4-public-session-consumer-affinity.md).

Architecture candidate for independent Sol review, 2026-10-12. This supplements
[M4](m4-http3.md) and [shared HTTP integration](m4-shared-http.md); it does not
declare runtime acceptance. Implementation starts after G2 passes. Standalone
work may proceed independently of upstream-client qualification. G3 downstream
H3 -> dedicated H1 and Chromium/Phoenix acceptance remains separately required.

## Scope and source identity

Design inspected `codex/m4-http3` at
`42f0c0569ba556f8b08e5e2bbc1bc1d3acf0261e`, based on main
`78de9d0f3bba5a4662717359438eb3d0853a79b4`, with concurrent uncommitted G2 work.
The HTTP Fetch/QUIC cohort is 0.21.3; `mix.lock` SHA256 is
`16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25`.

Deliver fixed-authority reverse proxying with explicit upstream H3, independently
tested H1/H2 -> H3 and H3 -> H3, plus data-only standalone H3 listeners with local
route generations. Preserve H1 as the upstream default. Do not add H3 forward
proxying, CONNECT, upstream groups, reusable H1/H2 adapters, discovery/fallback,
automatic replay, WebSocket-over-H3, or operational certificate management.
Standalone static and H3-to-dedicated-H1 proxy acceptance proceeds after G3's
compatibility repair even if the separately selected H3 origin adapter is blocked.
Explicit H3 uses a fresh request identity (`http3_reuse: false`), not an advertised
Gaoxy connection pool. This flag alone is not a claim that the dependency closes
its idle connection immediately.

Publication, deployment, production changes, public management, Vault and the
disabled release-artifact E2E remain outside authorization. The dismissed
`http_fetch#97` proof is excluded; no exact native allocation/accounting gate is
introduced here. Normal functional cancellation, finite local lifecycle, actual
bounded streaming and honest capability reporting remain required.

## Public client audit and qualification decisions

These are source findings, not executed reproductions:

| Concern | Pinned source and conclusion |
| --- | --- |
| Protocol selection | `deps/http_fetch/lib/http/fetch_options.ex` exposes `http_version: :http3`, `http3_reuse: false`, `stream_response: true`, manual redirects, proxy request mode and disabled decoding. |
| Upload | Public `HTTP.Stream.start_link/1`, `chunk/3`, `finish/1` with a PID body and `duplex: :half` provide acknowledged streaming. H3 BodyBridge admits at most 65,536 bytes from one producer delivery and splits native writes into 16,384-byte pieces. |
| Response | Public `%HTTP.Response{http_version: :http3, stream: pid}`, Stream's documented acknowledged-reader messages, ordered headers and response trailers are available. SocketClient streams when explicitly requested; do not use buffered Response helpers. |
| TLS | `ssl: [cacertfile: path, verify: :verify_peer]` reaches the QUIC TLS validator. Trust is mandatory: no CA input produces `:ca_trust_required`. Host identity comes from URL host; DNS hosts get SNI, literal IPs require IP SAN. `verify_none` is rejected. Omit `tls_backend` and TCP `socket_opts`; H3 rejects them. |
| Address | FetchOptions rejects `connect_address` with `ArgumentError`, `connect_address is unsupported with HTTP/3, Unix sockets or proxies`. Reject H3 plus address pinning at Gaoxy initialization. A configured reverse authority does not need the forward proxy's address-authorization path; preserve that path on H1. |
| Request trailers | Public `HTTP.Stream.finish/2` documents H3 `:request_trailers_unsupported`. It can return `:ok` after enqueueing; H3 BodyBridge subsequently emits the error. No synchronous `finish/2` success proves trailers reached the origin. Never drop trailers or turn this into a successful response. |
| Cleanup | `HTTP.RequestCompletion.new/2` returns `unsupported: :http_version` for H3. Both public wait functions return `{:error, {:unsupported_completion, :http_version}}`. The ordinary H1 completion implementation cannot simply be delegated. |

The audit examined alternative supported cancellation APIs. `HTTP` and
`HTTP.Promise` export no cancel operation. `HTTP.AbortController.abort/1` is a
public cancellation request; its documented `:ok` confirms an Agent update, not
completion. Promise resolution precedes streamed-body completion. Stream terminal
messages/DOWN establish only the visible stream's state. `QuicHttp3.Session.abort/1`
and `close/1` apply to caller-owned sessions, but `HTTP.fetch` does not expose its
session. Fetching a private owner/session or inspecting AbortController's Agent
state to manufacture a completion receipt is outside this design.

The direct public Session alternative was also audited: `new/1`, `connect/4`,
`ready/1`, `open/1`, `request/4`, `send_data/5`, `reset_send/2`, `poll/3`,
`cancel/2`, `close/1`, `abort/1` and resumable operations exist. `request/4`
opens a new request; `send_data/5` emits DATA plus optional FIN. There is no
public trailing-HEADERS/send-trailers operation. Receiving response trailers is
implemented, but does not supply an upload operation. Consequently owning a
Session could supply a supported cleanup boundary, but cannot fulfill required
request-trailer preservation on 0.21.3. Do not inject encoded raw frames through
the Session's private stream handles. Both `http_fetch/mix.exs` and
`elixir_quic_http3/mix.exs` identify `https://github.com/gsmlg-dev/http_fetch` as
their source, so route the functional trailer feature there.

Recommended next action is a public-API functional qualification, before enabling
the adapter. Exercise AbortController on pending headers, blocked upload and a
response stalled after headers; observe public task/stream termination, finite
Gaoxy cleanup and independent origin cancellation. Inspect whether those supported
observations suffice for the existing Service cleanup contract. A cancellation
request alone must never call `Gaoxy.Service.complete_cleanup/2`. If no supported
transport-appropriate completion contract exists, route a narrow upstream Feature
request for request cancellation/completion, accepting an equivalent public H3
API instead of insisting on the H1 API name. This is not a demand for a full
native-resource ledger. Do not implement the dependent adapter behind a permanent
`cleanup_unconfirmed` result.

Request-trailer preservation is a required functional proxy row. Confirm the
documented rejection against the independent origin, then route a separate
upstream Feature request if still missing. Its scope is ordered trailing HEADERS
after acknowledged DATA/zero DATA, asynchronous failure propagation and early
response cancellation. Until supported, mark that row unsupported/blocked with
the exact reason; do not claim the full required upstream matrix passed. Both
upstream tasks can be pursued while standalone and G3 proceed. Issue creation,
dependency updates and reproductions belong to the coordinator's execution phase;
this two-document assignment performed none.

Audit source SHA256:

| File under `deps/` | SHA256 |
| --- | --- |
| `http_fetch/lib/http/request_completion.ex` | `2579b9bbae473603227bcf0edc9509adb8c070927d44fb4e141e7d11160bcb9f` |
| `http_fetch/lib/http/abort_controller.ex` | `82dd7af703720aa49e1a798275f92a81120e983c2133aee548ae02c96523ae93` |
| `http_fetch/lib/http/stream.ex` | `552c5951d30c21ce864a77c1a61dc5e8bcda038559040028e4f3282074325d05` |
| `http_fetch/lib/http/fetch_options.ex` | `8e035e1ec4a8c3afb68731ceb325ddf1cd1b5a780bd1b2a063e3f417241b6061` |
| `http_runtime/lib/http/http3/body_bridge.ex` | `7e8111e37f1aab2074878f70efbdd95620dffa2883edca3b49ff6b799aea9f94` |
| `http_core/lib/http/quic/tls_options.ex` | `43f9309449c14be7b10fb1eb6a2b51f6b8b0431d624b26de9f25d74a8c17763e` |

## Selected adapter boundary

Add `Gaoxy.Proxy.HTTP3FetchClient` implementing `UpstreamClient`. Extend the
behavior only for methods already needed by the proxy: `host_supported?/0` and
`reservation_bytes/3`. H1 retains `HTTPFetchClient`; H3 fixes its own options,
capabilities, delivery ceiling and cleanup handle. Keep the small protocol-specific
adapters separate rather than refactoring the qualified H1 transport internals.

`Gaoxy.Proxy.HTTP.init/1` accepts `upstream_protocol: :http1 | :http3`, defaulting
to H1, and stores its allowlisted client module in the normalized configuration.
Users cannot inject a module, arbitrary Fetch options or reuse policy. H3 requires
HTTPS and a regular `cacertfile`, rejects `connect_address`, and uses an explicit
positive upload chunk limit at most 16,384 bytes (default 16,384 for H3 only).
H1 keeps existing chunk defaults and TLS behavior. Reinitializing a config struct
must revalidate protocol/client consistency rather than accepting forged clients.

The endpoint still owns downstream reads/writes; Session owns the Promise,
response subscription, one unacknowledged delivery, cancellation state and cleanup
token. Replace hardcoded H1 calls in both with the selected client. GroupEndpoint
continues selecting H1 explicitly; `UpstreamGroups.Options` rejects H3 before
activation, including precompiled struct revalidation, so H1-only probes and
reservations never operate on an H3 member. ForwardHTTP continues constructing
H1 configurations after authentication and connection-time address validation.

Keep the existing handle contract (`promise`, `stream`, `resolved`) explicit, or
return the stream-present bit with the headers event if the implementation needs
an opaque handle. Do not allow Session to inspect transport-private processes.
After member selection, the Session client must still match the endpoint client;
mixed-protocol groups are outside scope. Upload write/finish uses the same selected
module as Session; changing only Session would leave an incorrect H1 upload path.

The H3 Fetch call supplies URL, method, normalized headers, stream PID/nil body,
half duplex when uploading, `http_version: :http3`, `http3_reuse: false`,
`redirect: :manual`, `request_mode: :proxy`, `decode_body: false`,
`stream_response: true`, explicit CA trust, remaining total/opening deadlines and
disabled telemetry. No network fallback or transparent application replay occurs.
Check `response.http_version == :http3` before admitting its head.

### Bounds, semantics and cleanup

One Stream producer write is outstanding at a time. A write timeout cancels the
request; it never replays the same bytes. Session acknowledges a response chunk
only after downstream Response accepts it. Cap one H3 delivery at 65,536 bytes,
validate response/trailer count/bytes against Exchange's existing limits before
forwarding, and fail visibly on an unexpected larger delivery. The pinned runtime
has finite H3 delivery queues and receive budgets; qualification records application
queue/lease bounds and independent slow-peer behavior, not total VM/native memory.

Use a conservative per-request Gaoxy payload reservation of
`8 * 262_144 + 8 * max_chunk_bytes + 2 * external_size({headers, ""}) + 2 * url_bytes`.
This covers the inspected 262,144-byte session retained-data ceiling plus bounded
copies/stream handoffs with headroom. It is deliberately not a native allocation
measurement; re-audit the constant when updating the dependency. Admission can
reject a proxy route when the remaining service budget is insufficient. Do not
silently shrink a reservation to make a small-budget fixture pass.

Preserve duplicate header order, escaped paths and present empty query, raw
compression, HEAD/204/304 semantics, and trailer allowlist/hop-field policy.
G3's shared header compatibility repair must recognize H3 framed requests and
responses; this slice consumes that change instead of duplicating it. Existing
trailer declaration policy stays in force even though H3 wire framing differs.
An early final response stops request-body production and cancels unread data
without harming sibling streams. An upstream error before final headers maps to
the existing 502/504 rules; after commitment it terminates the stream.

Keep one original request deadline, narrowed by existing total/opening/write limits.
Cleanup retries use the existing deadline plus finite cleanup headroom. H3 cleanup
must have a qualified public contract before the guardian releases its Service
token and reservation. If a public API returns uncertainty, preserve the error;
never equate a sent abort, timed-out call or dead response task with confirmed
cleanup. The selected API may differ from H1 without changing this invariant.

### Alternatives

1. **Selected: protocol-specific Fetch adapter with shared Session.** Smallest
   application change, preserves HTTP policy and ownership; requires qualifying
   the H3 public lifecycle/trailer gaps above.
2. **Own a public QuicHttp3.Session client in Gaoxy.** Provides direct session
   abort/close access, but needs a second client scheduler, upload writer,
   reconciliation and response-demultiplexing implementation, and still lacks
   request trailers in this cohort. It is not a private API workaround, but is
   a larger architecture change and is not selected here.
3. **Enable dependency auto/reuse or copy private H3 owners.** Auto/reuse changes
   the advertised transport contract; private ownership violates project bounds.
   Neither is selected.

## Standalone data-only H3

Retain configuration version 1. An H3 listener uses explicit `handler: "http3"`,
`transport: "quic"` and `protocols: ["http3"]`; require that exact protocol list
for this new handler. Existing `handler: "http"` keeps the H1 default and existing
H1/H2 selection. Reject mixed lists, wrong transport, `h2c`, `h2_limits`, `udp`,
`handler_options`, arbitrary endpoint/Plug/module fields, wildcard/IPv6 binds and
TLS provider/ALPN overrides for the H3 branch. `mode` may only be `unicast`.

Accept existing `routes`, `limits`, `http_limits`, and explicitly allowlisted
`h3_limits` keys from HTTP3.Options. Use only `tls.certfile` and `tls.keyfile`;
`HTTP3.service_spec/1` fixes `quic.alpn` to `["h3"]`. Do not expose general QUIC
or dependency options in JSON. For example, a local fixture configuration is:

```json
{
  "version": 1,
  "services": [{
    "id": "h3", "handler": "http3", "transport": "quic",
    "protocols": ["http3"], "ip": "127.0.0.1", "port": 0,
    "tls": {"certfile": "/tmp/gaoxy-fixture/cert.pem", "keyfile": "/tmp/gaoxy-fixture/key.pem"},
    "limits": {"max_bytes": 33554432},
    "routes": {"version": 1, "routes": [{"target": {"type": "static", "body": "h3"}}]}
  }]
}
```

Add the existing umbrella `gaoxy_http3` app to `gaoxy_server` dependencies. This
changes standalone's declared runtime closure, not `gaoxy`/`gaoxy_http` consumer
closure; no new external package/version is needed. The existing release's
`gaoxy_server: :permanent` declaration then includes the H3 runtime naturally.
This is source-level standalone qualification, not permission to build/publish
a new release or enable release-artifact E2E.

Both HTTP handlers share Router compilation, configuration byte limits, registered
static/reverse-proxy targets and local Generation stores. RouteConfig adds only
`upstream_protocol: "http1" | "http3"` for reverse_proxy targets, maps strings
without atom creation and keeps omission as H1. H3 route activation depends on
the upstream qualification gate; standalone static/H1 routes do not depend on it.
Unknown values fail before listener bind or generation activation.

### Generation initialization and budget

The existing supervisor recognizes only `Gaoxy.HTTP.Connection`, and the H3
handler does not rerun endpoint initialization via core Config. Merely swapping
H3's endpoint to `{Generation, name}` with `initialized: false` is incorrect.

Recognize both concrete handlers for route-store creation. Keep stores before
the runtime under `:rest_for_one`. Add a small internal runtime-start function
in `Gaoxy.Server.Supervisor`: its child MFA runs after the Registry and stores
start, calls public `Generation.init(route_store(id))` for each H3 route endpoint,
then substitutes `{Generation, initialized_options}` before `Gaoxy.start_link`.
Preserve the Gaoxy child's restart/shutdown policy. Reinitialize against the new
store PID on every runtime restart; do not capture the old store PID in the
supervisor's original child args. H1's existing normalization remains unchanged.
No core handler contract or new per-request process is needed.

Registry profiles for H3 carry `protocols: [:http3]` and normalized `http_limits`;
this is standalone validation metadata, not an input to H1/H2 Options.normalize.
StaticEndpoint.validate_limits treats H3 as framed fields including `:status`,
counts UTF-8/binary field bytes using the existing framed header-size convention,
and preserves content-length/bodyless validation. Both initial config and local
reload validate the profile before activation. Listener settings and credentials
still require restart; route reload never changes transport or opens management.

For standalone H3, require service `max_bytes` at least
`connection + max_streams * (request + 2 * max_config_bytes) + writer`, with the
reservations from HTTP3.Options and `max_config_bytes = 1_048_576` as today.
The added two snapshots per admitted request cover Generation.call's route-byte
charge; using H1's single-request snapshot allowance would underbudget concurrent
H3 requests. Preserve HTTP3.Options' independent `max_state`, ingress/output and
max-active checks. Proxy cleanup reservations remain separately admitted when
requests execute. This is a capacity admission check, not a promise of unlimited
upstream sessions or total native-memory accounting.

## Acceptance boundaries

UP0 qualifies public client operations against an independent aioquic origin and
records gaps; UP1 tests the adapter and existing H1/proxy policy compatibility;
UP2 proves H1/H2/H3 downstreams to the independent H3 origin with two distinct
origin identities and isolated cancellation. ST1 covers strict data-only decode,
generation profiles/budgets and H1 compatibility; ST2 runs a standalone child with
ephemeral credentials/ports, reload rollback, startup rollback, bounded shutdown
and UDP port rebind after ownership is released. The [plan](../plans/m4-upstream-standalone.md)
sets exact owners, commands and cases. Every live gate needs nonzero checks,
immutable source hashes, child exit evidence and independent Sol review.

No runtime checks were executed for this architecture assignment. H3 upstream
cleanup/trailers remain qualification prerequisites, all new matrix/standalone
runtime rows are NOT RUN, and existing G2 edits remain owned by their writers.
Architecture consumes zero Astra recovery rounds. Received counters are Connection
Sol3/unsuccessful2/Astra1/unsuccessful0 and Options Sol4/unsuccessful1/Astra0;
neither counter is reset or extended by this document.
