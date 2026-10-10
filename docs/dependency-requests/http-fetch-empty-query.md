# HTTP Fetch empty-query preservation

Upstream: [gsmlg-dev/http_fetch#64](https://github.com/gsmlg-dev/http_fetch/issues/64),
type Bug, label `internal request`, OPEN when checked on 2026-10-10.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m2-native`

**Severity:** blocker for M2 reverse-proxy raw request-target preservation.

HTTP Fetch/Core 0.19.0 silently removes a present empty query delimiter. A request to `/upload?` reaches the origin as `/upload`. A transparent reverse proxy must preserve the escaped path and the distinction between an absent query and a present empty query; rewriting it can change origin routing, signatures, or cache identity.

Published packages: `http_fetch`, `http_core`, `http_runtime` 0.19.0, release `v0.19.0` at `09b1686fb2ce529a17287d97801107c53b1ac57c`. Installed library files match the release archive. Runtime: Elixir 1.18.5 / OTP 28.5.0.5 on Linux.

### Minimal reproduction

Run in a consumer with `{:http_fetch, "== 0.19.0"}`:

```elixir
request = %HTTP.Request{
  method: :get,
  request_mode: :proxy,
  url: URI.parse("http://example.test/upload?"),
  headers: HTTP.Headers.new([])
}
wire = request |> HTTP.Request.to_iodata() |> IO.iodata_to_binary()
IO.inspect(request.url.query) # ""
IO.inspect(hd(String.split(wire, "\r\n")))
# Actual:   "GET /upload HTTP/1.1"
# Expected: "GET /upload? HTTP/1.1"
```

A real loopback peer independently reproduced this through `HTTP.fetch/2` for both the string URL and `%URI{query: ""}` input with `request_mode: :proxy`, `http_version: :http1`, `http1_reuse: false`, `redirect: :manual`, `stream_response: true`, and `decode_body: false`. Both requests returned 200 and public RequestCompletion cleanup returned `:ok`; both actual request lines omitted `?`. Gaoxy end-to-end POST/GET/DELETE wire regressions show the same loss.

### Source and expected fix

`apps/http_core/lib/http/request.ex:120` uses `if uri.query && uri.query != ""` in `origin_form/1`, treating `""` and `nil` alike. H1 preparation calls `HTTP.Proxy.target/1`, which uses this serializer. The public Fetch options offer no raw request-target preservation option.

Preserve `?` when `URI.query` is the empty string, while keeping an absent (`nil`) query absent. Please add public serializer and real Fetch H1 tests for absent query, empty query, and nonempty escaped query, including streaming proxy requests. Check other protocol target serializers for the same distinction as appropriate.

Gaoxy has not patched dependencies, used private APIs, or rewritten URI path semantics as a workaround. Cancellation completion from #60 passes independently; this is a separate wire-identity blocker found during the newly unblocked proxy acceptance.
