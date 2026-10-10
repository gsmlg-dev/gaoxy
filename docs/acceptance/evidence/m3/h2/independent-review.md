# Independent native HTTP/2 specification and code review

Date: 2026-10-10. Reviewer task: `/root/m3_udp_implementation`, direct independent
review assignment. Current verdict: **PASS for the independently reviewed native
H2 source slice after parent round 8; remaining milestone gates are separate**.
Initial verdict was FAIL with five actionable findings reproduced below.
Production repairs belong to `/root`; the reviewer authored no native H2 source.
This review does not approve the reviewer's own UDP implementation.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.
Branch: `codex/m3-gateway`. Baseline:
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus shared task changes.
Existing HTTP/H2, proxy, generation, Groups, Service and UDP changes were preserved.
Only the independent review fixture and this report were edited by this assignment.

Reviewed contracts: `docs/plans/m3-gateway.md` Task 2 and native-H2 portions of
`docs/designs/m3-gateway.md`, including protocol-neutral interfaces, finite
admission/deadlines, flow control, cancellation and resource cleanup.

## Historical reproduced findings — all closed by parent round 8

### H2-I1 — P1: informational headers are accepted after final commitment

Location: `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:605`.

The head operation rejects `(final and stream.committed)` but permits a nonfinal
head after commitment if the response body is still open. An endpoint that calls
`send_chunked(200)` followed by `inform(103)` receives `:ok` for the latter and
queues a new `:status` header block after the final response head. Informational
responses must precede the final response; this also violates the owner's
authoritative response-state contract.

Regression: `informational headers cannot follow a committed final response`.
Actual red result: `{:review_inform, :ok}` where a stream-local
`{:error, :invalid_response_state}` was required. Reject before enqueueing;
preserve the final response and a live sibling stream.

### H2-I2 — P1: readiness marks buffered terminal input consumed too early

Location: `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:861`.

If an initial HEADERS block without END_STREAM and terminal trailers arrive
before the stream worker obtains its lease, readiness initializes the Exchange
body as `:done` whenever `stream.eof && stream.input == ""`, with empty Exchange
trailers. This confuses known wire EOF with the consumer's terminal body step.

The deterministic fixture suspends only its own Admission gate, waits until the
owner has stored the two ordered trailers with `eof: true, lease: nil`, then
resumes admission. The endpoint sees `body_complete? == true` before its first
body read. A forced read still retrieves both trailers; the defect is premature
completion, not loss from the owner's queue. The direct H1 proxy's upload pump
checks `body_complete?` before calling the final read/finish path, so this state
can suppress upload finalization and trailer forwarding.

Regression: `terminal trailers buffered before worker admission still require
final body consumption`. Actual red message:
`{:review_trailers, true, [{"x-check", "first"}, {"x-check", "last"}]}`.
Keep terminal input pending until consumption; an initially ended, bodyless GET
must continue to open no upstream upload stream.

### H2-I3 — P2: generated status escapes response header count/byte bounds

Location: `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:612` and `:626`.

The owner validates regular response fields, including generated content-length,
and only afterward prepends `:status`. With `max_headers: 5`, four endpoint fields
plus content-length pass, then the encoder emits six fields with status. The
request-side limit counts pseudoheaders, while this response path omits its
generated pseudoheader from the same configured count and byte accounting.

Regression: `generated status and framing fields stay inside the configured
response header count`. Actual red result: `{:ok, %Exchange{response: :sent}}`
instead of precommit rejection. The follow-up byte regression uses a 256-byte
limit: one field costs 177 bytes, generated content-length costs 47, and generated
status adds 42, making the complete list 266 bytes. The added byte regression
passes in the fresh round 8 command below. Validate the complete emitted list
while preserving rejection of application-supplied pseudoheaders and safe
fallback responses.

### H2-I4 — P2: a validated advertised frame does not fit the carry limit

Location: `apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex:19`,
`apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:105` and HTTP option validation.

`max_frame: 65_535` is accepted with the default 65,536-byte carry limit. A legal
65,535-byte unknown frame requires 65,544 bytes including its frame header, but
the owner closes on carry growth before its incremental parser can accept it.
The real TCP fixture sends that allowed frame after a live held stream, then
opens a sibling; the sibling receives `{:error, :closed}`.

Regression: `the advertised maximum frame fits the validated ingress carry
budget`. Preserve the original red log. The parent selected strict prebind
rejection of incompatible limits. The updated fixture requires that rejection
from `service_spec/1` and retains the same legal maximum-frame/sibling wire
assertion with an explicit 131,072-byte carry limit. No implicit core budget
increase is requested.

### H2-I5 — P1: response head writes renew the absolute stream deadline

Location: `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:749`.

Queued HEADERS/CONTINUATION operations use a new
`Lifecycle.deadline(write_timeout)` when scheduled; DATA uses the original
stream deadline. The fixture suspends the test connection's Gaoxy writer and
captures the admitted `h2_write` command from a real response operation with a
one-second request deadline and five-second write timeout. Its scheduled
deadline exceeds the original stream deadline by 4,009 ms.

