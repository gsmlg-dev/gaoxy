# Managed H1 parser-error delivery

## Current 0.21.3 disposition — 2026-10-11

Bug#98 is contained in installed0.21.3. The original B11/B12 exact parser
oracles now pass within baseline20/0; the separate public H2 parser supplement
also passes. Preserve the original failed0.21.2 receipts and submitted request.

Installed coordinated packages are **0.21.3**, tag
`ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Compatibility486/0, public
managed39/39, supplemental TLS95 five cases/five cleanups, H1 baseline20/0,
B21 and public H2 supplement8/8 (TLS4/h2c4) pass with owned joins.
See [current acceptance](../acceptance/m3.md) for the exact execution receipts.
Five acquired-request failure regressions and final delivery review are pending.

Feature [#97](http-fetch-managed-h1-control-frontier.md) remains OPEN and blocks
complete H1 numerical/native control accounting and managed activation. Full
H2 accounting/adversarial backlog, managed integration, matrix and soaks remain
unqualified; managed Tasks4–8 and M4 stay gated. No local workaround is used.

## Historical 0.21.2 observation and submitted request

Upstream: [gsmlg-dev/http_fetch#98](https://github.com/gsmlg-dev/http_fetch/issues/98).
Bug, label `internal request`; closed by merged PR99 (`263858903a586f31d1f25da41d444d718e497695`).
The installed0.21.2 artifact lacks this fix. GitHub latest remains0.21.2 at this
observation, so B11/B12 remain BLOCKED until a containing dependency update and
fresh original-case qualification. No local workaround. Feature97 remains OPEN
and independently blocks numerical accounting and managed activation.

The following is the submitted request, describing the unchanged0.21.2 baseline.
Exact remote state/body/type is preserved in
[`h1-parser-error-issue98.json`](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/h1-parser-error-issue98.json).

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** blocker for M3 managed H1 parser/trailer functional qualification (B11/B12). Managed production activation remains disabled. We are stopping these cases without a local timing workaround or weakened error assertions.

We need parser failures on a streamed H1 response to remain observable through the supported response-stream API, including when the first reader attaches after the response head. The installed coordinated HTTP Fetch 0.21.2 cohort can terminate the public stream through lifecycle cancellation before delivering its parser error. A late reader can receive no terminal response; an already attached reader can race to generic `:aborted` instead of the original parser reason.

Audited release: seven packages at 0.21.2, tag `f677ca49519a007a7a551a5a515127c0f29d8ae6`, tree `664a2a0de2bd4820017599b2d25f62bc7dcf63b0`. Environment: Elixir 1.18.5, OTP 28.5.0.7 / ERTS 16.4.0.6, Linux x86_64, `+S 2:2`. Package provenance is `deps/http_fetch/mix.exs` (`@source_url https://github.com/gsmlg-dev/http_fetch`); the lifecycle module comes from the coordinated `http_core` package.

**Minimal public reproduction**

1. Open one supported `HTTP.ManagedTransport` scope with explicit H1, finite deadlines and connection/request limits. Start a loopback independent peer.
2. Call `HTTP.fetch` with that scope and `stream_response: true`. Register the original `HTTP.Promise.completion(promise)` before `HTTP.Promise.await` and retain that original handle.
3. The peer sends `HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n`. Return the public response head before attaching its reader.
4. After the controller receives the head, the peer emits 8193 ASCII `0` bytes without CRLF and holds the socket open. This must fail as `:line_too_long`.
5. Await the original completion with a finite timeout before first reader attachment, then attach with the supported `{:read_chunk, self(), :ack}` stream message and wait finitely for its terminal error.
6. The current source permits completion `:ok` after cancellation stops the unread stream; the subsequently attached reader receives no terminal error. With an earlier reader, lifecycle cancellation can race with the parser error and expose `:aborted`.

The same race affects forbidden or excess H1 response trailers. No private-process monitoring, process suspension, source patch or artificial reader-order barrier is needed to expose the defect.

**Source ordering**

- `apps/http_fetch/lib/http/socket_client.ex:1558-1575`: `fail/2` calls `HTTP.RequestLifecycle.abort(...)` before `HTTP.Stream.error(stream_pid, reason)`.
- `apps/http_core/lib/http/request_lifecycle.ex:409-412`: cancellation of a managed response stream sends `{:request_lifecycle_stop, :aborted}`.
- `apps/http_fetch/lib/http/stream.ex:194-202`: lifecycle-stop flushes an error and returns `:ok` unconditionally. If no reader is attached, the stream exits with no consumer terminal message. Its later parser-error message cannot be delivered.

These messages originate from different senders, so their order is not established by the order of calls in `fail/2`. A requester-side reader barrier does not establish the ordering of lifecycle stop and parser error.

**Actual requesting-repo evidence**

Our unchanged-oracle 20-case baseline executed 20 tests, with 4 failures, exit 1 and zero skips/exclusions. B11 times out consuming the 8193-byte line case; B12 times out consuming forbidden trailers, while a preceding excess-trailer case did deliver its exact error. B05/B17 are distinct local fixture issues and are being handled separately. All 1132 selected source/build inputs were unchanged. Owned fixture actors and peers were stopped/joined, but public attempt cleanup proof for the failed cases did not pass.

Preserved artifacts in `docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/`:

- `h1-fixture-repair2-baseline2.json`, `.log`, `-analysis.json`;
- `h1-fixture-repair2-baseline2-artifacts/B11-result.json` and `B12-result.json`, plus their attempt/generation rows;
- baseline log SHA256 `993d6e494225d014381d39fbf10a6144af4dc8bec4fa42dfae5f4b9ca8063cc3`.

**Expected behavior and upstream acceptance**

Preserve the original parser error for both already attached and late first response readers, with exactly one terminal observation and bounded cleanup. A malformed response must not become an unobservable dead stream or a generic abort merely because internal lifecycle cleanup won a race. Add deterministic regressions for the line limit and malformed response trailers, with reader attachment before and after failure; verify original completion and scope retirement separately. Publish the fix in the coordinated dependency release so the requesting repo can update and requalify its original cases.
