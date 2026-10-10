**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m2-native`

**Severity:** blocker

Gaoxy M2 needs bounded HTTP/1 reverse-proxy upload and response streaming. An
upstream may reject an unfinished upload (for example with 413); the proxy must
receive and forward that response without waiting for downstream upload EOF.

Audited `gsmlg-dev/http_fetch` revision
`a78c0a35d84921678de40e8623eeeae71389c4ce` (0.17.1), Elixir 1.18.5/OTP 28.
Reproduced through public `HTTP.fetch/2` against a loopback TCP peer. The peer
reads request headers and immediately replies with:

```http
HTTP/1.1 413 Payload Too Large
Content-Length: 0

```

Keep an upload stream open without sending body data:

```elixir
{:ok, upload} = HTTP.Stream.start_link(0)
HTTP.fetch(url,
  method: :post,
  body: upload,
  duplex: "half",
  http_version: :http1,
  redirect: :manual,
  timeout: 150
)
|> HTTP.Promise.await(2_000)
# Actual: {:error, :request_timeout}
# Expected: the 413 response, with unfinished upload stopped/cancelled.
```

The H1 owner completes `send_prepared_request` before activating socket reads
(`apps/http_fetch/lib/http/socket_client.ex`, lines 430-439). Its upload loop
handles stream/abort/deadline messages, so the early response remains unread.

Please expose concurrent H1 response reception during a credit-bounded upload,
including final response delivery, cancellation of pending upload work and
idempotent resource cleanup under the original deadline. Preserve no-replay
semantics and distinguish cancellation signalling from confirmed cleanup.
Regression cases should include early 413 with a stalled/open upload, response
body streaming, downstream cancellation, slow sends, owner death and bounded
retained bytes. No timeout increase can repair the protocol ordering.

This blocks Gaoxy's proxy slice; native HTTP/Plug work remains independent. No
dependency source modification or local workaround has been made. Related raw
response transparency requirement is already tracked by #27.
