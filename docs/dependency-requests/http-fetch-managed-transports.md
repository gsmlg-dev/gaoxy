# HTTP Fetch managed reusable transport prerequisite

**Status: BLOCKED** on [Feature #78](https://github.com/gsmlg-dev/http_fetch/issues/78).
Issue type Feature, label `internal request`, severity blocker.

The seven coordinated 0.20.0 packages are installed; #66/#67 are contained
in that release. The new [public source audit](../acceptance/evidence/m3/upstream-0.20/public-client-audit.md)
and [release provenance](../acceptance/evidence/m3/upstream-0.20/release-provenance.json)
distinguish request completion from pool ownership and confirmed retirement.
Gaoxy reusable H1/upstream H2 activation stays disabled; dedicated H1 remains
the current adapter policy. No dependency source/private-process workaround is used.

## Routed request

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker for M3 reusable HTTP/1 and upstream HTTP/2 activation. Dedicated HTTP/1 and other gateway work can continue.

Gaoxy needs to retain upstream transports during in-flight immutable route generations, then confirm their retirement on generation/service shutdown while preserving sibling requests. The published v0.20.0 request-completion fixes (#66/#67) are installed and appreciated; per-request completion does not provide ownership or retirement of a reusable pool.

**Verified source:** v0.20.0 commit `951ec75dadcebd8218f30d3ecdf99da142d4a463` (all seven coordinated Hex packages at 0.20.0).

- `apps/http_fetch/lib/http/fetch_options.ex` lines 135-165 and option merge from 285 expose protocol scope/profile and H1 idle options, but no caller-owned transport/pool handle.
- `apps/http_fetch/lib/http/socket_client.ex` lines 426-447 and 718-747 select the globally registered `:http_fetch_http2_pool`.
- `apps/http_runtime/lib/http_runtime.ex` lines 6-12 starts global H1/H2 pools. The H1 pool is internal; H2 exposes low-level connection methods but neither Fetch pool injection nor whole-scope acknowledged retirement.
- H2 pool defaults are finite, but not selectable per Gaoxy service through Fetch. An idle timeout cannot acknowledge that the retired service owns zero sockets/processes/buffers, and retiring the global pool would affect unrelated clients.

**Current supported usage that demonstrates the gap:**

```elixir
promise = HTTP.fetch(url,
  http_version: :http1,
  http1_reuse: true,
  http1_scope: "route-epoch-1",
  http1_idle_timeout: 60_000,
  request_mode: :proxy,
  redirect: :manual,
  decode_body: false,
  stream_response: true
)
completion = HTTP.Promise.completion(promise)
# After draining the response, RequestCompletion.await/2 confirms this request's
# completion/return. The reusable healthy socket can remain in the global pool.
# There is no public Fetch transport handle or whole-scope retirement receipt.
```

The H2 scope option similarly isolates a connection key but does not provide whole-scope lifecycle ownership. Calling private processes, inventing their names, terminating a shared global pool, or waiting an idle timeout is not an acceptable local substitute.

**Expected public behavior / acceptance:**

1. An opaque, caller-owned managed transport/pool scope that `HTTP.fetch/2` can select for reusable H1 and multiplexed H2. Independent owners cannot reuse each other's transports.
2. Validated finite capacity for owned connections, active/pending requests/streams, idle retention, and buffered/retained protocol state (or documented enforceable finite bounds). Capacity exhaustion has an explicit bounded failure; no unbounded queues.
3. Immutable pooling identity includes numeric dial destination and security policy: authority/SNI, verification mode, CA contents/policy version and credentials/client certs where supported, plus transport settings. Different request/connect/write deadlines retain their per-request semantics and must not accidentally share mutable socket settings.
4. Public retirement with a finite deadline: stop admission, retain already-admitted live siblings while they complete/cancel, close idle and then remaining owned transports according to the explicit graceful/abort policy, and acknowledge confirmed absence of owned sockets/processes/buffers. Deadline expiration remains explicit pending/uncertain; do not report cleanup success prematurely.
5. Public bounded status/snapshot and retirement receipt sufficient for independent network tests and service/generation resource accounting. Existing per-request `RequestCompletion` remains separate and usable.
6. Qualification: same-origin H1 reuse and stale-socket/no-replay behavior; concurrent H2 sibling cancellation and stream completion; capacity/saturation; independent scopes and TLS-policy isolation; old/new route generations and whole-scope retirement. Preserve streaming, raw bytes, ordered request/response trailers and no automatic replay/manual redirects.

Please choose the minimal supported public facade; no private connection/process access is required by Gaoxy. This blocks transport activation until a containing package release is installed and independently qualified, not merely until the issue is closed.
