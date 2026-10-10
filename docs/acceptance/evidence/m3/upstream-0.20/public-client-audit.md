# HTTP Fetch 0.20.0 public-client source audit

Task `m3_public_client_audit`, direct read-only source/contract assignment.
Audit result: **BLOCKED_ENV for M3 reusable transport delivery**: the installed
public fetch contract cannot give Gaoxy owned transport admission, retained-byte
accounting and deadline-confirmed retirement. This is a missing upstream feature,
tracked by [Feature #78](https://github.com/gsmlg-dev/http_fetch/issues/78)
(`internal request`, severity blocker), not a reason to access private pool state
or patch a dependency. Completion and
H2 upload-trailer support are now present; they do not close this lifecycle gap.

Workspace `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `d92d3691e073fbf33195b567af7be10cea6132fc`.
Initial checkout was clean. Parent subsequently owns `apps/gaoxy_proxy/mix.exs`,
`mix.lock` and dependency installation; another agent owns architecture documents.
This auditor changes this report only. No Mix command, runtime fixture, dependency
edit, private-process inspection, commit, push or publication was performed.

## Installed identity and scope of evidence

All seven coordinated lock entries now resolve to **0.20.0**. The parent-owned
[release provenance](release-provenance.json) records actual `v0.20.0` tag commit
`951ec75dadcebd8218f30d3ecdf99da142d4a463`, containing both #66 and #67 fixes.
The release workflow's `head_sha` is separately recorded and must not substitute
for that actual tag identity. [Installed source](installed-source.json) preserves
package checksums and per-file hashes. A read-only Python SHA256 comparison of
every listed `http_fetch`, `http_core` and `http_runtime` source file passed.
Historical 0.19.1 failure evidence remains valid for that historical installation.

This report establishes source contracts and missing interfaces. Dynamic normal,
cancel, sibling, stale-peer, version-matrix, retirement and memory acceptance on
0.20.0 are **NOT RUN by this auditor**. Parent-run tests have separate logs and
must not be inferred from this report.
Parent reports the existing dedicated-H1 baseline passed strict format/compile
and **460 tests / 0 failures**, seed161790; that baseline does not exercise new
Gaoxy pooled/H2 transport behavior.

Source references below use installed package-relative paths and line numbers;
GitHub links are pinned to the actual tag commit and upstream umbrella app paths.

## Public request and cleanup boundary

| Contract | Exact functions/options/types and evidence | Finding |
| --- | --- | --- |
| Fetch | `HTTP.fetch/2` returns `%HTTP.Promise{task: Task.t(), completion: HTTP.RequestCompletion.t()}`; [promise.ex:56–61](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_fetch/lib/http/promise.ex#L56), `http.ex:308–352` | Keep the original promise; chained promises have no cleanup handle. |
| Request cleanup | `HTTP.Promise.completion/1`; `HTTP.RequestCompletion.await/2` and `abort_and_await/2`, finite nonnegative milliseconds, return `:ok` or `{:error, :cleanup_pending \| :cleanup_unconfirmed \| {:unsupported_completion, atom()}}`; [request_completion.ex:3–26,52–79](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_fetch/lib/http/request_completion.ex#L3) | H1 including reuse, H2 and h2c now supported, with manual/error redirects and direct TCP/OTP TLS. Repeated cross-process waits supported. `:ok` releases request resources while healthy shared transports remain open. |
| Unsupported completion | Same file:29–48 | `:auto`/H3, follow redirects, explicit proxy, Unix socket and ExSSL remain unsupported. Gaoxy must choose an explicit protocol and `tls_backend: :ssl`. |
| H2 release acknowledgement | `socket_client.ex:1271–1315` calls `ConnectionOwner.release_stream/2`, then `Pool.release/3` synchronously; failed calls mark lifecycle unconfirmed | Normal/cancel request completion is distinct from transport retirement. |
| Shared resource handoff | `http_core/lib/http/request_lifecycle.ex:50–66,114–125` and `http_runtime/lib/http/http2/pool.ex:125–129` | Tracker relinquishes the pooled socket/connection before pool exposure. Aborting this request does not intentionally close healthy sibling connections. Source support needs live-sibling runtime qualification. |
| Owner loss | `request_lifecycle.ex:162–191` tracks owner/task completion and sets persistent latch to unconfirmed if evidence lost | Owner DOWN alone must not clear a Gaoxy cleanup reservation. No weakening of uncertainty is permitted. |

Gaoxy's existing public contract is `Gaoxy.Proxy.UpstreamClient` callbacks
`open/1`, `poll_headers/1`, `event/2`, `subscribe/1`, `write_body/3`,
`finish_body/2`, `acknowledge/2`, `cleanup/2`, `completion/1`,
`await_completion/2` (`apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_client.ex:4–13`).
`HTTPFetchClient` uses the original handle, zero-time public cleanup polling,
one outstanding acknowledged delivery and `decode_body: false`. The
`Gaoxy.Proxy.HTTP.Session` process acts as cleanup guardian: it monitors owners,
binds group selections to that completion handle and clears service cleanup only
after public cleanup succeeds (`http/session.ex:15–19,132–136,235–267,285–293`).
Pending cleanup polls until the existing finite headroom; unconfirmed cleanup
retains service/group accounting. Preserve this boundary.

The adapter still hardcodes dedicated H1 (`http_fetch_client.ex:55–58`), so the
dependency update alone enables no Gaoxy reuse/H2 feature. Current completion
regressions deliberately use `http_version: :http1, http1_reuse: false`
(`test/http_fetch_completion_test.exs:139–150`), covering cancellation before
headers, outstanding response ACK, blocked upload producer, TLS handshake and
concurrent/repeated waits. They establish no new pooled/H2 acceptance.

## Pool policy, capacity and missing lifecycle

[FetchOptions](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_fetch/lib/http/fetch_options.ex#L44)
documents `http_version: :http1 | :http2 | :h2c | :http3 | :auto`,
`http1_reuse: boolean()` (default false), `http1_scope: atom() | binary() | nil`,
`http1_pool_size: 1..16` (default 2), `http1_idle_timeout: 1..60_000` (default
30_000), `http2_reuse: boolean()` (default true), `http2_scope: atom() | binary()
| nil`, and `http2_profile: atom() | binary() | map() | nil` (lines 44–77,
167–203). Map profile input accepts only `:id`, `:version`, `:synthetic`
(561–575), not caller receive/queue limits.

There is **no pool PID/opaque transport handle fetch option**. Unknown ordinary
options are silently ignored; unknown `http2*` options raise
`ArgumentError, "unsupported HTTP/2 option: ..."` (380–385,609–613). A minimal
source-derived pure reproduction is:

```elixir
# No runtime fixture executed in this audit.
HTTP.FetchOptions.new(pool: self()) == HTTP.FetchOptions.new([])
# true: :pool is silently discarded; no caller pool is selected.
```

`socket_client.ex:426–447,718–747` selects only
`Process.whereis(:http_fetch_http2_pool)`.
[HTTPRuntime.Application:6–12](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_runtime/lib/http_runtime.ex#L6)
starts global H1/H2 pools. No application config read supplies their limits.
H1 `HTTP.HTTP1.Pool` is `@moduledoc false`, fixed global name, and its only
request operations are internal checkout/checkin; it retains at most **256 idle
sockets globally**, subject to per-key size and idle TTL
(`http_runtime/lib/http/http1/pool.ex:1–9,29–46,57–77`). Active H1 sockets remain
bounded by caller admission, not this idle pool limit.

[HTTP.HTTP2.Pool:8–89](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_runtime/lib/http/http2/pool.ex#L8)
exposes `start_link/1`, `reserve/3`, `try_reserve/2`, `claim_connect/2`,
`complete_connect/2`, `fail_connect/3`, `mark_draining/3`, `release/3`,
`cancel/2`, `register/4`, `update_capacity/4`, `update_capabilities/4`, `stats/1`.
Its constructor accepts max connections/key **2**, total connections **20**,
keys **100**, streams/connection **100**, pending/key **100**, idle **30_000 ms**
by default; fetch cannot select a separately constructed pool or pass these
settings. `stats/1` exposes per-key counts, not an owned transport handle or
retirement receipt (94–106). `mark_draining/3` requires a particular owner PID
and only sets admission state; it is not scope retirement or a socket-close
receipt (269–286). Idle expiry starts asynchronous owner stop (431–435).

Example missing acceptance: after an H1 request with reuse and 60-second idle
retention, `RequestCompletion.await/2 == :ok` permits the healthy socket to
remain in the global pool. No supported operation retires only that Gaoxy
generation and acknowledges its sockets/buffers are gone by the service stop
deadline. A scope string separates reuse identity; it cannot join retirement.
H2 has the same distinction, plus a shared long-lived connection budget.
Stopping/reconfiguring global dependency pools, enumerating private owners or
sending private messages would violate Gaoxy's supported-API boundary.

## Identity, verified numeric dial and no replay

[PoolKey.build/4](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_runtime/lib/http/http2/pool_key.ex#L24)
returns `{:ok, map()}` / `{:ok, :non_reusable, map()}` / `{:error, term()}`.
It includes normalized scheme/host/port, negotiated protocol, route/proxy,
numeric `connect_address`, TLS options/backend, socket options, connection
options, compiled profile and caller scope (33–71). CA/certificate/key file
identity hashes size, mtime, mode and contents (178–222); callbacks and opaque
terms disable reuse (198–200,257–283). H1 uses this identity plus its own scope
and pool-size/TTL policy (`http1/pool.ex:29–46`).

`connect_timeout` is part of the connection key (237–239); all `socket_opts`,
including `send_timeout`, are part of socket identity. Gaoxy currently derives
both from remaining request budgets (`http_fetch_client.ex:66–73`), so simply
turning on reuse can create different keys for otherwise equal routes. Required
repair belongs to a public immutable policy contract separated from per-request
deadlines; rounding/lengthening deadlines or removing finite writes is not an
acceptable local workaround.

`connect_address: :inet.ip_address()` retains the original authority/TLS identity;
manual/error redirects are required and H3/Unix/proxy routes rejected
(`fetch_options.ex:34–43,426–442`).
[Dialer:58–92](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_runtime/lib/http/runtime/dialer.ex#L58)
rejects conflicting SNI before dial.
[OTP SSL transport:143–179](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_core/lib/http/transport/ssl.ex#L143)
defaults to peer verification, system CA, original-host SNI and HTTPS hostname
matching; explicit CA file replaces system CA. Numeric address controls the
dial, with no address fallback. TLS files are read for pool identity separately
from the TLS handshake: mutable-file rotation is not an atomic snapshot contract;
future Gaoxy policy must use immutable trust/credential inputs. No race exploit
is claimed or tested here.

No automatic request replay is documented (`fetch_options.ex:31–36,51–53`).
H1 leases reject expired sockets, socket events or an immediately readable/closed
peer before ownership transfer (`http1/pool.ex:118–166`); only fully consumed,
self-delimited, no-carry/no-active-upload responses are reusable
(`socket_client.ex:1539–1565`). After-send failures surface as failures; these
guards are source evidence, not substitute tests for stale-socket races or exact
peer request counts. H2 cleanup releases one stream and pool reservation while
healthy siblings remain; new connections after failure do not replay that request.

## Streaming, trailers and finite retained state

The existing adapter keeps public `HTTP.Stream.start_link/1`, `chunk/3`,
`finish/2`, acknowledged `{:read_chunk, pid, :ack}` delivery and
`{:stream_chunk_ack, ref}`. `stream_response: true` resolves at final headers;
`decode_body: false` retains entity bytes. `finish/2` accepts ordered
`HTTP.Headers.t()` or field list, validates **128 fields / 65_536 serialized
bytes**, and is asynchronous
([stream.ex:117–139](https://github.com/gsmlg-dev/http_fetch/blob/951ec75dadcebd8218f30d3ecdf99da142d4a463/apps/http_fetch/lib/http/stream.ex#L117)).
H1 trailers require chunked upload and declared Trailer fields. H2 upload
trailers now traverse `BodyBridge` validation/EOF (144–175), then
`Connection.send_trailers` and writer admission
(`http_runtime/lib/http/http2/connection_owner.ex:1331–1349`). Queue admission
precedes HPACK encoder commitment, preserving sibling compression state on
rejection. No trailer reordering/collapse is introduced by this source path.

| Retained component | Source-established bound | Practical limit |
| --- | --- | --- |
| H1 delivery + carry | Existing Gaoxy adapter assumes OTP inet/SSL qualified delivery 837_637 bytes with socket buffer8192, plus H1 carry65_536; eight copy windows and chunk/URL/header allowance | Historical OTP qualification is H1-only; recheck installed parser/OTP source before reuse acceptance. Idle retained transports need a separate accounting owner. |
| H2 connection writer queue | 1_048_576 bytes; connection_owner.ex:23,107,677–680 | Fetch does not pass caller queue policy into owner creation (socket_client.ex:577–583). |
| H2 outstanding DATA | max(1_048_576, profile initial connection window); connection_owner.ex:121,1150–1175; stream credit returns on ACK | Shared per connection, not Gaoxy per-request cleanup reservation. Does not bound protocol/control metadata or kernel/OTP buffers. |
| H2 compressed header payload | 65_536 bytes across HEADERS/CONTINUATION; connection_owner.ex:982–1019 | **Fragment-count gap below**; byte cap alone does not bound retained list metadata. |
| HPACK decoded fields/table | Block/decoded/field65_536, fields256, decoder table4096 default; http_core/lib/http/http2/hpack.ex:365–375,532–537,681–702 | Finite decoded expansion; caller cannot supply these decoder limits through Fetch. Not a total allocation/RSS proof. |
| H2 informational response accumulator | 128 responses and65_536 serialized bytes; socket_client.ex:1006–1017 | Enforced in request owner after connection events are sent; does not independently cap control-event mailbox rate. |
| H2 response trailers | 256 fields/65_536 serialized bytes; socket_client.ex:994–1003 | Must also pass Gaoxy downstream header/trailer policy. |
| H2 upload bridge | Max buffered source chunk65_536, slices16_384, one inflight source ACK; body_bridge.ex:10–11,117–139,208–245 | Gaoxy chunks exceeding65_536 must be prevented at configuration/adapter boundary. |

**Concrete source defect requiring upstream qualification:** valid empty
CONTINUATION frames with END_HEADERS unset repeatedly execute
`fragments: [payload | block.fragments]` while `size` remains zero
(`connection_owner.ex:1006–1019`). Empty HEADERS can establish the block.
`http_core/lib/http/http2/boundary.ex:10–29,55–69` admits zero-length
HEADERS/CONTINUATION with valid stream/continuation ordering. Thus arbitrary
empty fragments grow a retained list despite the compressed-byte cap. Request
timeouts limit duration, not a hard fragment/metadata count. A public-peer
regression and upstream finite-fragment policy are **NOT RUN / required**;
there is no permitted Gaoxy wrapper cap that prevents upstream retention before
it receives a decoded response. No unrelated mailbox bug is asserted without a
reproduction.

## Required upstream acceptance and verdict

The parent routed the missing-feature blocker as #78. Required public contract:

1. An opaque instance-owned transport/pool handle accepted by `HTTP.fetch/2`,
   covering H1 reuse and H2, with validated finite connection, stream, queue,
   pending, idle and retained-byte policy.
2. Immutable origin, numeric pin, TLS CA/SNI/authentication, socket and wire
   identity separated from each request's absolute opening/total/write deadlines.
3. Deadline-aware retirement that refuses new work, preserves already admitted
   siblings, settles active request resources, closes idle/shared owned sockets
   and joins owned processes/buffers/reservations before an explicit receipt.
   A failed/pending retirement retains accounting; a healthy other instance is
   untouched. Bounded public status supports exact empty-owned-state checks.
4. Preserve public request-scoped normal/cancel cleanup, streaming/ACK/trailers,
   no replay, TLS verification and policy-isolation behavior. Qualify healthy
   live multiplexed siblings, capacity/saturation, stale sockets, early final,
   abrupt owner loss, drain/force and each supported H1/H2 direction with real peers.
5. Bound empty-header-fragment metadata upstream and add a deterministic
   regression; measure retained shared state separately from request reservations.

Unblocked public qualification recipes for the next worker (all **NOT RUN** in
this audit): use an independent TCP H1 peer, an independent h2c/H2 TLS peer and
stable explicit test options `redirect: :manual`, `request_mode: :proxy`,
`decode_body: false`, `stream_response: true`, `tls_backend: :ssl`, finite
`timeout`/`connect_timeout` and stable `socket_opts`. Reuse cases use
`http_version: :http1, http1_reuse: true, http1_scope: unique_string,
http1_pool_size: 1, http1_idle_timeout: finite_ms`, or
`http_version: :h2c` / `:http2`, `http2_reuse: true`,
`http2_scope: unique_string`, `http2_profile: :native_v1`. Keep each test's
transport settings fixed so shrinking remaining deadlines do not split keys.

- H1 normal fully consumed response: public completion succeeds; peer then sees
  a second request on the exact same connection. Cancellation with an outstanding
  ACK closes that request socket and completion joins the stream/upload producer.
- H2: keep a second stream visibly live on the same independent peer connection;
  normal completion and cancellation of the first must release that request while
  the second continues exact bytes/trailers. Repeated cross-process completion
  waits must be idempotent. Test reset, early final and owner-loss uncertainty.
- Streamed H2 POST uses `HTTP.Stream.chunk/3` and `finish/2` with ordered duplicate
  trailer fields; independent peer verifies final HEADERS END_STREAM, field order,
  exact DATA and byte-based Content-Length. Test both H1 and H2 downstream paths
  separately when the Gaoxy adapter is eventually implemented.
- Empty-fragment reproduction: independent h2c peer sends valid SETTINGS, observes
  request stream ID, sends empty HEADERS without END_HEADERS, then a finite chosen
  count of empty CONTINUATION frames on that stream without END_HEADERS. The
  source growth is one retained fragment-list cell/frame. Finish or cancel inside
  finite deadlines; capture exact owned process/socket teardown. A source report
  may describe the growth, but a runtime observation still needs its own evidence
  and must not be claimed from the nominal65_536 payload cap.

**M3 P8 remains BLOCKED**, while dedicated H1 and already qualified independent
slices remain available. Neither issue closure nor package update alone is
whole-M3 acceptance. Sol repair rounds for this fresh source audit: **0**;
no Astra repair counter received. Commands finished normally; no auditor-owned
process remains. No architecture/model escalation is needed: the blocker is an
evidenced absent dependency contract. Parent owns issue routing, runtime probes,
canonical verification and any later implementation decision.
