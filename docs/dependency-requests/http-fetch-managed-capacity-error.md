# Canonical managed H2 connection-capacity error

Upstream: [gsmlg-dev/http_fetch#89](https://github.com/gsmlg-dev/http_fetch/issues/89).
Type Bug; label `internal request`; severity needed.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** needed. Managed H2 connection capacity must retain its documented
public error shape while a GOAWAY owner drains. Finite rejection, isolation and
replacement behavior currently pass in our TLS fixture; this report does not
claim a capacity bypass, replay or measured leak. The separate aggregate
header/control bounds blocker is #86.

**Source/artifacts:** Installed coordinated HTTP packages 0.21.0, actual tag
`9813c126dc8b48055b9ee941c693fc27fa691489`; all196 shipped files and175 runtime
Git blobs match the containing artifacts. Elixir1.18.5, OTP28.5.0.7,
ERTS16.4.0.6, SSL11.6.0.6, x86_64 Linux.

**Minimal public reproduction:**

1. Open a public managed verified TLS H2 scope pinned to an independent peer,
   with `max_connections: 1`, `max_requests: 32`, `max_pending: 0`, finite
   timeouts, raw streaming and manual redirects.
2. Admit a request and hold its response after final headers. Send valid
   GOAWAY retaining that stream, then PING; observe the client PING ACK before
   the next admission. The first owner still occupies the one connection slot.
3. Fetch another request through the same opaque managed scope, capturing and
   awaiting its original public Promise/completion.
4. Actual rejection is `{:error, :pending_capacity}`. The facade documents
   `{:error, {:transport_scope_capacity, :connections}}`.
5. Confirm no new accept/request-frame bytes; finish the held stream, await
   original completion and public zero connection/request counts, then make
   one explicit replacement on a new connection. Independent scope B remains
   usable. Retire/await every scope and join the owned peer.

**Executed evidence:** Gaoxy
`integration/http_fetch_contract/managed_transport_probe.exs`,
`tls_max_connections_draining_before_bytes_no_pending_queue`. The run emits
`MANAGED_CAPACITY_ERROR_CONTRACT` with documented, source-predicted and observed
results and explicitly labels canonical compliance MISMATCH. Repair1 overall
exited1 after24 case receipts/25 successful peer cleanups due to a later unrelated
empty-response fixture dispatch error; this named capacity case passed its finite
resource-property checks before that error. All425 frozen source hashes matched,
no owned peer remained. h2c was not reached, so no h2c runtime claim is made.

**Source path:** Public facade `apps/http_runtime/lib/http/managed_transport.ex`
lines45–48 documents the canonical tuple. SocketClient466–482 propagates pool
reservation errors unchanged. H2 Pool504–505 returns `:pending_capacity` when
the zero-length pending queue is full during draining-owner saturation.

**Expected behavior:** Normalize this managed-scope saturation to the documented
connection-capacity tuple, or deliberately revise and document the public
contract. Preserve immediate bounded admission with no pending payload queue,
no new request bytes, healthy independent scopes, confirmed original completion,
retirement and no replay. Add verified TLS H2 and separate h2c public regressions
and publish containing artifacts before canonical compliance is claimed.
