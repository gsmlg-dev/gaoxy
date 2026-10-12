**Requesting repo:** `gsmlg-opt/gaoxy` on branch `codex/m4-http3`.

Gaoxy M4 requires forwarding ordered repeated request trailers to a fixed
HTTP/3 origin through the public Fetch/Stream APIs, including a zero-DATA body.
The pinned HTTP Fetch cohort 0.21.3 supports ordinary HTTP/3 upload/download and
response trailers, but rejects request trailers.

**Expected behavior:** `HTTP.Stream.finish/2` sends trailing HEADERS preserving
ordered duplicate fields, followed by request FIN, for nonempty and zero-DATA
H3 uploads. A supported public caller observes completion or an actionable
failure. H3 trailing HEADERS do not require a `Trailer` declaration; if an
application supplies an otherwise valid declaration, it should not crash the
H3 request-header builder.

**Minimal public reproduction** against a real H3 origin that returns a final
response only after request FIN (`url` and `ca` refer to ephemeral loopback
fixtures):

```elixir
{:ok, upload} = HTTP.Stream.start_link(0)
promise = HTTP.fetch(url <> "/echo-three",
  method: :post, body: upload, duplex: :half,
  http_version: :http3, http3_reuse: false, redirect: :manual,
  request_mode: :proxy, stream_response: true, decode_body: false,
  ssl: [cacertfile: ca, verify: :verify_peer], timeout: 3_000)
:ok = HTTP.Stream.chunk(upload, "abc", 1_000)
# Independent origin wire barrier: exact "abc" received, request FIN false.
:ok = HTTP.Stream.finish(upload, [{"x-check", "one"}, {"x-check", "two"}])
HTTP.Promise.await(promise, 4_000)
# Actual: {:error, :request_trailers_unsupported}
# Origin: three DATA bytes, no trailers, no request FIN.
```

Repeat omitting `chunk/3`: the origin sees initial request HEADERS with zero
DATA and no FIN; `finish/2` returns `:ok`, then the Promise reports the same
error. Both public upload streams and Promise tasks terminate. No origin retry
is observed.

A separate declaration-bearing probe with `headers: [{"trailer", "x-check"}]`
fails before origin request HEADERS. Its chunk operation returns an
`:http3_stream_down` error containing
`%ArgumentError{message: "Trailer request headers are not supported"}`.
The path is `HTTP.HTTP3.Stream.headers/1` → `HTTP.HTTP2.base_request_headers/1`
→ `HTTP.Request.reject_unsupported_request_framing!/1`.

**Independent evidence:** Gaoxy HEAD
`29d79f95b78d112a1d8e1661d108b788f7780f3f`, HTTP Fetch 0.21.3, Elixir 1.18.5,
OTP 28, independent aioquic 1.2.0. Source-bound run
`run-1791811050964927834` executed seven rows: five supported rows PASS and two
required trailer rows BLOCKED. Each origin/path was requested exactly once.
Ordinary progressive upload, repeated response trailers on two separately
certified authorities, public cancellation before headers and during an
unacknowledged response chunk succeeded. Both owned children exited 0 and both
UDP ports rebound. Earlier declaration failure remains FAIL in
`run-1791792452444772174`; the fixture TLS failure is separately preserved.

Public `QuicHttp3.Session` exports include `request/4` and `send_data/5`, but no
upload-trailer operation in this cohort. This is an export audit, not a second
live protocol test. No dependency-private transport, owner lookup or local
production workaround was used.

**Severity:** blocker for M4 upstream-H3 request-trailer support. Independent
downstream H3 and standalone work can continue. This request concerns functional
trailers; successful public cancellation rows remain successful.