Regression: `a queued response head retains its original absolute stream
deadline`. This permits started header blocks, including those preserved after
worker cancellation, to hold the writer and siblings beyond the stream budget.
Retain the original deadline through header fragmentation/scheduling. Once a
header block is started, complete its required CONTINUATION sequence within that
deadline or close the connection; do not drop END_HEADERS or replay uncertain
writes.

## Historical initial source assessment (listed findings now closed)

| Area inspected | Assessment at reviewed source |
| --- | --- |
| Connection/Frame/Settings state | Preface, first SETTINGS, ACK lengths, stream IDs, padding, priority self-dependency, continuation exclusivity, WINDOW_UPDATE zero/overflow, reset/GOAWAY and unknown frames traced. Frame carry/configuration finding H2-I4 remains. |
| HPACK/Headers | Public pinned HPAX 1.1.0 only; fixed reserved decoder capacity acquired before SETTINGS/decode; header-block limit enforced before decode; rejected/closed-stream header blocks still update decoder. RFC Huffman/dynamic and malformed vectors exist; Python h2/hpack independently decodes wire responses. Stateless never-store encoder declares size zero on every block, allowing unsent canceled blocks to be removed without lost resize state. Complete generated-field bound finding H2-I3 remains. |
| Stream admission/body credits | One pending worker start, service/local stream limits, separate worker lease and Admission request watchdog, authenticated PID+stream-token operations, one deferred read/write, connection/stream credit on next demand, full padded DATA wire charging, bounded canceled-body discard traced. Readiness finding H2-I2 remains. |
| Outbound scheduling/cancellation | One writer frame in flight; DATA requires both windows; round-robin ready streams; unsent canceled headers removed; already-started header blocks preserved through END_HEADERS. Fresh parent tests exercise both cancellation cases. Original header deadline finding H2-I5 remains. |
| Response/Exchange/Plug/facades | Protocol-neutral body, trailers, metadata, abort and response dispatch preserve H1 routing. Bodyless HEAD/204/205/304, duplicate fields, file chunks, fixed/streamed bodies, declared trailers and informational response tests exist. Owner commitment rejects a second final response and application pseudoheaders. Informational-after-final finding H2-I1 remains. |
| Ownership and public cleanup | Owner/writer/worker links and monitors traced, plus public socket closure and Admission expiry. Dedicated H1 proxy guardian monitors worker/service/instance/gate; it retains Service cleanup tracking until public `RequestCompletion.await` or `abort_and_await` settles. No private HTTP Fetch process inspection or dependency edits found in this slice. |
| ALPN/TLS/h2c/unsupported operations | Default H1 preserved; explicit prior-knowledge H2-only TCP; validated TLS ALPN; no ALPN/unknown protocol fail closed where required; TLS policy traced. H2 CONNECT returns 501; Plug upgrade/push reject; no extended-CONNECT advertisement. Independent verified TLS peer exists. |
| Drain/pause | Drain sends GOAWAY with accepted stream watermark and a finite service close timer, continues admitted streams, and cancels remaining workers on close. Pause refusal follows Admission mode while existing frame/control traffic progresses. Existing scoped network assertions cover these paths. |

Positive new runtime checks: a positive WINDOW_UPDATE on a never-opened stream
produces a connection PROTOCOL_ERROR and terminates the held worker; a SETTINGS
window reduction creates a negative stream send window while a separately
credited sibling completes exactly, then restored credit completes the original
stream. Both passed in the seven-test red command.

## Exact verification and source identity

Exclusive umbrella Mix window granted by `/root` after Groups reached a
compile-safe checkpoint. Executed from the worktree root:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; set -euo pipefail
unbuffer mix format apps/gaoxy_http/test/http2_independent_review_test.exs
unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/http2_independent_review_test.exs | tee docs/acceptance/evidence/m3/h2/independent-review-red.log'
```

Formatting passed; compilation of changed HTTP/Proxy modules passed; ExUnit
executed **7 tests, 5 failures**, seed **483847**, process exit **2**. This was a
findings reproduction gate, not a green acceptance gate. Session `97389` finished;
no reviewer-owned command remains running. The Mix window was released to root.

SHA256 at red verification:

- HTTP2 Connection: `b0c0cd468a51af4a10b4d79a05179621e251434dacc7f62babf3ce12fb66b840`
- HTTP2 Limits: `513c774a5e45a06c44a516274bec2f7bd3dbc1a25d273b3df7499eff69bdfb24`
- Original seven-test fixture: `6f409e6ff7205e5e97c8c230717b0f33f95098b5e6bb16d8b6d5295ae2da5aab`

The current fixture adds the byte-bound case and the agreed maximum-frame
configuration contract. Parent production repair round 8 was independently
re-reviewed and verified as recorded below. Historical
`parent-udp3-h2-green.log` records 28 network/integration tests passing at seed
502446; it does not cover these new assertions or establish current whole-slice
acceptance.

## Parent round 8 independent re-review — PASS

The reviewer read the repaired owner head-state/complete emitted-field bound,
initial EOF tracking/readiness, fragmented output deadline/cancellation queue
handling, and pure ingress-budget validation. H2-I1 through H2-I5 are closed:

| Finding | Verified repair |
| --- | --- |
| H2-I1 | Any committed final response rejects later heads, including informational heads. The original final response and a sibling still complete. |
| H2-I2 | `initial_eof` records the initial HEADERS state independently of later wire EOF. Buffered terminal trailers require a final consumer read; initially ended GET compatibility remains green. |
| H2-I3 | Owner reserves one field and the full generated status-byte charge before validating regular output. Count and byte fixtures reject before commitment and return an exact safe fallback. |
| H2-I4 | Pure HTTP options reject `max_frame + 9 > max_buffer_bytes`; the legal 65,535-byte unknown-frame/sibling assertion passes with explicit 131,072-byte carry capacity. |
| H2-I5 | Every HEADERS/CONTINUATION queue entry carries the original stream deadline, preserved by scheduling and triple-shaped cancellation filtering. Deadline capture and both existing cancellation/END_HEADERS fixtures pass. |

Granted exclusive Mix window, exact command:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; set -euo pipefail
sha256sum apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex apps/gaoxy_http/lib/gaoxy/http/options.ex
unbuffer mix format apps/gaoxy_http/test/http2_independent_review_test.exs
unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_http/test/http2_independent_review_test.exs apps/gaoxy_http/test/http2_network_test.exs apps/gaoxy_http/test/http2_integration_test.exs | tee docs/acceptance/evidence/m3/h2/independent-review-round8.log'
```

