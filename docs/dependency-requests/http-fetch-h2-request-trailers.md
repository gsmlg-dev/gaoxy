## Current 0.21.3 disposition — 2026-10-11

Feature#67 is contained in installed0.21.3. The original0.19.1 contract
and0.20.0 containing-release observations below remain historical.

Installed coordinated packages are **0.21.3**, tag
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Compatibility486/0, public
managed39/39, supplemental TLS95 five cases/five cleanups, H1 baseline20/0,
B21 and public H2 supplement8/8 (TLS4/h2c4) pass with owned joins.
See [current acceptance](../acceptance/m3.md) for the exact execution receipts.
Five acquired-request failure regressions and final delivery review are pending.

Feature [#97](http-fetch-managed-h1-control-frontier.md) remains OPEN and blocks
complete H1 numerical/native control accounting and managed activation. Full
H2 accounting/adversarial backlog, managed integration, matrix and soaks remain
unqualified; managed Tasks4–8 and M4 stay gated. No local workaround is used.

## Historical containing-release disposition and request

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker — upstream HTTP/2 request-trailer proxy matrix only.

**Status:** FIXED IN INSTALLED 0.20.0 — [gsmlg-dev/http_fetch#67](https://github.com/gsmlg-dev/http_fetch/issues/67)
(Feature, `internal request`).

**Current state:** #67 is CLOSED and its fix is contained in installed0.20.0,
actual tag `951ec75dadcebd8218f30d3ecdf99da142d4a463`. Positive public-network
request qualification passes [16/16 cases](../acceptance/evidence/m3/upstream-0.20/public-probes-final.json),
including normal/empty/split H2 upload trailers for verified TLS and h2c.
The full Gaoxy version matrix remains BLOCKED on
the separate [managed-resource prerequisite #78](http-fetch-managed-transports.md)
and remaining H2 bounds/qualification. The text and negative evidence below
describe the historical0.19.1 contract, not the current installed API.

Gaoxy M3 must preserve admitted request trailers when proxying to an HTTP/2
upstream. HTTP Fetch 0.19.1 provides bounded streaming uploads and public
`HTTP.Stream.finish/2`, but explicitly rejects request upload trailers in its
HTTP/2 body bridge. Response-trailer support does not establish upload support.
The existing product requirement is `implement-plan.md` §7.2: bounded streaming
both directions with trailers retained across different HTTP versions.

**Package/source evidence:** `apps/gaoxy_proxy/mix.exs` pins Hex `http_fetch`
0.19.1; its package `mix.exs` identifies `gsmlg-dev/http_fetch`. Tag `v0.19.1`
resolves to `c26a17712a02a03985a764b6b100ca840fcc4349`. Installed
`lib/http/http2/body_bridge.ex` matches the release-audited source byte-for-byte
(SHA-256 `b3a6efc4b1f6cca591d2d90e9415cb31dda9da91b5eb617110ca91b2f974a244`).

- Public `apps/http_fetch/lib/http/stream.ex:123-130` documents that H2/H3 upload
  bridges currently reject these trailers as `:request_trailers_unsupported`.
- `HTTP.Stream.finish/2` validates trailers, sends `{:finish, headers}`, and
  emits `{:stream_trailers, ...}` before the terminal stream event.
- `apps/http_fetch/lib/http/http2/body_bridge.ex:143-147` receives that trailer
  event and calls `stop_stream(state, :request_trailers_unsupported)`.

Closed [#29](https://github.com/gsmlg-dev/http_fetch/issues/29) deliberately
covered HTTP/1 trailers. [#66](https://github.com/gsmlg-dev/http_fetch/issues/66)
covers pooled request completion, a separate prerequisite. Neither supplies
the missing HTTP/2 upload-trailer contract.

**Public API reproduction sequence:** Against a validating loopback HTTP/2 TLS
peer that consumes the complete request before responding:

```elixir
{:ok, upload} = HTTP.Stream.start_link(1_024)
promise = HTTP.fetch(h2_tls_url,
  method: :post,
  body: upload,
  duplex: :half,
  http_version: :http2,
  redirect: :manual,
  stream_response: true,
  decode_body: false,
  tls_backend: :ssl,
  ssl: [cacertfile: fixture_ca_path],
  timeout: 5_000,
  telemetry: false
)
:ok = HTTP.Stream.chunk(upload, "data", 2_000)
:ok = HTTP.Stream.finish(upload, [{"x-checksum", "expected"}])
HTTP.Promise.await(promise, 6_000)
```

The public documentation and source establish rejection at the body bridge;
this sequence has not been executed as an HTTP/2 wire test in Gaoxy. Record its
runtime status as NOT RUN, not a reproduced wire failure. Source review is
sufficient to identify the explicitly unsupported contract without calling
private connection/body-bridge APIs or patching dependencies.

**Expected behavior:** Support validated HTTP/2 request trailers through the
public streaming upload API. After ordered DATA, emit the trailing HEADERS
block with END_STREAM, preserving ordered duplicate permitted fields and
connection-wide HPACK state. Keep finite field/serialized-byte limits, bounded
buffering, send deadlines, and demand/cancellation semantics. Reject forbidden
framing/routing fields and pseudoheaders before wire emission; report an
explicit request-local error rather than discarding trailers or closing healthy
siblings. Define behavior for an early final response and cancellation before,
during, and after trailer transmission. Fixed content length validates DATA
bytes independently from trailer metadata.

Qualify with an independent HTTP/2 TLS peer: exact request body and trailers,
empty body with trailers, duplicate allowed fields, malformed/forbidden fields,
header-size bounds, fragmented CONTINUATION output, slow peers, reset/early
response, and a concurrently active sibling. Public request cleanup must still
meet #66's separate contract before Gaoxy enables upstream HTTP/2.

Gaoxy will not silently drop trailers, inspect private upstream state, or
replace the upstream upload bridge. Upstream-H2 trailer acceptance stays
blocked until a containing release is installed and its focused wire tests
pass. Dedicated H1 proxying, downstream H2, policies, and raw relays remain
independently implementable. This request does not expand the H3 milestone.
