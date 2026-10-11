## Current 0.21.3 disposition — 2026-10-11

Feature#66 is contained in installed0.21.3. The original0.19.1 contract
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

**Severity:** blocker

**Status:** FIXED IN INSTALLED 0.20.0 — [gsmlg-dev/http_fetch#66](https://github.com/gsmlg-dev/http_fetch/issues/66)
(Feature, `internal request`).

**Current state:** #66 is CLOSED and its fix is contained in installed0.20.0,
actual tag `951ec75dadcebd8218f30d3ecdf99da142d4a463`. Positive public-network
request qualification passes [16/16 cases](../acceptance/evidence/m3/upstream-0.20/public-probes-final.json).
Gaoxy transport activation remains BLOCKED on the
separate [managed-resource prerequisite #78](http-fetch-managed-transports.md)
and remaining bounds/qualification. The text and negative evidence below are
the historical0.19.1 contract, not the current installed API.

Gaoxy M3 requires upstream HTTP/1 connection reuse and HTTP/2 multiplexing while
retaining its request-scoped cleanup barrier. The proxy holds request resource
reservations until `HTTP.RequestCompletion.await/2` or `abort_and_await/2`
confirms cleanup. A response Promise or response stream ending cannot replace
that barrier.

The pinned Hex dependency is `http_fetch` 0.19.1, whose package `mix.exs` names
`https://github.com/gsmlg-dev/http_fetch` as its source. The published tag
`v0.19.1` resolves to `c26a17712a02a03985a764b6b100ca840fcc4349`.
`apps/http_fetch/lib/http/request_completion.ex:29-33` explicitly rejects
`http_version != :http1` and `http1_reuse: true`. The installed source matches
the previously verified release source; its SHA-256 is
`d923c66fe99a2ccc736e9bf283a2d25234a0c629d5262dcd29d1944de9df1c03`.
Closed issue [#60](https://github.com/gsmlg-dev/http_fetch/issues/60) deliberately
covered dedicated HTTP/1 only, so this is a separate feature extension.

**Public reproduction:**

```elixir
promise = HTTP.fetch(url,
  http_version: :http1,
  http1_reuse: true,
  redirect: :manual,
  tls_backend: :ssl,
  stream_response: true,
  decode_body: false,
  telemetry: false
)
completion = HTTP.Promise.completion(promise)
HTTP.RequestCompletion.await(completion, 0)
# => {:error, {:unsupported_completion, :http1_reuse}}
HTTP.RequestCompletion.abort_and_await(completion, 0)
# => {:error, {:unsupported_completion, :http1_reuse}}
# With http_version: :http2, both return:
# => {:error, {:unsupported_completion, :http_version}}
```

The local deterministic probe is
`integration/http_fetch_contract/pooled_completion_probe.exs`. It exercises
these public option gates against a passive loopback listener with a finite
request deadline. It does not claim pooled-wire or HTTP/2 interoperability
acceptance. HTTP/2 uses an HTTPS URL; the passive peer intentionally never
completes TLS. Runtime evidence is recorded under
`docs/acceptance/evidence/m3/upstream/`.

**Executed evidence (2026-10-10):**

```sh
nix develop --command bash -c "export ERL_FLAGS='+S 4:4'; export MIX_ENV=test; unbuffer mix format --check-formatted integration/http_fetch_contract/pooled_completion_probe.exs apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex && unbuffer mix run --no-compile --no-start integration/http_fetch_contract/pooled_completion_probe.exs"
```

Exit 0; format check PASS; two public option-gate probes PASS. Runtime:
Elixir 1.18.5, OTP 28, ERTS 16.4.0.6, HTTP Fetch 0.19.1. Both `await/2` and
`abort_and_await/2` returned the exact unsupported tuples shown above.
The HTTP/1 Promise settled as `{:error, :request_timeout}` and the HTTP/2
Promise as `{:error, :connect_timeout}` after the intentionally unresponsive
peer. These bounded Promise results do not establish request cleanup; the
completion results establish the missing public contract. Full output:
[pooled-completion-probe.log](../acceptance/evidence/m3/upstream/pooled-completion-probe.log).
Pooling/upstream-H2 runtime acceptance remains BLOCKED on #66.

**Expected behavior:** Extend the supported public completion contract to
reused HTTP/1 requests and HTTP/2 requests, including pooled HTTP/2 streams.
The handle must be available before dialing and permit finite, repeated,
concurrent cleanup waits and cancellation across connection establishment,
TLS, upload, early response, and post-header response streaming. Define normal
completion, cancellation before owner registration, owner death, pool wait,
and deadline expiration; distinguish cleanup pending and cleanup unconfirmed.

For HTTP/1, successful completion confirms request-owned helpers and body
streams have terminated and the connection has either been safely returned
to the pool or closed. It does not require closing a reusable idle connection.
For HTTP/2, successful completion confirms request-owned streams, helpers,
queued deliveries, and pool reservations have been settled; cancellation must
preserve a healthy shared connection and unrelated sibling streams. Do not
report `:ok` merely because a reset was enqueued or response EOF was delivered.
Cover these conditions with deterministic barriers, including a live sibling
stream during cancellation and delayed cleanup after an early response.

Gaoxy will retain the dedicated HTTP/1 client configuration until the upstream
issue is resolved, a containing dependency release is installed, and focused
cleanup/cancellation/pool regressions pass. Pooling and upstream HTTP/2 are
blocked; independent server HTTP/2 work can proceed. No private connection
process inspection, dependency patch, or unconfirmed-cleanup workaround is
permitted.

**Additional HTTP/2 limitation:** In the same release,
`apps/http_fetch/lib/http/http2/body_bridge.ex:143-147` handles request
`{:stream_trailers, ...}` by stopping the stream with
`:request_trailers_unsupported`. Response trailers have a separate supported
path; they do not establish request-upload trailer support. This source finding
must be included in M3's design gates. It is not covered by the completion
feature request, and no request-trailer wire acceptance has been run here.
