**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m2-native`

**Severity:** blocker

Gaoxy M2's streaming reverse proxy needs bounded HTTP/1 request and response
trailers through the public upstream client contract. Audited revision
`a78c0a35d84921678de40e8623eeeae71389c4ce` (0.17.1).

Minimal response from a loopback peer:

```http
HTTP/1.1 200 OK
Transfer-Encoding: chunked
Trailer: X-Checksum

4
data
0
X-Checksum: expected

```

Call `HTTP.fetch(url, http_version: :http1, redirect: :manual)` and await its
response. Subscribe to `response.body` using `{:read_chunk, self(), :ack}`;
acknowledge each `{:stream_chunk, stream, bytes, ref}` with
`{:stream_chunk_ack, ref}`. Actual: body data followed by `{:stream_end, stream}`,
with empty `response.trailers` and no trailer event. Reproduced against untouched
upstream source on Elixir 1.18.5/OTP 28. The H1 codec discards trailer fields
(`apps/http_core/lib/http/http1.ex`, lines 198 and 403); Response documentation
explicitly records the H1 limitation. Upload stream termination also exposes no
H1 trailer path.

Expected: validated and byte/count-bounded H1 trailers delivered before stream
end, preferably matching the existing public H2/H3
`{:stream_trailers, stream, headers}` contract, plus a bounded upload completion
API accepting trailers. Reject forbidden framing/routing trailer fields and
malformed syntax; preserve ordered duplicate permitted fields, backpressure and
cancellation. Cover fragmented trailers, declared/undeclared trailer policy,
limits, negative fields and cancellation before completion.

This blocks the required proxy trailer-forwarding gate. Gaoxy will not parse
private upstream socket messages or silently discard trailers as a workaround.
