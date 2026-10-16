# fixed_generation_h2_close_source1 — DONE (read-only diagnosis)

Direct assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline `aa272c3dca700a9275a00bd23920d09bbd4748a1`. Root owns runtime/repository/Git; this worker owns only these two `/tmp` reports. Existing modified/untracked task files were preserved. No implementation or runtime was started. DONE applies to this source diagnosis, not browser/stage acceptance.

## Result

The initiating cause of target350 closing remains **UNPROVEN**. The authenticated target terminal is `{:shutdown, :peer_closed}`. On the inspected Gaoxy/ThousandIsland code path this identifies a matching remote socket-close notification. Worker357 normal DOWN followed by writer355 `:stop` does **not** establish a production worker-DOWN-triggered connection-close defect. A protocol error/reset or peer GOAWAY preceding the remote close also remains possible: the current safe observer does not capture the information necessary to distinguish these paths. Do not change production or relax target-live based on these artifacts alone.

## Proven source path

1. `Gaoxy.HTTP.Connection` uses ThousandIsland.Handler before its own definitions (`apps/gaoxy_http/lib/gaoxy/http/connection.ex:3`). `deps/thousand_island/lib/thousand_island/handler.ex:322–335` injects the GenServer implementation at that point. Its `handle_info` clause at `:416–421` matches **the current socket's** `:tcp_closed` or `:ssl_closed` and returns `{:stop, {:shutdown, :peer_closed}, {socket,state}}`. The HTTP2 generic info handler is defined later at `Gaoxy.HTTP.Connection:302–303`; it does not swallow this earlier injected socket-close clause.
2. ThousandIsland `terminate({:shutdown,reason},...)` at `handler.ex:495–497` invokes `Gaoxy.HTTP.Connection.handle_close/2`, which delegates to HTTP2 `close/1` (`connection.ex:355`). HTTP2 `close/1` kills any remaining workers and sends its writer `:stop` (`http2/connection.ex:1411–1418`). This is a concrete explanation for writer355 stop immediately before target350 exits peer_closed. The writer receives `:stop` and returns normally (`http2/writer.ex:61–62`), consistent with writer355's actual normal terminal.
3. HTTP2 `info/3` at `http2/connection.ex:965–970` returns **local_closed** when `message/2` returns `:close`. Writer-monitor DOWN returns `:close` (`:1079–1081`); a matched worker-monitor DOWN instead resets that one stream, starts pending work, and returns state (`:1083–1097`). There is no direct worker-normal-DOWN -> whole-connection-close branch. Reset emits stream RST_STREAM (`:1328–1331`), not an unconditional connection close.
4. `Stream.run/7` sends authentic `h2_stream_done` before returning `:ok` (`http2/stream.ex:62–77`). Matching ordinary done with local_closed/eof discards with kill=false (`http2/connection.ex:1060–1076`). Discard demonitor-flushes the worker monitor (`:1371`) and removes that stream (`:1378`). Other completion states reset cancel/internal_error. Existing evidence cannot say which branch ran.
5. A protocol-level close can still be a causal predecessor of a peer_closed terminal. `failure/2` queues GOAWAY and marks close_after_write (`:1383–1391`); schedule sends self `:h2_close` once writes drain (`:869–873`), and a peer can close before that message wins. Peer GOAWAY sets draining (`:298–299`). Thus remote terminal reason does not prove Chrome independently chose to close a healthy connection.

## Actual safe evidence and limits

All evidence below is under `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/browser-final2/h2-http2/`.

- `host.log:3` authentic native ids bind target connection350, writer355, worker357 and their leases. Extra connection354/writer356 is a separate admitted actor, not a target substitute.
- `causal-metadata.log:7–9` writer355 successfully sends three final recorded h2_written ACKs. These contain tokens/results only, so they do not identify corresponding frame types or rule out a final RST_STREAM/GOAWAY frame.
- `causal-metadata.log:10` target350 receives worker357's normal DOWN at -576460744527904009; `:11` target sends writer355 stop at -576460744527480990; `:12–13` writer receives stop and target receives writer normal DOWN. Receive trace indicates message receipt; it alone does not prove the matching application callback/branch processed it before demonitor-flush.
- `failure-cohort.log:1` records authenticated writer355 normal terminal sequence61 and target350 peer_closed terminal sequence63. These are genuine target deaths, not failure of identity selection. Extra354 peer_closed and writer356 normal terminal appear separately at sequences33/35.
- `old-browser-events.json` and `browser.log:2` prove old document status200/protocolh2, completed loading, correct DOM, visible screenshot probe. They do not expose the Chromium network service's socket-close decision or post-load HTTP2 frame processing. The production failure source is not proven by a page-level successful response.
- `fixed-generation-browser-cohort1.exs:80–111` captures only writer-ready, writer-written, stop and selected DOWN metadata. It deliberately excludes stream-done, h2_close, socket-close, frame metadata, and callback state. `facts/1` is explicitly a finite failure prefix, not completeness proof (`:62–63`). Missing facts are not proof of absent events.

