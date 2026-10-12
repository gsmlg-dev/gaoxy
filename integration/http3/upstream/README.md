# Public upstream HTTP/3 contract qualification

This bounded prerequisite uses HTTP Fetch 0.21.3 public Fetch, Promise, Stream
and AbortController APIs against two independent aioquic 1.2.0 loopback origins.
Each origin has a distinct generated CA/leaf identity. No production adapter,
private client owner, native accounting ledger or reusable pool is introduced.
The origin credentials use P-256 certificate signatures allowed by the public
QUIC client profile; the original RSA PKCS#1 fixture rejection stays in evidence.

Under the coordinator's exclusive Mix/live lease, after strict compilation:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
  integration/http3/upstream/run.py --gate contract \
  --evidence docs/acceptance/evidence/m4/upstream-contract
```

The runner checks ordinary streamed download including repeated response
trailers for each authority, progressive streamed upload, repeated request
trailers with three bytes and zero DATA, and cancellation before headers and
with an unacknowledged response chunk. Explicit wire barriers precede upload
FIN and response FIN. Request-trailer `finish/2` returning `:ok` is recorded
separately from the asynchronous request result and missing origin trailers.
The public Session export list is an API audit, not a second live protocol test.

The first declaration-bearing upload failed before origin request HEADERS with
`Trailer request headers are not supported`. Its failed run and original
assertions remain immutable. A separate diagnostic now omits that declaration:
H3 trailing HEADERS do not require it. This exercises public `finish/2` after
actual origin DATA/zero-DATA barriers without enabling a production workaround.

Unique evidence directories retain logs, source hashes before/after, dependency
versions, observed wire bytes/FIN/trailers/cancellation, public task/stream DOWN,
owned child exits and UDP rebind. Disposable keys are never copied to evidence.
All readiness, wire and child waits are finite, with a total runner deadline.

Exit 2 means the required trailer feature was independently reproduced as
blocked; supported rows may individually PASS. Exit 1 is an unexpected failure.
Neither exit is full UP0 or M4 acceptance. TLS rejection variants, blocked-upload
and owner-loss cancellation, the production adapter and UP2 remain NOT RUN by
this minimal harness; retain them as separate requirements when the upstream
feature is available. The coordinator routes confirmed dependency gaps upstream
and supplies the actual issue marker at the affected probe callsite.