Actual result: formatting passed, **37 tests, 0 failures**, seed **196890**,
exit **0**. This includes all eight independent fixtures, actual Python TCP and
verified TLS ALPN/HPACK peer checks, proxy trailer/early-final/reset/disconnect
cleanup, and owner/writer/cancellation/drain network tests in the named suites.
Session `44702` finished and the Mix window was released; no own command remains
running. The original seven-test red log is unchanged.

SHA256 of re-reviewed source and current fixture:

- HTTP2 Connection: `afa7af5c793c01c562c27e0ab986828cd1f645f72a62d485321e5d81776bbf8c`
- HTTP Options: `3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90`
- Eight-test fixture: `27eab0d72a8e0aff546d413999d9ab6a6a2cfd4960893e3e153fdd58f8419b82`

## Current formatted-source specification and separate quality re-review

Current Connection SHA256:
`36c327b6b2294cb847cfceca9658beb955acf6080e7cdc547604ee2b89ad56b8`.
Options remains
`3c1a68f1bf58d4f205958b82230e6d28665b719c7b64923593992decdcafdb90`.
Root identifies the intervening delta from the round 8 source as `mix format`
only, with no production logic changes. The reviewer re-read committed/final
head guards, full generated-status bounds, initial-EOF consumer tracking,
HEADERS/CONTINUATION deadlines, queue scheduling/cancellation triples and ingress
carry validation at the formatted source. **Specification verdict: PASS**;
H2-I1 through H2-I5 remain closed.

After that specification pass, performed a separate quality review of those
current paths: **quality verdict: PASS for this reviewed source slice**. The
changes retain the authoritative owner, original stream deadline, decoder state
and already-started header-block sequencing, while applying bounded validation
before commitment. No new actionable source finding remains. This is separate
from the reviewer's own UDP work.

The **37/0** runtime result above belongs to its recorded `afa7af5...` Connection
hash; it is retained as that exact historical proof. Current formatted-source
canonical HTTP/proxy execution is owned by root and must record the new hash
before it is claimed as fresh acceptance. No concurrent reviewer Mix was run.

## Remaining gates and handoff (current)

- H2-I1 through H2-I5 are resolved and the eight current independent fixtures
  plus network/integration suites pass. The prescribed full scoped HTTP/proxy
  command and broader codec/protocol/facade gates still need their own current
  evidence before full Task 2/milestone acceptance.
- Preserve independent Python TCP and verified TLS ALPN/Huffman/dynamic decoding,
  cancellation/CONTINUATION, early H1 final, request/response trailer, stale
  operation, writer/owner death, pause/drain and public cleanup assertions.
- Invalid TLS version/cipher rejection, a broader malformed-frame/error-scope
  matrix, actual slow socket-send uncertainty, header/SETTINGS/partial-preface
  timer exhaustion and configured output-reservation sizing are not newly
  qualified by this review command. Selected existing tests are scoped evidence,
  not HTTP/2 conformance/security certification.
- External core consumer isolation, full M3 ten-minute load/browser/reload gates,
  hosted CI, publication/deployment and production acceptance are not run by this
  assignment; retain their separate milestone status.

Reviewer production repair rounds: **0**. Expected red regression execution is
not a production repair. Prior UDP worker counters remain attempted **2**,
unsuccessful **1**, Astra **0**, with UDP production ownership already transferred
to parent. No new Astra gate is asserted. No commits, pushes, dependency patches,
test skips or weakened assertions were performed. Parent decides and implements
the targeted fixes; no user product decision or external permission is needed.