## Smallest useful additional diagnostic (root execution only)

Keep the executed host2/runner2/cohort1 immutable. Create additive diagnostic copies; retain all live-target assertions, deadlines, actor census, authentic ids, and monitor joins.

1. Add VM-filtered scalar receive/send metadata for authentic `h2_stream_done` (worker/id/token/outcome), `:h2_close`, and current target socket close tag. No socket data or raw state enters logs. Socket-close receipt establishes event ordering but still cannot explain a preceding server frame.
2. Add **arity-only local-call** trace projections for `HTTP2.Connection.message/2` done and DOWN paths, `reset/3`, `failure/2`, `receive_frame/2` for RST/GOAWAY (id/type/code only), and `Gaoxy.HTTP.Connection.handle_close/2` entry. Follow already-qualified scalar match-spec style in `managed_h2_fixed_generation_test.exs:869–916`: `:trace.process(..., [:call,:arity])`, explicit match-spec `{:message, compact_projection}`, no `return_trace` because return values include full state. Project only stream id/token/worker identity equality, present/local_closed/eof/write_failed and connection closing/draining/close_after_write flags; no raw exchange/headers/buffers/sockets. Install before the event under investigation and retain existing bounded trace-delivery custody.
3. If the server projections show ordinary stream discard followed by peer socket close without prior server close/reset/failure, obtain bounded Chrome NetLog or another independent peer-side scalar projection (socket source id, HTTP2 session close event, numeric error and dependency ids). Do not infer idle/preconnect replacement from extra354 closing. Do not discard extra connections or claim a browser internal cause without this evidence.

This is an investigation proposal, not an implemented fixture or runtime repair. Source-side trace can narrow the close; browser-side metadata may still be necessary to prove the initiating client reason. Re-running unchanged browser is not a substitute.

## Ownership, checks and counters

Commands: read-only pwd/Git status/rev-parse/diff-numstat; rg/sed/cat of scoped production, dependency implementation, safe evidence and skills; SHA256 calculations. A first rg referenced nonexistent `native-worker-cohort1.exs` (exit2); corrected to actual `fixed-generation-browser-cohort1.exs`, no source/runtime effect. No tests/compile/build/browser/application/network/process launch or Git mutation. All own commands have finished; no background process exists. Only the assigned `/tmp` reports were created. Production and repository diff unchanged by this worker.

No repair-and-validation round attempted; worker increment0. Received cumulative counters from root handoff: group44/root60/stage failedGREEN3 before new browser failure, expected new failure group45/root61/stage failedGREEN4 pending root recording; fixture repairs3/production repairs0/orchestration repairs2; Astra2/2 exhausted. This report does not reset/increment repair counters or request Astra. No new permission/product decision needed. Remaining risk: actual root cause and browser gate remain unresolved; target-live cannot be waived. Tests were NOT RUN by explicit read-only assignment.

Historical memory was checked only for user preference to preserve assertions/history and use live source identity; no historical runtime result was treated as current evidence.

## Input SHA256

- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`: `586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52`
- `apps/gaoxy_http/lib/gaoxy/http/http2/writer.ex`: `6af7f110ce8a39a834f40409b08f7626ca057230ee66cab0b65304584cec562a`
- `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex`: `2276f9bfb14053ff853a13b564397ba82e5ad685a1451619dde89e398980a581`
- `apps/gaoxy_http/lib/gaoxy/http/connection.ex`: `1b7e3caf6f99352f622f3243dbf3c1742a039182779af06c0ae5fe94eaa708a4`
- `deps/thousand_island/lib/thousand_island/handler.ex`: `baa63be02492beb348e11412fd4a8524a288ecdb1010f6f2c08df2e02f202319`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/fixed-generation-browser-cohort1.exs`: `86776f89816c8659b01d2b3e32133dc6af06eb1d212a4d26bd07993af81c2d8c`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/fixed-generation-browser-host2.exs`: `3a543ae6cf85f26dfe593d3d474f8a7370b8b6ad8e2e07a3e57da5806ec564d9`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/fixed-generation-browser-runner2.py`: `ecdeec87aeaa9d2026375a950923d29bb1449e87ef9e55ed325ea1ef9b8f8f94`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/browser-final2/h2-http2/causal-metadata.log`: `1ac93c5d302b5de63b0ca92354d6aa2e0c0d88fef8b2631e68b2cc758c04d0e9`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/browser-final2/h2-http2/failure-cohort.log`: `c897497fc1bd6333f7ab974b3608550639ed4ed16c6accdc35252710868e1192`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/browser-final2/h2-http2/host.log`: `0a533da3b6f74bcd324aaeefb3a7c0610eac71c2330501a33c87c4d2d877954a`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/browser-final2/h2-http2/old-browser-events.json`: `a9954bd4ad5e2e39df77a4d5b0712314b1e96dd9498ae93df5a91d46690fcf42`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/browser-final2/h2-http2/browser.log`: `f681212ca300dd50ef6a4c32d45f7f90649329825d6bdc7aaef9eea2f76ee4dd`
