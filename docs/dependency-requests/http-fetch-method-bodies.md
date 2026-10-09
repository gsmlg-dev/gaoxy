**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m2-native`

**Severity:** blocker

Gaoxy M2 needs to forward the admitted HTTP method and request entity unchanged
through the public upstream client. Published `http_fetch`, `http_core` and
`http_runtime` 0.17.2 silently discard GET and DELETE bodies. This prevents
transparent reverse-proxy requests even after the fixes for #27–#30.

**Minimal reproduction:** Run a loopback HTTP peer that records its request head
and body, then returns an empty or small 200 response. Send the same request with
POST (control), DELETE and GET:

```elixir
HTTP.fetch(url,
  method: :delete,
  headers: [{"content-length", "3"}],
  body: "abc",
  http_version: :http1,
  redirect: :manual,
  telemetry: false,
  timeout: 2_000
)
|> HTTP.Promise.await(3_000)
```

Observed over actual TCP with the published Hex packages on Elixir 1.18.5 / OTP 28:

| Method | Expected body | Received body | Content-Length received |
|---|---|---|---|
| POST | `abc` | `abc` | `3` |
| DELETE | `abc` | empty | absent |
| GET | `abc` | empty | absent |

All three calls returned status 200. This is silent request mutation, not a
reported unsupported operation. `HTTP.Request.body_payload/1` in
`apps/http_core/lib/http/request.ex` returns nil for `[:get, :head, :delete]`,
and `put_body_headers/2` deletes Content-Length for that result. The public
Fetch API passes through this path. Streaming bodies encounter the same branch.

**Expected behavior:** Provide a supported public proxy/request mode which
preserves valid request bodies for the admitted HTTP method, including bounded
PID-streamed DELETE and GET bodies, fixed/chunked framing, declared trailers,
early final responses and cancellation. A browser-compatible default may remain,
but the proxy mode must neither drop bytes nor silently rewrite methods/framing.
Preserve the existing HEAD response-body rules independently of request bodies.

Gaoxy's executable reproduction is `integration/http_fetch_contract/method_body_probe.exs`
on branch `codex/m2-native`; it uses only public `HTTP.fetch/2` and a raw loopback
peer. It exits nonzero if any body changes. No dependency source is patched and
no private SocketClient/Request bypass or body-dropping local fallback is used.
